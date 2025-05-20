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
