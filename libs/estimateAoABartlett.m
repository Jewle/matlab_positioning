function [anglesDeg, spectrumDeg, scanAnglesDeg] = estimateAoABartlett(Rxx, numSensors, elementSpacingInWavelengths, scanGridDeg)
% estimateAoABartlett Bartlett beamformer AoA spectrum for ULA
%
%   [anglesDeg, spectrumDeg, scanAnglesDeg] = estimateAoABartlett(Rxx, M, d, scanGridDeg)
%   computes the Bartlett spatial spectrum for a ULA with M sensors and spacing
%   d (in wavelengths). Returns the DoA estimate at the spectrum maximum.

    validateattributes(Rxx, {'numeric'}, {'2d','square','nonempty','finite'}, mfilename, 'Rxx');
    validateattributes(numSensors, {'numeric'}, {'scalar','integer','>=',2}, mfilename, 'numSensors');
    validateattributes(elementSpacingInWavelengths, {'numeric'}, {'scalar','real','>',0}, mfilename, 'elementSpacingInWavelengths');

    if nargin < 4 || isempty(scanGridDeg)
        scanAnglesDeg = -90:0.2:90;
    else
        scanAnglesDeg = scanGridDeg(:).';
    end

    A = ulaSteeringVector(numSensors, elementSpacingInWavelengths, scanAnglesDeg); % M-by-L
    % Normalize steering vectors
    An = A ./ vecnorm(A);

    spectrum = real(sum(conj(An) .* (Rxx * An), 1));
    spectrum = spectrum / max(spectrum);
    spectrumDeg = spectrum;

    [~, idx] = max(spectrumDeg);
    anglesDeg = scanAnglesDeg(idx);
end