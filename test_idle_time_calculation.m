function test_idle_time_calculation()
% Test script to debug operator idle time calculation
% This will load data and show detailed idle time calculations

fprintf('=== Testing Idle Time Calculation ===\n');

% Load historical data
try
    historicalData = loadHistoricalDataFromFile();
    fprintf('Loaded historical data with %d cases\n', length(historicalData.caseID));
catch ME
    fprintf('Error loading historical data: %s\n', ME.message);
    return;
end

% Load historical schedules
try
    scheduleData = load('data/historicalEPSchedules.mat');
    historicalSchedules = scheduleData.historicalSchedules;
    fprintf('Loaded historical schedules for %d dates\n', length(keys(historicalSchedules)));
catch ME
    fprintf('Error loading schedules: %s\n', ME.message);
    return;
end

% Run analysis with schedules
try
    analysisResults = analyzeHistoricalData(historicalData, ...
        'HistoricalSchedules', historicalSchedules, 'ShowStats', false);
    fprintf('Analysis completed successfully\n');
catch ME
    fprintf('Error in analysis: %s\n', ME.message);
    return;
end

% Check if we have schedule analysis results
if isempty(analysisResults.operatorAnalysis)
    fprintf('No operator analysis results found\n');
    return;
end

% Get the idle time statistics
idleTimeStats = analysisResults.operatorAnalysis.idleTimeStats;
caseStats = analysisResults.operatorAnalysis.caseStats;
multiProcAverages = analysisResults.operatorAnalysis.multiProcedureDayAverages;
analyzedDates = analysisResults.operatorAnalysis.analyzedDates;

if isempty(idleTimeStats)
    fprintf('No idle time statistics found\n');
    return;
end

fprintf('\n=== Detailed Idle Time Analysis ===\n');
fprintf('Analyzed %d dates\n', length(analyzedDates));

operatorNames = keys(idleTimeStats);
fprintf('Found %d operators with idle time data\n', length(operatorNames));

% Show detailed breakdown for each operator
for i = 1:length(operatorNames)
    opName = operatorNames{i};
    idleArray = idleTimeStats(opName);
    caseArray = caseStats(opName);
    
    fprintf('\n--- Operator: %s ---\n', opName);
    
    % Show daily data
    validDays = 0;
    totalIdleTime = 0;
    multiProcDays = 0;
    multiProcIdleTime = 0;
    
    for dayIdx = 1:length(idleArray)
        if ~isnan(idleArray(dayIdx)) && ~isnan(caseArray(dayIdx))
            validDays = validDays + 1;
            totalIdleTime = totalIdleTime + idleArray(dayIdx);
            
            fprintf('  Day %d (%s): %d cases, %.1f min idle\n', ...
                dayIdx, analyzedDates{dayIdx}, caseArray(dayIdx), idleArray(dayIdx));
            
            % Track multi-procedure days
            if caseArray(dayIdx) > 1
                multiProcDays = multiProcDays + 1;
                multiProcIdleTime = multiProcIdleTime + idleArray(dayIdx);
            end
        end
    end
    
    if validDays > 0
        avgIdleTime = totalIdleTime / validDays;
        fprintf('  Summary: %d valid days, %.1f min avg idle time\n', validDays, avgIdleTime);
        
        if multiProcDays > 0
            avgMultiProcIdleTime = multiProcIdleTime / multiProcDays;
            fprintf('  Multi-proc days: %d days, %.1f min avg idle time\n', multiProcDays, avgMultiProcIdleTime);
            
            % Compare with stored average
            if isKey(multiProcAverages, opName)
                storedAvg = multiProcAverages(opName);
                if ~isnan(storedAvg.avgIdleTime)
                    fprintf('  Stored multi-proc avg: %.1f min (match: %s)\n', ...
                        storedAvg.avgIdleTime, ...
                        abs(storedAvg.avgIdleTime - avgMultiProcIdleTime) < 0.1);
                else
                    fprintf('  Stored multi-proc avg: NaN\n');
                end
            end
        else
            fprintf('  No multi-procedure days found\n');
        end
    else
        fprintf('  No valid days found\n');
    end
end

fprintf('\n=== Testing Individual Schedule Analysis ===\n');

% Test a specific date's schedule analysis
if ~isempty(analyzedDates)
    testDate = analyzedDates{1};
    fprintf('Testing schedule analysis for date: %s\n', testDate);
    
    % Load the specific schedule
    try
        scheduleFile = sprintf('data/historicalEPSchedules.mat');
        scheduleData = load(scheduleFile);
        
        if isfield(scheduleData, 'historicalSchedules') && ...
           isKey(scheduleData.historicalSchedules, testDate)
            
            daySchedule = scheduleData.historicalSchedules(testDate);
            
            if isfield(daySchedule, 'schedule') && isfield(daySchedule.schedule, 'operators')
                fprintf('Found operators for %s: %s\n', testDate, strjoin(keys(daySchedule.schedule.operators), ', '));
                
                % Test the idle time calculation function directly
                [idleStats, flipStats, totalFlips] = analyzeOperatorIdleTimeAndFlips(...
                    daySchedule.schedule.operators, daySchedule.schedule.labs);
                
                fprintf('Direct calculation results:\n');
                opNames = keys(idleStats);
                for j = 1:length(opNames)
                    opName = opNames{j};
                    fprintf('  %s: %.1f min idle, %d flips\n', ...
                        opName, idleStats(opName), flipStats(opName));
                end
            else
                fprintf('No operator data found in schedule\n');
            end
        else
            fprintf('No schedule found for date %s\n', testDate);
        end
    catch ME
        fprintf('Error loading schedule: %s\n', ME.message);
    end
end

end