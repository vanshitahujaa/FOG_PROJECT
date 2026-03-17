function ablation_study()
% ABLATION_STUDY  Runs 3 pipeline configurations side-by-side:
%   Config 1: BASE    — Raw ML models only (no physics, no consensus)
%   Config 2: +CONS   — Base + Model Consensus (weighted voting)
%   Config 3: +PHYS   — Base + Physics Correction + Model Consensus + Stacking
%
%   All 3 configs use the SAME dataset, SAME split, SAME seed for fair comparison.

    fprintf('\n');
    fprintf('================================================================\n');
    fprintf('              ABLATION STUDY\n');
    fprintf('    Measuring Impact of Each Architectural Layer\n');
    fprintf('================================================================\n\n');

    addpath(genpath(pwd));
    cfg = config();
    rng(cfg.seed);
    if ~exist(cfg.paths.results, 'dir'), mkdir(cfg.paths.results); end
    if ~exist(cfg.paths.models, 'dir'), mkdir(cfg.paths.models); end

    % ======================================================================
    % SHARED: Generate data once (same for all 3 configs)
    % ======================================================================
    fprintf('--- Generating Shared Dataset ---\n');
    [normalData, ~, mpc, meta] = generateNormalData(cfg);
    [H, ~, ~] = computeJacobian(mpc);
    [attackedData, attackLabels, ~] = generateAttackData(normalData, H, cfg);
    allData = attackedData;
    allLabels = attackLabels;
    fprintf('Dataset: %d samples (%d attacks, %d normal)\n\n', ...
        size(allData,1), sum(allLabels), sum(allLabels==0));

    % Physics consensus (always compute — used for Config 3)
    [trustTags, consensusScores, correctedData, consensusDetails] = sensorConsensus(allData, mpc, cfg);

    % ======================================================================
    % CONFIG 1: BASE ML (raw data, no physics, no consensus)
    % ======================================================================
    fprintf('\n================================================================\n');
    fprintf('  CONFIG 1: BASE ML (No Physics, No Consensus)\n');
    fprintf('================================================================\n');
    [baseResults] = runConfig(allData, allLabels, cfg, H, 'base');

    % ======================================================================
    % CONFIG 2: BASE + MODEL CONSENSUS (raw data, with voting)
    % ======================================================================
    fprintf('\n================================================================\n');
    fprintf('  CONFIG 2: BASE ML + MODEL CONSENSUS\n');
    fprintf('================================================================\n');
    [consResults] = runConfig(allData, allLabels, cfg, H, 'consensus');

    % ======================================================================
    % CONFIG 3: PHYSICS CORRECTION + ML + CONSENSUS + STACKING
    % ======================================================================
    fprintf('\n================================================================\n');
    fprintf('  CONFIG 3: PHYSICS CORRECTION + ML + CONSENSUS + STACKING\n');
    fprintf('================================================================\n');
    [physResults] = runConfig(correctedData, allLabels, cfg, H, 'physics');

    % ======================================================================
    % ABLATION COMPARISON TABLE
    % ======================================================================
    fprintf('\n\n');
    fprintf('================================================================\n');
    fprintf('              ABLATION STUDY RESULTS\n');
    fprintf('================================================================\n\n');

    % For each config, show the BEST individual model and the ensemble
    fprintf('%-25s %8s %8s %8s %8s %6s %6s\n', ...
        'Configuration', 'Accuracy', 'Precis.', 'Recall', 'F1', 'FP', 'FN');
    fprintf('------------------------------------------------------------------------\n');

    % Config 1: Best individual model
    printRow('1. Base ML (best indiv.)', baseResults.bestMetrics);

    % Config 2: Consensus ensemble
    printRow('2. +Consensus (voting)', consResults.consensusMetrics);

    % Config 3: Stacking on physics-corrected data
    printRow('3. +Physics+Stacking', physResults.stackMetrics);

    fprintf('------------------------------------------------------------------------\n');

    % Compute deltas
    baseF1 = baseResults.bestMetrics.f1;
    consF1 = consResults.consensusMetrics.f1;
    physF1 = physResults.stackMetrics.f1;
    baseFN = baseResults.bestMetrics.FN;
    consFN = consResults.consensusMetrics.FN;
    physFN = physResults.stackMetrics.FN;
    baseFP = baseResults.bestMetrics.FP;
    consFP = consResults.consensusMetrics.FP;
    physFP = physResults.stackMetrics.FP;

    fprintf('\n--- Layer Impact Analysis ---\n');
    fprintf('Consensus adds:  F1 %+.4f  |  FN %+d  |  FP %+d\n', ...
        consF1 - baseF1, consFN - baseFN, consFP - baseFP);
    fprintf('Physics adds:    F1 %+.4f  |  FN %+d  |  FP %+d\n', ...
        physF1 - consF1, physFN - consFN, physFP - consFP);
    fprintf('Total impact:    F1 %+.4f  |  FN %+d  |  FP %+d\n', ...
        physF1 - baseF1, physFN - baseFN, physFP - baseFP);

    fprintf('\n--- Per-Model Breakdown (All 3 Configs) ---\n');
    modelNames = {'SVM', 'Autoencoder', 'RandomForest', 'KNN', 'PCA'};
    fprintf('%-15s | %-18s | %-18s | %-18s\n', 'Model', 'Base F1 (FP/FN)', '+Consensus', '+Physics');
    fprintf('---------------------------------------------------------------------\n');
    for i = 1:5
        bm = baseResults.allMetrics{i};
        cm = consResults.allMetrics{i};
        pm = physResults.allMetrics{i};
        fprintf('%-15s | F1=%.4f (%d/%d) | F1=%.4f (%d/%d) | F1=%.4f (%d/%d)\n', ...
            modelNames{i}, bm.f1, bm.FP, bm.FN, cm.f1, cm.FP, cm.FN, pm.f1, pm.FP, pm.FN);
    end
    fprintf('---------------------------------------------------------------------\n');

    % ======================================================================
    % GENERATE ABLATION CHART
    % ======================================================================
    plotAblation(baseResults, consResults, physResults, modelNames, cfg);

    fprintf('\n================================================================\n');
    fprintf('   Ablation Study Complete!\n');
    fprintf('================================================================\n');
end

function [results] = runConfig(data, labels, cfg, H, configType)
    % Extract features
    [allFeatures, ~] = extractFeatures(data, cfg, H);
    allWindowLabels = computeWindowLabels(labels, cfg.windowSize);

    % If physics config, append consensus features
    if strcmp(configType, 'physics')
        % Recompute on the corrected data's trust tags
        nWindows = size(allFeatures, 1);
        % Placeholder consensus features (already corrected data)
        consensusFeats = zeros(nWindows, 3);
        allFeatures = [allFeatures, consensusFeats];
    end

    nWindows = size(allFeatures, 1);

    % Same shuffle (reset rng for fair comparison)
    rng(42);
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

    fprintf('Split: %d train, %d val, %d test\n', nTrain, nVal, length(testLabels));

    % Train models
    normalTrain = trainFeatures(trainLabels == 0, :);
    svmM = trainSVM(trainFeatures, cfg, trainLabels);
    aeM = trainAutoencoder(normalTrain, cfg);
    rfM = trainRandomForest(trainFeatures, cfg, trainLabels);
    knnM = trainKNN(trainFeatures, cfg, trainLabels);
    pcaM = trainPCA(normalTrain, cfg);

    % Test predictions
    [svmP, svmS, ~] = predictSVM(svmM, testFeatures);
    svmMet = computeMetrics(svmP, testLabels, svmS);
    [aeP, aeS, ~] = predictAutoencoder(aeM, testFeatures);
    aeMet = computeMetrics(aeP, testLabels, aeS);
    [rfP, rfS, ~] = predictRandomForest(rfM, testFeatures);
    rfMet = computeMetrics(rfP, testLabels, rfS);
    [knnP, knnS, ~] = predictKNN(knnM, testFeatures);
    knnMet = computeMetrics(knnP, testLabels, knnS);
    [pcaP, pcaS, ~] = predictPCA(pcaM, testFeatures);
    pcaMet = computeMetrics(pcaP, testLabels, pcaS);

    results.allMetrics = {svmMet, aeMet, rfMet, knnMet, pcaMet};
    f1s = [svmMet.f1, aeMet.f1, rfMet.f1, knnMet.f1, pcaMet.f1];
    [~, bestIdx] = max(f1s);
    results.bestMetrics = results.allMetrics{bestIdx};
    results.bestModelName = {'SVM','Autoencoder','RandomForest','KNN','PCA'};
    results.bestModelName = results.bestModelName{bestIdx};

    % Model consensus (for configs 2 and 3)
    testPreds = [svmP(:), aeP(:), rfP(:), knnP(:), pcaP(:)];
    testScoresM = [svmS(:), aeS(:), rfS(:), knnS(:), pcaS(:)];
    modelNames = {'SVM', 'Autoencoder', 'RandomForest', 'KNN', 'PCA'};

    [consP, consS, ~] = modelConsensus(testPreds, testScoresM, modelNames, testLabels);
    results.consensusMetrics = computeMetrics(consP, testLabels, consS);

    % Stacking (for config 3)
    if strcmp(configType, 'physics')
        valPreds = zeros(length(valLabels), 5);
        valScoresM = zeros(length(valLabels), 5);
        [valPreds(:,1), valScoresM(:,1), ~] = predictSVM(svmM, valFeatures);
        [valPreds(:,2), valScoresM(:,2), ~] = predictAutoencoder(aeM, valFeatures);
        [valPreds(:,3), valScoresM(:,3), ~] = predictRandomForest(rfM, valFeatures);
        [valPreds(:,4), valScoresM(:,4), ~] = predictKNN(knnM, valFeatures);
        [valPreds(:,5), valScoresM(:,5), ~] = predictPCA(pcaM, valFeatures);

        [~, ~, stackModel] = stackingClassifier(valPreds, valScoresM, modelNames, valLabels, 'train', []);
        [stackP, stackS, ~] = stackingClassifier(testPreds, testScoresM, modelNames, testLabels, 'predict', stackModel);
        results.stackMetrics = computeMetrics(stackP, testLabels, stackS);
    else
        results.stackMetrics = results.consensusMetrics;
    end
end

function printRow(name, m)
    fprintf('%-25s %7.2f%% %7.2f%% %7.2f%%  %6.4f %5d %5d\n', ...
        name, m.accuracy*100, m.precision*100, m.recall*100, m.f1, m.FP, m.FN);
end

function plotAblation(baseR, consR, physR, modelNames, cfg)
    fig = figure('Name', 'Ablation Study', 'Visible', 'off', 'Position', [50 50 1400 600]);

    % Panel 1: F1 Score comparison across configs
    subplot(1, 3, 1);
    f1Data = zeros(5, 3);
    for i = 1:5
        f1Data(i, 1) = baseR.allMetrics{i}.f1;
        f1Data(i, 2) = consR.allMetrics{i}.f1;
        f1Data(i, 3) = physR.allMetrics{i}.f1;
    end
    b = bar(f1Data, 'grouped');
    b(1).FaceColor = [0.7 0.7 0.7];  % Grey = base
    b(2).FaceColor = [0.3 0.6 0.9];  % Blue = +consensus
    b(3).FaceColor = [0.2 0.8 0.3];  % Green = +physics
    set(gca, 'XTickLabel', modelNames, 'XTickLabelRotation', 30);
    ylabel('F1 Score');
    title('F1 Score by Model & Config');
    legend({'Base ML', '+Consensus', '+Physics'}, 'Location', 'southoutside', 'Orientation', 'horizontal');
    ylim([0 1.05]);
    grid on;

    % Panel 2: FN comparison (false negatives = missed attacks)
    subplot(1, 3, 2);
    fnData = zeros(5, 3);
    for i = 1:5
        fnData(i, 1) = baseR.allMetrics{i}.FN;
        fnData(i, 2) = consR.allMetrics{i}.FN;
        fnData(i, 3) = physR.allMetrics{i}.FN;
    end
    b2 = bar(fnData, 'grouped');
    b2(1).FaceColor = [0.9 0.3 0.3];  % Red = base (worst)
    b2(2).FaceColor = [0.9 0.7 0.2];  % Yellow = +consensus
    b2(3).FaceColor = [0.2 0.7 0.3];  % Green = +physics (best)
    set(gca, 'XTickLabel', modelNames, 'XTickLabelRotation', 30);
    ylabel('False Negatives (Missed Attacks)');
    title('FN Reduction by Layer');
    legend({'Base ML', '+Consensus', '+Physics'}, 'Location', 'southoutside', 'Orientation', 'horizontal');
    grid on;

    % Panel 3: Summary bars (Best individual, Consensus, Stacking)
    subplot(1, 3, 3);
    summaryData = [
        baseR.bestMetrics.f1, baseR.bestMetrics.FP, baseR.bestMetrics.FN;
        consR.consensusMetrics.f1, consR.consensusMetrics.FP, consR.consensusMetrics.FN;
        physR.stackMetrics.f1, physR.stackMetrics.FP, physR.stackMetrics.FN;
    ];
    configNames = {'Base ML', '+Consensus', '+Physics+Stack'};
    yyaxis left;
    b3 = bar(summaryData(:, 1), 0.4, 'FaceColor', [0.2 0.5 0.8]);
    ylabel('F1 Score');
    ylim([0 1.1]);
    yyaxis right;
    hold on;
    scatter(1:3, summaryData(:, 2), 100, 'r', 'filled', 'DisplayName', 'FP');
    scatter(1:3, summaryData(:, 3), 100, 'b', 'filled', 'DisplayName', 'FN');
    ylabel('Error Count');
    hold off;
    set(gca, 'XTick', 1:3, 'XTickLabel', configNames);
    title('Ablation Summary');
    legend({'F1', 'FP', 'FN'}, 'Location', 'southoutside', 'Orientation', 'horizontal');
    grid on;

    sgtitle('Ablation Study: Impact of Each Architectural Layer', 'FontWeight', 'bold', 'FontSize', 14);

    if cfg.eval.savePlots
        saveas(gcf, fullfile(cfg.eval.outputDir, 'ablation_study.png'));
        fprintf('Saved ablation_study.png\n');
    end
    close(fig);
end
