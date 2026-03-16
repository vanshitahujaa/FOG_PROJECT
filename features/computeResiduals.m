%% STATE ESTIMATION RESIDUAL COMPUTATION
% Computes residuals from DC state estimation for bad data detection
%
% The residual r = z - H*x_hat indicates measurement consistency
% Large residuals suggest bad/attacked data
%
% Usage:
%   [residuals, x_hat, J] = computeResiduals(z, H)
%   [residuals, x_hat, J, chi2_test] = computeResiduals(z, H, W)

function [residuals, x_hat, J, detection] = computeResiduals(z, H, W)
    % Input handling
    if nargin < 3 || isempty(W)
        % Default: identity weight matrix (equal weights)
        W = eye(size(H, 1));
end

    [m, n] = size(H);
% m = measurements, n = states

                            % Ensure z is column vector and
                        correct size if isrow (z)
                            z = z'; end

                                if length (z) > m z = z(1 : m);
elseif length(z) < m z = [z; zeros(m - length(z), 1)];
    end
    
    %% Weighted Least Squares State Estimation
    % x_hat = (H'WH)^-1 * H'W * z
    
    HtWH = H' * W * H;
    HtWz = H' * W * z;
    
    % Check conditioning
    condNumber = cond(HtWH);
    if condNumber > 1e12
        warning('State estimation is ill-conditioned (cond = %.2e)', condNumber);
        x_hat = pinv(HtWH) * HtWz;  % Use pseudo-inverse
    else
        x_hat = HtWH \ HtWz;
    end
    
    %% Compute Residuals
    residuals = z - H * x_hat;
    
    %% Chi-squared Test (J(x) test)
    J = residuals' * W * residuals;
    
    %% Detection output
    detection.residuals = residuals;
    detection.residualNorm = norm(residuals);
    detection.J = J;
    detection.x_hat = x_hat;
    detection.condNumber = condNumber;
    
    % Chi-squared threshold (degrees of freedom = m - n)
    df = m - n;
    if df > 0
        % 95% confidence threshold
        detection.threshold = chi2inv(0.95, df);
        detection.isPassing = (J < detection.threshold);
    else
        detection.threshold = Inf;
        detection.isPassing = true;
    end
    
    % Largest normalized residual (for identifying bad data)
    R = W - W * H * (HtWH \ (H' * W));  % Residual sensitivity matrix
    diagR = diag(R);
    diagR(diagR <= 0) = 1e-10;  % Avoid division by zero/negative
    
    normalizedResiduals = residuals ./ sqrt(diagR);
    [detection.maxNormResidual, detection.suspectMeas] = max(abs(normalizedResiduals));
    detection.normalizedResiduals = normalizedResiduals;
end

%% Traditional Bad Data Detection
function [isAttack, details] = traditionalBDD(z, H, threshold)
    % Traditional BDD using normalized residuals
    % Returns true if attack detected (but FDIA bypasses this!)
    
    if nargin < 3
        threshold = 3.0;  % 3-sigma threshold
    end
    
    [residuals, x_hat, J, detection] = computeResiduals(z, H);
    
    % Check largest normalized residual
    isAttack = detection.maxNormResidual > threshold;
    
    details.J = J;
    details.maxNormResidual = detection.maxNormResidual;
    details.suspectMeas = detection.suspectMeas;
    details.threshold = threshold;
    details.chiSquaredPass = detection.isPassing;
end

%% Demonstrate FDIA bypass
function demonstrateFDIABypass(z_normal, z_attack, H)
    % Shows how FDIA bypasses traditional BDD
    fprintf('\n=== FDIA Bypass Demonstration ===\n');
    
    % Normal data residual
    [r_normal, ~, J_normal, det_normal] = computeResiduals(z_normal, H);
    
    % Attacked data residual
    [r_attack, ~, J_attack, det_attack] = computeResiduals(z_attack, H);
    
    fprintf('\nNormal Data:\n');
    fprintf('  Residual norm: %.6f\n', norm(r_normal));
    fprintf('  J statistic: %.6f\n', J_normal);
    fprintf('  Max normalized residual: %.6f\n', det_normal.maxNormResidual);
    
    fprintf('\nAttacked Data:\n');
    fprintf('  Residual norm: %.6f\n', norm(r_attack));
    fprintf('  J statistic: %.6f\n', J_attack);
    fprintf('  Max normalized residual: %.6f\n', det_attack.maxNormResidual);
    
    fprintf('\nChange in metrics:\n');
    fprintf('  Residual norm change: %.6f (%.2f%%)\n', ...
        abs(norm(r_attack) - norm(r_normal)), ...
        100 * abs(norm(r_attack) - norm(r_normal)) / (norm(r_normal) + 1e-10));
    fprintf('  J statistic change: %.6f (%.2f%%)\n', ...
        abs(J_attack - J_normal), ...
        100 * abs(J_attack - J_normal) / (J_normal + 1e-10));
    
    if abs(norm(r_attack) - norm(r_normal)) / (norm(r_normal) + 1e-10) < 0.01
        fprintf('\n  >>> FDIA SUCCESSFULLY BYPASSED TRADITIONAL BDD! <<<\n');
    else
        fprintf('\n  Note: This attack may be detectable by traditional BDD.\n');
    end
end
