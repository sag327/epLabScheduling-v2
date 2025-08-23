% Debug why plotAnalysisResults finds 0 operators with multi-procedure day data
% Version: 1.0.0

fprintf('=== Debugging Plot Filtering Logic ===\n');

% Load and analyze data (assuming you have the full dataset loaded)
load('data/historicalEPData.mat');
fprintf('Analyzing data to understand plot filtering...\n');

% This should include historicalSchedules if that's what you're passing
analysisResults = analyzeHistoricalData(historicalData, 'ShowStats', false);

% Check if we have the required data structures
if ~isfield(analysisResults, 'operatorAnalysis') || ...
   ~isfield(analysisResults.operatorAnalysis, 'multiProcedureDayAverages')
    fprintf('ERROR: Missing operatorAnalysis.multiProcedureDayAverages\n');
    fprintf('This suggests historicalSchedules was not provided or is empty\n');
    return;
end

averages = analysisResults.operatorAnalysis.multiProcedureDayAverages;
operatorNames = keys(averages);

fprintf('\n=== Operator Multi-Procedure Day Analysis ===\n');
fprintf('Total operators in averages: %d\n', length(operatorNames));

validCount = 0;
for i = 1:length(operatorNames)
    opName = operatorNames{i};
    opData = averages(opName);
    
    % Check each filtering condition
    condition1 = ~isnan(opData.avgFlips);
    condition2 = ~isnan(opData.medianIdleTime);
    condition3 = ~isnan(opData.flipToTurnoverRatio);
    condition4 = opData.multiProcedureDays > 0;
    
    allConditions = condition1 && condition2 && condition3 && condition4;
    
    if condition4  % Has multi-procedure days
        fprintf('\n%s (Multi-proc days: %d):\n', opName, opData.multiProcedureDays);
        fprintf('  avgFlips not NaN: %s (%.2f)\n', mat2str(condition1), opData.avgFlips);
        fprintf('  medianIdleTime not NaN: %s (%.2f)\n', mat2str(condition2), opData.medianIdleTime);
        fprintf('  flipToTurnoverRatio not NaN: %s (%.2f)\n', mat2str(condition3), opData.flipToTurnoverRatio);
        fprintf('  multiProcedureDays > 0: %s\n', mat2str(condition4));
        fprintf('  ALL CONDITIONS MET: %s\n', mat2str(allConditions));
        
        if allConditions
            validCount = validCount + 1;
        else
            fprintf('  ❌ FILTERED OUT due to failed conditions\n');
        end
    end
end

fprintf('\n=== SUMMARY ===\n');
fprintf('Operators with multi-procedure days: %d\n', sum(cell2mat(values(averages, 'multiProcedureDays')) > 0));
fprintf('Operators passing ALL filter conditions: %d\n', validCount);

if validCount == 0
    fprintf('\n=== ROOT CAUSE ANALYSIS ===\n');
    fprintf('Most likely causes:\n');
    fprintf('1. medianIdleTime is NaN due to recent idle time calculation fixes\n');
    fprintf('2. avgFlips or flipToTurnoverRatio calculations are failing\n');
    fprintf('3. Schedule analysis is not providing the required data\n');
    
    fprintf('\n=== RECOMMENDED FIXES ===\n');
    fprintf('1. Check if historicalSchedules parameter is being passed correctly\n');
    fprintf('2. Verify that schedule analysis is calculating idle times properly\n');
    fprintf('3. Consider relaxing filter conditions in plotAnalysisResults.m\n');
end

fprintf('\nDiagnostic complete!\n');