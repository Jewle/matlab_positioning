function [positionSTAEst, RMSE] = performTrilateration(aoaEst,numAPs, numIterations, snrRange, positionAP, positionSTA, distEst, methodStr,useAoA)
    % Выполняет трилатерацию или AoA-позиционирование для оценки позиции STA
    % numAPs - количество точек доступа
    % numIterations - количество итераций
    % snrRange - диапазон ОСШ
    % positionAP - позиции AP [2, numAPs, numIterations, numSNR]
    % positionSTA - истинные позиции STA [2, numIterations, numSNR]
    % distEst - оценённые расстояния [numAPs, numIterations, numSNR]
    % aoaEst - оценённые углы [numAPs, numIterations, numSNR, numPaths]
    % methodStr - строка метода
    % useAoA - логический флаг, true для режима только AoA

    numSNR = numel(snrRange);
    
    % Проверка размеров
    if size(distEst, 1) ~= numAPs || size(positionAP, 2) ~= numAPs
        error('Размеры distEst или positionAP не соответствуют numAPs');
    end

    positionSTAEst = nan(2, numIterations, numSNR);
    RMSE = nan(numIterations, numSNR);
    
     for isnr = 1:numSNR
        for i = 1:numIterations
            if useAoA
                % Режим AoA: используем AoA и, если доступно, ToA
                positionSTAEst(:, i, isnr) = heAoAPositionEstimate(squeeze(positionAP(:, :, i, isnr)), ...
                                                                   squeeze(distEst(:, i, isnr)), ...
                                                                   squeeze(aoaEst(:, i, isnr, :)));
            else
                % Режим трилатерации: только ToA
                if sum(~isnan(distEst(:, i, isnr))) >= 3
                    positionSTAEst(:, i, isnr) = hePositionEstimate(squeeze(positionAP(:, :, i, isnr)), ...
                                                                    squeeze(distEst(:, i, isnr)));
                end
            end
            % Вычисление RMSE
            if ~isnan(positionSTAEst(:, i, isnr))
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