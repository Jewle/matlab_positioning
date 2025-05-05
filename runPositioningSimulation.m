function runPositioningSimulation(snr, numAPs, chanBW, numTx, numRx, numSTS, numLTFRepetitions, delayProfile, carrierFrequency, delayULDL, useMusic)
    % Добавляем папку libs и текущую директорию в путь поиска
    addpath('libs');
    currentFolder = fileparts(mfilename('fullpath'));
    addpath(currentFolder);

    % Параметры движения
    numMoveIterations = 20; % Количество итераций для движения
    xStart = 0; % Начальная координата x
    xStep = 0.5; % Шаг по x для монотонного увеличения

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

    % Генерация траектории STA по y = 3x + 1
    positionSTA = zeros(2, numMoveIterations);
    x = xStart + (0:numMoveIterations-1) * xStep; % Монотонно возрастающая x
    positionSTA(1, :) = x; % x-координаты
    positionSTA(2, :) = 3 * x + 1; % y = 3x + 1

    % Генерация позиций AP
    positionAP = zeros(2, numAPs);
    [~, positionAP(:, :, 1, 1), ~] = heGeneratePositions(numAPs);

    % Инициализация массивов для хранения результатов
    positionSTAEst = nan(2, numMoveIterations);
    distEst = nan(numAPs, numMoveIterations);

    % Определяем строку метода для лейблов через if else
    if useMusic
        methodStr = 'MUSIC';
    else
        methodStr = 'No MUSIC';
    end

    % Вычисление SNR
    snrVal = snr - 10*log10(ofdmInfo.FFTLength/ofdmInfo.NumTones);
    failedPackets = 0;

    % Вычисление позиций для каждой итерации движения
    for iter = 1:numMoveIterations
        % Вычисляем расстояния от STA до AP
        distance = zeros(numAPs, 1);
        for ap = 1:numAPs
            distance(ap) = norm(positionSTA(:, iter) - positionAP(:, ap));
        end

        % Вызываем функцию для оценки позиции
        [distEst(:, iter), positionSTAEst(:, iter), success] = estimatePosition(...
            positionSTA(:, iter), positionAP, distance, cfgSTABase, cfgAPBase, chanBase, ...
            ofdmInfo, sampleRate, chDelay, numPaths, snrVal, useMusic, delayULDL);

        if ~success
            failedPackets = failedPackets + 1;
        end

        % Задержка для имитации непрерывного движения
        pause(0.05);
    end

    % Вывод процента отброшенных пакетов
    per = failedPackets/(numAPs*numMoveIterations);
    if per > 0.01
        warning('wlan:discardPacket', 'At SNR = %d dB, %d%% of packets were discarded', snr, 100*per);
    end

    % Построение последнего графика трилатерации
    figure('Name', ['Trilateration - Last Iteration, Method: ', methodStr]);
    if ~isnan(positionSTAEst(1, end))
        hePlotTrilaterationCircles(positionAP, positionSTAEst(:, end), distEst(:, end), snr, numMoveIterations);
        plot(positionSTA(1, end), positionSTA(2, end), 'ro', 'MarkerSize', 10, 'DisplayName', 'Real STA');
        plot(positionSTAEst(1, end), positionSTAEst(2, end), 'bo', 'MarkerSize', 10, 'DisplayName', 'Estimated STA');
        legend('show');
    end

    % Построение графиков траекторий
    figure('Name', 'Trajectory Plots');
    % Реальная траектория
    subplot(2, 1, 1);
    plot(positionSTA(1, :), positionSTA(2, :), 'r-', 'LineWidth', 2, 'DisplayName', 'Real Trajectory');
    xlabel('X (meters)');
    ylabel('Y (meters)');
    title('Real Position Trajectory');
    legend('show');
    grid on;

    % Оценённая траектория
    subplot(2, 1, 2);
    plot(positionSTAEst(1, :), positionSTAEst(2, :), 'b--', 'DisplayName', ['Estimated (SNR=' num2str(snr) ' dB)']);
    xlabel('X (meters)');
    ylabel('Y (meters)');
    title('Estimated Position Trajectory');
    legend('show');
    grid on;

    % Удаляем путь после выполнения
    rmpath('libs');
    rmpath(currentFolder);
end

function [distEst, positionEst, success] = estimatePosition(positionSTA, positionAP, distance, cfgSTABase, cfgAPBase, chanBase, ofdmInfo, sampleRate, chDelay, numPaths, snrVal, useMusic, delayULDL)
    % Функция для оценки позиции STA в одной итерации
    speedOfLight = physconst('lightspeed');
    numAPs = size(positionAP, 2);
    distEst = nan(numAPs, 1);
    success = true;

    % Копии конфигураций
    cfgSTA = cfgSTABase;
    cfgAP = cfgAPBase;

    for ap = 1:numAPs
        linkType = ["Uplink", "Downlink"];
        todUL = randsrc(1, 1, 0:1e-9:1e-6);
        numLinks = numel(linkType);
        txTime = zeros(1, numLinks);

        delay = distance(ap)/speedOfLight;
        sampleDelay = delay*sampleRate;

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

            reset(chanBase);
            tx = heRangingWaveformGenerator(cfg);
            txDelay = heDelaySignal(tx, sampleDelay);
            txMultipath = chanBase([txDelay; zeros(50, cfg.NumTransmitAntennas)]);
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
            distEst(ap) = (rtt/2)*speedOfLight;
        else
            distEst(ap) = NaN;
            success = false;
        end
    end

    % Trilateration
    if sum(~isnan(distEst)) >= 3
        positionEst = hePositionEstimate(positionAP, distEst);
    else
        positionEst = nan(2, 1);
        success = false;
    end
end

function fracDelay = heRangingTOAEstimateWithoutMusic(chanEstActiveSC, activeFFTIndices, fftLength, sampleRate)
    chanEstMean = mean(chanEstActiveSC, [2, 3]);
    chanEstFull = zeros(fftLength, 1);
    chanEstFull(activeFFTIndices) = chanEstMean;
    impulseResponse = ifft(ifftshift(chanEstFull));
    [~, idx] = max(abs(impulseResponse));
    fracDelay = (idx - 1) / sampleRate;
end