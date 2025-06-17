function [distEst, aoaEst, per] = simulateRanging(numAPs, numIterations, snrRange, cfgSTABase, cfgAPBase, ...
    chanBase, ofdmInfo, sampleRate, chDelay, numPaths, numRx, carrierFrequency, speedOfLight, distance, delayULDL, useMusic, useAoA, aoaMethod, methodStr)

    numSNR = numel(snrRange);
    distEst = nan(numAPs, numIterations, numSNR);
    aoaEst = nan(numAPs, numIterations, numSNR, numPaths);
    per = zeros(numSNR, 1);
    numLinks = 2; % Uplink и Downlink
    fracDelayEst = nan(numAPs, numIterations, numSNR, numLinks); % Новый массив для fracDelay

    for isnr = 1:numSNR
        chan = chanBase;
        cfgAP = cfgAPBase;
        cfgSTA = cfgSTABase;
        rangingError = 0;
        failedPackets = 0;
        stream = RandStream('combRecursive', 'Seed', 123456);
        stream.Substream = isnr;
        RandStream.setGlobalStream(stream);
        snrVal = snrRange(isnr) - 10*log10(ofdmInfo.FFTLength/ofdmInfo.NumTones);
        localDistEst = nan(numAPs, numIterations);
        localAoaEst = nan(numAPs, numIterations, numPaths);

        for iter = 1:numIterations
            delay = distance(:, iter)/speedOfLight;
            sampleDelay = delay*sampleRate;

            for ap = 1:numAPs
                linkType = ["Uplink", "Downlink"];
                todUL = randsrc(1, 1, 0:1e-9:1e-6);
                numLinks = numel(linkType);
                txTime = zeros(1, numLinks);

                for l = 1:numLinks
                    if linkType(l) == "Uplink"
                        cfgSTA.UplinkIndication = 1;
                        numOctets = numSecureHELTFOctets(cfgSTA);
                        cfgSTA.User{1}.SecureHELTFOctets = dec2hex(randsrc(1, 2*numOctets(1), (0:15)))';
                        cfg = cfgSTA;
                    else
                        numOctets = numSecureHELTFOctets(cfgAP{ap});
                        cfgAP{ap}.User{1}.SecureHELTFOctets = dec2hex(randsrc(1, 2*numOctets(1), (0:15)))';
                        cfg = cfgAP{ap};
                    end

                    reset(chan);
                    tx = heRangingWaveformGenerator(cfg);
                    txDelay = heDelaySignal(tx, sampleDelay(ap));
                    txMultipath = chan([txDelay; zeros(50, cfg.NumTransmitAntennas)]);
                    rx = awgn(txMultipath, snrVal);
                    [chanEstActiveSC, integerOffset] = heRangingSynchronize(rx, cfg);

                    if ~isempty(chanEstActiveSC)
                        % Оценка ToA
                        if ~useAoA
                            if useMusic
                                fracDelay = heRangingTOAEstimate(chanEstActiveSC, ofdmInfo.ActiveFFTIndices, ...
                                                                 ofdmInfo.FFTLength, sampleRate, numPaths);
                            else
                                fracDelay = heRangingTOAEstimateWithoutMusic(chanEstActiveSC, ofdmInfo.ActiveFFTIndices, ...
                                                                             ofdmInfo.FFTLength, sampleRate);
                            end
                            fracDelayEst(ap, iter, isnr, l) = fracDelay; % Сохранение fracDelay
                            integerOffset = integerOffset - chDelay;
                            intDelay = integerOffset/sampleRate;
                            txTime(l) = intDelay + fracDelay;
                        end

                        % Оценка AoA
                        if useAoA
                            if strcmp(aoaMethod, 'MUSIC')
                                localAoaEst(ap, iter, :) = heRangingAoAEstimate(chanEstActiveSC, carrierFrequency, numPaths);
                            else % ESPRIT
                                localAoaEst(ap, iter, :) = heRangingAoAEstimateESPRIT(chanEstActiveSC, numRx, carrierFrequency, numPaths);
                            end
                        end
                    else
                        txTime(l) = NaN;
                        fracDelayEst(ap, iter, isnr, l) = NaN; % Сохранение NaN при неудаче
                    end
                end

                if ~useAoA && ~any(isnan(txTime))
                    toaUL = todUL + txTime(1);
                    todDL = toaUL;
                    toaDL = todDL + txTime(2);
                    rtt = (toaDL - todUL) - (todDL - toaUL);
                    localDistEst(ap, iter) = (rtt/2)*speedOfLight;
                    rangingError = rangingError + abs(distance(ap, iter) - localDistEst(ap, iter));
                elseif ~useAoA
                    localDistEst(ap, iter) = NaN;
                    failedPackets = failedPackets + 1;
                end
            end
        end

        distEst(:, :, isnr) = localDistEst;
        aoaEst(:, :, isnr, :) = localAoaEst;

        if ~useAoA
            mae = rangingError/((numAPs*numIterations) - failedPackets);
            per(isnr) = failedPackets/(numAPs*numIterations);
            if per(isnr) > 0.01
                warning('wlan:discardPacket', 'At SNR = %d dB, %d%% of packets were discarded', snrRange(isnr), 100*per(isnr));
            end
            disp(['Для ОСШ = ', num2str(snrRange(isnr)), ' дБ, Метод: ', methodStr, ', Ошибка определения дистанции = ', num2str(mae), ' м.'])
        end

        if useAoA
            disp(['Оценённые углы прихода (AoA) для ОСШ = ', num2str(snrRange(isnr)), ' дБ:']);
            disp(squeeze(aoaEst(:, :, isnr, :)));
        end
    end

    % Построение графиков fracDelay от итераций для каждого SNR
    if ~useAoA
        figure;
        for isnr = 1:numSNR
            subplot(numSNR, 1, isnr);
            % Усреднение fracDelay по AP и каналам (Uplink/Downlink) для каждой итерации
            meanFracDelay = nanmean(fracDelayEst(:, :, isnr, :), [1, 4]); % Усреднение по AP и каналам
            meanFracDelay = squeeze(meanFracDelay); % Размер [numIterations]
            plot(1:numIterations, meanFracDelay * 1e9, '-o'); % Перевод в наносекунды
            xlabel('Итерация');
            ylabel('fracDelay (нс)');
            title(['SNR = ', num2str(snrRange(isnr)), ' дБ']);
            grid on;
        end
        sgtitle('Дробная задержка в зависимости от итераций для различных SNR');
    else
        warning('Графики fracDelay не строятся, так как включен режим AoA');
    end
end