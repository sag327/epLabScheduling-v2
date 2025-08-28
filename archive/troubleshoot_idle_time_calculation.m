% Troubleshoot idle time per turnover calculation for operators
% Version: 2.1.0

fprintf('=== Troubleshooting Idle Time Per Turnover Calculation ===\n');

% Load and analyze data
load('data/historicalEPData.mat');
fprintf('Analyzing historical data to troubleshoot idle time calculations...\n');
analysisResults = analyzeHistoricalData(historicalData);

% Find operators with many cases but 0 or unexpected idle time values
if isfield(analysisResults, 'comprehensiveOperatorMetrics')
    compMetrics = analysisResults.comprehensiveOperatorMetrics;
    opNames = fieldnames(compMetrics);
    
    fprintf('\n=== Operator Idle Time Summary ===\n');
    problemOperators = {};
    
    for i = 1:length(opNames)
        opFieldName = opNames{i};
        opData = compMetrics.(opFieldName);
        
        % Look for operators with many cases
        if opData.totalCases >= 50  % Significant case volume
            idlePerTurnover = opData.medianIdleTimePerTurnover;
            
            fprintf('\n%s (%d cases, %d working days, %d multi-proc days):\n', ...
                opData.name, opData.totalCases, opData.workingDays, opData.multiProcedureDays);
            fprintf('  avgIdleTimePerDay: %.1f min\n', opData.avgIdleTimePerDay);
            fprintf('  medianIdleTimePerDay: %.1f min\n', opData.medianIdleTimePerDay);
            fprintf('  medianIdleTimePerTurnover: %.1f min\n', idlePerTurnover);
            
            % Flag potential problems
            if idlePerTurnover == 0 || (opData.multiProcedureDays > 0 && isnan(idlePerTurnover))
                problemOperators{end+1} = opFieldName;
                fprintf('  ⚠ PROBLEM: Zero or NaN idle time per turnover despite multi-procedure days!\n');
            end
            
            % Check data availability
            if ~isempty(opData.dailyIdleTimes)
                fprintf('  dailyIdleTimes available: %d days\n', length(opData.dailyIdleTimes));
            else
                fprintf('  ⚠ No dailyIdleTimes data\n');
            end
            
            if ~isempty(opData.dailyCaseCounts)
                fprintf('  dailyCaseCounts available: %d days\n', length(opData.dailyCaseCounts));
                multiProcDays = sum(opData.dailyCaseCounts > 1);
                fprintf('  Calculated multi-procedure days: %d\n', multiProcDays);
            else
                fprintf('  ⚠ No dailyCaseCounts data\n');
            end
            
            if ~isempty(opData.dailyIdleTimePerTurnover)
                fprintf('  dailyIdleTimePerTurnover available: %d values\n', length(opData.dailyIdleTimePerTurnover));
            else
                fprintf('  ⚠ No dailyIdleTimePerTurnover calculated\n');
            end
        end
    end
    
    % Deep dive into the first problem operator
    if ~isempty(problemOperators)
        fprintf('\n=== DEEP DIVE: First Problem Operator ===\n');
        problemOpField = problemOperators{1};
        problemOpData = compMetrics.(problemOpField);
        
        fprintf('Operator: %s\n', problemOpData.name);
        fprintf('Total cases: %d\n', problemOpData.totalCases);
        fprintf('Multi-procedure days: %d\n', problemOpData.multiProcedureDays);
        
        % Check the raw historical data for this operator
        opMask = strcmp(string(historicalData.surgeon), problemOpData.name);
        opCases = find(opMask);
        
        fprintf('\nRaw historical data check:\n');
        fprintf('  Cases found in historical data: %d\n', length(opCases));
        
        if length(opCases) > 0
            % Look at dates and case counts per day
            opDates = historicalData.date(opCases);
            uniqueDates = unique(opDates);
            
            fprintf('  Unique dates: %d\n', length(uniqueDates));
            fprintf('  Sample of daily case counts:\n');
            
            multiProcDayCount = 0;
            for d = 1:min(10, length(uniqueDates))  % Show first 10 days
                dateStr = uniqueDates{d};
                casesThisDay = sum(strcmp(opDates, dateStr));
                if casesThisDay > 1
                    multiProcDayCount = multiProcDayCount + 1;
                end
                if casesThisDay > 1
                    fprintf('    %s: %d cases (MULTI-PROC)\n', dateStr, casesThisDay);
                else
                    fprintf('    %s: %d cases\n', dateStr, casesThisDay);
                end
            end
            
            fprintf('  Multi-procedure days in sample: %d\n', multiProcDayCount);
            
            % Check if idle time data exists in the analysis
            if isfield(analysisResults, 'operatorAnalysis') && ...
               isfield(analysisResults.operatorAnalysis, 'operatorIdleStats')
                
                if isKey(analysisResults.operatorAnalysis.operatorIdleStats, problemOpData.name)
                    idleArray = analysisResults.operatorAnalysis.operatorIdleStats(problemOpData.name);
                    validIdleValues = idleArray(~isnan(idleArray));
                    
                    fprintf('\nIdle time analysis:\n');
                    fprintf('  Idle time array length: %d\n', length(idleArray));
                    fprintf('  Valid (non-NaN) idle values: %d\n', length(validIdleValues));
                    
                    if ~isempty(validIdleValues)
                        fprintf('  Idle time range: %.1f - %.1f min\n', min(validIdleValues), max(validIdleValues));
                        fprintf('  Average idle time: %.1f min\n', mean(validIdleValues));
                        
                        % Check for zeros
                        zeroIdleCount = sum(validIdleValues == 0);
                        fprintf('  Days with zero idle time: %d\n', zeroIdleCount);
                    else
                        fprintf('  ⚠ All idle time values are NaN or empty!\n');
                    end
                else
                    fprintf('  ⚠ No idle time data found for this operator in operatorIdleStats\n');
                end
            else
                fprintf('  ⚠ operatorIdleStats not available in analysis results\n');
            end
            
            % Check comprehensive metrics calculation details
            fprintf('\nComprehensive metrics details:\n');
            fprintf('  dailyIdleTimes: %s\n', mat2str(problemOpData.dailyIdleTimes));
            fprintf('  dailyCaseCounts: %s\n', mat2str(problemOpData.dailyCaseCounts));
            
            if ~isempty(problemOpData.dailyIdleTimes) && ~isempty(problemOpData.dailyCaseCounts)
                fprintf('\nStep-by-step idle per turnover calculation:\n');
                for d = 1:min(5, length(problemOpData.dailyCaseCounts))
                    cases = problemOpData.dailyCaseCounts(d);
                    idle = problemOpData.dailyIdleTimes(d);
                    
                    if cases > 1
                        turnovers = cases - 1;
                        idlePerTurnover = idle / turnovers;
                        fprintf('  Day %d: %d cases, %.1f idle, %.1f idle/turnover\n', ...
                            d, cases, idle, idlePerTurnover);
                    else
                        fprintf('  Day %d: %d cases (single case, no turnover)\n', d, cases);
                    end
                end
            end
        end
    else
        fprintf('\nNo problem operators found with the current criteria.\n');
        fprintf('All operators with >50 cases have reasonable idle time values.\n');
    end
    
else
    fprintf('✗ No comprehensive metrics available\n');
end

fprintf('\n=== Troubleshooting Complete ===\n');