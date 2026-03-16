%% AUTOENCODER-BASED ANOMALY DETECTION
% Trains autoencoder for unsupervised anomaly detection
%
% Principle: Autoencoder learns to reconstruct normal data
% High reconstruction error = anomaly (attack)
%
% Usage:
%   model = trainAutoencoder(normalFeatures, cfg)

function model = trainAutoencoder(normalFeatures, cfg)
    fprintf('=== Training Autoencoder ===\n');

% Normalize features[X_norm, mu, sigma] = zscore(normalFeatures);
sigma(sigma == 0) = 1;

[ nSamples, inputSize ] = size(X_norm);
fprintf('Input size: %d features, %d samples\n', inputSize, nSamples);

% % Define Autoencoder Architecture % Symmetric encoder -
    decoder structure hiddenSizes = cfg.ae.hiddenSize;

% Ensure symmetric architecture if length (hiddenSizes) <
    3 % Default architecture based on input size bottleneck =
    max(4, floor(inputSize / 4));
hiddenSizes = [ floor(inputSize / 2), bottleneck, floor(inputSize / 2) ];
end

    fprintf('Architecture: %d', inputSize);
    for
      h = hiddenSizes fprintf(' -> %d', h);
    end fprintf(' -> %d\n', inputSize);

    % % Build Network using Deep Learning Toolbox try layers =
        buildAutoencoderLayers(inputSize, hiddenSizes);

    % Training options options = trainingOptions(
        'adam', ... 'MaxEpochs', cfg.ae.maxEpochs, ... 'MiniBatchSize',
        min(128, nSamples), ... 'InitialLearnRate', cfg.ae.learningRate,
        ... 'L2Regularization', cfg.ae.l2Reg, ... 'Shuffle', 'every-epoch',
        ... 'Verbose', false, ... 'Plots', 'none');

    % Train network(autoencoder reconstructs input) net = trainNetwork(X_norm,
                                                                       X_norm,
                                                                       layers,
                                                                       options);

    model.net = net;
    model.useDeepLearning = true;

    catch ME fprintf('Deep Learning Toolbox not available or error: %s\n',
                     ME.message);
    fprintf('Falling back to simple autoencoder...\n');

    % Fallback : Use MATLAB's built-in autoencoder model =
        trainSimpleAutoencoder(X_norm, cfg);
    model.useDeepLearning = false;
    end

        % % Compute Reconstruction Error Threshold X_reconstructed =
        reconstructAutoencoder(model, X_norm);
    errors = computeReconstructionError(X_norm, X_reconstructed);

    model.mu = mu;
    model.sigma = sigma;
    model.trainErrors = errors;
    model.meanError = mean(errors);
    model.stdError = std(errors);
    model.threshold =
        model.meanError + cfg.ae.thresholdMultiplier * model.stdError;
    model.cfg = cfg;

    fprintf('Mean reconstruction error: %.6f\n', model.meanError);
    fprintf('Threshold (mean + %.1f*std): %.6f\n', cfg.ae.thresholdMultiplier,
            model.threshold);
    fprintf('=== Autoencoder Training Complete ===\n');
    end

        % % Build autoencoder layers function layers =
        buildAutoencoderLayers(inputSize, hiddenSizes) layers =
            [featureInputLayer(inputSize, 'Name', 'input')];

    % Encoder layers
    for i = 1:length(hiddenSizes)
        layers = [layers
            fullyConnectedLayer(hiddenSizes(i), 'Name', sprintf('enc%d', i))
            reluLayer('Name', sprintf('relu%d', i))
        ];
    end

        % Output layer(reconstructs input) layers = [layers fullyConnectedLayer(
        inputSize, 'Name', 'output') regressionLayer('Name', 'regression')];
    end

        % %
        Simple autoencoder fallback(using Statistics toolbox) function model =
        trainSimpleAutoencoder(X, cfg)[nSamples, inputSize] = size(X);

    % Use PCA as a simple linear autoencoder bottleneckSize =
        min(cfg.ae.hiddenSize);
    bottleneckSize = min(bottleneckSize, inputSize - 1);

    [ coeff, score, ~, ~, explained, mu_pca ] = pca(X);

    % Keep components up to bottleneck size model.coeff =
        coeff( :, 1 : bottleneckSize);
    model.mu_pca = mu_pca;
    model.type = 'pca';
    model.bottleneckSize = bottleneckSize;
    model.explainedVariance = sum(explained(1 : bottleneckSize));

    fprintf('PCA Autoencoder: Bottleneck=%d, Explained variance=%.2f%%\n',
            ... bottleneckSize, model.explainedVariance);
    end

        % % Reconstruct using autoencoder function X_reconstructed =
        reconstructAutoencoder(
            model, X_norm) if model.useDeepLearning X_reconstructed =
            predict(model.net, X_norm);
    else % PCA reconstruction centered = X_norm - model.mu_pca;
    projected = centered * model.coeff;
    X_reconstructed = projected *model.coeff' + model.mu_pca; end end

                      % % Compute reconstruction error function errors =
                          computeReconstructionError(original, reconstructed) %
                          Mean squared error per sample errors =
                              mean((original - reconstructed).^ 2, 2);
    end

        % %
        Predict using autoencoder function[predictions, errors, probabilities] =
        predictAutoencoder(model, testFeatures) %
        Normalize using training parameters X_norm =
            (testFeatures - model.mu)./ model.sigma;
    X_norm(isnan(X_norm)) = 0;
    X_norm(isinf(X_norm)) = 0;

    % Reconstruct X_reconstructed = reconstructAutoencoder(model, X_norm);

    % Compute errors errors =
        computeReconstructionError(X_norm, X_reconstructed);

    % Predictions based on threshold predictions =
        double(errors > model.threshold);

    % Convert errors to probabilities using sigmoid normalized_errors =
        (errors - model.meanError) / model.stdError;
    probabilities = 1 ./ (1 + exp(-normalized_errors));
    end
