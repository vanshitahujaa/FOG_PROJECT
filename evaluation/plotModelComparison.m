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
