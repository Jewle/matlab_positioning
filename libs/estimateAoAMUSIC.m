function [anglesDeg, spectrumDeg, scanAnglesDeg] = estimateAoAMUSIC(Rxx, numSources, numSensors, elementSpacingInWavelengths, scanGridDeg)
% estimateAoAMUSIC MUSIC AoA estimation for ULA
%
%   [anglesDeg, spectrumDeg, scanAnglesDeg] = estimateAoAMUSIC(Rxx, K, M, d, scanGridDeg)
%   performs the MUSIC algorithm on the array correlation matrix Rxx using a
%   ULA with M sensors and spacing d (wavelengths). K is the number of impinging
%   sources. scanGridDeg defines scan angles in degrees (from broadside).
%
%   Outputs:
%     - anglesDeg: Estimated AoAs (degrees) length-K, sorted ascending
%     - spectrumDeg: MUSIC pseudospectrum sampled on scanAnglesDeg
%     - scanAnglesDeg: Scan grid used (degrees)

    validateattributes(Rxx, {'numeric'}, {'2d','square','nonempty','finite'}, mfilename, 'Rxx');
    validateattributes(numSources, {'numeric'}, {'scalar','integer','>=',1}, mfilename, 'numSources');
    validateattributes(numSensors, {'numeric'}, {'scalar','integer','>=',2}, mfilename, 'numSensors');
    validateattributes(elementSpacingInWavelengths, {'numeric'}, {'scalar','real','>',0}, mfilename, 'elementSpacingInWavelengths');

    if nargin < 5 || isempty(scanGridDeg)
        scanAnglesDeg = -90:0.1:90;
    else
        scanAnglesDeg = scanGridDeg(:).';
    end

    % Eigen-decomposition
    [eigenVectors, eigenValuesMatrix] = eig((Rxx+Rxx')/2);
    eigenValues = real(diag(eigenValuesMatrix));
    [~, sortIdx] = sort(eigenValues, 'ascend');
    U = eigenVectors(:, sortIdx(1:end-numSources)); % Noise subspace

    % MUSIC pseudospectrum
    A = ulaSteeringVector(numSensors, elementSpacingInWavelengths, scanAnglesDeg); % M-by-L
    denom = sum(abs((U') * A).^2, 1);
    spectrum = 1 ./ max(denom, eps);

    % Normalize for plotting
    spectrum = spectrum / max(spectrum);
    spectrumDeg = spectrum;

    % Select top-K peaks via maxk
    [~, idx] = maxk(spectrumDeg, numSources);
    estAngles = sort(scanAnglesDeg(idx));

    anglesDeg = estAngles(:).';
end