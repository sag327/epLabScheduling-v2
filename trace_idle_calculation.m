function trace_idle_calculation()
% Trace the idle time calculation to find the discrepancy

fprintf('=== Tracing Idle Time Calculation ===\n');

% Load data
try
    dataFile = load('data/historicalEPData.mat');
    historicalData = dataFile.historicalData;
    
    scheduleFile = load('data/historicalEPSchedules.mat');
    historicalSchedules = scheduleFile.historicalSchedules;
    
    fprintf('Loaded data successfully\n');
catch ME
    fprintf('Error loading data: %s\n', ME.message);
    return;
end

% Focus on ARSHAD, AYSHA since we know her specific day values
targetOperator = 'ARSHAD, AYSHA';
fprintf('\nTracing calculation for: %s\n', targetOperator);

% Get all schedule dates
scheduleKeys = keys(historicalSchedules);
scheduleKeys = sort(scheduleKeys); % Sort chronologically

% Track this operator across all dates
operatorDailyData = [];
dateIndex = 1;

for i = 1:length(scheduleKeys)
    dateKey = scheduleKeys{i};
    daySchedule = historicalSchedules(dateKey);
    
    if isfield(daySchedule, 'schedule') && isfield(daySchedule.schedule, 'operators')
        operators = daySchedule.schedule.operators;
        
        if isKey(operators, targetOperator)
            opSchedule = operators(targetOperator);
            
            % Count cases for this day
            if isstruct(opSchedule) && length(opSchedule) > 1
                numCases = length(opSchedule);
                
                % Calculate idle time manually (replicate the function logic)
                totalIdleTime = 0;
                
                % Extract and sort cases by start time
                startTimes = [];
                for j = 1:length(opSchedule)
                    if isfield(opSchedule(j), 'caseInfo') && isfield(opSchedule(j).caseInfo, 'startTime')
                        startTimes(j) = opSchedule(j).caseInfo.startTime;
                    else
                        startTimes(j) = 0;
                    end
                end
                [~, sortIdx] = sort(startTimes);
                sortedSchedule = opSchedule(sortIdx);
                
                % Calculate idle time between consecutive cases
                for j = 1:length(sortedSchedule)-1
                    currentCase = sortedSchedule(j);
                    nextCase = sortedSchedule(j+1);
                    
                    if isfield(currentCase.caseInfo, 'endTime') && isfield(nextCase.caseInfo, 'startTime')
                        idleTime = nextCase.caseInfo.startTime - currentCase.caseInfo.endTime;
                        if idleTime > 0
                            totalIdleTime = totalIdleTime + idleTime;
                        end
                    end
                end
                
                % Store this day's data
                operatorDailyData(dateIndex).date = dateKey;
                operatorDailyData(dateIndex).numCases = numCases;
                operatorDailyData(dateIndex).idleTime = totalIdleTime;
                operatorDailyData(dateIndex).isMultiProc = (numCases > 1);
                
                fprintf('  %s: %d cases, %.1f min idle\n', dateKey, numCases, totalIdleTime);
                dateIndex = dateIndex + 1;
                
            elseif isstruct(opSchedule) && length(opSchedule) == 1
                % Single case - store with 0 idle time
                operatorDailyData(dateIndex).date = dateKey;
                operatorDailyData(dateIndex).numCases = 1;
                operatorDailyData(dateIndex).idleTime = 0;
                operatorDailyData(dateIndex).isMultiProc = false;
                
                fprintf('  %s: 1 case, 0 min idle\n', dateKey);
                dateIndex = dateIndex + 1;
            end
        end
    end
end

if isempty(operatorDailyData)
    fprintf('No data found for %s\n', targetOperator);
    return;
end

% Now calculate the averages manually
allDays = length(operatorDailyData);
multiProcDays = sum([operatorDailyData.isMultiProc]);

% All days average
allIdleTimes = [operatorDailyData.idleTime];
avgIdleAllDays = mean(allIdleTimes);

% Multi-procedure days only
multiProcMask = [operatorDailyData.isMultiProc];
multiProcIdleTimes = allIdleTimes(multiProcMask);
avgIdleMultiProcDays = mean(multiProcIdleTimes);

fprintf('\n=== Manual Calculation Results ===\n');
fprintf('Total days: %d\n', allDays);
fprintf('Multi-procedure days: %d\n', multiProcDays);
fprintf('Average idle time (all days): %.1f min\n', avgIdleAllDays);
fprintf('Average idle time (multi-proc days): %.1f min\n', avgIdleMultiProcDays);

% Show detailed breakdown
fprintf('\n=== Detailed Daily Breakdown ===\n');
for i = 1:length(operatorDailyData)
    day = operatorDailyData(i);
    fprintf('%s: %d cases, %.1f min idle %s\n', ...
        day.date, day.numCases, day.idleTime, ...
        ternary(day.isMultiProc, '(multi-proc)', '(single)'));
end

% Now run the actual analysis function and compare
fprintf('\n=== Comparing with Analysis Function ===\n');
try
    analysisResults = analyzeHistoricalData(historicalData, ...
        'HistoricalSchedules', historicalSchedules, 'ShowStats', false);
    
    if ~isempty(analysisResults.operatorAnalysis) && ...
       isKey(analysisResults.operatorAnalysis.idleTimeStats, targetOperator)
        
        % Get the stored arrays
        idleArray = analysisResults.operatorAnalysis.idleTimeStats(targetOperator);
        caseArray = analysisResults.operatorAnalysis.caseStats(targetOperator);
        dates = analysisResults.operatorAnalysis.analyzedDates;
        
        % Find valid entries for this operator
        validMask = ~isnan(idleArray) & ~isnan(caseArray);
        validIdleTimes = idleArray(validMask);
        validCases = caseArray(validMask);
        validDates = dates(validMask);
        
        fprintf('Analysis function results:\n');
        fprintf('Valid days found: %d\n', length(validIdleTimes));
        
        if ~isempty(validIdleTimes)
            multiProcMask2 = validCases > 1;
            multiProcIdleTimes2 = validIdleTimes(multiProcMask2);
            
            fprintf('Multi-proc days: %d\n', sum(multiProcMask2));
            if ~isempty(multiProcIdleTimes2)
                fprintf('Average idle time (multi-proc): %.1f min\n', mean(multiProcIdleTimes2));
            end
            
            % Show first few entries to compare
            fprintf('\nFirst 10 entries from analysis function:\n');
            for i = 1:min(10, length(validDates))
                fprintf('  %s: %d cases, %.1f min idle\n', ...
                    validDates{i}, validCases(i), validIdleTimes(i));
            end
        end
        
        % Check the multi-procedure averages
        if isfield(analysisResults.operatorAnalysis, 'multiProcedureDayAverages') && ...
           isKey(analysisResults.operatorAnalysis.multiProcedureDayAverages, targetOperator)
            
            storedAvg = analysisResults.operatorAnalysis.multiProcedureDayAverages(targetOperator);
            fprintf('\nStored multi-procedure average: %.1f min\n', storedAvg.avgIdleTime);
        end
    else
        fprintf('No data found in analysis results for %s\n', targetOperator);
    end
    
catch ME
    fprintf('Error running analysis: %s\n', ME.message);
end

end

function result = ternary(condition, trueValue, falseValue)
    if condition
        result = trueValue;
    else
        result = falseValue;
    end
end