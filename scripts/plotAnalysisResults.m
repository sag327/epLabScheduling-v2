function plotAnalysisResults(analysisResults, varargin)
% Create retrospective visualizations for operator and department efficiency metrics.
% Uses explicit denominator labels so operator-turnover and lab-turnover
% metrics are not conflated in plots.
% Version: 2.2.0
%
% Available Plots and Metrics
% - Operator bar charts (rendered by default when time-series mode is off):
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
%   - Figure 1: average operator flip ratio and department flip ratio over time
%   - Figure 2: median operator idle time per turnover over time
%   - Optional operator-trace figure when 'ShowIndividualOperatorTraces' is true
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
%   'ShowIndividualOperatorTraces' - logical, show the optional individual
%                                    operator trace figure when plotting
%                                    time series data (default: false)
%   'RetrospectiveMonths' - positive scalar, plot only the latest N months
%                           in time-series mode (default: all dates)
%   'CreateBoxPlots'        - logical, create box and whisker plots (default: false)
%   'CreateDailyDeptScatter' - logical, plot daily dept idle/turnover vs flip/turnover and avg concurrent labs (default: false)
%   'SelectedProcedure'     - string, procedure for correlation (default: auto-select)
%   'SelectedMetric'        - string, metric for correlation (default: auto-select)
%
% Examples:
%   plotAnalysisResults(analysisResults)  % Basic plots only
%   plotAnalysisResults(analysisResults, 'CreateCorrelationPlot', true)
%   plotAnalysisResults(analysisResults, 'CreateCorrelationPlot', true, 'CreateTimeSeriesPlot', true)
%   plotAnalysisResults(analysisResults, 'CreateTimeSeriesPlot', true, 'ShowIndividualOperatorTraces', true)
%   plotAnalysisResults(analysisResults, 'CreateTimeSeriesPlot', true, 'RetrospectiveMonths', 6)
%   plotAnalysisResults(analysisResults, 'CreateBoxPlots', true)

% Parse optional parameters
p = inputParser();
addParameter(p, 'CreateCorrelationPlot', false, @islogical);
addParameter(p, 'CreateTimeSeriesPlot', false, @islogical);
addParameter(p, 'ShowIndividualOperatorTraces', false, @islogical);
addParameter(p, 'RetrospectiveMonths', [], @(x) isempty(x) || (isnumeric(x) && isscalar(x) && x > 0 && floor(x) == x));
addParameter(p, 'CreateBoxPlots', false, @islogical);
addParameter(p, 'CreateDailyDeptScatter', false, @islogical);
addParameter(p, 'SelectedProcedure', '', @ischar);
addParameter(p, 'SelectedMetric', '', @ischar);
parse(p, varargin{:});

doCreateCorrelationPlot = p.Results.CreateCorrelationPlot;
doCreateTimeSeriesPlot = p.Results.CreateTimeSeriesPlot;
doShowIndividualOperatorTraces = p.Results.ShowIndividualOperatorTraces;
retrospectiveMonths = p.Results.RetrospectiveMonths;
doCreateBoxPlots = p.Results.CreateBoxPlots;
doCreateDailyDeptScatter = p.Results.CreateDailyDeptScatter;
selectedProcedure = p.Results.SelectedProcedure;
selectedMetric = p.Results.SelectedMetric;

if doCreateTimeSeriesPlot
    createTimeSeriesPlot(analysisResults, doShowIndividualOperatorTraces, retrospectiveMonths);
    return;
end

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

createOperatorSummaryBarFigure(validOperators, flipsPerTurnoverRatio, medianIdleTimeToTurnoverRatio);

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

function createOperatorSummaryBarFigure(validOperators, flipsPerTurnoverRatio, medianIdleTimeToTurnoverRatio)
fig = figure('Position', [100, 100, 1400, 1000], 'Color', 'w', 'InvertHardcopy', 'off');

ax1 = subplot(2, 1, 1, 'Parent', fig);
bar(ax1, flipsPerTurnoverRatio);
set(ax1, 'XTick', 1:length(validOperators), 'XTickLabel', validOperators);
xlabel(ax1, 'Operator');
ylabel(ax1, 'Lab Flips per Operator Turnover (%)');
title(ax1, 'Lab Flips per Operator Turnover by Operator (Multi-Procedure Days Only)');
grid(ax1, 'on');
xtickangle(ax1, 45);
for i = 1:length(flipsPerTurnoverRatio)
    text(ax1, i, flipsPerTurnoverRatio(i) + max(1, max(flipsPerTurnoverRatio) * 0.01), sprintf('%.1f', flipsPerTurnoverRatio(i)), ...
         'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom');
end

ax2 = subplot(2, 1, 2, 'Parent', fig);
bar(ax2, medianIdleTimeToTurnoverRatio);
set(ax2, 'XTick', 1:length(validOperators), 'XTickLabel', validOperators);
xlabel(ax2, 'Operator');
ylabel(ax2, 'Median Idle Time per Turnover (minutes)');
title(ax2, 'Median Idle Time per Turnover by Operator (Multi-Procedure Days Only)');
grid(ax2, 'on');
xtickangle(ax2, 45);
idleLabelOffset = max(1, max(medianIdleTimeToTurnoverRatio) * 0.01);
for i = 1:length(medianIdleTimeToTurnoverRatio)
    text(ax2, i, medianIdleTimeToTurnoverRatio(i) + idleLabelOffset, sprintf('%.1f', medianIdleTimeToTurnoverRatio(i)), ...
         'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom');
end
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
    plot(xTrend, yTrend, 'r-', 'LineWidth', 2);
    
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
            plot(xTrend, yTrend, 'r-', 'LineWidth', 2);
            
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

function createTimeSeriesPlot(analysisResults, showIndividualOperatorTraces, retrospectiveMonths)
% Create retrospective time series figures:
% 1) average operator flip ratio and department flip ratio
% 2) median operator idle time per turnover
%
% Input:
%   analysisResults - structure returned by analyzeHistoricalData
%   showIndividualOperatorTraces - logical, show optional operator-trace figure
%   retrospectiveMonths - positive scalar months to show, or [] for all dates

if nargin < 2
    showIndividualOperatorTraces = false;
end
if nargin < 3
    retrospectiveMonths = [];
end

if ~isfield(analysisResults, 'operatorAnalysis') || ...
   ~isfield(analysisResults.operatorAnalysis, 'caseStats') || ...
   ~isfield(analysisResults.operatorAnalysis, 'idleTimeStats') || ...
   ~isfield(analysisResults.operatorAnalysis, 'analyzedDates')
    msgbox('No time series data available. Operator analysis with schedules is required.', 'Error', 'error');
    return;
end

caseStats = analysisResults.operatorAnalysis.caseStats;
idleTimeStats = analysisResults.operatorAnalysis.idleTimeStats;
analyzedDates = analysisResults.operatorAnalysis.analyzedDates;

if isempty(analyzedDates)
    msgbox('No analyzed dates found in the data.', 'Error', 'error');
    return;
end

dateObjects = convertDateStringsToDatetime(analyzedDates);
if isempty(dateObjects)
    msgbox('Unable to parse dates for time series plot.', 'Error', 'error');
    return;
end

[dateObjects, analyzedDates, selectedDateIndices] = filterRetrospectiveDates(dateObjects, analyzedDates, retrospectiveMonths);
if isempty(dateObjects)
    msgbox('No dates remain after applying the retrospective month filter.', 'No Data', 'warn');
    return;
end

operatorNames = keys(caseStats);
numOperators = length(operatorNames);
numDates = length(selectedDateIndices);

if numOperators == 0 || numDates == 0
    msgbox('No operator data available for time series plot.', 'Error', 'error');
    return;
end

flipRatioMatrix = NaN(numOperators, numDates);
operatorLabels = cell(numOperators, 1);
for opIdx = 1:numOperators
    opName = operatorNames{opIdx};
    operatorLabels{opIdx} = opName;

    caseArray = caseStats(opName);
    if isfield(analysisResults, 'labFlipAnalysis') && ...
       isfield(analysisResults.labFlipAnalysis, 'operatorFlipStats') && ...
       isKey(analysisResults.labFlipAnalysis.operatorFlipStats, opName)
        flipArray = analysisResults.labFlipAnalysis.operatorFlipStats(opName);
        for dateIdx = 1:numDates
            sourceDateIdx = selectedDateIndices(dateIdx);
            casesThisDay = caseArray(sourceDateIdx);
            flipsThisDay = flipArray(sourceDateIdx);
            if ~isnan(casesThisDay) && casesThisDay > 1 && ~isnan(flipsThisDay)
                turnovers = casesThisDay - 1;
                if turnovers > 0
                    flipRatioMatrix(opIdx, dateIdx) = (flipsThisDay / turnovers) * 100;
                end
            end
        end
    end
end

avgOperatorFlipRatio = nanmean(flipRatioMatrix, 1);
[deptFlipPerOperatorTurnover, deptDateObjects] = buildDepartmentFlipSeries(analysisResults, analyzedDates);
[dailyMedianIdlePerTurnover, dailyOperatorIdlePerTurnoverMatrix, operatorNamesForIdle] = buildOperatorIdleSeries(analysisResults, selectedDateIndices);

if showIndividualOperatorTraces
    createIndividualOperatorTracesFigure(dateObjects, flipRatioMatrix, operatorLabels);
end

createFlipRatioSummaryFigure(dateObjects, avgOperatorFlipRatio, deptFlipPerOperatorTurnover);
createOperatorIdleTimeTrendFigure(deptDateObjects, dailyMedianIdlePerTurnover, dailyOperatorIdlePerTurnoverMatrix, operatorNamesForIdle, showIndividualOperatorTraces);

validAvgData = ~isnan(avgOperatorFlipRatio);
validOperatorCount = sum(any(~isnan(flipRatioMatrix), 2));
if validOperatorCount > 0
    fprintf('Operator time series plot created with %d operators across %d dates\n', validOperatorCount, sum(validAvgData));
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
end

function [filteredDateObjects, filteredDateStrings, selectedDateIndices] = filterRetrospectiveDates(dateObjects, dateStrings, retrospectiveMonths)
selectedDateIndices = 1:length(dateObjects);

if ~isempty(retrospectiveMonths)
    latestDate = max(dateObjects);
    startDate = latestDate - calmonths(retrospectiveMonths);
    selectedDateIndices = find(dateObjects >= startDate & dateObjects <= latestDate);
end

filteredDateObjects = dateObjects(selectedDateIndices);
filteredDateStrings = dateStrings(selectedDateIndices);
end

function dateObjects = convertDateStringsToDatetime(dateStrings)
dateObjects = NaT(length(dateStrings), 1);
for i = 1:length(dateStrings)
    dateStr = dateStrings{i};
    try
        dateObjects(i) = datetime(dateStr, 'InputFormat', 'dd-MMM-yyyy');
    catch
        try
            dateObjects(i) = datetime(dateStr);
        catch
            dateObjects = [];
            return;
        end
    end
end
end

function [deptFlipPerOperatorTurnover, dateObjects] = buildDepartmentFlipSeries(analysisResults, analyzedDates)
dateObjects = convertDateStringsToDatetime(analyzedDates);
deptFlipPerOperatorTurnover = NaN(length(analyzedDates), 1);

if isempty(dateObjects)
    return;
end

if ~isfield(analysisResults, 'scheduleAnalysis') || ...
   ~isfield(analysisResults.scheduleAnalysis, 'dailyEfficiency') || ...
   ~isfield(analysisResults.scheduleAnalysis.dailyEfficiency, 'byDate') || ...
   isempty(analysisResults.scheduleAnalysis.dailyEfficiency.byDate)
    warning('Department daily efficiency metrics not available for department flip-ratio plot.');
    return;
end

dailyEff = analysisResults.scheduleAnalysis.dailyEfficiency.byDate;
for i = 1:length(analyzedDates)
    dateStr = analyzedDates{i};
    if isKey(dailyEff, dateStr)
        d = dailyEff(dateStr);
        if isfield(d, 'overallDeptLabFlipPerOperatorTurnoverDaily')
            deptFlipPerOperatorTurnover(i) = d.overallDeptLabFlipPerOperatorTurnoverDaily * 100;
        elseif isfield(d, 'overallDeptFlipToTurnoverRatioDaily')
            deptFlipPerOperatorTurnover(i) = d.overallDeptFlipToTurnoverRatioDaily * 100;
        end
    end
end
end

function [dailyMedianIdlePerTurnover, dailyOperatorIdlePerTurnoverMatrix, operatorNames] = buildOperatorIdleSeries(analysisResults, selectedDateIndices)
numDates = length(selectedDateIndices);
dailyMedianIdlePerTurnover = NaN(numDates, 1);
dailyOperatorIdlePerTurnoverMatrix = [];
operatorNames = {};

if ~isfield(analysisResults, 'operatorAnalysis') || ...
   ~isfield(analysisResults.operatorAnalysis, 'caseStats') || ...
   ~isfield(analysisResults.operatorAnalysis, 'idleTimeStats')
    warning('Operator daily idle statistics not available for idle-time trend plot.');
    return;
end

caseStats = analysisResults.operatorAnalysis.caseStats;
idleTimeStats = analysisResults.operatorAnalysis.idleTimeStats;
operatorNames = keys(caseStats);
numOperators = length(operatorNames);
dailyOperatorIdlePerTurnoverMatrix = NaN(numOperators, numDates);

for dateIdx = 1:numDates
    sourceDateIdx = selectedDateIndices(dateIdx);
    dailyIdlePerTurnover = [];
    for opIdx = 1:length(operatorNames)
        opName = operatorNames{opIdx};
        caseArray = caseStats(opName);
        idleArray = idleTimeStats(opName);
        if sourceDateIdx <= length(caseArray) && sourceDateIdx <= length(idleArray)
            casesThisDay = caseArray(sourceDateIdx);
            idleThisDay = idleArray(sourceDateIdx);
            if ~isnan(casesThisDay) && casesThisDay > 1 && ~isnan(idleThisDay)
                turnovers = casesThisDay - 1;
                if turnovers > 0
                    operatorIdlePerTurnover = idleThisDay / turnovers;
                    dailyOperatorIdlePerTurnoverMatrix(opIdx, dateIdx) = operatorIdlePerTurnover;
                    dailyIdlePerTurnover(end+1) = operatorIdlePerTurnover; %#ok<AGROW>
                end
            end
        end
    end

    if ~isempty(dailyIdlePerTurnover)
        dailyMedianIdlePerTurnover(dateIdx) = median(dailyIdlePerTurnover, 'omitnan');
    end
end
end

function createIndividualOperatorTracesFigure(dateObjects, flipRatioMatrix, operatorLabels)
avgLineColor = [0.00 0.45 0.74];
trendLineColor = [0.85 0.33 0.10];
traceColor = [0.70 0.70 0.70];

fig = figure('Position', [350, 350, 1500, 700], 'Color', 'w', 'InvertHardcopy', 'off');
ax = axes('Parent', fig);
applyReadableTimeSeriesAxesStyle(ax);
hold(ax, 'on');

numOperators = size(flipRatioMatrix, 1);
for opIdx = 1:numOperators
    validData = ~isnan(flipRatioMatrix(opIdx, :));
    if any(validData)
        plot(ax, dateObjects(validData), flipRatioMatrix(opIdx, validData), 'o', ...
            'Color', traceColor, 'MarkerSize', 3, 'HandleVisibility', 'off');
    end
end

avgOperatorFlipRatio = nanmean(flipRatioMatrix, 1);
validAvgData = ~isnan(avgOperatorFlipRatio);
if any(validAvgData)
    plot(ax, dateObjects, avgOperatorFlipRatio, 'o-', ...
        'Color', avgLineColor, 'LineWidth', 2.5, 'MarkerSize', 5, ...
        'MarkerFaceColor', avgLineColor, 'DisplayName', 'Average Operator Flip Ratio');
    if sum(validAvgData) > 2
        validDates = dateObjects(validAvgData);
        validValues = avgOperatorFlipRatio(validAvgData);
        dateNums = datenum(validDates);
        p = polyfit(dateNums, validValues, 1);
        trendLine = polyval(p, dateNums);
        plot(ax, validDates, trendLine, '-', 'Color', trendLineColor, ...
            'LineWidth', 2.2, 'DisplayName', 'Linear Trend');
    end
end

title(ax, 'Individual Operator Lab Flips per Operator Turnover Over Time');
xlabel(ax, 'Date');
ylabel(ax, 'Lab Flips per Operator Turnover (%)');
ylim(ax, [0 100]);
xlim(ax, [min(dateObjects) max(dateObjects)]);
set(get(ax, 'Title'), 'Color', [0.10 0.10 0.10]);
set(get(ax, 'XLabel'), 'Color', [0.10 0.10 0.10]);
set(get(ax, 'YLabel'), 'Color', [0.10 0.10 0.10]);
leg = legend(ax, 'Location', 'northwest', 'FontSize', 9, 'Box', 'off');
set(leg, 'TextColor', [0.10 0.10 0.10], 'Color', 'w');
text(ax, 0.995, 0.03, 'Gray markers = individual operator-days', ...
    'Units', 'normalized', 'HorizontalAlignment', 'right', ...
    'VerticalAlignment', 'bottom', 'FontSize', 9, 'Color', [0.35 0.35 0.35]);
hold(ax, 'off');
end

function createFlipRatioSummaryFigure(dateObjects, avgOperatorFlipRatio, deptFlipPerOperatorTurnover)
avgLineColor = [0.00 0.45 0.74];
deptLineColor = [0.10 0.55 0.35];
trendLineColor = [0.85 0.33 0.10];

fig = figure('Position', [400, 400, 1400, 850], 'Color', 'w', 'InvertHardcopy', 'off');

ax1 = subplot(2, 1, 1, 'Parent', fig);
applyReadableTimeSeriesAxesStyle(ax1);
hold(ax1, 'on');
validAvgData = ~isnan(avgOperatorFlipRatio);
if any(validAvgData)
    plot(ax1, dateObjects, avgOperatorFlipRatio, 'o-', ...
         'Color', avgLineColor, 'LineWidth', 0.5, 'MarkerSize', 2.5, ...
         'MarkerFaceColor', avgLineColor, 'DisplayName', 'Average Operator Flip Ratio');
    if sum(validAvgData) > 2
        validDates = dateObjects(validAvgData);
        validValues = avgOperatorFlipRatio(validAvgData);
        dateNums = datenum(validDates);
        p = polyfit(dateNums, validValues, 1);
        trendLine = polyval(p, dateNums);
        plot(ax1, validDates, trendLine, '-', 'Color', trendLineColor, ...
            'LineWidth', 2.5, 'DisplayName', 'Linear Trend');
    end
end
title(ax1, 'Average Operator Lab Flips per Operator Turnover Over Time');
xlabel(ax1, 'Date');
ylabel(ax1, 'Lab Flips per Operator Turnover (%)');
ylim(ax1, [0 100]);
xlim(ax1, [min(dateObjects) max(dateObjects)]);
set(get(ax1, 'Title'), 'Color', [0.10 0.10 0.10]);
set(get(ax1, 'XLabel'), 'Color', [0.10 0.10 0.10]);
set(get(ax1, 'YLabel'), 'Color', [0.10 0.10 0.10]);
leg1 = legend(ax1, 'Location', 'northwest', 'FontSize', 9, 'Box', 'off');
set(leg1, 'TextColor', [0.10 0.10 0.10], 'Color', 'w');
grid off;
hold(ax1, 'off');

ax2 = subplot(2, 1, 2, 'Parent', fig);
applyReadableTimeSeriesAxesStyle(ax2);
hold(ax2, 'on');
validDeptData = ~isnan(deptFlipPerOperatorTurnover);
if any(validDeptData)
    plot(ax2, dateObjects, deptFlipPerOperatorTurnover, 'o-', ...
         'Color', deptLineColor, 'LineWidth', 0.5, 'MarkerSize', 2, ...
         'MarkerFaceColor', deptLineColor, 'DisplayName', 'Department Daily Ratio');
    if sum(validDeptData) > 2
        validDates = dateObjects(validDeptData);
        validValues = deptFlipPerOperatorTurnover(validDeptData);
        dateNums = datenum(validDates);
        p = polyfit(dateNums, validValues, 1);
        trendLine = polyval(p, dateNums);
        plot(ax2, validDates, trendLine, '-', 'Color', trendLineColor, ...
            'LineWidth', 2.5, 'DisplayName', 'Linear Trend');
    end
end
title(ax2, 'Department Lab Flips per Operator Turnover Over Time');
xlabel(ax2, 'Date');
ylabel(ax2, 'Lab Flips per Operator Turnover (%)');
ylim(ax2, [0 100]);
xlim(ax2, [min(dateObjects) max(dateObjects)]);
set(get(ax2, 'Title'), 'Color', [0.10 0.10 0.10]);
set(get(ax2, 'XLabel'), 'Color', [0.10 0.10 0.10]);
set(get(ax2, 'YLabel'), 'Color', [0.10 0.10 0.10]);
leg2 = legend(ax2, 'Location', 'northwest', 'FontSize', 9, 'Box', 'off');
set(leg2, 'TextColor', [0.10 0.10 0.10], 'Color', 'w');
grid off;
hold(ax2, 'off');
end

function createOperatorIdleTimeTrendFigure(dateObjects, dailyMedianIdlePerTurnover, dailyOperatorIdlePerTurnoverMatrix, operatorLabels, showIndividualOperatorTraces)
medianColor = [0.00 0.45 0.74];
trendLineColor = [0.85 0.33 0.10];
operatorTraceColors = lines(max(1, size(dailyOperatorIdlePerTurnoverMatrix, 1)));

fig = figure('Position', [450, 450, 1400, 650], 'Color', 'w', 'InvertHardcopy', 'off');
ax = axes('Parent', fig);
applyReadableTimeSeriesAxesStyle(ax);
hold(ax, 'on');

legendHandles = gobjects(0);
legendLabels = {};

if nargin >= 5 && showIndividualOperatorTraces && ~isempty(dailyOperatorIdlePerTurnoverMatrix)
    numOperators = size(dailyOperatorIdlePerTurnoverMatrix, 1);
    for opIdx = 1:numOperators
        validData = ~isnan(dailyOperatorIdlePerTurnoverMatrix(opIdx, :));
        if any(validData)
            plotHandle = plot(ax, dateObjects(validData), dailyOperatorIdlePerTurnoverMatrix(opIdx, validData), 'o', ...
                'Color', operatorTraceColors(opIdx, :), 'MarkerSize', 2.5, ...
                'DisplayName', operatorLabels{opIdx});
            legendHandles(end+1) = plotHandle; %#ok<AGROW>
            legendLabels{end+1} = operatorLabels{opIdx}; %#ok<AGROW>
        end
    end
end

validMedian = ~isnan(dailyMedianIdlePerTurnover);
if any(validMedian)
    medianHandle = plot(ax, dateObjects, dailyMedianIdlePerTurnover, 'o-', ...
        'Color', medianColor, 'LineWidth', 0.5, 'MarkerSize', 2.5, ...
        'MarkerFaceColor', medianColor, 'DisplayName', 'Median Operator Idle/Turnover');
    legendHandles(end+1) = medianHandle; %#ok<AGROW>
    legendLabels{end+1} = 'Median Operator Idle/Turnover'; %#ok<AGROW>
    if sum(validMedian) > 2
        validDates = dateObjects(validMedian);
        validValues = dailyMedianIdlePerTurnover(validMedian);
        dateNums = datenum(validDates);
        p = polyfit(dateNums, validValues, 1);
        trendLine = polyval(p, dateNums);
        trendHandle = plot(ax, validDates, trendLine, '-', 'Color', trendLineColor, ...
            'LineWidth', 2.2, 'DisplayName', 'Linear Trend');
        legendHandles(end+1) = trendHandle; %#ok<AGROW>
        legendLabels{end+1} = 'Linear Trend'; %#ok<AGROW>
    end
end

title(ax, 'Operator Idle Time per Turnover Over Time');
xlabel(ax, 'Date');
ylabel(ax, 'Idle Time per Turnover (minutes)');
xlim(ax, [min(dateObjects) max(dateObjects)]);
set(get(ax, 'Title'), 'Color', [0.10 0.10 0.10]);
set(get(ax, 'XLabel'), 'Color', [0.10 0.10 0.10]);
set(get(ax, 'YLabel'), 'Color', [0.10 0.10 0.10]);
if nargin >= 5 && showIndividualOperatorTraces
    if ~isempty(legendHandles)
        leg = legend(ax, legendHandles, legendLabels, 'Location', 'eastoutside', 'FontSize', 8, 'Box', 'off');
    else
        leg = legend(ax, 'Location', 'northwest', 'FontSize', 9, 'Box', 'off');
    end
else
    leg = legend(ax, 'Location', 'northwest', 'FontSize', 9, 'Box', 'off');
end
set(leg, 'TextColor', [0.10 0.10 0.10], 'Color', 'w');
if nargin >= 5 && showIndividualOperatorTraces
    text(ax, 0.995, 0.03, 'Colored markers = individual operator-days; median = typical operator-day; line = linear trend', ...
        'Units', 'normalized', 'HorizontalAlignment', 'right', ...
        'VerticalAlignment', 'bottom', 'FontSize', 9, 'Color', [0.35 0.35 0.35]);
else
    text(ax, 0.995, 0.03, 'Median = typical operator-day; line = linear trend', ...
        'Units', 'normalized', 'HorizontalAlignment', 'right', ...
        'VerticalAlignment', 'bottom', 'FontSize', 9, 'Color', [0.35 0.35 0.35]);
end
grid off;
hold(ax, 'off');
end

function applyReadableTimeSeriesAxesStyle(ax)
% Apply a consistent high-contrast style for dense time-series plots.
if isgraphics(ax.Parent, 'figure')
    set(ax.Parent, 'Color', 'w', 'InvertHardcopy', 'off');
end
set(ax, 'Box', 'off', ...
    'Color', 'w', ...
    'FontSize', 11, ...
    'LineWidth', 1.0, ...
    'XColor', [0.20 0.20 0.20], ...
    'YColor', [0.20 0.20 0.20], ...
    'GridColor', [0.85 0.85 0.85], ...
    'GridAlpha', 1.0, ...
    'MinorGridColor', [0.93 0.93 0.93], ...
    'MinorGridAlpha', 1.0);
grid(ax, 'on');
grid(ax, 'minor');
ax.Layer = 'top';
try
    xtickformat(ax, 'MMM yyyy');
catch
end
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
