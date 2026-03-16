%% PCA-BASED ANOMALY DETECTION
% Trains a PCA model for unsupervised anomaly detection
%
% Principle: PCA learns the principal subspace of normal data.
% Anomaly score is computed using:
%   - Hotelling's T² statistic (variation within principal subspace)
%   - Q-statistic / SPE (variation outside principal subspace)
%
% Usage:
%   model = trainPCA(normalFeatures, cfg)

function model = trainPCA(normalFeatures, cfg)
    fprintf('=== Training PCA Anomaly Detection Model ===\n');

% Normalize features[X_norm, mu, sigma] = zscore(normalFeatures);
sigma(sigma == 0) = 1;

[ nSamples, nFeatures ] = size(X_norm);
fprintf('Training data: %d samples x %d features\n', nSamples, nFeatures);

% % Perform PCA[coeff, score, latent, tsquared, explained, mu_pca] =
    pca(X_norm);

% % Select number of components based on variance retained varianceRetained =
    cfg.pca.varianceRetained;
cumExplained = cumsum(explained);
nComponents = find(cumExplained >= varianceRetained * 100, 1, 'first');

if isempty (nComponents)
  nComponents = nFeatures;
end nComponents = max(1, min(nComponents, nFeatures));

fprintf('Components retained: %d / %d (%.1f%% variance)\n', ... nComponents,
        nFeatures, cumExplained(nComponents));

% % Compute thresholds on training data

    % Principal component loadings(retained) P = coeff( :, 1 : nComponents);
eigenvalues = latent(1 : nComponents);

% Reconstruct training data scores_train = X_norm * P;
X_reconstructed = scores_train *P'; residuals = X_norm - X_reconstructed;

    % T² statistic (Hotelling's T-squared)
    % T² = sum((score_i / sqrt(lambda_i))^2)
    T2_train = sum((scores_train ./ sqrt(eigenvalues' + 1e-10)).^2, 2);

    % Q statistic (Squared Prediction Error / SPE)
    Q_train = sum(residuals.^2, 2);

    % Combined anomaly score (normalized sum)
    T2_mean = mean(T2_train);
    T2_std = std(T2_train);
    Q_mean = mean(Q_train);
    Q_std = std(Q_train);

    combinedScores_train = (T2_train - T2_mean) / (T2_std + 1e-10) + ...
                           (Q_train - Q_mean) / (Q_std + 1e-10);

    % Threshold: mean + multiplier * std
    threshMultiplier = cfg.pca.thresholdMultiplier;
    model.T2_threshold = T2_mean + threshMultiplier * T2_std;
    model.Q_threshold = Q_mean + threshMultiplier * Q_std;
    model.combined_threshold = mean(combinedScores_train) + ...
                               threshMultiplier * std(combinedScores_train);

    %% Store model
    model.coeff = coeff;
    model.P = P;
    model.eigenvalues = eigenvalues;
    model.nComponents = nComponents;
    model.mu = mu;
    model.sigma = sigma;
    model.mu_pca = mu_pca;
    model.explained = explained;
    model.T2_mean = T2_mean;
    model.T2_std = T2_std;
    model.Q_mean = Q_mean;
    model.Q_std = Q_std;
    model.combined_mean = mean(combinedScores_train);
    model.combined_std = std(combinedScores_train);
    model.cfg = cfg;
    model.type = 'pca';

    fprintf('T² threshold: %.4f\n', model.T2_threshold);
    fprintf('Q threshold: %.4f\n', model.Q_threshold);
    fprintf('=== PCA Training Complete ===\n');
end

%% Predict using trained PCA model
function [predictions, scores, probabilities] = predictPCA(model, testFeatures)
    % Normalize using training parameters
    X_norm = (testFeatures - model.mu) ./ model.sigma;
    X_norm(isnan(X_norm)) = 0;
    X_norm(isinf(X_norm)) = 0;

    %% Project onto principal subspace
    scores_proj = X_norm * model.P;
    X_reconstructed = scores_proj * model.P';
    residuals = X_norm - X_reconstructed;

    %% Compute anomaly statistics
    % T² statistic
    T2 = sum((scores_proj ./ sqrt(model.eigenvalues' + 1e-10)).^2, 2);

    % Q statistic (SPE)
    Q = sum(residuals.^2, 2);

    %% Combined normalized score
    scores = (T2 - model.T2_mean) / (model.T2_std + 1e-10) + ...
             (Q - model.Q_mean) / (model.Q_std + 1e-10);

    %% Predictions based on combined threshold
    predictions = double(scores > model.combined_threshold);

    %% Convert to probabilities using sigmoid
    normalized_scores = (scores - model.combined_mean) / (model.combined_std + 1e-10);
    probabilities = 1 ./ (1 + exp(-normalized_scores));
end
