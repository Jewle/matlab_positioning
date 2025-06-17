function visualizeTrilateration(numAPs, numIterations, snrRange, positionAP, positionSTAEst, distEst, methodStr)
    % Визуализирует трилатерацию с усреднением по итерациям
    % numAPs - количество точек доступа
    % numIterations - количество итераций
    % snrRange - диапазон ОСШ
    % positionAP - позиции AP [2, numAPs, numIterations, numSNR]
    % positionSTAEst - оценённые позиции STA [2, numIterations, numSNR]
    % distEst - оценённые расстояния [numAPs, numIterations, numSNR]
    % methodStr - строка метода

    numSNR = numel(snrRange);
    for isnr = 1:numSNR
        % Выбор валидных итераций (где достаточно оценок расстояний)
        validIters = find(sum(~isnan(distEst(:, :, isnr)), 1) >= 3);
        if isempty(validIters)
            disp(['Нет корректных данных для ОСШ ', num2str(snrRange(isnr)), ' дБ, Метод: ', methodStr]);
            continue;
        end

        % Усреднение позиций AP, оценок STA и расстояний
        meanPositionAP = mean(positionAP(:, :, validIters, isnr), 3); % [2, numAPs]
        meanPositionSTAEst = mean(positionSTAEst(:, validIters, isnr), 2, 'omitnan'); % [2, 1]
        meanDistEst = mean(distEst(:, validIters, isnr), 2, 'omitnan'); % [numAPs, 1]

        % Вычисление ковариационной матрицы для доверительного эллипса
        validPosEst = positionSTAEst(:, validIters, isnr);
        validPosEst = validPosEst(:, ~any(isnan(validPosEst), 1));
        if size(validPosEst, 2) > 1
            covMatrix = cov(validPosEst');
            [V, D] = eig(covMatrix);
            radii = sqrt(diag(D)) * sqrt(5.991); % 95% доверительный интервал (chi^2, 2 dof)
            theta = linspace(0, 2*pi, 100);
            ellipse = V * [radii(1)*cos(theta); radii(2)*sin(theta)] + meanPositionSTAEst;
        else
            ellipse = [];
        end

        % Построение графика
        figure('Name', ['Трилатерация, ОСШ = ', num2str(snrRange(isnr)), ' дБ']);
        hePlotNodePositions(meanPositionAP, [0; 0]); % Истинная STA в начале
        hold on;
        plot(meanPositionSTAEst(1), meanPositionSTAEst(2), 'kx', 'LineWidth', 1.5, 'MarkerSize', 10, 'DisplayName', 'Оценка позиции STA');

        % Отрисовка трилатерационных окружностей
        angles = 0:2*pi/720:2*pi;
        for i = 1:numAPs
            x = meanDistEst(i) * cos(angles) + meanPositionAP(1, i);
            y = meanDistEst(i) * sin(angles) + meanPositionAP(2, i);
            plot(x, y, 'k--', 'LineWidth', 1, 'HandleVisibility', 'off');
        end

        % Доверительный эллипс
        if ~isempty(ellipse)
            plot(ellipse(1, :), ellipse(2, :), 'r:', 'LineWidth', 1, 'DisplayName', '95% доверительный интервал');
        end

        title(['Трилатерация, ОСШ = ', num2str(snrRange(isnr)), ' дБ, Метод: ', methodStr]);
        legend('show', 'Location', 'best', 'FontSize', 10);
        legend('boxoff');
        hold off;
    end
end