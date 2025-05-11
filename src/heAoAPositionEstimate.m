function positionSTAEst = heAoAPositionEstimate(positionAP, aoaEst)
    % Оценивает позицию STA только на основе углов прихода (AoA)
    % positionAP - позиции AP [2, numAPs]
    % aoaEst - оценённые углы прихода [numAPs, numPaths] в градусах
    % Возвращает positionSTAEst [2, 1] - координаты STA

    numAPs = size(positionAP, 2);
    positionSTAEst = nan(2, 1);

    if numAPs < 2 || any(isnan(aoaEst(:)))
        warning('Для позиционирования по AoA требуется минимум 2 точки доступа с валидными углами');
        return;
    end

    % Начальное приближение - среднее положение AP
    x0 = mean(positionAP, 2);

    % Ограничения на область поиска (10x10 м)
    lb = [0; 0]; % Нижняя граница
    ub = [10; 10]; % Верхняя граница

    % Функция ошибки: сумма квадратов угловых отклонений
    errorFunc = @(x) sum(arrayfun(@(i) (atan2(x(2) - positionAP(2, i), x(1) - positionAP(1, i)) - deg2rad(aoaEst(i, 1))).^2, 1:numAPs));

    % Оптимизация с ограничениями
    options = optimoptions('fmincon', 'Display', 'off', 'Algorithm', 'sqp');
    try
        xOpt = fmincon(errorFunc, x0, [], [], [], [], lb, ub, [], options);
        positionSTAEst = xOpt;
    catch e
        warning('Ошибка оптимизации: %s', e.message);
        positionSTAEst = nan(2, 1);
    end

    % Отладочный вывод
    if any(isnan(positionSTAEst))
        disp('Невозможно определить позицию STA. Проверьте aoaEst:');
        disp(aoaEst(:, 1));
    end
end