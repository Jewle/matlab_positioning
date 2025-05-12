function fracDelay = toAEstUpdated(chanEstActiveSC, activeFFTIndices, fftLength, sampleRate)
    % Оценивает дробную задержку времени (ToA) на основе канальных оценок
    % chanEstActiveSC - канальные оценки [numSubcarriers, numRx, numSTS]
    % activeFFTIndices - индексы активных поднесущих
    % fftLength - длина FFT
    % sampleRate - частота дискретизации (Гц)
    % Возвращает fracDelay - дробная задержка в секундах

    % Среднее значение по антеннам и потокам
    chanEstMean = mean(chanEstActiveSC, [2, 3]);
    
    % Восстановление полного спектра
    chanEstFull = zeros(fftLength, 1);
    chanEstFull(activeFFTIndices) = chanEstMean;
    
    % Получение импульсной характеристики
    impulseResponse = ifft(ifftshift(chanEstFull));
    absImpulse = abs(impulseResponse);
    
    % Определение порога шума на основе медианы
    noiseRegion = absImpulse(end-fftLength/4:end); % Последняя четверть как шум
    noiseThreshold = median(noiseRegion) + 3 * mad(noiseRegion, 1); % Медиана + 3 медианных абсолютных отклонения
    
    % Поиск валидных пиков
    validPeaks = absImpulse > noiseThreshold;
    [peakValues, peakIndices] = findpeaks(absImpulse, 'MinPeakHeight', noiseThreshold, 'NPeaks', 3);
    
    if isempty(peakIndices)
        warning('Пики не найдены, возвращается fracDelay = 0');
        fracDelay = 0;
    else
        % Берем первый пик как основной (LOS)
        firstPeakIdx = peakIndices(1);
        
        % Уточнение с помощью параболической интерполяции
        window = max(1, firstPeakIdx-1):min(fftLength, firstPeakIdx+1);
        if length(window) < 3
            window = max(1, firstPeakIdx):min(fftLength, firstPeakIdx+1);
            if length(window) < 2
                window = firstPeakIdx;
            end
        end
        y = absImpulse(window);
        [~, maxIdx] = max(y);
        if length(y) >= 3
            p = polyfit((1:length(y)) - maxIdx, y, 2); % Параболическая интерполяция
            vertex = -p(2) / (2 * p(1)); % Позиция вершины
            fracOffset = vertex - 1; % Сдвиг относительно максимума
        else
            fracOffset = 0; % Без интерполяции, если окно слишком мало
        end
        
        % Итоговая задержка
        fracDelay = (window(1) + fracOffset - 1) / sampleRate;
        
        % Отладка
        disp(['Первый пик: индекс=', num2str(firstPeakIdx), ', значение=', num2str(peakValues(1))]);
        disp(['Дробная задержка: ', num2str(fracDelay), ' с']);
    end
end