function anglesDeg = estimateAoAESPRIT(Rxx, numSources, numSensors, elementSpacingInWavelengths)
% estimateAoAESPRIT ESPRIT AoA estimation for ULA
%
%   anglesDeg = estimateAoAESPRIT(Rxx, K, M, d) computes K AoAs (degrees)
%   for a ULA with M sensors and spacing d (in wavelengths), given the
%   array correlation matrix Rxx. Uses TLS-ESPRIT with forward-backward
%   averaging.

    validateattributes(Rxx, {'numeric'}, {'2d','square','nonempty','finite'}, mfilename, 'Rxx');
    validateattributes(numSources, {'numeric'}, {'scalar','integer','>=',1}, mfilename, 'numSources');
    validateattributes(numSensors, {'numeric'}, {'scalar','integer','>=',2}, mfilename, 'numSensors');
    validateattributes(elementSpacingInWavelengths, {'numeric'}, {'scalar','real','>',0}, mfilename, 'elementSpacingInWavelengths');

    % Ensure Hermitian
    R = (Rxx + Rxx')/2;

    % Forward-backward averaging to improve performance with coherent sources
    J = flipud(eye(numSensors));
    Rfb = (R + J*conj(R)*J)/2;

    % Signal subspace from eigen-decomposition
    [E, D] = eig(Rfb);
    [~, order] = sort(real(diag(D)), 'descend');
    Es = E(:, order(1:numSources));

    % Selection matrices for shift invariance
    J1 = [eye(numSensors-1), zeros(numSensors-1, 1)];
    J2 = [zeros(numSensors-1, 1), eye(numSensors-1)];

    % TLS-ESPRIT: solve J1*Es*Psi ≈ J2*Es
    % Use least squares via pseudoinverse
    Psi = pinv(J1*Es) * (J2*Es);

    % Eigenvalues give spatial frequencies
    lambda = eig(Psi);
    spatialFrequencies = angle(lambda); % in radians

    % AoA from sin(theta) = spatialFrequency/(2*pi*d)
    sinTheta = spatialFrequencies ./ (2*pi*elementSpacingInWavelengths);
    sinTheta = max(min(real(sinTheta), 1), -1);
    thetaRad = asin(sinTheta);

    anglesDeg = sort(rad2deg(thetaRad(:).'));
end