function main(mode)
    if nargin < 1
        mode = 'full';
    end
    fprintf('\n');
    fprintf('================================================================\n');
    fprintf('   FOG-ASSISTED FDIA DETECTION SYSTEM FOR SMART GRID\n');
    fprintf('   4-Layer Consensus + Blockchain Pipeline\n');
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
    % STEP 1: Data Generation
    % ======================================================================
    fprintf('\n--- STEP 1: Data Generation ---\n');
    [normalData, ~, mpc, meta] = generateNormalData(cfg);

    % ======================================================================
    % STEP 2: System Jacobian
    % ======================================================================
    fprintf('\n--- STEP 2: Computing System Jacobian ---\n');
    [H, ~, info] = computeJacobian(mpc);
    fprintf('H matrix: [%d x %d]\n', size(H, 1), size(H, 2));

    % ======================================================================
    % STEP 3: FDIA Attack Injection
    % ======================================================================
    fprintf('\n--- STEP 3: Generating FDIA Attacks ---\n');
    [attackedData, attackLabels, attackInfo] = generateAttackData(normalData, H, cfg);
    allData = attackedData;
    allLabels = attackLabels;
    fprintf('Dataset: %d samples (%d attacks, %d normal)\n', ...
        size(allData, 1), sum(allLabels), sum(allLabels == 0));

    % ======================================================================
    % STEP 4: LAYER 1 — Sensor-Level Physics Consensus (PBFT)
    % ======================================================================
    fprintf('\n--- STEP 4: Layer 1 — Sensor Physics Consensus (PBFT) ---\n');
    [trustTags, consensusScores, consensusDetails] = sensorConsensus(allData, mpc, cfg);

    % Initialize Trust Manager and Blockchain
    trustMgr = TrustManager(meta.nBuses);
    ledger = BlockchainLedger();

    % Update trust scores based on consensus results
    trustMgr.updateTrust(trustTags, consensusScores);
    ledger.logTrustUpdate(trustMgr.trustScores, 'Initial sensor consensus');
    ledger.mineBlock();

    trustMgr.displayStatus();

    % ======================================================================
    % STEP 5: Feature Extraction (with consensus features)
    % ======================================================================
    fprintf('\n--- STEP 5: Feature Extraction (+ Consensus Features) ---\n');
    [allFeatures, featureNames] = extractFeatures(allData, cfg, H);
    allWindowLabels = computeWindowLabels(allLabels, cfg.windowSize);

    % Append per-window consensus features
    % For each window, compute: mean trust tag, max consensus score, num suspicious buses
    nWindows = size(allFeatures, 1);
    consensusFeatures = zeros(nWindows, 3);
    for w = 1:nWindows
        startIdx = w;
        endIdx = min(w + cfg.windowSize - 1, size(trustTags, 1));
        windowTags = trustTags(startIdx:endIdx, :);
        windowScores = consensusScores(startIdx:endIdx, :);
        consensusFeatures(w, 1) = mean(windowTags(:));        % Avg suspicious rate
        consensusFeatures(w, 2) = max(windowScores(:));        % Max anomaly score
        consensusFeatures(w, 3) = sum(any(windowTags, 1));     % Num suspicious buses
    end
    % Append consensus features to ML input
    allFeatures = [allFeatures, consensusFeatures];
    fprintf('Added 3 consensus features (total: %d features per window)\n', size(allFeatures, 2));

    % Shuffle at window level and split
    shuffleIdx = randperm(nWindows);
    allFeatures = allFeatures(shuffleIdx, :);
    allWindowLabels = allWindowLabels(shuffleIdx);
    nTrain = floor(nWindows * cfg.trainRatio);
    trainFeatures = allFeatures(1:nTrain, :);
    trainWindowLabels = allWindowLabels(1:nTrain);
    testFeatures = allFeatures(nTrain+1:end, :);
    testWindowLabels = allWindowLabels(nTrain+1:end);
    fprintf('Train windows: %d (%d attack, %d normal)\n', nTrain, ...
        sum(trainWindowLabels == 1), sum(trainWindowLabels == 0));
    fprintf('Test windows:  %d (%d attack, %d normal)\n', nWindows - nTrain, ...
        sum(testWindowLabels == 1), sum(testWindowLabels == 0));

    % ======================================================================
    % STEP 6: LAYER 2 — ML Model Training (5 Models)
    % ======================================================================
    fprintf('\n--- STEP 6: Layer 2 — Training 5 ML Models ---\n');
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

    % ======================================================================
    % STEP 7: Individual Model Predictions
    % ======================================================================
    fprintf('\n--- STEP 7: Individual Model Evaluation ---\n');
    modelNames = {'SVM', 'Autoencoder', 'RandomForest', 'KNN', 'PCA'};
    nTest = size(testFeatures, 1);

    fprintf('\n[SVM Evaluation]\n');
    [svmPreds, svmScores, ~] = predictSVM(svmModel, testFeatures);
    svmMetrics = computeMetrics(svmPreds, testWindowLabels, svmScores);
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

    % ======================================================================
    % STEP 8: LAYER 3 — Model Consensus (Weighted Voting)
    % ======================================================================
    fprintf('\n--- STEP 8: Layer 3 — Model Consensus (Weighted Voting) ---\n');
    % Build prediction and score matrices
    allPreds = [svmPreds(:), aePreds(:), rfPreds(:), knnPreds(:), pcaPreds(:)];
    allScoresMatrix = [svmScores(:), aeScores(:), rfScores(:), knnScores(:), pcaScores(:)];
    [consensusPreds, consensusScoresOut, ensembleInfo] = modelConsensus(allPreds, allScoresMatrix, modelNames, testWindowLabels);

    fprintf('\n[Consensus Ensemble Evaluation]\n');
    consensusMetrics = computeMetrics(consensusPreds, testWindowLabels, consensusScoresOut);

    % ======================================================================
    % STEP 9: LAYER 4 — Blockchain Logging
    % ======================================================================
    fprintf('\n--- STEP 9: Layer 4 — Blockchain Audit Logging ---\n');
    % Log each test prediction to the blockchain
    batchSize = 10;  % Mine a block every 10 records
    for i = 1:nTest
        modelVotes = allPreds(i, :);
        ledger.logDetection(i, [], modelVotes, modelNames, consensusPreds(i), trustMgr.trustScores);
        if mod(i, batchSize) == 0
            ledger.mineBlock();
        end
    end
    % Mine remaining records
    if ~isempty(ledger.pendingData)
        ledger.mineBlock();
    end
    % Log final trust scores
    ledger.logTrustUpdate(trustMgr.trustScores, 'Post-evaluation trust state');
    ledger.mineBlock();
    ledger.displayStatus();

    % ======================================================================
    % STEP 10: Fog Node Simulation
    % ======================================================================
    fprintf('\n--- STEP 10: Fog Node Simulation ---\n');
    fogNode = FogNode(svmModel, cfg, H);
    cloud = CloudLayer(cfg);
    fprintf('Processing data through fog node...\n');
    fogTestData = allData(floor(size(allData,1)*0.7)+1:end, :);
    timestamps = 1:size(fogTestData, 1);
    [fogResults, totalLatency] = fogNode.processBatch(fogTestData, timestamps);
    alerts = fogNode.flushAlerts();
    cloud.receiveAlerts(alerts, 1);
    fogNode.displayStatus();
    cloud.displayStatus();

    % ======================================================================
    % RESULTS: Comparison Table (Individual + Consensus)
    % ======================================================================
    fprintf('\n');
    fprintf('================================================================\n');
    fprintf('           MULTI-MODEL + CONSENSUS COMPARISON TABLE\n');
    fprintf('================================================================\n');
    fprintf('%-15s %8s %8s %8s %8s %8s %6s %6s\n', 'Model', 'Accuracy', 'Precis.', 'Recall', 'F1', 'FAR', 'FP', 'FN');
    fprintf('-------------------------------------------------------------------------------\n');
    allMetrics = {svmMetrics, aeMetrics, rfMetrics, knnMetrics, pcaMetrics, consensusMetrics};
    allModelNames = {'SVM', 'Autoencoder', 'RandomForest', 'KNN', 'PCA', 'CONSENSUS'};
    f1Scores = zeros(1, 6);
    for i = 1:6
        m = allMetrics{i};
        f1Scores(i) = m.f1;
        prefix = '';
        if i == 6, prefix = '>> '; end
        fprintf('%s%-15s %7.2f%% %7.2f%% %7.2f%%  %6.4f %6.2f%% %5d %5d\n', ...
            prefix, allModelNames{i}, m.accuracy*100, m.precision*100, m.recall*100, m.f1, m.FAR*100, m.FP, m.FN);
    end
    fprintf('================================================================\n');

    % Show improvement
    bestIndividualF1 = max(f1Scores(1:5));
    consensusF1 = f1Scores(6);
    improvement = ((consensusF1 - bestIndividualF1) / max(bestIndividualF1, 0.01)) * 100;
    fprintf('\nConsensus F1: %.4f (%.1f%% vs best individual model)\n', consensusF1, improvement);

    % ======================================================================
    % Visualizations
    % ======================================================================
    fprintf('\n--- STEP 11: Generating Visualizations ---\n');
    plotResults(svmMetrics, allData, svmPreds, testWindowLabels, cfg, fogResults.latencies);
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
    fprintf('\nArchitecture: 4-Layer Consensus + Blockchain\n');
    fprintf('  Layer 1: Sensor Physics Consensus (PBFT)\n');
    fprintf('  Layer 2: 5 ML Models (SVM, AE, RF, KNN, PCA)\n');
    fprintf('  Layer 3: Dynamic Weighted Model Consensus\n');
    fprintf('  Layer 4: Blockchain Audit Ledger (SHA-256)\n');
    fprintf('\nModel Rankings (by F1-Score):\n');
    [sortedF1, rankIdx] = sort(f1Scores, 'descend');
    for i = 1:6
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
