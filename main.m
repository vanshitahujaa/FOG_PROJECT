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
    addpath(genpath(pwd));
    cfg = config();
    rng(cfg.seed);
    if ~exist(cfg.paths.results, 'dir'), mkdir(cfg.paths.results); end
    if ~exist(cfg.paths.models, 'dir'), mkdir(cfg.paths.models); end
    if ~exist(cfg.paths.logs, 'dir'), mkdir(cfg.paths.logs); end
    if ~exist('loadcase', 'file')
        error('MATPOWER not found!');
    end
    fprintf('MATPOWER detected\n');
    fprintf('\n--- STEP 1: Data Generation ---\n');
    [normalData, ~, mpc, meta] = generateNormalData(cfg);
    fprintf('\n--- STEP 2: Computing System Jacobian ---\n');
    [H, ~, info] = computeJacobian(mpc);
    fprintf('H matrix: [%d x %d]\n', size(H, 1), size(H, 2));
    fprintf('\n--- STEP 3: Generating FDIA Attacks ---\n');
    [attackedData, attackLabels, attackInfo] = generateAttackData(normalData, H, cfg);
    allData = [normalData; attackedData];
    allLabels = [zeros(size(normalData, 1), 1); attackLabels];
    nTrain = floor(size(allData, 1) * cfg.trainRatio);
    trainData = allData(1:nTrain, :);
    trainLabels = allLabels(1:nTrain);
    testData = allData(nTrain+1:end, :);
    testLabels = allLabels(nTrain+1:end);
    fprintf('Train: %d samples (%d attacks)\n', nTrain, sum(trainLabels));
    fprintf('Test:  %d samples (%d attacks)\n', size(testData, 1), sum(testLabels));
    fprintf('\n--- STEP 4: Feature Extraction ---\n');
    [trainFeatures, featureNames] = extractFeatures(trainData, cfg, H);
    [testFeatures, ~] = extractFeatures(testData, cfg, H);
    trainWindowLabels = computeWindowLabels(trainLabels, cfg.windowSize);
    testWindowLabels = computeWindowLabels(testLabels, cfg.windowSize);
    fprintf('Train features: [%d x %d]\n', size(trainFeatures, 1), size(trainFeatures, 2));
    fprintf('Test features:  [%d x %d]\n', size(testFeatures, 1), size(testFeatures, 2));
    fprintf('\n--- STEP 5: Training Detection Models (5 Models) ---\n');
    normalTrainFeatures = trainFeatures(trainWindowLabels == 0, :);
    fprintf('\n[1/5] SVM Model\n');
    svmModel = trainSVM(trainFeatures, cfg, trainWindowLabels);
    fprintf('\n[2/5] Autoencoder Model\n');
    aeModel = trainAutoencoder(normalTrainFeatures, cfg);
    fprintf('\n[3/5] Random Forest Model\n');
    rfModel = trainRandomForest(trainFeatures, cfg, trainWindowLabels);
    fprintf('\n[4/5] KNN Model\n');
    knnModel = trainKNN(trainFeatures, cfg, trainWindowLabels);
    fprintf('\n[5/5] PCA Anomaly Detection Model\n');
    pcaModel = trainPCA(normalTrainFeatures, cfg);
    save(fullfile(cfg.paths.models, 'allModels.mat'), 'svmModel', 'aeModel', 'rfModel', 'knnModel', 'pcaModel');
    fprintf('\nAll 5 models trained and saved\n');
    fprintf('\n--- STEP 6: Fog Node Simulation ---\n');
    fogNode = FogNode(svmModel, cfg, H);
    cloud = CloudLayer(cfg);
    fprintf('Processing test data through fog node...\n');
    timestamps = 1:size(testData, 1);
    [fogResults, totalLatency] = fogNode.processBatch(testData, timestamps);
    alerts = fogNode.flushAlerts();
    cloud.receiveAlerts(alerts, 1);
    fogNode.displayStatus();
    cloud.displayStatus();
    fprintf('\n--- STEP 7: Multi-Model Evaluation ---\n');
    fprintf('\n[SVM Evaluation]\n');
    [svmPreds, svmScores, ~] = predictSVM(svmModel, testFeatures);
    svmMetrics = computeMetrics(svmPreds, testWindowLabels, svmScores, fogResults.latencies);
    fprintf('\n[Autoencoder Evaluation]\n');
    [aePreds, aeScores, ~] = predictAutoencoder(aeModel, testFeatures);
    aeMetrics = computeMetrics(aePreds, testWindowLabels, aeScores);
    fprintf('\n[Random Forest Evaluation]\n');
    [rfPreds, rfScores, ~] = predictRandomForest(rfModel, testFeatures);
    rfMetrics = computeMetrics(rfPreds, testWindowLabels, rfScores);
    fprintf('\n[KNN Evaluation]\n');
    [knnPreds, knnScores, ~] = predictKNN(knnModel, testFeatures);
    knnMetrics = computeMetrics(knnPreds, testWindowLabels, knnScores);
    fprintf('\n[PCA Evaluation]\n');
    [pcaPreds, pcaScores, ~] = predictPCA(pcaModel, testFeatures);
    pcaMetrics = computeMetrics(pcaPreds, testWindowLabels, pcaScores);
    fprintf('\n');
    fprintf('================================================================\n');
    fprintf('               MULTI-MODEL COMPARISON TABLE\n');
    fprintf('================================================================\n');
    fprintf('%-15s %8s %8s %8s %8s %8s %6s %6s\n', 'Model', 'Accuracy', 'Precis.', 'Recall', 'F1', 'FAR', 'FP', 'FN');
    fprintf('-------------------------------------------------------------------------------\n');
    allMetrics = {svmMetrics, aeMetrics, rfMetrics, knnMetrics, pcaMetrics};
    modelNames = {'SVM', 'Autoencoder', 'RandomForest', 'KNN', 'PCA'};
    f1Scores = zeros(1, 5);
    for i = 1:5
        m = allMetrics{i};
        f1Scores(i) = m.f1;
        fprintf('%-15s %7.2f%% %7.2f%% %7.2f%%  %6.4f %6.2f%% %5d %5d\n', ...
            modelNames{i}, m.accuracy*100, m.precision*100, m.recall*100, m.f1, m.FAR*100, m.FP, m.FN);
    end
    fprintf('================================================================\n');
    [bestF1, bestIdx] = max(f1Scores);
    fprintf('\nBest Model: %s (F1 = %.4f)\n', modelNames{bestIdx}, bestF1);
    fprintf('\n--- STEP 8: Generating Visualizations ---\n');
    plotResults(svmMetrics, testData, svmPreds, testWindowLabels, cfg, fogResults.latencies);
    plotModelComparison(allMetrics, modelNames, cfg);
    if exist('normalData', 'var') && exist('attackedData', 'var')
        plotAttackComparison(normalData, attackedData, meta, cfg);
    end
    fprintf('\n================================================================\n');
    fprintf('   SUMMARY REPORT\n');
    fprintf('================================================================\n');
    fprintf('IEEE Bus System: %s (%d buses)\n', cfg.busCase, meta.nBuses);
    fprintf('Total Samples: %d\n', size(normalData, 1) + size(attackedData, 1));
    fprintf('Attack Ratio: %.1f%%\n', cfg.attackRatio * 100);
    fprintf('Window Size: %d\n', cfg.windowSize);
    fprintf('\nModel Rankings (by F1-Score):\n');
    [sortedF1, rankIdx] = sort(f1Scores, 'descend');
    for i = 1:5
        m = allMetrics{rankIdx(i)};
        marker = '';
        if i == 1, marker = ' <- BEST'; end
        fprintf('  %d. %-15s  F1=%.4f  Acc=%.2f%%  Prec=%.2f%%  Rec=%.2f%%  FP=%d  FN=%d%s\n', ...
            i, modelNames{rankIdx(i)}, sortedF1(i), m.accuracy*100, m.precision*100, m.recall*100, m.FP, m.FN, marker);
    end
    fprintf('\nFog Layer Performance:\n');
    fprintf('  Avg Latency:  %.2f ms\n', fogNode.stats.avgLatency);
    fprintf('  P95 Latency:  %.2f ms\n', prctile(fogResults.latencies, 95));
    fprintf('  Alerts Sent:  %d\n', fogNode.stats.attacksDetected);
    fprintf('\nResults saved to: %s\n', cfg.paths.results);
    fprintf('\n================================================================\n');
    fprintf('   Pipeline Complete!\n');
    fprintf('================================================================\n');
end
