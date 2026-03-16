%% GENERATE NORMAL OPERATION DATA
% Generates time-series measurement data from IEEE bus system
% Uses MATPOWER for power flow calculations
%
% Inputs:
%   cfg - Configuration struct from config()
%
% Outputs:
%   data   - [nSamples x nFeatures] measurement matrix
%   labels - [nSamples x 1] labels (all zeros for normal)
%   mpc    - MATPOWER case struct
%   meta   - Metadata about the generated data

function [data, labels, mpc, meta] = generateNormalData(cfg)
    fprintf('=== Generating Normal Operation Data ===\n');
    
    % Set random seed for reproducibility
    rng(cfg.seed);
    
    % Load IEEE bus case
    fprintf('Loading %s...\n', cfg.busCase);
    mpc = loadcase(cfg.busCase);
    
    % Run base power flow to get steady-state values
    mpopt = mpoption('verbose', 0, 'out.all', 0);
    results = runpf(mpc, mpopt);
    
    if ~results.success
        error('Base power flow did not converge!');
    end
    
    % Extract base measurements
    nBuses = size(results.bus, 1);
    V_base = results.bus(:, 8);
% Voltage magnitude(p.u.) theta_base = results.bus( :, 9);
% Voltage angle(degrees) P_base = results.bus( :, 3);
% Active power demand(MW) Q_base = results.bus( :, 4);
% Reactive power demand(MVAr)

    % Get branch power flows nBranches = size(results.branch, 1);
Pf_base = results.branch( :, 14);
% Active power flow(from) Qf_base = results.branch( :, 15);
% Reactive power flow(from)

        fprintf('System: %d buses, %d branches\n', nBuses, nBranches);

    % Initialize data matrix
    % Features: V, theta, P, Q for each bus + Pf, Qf for each branch
    nFeatures = nBuses * 4 + nBranches * 2;
    data = zeros(cfg.nSamples, nFeatures);

    fprintf('Generating %d time-series samples...\n', cfg.nSamples);

    % Progress tracking progressStep = floor(cfg.nSamples / 10);

    for
      t = 1 : cfg.nSamples %
          Realistic load variation model
          : %
            1. Daily pattern(sinusoidal) % 2. Random fluctuations(Gaussian) %
            3. Occasional load spikes

            %
            Daily load pattern(peak at t = period / 2)
                daily_factor = 1 + 0.1 * sin(2 * pi * t / cfg.period);

    % Random fluctuation random_factor = 1 + cfg.noise * randn();

    % Occasional spike(5 % chance) if rand () <
        0.05 spike_factor = 1 + 0.1 * rand();
    else spike_factor = 1;
    end

        % Combined load factor load_factor =
        daily_factor * random_factor * spike_factor;

    % Apply load variation mpc_t = mpc;
    mpc_t.bus( :, 3) = P_base * load_factor;
    mpc_t.bus( :, 4) = Q_base * load_factor;

    % Run power flow results_t = runpf(mpc_t, mpopt);

    if results_t
      .success % Extract measurements V = results_t.bus( :, 8);
    theta = results_t.bus( :, 9);
    P = results_t.bus( :, 3);
    Q = results_t.bus( :, 4);
    Pf = results_t.branch( :, 14);
    Qf = results_t.branch( :, 15);

    % Concatenate features data(t, :) = [ V ', theta', P ', Q', Pf ', Qf' ];
    else % If power flow fails,
        use previous values with small noise if t >
            1 data(t, :) = data(t - 1, :).*(1 + 0.001 * randn(1, nFeatures));
    else data(t, :) = [
      V_base ', theta_base', P_base ', Q_base', Pf_base ', Qf_base'
    ];
    end end

            % Progress update if mod (t, progressStep) ==
        0 fprintf('  Progress: %d%%\n', round(100 * t / cfg.nSamples));
    end end

        % All normal data labeled as 0 labels = zeros(cfg.nSamples, 1);

    % Create metadata meta.nBuses = nBuses;
    meta.nBranches = nBranches;
    meta.nFeatures = nFeatures;
    meta.featureNames = createFeatureNames(nBuses, nBranches);
    meta.busCase = cfg.busCase;
    meta.timestamp = datetime('now');
    meta.config = cfg;

    fprintf('=== Data Generation Complete ===\n');
    fprintf('Shape: [%d samples x %d features]\n', cfg.nSamples, nFeatures);
    end

        % % Helper function to create feature names function names =
        createFeatureNames(nBuses, nBranches) names = {};

    % Voltage magnitudes
    for i = 1:nBuses
        names{end+1} = sprintf('V_%d', i);
    end
    
    % Voltage angles
    for i = 1:nBuses
        names{end+1} = sprintf('theta_%d', i);
    end
    
    % Active power
    for i = 1:nBuses
        names{end+1} = sprintf('P_%d', i);
    end
    
    % Reactive power
    for i = 1:nBuses
        names{end+1} = sprintf('Q_%d', i);
    end
    
    % Branch active power
    for i = 1:nBranches
        names{end+1} = sprintf('Pf_%d', i);
    end
    
    % Branch reactive power
    for i = 1:nBranches
        names{end+1} = sprintf('Qf_%d', i);
    end end
