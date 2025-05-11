function fracDelay = toAEstUpdated(chanEstActiveSC, activeFFTIndices, fftLength, sampleRate)
    chanEstMean = mean(chanEstActiveSC, [2, 3]);
    chanEstFull = zeros(fftLength, 1);
    chanEstFull(activeFFTIndices) = chanEstMean;
    impulseResponse = ifft(ifftshift(chanEstFull));
    absImpulse = abs(impulseResponse);
    noiseThreshold = mean(absImpulse(end-fftLength/4:end)) * 3;
    validPeaks = absImpulse > noiseThreshold;
    firstPeakIdx = find(validPeaks, 1, 'first');
    
    if isempty(firstPeakIdx)
        warning('Первый пик не найден, возвращается fracDelay = 0');
        fracDelay = 0;
    else
        window = max(1, firstPeakIdx-2):min(length(absImpulse), firstPeakIdx+2);
        [~, relIdx] = max(absImpulse(window));
        fracDelay = (window(relIdx) - 1) / sampleRate;
    end
end
