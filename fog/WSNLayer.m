classdef WSNLayer < handle
% WSNLAYER  Simulates a Wireless Sensor Network for Smart Grid Monitoring.
%   Nodes -> K-means Clustering -> Energy/Trust-Aware CH Selection -> Aggregation.

    properties
        nNodes
        area
        nBuses
        pos
        energy
        trust
        mappedBus      % Which grid bus this node targets (1..nBuses)
        k              % Number of clusters
        cluster        % Cluster indices (nNodesx1)
        centroids      % Cluster centers
        clusterHeads   % Node index of the CH for each cluster
        deadNodes
    end

    methods
        function obj = WSNLayer(nNodes, area, nBuses)
            obj.nNodes = nNodes;
            obj.area = area;
            obj.nBuses = nBuses;
            
            % Step 1: Node Deployment
            obj.pos = rand(nNodes, 2) * area;
            % Heterogeneous initial energy (0.5 to 1.0)
            obj.energy = 0.5 + rand(nNodes, 1) * 0.5;
            % All nodes start fully trusted
            obj.trust = ones(nNodes, 1);
            
            % Randomly assign nodes to monitor a specific bus
            obj.mappedBus = randi(nBuses, nNodes, 1);
            obj.deadNodes = false(nNodes, 1);
            
            % Step 3: Cluster Formation
            obj.k = round(sqrt(nNodes));
            obj.formClusters();
            
            % Step 4: Cluster Head Selection
            obj.selectClusterHeads();
            
            fprintf('WSN Layer Initialized: %d nodes, %d clusters\n', obj.nNodes, obj.k);
        end

        function formClusters(obj)
            % Use K-means for cluster formation
            % Perform clustering only on alive nodes
            aliveIdx = find(~obj.deadNodes);
            if isempty(aliveIdx)
                return;
            end
            
            effectiveK = min(obj.k, length(aliveIdx));
            X = obj.pos(aliveIdx, :);
            
            % Custom K-means (no toolbox required)
            nAlive = length(aliveIdx);
            randStart = randperm(nAlive, effectiveK);
            C = X(randStart, :);
            idx = zeros(nAlive, 1);
            
            for iter = 1:50
                oldIdx = idx;
                
                % Assign to nearest
                for i = 1:nAlive
                    dists = sum((C - X(i, :)).^2, 2);
                    [~, minId] = min(dists);
                    idx(i) = minId;
                end
                
                % Update centroids
                for c = 1:effectiveK
                    members = X(idx == c, :);
                    if ~isempty(members)
                        C(c, :) = mean(members, 1);
                    end
                end
                
                if all(idx == oldIdx)
                    break;
                end
            end
            
            obj.cluster = zeros(obj.nNodes, 1);
            obj.cluster(aliveIdx) = idx;
            obj.centroids = C;
            obj.k = effectiveK;
        end

        function selectClusterHeads(obj)
            % NOVEL: Cluster Head Selection combining Energy, Trust, and Distance
            obj.clusterHeads = zeros(obj.k, 1);
            for c = 1:obj.k
                % Find active nodes in this cluster
                clusterNodes = find(obj.cluster == c & ~obj.deadNodes);
                if isempty(clusterNodes)
                    continue;
                end
                
                centroid = obj.centroids(c, :);
                % L2 distance to centroid
                d = vecnorm(obj.pos(clusterNodes, :) - centroid, 2, 2);
                
                % Normalize distance inverse to reasonable values
                distInv = 1 ./ (d + 1e-3);
                distNorm = distInv / max(distInv);
                
                % SCORE FORMULA
                score = 0.4 * obj.energy(clusterNodes) + ...
                        0.4 * obj.trust(clusterNodes) + ...
                        0.2 * distNorm;
                
                [~, idxMax] = max(score);
                obj.clusterHeads(c) = clusterNodes(idxMax);
            end
        end

        function aggRow = aggregateData(obj, rawRow)
            % Step 5: Data Aggregation
            % Simulates Nodes -> Cluster Head -> Fog Node traffic
            
            % 1. Energy drain for transmission
            activeNodes = ~obj.deadNodes;
            obj.energy(activeNodes) = obj.energy(activeNodes) - 0.0001;
            
            % CHs drain more energy
            activeCHs = obj.clusterHeads(obj.clusterHeads > 0);
            obj.energy(activeCHs) = max(0, obj.energy(activeCHs) - 0.002);
            
            % Check dead nodes
            obj.deadNodes = obj.energy <= 0;
            
            % 2. Aggregation simulation
            % In reality, nodes measure specific traits. For simplicity in the pipeline,
            % every cluster averages the reading with slight noise, then Fog Node 
            % combines the CHs.
            
            nFeatures = length(rawRow);
            clusterAgg = zeros(obj.k, nFeatures);
            validClusters = 0;
            
            for c = 1:obj.k
                ch = obj.clusterHeads(c);
                if ch == 0 || obj.deadNodes(ch)
                    continue; % Dead CH
                end
                
                members = find(obj.cluster == c & ~obj.deadNodes);
                if isempty(members)
                    continue;
                end
                
                % CH collects from members (introducing small sensor noise)
                nodeReadings = repmat(rawRow, length(members), 1) + randn(length(members), nFeatures) * 0.005;
                
                % CH aggregates
                clusterAgg(c, :) = mean(nodeReadings, 1);
                validClusters = validClusters + 1;
            end
            
            if validClusters == 0
                % Fallback if whole network dies
                aggRow = rawRow;
                return;
            end
            
            % 3. Fog Node combines CH data, weighted by CH trust
            % Higher trust CHs have larger influence on the final reading
            chTrusts = zeros(obj.k, 1);
            for c = 1:obj.k
                ch = obj.clusterHeads(c);
                if ch > 0
                    chTrusts(c) = obj.trust(ch);
                end
            end
            
            w = chTrusts / (sum(chTrusts) + 1e-6);
            aggRow = sum(clusterAgg .* w, 1);
        end

        function updateTrust(obj, flaggedBuses)
            % Step 7: Trust Update Loop
            % Called after Fog Node / Consensus makes a decision
            % Decrements trust for nodes providing suspicious data, increments otherwise.
            
            for i = 1:obj.nNodes
                if obj.deadNodes(i)
                    continue;
                end
                
                b = obj.mappedBus(i);
                if ismember(b, flaggedBuses)
                    % Penalty for flagged node
                    obj.trust(i) = max(0.1, obj.trust(i) * 0.9);
                else
                    % Reward for normal operation
                    obj.trust(i) = min(1.0, obj.trust(i) + 0.01);
                end
            end
        end

        function plotNetwork(obj, savePath)
            % Visualizes the WSN in 2D space
            fig = figure('Name', 'WSN Deployment', 'Visible', 'off');
            hold on;
            
            % Plot full clusters
            colors = lines(obj.k);
            for c = 1:obj.k
                members = find(obj.cluster == c & ~obj.deadNodes);
                if ~isempty(members)
                    scatter(obj.pos(members, 1), obj.pos(members, 2), 20, colors(c, :), 'filled', 'MarkerFaceAlpha', 0.5);
                end
            end
            
            % Highlight suspicious nodes (Trust < 0.5) in RED
            suspiciousNodes = find(obj.trust < 0.5 & ~obj.deadNodes);
            if ~isempty(suspiciousNodes)
                scatter(obj.pos(suspiciousNodes, 1), obj.pos(suspiciousNodes, 2), 40, 'r', 'x', 'LineWidth', 1.5);
            end
            
            % Highlight dead nodes in BLACK
            dead = find(obj.deadNodes);
            if ~isempty(dead)
                scatter(obj.pos(dead, 1), obj.pos(dead, 2), 20, 'k', 'filled');
            end
            
            % Highlight Cluster Heads with large stars
            validIdx = obj.clusterHeads > 0;
            activeCHs = obj.clusterHeads(validIdx);
            activeCHs = activeCHs(~obj.deadNodes(activeCHs));
            if ~isempty(activeCHs)
                scatter(obj.pos(activeCHs, 1), obj.pos(activeCHs, 2), 150, 'p', 'filled', 'MarkerFaceColor', 'y', 'MarkerEdgeColor', 'k');
            end
            
            title('Wireless Sensor Network Layer (Clustering & CHs)');
            xlabel('X Distance (m)');
            ylabel('Y Distance (m)');
            grid on;
            box on;
            hold off;
            
            if nargin > 1 && ~isempty(savePath)
                saveas(gcf, savePath);
            end
        end
    end
end
