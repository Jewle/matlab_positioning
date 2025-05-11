function [positionSTA, positionAP, distance] = customPosGen(numAPs, numIterations, numSNR)
    % Генерирует позиции STA и AP для симуляции
    % numAPs - количество точек доступа
    % numIterations - количество итераций
    % numSNR - количество значений ОСШ
    % Возвращает:
    % positionSTA - позиции STA [2, numIterations, numSNR]
    % positionAP - позиции AP [2, numAPs, numIterations, numSNR]
    % distance - расстояния от STA до AP [numAPs, numIterations]

    positionSTA = zeros(2, numIterations, numSNR);
    positionAP = zeros(2, numAPs, numIterations, numSNR);
    distance = zeros(numAPs, numIterations);
    
    for iter = 1:numIterations
        % Генерация случайной позиции STA в области 10x10 м
        staPos = 10 * rand(2, 1); % Координаты [x, y] в диапазоне [0, 10]

        % Генерация позиций AP, гарантирующая их различие
        apPos = zeros(2, numAPs);
        minSeparation = 1; % Минимальное расстояние между AP (в метрах)
        for ap = 1:numAPs
            validPos = false;
            while ~validPos
                candidatePos = 10 * rand(2, 1); % Случайная позиция
                % Проверка расстояния до уже сгенерированных AP
                if ap == 1 || all(vecnorm(apPos(:, 1:ap-1) - candidatePos) >= minSeparation)
                    apPos(:, ap) = candidatePos;
                    validPos = true;
                end
            end
        end

        % Вычисление расстояний от STA до AP
        dist = vecnorm(apPos - staPos);
        
        % Сохранение результатов
        distance(:, iter) = dist;
        positionSTA(:, iter, 1) = staPos;
        positionAP(:, :, iter, 1) = apPos;

        % Копирование для всех SNR
        for isnr = 1:numSNR
            positionSTA(:, iter, isnr) = positionSTA(:, iter, 1);
            positionAP(:, :, iter, isnr) = positionAP(:, :, iter, 1);
        end
    end
end