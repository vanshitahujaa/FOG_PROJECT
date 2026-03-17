function [data, labels, mpc, meta] = generateNormalData(cfg)
    fprintf('=== Generating Normal Operation Data ===\n');
    rng(cfg.seed);
    fprintf('Loading %s...\n', cfg.busCase);
    mpc = loadcase(cfg.busCase);
    mpopt = mpoption('verbose', 0, 'out.all', 0);
    results = runpf(mpc, mpopt);
    if ~results.success
        error('Base power flow did not converge!');
    end
    nBuses = size(results.bus, 1);
    V_base = results.bus(:, 8);
    theta_base = results.bus(:, 9);
    P_base = results.bus(:, 3);
    Q_base = results.bus(:, 4);
    nBranches = size(results.branch, 1);
    Pf_base = results.branch(:, 14);
    Qf_base = results.branch(:, 15);
    fprintf('System: %d buses, %d branches\n', nBuses, nBranches);
    nFeatures = nBuses * 4 + nBranches * 2;
    data = zeros(cfg.nSamples, nFeatures);
    fprintf('Generating %d time-series samples...\n', cfg.nSamples);
    progressStep = floor(cfg.nSamples / 10);

    % Per-sensor noise standard deviations (realistic: each sensor has different accuracy)
    sensorNoiseStd = cfg.sensorNoiseStd;
    V_noise_std = sensorNoiseStd * (0.5 + rand(nBuses, 1));       % Voltage: 1.5-4.5% noise
    theta_noise_std = sensorNoiseStd * (0.8 + 1.2*rand(nBuses, 1)); % Angle: 2.4-6% noise
    P_noise_std = sensorNoiseStd * (1.0 + 2.0*rand(nBuses, 1));     % Active power: 3-9% noise
    Q_noise_std = sensorNoiseStd * (1.0 + 2.0*rand(nBuses, 1));     % Reactive power: 3-9% noise
    Pf_noise_std = sensorNoiseStd * (0.8 + 1.5*rand(nBranches, 1)); % Branch P flow: 2.4-6.9% noise
    Qf_noise_std = sensorNoiseStd * (0.8 + 1.5*rand(nBranches, 1)); % Branch Q flow: 2.4-6.9% noise

    for t = 1:cfg.nSamples
        % Realistic daily load curve with multiple harmonics
        hour_of_day = mod(t, cfg.period) / cfg.period * 24;
        daily_factor = 1 + 0.15 * sin(2 * pi * t / cfg.period) ...
                         + 0.05 * sin(4 * pi * t / cfg.period) ...
                         + 0.03 * cos(6 * pi * t / cfg.period);

        % Random global load fluctuation (higher variance = more realistic)
        random_factor = 1 + cfg.noise * randn();

        % Occasional load spikes and dips (10% chance, higher magnitude)
        if rand() < 0.10
            spike_factor = 1 + 0.15 * (2*rand() - 1);  % +/- 15% spikes
        else
            spike_factor = 1;
        end

        % PER-BUS random variation (each bus fluctuates independently)
        bus_variation = 1 + 0.03 * randn(nBuses, 1);

        load_factor = daily_factor * random_factor * spike_factor;
        mpc_t = mpc;
        mpc_t.bus(:, 3) = P_base .* bus_variation * load_factor;
        mpc_t.bus(:, 4) = Q_base .* bus_variation * load_factor;
        results_t = runpf(mpc_t, mpopt);
        if results_t.success
            V = results_t.bus(:, 8);
            theta = results_t.bus(:, 9);
            P = results_t.bus(:, 3);
            Q = results_t.bus(:, 4);
            Pf = results_t.branch(:, 14);
            Qf = results_t.branch(:, 15);

            % Add per-sensor measurement noise (simulates real RTU/PMU inaccuracies)
            V = V + V_noise_std .* randn(nBuses, 1) .* abs(V);
            theta = theta + theta_noise_std .* randn(nBuses, 1);
            P = P + P_noise_std .* randn(nBuses, 1) .* max(abs(P), 0.01);
            Q = Q + Q_noise_std .* randn(nBuses, 1) .* max(abs(Q), 0.01);
            Pf = Pf + Pf_noise_std .* randn(nBranches, 1) .* max(abs(Pf), 0.01);
            Qf = Qf + Qf_noise_std .* randn(nBranches, 1) .* max(abs(Qf), 0.01);

            data(t, :) = [V', theta', P', Q', Pf', Qf'];
        else
            if t > 1
                data(t, :) = data(t-1, :) .* (1 + 0.005 * randn(1, nFeatures));
            else
                data(t, :) = [V_base', theta_base', P_base', Q_base', Pf_base', Qf_base'];
            end
        end
        if mod(t, progressStep) == 0
            fprintf('  Progress: %d%%\n', round(100 * t / cfg.nSamples));
        end
    end
    labels = zeros(cfg.nSamples, 1);
    meta.nBuses = nBuses;
    meta.nBranches = nBranches;
    meta.nFeatures = nFeatures;
    meta.busCase = cfg.busCase;
    meta.timestamp = datetime('now');
    meta.config = cfg;
    meta.featureNames = {};
    for i = 1:nBuses
        meta.featureNames{end+1} = sprintf('V_%d', i);
    end
    for i = 1:nBuses
        meta.featureNames{end+1} = sprintf('theta_%d', i);
    end
    for i = 1:nBuses
        meta.featureNames{end+1} = sprintf('P_%d', i);
    end
    for i = 1:nBuses
        meta.featureNames{end+1} = sprintf('Q_%d', i);
    end
    for i = 1:nBranches
        meta.featureNames{end+1} = sprintf('Pf_%d', i);
    end
    for i = 1:nBranches
        meta.featureNames{end+1} = sprintf('Qf_%d', i);
    end
    fprintf('=== Data Generation Complete ===\n');
    fprintf('Shape: [%d samples x %d features]\n', cfg.nSamples, nFeatures);
end
