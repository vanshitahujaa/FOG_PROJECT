%% QUICK START SCRIPT
% Run this for a quick demo of the FDIA detection system
%
% This script:
%   1. Checks MATPOWER installation
%   2. Runs a simplified pipeline
%   3. Shows key results
%
% Usage:
%   >> quickStart

function quickStart()
    clc;
fprintf('\n');
fprintf('╔════════════════════════════════════════════════════════════╗\n');
fprintf('║     FOG-ASSISTED FDIA DETECTION - QUICK START DEMO        ║\n');
fprintf('╚════════════════════════════════════════════════════════════╝\n');
fprintf('\n');

% % Step 0 : Add paths addpath(genpath(pwd));

% %
    Step 1
    : Check MATPOWER fprintf('[1/6] Checking MATPOWER installation...\n');

if
  ~exist('loadcase', 'file') fprintf('\n⚠️  MATPOWER not found!\n');
fprintf('   Run: setupMatpower\n');
fprintf('   Or visit: https://matpower.org/\n\n');
return;
end fprintf('      ✓ MATPOWER is installed\n\n');

    %% Step 2: Load configuration (reduced for demo)
    fprintf('[2/6] Loading configuration (demo mode)...\n');
    cfg = config();
    cfg.nSamples = 500;           % Reduced for quick demo
    cfg.ae.maxEpochs = 50;
    % Faster training rng(cfg.seed);
    fprintf('      ✓ Using %d samples (demo mode)\n\n', cfg.nSamples);

    % %
        Step 3
        : Generate data fprintf('[3/6] Generating power system data...\n');
    [ normalData, ~, mpc, meta ] = generateNormalData(cfg);
    fprintf('      ✓ Generated %d samples from IEEE %d-bus system\n\n',
            ... size(normalData, 1), meta.nBuses);

    % %
        Step 4
        : Compute Jacobian and inject attacks fprintf(
              '[4/6] Computing Jacobian and injecting FDIA attacks...\n');
    [ H, ~, ~] = computeJacobian(mpc);

    % Use basic attack scenarios[attackedData, attackLabels, ~] =
        generateAttackData(normalData, H, cfg);

    % Combine and split allData = [normalData; attackedData];
    allLabels = [zeros(size(normalData, 1), 1); attackLabels];

    idx = randperm(size(allData, 1));
    allData = allData(idx, :);
    allLabels = allLabels(idx);

    nTrain = floor(size(allData, 1) * 0.7);
    trainData = allData(1 : nTrain, :);
    trainLabels = allLabels(1 : nTrain);
    testData = allData(nTrain + 1 : end, :);
    testLabels = allLabels(nTrain + 1 : end);

    fprintf('      ✓ Injected %d attacks (%.1f%%)\n\n', ... sum(allLabels),
            100 * sum(allLabels) / length(allLabels));

    % %
        Step 5
        : Extract features and
              train model fprintf('[5/6] Training SVM detection model...\n');

    % Extract features[trainFeatures, ~] = extractFeatures(trainData, cfg, H);
    [ testFeatures, ~] = extractFeatures(testData, cfg, H);
    trainWindowLabels = computeWindowLabels(trainLabels, cfg.windowSize);
    testWindowLabels = computeWindowLabels(testLabels, cfg.windowSize);

    % Train SVM svmModel = trainSVM(trainFeatures, cfg, trainWindowLabels);
    fprintf('      ✓ Model trained\n\n');

    % %
        Step 6
        : Evaluate fprintf('[6/6] Evaluating detection performance...\n\n');

    [ predictions, scores, ~] = predictSVM(svmModel, testFeatures);

    % Compute metrics TP = sum(predictions == 1 & testWindowLabels == 1);
    TN = sum(predictions == 0 & testWindowLabels == 0);
    FP = sum(predictions == 1 & testWindowLabels == 0);
    FN = sum(predictions == 0 & testWindowLabels == 1);

    accuracy = (TP + TN) / length(testWindowLabels);
    precision = TP / (TP + FP + eps);
    recall = TP / (TP + FN + eps);
    f1 = 2 * precision * recall / (precision + recall + eps);
    far = FP / (FP + TN + eps);

    % %
        Display Results fprintf(
            '╔════════════════════════════════════════════════════════════╗\n');
    fprintf('║                    DETECTION RESULTS                       ║\n');
    fprintf('╠════════════════════════════════════════════════════════════╣\n');
    fprintf('║  Metric          │ Value                                   ║\n');
    fprintf(
        '╠───────────────────┼─────────────────────────────────────────╣\n');
    fprintf(
        '║  Accuracy         │ %6.2f%%                                  ║\n',
        accuracy * 100);
    fprintf(
        '║  Precision        │ %6.2f%%                                  ║\n',
        precision * 100);
    fprintf(
        '║  Recall           │ %6.2f%%                                  ║\n',
        recall * 100);
    fprintf('║  F1-Score         │ %6.4f                                  ║\n',
            f1);
    fprintf(
        '║  False Alarm Rate │ %6.2f%%                                  ║\n',
        far * 100);
    fprintf('╠════════════════════════════════════════════════════════════╣\n');
    fprintf('║  Confusion Matrix:                                         ║\n');
    fprintf('║                    Predicted                               ║\n');
    fprintf('║                  Normal  Attack                            ║\n');
    fprintf('║  Actual Normal   %5d   %5d                             ║\n', TN,
            FP);
    fprintf('║         Attack   %5d   %5d                             ║\n', FN,
            TP);
    fprintf('╚════════════════════════════════════════════════════════════╝\n');

    fprintf('\n');
    fprintf('✅ Quick start demo complete!\n\n');
    fprintf('Next steps:\n');
    fprintf('  • Run full pipeline:    >> main\n');
    fprintf('  • View attack types:    >> advancedAttackScenarios\n');
    fprintf('  • See architecture:     open docs/ARCHITECTURE.md\n');
    fprintf('\n');

    % %
        Quick plot figure('Name', 'Quick Start Results', 'Position',
                          [ 100, 100, 800, 300 ]);

    subplot(1, 2, 1);
    bar([ accuracy, precision, recall, f1 ], 'FaceColor', [ 0.3, 0.6, 0.9 ]);
    set(gca, 'XTickLabel', {'Accuracy', 'Precision', 'Recall', 'F1'});
    ylabel('Score');
    title('Detection Performance');
    ylim([ 0, 1.1 ]);
    grid on;

    subplot(1, 2, 2);
    confMat = [ TN, FP; FN, TP ];
    imagesc(confMat);
    colormap(flipud(hot));
    colorbar;
    title('Confusion Matrix');
    set(gca, 'XTick', [ 1, 2 ], 'XTickLabel', {'Normal', 'Attack'});
    set(gca, 'YTick', [ 1, 2 ], 'YTickLabel', {'Normal', 'Attack'});
    xlabel('Predicted');
    ylabel('Actual');

    % Add text
    for i = 1:2
        for j = 1:2
            text(j, i, num2str(confMat(i,j)), 'HorizontalAlignment', 'center', ...
                'FontSize', 14, 'FontWeight', 'bold', 'Color', 'w');
    end end end
