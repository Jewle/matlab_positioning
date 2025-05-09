function aoa = heRangingAoAEstimate(chanEst, numRx, carrierFrequency, numPaths)
    lambda = physconst('LightSpeed') / carrierFrequency;
    d = lambda / 2;
    theta = -90:0.1:90;
    steeringVectors = exp(-1j * 2 * pi * d / lambda * (0:numRx-1)' * sind(theta));
    R = zeros(numRx, numRx);
    for sc = 1:size(chanEst, 1)
        H = squeeze(chanEst(sc, :, :));
        R = R + H * H';
    end
    R = R / size(chanEst, 1);
    [V, D] = eig(R);
    [~, idx] = sort(diag(D), 'descend');
    V = V(:, idx);
    En = V(:, numPaths+1:end);
    Pmusic = zeros(1, length(theta));
    for i = 1:length(theta)
        a = steeringVectors(:, i);
        Pmusic(i) = 1 / abs(a' * (En * En') * a);
    end
    [~, locs] = findpeaks(Pmusic, 'SortStr', 'descend', 'NPeaks', min(numPaths, length(theta)));
    if isempty(locs)
        aoa = zeros(1, numPaths);
    else
        aoa = theta(locs);
        if length(aoa) < numPaths
            aoa = [aoa, zeros(1, numPaths - length(aoa))];
        end
    end
end
