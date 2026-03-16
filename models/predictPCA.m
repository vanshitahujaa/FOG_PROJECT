function [predictions, scores, probabilities] = predictPCA(model, testFeatures)
    X_norm = (testFeatures - model.mu) ./ model.sigma;
    X_norm(isnan(X_norm)) = 0;
    X_norm(isinf(X_norm)) = 0;
    scores_proj = X_norm * model.P;
    X_reconstructed = scores_proj * model.P';
    residuals = X_norm - X_reconstructed;
    T2 = sum((scores_proj ./ sqrt(model.eigenvalues' + 1e-10)).^2, 2);
    Q = sum(residuals.^2, 2);
    scores = (T2 - model.T2_mean) / (model.T2_std + 1e-10) + (Q - model.Q_mean) / (model.Q_std + 1e-10);
    predictions = double(scores > model.combined_threshold);
    normalized_scores = (scores - model.combined_mean) / (model.combined_std + 1e-10);
    probabilities = 1 ./ (1 + exp(-normalized_scores));
end
