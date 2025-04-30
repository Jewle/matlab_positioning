function hePlotTrilaterationCircles(positionAP, positionSTAEst, distEst, snr, iteration)
% hePlotTrilaterationCircles Plot trilateration circles for a single STA
%
%   Inputs:
%   positionAP    - 2 x numAPs matrix of AP positions [x; y]
%   positionSTAEst - 2 x 1 vector of estimated STA position [x; y]
%   distEst       - numAPs x 1 vector of estimated distances
%   snr           - SNR value (dB)
%   iteration     - Iteration number
%
%   Plots circles centered at AP positions with radii equal to estimated distances
%   and marks estimated STA position.

% Проверяем валидность данных
if any(isnan(distEst)) || any(isnan(positionSTAEst))
    disp(['Skipping trilateration plot for SNR = ', num2str(snr), ' dB, Iteration = ', num2str(iteration), ': Invalid data']);
    return;
end

figure;
hold on;

theta = linspace(0, 2*pi, 100);
color = 'b'; % Цвет для одной STA

% Plot AP positions
scatter(positionAP(1, :), positionAP(2, :), 'k^', 'filled', 'DisplayName', 'APs');

% Plot estimated STA position
scatter(positionSTAEst(1), positionSTAEst(2), 50, color, 'o', 'filled', 'DisplayName', 'Estimated STA');

% Plot trilateration circles
for ap = 1:size(positionAP, 2)
    x_circle = positionAP(1, ap) + distEst(ap) * cos(theta);
    y_circle = positionAP(2, ap) + distEst(ap) * sin(theta);
    plot(x_circle, y_circle, 'Color', color, 'LineStyle', '--', 'DisplayName', ['Circle AP ' num2str(ap)]);
end

hold off;
xlabel('X (meters)');
ylabel('Y (meters)');
title(['Trilateration Circles for Iteration ' num2str(iteration) ' at SNR ' num2str(snr) ' dB']);
grid on;
legend('show', 'Interpreter', 'none');
axis equal;
end