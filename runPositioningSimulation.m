function runPositioningSimulation(numIterations, snrRange, numAPs, chanBW, numTx, numRx, numSTS, numLTFRepetitions, delayProfile, carrierFrequency, delayULDL)
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
        disp(['At SNR = ', num2str(snrRange(isnr)), ' dB, ', 'Ranging mean absolute error = ', num2str(mae), ' meters.'])
    end

    % Построение CDF ошибок расстояний
    rangingError = abs(distance - distEst);
    rangingError = reshape(rangingError(~isnan(rangingError)), [], numSNR);
    if ~isempty(rangingError)
        figure('Name', 'Ranging Error CDF');
        hePlotErrorCDF(rangingError, snrRange);
        xlabel('Absolute ranging error (meters)');
        title('Ranging Error CDF');
    else
        disp('No valid ranging error data for CDF plot.');
    end

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
            disp(['At SNR = ', num2str(snrRange(isnr)), ' dB, Average RMS Positioning error = ', num2str(posEr), ' meters.'])
        else
            disp(['At SNR = ', num2str(snrRange(isnr)), ' dB, No valid positioning data.'])
        end
    end

    % Построение CDF ошибок позиционирования
    % validRMSE = RMSE(~isnan(RMSE(:)));
    % if ~isempty(validRMSE)
    %     figure('Name', 'Positioning Error CDF');
    %     hePlotErrorCDF(validRMSE, snrRange);
    %     xlabel('RMS positioning error (meters)');
    %     title('Positioning Error CDF');
    % else
    %     disp('No valid positioning error data for CDF plot.');
    % end

    % Построение трилатерационных кругов для каждого SNR
    for isnr = 1:numSNR
        validIter = find(sum(~isnan(distEst(:, :, isnr)), 1) >= 3, 1, 'last');
        if ~isempty(validIter)
            figure('Name', ['Trilateration Circles for SNR ', num2str(snrRange(isnr)), ' dB']);
            hePlotTrilaterationCircles(squeeze(positionAP(:, :, validIter, isnr)), ...
                                       squeeze(positionSTAEst(:, validIter, isnr)), ...
                                       squeeze(distEst(:, validIter, isnr)), ...
                                       snrRange(isnr), validIter);
        else
            disp(['No valid trilateration data for SNR ', num2str(snrRange(isnr)), ' dB']);
        end
    end

    % Удаляем путь после выполнения
    rmpath('libs');
    rmpath(currentFolder);
end