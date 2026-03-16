classdef CloudLayer < handle
    properties
        alertLog
        stats
        cfg
    end
    methods
        function obj = CloudLayer(cfg)
            obj.cfg = cfg;
            obj.alertLog = {};
            obj.stats.totalAlerts = 0;
            obj.stats.criticalAlerts = 0;
            obj.stats.highAlerts = 0;
            obj.stats.mediumAlerts = 0;
            obj.stats.lowAlerts = 0;
            fprintf('CloudLayer initialized\n');
        end
        function receiveAlerts(obj, alerts, nodeId)
            for i = 1:length(alerts)
                alert = alerts{i};
                alert.nodeId = nodeId;
                alert.receivedAt = datetime('now');
                obj.alertLog{end+1} = alert;
                switch alert.severity
                    case 'CRITICAL'
                        obj.stats.criticalAlerts = obj.stats.criticalAlerts + 1;
                    case 'HIGH'
                        obj.stats.highAlerts = obj.stats.highAlerts + 1;
                    case 'MEDIUM'
                        obj.stats.mediumAlerts = obj.stats.mediumAlerts + 1;
                    case 'LOW'
                        obj.stats.lowAlerts = obj.stats.lowAlerts + 1;
                end
            end
            obj.stats.totalAlerts = length(obj.alertLog);
            fprintf('Cloud received %d alerts from Node %d\n', length(alerts), nodeId);
        end
        function displayStatus(obj)
            fprintf('\n--- Cloud Layer Status ---\n');
            fprintf('Total alerts: %d\n', obj.stats.totalAlerts);
            fprintf('  CRITICAL: %d\n', obj.stats.criticalAlerts);
            fprintf('  HIGH:     %d\n', obj.stats.highAlerts);
            fprintf('  MEDIUM:   %d\n', obj.stats.mediumAlerts);
            fprintf('  LOW:      %d\n', obj.stats.lowAlerts);
        end
    end
end
