classdef PositioningGUI < matlab.apps.AppBase
    properties (Access = public)
        UIFigure
        NumIterationsLabel
        NumIterationsEditField
        SNRRangeLabel
        SNRRangeEditField
        NumAPsLabel
        NumAPsEditField
        NumSTAsLabel
        NumSTAsEditField
        ChanBWLabel
        ChanBWDropDown
        NumTxLabel
        NumTxEditField
        NumRxLabel
        NumRxEditField
        NumSTSLabel
        NumSTSEditField
        NumLTFRepetitionsLabel
        NumLTFRepetitionsEditField
        DelayProfileLabel
        DelayProfileDropDown
        CarrierFrequencyLabel
        CarrierFrequencyEditField
        DelayULDLLabel
        DelayULDLEditField
        RunSimulationButton
        RunAoAComparisonButton
    end

    methods (Access = private)
        function RunSimulationButtonPushed(app, event)
            addpath('libs');
            numIterations = app.NumIterationsEditField.Value;
            snrRangeStr = app.SNRRangeEditField.Value;
            snrRange = str2num(snrRangeStr);
            numAPs = app.NumAPsEditField.Value;
            numSTAs = app.NumSTAsEditField.Value;
            chanBW = app.ChanBWDropDown.Value;
            numTx = app.NumTxEditField.Value;
            numRx = app.NumRxEditField.Value;
            numSTS = app.NumSTSEditField.Value;
            numLTFRepetitions = app.NumLTFRepetitionsEditField.Value;
            delayProfile = app.DelayProfileDropDown.Value;
            carrierFrequency = app.CarrierFrequencyEditField.Value;
            delayULDL = app.DelayULDLEditField.Value;

            runPositioningSimulation(numIterations, snrRange, numAPs, numSTAs, chanBW, numTx, numRx, numSTS, numLTFRepetitions, delayProfile, carrierFrequency, delayULDL);
            rmpath('libs');
        end

        function RunAoAComparisonButtonPushed(app, event)
            addpath('libs');
            numIterations = app.NumIterationsEditField.Value;
            snrRangeStr = app.SNRRangeEditField.Value;
            snrRange = str2num(snrRangeStr);
            numAPs = app.NumAPsEditField.Value;
            chanBW = app.ChanBWDropDown.Value;
            carrierFrequency = app.CarrierFrequencyEditField.Value;
            % Use NumRx as array size for AoA at each AP
            numSensors = app.NumRxEditField.Value;

            runAoAPositioningComparison(numIterations, snrRange, numAPs, numSensors, chanBW, carrierFrequency);
            rmpath('libs');
        end
    end

    methods (Access = private)
        function createComponents(app)
            app.UIFigure = uifigure;
            app.UIFigure.Position = [100 100 640 520];
            app.UIFigure.Name = 'Positioning Simulation GUI';

            % Num Iterations
            app.NumIterationsLabel = uilabel(app.UIFigure);
            app.NumIterationsLabel.HorizontalAlignment = 'right';
            app.NumIterationsLabel.Position = [50 470 100 22];
            app.NumIterationsLabel.Text = 'Num Iterations';
            app.NumIterationsEditField = uieditfield(app.UIFigure, 'numeric');
            app.NumIterationsEditField.Position = [160 470 100 22];
            app.NumIterationsEditField.Value = 50;

            % SNR Range
            app.SNRRangeLabel = uilabel(app.UIFigure);
            app.SNRRangeLabel.HorizontalAlignment = 'right';
            app.SNRRangeLabel.Position = [50 440 100 22];
            app.SNRRangeLabel.Text = 'SNR Range (dB)';
            app.SNRRangeEditField = uieditfield(app.UIFigure, 'text');
            app.SNRRangeEditField.Position = [160 440 100 22];
            app.SNRRangeEditField.Value = '15:10:35';

            % Num APs
            app.NumAPsLabel = uilabel(app.UIFigure);
            app.NumAPsLabel.HorizontalAlignment = 'right';
            app.NumAPsLabel.Position = [50 410 100 22];
            app.NumAPsLabel.Text = 'Num APs';
            app.NumAPsEditField = uieditfield(app.UIFigure, 'numeric');
            app.NumAPsEditField.Position = [160 410 100 22];
            app.NumAPsEditField.Value = 3;

            % Num STAs
            app.NumSTAsLabel = uilabel(app.UIFigure);
            app.NumSTAsLabel.HorizontalAlignment = 'right';
            app.NumSTAsLabel.Position = [50 380 100 22];
            app.NumSTAsLabel.Text = 'Num STAs';
            app.NumSTAsEditField = uieditfield(app.UIFigure, 'numeric');
            app.NumSTAsEditField.Position = [160 380 100 22];
            app.NumSTAsEditField.Value = 1;

            % Channel Bandwidth
            app.ChanBWLabel = uilabel(app.UIFigure);
            app.ChanBWLabel.HorizontalAlignment = 'right';
            app.ChanBWLabel.Position = [50 350 100 22];
            app.ChanBWLabel.Text = 'Channel Bandwidth';
            app.ChanBWDropDown = uidropdown(app.UIFigure);
            app.ChanBWDropDown.Items = {'CBW20', 'CBW40', 'CBW80', 'CBW160'};
            app.ChanBWDropDown.Position = [160 350 100 22];
            app.ChanBWDropDown.Value = 'CBW80';

            % Num Tx Antennas
            app.NumTxLabel = uilabel(app.UIFigure);
            app.NumTxLabel.HorizontalAlignment = 'right';
            app.NumTxLabel.Position = [50 320 100 22];
            app.NumTxLabel.Text = 'Num Tx Antennas';
            app.NumTxEditField = uieditfield(app.UIFigure, 'numeric');
            app.NumTxEditField.Position = [160 320 100 22];
            app.NumTxEditField.Value = 1;

            % Num Rx Antennas
            app.NumRxLabel = uilabel(app.UIFigure);
            app.NumRxLabel.HorizontalAlignment = 'right';
            app.NumRxLabel.Position = [50 290 100 22];
            app.NumRxLabel.Text = 'Num Rx Antennas';
            app.NumRxEditField = uieditfield(app.UIFigure, 'numeric');
            app.NumRxEditField.Position = [160 290 100 22];
            app.NumRxEditField.Value = 1;

            % Num Space-Time Streams
            app.NumSTSLabel = uilabel(app.UIFigure);
            app.NumSTSLabel.HorizontalAlignment = 'right';
            app.NumSTSLabel.Position = [50 260 100 22];
            app.NumSTSLabel.Text = 'Num Space-Time Streams';
            app.NumSTSEditField = uieditfield(app.UIFigure, 'numeric');
            app.NumSTSEditField.Position = [160 260 100 22];
            app.NumSTSEditField.Value = 1;

            % Num HE-LTF Repetitions
            app.NumLTFRepetitionsLabel = uilabel(app.UIFigure);
            app.NumLTFRepetitionsLabel.HorizontalAlignment = 'right';
            app.NumLTFRepetitionsLabel.Position = [50 230 150 22];
            app.NumLTFRepetitionsLabel.Text = 'Num HE-LTF Repetitions';
            app.NumLTFRepetitionsEditField = uieditfield(app.UIFigure, 'numeric');
            app.NumLTFRepetitionsEditField.Position = [210 230 50 22];
            app.NumLTFRepetitionsEditField.Value = 3;

            % Delay Profile
            app.DelayProfileLabel = uilabel(app.UIFigure);
            app.DelayProfileLabel.HorizontalAlignment = 'right';
            app.DelayProfileLabel.Position = [50 200 100 22];
            app.DelayProfileLabel.Text = 'Delay Profile';
            app.DelayProfileDropDown = uidropdown(app.UIFigure);
            app.DelayProfileDropDown.Items = {'Model-A', 'Model-B', 'Model-C', 'Model-D', 'Model-E'};
            app.DelayProfileDropDown.Position = [160 200 100 22];
            app.DelayProfileDropDown.Value = 'Model-B';

            % Carrier Frequency
            app.CarrierFrequencyLabel = uilabel(app.UIFigure);
            app.CarrierFrequencyLabel.HorizontalAlignment = 'right';
            app.CarrierFrequencyLabel.Position = [50 170 120 22];
            app.CarrierFrequencyLabel.Text = 'Carrier Frequency (Hz)';
            app.CarrierFrequencyEditField = uieditfield(app.UIFigure, 'numeric');
            app.CarrierFrequencyEditField.Position = [180 170 100 22];
            app.CarrierFrequencyEditField.Value = 5e9;

            % Delay UL-DL
            app.DelayULDLLabel = uilabel(app.UIFigure);
            app.DelayULDLLabel.HorizontalAlignment = 'right';
            app.DelayULDLLabel.Position = [50 140 100 22];
            app.DelayULDLLabel.Text = 'Delay UL-DL (s)';
            app.DelayULDLEditField = uieditfield(app.UIFigure, 'numeric');
            app.DelayULDLEditField.Position = [160 140 100 22];
            app.DelayULDLEditField.Value = 16e-6;

            % Run Simulation Button
            app.RunSimulationButton = uibutton(app.UIFigure, 'push');
            app.RunSimulationButton.ButtonPushedFcn = createCallbackFcn(app, @RunSimulationButtonPushed, true);
            app.RunSimulationButton.Position = [120 50 150 30];
            app.RunSimulationButton.Text = 'Запустить симуляцию';

            % Run AoA Comparison Button
            app.RunAoAComparisonButton = uibutton(app.UIFigure, 'push');
            app.RunAoAComparisonButton.ButtonPushedFcn = createCallbackFcn(app, @RunAoAComparisonButtonPushed, true);
            app.RunAoAComparisonButton.Position = [330 50 190 30];
            app.RunAoAComparisonButton.Text = 'Сравнить AoA (Bartlett/MUSIC/ESPRIT)';
        end
    end

    methods (Access = public)
        function app = PositioningGUI
            createComponents(app)
            registerApp(app, app.UIFigure)
            if nargout == 0
                clear app
            end
        end

        function delete(app)
            delete(app.UIFigure)
        end
    end
end