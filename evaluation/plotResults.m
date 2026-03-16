%% VISUALIZATION AND PLOTTING
% Generates all visualization plots for FDIA detection results
%
% Plots:
%   - Confusion Matrix
%   - ROC Curve
%   - Precision-Recall Curve
%   - Detection Timeline
%   - Latency Distribution
%   - Attack vs Normal Comparison

function plotResults(metrics, data, predictions, labels, cfg, varargin)
    fprintf('=== Generating Visualizations ===\n');

% Create output directory outputDir = cfg.eval.outputDir;
if
  ~exist(outputDir, 'dir') mkdir(outputDir);
end

    % %
    Figure 1 : Confusion Matrix figure('Name', 'Confusion Matrix', 'Position',
                                       [ 100, 100, 600, 500 ]);

cm = metrics.confusionMatrix;
imagesc(cm);
colormap(flipud(hot));
colorbar;

% Add text labels textStrings = num2str(cm( :), '%d');
textStrings = strtrim(cellstr(textStrings));
[ x, y ] = meshgrid(1 : 2, 1 : 2);
text(x( :), y( :), textStrings( :), 'HorizontalAlignment', 'center',
     ... 'FontSize', 20, 'FontWeight', 'bold', 'Color', 'w');

title('Confusion Matrix', 'FontSize', 14);
xlabel('Predicted', 'FontSize', 12);
ylabel('Actual', 'FontSize', 12);
set(gca, 'XTick', [ 1, 2 ], 'XTickLabel', {'Normal', 'Attack'});
set(gca, 'YTick', [ 1, 2 ], 'YTickLabel', {'Normal', 'Attack'});

if cfg
  .eval.savePlots saveas(gcf, fullfile(outputDir, 'confusion_matrix.png'));
end

    % %
    Figure 2
    : ROC Curve if isfield (metrics, 'roc')
          figure('Name', 'ROC Curve', 'Position', [ 150, 150, 600, 500 ]);

plot(metrics.roc.fpr, metrics.roc.tpr, 'b-', 'LineWidth', 2);
hold on;
plot([ 0, 1 ], [ 0, 1 ], 'k--', 'LineWidth', 1);

title(sprintf('ROC Curve (AUC = %.4f)', metrics.aucROC), 'FontSize', 14);
xlabel('False Positive Rate', 'FontSize', 12);
ylabel('True Positive Rate', 'FontSize', 12);
legend('ROC Curve', 'Random Classifier', 'Location', 'southeast');
grid on;

if cfg
  .eval.savePlots saveas(gcf, fullfile(outputDir, 'roc_curve.png'));
end end

        % % Figure 3 : Precision -
    Recall Curve if isfield (metrics, 'pr')
        figure('Name', 'Precision-Recall Curve', 'Position',
               [ 200, 200, 600, 500 ]);

plot(metrics.pr.recall, metrics.pr.precision, 'r-', 'LineWidth', 2);

title(sprintf('Precision-Recall Curve (AUC = %.4f)', metrics.aucPR), 'FontSize',
      14);
xlabel('Recall', 'FontSize', 12);
ylabel('Precision', 'FontSize', 12);
grid on;
xlim([ 0, 1 ]);
ylim([ 0, 1 ]);

if cfg
  .eval.savePlots saveas(gcf, fullfile(outputDir, 'pr_curve.png'));
end end

            % % Figure 4 : Detection Timeline if nargin >=
        4 &&
    ~isempty(predictions) &&
    ~isempty(labels) figure('Name', 'Detection Timeline', 'Position',
                            [ 250, 250, 1200, 400 ]);

n = length(predictions);
t = 1 : n;

% True labels subplot(3, 1, 1);
stem(t, labels, 'b', 'Marker', 'none');
title('True Labels (0=Normal, 1=Attack)', 'FontSize', 12);
ylim([ -0.2, 1.2 ]);
ylabel('Label');

% Predictions subplot(3, 1, 2);
stem(t, predictions, 'r', 'Marker', 'none');
title('Model Predictions', 'FontSize', 12);
ylim([ -0.2, 1.2 ]);
ylabel('Prediction');

% Errors subplot(3, 1, 3);
errors = xor(predictions, labels);
stem(t, errors, 'Color', [ 0.8, 0.2, 0.2 ], 'Marker', 'none');
title(sprintf('Errors (Total: %d / %d = %.2f%%)', sum(errors), n,
              100 * sum(errors) / n),
      'FontSize', 12);
ylim([ -0.2, 1.2 ]);
xlabel('Sample Index');
ylabel('Error');

if cfg
  .eval.savePlots saveas(gcf, fullfile(outputDir, 'detection_timeline.png'));
end end

        % % Figure 5 : Latency Distribution if isfield (metrics, 'latency') &&
    ~isempty(varargin) && ~isempty(varargin{1}) latencies = varargin{1};

figure('Name', 'Latency Distribution', 'Position', [ 300, 300, 800, 400 ]);

subplot(1, 2, 1);
histogram(latencies, 50, 'FaceColor', 'blue', 'EdgeColor', 'none');
title('Detection Latency Distribution', 'FontSize', 12);
xlabel('Latency (ms)');
ylabel('Frequency');

% Add statistics xline(metrics.latency.mean, 'r--', 'LineWidth', 2);
xline(metrics.latency.p95, 'g--', 'LineWidth', 2);
legend('Histogram', sprintf('Mean: %.2f ms', metrics.latency.mean),
       ... sprintf('P95: %.2f ms', metrics.latency.p95));

subplot(1, 2, 2);
plot(latencies, 'b-', 'LineWidth', 0.5);
hold on;
yline(cfg.fog.latencyBudget, 'r--', 'LineWidth', 2);
title('Latency Over Time', 'FontSize', 12);
xlabel('Sample');
ylabel('Latency (ms)');
legend('Latency', sprintf('Budget: %d ms', cfg.fog.latencyBudget));

if cfg
  .eval.savePlots saveas(gcf, fullfile(outputDir, 'latency_distribution.png'));
end end

    % %
    Figure 6
    : Metrics Summary Bar Chart figure('Name', 'Metrics Summary', 'Position',
                                       [ 350, 350, 700, 400 ]);

metricNames = {'Accuracy', 'Precision', 'Recall', 'F1-Score', 'Specificity'};
metricValues = [
  metrics.accuracy, metrics.precision, metrics.recall, ... metrics.f1,
  metrics.specificity
];

bar(metricValues, 'FaceColor', [ 0.3, 0.6, 0.9 ]);
set(gca, 'XTickLabel', metricNames);
ylim([ 0, 1.1 ]);
ylabel('Score');
title('Detection Performance Metrics', 'FontSize', 14);

    % Add value labels
    for i = 1:length(metricValues)
        text(i, metricValues(i) + 0.03, sprintf('%.3f', metricValues(i)), ...
            'HorizontalAlignment', 'center', 'FontSize', 10);
    end

        grid on;

    if cfg
      .eval.savePlots saveas(gcf, fullfile(outputDir, 'metrics_summary.png'));
    end

        fprintf('=== Visualization Complete ===\n');
    if cfg
      .eval.savePlots fprintf('Plots saved to: %s\n', outputDir);
    end end

        % %
        Plot attack comparison(normal vs attacked data) function
        plotAttackComparison(normalData, attackedData, meta, cfg)
            figure('Name', 'Attack Comparison', 'Position',
                   [ 100, 100, 1400, 600 ]);

    nBuses = meta.nBuses;
    nSamples = min(500, size(normalData, 1));
    % Plot first 500 samples

        % Voltage comparison subplot(2, 2, 1);
    plot(normalData(1 : nSamples, 1), 'b-', 'LineWidth', 1);
    hold on;
    plot(attackedData(1 : nSamples, 1), 'r--', 'LineWidth', 1);
    title('Bus 1 Voltage: Normal vs Attacked', 'FontSize', 12);
    xlabel('Sample');
    ylabel('Voltage (p.u.)');
    legend('Normal', 'Attacked');
    grid on;

    % Difference subplot(2, 2, 2);
    diff = attackedData(1 : nSamples, 1 : nBuses) -
           normalData(1 : nSamples, 1 : nBuses);
    plot(mean(abs(diff), 2), 'Color', [ 0.8, 0.2, 0.2 ], 'LineWidth', 1);
    title('Mean Absolute Voltage Deviation', 'FontSize', 12);
    xlabel('Sample');
    ylabel('|Attacked - Normal|');
    grid on;

    % Power comparison subplot(2, 2, 3);
    pIdx = 2 * nBuses + 1;
    % Active power start index plot(normalData(1 : nSamples, pIdx), 'b-',
                                    'LineWidth', 1);
    hold on;
    plot(attackedData(1 : nSamples, pIdx), 'r--', 'LineWidth', 1);
    title('Bus 1 Active Power: Normal vs Attacked', 'FontSize', 12);
    xlabel('Sample');
    ylabel('Power (MW)');
    legend('Normal', 'Attacked');
    grid on;

    % Feature space(2D projection) subplot(2, 2, 4);
    [ coeff, score ] = pca([normalData; attackedData]);
    nNormal = size(normalData, 1);
    scatter(score(1 : nNormal, 1), score(1 : nNormal, 2), 10, 'b', 'filled',
            'MarkerFaceAlpha', 0.3);
    hold on;
    scatter(score(nNormal + 1 : end, 1), score(nNormal + 1 : end, 2), 10, 'r',
            'filled', 'MarkerFaceAlpha', 0.3);
    title('PCA: Normal vs Attacked', 'FontSize', 12);
    xlabel('PC1');
    ylabel('PC2');
    legend('Normal', 'Attacked');
    grid on;

    if cfg
      .eval.savePlots saveas(gcf, fullfile(cfg.eval.outputDir,
                                           'attack_comparison.png'));
    end end
