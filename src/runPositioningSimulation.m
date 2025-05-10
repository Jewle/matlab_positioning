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
        chanBase, ofdmInfo, sampleRate, chDelay, numPaths, speedOfLight, distance, delayULDL,useMusic, useAoA, methodStr);
    
    % Трилатерация и вычисление ошибок
    [positionSTAEst, RMSE] = performTrilateration(numAPs, numIterations, snrRange, positionAP, positionSTA, distEst, methodStr);
    
    % Визуализация результатов
    visualizeTrilateration(numAPs, numIterations, snrRange, positionAP, positionSTAEst, distEst, methodStr);
    
    % Очистка путей поиска
    cleanupSearchPaths();
end

function setupSearchPaths()
    addpath('libs');
    currentFolder = fileparts(mfilename('fullpath'));
    addpath(currentFolder);
    addpath(fullfile(currentFolder, 'src')); % Добавляем папку с декомпозированными файлами
end

function cleanupSearchPaths()
    rmpath('libs');
    currentFolder = fileparts(mfilename('fullpath'));
    rmpath(currentFolder);
    rmpath(fullfile(currentFolder, 'src')); % Удаляем папку
end
