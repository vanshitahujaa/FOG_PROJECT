% % FALSE DATA INJECTION ATTACK(FDIA) MODULE
        % Implements various types of FDIA attacks that bypass residual
    - based detection % % Key principle : a =
    H * c produces attack that doesn't change residual %
        % Attack Types : % 1. bias
    - Constant offset on target buses % 2. ramp
    - Slowly increasing attack(harder to detect) % 3. coordinated - Multi
    - sensor attack with controlled magnitude % 4. random_stealthy
    - Random but within detection threshold % 5. targeted -
    Attack specific measurements to affect state estimation %
        % Usage : % [ z_attack, info ] = injectFDIA(z, H, 'bias', params)

        function[z_attack, attack_info] =
            injectFDIA(z, H, attackType, params) % Input validation if nargin <
            4 params = struct();
end

    [m, n] = size(H);
% m = measurements,
  n = states

      % Ensure z is column vector if isrow (z)
            z = z'; end

                    % Truncate / pad z if necessary to match H if length (z) >
                m z = z(1 : m);
elseif length(z) < m z = [z; zeros(m - length(z), 1)];
end

    % Initialize attack vector c = zeros(n, 1);

switch
lower(attackType) case 'bias' % % Bias Attack:
  Constant offset on target buses % Simplest FDIA -
      adds fixed deviation to specific measurements

      if ~isfield(params,
                  'targetBuses') params.targetBuses = randperm(n, min(3, n));
  % Random 3 buses end if ~isfield(params, 'magnitude') params.magnitude = 0.05;
% 5 %
    deviation end

        c(params.targetBuses) = params.magnitude;
a = H * c;

case 'ramp' % % Ramp Attack:
Gradually increasing attack %
    Harder to detect because change is slow

    if ~isfield(params, 'targetBuses') params.targetBuses = randperm(n,
                                                                     min(3, n));
end if ~isfield(params, 'rampFactor') params.rampFactor = 1.0;
% Current position in ramp
        end if ~isfield(params, 'maxMagnitude') params.maxMagnitude = 0.08;
end

    currentMag = params.maxMagnitude * params.rampFactor;
c(params.targetBuses) = currentMag;
a = H * c;

        case 'coordinated'
            %% Coordinated Multi-sensor Attack
            % Affects multiple sensors with correlated attack vectors
            
            if ~isfield(params, 'attackNorm')
                params.attackNorm = 0.1;
            end
            if ~isfield(params, 'direction')
                % Random direction in state space
                params.direction = randn(n, 1);
            end
            
            c = params.direction / norm(params.direction);
            c = c * params.attackNorm;
            a = H * c;
            
        case 'random_stealthy'
            %% Random Stealthy Attack
            % Random attack vector but constrained to be small
            
            if ~isfield(params, 'stealthyNorm')
                params.stealthyNorm = 0.03;
            end
            
            c = randn(n, 1);
            c = c / norm(c) * params.stealthyNorm;
            a = H * c;
            
        case 'targeted'
            %% Targeted Attack
            % Designed to cause specific state estimation error
            
            if ~isfield(params, 'targetState')
                params.targetState = 1;
            end
            if ~isfield(params, 'targetError')
                params.targetError = 0.1;  % Desired error in target state
            end
            
            c(params.targetState) = params.targetError;
            a = H * c;
            
        case 'scaling'
            %% Scaling Attack
            % Scales all measurements by a factor
            
            if ~isfield(params, 'scaleFactor')
                params.scaleFactor = 1.02;  % 2% scaling
            end
            
            % This isn't a true FDIA but can be stealthy
            a = z * (params.scaleFactor - 1);
            c = H \ a;  % Back-calculate c for reference
            
        case 'replay'
            %% Replay Attack
            % Uses historical data instead of current
            
            if ~isfield(params, 'historicalZ')
                error('Replay attack requires historicalZ parameter');
            end
            
            a = params.historicalZ - z;
            c = H \ a;
            
        otherwise
            error('Unknown attack type: %s', attackType);
    end
    
    % Apply attack
    z_attack = z + a;
    
    % Verify attack is stealthy (theoretical check)
    % For a = Hc, the residual should remain unchanged
    % r_attack = z_attack - H*x_attack = z + Hc - H*(x + c) = z - Hx = r
    
    % Build attack info struct
    attack_info.type = attackType;
    attack_info.c = c;
    attack_info.a = a;
    attack_info.attackNorm = norm(a);
    attack_info.stateNorm = norm(c);
    attack_info.params = params;
    attack_info.isStealthy = true;  % By construction using a = Hc
    
    % Compute theoretical residual change (should be ~0 for true FDIA)
    % This is for verification purposes
    attack_info.theoreticalResidualChange = norm(a - H*c);
end

%% Generate attack dataset
function [attackedData, attackLabels, attackInfo] = generateAttackData(normalData, H, cfg)
    % Generates attacked version of normal data with various attack types
    
    fprintf('=== Generating Attack Data ===\n');
    
    [nSamples, nFeatures] = size(normalData);
    nAttacks = floor(nSamples * cfg.attackRatio);
    
    attackedData = normalData;
    attackLabels = zeros(nSamples, 1);
    attackInfo = cell(nSamples, 1);
    
    % Select random samples to attack
    rng(cfg.seed + 1);  % Different seed from data generation
    attackIdx = randperm(nSamples, nAttacks);
    
    % Distribute attack types
    nTypes = length(cfg.attackTypes);
    samplesPerType = floor(nAttacks / nTypes);
    
    currentIdx = 1;
    for t = 1:
        nTypes attackType = cfg.attackTypes{t};

        if t
          == nTypes % Last type gets remaining samples typeIdx =
              attackIdx(currentIdx : end);
        else
          typeIdx = attackIdx(currentIdx : currentIdx + samplesPerType - 1);
        end

            fprintf('  Generating %d %s attacks...\n', length(typeIdx),
                    attackType);

        % Get attack parameters based on type params =
            getAttackParams(attackType, cfg);

        for
          i = 1 : length(typeIdx) idx = typeIdx(i);
        z = normalData(idx, :)';

            % For ramp attack,
        vary the ramp factor if strcmp (attackType, 'ramp') params.rampFactor =
            i / length(typeIdx);
        end

            % Inject attack[z_attack, info] =
            injectFDIA(z, H, attackType, params);

        % Handle size mismatch(
              H may be smaller than full feature vector) if length (z_attack) <
            nFeatures attackedData(idx, 1 : length(z_attack)) =
            z_attack'; else attackedData(idx, :) = z_attack(1 : nFeatures)'; end

            attackLabels(idx) = 1;
        attackInfo{idx} = info;
        end

            currentIdx = currentIdx + samplesPerType;
        end

            fprintf('=== Attack Generation Complete ===\n');
        fprintf('Total attacks: %d (%.1f%%)\n', sum(attackLabels),
                100 * sum(attackLabels) / nSamples);
        end

            % % Get attack parameters from config function params =
            getAttackParams(attackType, cfg) switch lower(
                attackType) case 'bias' params = cfg.attack.bias;
            case 'ramp' params = cfg.attack.ramp;
            params.maxMagnitude = cfg.attack.ramp.maxMag;
            case 'coordinated' params = cfg.attack.coordinated;
            case 'random_stealthy' params = cfg.attack.stealthy;
            otherwise params = struct(); end end
