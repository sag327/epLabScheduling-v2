% Quick example to create operator flips bar chart
% Load data and run analysis
data = load('data/historicalEPData.mat');
schedules = load('data/historicalEPSchedules.mat');
analysisResults = analyzeHistoricalData(data.historicalData, ...
    'HistoricalSchedules', schedules.historicalSchedules, 'ShowStats', false);

% Extract operator names and average flips
averages = analysisResults.operatorAnalysis.multiProcedureDayAverages;
operatorNames = keys(averages);

% Get data for operators with valid flips
avgFlips = [];
validOperators = {};
for i = 1:length(operatorNames)
    opData = averages(operatorNames{i});
    if ~isnan(opData.avgFlips) && opData.multiProcedureDays > 0
        avgFlips(end+1) = opData.avgFlips;
        validOperators{end+1} = operatorNames{i};
    end
end

% Sort by flip count (descending)
[avgFlips, idx] = sort(avgFlips, 'descend');
validOperators = validOperators(idx);

% Create bar chart
figure;
bar(avgFlips);
set(gca, 'XTickLabel', validOperators);
xtickangle(45);
xlabel('Operator');
ylabel('Average Lab Flips per Multi-Procedure Day');
title('Average Lab Flips by Operator');
grid on;

% Add value labels on bars
for i = 1:length(avgFlips)
    text(i, avgFlips(i) + 0.05, sprintf('%.2f', avgFlips(i)), ...
         'HorizontalAlignment', 'center');
end