function plotAnalysisResults(analysisResults, varargin)
% Create retrospective visualizations for operator and department efficiency metrics.
% Uses explicit denominator labels so operator-turnover and lab-turnover
% metrics are not conflated in plots.
% Version: 2.2.0
%
% Available Plots and Metrics
% - Operator bar charts (always rendered):
%   - Lab flips per operator turnover by operator (% of same-operator turnovers)
%   - Median idle time per turnover by operator (minutes per turnover)
%
% - Correlation plot (enable with 'CreateCorrelationPlot', true):
%   - User selects a procedure and a procedure-time metric to correlate against
%     lab flips per operator turnover
%   - Selectable procedure-time metrics per operator for the chosen procedure:
%       'mean', 'median', 'std', 'min', 'max', 'p25', 'p75', 'p90'
%
% - Time series plot (enable with 'CreateTimeSeriesPlot', true):
%   - Operator flip ratio over time by operator, plus average operator flip ratio trend
%   - Separate department time series for lab flips per lab turnover
%
% - Box plots (enable with 'CreateBoxPlots', true):
%   - Distribution of operator lab-flips-per-operator-turnover ratios (%)
%   - Distribution of median idle time/turnover (minutes)
%
% - Daily department-wide scatter (enable with 'CreateDailyDeptScatter', true):
%   - Daily overall department Idle/Lab Turnover (min per lab turnover) vs:
%       • Lab Flips/Lab Turnover
%       • Average Concurrent Labs (includes setup + procedure + post times)
%
% Inputs:
%   analysisResults - structure returned by analyzeHistoricalData
%
% Optional Parameters:
%   'CreateCorrelationPlot' - logical, create correlation plot (default: false)
%   'CreateTimeSeriesPlot'  - logical, create time series plot (default: false)
%   'CreateBoxPlots'        - logical, create box and whisker plots (default: false)
%   'CreateDailyDeptScatter' - logical, plot daily dept idle/turnover vs flip/turnover and avg concurrent labs (default: false)
%   'SelectedProcedure'     - string, procedure for correlation (default: auto-select)
%   'SelectedMetric'        - string, metric for correlation (default: auto-select)
%
% Examples:
%   plotAnalysisResults(analysisResults)  % Basic plots only
%   plotAnalysisResults(analysisResults, 'CreateCorrelationPlot', true)
%   plotAnalysisResults(analysisResults, 'CreateCorrelationPlot', true, 'CreateTimeSeriesPlot', true)
%   plotAnalysisResults(analysisResults, 'CreateBoxPlots', true)

% Parse optional parameters
p = inputParser();
addParameter(p, 'CreateCorrelationPlot', false, @islogical);
addParameter(p, 'CreateTimeSeriesPlot', false, @islogical);
addParameter(p, 'CreateBoxPlots', false, @islogical);
addParameter(p, 'CreateDailyDeptScatter', false, @islogical);
addParameter(p, 'SelectedProcedure', '', @ischar);
addParameter(p, 'SelectedMetric', '', @ischar);
parse(p, varargin{:});

doCreateCorrelationPlot = p.Results.CreateCorrelationPlot;
doCreateTimeSeriesPlot = p.Results.CreateTimeSeriesPlot;
doCreateBoxPlots = p.Results.CreateBoxPlots;
doCreateDailyDeptScatter = p.Results.CreateDailyDeptScatter;
selectedProcedure = p.Results.SelectedProcedure;
selectedMetric = p.Results.SelectedMetric;

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

% Create first figure: Lab flips per operator turnover by operator
figure('Position', [100, 100, 1400, 1000]);

bar(validOperators, flipsPerTurnoverRatio);
set(gca, 'XTickLabel', validOperators);
xtickangle(45);
xlabel('Operator');
ylabel('Lab Flips per Operator Turnover (%)');
title('Lab Flips per Operator Turnover by Operator (Multi-Procedure Days Only)');
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

% Create correlation plot if requested
if doCreateCorrelationPlot
    % Auto-select or use provided procedure/metric
    if isempty(selectedProcedure) || isempty(selectedMetric)
        [selectedProcedure, selectedMetric] = selectProcedureAndMetric(analysisResults);
    end
    
    if ~isempty(selectedProcedure) && ~isempty(selectedMetric)
        % Collect correlation data based on selection
        [correlationValues, correlationOperators, correlationFlipRatios] = ...
            collectCorrelationData(analysisResults, validOperators, flipsPerTurnoverRatio, ...
                                  selectedProcedure, selectedMetric);
        
        % Create correlation plot
        createCorrelationPlot(correlationValues, correlationOperators, correlationFlipRatios, ...
                             selectedProcedure, selectedMetric, analysisResults, validOperators, flipsPerTurnoverRatio);
    else
        fprintf('Correlation plot cancelled or no valid selection made.\n');
    end
end

% Create time series plot if requested
if doCreateTimeSeriesPlot
    createTimeSeriesPlot(analysisResults);
end

% Create box plots if requested
if doCreateBoxPlots
    createBoxPlotsForMetrics(flipsPerTurnoverRatio, medianIdleTimeToTurnoverRatio, validOperators);
end

% Create daily department-wide scatter plots if requested
if doCreateDailyDeptScatter
    createDailyDeptScatterPlots(analysisResults);
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
[metricIdx, ok] = listdlg('PromptString', 'Select a metric to correlate with lab flips per operator turnover:', ...
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
%   correlationFlipRatios - array of lab-flips-per-operator-turnover ratios for correlation

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
%   correlationFlipRatios - array of lab-flips-per-operator-turnover ratios
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
    titleStr = sprintf('%s %s vs Lab Flips per Operator Turnover (r = %.3f)', selectedProcedure, upper(selectedMetric), rValue);
    title(titleStr);
    
    % Display correlation in console
    fprintf('Correlation between %s %s and lab flips per operator turnover: r = %.3f\n', selectedProcedure, selectedMetric, rValue);
    if abs(rValue) > 0.5
        fprintf('Strong correlation detected!\n');
    elseif abs(rValue) > 0.3
        fprintf('Moderate correlation detected.\n');
    else
        fprintf('Weak correlation.\n');
    end
else
    title(sprintf('%s %s vs Lab Flips per Operator Turnover', selectedProcedure, upper(selectedMetric)));
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
            titleStr = sprintf('%s %s vs Lab Flips per Operator Turnover (r = %.3f)', newProcedure, upper(newMetric), rValue);
            title(titleStr);
            
            % Display correlation in console
            fprintf('Correlation between %s %s and lab flips per operator turnover: r = %.3f\n', newProcedure, newMetric, rValue);
            if abs(rValue) > 0.5
                fprintf('Strong correlation detected!\n');
            elseif abs(rValue) > 0.3
                fprintf('Moderate correlation detected.\n');
            else
                fprintf('Weak correlation.\n');
            end
        else
            title(sprintf('%s %s vs Lab Flips per Operator Turnover', newProcedure, upper(newMetric)));
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
% Create time series plots for:
% 1) operator lab-flips per operator turnover over time
% 2) department lab-flips per lab turnover over time
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

% Create operator-focused figure
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

% This is the unweighted average of valid operator daily ratios, not a
% department-wide total-flips / total-turnovers calculation.
avgOperatorFlipRatio = nanmean(flipRatioMatrix, 1);
validAvgData = ~isnan(avgOperatorFlipRatio);
if any(validAvgData)
    plot(dateObjects(validAvgData), avgOperatorFlipRatio(validAvgData), 'k-', 'LineWidth', 3, ...
         'MarkerSize', 8, 'DisplayName', 'Average Operator Flip Ratio');
end

title('Operator Lab Flips per Operator Turnover Over Time');
xlabel('Date');
ylabel('Lab Flips per Operator Turnover (%)');
grid on;
legend('Location', 'best', 'FontSize', 8);
hold off;

% Create second subplot showing just the operator-average trend
subplot(2, 1, 2);
if any(validAvgData)
    plot(dateObjects(validAvgData), avgOperatorFlipRatio(validAvgData), 'ko-', 'LineWidth', 2, 'MarkerSize', 6);
    hold on;
    
    % Add trend line if we have enough points
    if sum(validAvgData) > 2
        validDates = dateObjects(validAvgData);
        validValues = avgOperatorFlipRatio(validAvgData);
        
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
        
        fprintf('Average operator flip-ratio trend: %s (slope = %.3f%% per day)\n', trendDirection, p(1));
    end
    
    hold off;
end

title('Average Operator Flip Ratio Trend');
xlabel('Date');
ylabel('Average Operator Flip Ratio (%)');
grid on;

% Add summary statistics
if validOperatorCount > 0
    fprintf('Operator time series plot created with %d operators across %d dates\n', validOperatorCount, sum(validAvgData));
    
    % Calculate and display summary statistics
    allValidRatios = flipRatioMatrix(~isnan(flipRatioMatrix));
    if ~isempty(allValidRatios)
        fprintf('Summary statistics across valid operator-day flip ratios:\n');
        fprintf('  Mean: %.1f%%\n', mean(allValidRatios));
        fprintf('  Median: %.1f%%\n', median(allValidRatios));
        fprintf('  Std Dev: %.1f%%\n', std(allValidRatios));
        fprintf('  Range: %.1f%% - %.1f%%\n', min(allValidRatios), max(allValidRatios));
    end
else
    fprintf('No valid operator time series data found for lab-flips-per-operator-turnover ratios\n');
end

createDepartmentFlipTimeSeriesPlot(analysisResults);
end

function createDepartmentFlipTimeSeriesPlot(analysisResults)
% Plot department lab flips per lab turnover over time using the daily
% department metric calculated in analyzeHistoricalData.

if ~isfield(analysisResults, 'scheduleAnalysis') || ...
   ~isfield(analysisResults.scheduleAnalysis, 'dailyEfficiency') || ...
   ~isfield(analysisResults.scheduleAnalysis.dailyEfficiency, 'byDate') || ...
   isempty(analysisResults.scheduleAnalysis.dailyEfficiency.byDate)
    warning('Department daily efficiency metrics not available for department flip-ratio plot.');
    return;
end

dailyEff = analysisResults.scheduleAnalysis.dailyEfficiency.byDate;
dateKeys = keys(dailyEff);
numDays = length(dateKeys);

if numDays == 0
    warning('No department daily efficiency entries found for department flip-ratio plot.');
    return;
end

dateObjects = NaT(numDays, 1);
deptFlipPerLabTurnover = NaN(numDays, 1);

for i = 1:numDays
    dateKey = dateKeys{i};
    try
        dateObjects(i) = datetime(dateKey, 'InputFormat', 'dd-MMM-yyyy');
    catch
        dateObjects(i) = datetime(dateKey);
    end

    d = dailyEff(dateKey);
    if isfield(d, 'overallDeptFlipToTurnoverRatioDaily')
        deptFlipPerLabTurnover(i) = d.overallDeptFlipToTurnoverRatioDaily * 100;
    end
end

[dateObjects, sortIdx] = sort(dateObjects);
deptFlipPerLabTurnover = deptFlipPerLabTurnover(sortIdx);
validData = ~isnan(deptFlipPerLabTurnover);

figure('Position', [450, 450, 1400, 500]);
if any(validData)
    plot(dateObjects(validData), deptFlipPerLabTurnover(validData), 'ko-', 'LineWidth', 2, 'MarkerSize', 6);
    hold on;

    if sum(validData) > 2
        validDates = dateObjects(validData);
        validValues = deptFlipPerLabTurnover(validData);
        dateNums = datenum(validDates);
        p = polyfit(dateNums, validValues, 1);
        trendLine = polyval(p, dateNums);
        plot(validDates, trendLine, 'r--', 'LineWidth', 2, 'DisplayName', 'Trend');

        if p(1) > 0
            trendDirection = 'increasing';
        elseif p(1) < 0
            trendDirection = 'decreasing';
        else
            trendDirection = 'stable';
        end

        fprintf('Department lab-flips-per-lab-turnover trend: %s (slope = %.3f%% per day)\n', trendDirection, p(1));
    end

    hold off;
else
    fprintf('No valid department daily lab-flips-per-lab-turnover values found.\n');
end

title('Department Lab Flips per Lab Turnover Over Time');
xlabel('Date');
ylabel('Lab Flips per Lab Turnover (%)');
grid on;
end

function createBoxPlotsForMetrics(flipsPerTurnoverRatio, medianIdleTimeToTurnoverRatio, validOperators)
% Create box and whisker plots for the two main metrics
%
% Inputs:
%   flipsPerTurnoverRatio - array of lab-flips per operator-turnover ratios (%)
%   medianIdleTimeToTurnoverRatio - array of idle time per turnover (minutes)
%   validOperators - cell array of operator names

if isempty(flipsPerTurnoverRatio) || isempty(medianIdleTimeToTurnoverRatio)
    fprintf('No data available for box plots\n');
    return;
end

% Create first box plot: Lab flips per operator turnover
figure('Position', [300, 300, 800, 600]);
boxplot(flipsPerTurnoverRatio,'Colors','k');
ylabel('Average Lab Flips per Operator Turnover (%)');
xlabel('');
set(gca,'XTickLabel','all operators');
grid off;
ylim([0 100]);

% Add summary statistics as text
stats1 = struct();
stats1.mean = mean(flipsPerTurnoverRatio);
stats1.median = median(flipsPerTurnoverRatio);
stats1.std = std(flipsPerTurnoverRatio);
stats1.min = min(flipsPerTurnoverRatio);
stats1.max = max(flipsPerTurnoverRatio);

box off;
t1 = text(0.98, 0.98, sprintf('Mean: %.1f%%\nMedian: %.1f%%\nStd: %.1f%%\nRange: %.1f%% - %.1f%%\nn = %d', ...
    stats1.mean, stats1.median, stats1.std, stats1.min, stats1.max, length(flipsPerTurnoverRatio)), ...
    'Units', 'normalized', 'VerticalAlignment', 'top', 'HorizontalAlignment', 'right', 'FontSize', 10, ...
    'BackgroundColor', 'white', 'EdgeColor', 'black');
t1.Position = [1.75 0.98];
beautifyBoxPlot(gcf,gca,[2 4]);


% Create second box plot: Idle Time per Turnover
figure('Position', [400, 400, 800, 600]);
boxplot(medianIdleTimeToTurnoverRatio,'Colors','k');
ylabel('median idle time/turnover (min)')
xlabel('');
set(gca,'XTickLabel','all operators');
grid off;
yl = ylim;
ylim([0 max(100, yl(2))]);


% Add summary statistics as text
stats2 = struct();
stats2.mean = mean(medianIdleTimeToTurnoverRatio);
stats2.median = median(medianIdleTimeToTurnoverRatio);
stats2.std = std(medianIdleTimeToTurnoverRatio);
stats2.min = min(medianIdleTimeToTurnoverRatio);
stats2.max = max(medianIdleTimeToTurnoverRatio);

box off;
t2 = text(0.98, 0.98, sprintf('Mean: %.1f min\nMedian: %.1f min\nStd: %.1f min\nRange: %.1f - %.1f min\nn = %d', ...
    stats2.mean, stats2.median, stats2.std, stats2.min, stats2.max, length(medianIdleTimeToTurnoverRatio)), ...
    'Units', 'normalized', 'VerticalAlignment', 'top', 'HorizontalAlignment', 'right', 'FontSize', 10, ...
    'BackgroundColor', 'white', 'EdgeColor', 'black');
t2.Position = [1.75 0.98];
beautifyBoxPlot(gcf,gca,[2 4]);


fprintf('Box plots created showing distribution of metrics across %d operators\n', length(validOperators));
end

function createDailyDeptScatterPlots(analysisResults)
% Plot per-day department-wide daily efficiency relationships:
% - Idle/Lab Turnover vs Lab Flips/Lab Turnover
% - Idle/Lab Turnover vs Avg Concurrent Labs
% - Lab Flips/Lab Turnover vs Makespan
% - Avg Concurrent Labs vs Makespan
% - Avg Concurrent Labs vs Lab Flips/Lab Turnover

% Validate presence of daily efficiency results
if ~isfield(analysisResults, 'scheduleAnalysis') || ...
   ~isfield(analysisResults.scheduleAnalysis, 'dailyEfficiency') || ...
   isempty(analysisResults.scheduleAnalysis.dailyEfficiency)
    warning('Daily department-wide efficiency metrics not available. Run analyzeHistoricalData with HistoricalSchedules.');
    return;
end

dailyEff = analysisResults.scheduleAnalysis.dailyEfficiency;
if ~isfield(dailyEff, 'byDate') || isempty(dailyEff.byDate)
    warning('No daily efficiency entries found.');
    return;
end

dateKeys = keys(dailyEff.byDate);
numDays = length(dateKeys);

idlePerTurn = NaN(numDays,1);
flipPerTurn = NaN(numDays,1);
avgConcurrent = NaN(numDays,1);
makespan = NaN(numDays,1);
outpatientOps = NaN(numDays,1);
flipPotential = NaN(numDays,1);

for i = 1:numDays
    d = dailyEff.byDate(dateKeys{i});
    if isfield(d, 'overallDeptIdleToTurnoverRatioDaily')
        idlePerTurn(i) = d.overallDeptIdleToTurnoverRatioDaily;
    end
    if isfield(d, 'overallDeptFlipToTurnoverRatioDaily')
        flipPerTurn(i) = d.overallDeptFlipToTurnoverRatioDaily;
    end
    if isfield(d, 'overallDeptAvgConcurrentLabsDaily')
        avgConcurrent(i) = d.overallDeptAvgConcurrentLabsDaily;
    end
    if isfield(d, 'overallDeptMakespanDaily')
        makespan(i) = d.overallDeptMakespanDaily;
    end
    if isfield(d, 'overallDeptOperatorsWithOutpatientDaily')
        outpatientOps(i) = d.overallDeptOperatorsWithOutpatientDaily;
    end
    if isfield(d, 'overallDeptFlipPotentialDaily')
        flipPotential(i) = d.overallDeptFlipPotentialDaily;
    end
end

figure('Position', [100, 100, 1800, 1000]);

% Exclude outlier days: average concurrent labs < 3 (applies to all subplots)
baseMask = isfinite(avgConcurrent) & avgConcurrent >= 3;
excludedCount = sum(isfinite(avgConcurrent) & avgConcurrent < 3);
includedCount = sum(baseMask);
totalCount = numDays;

% === ROW 1: IDLE/TURNOVER ON Y-AXIS ===

% Subplot (1,1): Lab Flips/Lab Turnover vs Idle/Lab Turnover
subplot(3,3,1);
mask1 = baseMask & isfinite(idlePerTurn) & isfinite(flipPerTurn);
scatter(flipPerTurn(mask1), idlePerTurn(mask1), 50, 'filled');
grid on;
xlabel('Lab Flips/Lab Turnover (flips per lab turnover)');
ylabel('Idle/Lab Turnover (minutes per lab turnover)');
title('Daily: Idle/Lab Turnover vs Lab Flips/Lab Turnover');
hold on;
if sum(mask1) >= 2
    x = flipPerTurn(mask1);
    y = idlePerTurn(mask1);
    p = polyfit(x, y, 1);
    xl = [min(x), max(x)];
    yl = polyval(p, xl);
    plot(xl, yl, 'r-', 'LineWidth', 2);
    [rP, pP] = corr(x, y, 'Type','Pearson');
    [rS, pS] = corr(x, y, 'Type','Spearman');
    legend('Days', sprintf('Fit: y = %.2fx%+.2f\nPearson r=%.2f (p=%.3f)\nSpearman r=%.2f (p=%.3f)', p(1), p(2), rP, pP, rS, pS), 'Location','best');
end
hold off;

% Subplot (1,2): Avg Concurrent Labs vs Idle/Lab Turnover
subplot(3,3,2);
mask2 = baseMask & isfinite(idlePerTurn) & isfinite(avgConcurrent);
scatter(avgConcurrent(mask2), idlePerTurn(mask2), 50, 'filled');
grid on;
xlabel('Average Concurrent Labs (setup+proc+post)');
ylabel('Idle/Lab Turnover (minutes per lab turnover)');
title('Daily: Idle/Lab Turnover vs Avg Concurrent Labs');
hold on;
if sum(mask2) >= 2
    x = avgConcurrent(mask2);
    y = idlePerTurn(mask2);
    p = polyfit(x, y, 1);
    xl = [min(x), max(x)];
    yl = polyval(p, xl);
    plot(xl, yl, 'r-', 'LineWidth', 2);
    [rP, pP] = corr(x, y, 'Type','Pearson');
    [rS, pS] = corr(x, y, 'Type','Spearman');
    legend('Days', sprintf('Fit: y = %.2fx%+.2f\nPearson r=%.2f (p=%.3f)\nSpearman r=%.2f (p=%.3f)', p(1), p(2), rP, pP, rS, pS), 'Location','best');
end
hold off;

% Subplot (1,3): Flip Potential vs Idle/Lab Turnover
subplot(3,3,3);
mask3 = baseMask & isfinite(idlePerTurn) & isfinite(flipPotential);
scatter(flipPotential(mask3), idlePerTurn(mask3), 50, 'filled');
grid on;
xlabel('Flip Potential (Active Labs - Effective Outpatient Ops)');
ylabel('Idle/Lab Turnover (minutes per lab turnover)');
title('Daily: Idle/Lab Turnover vs Flip Potential');
hold on;
if sum(mask3) >= 2
    x = flipPotential(mask3);
    y = idlePerTurn(mask3);
    p = polyfit(x, y, 1);
    xl = [min(x), max(x)];
    yl = polyval(p, xl);
    plot(xl, yl, 'r-', 'LineWidth', 2);
    [rP, pP] = corr(x, y, 'Type','Pearson');
    [rS, pS] = corr(x, y, 'Type','Spearman');
    legend('Days', sprintf('Fit: y = %.2fx%+.2f\nPearson r=%.2f (p=%.3f)\nSpearman r=%.2f (p=%.3f)', p(1), p(2), rP, pP, rS, pS), 'Location','best');
end
hold off;

% === ROW 2: LAB FLIPS / LAB TURNOVER ON Y-AXIS ===

% Subplot (2,2): Avg Concurrent Labs vs Lab Flips/Lab Turnover
subplot(3,3,5);
mask4 = baseMask & isfinite(avgConcurrent) & isfinite(flipPerTurn);
scatter(avgConcurrent(mask4), flipPerTurn(mask4), 50, 'filled');
grid on;
xlabel('Average Concurrent Labs (setup+proc+post)');
ylabel('Lab Flips/Lab Turnover (flips per lab turnover)');
title('Daily: Lab Flips/Lab Turnover vs Avg Concurrent Labs');
hold on;
if sum(mask4) >= 2
    x = avgConcurrent(mask4);
    y = flipPerTurn(mask4);
    p = polyfit(x, y, 1);
    xl = [min(x), max(x)];
    yl = polyval(p, xl);
    plot(xl, yl, 'r-', 'LineWidth', 2);
    [rP, pP] = corr(x, y, 'Type','Pearson');
    [rS, pS] = corr(x, y, 'Type','Spearman');
    legend('Days', sprintf('Fit: y = %.2fx%+.2f\nPearson r=%.2f (p=%.3f)\nSpearman r=%.2f (p=%.3f)', p(1), p(2), rP, pP, rS, pS), 'Location','best');
end
hold off;

% Subplot (2,3): Flip Potential vs Lab Flips/Lab Turnover
subplot(3,3,6);
mask5 = baseMask & isfinite(flipPotential) & isfinite(flipPerTurn);
scatter(flipPotential(mask5), flipPerTurn(mask5), 50, 'filled');
grid on;
xlabel('Flip Potential (Active Labs - Effective Outpatient Ops)');
ylabel('Lab Flips/Lab Turnover (flips per lab turnover)');
title('Daily: Lab Flips/Lab Turnover vs Flip Potential');
hold on;
if sum(mask5) >= 2
    x = flipPotential(mask5);
    y = flipPerTurn(mask5);
    p = polyfit(x, y, 1);
    xl = [min(x), max(x)];
    yl = polyval(p, xl);
    plot(xl, yl, 'r-', 'LineWidth', 2);
    [rP, pP] = corr(x, y, 'Type','Pearson');
    [rS, pS] = corr(x, y, 'Type','Spearman');
    legend('Days', sprintf('Fit: y = %.2fx%+.2f\nPearson r=%.2f (p=%.3f)\nSpearman r=%.2f (p=%.3f)', p(1), p(2), rP, pP, rS, pS), 'Location','best');
end
hold off;

% === ROW 3: MAKESPAN ON Y-AXIS ===

% Subplot (3,1): Lab Flips/Lab Turnover vs Makespan
subplot(3,3,7);
mask6 = baseMask & isfinite(flipPerTurn) & isfinite(makespan);
scatter(flipPerTurn(mask6), makespan(mask6), 50, 'filled');
grid on;
xlabel('Lab Flips/Lab Turnover (flips per lab turnover)');
ylabel('Makespan (minutes)');
title('Daily: Makespan vs Lab Flips/Lab Turnover');
hold on;
if sum(mask6) >= 2
    x = flipPerTurn(mask6);
    y = makespan(mask6);
    p = polyfit(x, y, 1);
    xl = [min(x), max(x)];
    yl = polyval(p, xl);
    plot(xl, yl, 'r-', 'LineWidth', 2);
    [rP, pP] = corr(x, y, 'Type','Pearson');
    [rS, pS] = corr(x, y, 'Type','Spearman');
    legend('Days', sprintf('Fit: y = %.2fx%+.2f\nPearson r=%.2f (p=%.3f)\nSpearman r=%.2f (p=%.3f)', p(1), p(2), rP, pP, rS, pS), 'Location','best');
end
hold off;

% Subplot (3,2): Avg Concurrent Labs vs Makespan
subplot(3,3,8);
mask7 = baseMask & isfinite(avgConcurrent) & isfinite(makespan);
scatter(avgConcurrent(mask7), makespan(mask7), 50, 'filled');
grid on;
xlabel('Average Concurrent Labs (setup+proc+post)');
ylabel('Makespan (minutes)');
title('Daily: Makespan vs Avg Concurrent Labs');
hold on;
if sum(mask7) >= 2
    x = avgConcurrent(mask7);
    y = makespan(mask7);
    p = polyfit(x, y, 1);
    xl = [min(x), max(x)];
    yl = polyval(p, xl);
    plot(xl, yl, 'r-', 'LineWidth', 2);
    [rP, pP] = corr(x, y, 'Type','Pearson');
    [rS, pS] = corr(x, y, 'Type','Spearman');
    legend('Days', sprintf('Fit: y = %.2fx%+.2f\nPearson r=%.2f (p=%.3f)\nSpearman r=%.2f (p=%.3f)', p(1), p(2), rP, pP, rS, pS), 'Location','best');
end
hold off;

% Subplot (3,3): Flip Potential vs Makespan
subplot(3,3,9);
mask8 = baseMask & isfinite(flipPotential) & isfinite(makespan);
scatter(flipPotential(mask8), makespan(mask8), 50, 'filled');
grid on;
xlabel('Flip Potential (Active Labs - Effective Outpatient Ops)');
ylabel('Makespan (minutes)');
title('Daily: Makespan vs Flip Potential');
hold on;
if sum(mask8) >= 2
    x = flipPotential(mask8);
    y = makespan(mask8);
    p = polyfit(x, y, 1);
    xl = [min(x), max(x)];
    yl = polyval(p, xl);
    plot(xl, yl, 'r-', 'LineWidth', 2);
    [rP, pP] = corr(x, y, 'Type','Pearson');
    [rS, pS] = corr(x, y, 'Type','Spearman');
    legend('Days', sprintf('Fit: y = %.2fx%+.2f\nPearson r=%.2f (p=%.3f)\nSpearman r=%.2f (p=%.3f)', p(1), p(2), rP, pP, rS, pS), 'Location','best');
end
hold off;

% Add note about excluded days to the figure
annotation('textbox', [0.50, 0.93, 0.48, 0.06], 'String', ...
    sprintf('Excluding %d outlier day(s) with Average Concurrent Labs < 3 (included %d of %d)', excludedCount, includedCount, totalCount), ...
    'HorizontalAlignment', 'right', 'VerticalAlignment', 'middle', 'EdgeColor', 'none', 'FontSize', 10);

fprintf(['Daily dept scatter plots created for %d days.\n' ...
         '  Excluded %d day(s) with avg concurrent labs < 3. Included %d day(s).\n' ...
         '  Plotted pairs counts: mask1=%d, mask2=%d, mask3=%d, mask4=%d, mask5=%d, mask6=%d, mask7=%d, mask8=%d.\n'], ...
        numDays, excludedCount, includedCount, sum(mask1), sum(mask2), sum(mask3), sum(mask4), sum(mask5), sum(mask6), sum(mask7), sum(mask8));
end
