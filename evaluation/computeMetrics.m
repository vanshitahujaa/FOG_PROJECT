function metrics = computeMetrics(predictions, labels, scores, latencies)
    fprintf('=== Computing Metrics ===\n');
    predictions = predictions(:);
    labels = labels(:);
    validIdx = ~isnan(predictions) & ~isnan(labels);
    predictions = predictions(validIdx);
    labels = labels(validIdx);
    n = length(labels);
    TP = sum(predictions == 1 & labels == 1);
    TN = sum(predictions == 0 & labels == 0);
    FP = sum(predictions == 1 & labels == 0);
    FN = sum(predictions == 0 & labels == 1);
    metrics.confusionMatrix = [TN, FP; FN, TP];
    metrics.TP = TP;
    metrics.TN = TN;
    metrics.FP = FP;
    metrics.FN = FN;
    metrics.accuracy = (TP + TN) / max(n, 1);
    if (TP + FP) > 0
        metrics.precision = TP / (TP + FP);
    else
        metrics.precision = 0;
    end
    if (TP + FN) > 0
        metrics.recall = TP / (TP + FN);
    else
        metrics.recall = 0;
    end
    if (TN + FP) > 0
        metrics.specificity = TN / (TN + FP);
    else
        metrics.specificity = 0;
    end
    metrics.FAR = 1 - metrics.specificity;
    if (metrics.precision + metrics.recall) > 0
        metrics.f1 = 2 * (metrics.precision * metrics.recall) / (metrics.precision + metrics.recall);
    else
        metrics.f1 = 0;
    end
    metrics.balancedAccuracy = (metrics.recall + metrics.specificity) / 2;
    denom = sqrt(double((TP+FP)) * double((TP+FN)) * double((TN+FP)) * double((TN+FN)));
    if denom > 0
        metrics.mcc = (double(TP*TN) - double(FP*FN)) / denom;
    else
        metrics.mcc = 0;
    end
    if nargin >= 3 && ~isempty(scores)
        scores = scores(validIdx);
        metrics.aucROC = manualAUC(labels, scores);
    else
        metrics.aucROC = 0.5;
    end
    if nargin >= 4 && ~isempty(latencies)
        metrics.latency.mean = mean(latencies);
        metrics.latency.std = std(latencies);
        metrics.latency.p95 = prctile_manual(latencies, 95);
        metrics.latency.max = max(latencies);
    end
    fprintf('Acc=%.2f%% Prec=%.2f%% Rec=%.2f%% F1=%.4f FAR=%.2f%% AUC=%.4f\n', ...
        metrics.accuracy*100, metrics.precision*100, metrics.recall*100, ...
        metrics.f1, metrics.FAR*100, metrics.aucROC);
    fprintf('CM: TP=%d TN=%d FP=%d FN=%d\n', TP, TN, FP, FN);
end

function auc = manualAUC(labels, scores)
    [~, sortIdx] = sort(scores, 'descend');
    sortedLabels = labels(sortIdx);
    nPos = sum(labels == 1);
    nNeg = sum(labels == 0);
    if nPos == 0 || nNeg == 0
        auc = 0.5;
        return;
    end
    tpr_prev = 0;
    fpr_prev = 0;
    auc = 0;
    tp = 0;
    fp = 0;
    for i = 1:length(sortedLabels)
        if sortedLabels(i) == 1
            tp = tp + 1;
        else
            fp = fp + 1;
        end
        tpr = tp / nPos;
        fpr = fp / nNeg;
        auc = auc + (fpr - fpr_prev) * (tpr + tpr_prev) / 2;
        tpr_prev = tpr;
        fpr_prev = fpr;
    end
end

function val = prctile_manual(data, p)
    data = sort(data);
    n = length(data);
    idx = max(1, min(n, round(p/100 * n)));
    val = data(idx);
end
