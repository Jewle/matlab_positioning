function [positionSTA, positionAP, distance] = generatePositions(numAPs, numIterations, numSNR)
    positionSTA = zeros(2, numIterations, numSNR);
    positionAP = zeros(2, numAPs, numIterations, numSNR);
    distance = zeros(numAPs, numIterations);
    
    for iter = 1:numIterations
        [positionSTA(:, iter, 1), positionAP(:, :, iter, 1), distanceAllAPs] = heGeneratePositions(numAPs);
        distance(:, iter) = distanceAllAPs;
        for isnr = 1:numSNR
            positionSTA(:, iter, isnr) = positionSTA(:, iter, 1);
            positionAP(:, :, iter, isnr) = positionAP(:, :, iter, 1);
        end
    end
end
