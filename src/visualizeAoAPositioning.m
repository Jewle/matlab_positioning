function visualizeAoAPositioning(numAPs, numIterations, snrRange, positionAP, positionSTA, positionSTAEst, aoaEst, methodStr)
    % Визуализирует позиционирование по AoA
    % numAPs - количество точек доступа
    % numIterations - количество итераций
    % snrRange - диапазон ОСШ
    % positionAP - позиции AP [2, numAPs, numIterations, numSNR]
    % positionSTA - истинные позиции STA [2, numIterations, numSNR]
    % positionSTAEst - оценённые позиции STA [2, numIterations, numSNR]
    % aoaEst - оценённые углы [numAPs, numIterations, numSNR, numPaths]
    % methodStr - строка метода

% disp('AP Positions');
% disp(positionAP);
% disp("STA Positions");
% disp(positionSTA);
% disp("STA Estimated Poisitions");
% disp("AoA Estimated");
% disp(aoaEst);

    numSNR = numel(snrRange);
    for isnr = 1:numSNR
        % Найти последнюю итерацию с валидными данными
        validIter = find(~any(isnan(positionSTAEst(:, :, isnr)), 1), 1, 'last');
        if isempty(validIter)
            disp(['Нет корректных данных для ОСШ ', num2str(snrRange(isnr)), ' дБ, Метод: ', methodStr]);
            continue;
        end

        figure('Name', ['Позиционирование по AoA, ОСШ = ', num2str(snrRange(isnr)), ' дБ']);
        hold on;
        grid on;
        axis equal;

        % Истинная позиция STA
        plot(positionSTA(1, validIter, isnr), positionSTA(2, validIter, isnr), 'go', 'MarkerSize', 10, 'LineWidth', 2, 'DisplayName', 'Истинная позиция STA');

        % Оценённая позиция STA
        plot(positionSTAEst(1, validIter, isnr), positionSTAEst(2, validIter, isnr), 'rx', 'MarkerSize', 10, 'LineWidth', 2, 'DisplayName', 'Оценённая позиция STA');

        % Позиции AP и лучи AoA
        apPos = squeeze(positionAP(:, :, validIter, isnr));
        angles = squeeze(aoaEst(:, validIter, isnr, 1));
        maxRange = 10; % Максимальная длина лучей для визуализации (в метрах)
        for i = 1:numAPs
            % Позиция AP
            plot(apPos(1, i), apPos(2, i), 'bs', 'MarkerSize', 8, 'LineWidth', 2, 'DisplayName', ['AP ', num2str(i)]);

            % Луч AoA
            theta = deg2rad(angles(i));
            endX = apPos(1, i) + maxRange * cos(theta);
            endY = apPos(2, i) + maxRange * sin(theta);
            plot([apPos(1, i), endX], [apPos(2, i), endY], 'b--', 'LineWidth', 1, 'HandleVisibility', 'off');
        end

        xlabel('X (м)');
        ylabel('Y (м)');
        title(['Позиционирование по AoA, ОСШ = ', num2str(snrRange(isnr)), ' дБ, Метод: ', methodStr]);
        legend('show');
        hold off;
    end
end