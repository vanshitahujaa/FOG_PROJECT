function plotModelComparison(allMetrics, modelNames, cfg)
    fig = figure('Name', 'Model Comparison', 'Visible', 'off', 'Position', [100 100 1400 500]);

    % Subplot 1: Performance metrics (0-1 scale)
    subplot(1, 2, 1);
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
    title('Detection Performance Metrics');
    legend({'Accuracy', 'Precision', 'Recall', 'F1', 'Specificity'}, 'Location', 'southoutside', 'Orientation', 'horizontal', 'FontSize', 7);
    ylim([0, 1.15]);
    grid on;

    % Subplot 2: FP and FN counts
    subplot(1, 2, 2);
    fpfnData = zeros(nModels, 2);
    for i = 1:nModels
        m = allMetrics{i};
        fpfnData(i, :) = [m.FP, m.FN];
    end
    b2 = bar(fpfnData, 'grouped');
    b2(1).FaceColor = [0.85 0.33 0.1];
    b2(2).FaceColor = [0.1 0.45 0.75];
    set(gca, 'XTickLabel', modelNames);
    ylabel('Count');
    title('False Positives & False Negatives');
    legend({'False Positives (FP)', 'False Negatives (FN)'}, 'Location', 'southoutside', 'Orientation', 'horizontal');
    grid on;

    % Add value labels on top of FP/FN bars
    for k = 1:2
        xData = b2(k).XEndPoints;
        yData = b2(k).YEndPoints;
        for j = 1:length(xData)
            if fpfnData(j, k) > 0
                text(xData(j), yData(j) + 0.3, num2str(fpfnData(j, k)), ...
                    'HorizontalAlignment', 'center', 'FontSize', 8, 'FontWeight', 'bold');
            end
        end
    end

    sgtitle('4-Layer Consensus FDIA Detection Comparison', 'FontWeight', 'bold', 'FontSize', 14);

    if cfg.eval.savePlots
        saveas(gcf, fullfile(cfg.eval.outputDir, 'model_comparison.png'));
    end
    close(fig);
end
