% Test script to display multi-procedure dates for operators
% Version: 1.0.0

fprintf('=== Multi-Procedure Date Analysis ===\n');

% Load and analyze data
load('data/historicalEPData.mat');
fprintf('Analyzing multi-procedure dates...\n');
analysisResults = analyzeHistoricalData(historicalData, 'ShowStats', false);

% Get comprehensive metrics
compMetrics = analysisResults.comprehensiveOperatorMetrics;
opNames = fieldnames(compMetrics);

fprintf('\n=== Multi-Procedure Dates by Operator ===\n');

% Show top 5 operators by case volume
for i = 1:min(5, length(opNames))
    opFieldName = opNames{i};
    opData = compMetrics.(opFieldName);
    
    fprintf('\n%s (%d total cases):\n', opData.name, opData.totalCases);
    fprintf('  Working days: %d\n', opData.workingDays);
    fprintf('  Multi-procedure days: %d (%.1f%%)\n', ...
        opData.multiProcedureDays, opData.multiProcedureDaysPct);
    
    if opData.multiProcedureDays > 0
        fprintf('  Multi-procedure dates:\n');
        for d = 1:min(10, length(opData.multiProcedureDates))  % Show max 10 dates
            dateStr = opData.multiProcedureDates{d};
            caseCount = opData.multiProcedureDateCounts(d);
            fprintf('    %s: %d cases\n', dateStr, caseCount);
        end
        
        if length(opData.multiProcedureDates) > 10
            fprintf('    ... and %d more dates\n', length(opData.multiProcedureDates) - 10);
        end
    else
        fprintf('  No multi-procedure days found\n');
    end
end

fprintf('\n=== Summary ===\n');
totalOperators = length(opNames);
operatorsWithMultiProcDays = 0;

for i = 1:length(opNames)
    opData = compMetrics.(opNames{i});
    if opData.multiProcedureDays > 0
        operatorsWithMultiProcDays = operatorsWithMultiProcDays + 1;
    end
end

fprintf('Total operators: %d\n', totalOperators);
fprintf('Operators with multi-procedure days: %d (%.1f%%)\n', ...
    operatorsWithMultiProcDays, (operatorsWithMultiProcDays/totalOperators)*100);

fprintf('\nTest complete!\n');