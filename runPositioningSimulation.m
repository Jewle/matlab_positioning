function runPositioningSimulation(numIterations, snrRange, numAPs, chanBW, numTx, numRx, numSTS, numLTFRepetitions, delayProfile, carrierFrequency, delayULDL, useMusic, speed)
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
    positionSTA = nan(2, numIterations); % Real STA positions (now 2D)
    positionSTAEst = nan(2, numIterations, numSNR); % Estimated STA positions
    positionAP = zeros(2, numAPs, numIterations, numSNR); % AP positions
    per = zeros(numSNR, 1); % Packet error rate

    % Генерируем начальные позиции AP и STA
    [positionSTA(:, 1), positionAP(:, :, 1, 1), distanceAllAPs] = heGeneratePositions(numAPs);
    distance = zeros(numAPs, numIterations); % True distance
    distance(:, 1) = distanceAllAPs;

    % Копируем начальные позиции AP для всех SNR
    for isnr = 1:numSNR
        positionAP(:, :, 1, isnr) = positionAP(:, :, 1, 1);
    end

    % Генерируем траекторию STA до parfor
    direction = rand(1, 2) * 2 - 1; % Случайное направление в 2D
    direction = direction / norm(direction); % Нормализуем
    localDirection = direction;
    for iter = 2:numIterations
        % Добавляем небольшое случайное отклонение к направлению для нелинейности
        perturbation = (rand(1, 2) - 0.5) * 0.2; % Небольшое отклонение
        localDirection = localDirection + perturbation;
        localDirection = localDirection / norm(localDirection); % Нормализуем
        % Перемещаем STA с равномерной скоростью
        positionSTA(:, iter) = positionSTA(:, iter-1) + speed * localDirection';
        % Обновляем расстояния до AP
        for ap = 1:numAPs
            distance(ap, iter) = norm(positionSTA(:, iter) - positionAP(:, ap, 1, 1));
        end
    end

    % Определяем строку метода для лейблов через if else
    if useMusic
        methodStr = 'MUSIC';
    else
        methodStr = 'No MUSIC';
    end

    % Создаем фигуры для анимации и графиков y(x)
    figure('Name', 'Trilateration Animation');
    hold on;
    axis equal;
    xlabel('X (meters)');
    ylabel('Y (meters)');
    title('Trilateration Animation');

    figure('Name', 'Trajectory Plots');
    subplot(2, 1, 1);
    hold on;
    title('Real Position Trajectory');
    xlabel('X (meters)');
    ylabel('Y (meters)');

    subplot(2, 1, 2);
    hold on;
    title('Estimated Position Trajectory');
    xlabel('X (meters)');
    ylabel('Y (meters)');

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
        localPositionSTAEst = nan(2, numIterations);
        localPositionAP = positionAP(:, :, :, isnr); % Копия позиций AP для текущего SNR

        for iter = 1:numIterations
            % Копируем позиции AP для текущей итерации
            localPositionAP(:, :, iter) = positionAP(:, :, 1, isnr);
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

            % Trilateration для текущей итерации
            if sum(~isnan(localDistEst(:, iter))) >= 3
                localPositionSTAEst(:, iter) = hePositionEstimate(squeeze(localPositionAP(:, :, iter)), localDistEst(:, iter));
            end
        end

        % Сохраняем результаты в глобальные массивы
        distEst(:, :, isnr) = localDistEst;
        positionSTAEst(:, :, isnr) = localPositionSTAEst;
        mae = rangingError/((numAPs*numIterations) - failedPackets);
        per(isnr) = failedPackets/(numAPs*numIterations);
        if per(isnr) > 0.01
            warning('wlan:discardPacket', 'At SNR = %d dB, %d%% of packets were discarded', snrRange(isnr), 100*per(isnr));
        end
        disp(['At SNR = ', num2str(snrRange(isnr)), ' dB, Method: ', methodStr, ', Ranging mean absolute error = ', num2str(mae), ' meters.'])
    end

    % Построение анимации трилатерации с дискретным позиционированием
    figure(1);
    for i = 1:numIterations
        for isnr = 1:numSNR
            if ~isnan(positionSTAEst(1, i, isnr)) && ~isnan(positionSTA(1, i))
                % Очищаем график для каждой новой точки
                cla;
                % Рисуем трилатерационные круги
                hePlotTrilaterationCircles(squeeze(positionAP(:, :, 1, isnr)), positionSTAEst(:, i, isnr), distEst(:, i, isnr), snrRange(isnr), i);
                % Рисуем реальную позицию STA (красная точка)
                plot(positionSTA(1, i), positionSTA(2, i), 'ro', 'MarkerSize', 10, 'DisplayName', 'Real STA');
                % Рисуем вычисленную позицию STA (синяя точка)
                plot(positionSTAEst(1, i, isnr), positionSTAEst(2, i, isnr), 'bo', 'MarkerSize', 10, 'DisplayName', 'Estimated STA');
                legend('show');
                drawnow; % Обновляем график
                pause(0.1); % Задержка для эффекта анимации
            end
        end
    end

    % Построение графиков y(x) для реальной и вычисленной позиций
    figure(2);
    subplot(2, 1, 1);
    plot(positionSTA(1, :), positionSTA(2, :), 'r-', 'DisplayName', 'Real Trajectory');
    legend('show');
    subplot(2, 1, 2);
    for isnr = 1:numSNR
        plot(positionSTAEst(1, :, isnr), positionSTAEst(2, :, isnr), 'b-', 'DisplayName', ['Estimated Trajectory SNR=' num2str(snrRange(isnr)) ' dB']);
    end
    legend('show');

    % Удаляем путь после выполнения
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