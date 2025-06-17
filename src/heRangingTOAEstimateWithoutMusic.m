function fracDelay = heRangingTOAEstimateWithoutMusic(chanEstActiveSC, activeFFTIndices, fftLength, sampleRate)
%heRangingTOAEstimateWithoutMusic Estimates ToA without MUSIC using correlation
%
%   FRACDELAY = heRangingTOAEstimateWithoutMusic(CHANESTACTIVESC, ACTIVEFFTINDICES, FFTLENGTH, SAMPLERATE)
%   estimates the time of arrival (ToA) using a correlation-based approach
%   instead of MUSIC, with sub-sample resolution.
%
%   CHANESTACTIVESC is the channel estimate for active subcarriers.
%   ACTIVEFFTINDICES are the indices of active subcarriers in the FFT.
%   FFTLENGTH is the length of the FFT.
%   SAMPLERATE is the sampling rate in Hz.
%
%   FRACDELAY is the fractional delay in seconds.

% Усреднение канальных оценок по приёмным антеннам и потокам
chanEstMean = mean(chanEstActiveSC, [2, 3]);

% Формирование полного спектра
chanEstFull = zeros(fftLength, 1);
chanEstFull(activeFFTIndices) = chanEstMean;

% Генерация опорного сигнала HE-LTF (предполагаем, что это известная последовательность)
% Для простоты используем единичную амплитуду с фазой канала
refSignal = ifft(ifftshift(chanEstFull));

% Нормализация опорного сигнала
refSignal = refSignal / norm(refSignal);

% Вычисление импульсной характеристики через IFFT
impulseResponse = ifft(ifftshift(chanEstFull));

% Вычисление корреляции с опорным сигналом
corr = xcorr(abs(impulseResponse), abs(refSignal));
corr = corr(length(impulseResponse):end); % Положительная часть корреляции

% Пороговая обработка
noiseFloor = mean(corr(end-fftLength/4:end)) * 3; % Порог = 3 * средний уровень шума
validPeaks = corr > noiseFloor;

% Поиск первого пика
firstPeakIdx = find(validPeaks, 1, 'first');

if isempty(firstPeakIdx)
    warning('Первый пик не найден, возвращается fracDelay = 0');
    fracDelay = 0;
    return;
end

% Субдискретизация для повышения разрешения
window = max(1, firstPeakIdx-2):min(length(corr), firstPeakIdx+2);
corrWindow = corr(window);

% Интерполяция параболой для субдискретного разрешения
if length(corrWindow) >= 3
    [maxVal, relIdx] = max(corrWindow);
    x = (relIdx-2:relIdx);
    y = corrWindow(max(1, relIdx-1):min(length(corrWindow), relIdx+1));
    if length(y) == 3
        p = polyfit(x, y, 2); % Параболическая интерполяция
        peakOffset = -p(2)/(2*p(1)); % Координата вершины параболы
        fracDelay = (window(relIdx) - 1 + peakOffset) / sampleRate;
    else
        fracDelay = (window(relIdx) - 1) / sampleRate;
    end
else
    fracDelay = (window(1) - 1) / sampleRate;
end

end