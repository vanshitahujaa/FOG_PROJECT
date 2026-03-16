%% ATTACK SCENARIOS
% Predefined attack scenarios for testing

function scenarios = attackScenarios()
    %% Simple Bias Attack
    scenarios.simpleBias.name = 'Simple Bias Attack';
scenarios.simpleBias.description = 'Constant offset on targeted buses';
scenarios.simpleBias.type = 'bias';
scenarios.simpleBias.params.magnitude = 0.05;
scenarios.simpleBias.params.targetBuses = [ 4, 5, 6 ];
scenarios.simpleBias.difficulty = 'Easy';

% % Slow Ramp Attack scenarios.slowRamp.name = 'Slow Ramp Attack';
scenarios.slowRamp.description = 'Gradually increasing deviation';
scenarios.slowRamp.type = 'ramp';
scenarios.slowRamp.params.maxMagnitude = 0.08;
scenarios.slowRamp.params.targetBuses = [ 3, 4 ];
scenarios.slowRamp.difficulty = 'Medium';

% % Coordinated Attack scenarios.coordinated.name =
    'Coordinated Multi-Sensor Attack';
scenarios.coordinated.description = 'Correlated attack on multiple sensors';
scenarios.coordinated.type = 'coordinated';
scenarios.coordinated.params.attackNorm = 0.1;
scenarios.coordinated.difficulty = 'Hard';

% % Stealthy Random Attack scenarios.stealthyRandom.name =
    'Stealthy Random Attack';
scenarios.stealthyRandom.description = 'Low magnitude within noise envelope';
scenarios.stealthyRandom.type = 'random_stealthy';
scenarios.stealthyRandom.params.stealthyNorm = 0.02;
scenarios.stealthyRandom.difficulty = 'Very Hard';

% % Load Manipulation Attack scenarios.loadManip.name =
    'Load Manipulation Attack';
scenarios.loadManip.description = 'Targets load buses to cause misestimation';
scenarios.loadManip.type = 'bias';
scenarios.loadManip.params.magnitude = 0.10;
scenarios.loadManip.params.targetBuses = [ 9, 10, 14 ];
scenarios.loadManip.difficulty = 'Medium';

% % Voltage Collapse Trigger scenarios.voltageCollapse.name =
    'Voltage Collapse Trigger';
scenarios.voltageCollapse.description = 'Hides voltage deterioration';
scenarios.voltageCollapse.type = 'targeted';
scenarios.voltageCollapse.params.targetState = 1;
scenarios.voltageCollapse.params.targetError = -0.15;
scenarios.voltageCollapse.difficulty = 'Hard';

% % Oscillating Attack scenarios.oscillating.name = 'Oscillating Attack';
scenarios.oscillating.description =
    'Attack magnitude oscillates to confuse detection';
scenarios.oscillating.type = 'bias';
scenarios.oscillating.params.magnitude = 0.06;
scenarios.oscillating.params.targetBuses = [ 5, 6, 7 ];
scenarios.oscillating.difficulty = 'Hard';
end

    % % Run a specific scenario function[attackedData, labels] =
    runScenario(scenario, normalData, H, cfg)
        fprintf('Running scenario: %s\n', scenario.name);
fprintf('  Type: %s\n', scenario.type);
fprintf('  Difficulty: %s\n', scenario.difficulty);

nSamples = size(normalData, 1);
attackedData = normalData;
labels = zeros(nSamples, 1);

nAttacks = floor(nSamples * cfg.attackRatio);
attackIdx = randperm(nSamples, nAttacks);

    for
      i = 1 : length(attackIdx) idx = attackIdx(i);
    z = normalData(idx, :)';

        if strcmp (scenario.type, 'ramp')
            scenario.params.rampFactor = i / length(attackIdx);
    end

        [z_attack, ~] = injectFDIA(z, H, scenario.type, scenario.params);

    nFeatures = size(normalData, 2);
    if length (z_attack)
      < nFeatures attackedData(idx, 1 : length(z_attack)) =
          z_attack'; else attackedData(idx, :) = z_attack(1 : nFeatures)'; end
          labels(idx) = 1;
    end

        fprintf('  Injected %d attacks\n', sum(labels));
    end
