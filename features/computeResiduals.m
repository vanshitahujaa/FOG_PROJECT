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
    if nargin < 3 || isempty(W)
        W = eye(size(H, 1));
end

    [m, n] = size(H);

if isrow (z)
  z = z'; end

      if length (z) > m z = z(1 : m);
elseif length(z) < m z = [z; zeros(m - length(z), 1)];
end

    % % Weighted Least Squares State Estimation HtWH = H' * W * H; HtWz = H' * W * z;

    condNumber = cond(HtWH);
if condNumber
  > 1e12 warning('State estimation is ill-conditioned (cond = %.2e)',
                 condNumber);
x_hat = pinv(HtWH) * HtWz;
else x_hat = HtWH \ HtWz;
end

    % % Compute Residuals residuals = z - H * x_hat;

% % Chi - squared Test J = residuals' * W * residuals;

                           % % Detection output detection.residuals = residuals;
detection.residualNorm = norm(residuals);
detection.J = J;
detection.x_hat = x_hat;
detection.condNumber = condNumber;

df = m - n;
if df
  > 0 detection.threshold = chi2inv(0.95, df);
detection.isPassing = (J < detection.threshold);
else detection.threshold = Inf;
detection.isPassing = true;
    end

    R = W - W * H * (HtWH \ (H' * W));
    diagR = diag(R);
    diagR(diagR <= 0) = 1e-10;

    normalizedResiduals = residuals ./ sqrt(diagR);
    [detection.maxNormResidual, detection.suspectMeas] = max(abs(normalizedResiduals));
    detection.normalizedResiduals = normalizedResiduals;
end

%% Traditional Bad Data Detection
function [isAttack, details] = traditionalBDD(z, H, threshold)
    if nargin < 3
        threshold = 3.0;
    end

    [residuals, x_hat, J, detection] = computeResiduals(z, H);

    isAttack = detection.maxNormResidual > threshold;

    details.J = J;
    details.maxNormResidual = detection.maxNormResidual;
    details.suspectMeas = detection.suspectMeas;
    details.threshold = threshold;
    details.chiSquaredPass = detection.isPassing;
end

%% Demonstrate FDIA bypass
function demonstrateFDIABypass(z_normal, z_attack, H)
    fprintf('\n=== FDIA Bypass Demonstration ===\n');

    [r_normal, ~, J_normal, det_normal] = computeResiduals(z_normal, H);
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
