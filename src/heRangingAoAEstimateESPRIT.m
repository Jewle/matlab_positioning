function aoa = heRangingAoAEstimateESPRIT(chanEst, numRx, carrierFrequency, numPaths)
    % Оценка углов прихода с помощью ESPRIT
    if numRx < 2
        error('Для ESPRIT требуется минимум 2 антенны');
    end

    numPaths = min(numPaths, numRx - 1);

    % Формирование корреляционной матрицы
    R = zeros(numRx, numRx);
    for sc = 1:size(chanEst, 1)
        H = squeeze(chanEst(sc, :, 1));
        R = R + H * H';
    end
    R = R / size(chanEst, 1) + 1e-6 * eye(numRx); % Регуляризация

    % Собственное разложение
    [V, D] = eig(R);
    [~, idx] = sort(diag(D), 'descend');
    V = V(:, idx);
    Es = V(:, 1:numPaths); % Сигнальное подпространство

    % Подмассивы
    E1 = Es(1:end-1, :);
    E2 = Es(2:end, :);

    % Матрица вращения
    Psi = pinv(E1) * E2;

    % Углы
    phi = angle(eig(Psi));
    lambda = physconst('LightSpeed') / carrierFrequency;
    d = lambda / 2;
    aoa = asin(phi * lambda / (2 * pi * d)) * 180 / pi;

    % Корректировка длины результата
    aoa = aoa(1:numPaths);
    if length(aoa) < numPaths
        aoa = [aoa; zeros(numPaths - length(aoa), 1)];
    end
end
