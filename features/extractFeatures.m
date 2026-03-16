%% FEATURE EXTRACTION MODULE
% Extracts statistical, temporal, and residual-based features for anomaly detection
%
% Features extracted:
%   - Statistical: mean, std, max, min, skewness, kurtosis, range
%   - Temporal: differences, trends, autocorrelation
%   - Residual: state estimation residuals (if H matrix available)
%
% Usage:
%   features = extractFeatures(data, cfg)
%   features = extractFeatures(data, cfg, H)  % With residual features

function [features, featureNames] = extractFeatures(data, cfg, H)
    fprintf('=== Extracting Features ===\n');

[ nSamples, nVars ] = size(data);
windowSize = cfg.windowSize;
nWindows = floor(nSamples / windowSize);

if nWindows
  < 1 error('Not enough samples for window size %d', windowSize);
end

    % Initialize feature storage statFeatures = [];
tempFeatures = [];
resFeatures = [];
featureNames = {};

% %
    Statistical Features(per window) if ismember ('statistical',
                                                  cfg.featureTypes)
        fprintf('  Extracting statistical features...\n');
[ statFeatures, statNames ] = extractStatisticalFeatures(data, windowSize);
featureNames = [ featureNames, statNames ];
end

    % %
    Temporal Features if ismember ('temporal', cfg.featureTypes)
        fprintf('  Extracting temporal features...\n');
[ tempFeatures, tempNames ] = extractTemporalFeatures(data, windowSize);
featureNames = [ featureNames, tempNames ];
end

        % %
        Residual Features(requires H matrix) if ismember ('residual',
                                                          cfg.featureTypes) &&
    nargin >= 3 && ~isempty(H) fprintf('  Extracting residual features...\n');
[ resFeatures, resNames ] = extractResidualFeatures(data, windowSize, H);
featureNames = [ featureNames, resNames ];
end

    % % Combine all features %
    Handle different number of windows from each feature type minWindows =
    min([ size(statFeatures, 1), size(tempFeatures, 1), size(resFeatures, 1) ]);
if isempty (minWindows)
  || minWindows == 0 minWindows = nWindows;
end

    features = [];
if
  ~isempty(statFeatures) features = [
    features, statFeatures(1 : minWindows, :)
  ];
end if ~isempty(tempFeatures) features = [
  features, tempFeatures(1 : minWindows, :)
];
end if ~isempty(resFeatures) features = [
  features, resFeatures(1 : minWindows, :)
];
end

    fprintf('=== Feature Extraction Complete ===\n');
fprintf('Shape: [%d windows x %d features]\n', size(features, 1),
        size(features, 2));
end

    % % Statistical Features function[features, names] =
    extractStatisticalFeatures(data, windowSize)[nSamples, nVars] = size(data);
nWindows = floor(nSamples / windowSize);

% 7 statistical features per variable nFeatPerVar = 7;
features = zeros(nWindows, nVars *nFeatPerVar);
names = {};

    for
      w = 1 : nWindows startIdx = (w - 1) * windowSize + 1;
    endIdx = w * windowSize;
    window = data(startIdx : endIdx, :);

        for
          v = 1 : nVars col = window( :, v);
        baseIdx = (v - 1) * nFeatPerVar;

        features(w, baseIdx + 1) = mean(col);
        features(w, baseIdx + 2) = std(col);
        features(w, baseIdx + 3) = max(col);
        features(w, baseIdx + 4) = min(col);
        features(w, baseIdx + 5) = skewness(col);
        features(w, baseIdx + 6) = kurtosis(col);
        features(w, baseIdx + 7) = max(col) - min(col);
        % Range

                if w ==
            1 names{end + 1} = sprintf('mean_v%d', v);
        names{end + 1} = sprintf('std_v%d', v);
        names{end + 1} = sprintf('max_v%d', v);
        names{end + 1} = sprintf('min_v%d', v);
        names{end + 1} = sprintf('skew_v%d', v);
        names{end + 1} = sprintf('kurt_v%d', v);
        names{end + 1} = sprintf('range_v%d', v);
        end end end

            % Handle NaN / Inf values features(isnan(features)) = 0;
        features(isinf(features)) = 0;
        end

            % % Temporal Features function[features, names] =
            extractTemporalFeatures(data, windowSize)[nSamples, nVars] =
                size(data);
        nWindows = floor(nSamples / windowSize);

        % 5 temporal features per variable nFeatPerVar = 5;
        features = zeros(nWindows, nVars *nFeatPerVar);
        names = {};

    for
      w = 1 : nWindows startIdx = (w - 1) * windowSize + 1;
    endIdx = w * windowSize;
    window = data(startIdx : endIdx, :);

        for
          v = 1 : nVars col = window( :, v);
        baseIdx = (v - 1) * nFeatPerVar;

        % First difference statistics diff1 = diff(col);
        features(w, baseIdx + 1) = mean(abs(diff1));
        features(w, baseIdx + 2) = std(diff1);

        % Trend(linear regression slope) X = (1 : length(col))'; p =
            polyfit(X, col, 1);
        features(w, baseIdx + 3) = p(1);
        % Slope

                % Autocorrelation(lag 1) if length (col) >
            1 acf = autocorr(col, 'NumLags', 1);
        features(w, baseIdx + 4) = acf(2);
        else features(w, baseIdx + 4) = 0;
        end

            % Rate of change(end vs start)
                  features(w, baseIdx + 5) = col(end) - col(1);

        if w
          == 1 names{end + 1} = sprintf('diff_mean_v%d', v);
        names{end + 1} = sprintf('diff_std_v%d', v);
        names{end + 1} = sprintf('trend_v%d', v);
        names{end + 1} = sprintf('acf1_v%d', v);
        names{end + 1} = sprintf('roc_v%d', v);
        end end end

            features(isnan(features)) = 0;
        features(isinf(features)) = 0;
        end

            % %
            Residual
            Features(based on state estimation) function[features, names] =
            extractResidualFeatures(data, windowSize,
                                    H)[nSamples, nVars] = size(data);
        nWindows = floor(nSamples / windowSize);

        [ m, n ] = size(H);

        % 4 residual features per window nFeat = 4;
        features = zeros(nWindows, nFeat);
        names = {'residual_norm', 'residual_max', 'residual_normalized',
                 'state_norm'};

    for
      w = 1 : nWindows startIdx = (w - 1) * windowSize + 1;
    endIdx = w * windowSize;
    window = data(startIdx : endIdx, :);

    % Use mean of window as measurement z =
        mean(window, 1)';

            % Truncate / pad measurement to match H if length (z) >
        m z_est = z(1 : m);
    else z_est = [z; zeros(m - length(z), 1)];
        end
        
        % State estimation: x_hat = (H'H)^-1 H' z
        try
            HtH = H' * H;
            if cond(HtH) < 1e10
                x_hat = HtH \ (H' * z_est);
                
                % Residual: r = z - H*x_hat
                r = z_est - H * x_hat;
                
                features(w, 1) = norm(r);
                features(w, 2) = max(abs(r));
                features(w, 3) = norm(r) / (norm(z_est) + 1e-10);  % Normalized
                features(w, 4) = norm(x_hat);
            else
                features(w, :) = [0, 0, 0, 0];
            end
        catch
            features(w, :) = [0, 0, 0, 0];
        end
    end
    
    features(isnan(features)) = 0;
    features(isinf(features)) = 0;
end

%% Compute window labels from sample labels
function windowLabels = computeWindowLabels(labels, windowSize)
    nSamples = length(labels);
    nWindows = floor(nSamples / windowSize);
    windowLabels = zeros(nWindows, 1);
    
    for w = 1:nWindows
        startIdx = (w-1) * windowSize + 1;
        endIdx = w * windowSize;
        
        % Window is attack if any sample is attack
        windowLabels(w) = max(labels(startIdx:endIdx));
    end
end
