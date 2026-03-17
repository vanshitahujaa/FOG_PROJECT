function [trustTags, consensusScores, correctedData, details] = sensorConsensus(data, mpc, cfg)
% SENSORCONSENSUS  PBFT-based physics consensus with data correction.
%   IMPROVED LAYER 2.0:
%   - Uses inverse-admittance (Y) weighting for neighbors instead of simple mean.
%   - Multi-feature anomaly scoring (V, P, Q) instead of just V.
%   - For suspicious readings, replaces measured value with Kirchhoff-weighted
%   value from neighbors. This is the CORE INNOVATION that reduces False Negatives.

    [nSamples, nFeatures] = size(data);
    nBuses = size(mpc.bus, 1);
    nBranches = size(mpc.branch, 1);

    % Build adjacency list and admittance weights from branch table
    adjList = cell(nBuses, 1);
    adjWeights = cell(nBuses, 1);
    for i = 1:nBuses
        adjList{i} = [];
        adjWeights{i} = [];
    end
    fromBus = mpc.branch(:, 1);
    toBus = mpc.branch(:, 2);
    r = mpc.branch(:, 3);
    x = mpc.branch(:, 4);
    busNums = mpc.bus(:, 1);
    for b = 1:nBranches
        fi = find(busNums == fromBus(b), 1);
        ti = find(busNums == toBus(b), 1);
        % Admittance magnitude Y = 1 / sqrt(r^2 + x^2)
        Y = 1.0 / sqrt(r(b)^2 + x(b)^2 + 1e-6);
        if ~isempty(fi) && ~isempty(ti)
            adjList{fi} = [adjList{fi}, ti];
            adjWeights{fi} = [adjWeights{fi}, Y];
            
            adjList{ti} = [adjList{ti}, fi];
            adjWeights{ti} = [adjWeights{ti}, Y];
        end
    end

    % Extract voltage readings
    V = data(:, 1:nBuses);

    % Physics validation threshold
    if isfield(cfg, 'sensorNoiseStd')
        physThreshold = 5 * cfg.sensorNoiseStd;
    else
        physThreshold = 0.15;
    end

    consensusScores = zeros(nSamples, nBuses);
    trustTags = zeros(nSamples, nBuses);
    correctedData = data;  

    nCorrected = 0;

    for t = 1:nSamples
        for i = 1:nBuses
            neighbors = adjList{i};
            w = adjWeights{i};
            if isempty(neighbors)
                consensusScores(t, i) = 0;
                trustTags(t, i) = 0;
                continue;
            end
            
            % Normalize weights to sum to 1
            w_norm = w / sum(w);

            % 1. Weighted Physics Predictions
            neighborVoltages = V(t, neighbors);
            predictedV = sum(neighborVoltages .* w_norm);
            measuredV = V(t, i);
            
            thetaCol = nBuses + i;
            pCol = 2*nBuses + i;
            qCol = 3*nBuses + i;
            
            % 2. Multi-feature Anomaly Scoring
            vDev = abs(measuredV - predictedV) / max(std(neighborVoltages), 0.01);
            pDev = 0; qDev = 0;
            
            predictedP = 0; predictedQ = 0; predictedTheta = 0;
            if pCol <= nFeatures
                neighborP = data(t, 2*nBuses + neighbors);
                predictedP = sum(neighborP .* w_norm);
                pDev = abs(data(t, pCol) - predictedP) / max(std(neighborP), 0.01);
            end
            if qCol <= nFeatures
                neighborQ = data(t, 3*nBuses + neighbors);
                predictedQ = sum(neighborQ .* w_norm);
                qDev = abs(data(t, qCol) - predictedQ) / max(std(neighborQ), 0.01);
            end
            if thetaCol <= nFeatures
                neighborThetas = data(t, nBuses + neighbors);
                predictedTheta = sum(neighborThetas .* w_norm);
            end

            % Combine z-scores
            zScore = (vDev + pDev + qDev) / 3.0;
            consensusScores(t, i) = min(1.0, zScore / 5.0);

            % 3. PBFT Vote (using weighted expected values)
            votesOK = 0;
            for ni = 1:length(neighbors)
                nIdx = neighbors(ni);
                nW_norm = adjWeights{nIdx} / sum(adjWeights{nIdx});
                expected = sum(V(t, adjList{nIdx}) .* nW_norm);
                if abs(measuredV - expected) < physThreshold
                    votesOK = votesOK + 1;
                end
            end

            % PBFT: > 2/3 agreement needed
            if votesOK >= ceil(2 * length(neighbors) / 3)
                trustTags(t, i) = 0;  % Trusted
            else
                trustTags(t, i) = 1;  % Suspicious

                % =========================================================
                % CORE INNOVATION: Physics-based data correction (Weighted)
                % =========================================================
                correctedData(t, i) = predictedV;
                if thetaCol <= nFeatures, correctedData(t, thetaCol) = predictedTheta; end
                if pCol <= nFeatures,     correctedData(t, pCol) = predictedP; end
                if qCol <= nFeatures,     correctedData(t, qCol) = predictedQ; end

                nCorrected = nCorrected + 1;
            end
        end
    end

    details.nBuses = nBuses;
    details.adjList = adjList;
    details.adjWeights = adjWeights;
    details.physThreshold = physThreshold;
    details.flaggedRate = sum(trustTags(:)) / numel(trustTags) * 100;
    details.nCorrected = nCorrected;
    fprintf('Sensor Consensus: %.1f%% flagged suspicious, %d values corrected\n', ...
        details.flaggedRate, nCorrected);
end
