function runPositioningSimulation(numIterations, snrRange, numAPs, chanBW, numTx, numRx, numSTS, numLTFRepetitions, delayProfile, carrierFrequency, delayULDL, useMusic)
    % Добавляем папку libs и текущую директорию в путь поиска
    addpath('libs');
    currentFolder = fileparts(mfilename('fullpath'));
    addpath(currentFolder);

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
    distEst = nan(numAPs, numIterations, numSNR); % Estimated distance
    positionSTA = zeros(2, numIterations, numSNR); % STA positions
    positionAP = zeros(2, numAPs, numIterations, numSNR); % AP positions
    per = zeros(numSNR, 1); % Packet error rate

    % Генерируем позиции AP и STA один раз перед parfor
    distance = zeros(numAPs, numIterations); % True distance (не зависит от SNR)
    for iter = 1:numIterations
        [positionSTA(:, iter, 1), positionAP(:, :, iter, 1), distanceAllAPs] = heGeneratePositions(numAPs);
        distance(:, iter) = distanceAllAPs;
        % Копируем позиции для всех SNR
        for isnr = 1:numSNR
            positionSTA(:, iter, isnr) = positionSTA(:, iter, 1);
            positionAP(:, :, iter, isnr) = positionAP(:, :, iter, 1);
        end
    end

    % Определяем строку метода для лейблов
   if useMusic
        methodStr = 'MUSIC';
    else
        methodStr = 'Без MUSIC';
   end

    parfor isnr = 1:numSNR
        chan = chanBase;
        cfgAP = cfgAPBase;
        cfgSTA = cfgSTABase;

        rangingError = 0;
        failedPackets = 0;

        stream = RandStream('combRecursive', 'Seed', 123456);
        stream.Substream = isnr;
        RandStream.setGlobalStream(stream);

        snrVal = snrRange(isnr) - 10*log10(ofdmInfo.FFTLength/ofdmInfo.NumTones);

        % Локальная копия distEst для текущего SNR
        localDistEst = nan(numAPs, numIterations);

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
                        if useMusic
                            fracDelay = heRangingTOAEstimate(chanEstActiveSC, ofdmInfo.ActiveFFTIndices, ...
                                                             ofdmInfo.FFTLength, sampleRate, numPaths);
                        else
                            fracDelay = heRangingTOAEstimateWithoutMusic(chanEstActiveSC, ofdmInfo.ActiveFFTIndices, ...
                                                                         ofdmInfo.FFTLength, sampleRate);
                        end
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
                    localDistEst(ap, iter) = (rtt/2)*speedOfLight;
                    rangingError = rangingError + abs(distance(ap, iter) - localDistEst(ap, iter));
                else
                    localDistEst(ap, iter) = NaN;
                    failedPackets = failedPackets + 1;
                end
            end
        end

        % Сохраняем результаты в глобальный массив
        distEst(:, :, isnr) = localDistEst;
        mae = rangingError/((numAPs*numIterations) - failedPackets);
        per(isnr) = failedPackets/(numAPs*numIterations);
        if per(isnr) > 0.01
            warning('wlan:discardPacket', 'At SNR = %d dB, %d%% of packets were discarded', snrRange(isnr), 100*per(isnr));
        end
        disp(['Для ОСШ = ', num2str(snrRange(isnr)), ' дБ, Метод: ', methodStr, ', Ошибка опредления дистанции = ', num2str(mae), ' м.'])
    end

    % Построение CDF ошибок расстояний
    % rangingError = abs(distance - distEst);
    % validRangingError = rangingError(~isnan(rangingError));
    % if ~isempty(validRangingError)
    %     figure('Name', ['Ranging Error CDF - Method: ', methodStr]);
    %     hePlotErrorCDF(validRangingError, snrRange, methodStr);
    %     xlabel('Absolute ranging error (meters)');
    %     title(['Ranging Error CDF - Method: ', methodStr]);
    % else
    %     disp(['No valid ranging error data for CDF plot - Method: ', methodStr]);
    % end

    % Trilateration
    positionSTAEst = nan(2, numIterations, numSNR);
    RMSE = nan(numIterations, numSNR);
    for isnr = 1:numSNR
        for i = 1:numIterations
            if sum(~isnan(distEst(:, i, isnr))) >= 3
                positionSTAEst(:, i, isnr) = hePositionEstimate(squeeze(positionAP(:, :, i, isnr)), squeeze(distEst(:, i, isnr)));
                RMSE(i, isnr) = sqrt(mean((positionSTAEst(:, i, isnr) - positionSTA(:, i, isnr)).^2));
            end
        end
        validRMSE = RMSE(:, isnr);
        validRMSE = validRMSE(~isnan(validRMSE));
        if ~isempty(validRMSE)
            posEr = mean(validRMSE);
            disp(['Для ОСШ = ', num2str(snrRange(isnr)), ' дБ, Метод: ', methodStr, ', Среднеквадратичная ошибка поз-ания = ', num2str(posEr), ' м.'])
        else
            disp(['Для ОСШ = ', num2str(snrRange(isnr)), ' дБ Нет валидных данных ', methodStr]);
        end
    end

    % Построение CDF ошибок позиционирования
    % validRMSE = RMSE(~isnan(RMSE(:)));
    % if ~isempty(validRMSE)
    %     figure('Name', ['Positioning Error CDF - Method: ', methodStr]);
    %     hePlotErrorCDF(validRMSE, snrRange, methodStr);
    %     xlabel('RMS positioning error (meters)');
    %     title(['Positioning Error CDF - Method: ', methodStr]);
    % else
    %     disp(['No valid positioning error data for CDF plot - Method: ', methodStr]);
    % end

    % Построение трилатерационных кругов для каждого SNR
    for isnr = 1:numSNR
        validIter = find(sum(~isnan(distEst(:, :, isnr)), 1) >= 3, 1, 'last');
        if ~isempty(validIter)
            figure('Name', ['Трилатерация - Метод: ', methodStr, ' для ОСШ ', num2str(snrRange(isnr)), ' дБ']);
            hePlotTrilaterationCircles(squeeze(positionAP(:, :, validIter, isnr)), ...
                                       squeeze(positionSTAEst(:, validIter, isnr)), ...
                                       squeeze(distEst(:, validIter, isnr)), ...
                                       snrRange(isnr), validIter);
        else
            disp(['Нет корректных данных ', num2str(snrRange(isnr)), ' дБ Метод: ', methodStr]);
        end
    end


    rmpath('libs');
    rmpath(currentFolder);
end

% Альтернативная оценка ToA без MUSIC
function fracDelay = heRangingTOAEstimateWithoutMusic(chanEstActiveSC, activeFFTIndices, fftLength, sampleRate)
    chanEstMean = mean(chanEstActiveSC, [2, 3]);
    chanEstFull = zeros(fftLength, 1);
    chanEstFull(activeFFTIndices) = chanEstMean;
    impulseResponse = ifft(ifftshift(chanEstFull));
    [~, idx] = max(abs(impulseResponse));
    fracDelay = (idx - 1) / sampleRate;
end