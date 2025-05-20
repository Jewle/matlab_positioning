#!/bin/bash

# Этот скрипт создает или обновляет файлы для проекта моделирования позиционирования.

# Предупреждение о перезаписи файлов
echo "Внимание: этот скрипт перезапишет следующие файлы:"
echo "  - PositioningGUI.m"
echo "  - runPositioningSimulation.m"
echo "  - src/simulateRanging.m"
echo "  - src/heRangingTOAEstimateWithoutMusic.m"
echo "  - src/heRangingAoAEstimateESPRIT.m"
echo "Убедитесь, что у вас есть резервные копии, если это необходимо."

# Создание директорий, если их еще нет
mkdir -p src libs

# Создание файла PositioningGUI.m
echo "Создание PositioningGUI.m..."
cat << 'EOF' > PositioningGUI.m
classdef PositioningGUI < matlab.apps.AppBase
    properties (Access = public)
        UIFigure
        NumIterationsLabel
        NumIterationsEditField
        SNRRangeLabel
        SNRRangeEditField
        NumAPsLabel
        NumAPsEditField
        ChanBWLabel
        ChanBWDropDown
        NumTxLabel
        NumTxEditField
        NumRxLabel
        NumRxEditField
        NumSTSLabel
        NumSTSEditField
        NumLTFRepetitionsLabel
        NumLTFRepetitionsEditField
        DelayProfileLabel
        DelayProfileDropDown
        CarrierFrequencyLabel
        CarrierFrequencyEditField
        DelayULDLLabel
        DelayULDLEditField
        UseMusicCheckBox
        UseAoACheckBox
        AoAMethodDropDown
        RunSimulationButton
    end

    methods (Access = private)
        function startupFcn(app)
            app.ChanBWDropDown.Items = {'CBW20', 'CBW40', 'CBW80', 'CBW160'};
            app.DelayProfileDropDown.Items = {'Model-A', 'Model-B', 'Model-C', 'Model-D', 'Model-E'};
            app.AoAMethodDropDown.Items = {'MUSIC', 'ESPRIT'};
        end

        function RunSimulationButtonPushed(app, event)
            addpath('libs');
            numIterations = app.NumIterationsEditField.Value;
            snrRangeStr = app.SNRRangeEditField.Value;
            snrRange = str2num(snrRangeStr); %#ok<ST2NM>
            numAPs = app.NumAPsEditField.Value;
            chanBW = app.ChanBWDropDown.Value;
            numTx = app.NumTxEditField.Value;
            numRx = app.NumRxEditField.Value;
            numSTS = app.NumSTSEditField.Value;
            numLTFRepetitions = app.NumLTFRepetitionsEditField.Value;
            delayProfile = app.DelayProfileDropDown.Value;
            carrierFrequency = app.CarrierFrequencyEditField.Value;
            delayULDL = app.DelayULDLEditField.Value;
            useMusic = app.UseMusicCheckBox.Value;
            useAoA = app.UseAoACheckBox.Value;
            aoaMethod = app.AoAMethodDropDown.Value;
            runPositioningSimulation(numIterations, snrRange, numAPs, chanBW, numTx, numRx, numSTS, numLTFRepetitions, delayProfile, carrierFrequency, delayULDL, useMusic, useAoA, aoaMethod);
        end
    end

    methods (Access = private)
        function createComponents(app)
            app.UIFigure = uifigure('Position', [100 100 640 520], 'Name', 'Моделирование позиционирования');

            % Number of Iterations
            app.NumIterationsLabel = uilabel(app.UIFigure, 'Position', [50 470 120 22], 'Text', 'Количество итераций');
            app.NumIterationsEditField = uieditfield(app.UIFigure, 'numeric', 'Position', [180 470 100 22], 'Value', 10);

            % SNR Range
            app.SNRRangeLabel = uilabel(app.UIFigure, 'Position', [50 440 120 22], 'Text', 'Диапазон ОСШ (дБ)');
            app.SNRRangeEditField = uieditfield(app.UIFigure, 'text', 'Position', [180 440 100 22], 'Value', '20:5:40');

            % Number of APs
            app.NumAPsLabel = uilabel(app.UIFigure, 'Position', [50 410 120 22], 'Text', 'Количество ТД');
            app.NumAPsEditField = uieditfield(app.UIFigure, 'numeric', 'Position', [180 410 100 22], 'Value', 3);

            % Channel Bandwidth
            app.ChanBWLabel = uilabel(app.UIFigure, 'Position', [50 380 120 22], 'Text', 'Ширина полосы');
            app.ChanBWDropDown = uidropdown(app.UIFigure, 'Position', [180 380 100 22], 'Items', {'CBW20', 'CBW40', 'CBW80', 'CBW160'}, 'Value', 'CBW40');

            % Number of Tx Antennas
            app.NumTxLabel = uilabel(app.UIFigure, 'Position', [50 350 120 22], 'Text', 'Количество передающих антенн');
            app.NumTxEditField = uieditfield(app.UIFigure, 'numeric', 'Position', [180 350 100 22], 'Value', 2);

            % Number of Rx Antennas
            app.NumRxLabel = uilabel(app.UIFigure, 'Position', [50 320 120 22], 'Text', 'Количество принимаемых антенн');
            app.NumRxEditField = uieditfield(app.UIFigure, 'numeric', 'Position', [180 320 100 22], 'Value', 2);

            % Number of Space-Time Streams
            app.NumSTSLabel = uilabel(app.UIFigure, 'Position', [50 290 120 22], 'Text', 'Количество пространственно-временных потоков');
            app.NumSTSEditField = uieditfield(app.UIFigure, 'numeric', 'Position', [180 290 100 22], 'Value', 2);

            % Number of LTF Repetitions
            app.NumLTFRepetitionsLabel = uilabel(app.UIFigure, 'Position', [50 260 120 22], 'Text', 'Повторение HE-LTF');
            app.NumLTFRepetitionsEditField = uieditfield(app.UIFigure, 'numeric', 'Position', [180 260 100 22], 'Value', 2);

            % Delay Profile
            app.DelayProfileLabel = uilabel(app.UIFigure, 'Position', [50 230 120 22], 'Text', 'Модель канала');
            app.DelayProfileDropDown = uidropdown(app.UIFigure, 'Position', [180 230 100 22], 'Items', {'Model-A', 'Model-B', 'Model-C', 'Model-D', 'Model-E'}, 'Value', 'Model-B');

            % Carrier Frequency
            app.CarrierFrequencyLabel = uilabel(app.UIFigure, 'Position', [50 200 120 22], 'Text', 'Частота (Гц)');
            app.CarrierFrequencyEditField = uieditfield(app.UIFigure, 'numeric', 'Position', [180 200 100 22], 'Value', 2.4e9);

            % Delay UL-DL
            app.DelayULDLLabel = uilabel(app.UIFigure, 'Position', [50 170 120 22], 'Text', 'Задержка ВЛ-НЛ (s)');
            app.DelayULDLEditField = uieditfield(app.UIFigure, 'numeric', 'Position', [180 170 100 22], 'Value', 1e-6);

            % Чекбоксы и выпадающий список
            app.UseMusicCheckBox = uicheckbox(app.UIFigure, 'Position', [50 140 200 22], 'Text', 'ToA с MUSIC', 'Value', true);
            app.UseAoACheckBox = uicheckbox(app.UIFigure, 'Position', [50 110 200 22], 'Text', 'Использовать AoA', 'Value', false);
            app.AoAMethodDropDown = uidropdown(app.UIFigure, 'Position', [250 110 100 22], 'Items', {'MUSIC', 'ESPRIT'}, 'Value', 'MUSIC');

            % Run Simulation Button
            app.RunSimulationButton = uibutton(app.UIFigure, 'push', 'Position', [280 50 150 30], 'Text', 'Запустить симуляцию');
            app.RunSimulationButton.ButtonPushedFcn = createCallbackFcn(app, @RunSimulationButtonPushed, true);
        end
    end

    methods (Access = public)
        function app = PositioningGUI
            createComponents(app);
            registerApp(app, app.UIFigure);
            runStartupFcn(app, @startupFcn);
        end

        function delete(app)
            delete(app.UIFigure);
        end
    end
end
EOF
echo "PositioningGUI.m создан."

# Создание файла runPositioningSimulation.m
echo "Создание runPositioningSimulation.m..."
cat << 'EOF' > runPositioningSimulation.m
function runPositioningSimulation(numIterations, snrRange, numAPs, chanBW, numTx, numRx, numSTS, numLTFRepetitions, delayProfile, carrierFrequency, delayULDL, useMusic, useAoA, aoaMethod)
    % Настройка путей поиска
    setupSearchPaths();

    % Конфигурация сигналов и канала
    [cfgSTABase, cfgAPBase, ofdmInfo, sampleRate, chanBase, chDelay, numPaths, speedOfLight] = ...
        configureWaveformAndChannel(numAPs, chanBW, numTx, numRx, numSTS, numLTFRepetitions, delayProfile, carrierFrequency);

    % Генерация позиций STA и AP
    [positionSTA, positionAP, distance] = generateAllPositions(numAPs, numIterations, numel(snrRange));

    % Определение строки метода
    if useAoA
        methodStr = ['AoA с ' aoaMethod];
    else
        methodStr = getMethodString(useMusic);
    end

    % Симуляция ranging
    [distEst, aoaEst, per] = simulateRanging(numAPs, numIterations, snrRange, cfgSTABase, cfgAPBase, ...
        chanBase, ofdmInfo, sampleRate, chDelay, numPaths, numRx, carrierFrequency, speedOfLight, distance, delayULDL, useMusic, useAoA, aoaMethod, methodStr);

    % Трилатерация или AoA-позиционирование и вычисление ошибок
    [positionSTAEst, RMSE] = performTrilateration(aoaEst, numAPs, numIterations, snrRange, positionAP, positionSTA, distEst, methodStr, useAoA);

    % Визуализация результатов
    if useAoA
        visualizeAoAPositioning(numAPs, numIterations, snrRange, positionAP, positionSTA, positionSTAEst, aoaEst, methodStr);
    else
        visualizeTrilateration(numAPs, numIterations, snrRange, positionAP, positionSTAEst, distEst, methodStr);
    end

    % Построение сравнительных графиков
    plotRMSEComparison(RMSE, snrRange, methodStr);

    % Очистка путей поиска
    cleanupSearchPaths();
end

function setupSearchPaths()
    addpath('libs');
    currentFolder = fileparts(mfilename('fullpath'));
    addpath(currentFolder);
    addpath(fullfile(currentFolder, 'src'));
end

function cleanupSearchPaths()
    rmpath('libs');
    currentFolder = fileparts(mfilename('fullpath'));
    rmpath(currentFolder);
    rmpath(fullfile(currentFolder, 'src'));
end

function plotRMSEComparison(RMSE, snrRange, methodStr)
    figure;
    plot(snrRange, mean(RMSE, 1, 'omitnan'), '-o', 'DisplayName', methodStr);
    xlabel('ОСШ (дБ)');
    ylabel('RMSE (м)');
    title('Сравнение точности позиционирования');
    legend('Location', 'best');
    grid on;
end
EOF
echo "runPositioningSimulation.m создан."

# Создание файла src/simulateRanging.m
echo "Создание src/simulateRanging.m..."
cat << 'EOF' > src/simulateRanging.m
function [distEst, aoaEst, per] = simulateRanging(numAPs, numIterations, snrRange, cfgSTABase, cfgAPBase, ...
    chanBase, ofdmInfo, sampleRate, chDelay, numPaths, numRx, carrierFrequency, speedOfLight, distance, delayULDL, useMusic, useAoA, aoaMethod, methodStr)

    numSNR = numel(snrRange);
    distEst = nan(numAPs, numIterations, numSNR);
    aoaEst = nan(numAPs, numIterations, numSNR, numPaths);
    per = zeros(numSNR, 1);

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
                    end
                end

                if ~useAoA && ~any(isnan(txTime))
                    toaUL = todUL + txTime(1);
                    todDL = toaUL + delayULDL;
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
end
EOF
echo "src/simulateRanging.m создан."

# Создание файла src/heRangingTOAEstimateWithoutMusic.m
echo "Создание src/heRangingTOAEstimateWithoutMusic.m..."
cat << 'EOF' > src/heRangingTOAEstimateWithoutMusic.m
function fracDelay = heRangingTOAEstimateWithoutMusic(chanEstActiveSC, activeFFTIndices, fftLength, sampleRate)
    chanEstMean = mean(chanEstActiveSC, [2, 3]);
    chanEstFull = zeros(fftLength, 1);
    chanEstFull(activeFFTIndices) = chanEstMean;
    impulseResponse = ifft(ifftshift(chanEstFull));
    absImpulse = abs(impulseResponse);

    % Оценка шумового уровня из последней четверти сигнала
    noiseThreshold = mean(absImpulse(end-fftLength/4:end)) * 3;
    validPeaks = absImpulse > noiseThreshold;
    firstPeakIdx = find(validPeaks, 1, 'first');

    if isempty(firstPeakIdx)
        warning('Первый пик не найден, возвращается fracDelay = 0');
        fracDelay = 0;
    else
        % Уточнение пика в окне ±2 отсчёта
        window = max(1, firstPeakIdx-2):min(length(absImpulse), firstPeakIdx+2);
        [~, relIdx] = max(absImpulse(window));
        fracDelay = (window(relIdx) - 1) / sampleRate;
    end
end
EOF
echo "src/heRangingTOAEstimateWithoutMusic.m создан."

# Создание файла src/heRangingAoAEstimateESPRIT.m
echo "Создание src/heRangingAoAEstimateESPRIT.m..."
cat << 'EOF' > src/heRangingAoAEstimateESPRIT.m
function aoa = heRangingAoAEstimateESPRIT(chanEst, numRx, carrierFrequency, numPaths)
    % Оценка углов прихода с помощью ESPRIT
    if numRx < 2
        error('Для ESPRIT требуется минимум 2 антенны');
    end

    numPaths = min(numPaths, numRx - 1);

    % Формирование корреляционной матрицы
    R = zeros(numRx, numRx);
    for sc = 1:size(chanEst, 1)
        H = squeeze(chanEst(sc, :, 1));
        R = R + H * H';
    end
    R = R / size(chanEst, 1) + 1e-6 * eye(numRx); % Регуляризация

    % Собственное разложение
    [V, D] = eig(R);
    [~, idx] = sort(diag(D), 'descend');
    V = V(:, idx);
    Es = V(:, 1:numPaths); % Сигнальное подпространство

    % Подмассивы
    E1 = Es(1:end-1, :);
    E2 = Es(2:end, :);

    % Матрица вращения
    Psi = pinv(E1) * E2;

    % Углы
    phi = angle(eig(Psi));
    lambda = physconst('LightSpeed') / carrierFrequency;
    d = lambda / 2;
    aoa = asin(phi * lambda / (2 * pi * d)) * 180 / pi;

    % Корректировка длины результата
    aoa = aoa(1:numPaths);
    if length(aoa) < numPaths
        aoa = [aoa; zeros(numPaths - length(aoa), 1)];
    end
end
EOF
echo "src/heRangingAoAEstimateESPRIT.m создан."

# Сообщение о завершении
echo "Все файлы успешно созданы или обновлены."
echo "Проверьте, что все остальные необходимые файлы уже присутствуют в проекте."
