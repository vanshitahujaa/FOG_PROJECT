function model = trainPCA(normalFeatures, cfg)
    fprintf('=== Training PCA Anomaly Detection ===\n');
    [X_norm, mu, sigma] = manualZscore(normalFeatures);
    [nSamples, nFeatures] = size(X_norm);
    fprintf('Data: %d samples x %d features\n', nSamples, nFeatures);
    [coeff, score, latent, ~, explained] = manualPCA(X_norm);
    varianceRetained = cfg.pca.varianceRetained;
    cumExplained = cumsum(explained);
    nComponents = find(cumExplained >= varianceRetained * 100, 1, 'first');
    if isempty(nComponents)
        nComponents = nFeatures;
    end
    nComponents = max(1, min(nComponents, nFeatures));
    fprintf('Components: %d / %d (%.1f%% variance)\n', nComponents, nFeatures, cumExplained(nComponents));
    P = coeff(:, 1:nComponents);
    eigenvalues = latent(1:nComponents);
    scores_train = X_norm * P;
    X_reconstructed = scores_train * P';
    residuals = X_norm - X_reconstructed;
    T2_train = sum((scores_train ./ sqrt(eigenvalues' + 1e-10)).^2, 2);
    Q_train = sum(residuals.^2, 2);
    T2_mean = mean(T2_train);
    T2_std = std(T2_train);
    Q_mean = mean(Q_train);
    Q_std = std(Q_train);
    combinedScores = (T2_train - T2_mean) / (T2_std + 1e-10) + (Q_train - Q_mean) / (Q_std + 1e-10);
    threshMultiplier = cfg.pca.thresholdMultiplier;
    model.T2_threshold = T2_mean + threshMultiplier * T2_std;
    model.Q_threshold = Q_mean + threshMultiplier * Q_std;
    model.combined_threshold = mean(combinedScores) + threshMultiplier * std(combinedScores);
    model.P = P;
    model.eigenvalues = eigenvalues;
    model.nComponents = nComponents;
    model.mu = mu;
    model.sigma = sigma;
    model.T2_mean = T2_mean;
    model.T2_std = T2_std;
    model.Q_mean = Q_mean;
    model.Q_std = Q_std;
    model.combined_mean = mean(combinedScores);
    model.combined_std = std(combinedScores);
    model.cfg = cfg;
    model.type = 'pca';
    fprintf('T2 threshold: %.4f, Q threshold: %.4f\n', model.T2_threshold, model.Q_threshold);
    fprintf('=== PCA Training Complete ===\n');
end
