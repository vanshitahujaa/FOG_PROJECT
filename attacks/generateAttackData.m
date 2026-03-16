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
