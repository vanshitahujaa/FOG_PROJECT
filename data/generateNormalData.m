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
    for t = 1:cfg.nSamples
        daily_factor = 1 + 0.1 * sin(2 * pi * t / cfg.period);
        random_factor = 1 + cfg.noise * randn();
        if rand() < 0.05
            spike_factor = 1 + 0.1 * rand();
        else
            spike_factor = 1;
        end
        load_factor = daily_factor * random_factor * spike_factor;
        mpc_t = mpc;
        mpc_t.bus(:, 3) = P_base * load_factor;
        mpc_t.bus(:, 4) = Q_base * load_factor;
        results_t = runpf(mpc_t, mpopt);
        if results_t.success
            V = results_t.bus(:, 8);
            theta = results_t.bus(:, 9);
            P = results_t.bus(:, 3);
            Q = results_t.bus(:, 4);
            Pf = results_t.branch(:, 14);
            Qf = results_t.branch(:, 15);
            data(t, :) = [V', theta', P', Q', Pf', Qf'];
        else
            if t > 1
                data(t, :) = data(t-1, :) .* (1 + 0.001 * randn(1, nFeatures));
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
