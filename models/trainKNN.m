function model = trainKNN(trainFeatures, cfg, trainLabels)
    fprintf('=== Training KNN Model ===\n');
    [X_norm, mu, sigma] = manualZscore(trainFeatures);
    model.normParams.mu = mu;
    model.normParams.sigma = sigma;
    model.X_train = X_norm;
    model.y_train = trainLabels;
    model.k = cfg.knn.k;
    model.knn = true;
    model.cfg = cfg;
    model.type = 'knn';
    fprintf('K=%d, %d training samples\n', model.k, size(X_norm, 1));
    fprintf('=== KNN Training Complete ===\n');
end
