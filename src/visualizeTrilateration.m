function visualizeTrilateration(numAPs, numIterations, snrRange, positionAP, positionSTAEst, distEst, methodStr)
    numSNR = numel(snrRange);
    for isnr = 1:numSNR
        validIter = find(sum(~isnan(distEst(:, :, isnr)), 1) >= 3, 1, 'last');
        if ~isempty(validIter)
            hePlotTrilaterationCircles(squeeze(positionAP(:, :, validIter, isnr)), ...
                                       squeeze(positionSTAEst(:, validIter, isnr)), ...
                                       squeeze(distEst(:, validIter, isnr)), ...
                                       snrRange(isnr), validIter);
        else
            disp(['Нет корректных данных для ОСШ ', num2str(snrRange(isnr)), ' дБ, Метод: ', methodStr]);
        end
    end
end
