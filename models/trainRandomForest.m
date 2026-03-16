function model = trainRandomForest(trainFeatures, cfg, trainLabels)
    fprintf('=== Training Random Forest (Decision Stump Ensemble) ===\n');
    [X_norm, mu, sigma] = manualZscore(trainFeatures);
    model.normParams.mu = mu;
    model.normParams.sigma = sigma;
    [nSamples, nFeatures] = size(X_norm);
    fprintf('Data: %d samples x %d features\n', nSamples, nFeatures);
    nTrees = cfg.rf.nTrees;
    model.stumps = struct('featureIdx', {}, 'threshold', {}, 'leftClass', {}, 'rightClass', {});
    rng(cfg.seed);
    for t = 1:nTrees
        bagIdx = randi([1, nSamples], [nSamples, 1]);
        X_bag = X_norm(bagIdx, :);
        y_bag = trainLabels(bagIdx);
        rp = randperm(nFeatures); featIdx = rp(1:max(1, floor(sqrt(nFeatures))));
        bestGini = Inf;
        bestFeat = featIdx(1);
        bestThresh = 0;
        bestLeft = 0;
        bestRight = 0;
        for f = featIdx(:)'
            vals = sort(unique(X_bag(:, f)));
            if length(vals) < 2
                continue;
            end
            thresholds = (vals(1:end-1) + vals(2:end)) / 2;
            if length(thresholds) > 10
                thresholds = thresholds(round(linspace(1, length(thresholds), 10)'));
            end
            thresholds = thresholds(:);
            for th = thresholds(:)'
                leftIdx = X_bag(:, f) <= th;
                rightIdx = ~leftIdx;
                nL = sum(leftIdx);
                nR = sum(rightIdx);
                if nL == 0 || nR == 0
                    continue;
                end
                pL1 = sum(y_bag(leftIdx) == 1) / nL;
                pR1 = sum(y_bag(rightIdx) == 1) / nR;
                giniL = 1 - pL1^2 - (1-pL1)^2;
                giniR = 1 - pR1^2 - (1-pR1)^2;
                gini = (nL * giniL + nR * giniR) / (nL + nR);
                if gini < bestGini
                    bestGini = gini;
                    bestFeat = f;
                    bestThresh = th;
                    bestLeft = double(pL1 > 0.5);
                    bestRight = double(pR1 > 0.5);
                end
            end
        end
        stump.featureIdx = bestFeat;
        stump.threshold = bestThresh;
        stump.leftClass = bestLeft;
        stump.rightClass = bestRight;
        model.stumps(t) = stump;
    end
    model.rf = true;
    model.nTrees = nTrees;
    model.cfg = cfg;
    model.type = 'randomforest';
    oobPreds = zeros(nSamples, 1);
    oobCounts = zeros(nSamples, 1);
    rng(cfg.seed);
    for t = 1:nTrees
        bagIdx = randi([1, nSamples], [nSamples, 1]);
        oobIdx = setdiff(1:nSamples, unique(bagIdx));
        if ~isempty(oobIdx)
            s = model.stumps(t);
            pred = double(X_norm(oobIdx, s.featureIdx) > s.threshold);
            pred(pred == 0) = s.leftClass;
            pred(pred == 1) = s.rightClass;
            oobPreds(oobIdx(:)) = oobPreds(oobIdx(:)) + pred(:);
            oobCounts(oobIdx(:)) = oobCounts(oobIdx(:)) + 1;
        end
    end
    validOob = oobCounts > 0;
    if any(validOob)
        oobFinal = double(oobPreds(validOob) ./ oobCounts(validOob) > 0.5);
        model.oobError = mean(oobFinal ~= trainLabels(validOob));
    else
        model.oobError = NaN;
    end
    fprintf('OOB Error: %.4f\n', model.oobError);
    fprintf('=== Random Forest Training Complete ===\n');
end
