%% EVALUATION METRICS
% Computes all evaluation metrics for FDIA detection
%
% Metrics:
%   - Accuracy, Precision, Recall, F1-Score
%   - False Alarm Rate (FAR), Miss Detection Rate
%   - AUC-ROC, AUC-PR
%   - Confusion Matrix
%   - Detection Latency
%
% Usage:
%   metrics = computeMetrics(predictions, labels)
%   metrics = computeMetrics(predictions, labels, scores)  % For ROC

function metrics = computeMetrics(predictions, labels, scores, latencies)
    fprintf('=== Computing Evaluation Metrics ===\n');

% Ensure column vectors predictions = predictions( :);
labels = labels( :);

% Remove NaN values validIdx = ~isnan(predictions) & ~isnan(labels);
predictions = predictions(validIdx);
labels = labels(validIdx);

n = length(labels);

% % Confusion Matrix TP = sum(predictions == 1 & labels == 1);
% True Positives TN = sum(predictions == 0 & labels == 0);
% True Negatives FP = sum(predictions == 1 & labels == 0);
% False Positives FN = sum(predictions == 0 & labels == 1);
% False Negatives

        metrics.confusionMatrix = [ TN, FP; FN, TP ];
metrics.TP = TP;
metrics.TN = TN;
metrics.FP = FP;
metrics.FN = FN;

% % Basic Metrics metrics.accuracy = (TP + TN) / n;

if (TP + FP)
  > 0 metrics.precision = TP / (TP + FP);
else
  metrics.precision = 0;
end

    if (TP + FN) > 0 metrics.recall = TP / (TP + FN);
% Also called Detection Rate else metrics.recall = 0;
end

    if (TN + FP) > 0 metrics.specificity = TN / (TN + FP);
else metrics.specificity = 0;
end

    % False Alarm Rate(FAR) metrics.FAR = 1 - metrics.specificity;
% FP / (FP + TN)

    % Miss Detection Rate metrics.missDetectionRate = 1 - metrics.recall;
% FN / (FN + TP)

        % F1 Score if (metrics.precision + metrics.recall) >
    0 metrics.f1 = 2 * (metrics.precision * metrics.recall) /
                   (metrics.precision + metrics.recall);
else metrics.f1 = 0;
end

    % Balanced Accuracy metrics.balancedAccuracy =
    (metrics.recall + metrics.specificity) / 2;

% Matthews Correlation Coefficient denom =
    sqrt((TP + FP) * (TP + FN) * (TN + FP) * (TN + FN));
if denom
  > 0 metrics.mcc = ((TP * TN) - (FP * FN)) / denom;
else
  metrics.mcc = 0;
end

            % % ROC Curve(if scores provided) if nargin
        >= 3 &&
    ~isempty(scores) scores = scores(validIdx);

[ X, Y, T, AUC ] = perfcurve(labels, scores, 1);
metrics.roc.fpr = X;
metrics.roc.tpr = Y;
metrics.roc.thresholds = T;
metrics.aucROC = AUC;

% Precision - Recall curve[prec, rec, ~] =
    perfcurve(labels, scores, 1, 'XCrit', 'reca', 'YCrit', 'prec');
metrics.pr.precision = prec;
metrics.pr.recall = rec;
metrics.aucPR = trapz(rec, prec);
end

            % % Latency Metrics(if provided) if nargin
        >= 4 &&
    ~isempty(latencies) metrics.latency.mean = mean(latencies);
metrics.latency.std = std(latencies);
metrics.latency.min = min(latencies);
metrics.latency.max = max(latencies);
metrics.latency.p50 = median(latencies);
metrics.latency.p95 = prctile(latencies, 95);
metrics.latency.p99 = prctile(latencies, 99);
end

    % % Print Summary fprintf('\n--- Classification Metrics ---\n');
fprintf('Accuracy:     %.4f (%.2f%%)\n', metrics.accuracy,
        metrics.accuracy * 100);
fprintf('Precision:    %.4f (%.2f%%)\n', metrics.precision,
        metrics.precision * 100);
fprintf('Recall:       %.4f (%.2f%%)\n', metrics.recall, metrics.recall * 100);
fprintf('F1-Score:     %.4f\n', metrics.f1);
fprintf('Specificity:  %.4f (%.2f%%)\n', metrics.specificity,
        metrics.specificity * 100);
fprintf('FAR:          %.4f (%.2f%%)\n', metrics.FAR, metrics.FAR * 100);
fprintf('Balanced Acc: %.4f\n', metrics.balancedAccuracy);
fprintf('MCC:          %.4f\n', metrics.mcc);

if isfield (metrics, 'aucROC')
  fprintf('AUC-ROC:      %.4f\n', metrics.aucROC);
end

    if isfield (metrics, 'latency') fprintf('\n--- Latency Metrics (ms) ---\n');
fprintf('Mean:   %.2f ms\n', metrics.latency.mean);
fprintf('P95:    %.2f ms\n', metrics.latency.p95);
fprintf('Max:    %.2f ms\n', metrics.latency.max);
end

    fprintf('\n--- Confusion Matrix ---\n');
fprintf('                 Predicted\n');
fprintf('              Normal  Attack\n');
fprintf('Actual Normal  %5d   %5d\n', TN, FP);
fprintf('       Attack  %5d   %5d\n', FN, TP);

fprintf('\n=== Metrics Computation Complete ===\n');
end

    % % Compare multiple models function comparison =
    compareModels(models, testFeatures, testLabels, modelNames) nModels =
        length(models);
comparison = struct();

fprintf('\n=== Model Comparison ===\n');

    for
      i = 1 : nModels model = models{i};
    name = modelNames{i};

    fprintf('\nEvaluating %s...\n', name);
    [ pred, scores, ~] = detectAnomaly(model, testFeatures);
    metrics = computeMetrics(pred, testLabels, scores);

    comparison.(name) = metrics;
    end

        % Summary table fprintf('\n--- Summary Comparison ---\n');
    fprintf('%-15s %8s %8s %8s %8s %8s\n', 'Model', 'Acc', 'Prec', 'Recall',
            'F1', 'FAR');
    fprintf('%s\n', repmat('-', 1, 60));

    for
      i = 1 : nModels name = modelNames{i};
    m = comparison.(name);
    fprintf('%-15s %8.4f %8.4f %8.4f %8.4f %8.4f\n', ... name, m.accuracy,
            m.precision, m.recall, m.f1, m.FAR);
    end end
