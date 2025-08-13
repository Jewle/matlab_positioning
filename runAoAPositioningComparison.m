function runAoAPositioningComparison(numIterations, snrRange, numAPs, numSensors, chanBW, carrierFrequency)
% runAoAPositioningComparison Compare AoA-based positioning methods
%
%   This script simulates a 2D scenario with N APs, each having a ULA with
%   numSensors elements and half-wavelength spacing. A single STA is placed
%   randomly. For each iteration and SNR, it:
%     - Generates signals for a narrowband snapshot per AP (derived from HE-LTF CFR)
%     - Forms an array correlation matrix per AP
%     - Estimates AoA at each AP using Bartlett, MUSIC, ESPRIT
%     - Triangulates STA position from AP bearings
%     - Accumulates positioning error statistics
%
%   Inputs:
%     - numIterations: Monte Carlo trials (e.g., 100)
%     - snrRange: vector of SNRs in dB (e.g., 0:5:30)
%     - numAPs: number of access points (>=2, ideally >=3)
%     - numSensors: ULA elements per AP (>=2)
%     - chanBW: 'CBW20'|'CBW40'|'CBW80'|'CBW160' (for compatibility)
%     - carrierFrequency: in Hz (affects wavelength)
%
%   Note: This function uses synthetic narrowband array snapshots based on
%   true bearings; integrating with the existing he* pipeline to get CFR per
%   AP/Rx for array processing is possible but not required to compare AoA
%   estimators.

    addpath('libs');

    validateattributes(numIterations, {'numeric'}, {'scalar','integer','>=',1}, mfilename, 'numIterations');
    validateattributes(numAPs, {'numeric'}, {'scalar','integer','>=',2}, mfilename, 'numAPs');
    validateattributes(numSensors, {'numeric'}, {'scalar','integer','>=',2}, mfilename, 'numSensors');
    validateattributes(carrierFrequency, {'numeric'}, {'scalar','real','>',0}, mfilename, 'carrierFrequency');

    lambda = physconst('LightSpeed')/carrierFrequency;
    dOverLambda = 0.5; % Half-wavelength spacing

    numSNR = numel(snrRange);
    posErrorBartlett = nan(numIterations, numSNR);
    posErrorMUSIC = nan(numIterations, numSNR);
    posErrorESPRIT = nan(numIterations, numSNR);

    % Geometry: random APs and STA per iteration
    for isnr = 1:numSNR
        snrDb = snrRange(isnr);
        for iter = 1:numIterations
            % Positions
            [positionSTA, positionAP, ~] = heGeneratePositions(numAPs, 1);

            % True bearings from each AP to STA (global reference: +x axis)
            dx = positionSTA(1,1) - positionAP(1,:);
            dy = positionSTA(2,1) - positionAP(2,:);
            trueAzimuthDeg = rad2deg(atan2(dy, dx)); % 1-by-N, from +x axis CCW
            % Convert to ULA broadside-referenced angles (ULA along x-axis => broadside is +y)
            trueBroadsideDeg = 90 - trueAzimuthDeg; % 0 deg = broadside, ±90 = endfire

            % For each AP, synthesize a single-snapshot narrowband array signal
            % Snapshot model: x = a(theta)*s + n, with s~CN(0,1), n~CN(0, sigma^2 I)
            bearingEstBart_broad = nan(1, numAPs);
            bearingEstMUSIC_broad = nan(1, numAPs);
            bearingEstESPRIT_broad = nan(1, numAPs);

            noiseVarLinear = 10^(-snrDb/10); % unit signal power assumption

            for ap = 1:numAPs
                aTheta = ulaSteeringVector(numSensors, dOverLambda, trueBroadsideDeg(ap)); % M-by-1
                s = (randn(1,1)+1j*randn(1,1))/sqrt(2); % CN(0,1)
                x = aTheta * s;
                n = sqrt(noiseVarLinear/2) * (randn(numSensors,1) + 1j*randn(numSensors,1));
                snapshot = x + n; % M-by-1

                % Correlation matrix estimate
                Rxx = snapshot * snapshot';

                % Bartlett
                [angB, ~, ~] = estimateAoABartlett(Rxx, numSensors, dOverLambda, -90:0.5:90);
                bearingEstBart_broad(ap) = angB;

                % MUSIC (single source)
                [angM, ~, ~] = estimateAoAMUSIC(Rxx, 1, numSensors, dOverLambda, -90:0.2:90);
                bearingEstMUSIC_broad(ap) = angM(1);

                % ESPRIT (single source)
                angE = estimateAoAESPRIT(Rxx, 1, numSensors, dOverLambda);
                bearingEstESPRIT_broad(ap) = angE(1);
            end

            % Convert estimated broadside angles back to global azimuth
            bearingEstBart = mod(90 - bearingEstBart_broad + 180, 360) - 180;
            bearingEstMUSIC = mod(90 - bearingEstMUSIC_broad + 180, 360) - 180;
            bearingEstESPRIT = mod(90 - bearingEstESPRIT_broad + 180, 360) - 180;

            % Triangulate
            posBart = triangulateFromBearings(positionAP, bearingEstBart);
            posMUSIC = triangulateFromBearings(positionAP, bearingEstMUSIC);
            posESPRIT = triangulateFromBearings(positionAP, bearingEstESPRIT);

            % Positioning errors
            posErrorBartlett(iter, isnr) = norm(posBart - positionSTA(:,1));
            posErrorMUSIC(iter, isnr) = norm(posMUSIC - positionSTA(:,1));
            posErrorESPRIT(iter, isnr) = norm(posESPRIT - positionSTA(:,1));
        end
    end

    % Plot CDFs per SNR for each method
    for isnr = 1:numSNR
        figure('Name', sprintf('Position Error CDF at SNR %g dB', snrRange(isnr)));
        hold on;
        [xB, FB] = stairs(sort(posErrorBartlett(:,isnr)), (1:numIterations)/numIterations);
        plot(xB, FB, 'DisplayName', 'Bartlett');
        [xM, FM] = stairs(sort(posErrorMUSIC(:,isnr)), (1:numIterations)/numIterations);
        plot(xM, FM, 'DisplayName', 'MUSIC');
        [xE, FE] = stairs(sort(posErrorESPRIT(:,isnr)), (1:numIterations)/numIterations);
        plot(xE, FE, 'DisplayName', 'ESPRIT');
        xlabel('Position error (m)'); ylabel('CDF'); grid on; legend('show');
        title(sprintf('AoA Positioning Error CDF at %g dB', snrRange(isnr)));
        hold off;
    end

    % Print average errors
    for isnr = 1:numSNR
        fprintf('SNR %g dB: mean error (m): Bartlett=%.3f, MUSIC=%.3f, ESPRIT=%.3f\n', ...
            snrRange(isnr), mean(posErrorBartlett(:,isnr)), mean(posErrorMUSIC(:,isnr)), mean(posErrorESPRIT(:,isnr)));
    end

    rmpath('libs');
end