%% RANDOM FOREST-BASED ANOMALY DETECTION
% Trains a Random Forest (TreeBagger) for FDIA detection
%
% Uses an ensemble of decision trees for binary classification.
% Handles class imbalance via cost-sensitive learning.
%
% Usage:
%   model = trainRandomForest(trainFeatures, cfg, trainLabels)

function model = trainRandomForest(trainFeatures, cfg, trainLabels)
    fprintf('=== Training Random Forest Model ===\n');

% Normalize features[X_norm, normParams.mu, normParams.sigma] =
    zscore(trainFeatures);
normParams.sigma(normParams.sigma == 0) = 1;

[ nSamples, nFeatures ] = size(X_norm);
fprintf('Training data: %d samples x %d features\n', nSamples, nFeatures);

% % Handle class imbalance nNormal = sum(trainLabels == 0);
nAttack = sum(trainLabels == 1);
fprintf('Class distribution: %d normal, %d attack\n', nNormal, nAttack);

if nAttack
  > 0 && nNormal > 0 costMatrix = [ 0, nNormal / nAttack; 1, 0 ];
else
  costMatrix = [ 0, 1; 1, 0 ];
end

    % % Train TreeBagger ensemble nTrees = cfg.rf.nTrees;
minLeafSize = cfg.rf.minLeafSize;

fprintf('Configuration: %d trees, min leaf size = %d\n', nTrees, minLeafSize);

rfModel =
    TreeBagger(nTrees, X_norm, trainLabels, ... 'Method', 'classification',
               ... 'MinLeafSize', minLeafSize, ... 'Cost', costMatrix,
               ... 'OOBPrediction', 'on', ... 'OOBPredictorImportance', 'on',
               ... 'NumPredictorsToSample', max(1, floor(sqrt(nFeatures))));

% % Out - of - bag error estimate oobErr = oobError(rfModel);
model.oobError = oobErr(end);
fprintf('Out-of-bag error: %.4f\n', model.oobError);

% % Feature importance model.featureImportance =
    rfModel.OOBPermutedPredictorDeltaError;
[ ~, sortedIdx ] = sort(model.featureImportance, 'descend');
model.topFeatures = sortedIdx(1 : min(10, nFeatures));

fprintf('Top 5 important features: ');
fprintf('%d ', model.topFeatures(1 : min(5, length(model.topFeatures))));
fprintf('\n');

% % Store model model.rf = rfModel;
model.normParams = normParams;
model.cfg = cfg;
model.type = 'randomforest';
model.nTrees = nTrees;

fprintf('=== Random Forest Training Complete ===\n');
end

    % %
    Predict using trained Random Forest
        function[predictions, scores, probabilities] =
    predictRandomForest(model, testFeatures) %
    Normalize using training parameters X_norm =
        (testFeatures - model.normParams.mu)./ model.normParams.sigma;
X_norm(isnan(X_norm)) = 0;
X_norm(isinf(X_norm)) = 0;

% Predict[labels_cell, scores_raw] = predict(model.rf, X_norm);

% Convert cell array to numeric predictions = str2double(labels_cell);

    % Scores for attack class (class 1)
    if size(scores_raw, 2) >= 2
        scores = scores_raw(:, 2);
    else scores = scores_raw( :, 1);
    end

        % Probabilities are directly the scores from TreeBagger probabilities =
        scores;
    end
