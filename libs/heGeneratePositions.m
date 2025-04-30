function [positionSTA, positionAP, distanceAllAPs] = heGeneratePositions(numAPs, numSTAs)
% heGeneratePositions Generate random AP and STA positions
%
%   [positionSTA, positionAP, distanceAllAPs] = heGeneratePositions(numAPs, numSTAs)
%   generates random 2D positions for numAPs access points (APs) and numSTAs
%   stations (STAs) and calculates the distances from each STA to each AP.
%
%   Inputs:
%   numAPs  - Number of access points
%   numSTAs - Number of stations
%
%   Outputs:
%   positionSTA   - 2 x numSTAs matrix of STA positions [x; y]
%   positionAP    - 2 x numAPs matrix of AP positions [x; y]
%   distanceAllAPs - numAPs x numSTAs matrix of distances from each STA to each AP

% Generate random positions within a 100x100 meter area
positionSTA = 100 * rand(2, numSTAs); % [x; y] for each STA
positionAP = 100 * rand(2, numAPs);   % [x; y] for each AP

% Calculate distances from each STA to each AP
distanceAllAPs = zeros(numAPs, numSTAs);
for sta = 1:numSTAs
    for ap = 1:numAPs
        distanceAllAPs(ap, sta) = norm(positionSTA(:, sta) - positionAP(:, ap));
    end
end

end