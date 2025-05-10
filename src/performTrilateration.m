function [positionSTAEst, RMSE] = performTrilateration(numAPs, numIterations, snrRange, positionAP, positionSTA, distEst, methodStr)
    numSNR = numel(snrRange);
    % Проверка размеров
    if size(distEst, 1) ~= numAPs || size(positionAP, 2) ~= numAPs
        error('Размеры distEst или positionAP не соответствуют numAPs');
    end
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
