%% FOG-ASSISTED FDIA DETECTION SYSTEM - CONFIGURATION
% Global configuration parameters for the entire project
% Author: Vanshit Ahuja
% Date: February 2026

function config = config()
    %% ==================== SYSTEM PARAMETERS ====================
    % IEEE Bus System Selection
    config.busCase = 'case14';          % Options: 'case14', 'case30', 'case57', 'case118'
    config.nBuses = 14;                  % Update if changing busCase
    
    %% ==================== DATA GENERATION ====================
    config.nSamples = 2000;              % Total time-series samples
    config.trainRatio = 0.7;             % 70% training, 30% testing
    config.noise = 0.02;                 % Gaussian noise level (2%)
    config.period = 100;                 % Load variation period (samples)
    config.samplingRate = 1;             % Samples per second (simulated)
    
    %% ==================== ATTACK PARAMETERS ====================
    config.attackRatio = 0.3;            % 30% of test data will be attacked
    config.attackTypes = {'bias', 'ramp', 'coordinated', 'random_stealthy'};
    
    % Bias attack
    config.attack.bias.magnitude = 0.05; % 5% voltage deviation
    config.attack.bias.targetBuses = [4, 5, 6]; % Target specific buses
    
    % Ramp attack
    config.attack.ramp.initialMag = 0.01;
    config.attack.ramp.maxMag = 0.08;
    config.attack.ramp.duration = 50;    % Samples to reach max
    
    % Coordinated attack
    config.attack.coordinated.attackNorm = 0.1;
    config.attack.coordinated.nTargets = 5;
    
    % Random stealthy attack
    config.attack.stealthy.stealthyNorm = 0.03;
    
    %% ==================== FEATURE EXTRACTION ====================
    config.windowSize = 20;              % Sliding window size
    config.featureTypes = {'statistical', 'temporal', 'residual'};
    
    %% ==================== SVM MODEL PARAMETERS ====================
    config.svm.kernelFunction = 'rbf';
    config.svm.kernelScale = 1.0;
    config.svm.nu = 0.05;                % Expected outlier fraction
    config.svm.outlierFraction = 0.05;
    config.svm.threshold = 0;
    
    %% ==================== AUTOENCODER PARAMETERS ====================
    config.ae.hiddenSize = [64, 32, 16, 32, 64]; % Encoder-Decoder architecture
    config.ae.maxEpochs = 200;
    config.ae.l2Reg = 0.001;
    config.ae.sparsityReg = 1;
    config.ae.sparsityProp = 0.05;
    config.ae.thresholdMultiplier = 3;   % Mean + 3*std for anomaly threshold
    config.ae.learningRate = 0.001;
    
    %% ==================== FOG NODE PARAMETERS ====================
    config.fog.detectionThreshold = 0.5;
    config.fog.latencyBudget = 100;      % Maximum latency in ms
    config.fog.bufferSize = 100;         % Readings to buffer before cloud sync
    config.fog.alertSeverityLevels = {'LOW', 'MEDIUM', 'HIGH', 'CRITICAL'};
    
    %% ==================== EVALUATION PARAMETERS ====================
    config.eval.metrics = {'accuracy', 'precision', 'recall', 'f1', 'far', 'latency'};
    config.eval.confusionMatrix = true;
    config.eval.rocCurve = true;
    config.eval.savePlots = true;
    config.eval.outputDir = 'results/';
    
    %% ==================== PATHS ====================
    config.paths.data = 'data/';
    config.paths.models = 'models/saved/';
    config.paths.results = 'results/';
    config.paths.logs = 'logs/';
    
    %% ==================== RANDOM SEED ====================
    config.seed = 42;                    % For reproducibility
end
