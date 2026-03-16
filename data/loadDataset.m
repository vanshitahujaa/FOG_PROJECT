%% LOAD DATASET UTILITIES
% Functions for loading, saving, and preprocessing datasets

function [trainData, testData, trainLabels, testLabels, meta] = loadDataset(cfg)
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

[ data, labels, ~, meta ] = generateNormalData(cfg);

nSamples = size(data, 1);
nTrain = floor(nSamples * cfg.trainRatio);

rng(cfg.seed);
idx = randperm(nSamples);

trainIdx = idx(1 : nTrain);
testIdx = idx(nTrain + 1 : end);

trainData = data(trainIdx, :);
testData = data(testIdx, :);
trainLabels = labels(trainIdx);
testLabels = labels(testIdx);

saveDataset(trainData, testData, trainLabels, testLabels, meta, dataFile);
end end

    % %
    Save dataset to file function
        saveDataset(trainData, testData, trainLabels, testLabels, meta,
                    filename)[filepath, ~, ~] = fileparts(filename);
if
  ~exist(filepath, 'dir') mkdir(filepath);
end

    save(filename, 'trainData', 'testData', 'trainLabels', 'testLabels', 'meta',
         '-v7.3');
fprintf('Dataset saved to %s\n', filename);
end

    % % Normalize data function[dataNorm, params] =
    normalizeData(data, params) if nargin < 2 || isempty(params) params.mu =
        mean(data, 1);
params.sigma = std(data, 0, 1);
params.sigma(params.sigma == 0) = 1;
end

    dataNorm = (data - params.mu)./ params.sigma;
end

    % % Create sliding windows function[windows, windowLabels] =
    createWindows(data, labels, windowSize, stride) if nargin < 4 stride = 1;
end

    [nSamples, nFeatures] = size(data);
nWindows = floor((nSamples - windowSize) / stride) + 1;

windows = zeros(nWindows, windowSize, nFeatures);
windowLabels = zeros(nWindows, 1);

    for
      i = 1 : nWindows startIdx = (i - 1) * stride + 1;
    endIdx = startIdx + windowSize - 1;
    windows(i, :, :) = data(startIdx : endIdx, :);
    windowLabels(i) = max(labels(startIdx : endIdx));
    end end
