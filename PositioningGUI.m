classdef PositioningGUI < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        UIFigure                        matlab.ui.Figure
        NumIterationsLabel              matlab.ui.control.Label
        NumIterationsEditField          matlab.ui.control.NumericEditField
        SNRRangeLabel                   matlab.ui.control.Label
        SNRRangeEditField               matlab.ui.control.EditField
        NumAPsLabel                     matlab.ui.control.Label
        NumAPsEditField                 matlab.ui.control.NumericEditField
        ChanBWLabel                     matlab.ui.control.Label
        ChanBWDropDown                  matlab.ui.control.DropDown
        NumTxLabel                      matlab.ui.control.Label
        NumTxEditField                  matlab.ui.control.NumericEditField
        NumRxLabel                      matlab.ui.control.Label
        NumRxEditField                  matlab.ui.control.NumericEditField
        NumSTSLabel                     matlab.ui.control.Label
        NumSTSEditField                 matlab.ui.control.NumericEditField
        NumLTFRepetitionsLabel          matlab.ui.control.Label
        NumLTFRepetitionsEditField      matlab.ui.control.NumericEditField
        DelayProfileLabel               matlab.ui.control.Label
        DelayProfileDropDown            matlab.ui.control.DropDown
        CarrierFrequencyLabel           matlab.ui.control.Label
        CarrierFrequencyEditField       matlab.ui.control.NumericEditField
        DelayULDLLabel                  matlab.ui.control.Label
        DelayULDLEditField              matlab.ui.control.NumericEditField
        RunSimulationButton             matlab.ui.control.Button
    end

    methods (Access = private)

        % Button pushed function: RunSimulationButton
        function RunSimulationButtonPushed(app, event)
            % Считываем значения из полей ввода
            addpath('libs');
            numIterations = app.NumIterationsEditField.Value;
            snrRangeStr = app.SNRRangeEditField.Value;
            snrRange = str2num(snrRangeStr); % Преобразуем строку в массив чисел
            numAPs = app.NumAPsEditField.Value;
            chanBW = app.ChanBWDropDown.Value;
            numTx = app.NumTxEditField.Value;
            numRx = app.NumRxEditField.Value;
            numSTS = app.NumSTSEditField.Value;
            numLTFRepetitions = app.NumLTFRepetitionsEditField.Value;
            delayProfile = app.DelayProfileDropDown.Value;
            carrierFrequency = app.CarrierFrequencyEditField.Value;
            delayULDL = app.DelayULDLEditField.Value;

            % Вызываем основную функцию симуляции с параметрами
            runPositioningSimulation(numIterations, snrRange, numAPs, chanBW, numTx, numRx, numSTS, numLTFRepetitions, delayProfile, carrierFrequency, delayULDL);
            rmpath('libs');
        end
    end

    % App initialization and construction
    methods (Access = private)

        % Create UIFigure and components
        function createComponents(app)

            % Create UIFigure
            app.UIFigure = uifigure;
            app.UIFigure.Position = [100 100 640 480];
            app.UIFigure.Name = 'Positioning Simulation GUI';

            % Create NumIterationsLabel
            app.NumIterationsLabel = uilabel(app.UIFigure);
            app.NumIterationsLabel.HorizontalAlignment = 'right';
            app.NumIterationsLabel.Position = [50 430 100 22];
            app.NumIterationsLabel.Text = 'Num Iterations';

            % Create NumIterationsEditField
            app.NumIterationsEditField = uieditfield(app.UIFigure, 'numeric');
            app.NumIterationsEditField.Position = [160 430 100 22];
            app.NumIterationsEditField.Value = 5;

            % Create SNRRangeLabel
            app.SNRRangeLabel = uilabel(app.UIFigure);
            app.SNRRangeLabel.HorizontalAlignment = 'right';
            app.SNRRangeLabel.Position = [50 400 100 22];
            app.SNRRangeLabel.Text = 'SNR Range (dB)';

            % Create SNRRangeEditField
            app.SNRRangeEditField = uieditfield(app.UIFigure, 'text');
            app.SNRRangeEditField.Position = [160 400 100 22];
            app.SNRRangeEditField.Value = '8:4:16';

            % Create NumAPsLabel
            app.NumAPsLabel = uilabel(app.UIFigure);
            app.NumAPsLabel.HorizontalAlignment = 'right';
            app.NumAPsLabel.Position = [50 370 100 22];
            app.NumAPsLabel.Text = 'Num APs';

            % Create NumAPsEditField
            app.NumAPsEditField = uieditfield(app.UIFigure, 'numeric');
            app.NumAPsEditField.Position = [160 370 100 22];
            app.NumAPsEditField.Value = 3;

            % Create ChanBWLabel
            app.ChanBWLabel = uilabel(app.UIFigure);
            app.ChanBWLabel.HorizontalAlignment = 'right';
            app.ChanBWLabel.Position = [50 340 100 22];
            app.ChanBWLabel.Text = 'Channel Bandwidth';

            % Create ChanBWDropDown
            app.ChanBWDropDown = uidropdown(app.UIFigure);
            app.ChanBWDropDown.Items = {'CBW20', 'CBW40', 'CBW80', 'CBW160'};
            app.ChanBWDropDown.Position = [160 340 100 22];
            app.ChanBWDropDown.Value = 'CBW80';

            % Create NumTxLabel
            app.NumTxLabel = uilabel(app.UIFigure);
            app.NumTxLabel.HorizontalAlignment = 'right';
            app.NumTxLabel.Position = [50 310 100 22];
            app.NumTxLabel.Text = 'Num Tx Antennas';

            % Create NumTxEditField
            app.NumTxEditField = uieditfield(app.UIFigure, 'numeric');
            app.NumTxEditField.Position = [160 310 100 22];
            app.NumTxEditField.Value = 2;

            % Create NumRxLabel
            app.NumRxLabel = uilabel(app.UIFigure);
            app.NumRxLabel.HorizontalAlignment = 'right';
            app.NumRxLabel.Position = [50 280 100 22];
            app.NumRxLabel.Text = 'Num Rx Antennas';

            % Create NumRxEditField
            app.NumRxEditField = uieditfield(app.UIFigure, 'numeric');
            app.NumRxEditField.Position = [160 280 100 22];
            app.NumRxEditField.Value = 2;

            % Create NumSTSLabel
            app.NumSTSLabel = uilabel(app.UIFigure);
            app.NumSTSLabel.HorizontalAlignment = 'right';
            app.NumSTSLabel.Position = [50 250 100 22];
            app.NumSTSLabel.Text = 'Num Space-Time Streams';

            % Create NumSTSEditField
            app.NumSTSEditField = uieditfield(app.UIFigure, 'numeric');
            app.NumSTSEditField.Position = [160 250 100 22];
            app.NumSTSEditField.Value = 2;

            % Create NumLTFRepetitionsLabel
            app.NumLTFRepetitionsLabel = uilabel(app.UIFigure);
            app.NumLTFRepetitionsLabel.HorizontalAlignment = 'right';
            app.NumLTFRepetitionsLabel.Position = [50 220 150 22];
            app.NumLTFRepetitionsLabel.Text = 'Num HE-LTF Repetitions';

            % Create NumLTFRepetitionsEditField
            app.NumLTFRepetitionsEditField = uieditfield(app.UIFigure, 'numeric');
            app.NumLTFRepetitionsEditField.Position = [210 220 50 22];
            app.NumLTFRepetitionsEditField.Value = 3;

            % Create DelayProfileLabel
            app.DelayProfileLabel = uilabel(app.UIFigure);
            app.DelayProfileLabel.HorizontalAlignment = 'right';
            app.DelayProfileLabel.Position = [50 190 100 22];
            app.DelayProfileLabel.Text = 'Delay Profile';

            % Create DelayProfileDropDown
            app.DelayProfileDropDown = uidropdown(app.UIFigure);
            app.DelayProfileDropDown.Items = {'Model-A', 'Model-B', 'Model-C', 'Model-D', 'Model-E'};
            app.DelayProfileDropDown.Position = [160 190 100 22];
            app.DelayProfileDropDown.Value = 'Model-E';

            % Create CarrierFrequencyLabel
            app.CarrierFrequencyLabel = uilabel(app.UIFigure);
            app.CarrierFrequencyLabel.HorizontalAlignment = 'right';
            app.CarrierFrequencyLabel.Position = [50 160 120 22];
            app.CarrierFrequencyLabel.Text = 'Carrier Frequency (Hz)';

            % Create CarrierFrequencyEditField
            app.CarrierFrequencyEditField = uieditfield(app.UIFigure, 'numeric');
            app.CarrierFrequencyEditField.Position = [180 160 100 22];
            app.CarrierFrequencyEditField.Value = 2.4e9;

            % Create DelayULDLLabel
            app.DelayULDLLabel = uilabel(app.UIFigure);
            app.DelayULDLLabel.HorizontalAlignment = 'right';
            app.DelayULDLLabel.Position = [50 130 100 22];
            app.DelayULDLLabel.Text = 'Delay UL-DL (s)';

            % Create DelayULDLEditField
            app.DelayULDLEditField = uieditfield(app.UIFigure, 'numeric');
            app.DelayULDLEditField.Position = [160 130 100 22];
            app.DelayULDLEditField.Value = 16e-6;

            % Create RunSimulationButton
            app.RunSimulationButton = uibutton(app.UIFigure, 'push');
            app.RunSimulationButton.ButtonPushedFcn = createCallbackFcn(app, @RunSimulationButtonPushed, true);
            app.RunSimulationButton.Position = [280 50 150 30];
            app.RunSimulationButton.Text = 'Запустить симуляцию';
        end
    end

    methods (Access = public)

        % Construct app
        function app = PositioningGUI
            % Create and configure components
            createComponents(app)

            % Register the app with App Designer
            registerApp(app, app.UIFigure)

            if nargout == 0
                clear app
            end
        end

        % Code that executes before app deletion
        function delete(app)
            % Delete UIFigure when app is deleted
            delete(app.UIFigure)
        end
    end
end