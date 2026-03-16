function model = trainAutoencoder(normalFeatures, cfg)
    fprintf('=== Training Autoencoder (PCA-based) ===\n');
    [X_norm, mu, sigma] = manualZscore(normalFeatures);
    [nSamples, inputSize] = size(X_norm);
    fprintf('Input: %d features, %d samples\n', inputSize, nSamples);
    bottleneckSize = min(cfg.ae.hiddenSize);
    bottleneckSize = min(bottleneckSize, inputSize - 1);
    bottleneckSize = max(bottleneckSize, 1);
    [coeff, ~, latent, ~, explained] = manualPCA(X_norm);
    model.coeff = coeff(:, 1:bottleneckSize);
    model.mu_pca = mean(X_norm, 1);
    model.useDeepLearning = false;
    model.bottleneckSize = bottleneckSize;
    model.explainedVariance = sum(explained(1:bottleneckSize));
    fprintf('PCA bottleneck=%d, variance=%.1f%%\n', bottleneckSize, model.explainedVariance);
    centered = X_norm - model.mu_pca;
    projected = centered * model.coeff;
    X_reconstructed = projected * model.coeff' + model.mu_pca;
    errors = mean((X_norm - X_reconstructed).^2, 2);
    model.mu = mu;
    model.sigma = sigma;
    model.trainErrors = errors;
    model.meanError = mean(errors);
    model.stdError = std(errors);
    model.threshold = model.meanError + cfg.ae.thresholdMultiplier * model.stdError;
    model.cfg = cfg;
    fprintf('Mean error: %.6f, Threshold: %.6f\n', model.meanError, model.threshold);
    fprintf('=== Autoencoder Training Complete ===\n');
end
