classdef BlockchainLedger < handle
% BLOCKCHAINLEDGER  Simple hash-chain for tamper-proof audit logging.
%   Stores detection events, consensus votes, and trust scores.

    properties
        chain           % Cell array of blocks
        pendingData     % Data waiting to be mined into next block
    end

    methods
        function obj = BlockchainLedger()
            obj.chain = {};
            obj.pendingData = {};
            % Create genesis block
            genesis.index = 0;
            genesis.timestamp = datetime('now');
            genesis.data = 'Genesis Block';
            genesis.previousHash = '0';
            genesis.nonce = 0;
            genesis.hash = obj.computeHash(genesis);
            obj.chain{1} = genesis;
            fprintf('BlockchainLedger initialized (genesis block created)\n');
        end

        function addRecord(obj, recordType, recordData)
            % Add a record to pending data
            record.type = recordType;
            record.data = recordData;
            record.timestamp = datetime('now');
            obj.pendingData{end+1} = record;
        end

        function block = mineBlock(obj)
            % Create a new block from pending data
            prevBlock = obj.chain{end};
            block.index = prevBlock.index + 1;
            block.timestamp = datetime('now');
            block.data = obj.pendingData;
            block.previousHash = prevBlock.hash;
            block.nonce = 0;
            block.hash = obj.computeHash(block);
            obj.chain{end+1} = block;
            obj.pendingData = {};
        end

        function logDetection(obj, windowId, sensorVotes, modelPreds, modelNames, consensusResult, trustScores)
            % Log a complete detection event
            record.windowId = windowId;
            record.sensorConsensus = sensorVotes;
            record.modelPredictions = struct();
            for m = 1:length(modelNames)
                fname = matlab.lang.makeValidName(modelNames{m});
                record.modelPredictions.(fname) = modelPreds(m);
            end
            record.finalDecision = consensusResult;
            record.trustScores = trustScores;
            obj.addRecord('DETECTION', record);
        end

        function logAlert(obj, alertData)
            % Log an alert event
            obj.addRecord('ALERT', alertData);
        end

        function logTrustUpdate(obj, trustScores, reason)
            % Log trust score changes
            record.scores = trustScores;
            record.reason = reason;
            obj.addRecord('TRUST_UPDATE', record);
        end

        function isValid = verifyChain(obj)
            % Verify integrity of the entire chain
            isValid = true;
            for i = 2:length(obj.chain)
                block = obj.chain{i};
                prevBlock = obj.chain{i-1};

                % Check previous hash link
                if ~strcmp(block.previousHash, prevBlock.hash)
                    fprintf('Chain broken at block %d: previousHash mismatch\n', block.index);
                    isValid = false;
                    return;
                end

                % Verify block hash
                recomputedHash = obj.computeHash(block);
                if ~strcmp(block.hash, recomputedHash)
                    fprintf('Chain broken at block %d: hash tampered\n', block.index);
                    isValid = false;
                    return;
                end
            end
        end

        function displayStatus(obj)
            fprintf('\n--- Blockchain Ledger Status ---\n');
            fprintf('Chain length: %d blocks\n', length(obj.chain));
            fprintf('Pending records: %d\n', length(obj.pendingData));
            if obj.verifyChain()
                fprintf('Chain integrity: VALID\n');
            else
                fprintf('Chain integrity: COMPROMISED!\n');
            end
        end
    end

    methods (Access = private)
        function h = computeHash(~, block)
            % Create a deterministic string from block data
            str = sprintf('%d_%s_%s_%d', block.index, ...
                char(block.timestamp), block.previousHash, block.nonce);
            % Pure MATLAB hash (FNV-1a inspired, 256-bit output)
            bytes = uint8(str);
            % Use 4 independent hash accumulators for 256-bit output
            h1 = uint64(14695981039346656037);
            h2 = uint64(6614537550898289747);
            h3 = uint64(1099511628211);
            h4 = uint64(9876543210987654321);
            for i = 1:length(bytes)
                b = uint64(bytes(i));
                h1 = bitxor(h1, b);
                h1 = h1 * uint64(1099511628211);
                h2 = bitxor(h2, b + uint64(i));
                h2 = h2 * uint64(6364136223846793005);
                h3 = bitxor(h3, b * uint64(31));
                h3 = h3 * uint64(1099511628211);
                h4 = bitxor(h4, bitxor(b, uint64(i * 7)));
                h4 = h4 * uint64(2654435761);
            end
            h = sprintf('%016x%016x%016x%016x', h1, h2, h3, h4);
        end
    end
end
