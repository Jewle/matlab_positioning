function positionEst = triangulateFromBearings(apPositionsXY, bearingAnglesDeg)
% triangulateFromBearings Estimate 2D position from multiple AP bearings
%
%   positionEst = triangulateFromBearings(AP, thetaDeg) solves for the 2D
%   position that best fits bearing lines originating at AP coordinates with
%   angles thetaDeg (in degrees, measured from +x axis, counter-clockwise).
%
%   AP is 2-by-N: rows are [x; y], columns are APs.
%   thetaDeg is 1-by-N or N-by-1 of bearings for corresponding APs.
%
%   Uses linear least squares on perpendicular distances to lines.

    validateattributes(apPositionsXY, {'numeric'}, {'2d','nrows',2}, mfilename, 'apPositionsXY');
    validateattributes(bearingAnglesDeg, {'numeric'}, {'vector','real'}, mfilename, 'bearingAnglesDeg');

    numAPs = size(apPositionsXY, 2);
    if numel(bearingAnglesDeg) ~= numAPs
        error('Number of bearings must match number of APs.');
    end

    x = apPositionsXY(1, :).';
    y = apPositionsXY(2, :).';
    thetaRad = deg2rad(bearingAnglesDeg(:));

    % For each line: normal vector n = [sin(theta); -cos(theta)] so that
    % line equation is n' * [X - x_i; Y - y_i] = 0
    n = [sin(thetaRad), -cos(thetaRad)]; % N-by-2

    % Stack as A*[X;Y] = b where b = n .* [x_i, y_i]
    A = n;                     % N-by-2
    b = n(:,1).*x + n(:,2).*y; % N-by-1

    % Solve least squares
    position = A \ b;
    positionEst = position(:); % 2-by-1
end