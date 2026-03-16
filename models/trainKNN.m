%% KNN-BASED ANOMALY DETECTION
% Trains a K-Nearest Neighbors classifier for FDIA detection
%
% Baseline anomaly detection using distance-based classification.
% Supports configurable K, distance metric, and distance weighting.
%
% Usage:
%   model = trainKNN(trainFeatures, cfg, trainLabels)

function model = trainKNN(trainFeatures, cfg, trainLabels)
    fprintf('=== Training KNN Model ===\n');

% Normalize features[X_norm, normParams.mu, normParams.sigma] =
    zscore(trainFeatures);
normParams.sigma(normParams.sigma == 0) = 1;

[ nSamples, nFeatures ] = size(X_norm);
fprintf('Training data: %d samples x %d features\n', nSamples, nFeatures);

% % Handle class imbalance via prior probabilities nNormal =
    sum(trainLabels == 0);
nAttack = sum(trainLabels == 1);
fprintf('Class distribution: %d normal, %d attack\n', nNormal, nAttack);

% % Train KNN classifier k = cfg.knn.k;
distMetric = cfg.knn.distance;

fprintf('Configuration: K=%d, distance=%s\n', k, distMetric);

knnModel = fitcknn(X_norm, trainLabels, ... 'NumNeighbors', k, ... 'Distance',
                   distMetric, ... 'DistanceWeight', 'squaredinverse',
                   ... 'Standardize', false, ... 'Prior', 'empirical');

% % Cross - validation error estimate try cvModel =
    crossval(knnModel, 'KFold', 5);
model.cvLoss = kfoldLoss(cvModel);
fprintf('5-Fold CV Loss: %.4f\n', model.cvLoss);
catch model.cvLoss = NaN;
end

    % % Store model model.knn = knnModel;
model.normParams = normParams;
model.cfg = cfg;
model.type = 'knn';
model.k = k;

fprintf('=== KNN Training Complete ===\n');
end

    % % Predict using trained KNN function[predictions, scores, probabilities] =
    predictKNN(model, testFeatures) %
    Normalize using training parameters X_norm =
        (testFeatures - model.normParams.mu)./ model.normParams.sigma;
X_norm(isnan(X_norm)) = 0;
X_norm(isinf(X_norm)) = 0;

% Predict with posterior probabilities[predictions, scores_raw] =
    predict(model.knn, X_norm);

    % Scores for attack class (class 1)
    if size(scores_raw, 2) >= 2
        scores = scores_raw(:, 2);
    else scores = scores_raw( :, 1);
    end

        % Posterior probabilities probabilities = scores;
    end
