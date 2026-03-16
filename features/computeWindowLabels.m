function windowLabels = computeWindowLabels(labels, windowSize)
    nSamples = length(labels);
    nWindows = floor(nSamples / windowSize);
    windowLabels = zeros(nWindows, 1);
    for w = 1:nWindows
        s1 = (w-1) * windowSize + 1;
        s2 = w * windowSize;
        windowLabels(w) = max(labels(s1:s2));
    end
end
