function main(mode)
    if nargin < 1
        mode = 'full';
    end
    fprintf('\n');
    fprintf('================================================================\n');
    fprintf('   FOG-ASSISTED FDIA DETECTION SYSTEM FOR SMART GRID\n');
    fprintf('   4-Layer Consensus + Blockchain Pipeline v2\n');
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

    % ======================================================================
    % STEP 1: Data Generation (10K+ samples)
    % ======================================================================
    fprintf('\n--- STEP 1: Data Generation (%d samples) ---\n', cfg.nSamples);
    [normalData, ~, mpc, meta] = generateNormalData(cfg);

    % ======================================================================
    % STEP 2: System Jacobian
    % ======================================================================
    fprintf('\n--- STEP 2: Computing System Jacobian ---\n');
    [H, ~, info] = computeJacobian(mpc);
    fprintf('H matrix: [%d x %d]\n', size(H, 1), size(H, 2));

    % ======================================================================
    % STEP 3: FDIA Attack Injection (contiguous bursts, gradual onset)
    % ======================================================================
    fprintf('\n--- STEP 3: Generating FDIA Attacks ---\n');
    [attackedData, attackLabels, attackInfo] = generateAttackData(normalData, H, cfg);
    allData = attackedData;
    allLabels = attackLabels;
    fprintf('Dataset: %d samples (%d attacks, %d normal)\n', ...
        size(allData, 1), sum(allLabels), sum(allLabels == 0));

    % ======================================================================
    % STEP 4: LAYER 1 — Sensor Physics Consensus + Data Correction
    % ======================================================================
    fprintf('\n--- STEP 4: Layer 1 — Sensor Physics Consensus + Correction ---\n');
    [trustTags, consensusScores, correctedData, consensusDetails] = sensorConsensus(allData, mpc, cfg);

    % Initialize Trust Manager and Blockchain
    trustMgr = TrustManager(meta.nBuses);
    ledger = BlockchainLedger();
    trustMgr.updateTrust(trustTags, consensusScores);
    ledger.logTrustUpdate(trustMgr.trustScores, 'Initial sensor consensus');
    ledger.mineBlock();
    trustMgr.displayStatus();

    % ======================================================================
    % STEP 5: Feature Extraction on CORRECTED data
    % ======================================================================
    fprintf('\n--- STEP 5: Feature Extraction (on physics-corrected data) ---\n');
    % USE correctedData instead of raw allData — this is the innovation
    [allFeatures, featureNames] = extractFeatures(correctedData, cfg, H);
    allWindowLabels = computeWindowLabels(allLabels, cfg.windowSize);

    % Append consensus features (3 features per window)
    nWindows = size(allFeatures, 1);
    consensusFeats = zeros(nWindows, 3);
    for w = 1:nWindows
        startIdx = w;
        endIdx = min(w + cfg.windowSize - 1, size(trustTags, 1));
        windowTags = trustTags(startIdx:endIdx, :);
        windowScores = consensusScores(startIdx:endIdx, :);
        consensusFeats(w, 1) = mean(windowTags(:));
        consensusFeats(w, 2) = max(windowScores(:));
        consensusFeats(w, 3) = sum(any(windowTags, 1));
    end
    allFeatures = [allFeatures, consensusFeats];
    fprintf('Features: %d windows x %d dims (incl. 3 consensus)\n', size(allFeatures, 1), size(allFeatures, 2));

    % ======================================================================
    % STEP 6: Train / Validation / Test Split (60/15/25)
    % ======================================================================
    fprintf('\n--- STEP 6: Train/Validation/Test Split ---\n');
    shuffleIdx = randperm(nWindows);
    allFeatures = allFeatures(shuffleIdx, :);
    allWindowLabels = allWindowLabels(shuffleIdx);

    nTrain = floor(nWindows * 0.60);
    nVal = floor(nWindows * 0.15);
    trainFeatures = allFeatures(1:nTrain, :);
    trainLabels = allWindowLabels(1:nTrain);
    valFeatures = allFeatures(nTrain+1:nTrain+nVal, :);
    valLabels = allWindowLabels(nTrain+1:nTrain+nVal);
    testFeatures = allFeatures(nTrain+nVal+1:end, :);
    testLabels = allWindowLabels(nTrain+nVal+1:end);

    fprintf('Train:      %d windows (%d attack, %d normal)\n', nTrain, sum(trainLabels==1), sum(trainLabels==0));
    fprintf('Validation: %d windows (%d attack, %d normal)\n', nVal, sum(valLabels==1), sum(valLabels==0));
    fprintf('Test:       %d windows (%d attack, %d normal)\n', length(testLabels), sum(testLabels==1), sum(testLabels==0));

    % ======================================================================
    % STEP 7: LAYER 2 — ML Model Training
    % ======================================================================
    fprintf('\n--- STEP 7: Layer 2 — Training 5 ML Models ---\n');
    normalTrainFeatures = trainFeatures(trainLabels == 0, :);
    fprintf('\n[1/5] SVM Model\n');
    svmModel = trainSVM(trainFeatures, cfg, trainLabels);
    fprintf('\n[2/5] Autoencoder Model\n');
    aeModel = trainAutoencoder(normalTrainFeatures, cfg);
    fprintf('\n[3/5] Random Forest Model\n');
    rfModel = trainRandomForest(trainFeatures, cfg, trainLabels);
    fprintf('\n[4/5] KNN Model\n');
    knnModel = trainKNN(trainFeatures, cfg, trainLabels);
    fprintf('\n[5/5] PCA Anomaly Detection Model\n');
    pcaModel = trainPCA(normalTrainFeatures, cfg);
    save(fullfile(cfg.paths.models, 'allModels.mat'), 'svmModel', 'aeModel', 'rfModel', 'knnModel', 'pcaModel');
    fprintf('\nAll 5 models trained and saved\n');

    % ======================================================================
    % STEP 8: Validation-Set Predictions (for stacking + threshold tuning)
    % ======================================================================
    fprintf('\n--- STEP 8: Validation Set Predictions ---\n');
    modelNames = {'SVM', 'Autoencoder', 'RandomForest', 'KNN', 'PCA'};

    [valSvmP, valSvmS, ~] = predictSVM(svmModel, valFeatures);
    [valAeP, valAeS, ~] = predictAutoencoder(aeModel, valFeatures);
    [valRfP, valRfS, ~] = predictRandomForest(rfModel, valFeatures);
    [valKnnP, valKnnS, ~] = predictKNN(knnModel, valFeatures);
    [valPcaP, valPcaS, ~] = predictPCA(pcaModel, valFeatures);

    valPreds = [valSvmP(:), valAeP(:), valRfP(:), valKnnP(:), valPcaP(:)];
    valScoresM = [valSvmS(:), valAeS(:), valRfS(:), valKnnS(:), valPcaS(:)];

    % Train stacking classifier on validation set
    fprintf('\n--- Training Stacking Classifier on Validation Set ---\n');
    [~, ~, stackModel] = stackingClassifier(valPreds, valScoresM, modelNames, valLabels, 'train', []);

    % Also tune model consensus threshold on validation set
    fprintf('\n--- Tuning Consensus Threshold on Validation Set ---\n');
    [~, ~, ~] = modelConsensus(valPreds, valScoresM, modelNames, valLabels);

    % ======================================================================
    % STEP 9: Test-Set Evaluation
    % ======================================================================
    fprintf('\n--- STEP 9: Test Set Evaluation ---\n');
    nTest = length(testLabels);

    fprintf('\n[SVM Evaluation]\n');
    [svmPreds, svmScores, ~] = predictSVM(svmModel, testFeatures);
    svmMetrics = computeMetrics(svmPreds, testLabels, svmScores);
    fprintf('\n[Autoencoder Evaluation]\n');
    [aePreds, aeScores, ~] = predictAutoencoder(aeModel, testFeatures);
    aeMetrics = computeMetrics(aePreds, testLabels, aeScores);
    fprintf('\n[Random Forest Evaluation]\n');
    [rfPreds, rfScores, ~] = predictRandomForest(rfModel, testFeatures);
    rfMetrics = computeMetrics(rfPreds, testLabels, rfScores);
    fprintf('\n[KNN Evaluation]\n');
    [knnPreds, knnScores, ~] = predictKNN(knnModel, testFeatures);
    knnMetrics = computeMetrics(knnPreds, testLabels, knnScores);
    fprintf('\n[PCA Evaluation]\n');
    [pcaPreds, pcaScores, ~] = predictPCA(pcaModel, testFeatures);
    pcaMetrics = computeMetrics(pcaPreds, testLabels, pcaScores);

    % ======================================================================
    % STEP 10: LAYER 3 — Model Consensus + Stacking on Test Set
    % ======================================================================
    fprintf('\n--- STEP 10: Layer 3 — Consensus + Stacking on Test Set ---\n');
    testPreds = [svmPreds(:), aePreds(:), rfPreds(:), knnPreds(:), pcaPreds(:)];
    testScoresM = [svmScores(:), aeScores(:), rfScores(:), knnScores(:), pcaScores(:)];

    % Weighted voting consensus
    [consensusPreds, consensusScoresOut, ~] = modelConsensus(testPreds, testScoresM, modelNames, testLabels);
    fprintf('\n[Consensus Evaluation]\n');
    consensusMetrics = computeMetrics(consensusPreds, testLabels, consensusScoresOut);

    % Stacking meta-classifier
    fprintf('\n[Stacking Evaluation]\n');
    [stackPreds, stackScores, ~] = stackingClassifier(testPreds, testScoresM, modelNames, testLabels, 'predict', stackModel);
    stackMetrics = computeMetrics(stackPreds, testLabels, stackScores);

    % ======================================================================
    % STEP 11: LAYER 4 — Blockchain Logging
    % ======================================================================
    fprintf('\n--- STEP 11: Layer 4 — Blockchain Audit Logging ---\n');
    batchSize = 20;
    for i = 1:nTest
        modelVotes = testPreds(i, :);
        ledger.logDetection(i, [], modelVotes, modelNames, stackPreds(i), trustMgr.trustScores);
        if mod(i, batchSize) == 0
            ledger.mineBlock();
        end
    end
    if ~isempty(ledger.pendingData)
        ledger.mineBlock();
    end
    ledger.logTrustUpdate(trustMgr.trustScores, 'Post-evaluation trust state');
    ledger.mineBlock();
    ledger.displayStatus();

    % ======================================================================
    % STEP 12: Fog Node Simulation
    % ======================================================================
    fprintf('\n--- STEP 12: Fog Node Simulation ---\n');
    fogNode = FogNode(svmModel, cfg, H);
    cloud = CloudLayer(cfg);
    fogTestData = allData(floor(size(allData,1)*0.7)+1:end, :);
    timestamps = 1:size(fogTestData, 1);
    [fogResults, totalLatency] = fogNode.processBatch(fogTestData, timestamps);
    alerts = fogNode.flushAlerts();
    cloud.receiveAlerts(alerts, 1);
    fogNode.displayStatus();
    cloud.displayStatus();

    % ======================================================================
    % RESULTS: Full Comparison Table (7 rows: 5 models + consensus + stacking)
    % ======================================================================
    fprintf('\n');
    fprintf('================================================================\n');
    fprintf('     FULL COMPARISON TABLE (Individual + Consensus + Stacking)\n');
    fprintf('================================================================\n');
    fprintf('%-15s %8s %8s %8s %8s %8s %6s %6s\n', 'Model', 'Accuracy', 'Precis.', 'Recall', 'F1', 'FAR', 'FP', 'FN');
    fprintf('-------------------------------------------------------------------------------\n');
    allMetrics = {svmMetrics, aeMetrics, rfMetrics, knnMetrics, pcaMetrics, consensusMetrics, stackMetrics};
    allModelNames = {'SVM', 'Autoencoder', 'RandomForest', 'KNN', 'PCA', 'CONSENSUS', 'STACKING'};
    f1Scores = zeros(1, 7);
    for i = 1:7
        m = allMetrics{i};
        f1Scores(i) = m.f1;
        prefix = '';
        if i >= 6, prefix = '>> '; end
        fprintf('%s%-15s %7.2f%% %7.2f%% %7.2f%%  %6.4f %6.2f%% %5d %5d\n', ...
            prefix, allModelNames{i}, m.accuracy*100, m.precision*100, m.recall*100, m.f1, m.FAR*100, m.FP, m.FN);
    end
    fprintf('================================================================\n');

    % Improvement analysis
    bestIndF1 = max(f1Scores(1:5));
    stackF1 = f1Scores(7);
    improvePct = ((stackF1 - bestIndF1) / max(bestIndF1, 0.01)) * 100;
    fprintf('\nStacking F1: %.4f (%+.1f%% vs best individual model)\n', stackF1, improvePct);

    % ======================================================================
    % Visualizations
    % ======================================================================
    fprintf('\n--- STEP 13: Generating Visualizations ---\n');
    plotResults(svmMetrics, correctedData, svmPreds, testLabels, cfg, fogResults.latencies);
    plotModelComparison(allMetrics, allModelNames, cfg);
    if exist('normalData', 'var') && exist('attackedData', 'var')
        plotAttackComparison(normalData, attackedData, meta, cfg);
    end

    % ======================================================================
    % SUMMARY REPORT
    % ======================================================================
    fprintf('\n================================================================\n');
    fprintf('   SUMMARY REPORT\n');
    fprintf('================================================================\n');
    fprintf('IEEE Bus System: %s (%d buses)\n', cfg.busCase, meta.nBuses);
    fprintf('Total Samples: %d\n', size(allData, 1));
    fprintf('Attack Ratio: %.1f%%\n', cfg.attackRatio * 100);
    fprintf('Window Size: %d\n', cfg.windowSize);
    fprintf('Data Correction: %d suspicious values replaced via Kirchhoff\n', consensusDetails.nCorrected);
    fprintf('\nArchitecture: 4-Layer Consensus + Blockchain\n');
    fprintf('  Layer 1: Sensor Physics Consensus + Data Correction (PBFT)\n');
    fprintf('  Layer 2: 5 ML Models (SVM, AE, RF, KNN, PCA)\n');
    fprintf('  Layer 3: Stacking Meta-Classifier (Logistic Regression)\n');
    fprintf('  Layer 4: Blockchain Audit Ledger (FNV-1a 256-bit)\n');
    fprintf('\nModel Rankings (by F1-Score):\n');
    [sortedF1, rankIdx] = sort(f1Scores, 'descend');
    for i = 1:7
        m = allMetrics{rankIdx(i)};
        marker = '';
        if i == 1, marker = ' <- BEST'; end
        fprintf('  %d. %-15s  F1=%.4f  Acc=%.2f%%  Prec=%.2f%%  Rec=%.2f%%  FP=%d  FN=%d%s\n', ...
            i, allModelNames{rankIdx(i)}, sortedF1(i), m.accuracy*100, m.precision*100, m.recall*100, m.FP, m.FN, marker);
    end
    fprintf('\nBlockchain: %d blocks, chain integrity = %s\n', ...
        length(ledger.chain), mat2str(ledger.verifyChain()));
    fprintf('\nFog Layer Performance:\n');
    fprintf('  Avg Latency:  %.2f ms\n', fogNode.stats.avgLatency);
    fprintf('  P95 Latency:  %.2f ms\n', prctile(fogResults.latencies, 95));
    fprintf('  Alerts Sent:  %d\n', fogNode.stats.attacksDetected);
    fprintf('\nResults saved to: %s\n', cfg.paths.results);
    fprintf('\n================================================================\n');
    fprintf('   Pipeline Complete!\n');
    fprintf('================================================================\n');
end
