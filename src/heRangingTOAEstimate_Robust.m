% src/heRangingTOAEstimate_Robust.m (с отладочной визуализацией)

function fracDelay = heRangingTOAEstimate_Robust(chanEstActiveSC, activeFFTIndices, fftLength, sampleRate, debug_plot)
    % Улучшенная версия с отладочной визуализацией.
    % debug_plot - необязательный флаг для включения графика.
    if nargin < 5
        debug_plot = false;
    end

    % --- Блок вычислений (остается без изменений) ---
    chanEstMean = mean(chanEstActiveSC, [2, 3]);
    if max(abs(chanEstMean)) < 1e-10
        warning('chanEstMean слишком мал. Возвращаем 0.');
        fracDelay = 0;
        return;
    end
    chanEstFull = zeros(fftLength, 1);
    chanEstFull(activeFFTIndices) = chanEstMean;
    impulseResponse = ifft(chanEstFull);
    cirPower = abs(impulseResponse).^2;
    noiseRegion = cirPower(round(fftLength/2):end);
    noiseMean = mean(noiseRegion);
    noiseStd = std(noiseRegion);
    noiseThreshold = noiseMean + 3 * noiseStd;
    aboveThreshold = cirPower > noiseThreshold;
    if license('test', 'image_toolbox') && ~isempty(ver('images'))
        islands = bwconncomp(aboveThreshold);
        if islands.NumObjects == 0
            warning('Не найдено пиков выше порога. Возвращаем 0.');
            fracDelay = 0;
            if debug_plot, plot_debug_info(cirPower, noiseThreshold, -1); end
            return;
        end
        firstIslandIndices = islands.PixelIdxList{1};
    else
        firstIslandStart = find(aboveThreshold, 1, 'first');
        if isempty(firstIslandStart)
            warning('Не найдено пиков выше порога. Возвращаем 0.');
            fracDelay = 0;
            if debug_plot, plot_debug_info(cirPower, noiseThreshold, -1); end
            return;
        end
        firstIslandEnd = find(~aboveThreshold(firstIslandStart:end), 1, 'first');
        if isempty(firstIslandEnd)
            firstIslandEnd = fftLength;
        else
            firstIslandEnd = firstIslandStart + firstIslandEnd - 2;
        end
        firstIslandIndices = firstIslandStart:firstIslandEnd;
    end
    [~, relativePeakIdx] = max(cirPower(firstIslandIndices));
    peakIdx = firstIslandIndices(relativePeakIdx);
    
    if peakIdx > 1 && peakIdx < fftLength
        y = cirPower(peakIdx-1 : peakIdx+1);
        delta = 0.5 * (y(1) - y(3)) / (y(1) - 2*y(2) + y(3));
        if isnan(delta) || isinf(delta) || abs(delta) > 1, delta = 0; end
        fracDelaySamples = peakIdx - 1 + delta;
    else
        fracDelaySamples = peakIdx - 1;
    end
    fracDelay = fracDelaySamples / sampleRate;

    % --- Блок отладочной визуализации ---
    if debug_plot
        plot_debug_info(cirPower, noiseThreshold, peakIdx);
    end
end

function plot_debug_info(cirPower, noiseThreshold, peakIdx)
    figure('Name', 'Отладка оценки ToA');
    time_axis_ns = (0:length(cirPower)-1) * (1/40e6) * 1e9; % Пример для 40MHz
    plot(time_axis_ns, 10*log10(cirPower), 'b-', 'DisplayName', 'Мощность CIR');
    hold on;
    line([time_axis_ns(1), time_axis_ns(end)], [10*log10(noiseThreshold), 10*log10(noiseThreshold)], ...
        'Color', 'r', 'LineStyle', '--', 'DisplayName', 'Порог шума');
    if peakIdx > 0
        peak_time_ns = (peakIdx-1) * (1/20e6) * 1e9;
        plot(peak_time_ns, 10*log10(cirPower(peakIdx)), 'go', 'MarkerSize', 10, 'LineWidth', 2, 'DisplayName', 'Найденный пик');
    end
    xlabel('Задержка (нс)');
    ylabel('Мощность (дБ)');
    title('Импульсная характеристика канала (CIR)');
    legend;
    grid on;
    drawnow; % Показать график немедленно
end
