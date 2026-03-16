%% LOAD DATASET UTILITIES
% Functions for loading, saving, and preprocessing datasets
%
% Usage:
%   [trainData, testData] = loadDataset(cfg)
%   saveDataset(data, labels, meta, filename)

function [trainData, testData, trainLabels, testLabels, meta] = loadDataset(cfg)
    %% Check if saved data exists
    dataFile = fullfile(cfg.paths.data, 'dataset.mat');

if exist (dataFile, 'file')
  fprintf('Loading existing dataset from %s...\n', dataFile);
loaded = load(dataFile);
trainData = loaded.trainData;
testData = loaded.testData;
trainLabels = loaded.trainLabels;
testLabels = loaded.testLabels;
meta = loaded.meta;
fprintf('Dataset loaded: %d train, %d test samples\n', ... size(trainData, 1),
        size(testData, 1));
else fprintf('No saved dataset found. Generating new data...\n');

% Generate normal data[data, labels, ~, meta] = generateNormalData(cfg);

% Split into train / test nSamples = size(data, 1);
nTrain = floor(nSamples * cfg.trainRatio);

% Shuffle indices rng(cfg.seed);
idx = randperm(nSamples);

trainIdx = idx(1 : nTrain);
testIdx = idx(nTrain + 1 : end);

trainData = data(trainIdx, :);
testData = data(testIdx, :);
trainLabels = labels(trainIdx);
testLabels = labels(testIdx);

        % Save for future use
        saveDataset(trainData, testData, trainLabels, testLabels, meta, dataFile);
        end end

            % %
            Save dataset to file function saveDataset(trainData, testData,
                                                      trainLabels, testLabels,
                                                      meta, filename) %
            Ensure directory exists[filepath, ~, ~] = fileparts(filename);
        if
          ~exist(filepath, 'dir') mkdir(filepath);
        end

            save(filename, 'trainData', 'testData', 'trainLabels', 'testLabels',
                 'meta', '-v7.3');
        fprintf('Dataset saved to %s\n', filename);
        end

            % % Normalize data function[dataNorm, params] =
            normalizeData(data, params) if nargin < 2 ||
            isempty(params) % Compute normalization parameters params.mu =
                mean(data, 1);
        params.sigma = std(data, 0, 1);
        params.sigma(params.sigma == 0) = 1;
        % Avoid division by zero end

                % Z -
            score normalization dataNorm = (data - params.mu)./ params.sigma;
        end

            % % Create sliding windows function[windows, windowLabels] =
            createWindows(data, labels, windowSize, stride) if nargin <
            4 stride = 1;
        end

            [nSamples, nFeatures] = size(data);
        nWindows = floor((nSamples - windowSize) / stride) + 1;

        windows = zeros(nWindows, windowSize, nFeatures);
        windowLabels = zeros(nWindows, 1);

    for
      i = 1 : nWindows startIdx = (i - 1) * stride + 1;
    endIdx = startIdx + windowSize - 1;
    windows(i, :, :) = data(startIdx : endIdx, :);

    % Window is labeled as attack if any sample is an attack windowLabels(i) =
        max(labels(startIdx : endIdx));
    end end

        % %
        Visualize data distribution function visualizeData(data, labels, meta,
                                                           cfg)
            figure('Name', 'Data Distribution', 'Position',
                   [ 100, 100, 1200, 800 ]);

    % Plot voltage magnitudes over time subplot(2, 2, 1);
    nBuses = meta.nBuses;
    plot(data( :, 1 : nBuses));
    title('Voltage Magnitudes Over Time');
    xlabel('Sample');
    ylabel('Voltage (p.u.)');
    legend(meta.featureNames(1 : min(5, nBuses)), 'Location', 'best');
    grid on;

    % Plot power flows subplot(2, 2, 2);
    P_start = 2 * nBuses + 1;
    P_end = 3 * nBuses;
    plot(data( :, P_start : P_end));
    title('Active Power Demand Over Time');
    xlabel('Sample');
    ylabel('Power (MW)');
    grid on;

    % Histogram of voltage magnitudes subplot(2, 2, 3);
    histogram(data( :, 1 : nBuses), 50);
    title('Distribution of Voltage Magnitudes');
    xlabel('Voltage (p.u.)');
    ylabel('Frequency');
    grid on;

    % Label distribution subplot(2, 2, 4);
    labelCounts = [ sum(labels == 0), sum(labels == 1) ];
    bar([ 0, 1 ], labelCounts);
    title('Label Distribution');
    xlabel('Class (0=Normal, 1=Attack)');
    ylabel('Count');
    xticklabels({'Normal', 'Attack'});
    grid on;

    % Save plot if cfg.eval.savePlots if ~exist(cfg.eval.outputDir, 'dir')
            mkdir(cfg.eval.outputDir);
    end saveas(gcf, fullfile(cfg.eval.outputDir, 'data_distribution.png'));
    fprintf('Saved data distribution plot to %s\n', cfg.eval.outputDir);
    end end
