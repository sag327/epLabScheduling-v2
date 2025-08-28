% Debug why dailyIdleTimePerTurnover is empty despite having idle times
% Version: 1.0.0

fprintf('=== Debugging Turnover Calculation ===\n');

% This diagnostic assumes you have historicalSchedules in your workspace
% and are calling analyzeHistoricalData with it

if ~exist('historicalSchedules', 'var')
    fprintf('ERROR: historicalSchedules variable not found in workspace\n');
    fprintf('Make sure to load/create historicalSchedules before running this diagnostic\n');
    return;
end

% Load historical data
load('data/historicalEPData.mat');

% Run analysis with schedules
fprintf('Running analyzeHistoricalData with historicalSchedules...\n');
analysisResults = analyzeHistoricalData(historicalData, 'HistoricalSchedules', historicalSchedules, 'ShowStats', false);

% Check comprehensive metrics
if ~isfield(analysisResults, 'comprehensiveOperatorMetrics')
    fprintf('ERROR: No comprehensive metrics generated\n');
    return;
end

compMetrics = analysisResults.comprehensiveOperatorMetrics;
opNames = fieldnames(compMetrics);

fprintf('\n=== Checking Operators with Multi-Procedure Days ===\n');

problemOperators = {};
for i = 1:length(opNames)
    opFieldName = opNames{i};
    opData = compMetrics.(opFieldName);
    
    if opData.multiProcedureDays > 0
        fprintf('\n--- %s ---\n', opData.name);
        fprintf('Multi-procedure days: %d\n', opData.multiProcedureDays);
        
        % Check dailyIdleTimes
        if isfield(opData, 'dailyIdleTimes')
            fprintf('dailyIdleTimes: [%s] (length: %d)\n', ...
                mat2str(opData.dailyIdleTimes), length(opData.dailyIdleTimes));
            validIdleCount = sum(~isnan(opData.dailyIdleTimes));
            fprintf('Valid idle times: %d\n', validIdleCount);
        else
            fprintf('❌ dailyIdleTimes field missing\n');
        end
        
        % Check dailyCaseCounts
        if isfield(opData, 'dailyCaseCounts')
            fprintf('dailyCaseCounts: [%s] (length: %d)\n', ...
                mat2str(opData.dailyCaseCounts), length(opData.dailyCaseCounts));
            multiProcDayCount = sum(opData.dailyCaseCounts > 1);
            fprintf('Multi-procedure days in counts: %d\n', multiProcDayCount);
        else
            fprintf('❌ dailyCaseCounts field missing\n');
        end
        
        % Check the condition that might be failing
        if isfield(opData, 'dailyIdleTimes') && isfield(opData, 'dailyCaseCounts')
            condition1 = ~isempty(opData.dailyIdleTimes);
            condition2 = length(opData.dailyIdleTimes) == length(opData.dailyCaseCounts);
            
            fprintf('Condition checks:\n');
            fprintf('  ~isempty(dailyIdleTimes): %s\n', mat2str(condition1));
            fprintf('  length match: %s (%d vs %d)\n', mat2str(condition2), ...
                length(opData.dailyIdleTimes), length(opData.dailyCaseCounts));
            
            if condition1 && condition2
                fprintf('✅ Conditions met - calculation should run\n');
                
                % Manual calculation to see what should happen
                fprintf('Manual calculation:\n');
                manualCalculation = [];
                for d = 1:length(opData.dailyCaseCounts)
                    cases = opData.dailyCaseCounts(d);
                    idleTime = opData.dailyIdleTimes(d);
                    
                    if cases > 1 && ~isnan(idleTime)
                        turnovers = cases - 1;
                        idlePerTurnover = idleTime / turnovers;
                        manualCalculation(end+1) = idlePerTurnover;
                        fprintf('  Day %d: %d cases, %.2f idle, %.2f idle/turnover\n', ...
                            d, cases, idleTime, idlePerTurnover);
                    end
                end
                
                fprintf('Expected dailyIdleTimePerTurnover: [%s]\n', mat2str(manualCalculation));
            else
                fprintf('❌ Conditions failed - calculation will be skipped\n');
            end
        end
        
        % Check actual results
        if isfield(opData, 'dailyIdleTimePerTurnover')
            fprintf('Actual dailyIdleTimePerTurnover: [%s]\n', mat2str(opData.dailyIdleTimePerTurnover));
            if isempty(opData.dailyIdleTimePerTurnover)
                problemOperators{end+1} = opData.name;
                fprintf('❌ PROBLEM: Empty despite conditions\n');
            end
        else
            fprintf('❌ dailyIdleTimePerTurnover field missing\n');
        end
        
        % Check medianIdleTimePerTurnover
        if isfield(opData, 'medianIdleTimePerTurnover')
            fprintf('medianIdleTimePerTurnover: %.2f\n', opData.medianIdleTimePerTurnover);
        else
            fprintf('❌ medianIdleTimePerTurnover field missing\n');
        end
    end
end

fprintf('\n=== SUMMARY ===\n');
fprintf('Operators with empty dailyIdleTimePerTurnover: %d\n', length(problemOperators));
if ~isempty(problemOperators)
    fprintf('Problem operators: %s\n', strjoin(problemOperators, ', '));
end

fprintf('\nDiagnostic complete!\n');