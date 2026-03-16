%% UNIFIED ANOMALY DETECTION INTERFACE
% Provides unified interface for all detection models
%
% Supported models: svm, autoencoder, randomforest, knn, pca
%
% Usage:
%   [prediction, score] = detectAnomaly(model, features)
%   [prediction, score] = detectAnomaly(model, features, 'svm')

function [prediction, score, details] = detectAnomaly(model, features, modelType)
    % Auto-detect model type if not specified
    if nargin < 3
        if isfield(model, 'svm')
            modelType = 'svm';
elseif isfield(model, 'rf') modelType = 'randomforest';
elseif isfield(model, 'knn') modelType = 'knn';
elseif isfield(model, 'net') ||
    (isfield(model, 'coeff') &&
     isfield(model, 'meanError')) modelType = 'autoencoder';
elseif isfield(model, 'P') && isfield(model, 'T2_threshold') modelType = 'pca';
else error('Unknown model type. Please specify modelType.');
        end
    end
    
    switch lower(modelType)
        case 'svm'
            [prediction, score, prob] = predictSVM(model, features);
            details.probability = prob;
            details.method = 'SVM';
            
        case 'autoencoder'
            [prediction, score, prob] = predictAutoencoder(model, features);
            details.probability = prob;
            details.method = 'Autoencoder';
            details.threshold = model.threshold;
            
        case 'randomforest'
            [prediction, score, prob] = predictRandomForest(model, features);
            details.probability = prob;
            details.method = 'Random Forest';
            
        case 'knn'
            [prediction, score, prob] = predictKNN(model, features);
            details.probability = prob;
            details.method = 'KNN';
            
        case 'pca'
            [prediction, score, prob] = predictPCA(model, features);
            details.probability = prob;
            details.method = 'PCA';
            
        case 'ensemble'
            % Ensemble of multiple models
            [prediction, score, details] = ensembleDetect(model, features);
            
        otherwise
            error('Unknown model type: %s', modelType);
    end
    
    details.type = modelType;
end

%% Ensemble Detection (combines multiple models)
function [prediction, score, details] = ensembleDetect(models, features)
    nModels = length(models);
    predictions = zeros(size(features, 1), nModels);
    scores = zeros(size(features, 1), nModels);
    
    for i = 1:
        nModels[pred, sc, ~] = detectAnomaly(models{i}, features);
        predictions( :, i) = pred;
        scores( :, i) = sc;
    end
    
    % Majority voting for prediction
    prediction = mode(predictions, 2);

    % Average score score = mean(scores, 2);

    details.individualPredictions = predictions;
    details.individualScores = scores;
    details.method = 'Ensemble';
    details.nModels = nModels;
    end

            % % Real -
        time Detection Wrapper function[isAttack, latency, details] =
        realTimeDetect(model, reading, buffer, cfg) % For fog node real -
        time detection tic;

    % Add reading to buffer buffer = [buffer; reading];

    if size (buffer, 1)
      >= cfg.windowSize % Extract features from buffer features =
          extractFeatures(buffer, cfg);

    % Detect[isAttack, score, details] = detectAnomaly(model, features);

    % Take last prediction isAttack = isAttack(end);
    details.score = score(end);
    else isAttack = false;
    details.score = 0;
    details.message = 'Insufficient buffer';
    end

        latency = toc * 1000;
    % Convert to ms details.latency_ms = latency;
    end
