function [finalPreds, finalScores, ensembleMetrics] = modelConsensus(allPreds, allScores, modelNames, trueLabels)
% MODELCONSENSUS  Weighted majority vote across multiple ML models.
%   Uses dynamic weights based on each model's rolling F1 performance.
%   allPreds: [nSamples x nModels] matrix of predictions
%   allScores: [nSamples x nModels] matrix of anomaly scores
%   trueLabels: [nSamples x 1] (used for dynamic weight updating)

    [nSamples, nModels] = size(allPreds);
    fprintf('=== Model Consensus (Weighted Voting) ===\n');
    fprintf('Models: %d, Samples: %d\n', nModels, nSamples);

    % Initialize equal weights
    weights = ones(1, nModels) / nModels;

    % Dynamic weight update: evaluate each model's F1 on a rolling basis
    % Use first 30% of data to calibrate weights, then apply to rest
    calibrationEnd = floor(nSamples * 0.3);

    if calibrationEnd > 10 && ~isempty(trueLabels)
        calLabels = trueLabels(1:calibrationEnd);
        calPreds = allPreds(1:calibrationEnd, :);

        f1Scores = zeros(1, nModels);
        for m = 1:nModels
            mp = calPreds(:, m);
            tp = sum(mp == 1 & calLabels == 1);
            fp = sum(mp == 1 & calLabels == 0);
            fn = sum(mp == 0 & calLabels == 1);
            prec = tp / max(tp + fp, 1);
            rec = tp / max(tp + fn, 1);
            if (prec + rec) > 0
                f1Scores(m) = 2 * prec * rec / (prec + rec);
            else
                f1Scores(m) = 0.01;
            end
        end

        % Weights proportional to F1 (softmax-like normalization)
        f1Scores = max(f1Scores, 0.01);  % Floor to avoid zero weights
        weights = f1Scores / sum(f1Scores);
    end

    fprintf('Dynamic Weights:\n');
    for m = 1:nModels
        fprintf('  %-15s: %.4f\n', modelNames{m}, weights(m));
    end

    % Weighted voting
    finalPreds = zeros(nSamples, 1);
    finalScores = zeros(nSamples, 1);

    for i = 1:nSamples
        votes = allPreds(i, :);
        scores = allScores(i, :);

        weightedVote = sum(weights .* votes);
        weightedScore = sum(weights .* scores);

        finalPreds(i) = double(weightedVote > 0.5);
        finalScores(i) = weightedScore;
    end

    % Compute ensemble metrics
    ensembleMetrics.weights = weights;
    ensembleMetrics.nAttackPreds = sum(finalPreds == 1);
    ensembleMetrics.nNormalPreds = sum(finalPreds == 0);
    ensembleMetrics.avgScore = mean(finalScores);

    fprintf('Consensus Results: %d attacks, %d normal\n', ...
        ensembleMetrics.nAttackPreds, ensembleMetrics.nNormalPreds);
    fprintf('=== Model Consensus Complete ===\n');
end
