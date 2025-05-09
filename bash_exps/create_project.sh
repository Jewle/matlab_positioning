#!/bin/bash

# Скрипт для создания MATLAB файлов из декомпозированного кода

# Директория для сохранения файлов
OUTPUT_DIR="./matlab_files"
mkdir -p "$OUTPUT_DIR"

# Функция для создания файла
create_file() {
    local filename="$1"
    local content="$2"
    local filepath="$OUTPUT_DIR/$filename"

    # Проверяем, существует ли файл
    if [ -f "$filepath" ]; then
        echo "Файл $filepath уже существует, пропускаем..."
        return
    fi

    # Записываем содержимое в файл
    echo "$content" > "$filepath"
    echo "Создан файл: $filepath"
}

# 1. runPositioningSimulation.m
create_file "runPositioningSimulation.m" "$(cat << 'EOF'
function runPositioningSimulation(numIterations, snrRange, numAPs, chanBW, numTx, numRx, numSTS, numLTFRepetitions, delayProfile, carrierFrequency, delayULDL, useMusic, useAoA)
    % Настройка путей поиска
    setupSearchPaths();
    
    % Конфигурация сигналов и канала
    [cfgSTABase, cfgAPBase, ofdmInfo, sampleRate, chanBase, chDelay, numPaths, speedOfLight] = ...
        configureWaveformAndChannel(numAPs, chanBW, numTx, numRx, numSTS, numLTFRepetitions, delayProfile, carrierFrequency);
    
    % Генерация позиций STA и AP
    [positionSTA, positionAP, distance] = generatePositions(numAPs, numIterations, numel(snrRange));
    
    % Определение строки метода
    methodStr = getMethodString(useMusic);
    
    % Симуляция ranging
    [distEst, aoaEst, per] = simulateRanging(numAPs, numIterations, snrRange, cfgSTABase, cfgAPBase, ...
        chanBase, ofdmInfo, sampleRate, chDelay, numPaths, speedOfLight, distance, useMusic, useAoA, methodStr);
    
    % Трилатерация и вычисление ошибок
    [positionSTAEst, RMSE] = performTrilateration(numAPs, numIterations, snrRange, positionAP, positionSTA, distEst, methodStr);
    
    % Визуализация результатов
    visualizeTrilateration(numAPs, numIterations, snrRange, positionAP, positionSTAEst, distEst, methodStr);
    
    % Очистка путей поиска
    cleanupSearchPaths();
end
EOF
)"

# 2. setupSearchPaths.m
create_file "setupSearchPaths.m" "$(cat << 'EOF'
function setupSearchPaths()
    addpath('libs');
    currentFolder = fileparts(mfilename('fullpath'));
    addpath(currentFolder);
end

function cleanupSearchPaths()
    rmpath('libs');
    currentFolder = fileparts(mfilename('fullpath'));
    rmpath(currentFolder);
end
EOF
)"

# 3. configureWaveformAndChannel.m
create_file "configureWaveformAndChannel.m" "$(cat << 'EOF'
function [cfgSTABase, cfgAPBase, ofdmInfo, sampleRate, chanBase, chDelay, numPaths, speedOfLight] = ...
    configureWaveformAndChannel(numAPs, chanBW, numTx, numRx, numSTS, numLTFRepetitions, delayProfile, carrierFrequency)
    % Конфигурация STA
    cfgSTABase = heRangingConfig;
    cfgSTABase.ChannelBandwidth = chanBW;
    cfgSTABase.NumTransmitAntennas = numTx;
    cfgSTABase.SecureHELTF = true;
    cfgSTABase.User{1}.NumSpaceTimeStreams = numSTS;
    cfgSTABase.User{1}.NumHELTFRepetitions = numLTFRepetitions;

    % Конфигурация AP
    cfgAPBase = cell(1, numAPs);
    for iAP = 1:numAPs
        cfgAPBase{iAP} = heRangingConfig;
        cfgAPBase{iAP}.ChannelBandwidth = chanBW;
        cfgAPBase{iAP}.NumTransmitAntennas = numTx;
        cfgAPBase{iAP}.SecureHELTF = true;
        cfgAPBase{iAP}.User{1}.NumSpaceTimeStreams = numSTS;
        cfgAPBase{iAP}.User{1}.NumHELTFRepetitions = numLTFRepetitions;
    end

    % Параметры OFDM
    ofdmInfo = wlanHEOFDMInfo('HE-LTF', chanBW, cfgSTABase.GuardInterval);
    sampleRate = wlanSampleRate(chanBW);

    % Конфигурация канала
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
end
EOF
)"

# 4. generatePositions.m
create_file "generatePositions.m" "$(cat << 'EOF'
function [positionSTA, positionAP, distance] = generatePositions(numAPs, numIterations, numSNR)
    positionSTA = zeros(2, numIterations, numSNR);
    positionAP = zeros(2, numAPs, numIterations, numSNR);
    distance = zeros(numAPs, numIterations);
    
    for iter = 1:numIterations
        [positionSTA(:, iter, 1), positionAP(:, :, iter, 1), distanceAllAPs] = heGeneratePositions(numAPs);
        distance(:, iter) = distanceAllAPs;
        for isnr = 1:numSNR
            positionSTA(:, iter, isnr) = positionSTA(:, iter, 1);
            positionAP(:, :, iter, isnr) = positionAP(:, :, iter, 1);
        end
    end
end
EOF
)"

# 5. simulateRanging.m
create_file "simulateRanging.m" "$(cat << 'EOF'
function [distEst, aoaEst, per] = simulateRanging(numAPs, numIterations, snrRange, cfgSTABase, cfgAPBase, ...
    chanBase, ofdmInfo, sampleRate, chDelay, numPaths, speedOfLight, distance, useMusic, useAoA, methodStr)
    numSNR = numel(snrRange);
    distEst = nan(numAPs, numIterations, numSNR);
    aoaEst = nan(numAPs, numIterations, numSNR, numPaths);
    per = zeros(numSNR, 1);
    
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
                        if useMusic
                            fracDelay = heRangingTOAEstimate(chanEstActiveSC, ofdmInfo.ActiveFFTIndices, ...
                                                             ofdmInfo.FFTLength, sampleRate, numPaths);
                        else
                            fracDelay = toEstUpdated(chanEstActiveSC, ofdmInfo.ActiveFFTIndices, ...
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

                if useAoA && ~isempty(chanEstActiveSC)
                    localAoaEst(ap, iter, :) = heRangingAoAEstimate(chanEstActiveSC, numRx, carrierFrequency, numPaths);
                end
            end
        end

        distEst(:, :, isnr) = localDistEst;
        aoaEst(:, :, isnr, :) = localAoaEst;
        mae = rangingError/((numAPs*numIterations) - failedPackets);
        per(isnr) = failedPackets/(numAPs*numIterations);
        if per(isnr) > 0.01
            warning('wlan:discardPacket', 'At SNR = %d dB, %d%% of packets were discarded', snrRange(isnr), 100*per(isnr));
        end
        disp(['Для ОСШ = ', num2str(snrRange(isnr)), ' дБ, Метод: ', methodStr, ', Ошибка определения дистанции = ', num2str(mae), ' м.'])
        if useAoA
            disp(['Оценённые углы прихода (AoA) для ОСШ = ', num2str(snrRange(isnr)), ' дБ:']);
            disp(squeeze(aoaEst(:, :, isnr, :)));
        end
    end
end
EOF
)"

# 6. performTrilateration.m
create_file "performTrilateration.m" "$(cat << 'EOF'
function [positionSTAEst, RMSE] = performTrilateration(numAPs, numIterations, snrRange, positionAP, positionSTA, distEst, methodStr)
    numSNR = numel(snrRange);
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
            disp(['Для ОСШ = ', num2str(snrRange(isnr)), ' дБ, Метод: ', methodStr, ', Среднеквадратичная ошибка позиционирования = ', num2str(posEr), ' м.'])
        else
            disp(['Для ОСШ = ', num2str(snrRange(isnr)), ' дБ Нет валидных данных ', methodStr]);
        end
    end
end
EOF
)"

# 7. visualizeTrilateration.m
create_file "visualizeTrilateration.m" "$(cat << 'EOF'
function visualizeTrilateration(numAPs, numIterations, snrRange, positionAP, positionSTAEst, distEst, methodStr)
    numSNR = numel(snrRange);
    for isnr = 1:numSNR
        validIter = find(sum(~isnan(distEst(:, :, isnr)), 1) >= 3, 1, 'last');
        if ~isempty(validIter)
            hePlotTrilaterationCircles(squeeze(positionAP(:, :, validIter, isnr)), ...
                                       squeeze(positionSTAEst(:, validIter, isnr)), ...
                                       squeeze(distEst(:, validIter, isnr)), ...
                                       snrRange(isnr), validIter);
        else
            disp(['Нет корректных данных для ОСШ ', num2str(snrRange(isnr)), ' дБ, Метод: ', methodStr]);
        end
    end
end
EOF
)"

# 8. getMethodString.m
create_file "getMethodString.m" "$(cat << 'EOF'
function methodStr = getMethodString(useMusic)
    if useMusic
        methodStr = 'MUSIC';
    else
        methodStr = 'Без MUSIC';
    end
end
EOF
)"

# 9. heRangingTOAEstimateWithoutMusic.m
create_file "heRangingTOAEstimateWithoutMusic.m" "$(cat << 'EOF'
function fracDelay = heRangingTOAEstimateWithoutMusic(chanEstActiveSC, activeFFTIndices, fftLength, sampleRate)
    chanEstMean = mean(chanEstActiveSC, [2, 3]);
    chanEstFull = zeros(fftLength, 1);
    chanEstFull(activeFFTIndices) = chanEstMean;
    impulseResponse = ifft(ifftshift(chanEstFull));
    [~, idx] = max(abs(impulseResponse));
    fracDelay = (idx - 1) / sampleRate;
end
EOF
)"

# 10. toEstUpdated.m
create_file "toEstUpdated.m" "$(cat << 'EOF'
function fracDelay = toEstUpdated(chanEstActiveSC, activeFFTIndices, fftLength, sampleRate)
    chanEstMean = mean(chanEstActiveSC, [2, 3]);
    chanEstFull = zeros(fftLength, 1);
    chanEstFull(activeFFTIndices) = chanEstMean;
    impulseResponse = ifft(ifftshift(chanEstFull));
    absImpulse = abs(impulseResponse);
    noiseThreshold = mean(absImpulse(end-fftLength/4:end)) * 3;
    validPeaks = absImpulse > noiseThreshold;
    firstPeakIdx = find(validPeaks, 1, 'first');
    
    if isempty(firstPeakIdx)
        warning('Первый пик не найден, возвращается fracDelay = 0');
        fracDelay = 0;
    else
        window = max(1, firstPeakIdx-2):min(length(absImpulse), firstPeakIdx+2);
        [~, relIdx] = max(absImpulse(window));
        fracDelay = (window(relIdx) - 1) / sampleRate;
    end
end
EOF
)"

# 11. heRangingAoAEstimate.m
create_file "heRangingAoAEstimate.m" "$(cat << 'EOF'
function aoa = heRangingAoAEstimate(chanEst, numRx, carrierFrequency, numPaths)
    lambda = physconst('LightSpeed') / carrierFrequency;
    d = lambda / 2;
    theta = -90:0.1:90;
    steeringVectors = exp(-1j * 2 * pi * d / lambda * (0:numRx-1)' * sind(theta));
    R = zeros(numRx, numRx);
    for sc = 1:size(chanEst, 1)
        H = squeeze(chanEst(sc, :, :));
        R = R + H * H';
    end
    R = R / size(chanEst, 1);
    [V, D] = eig(R);
    [~, idx] = sort(diag(D), 'descend');
    V = V(:, idx);
    En = V(:, numPaths+1:end);
    Pmusic = zeros(1, length(theta));
    for i = 1:length(theta)
        a = steeringVectors(:, i);
        Pmusic(i) = 1 / abs(a' * (En * En') * a);
    end
    [~, locs] = findpeaks(Pmusic, 'SortStr', 'descend', 'NPeaks', min(numPaths, length(theta)));
    if isempty(locs)
        aoa = zeros(1, numPaths);
    else
        aoa = theta(locs);
        if length(aoa) < numPaths
            aoa = [aoa, zeros(1, numPaths - length(aoa))];
        end
    end
end
EOF
)"

echo "Все файлы созданы в директории $OUTPUT_DIR"
