function model = trainSVM(trainFeatures, cfg, trainLabels)
    fprintf('=== Training SVM Model ===\n');
    [X_norm, mu, sigma] = manualZscore(trainFeatures);
    model.normParams.mu = mu;
    model.normParams.sigma = sigma;
    if nargin < 3 || isempty(trainLabels) || all(trainLabels == 0)
        fprintf('Training One-Class (distance-based)...\n');
        model.type = 'oneclass';
        model.center = mean(X_norm, 1);
        dists = sqrt(sum((X_norm - model.center).^2, 2));
        model.threshold = mean(dists) + 2 * std(dists);
        model.trainDists = dists;
    else
        fprintf('Training Binary (centroid-based)...\n');
        model.type = 'binary';
        normalIdx = trainLabels == 0;
        attackIdx = trainLabels == 1;
        model.normalCenter = mean(X_norm(normalIdx, :), 1);
        model.attackCenter = mean(X_norm(attackIdx, :), 1);
        model.threshold = 0;
    end
    model.cfg = cfg;
    model.svm = true;
    fprintf('=== SVM Training Complete ===\n');
end
