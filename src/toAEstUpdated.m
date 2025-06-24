function fracDelay = toAEstUpdated(chanEstActiveSC, activeFFTIndices, fftLength, sampleRate)
%toAEstUpdated Estimates ToA with improved correlation-based approach
%
%   FRACDELAY = toAEstUpdated(CHANESTACTIVESC, ACTIVEFFTINDICES, FFTLENGTH, SAMPLERATE)
%   estimates the time of arrival (ToA) using an improved correlation method.

chanEstMean = mean(chanEstActiveSC, [2, 3]);
chanEstFull = zeros(fftLength, 1);
chanEstFull(activeFFTIndices) = chanEstMean;
impulseResponse = ifft(ifftshift(chanEstFull));
absImpulse = abs(impulseResponse);
noiseThreshold = mean(absImpulse(end-fftLength/4:end)) * 1.5; % Снижен порог для чувствительности
validPeaks = absImpulse > noiseThreshold;
firstPeakIdx = find(validPeaks, 1, 'first');

if isempty(firstPeakIdx)
    warning('Первый пик не найден, возвращается fracDelay = 0');
    fracDelay = 0;
else
    window = max(1, firstPeakIdx-2):min(length(absImpulse), firstPeakIdx+2);
    [maxVal, relIdx] = max(absImpulse(window));
    if length(window) >= 3
        x = (-2:0) + relIdx; % Относительные индексы в окне
        y = absImpulse(window(max(1, relIdx-1):min(length(window), relIdx+1)));
        if length(y) == 3
            p = polyfit(x, y, 2); % Параболическая интерполяция
            peakOffset = -p(2)/(2*p(1)); % Вершина параболы
            fracDelay = (window(relIdx) - 1 + peakOffset) / sampleRate;
        else
            fracDelay = (window(relIdx) - 1) / sampleRate;
        end
    else
        fracDelay = (window(relIdx) - 1) / sampleRate;
    end
end
end