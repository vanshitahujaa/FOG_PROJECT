classdef TrustManager < handle
% TRUSTMANAGER  Manages per-sensor reputation/trust scores.
%   Sensors that consistently agree with consensus maintain high trust.
%   Sensors frequently flagged as suspicious lose trust over time.

    properties
        trustScores     % [1 x nBuses] current trust scores
        nBuses          % Number of buses
        alpha           % Exponential moving average decay factor
        history         % Cell array tracking trust evolution
    end

    methods
        function obj = TrustManager(nBuses, alpha)
            if nargin < 2
                alpha = 0.9;
            end
            obj.nBuses = nBuses;
            obj.alpha = alpha;
            obj.trustScores = ones(1, nBuses);  % All start fully trusted
            obj.history = {};
            fprintf('TrustManager initialized: %d sensors, alpha=%.2f\n', nBuses, alpha);
        end

        function updateTrust(obj, trustTags, consensusScores)
            % Update trust based on consensus results
            % trustTags: [nSamples x nBuses] (0=trusted, 1=suspicious)
            % consensusScores: [nSamples x nBuses] (0-1 anomaly score)

            nSamples = size(trustTags, 1);

            for i = 1:obj.nBuses
                % Agreement rate: fraction of samples where bus was trusted
                agreementRate = 1 - mean(trustTags(:, i));
                avgAnomalyScore = mean(consensusScores(:, i));

                % Exponential moving average update
                % High agreement → trust stays high
                % Low agreement → trust decays
                trustUpdate = agreementRate * (1 - avgAnomalyScore);
                obj.trustScores(i) = obj.alpha * obj.trustScores(i) + ...
                    (1 - obj.alpha) * trustUpdate;

                % Clamp to [0.1, 1.0] — never fully distrust (sensor could recover)
                obj.trustScores(i) = max(0.1, min(1.0, obj.trustScores(i)));
            end

            % Log to history
            entry.timestamp = datetime('now');
            entry.scores = obj.trustScores;
            entry.nSamples = nSamples;
            obj.history{end+1} = entry;
        end

        function w = getTrustWeights(obj)
            % Return normalized weights for use in consensus voting
            w = obj.trustScores / sum(obj.trustScores);
        end

        function displayStatus(obj)
            fprintf('\n--- Trust Manager Status ---\n');
            fprintf('Sensor Trust Scores:\n');
            for i = 1:obj.nBuses
                bar = repmat('=', 1, round(obj.trustScores(i) * 20));
                if obj.trustScores(i) < 0.5
                    status = 'LOW';
                elseif obj.trustScores(i) < 0.8
                    status = 'MEDIUM';
                else
                    status = 'HIGH';
                end
                fprintf('  Bus %2d: %.3f [%-20s] %s\n', i, obj.trustScores(i), bar, status);
            end
            fprintf('Updates performed: %d\n', length(obj.history));
        end
    end
end
