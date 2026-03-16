%% FOG-ASSISTED FDIA DETECTION SYSTEM - MAIN SCRIPT
% Complete pipeline for False Data Injection Attack detection
% 
% Author: Vanshit Ahuja
% Date: February 2026
%
% This script orchestrates the entire detection pipeline:
%   1. Data generation (IEEE bus system)
%   2. FDIA attack injection
%   3. Feature extraction
%   4. Model training (SVM + Autoencoder)
%   5. Fog node simulation
%   6. Performance evaluation
%
% Requirements:
%   - MATPOWER (https://matpower.org/)
%   - Statistics and Machine Learning Toolbox
%   - (Optional) Deep Learning Toolbox for Autoencoder
%
% Usage:
%   >> main                     % Run full pipeline
%   >> main('skipDataGen')      % Skip data generation if already done
%   >> main('modelOnly')        % Only train models
%   >> main('evalOnly')         % Only evaluate (requires saved models)

function main(mode)
    if nargin < 1
        mode = 'full';
    end
    
    fprintf('\n');
    fprintf('================================================================\n');
    fprintf('   FOG-ASSISTED FDIA DETECTION SYSTEM FOR SMART GRID\n');
    fprintf('================================================================\n');
    fprintf('\n');
    
    %% Initialize
    addpath(genpath(pwd));  % Add all subdirectories to path
    cfg = config();
    rng(cfg.seed);  % Set random seed for reproducibility
    
    % Create output directories
    if ~exist(cfg.paths.results, 'dir'), mkdir(cfg.paths.results); end
    if ~exist(cfg.paths.models, 'dir'), mkdir(cfg.paths.models); end
    if ~exist(cfg.paths.logs, 'dir'), mkdir(cfg.paths.logs); end
    
    %% Check MATPOWER installation
    if ~exist('loadcase', 'file')
        error(['MATPOWER not found! Please install from:\n' ...
               'https://matpower.org/\n' ...
               'And add to MATLAB path: addpath(''path/to/matpower'')']);
    end
    fprintf('✓ MATPOWER detected\n');
    
    %% Step 1: Data Generation
    if ~strcmp(mode, 'evalOnly') && ~strcmp(mode, 'modelOnly')
        fprintf('\n--- STEP 1: Data Generation ---\n');
        
        dataFile = fullfile(cfg.paths.data, 'dataset.mat');
        
        if exist(dataFile, 'file') && ~strcmp(mode, 'full')
            fprintf('Loading existing dataset...\n');
            load(dataFile, 'normalData', 'meta', 'mpc');
        else
            [normalData, ~, mpc, meta] = generateNormalData(cfg);
            save(dataFile, 'normalData', 'meta', 'mpc', '-v7.3');
        end
        
        fprintf('Data shape: [%d samples x %d features]\n', size(normalData));
    else
        fprintf('\n--- Skipping data generation (loading existing) ---\n');
        load(fullfile(cfg.paths.data, 'dataset.mat'));
    end
    
    %% Step 2: Compute Jacobian Matrix
    fprintf('\n--- STEP 2: Computing System Jacobian ---\n');
    [H, ~, info] = computeJacobian(mpc);
    fprintf('H matrix: [%d x %d]\n', size(H, 1), size(H, 2));
    
    %% Step 3: Generate Attack Data
    if ~strcmp(mode, 'evalOnly')
        fprintf('\n--- STEP 3: Generating FDIA Attacks ---\n');
        [attackedData, attackLabels, attackInfo] = generateAttackData(normalData, H, cfg);
        
        % Combine normal and attacked data
        allData = [normalData; attackedData];
        allLabels = [zeros(size(normalData, 1), 1); attackLabels];
        
        % Shuffle
        idx = randperm(size(allData, 1));
        allData = allData(idx, :);
        allLabels = allLabels(idx);
        
        % Split train/test
        nTrain = floor(size(allData, 1) * cfg.trainRatio);
        trainData = allData(1:nTrain, :);
        trainLabels = allLabels(1:nTrain);
        testData = allData(nTrain+1:end, :);
        testLabels = allLabels(nTrain+1:end);
        
        fprintf('Train: %d samples (%d attacks)\n', nTrain, sum(trainLabels));
        fprintf('Test:  %d samples (%d attacks)\n', size(testData, 1), sum(testLabels));
        
        % Save
        save(fullfile(cfg.paths.data, 'train_test.mat'), ...
            'trainData', 'trainLabels', 'testData', 'testLabels', 'meta');
    else
        load(fullfile(cfg.paths.data, 'train_test.mat'));
    end
    
    %% Step 4: Feature Extraction
    fprintf('\n--- STEP 4: Feature Extraction ---\n');
    
    [trainFeatures, featureNames] = extractFeatures(trainData, cfg, H);
    [testFeatures, ~] = extractFeatures(testData, cfg, H);
    
    % Compute window labels
    trainWindowLabels = computeWindowLabels(trainLabels, cfg.windowSize);
    testWindowLabels = computeWindowLabels(testLabels, cfg.windowSize);
    
    fprintf('Train features: [%d x %d]\n', size(trainFeatures));
    fprintf('Test features:  [%d x %d]\n', size(testFeatures));
    
    %% Step 5: Train Detection Models
    if ~strcmp(mode, 'evalOnly')
        fprintf('\n--- STEP 5: Training Detection Models ---\n');
        
        % Get normal training data only for unsupervised methods
        normalTrainFeatures = trainFeatures(trainWindowLabels == 0, :);
        
        % Train SVM
        fprintf('\n[SVM Model]\n');
        svmModel = trainSVM(trainFeatures, cfg, trainWindowLabels);
        
        % Train Autoencoder
        fprintf('\n[Autoencoder Model]\n');
        aeModel = trainAutoencoder(normalTrainFeatures, cfg);
        
        % Save models
        save(fullfile(cfg.paths.models, 'svmModel.mat'), 'svmModel');
        save(fullfile(cfg.paths.models, 'aeModel.mat'), 'aeModel');
    else
        load(fullfile(cfg.paths.models, 'svmModel.mat'));
        load(fullfile(cfg.paths.models, 'aeModel.mat'));
    end
    
    %% Step 6: Fog Node Simulation
    fprintf('\n--- STEP 6: Fog Node Simulation ---\n');
    
    % Initialize fog node with SVM model
    fogNode = FogNode(svmModel, cfg, H);
    
    % Initialize cloud layer
    cloud = CloudLayer(cfg);
    
    % Process test readings through fog node
    fprintf('Processing test data through fog node...\n');
    timestamps = 1:size(testData, 1);
    [fogResults, totalLatency] = fogNode.processBatch(testData, timestamps);
    
    % Sync alerts to cloud
    alerts = fogNode.flushAlerts();
    cloud.receiveAlerts(alerts, 1);
    
    % Display status
    fogNode.displayStatus();
    cloud.displayStatus();
    
    %% Step 7: Evaluate Models
    fprintf('\n--- STEP 7: Model Evaluation ---\n');
    
    % SVM Evaluation
    fprintf('\n[SVM Evaluation]\n');
    [svmPreds, svmScores, ~] = predictSVM(svmModel, testFeatures);
    svmMetrics = computeMetrics(svmPreds, testWindowLabels, svmScores, fogResults.latencies);
    
    % Autoencoder Evaluation
    fprintf('\n[Autoencoder Evaluation]\n');
    [aePreds, aeScores, ~] = predictAutoencoder(aeModel, testFeatures);
    aeMetrics = computeMetrics(aePreds, testWindowLabels, aeScores);
    
    % Compare models
    fprintf('\n[Model Comparison]\n');
    fprintf('%-15s %8s %8s %8s %8s\n', 'Model', 'Acc', 'Prec', 'Recall', 'F1');
    fprintf('%s\n', repmat('-', 1, 55));
    fprintf('%-15s %8.4f %8.4f %8.4f %8.4f\n', 'SVM', ...
        svmMetrics.accuracy, svmMetrics.precision, svmMetrics.recall, svmMetrics.f1);
    fprintf('%-15s %8.4f %8.4f %8.4f %8.4f\n', 'Autoencoder', ...
        aeMetrics.accuracy, aeMetrics.precision, aeMetrics.recall, aeMetrics.f1);
    
    %% Step 8: Generate Visualizations
    fprintf('\n--- STEP 8: Generating Visualizations ---\n');
    
    plotResults(svmMetrics, testData, svmPreds, testWindowLabels, cfg, fogResults.latencies);
    
    if exist('normalData', 'var') && exist('attackedData', 'var')
        plotAttackComparison(normalData, attackedData, meta, cfg);
    end
    
    %% Summary Report
    fprintf('\n');
    fprintf('================================================================\n');
    fprintf('   SUMMARY REPORT\n');
    fprintf('================================================================\n');
    fprintf('\n');
    fprintf('System Configuration:\n');
    fprintf('  IEEE Bus System: %s (%d buses)\n', cfg.busCase, meta.nBuses);
    fprintf('  Total Samples: %d\n', size(normalData, 1) + size(attackedData, 1));
    fprintf('  Attack Ratio: %.1f%%\n', cfg.attackRatio * 100);
    fprintf('  Window Size: %d\n', cfg.windowSize);
    fprintf('\n');
    fprintf('Best Model Performance (SVM):\n');
    fprintf('  Accuracy:     %.2f%%\n', svmMetrics.accuracy * 100);
    fprintf('  Precision:    %.2f%%\n', svmMetrics.precision * 100);
    fprintf('  Recall:       %.2f%%\n', svmMetrics.recall * 100);
    fprintf('  F1-Score:     %.4f\n', svmMetrics.f1);
    fprintf('  False Alarm:  %.2f%%\n', svmMetrics.FAR * 100);
    fprintf('\n');
    fprintf('Fog Layer Performance:\n');
    fprintf('  Avg Latency:  %.2f ms\n', fogNode.stats.avgLatency);
    fprintf('  P95 Latency:  %.2f ms\n', prctile(fogResults.latencies, 95));
    fprintf('  Alerts Sent:  %d\n', fogNode.stats.attacksDetected);
    fprintf('\n');
    fprintf('Results saved to: %s\n', cfg.paths.results);
    fprintf('Models saved to: %s\n', cfg.paths.models);
    fprintf('\n');
    fprintf('================================================================\n');
    fprintf('   Pipeline Complete!\n');
    fprintf('================================================================\n');
end

%% Quick Demo Function
function demo()
    fprintf('Running quick demo with reduced dataset...\n');
    
    cfg = config();
    cfg.nSamples = 500;  % Smaller dataset for demo
    cfg.ae.maxEpochs = 50;  % Faster training
    
    % Override config function temporarily
    % (In practice, you'd modify config.m)
    
    main('full');
end
