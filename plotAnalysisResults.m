function plotAnalysisResults(analysisResults)
% Create subplots showing operator performance metrics from multi-procedure days
% Input: analysisResults - structure returned by analyzeHistoricalData

if ~isfield(analysisResults, 'operatorAnalysis') || ...
   ~isfield(analysisResults.operatorAnalysis, 'multiProcedureDayAverages')
    error('Analysis results must contain multi-procedure day averages');
end

averages = analysisResults.operatorAnalysis.multiProcedureDayAverages;
caseStats = analysisResults.operatorAnalysis.caseStats;
operatorNames = keys(averages);

% Extract metrics for operators with multi-procedure days
avgFlips = [];
avgIdleTimes = [];
avgCasesPerMultiProcDay = [];
flipsPerCaseRatio = [];
flipsPerTurnoverRatio = [];
idleTimeToTurnoverRatio = [];
validOperators = {};

for i = 1:length(operatorNames)
    opName = operatorNames{i};
    opData = averages(opName);
    opCaseArray = caseStats(opName);
    
    % Only include operators with valid multi-procedure day data
    if ~isnan(opData.avgFlips) && ~isnan(opData.avgIdleTime) && opData.multiProcedureDays > 0
        % Find multi-procedure days (>1 case) and calculate average cases per such day
        multiProcDayMask = opCaseArray > 1;
        multiProcCases = opCaseArray(multiProcDayMask);
        validMultiProcCases = multiProcCases(~isnan(multiProcCases));
        
        if ~isempty(validMultiProcCases)
            avgCasesThisOp = mean(validMultiProcCases);
            avgTurnOversThisOp = avgCasesThisOp - 1;
            avgFlipsThisOp = opData.avgFlips;
            avgIdleTimeThisOp = opData.avgIdleTime;
            
            avgFlips = [avgFlips, avgFlipsThisOp];
            avgIdleTimes = [avgIdleTimes, avgIdleTimeThisOp];
            avgCasesPerMultiProcDay = [avgCasesPerMultiProcDay, avgCasesThisOp];
            flipsPerCaseRatio = [flipsPerCaseRatio, avgFlipsThisOp / avgCasesThisOp];
            flipsPerTurnoverRatio = [flipsPerTurnoverRatio, avgFlipsThisOp / avgTurnOversThisOp];
            idleTimeToTurnoverRatio = [idleTimeToTurnoverRatio, avgIdleTimeThisOp / avgTurnOversThisOp];
            validOperators{end+1} = opName;
        end
    end
end

if isempty(avgFlips)
    fprintf('No operators with valid multi-procedure day data found\n');
    return;
end

% Sort operators by average flips (descending) for consistent ordering
[~, sortIdx] = sort(avgFlips, 'descend');
avgFlips = avgFlips(sortIdx);
avgIdleTimes = avgIdleTimes(sortIdx);
avgCasesPerMultiProcDay = avgCasesPerMultiProcDay(sortIdx);
flipsPerCaseRatio = flipsPerCaseRatio(sortIdx);
flipsPerTurnoverRatio = flipsPerTurnoverRatio(sortIdx);
idleTimeToTurnoverRatio = idleTimeToTurnoverRatio(sortIdx);
validOperators = validOperators(sortIdx);

flipsPerTurnoverRatio = flipsPerTurnoverRatio .* 100;

% Create first figure: Proportion of Turnovers that are Flips
figure('Position', [100, 100, 1400, 1000]);

bar(validOperators, flipsPerTurnoverRatio);
set(gca, 'XTickLabel', validOperators);
xtickangle(45);
xlabel('Operator');
ylabel('% of Turnovers');
title('Proportion of Turnovers that are Flips by Operator (Multi-Procedure Days Only)');
grid on;
% Add value labels
for i = 1:length(flipsPerTurnoverRatio)
    text(i, flipsPerTurnoverRatio(i) + 0.01, sprintf('%.1f', flipsPerTurnoverRatio(i)), ...
         'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom');
end

% Create second figure: Average Idle Time to Average Number of Turnovers Ratio
figure('Position', [200, 200, 1400, 1000]);

bar(validOperators, idleTimeToTurnoverRatio);
set(gca, 'XTickLabel', validOperators);
xtickangle(45);
xlabel('Operator');
ylabel('Idle Time per Turnover (minutes)');
title('Average Idle Time per Turnover by Operator (Multi-Procedure Days Only)');
grid on;
% Add value labels
for i = 1:length(idleTimeToTurnoverRatio)
    text(i, idleTimeToTurnoverRatio(i) + max(idleTimeToTurnoverRatio)*0.01, sprintf('%.1f', idleTimeToTurnoverRatio(i)), ...
         'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom');
end

fprintf('Charts created with %d operators\n', length(validOperators));
end