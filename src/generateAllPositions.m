function [positionSTA, positionAP, distance] = generateAllPositions(numAPs, numIterations, numSNR)
%generateAllPositions Generate STA and APs positions for multiple iterations and SNR
%
%   [POSITIONSTA, POSITIONAP, DISTANCE] = generateAllPositions(NUMAPS, NUMITERATIONS, NUMSNR)
%   generates positions for a station (STA) and NUMAPS access points (APs) randomly
%   in the xy-plane with X and Y positions in meters, repeated for NUMITERATIONS
%   iterations and NUMSNR SNR levels.
%
%   POSITIONSTA is a matrix of size 2-by-NUMITERATIONS-by-NUMSNR, representing
%   the 2-dimensional position of the STA (fixed at origin [0; 0]).
%
%   POSITIONAP is a matrix of size 2-by-NUMAPS-by-NUMITERATIONS-by-NUMSNR,
%   representing the 2-dimensional positions of the APs.
%
%   DISTANCE is a matrix of size NUMAPS-by-NUMITERATIONS, representing the
%   distances between the STA and APs in meters.
%
%   NUMAPS is the number of APs in the network.
%   NUMITERATIONS is the number of simulation iterations.
%   NUMSNR is the number of SNR levels.
%
%   Copyright 2025 The MathWorks, Inc.

% Инициализация выходных массивов
positionSTA = zeros(2, numIterations, numSNR);
positionAP = zeros(2, numAPs, numIterations, numSNR);
distance = zeros(numAPs, numIterations);

for iter = 1:numIterations
    % Генерация позиций для одной итерации
    % STA всегда в начале координат
    staPos = [0; 0];
    
    % Генерация углов в радианах в пределах [0: 2*pi] с сектором 2*pi/numAPs
    phi = (0:numAPs-1)*(2*pi/numAPs) + rand(1, numAPs)*2*pi/(2*numAPs);
    
    % Генерация радиусов в метрах из равномерного распределения на интервале [2, 20]
    minRadius = 2; % Минимальное расстояние до AP (м)
    maxRadius = 20; % Максимальное расстояние до AP (м)
    radius = minRadius + (maxRadius - minRadius) * rand(1, numAPs); % Радиус в метрах
    
    % Преобразование из полярных координат в декартовы
    [x, y] = pol2cart(phi, radius);
    
    % Позиции AP
    apPos = [x; y]; % X и Y позиции в метрах
    
    % Проверка минимального расстояния между AP
    minSeparation = 2; % Минимальное расстояние между AP (м)
    for i = 1:numAPs
        for j = i+1:numAPs
            dist = norm(apPos(:, i) - apPos(:, j));
            if dist < minSeparation
                % Перегенерировать позицию j-го AP
                valid = false;
                while ~valid
                    newPhi = rand * 2 * pi;
                    newRadius = minRadius + (maxRadius - minRadius) * rand;
                    [newX, newY] = pol2cart(newPhi, newRadius);
                    newPos = [newX; newY];
                    valid = true;
                    for k = 1:numAPs
                        if k ~= j && norm(newPos - apPos(:, k)) < minSeparation
                            valid = false;
                            break;
                        end
                    end
                    if valid
                        apPos(:, j) = newPos;
                        radius(j) = newRadius;
                    end
                end
            end
        end
    end
    
    % Проверка размеров
    if size(apPos, 2) ~= numAPs || length(radius) ~= numAPs
        error('Некорректные размеры: apPos=%s, radius=%s', ...
              mat2str(size(apPos)), mat2str(size(radius)));
    end
    
    % Сохранение результатов
    distance(:, iter) = radius(:); % Убедимся, что radius - столбец
    positionSTA(:, iter, 1) = staPos;
    positionAP(:, :, iter, 1) = apPos;
    
    % Копирование позиций для всех SNR
    for isnr = 1:numSNR
        positionSTA(:, iter, isnr) = positionSTA(:, iter, 1);
        positionAP(:, :, iter, isnr) = positionAP(:, :, iter, 1);
    end
end
end