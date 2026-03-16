%% FOG NODE SIMULATION
% Simulates fog layer detection node for real-time FDIA detection
%
% Responsibilities:
%   - Real-time anomaly detection
%   - Local decision making
%   - Alert generation and cloud sync
%   - Latency tracking
%
% Usage:
%   fogNode = FogNode(model, cfg);
% [ isAttack, latency ] = fogNode.processReading(reading, timestamp);

classdef FogNode < handle
    properties
        model           % Trained detection model
        modelType       % 'svm' or 'autoencoder'
        buffer          % Sliding window buffer
        windowSize      % Feature extraction window
        alertQueue      % Pending alerts for cloud
        localDecisions  % Local decision history
        latencyLog      % Detection latency measurements
        config          % Configuration
        stats           % Running statistics
        H               % Jacobian matrix for residual features
    end
    
    methods
        %% Constructor
        function obj = FogNode(model, cfg, H)
            obj.model = model;
obj.config = cfg;
obj.windowSize = cfg.windowSize;
obj.buffer = [];
obj.alertQueue = {};
obj.localDecisions = [];
obj.latencyLog = [];

% Determine model type if isfield (model, 'svm') obj.modelType = 'svm';
else obj.modelType = 'autoencoder';
end

    if nargin >= 3 obj.H = H;
else obj.H = [];
end

    % Initialize statistics obj.stats.totalReadings = 0;
obj.stats.attacksDetected = 0;
obj.stats.normalDetected = 0;
obj.stats.avgLatency = 0;

fprintf('Fog Node initialized with %s model\n', obj.modelType);
end

    % %
    Process single reading(real - time simulation)
        function[isAttack, latency, details] = processReading(obj, reading,
                                                              timestamp) tic;

% Update statistics obj.stats.totalReadings = obj.stats.totalReadings + 1;

            % Add to buffer
            if isrow(reading)
                reading = reading';
            end
            obj.buffer = [obj.buffer; reading'];
            
            if size(obj.buffer, 1) >= obj.windowSize
                % Extract features
                cfgTemp = obj.config;
                if ~isempty(obj.H)
                    [features, ~] = extractFeatures(obj.buffer, cfgTemp, obj.H);
                else
                    cfgTemp.featureTypes = {'statistical', 'temporal'};
                    [features, ~] = extractFeatures(obj.buffer, cfgTemp);
                end
                
                % Detect anomaly
                [isAttack, score, details] = detectAnomaly(obj.model, features, obj.modelType);
                isAttack = isAttack(end);  % Take last window result
                
                % Record local decision
                obj.localDecisions = [obj.localDecisions; isAttack];
                
                % Queue alert for cloud if attack detected
                if isAttack
                    obj.stats.attacksDetected = obj.stats.attacksDetected + 1;
                    
                    alert.timestamp = timestamp;
                    alert.score = score(end);
                    alert.severity = obj.classifySeverity(score(end));
                    alert.features = features(end, :);
                    alert.reading = reading';
                    
                    obj.alertQueue{end+1} = alert;
                else
                    obj.stats.normalDetected = obj.stats.normalDetected + 1;
                end
                
                % Slide window (keep last windowSize-1 samples)
                obj.buffer = obj.buffer(end-obj.windowSize+2:end, :);
            else
                isAttack = false;
                details = struct('message', 'Buffering', 'bufferSize', size(obj.buffer, 1));
            end
            
            latency = toc * 1000;  % Convert to ms
            obj.latencyLog = [obj.latencyLog; latency];
            obj.stats.avgLatency = mean(obj.latencyLog);
            
            details.latency = latency;
            details.bufferSize = size(obj.buffer, 1);
        end
        
        %% Process batch of readings
        function [results, totalLatency] = processBatch(obj, readings, timestamps)
            nReadings = size(readings, 1);
            results = struct();
            results.predictions = zeros(nReadings, 1);
            results.latencies = zeros(nReadings, 1);
            results.scores = zeros(nReadings, 1);
            
            fprintf('Processing %d readings...\n', nReadings);
            progressStep = floor(nReadings / 10);
            
            for i = 1:nReadings
                [isAttack, latency, details] = obj.processReading(readings(i, :), timestamps(i));
                results.predictions(i) = isAttack;
                results.latencies(i) = latency;
                if isfield(details, 'score')
                    results.scores(i) = details.score;
                end
                
                if mod(i, progressStep) == 0
                    fprintf('  Progress: %d%%\n', round(100 * i / nReadings));
                end
            end
            
            totalLatency = sum(results.latencies);
            fprintf('Batch processing complete. Total time: %.2f ms\n', totalLatency);
        end
        
        %% Classify alert severity
        function severity = classifySeverity(obj, score)
            levels = obj.config.fog.alertSeverityLevels;
            
            if score > 0.9
                severity = levels{4};  % CRITICAL
            elseif score > 0.7
                severity = levels{3};  % HIGH
            elseif score > 0.5
                severity = levels{2};  % MEDIUM
            else
                severity = levels{1};  % LOW
            end
        end
        
        %% Flush alerts to cloud
        function alerts = flushAlerts(obj)
            alerts = obj.alertQueue;
            obj.alertQueue = {};
            
            fprintf('Flushed %d alerts to cloud\n', length(alerts));
        end
        
        %% Get node statistics
        function stats = getStats(obj)
            stats = obj.stats;
            stats.detectionRate = stats.attacksDetected / ...
                (stats.attacksDetected + stats.normalDetected + 1e-10);
            stats.latencyStats.mean = mean(obj.latencyLog);
            stats.latencyStats.std = std(obj.latencyLog);
            stats.latencyStats.max = max(obj.latencyLog);
            stats.latencyStats.min = min(obj.latencyLog);
            stats.latencyStats.p95 = prctile(obj.latencyLog, 95);
        end
        
        %% Reset node state
        function reset(obj)
            obj.buffer = [];
            obj.alertQueue = {};
            obj.localDecisions = [];
            obj.latencyLog = [];
            obj.stats.totalReadings = 0;
            obj.stats.attacksDetected = 0;
            obj.stats.normalDetected = 0;
            obj.stats.avgLatency = 0;
        end
        
        %% Display node status
        function displayStatus(obj)
            fprintf('\n=== Fog Node Status ===\n');
            fprintf('Model: %s\n', obj.modelType);
            fprintf('Buffer size: %d/%d\n', size(obj.buffer, 1), obj.windowSize);
            fprintf('Total readings processed: %d\n', obj.stats.totalReadings);
            fprintf('Attacks detected: %d\n', obj.stats.attacksDetected);
            fprintf('Normal readings: %d\n', obj.stats.normalDetected);
            fprintf('Pending alerts: %d\n', length(obj.alertQueue));
            fprintf('Average latency: %.2f ms\n', obj.stats.avgLatency);
            fprintf('=======================\n');
        end
    end
end
