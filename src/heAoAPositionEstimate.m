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

    % Начальное приближение - случайная точка в области
    lb = [-30; -30]; % Расширенная нижняя граница
    ub = [30; 30];   % Расширенная верхняя граница
    x0 = lb + rand(2, 1) .* (ub - lb);

    % Функция ошибки: сумма квадратов угловых отклонений
    errorFunc = @(x) sum(arrayfun(@(i) (atan2(x(2) - positionAP(2, i), x(1) - positionAP(1, i)) * 180/pi - aoaEst(i, 1)).^2, 1:numAPs));

    % Оптимизация с настройками
    options = optimoptions('fmincon', 'Display', 'off', 'Algorithm', 'sqp', 'MaxIterations', 1000, 'TolFun', 1e-6);
    try
        xOpt = fmincon(errorFunc, x0, [], [], [], [], lb, ub, [], options);
        positionSTAEst = xOpt;
        disp(['Оценённая позиция STA: ', mat2str(positionSTAEst')]);
        disp(['Углы прихода aoaEst: ', mat2str(aoaEst(:, 1)')]);
    catch e
        warning('Ошибка оптимизации: %s', e.message);
        positionSTAEst = nan(2, 1);
    end

    % Отладка
    if any(isnan(positionSTAEst))
        disp('Невозможно определить позицию STA. Проверьте aoaEst:');
        disp(aoaEst(:, 1));
    end
end