function test_corrected_idle()
% Test the corrected idle time calculation

fprintf('=== Testing Corrected Idle Time Calculation ===\n');

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

% Run analysis with corrected calculation
try
    analysisResults = analyzeHistoricalData(historicalData, ...
        'HistoricalSchedules', historicalSchedules, 'ShowStats', false);
    fprintf('Analysis completed successfully\n');
catch ME
    fprintf('Error in analysis: %s\n', ME.message);
    return;
end

% Check results for ARSHAD, AYSHA specifically
targetOperator = 'ARSHAD, AYSHA';

if isempty(analysisResults.operatorAnalysis) || ...
   ~isKey(analysisResults.operatorAnalysis.idleTimeStats, targetOperator)
    fprintf('No results found for %s\n', targetOperator);
    return;
end

% Get the corrected statistics
idleArray = analysisResults.operatorAnalysis.idleTimeStats(targetOperator);
caseArray = analysisResults.operatorAnalysis.caseStats(targetOperator);
multiProcAverages = analysisResults.operatorAnalysis.multiProcedureDayAverages(targetOperator);
dates = analysisResults.operatorAnalysis.analyzedDates;

% Calculate statistics
validMask = ~isnan(idleArray) & ~isnan(caseArray);
validIdleTimes = idleArray(validMask);
validCases = caseArray(validMask);
validDates = dates(validMask);

multiProcMask = validCases > 1;
multiProcIdleTimes = validIdleTimes(multiProcMask);

fprintf('\n=== Corrected Results for %s ===\n', targetOperator);
fprintf('Total valid days: %d\n', length(validIdleTimes));
fprintf('Multi-procedure days: %d\n', sum(multiProcMask));

if ~isempty(validIdleTimes)
    fprintf('Average idle time (all days): %.1f min\n', mean(validIdleTimes));
end

if ~isempty(multiProcIdleTimes)
    fprintf('Average idle time (multi-proc days): %.1f min\n', mean(multiProcIdleTimes));
    
    % Calculate average cases and turnovers for multi-proc days
    multiProcCases = validCases(multiProcMask);
    avgCases = mean(multiProcCases);
    avgTurnovers = avgCases - 1;
    avgIdlePerTurnover = mean(multiProcIdleTimes) / avgTurnovers;
    
    fprintf('Average cases (multi-proc days): %.1f\n', avgCases);
    fprintf('Average turnovers: %.1f\n', avgTurnovers);
    fprintf('Average idle time per turnover: %.1f min\n', avgIdlePerTurnover);
end

fprintf('Stored multi-proc average: %.1f min\n', multiProcAverages.avgIdleTime);

% Check the specific day we analyzed before (03-Jan-2025)
testDateIdx = find(strcmp(validDates, '03-Jan-2025'));
if ~isempty(testDateIdx)
    fprintf('\nSpecific day check (03-Jan-2025):\n');
    fprintf('Cases: %d, Idle time: %.1f min\n', ...
        validCases(testDateIdx), validIdleTimes(testDateIdx));
    
    % This should now match our manual calculation of 365 min
    if abs(validIdleTimes(testDateIdx) - 365) < 1
        fprintf('✓ Matches expected corrected calculation (365 min)\n');
    else
        fprintf('✗ Does not match expected calculation (expected 365 min)\n');
    end
end

% Show first few days for verification
fprintf('\nFirst 5 days:\n');
for i = 1:min(5, length(validDates))
    fprintf('  %s: %d cases, %.1f min idle\n', ...
        validDates{i}, validCases(i), validIdleTimes(i));
end

end