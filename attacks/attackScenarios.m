%% ATTACK SCENARIOS
% Predefined attack scenarios for testing and demonstration
%
% Each scenario represents a realistic attack pattern

function scenarios = attackScenarios()
    %% Scenario 1: Simple Bias Attack
    % Attacker modifies voltage readings at a few buses
    scenarios.simpleBias.name = 'Simple Bias Attack';
scenarios.simpleBias.description = 'Constant offset on 3 target buses';
scenarios.simpleBias.type = 'bias';
scenarios.simpleBias.params.targetBuses = [ 4, 5, 6 ];
scenarios.simpleBias.params.magnitude = 0.05;
scenarios.simpleBias.difficulty = 'Easy to detect';

% % Scenario 2 : Slow Ramp Attack %
                 Gradual increase to avoid sudden change detection
                     scenarios.slowRamp.name = 'Slow Ramp Attack';
scenarios.slowRamp.description =
    'Gradually increasing deviation over 50 samples';
scenarios.slowRamp.type = 'ramp';
scenarios.slowRamp.params.targetBuses = [ 3, 7, 9 ];
scenarios.slowRamp.params.maxMagnitude = 0.08;
scenarios.slowRamp.params.duration = 50;
scenarios.slowRamp.difficulty = 'Medium';

% % Scenario 3 : Coordinated Multi -
    bus Attack % Sophisticated attack affecting multiple sensors coherently
                     scenarios.coordinated.name =
    'Coordinated Multi-bus Attack';
scenarios.coordinated.description = 'Correlated attack on multiple buses';
scenarios.coordinated.type = 'coordinated';
scenarios.coordinated.params.attackNorm = 0.1;
scenarios.coordinated.params.nTargets = 5;
scenarios.coordinated.difficulty = 'Hard to detect';

% % Scenario 4 : Stealthy Random Attack %
                 Low magnitude attack designed to stay under detection threshold
                     scenarios.stealthy.name = 'Stealthy Random Attack';
scenarios.stealthy.description = 'Low-magnitude attack on random buses';
scenarios.stealthy.type = 'random_stealthy';
scenarios.stealthy.params.stealthyNorm = 0.03;
scenarios.stealthy.difficulty = 'Very hard to detect';

% % Scenario 5 : Load Manipulation Attack %
                 Fake load increase to cause wrong dispatch decisions
                     scenarios.loadManipulation.name =
    'Load Manipulation Attack';
scenarios.loadManipulation.description = 'Fake load increase at specific buses';
scenarios.loadManipulation.type = 'bias';
scenarios.loadManipulation.params.targetBuses = [ 2, 5, 10 ];
scenarios.loadManipulation.params.magnitude = 0.1;
% 10 % load increase scenarios.loadManipulation.difficulty =
    'Economic impact focused';

% % Scenario 6 : Voltage Collapse Trigger %
                 Attack designed to trigger incorrect voltage emergency response
                     scenarios.voltageCollapse.name =
    'Voltage Collapse Trigger';
scenarios.voltageCollapse.description = 'Fake low voltage readings';
scenarios.voltageCollapse.type = 'bias';
scenarios.voltageCollapse.params.targetBuses = [ 4, 5, 6, 7 ];
scenarios.voltageCollapse.params.magnitude = -0.08;
% Negative = lower voltage scenarios.voltageCollapse.difficulty =
    'Critical impact';

% % Scenario 7 : Oscillating Attack % Alternating positive /
                 negative deviations scenarios.oscillating.name =
    'Oscillating Attack';
scenarios.oscillating.description =
    'Alternating deviations to confuse detection';
scenarios.oscillating.type = 'coordinated';
scenarios.oscillating.params.pattern = 'oscillating';
scenarios.oscillating.params.frequency = 10;
% Samples per cycle scenarios.oscillating.difficulty = 'Medium';

% % Print summary fprintf('\n=== Available Attack Scenarios ===\n');
fields = fieldnames(scenarios);
    for
      i = 1 : length(fields) s = scenarios.(fields{i});
    fprintf('%d. %s\n', i, s.name);
    fprintf('   Type: %s | Difficulty: %s\n', s.type, s.difficulty);
    fprintf('   %s\n\n', s.description);
    end end

        % % Run specific scenario function[attackedData, labels, info] =
        runScenario(scenarioName, normalData, H, cfg) scenarios =
            attackScenarios();

    if
      ~isfield(scenarios, scenarioName)
          error('Unknown scenario: %s', scenarioName);
    end

        scenario = scenarios.(scenarioName);
    fprintf('\n=== Running Scenario: %s ===\n', scenario.name);
    fprintf('Description: %s\n', scenario.description);

    [ nSamples, nFeatures ] = size(normalData);
    attackedData = normalData;
    labels = zeros(nSamples, 1);
    info = cell(nSamples, 1);

    % Attack latter half of data attackStartIdx = floor(nSamples / 2);

    for
      i = attackStartIdx : nSamples z = normalData(i, :)';

                                        % For ramp attacks,
      compute ramp factor if strcmp (scenario.type, 'ramp')
          scenario.params.rampFactor =
          (i - attackStartIdx) / (nSamples - attackStartIdx);
    end

        [z_attack, attackInfo] =
            injectFDIA(z, H, scenario.type, scenario.params);

    if length (z_attack)
      < nFeatures attackedData(i, 1 : length(z_attack)) =
          z_attack'; else attackedData(i, :) = z_attack(1 : nFeatures)'; end

          labels(i) = 1;
    info{i} = attackInfo;
    end

        fprintf('Attacks injected: %d/%d samples\n', sum(labels), nSamples);
    end
