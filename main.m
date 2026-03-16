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
%   4. Model training (SVM, Autoencoder, Random Forest, KNN, PCA)
%   5. Fog node simulation
%   6. Multi-model comparison and evaluation
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
    fprintf('   5-Model Comparison Pipeline\n');
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
    
    %% Step 5: Train All Detection Models
    if ~strcmp(mode, 'evalOnly')
        fprintf('\n--- STEP 5: Training Detection Models (5 Models) ---\n');
        
        % Get normal training data only for unsupervised methods
        normalTrainFeatures = trainFeatures(trainWindowLabels == 0, :);
        
        % ----- Model 1: SVM -----
        fprintf('\n[1/5] SVM Model\n');
        svmModel = trainSVM(trainFeatures, cfg, trainWindowLabels);
        
        % ----- Model 2: Autoencoder -----
        fprintf('\n[2/5] Autoencoder Model\n');
        aeModel = trainAutoencoder(normalTrainFeatures, cfg);
        
        % ----- Model 3: Random Forest -----
        fprintf('\n[3/5] Random Forest Model\n');
        rfModel = trainRandomForest(trainFeatures, cfg, trainWindowLabels);
        
        % ----- Model 4: KNN -----
        fprintf('\n[4/5] KNN Model\n');
        knnModel = trainKNN(trainFeatures, cfg, trainWindowLabels);
        
        % ----- Model 5: PCA -----
        fprintf('\n[5/5] PCA Anomaly Detection Model\n');
        pcaModel = trainPCA(normalTrainFeatures, cfg);
        
        % Save all models
        save(fullfile(cfg.paths.models, 'svmModel.mat'), 'svmModel');
        save(fullfile(cfg.paths.models, 'aeModel.mat'), 'aeModel');
        save(fullfile(cfg.paths.models, 'rfModel.mat'), 'rfModel');
        save(fullfile(cfg.paths.models, 'knnModel.mat'), 'knnModel');
        save(fullfile(cfg.paths.models, 'pcaModel.mat'), 'pcaModel');
        
        fprintf('\n✓ All 5 models trained and saved\n');
    else
        load(fullfile(cfg.paths.models, 'svmModel.mat'));
        load(fullfile(cfg.paths.models, 'aeModel.mat'));
        load(fullfile(cfg.paths.models, 'rfModel.mat'));
        load(fullfile(cfg.paths.models, 'knnModel.mat'));
        load(fullfile(cfg.paths.models, 'pcaModel.mat'));
    end
    
    %% Step 6: Fog Node Simulation
    fprintf('\n--- STEP 6: Fog Node Simulation ---\n');
    
    % Initialize fog node with SVM model (primary detector)
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
    
    %% Step 7: Evaluate All Models
    fprintf('\n--- STEP 7: Multi-Model Evaluation ---\n');
    
    % SVM Evaluation
    fprintf('\n[SVM Evaluation]\n');
    [svmPreds, svmScores, ~] = predictSVM(svmModel, testFeatures);
    svmMetrics = computeMetrics(svmPreds, testWindowLabels, svmScores, fogResults.latencies);
    
    % Autoencoder Evaluation
    fprintf('\n[Autoencoder Evaluation]\n');
    [aePreds, aeScores, ~] = predictAutoencoder(aeModel, testFeatures);
    aeMetrics = computeMetrics(aePreds, testWindowLabels, aeScores);
    
    % Random Forest Evaluation
    fprintf('\n[Random Forest Evaluation]\n');
    [rfPreds, rfScores, ~] = predictRandomForest(rfModel, testFeatures);
    rfMetrics = computeMetrics(rfPreds, testWindowLabels, rfScores);
    
    % KNN Evaluation
    fprintf('\n[KNN Evaluation]\n');
    [knnPreds, knnScores, ~] = predictKNN(knnModel, testFeatures);
    knnMetrics = computeMetrics(knnPreds, testWindowLabels, knnScores);
    
    % PCA Evaluation
    fprintf('\n[PCA Evaluation]\n');
    [pcaPreds, pcaScores, ~] = predictPCA(pcaModel, testFeatures);
    pcaMetrics = computeMetrics(pcaPreds, testWindowLabels, pcaScores);
    
    %% Multi-Model Comparison Table
    fprintf('\n');
    fprintf('╔══════════════════════════════════════════════════════════════════════╗\n');
    fprintf('║                    MULTI-MODEL COMPARISON TABLE                     ║\n');
    fprintf('╠═════════════════╤══════════╤══════════╤══════════╤══════════╤═══════╣\n');
    fprintf('║ Model           │ Accuracy │ Precis.  │ Recall   │ F1-Score │ FAR   ║\n');
    fprintf('╠═════════════════╪══════════╪══════════╪══════════╪══════════╪═══════╣\n');
    
    allMetrics = {svmMetrics, aeMetrics, rfMetrics, knnMetrics, pcaMetrics};
    modelNames = {'SVM', 'Autoencoder', 'Random Forest', 'KNN', 'PCA'};
    
    f1Scores = zeros(1, 5);
    for i = 1:5
        m = allMetrics{i};
        f1Scores(i) = m.f1;
        fprintf('║ %-15s │ %6.2f%%  │ %6.2f%%  │ %6.2f%%  │ %6.4f  │%5.2f%% ║\n', ...
            modelNames{i}, m.accuracy*100, m.precision*100, m.recall*100, m.f1, m.FAR*100);
    end
    
    fprintf('╚═════════════════╧══════════╧══════════╧══════════╧══════════╧═══════╝\n');
    
    % Identify best model
    [bestF1, bestIdx] = max(f1Scores);
    fprintf('\n🏆 Best Model: %s (F1 = %.4f)\n', modelNames{bestIdx}, bestF1);
    
    %% Step 8: Generate Visualizations
    fprintf('\n--- STEP 8: Generating Visualizations ---\n');
    
    plotResults(svmMetrics, testData, svmPreds, testWindowLabels, cfg, fogResults.latencies);
    
    % Multi-model comparison plot
    plotModelComparison(allMetrics, modelNames, cfg);
    
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
    fprintf('Model Rankings (by F1-Score):\n');
    [sortedF1, rankIdx] = sort(f1Scores, 'descend');
    for i = 1:5
        m = allMetrics{rankIdx(i)};
        marker = '';
        if i == 1, marker = ' ← BEST'; end
        fprintf('  %d. %-15s  F1=%.4f  Acc=%.2f%%  Prec=%.2f%%  Rec=%.2f%%%s\n', ...
            i, modelNames{rankIdx(i)}, sortedF1(i), ...
            m.accuracy*100, m.precision*100, m.recall*100, marker);
    end
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

%% Multi-model comparison bar chart
function plotModelComparison(allMetrics, modelNames, cfg)
    figure('Name', 'Multi-Model Comparison', 'Position', [100, 100, 900, 500]);
    
    nModels = length(allMetrics);
    metricLabels = {'Accuracy', 'Precision', 'Recall', 'F1-Score', 'Specificity'};
    data = zeros(nModels, 5);
    
    for i = 1:nModels
        m = allMetrics{i};
        data(i, :) = [m.accuracy, m.precision, m.recall, m.f1, m.specificity];
    end
    
    b = bar(data, 'grouped');
    
    % Color scheme
    colors = [0.2 0.4 0.8; 0.9 0.3 0.3; 0.3 0.7 0.3; 0.9 0.6 0.1; 0.6 0.3 0.7];
    for i = 1:min(5, length(b))
        b(i).FaceColor = colors(i, :);
    end
    
    set(gca, 'XTickLabel', modelNames);
    ylabel('Score');
    title('Multi-Model Detection Performance Comparison', 'FontSize', 14);
    legend(metricLabels, 'Location', 'southoutside', 'Orientation', 'horizontal');
    ylim([0, 1.15]);
    grid on;
    
    if cfg.eval.savePlots
        saveas(gcf, fullfile(cfg.eval.outputDir, 'model_comparison.png'));
    end
end
