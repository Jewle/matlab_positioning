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

    % Начальное приближение - центр масс AP с корректировкой
    x0 = mean(positionAP, 2) * 0.5; % Уменьшаем влияние крайних AP

    % Ограничения на область поиска (расширим до 50x50 м)
    lb = [-50; -50];
    ub = [50; 50];

    % Функция ошибки с весами
    w = ones(1, numAPs) ./ (1 + abs(aoaEst(:, 1) + 90)); % Вес зависит от близости к -90°
    errorFunc = @(x) sum(arrayfun(@(i) w(i) * (atan2(x(2) - positionAP(2, i), x(1) - positionAP(1, i)) * 180/pi - aoaEst(i, 1)).^2, 1:numAPs));
    

    % Оптимизация с настройками
    options = optimoptions('fmincon', 'Display', 'off', 'Algorithm', 'sqp', 'MaxIterations', 2000, 'TolFun', 1e-6);
    try
        xOpt = fmincon(errorFunc, x0, [], [], [], [], lb, ub, [], options);
        positionSTAEst = xOpt;
        disp(['Оценённая позиция STA: ', mat2str(positionSTAEst')]);
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