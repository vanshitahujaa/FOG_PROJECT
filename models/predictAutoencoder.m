function [predictions, errors, probabilities] = predictAutoencoder(model, testFeatures)
    X_norm = (testFeatures - model.mu) ./ model.sigma;
    X_norm(isnan(X_norm)) = 0;
    X_norm(isinf(X_norm)) = 0;
    centered = X_norm - model.mu_pca;
    projected = centered * model.coeff;
    X_reconstructed = projected * model.coeff' + model.mu_pca;
    errors = mean((X_norm - X_reconstructed).^2, 2);
    predictions = double(errors > model.threshold);
    normalized_errors = (errors - model.meanError) / model.stdError;
    probabilities = 1 ./ (1 + exp(-normalized_errors));
end
