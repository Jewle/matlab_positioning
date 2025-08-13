function a = ulaSteeringVector(numSensors, elementSpacingInWavelengths, anglesDeg)
% ulaSteeringVector Computes ULA steering vectors for given broadside angles
%
%   a = ulaSteeringVector(M, d, thetaDeg) returns the M-by-L array manifold
%   where M is the number of sensors, d is the inter-element spacing in
%   wavelengths (e.g., 0.5 for half-wavelength spacing), and thetaDeg is a
%   vector of L angles in degrees measured from the array broadside
%   (broadside=0 deg, endfire=±90 deg).
%
%   Angles outside [-90, 90] are wrapped into that range.
%
%   The steering vector model is:
%       a_m(theta) = exp(1j*2*pi*d*(m-1)*sin(theta)),  m = 1..M
%
%   Inputs:
%     - numSensors: Number of array elements (M)
%     - elementSpacingInWavelengths: Inter-element spacing in wavelengths (d)
%     - anglesDeg: Vector of angles in degrees from broadside (thetaDeg)
%
%   Output:
%     - a: M-by-L complex array of steering vectors
%
%   This function assumes a uniform linear array (ULA) aligned along the x-axis.

    validateattributes(numSensors, {'numeric'}, {'scalar','integer','>=',2}, mfilename, 'numSensors');
    validateattributes(elementSpacingInWavelengths, {'numeric'}, {'scalar','real','>',0}, mfilename, 'elementSpacingInWavelengths');
    validateattributes(anglesDeg, {'numeric'}, {'vector','real'}, mfilename, 'anglesDeg');

    % Wrap to [-90, 90]
    anglesWrapped = mod(anglesDeg + 90, 180) - 90;
    anglesRad = deg2rad(anglesWrapped(:).'); % 1-by-L

    elementIndices = (0:numSensors-1).'; % M-by-1
    phaseShifts = 2*pi*elementSpacingInWavelengths * elementIndices * sin(anglesRad); % M-by-L
    a = exp(1j * phaseShifts);
end