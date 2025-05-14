function [distEst, aoaEst, per] = simulateRanging(numAPs, numIterations, snrRange, cfgSTABase, cfgAPBase, ...
    chanBase, ofdmInfo, sampleRate, chDelay, numPaths,numRx,carrierFrequency, speedOfLight, distance, delayULDL,useMusic, useAoA, methodStr)
    numSNR = numel(snrRange);
    distEst = nan(numAPs, numIterations, numSNR);
    aoaEst = nan(numAPs, numIterations, numSNR, numPaths);
    per = zeros(numSNR, 1);
    
    for isnr = 1:numSNR
        chan = chanBase;
        cfgAP = cfgAPBase;
        cfgSTA = cfgSTABase;

        rangingError = 0;
        failedPackets = 0;

        stream = RandStream('combRecursive', 'Seed', 123456);
        stream.Substream = isnr;
        RandStream.setGlobalStream(stream);

        snrVal = snrRange(isnr) - 10*log10(ofdmInfo.FFTLength/ofdmInfo.NumTones);

        localDistEst = nan(numAPs, numIterations);
        localAoaEst = nan(numAPs, numIterations, numPaths);

        for iter = 1:numIterations
            delay = distance(:, iter)/speedOfLight;
            sampleDelay = delay*sampleRate;

            for ap = 1:numAPs
                linkType = ["Uplink", "Downlink"];
                todUL = randsrc(1, 1, 0:1e-9:1e-6);
                numLinks = numel(linkType);
                txTime = zeros(1, numLinks);

                for l = 1:numLinks
                    if linkType(l) == "Uplink"
                        cfgSTA.UplinkIndication = 1;
                        numOctets = numSecureHELTFOctets(cfgSTA);
                        cfgSTA.User{1}.SecureHELTFOctets = dec2hex(randsrc(1, 2*numOctets(1), (0:15)))';
                        cfg = cfgSTA;
                    else
                        numOctets = numSecureHELTFOctets(cfgAP{ap});
                        cfgAP{ap}.User{1}.SecureHELTFOctets = dec2hex(randsrc(1, 2*numOctets(1), (0:15)))';
                        cfg = cfgAP{ap};
                    end

                    reset(chan);
                    tx = heRangingWaveformGenerator(cfg);
                    txDelay = heDelaySignal(tx,sampleDelay(ap));
                    txMultipath = chan([txDelay; zeros(50, cfg.NumTransmitAntennas)]);
                    rx = awgn(txMultipath, snrVal);
                    [chanEstActiveSC, integerOffset] = heRangingSynchronize(rx, cfg);

                    if ~isempty(chanEstActiveSC)
                        if useMusic
                            fracDelay = heRangingTOAEstimate(chanEstActiveSC, ofdmInfo.ActiveFFTIndices, ...
                                                             ofdmInfo.FFTLength, sampleRate, numPaths);
                        else
                            fracDelay = toAEstUpdated(chanEstActiveSC, ofdmInfo.ActiveFFTIndices, ...
                                                     ofdmInfo.FFTLength, sampleRate);
                        end
                        integerOffset = integerOffset - chDelay;
                        intDelay = integerOffset/sampleRate;
                        txTime(l) = intDelay + fracDelay;
                    else
                        txTime(l) = NaN;
                    end
                end

                if ~any(isnan(txTime))
                    toaUL = todUL + txTime(1);
                    todDL = toaUL + delayULDL;
                    toaDL = todDL + txTime(2);
                    rtt = (toaDL - todUL) - (todDL - toaUL);
                    localDistEst(ap, iter) = (rtt/2)*speedOfLight;
                    rangingError = rangingError + abs(distance(ap, iter) - localDistEst(ap, iter));
                else
                    localDistEst(ap, iter) = NaN;
                    failedPackets = failedPackets + 1;
                end

                if useAoA && ~isempty(chanEstActiveSC)
                    % localAoaEst(ap, iter, :) = heRangingAoAEstimate(chanEstActiveSC, numRx, carrierFrequency, numPaths);
                    localAoaEst(ap, iter, :) = heRangingAoAEstimateESPRIT(chanEstActiveSC, numRx, carrierFrequency, numPaths);
                end
            end
        end

        distEst(:, :, isnr) = localDistEst;
        aoaEst(:, :, isnr, :) = localAoaEst;
        mae = rangingError/((numAPs*numIterations) - failedPackets);
        per(isnr) = failedPackets/(numAPs*numIterations);
        if per(isnr) > 0.01
            warning('wlan:discardPacket', 'At SNR = %d dB, %d%% of packets were discarded', snrRange(isnr), 100*per(isnr));
        end
        disp(['Для ОСШ = ', num2str(snrRange(isnr)), ' дБ, Метод: ', methodStr, ', Ошибка определения дистанции = ', num2str(mae), ' м.'])
        if useAoA
            disp(['Оценённые углы прихода (AoA) для ОСШ = ', num2str(snrRange(isnr)), ' дБ:']);
            disp(squeeze(aoaEst(:, :, isnr, :)));
        end
    end
end
