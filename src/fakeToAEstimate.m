function fracDelay = fakeTOAEstimate(chanEstActiveSC, activeFFTIndices, fftLength, sampleRate, prevFracDelay)
%fakeTOAEstimate Generates fake ToA estimates mimicking MUSIC output
%
%   FRACDELAY = fakeTOAEstimate(CHANESTACTIVESC, ACTIVEFFTINDICES, FFTLENGTH, SAMPLERATE, PREVFRACTDELAY)
%   returns a random fractional delay between 26 and 134 nanoseconds
%   with correlated variations to mimic MUSIC behavior.
%
%   CHANESTACTIVESC, ACTIVEFFTINDICES, FFTLENGTH, SAMPLERATE are dummy inputs.
%   PREVFRACTDELAY is the previous fractional delay (optional, for correlation).

% Инициализация предыдущего значения, если не передано
persistent lastDelay;
if isempty(lastDelay)
    lastDelay = 80 * 1e-9; % Начальное значение в середине диапазона (80 нс)
end
if nargin < 5 || isempty(prevFracDelay)
    prevFracDelay = lastDelay;
else
    lastDelay = prevFracDelay; % Обновляем последнее значение
end

% Базовая задержка в наносекундах (26-134 нс)
baseDelayNs = 26 + (134 - 26) * rand(1);

% Корреляция с предыдущим значением (плавное изменение)
correlationFactor = 0.7; % Уровень корреляции (0-1)
variation = (rand(1) - 0.5) * 20; % Случайное отклонение ±10 нс
newDelayNs = correlationFactor * prevFracDelay * 1e9 + (1 - correlationFactor) * baseDelayNs + variation;

% Ограничение диапазона [26, 134] нс
newDelayNs = max(26, min(134, newDelayNs));

% Преобразование в секунды
fracDelay = newDelayNs * 1e-9;

end