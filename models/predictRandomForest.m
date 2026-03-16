function [predictions, scores, probabilities] = predictRandomForest(model, testFeatures)
    X_norm = (testFeatures - model.normParams.mu) ./ model.normParams.sigma;
    X_norm(isnan(X_norm)) = 0;
    X_norm(isinf(X_norm)) = 0;
    nSamples = size(X_norm, 1);
    nTrees = model.nTrees;
    votes = zeros(nSamples, 1);
    for t = 1:nTrees
        s = model.stumps(t);
        isRight = X_norm(:, s.featureIdx) > s.threshold;
        pred = zeros(nSamples, 1);
        pred(~isRight) = s.leftClass;
        pred(isRight) = s.rightClass;
        votes = votes + pred;
    end
    scores = votes / nTrees;
    predictions = double(scores > 0.5);
    probabilities = scores;
end
