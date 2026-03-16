function [z_attack, attack_info] = injectFDIA(z, H, attackType, params)
    if nargin < 4
        params = struct();
    end
    [m, n] = size(H);
    if isrow(z)
        z = z';
    end
    if length(z) > m
        z = z(1:m);
    elseif length(z) < m
        z = [z; zeros(m - length(z), 1)];
    end
    c = zeros(n, 1);
    switch lower(attackType)
        case 'bias'
            if ~isfield(params, 'targetBuses')
                params.targetBuses = randperm(n, min(3, n));
            end
            if ~isfield(params, 'magnitude')
                params.magnitude = 0.05;
            end
            validTargets = params.targetBuses(params.targetBuses <= n);
            c(validTargets) = params.magnitude;
            a = H * c;
        case 'ramp'
            if ~isfield(params, 'targetBuses')
                params.targetBuses = randperm(n, min(3, n));
            end
            if ~isfield(params, 'rampFactor')
                params.rampFactor = 1.0;
            end
            if ~isfield(params, 'maxMagnitude')
                params.maxMagnitude = 0.08;
            end
            currentMag = params.maxMagnitude * params.rampFactor;
            validTargets = params.targetBuses(params.targetBuses <= n);
            c(validTargets) = currentMag;
            a = H * c;
        case 'coordinated'
            if ~isfield(params, 'attackNorm')
                params.attackNorm = 0.1;
            end
            if ~isfield(params, 'direction')
                params.direction = randn(n, 1);
            end
            c = params.direction / norm(params.direction);
            c = c * params.attackNorm;
            a = H * c;
        case 'random_stealthy'
            if ~isfield(params, 'stealthyNorm')
                params.stealthyNorm = 0.03;
            end
            c = randn(n, 1);
            c = c / norm(c) * params.stealthyNorm;
            a = H * c;
        case 'targeted'
            if ~isfield(params, 'targetState')
                params.targetState = 1;
            end
            if ~isfield(params, 'targetError')
                params.targetError = 0.1;
            end
            targetState = min(params.targetState, n);
            c(targetState) = params.targetError;
            a = H * c;
        case 'scaling'
            if ~isfield(params, 'scaleFactor')
                params.scaleFactor = 1.02;
            end
            a = z * (params.scaleFactor - 1);
            c = H \ a;
        case 'replay'
            if ~isfield(params, 'historicalZ')
                error('Replay attack requires historicalZ parameter');
            end
            a = params.historicalZ - z;
            c = H \ a;
        otherwise
            error('Unknown attack type: %s', attackType);
    end
    z_attack = z + a;
    attack_info.type = attackType;
    attack_info.c = c;
    attack_info.a = a;
    attack_info.attackNorm = norm(a);
    attack_info.stateNorm = norm(c);
    attack_info.params = params;
    attack_info.isStealthy = true;
    attack_info.theoreticalResidualChange = norm(a - H*c);
end

function [attackedData, attackLabels, attackInfo] = generateAttackData(normalData, H, cfg)
    fprintf('=== Generating Attack Data ===\n');
    [nSamples, nFeatures] = size(normalData);
    nAttacks = floor(nSamples * cfg.attackRatio);
    attackedData = normalData;
    attackLabels = zeros(nSamples, 1);
    attackInfo = cell(nSamples, 1);
    rng(cfg.seed + 1);
    attackIdx = randperm(nSamples, nAttacks);
    nTypes = length(cfg.attackTypes);
    samplesPerType = floor(nAttacks / nTypes);
    currentIdx = 1;
    for t = 1:nTypes
        attackType = cfg.attackTypes{t};
        if t == nTypes
            typeIdx = attackIdx(currentIdx:end);
        else
            typeIdx = attackIdx(currentIdx:currentIdx + samplesPerType - 1);
        end
        fprintf('  Generating %d %s attacks...\n', length(typeIdx), attackType);
        params = getAttackParams(attackType, cfg);
        for i = 1:length(typeIdx)
            idx = typeIdx(i);
            z = normalData(idx, :)';
            if strcmp(attackType, 'ramp')
                params.rampFactor = i / length(typeIdx);
            end
            [z_attack, info] = injectFDIA(z, H, attackType, params);
            if length(z_attack) < nFeatures
                attackedData(idx, 1:length(z_attack)) = z_attack';
            else
                attackedData(idx, :) = z_attack(1:nFeatures)';
            end
            attackLabels(idx) = 1;
            attackInfo{idx} = info;
        end
        currentIdx = currentIdx + samplesPerType;
    end
    fprintf('=== Attack Generation Complete ===\n');
    fprintf('Total attacks: %d (%.1f%%)\n', sum(attackLabels), 100 * sum(attackLabels) / nSamples);
end

function params = getAttackParams(attackType, cfg)
    switch lower(attackType)
        case 'bias'
            params = cfg.attack.bias;
        case 'ramp'
            params = cfg.attack.ramp;
            params.maxMagnitude = cfg.attack.ramp.maxMag;
        case 'coordinated'
            params = cfg.attack.coordinated;
        case 'random_stealthy'
            params = cfg.attack.stealthy;
        otherwise
            params = struct();
    end
end
