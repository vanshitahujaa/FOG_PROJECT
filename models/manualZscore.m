function [X_norm, mu, sigma] = manualZscore(X)
    mu = mean(X, 1);
    sigma = std(X, 0, 1);
    sigma(sigma == 0) = 1;
    X_norm = (X - mu) ./ sigma;
end
