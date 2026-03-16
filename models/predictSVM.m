function [predictions, scores, probabilities] = predictSVM(model, testFeatures)
    X_norm = (testFeatures - model.normParams.mu) ./ model.normParams.sigma;
    X_norm(isnan(X_norm)) = 0;
    X_norm(isinf(X_norm)) = 0;
    if strcmp(model.type, 'oneclass')
        dists = sqrt(sum((X_norm - model.center).^2, 2));
        predictions = double(dists > model.threshold);
        scores = dists ./ (model.threshold + 1e-10);
    else
        distNormal = sqrt(sum((X_norm - model.normalCenter).^2, 2));
        distAttack = sqrt(sum((X_norm - model.attackCenter).^2, 2));
        scores = distNormal - distAttack;
        predictions = double(scores > model.threshold);
    end
    probabilities = 1 ./ (1 + exp(-scores));
end
