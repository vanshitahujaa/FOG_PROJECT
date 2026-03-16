function [features, featureNames] = extractFeatures(data, cfg, H)
    [nSamples, nVars] = size(data);
    windowSize = cfg.windowSize;
    nWindows = floor(nSamples / windowSize);
    if nWindows < 1
        nWindows = 1;
        windowSize = nSamples;
    end
    allFeatures = [];
    featureNames = {};
    if ismember('statistical', cfg.featureTypes)
        nFeatPerVar = 7;
        statFeat = zeros(nWindows, nVars * nFeatPerVar);
        for w = 1:nWindows
            s1 = (w-1) * windowSize + 1;
            s2 = min(w * windowSize, nSamples);
            win = data(s1:s2, :);
            for v = 1:nVars
                col = win(:, v);
                bi = (v-1) * nFeatPerVar;
                statFeat(w, bi+1) = mean(col);
                statFeat(w, bi+2) = std(col);
                statFeat(w, bi+3) = max(col);
                statFeat(w, bi+4) = min(col);
                n = length(col);
                mu = mean(col);
                s = std(col);
                if s > 0 && n > 2
                    statFeat(w, bi+5) = (1/n) * sum(((col - mu)/s).^3);
                    statFeat(w, bi+6) = (1/n) * sum(((col - mu)/s).^4);
                else
                    statFeat(w, bi+5) = 0;
                    statFeat(w, bi+6) = 0;
                end
                statFeat(w, bi+7) = max(col) - min(col);
            end
        end
        statFeat(isnan(statFeat)) = 0;
        statFeat(isinf(statFeat)) = 0;
        allFeatures = [allFeatures, statFeat];
    end
    if ismember('temporal', cfg.featureTypes)
        nFeatPerVar = 5;
        tempFeat = zeros(nWindows, nVars * nFeatPerVar);
        for w = 1:nWindows
            s1 = (w-1) * windowSize + 1;
            s2 = min(w * windowSize, nSamples);
            win = data(s1:s2, :);
            for v = 1:nVars
                col = win(:, v);
                bi = (v-1) * nFeatPerVar;
                d1 = diff(col);
                if isempty(d1)
                    d1 = 0;
                end
                tempFeat(w, bi+1) = mean(abs(d1));
                tempFeat(w, bi+2) = std(d1);
                X = (1:length(col))';
                if length(col) > 1
                    p = polyfit(X, col, 1);
                    tempFeat(w, bi+3) = p(1);
                else
                    tempFeat(w, bi+3) = 0;
                end
                if length(col) > 2
                    col_centered = col - mean(col);
                    c0 = sum(col_centered.^2);
                    if c0 > 0
                        c1 = sum(col_centered(1:end-1) .* col_centered(2:end));
                        tempFeat(w, bi+4) = c1 / c0;
                    else
                        tempFeat(w, bi+4) = 0;
                    end
                else
                    tempFeat(w, bi+4) = 0;
                end
                tempFeat(w, bi+5) = col(end) - col(1);
            end
        end
        tempFeat(isnan(tempFeat)) = 0;
        tempFeat(isinf(tempFeat)) = 0;
        allFeatures = [allFeatures, tempFeat];
    end
    if ismember('residual', cfg.featureTypes) && nargin >= 3 && ~isempty(H)
        [m, n] = size(H);
        nFeat = 4;
        resFeat = zeros(nWindows, nFeat);
        for w = 1:nWindows
            s1 = (w-1) * windowSize + 1;
            s2 = min(w * windowSize, nSamples);
            win = data(s1:s2, :);
            z = mean(win, 1)';
            if length(z) > m
                z_est = z(1:m);
            else
                z_est = [z; zeros(m - length(z), 1)];
            end
            try
                HtH = H' * H;
                if cond(HtH) < 1e10
                    x_hat = HtH \ (H' * z_est);
                    r = z_est - H * x_hat;
                    resFeat(w, 1) = norm(r);
                    resFeat(w, 2) = max(abs(r));
                    resFeat(w, 3) = norm(r) / (norm(z_est) + 1e-10);
                    resFeat(w, 4) = norm(x_hat);
                end
            catch
            end
        end
        resFeat(isnan(resFeat)) = 0;
        resFeat(isinf(resFeat)) = 0;
        allFeatures = [allFeatures, resFeat];
    end
    features = allFeatures;
end
