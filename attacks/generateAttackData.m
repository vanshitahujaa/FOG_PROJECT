function [attackedData, attackLabels, attackInfo] = generateAttackData(normalData, H, cfg)
    fprintf('=== Generating Attack Data ===\n');
    [nSamples, nFeatures] = size(normalData);
    nAttacks = floor(nSamples * cfg.attackRatio);
    attackedData = normalData;
    attackLabels = zeros(nSamples, 1);
    attackInfo = cell(nSamples, 1);
    rng(cfg.seed + 1);

    % --- CONTIGUOUS BURST ATTACK INJECTION ---
    % Instead of attacking random individual samples, inject attacks in
    % contiguous bursts of 20-50 consecutive samples. This is realistic:
    % real attackers maintain temporal consistency.
    nTypes = length(cfg.attackTypes);
    attacksPerType = floor(nAttacks / nTypes);

    % Generate burst start positions spread across the timeline
    minBurstLen = 15;
    maxBurstLen = 50;
    attackedSoFar = 0;
    typeCounter = 1;
    attackType = cfg.attackTypes{typeCounter};
    attacksInCurrentType = 0;

    % Pre-plan burst locations to avoid overlapping
    burstStarts = [];
    burstLens = [];
    pos = randi([10, 30]);  % Start after some normal samples
    while attackedSoFar < nAttacks && pos < nSamples - minBurstLen
        burstLen = randi([minBurstLen, maxBurstLen]);
        burstLen = min(burstLen, nSamples - pos);
        burstLen = min(burstLen, nAttacks - attackedSoFar);
        burstStarts(end+1) = pos;
        burstLens(end+1) = burstLen;
        attackedSoFar = attackedSoFar + burstLen;
        % Gap between bursts (normal data)
        gap = randi([20, 80]);
        pos = pos + burstLen + gap;
    end

    fprintf('  Planned %d attack bursts across timeline\n', length(burstStarts));

    % Inject attacks into each burst
    attackedSoFar = 0;
    typeCounter = 1;
    attacksInCurrentType = 0;
    for b = 1:length(burstStarts)
        bStart = burstStarts(b);
        bLen = burstLens(b);

        % Determine current attack type
        if typeCounter <= nTypes
            attackType = cfg.attackTypes{typeCounter};
        end
        params = getAttackParams(attackType, cfg);

        fprintf('  Burst %d: %d %s attacks at samples %d-%d\n', ...
            b, bLen, attackType, bStart, bStart+bLen-1);

        for i = 1:bLen
            idx = bStart + i - 1;
            if idx > nSamples, break; end
            z = normalData(idx, :)';

            % --- GRADUAL ONSET: first 20% of burst ramps up from 0 to full ---
            onsetFraction = min(1.0, i / max(1, floor(bLen * 0.2)));

            if strcmp(attackType, 'ramp')
                params.rampFactor = i / bLen;
            end

            [z_attack, info] = injectFDIA(z, H, attackType, params);

            % Apply gradual onset: blend between normal and attacked
            % z_attack may be shorter than z (truncated to H measurement count)
            nAtt = length(z_attack);
            z_orig_sub = z(1:nAtt);
            z_blended_sub = z_orig_sub + onsetFraction * (z_attack - z_orig_sub);

            % Write back into full feature vector
            attackedData(idx, 1:nAtt) = z_blended_sub';
            attackLabels(idx) = 1;
            info.onsetFraction = onsetFraction;
            info.burstId = b;
            info.positionInBurst = i;
            attackInfo{idx} = info;
        end

        attacksInCurrentType = attacksInCurrentType + bLen;
        if attacksInCurrentType >= attacksPerType && typeCounter < nTypes
            typeCounter = typeCounter + 1;
            attacksInCurrentType = 0;
        end
    end

    fprintf('=== Attack Generation Complete ===\n');
    fprintf('Total attacks: %d (%.1f%%)\n', sum(attackLabels), 100 * sum(attackLabels) / nSamples);
    fprintf('Attack types used: %d, Bursts: %d\n', min(typeCounter, nTypes), length(burstStarts));
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
        case 'scaling'
            params = cfg.attack.scaling;
        case 'targeted'
            params = cfg.attack.targeted;
        otherwise
            params = struct();
    end
end
