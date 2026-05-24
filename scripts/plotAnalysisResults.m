function plotAnalysisResults(analysisResults, varargin)
% Create retrospective visualizations for operator and department efficiency metrics.
% Uses explicit denominator labels so operator-turnover and lab-turnover
% metrics are not conflated in plots.
% Version: 2.2.0
%
% Available Plots and Metrics
% - Default manuscript-ready suite (rendered when no specific Create* flag is set):
%   - Department flip ratio and pooled idle-time time series
%   - Combined department and operator flip-ratio vs idle-time associations
%
% - Operator bar charts (enable with 'CreateOperatorSummaryFigure', true):
%   - Lab flips per operator turnover by operator (% of same-operator turnovers)
%   - Median idle time per turnover by operator (minutes per turnover)
%
% - Correlation plot (enable with 'CreateCorrelationPlot', true):
%   - User selects a procedure and a procedure-time metric to correlate against
%     lab flips per operator turnover
%   - Selectable procedure-time metrics per operator for the chosen procedure:
%       'mean', 'median', 'std', 'min', 'max', 'p25', 'p75', 'p90'
%
% - Idle/flip correlation plot (enable with 'CreateIdleFlipCorrelationPlot', true):
%   - Operator lab flips per operator turnover (%) vs median idle time per turnover
%   - Data points are labeled with operator initials
%
% - Time series plot (enable with 'CreateTimeSeriesPlot', true):
%   - Figure 1: pooled included-operator and department flip ratios over time
%   - Figure 2: median operator idle time per turnover over time
%   - Optional operator-trace figure when 'ShowIndividualOperatorTraces' is true
%   - Reads precomputed day/week/month/quarter/year series from analysisResults
%
% - Operator turnover plot (enable with 'CreateOperatorTurnoverPlot', true):
%   - Department total same-operator consecutive-case opportunities over time
%   - Reads precomputed day/week/month/quarter/year series selected by 'TimeBin'
%
% - Operator idle-time by flip-status plot (enable with 'CreateOperatorIdleByFlipStatusPlot', true):
%   - Two-panel binned comparison of idle minutes with vs without a lab flip
%   - Displays median values by default; set 'FlipIdleStatistic' to 'mean'
%   - Lower panel shows descriptive minutes saved per flip (not causal recovery)
%
% - Bottleneck decomposition plot (enable with 'CreateBottleneckDecompositionPlot', true):
%   - By default, one whole-period 100% stacked bar for setup, procedure,
%     post-procedure, and observed same-lab room-gap time
%   - When 'TimeBin' is supplied, an absolute-minute stacked area plot by
%     day, week, month, quarter, or year with component percentage labels;
%     set 'BottleneckScale' to 'percent' for a 100% stacked binned view or
%     'per_case' for component minutes per procedure in each bin
%
% - Manuscript figures:
%   - 'CreateManuscriptTimeSeriesFigure': publication-styled department flip
%     ratio and pooled department idle time by stored time bin
%   - 'CreateManuscriptAssociationFigure': publication-styled combined
%     department and operator association figure
%   - 'CreateManuscriptOperatorAssociationFigure': backwards-compatible alias
%     for the combined manuscript association figure
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
%   'CreateIdleFlipCorrelationPlot' - logical, create operator flip/idle
%                                     correlation plot (default: false)
%   'CreateTimeSeriesPlot'  - logical, create time series plot (default: false)
%   'CreateOperatorTurnoverPlot' - logical, plot total operator turnover
%                                  opportunities by time bin (default: false)
%   'CreateOperatorIdleByFlipStatusPlot' - logical, plot binned operator idle
%                                  time with vs without a lab flip and the
%                                  descriptive difference (default: false)
%   'FlipIdleStatistic'     - statistic shown in the flip-status plot:
%                             'median' (default) or 'mean'
%   'CreateBottleneckDecompositionPlot' - logical, create the department
%                                    bottleneck duration composition plot
%                                    (default: false)
%   'BottleneckScale'       - bottleneck display scale: 'minutes' (default),
%                             'percent', or 'per_case' (minutes per
%                             procedure); 'minutes' and 'percent' retain
%                             the default whole-period percentage bar
%   'ShowIndividualOperatorTraces' - logical, show the optional individual
%                                    operator trace figure when plotting
%                                    time series data (default: false)
%   'TimeBin'               - displayed time-series granularity: 'day',
%                             'week', 'month', 'quarter', or 'year'
%                             (default: 'day' generally; 'quarter' for
%                             manuscript figures when omitted)
%   'CreateManuscriptTimeSeriesFigure' - logical, create publication-styled
%                                        departmental time-series figure
%   'CreateManuscriptAssociationFigure' - logical, create the publication-styled
%                                         combined association figure
%   'CreateManuscriptOperatorAssociationFigure' - logical, backwards-compatible
%                                         alias for the combined association figure
%   'ShowOperatorInitialLabels' - logical, annotate manuscript operator
%                                 points with initials (default: false)
%   'CreateOperatorSummaryFigure' - logical, create the exploratory operator
%                                   two-panel bar-chart summary
%   'ExportPath'            - manuscript export filename prefix (default: '')
%   'ExportFormat'          - 'pdf' vector output or 'tiff' raster output
%                             for manuscript figures (default: 'pdf')
%   'ExportResolution'      - TIFF export DPI (default: 600)
%   'CreateBoxPlots'        - logical, create box and whisker plots (default: false)
%   'CreateDailyDeptScatter' - logical, plot daily dept idle/turnover vs flip/turnover and avg concurrent labs (default: false)
%   'SelectedProcedure'     - string, procedure for correlation (default: auto-select)
%   'SelectedMetric'        - string, metric for correlation (default: auto-select)
%
% If any Create* plot flag is true, only requested plot type(s) are rendered.
% With no Create* flags, the two manuscript-ready figures are rendered.
%
% Examples:
%   plotAnalysisResults(analysisResults)  % Default two-figure manuscript suite
%   plotAnalysisResults(analysisResults, 'CreateCorrelationPlot', true)
%   plotAnalysisResults(analysisResults, 'CreateIdleFlipCorrelationPlot', true)
%   plotAnalysisResults(analysisResults, 'CreateCorrelationPlot', true, 'CreateTimeSeriesPlot', true)
%   plotAnalysisResults(analysisResults, 'CreateTimeSeriesPlot', true, 'ShowIndividualOperatorTraces', true)
%   plotAnalysisResults(analysisResults, 'CreateTimeSeriesPlot', true, 'TimeBin', 'month')
%   plotAnalysisResults(analysisResults, 'CreateOperatorTurnoverPlot', true, 'TimeBin', 'month')
%   plotAnalysisResults(analysisResults, 'CreateOperatorIdleByFlipStatusPlot', true, 'TimeBin', 'month')
%   plotAnalysisResults(analysisResults, 'CreateOperatorIdleByFlipStatusPlot', true, 'TimeBin', 'quarter', 'FlipIdleStatistic', 'mean')
%   plotAnalysisResults(analysisResults, 'CreateBottleneckDecompositionPlot', true)
%   plotAnalysisResults(analysisResults, 'CreateBottleneckDecompositionPlot', true, 'TimeBin', 'quarter')
%   plotAnalysisResults(analysisResults, 'CreateBottleneckDecompositionPlot', true, 'TimeBin', 'quarter', 'BottleneckScale', 'percent')
%   plotAnalysisResults(analysisResults, 'CreateBottleneckDecompositionPlot', true, 'TimeBin', 'quarter', 'BottleneckScale', 'per_case')
%   plotAnalysisResults(analysisResults, 'CreateManuscriptTimeSeriesFigure', true)
%   plotAnalysisResults(analysisResults, 'CreateManuscriptAssociationFigure', true, 'TimeBin', 'quarter')
%   plotAnalysisResults(analysisResults, 'CreateManuscriptAssociationFigure', true, 'ShowOperatorInitialLabels', true)
%   plotAnalysisResults(analysisResults, 'CreateOperatorSummaryFigure', true)
%   plotAnalysisResults(analysisResults, 'CreateBoxPlots', true)

% Parse optional parameters
p = inputParser();
addParameter(p, 'CreateCorrelationPlot', false, @islogical);
addParameter(p, 'CreateIdleFlipCorrelationPlot', false, @islogical);
addParameter(p, 'CreateTimeSeriesPlot', false, @islogical);
addParameter(p, 'CreateOperatorTurnoverPlot', false, @islogical);
addParameter(p, 'CreateOperatorIdleByFlipStatusPlot', false, @islogical);
addParameter(p, 'FlipIdleStatistic', 'median', @isValidFlipIdleStatisticInput);
addParameter(p, 'CreateBottleneckDecompositionPlot', false, @islogical);
addParameter(p, 'BottleneckScale', 'minutes', @isValidBottleneckScaleInput);
addParameter(p, 'ShowIndividualOperatorTraces', false, @islogical);
addParameter(p, 'TimeBin', 'day', @isValidTimeBinInput);
addParameter(p, 'CreateManuscriptTimeSeriesFigure', false, @islogical);
addParameter(p, 'CreateManuscriptAssociationFigure', false, @islogical);
addParameter(p, 'CreateManuscriptOperatorAssociationFigure', false, @islogical);
addParameter(p, 'ShowOperatorInitialLabels', false, @islogical);
addParameter(p, 'CreateOperatorSummaryFigure', false, @islogical);
addParameter(p, 'ExportPath', '', @(x) ischar(x) || (isstring(x) && isscalar(x)));
addParameter(p, 'ExportFormat', 'pdf', @isValidExportFormatInput);
addParameter(p, 'ExportResolution', 600, @(x) isnumeric(x) && isscalar(x) && isfinite(x) && x > 0);
addParameter(p, 'CreateBoxPlots', false, @islogical);
addParameter(p, 'CreateDailyDeptScatter', false, @islogical);
addParameter(p, 'SelectedProcedure', '', @ischar);
addParameter(p, 'SelectedMetric', '', @ischar);
parse(p, varargin{:});

doCreateCorrelationPlot = p.Results.CreateCorrelationPlot;
doCreateIdleFlipCorrelationPlot = p.Results.CreateIdleFlipCorrelationPlot;
doCreateTimeSeriesPlot = p.Results.CreateTimeSeriesPlot;
doCreateOperatorTurnoverPlot = p.Results.CreateOperatorTurnoverPlot;
doCreateOperatorIdleByFlipStatusPlot = p.Results.CreateOperatorIdleByFlipStatusPlot;
flipIdleStatistic = lower(char(string(p.Results.FlipIdleStatistic)));
doCreateBottleneckDecompositionPlot = p.Results.CreateBottleneckDecompositionPlot;
bottleneckScale = lower(char(string(p.Results.BottleneckScale)));
doShowIndividualOperatorTraces = p.Results.ShowIndividualOperatorTraces;
timeBin = lower(char(string(p.Results.TimeBin)));
timeBinWasSpecified = ~any(strcmp(p.UsingDefaults, 'TimeBin'));
doCreateManuscriptTimeSeriesFigure = p.Results.CreateManuscriptTimeSeriesFigure;
doCreateManuscriptAssociationFigure = p.Results.CreateManuscriptAssociationFigure;
doCreateManuscriptOperatorAssociationFigure = p.Results.CreateManuscriptOperatorAssociationFigure;
doShowOperatorInitialLabels = p.Results.ShowOperatorInitialLabels;
doCreateOperatorSummaryFigure = p.Results.CreateOperatorSummaryFigure;
exportPath = char(string(p.Results.ExportPath));
exportFormat = lower(char(string(p.Results.ExportFormat)));
exportResolution = p.Results.ExportResolution;
doCreateBoxPlots = p.Results.CreateBoxPlots;
doCreateDailyDeptScatter = p.Results.CreateDailyDeptScatter;
selectedProcedure = p.Results.SelectedProcedure;
selectedMetric = p.Results.SelectedMetric;
specificPlotRequested = doCreateCorrelationPlot || doCreateIdleFlipCorrelationPlot || ...
    doCreateTimeSeriesPlot || doCreateOperatorTurnoverPlot || doCreateOperatorIdleByFlipStatusPlot || ...
    doCreateBottleneckDecompositionPlot || ...
    doCreateManuscriptTimeSeriesFigure || ...
    doCreateManuscriptAssociationFigure || doCreateManuscriptOperatorAssociationFigure || ...
    doCreateOperatorSummaryFigure || doCreateBoxPlots || doCreateDailyDeptScatter;

defaultManuscriptSuite = ~specificPlotRequested;
if defaultManuscriptSuite
    doCreateManuscriptTimeSeriesFigure = true;
    doCreateManuscriptAssociationFigure = true;
end

if (defaultManuscriptSuite || doCreateManuscriptTimeSeriesFigure || ...
        doCreateManuscriptAssociationFigure || doCreateManuscriptOperatorAssociationFigure) && ...
        any(strcmp(p.UsingDefaults, 'TimeBin'))
    timeBin = 'quarter';
end

if doCreateManuscriptTimeSeriesFigure || doCreateManuscriptAssociationFigure || doCreateManuscriptOperatorAssociationFigure
    if doCreateManuscriptTimeSeriesFigure
        timeSeries = getStoredTimeSeries(analysisResults, timeBin);
        manuscriptTimeSeriesFigure = createManuscriptTimeSeriesFigure(timeSeries, timeBin);
        exportManuscriptFigure(manuscriptTimeSeriesFigure, exportPath, ...
            'time_series', exportFormat, exportResolution);
    end
    if doCreateManuscriptAssociationFigure || doCreateManuscriptOperatorAssociationFigure
        timeSeries = getStoredTimeSeries(analysisResults, timeBin);
        operatorAssociation = getManuscriptOperatorAssociation(analysisResults);
        manuscriptAssociationFigure = createManuscriptAssociationFigure( ...
            timeSeries, operatorAssociation, doShowOperatorInitialLabels, timeBin);
        exportManuscriptFigure(manuscriptAssociationFigure, exportPath, ...
            'association', exportFormat, exportResolution);
    end
    exploratoryRequested = doCreateCorrelationPlot || doCreateIdleFlipCorrelationPlot || ...
        doCreateTimeSeriesPlot || doCreateOperatorTurnoverPlot || doCreateOperatorIdleByFlipStatusPlot || ...
        doCreateBottleneckDecompositionPlot || ...
        doCreateOperatorSummaryFigure || doCreateBoxPlots || doCreateDailyDeptScatter;
    if defaultManuscriptSuite || ~exploratoryRequested
        return;
    end
end

if doCreateBottleneckDecompositionPlot
    createBottleneckDecompositionPlot(analysisResults, timeBin, timeBinWasSpecified, bottleneckScale);
    remainingPlotRequested = doCreateCorrelationPlot || doCreateIdleFlipCorrelationPlot || ...
        doCreateTimeSeriesPlot || doCreateOperatorTurnoverPlot || doCreateOperatorIdleByFlipStatusPlot || ...
        doCreateOperatorSummaryFigure || ...
        doCreateBoxPlots || doCreateDailyDeptScatter;
    if ~remainingPlotRequested
        return;
    end
end

if doCreateOperatorTurnoverPlot
    createOperatorTurnoverPlot(analysisResults, timeBin);
    remainingPlotRequested = doCreateCorrelationPlot || doCreateIdleFlipCorrelationPlot || ...
        doCreateTimeSeriesPlot || doCreateOperatorIdleByFlipStatusPlot || doCreateOperatorSummaryFigure || ...
        doCreateBoxPlots || doCreateDailyDeptScatter;
    if ~remainingPlotRequested
        return;
    end
end

if doCreateOperatorIdleByFlipStatusPlot
    createOperatorIdleByFlipStatusPlot(analysisResults, timeBin, flipIdleStatistic);
    remainingPlotRequested = doCreateCorrelationPlot || doCreateIdleFlipCorrelationPlot || ...
        doCreateTimeSeriesPlot || doCreateOperatorSummaryFigure || ...
        doCreateBoxPlots || doCreateDailyDeptScatter;
    if ~remainingPlotRequested
        return;
    end
end

if doCreateTimeSeriesPlot
    createTimeSeriesPlot(analysisResults, doShowIndividualOperatorTraces, timeBin);
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

if doCreateOperatorSummaryFigure
    createOperatorSummaryBarFigure(validOperators, flipsPerTurnoverRatio, medianIdleTimeToTurnoverRatio);
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

if doCreateIdleFlipCorrelationPlot
    createIdleFlipCorrelationPlot(flipsPerTurnoverRatio, medianIdleTimeToTurnoverRatio, validOperators);
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

function createIdleFlipCorrelationPlot(flipsPerTurnoverRatio, medianIdleTimeToTurnoverRatio, validOperators)
validData = isfinite(flipsPerTurnoverRatio) & isfinite(medianIdleTimeToTurnoverRatio);
flipValues = flipsPerTurnoverRatio(validData);
idleValues = medianIdleTimeToTurnoverRatio(validData);
operatorLabels = validOperators(validData);

if isempty(flipValues)
    msgbox('No valid operator flip/idle data available for correlation plot.', 'No Data', 'warn');
    return;
end

fig = figure('Position', [300, 300, 1200, 850], 'Color', 'w', 'InvertHardcopy', 'off');
ax = axes('Parent', fig);
hold(ax, 'on');

scatter(ax, flipValues, idleValues, 90, [0.00 0.45 0.74], 'filled', ...
    'MarkerFaceAlpha', 0.75, 'MarkerEdgeColor', [0.10 0.10 0.10]);

initialLabels = createOperatorInitialLabels(operatorLabels);
xOffset = max(1, range(flipValues) * 0.015);
yOffset = max(1, range(idleValues) * 0.015);
for i = 1:length(operatorLabels)
    text(ax, flipValues(i) + xOffset, idleValues(i) + yOffset, initialLabels{i}, ...
        'FontSize', 9, 'FontWeight', 'bold', 'Color', [0.10 0.10 0.10], ...
        'HorizontalAlignment', 'left', 'VerticalAlignment', 'bottom');
end

if length(flipValues) > 2
    correlationCoeff = corrcoef(flipValues, idleValues);
    rValue = correlationCoeff(1, 2);
    p = polyfit(flipValues, idleValues, 1);
    xTrend = linspace(min(flipValues), max(flipValues), 100);
    yTrend = polyval(p, xTrend);
    plot(ax, xTrend, yTrend, '-', 'Color', [0.85 0.33 0.10], ...
        'LineWidth', 2.2, 'DisplayName', 'Linear Trend');
    addTrendStatsAnnotation(ax, calculateLinearTrendStats(flipValues, idleValues), '');
    title(ax, sprintf('Operator Flip Ratio vs Idle Time per Turnover (r = %.3f)', rValue));
    fprintf('Correlation between lab flips per operator turnover and median idle time per turnover: r = %.3f\n', rValue);
else
    title(ax, 'Operator Flip Ratio vs Idle Time per Turnover');
    fprintf('Not enough operators for flip/idle correlation analysis (%d points)\n', length(flipValues));
end

xlabel(ax, 'Lab Flips per Operator Turnover (%)');
ylabel(ax, 'Median Idle Time per Turnover (minutes)');
set(ax, 'Color', 'w', 'Box', 'off', 'FontSize', 11, ...
    'XColor', [0.20 0.20 0.20], 'YColor', [0.20 0.20 0.20], ...
    'GridColor', [0.85 0.85 0.85], 'GridAlpha', 1.0);
set(get(ax, 'Title'), 'Color', [0.10 0.10 0.10]);
set(get(ax, 'XLabel'), 'Color', [0.10 0.10 0.10]);
set(get(ax, 'YLabel'), 'Color', [0.10 0.10 0.10]);
grid(ax, 'on');
padAxisLimits(ax, flipValues, idleValues);
hold(ax, 'off');
end

function labels = createOperatorInitialLabels(operatorNames)
labels = cell(size(operatorNames));
labelCounts = containers.Map('KeyType', 'char', 'ValueType', 'double');

for i = 1:length(operatorNames)
    baseLabel = createOperatorInitials(operatorNames{i});
    if isKey(labelCounts, baseLabel)
        labelCounts(baseLabel) = labelCounts(baseLabel) + 1;
        labels{i} = sprintf('%s%d', baseLabel, labelCounts(baseLabel));
    else
        labelCounts(baseLabel) = 1;
        labels{i} = baseLabel;
    end
end
end

function initials = createOperatorInitials(operatorName)
nameText = upper(strtrim(char(operatorName)));
if contains(nameText, ',')
    nameParts = strsplit(nameText, ',');
    orderedName = strtrim(sprintf('%s %s', nameParts{2}, nameParts{1}));
else
    orderedName = nameText;
end

tokens = regexp(orderedName, '[A-Z]+', 'match');
initials = '';
for i = 1:length(tokens)
    initials = [initials tokens{i}(1)]; %#ok<AGROW>
end

if isempty(initials)
    initials = 'OP';
end
end

function padAxisLimits(ax, xValues, yValues)
xMin = min(xValues);
xMax = max(xValues);
yMin = min(yValues);
yMax = max(yValues);
xPad = max(1, (xMax - xMin) * 0.08);
yPad = max(1, (yMax - yMin) * 0.08);

xlim(ax, [xMin - xPad, xMax + xPad]);
ylim(ax, [yMin - yPad, yMax + yPad]);
end

function trendStats = calculateLinearTrendStats(xValues, yValues)
xValues = xValues(:);
yValues = yValues(:);
validMask = isfinite(xValues) & isfinite(yValues);
xValues = xValues(validMask);
yValues = yValues(validMask);

trendStats = struct('slope', NaN, 'rSquared', NaN);
if numel(xValues) < 3
    return;
end

try
    model = fitlm(xValues, yValues);
    trendStats.slope = model.Coefficients.Estimate(2);
    trendStats.rSquared = model.Rsquared.Ordinary;
catch
    p = polyfit(xValues, yValues, 1);
    fittedValues = polyval(p, xValues);
    trendStats.slope = p(1);
    trendStats.rSquared = calculateFallbackRSquared(yValues, fittedValues);
end
end

function rSquared = calculateFallbackRSquared(observedValues, fittedValues)
observedValues = observedValues(:);
fittedValues = fittedValues(:);
totalSumSquares = sum((observedValues - mean(observedValues)).^2);
if totalSumSquares == 0
    rSquared = NaN;
else
    residualSumSquares = sum((observedValues - fittedValues).^2);
    rSquared = 1 - (residualSumSquares / totalSumSquares);
end
end

function addTrendStatsAnnotation(ax, trendStats, slopeUnit)
if nargin < 3
    slopeUnit = '';
end

if isempty(slopeUnit)
    slopeText = sprintf('Slope = %.3g', trendStats.slope);
else
    slopeText = sprintf('Slope = %.3g%s', trendStats.slope, slopeUnit);
end

if isfinite(trendStats.rSquared)
    rSquaredText = sprintf('R^2 = %.3f', trendStats.rSquared);
else
    rSquaredText = 'R^2 = NA';
end

text(ax, 0.98, 0.93, sprintf('%s\n%s', slopeText, rSquaredText), ...
    'Units', 'normalized', ...
    'HorizontalAlignment', 'right', ...
    'VerticalAlignment', 'top', ...
    'FontSize', 9, ...
    'Color', [0.10 0.10 0.10], ...
    'BackgroundColor', 'w', ...
    'EdgeColor', [0.80 0.80 0.80], ...
    'Margin', 4);
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
    addTrendStatsAnnotation(gca, calculateLinearTrendStats(correlationValues, correlationFlipRatios), '');
    
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
            addTrendStatsAnnotation(gca, calculateLinearTrendStats(newCorrelationValues, newCorrelationFlipRatios), '');
            
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

function createTimeSeriesPlot(analysisResults, showIndividualOperatorTraces, timeBin)
% Create retrospective time series figures from stored binned summaries.
if nargin < 2
    showIndividualOperatorTraces = false;
end
if nargin < 3
    timeBin = 'day';
end

timeSeries = getStoredTimeSeries(analysisResults, timeBin);
dateObjects = timeSeries.binStartDates;
operators = timeSeries.operators;
department = timeSeries.department;
trends = timeSeries.trends;
if isempty(dateObjects) || isempty(operators.operatorNames)
    warning('No stored %s time-series data available to plot.', timeBin);
    return;
end

if showIndividualOperatorTraces
    createIndividualOperatorTracesFigure(dateObjects, operators.flipRatioPercent, ...
        operators.operatorNames, operators.pooledFlipRatioPercent, ...
        trends.includedOperatorFlipRatioPercent, timeBin);
end

createFlipRatioSummaryFigure(dateObjects, operators.pooledFlipRatioPercent, ...
    department.labFlipPerOperatorTurnoverPercent, trends, timeBin);
createOperatorIdleTimeTrendFigure(dateObjects, operators.medianIdleTimePerTurnover, ...
    operators.idleTimePerTurnover, operators.operatorNames, ...
    showIndividualOperatorTraces, trends.medianOperatorIdlePerTurnover, timeBin);

validCohortData = ~isnan(operators.pooledFlipRatioPercent);
validOperatorCount = sum(any(~isnan(operators.flipRatioPercent), 2));
if validOperatorCount > 0
    fprintf('%s operator time series plot created with %d operators across %d bins\n', ...
        timeBin, validOperatorCount, sum(validCohortData));
    allValidRatios = operators.flipRatioPercent(~isnan(operators.flipRatioPercent));
    if ~isempty(allValidRatios)
        fprintf('Summary statistics across valid operator-%s flip ratios:\n', timeBin);
        fprintf('  Mean: %.1f%%\n', mean(allValidRatios));
        fprintf('  Median: %.1f%%\n', median(allValidRatios));
        fprintf('  Std Dev: %.1f%%\n', std(allValidRatios));
        fprintf('  Range: %.1f%% - %.1f%%\n', min(allValidRatios), max(allValidRatios));
    end
else
    fprintf('No valid operator time series data found for lab-flips-per-operator-turnover ratios\n');
end
end

function fig = createOperatorTurnoverPlot(analysisResults, timeBin)
% Plot same-operator consecutive-case opportunities from stored binned totals.
timeSeries = getStoredOperatorTurnoverSeries(analysisResults, timeBin);
dateObjects = timeSeries.binStartDates(:);
turnovers = timeSeries.department.totalOperatorTurnovers(:);

if isempty(dateObjects) || numel(dateObjects) ~= numel(turnovers)
    error('Stored %s turnover summaries do not contain valid matching bin dates.', timeBin);
end
if any(~isfinite(turnovers)) || any(turnovers < 0)
    error('Stored %s operator turnover totals must be finite and nonnegative.', timeBin);
end

fig = figure('Name', 'Operator Turnovers Over Time', 'NumberTitle', 'off', ...
    'Tag', 'OperatorTurnoverFigure', ...
    'Position', [420, 220, 1240, 700], 'Color', 'w', 'InvertHardcopy', 'off');
ax = axes('Parent', fig);
applyReadableTimeSeriesAxesStyle(ax);
hold(ax, 'on');

turnoverColor = [0.08 0.35 0.62];
plot(ax, dateObjects, turnovers, 'o-', 'Tag', 'OperatorTurnoverSeries', ...
    'Color', turnoverColor, 'MarkerFaceColor', turnoverColor, ...
    'LineWidth', 1.5, 'MarkerSize', 5);
title(ax, sprintf('Operator Turnover Opportunities by %s', capitalizeBinName(timeBin)));
xlabel(ax, 'Date');
ylabel(ax, 'Operator turnovers (count)');
setTimeSeriesXLimits(ax, dateObjects);
formatStoredTimeAxis(ax, timeSeries);
text(ax, 0.995, 0.02, ...
    'Operator turnover = same-operator consecutive-case opportunity', ...
    'Units', 'normalized', 'HorizontalAlignment', 'right', ...
    'VerticalAlignment', 'bottom', 'FontSize', 9, 'Color', [0.35 0.35 0.35]);
hold(ax, 'off');
end

function fig = createOperatorIdleByFlipStatusPlot(analysisResults, timeBin, statistic)
% Plot stored flip-stratified operator idle summaries and descriptive difference.
timeSeries = getStoredOperatorIdleByFlipStatusSeries(analysisResults, timeBin);
dateObjects = timeSeries.binStartDates(:);
idleByFlipStatus = timeSeries.department.operatorIdleByFlipStatus;
if strcmp(statistic, 'median')
    statisticField = 'medianIdleMinutes';
    differenceField = 'medianMinutesSavedPerFlip';
    statisticLabel = 'Median';
else
    statisticField = 'meanIdleMinutes';
    differenceField = 'meanMinutesSavedPerFlip';
    statisticLabel = 'Mean';
end

flippedIdle = idleByFlipStatus.flipped.(statisticField)(:);
notFlippedIdle = idleByFlipStatus.notFlipped.(statisticField)(:);
minutesSaved = idleByFlipStatus.(differenceField)(:);
validateOperatorIdleByFlipStatusValues(dateObjects, flippedIdle, notFlippedIdle, minutesSaved, timeBin);

fig = figure('Name', 'Operator Idle Time by Flip Status', 'NumberTitle', 'off', ...
    'Tag', 'OperatorIdleByFlipStatusFigure', ...
    'Position', [420, 140, 1240, 860], 'Color', 'w', 'InvertHardcopy', 'off');
layout = tiledlayout(fig, 2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');

comparisonAx = nexttile(layout, 1);
applyReadableTimeSeriesAxesStyle(comparisonAx);
hold(comparisonAx, 'on');
flippedColor = [0.10 0.48 0.63];
notFlippedColor = [0.77 0.31 0.20];
plot(comparisonAx, dateObjects, flippedIdle, 'o-', 'Tag', 'OperatorIdleFlippedSeries', ...
    'DisplayName', 'With lab flip', 'Color', flippedColor, ...
    'MarkerFaceColor', flippedColor, 'LineWidth', 1.5, 'MarkerSize', 5);
plot(comparisonAx, dateObjects, notFlippedIdle, 'o-', 'Tag', 'OperatorIdleNotFlippedSeries', ...
    'DisplayName', 'Without lab flip', 'Color', notFlippedColor, ...
    'MarkerFaceColor', notFlippedColor, 'LineWidth', 1.5, 'MarkerSize', 5);
title(comparisonAx, sprintf('%s Operator Idle Time by Flip Status and %s', ...
    statisticLabel, capitalizeBinName(timeBin)));
ylabel(comparisonAx, sprintf('%s idle time (minutes)', lower(statisticLabel)));
setTimeSeriesXLimits(comparisonAx, dateObjects);
formatStoredTimeAxis(comparisonAx, timeSeries);
legend(comparisonAx, 'Location', 'best', 'Box', 'off');
hold(comparisonAx, 'off');

savingsAx = nexttile(layout, 2);
applyReadableTimeSeriesAxesStyle(savingsAx);
hold(savingsAx, 'on');
savingsColor = [0.24 0.52 0.30];
yline(savingsAx, 0, ':', 'Color', [0.45 0.45 0.45], 'HandleVisibility', 'off');
plot(savingsAx, dateObjects, minutesSaved, 'o-', 'Tag', 'OperatorIdleMinutesSavedSeries', ...
    'Color', savingsColor, 'MarkerFaceColor', savingsColor, ...
    'LineWidth', 1.5, 'MarkerSize', 5);
title(savingsAx, sprintf('Descriptive %s Minutes Saved per Flip', statisticLabel));
xlabel(savingsAx, 'Date');
ylabel(savingsAx, 'Without flip - with flip (minutes)');
setTimeSeriesXLimits(savingsAx, dateObjects);
formatStoredTimeAxis(savingsAx, timeSeries);
text(savingsAx, 0.995, 0.02, ...
    'Difference is descriptive, not a causal recovered-capacity estimate; gaps = missing comparison group', ...
    'Units', 'normalized', 'HorizontalAlignment', 'right', ...
    'VerticalAlignment', 'bottom', 'FontSize', 9, 'Color', [0.35 0.35 0.35]);
hold(savingsAx, 'off');
end

function validateOperatorIdleByFlipStatusValues(dateObjects, flippedIdle, notFlippedIdle, minutesSaved, timeBin)
if isempty(dateObjects) || numel(dateObjects) ~= numel(flippedIdle) || ...
        numel(dateObjects) ~= numel(notFlippedIdle) || numel(dateObjects) ~= numel(minutesSaved)
    error('Stored %s operator idle-by-flip summaries do not contain valid matching bin values.', timeBin);
end
plotValues = [flippedIdle; notFlippedIdle; minutesSaved];
if any(isinf(plotValues)) || any(flippedIdle(isfinite(flippedIdle)) < 0) || ...
        any(notFlippedIdle(isfinite(notFlippedIdle)) < 0)
    error('Stored %s operator idle-by-flip values must be nonnegative idle minutes or missing values.', timeBin);
end
end

function fig = createBottleneckDecompositionPlot(analysisResults, timeBin, timeBinWasSpecified, bottleneckScale)
% Plot department bottleneck components using observed room-gap time.
componentLabels = {'Setup', 'Procedure', 'Post-procedure', 'Observed lab idle / room-gap'};
componentColors = [0.22 0.49 0.72; ...
    0.16 0.63 0.45; ...
    0.93 0.64 0.20; ...
    0.66 0.66 0.66];

if timeBinWasSpecified
    [componentMinutes, timeSeries] = getStoredBottleneckComponents(analysisResults, timeBin);
else
    [dailyMinutes, dailySeries] = getStoredBottleneckComponents(analysisResults, 'day');
    componentMinutes = sum(dailyMinutes, 1);
    timeSeries = struct();
end

totalMinutes = sum(componentMinutes, 2);
if ~any(totalMinutes > 0)
    error(['No nonzero bottleneck duration totals are available to plot. ' ...
        'Rerun analyzeHistoricalData with HistoricalSchedules and an included operational cohort.']);
end
if strcmp(bottleneckScale, 'per_case')
    if timeBinWasSpecified
        procedureCounts = getStoredBottleneckProcedureCounts(timeSeries, timeBin);
    else
        procedureCounts = sum(getStoredBottleneckProcedureCounts(dailySeries, 'day'));
    end
end

fig = figure('Name', 'Bottleneck Decomposition', 'NumberTitle', 'off', ...
    'Tag', 'BottleneckDecompositionFigure', ...
    'Position', [420, 220, 1400, 760], 'Color', 'w', 'InvertHardcopy', 'off');
ax = axes('Parent', fig);
applyReadableTimeSeriesAxesStyle(ax);
hold(ax, 'on');

if ~timeBinWasSpecified && ~strcmp(bottleneckScale, 'per_case')
    totalDuration = sum(componentMinutes);
    percentages = componentMinutes ./ totalDuration * 100;
    plotHandles = bar(ax, 1, percentages, 'stacked', 'BarWidth', 0.55);
    for componentIdx = 1:length(plotHandles)
        plotHandles(componentIdx).FaceColor = componentColors(componentIdx, :);
        plotHandles(componentIdx).EdgeColor = 'none';
        plotHandles(componentIdx).Tag = sprintf('BottleneckComponent%d', componentIdx);
    end
    addBottleneckPercentageLabels(ax, 1, percentages, percentages);
    title(ax, 'Bottleneck Duration Decomposition for Full Included Period');
    ylabel(ax, 'Share of total duration (%)');
    xticks(ax, 1);
    xticklabels(ax, {'Full included period'});
    ylim(ax, [0 100]);
elseif ~timeBinWasSpecified
    perCaseMinutes = componentMinutes ./ procedureCounts;
    percentages = componentMinutes ./ sum(componentMinutes) * 100;
    plotHandles = bar(ax, 1, perCaseMinutes, 'stacked', 'BarWidth', 0.55);
    for componentIdx = 1:length(plotHandles)
        plotHandles(componentIdx).FaceColor = componentColors(componentIdx, :);
        plotHandles(componentIdx).EdgeColor = 'none';
        plotHandles(componentIdx).Tag = sprintf('BottleneckComponent%d', componentIdx);
    end
    addBottleneckPercentageLabels(ax, 1, perCaseMinutes, percentages);
    title(ax, 'Average Bottleneck Duration per Procedure for Full Included Period');
    ylabel(ax, 'Duration per procedure (minutes/procedure)');
    xticks(ax, 1);
    xticklabels(ax, {'Full included period'});
else
    dateObjects = timeSeries.binStartDates;
    if isempty(dateObjects) || length(dateObjects) ~= size(componentMinutes, 1)
        error('Stored %s bottleneck summaries do not contain valid matching bin dates.', timeBin);
    end
    percentages = NaN(size(componentMinutes));
    validBins = totalMinutes > 0;
    percentages(validBins, :) = componentMinutes(validBins, :) ./ totalMinutes(validBins) * 100;
    areaDates = dateObjects;
    if strcmp(bottleneckScale, 'percent')
        areaValues = percentages;
    elseif strcmp(bottleneckScale, 'per_case')
        areaValues = NaN(size(componentMinutes));
        validProcedureBins = procedureCounts > 0;
        areaValues(validProcedureBins, :) = componentMinutes(validProcedureBins, :) ./ procedureCounts(validProcedureBins);
    else
        areaValues = componentMinutes;
    end
    if isscalar(dateObjects)
        areaDates = [dateObjects; getSingleBottleneckBinEndDate(timeSeries, timeBin, dateObjects)];
        areaValues = [areaValues; areaValues];
    end
    plotHandles = area(ax, areaDates, areaValues, 'LineStyle', 'none');
    for componentIdx = 1:length(plotHandles)
        plotHandles(componentIdx).FaceColor = componentColors(componentIdx, :);
        plotHandles(componentIdx).FaceAlpha = 0.88;
        plotHandles(componentIdx).Tag = sprintf('BottleneckComponent%d', componentIdx);
    end
    addBottleneckPercentageLabels(ax, dateObjects, areaValues(1:size(componentMinutes, 1), :), percentages);
    if strcmp(bottleneckScale, 'percent')
        title(ax, sprintf('Bottleneck Duration Composition by %s', capitalizeBinName(timeBin)));
        ylabel(ax, 'Share of bin duration (%)');
        ylim(ax, [0 100]);
    elseif strcmp(bottleneckScale, 'per_case')
        title(ax, sprintf('Average Bottleneck Duration per Procedure by %s', capitalizeBinName(timeBin)));
        ylabel(ax, 'Duration per procedure (minutes/procedure)');
    else
        title(ax, sprintf('Bottleneck Duration Decomposition by %s', capitalizeBinName(timeBin)));
        ylabel(ax, 'Duration (minutes)');
    end
    xlabel(ax, 'Date');
    if isscalar(areaDates)
        setTimeSeriesXLimits(ax, areaDates);
    else
        xlim(ax, [areaDates(1), areaDates(end)]);
    end
    formatStoredTimeAxis(ax, timeSeries);
end

legend(ax, plotHandles, componentLabels, 'Location', 'eastoutside', ...
    'FontSize', 9, 'Box', 'off');
if strcmp(bottleneckScale, 'per_case')
    plotNote = ['Room-gap burden per procedure = observed same-lab inter-case ' ...
        'minutes / procedures; not mean interval duration'];
else
    plotNote = 'Room-gap time = observed wheels-out to next wheels-in interval in the same lab';
end
text(ax, 0.995, 0.02, plotNote, ...
    'Units', 'normalized', 'HorizontalAlignment', 'right', ...
    'VerticalAlignment', 'bottom', 'FontSize', 9, 'Color', [0.35 0.35 0.35]);
hold(ax, 'off');
end

function endDate = getSingleBottleneckBinEndDate(timeSeries, timeBin, startDate)
if isfield(timeSeries, 'binEndDates') && ~isempty(timeSeries.binEndDates) && ...
        ~isnat(timeSeries.binEndDates(1)) && timeSeries.binEndDates(1) > startDate
    endDate = timeSeries.binEndDates(1);
    return;
end
switch timeBin
    case 'day'
        endDate = startDate + days(1);
    case 'week'
        endDate = startDate + calweeks(1);
    case 'month'
        endDate = startDate + calmonths(1);
    case 'quarter'
        endDate = startDate + calmonths(3);
    case 'year'
        endDate = startDate + calyears(1);
end
end

function [componentMinutes, timeSeries] = getStoredBottleneckComponents(analysisResults, timeBin)
if ~isfield(analysisResults, 'timeSeriesAnalysis') || ...
        ~isfield(analysisResults.timeSeriesAnalysis, timeBin)
    error(['Bottleneck time-series summaries are not available for ''%s''. ' ...
        'Rerun analyzeHistoricalData with HistoricalSchedules to create stored bottleneck results.'], timeBin);
end
timeSeries = analysisResults.timeSeriesAnalysis.(timeBin);
if ~isfield(timeSeries, 'department') || ~isfield(timeSeries.department, 'bottleneck')
    error(['Bottleneck time-series summaries are not available for ''%s''. ' ...
        'Rerun analyzeHistoricalData with HistoricalSchedules to create stored bottleneck results.'], timeBin);
end
bottleneck = timeSeries.department.bottleneck;
fieldNames = {'totalSetupMinutes', 'totalProcedureMinutes', 'totalPostMinutes', ...
    'totalObservedSameLabInterCaseMinutes'};
for fieldIdx = 1:length(fieldNames)
    if ~isfield(bottleneck, fieldNames{fieldIdx})
        error(['Stored %s summaries do not contain %s. ' ...
            'Rerun analyzeHistoricalData to regenerate bottleneck results.'], ...
            timeBin, fieldNames{fieldIdx});
    end
end
componentMinutes = [bottleneck.totalSetupMinutes(:), ...
    bottleneck.totalProcedureMinutes(:), bottleneck.totalPostMinutes(:), ...
    bottleneck.totalObservedSameLabInterCaseMinutes(:)];
if any(~isfinite(componentMinutes), 'all') || any(componentMinutes < 0, 'all')
    error('Stored %s bottleneck duration totals must be finite and nonnegative.', timeBin);
end
end

function procedureCounts = getStoredBottleneckProcedureCounts(timeSeries, timeBin)
if ~isfield(timeSeries, 'department') || ~isfield(timeSeries.department, 'volume') || ...
        ~isfield(timeSeries.department.volume, 'totalProcedures')
    error(['Stored %s summaries do not contain procedure-count denominators. ' ...
        'Rerun analyzeHistoricalData to regenerate per-case bottleneck results.'], timeBin);
end
procedureCounts = timeSeries.department.volume.totalProcedures(:);
if any(~isfinite(procedureCounts)) || any(procedureCounts < 0)
    error('Stored %s procedure-count denominators must be finite and nonnegative.', timeBin);
end
if numel(procedureCounts) ~= numel(timeSeries.binStartDates)
    error('Stored %s procedure counts do not contain valid matching bin values.', timeBin);
end
if ~any(procedureCounts > 0)
    error('No procedure-count denominator is available to plot per-case %s bottleneck durations.', timeBin);
end
end

function addBottleneckPercentageLabels(ax, xValues, componentHeights, percentages)
cumulativeHeights = cumsum(componentHeights, 2);
for binIdx = 1:size(componentHeights, 1)
    for componentIdx = 1:size(componentHeights, 2)
        if ~isfinite(componentHeights(binIdx, componentIdx)) || componentHeights(binIdx, componentIdx) <= 0
            continue;
        end
        yValue = cumulativeHeights(binIdx, componentIdx) - componentHeights(binIdx, componentIdx) / 2;
        text(ax, xValues(binIdx), yValue, sprintf('%.1f%%', percentages(binIdx, componentIdx)), ...
            'Tag', 'BottleneckPercentageLabel', 'HorizontalAlignment', 'center', ...
            'VerticalAlignment', 'middle', 'FontSize', 8, ...
            'Color', [0.10 0.10 0.10], 'FontWeight', 'bold');
    end
end
end

function formatStoredTimeAxis(ax, timeSeries)
numBins = length(timeSeries.binStartDates);
if numBins <= 12
    tickIdx = 1:numBins;
else
    tickIdx = unique(round(linspace(1, numBins, 10)));
end
xticks(ax, timeSeries.binStartDates(tickIdx));
if isfield(timeSeries, 'binLabels') && numel(timeSeries.binLabels) == numBins
    xticklabels(ax, timeSeries.binLabels(tickIdx));
end
xtickangle(ax, 35);
end

function timeSeries = getStoredOperatorTurnoverSeries(analysisResults, timeBin)
if ~isfield(analysisResults, 'timeSeriesAnalysis') || ...
        ~isfield(analysisResults.timeSeriesAnalysis, timeBin)
    error(['Operator turnover time-series summaries are not available for ''%s''. ' ...
        'Rerun analyzeHistoricalData with HistoricalSchedules to create stored turnover results.'], timeBin);
end
timeSeries = analysisResults.timeSeriesAnalysis.(timeBin);
if ~isfield(timeSeries, 'department') || ...
        ~isfield(timeSeries.department, 'totalOperatorTurnovers')
    error(['Operator turnover time-series summaries are not available for ''%s''. ' ...
        'Rerun analyzeHistoricalData with HistoricalSchedules to create stored turnover results.'], timeBin);
end
end

function timeSeries = getStoredOperatorIdleByFlipStatusSeries(analysisResults, timeBin)
if ~isfield(analysisResults, 'timeSeriesAnalysis') || ...
        ~isfield(analysisResults.timeSeriesAnalysis, timeBin)
    error(['Operator idle-by-flip time-series summaries are not available for ''%s''. ' ...
        'Rerun analyzeHistoricalData with HistoricalSchedules to create stored idle-by-flip results.'], timeBin);
end
timeSeries = analysisResults.timeSeriesAnalysis.(timeBin);
if ~isfield(timeSeries, 'department') || ...
        ~isfield(timeSeries.department, 'operatorIdleByFlipStatus')
    error(['Operator idle-by-flip time-series summaries are not available for ''%s''. ' ...
        'Rerun analyzeHistoricalData with HistoricalSchedules to create stored idle-by-flip results.'], timeBin);
end
idleByFlipStatus = timeSeries.department.operatorIdleByFlipStatus;
requiredGroups = {'flipped', 'notFlipped'};
requiredSummaryFields = {'meanIdleMinutes', 'medianIdleMinutes'};
for groupIdx = 1:length(requiredGroups)
    groupName = requiredGroups{groupIdx};
    if ~isfield(idleByFlipStatus, groupName)
        error('Stored %s operator idle-by-flip summaries do not contain %s results.', timeBin, groupName);
    end
    for summaryIdx = 1:length(requiredSummaryFields)
        if ~isfield(idleByFlipStatus.(groupName), requiredSummaryFields{summaryIdx})
            error('Stored %s operator idle-by-flip summaries do not contain %s.%s.', ...
                timeBin, groupName, requiredSummaryFields{summaryIdx});
        end
    end
end
requiredDifferenceFields = {'meanMinutesSavedPerFlip', 'medianMinutesSavedPerFlip'};
for fieldIdx = 1:length(requiredDifferenceFields)
    if ~isfield(idleByFlipStatus, requiredDifferenceFields{fieldIdx})
        error('Stored %s operator idle-by-flip summaries do not contain %s.', ...
            timeBin, requiredDifferenceFields{fieldIdx});
    end
end
end

function timeSeries = getStoredTimeSeries(analysisResults, timeBin)
if ~isfield(analysisResults, 'timeSeriesAnalysis') || ...
        ~isfield(analysisResults.timeSeriesAnalysis, timeBin)
    error(['Time-series summaries are not available for ''%s''. ' ...
        'Rerun analyzeHistoricalData to create stored time-binned results.'], timeBin);
end
timeSeries = analysisResults.timeSeriesAnalysis.(timeBin);
timeSeries = ensureManuscriptTimeSeriesCompatibility(timeSeries);
end

function timeSeries = ensureManuscriptTimeSeriesCompatibility(timeSeries)
if ~isfield(timeSeries, 'trends')
    timeSeries.trends = struct();
end
if ~isfield(timeSeries.trends, 'departmentFlipRatioPercent')
    timeSeries.trends.departmentFlipRatioPercent = calculateDisplayTrendStats( ...
        timeSeries.department.labFlipPerOperatorTurnoverPercent);
end
if ~isfield(timeSeries.trends, 'departmentOperatorIdlePerTurnover')
    timeSeries.trends.departmentOperatorIdlePerTurnover = calculateDisplayTrendStats( ...
        timeSeries.department.operatorIdlePerOperatorTurnover);
end
if ~isfield(timeSeries, 'relationships')
    timeSeries.relationships = struct();
end
if ~isfield(timeSeries.relationships, 'departmentFlipVsIdle')
    timeSeries.relationships.departmentFlipVsIdle = calculateDisplayRelationshipStats( ...
        timeSeries.department.labFlipPerOperatorTurnoverPercent, ...
        timeSeries.department.operatorIdlePerOperatorTurnover);
end
end

function operatorAssociation = getManuscriptOperatorAssociation(analysisResults)
if isfield(analysisResults, 'manuscriptOperatorAssociation') && ...
        isfield(analysisResults.manuscriptOperatorAssociation, 'pooledFlipRatioPercent')
    operatorAssociation = analysisResults.manuscriptOperatorAssociation;
    return;
end
if ~isfield(analysisResults, 'timeSeriesAnalysis') || ...
        ~isfield(analysisResults.timeSeriesAnalysis, 'day') || ...
        ~isfield(analysisResults.timeSeriesAnalysis.day, 'operators')
    error(['Operator manuscript data are unavailable. Rerun analyzeHistoricalData ' ...
        'to create manuscript-ready operator summaries.']);
end
dailyOperators = analysisResults.timeSeriesAnalysis.day.operators;
operatorAssociation = struct();
operatorAssociation.operatorNames = dailyOperators.operatorNames;
operatorAssociation.totalLabFlips = sum(dailyOperators.totalFlips, 2);
operatorAssociation.totalOperatorTurnovers = sum(dailyOperators.flipEligibleOperatorTurnovers, 2);
operatorAssociation.pooledFlipRatioPercent = NaN(size(operatorAssociation.totalOperatorTurnovers));
validTurnovers = operatorAssociation.totalOperatorTurnovers > 0;
operatorAssociation.pooledFlipRatioPercent(validTurnovers) = ...
    operatorAssociation.totalLabFlips(validTurnovers) ./ ...
    operatorAssociation.totalOperatorTurnovers(validTurnovers) * 100;
operatorAssociation.medianIdleTimePerTurnover = median(dailyOperators.idleTimePerTurnover, 2, 'omitnan');
operatorAssociation.medianIdleTimePerTurnover(all(~isfinite(dailyOperators.idleTimePerTurnover), 2)) = NaN;
operatorAssociation.relationship = calculateDisplayRelationshipStats( ...
    operatorAssociation.pooledFlipRatioPercent, operatorAssociation.medianIdleTimePerTurnover);
end

function fig = createManuscriptTimeSeriesFigure(timeSeries, timeBin)
dateObjects = timeSeries.binStartDates;
department = timeSeries.department;
trends = timeSeries.trends;
if isempty(dateObjects)
    error('No stored %s department time-series data available for manuscript figure.', timeBin);
end

observedColor = [0.08 0.20 0.38];
trendColor = [0.68 0.35 0.19];
[fig, axesHandles] = createManuscriptFigureCanvas('timeSeries');

ax1 = axesHandles(1);
applyManuscriptAxesStyle(ax1);
hold(ax1, 'on');
plot(ax1, dateObjects, department.labFlipPerOperatorTurnoverPercent, 'o-', ...
    'Color', observedColor, 'MarkerFaceColor', observedColor, ...
    'MarkerSize', 4.5, 'LineWidth', 1.15);
plotManuscriptTemporalTrend(ax1, dateObjects, trends.departmentFlipRatioPercent, ...
    trendColor, timeBin, 'percentage points');
ylabel(ax1, 'Lab flips per operator turnover (%)');
addPanelLabel(ax1, 'A');
formatManuscriptTimeAxis(ax1, timeSeries);
hold(ax1, 'off');

ax2 = axesHandles(2);
applyManuscriptAxesStyle(ax2);
hold(ax2, 'on');
plot(ax2, dateObjects, department.operatorIdlePerOperatorTurnover, 'o-', ...
    'Color', observedColor, 'MarkerFaceColor', observedColor, ...
    'MarkerSize', 4.5, 'LineWidth', 1.15);
plotManuscriptTemporalTrend(ax2, dateObjects, trends.departmentOperatorIdlePerTurnover, ...
    trendColor, timeBin, 'min/turnover');
ylabel(ax2, 'Operator idle time per turnover (min)');
addPanelLabel(ax2, 'B');
formatManuscriptTimeAxis(ax2, timeSeries);
hold(ax2, 'off');
linkaxes([ax1 ax2], 'x');
end

function fig = createManuscriptAssociationFigure(timeSeries, operatorAssociation, showOperatorInitialLabels, timeBin)
xValues = timeSeries.department.labFlipPerOperatorTurnoverPercent;
yValues = timeSeries.department.operatorIdlePerOperatorTurnover;
[fig, axesHandles] = createManuscriptFigureCanvas('association');
plotManuscriptScatterAxes(axesHandles(1), xValues, yValues, ...
    timeSeries.relationships.departmentFlipVsIdle, timeSeries.binLabels, true, [], ...
    'Lab flips per operator turnover (%)', 'Operator idle time per turnover (min)');
title(axesHandles(1), 'Department-Level Temporal Association');
addPanelLabel(axesHandles(1), 'A');
addManuscriptContextAnnotation(axesHandles(1), sprintf('Each point represents one %s.', timeBin));

labels = {};
if showOperatorInitialLabels
    labels = createOperatorInitialLabels(operatorAssociation.operatorNames);
end
plotManuscriptScatterAxes(axesHandles(2), operatorAssociation.pooledFlipRatioPercent, ...
    operatorAssociation.medianIdleTimePerTurnover, operatorAssociation.relationship, ...
    labels, showOperatorInitialLabels, operatorAssociation.totalOperatorTurnovers, ...
    'Pooled lab flips per operator turnover (%)', 'Median operator idle time per turnover (min)');
title(axesHandles(2), 'Operator-Level Association');
addPanelLabel(axesHandles(2), 'B');
end

function plotManuscriptScatterAxes(ax, xValues, yValues, relationship, labels, showLabels, pointWeights, xLabelText, yLabelText)
validValues = isfinite(xValues) & isfinite(yValues);
if ~any(validValues)
    error('No valid data available for manuscript association figure.');
end

observedColor = [0.08 0.20 0.38];
trendColor = [0.68 0.35 0.19];
applyManuscriptAxesStyle(ax);
hold(ax, 'on');
plottedX = xValues(validValues);
plottedY = yValues(validValues);
if isempty(pointWeights)
    markerSizes = repmat(46, sum(validValues), 1);
else
    plottedWeights = pointWeights(validValues);
    markerSizes = scaleManuscriptMarkerSizes(plottedWeights);
end
scatter(ax, plottedX, plottedY, markerSizes, observedColor, 'filled', ...
    'MarkerEdgeColor', 'w', 'LineWidth', 0.6);

if sum(validValues) >= 2 && isfinite(relationship.slope)
    sortedX = sort(plottedX);
    fittedY = relationship.intercept + relationship.slope .* sortedX;
    plot(ax, sortedX, fittedY, '--', 'Color', trendColor, 'LineWidth', 1.35);
    annotationText = sprintf('Slope: %.2f min per 1%% flip ratio\nR^2 = %.2f', ...
        relationship.slope, relationship.rSquared);
    addManuscriptStatsAnnotation(ax, annotationText);
end
if showLabels
    addManuscriptPointLabels(ax, plottedX, plottedY, labels(validValues));
end
if ~isempty(pointWeights)
    addTurnoverOpportunityCaption(ax, pointWeights(validValues));
end
xlabel(ax, xLabelText);
ylabel(ax, yLabelText);
hold(ax, 'off');
end

function createIndividualOperatorTracesFigure(dateObjects, flipRatioMatrix, operatorLabels, pooledFlipRatio, trendStats, timeBin)
avgLineColor = [0.00 0.45 0.74];
trendLineColor = [0.85 0.33 0.10];
operatorTraceColors = lines(max(1, size(flipRatioMatrix, 1)));

fig = figure('Position', [350, 350, 1500, 700], 'Color', 'w', 'InvertHardcopy', 'off');
ax = axes('Parent', fig);
applyReadableTimeSeriesAxesStyle(ax);
hold(ax, 'on');

numOperators = size(flipRatioMatrix, 1);
legendHandles = gobjects(0);
legendLabels = {};
for opIdx = 1:numOperators
    validData = ~isnan(flipRatioMatrix(opIdx, :));
    if any(validData)
        traceHandle = plot(ax, dateObjects, flipRatioMatrix(opIdx, :), 'o-', ...
            'Color', operatorTraceColors(opIdx, :), 'MarkerSize', 3, ...
            'LineWidth', 0.8, 'DisplayName', operatorLabels{opIdx});
        legendHandles(end+1) = traceHandle; %#ok<AGROW>
        legendLabels{end+1} = operatorLabels{opIdx}; %#ok<AGROW>
    end
end

validAvgData = ~isnan(pooledFlipRatio);
if any(validAvgData)
    cohortHandle = plot(ax, dateObjects, pooledFlipRatio, 'o-', ...
        'Color', avgLineColor, 'LineWidth', 2.5, 'MarkerSize', 5, ...
        'MarkerFaceColor', avgLineColor, 'DisplayName', 'Included-Operator Cohort Ratio');
    legendHandles(end+1) = cohortHandle; %#ok<AGROW>
    legendLabels{end+1} = 'Included-Operator Cohort Ratio'; %#ok<AGROW>
    trendHandle = plotStoredTrend(ax, dateObjects, trendStats, trendLineColor, timeBin, '%');
    if ~isempty(trendHandle)
        legendHandles(end+1) = trendHandle; %#ok<AGROW>
        legendLabels{end+1} = 'Linear Trend'; %#ok<AGROW>
    end
end

title(ax, sprintf('Individual Operator Lab Flips per Operator Turnover by %s', capitalizeBinName(timeBin)));
xlabel(ax, 'Date');
ylabel(ax, 'Lab Flips per Operator Turnover (%)');
ylim(ax, [0 100]);
setTimeSeriesXLimits(ax, dateObjects);
set(get(ax, 'Title'), 'Color', [0.10 0.10 0.10]);
set(get(ax, 'XLabel'), 'Color', [0.10 0.10 0.10]);
set(get(ax, 'YLabel'), 'Color', [0.10 0.10 0.10]);
leg = legend(ax, legendHandles, legendLabels, 'Location', 'eastoutside', 'FontSize', 8, 'Box', 'off');
set(leg, 'TextColor', [0.10 0.10 0.10], 'Color', 'w');
text(ax, 0.995, 0.03, 'Colored lines = individual operators; gaps = no turnover opportunity', ...
    'Units', 'normalized', 'HorizontalAlignment', 'right', ...
    'VerticalAlignment', 'bottom', 'FontSize', 9, 'Color', [0.35 0.35 0.35]);
hold(ax, 'off');
end

function createFlipRatioSummaryFigure(dateObjects, cohortFlipRatio, deptFlipPerOperatorTurnover, trends, timeBin)
avgLineColor = [0.00 0.45 0.74];
deptLineColor = [0.10 0.55 0.35];
trendLineColor = [0.85 0.33 0.10];

fig = figure('Position', [400, 400, 1400, 850], 'Color', 'w', 'InvertHardcopy', 'off');

ax1 = subplot(2, 1, 1, 'Parent', fig);
applyReadableTimeSeriesAxesStyle(ax1);
hold(ax1, 'on');
validAvgData = ~isnan(cohortFlipRatio);
if any(validAvgData)
    plot(ax1, dateObjects, cohortFlipRatio, 'o-', ...
         'Color', avgLineColor, 'LineWidth', 0.5, 'MarkerSize', 2.5, ...
         'MarkerFaceColor', avgLineColor, 'DisplayName', 'Included-Operator Cohort Ratio');
    plotStoredTrend(ax1, dateObjects, trends.includedOperatorFlipRatioPercent, ...
        trendLineColor, timeBin, '%');
end
title(ax1, sprintf('Included-Operator Cohort Lab Flips per Operator Turnover by %s', capitalizeBinName(timeBin)));
xlabel(ax1, 'Date');
ylabel(ax1, 'Lab Flips per Operator Turnover (%)');
ylim(ax1, [0 100]);
setTimeSeriesXLimits(ax1, dateObjects);
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
         'MarkerFaceColor', deptLineColor, 'DisplayName', 'Department Ratio');
    plotStoredTrend(ax2, dateObjects, trends.departmentFlipRatioPercent, ...
        trendLineColor, timeBin, '%');
end
title(ax2, sprintf('Department Lab Flips per Operator Turnover by %s', capitalizeBinName(timeBin)));
xlabel(ax2, 'Date');
ylabel(ax2, 'Lab Flips per Operator Turnover (%)');
ylim(ax2, [0 100]);
setTimeSeriesXLimits(ax2, dateObjects);
set(get(ax2, 'Title'), 'Color', [0.10 0.10 0.10]);
set(get(ax2, 'XLabel'), 'Color', [0.10 0.10 0.10]);
set(get(ax2, 'YLabel'), 'Color', [0.10 0.10 0.10]);
leg2 = legend(ax2, 'Location', 'northwest', 'FontSize', 9, 'Box', 'off');
set(leg2, 'TextColor', [0.10 0.10 0.10], 'Color', 'w');
grid off;
hold(ax2, 'off');
end

function createOperatorIdleTimeTrendFigure(dateObjects, medianIdlePerTurnover, operatorIdlePerTurnoverMatrix, operatorLabels, showIndividualOperatorTraces, trendStats, timeBin)
medianColor = [0.00 0.45 0.74];
trendLineColor = [0.85 0.33 0.10];
operatorTraceColors = lines(max(1, size(operatorIdlePerTurnoverMatrix, 1)));

fig = figure('Position', [450, 450, 1400, 650], 'Color', 'w', 'InvertHardcopy', 'off');
ax = axes('Parent', fig);
applyReadableTimeSeriesAxesStyle(ax);
hold(ax, 'on');

legendHandles = gobjects(0);
legendLabels = {};

if showIndividualOperatorTraces && ~isempty(operatorIdlePerTurnoverMatrix)
    numOperators = size(operatorIdlePerTurnoverMatrix, 1);
    for opIdx = 1:numOperators
        validData = ~isnan(operatorIdlePerTurnoverMatrix(opIdx, :));
        if any(validData)
            plotHandle = plot(ax, dateObjects, operatorIdlePerTurnoverMatrix(opIdx, :), 'o-', ...
                'Color', operatorTraceColors(opIdx, :), 'MarkerSize', 2.5, ...
                'LineWidth', 0.8, ...
                'DisplayName', operatorLabels{opIdx});
            legendHandles(end+1) = plotHandle; %#ok<AGROW>
            legendLabels{end+1} = operatorLabels{opIdx}; %#ok<AGROW>
        end
    end
end

validMedian = ~isnan(medianIdlePerTurnover);
if any(validMedian)
    medianHandle = plot(ax, dateObjects, medianIdlePerTurnover, 'o-', ...
        'Color', medianColor, 'LineWidth', 0.5, 'MarkerSize', 2.5, ...
        'MarkerFaceColor', medianColor, 'DisplayName', 'Median Operator Idle/Turnover');
    legendHandles(end+1) = medianHandle; %#ok<AGROW>
    legendLabels{end+1} = 'Median Operator Idle/Turnover'; %#ok<AGROW>
    trendHandle = plotStoredTrend(ax, dateObjects, trendStats, trendLineColor, timeBin, ' minutes');
    if ~isempty(trendHandle)
        legendHandles(end+1) = trendHandle; %#ok<AGROW>
        legendLabels{end+1} = 'Linear Trend'; %#ok<AGROW>
    end
end

title(ax, sprintf('Median Operator Idle Time per Turnover by %s', capitalizeBinName(timeBin)));
xlabel(ax, 'Date');
ylabel(ax, 'Idle Time per Turnover (minutes)');
setTimeSeriesXLimits(ax, dateObjects);
set(get(ax, 'Title'), 'Color', [0.10 0.10 0.10]);
set(get(ax, 'XLabel'), 'Color', [0.10 0.10 0.10]);
set(get(ax, 'YLabel'), 'Color', [0.10 0.10 0.10]);
if showIndividualOperatorTraces
    if ~isempty(legendHandles)
        leg = legend(ax, legendHandles, legendLabels, 'Location', 'eastoutside', 'FontSize', 8, 'Box', 'off');
    else
        leg = legend(ax, 'Location', 'northwest', 'FontSize', 9, 'Box', 'off');
    end
else
    leg = legend(ax, 'Location', 'northwest', 'FontSize', 9, 'Box', 'off');
end
set(leg, 'TextColor', [0.10 0.10 0.10], 'Color', 'w');
if showIndividualOperatorTraces
    text(ax, 0.995, 0.03, 'Colored lines = individual operators; gaps = no turnover opportunity; median = typical operator-bin', ...
        'Units', 'normalized', 'HorizontalAlignment', 'right', ...
        'VerticalAlignment', 'bottom', 'FontSize', 9, 'Color', [0.35 0.35 0.35]);
else
    text(ax, 0.995, 0.03, 'Median = typical operator-bin; line = linear trend', ...
        'Units', 'normalized', 'HorizontalAlignment', 'right', ...
        'VerticalAlignment', 'bottom', 'FontSize', 9, 'Color', [0.35 0.35 0.35]);
end
grid off;
hold(ax, 'off');
end

function trendHandle = plotStoredTrend(ax, dateObjects, trendStats, trendLineColor, timeBin, slopePrefix)
trendHandle = [];
if ~isfield(trendStats, 'fittedValues') || sum(isfinite(trendStats.fittedValues)) < 2
    return;
end
trendHandle = plot(ax, dateObjects, trendStats.fittedValues, '-', 'Color', trendLineColor, ...
    'LineWidth', 2.5, 'DisplayName', 'Linear Trend');
displayStats = struct('slope', trendStats.slopePerBin, 'rSquared', trendStats.rSquared);
addTrendStatsAnnotation(ax, displayStats, sprintf('%s/%s', slopePrefix, timeBin));
end

function label = capitalizeBinName(timeBin)
label = [upper(timeBin(1)) timeBin(2:end)];
end

function isValid = isValidTimeBinInput(timeBin)
isValid = (ischar(timeBin) || (isstring(timeBin) && isscalar(timeBin))) && ...
    any(strcmpi(char(string(timeBin)), {'day', 'week', 'month', 'quarter', 'year'}));
end

function isValid = isValidBottleneckScaleInput(scale)
isValid = (ischar(scale) || (isstring(scale) && isscalar(scale))) && ...
    any(strcmpi(char(string(scale)), {'minutes', 'percent', 'per_case'}));
end

function isValid = isValidFlipIdleStatisticInput(statistic)
isValid = (ischar(statistic) || (isstring(statistic) && isscalar(statistic))) && ...
    any(strcmpi(char(string(statistic)), {'median', 'mean'}));
end

function isValid = isValidExportFormatInput(exportFormat)
isValid = (ischar(exportFormat) || (isstring(exportFormat) && isscalar(exportFormat))) && ...
    any(strcmpi(char(string(exportFormat)), {'pdf', 'tiff'}));
end

function setTimeSeriesXLimits(ax, dateObjects)
if length(dateObjects) == 1
    xlim(ax, [dateObjects(1) - days(1), dateObjects(1) + days(1)]);
else
    xlim(ax, [min(dateObjects), max(dateObjects)]);
end
end

function plotManuscriptTemporalTrend(ax, dateObjects, trendStats, trendColor, timeBin, slopeUnits)
if ~isfield(trendStats, 'fittedValues') || sum(isfinite(trendStats.fittedValues)) < 2
    return;
end
plot(ax, dateObjects, trendStats.fittedValues, '--', 'Color', trendColor, 'LineWidth', 1.35);
annotationText = sprintf('Trend: %+.2f %s/%s\nR^2 = %.2f', ...
    trendStats.slopePerBin, slopeUnits, timeBin, trendStats.rSquared);
addManuscriptStatsAnnotation(ax, annotationText);
end

function addManuscriptStatsAnnotation(ax, annotationText)
fig = ancestor(ax, 'figure');
axPosition = getpixelposition(ax, true);
offset = scaleManuscriptPixels([20, 52, 170, 48]);
annotation(fig, 'textbox', 'Units', 'pixels', ...
    'Position', [axPosition(1) + axPosition(3) + offset(1), ...
    axPosition(2) + axPosition(4) - offset(2), offset(3), offset(4)], ...
    'String', annotationText, 'HorizontalAlignment', 'left', ...
    'VerticalAlignment', 'top', 'FontName', 'Arial', 'FontSize', 9, ...
    'Color', [0.15 0.15 0.15], 'EdgeColor', 'none', ...
    'BackgroundColor', 'none', 'FitBoxToText', 'off');
end

function addPanelLabel(ax, panelLabel)
text(ax, -0.075, 1.03, panelLabel, 'Units', 'normalized', ...
    'FontSize', 12, 'FontWeight', 'bold', 'Color', [0.10 0.10 0.10], ...
    'HorizontalAlignment', 'left', 'VerticalAlignment', 'bottom');
end

function addManuscriptPointLabels(ax, xValues, yValues, labels)
xSpan = max(range(xValues), 1);
ySpan = max(range(yValues), 1);
candidateOffsets = [ ...
     0.02,  0.035; ...
     0.02, -0.045; ...
     0.11,  0.000; ...
    -0.04,  0.035; ...
    -0.04, -0.045; ...
     0.11,  0.055; ...
     0.11, -0.060; ...
    -0.04,  0.075];
labelX = NaN(length(labels), 1);
labelY = NaN(length(labels), 1);

for pointIdx = 1:length(labels)
    selectedOffset = candidateOffsets(1, :);
    for candidateIdx = 1:size(candidateOffsets, 1)
        candidateOffset = candidateOffsets(candidateIdx, :);
        proposedX = xValues(pointIdx) + candidateOffset(1) * xSpan;
        proposedY = yValues(pointIdx) + candidateOffset(2) * ySpan;
        if pointIdx == 1 || ~any(abs(proposedX - labelX(1:pointIdx-1)) < 0.13 * xSpan & ...
                abs(proposedY - labelY(1:pointIdx-1)) < 0.06 * ySpan)
            selectedOffset = candidateOffset;
            break;
        end
    end
    labelX(pointIdx) = xValues(pointIdx) + selectedOffset(1) * xSpan;
    labelY(pointIdx) = yValues(pointIdx) + selectedOffset(2) * ySpan;
    if selectedOffset(1) < 0
        horizontalAlignment = 'right';
    else
        horizontalAlignment = 'left';
    end
    text(ax, labelX(pointIdx), labelY(pointIdx), labels{pointIdx}, ...
        'FontSize', 8, 'Color', [0.20 0.20 0.20], ...
        'HorizontalAlignment', horizontalAlignment, ...
        'BackgroundColor', 'w', 'Margin', 1);
end
end

function markerSizes = scaleManuscriptMarkerSizes(pointWeights)
pointWeights = pointWeights(:);
if range(pointWeights) == 0
    markerSizes = repmat(62, size(pointWeights));
    return;
end
normalizedWeights = (sqrt(pointWeights) - min(sqrt(pointWeights))) ./ range(sqrt(pointWeights));
markerSizes = 38 + normalizedWeights * 82;
end

function addTurnoverOpportunityCaption(ax, pointWeights)
noteText = sprintf(['Each point represents one operator.\n' ...
    'Point area scales with turnover opportunities\n' ...
    '(square-root scaled; range: %d--%d).'], ...
    round(min(pointWeights)), round(max(pointWeights)));
addManuscriptContextAnnotation(ax, noteText);
end

function addManuscriptContextAnnotation(ax, noteText)
fig = ancestor(ax, 'figure');
axPosition = getpixelposition(ax, true);
offset = scaleManuscriptPixels([20, 155, 190, 72]);
annotation(fig, 'textbox', 'Units', 'pixels', ...
    'Position', [axPosition(1) + axPosition(3) + offset(1), ...
    axPosition(2) + axPosition(4) - offset(2), offset(3), offset(4)], ...
    'String', noteText, 'HorizontalAlignment', 'left', ...
    'VerticalAlignment', 'top', 'FontName', 'Arial', 'FontSize', 8, ...
    'Color', [0.25 0.25 0.25], 'EdgeColor', 'none', ...
    'BackgroundColor', 'none', 'FitBoxToText', 'off');
end

function trendStats = calculateDisplayTrendStats(values)
values = values(:);
xValues = (0:length(values)-1)';
validValues = isfinite(values);
trendStats = struct('slopePerBin', NaN, 'rSquared', NaN, ...
    'fittedValues', NaN(size(values)), 'nBins', sum(validValues));
if sum(validValues) < 2
    return;
end
if exist('fitlm', 'file') == 2
    model = fitlm(xValues(validValues), values(validValues));
    trendStats.slopePerBin = model.Coefficients.Estimate(2);
    trendStats.rSquared = model.Rsquared.Ordinary;
    trendStats.fittedValues = predict(model, xValues);
else
    coefficients = polyfit(xValues(validValues), values(validValues), 1);
    trendStats.slopePerBin = coefficients(1);
    trendStats.fittedValues = polyval(coefficients, xValues);
    trendStats.rSquared = calculateFallbackRSquared(values(validValues), trendStats.fittedValues(validValues));
end
end

function relationshipStats = calculateDisplayRelationshipStats(xValues, yValues)
xValues = xValues(:);
yValues = yValues(:);
validValues = isfinite(xValues) & isfinite(yValues);
relationshipStats = struct('slope', NaN, 'intercept', NaN, 'rSquared', NaN, ...
    'fittedValues', NaN(size(yValues)), 'nBins', sum(validValues));
if sum(validValues) < 2 || length(unique(xValues(validValues))) < 2
    return;
end
if exist('fitlm', 'file') == 2
    model = fitlm(xValues(validValues), yValues(validValues));
    relationshipStats.intercept = model.Coefficients.Estimate(1);
    relationshipStats.slope = model.Coefficients.Estimate(2);
    relationshipStats.rSquared = model.Rsquared.Ordinary;
    relationshipStats.fittedValues(validValues) = predict(model, xValues(validValues));
else
    coefficients = polyfit(xValues(validValues), yValues(validValues), 1);
    relationshipStats.slope = coefficients(1);
    relationshipStats.intercept = coefficients(2);
    relationshipStats.fittedValues(validValues) = polyval(coefficients, xValues(validValues));
    relationshipStats.rSquared = calculateFallbackRSquared(yValues(validValues), relationshipStats.fittedValues(validValues));
end
end

function formatManuscriptTimeAxis(ax, timeSeries)
dateObjects = timeSeries.binStartDates;
setTimeSeriesXLimits(ax, dateObjects);
numBins = length(dateObjects);
if numBins <= 12
    tickIdx = 1:numBins;
else
    tickIdx = unique(round(linspace(1, numBins, 10)));
end
xticks(ax, dateObjects(tickIdx));
xticklabels(ax, timeSeries.binLabels(tickIdx));
xtickangle(ax, 35);
end

function [fig, axesHandles] = createManuscriptFigureCanvas(figureType)
axisSize = scaleManuscriptPixels(400);
axisLeft = scaleManuscriptPixels(92);
statsWidth = scaleManuscriptPixels(190);
figureWidth = axisLeft + axisSize + statsWidth + scaleManuscriptPixels(18);
switch figureType
    case 'timeSeries'
        figureHeight = scaleManuscriptPixels(1050);
        axisPositions = [axisLeft, scaleManuscriptPixels(590), axisSize, axisSize; ...
            axisLeft, scaleManuscriptPixels(64), axisSize, axisSize];
        figurePosition = [300, 40, figureWidth, figureHeight];
    case 'association'
        figureHeight = scaleManuscriptPixels(1050);
        axisPositions = [axisLeft, scaleManuscriptPixels(590), axisSize, axisSize; ...
            axisLeft, scaleManuscriptPixels(64), axisSize, axisSize];
        figurePosition = [350, 40, figureWidth, figureHeight];
    otherwise
        error('Unsupported manuscript figure type: %s', figureType);
end
fig = figure('Units', 'pixels', 'Position', figurePosition, ...
    'Color', 'w', 'InvertHardcopy', 'off');
axesHandles = gobjects(size(axisPositions, 1), 1);
for axisIdx = 1:size(axisPositions, 1)
    axesHandles(axisIdx) = axes('Parent', fig, 'Units', 'pixels', ...
        'Position', axisPositions(axisIdx, :));
end
end

function scaledPixels = scaleManuscriptPixels(pixelValues)
scaledPixels = round(pixelValues * 0.85);
end

function applyManuscriptAxesStyle(ax)
fig = ancestor(ax, 'figure');
set(fig, 'Color', 'w', 'InvertHardcopy', 'off');
set(ax, 'Box', 'off', 'Color', 'w', 'FontName', 'Arial', 'FontSize', 10, ...
    'LineWidth', 0.85, 'TickDir', 'out', ...
    'XColor', [0.12 0.12 0.12], 'YColor', [0.12 0.12 0.12], ...
      'YGrid', 'on', 'XGrid', 'off', 'GridColor', [0.90 0.90 0.90], ...
      'GridAlpha', 1.0, 'MinorGridLineStyle', 'none');
pbaspect(ax, [1 1 1]);
ax.Layer = 'top';
end

function exportManuscriptFigure(fig, exportPath, figureSuffix, exportFormat, exportResolution)
if isempty(exportPath)
    return;
end
[exportFolder, exportName, ~] = fileparts(exportPath);
if isempty(exportName)
    error('ExportPath must provide a manuscript filename prefix.');
end
if isempty(exportFolder)
    exportFolder = '.';
end
if ~exist(exportFolder, 'dir')
    error('ExportPath folder does not exist: %s', exportFolder);
end
outputFile = fullfile(exportFolder, sprintf('%s_%s.%s', exportName, figureSuffix, exportFormat));
switch exportFormat
    case 'pdf'
        exportgraphics(fig, outputFile, 'ContentType', 'vector');
    case 'tiff'
        exportgraphics(fig, outputFile, 'Resolution', exportResolution);
end
fprintf('Exported manuscript figure: %s\n', outputFile);
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
    addTrendStatsAnnotation(gca, calculateLinearTrendStats(x, y), '');
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
    addTrendStatsAnnotation(gca, calculateLinearTrendStats(x, y), '');
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
    addTrendStatsAnnotation(gca, calculateLinearTrendStats(x, y), '');
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
    addTrendStatsAnnotation(gca, calculateLinearTrendStats(x, y), '');
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
    addTrendStatsAnnotation(gca, calculateLinearTrendStats(x, y), '');
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
    addTrendStatsAnnotation(gca, calculateLinearTrendStats(x, y), '');
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
    addTrendStatsAnnotation(gca, calculateLinearTrendStats(x, y), '');
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
    addTrendStatsAnnotation(gca, calculateLinearTrendStats(x, y), '');
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
