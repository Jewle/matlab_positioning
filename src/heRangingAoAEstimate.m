function aoa = heRangingAoAEstimate(chanEst, carrierFrequency, numPaths)
% Оценка углов прихода (AoA) через MUSIC
% chanEst: [numSubcarriers × numRx × numSTS], numSTS обычно =1 для AoA
% carrierFrequency: несущая частота (Гц)
% numPaths: число возвращаемых углов

    %=== 1) Параметры антенной решётки ===%
    c = physconst('LightSpeed');          
    lambda = c / carrierFrequency;        % длина волны
    d = lambda/2;                         % шаг между антеннами

    %=== 2) Steering-векторы ===%
    numRx = size(chanEst,2);
    theta = -90:0.1:90;                   % разрешение 0.1° — чуть быстрее, чем 0.05°
    % exp(-j·2π·d/λ·m·sinθ) для m=0..numRx-1
    steeringVectors = exp(-1j*2*pi*(d/lambda)*(0:numRx-1)' * sind(theta));

    %=== 3) Оценка корреляционной матрицы ===%
    R = zeros(numRx);
    Nsub = size(chanEst,1);
    for sc = 1:Nsub
        Hsc = squeeze(chanEst(sc,:,1)).'; % [numRx×1], берем первый поток
        R = R + (Hsc * Hsc');              % аккумулируем энергию
    end
    R = R / Nsub;                        % усреднение

    %=== 4) EVD и отделение шумового подпространства ===%
    [V, D] = eig(R);
    [~, idx] = sort(diag(D), 'descend');
    V = V(:, idx);
    En = V(:, numPaths+1:end);          % шумовое подпространство

    %=== 5) Вычисление MUSIC-спектра ===%
    Pmusic = zeros(1, numel(theta));
    for i = 1:numel(theta)
        a = steeringVectors(:, i);
        denom = real(a' * (En*En') * a);
        Pmusic(i) = 1 / max(eps, denom); % защита от деления на ноль
    end

    %=== 6) Поиск пиков в спектре ===%
    [pks, locs] = findpeaks(Pmusic, ...
        'SortStr','descend', ...
        'NPeaks',numPaths, ...
        'MinPeakHeight', max(Pmusic)/10);
    if isempty(locs)
        warning('MUSIC peaks not found, returning zeros');
        aoa = zeros(1, numPaths);
    else
        aoa = theta(locs);              % углы в градусах
        % если пиков меньше, чем numPaths — дополняем нулями
        aoa = [aoa, zeros(1, max(0, numPaths-numel(aoa)))];
    end
end


