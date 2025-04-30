function runPositioningSimulation(numIterations, snrRange, numAPs, chanBW, numTx, numRx, numSTS, numLTFRepetitions, delayProfile, carrierFrequency, delayULDL)
   

% 802.11az Waveform Configuration
% Configure waveform generators for each AP and the STA.


%%
% Configure the HE ranging NDP parameters of the STA.

cfgSTABase = heRangingConfig;
cfgSTABase.ChannelBandwidth = chanBW;
cfgSTABase.NumTransmitAntennas = numTx;
cfgSTABase.SecureHELTF = true;
cfgSTABase.User{1}.NumSpaceTimeStreams = numSTS;
cfgSTABase.User{1}.NumHELTFRepetitions = numLTFRepetitions;
%%
% Configure the HE ranging NDP parameters of the APs.

cfgAPBase = cell(1,numAPs);
for iAP = 1:numAPs
    cfgAPBase{iAP} = heRangingConfig;
    cfgAPBase{iAP}.ChannelBandwidth = chanBW;
    cfgAPBase{iAP}.NumTransmitAntennas = numTx;
    cfgAPBase{iAP}.SecureHELTF = true;
    cfgAPBase{iAP}.User{1}.NumSpaceTimeStreams = numSTS;
    cfgAPBase{iAP}.User{1}.NumHELTFRepetitions = numLTFRepetitions;
end

ofdmInfo = wlanHEOFDMInfo('HE-LTF',chanBW,cfgSTABase.GuardInterval);
sampleRate = wlanSampleRate(chanBW);
% Channel Configuration
% Configure the WLAN TGax multipath channel by using the <docid:wlan_ref#mw_43b5900e-69e1-4636-b084-1e72dbd46293
% wlanTGaxChannel> System object™. This System object can generate a channel with
% a dominant direct path, in which the DLOS path is the strongest path, or a channel
% with a non-dominant direct path, for which the DLOS path is present, but not
% the strongest path.




speedOfLight = physconst('lightspeed');

chanBase = wlanTGaxChannel;
chanBase.DelayProfile = delayProfile;
chanBase.NumTransmitAntennas = numTx;
chanBase.NumReceiveAntennas = numRx;
chanBase.SampleRate = sampleRate;
chanBase.CarrierFrequency = carrierFrequency;
chanBase.ChannelBandwidth = chanBW;
chanBase.PathGainsOutputPort = true;
chanBase.NormalizeChannelOutputs = false;
%%
% Get channel filter delay and the number of paths

chBaseInfo = info(chanBase);
chDelay = chBaseInfo.ChannelFilterDelay;
numPaths = size(chBaseInfo.PathDelays,2);
%% Ranging Measurement
% Run a ranging simulation with multiple iterations for all STA-AP pairs. Display
% the ranging mean absolute error (MAE) and the ranging error CDF for each SNR
% point.

 % Time delay between UL NDP ToA and DL NDP ToD, in seconds

numSNR = numel(snrRange);
distEst = zeros(numAPs,numIterations,numSNR);  % Estimated distance
distance = zeros(numAPs,numIterations,numSNR); % True distance
positionSTA = zeros(2,numIterations,numSNR);   % Two-dimensional position of the STA
positionAP= zeros(2,numAPs,numIterations,numSNR); % Two-dimensional positions of the APs
per = zeros(numSNR,1); % Packet error rate (PER)

%parfor isnr = 1:numSNR % Use 'parfor' to speed up the simulation
parfor isnr = 1:numSNR

    % Use a separate channel and waveform configuration object for each parfor stream
    chan = chanBase;
    cfgAP = cfgAPBase;
    cfgSTA = cfgSTABase;

    % Initialize ranging error and total failed packet count variables
    rangingError = 0;
    failedPackets = 0;

    % Set random substream index per iteration to ensure that each
    % iteration uses a repeatable set of random numbers
    stream = RandStream('combRecursive','Seed',123456);
    stream.Substream = isnr;
    RandStream.setGlobalStream(stream);

    % Define the SNR per active subcarrier to account for noise energy in nulls
    snrVal = snrRange(isnr) - 10*log10(ofdmInfo.FFTLength/ofdmInfo.NumTones);

    for iter = 1:numIterations

        % Generate random AP positions
        [positionSTA(:,iter,isnr),positionAP(:,:,iter,isnr),distanceAllAPs] = heGeneratePositions(numAPs);
        distance(:,iter,isnr) = distanceAllAPs;

        % Range-based delay
        delay = distance(:,iter,isnr)/speedOfLight;
        sampleDelay = delay*sampleRate;

        % Loop over the number of APs
        for ap = 1:numAPs

            linkType = ["Uplink","Downlink"];

            % ToD of UL NDP (t1)
            todUL = randsrc(1,1,0:1e-9:1e-6);

            % Loop for both UL and DL transmission
            numLinks = numel(linkType);
            txTime = zeros(1,numLinks);

            for l = 1:numLinks
                if linkType(l) == "Uplink" % STA to AP
                    cfgSTA.UplinkIndication = 1; % For UL
                    % Generate a random secure HE-LTF octets for the exchange
                    numOctets = numSecureHELTFOctets(cfgSTA);
                    cfgSTA.User{1}.SecureHELTFOctets = dec2hex(randsrc(1,2*numOctets(1),(0:15)))';
                    cfg = cfgSTA;
                else % AP to STA
                    % Generate a random secure HE-LTF octets for the exchange
                    numOctets = numSecureHELTFOctets(cfgAP{ap});
                    cfgAP{ap}.User{1}.SecureHELTFOctets = dec2hex(randsrc(1,2*numOctets(1),(0:15)))';
                    cfg = cfgAP{ap}; % For DL
                end

                % Set different channel for UL and DL, assuming that the channel is not reciprocal
                reset(chan)

                % Generate HE Ranging NDP transmission
                tx = heRangingWaveformGenerator(cfg);

                % Introduce time delay (fractional and integer) in the transmit waveform
                txDelay = heDelaySignal(tx,sampleDelay(ap));

                % Pad signal and pass through multipath channel
                txMultipath = chan([txDelay;zeros(50,cfg.NumTransmitAntennas)]);

                % Pass waveform through AWGN channel
                rx = awgn(txMultipath,snrVal);

                % Perform synchronization and channel estimation
                [chanEstActiveSC,integerOffset] = heRangingSynchronize(rx,cfg);

                % Estimate the transmission time between UL and DL
                if ~isempty(chanEstActiveSC) % If packet detection is successful

                    % Estimate fractional delay with MUSIC super-resolution
                    fracDelay = heRangingTOAEstimate(chanEstActiveSC,ofdmInfo.ActiveFFTIndices, ...
                                                     ofdmInfo.FFTLength,sampleRate,numPaths);

                    integerOffset = integerOffset - chDelay; % Account for channel filter delay
                    intDelay = integerOffset/sampleRate; % Estimate integer time delay
                    txTime(l) = intDelay + fracDelay; % Transmission time

                else % If packet detection fails
                    txTime(l) = NaN;
                end

            end

            if ~any(isnan(txTime)) % If packet detection succeeds

                % TOA of UL waveform (t2)
                toaUL = todUL + txTime(1);

                % Time of departure of DL waveform (t3)
                todDL = toaUL + delayULDL;

                % TOA DL waveform (t4)
                toaDL = todDL + txTime(2);

                % Compute the RTT
                rtt = (toaDL-todUL) - (todDL-toaUL);

                % Estimate the distance between the STA and AP
                distEst(ap,iter,isnr) = (rtt/2)*speedOfLight;
                % Accumulate error to MAE
                rangingError = rangingError + abs(distanceAllAPs(ap) - distEst(ap,iter,isnr));

            else % If packet detection fails
                distEst(ap,iter,isnr) = NaN;
                failedPackets = failedPackets + 1;
            end

        end
    end
    
    mae = rangingError/((numAPs*numIterations) - failedPackets); % MAE for successful packets
    per(isnr) = failedPackets/(numAPs*numIterations); % PER
    if(per(isnr) > 0.01) % Use only successful packets for ranging and positioning
        warning('wlan:discardPacket','At SNR = %d dB, %d%% of packets were discarded',snrRange(isnr),100*per(isnr));
    end
    disp(['At SNR = ',num2str(snrRange(isnr)),' dB, ','Ranging mean absolute error = ',num2str(mae), ' meters.'])
end
% Reshape to consider all packets within one SNR point as one dataset
rangingError = reshape(abs(distance - distEst),[numAPs*numIterations,numSNR]);
figure; % Создаем новое окно для первого графика
hePlotErrorCDF(rangingError, snrRange);
xlabel('Absolute ranging error (meters)');
title('Ranging Error CDF');
%% Trilateration


positionSTAEst = zeros(2,numIterations,numSNR);
RMSE = zeros(numIterations,numSNR);
for isnr = 1:numSNR
    for i = 1:numIterations
        positionSTAEst(:,i,isnr) = hePositionEstimate(squeeze(positionAP(:,:,i,isnr)),squeeze(distEst(:,i,isnr)));
    end
    % Find the RMSE for each iteration, then take the mean of all RMSEs
    RMSE = reshape(sqrt(mean(((positionSTAEst-positionSTA).^2),1)),[numIterations numSNR]);
    posEr = mean(RMSE(:,isnr),'all','omitnan');
    disp(['At SNR = ',num2str(snrRange(isnr)),' dB, ', 'Average RMS Positioning error = ', num2str(posEr), ' meters.'])
end
figure('Name', 'Positioning Error CDF');
hePlotErrorCDF(RMSE, snrRange);
xlabel('RMS positioning error (meters)');
title('Positioning Error CDF');
%%
% Plot the location estimate and the trilateration circles of the last iteration.
figure('Name', 'Trilateration Circles');
hePlotTrilaterationCircles(positionAP(:,:,numIterations,numSNR), positionSTAEst(:,numIterations,numSNR), distEst(:,numIterations,numSNR), snrRange(numSNR), numIterations);
end