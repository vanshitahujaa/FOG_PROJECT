classdef FogNode < handle
    properties
        model
        modelType
        cfg
        H
        buffer
        bufferSize
        windowSize
        alerts
        stats
        latencyLog
    end
    methods
        function obj = FogNode(model, cfg, H)
            obj.model = model;
            obj.cfg = cfg;
            obj.H = H;
            obj.windowSize = cfg.windowSize;
            obj.bufferSize = cfg.fog.bufferSize;
            obj.buffer = [];
            obj.alerts = {};
            obj.latencyLog = [];
            if isfield(model, 'svm')
                obj.modelType = 'svm';
            elseif isfield(model, 'rf')
                obj.modelType = 'randomforest';
            elseif isfield(model, 'knn')
                obj.modelType = 'knn';
            elseif isfield(model, 'P') && isfield(model, 'T2_threshold')
                obj.modelType = 'pca';
            else
                obj.modelType = 'autoencoder';
            end
            obj.stats.totalProcessed = 0;
            obj.stats.attacksDetected = 0;
            obj.stats.avgLatency = 0;
            obj.stats.maxLatency = 0;
            fprintf('FogNode initialized with %s model\n', obj.modelType);
        end
        function [isAttack, latency, details] = processReading(obj, reading, timestamp)
            tic;
            obj.buffer = [obj.buffer; reading];
            if size(obj.buffer, 1) > obj.bufferSize
                obj.buffer = obj.buffer(end-obj.bufferSize+1:end, :);
            end
            isAttack = false;
            details = struct();
            if size(obj.buffer, 1) >= obj.windowSize
                windowData = obj.buffer(end-obj.windowSize+1:end, :);
                [features, ~] = extractFeatures(windowData, obj.cfg, obj.H);
                if ~isempty(features)
                    [isAttack, score, details] = detectAnomaly(obj.model, features(end, :), obj.modelType);
                    if isAttack
                        obj.stats.attacksDetected = obj.stats.attacksDetected + 1;
                        alert.timestamp = timestamp;
                        alert.score = score;
                        alert.modelType = obj.modelType;
                        if score > 0.9
                            alert.severity = 'CRITICAL';
                        elseif score > 0.7
                            alert.severity = 'HIGH';
                        elseif score > 0.5
                            alert.severity = 'MEDIUM';
                        else
                            alert.severity = 'LOW';
                        end
                        alert.details = details;
                        obj.alerts{end+1} = alert;
                    end
                end
            end
            latency = toc * 1000;
            obj.latencyLog(end+1) = latency;
            obj.stats.totalProcessed = obj.stats.totalProcessed + 1;
            obj.stats.avgLatency = mean(obj.latencyLog);
            obj.stats.maxLatency = max(obj.latencyLog);
        end
        function [results, totalLatency] = processBatch(obj, data, timestamps)
            nSamples = size(data, 1);
            results.predictions = zeros(nSamples, 1);
            results.latencies = zeros(nSamples, 1);
            for i = 1:nSamples
                [isAttack, latency, ~] = obj.processReading(data(i, :), timestamps(i));
                results.predictions(i) = isAttack;
                results.latencies(i) = latency;
            end
            totalLatency = sum(results.latencies);
            fprintf('Batch: %d samples, %d attacks detected\n', nSamples, sum(results.predictions));
        end
        function alerts = flushAlerts(obj)
            alerts = obj.alerts;
            obj.alerts = {};
        end
        function displayStatus(obj)
            fprintf('\n--- Fog Node Status ---\n');
            fprintf('Model: %s\n', obj.modelType);
            fprintf('Processed: %d\n', obj.stats.totalProcessed);
            fprintf('Attacks: %d\n', obj.stats.attacksDetected);
            fprintf('Avg latency: %.2f ms\n', obj.stats.avgLatency);
            fprintf('Max latency: %.2f ms\n', obj.stats.maxLatency);
        end
        function reset(obj)
            obj.buffer = [];
            obj.alerts = {};
            obj.latencyLog = [];
            obj.stats.totalProcessed = 0;
            obj.stats.attacksDetected = 0;
            obj.stats.avgLatency = 0;
            obj.stats.maxLatency = 0;
        end
    end
end
