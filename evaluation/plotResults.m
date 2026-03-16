function plotResults(metrics, data, predictions, labels, cfg, varargin)
    fprintf('=== Generating Visualizations ===\n');
    outputDir = cfg.eval.outputDir;
    if ~exist(outputDir, 'dir')
        mkdir(outputDir);
    end
    fig = figure('Name', 'Confusion Matrix', 'Visible', 'off');
    cm = metrics.confusionMatrix;
    imagesc(cm);
    colormap(flipud(hot));
    colorbar;
    title('Confusion Matrix');
    xlabel('Predicted');
    ylabel('Actual');
    set(gca, 'XTick', [1, 2], 'XTickLabel', {'Normal', 'Attack'});
    set(gca, 'YTick', [1, 2], 'YTickLabel', {'Normal', 'Attack'});
    if cfg.eval.savePlots
        saveas(gcf, fullfile(outputDir, 'confusion_matrix.png'));
    end
    close(fig);
    fig2 = figure('Name', 'Metrics Summary', 'Visible', 'off');
    metricNames = {'Accuracy', 'Precision', 'Recall', 'F1-Score', 'Specificity'};
    metricValues = [metrics.accuracy, metrics.precision, metrics.recall, metrics.f1, metrics.specificity];
    bar(metricValues, 'FaceColor', [0.3, 0.6, 0.9]);
    set(gca, 'XTickLabel', metricNames);
    ylim([0, 1.1]);
    ylabel('Score');
    title('Detection Performance Metrics');
    grid on;
    if cfg.eval.savePlots
        saveas(gcf, fullfile(outputDir, 'metrics_summary.png'));
    end
    close(fig2);
    fprintf('=== Visualization Complete ===\n');
    if cfg.eval.savePlots
        fprintf('Plots saved to: %s\n', outputDir);
    end
end

function plotAttackComparison(normalData, attackedData, meta, cfg)
    fig = figure('Name', 'Attack Comparison', 'Visible', 'off');
    nBuses = meta.nBuses;
    nSamples = min(500, size(normalData, 1));
    subplot(2, 2, 1);
    plot(normalData(1:nSamples, 1), 'b-');
    hold on;
    plot(attackedData(1:nSamples, 1), 'r--');
    title('Bus 1 Voltage: Normal vs Attacked');
    xlabel('Sample');
    ylabel('Voltage (p.u.)');
    legend('Normal', 'Attacked');
    grid on;
    subplot(2, 2, 2);
    d = attackedData(1:nSamples, 1:nBuses) - normalData(1:nSamples, 1:nBuses);
    plot(mean(abs(d), 2), 'r-');
    title('Mean Absolute Deviation');
    grid on;
    subplot(2, 2, 3);
    pIdx = 2 * nBuses + 1;
    plot(normalData(1:nSamples, pIdx), 'b-');
    hold on;
    plot(attackedData(1:nSamples, pIdx), 'r--');
    title('Bus 1 Active Power');
    legend('Normal', 'Attacked');
    grid on;
    subplot(2, 2, 4);
    [~, score] = pca([normalData; attackedData]);
    nN = size(normalData, 1);
    scatter(score(1:nN, 1), score(1:nN, 2), 10, 'b', 'filled', 'MarkerFaceAlpha', 0.3);
    hold on;
    scatter(score(nN+1:end, 1), score(nN+1:end, 2), 10, 'r', 'filled', 'MarkerFaceAlpha', 0.3);
    title('PCA: Normal vs Attacked');
    legend('Normal', 'Attacked');
    grid on;
    if cfg.eval.savePlots
        saveas(gcf, fullfile(cfg.eval.outputDir, 'attack_comparison.png'));
    end
    close(fig);
end

function plotModelComparison(allMetrics, modelNames, cfg)
    fig = figure('Name', 'Model Comparison', 'Visible', 'off');
    nModels = length(allMetrics);
    data = zeros(nModels, 5);
    for i = 1:nModels
        m = allMetrics{i};
        data(i, :) = [m.accuracy, m.precision, m.recall, m.f1, m.specificity];
    end
    b = bar(data, 'grouped');
    colors = [0.2 0.4 0.8; 0.9 0.3 0.3; 0.3 0.7 0.3; 0.9 0.6 0.1; 0.6 0.3 0.7];
    for i = 1:min(5, length(b))
        b(i).FaceColor = colors(i, :);
    end
    set(gca, 'XTickLabel', modelNames);
    ylabel('Score');
    title('Multi-Model Detection Performance');
    legend({'Accuracy', 'Precision', 'Recall', 'F1', 'Specificity'}, 'Location', 'southoutside', 'Orientation', 'horizontal');
    ylim([0, 1.15]);
    grid on;
    if cfg.eval.savePlots
        saveas(gcf, fullfile(cfg.eval.outputDir, 'model_comparison.png'));
    end
    close(fig);
end
