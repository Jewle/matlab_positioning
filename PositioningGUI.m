classdef PositioningGUI < matlab.apps.AppBase
    properties (Access = public)
        UIFigure
        NumIterationsLabel
        NumIterationsEditField
        SNRRangeLabel
        SNRRangeEditField
        NumAPsLabel
        NumAPsEditField
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
        UseMusicCheckBox % Новый чекбокс
        RunSimulationButton
    end

    methods (Access = private)
        function startupFcn(app)
            app.ChanBWDropDown.Items = {'CBW20', 'CBW40', 'CBW80', 'CBW160'};
            app.DelayProfileDropDown.Items = {'Model-A', 'Model-B', 'Model-C', 'Model-D', 'Model-E'};
        end

        function RunSimulationButtonPushed(app, event)
            addpath('libs');
            numIterations = app.NumIterationsEditField.Value;
            snrRangeStr = app.SNRRangeEditField.Value;
            snrRange = str2num(snrRangeStr); %#ok<ST2NM>
            numAPs = app.NumAPsEditField.Value;
            chanBW = app.ChanBWDropDown.Value;
            numTx = app.NumTxEditField.Value;
            numRx = app.NumRxEditField.Value;
            numSTS = app.NumSTSEditField.Value;
            numLTFRepetitions = app.NumLTFRepetitionsEditField.Value;
            delayProfile = app.DelayProfileDropDown.Value;
            carrierFrequency = app.CarrierFrequencyEditField.Value;
            delayULDL = app.DelayULDLEditField.Value;
            useMusic = app.UseMusicCheckBox.Value; % Передаём значение чекбокса

            runPositioningSimulation(numIterations, snrRange, numAPs, chanBW, numTx, numRx, numSTS, numLTFRepetitions, delayProfile, carrierFrequency, delayULDL, useMusic);
            rmpath('libs');
        end
    end

    methods (Access = private)
        function createComponents(app)
            app.UIFigure = uifigure('Position', [100 100 640 520], 'Name', 'Моделирование позиционирования');

            % Number of Iterations
            app.NumIterationsLabel = uilabel(app.UIFigure, 'Position', [50 470 120 22], 'Text', 'Количество итераций');
            app.NumIterationsEditField = uieditfield(app.UIFigure, 'numeric', 'Position', [180 470 100 22], 'Value', 5);

            % SNR Range
            app.SNRRangeLabel = uilabel(app.UIFigure, 'Position', [50 440 120 22], 'Text', 'Диапазон ОСШ (дБ)');
            app.SNRRangeEditField = uieditfield(app.UIFigure, 'text', 'Position', [180 440 100 22], 'Value', '8:2:14');

            % Number of APs
            app.NumAPsLabel = uilabel(app.UIFigure, 'Position', [50 410 120 22], 'Text', 'Количество ТД');
            app.NumAPsEditField = uieditfield(app.UIFigure, 'numeric', 'Position', [180 410 100 22], 'Value', 3);

            % Channel Bandwidth
            app.ChanBWLabel = uilabel(app.UIFigure, 'Position', [50 380 120 22], 'Text', 'Ширина полосы');
            app.ChanBWDropDown = uidropdown(app.UIFigure, 'Position', [180 380 100 22], 'Items', {'CBW20', 'CBW40', 'CBW80', 'CBW160'}, 'Value', 'CBW20');

            % Number of Tx Antennas
            app.NumTxLabel = uilabel(app.UIFigure, 'Position', [50 350 120 22], 'Text', 'Количество передающих антенн');
            app.NumTxEditField = uieditfield(app.UIFigure, 'numeric', 'Position', [180 350 100 22], 'Value', 1);

            % Number of Rx Antennas
            app.NumRxLabel = uilabel(app.UIFigure, 'Position', [50 320 120 22], 'Text', 'Количество принимаемых антенн');
            app.NumRxEditField = uieditfield(app.UIFigure, 'numeric', 'Position', [180 320 100 22], 'Value', 1);

            % Number of Space-Time Streams
            app.NumSTSLabel = uilabel(app.UIFigure, 'Position', [50 290 120 22], 'Text', 'Количество пространственно-временных потоков');
            app.NumSTSEditField = uieditfield(app.UIFigure, 'numeric', 'Position', [180 290 100 22], 'Value', 1);

            % Number of LTF Repetitions
            app.NumLTFRepetitionsLabel = uilabel(app.UIFigure, 'Position', [50 260 120 22], 'Text', 'Повторение HE-LTF');
            app.NumLTFRepetitionsEditField = uieditfield(app.UIFigure, 'numeric', 'Position', [180 260 100 22], 'Value', 2);

            % Delay Profile
            app.DelayProfileLabel = uilabel(app.UIFigure, 'Position', [50 230 120 22], 'Text', 'Модель канала');
            app.DelayProfileDropDown = uidropdown(app.UIFigure, 'Position', [180 230 100 22], 'Items', {'Model-A', 'Model-B', 'Model-C', 'Model-D', 'Model-E'}, 'Value', 'Model-B');

            % Carrier Frequency
            app.CarrierFrequencyLabel = uilabel(app.UIFigure, 'Position', [50 200 120 22], 'Text', 'Частота (Гц)');
            app.CarrierFrequencyEditField = uieditfield(app.UIFigure, 'numeric', 'Position', [180 200 100 22], 'Value', 2.4e9);

            % Delay UL-DL
            app.DelayULDLLabel = uilabel(app.UIFigure, 'Position', [50 170 120 22], 'Text', 'Задержка ВЛ-НЛ (s)');
            app.DelayULDLEditField = uieditfield(app.UIFigure, 'numeric', 'Position', [180 170 100 22], 'Value', 1e-6);

            % Чекбокс Use MUSIC
            app.UseMusicCheckBox = uicheckbox(app.UIFigure, 'Position', [50 140 200 22], 'Text', 'Использование MUSIC', 'Value', true);

            % Run Simulation Button
            app.RunSimulationButton = uibutton(app.UIFigure, 'push', 'Position', [280 50 150 30], 'Text', 'Запустить симуляцию');
            app.RunSimulationButton.ButtonPushedFcn = createCallbackFcn(app, @RunSimulationButtonPushed, true);
        end
    end

    methods (Access = public)
        function app = PositioningGUI
            createComponents(app);
            registerApp(app, app.UIFigure);
            runStartupFcn(app, @startupFcn);
        end

        function delete(app)
            delete(app.UIFigure);
        end
    end
end