% function runPositioningSimulation(numIterations, snrRange, numAPs, chanBW, numTx, numRx, numSTS, numLTFRepetitions, delayProfile, carrierFrequency, delayULDL, useMusic,useAoA)
%     % Основная функция симуляции позиционирования
%     % useAoAMode - логический флаг, true для режима только AoA
% 
%     % Настройка путей поиска
%     setupSearchPaths();
% 
%     % Конфигурация сигналов и канала
%     [cfgSTABase, cfgAPBase, ofdmInfo, sampleRate, chanBase, chDelay, numPaths, speedOfLight] = ...
%         configureWaveformAndChannel(numAPs, chanBW, numTx, numRx, numSTS, numLTFRepetitions, delayProfile, carrierFrequency);
% 
%     % Генерация позиций STA и AP
%     [positionSTA, positionAP, distance] = generatePositions(numAPs, numIterations, numel(snrRange));
% 
%     % Определение строки метода
%     methodStr = getMethodString(useMusic);
% 
%     % Симуляция ranging
%     [distEst, aoaEst, per] = simulateRanging(numAPs, numIterations, snrRange, cfgSTABase, cfgAPBase, ...
%         chanBase, ofdmInfo, sampleRate, chDelay, numPaths,numRx,speedOfLight, distance,delayULDL, useMusic, useAoA, methodStr);
% 
%     % Трилатерация или AoA-позиционирование
%     [positionSTAEst, RMSE] = performTrilateration(numAPs, numIterations, snrRange, positionAP, positionSTA, distEst, aoaEst, methodStr, useAoA);
% 
%     % Визуализация результатов
%     visualizeTrilateration(numAPs, numIterations, snrRange, positionAP, positionSTAEst, distEst, methodStr);
% 
%     % Очистка путей поиска
%     cleanupSearchPaths();
% end