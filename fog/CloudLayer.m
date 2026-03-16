%% CLOUD LAYER SIMULATION
% Simulates cloud layer for logging, visualization, and model updates
%
% Responsibilities:
%   - Receive and log alerts from fog nodes
%   - Long-term storage
%   - Visualization and dashboards
%   - Model update management

classdef CloudLayer < handle
    properties
        alertLog        % All received alerts
        aggregatedStats % Statistics from all fog nodes
        eventHistory    % Timeline of events
        config          % Configuration
    end
    
    methods
        %% Constructor
        function obj = CloudLayer(cfg)
            obj.config = cfg;
obj.alertLog = {};
obj.aggregatedStats = struct();
obj.eventHistory = [];

fprintf('Cloud Layer initialized\n');
        end
        
        %% Receive alerts from fog node
        function receiveAlerts(obj, alerts, nodeId)
            for i = 1:length(alerts)
                alert = alerts{i};
        alert.nodeId = nodeId;
        alert.receivedAt = datetime('now');
        obj.alertLog{end + 1} = alert;
        end

            fprintf('Cloud received %d alerts from Node %d\n', length(alerts),
                    nodeId);
        end

            % % Log event function logEvent(obj, event) event.timestamp =
            datetime('now');
        obj.eventHistory = [obj.eventHistory; event];
        end

            % % Generate dashboard data function dashboardData =
            generateDashboard(obj) dashboardData.totalAlerts =
                length(obj.alertLog);

        if isempty (obj.alertLog)
          dashboardData.severityCounts =
              struct('LOW', 0, 'MEDIUM', 0, 'HIGH', 0, 'CRITICAL', 0);
        dashboardData.recentAlerts = {};
        return;
        end

            % Count by severity severities =
            cellfun(@(a) a.severity, obj.alertLog, 'UniformOutput', false);
        dashboardData.severityCounts.LOW = sum(strcmp(severities, 'LOW'));
        dashboardData.severityCounts.MEDIUM = sum(strcmp(severities, 'MEDIUM'));
        dashboardData.severityCounts.HIGH = sum(strcmp(severities, 'HIGH'));
        dashboardData.severityCounts.CRITICAL =
            sum(strcmp(severities, 'CRITICAL'));

        % Recent alerts(last 10) nRecent = min(10, length(obj.alertLog));
        dashboardData.recentAlerts = obj.alertLog(end - nRecent + 1 : end);
        end

            % %
            Display cloud status function displayStatus(obj)
                fprintf('\n=== Cloud Layer Status ===\n');
        fprintf('Total alerts received: %d\n', length(obj.alertLog));

        dashboard = obj.generateDashboard();
        fprintf('Severity breakdown:\n');
        fprintf('  LOW: %d\n', dashboard.severityCounts.LOW);
        fprintf('  MEDIUM: %d\n', dashboard.severityCounts.MEDIUM);
        fprintf('  HIGH: %d\n', dashboard.severityCounts.HIGH);
        fprintf('  CRITICAL: %d\n', dashboard.severityCounts.CRITICAL);
        fprintf('==========================\n');
        end end end
