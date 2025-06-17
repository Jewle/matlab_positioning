function fracDelay = heRangingTOAEstimatePhaseBased(chanEstActiveSC, activeFFTIndices, fftLength, sampleRate)
%heRangingTOAEstimatePhaseBased Estimates ToA using phase-based approach
%
%   FRACDELAY = heRangingTOAEstimatePhaseBased(CHANESTACTIVESC, ACTIVEFFTINDICES, FFTLENGTH, SAMPLERATE)
%   estimates the time of arrival (ToA) using the phase slope of the channel estimate.
%
%   CHANESTACTIVESC is the channel estimate for active subcarriers (Nst-by-Nsts-by-Nr).
%   ACTIVEFFTINDICES are the indices of active subcarriers in the FFT.
%   FFTLENGTH is the length of the FFT.
%   SAMPLERATE is the sampling rate in Hz.
%
%   FRACDELAY is the fractional delay in seconds.

% Усреднение канальных оценок по приёмным антеннам и потокам
chanEstMean = mean(chanEstActiveSC, [2, 3]); % Размер [Nst, 1]

% Частоты поднесущих
subcarrierSpacing = sampleRate / fftLength; % Частотный интервал поднесущих
subcarrierIndices = activeFFTIndices - (fftLength/2 + 1); % Центрирование индексов относительно нулевой частоты
frequencies = subcarrierIndices * subcarrierSpacing; % Частоты поднесущих в Гц

% Вычисление фаз
phases = unwrap(angle(chanEstMean)); % Разворачивание фаз для устранения скачков на ±2π

% Линейная регрессия для оценки наклона фазы
p = polyfit(frequencies, phases, 1); % p(1) — наклон, p(2) — смещение
slope = p(1); % Наклон фазы (рад/Гц)

% Оценка задержки: τ = -slope / (2π)
fracDelay = -slope / (2 * pi);

% Проверка реалистичности задержки
if abs(fracDelay) > 1/sampleRate
    warning('Оценка задержки превышает один отсчет, возвращается fracDelay = 0');
    fracDelay = 0;
end

end