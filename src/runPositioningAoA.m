function runPositioningAoA(numIter, snrRange, numAPs, chanBW, numTx, numRx, numSTS, numEstAPs, delayProfile, carrierFrequency, sampleTime, useAoAMode, useTDoAMode, useFDoAMode)
    % Запуск симуляции для MUSIC и ESPRIT
    methods = {'MUSIC', 'ESPRIT'};
    rmseResults = zeros(length(snrRange), length(methods));

    for methodIdx = 1:length(methods)
        method = methods{methodIdx};
        fprintf('Запуск симуляции с методом: %s\n', method);

        % Инициализация массивов для хранения результатов
        positionError = zeros(numIter, length(snrRange));
        allDistanceEst = zeros(numAPs, numIter, length(snrRange));
        allAoaEst = zeros(numAPs, 2, numIter, length(snrRange));
        allPositionSTA = zeros(2, numIter, length(snrRange));
        allPositionAP = zeros(2, numAPs, numIter, length(snrRange));

        for isnr = 1:length(snrRange)
            snr = snrRange(isnr);
            fprintf('Для ОСШ = %d дБ\n', snr);

            for iter = 1:numIter
                % Генерация позиций
                [positionSTA, positionAP] = generateAllPositions(iter, numAPs, snr);

                % Сохранение позиций
                allPositionSTA(:, iter, isnr) = positionSTA;
                allPositionAP(:, :, iter, isnr) = positionAP;

                % Симуляция
                [distanceEst, aoaEst] = simulateRanging(positionSTA, positionAP, snr, chanBW, numTx, numRx, numSTS, numAPs, delayProfile, carrierFrequency, sampleTime, useAoAMode, useTDoAMode, useFDoAMode, method);

                % Сохранение результатов
                allDistanceEst(:, iter, isnr) = distanceEst;
                allAoaEst(:, :, iter, isnr) = aoaEst;

                % Оценка позиции
                positionSTAEst = heAoAPositionEstimate(positionAP, aoaEst);

                % Ошибка
                positionError(iter, isnr) = sqrt(sum((positionSTA - positionSTAEst).^2));

                % Визуализация (для последней итерации)
                if iter == numIter
                    visualizeAoAPositioning(positionSTA, positionAP, positionSTAEst, aoaEst, method);
                end
            end

            rmse = sqrt(mean(positionError(:, isnr).^2));
            rmseResults(isnr, methodIdx) = rmse;
            fprintf('Для ОСШ = %d дБ, Метод: %s, Среднеквадратичная ошибка позиционирования = %.4f м.\n', snr, method, rmse);
        end
    end

    % Вывод сравнительной таблицы
    fprintf('\nСравнительная таблица RMSE (м):\n');
    fprintf('SNR (дБ) | MUSIC  | ESPRIT\n');
    fprintf('---------|--------|--------\n');
    for isnr = 1:length(snrRange)
        fprintf('%d       | %.4f | %.4f\n', snrRange(isnr), rmseResults(isnr, 1), rmseResults(isnr, 2));
    end
end