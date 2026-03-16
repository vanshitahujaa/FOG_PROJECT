%% SVM-BASED ANOMALY DETECTION
% Trains One-Class SVM or Binary SVM for FDIA detection
%
% One-Class SVM: Train on normal data only (unsupervised)
% Binary SVM: Train on normal + attack data (supervised)
%
% Usage:
%   model = trainSVM(trainFeatures, cfg)                    % One-class
%   model = trainSVM(trainFeatures, cfg, trainLabels)       % Binary

function model = trainSVM(trainFeatures, cfg, trainLabels)
    fprintf('=== Training SVM Model ===\n');

% Normalize features[X_norm, normParams.mu, normParams.sigma] =
    zscore(trainFeatures);
normParams.sigma(normParams.sigma == 0) = 1;
% Avoid div by zero

            if nargin <
        3 ||
    isempty(trainLabels) ||
    all(trainLabels == 0) % % One - Class
        SVM(Anomaly Detection)
            fprintf('Training One-Class SVM (unsupervised)...\n');

        % Create synthetic "outlier" class for one-class learning
        nSamples = size(X_norm, 1);

        % Train using fitcsvm with one class svmModel =
            fitcsvm(X_norm, ones(nSamples, 1), ... 'KernelFunction',
                    cfg.svm.kernelFunction, ... 'KernelScale',
                    cfg.svm.kernelScale, ... 'Standardize', false,
                    ... 'OutlierFraction', cfg.svm.outlierFraction);

        model.type = 'oneclass';
        model.svm = svmModel;

        % Compute scores on training data for threshold
        [~, scores] = predict(svmModel, X_norm);
        model.trainScores = scores( :, 1);
        model.threshold =
            prctile(model.trainScores, cfg.svm.outlierFraction * 100);

        else % %
            Binary SVM(Supervised Classification)
                fprintf('Training Binary SVM (supervised)...\n');

        % Handle class imbalance nNormal = sum(trainLabels == 0);
        nAttack = sum(trainLabels == 1);

        if nAttack
          > 0 && nNormal > 0 weights = ones(length(trainLabels), 1);
        weights(trainLabels == 1) = nNormal / nAttack;
        % Upsample minority else weights = ones(length(trainLabels), 1);
        end

            svmModel = fitcsvm(X_norm, trainLabels, ... 'KernelFunction',
                               cfg.svm.kernelFunction, ... 'KernelScale',
                               cfg.svm.kernelScale, ... 'Standardize', false,
                               ... 'Weights', weights, ... 'BoxConstraint', 1);

        model.type = 'binary';
        model.svm = svmModel;
        model.threshold = 0;
        % Decision boundary end

                model.normParams = normParams;
        model.cfg = cfg;

        % Cross - validation error estimate try cvModel =
            crossval(svmModel, 'KFold', 5);
        model.cvLoss = kfoldLoss(cvModel);
        fprintf('5-Fold CV Loss: %.4f\n', model.cvLoss);
        catch model.cvLoss = NaN;
        end

            fprintf('=== SVM Training Complete ===\n');
        end

            % %
            Predict using trained SVM
                function[predictions, scores, probabilities] =
            predictSVM(model, testFeatures) %
            Normalize using training parameters X_norm =
                (testFeatures - model.normParams.mu)./ model.normParams.sigma;

        % Handle NaN / Inf X_norm(isnan(X_norm)) = 0;
        X_norm(isinf(X_norm)) = 0;

        % Predict[labels, scores_raw] = predict(model.svm, X_norm);

        if strcmp (model.type, 'oneclass')
          % One - class : negative score = anomaly scores = scores_raw( :, 1);
        predictions = double(scores < model.threshold);
        else % Binary : direct classification predictions = labels;
        scores = scores_raw( :, 2);  % Score for class 1 (attack)
    end
    
    % Convert scores to probabilities using sigmoid
    probabilities = 1 ./ (1 + exp(-scores));
        end

            % % Hyperparameter Tuning function bestModel =
            tuneSVMHyperparameters(trainFeatures, trainLabels, cfg)
                fprintf('=== Tuning SVM Hyperparameters ===\n');

        % Parameter grid kernelScales = [ 0.1, 0.5, 1, 2, 5, 10 ];
        boxConstraints = [ 0.1, 1, 10, 100 ];

        bestLoss = Inf;
        bestModel = [];

    for ks = kernelScales
        for bc = boxConstraints
            cfgTune = cfg;
    cfgTune.svm.kernelScale = ks;
    cfgTune.svm.boxConstraint = bc;

    try model = trainSVM(trainFeatures, cfgTune, trainLabels);

    if model
      .cvLoss < bestLoss bestLoss = model.cvLoss;
    bestModel = model;
    fprintf('  New best: KS=%.1f, BC=%.1f, Loss=%.4f\n', ks, bc, bestLoss);
    end catch ME fprintf('  Failed: KS=%.1f, BC=%.1f (%s)\n', ks, bc,
                         ME.message);
    end end end

        if isempty (bestModel)
            warning('Hyperparameter tuning failed. Using default parameters.');
    bestModel = trainSVM(trainFeatures, cfg, trainLabels);
    end

        fprintf('Best hyperparameters: KS=%.1f, BC=%.1f\n',
                ... bestModel.cfg.svm.kernelScale,
                bestModel.cfg.svm.boxConstraint);
    end
