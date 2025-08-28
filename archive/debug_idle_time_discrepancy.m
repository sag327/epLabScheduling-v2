% Debug idle time discrepancy between single-day vs multi-day data
% Focus on Chirag Sandesara Feb 3 data
% Version: 1.0.0

fprintf('=== Debugging Idle Time Discrepancy ===\n');
fprintf('Comparing single-day vs multi-day idle time calculations for Chirag Sandesara\n\n');

%% Test 1: Current dataset (appears to be Feb 3 only)
fprintf('=== Test 1: Current Dataset ===\n');
load('data/historicalEPData.mat');
fprintf('Dataset size: %d cases\n', length(historicalData.date));

% Check what dates are in the current dataset
uniqueDates = unique(string(historicalData.date));
fprintf('Unique dates in dataset: ');
for i = 1:length(uniqueDates)
    fprintf('%s ', uniqueDates{i});
end
fprintf('\n');

% Find Chirag's cases
chiragMask = strcmp(string(historicalData.surgeon), 'SANDESARA, CHIRAG M');
chiragCases = find(chiragMask);
fprintf('Chirag cases found: %d\n', length(chiragCases));

if ~isempty(chiragCases)
    chiragDates = historicalData.date(chiragCases);
    fprintf('Chirag''s case dates: ');
    if iscell(chiragDates)
        for i = 1:length(chiragDates)
            fprintf('%s ', chiragDates{i});
        end
    else
        for i = 1:length(chiragDates)
            fprintf('%s ', string(chiragDates(i)));
        end
    end
    fprintf('\n');
    
    % Analyze Chirag's data
    analysisResults = analyzeHistoricalData(historicalData, 'ShowStats', false);
    
    if isfield(analysisResults, 'comprehensiveOperatorMetrics') && isfield(analysisResults.comprehensiveOperatorMetrics, 'SANDESARA_CHIRAGM')
        chirag = analysisResults.comprehensiveOperatorMetrics.SANDESARA_CHIRAGM;
        
        fprintf('\nChirag Analysis Results:\n');
        fprintf('  Total cases: %d\n', chirag.totalCases);
        fprintf('  Multi-procedure days: %d\n', chirag.multiProcedureDays);
        fprintf('  Avg idle time per day: %.2f min\n', chirag.avgIdleTimePerDay);
        fprintf('  Median idle time per day: %.2f min\n', chirag.medianIdleTimePerDay);
        fprintf('  Median idle time per turnover: %.2f min\n', chirag.medianIdleTimePerTurnover);
        
        if ~isempty(chirag.multiProcedureDates)
            fprintf('  Multi-procedure dates:\n');
            for i = 1:length(chirag.multiProcedureDates)
                fprintf('    %s: %d cases\n', chirag.multiProcedureDates{i}, chirag.multiProcedureDateCounts(i));
            end
        end
    else
        fprintf('Chirag not found in comprehensive metrics\n');
    end
else
    fprintf('No cases found for Chirag Sandesara\n');
end

%% Instructions for user
fprintf('\n=== Next Steps ===\n');
fprintf('To complete this diagnosis:\n');
fprintf('1. Load the full dataset (procedureDurationsB.xlsx)\n');
fprintf('2. Run this script again to compare results\n');
fprintf('3. Look for differences in:\n');
fprintf('   - How Feb 3 data appears in both datasets\n');
fprintf('   - Whether idle time calculations differ\n');
fprintf('   - Array indexing or date matching issues\n');

fprintf('\n=== Key Questions to Investigate ===\n');
fprintf('1. Does Feb 3 appear in the same position in both datasets?\n');
fprintf('2. Are the procedure times and sequences identical?\n');
fprintf('3. Is the idle time being calculated the same way?\n');
fprintf('4. Are there any NaN values contaminating the calculation?\n');

fprintf('\nDiagnostic complete!\n');