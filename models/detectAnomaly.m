function [prediction, score, details] = detectAnomaly(model, features, modelType)
    if nargin < 3
        if isfield(model, 'svm')
            modelType = 'svm';
        elseif isfield(model, 'rf')
            modelType = 'randomforest';
        elseif isfield(model, 'knn')
            modelType = 'knn';
        elseif isfield(model, 'net') || (isfield(model, 'coeff') && isfield(model, 'meanError'))
            modelType = 'autoencoder';
        elseif isfield(model, 'P') && isfield(model, 'T2_threshold')
            modelType = 'pca';
        else
            error('Unknown model type');
        end
    end
    details = struct();
    switch lower(modelType)
        case 'svm'
            [prediction, score, prob] = predictSVM(model, features);
            details.method = 'SVM';
        case 'autoencoder'
            [prediction, score, prob] = predictAutoencoder(model, features);
            details.method = 'Autoencoder';
        case 'randomforest'
            [prediction, score, prob] = predictRandomForest(model, features);
            details.method = 'Random Forest';
        case 'knn'
            [prediction, score, prob] = predictKNN(model, features);
            details.method = 'KNN';
        case 'pca'
            [prediction, score, prob] = predictPCA(model, features);
            details.method = 'PCA';
        otherwise
            error('Unknown model type: %s', modelType);
    end
    details.type = modelType;
end
