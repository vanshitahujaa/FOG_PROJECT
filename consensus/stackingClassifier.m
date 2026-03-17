function [stackPreds, stackScores, stackInfo] = stackingClassifier(allPreds, allScores, modelNames, labels, mode, trainedModel)
% STACKINGCLASSIFIER  Stacking meta-classifier using logistic regression.
%   In 'train' mode: trains a logistic regression on model outputs.
%   In 'predict' mode: uses trainedModel to predict.
%
%   Features: 5 model predictions + 5 model scores = 10 features
%   Target: true labels
%   Method: simple logistic regression (sigmoid on weighted sum)

    [nSamples, nModels] = size(allPreds);

    % Build meta-features: [pred1, pred2, ..., score1, score2, ...]
    metaFeatures = [allPreds, allScores];

    if strcmp(mode, 'train')
        fprintf('=== Training Stacking Classifier ===\n');
        fprintf('Meta-features: %d samples x %d features\n', nSamples, size(metaFeatures, 2));

        % Simple logistic regression via gradient descent
        nFeats = size(metaFeatures, 2);
        weights = zeros(nFeats, 1);
        bias = 0;
        lr = 0.1;
        nIter = 500;

        % Normalize meta-features
        mu = mean(metaFeatures, 1);
        sigma = std(metaFeatures, 0, 1);
        sigma(sigma < 1e-8) = 1;
        X = (metaFeatures - mu) ./ sigma;

        y = labels(:);

        for iter = 1:nIter
            z = X * weights + bias;
            pred = 1 ./ (1 + exp(-z));  % Sigmoid
            pred = max(min(pred, 1 - 1e-10), 1e-10);

            % Binary cross-entropy gradient
            error = pred - y;
            gradW = (X' * error) / nSamples;
            gradB = mean(error);

            % L2 regularization
            lambda = 0.01;
            gradW = gradW + lambda * weights;

            weights = weights - lr * gradW;
            bias = bias - lr * gradB;
        end

        % Final training predictions
        z = X * weights + bias;
        trainProbs = 1 ./ (1 + exp(-z));

        % Find optimal threshold on training data
        bestF1 = 0;
        bestThresh = 0.5;
        for th = 0.2:0.02:0.8
            preds = double(trainProbs > th);
            tp = sum(preds == 1 & y == 1);
            fp = sum(preds == 1 & y == 0);
            fn = sum(preds == 0 & y == 1);
            prec = tp / max(tp + fp, 1);
            rec = tp / max(tp + fn, 1);
            if (prec + rec) > 0
                f1 = 2 * prec * rec / (prec + rec);
            else
                f1 = 0;
            end
            if f1 > bestF1
                bestF1 = f1;
                bestThresh = th;
            end
        end

        % Store trained model
        stackInfo.weights = weights;
        stackInfo.bias = bias;
        stackInfo.mu = mu;
        stackInfo.sigma = sigma;
        stackInfo.threshold = bestThresh;
        stackInfo.trainF1 = bestF1;
        stackPreds = double(trainProbs > bestThresh);
        stackScores = trainProbs;

        fprintf('Optimal threshold: %.2f (train F1=%.4f)\n', bestThresh, bestF1);
        fprintf('=== Stacking Classifier Trained ===\n');

    elseif strcmp(mode, 'predict')
        % Use trained model to predict
        X = (metaFeatures - trainedModel.mu) ./ trainedModel.sigma;
        z = X * trainedModel.weights + trainedModel.bias;
        stackScores = 1 ./ (1 + exp(-z));
        stackPreds = double(stackScores > trainedModel.threshold);
        stackInfo = trainedModel;

        fprintf('Stacking predictions: %d attack, %d normal (threshold=%.2f)\n', ...
            sum(stackPreds == 1), sum(stackPreds == 0), trainedModel.threshold);
    end
end
