function plotAttackComparison(normalData, attackedData, meta, cfg)
    fig = figure('Name', 'Attack Comparison', 'Visible', 'off');
    nBuses = meta.nBuses;
    nSamples = min(500, size(normalData, 1));
    subplot(2, 2, 1);
    plot(normalData(1:nSamples, 1), 'b-');
    hold on;
    plot(attackedData(1:nSamples, 1), 'r--');
    title('Bus 1 Voltage');
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
    [~, score] = manualPCA([normalData; attackedData]);
    nN = size(normalData, 1);
    scatter(score(1:nN, 1), score(1:nN, 2), 10, 'b', 'filled', 'MarkerFaceAlpha', 0.3);
    hold on;
    scatter(score(nN+1:end, 1), score(nN+1:end, 2), 10, 'r', 'filled', 'MarkerFaceAlpha', 0.3);
    title('PCA Projection');
    legend('Normal', 'Attacked');
    grid on;
    if cfg.eval.savePlots
        saveas(gcf, fullfile(cfg.eval.outputDir, 'attack_comparison.png'));
    end
    close(fig);
end
