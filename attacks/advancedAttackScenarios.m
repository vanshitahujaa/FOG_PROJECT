% % ADVANCED ATTACK SCENARIOS %
        Extended attack scenarios with realistic FDIA patterns %
        Based on published research and real -
    world attack models % % Categories : % 1. Economic Attacks -
    Cause financial loss % 2. Physical Attacks -
    Cause equipment damage % 3. Stealth Attacks -
    Evade detection % 4. Cascading Attacks -
    Trigger chain failures % % Usage : % scenarios = advancedAttackScenarios();
% [ data, labels ] =
    executeScenario(scenarios.economicLoadShift, normalData, H, cfg);

function scenarios = advancedAttackScenarios()
    fprintf('\n=== Advanced FDIA Attack Scenarios ===\n\n');

% % == == == == == == ==
    CATEGORY 1 : ECONOMIC ATTACKS == == == == == == ==
                 % Goal : Cause financial loss through market manipulation

                          %
                          Scenario 1.1
    : Load Redistribution Attack scenarios.economicLoadShift.name =
    'Load Redistribution Attack';
scenarios.economicLoadShift.category = 'Economic';
scenarios.economicLoadShift.description =
    [... 'Falsifies load measurements to cause uneconomic dispatch. ' ... 'Attacker increases apparent load at cheap generation zones ' ... 'and decreases at expensive zones, causing cost increase.'];
scenarios.economicLoadShift.type = 'bias';
scenarios.economicLoadShift.params =
    struct(... 'increaseBuses', [ 4, 5, 9 ],
           ... % Buses near cheap gen 'decreaseBuses', [ 10, 11, 14 ],
           ... % Buses near expensive gen 'increaseMag', 0.15,
           ... % 15 % apparent load increase 'decreaseMag', -0.10);
% 10 % apparent load decrease scenarios.economicLoadShift.impact =
    'Financial: 5-15% increase in dispatch cost';
scenarios.economicLoadShift.detectDifficulty = 'Medium';

% Scenario 1.2 : LMP Manipulation Attack scenarios.lmpManipulation.name =
    'LMP Manipulation Attack';
scenarios.lmpManipulation.category = 'Economic';
scenarios.lmpManipulation.description =
    [... 'Alters congestion patterns to manipulate Locational Marginal Prices. ' ... 'Attacker benefits from trading positions based on predicted price changes.'];
scenarios.lmpManipulation.type = 'coordinated';
scenarios.lmpManipulation.params =
    struct(... 'targetLines', [ 3, 5, 7 ],
           ... % Congested lines to manipulate 'congestionIncrease', 0.08,
           ... % Fake congestion increase 'attackNorm', 0.12);
scenarios.lmpManipulation.impact = 'Financial: Market manipulation profits';
scenarios.lmpManipulation.detectDifficulty = 'Hard';

% % == == == == == == == CATEGORY 2 : PHYSICAL ATTACKS == == == == == == ==
                                      % Goal : Cause equipment damage or
    blackouts

        %
        Scenario 2.1 : Voltage Collapse Trigger scenarios.voltageCollapse.name =
    'Voltage Collapse Trigger';
scenarios.voltageCollapse.category = 'Physical';
scenarios.voltageCollapse.description =
    [... 'Falsifies voltage readings to appear critically low, triggering ' ... 'automatic voltage support actions. Can cause actual voltage ' ... 'collapse if countermeasures destabilize the system.'];
scenarios.voltageCollapse.type = 'bias';
scenarios.voltageCollapse.params =
    struct(... 'targetBuses', [ 4, 5, 7, 9 ], ... 'voltageDrop', -0.08,
           ... % 8 % apparent voltage drop 'duration', 100);
% Sustained attack scenarios.voltageCollapse.impact =
    'Physical: Potential blackout';
scenarios.voltageCollapse.detectDifficulty = 'Easy (if threshold-based)';

% Scenario 2.2 : Line Overload Attack scenarios.lineOverload.name =
    'Line Overload Attack';
scenarios.lineOverload.category = 'Physical';
scenarios.lineOverload.description =
    [... 'Makes operators believe a line is underloaded when its actually ' ... 'at capacity. Prevents corrective actions until thermal damage occurs.'];
scenarios.lineOverload.type = 'bias';
scenarios.lineOverload.params =
    struct(... 'targetBranches', [ 5, 8, 12 ], ... 'flowReduction', -0.20,
           ... % Show 20 % less flow than actual 'hiddenOverload', true);
scenarios.lineOverload.impact = 'Physical: Transmission line damage';
scenarios.lineOverload.detectDifficulty = 'Medium';

% Scenario 2.3 : Generator Trip Attack scenarios.generatorTrip.name =
    'Generator Trip Attack';
scenarios.generatorTrip.category = 'Physical';
scenarios.generatorTrip.description =
    [... 'Falsifies generator output to trigger protective relay actions. ' ... 'Can cause unnecessary generator trips, leading to generation-load imbalance.'];
scenarios.generatorTrip.type = 'targeted';
scenarios.generatorTrip.params =
    struct(... 'targetGen', [ 1, 2 ], ... % Generator buses 'fakeOutput', 0.25,
           ... % Show 25 % of actual output 'triggerRelay', true);
scenarios.generatorTrip.impact = 'Physical: Generator disconnection';
scenarios.generatorTrip.detectDifficulty = 'Medium';

% % == == == == == == ==
    CATEGORY 3 : STEALTH ATTACKS == == == == == == ==
                 % Goal : Remain undetected while causing gradual harm

                          %
                          Scenario 3.1
    : Slow Ramp Attack scenarios.slowRamp.name = 'Slow Ramp Attack';
scenarios.slowRamp.category = 'Stealth';
scenarios.slowRamp.description =
    [... 'Gradually increases attack magnitude over hours/days. ' ... 'Rate of change stays below detection thresholds. ' ... 'By the time noticed, significant state deviation has occurred.'];
scenarios.slowRamp.type = 'ramp';
scenarios.slowRamp.params = struct(
    ... 'targetBuses', [ 5, 9, 13 ], ... 'initialMag', 0.001,
    ... % Start very small 'finalMag', 0.10, ... % End at 10 % 'rampDuration',
    500, ... % 500 samples to reach max 'rateLimit', 0.0002);
% Max change per sample scenarios.slowRamp.impact =
    'Depends on final deviation';
scenarios.slowRamp.detectDifficulty = 'Very Hard';

% Scenario 3.2 : Noise - Masked Attack scenarios.noiseMasked.name =
    'Noise-Masked Attack';
scenarios.noiseMasked.category = 'Stealth';
scenarios.noiseMasked.description =
    [... 'Injects attack signal within the normal noise envelope. ' ... 'Makes statistical detection difficult as attack looks like noise.'];
scenarios.noiseMasked.type = 'random_stealthy';
scenarios.noiseMasked.params = struct(
    ... 'noiseLevel', 0.02, ... % Match system noise level 'attackWithinNoise',
    true, ... 'stealthyNorm', 0.015);
% Stay below noise std scenarios.noiseMasked.impact =
    'Subtle state estimation errors';
scenarios.noiseMasked.detectDifficulty = 'Very Hard';

% Scenario 3.3 : Intermittent Attack scenarios.intermittent.name =
    'Intermittent Attack';
scenarios.intermittent.category = 'Stealth';
scenarios.intermittent.description =
    [... 'Attacks are injected sporadically, not continuously. ' ... 'Makes pattern-based detection difficult. Attack presence appears random.'];
scenarios.intermittent.type = 'bias';
scenarios.intermittent.params = struct(
    ... 'targetBuses', [ 7, 11 ], ... 'magnitude', 0.06,
    ... 'attackProbability', 0.1, ... % 10 % of samples attacked 'minGap', 10,
    ... % Minimum gap between attacks 'maxConsecutive', 3);
% Max consecutive attack samples scenarios.intermittent.impact =
    'Intermittent control errors';
scenarios.intermittent.detectDifficulty = 'Hard';

% % == == == == == == ==
    CATEGORY 4 : CASCADING ATTACKS == == == == == == ==
                 % Goal : Trigger chain reactions in the power system

                          %
                          Scenario 4.1
    : N - 1 Violation Attack scenarios.n1Violation.name =
    'N-1 Violation Attack';
scenarios.n1Violation.category = 'Cascading';
scenarios.n1Violation.description =
    [... 'Hides the fact that system is in N-1 contingency violation. ' ... 'Operators believe system is secure when its actually vulnerable. ' ... 'If another contingency occurs, cascading failure results.'];
scenarios.n1Violation.type = 'coordinated';
scenarios.n1Violation.params =
    struct(... 'hiddenViolation', true, ... 'violatedBranch', 7,
           ... 'maskingStrategy', 'redistribute', ... 'attackNorm', 0.15);
scenarios.n1Violation.impact = 'Cascading: Potential wide-area blackout';
scenarios.n1Violation.detectDifficulty = 'Hard';

% Scenario 4.2 : Protection Coordination Attack scenarios.protectionCoord.name =
    'Protection Coordination Attack';
scenarios.protectionCoord.category = 'Cascading';
scenarios.protectionCoord.description =
    [... 'Falsifies measurements to cause mis-operation of protective relays. ' ... 'Trips healthy equipment while keeping faulted equipment online.'];
scenarios.protectionCoord.type = 'targeted';
scenarios.protectionCoord.params =
    struct(... 'targetRelays', [ 3, 6, 9 ], ... 'falseTrip', true,
           ... 'magnitude', 0.12);
scenarios.protectionCoord.impact = 'Cascading: Multiple equipment trips';
scenarios.protectionCoord.detectDifficulty = 'Medium';

% % Print Summary fprintf('Category: ECONOMIC ATTACKS\n');
fprintf('  1. %s\n', scenarios.economicLoadShift.name);
fprintf('  2. %s\n', scenarios.lmpManipulation.name);
fprintf('\nCategory: PHYSICAL ATTACKS\n');
fprintf('  3. %s\n', scenarios.voltageCollapse.name);
fprintf('  4. %s\n', scenarios.lineOverload.name);
fprintf('  5. %s\n', scenarios.generatorTrip.name);
fprintf('\nCategory: STEALTH ATTACKS\n');
fprintf('  6. %s\n', scenarios.slowRamp.name);
fprintf('  7. %s\n', scenarios.noiseMasked.name);
fprintf('  8. %s\n', scenarios.intermittent.name);
fprintf('\nCategory: CASCADING ATTACKS\n');
fprintf('  9. %s\n', scenarios.n1Violation.name);
fprintf('  10. %s\n', scenarios.protectionCoord.name);
fprintf('\n');
end

    % % Execute a specific scenario function[attackedData, labels, attackInfo] =
    executeScenario(scenario, normalData, H, cfg)
        fprintf('\n=== Executing Scenario: %s ===\n', scenario.name);
fprintf('Category: %s\n', scenario.category);
fprintf('Description: %s\n', scenario.description);
fprintf('Expected Impact: %s\n', scenario.impact);
fprintf('Detection Difficulty: %s\n', scenario.detectDifficulty);

[ nSamples, nFeatures ] = size(normalData);
attackedData = normalData;
labels = zeros(nSamples, 1);
attackInfo = cell(nSamples, 1);

% Determine attack start based on scenario type attackStart =
    floor(nSamples * 0.5);  % Attack latter half by default
    
    for i = attackStart:nSamples
        z = normalData(i, :)';
        params = scenario.params;

        % Handle special scenario logic
        switch scenario.type
            case 'ramp'
                % Progressive ramp
                progress = (i - attackStart) / (nSamples - attackStart);
                params.rampFactor = progress;
                params.magnitude = params.initialMag + ...
                    (params.finalMag - params.initialMag) * progress;
                
            case 'bias'
                % Handle increase/decrease buses for economic attacks
                if isfield(params, 'increaseBuses')
                    params.targetBuses = params.increaseBuses;
                    params.magnitude = params.increaseMag;
                end
        end
        
        % Check for intermittent attack
        if isfield(params, 'attackProbability')
            if rand() > params.attackProbability
                continue;  % Skip this sample
            end
        end
        
        % Inject attack
        [z_attack, info] = injectFDIA(z, H, scenario.type, params);
        
        % Store result
        if length(z_attack) < nFeatures
            attackedData(i, 1:length(z_attack)) = z_attack';
        else
            attackedData(i, :) = z_attack(1:nFeatures)';
        end
        
        labels(i) = 1;
        info.scenario = scenario.name;
        info.category = scenario.category;
        attackInfo{i} = info;
        end

            fprintf('\nAttack Summary:\n');
        fprintf('  Samples attacked: %d/%d (%.1f%%)\n', sum(labels), nSamples,
                100 * sum(labels) / nSamples);
        fprintf('  Attack type: %s\n', scenario.type);
        fprintf('===================================\n');
        end

            % % Compare detection across scenarios function results =
            benchmarkScenarios(normalData, H, cfg, modelSVM, modelAE)
                scenarios = advancedAttackScenarios();
        scenarioNames = fieldnames(scenarios);

        results = struct();

        fprintf('\n=== Benchmarking All Scenarios ===\n\n');
        fprintf('%-25s %8s %8s %8s %8s\n', 'Scenario', 'SVM Acc', 'SVM Rec',
                'AE Acc', 'AE Rec');
        fprintf('%s\n', repmat('-', 1, 70));

    for
      i = 1 : length(scenarioNames) name = scenarioNames{i};
    scenario = scenarios.(name);

    % Execute scenario[attackedData, labels, ~] =
        executeScenario(scenario, normalData, H, cfg);

    % Extract features features = extractFeatures(attackedData, cfg, H);
    windowLabels = computeWindowLabels(labels, cfg.windowSize);

    % Evaluate SVM[svmPreds, ~, ~] = predictSVM(modelSVM, features);
    svmAcc = sum(svmPreds == windowLabels) / length(windowLabels);
    svmRec = sum(svmPreds == 1 & windowLabels == 1) / sum(windowLabels == 1);

    % Evaluate Autoencoder[aePreds, ~, ~] =
        predictAutoencoder(modelAE, features);
    aeAcc = sum(aePreds == windowLabels) / length(windowLabels);
    aeRec = sum(aePreds == 1 & windowLabels == 1) / sum(windowLabels == 1);

    % Store results results.(name).svmAccuracy = svmAcc;
    results.(name).svmRecall = svmRec;
    results.(name).aeAccuracy = aeAcc;
    results.(name).aeRecall = aeRec;
    results.(name).difficulty = scenario.detectDifficulty;

    fprintf('%-25s %8.4f %8.4f %8.4f %8.4f\n',
            ... scenario.name(1 : min(25, end)), svmAcc, svmRec, aeAcc, aeRec);
    end

        fprintf('\n=== Benchmark Complete ===\n');
    end
