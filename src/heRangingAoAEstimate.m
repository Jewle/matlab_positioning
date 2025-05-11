function aoa = heRangingAoAEstimate(chanEst, numRx, carrierFrequency, numPaths)
    % Оценивает углы прихода (AoA) с использованием MUSIC
    % chanEst - канальные оценки [numSubcarriers, numRx, numSTS]
    % numRx - количество приёмных антенн
    % carrierFrequency - несущая частота (Гц)
    % numPaths - количество путей
    % Возвращает aoa - углы в градусах [1, numPaths]

    % Параметры антенной решётки
    lambda = physconst('LightSpeed') / carrierFrequency;
    d = lambda / 2; % Расстояние между антеннами
    theta = -90:0.05:90; % Более высокое разрешение углов

    % Вектор управления
    steeringVectors = exp(-1j * 2 * pi * d / lambda * (0:numRx-1)' * sind(theta));

    % Формирование корреляционной матрицы
    R = zeros(numRx, numRx);
    for sc = 1:size(chanEst, 1)
        H = squeeze(chanEst(sc, :, :));
        R = R + H * H';
    end
    R = R / size(chanEst, 1);

    % Собственное разложение
    [V, D] = eig(R);
    [~, idx] = sort(diag(D), 'descend');
    V = V(:, idx);
    En = V(:, numPaths+1:end); % Шумовое подпространство

    % Псевдоспектр MUSIC
    Pmusic = zeros(1, length(theta));
    for i = 1:length(theta)
        a = steeringVectors(:, i);
        Pmusic(i) = 1 / abs(a' * (En * En') * a);
    end

    % Поиск пиков с фильтрацией
    [pks, locs] = findpeaks(Pmusic, 'SortStr', 'descend', 'NPeaks', numPaths, 'MinPeakHeight', max(Pmusic)/10);
    if isempty(locs)
        warning('Пики MUSIC не найдены, возвращаются нулевые углы');
        aoa = zeros(1, numPaths);
    else
        aoa = theta(locs);
        if length(aoa) < numPaths
            aoa = [aoa, zeros(1, numPaths - length(aoa))];
        end
    end
end