function [trustTags, consensusScores, correctedData, details] = sensorConsensus(data, mpc, cfg)
% SENSORCONSENSUS  PBFT-based physics consensus with data correction.
%   For suspicious readings, replaces measured value with Kirchhoff-predicted
%   value from neighbor consensus. This is the CORE INNOVATION.
%   trustTags: 0 = trusted, 1 = suspicious
%   consensusScores: anomaly score per bus per sample (0-1)
%   correctedData: data with suspicious readings replaced by neighbor predictions

    [nSamples, nFeatures] = size(data);
    nBuses = size(mpc.bus, 1);
    nBranches = size(mpc.branch, 1);

    % Build adjacency list from branch table
    adjList = cell(nBuses, 1);
    for i = 1:nBuses
        adjList{i} = [];
    end
    fromBus = mpc.branch(:, 1);
    toBus = mpc.branch(:, 2);
    busNums = mpc.bus(:, 1);
    for b = 1:nBranches
        fi = find(busNums == fromBus(b), 1);
        ti = find(busNums == toBus(b), 1);
        if ~isempty(fi) && ~isempty(ti)
            adjList{fi} = [adjList{fi}, ti];
            adjList{ti} = [adjList{ti}, fi];
        end
    end

    % Extract voltage readings (first nBuses columns)
    V = data(:, 1:nBuses);

    % Physics validation threshold
    if isfield(cfg, 'sensorNoiseStd')
        physThreshold = 5 * cfg.sensorNoiseStd;
    else
        physThreshold = 0.15;
    end

    consensusScores = zeros(nSamples, nBuses);
    trustTags = zeros(nSamples, nBuses);
    correctedData = data;  % Start with a copy of original data

    nCorrected = 0;

    for t = 1:nSamples
        for i = 1:nBuses
            neighbors = adjList{i};
            if isempty(neighbors)
                consensusScores(t, i) = 0;
                trustTags(t, i) = 0;
                continue;
            end

            % Kirchhoff-based validation:
            % Predicted voltage at bus i ~ weighted average of neighbor voltages
            neighborVoltages = V(t, neighbors);
            predictedV = mean(neighborVoltages);
            measuredV = V(t, i);

            % Voltage deviation from neighborhood consensus
            voltageDeviation = abs(measuredV - predictedV);

            % Z-score relative to neighbor spread
            neighborStd = std(neighborVoltages);
            if neighborStd < 1e-6
                neighborStd = 0.01;
            end
            zScore = voltageDeviation / neighborStd;

            % Combined anomaly score
            consensusScores(t, i) = min(1.0, zScore / 5.0);

            % PBFT vote: count how many neighbors "agree" this reading is OK
            nNeighbors = length(neighbors);
            votesOK = 0;
            for ni = 1:nNeighbors
                nIdx = neighbors(ni);
                expected = mean(V(t, adjList{nIdx}));
                if abs(measuredV - expected) < physThreshold
                    votesOK = votesOK + 1;
                end
            end

            % PBFT: need > 2/3 agreement to be trusted
            if votesOK >= ceil(2 * nNeighbors / 3)
                trustTags(t, i) = 0;  % Trusted
            else
                trustTags(t, i) = 1;  % Suspicious

                % =========================================================
                % CORE INNOVATION: Physics-based data correction
                % Replace suspicious measurement with Kirchhoff prediction
                % =========================================================
                correctedData(t, i) = predictedV;  % Voltage column

                % Also correct the corresponding theta, P, Q columns
                % using neighbor averages for those quantities too
                thetaCol = nBuses + i;
                pCol = 2*nBuses + i;
                qCol = 3*nBuses + i;

                if thetaCol <= nFeatures
                    neighborThetas = data(t, nBuses + neighbors);
                    correctedData(t, thetaCol) = mean(neighborThetas);
                end
                if pCol <= nFeatures
                    neighborP = data(t, 2*nBuses + neighbors);
                    correctedData(t, pCol) = mean(neighborP);
                end
                if qCol <= nFeatures
                    neighborQ = data(t, 3*nBuses + neighbors);
                    correctedData(t, qCol) = mean(neighborQ);
                end

                nCorrected = nCorrected + 1;
            end
        end
    end

    details.nBuses = nBuses;
    details.adjList = adjList;
    details.physThreshold = physThreshold;
    details.flaggedRate = sum(trustTags(:)) / numel(trustTags) * 100;
    details.nCorrected = nCorrected;
    fprintf('Sensor Consensus: %.1f%% flagged suspicious, %d values corrected\n', ...
        details.flaggedRate, nCorrected);
end
