function simple_idle_test()
% Simple test of idle time calculation using existing data

fprintf('=== Simple Idle Time Test ===\n');

% Load existing data
try
    dataFile = load('data/historicalEPData.mat');
    historicalData = dataFile.historicalData;
    fprintf('Loaded %d cases from existing data\n', length(historicalData.caseID));
    
    scheduleFile = load('data/historicalEPSchedules.mat');
    historicalSchedules = scheduleFile.historicalSchedules;
    fprintf('Loaded schedules for %d dates\n', length(keys(historicalSchedules)));
catch ME
    fprintf('Error loading data: %s\n', ME.message);
    return;
end

% Run analysis
try
    analysisResults = analyzeHistoricalData(historicalData, ...
        'HistoricalSchedules', historicalSchedules, 'ShowStats', false);
    fprintf('Analysis completed successfully\n');
catch ME
    fprintf('Error in analysis: %s\n', ME.message);
    return;
end

% Check results
if isempty(analysisResults.operatorAnalysis)
    fprintf('No operator analysis results found\n');
    return;
end

fprintf('Found operator analysis results!\n');

% Get the idle time statistics
idleTimeStats = analysisResults.operatorAnalysis.idleTimeStats;
caseStats = analysisResults.operatorAnalysis.caseStats;
multiProcAverages = analysisResults.operatorAnalysis.multiProcedureDayAverages;
analyzedDates = analysisResults.operatorAnalysis.analyzedDates;

operatorNames = keys(idleTimeStats);
fprintf('Found %d operators with idle time data\n', length(operatorNames));

% Show sample of detailed breakdown for first few operators
for i = 1:min(3, length(operatorNames))
    opName = operatorNames{i};
    idleArray = idleTimeStats(opName);
    caseArray = caseStats(opName);
    
    fprintf('\n--- Operator: %s ---\n', opName);
    
    % Count valid days and calculate stats
    validDayMask = ~isnan(idleArray) & ~isnan(caseArray);
    validDays = sum(validDayMask);
    
    if validDays > 0
        validIdleTimes = idleArray(validDayMask);
        validCases = caseArray(validDayMask);
        
        totalIdleTime = sum(validIdleTimes);
        avgIdleTime = totalIdleTime / validDays;
        
        % Multi-procedure days
        multiProcMask = validDayMask & (caseArray > 1);
        multiProcDays = sum(multiProcMask);
        
        if multiProcDays > 0
            multiProcIdleTimes = idleArray(multiProcMask);
            multiProcCases = caseArray(multiProcMask);
            avgMultiProcIdleTime = mean(multiProcIdleTimes);
            avgMultiProcCases = mean(multiProcCases);
            avgTurnovers = avgMultiProcCases - 1;
            idlePerTurnover = avgMultiProcIdleTime / avgTurnovers;
            
            fprintf('  Valid days: %d, Multi-proc days: %d\n', validDays, multiProcDays);
            fprintf('  Avg idle time (all days): %.1f min\n', avgIdleTime);
            fprintf('  Avg idle time (multi-proc): %.1f min\n', avgMultiProcIdleTime);
            fprintf('  Avg cases (multi-proc): %.1f\n', avgMultiProcCases);
            fprintf('  Avg turnovers: %.1f\n', avgTurnovers);
            fprintf('  Idle time per turnover: %.1f min\n', idlePerTurnover);
            
            % Check stored value
            if isKey(multiProcAverages, opName)
                storedAvg = multiProcAverages(opName);
                if ~isnan(storedAvg.avgIdleTime)
                    fprintf('  Stored multi-proc avg: %.1f min\n', storedAvg.avgIdleTime);
                end
            end
            
            % Show a few example days
            fprintf('  Sample days:\n');
            dayIndices = find(multiProcMask);
            for j = 1:min(3, length(dayIndices))
                dayIdx = dayIndices(j);
                fprintf('    %s: %d cases, %.1f min idle\n', ...
                    analyzedDates{dayIdx}, caseArray(dayIdx), idleArray(dayIdx));
            end
        else
            fprintf('  No multi-procedure days\n');
        end
    else
        fprintf('  No valid days found\n');
    end
end

% Test individual schedule analysis for one date
fprintf('\n=== Testing Individual Day ===\n');
scheduleKeys = keys(historicalSchedules);
if ~isempty(scheduleKeys)
    testDate = scheduleKeys{1};
    fprintf('Testing: %s\n', testDate);
    
    daySchedule = historicalSchedules(testDate);
    if isfield(daySchedule, 'schedule') && isfield(daySchedule.schedule, 'operators')
        fprintf('Operators: %s\n', strjoin(keys(daySchedule.schedule.operators), ', '));
        
        % Test idle time calculation directly
        [idleStats, flipStats, totalFlips] = analyzeOperatorIdleTimeAndFlips(...
            daySchedule.schedule.operators, daySchedule.schedule.labs);
        
        fprintf('Direct calculation results:\n');
        opNames = keys(idleStats);
        for j = 1:length(opNames)
            opName = opNames{j};
            fprintf('  %s: %.1f min idle, %d flips\n', ...
                opName, idleStats(opName), flipStats(opName));
        end
    end
end

end