function plotAnalysisResults(analysisResults)
% Create subplots showing operator performance metrics from multi-procedure days
% Uses pre-calculated flip-to-turnover ratios and correlates with selected procedure metrics
% Version: 2.1.0
% Input: analysisResults - structure returned by analyzeHistoricalData

if ~isfield(analysisResults, 'operatorAnalysis') || ...
   ~isfield(analysisResults.operatorAnalysis, 'multiProcedureDayAverages')
    error('Analysis results must contain multi-procedure day averages');
end

if ~isfield(analysisResults, 'procedureTimeByOperator')
    error('Analysis results must contain procedureTimeByOperator for atrial fibrillation ablation analysis');
end

averages = analysisResults.operatorAnalysis.multiProcedureDayAverages;
caseStats = analysisResults.operatorAnalysis.caseStats;
operatorNames = keys(averages);

% Extract metrics for operators with multi-procedure days
avgFlips = [];
medianIdleTimes = [];
avgCasesPerMultiProcDay = [];
flipsPerCaseRatio = [];
flipsPerTurnoverRatio = [];
medianIdleTimeToTurnoverRatio = [];
procedureTimeStd = [];
validOperators = {};

% Arrays for correlation analysis (will be populated based on user selection)
correlationValues = [];
correlationOperators = {};
correlationFlipRatios = [];

for i = 1:length(operatorNames)
    opName = operatorNames{i};
    opData = averages(opName);
    opCaseArray = caseStats(opName);
    
    % Include operators with valid multi-procedure day data for first two plots
    if ~isnan(opData.avgFlips) && ~isnan(opData.medianIdleTime) && ~isnan(opData.flipToTurnoverRatio) && opData.multiProcedureDays > 0
        % Use pre-calculated values from analysis results
        avgFlipsThisOp = opData.avgFlips;
        medianIdleTimeThisOp = opData.medianIdleTime;
        avgCasesThisOp = opData.avgCasesPerMultiProcDay;
        flipToTurnoverRatioThisOp = opData.flipToTurnoverRatio;
        avgTurnOversThisOp = avgCasesThisOp - 1;
        
        avgFlips = [avgFlips, avgFlipsThisOp];
        medianIdleTimes = [medianIdleTimes, medianIdleTimeThisOp];
        avgCasesPerMultiProcDay = [avgCasesPerMultiProcDay, avgCasesThisOp];
        flipsPerCaseRatio = [flipsPerCaseRatio, avgFlipsThisOp / avgCasesThisOp];
        flipsPerTurnoverRatio = [flipsPerTurnoverRatio, flipToTurnoverRatioThisOp];
        % ONLY use the correctly calculated medianIdleTimePerTurnover from comprehensive metrics
        % No fallback calculations - if comprehensive data not available, skip this operator
        if isfield(analysisResults, 'comprehensiveOperatorMetrics')
            safeOpName = matlab.lang.makeValidName(opName);
            if isfield(analysisResults.comprehensiveOperatorMetrics, safeOpName)
                compMetrics = analysisResults.comprehensiveOperatorMetrics.(safeOpName);
                if isfield(compMetrics, 'medianIdleTimePerTurnover') && ~isnan(compMetrics.medianIdleTimePerTurnover)
                    medianIdleTimeToTurnoverRatio = [medianIdleTimeToTurnoverRatio, compMetrics.medianIdleTimePerTurnover];
                else
                    % Skip operator if no valid comprehensive data - do not use fallback calculation
                    continue;
                end
            else
                % Skip operator if not in comprehensive metrics
                continue;
            end
        else
            % Skip all operators if comprehensive metrics not available
            warning('Comprehensive metrics not available - cannot plot idle time per turnover');
            break;
        end
        validOperators{end+1} = opName;
        
    end
end

if isempty(avgFlips)
    fprintf('No operators with valid multi-procedure day data found\n');
    return;
end

fprintf('Found %d operators with multi-procedure day data\n', length(validOperators));

% Sort operators by average flips (descending) for consistent ordering
[~, sortIdx] = sort(avgFlips, 'descend');
avgFlips = avgFlips(sortIdx);
medianIdleTimes = medianIdleTimes(sortIdx);
avgCasesPerMultiProcDay = avgCasesPerMultiProcDay(sortIdx);
flipsPerCaseRatio = flipsPerCaseRatio(sortIdx);
flipsPerTurnoverRatio = flipsPerTurnoverRatio(sortIdx);
medianIdleTimeToTurnoverRatio = medianIdleTimeToTurnoverRatio(sortIdx);
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

% Create second figure: Median Idle Time to Average Number of Turnovers Ratio
figure('Position', [200, 200, 1400, 1000]);

bar(validOperators, medianIdleTimeToTurnoverRatio);
set(gca, 'XTickLabel', validOperators);
xtickangle(45);
xlabel('Operator');
ylabel('Median Idle Time per Turnover (minutes)');
title('Median Idle Time per Turnover by Operator (Multi-Procedure Days Only)');
grid on;
% Add value labels
for i = 1:length(medianIdleTimeToTurnoverRatio)
    text(i, medianIdleTimeToTurnoverRatio(i) + max(medianIdleTimeToTurnoverRatio)*0.01, sprintf('%.1f', medianIdleTimeToTurnoverRatio(i)), ...
         'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom');
end

% Ask user if they want to create a correlation plot
answer = questdlg('Do you want to create a correlation plot with procedure metrics?', ...
                  'Correlation Analysis', 'Yes', 'No', 'Yes');

if strcmp(answer, 'Yes')
    % Get available procedures and metrics from analysis results
    [selectedProcedure, selectedMetric] = selectProcedureAndMetric(analysisResults);
    
    if ~isempty(selectedProcedure) && ~isempty(selectedMetric)
        % Collect correlation data based on user selection
        [correlationValues, correlationOperators, correlationFlipRatios] = ...
            collectCorrelationData(analysisResults, validOperators, flipsPerTurnoverRatio, ...
                                  selectedProcedure, selectedMetric);
        
        % Create correlation plot with reselect capability
        createCorrelationPlot(correlationValues, correlationOperators, correlationFlipRatios, ...
                             selectedProcedure, selectedMetric, analysisResults, validOperators, flipsPerTurnoverRatio);
    else
        fprintf('Correlation plot cancelled or no valid selection made.\n');
    end
end

% Ask user if they want to create a time series plot
answer = questdlg('Do you want to create a time series plot showing flip-to-turnover ratios over time?', ...
                  'Time Series Analysis', 'Yes', 'No', 'Yes');

if strcmp(answer, 'Yes')
    createTimeSeriesPlot(analysisResults);
end

fprintf('Charts created with %d operators\n', length(validOperators));
end

function [selectedProcedure, selectedMetric] = selectProcedureAndMetric(analysisResults)
% Create popup windows for user to select procedure and metric
% 
% Output:
%   selectedProcedure - string, name of selected procedure (empty if cancelled)
%   selectedMetric - string, name of selected metric (empty if cancelled)

selectedProcedure = '';
selectedMetric = '';

% Get all available procedures from the analysis results
if ~isfield(analysisResults, 'procedureTimeByOperator')
    msgbox('No procedure-by-operator data available for correlation analysis.', 'Error', 'error');
    return;
end

% Collect all unique procedure names
allProcedures = {};
operatorFields = fieldnames(analysisResults.procedureTimeByOperator);

for i = 1:length(operatorFields)
    opField = operatorFields{i};
    if ~strcmp(opField, 'operatorName') && ~strcmp(opField, 'totalCases')
        opData = analysisResults.procedureTimeByOperator.(opField);
        procFields = fieldnames(opData);
        procFields = procFields(~strcmp(procFields, 'operatorName') & ~strcmp(procFields, 'totalCases'));
        
        for j = 1:length(procFields)
            procField = procFields{j};
            if isfield(opData, procField) && isfield(opData.(procField), 'procedureName')
                procName = opData.(procField).procedureName;
                if ~ismember(procName, allProcedures)
                    allProcedures{end+1} = procName;
                end
            end
        end
    end
end

if isempty(allProcedures)
    msgbox('No procedures found in the analysis results.', 'Error', 'error');
    return;
end

% Sort procedures alphabetically
allProcedures = sort(allProcedures);

% Show procedure selection dialog
[procIdx, ok] = listdlg('PromptString', 'Select a procedure type:', ...
                        'SelectionMode', 'single', ...
                        'ListString', allProcedures, ...
                        'ListSize', [400, 300], ...
                        'Name', 'Procedure Selection');

if ~ok || isempty(procIdx)
    return; % User cancelled
end

selectedProcedure = allProcedures{procIdx};

% Define available metrics
availableMetrics = {'mean', 'median', 'std', 'min', 'max', 'p25', 'p75', 'p90'};
metricDescriptions = {
    'Mean - Average procedure time',
    'Median - 50th percentile procedure time', 
    'Std - Standard deviation of procedure times',
    'Min - Minimum procedure time',
    'Max - Maximum procedure time',
    'P25 - 25th percentile procedure time',
    'P75 - 75th percentile procedure time',
    'P90 - 90th percentile procedure time'
};

% Show metric selection dialog
[metricIdx, ok] = listdlg('PromptString', 'Select a metric to correlate with flip-to-turnover ratio:', ...
                          'SelectionMode', 'single', ...
                          'ListString', metricDescriptions, ...
                          'ListSize', [500, 250], ...
                          'Name', 'Metric Selection');

if ~ok || isempty(metricIdx)
    selectedProcedure = ''; % Reset since user cancelled
    return;
end

selectedMetric = availableMetrics{metricIdx};
end

function [correlationValues, correlationOperators, correlationFlipRatios] = ...
    collectCorrelationData(analysisResults, validOperators, flipsPerTurnoverRatio, selectedProcedure, selectedMetric)
% Collect correlation data based on user selection
%
% Outputs:
%   correlationValues - array of metric values for correlation
%   correlationOperators - cell array of operator names with valid data
%   correlationFlipRatios - array of flip-to-turnover ratios for correlation

correlationValues = [];
correlationOperators = {};
correlationFlipRatios = [];

for i = 1:length(validOperators)
    opName = validOperators{i};
    opFieldName = matlab.lang.makeValidName(opName);
    
    if isfield(analysisResults.procedureTimeByOperator, opFieldName)
        opData = analysisResults.procedureTimeByOperator.(opFieldName);
        procFields = fieldnames(opData);
        procFields = procFields(~strcmp(procFields, 'operatorName') & ~strcmp(procFields, 'totalCases'));
        
        % Look for the selected procedure
        for j = 1:length(procFields)
            procField = procFields{j};
            if isfield(opData, procField) && isfield(opData.(procField), 'procedureName')
                if strcmp(opData.(procField).procedureName, selectedProcedure)
                    % Found the procedure, get the selected metric
                    procInfo = opData.(procField);
                    if isfield(procInfo, 'procedureTime') && procInfo.procedureTime.validCount > 0
                        if isfield(procInfo.procedureTime, selectedMetric)
                            metricValue = procInfo.procedureTime.(selectedMetric);
                            if ~isnan(metricValue)
                                correlationValues = [correlationValues, metricValue];
                                correlationOperators{end+1} = opName;
                                correlationFlipRatios = [correlationFlipRatios, flipsPerTurnoverRatio(i)];
                            end
                        end
                    end
                    break; % Found the procedure, no need to continue
                end
            end
        end
    end
end
end

function createCorrelationPlot(correlationValues, correlationOperators, correlationFlipRatios, selectedProcedure, selectedMetric, analysisResults, validOperators, flipsPerTurnoverRatio)
% Create the correlation scatter plot with reselect capability
%
% Inputs:
%   correlationValues - array of metric values
%   correlationOperators - cell array of operator names  
%   correlationFlipRatios - array of flip-to-turnover ratios
%   selectedProcedure - string, name of selected procedure
%   selectedMetric - string, name of selected metric
%   analysisResults - full analysis results for reselection
%   validOperators - all valid operators for reselection
%   flipsPerTurnoverRatio - all flip ratios for reselection

if isempty(correlationValues)
    msgbox(sprintf('No data found for %s procedure with %s metric.', selectedProcedure, selectedMetric), ...
           'No Data', 'warn');
    return;
end

% Create new figure
fig = figure('Position', [300, 300, 1400, 1000]);

% Flip ratios are already in percentages (converted earlier)

% Create scatter plot
scatter(correlationValues, correlationFlipRatios, 100, 'filled');
hold on;

% Add operator labels next to points
for i = 1:length(correlationOperators)
    text(correlationValues(i) + max(correlationValues)*0.01, correlationFlipRatios(i), correlationOperators{i}, ...
         'FontSize', 8, 'HorizontalAlignment', 'left');
end

% Calculate and display correlation
if length(correlationValues) > 2
    correlationCoeff = corrcoef(correlationValues, correlationFlipRatios);
    rValue = correlationCoeff(1,2);
    
    % Add trend line
    p = polyfit(correlationValues, correlationFlipRatios, 1);
    xTrend = linspace(min(correlationValues), max(correlationValues), 100);
    yTrend = polyval(p, xTrend);
    plot(xTrend, yTrend, 'r--', 'LineWidth', 2);
    
    % Create title with correlation
    titleStr = sprintf('%s %s vs Flip-to-Turnover Ratio (r = %.3f)', selectedProcedure, upper(selectedMetric), rValue);
    title(titleStr);
    
    % Display correlation in console
    fprintf('Correlation between %s %s and flip-to-turnover ratio: r = %.3f\n', selectedProcedure, selectedMetric, rValue);
    if abs(rValue) > 0.5
        fprintf('Strong correlation detected!\n');
    elseif abs(rValue) > 0.3
        fprintf('Moderate correlation detected.\n');
    else
        fprintf('Weak correlation.\n');
    end
else
    title(sprintf('%s %s vs Flip-to-Turnover Ratio', selectedProcedure, upper(selectedMetric)));
    fprintf('Not enough data points for correlation analysis (%d points)\n', length(correlationValues));
end

% Set axis labels
xlabel(sprintf('%s %s (minutes)', selectedProcedure, upper(selectedMetric)));
ylabel('% of Turnovers that are Flips');
grid on;
hold off;

% Add "Reselect Options" button
reselectBtn = uicontrol('Style', 'pushbutton', ...
                       'String', 'Reselect Options', ...
                       'Position', [20, 20, 120, 30], ...
                       'FontSize', 10, ...
                       'Callback', @(src, event) reselectOptionsCallback(fig, analysisResults, validOperators, flipsPerTurnoverRatio));

fprintf('Correlation plot created with %d data points\n', length(correlationValues));
end

function reselectOptionsCallback(fig, analysisResults, validOperators, flipsPerTurnoverRatio)
% Callback function for the reselect options button
% Allows user to choose new procedure and metric and replot

% Get new selections from user
[newProcedure, newMetric] = selectProcedureAndMetric(analysisResults);

if ~isempty(newProcedure) && ~isempty(newMetric)
    % Collect new correlation data
    [newCorrelationValues, newCorrelationOperators, newCorrelationFlipRatios] = ...
        collectCorrelationData(analysisResults, validOperators, flipsPerTurnoverRatio, ...
                              newProcedure, newMetric);
    
    if ~isempty(newCorrelationValues)
        % Clear the current figure and replot with new data
        figure(fig);
        clf(fig);
        
        % Flip ratios are already in percentages (converted earlier)
        
        % Create new scatter plot
        scatter(newCorrelationValues, newCorrelationFlipRatios, 100, 'filled');
        hold on;
        
        % Add operator labels next to points
        for i = 1:length(newCorrelationOperators)
            text(newCorrelationValues(i) + max(newCorrelationValues)*0.01, newCorrelationFlipRatios(i), newCorrelationOperators{i}, ...
                 'FontSize', 8, 'HorizontalAlignment', 'left');
        end
        
        % Calculate and display correlation
        if length(newCorrelationValues) > 2
            correlationCoeff = corrcoef(newCorrelationValues, newCorrelationFlipRatios);
            rValue = correlationCoeff(1,2);
            
            % Add trend line
            p = polyfit(newCorrelationValues, newCorrelationFlipRatios, 1);
            xTrend = linspace(min(newCorrelationValues), max(newCorrelationValues), 100);
            yTrend = polyval(p, xTrend);
            plot(xTrend, yTrend, 'r--', 'LineWidth', 2);
            
            % Create title with correlation
            titleStr = sprintf('%s %s vs Flip-to-Turnover Ratio (r = %.3f)', newProcedure, upper(newMetric), rValue);
            title(titleStr);
            
            % Display correlation in console
            fprintf('Correlation between %s %s and flip-to-turnover ratio: r = %.3f\n', newProcedure, newMetric, rValue);
            if abs(rValue) > 0.5
                fprintf('Strong correlation detected!\n');
            elseif abs(rValue) > 0.3
                fprintf('Moderate correlation detected.\n');
            else
                fprintf('Weak correlation.\n');
            end
        else
            title(sprintf('%s %s vs Flip-to-Turnover Ratio', newProcedure, upper(newMetric)));
            fprintf('Not enough data points for correlation analysis (%d points)\n', length(newCorrelationValues));
        end
        
        % Set axis labels
        xlabel(sprintf('%s %s (minutes)', newProcedure, upper(newMetric)));
        ylabel('% of Turnovers that are Flips');
        grid on;
        hold off;
        
        % Re-add the reselect button (since clf cleared it)
        uicontrol('Style', 'pushbutton', ...
                 'String', 'Reselect Options', ...
                 'Position', [20, 20, 120, 30], ...
                 'FontSize', 10, ...
                 'Callback', @(src, event) reselectOptionsCallback(fig, analysisResults, validOperators, flipsPerTurnoverRatio));
        
        fprintf('Plot updated with %d data points\n', length(newCorrelationValues));
    else
        msgbox(sprintf('No data found for %s procedure with %s metric.', newProcedure, newMetric), ...
               'No Data', 'warn');
    end
else
    fprintf('Reselection cancelled.\n');
end
end

function createTimeSeriesPlot(analysisResults)
% Create a time series plot showing flip-to-turnover ratios over time for all operators
%
% Input:
%   analysisResults - structure returned by analyzeHistoricalData

if ~isfield(analysisResults, 'operatorAnalysis') || ...
   ~isfield(analysisResults.operatorAnalysis, 'caseStats') || ...
   ~isfield(analysisResults.operatorAnalysis, 'idleTimeStats') || ...
   ~isfield(analysisResults.operatorAnalysis, 'analyzedDates')
    msgbox('No time series data available. Operator analysis with schedules is required.', 'Error', 'error');
    return;
end

% Get time series data
caseStats = analysisResults.operatorAnalysis.caseStats;
idleTimeStats = analysisResults.operatorAnalysis.idleTimeStats;
analyzedDates = analysisResults.operatorAnalysis.analyzedDates;

if isempty(analyzedDates)
    msgbox('No analyzed dates found in the data.', 'Error', 'error');
    return;
end

% Convert date strings to datetime objects for proper plotting
try
    dateObjects = datetime(analyzedDates, 'InputFormat', 'dd-MMM-yyyy');
catch
    % Try alternative format
    try
        dateObjects = datetime(analyzedDates);
    catch
        msgbox('Unable to parse dates for time series plot.', 'Error', 'error');
        return;
    end
end

% Get all operators
operatorNames = keys(caseStats);
numOperators = length(operatorNames);
numDates = length(analyzedDates);

if numOperators == 0 || numDates == 0
    msgbox('No operator data available for time series plot.', 'Error', 'error');
    return;
end

% Create new figure for time series plot
figure('Position', [400, 400, 1400, 800]);

% Calculate flip-to-turnover ratios for each operator on each day
flipRatioMatrix = NaN(numOperators, numDates);  % operators x dates
operatorLabels = cell(numOperators, 1);

for opIdx = 1:numOperators
    opName = operatorNames{opIdx};
    operatorLabels{opIdx} = opName;
    
    caseArray = caseStats(opName);
    
    % Get flip stats if available
    if isfield(analysisResults.operatorAnalysis, 'idleTimeStats') && ...
       isfield(analysisResults, 'labFlipAnalysis') && ...
       isfield(analysisResults.labFlipAnalysis, 'operatorFlipStats') && ...
       isKey(analysisResults.labFlipAnalysis.operatorFlipStats, opName)
        
        flipArray = analysisResults.labFlipAnalysis.operatorFlipStats(opName);
        
        for dateIdx = 1:numDates
            casesThisDay = caseArray(dateIdx);
            flipsThisDay = flipArray(dateIdx);
            
            % Only calculate ratio for multi-procedure days (>1 case)
            if ~isnan(casesThisDay) && casesThisDay > 1 && ~isnan(flipsThisDay)
                turnovers = casesThisDay - 1;
                if turnovers > 0
                    flipRatioMatrix(opIdx, dateIdx) = (flipsThisDay / turnovers) * 100; % Convert to percentage
                end
            end
        end
    end
end

% Plot options
subplot(2, 1, 1);
% Plot individual operator lines (lighter colors)
colors = lines(numOperators);
hold on;

validOperatorCount = 0;
for opIdx = 1:numOperators
    validData = ~isnan(flipRatioMatrix(opIdx, :));
    if any(validData)
        validOperatorCount = validOperatorCount + 1;
        plot(dateObjects, flipRatioMatrix(opIdx, :), 'o-', 'Color', colors(opIdx, :), ...
             'LineWidth', 1, 'MarkerSize', 4, 'DisplayName', operatorLabels{opIdx});
    end
end

% Calculate and plot overall average
overallAvg = nanmean(flipRatioMatrix, 1);
validAvgData = ~isnan(overallAvg);
if any(validAvgData)
    plot(dateObjects(validAvgData), overallAvg(validAvgData), 'k-', 'LineWidth', 3, ...
         'MarkerSize', 8, 'DisplayName', 'Overall Average');
end

title('Flip-to-Turnover Ratio Over Time by Operator');
xlabel('Date');
ylabel('Flip-to-Turnover Ratio (%)');
grid on;
legend('Location', 'best', 'FontSize', 8);
hold off;

% Create second subplot showing just the overall trend
subplot(2, 1, 2);
if any(validAvgData)
    plot(dateObjects(validAvgData), overallAvg(validAvgData), 'ko-', 'LineWidth', 2, 'MarkerSize', 6);
    hold on;
    
    % Add trend line if we have enough points
    if sum(validAvgData) > 2
        validDates = dateObjects(validAvgData);
        validValues = overallAvg(validAvgData);
        
        % Convert dates to numbers for polyfit
        dateNums = datenum(validDates);
        p = polyfit(dateNums, validValues, 1);
        trendLine = polyval(p, dateNums);
        plot(validDates, trendLine, 'r--', 'LineWidth', 2, 'DisplayName', 'Trend');
        
        % Display trend info
        if p(1) > 0
            trendDirection = 'increasing';
        elseif p(1) < 0
            trendDirection = 'decreasing';
        else
            trendDirection = 'stable';
        end
        
        fprintf('Overall flip-to-turnover ratio trend: %s (slope = %.3f%% per day)\n', trendDirection, p(1));
    end
    
    hold off;
end

title('Overall Average Flip-to-Turnover Ratio Trend');
xlabel('Date');
ylabel('Average Flip-to-Turnover Ratio (%)');
grid on;

% Add summary statistics
if validOperatorCount > 0
    fprintf('Time series plot created with %d operators across %d dates\n', validOperatorCount, sum(validAvgData));
    
    % Calculate and display summary statistics
    allValidRatios = flipRatioMatrix(~isnan(flipRatioMatrix));
    if ~isempty(allValidRatios)
        fprintf('Summary statistics across all operators and dates:\n');
        fprintf('  Mean: %.1f%%\n', mean(allValidRatios));
        fprintf('  Median: %.1f%%\n', median(allValidRatios));
        fprintf('  Std Dev: %.1f%%\n', std(allValidRatios));
        fprintf('  Range: %.1f%% - %.1f%%\n', min(allValidRatios), max(allValidRatios));
    end
else
    fprintf('No valid time series data found for flip-to-turnover ratios\n');
end
end