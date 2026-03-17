function [trustTags, consensusScores, details] = sensorConsensus(data, mpc, cfg)
% SENSORCONSENSUS  PBFT-based physics consensus among neighboring sensors.
%   For each bus, neighboring buses cross-validate readings using
%   Kirchhoff's voltage and power balance laws.
%   trustTags: 0 = trusted, 1 = suspicious
%   consensusScores: anomaly score per bus per sample (0-1)

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
    % Map external bus numbers to internal indices
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

    % Physics validation threshold (based on noise level)
    if isfield(cfg, 'sensorNoiseStd')
        physThreshold = 5 * cfg.sensorNoiseStd;
    else
        physThreshold = 0.15;
    end

    consensusScores = zeros(nSamples, nBuses);
    trustTags = zeros(nSamples, nBuses);

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
            % (simplified: in a lossless network, voltages propagate with small drops)
            neighborVoltages = V(t, neighbors);
            predictedV = mean(neighborVoltages);
            measuredV = V(t, i);

            % Voltage deviation from neighborhood consensus
            voltageDeviation = abs(measuredV - predictedV);

            % Also check if this bus's voltage is an outlier vs neighbors
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
                % Neighbor says "OK" if bus_i voltage is close to what they'd expect
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
            end
        end
    end

    details.nBuses = nBuses;
    details.adjList = adjList;
    details.physThreshold = physThreshold;
    details.flaggedRate = sum(trustTags(:)) / numel(trustTags) * 100;
    fprintf('Sensor Consensus: %.1f%% of bus readings flagged suspicious\n', details.flaggedRate);
end
