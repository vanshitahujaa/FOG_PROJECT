function [coeff, score, latent, tsquared, explained, mu] = manualPCA(X)
    [n, p] = size(X);
    mu = mean(X, 1);
    X0 = X - mu;
    [U, S, V] = svd(X0, 'econ');
    coeff = V;
    score = X0 * V;
    latent = (diag(S).^2) / max(n-1, 1);
    sum_latent = sum(latent);
    if sum_latent == 0, sum_latent = 1; end
    explained = 100 * latent / sum_latent;
    if nargout > 3
        tsquared = sum((score ./ sqrt(latent' + 1e-10)).^2, 2);
    else
        tsquared = [];
    end
end
