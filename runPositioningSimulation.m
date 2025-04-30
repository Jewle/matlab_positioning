function runPositioningSimulation(numIterations, snrRange, numAPs, numSTAs, chanBW, numTx, numRx, numSTS, numLTFRepetitions, delayProfile, carrierFrequency, delayULDL)
    % Добавляем папку libs в путь поиска
    addpath('libs');

    % 802.11az Waveform Configuration
    cfgSTABase = heRangingConfig;
    cfgSTABase.ChannelBandwidth = chanBW;
    cfgSTABase.NumTransmitAntennas = numTx;
    cfgSTABase.SecureHELTF = true;
    cfgSTABase.User{1}.NumSpaceTimeStreams = numSTS;
    cfgSTABase.User{1}.NumHELTFRepetitions = numLTFRepetitions;

    cfgAPBase = cell(1, numAPs);
    for iAP = 1:numAPs
        cfgAPBase{iAP} = heRangingConfig;
        cfgAPBase{iAP}.ChannelBandwidth = chanBW;
        cfgAPBase{iAP}.NumTransmitAntennas = numTx;
        cfgAPBase{iAP}.SecureHELTF = true;
        cfgAPBase{iAP}.User{1}.NumSpaceTimeStreams = numSTS;
        cfgAPBase{iAP}.User{1}.NumHELTFRepetitions = numLTFRepetitions;
    end

    ofdmInfo = wlanHEOFDMInfo('HE-LTF', chanBW, cfgSTABase.GuardInterval);
    sampleRate = wlanSampleRate(chanBW);

    % Channel Configuration
    speedOfLight = physconst('lightspeed');
    chanBase = wlanTGaxChannel;
    chanBase.DelayProfile = delayProfile;
    chanBase.NumTransmitAntennas = numTx;
    chanBase.NumReceiveAntennas = numRx;
    chanBase.SampleRate = sampleRate;
    chanBase.CarrierFrequency = carrierFrequency;
    chanBase.ChannelBandwidth = chanBW;
    chanBase.PathGainsOutputPort = true;
    chanBase.NormalizeChannelOutputs = false;

    chBaseInfo = info(chanBase);
    chDelay = chBaseInfo.ChannelFilterDelay;
    numPaths = size(chBaseInfo.PathDelays, 2);

    % Ranging Measurement
    numSNR = numel(snrRange);
    distEst = nan(numAPs, numSTAs, numIterations, numSNR); % Estimated distance
    distance = zeros(numAPs, numSTAs, numIterations, numSNR); % True distance
    positionSTA = zeros(2, numSTAs, numIterations, numSNR); % STA positions
    positionAP = zeros(2, numAPs, numIterations, numSNR); % AP positions
    per = zeros(numSNR, 1); % Packet error rate

    parfor isnr = 1:numSNR
        chan = chanBase;
        cfgAP = cfgAPBase;
        cfgSTA = cfgSTABase;

        rangingError = 0;
        failedPackets = 0;

        stream = RandStream('combRecursive', 'Seed', 123456);
        stream.Substream = isnr;
        RandStream.setGlobalStream(stream);

        % Уменьшаем SNR для учета интерференции от других STA
        snrVal = snrRange(isnr) - 10*log10(ofdmInfo.FFTLength/ofdmInfo.NumTones) - 10*log10(numSTAs);

        for iter = 1:numIterations
            % Generate random AP and STA positions
            [positionSTA(:, :, iter, isnr), positionAP(:, :, iter, isnr), distanceAllAPs] = heGeneratePositions(numAPs, numSTAs);
            distance(:, :, iter, isnr) = distanceAllAPs;

            % Range-based delay
            delay = distance(:, :, iter, isnr)/speedOfLight;
            sampleDelay = delay*sampleRate;

            for sta = 1:numSTAs
                for ap = 1:numAPs
                    linkType = ["Uplink", "Downlink"];
                    todUL = randsrc(1, 1, 0:1e-9:1e-6);
                    numLinks = numel(linkType);
                    txTime = zeros(1, numLinks);

                    % Моделирование интерференции от других STA
                    interference = zeros(size(tx, 1) + 50, cfg.NumTransmitAntennas);
                    for otherSTA = 1:numSTAs
                        if otherSTA ~= sta
                            % Генерируем сигнал от другой STA
                            cfgInterf = cfgSTA;
                            cfgInterf.User{1}.SecureHELTFOctets = dec2hex(randsrc(1, 2*numOctets(1), (0:15)))';
                            txInterf = heRangingWaveformGenerator(cfgInterf);
                            % Применяем случайную задержку для интерференции
                            interfDelay = heDelaySignal(txInterf, randi([0, 50]));
                            % Прохождение через канал
                            interfMultipath = chan([interfDelay; zeros(50, cfg.NumTransmitAntennas)]);
                            % Нормируем мощность интерференции
                            interfPower = mean(abs(interfMultipath).^2);
                            if interfPower > 0
                                interfMultipath = interfMultipath * sqrt(10^(-snrVal/10) / interfPower);
                            end
                            interference = interference + interfMultipath;
                        end
                    end

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
                        txDelay = heDelaySignal(tx, sampleDelay(ap, sta));
                        txMultipath = chan([txDelay; zeros(50, cfg.NumTransmitAntennas)]);
                        % Добавляем интерференцию
                        rx = awgn(txMultipath + interference, snrVal);
                        [chanEstActiveSC, integerOffset] = heRangingSynchronize(rx, cfg);

                        if ~isempty(chanEstActiveSC)
                            fracDelay = heRangingTOAEstimate(chanEstActiveSC, ofdmInfo.ActiveFFTIndices, ...
                                                             ofdmInfo.FFTLength, sampleRate, numPaths);
                            integerOffset = integerOffset - chDelay;
                            intDelay = integerOffset/sampleRate;
                            txTime(l) = intDelay + fracDelay;
                        else
                            txTime(l) = NaN;
                        end
                    end

                    if ~any(isnan(txTime))
                        toaUL = todUL + txTime(1);
                        todDL = toaUL + delayULDL;
                        toaDL = todDL + txTime(2);
                        rtt = (toaDL - todUL) - (todDL - toaUL);
                        distEst(ap, sta, iter, isnr) = (rtt/2)*speedOfLight;
                        rangingError = rangingError + abs(distanceAllAPs(ap, sta) - distEst(ap, sta, iter, isnr));
                    else
                        distEst(ap, sta, iter, isnr) = NaN;
                        failedPackets = failedPackets + 1;
                    end
                end
            end
        end
        mae = rangingError/((numAPs*numSTAs*numIterations) - failedPackets);
        per(isnr) = failedPackets/(numAPs*numSTAs*numIterations);
        if per(isnr) > 0.01
            warning('wlan:discardPacket', 'At SNR = %d dB, %d%% of packets were discarded', snrRange(isnr), 100*per(isnr));
        end
        disp(['At SNR = ', num2str(snrRange(isnr)), ' dB, ', 'Ranging mean absolute error = ', num2str(mae), ' meters.'])
    end

    % Построение CDF ошибок расстояний
    rangingError = reshape(abs(distance - distEst), [numAPs*numSTAs*numIterations, numSNR]);
    figure('Name', 'Ranging Error CDF');
    hePlotErrorCDF(rangingError, snrRange);
    xlabel('Absolute ranging error (meters)');
    title('Ranging Error CDF');

    % Trilateration
    positionSTAEst = nan(2, numSTAs, numIterations, numSNR);
    RMSE = nan(numSTAs, numIterations, numSNR);
    for isnr = 1:numSNR
        for sta = 1:numSTAs
            for i = 1:numIterations
                % Проверяем, есть ли валидные расстояния
                if sum(~isnan(distEst(:, sta, i, isnr))) >= 3
                    positionSTAEst(:, sta, i, isnr) = hePositionEstimate(squeeze(positionAP(:, :, i, is
                    RMSE(sta, i, isnr) = sqrt(mean((positionSTAEst(:, sta, i, isnr) - positionSTA(:, sta, i, isnr)).^2));
                end
            end
            validRMSE = RMSE(sta, :, isnr);
            validRMSE = validRMSE(~isnan(validRMSE));
            if ~isempty(validRMSE)
                posEr = mean(validRMSE);
                disp(['At SNR = ', num2str(snrRange(isnr)), ' dB, STA ', num2str(sta), ', Average RMS Positioning error = ', num2str(posEr), ' meters.'])
            else
                disp(['At SNR = ', num2str(snrRange(isnr)), ' dB, STA ', num2str(sta), ', No valid positioning data.'])
            end
        end
    end

    % Построение графика RMSE от итерации для каждой STA
    for sta = 1:numSTAs
        figure('Name', ['RMSE vs Iteration for STA ', num2str(sta)]);
        hold on;
        for isnr = 1:numSNR
            validRMSE = RMSE(sta, :, isnr);
            if any(~isnan(validRMSE))
                plot(1:numIterations, validRMSE, 'LineWidth', 2, 'DisplayName', ['SNR = ' num2str(snrRange(isnr)) ' dB']);
            end
        end
        hold off;
        xlabel('Iteration');
        ylabel('RMS Positioning Error (meters)');
        title(['RMSE vs Iteration for STA ', num2str(sta)]);
        grid on;
        legend('show');
    end

    % Построение CDF ошибок позиционирования
    figure('Name', 'Positioning Error CDF');
    hold on;
    for sta = 1:numSTAs
        validRMSE = squeeze(RMSE(sta, :, :));
        validRMSE = validRMSE(~isnan(validRMSE(:)));
        if ~isempty(validRMSE)
            hePlotErrorCDF(validRMSE, snrRange, 'DisplayName', ['STA ', num2str(sta)]);
        end
    end
    hold off;
    xlabel('RMS positioning error (meters)');
    title('Positioning Error CDF for All STAs');
    legend('show');

    % Построение трилатерационных кругов для каждой STA
    for sta = 1:numSTAs
        validIter = find(sum(~isnan(distEst(:, sta, :, numSNR)), 1) >= 3, 1, 'last');
        if ~isempty(validIter)
            figure('Name', ['Trilateration Circles for STA ', num2str(sta), ' at SNR ', num2str(snrRange(numSNR)), ' dB']);
            hePlotTrilaterationCircles(squeeze(positionAP(:, :, validIter, numSNR)), ...
                                       squeeze(positionSTAEst(:, sta, validIter, numSNR)), ...
                                       squeeze(distEst(:, sta, validIter, numSNR)), ...
                                       snrRange(numSNR), validIter);
        end
    end

    % Удаляем путь после выполнения
    rmpath('libs');
end