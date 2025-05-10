function positionSTAEst = heAoAPositionEstimate(positionAP, distEst, aoaEst)
    % Оценивает позицию STA на основе AoA и ToA
    % positionAP - позиции AP [2, numAPs]
    % distEst - оценённые расстояния [numAPs, 1]
    % aoaEst - оценённые углы прихода [numAPs, numPaths]
    % Возвращает positionSTAEst [2, 1] - координаты STA

    numAPs = size(positionAP, 2);
    positionSTAEst = nan(2, 1);

    if numAPs < 1 || any(isnan(distEst)) || any(isnan(aoaEst(:)))
        return; % Недостаточно данных
    end

    % Для одного AP используем ToA (расстояние) и AoA (угол)
    if numAPs == 1
        % Положение AP
        apX = positionAP(1, 1);
        apY = positionAP(2, 1);
        
        % Расстояние (ToA)
        r = distEst(1);
        
        % Угол AoA (берём первый путь, конвертируем в радианы)
        theta = deg2rad(aoaEst(1, 1));
        
        % Вычисляем координаты STA
        staX = apX + r * cos(theta);
        staY = apY + r * sin(theta);
        
        positionSTAEst = [staX; staY];
    else
        % Для нескольких AP используем пересечение лучей (AoA)
        % Упрощённый подход: минимизация ошибки по углам
        % Начальное приближение - среднее положение AP
        x0 = mean(positionAP, 2);
        
        % Функция ошибки: сумма угловых отклонений
        errorFunc = @(x) sum(arrayfun(@(i) abs(atan2(x(2) - positionAP(2, i), x(1) - positionAP(1, i)) - deg2rad(aoaEst(i, 1))), 1:numAPs));
        
        % Оптимизация
        options = optimoptions('fminunc', 'Display', 'off');
        xOpt = fminunc(errorFunc, x0, options);
        
        positionSTAEst = xOpt;
    end
end