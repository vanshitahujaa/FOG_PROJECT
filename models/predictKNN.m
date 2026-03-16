function [predictions, scores, probabilities] = predictKNN(model, testFeatures)
    X_norm = (testFeatures - model.normParams.mu) ./ model.normParams.sigma;
    X_norm(isnan(X_norm)) = 0;
    X_norm(isinf(X_norm)) = 0;
    nTest = size(X_norm, 1);
    nTrain = size(model.X_train, 1);
    k = min(model.k, nTrain);
    predictions = zeros(nTest, 1);
    scores = zeros(nTest, 1);
    for i = 1:nTest
        diffs = model.X_train - X_norm(i, :);
        dists = sqrt(sum(diffs.^2, 2));
        [~, sortIdx] = sort(dists);
        kIdx = sortIdx(1:k);
        kLabels = model.y_train(kIdx);
        kDists = dists(kIdx);
        weights = 1 ./ (kDists.^2 + 1e-10);
        weightedVote = sum(weights .* kLabels) / sum(weights);
        predictions(i) = double(weightedVote > 0.5);
        scores(i) = weightedVote;
    end
    probabilities = scores;
end
