function plotConsensusBlockchain(trustMgr, consensusDetails, trustTags, consensusScores, ledger, cfg)
% PLOTCONSENSUSBLOCKCHAIN  Visualize physics consensus and blockchain metrics.
%   Creates a multi-panel figure showing:
%   - Per-bus trust scores
%   - Sensor flagging rates
%   - Consensus anomaly heatmap
%   - Blockchain stats

    fig = figure('Name', 'Consensus & Blockchain', 'Visible', 'off', 'Position', [50 50 1600 900]);

    nBuses = trustMgr.nBuses;
    busLabels = arrayfun(@(x) sprintf('Bus %d', x), 1:nBuses, 'UniformOutput', false);

    % =====================================================================
    % Panel 1: Per-Bus Trust Scores (Bar chart with color coding)
    % =====================================================================
    subplot(2, 3, 1);
    scores = trustMgr.trustScores;
    barColors = zeros(nBuses, 3);
    for i = 1:nBuses
        if scores(i) >= 0.8
            barColors(i, :) = [0.2 0.7 0.3];   % Green = HIGH trust
        elseif scores(i) >= 0.5
            barColors(i, :) = [0.9 0.7 0.1];   % Yellow = MEDIUM
        else
            barColors(i, :) = [0.9 0.2 0.2];   % Red = LOW
        end
    end
    b = bar(scores);
    b.FaceColor = 'flat';
    b.CData = barColors;
    set(gca, 'XTick', 1:nBuses, 'XTickLabel', busLabels, 'XTickLabelRotation', 45);
    ylabel('Trust Score');
    title('Layer 1: Per-Bus Trust Scores');
    ylim([0 1.1]);
    % Add value labels
    for i = 1:nBuses
        text(i, scores(i) + 0.02, sprintf('%.3f', scores(i)), ...
            'HorizontalAlignment', 'center', 'FontSize', 7);
    end
    grid on;

    % =====================================================================
    % Panel 2: Per-Bus Flagging Rate (% of samples flagged suspicious)
    % =====================================================================
    subplot(2, 3, 2);
    flagRates = sum(trustTags, 1) / size(trustTags, 1) * 100;  % [1 x nBuses]
    bar(flagRates, 'FaceColor', [0.85 0.33 0.1]);
    set(gca, 'XTick', 1:nBuses, 'XTickLabel', busLabels, 'XTickLabelRotation', 45);
    ylabel('Flagging Rate (%)');
    title('Layer 1: Sensor Suspicious Rate');
    % Add value labels
    for i = 1:nBuses
        text(i, flagRates(i) + 0.3, sprintf('%.1f%%', flagRates(i)), ...
            'HorizontalAlignment', 'center', 'FontSize', 7);
    end
    grid on;

    % =====================================================================
    % Panel 3: Consensus Anomaly Score Heatmap (sample windows of data)
    % =====================================================================
    subplot(2, 3, 3);
    % Show a subset of samples for readability
    nShow = min(200, size(consensusScores, 1));
    heatData = consensusScores(1:nShow, :);
    imagesc(heatData');
    colormap(gca, 'hot');
    colorbar;
    xlabel('Sample Index');
    ylabel('Bus');
    set(gca, 'YTick', 1:nBuses, 'YTickLabel', busLabels);
    title('Layer 1: Anomaly Score Heatmap');

    % =====================================================================
    % Panel 4: Physics Correction Summary (Pie chart)
    % =====================================================================
    subplot(2, 3, 4);
    totalReadings = numel(trustTags);
    nCorrected = consensusDetails.nCorrected;
    nTrusted = totalReadings - sum(trustTags(:));
    nFlagged = sum(trustTags(:));
    pie([nTrusted, nFlagged], {
        sprintf('Trusted (%d)', nTrusted), ...
        sprintf('Corrected (%d)', nFlagged)
    });
    title(sprintf('Layer 1: Physics Data Correction\n%d values corrected via Kirchhoff', nCorrected));
    legend('Location', 'southoutside', 'Orientation', 'horizontal');

    % =====================================================================
    % Panel 5: Blockchain Chain Statistics
    % =====================================================================
    subplot(2, 3, 5);
    chainLen = length(ledger.chain);
    isValid = ledger.verifyChain();

    % Count record types
    nDetection = 0;
    nTrustUpdate = 0;
    nAlert = 0;
    for i = 2:chainLen
        block = ledger.chain{i};
        if iscell(block.data)
            for j = 1:length(block.data)
                rec = block.data{j};
                if isfield(rec, 'type')
                    switch rec.type
                        case 'DETECTION'
                            nDetection = nDetection + 1;
                        case 'TRUST_UPDATE'
                            nTrustUpdate = nTrustUpdate + 1;
                        case 'ALERT'
                            nAlert = nAlert + 1;
                    end
                end
            end
        end
    end

    categories = {'Detection', 'Trust Update', 'Alert'};
    counts = [nDetection, nTrustUpdate, nAlert];
    b = bar(counts, 'FaceColor', 'flat');
    b.CData = [0.2 0.5 0.8; 0.3 0.7 0.4; 0.9 0.4 0.2];
    set(gca, 'XTickLabel', categories);
    ylabel('Record Count');
    title(sprintf('Layer 4: Blockchain Records\n%d blocks | Integrity: %s', ...
        chainLen, mat2str(isValid)));
    % Add value labels
    for i = 1:length(counts)
        text(i, counts(i) + max(counts)*0.02, num2str(counts(i)), ...
            'HorizontalAlignment', 'center', 'FontWeight', 'bold');
    end
    grid on;

    % =====================================================================
    % Panel 6: Blockchain Summary Table (text-based)
    % =====================================================================
    subplot(2, 3, 6);
    axis off;
    summaryText = {
        sprintf('\\bf{Blockchain Audit Ledger}');
        '';
        sprintf('Chain Length:    %d blocks', chainLen);
        sprintf('Hash Algorithm: FNV-1a 256-bit');
        sprintf('Chain Integrity: %s', ternary(isValid, 'VALID', 'COMPROMISED'));
        '';
        sprintf('Records Logged:');
        sprintf('  Detection Events: %d', nDetection);
        sprintf('  Trust Updates:    %d', nTrustUpdate);
        sprintf('  Alerts:           %d', nAlert);
        '';
        sprintf('Genesis Hash:');
        sprintf('  %s...', ledger.chain{1}.hash(1:32));
        '';
        sprintf('Latest Hash:');
        sprintf('  %s...', ledger.chain{end}.hash(1:32));
    };
    text(0.05, 0.95, summaryText, 'VerticalAlignment', 'top', ...
        'FontSize', 9, 'FontName', 'FixedWidth', 'Interpreter', 'tex');

    sgtitle('Physics Consensus & Blockchain Metrics', 'FontWeight', 'bold', 'FontSize', 14);

    if cfg.eval.savePlots
        saveas(gcf, fullfile(cfg.eval.outputDir, 'consensus_blockchain_metrics.png'));
        fprintf('Saved consensus_blockchain_metrics.png\n');
    end
    close(fig);
end

function result = ternary(condition, trueVal, falseVal)
    if condition
        result = trueVal;
    else
        result = falseVal;
    end
end
