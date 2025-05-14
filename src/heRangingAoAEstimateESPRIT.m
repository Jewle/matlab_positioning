function aoa = heRangingAoAEstimateESPRIT(chanEst, numRx, carrierFrequency, numPaths)
    % Оценивает углы прихода (AoA) с использованием алгоритма ESPRIT
    % chanEst - канальные оценки [numSubcarriers, numRx, numSTS]
    % numRx - количество приёмных антенн
    % carrierFrequency - несущая частота (Гц)
    % numPaths - количество путей
    % Возвращает aoa - углы в градусах [1, numPaths]

    % Проверка входных данных
    if numRx < 2
        error('Для AoA требуется минимум 2 приёмные антенны, получено numRx=%d', numRx);
    end
    numPaths = min(numPaths, numRx - 1); % Ограничение числа путей
    disp(['Размер chanEst: ', mat2str(size(chanEst))]);
    disp(['numRx: ', num2str(numRx), ', carrierFrequency: ', num2str(carrierFrequency), ', numPaths: ', num2str(numPaths)]);
    if any(isnan(chanEst(:)))
        warning('chanEst содержит NaN');
    end

    % Параметры антенной решётки
    lambda = physconst('LightSpeed') / carrierFrequency; % Длина волны
    d = lambda / 2; % Расстояние между антеннами

    % Формирование корреляционной матрицы
    R = zeros(numRx, numRx);
    for sc = 1:size(chanEst, 1)
        H = squeeze(chanEst(sc, :, :));
        R = R + H * H';
    end
    R = R / size(chanEst, 1);
    R = R + 1e-6 * eye(numRx); % Регуляризация

    % Отладка
    disp('Корреляционная матрица R:');
    disp(R);
    if rank(R) < numRx
        warning('Корреляционная матрица вырождена, ранг=%d, ожидается %d', rank(R), numRx);
    end

    % Собственное разложение
    [V, D] = eig(R);
    [~, idx] = sort(diag(D), 'descend');
    V = V(:, idx);
    Es = V(:, 1:numPaths); % Сигнальное подпространство

    % Разделение на подмассивы
    E1 = Es(1:end-1, :); % Первые M-1 строк
    E2 = Es(2:end, :);    % Последние M-1 строк

    % Вычисление матрицы вращения Psi
    Psi = pinv(E1) * E2; % Псевдообратная матрица

    % Собственные значения Psi
    [~, D] = eig(Psi);
    phi = angle(diag(D)); % Фазовые сдвиги

    % Преобразование фаз в углы
    aoa = asin(phi * lambda / (2 * pi * d)) * 180 / pi; % В градусах
    disp(['Найдены углы (ESPRIT): ', mat2str(aoa')]);

    % Убедимся, что возвращаем numPaths углов
    aoa = aoa(1:numPaths);
    if length(aoa) < numPaths
        aoa = [aoa; zeros(numPaths - length(aoa), 1)];
    end
end