function plotMultiExperimentResults(experimentResults, varargin)
% Plot analysis results from multiple experiments for comparison
% Version: 1.0.0
%
% Inputs:
%   experimentResults - cell array of results structures from runSchedulingExperiment.m
%
% Optional Parameters:
%   'MetricType'        - string, metric to plot ('IdleToTurnover', 'FlipToTurnover', 'Makespan', 'LabUtilization', 'MedianDailyIdleTime') (default: 'IdleToTurnover')
%   'PlotType'          - string, type of plot ('Bar', 'Box', 'Line') (default: 'Bar')
%   'ShowIndividualOps' - logical, show individual operator metrics within experiments (default: false)
%   'ExperimentNames'   - cell array of strings, custom names for experiments (default: auto-generated)
%   'Title'             - string, custom plot title (default: auto-generated)
%
% Examples:
%   plotMultiExperimentResults(experimentResults)  % Default: average idle to turnover ratio bar chart
%   plotMultiExperimentResults(experimentResults, 'MetricType', 'Makespan')
%   plotMultiExperimentResults(experimentResults, 'MetricType', 'MedianDailyIdleTime')
%   plotMultiExperimentResults(experimentResults, 'PlotType', 'Box', 'ShowIndividualOps', true)
%   plotMultiExperimentResults(experimentResults, 'ExperimentNames', {'Baseline', 'Optimized'})

% Parse optional parameters
p = inputParser();
addParameter(p, 'MetricType', 'IdleToTurnover', @ischar);
addParameter(p, 'PlotType', 'Bar', @ischar);
addParameter(p, 'ShowIndividualOps', false, @islogical);
addParameter(p, 'ExperimentNames', {}, @iscell);
addParameter(p, 'Title', '', @ischar);
parse(p, varargin{:});

metricType = p.Results.MetricType;
plotType = p.Results.PlotType;
showIndividualOps = p.Results.ShowIndividualOps;
experimentNames = p.Results.ExperimentNames;
customTitle = p.Results.Title;

% Validate inputs
if isempty(experimentResults)
    error('experimentResults cannot be empty');
end

% Convert single result or struct array to cell array for consistency
if ~iscell(experimentResults)
    if isstruct(experimentResults) && length(experimentResults) > 1
        % Convert struct array to cell array
        tempCell = cell(length(experimentResults), 1);
        for idx = 1:length(experimentResults)
            tempCell{idx} = experimentResults(idx);
        end
        experimentResults = tempCell;
    else
        % Single struct, wrap in cell
        experimentResults = {experimentResults};
    end
end

numExperiments = length(experimentResults);

% Generate experiment names if not provided
if isempty(experimentNames)
    experimentNames = cell(numExperiments, 1);
    for i = 1:numExperiments
        expResult = experimentResults{i};
        if isfield(expResult, 'config')
            if isfield(expResult.config, 'experimentName')
                experimentNames{i} = expResult.config.experimentName;
            else
                experimentNames{i} = sprintf('Experiment %d', i);
            end
        else
            experimentNames{i} = sprintf('Experiment %d', i);
        end
    end
end

% Validate experiment names length
if length(experimentNames) ~= numExperiments
    error('Number of experiment names must match number of experiments');
end

% Extract metrics based on metric type
switch metricType
    case 'IdleToTurnover'
        [metricData, metricLabel, metricUnit] = extractIdleToTurnoverMetrics(experimentResults, showIndividualOps);
    case 'FlipToTurnover'
        [metricData, metricLabel, metricUnit] = extractFlipToTurnoverMetrics(experimentResults, showIndividualOps);
    case 'Makespan'
        [metricData, metricLabel, metricUnit] = extractMakespanMetrics(experimentResults, showIndividualOps);
    case 'LabUtilization'
        [metricData, metricLabel, metricUnit] = extractLabUtilizationMetrics(experimentResults, showIndividualOps);
    case 'MedianDailyIdleTime'
        [metricData, metricLabel, metricUnit] = extractMedianDailyIdleTimeMetrics(experimentResults, showIndividualOps);
    otherwise
        error('Unsupported metric type: %s. Supported types: IdleToTurnover, FlipToTurnover, Makespan, LabUtilization, MedianDailyIdleTime', metricType);
end

% Create plot based on plot type
figure('Position', [100, 100, 1200, 800]);

switch plotType
    case 'Bar'
        createBarPlot(metricData, experimentNames, metricLabel, metricUnit, showIndividualOps);
    case 'Box'
        createBoxPlot(metricData, experimentNames, metricLabel, metricUnit, showIndividualOps);
    case 'Line'
        createLinePlot(metricData, experimentNames, metricLabel, metricUnit, showIndividualOps);
    otherwise
        error('Unsupported plot type: %s. Supported types: Bar, Box, Line', plotType);
end

% Set title
if ~isempty(customTitle)
    title(customTitle);
else
    title('');
end

grid off;
fprintf('Multi-experiment plot created with %d experiments\n', numExperiments);
end

function [metricData, metricLabel, metricUnit] = extractIdleToTurnoverMetrics(experimentResults, showIndividualOps)
% Extract idle time to turnover ratio metrics (same as plotAnalysisResults.m)
metricLabel = 'median idle time/turnover';
metricUnit = 'min';
numExperiments = length(experimentResults);

% Always extract individual operator metrics for box plots (default behavior)
metricData = cell(numExperiments, 1);

for i = 1:numExperiments
    result = experimentResults{i};
    operatorMetrics = [];
    
    if isfield(result, 'analysisResults')
        analysisRes = result.analysisResults;
        if isfield(analysisRes, 'comprehensiveOperatorMetrics')
            compMetrics = analysisRes.comprehensiveOperatorMetrics;
            operatorNames = fieldnames(compMetrics);
            
            for j = 1:length(operatorNames)
                opName = operatorNames{j};
                opData = compMetrics.(opName);
                
                if isfield(opData, 'medianIdleTimePerTurnover')
                    idleValue = opData.medianIdleTimePerTurnover;
                    if ~isnan(idleValue)
                        operatorMetrics = [operatorMetrics, idleValue];
                    end
                end
            end
        end
    end
    
    metricData{i} = operatorMetrics;
    
    if isempty(operatorMetrics)
        fprintf('Warning: No idle to turnover metrics found for experiment %d\n', i);
    end
end
end

function [metricData, metricLabel, metricUnit] = extractFlipToTurnoverMetrics(experimentResults, showIndividualOps)
% Extract flip to turnover ratio metrics (same as plotAnalysisResults.m)
metricLabel = 'average flips/turnover';
metricUnit = '%';
numExperiments = length(experimentResults);

% Always extract individual operator metrics for box plots (default behavior)
metricData = cell(numExperiments, 1);

for i = 1:numExperiments
    result = experimentResults{i};
    operatorMetrics = [];
    
    if isfield(result, 'analysisResults')
        analysisRes = result.analysisResults;
        if isfield(analysisRes, 'operatorAnalysis')
            opAnalysis = analysisRes.operatorAnalysis;
            if isfield(opAnalysis, 'multiProcedureDayAverages')
                averages = opAnalysis.multiProcedureDayAverages;
                operatorNames = keys(averages);
                
                for j = 1:length(operatorNames)
                    opName = operatorNames{j};
                    opData = averages(opName);
                    
                    % Use same logic as plotAnalysisResults.m
                    if ~isnan(opData.avgFlips) && ~isnan(opData.medianIdleTime) && ~isnan(opData.flipToTurnoverRatio) && opData.multiProcedureDays > 0
                        flipToTurnoverRatioThisOp = opData.flipToTurnoverRatio * 100; % Convert to percentage
                        operatorMetrics = [operatorMetrics, flipToTurnoverRatioThisOp];
                    end
                end
            end
        end
    end
    
    metricData{i} = operatorMetrics;
    
    if isempty(operatorMetrics)
        fprintf('Warning: No flip to turnover metrics found for experiment %d\n', i);
    end
end
end

function [metricData, metricLabel, metricUnit] = extractMakespanMetrics(experimentResults, showIndividualOps)
% Extract makespan metrics
metricLabel = 'average makespan';
metricUnit = 'hours';
numExperiments = length(experimentResults);

if showIndividualOps
    % Extract makespan for each date as individual data points
    metricData = cell(numExperiments, 1);
    
    for i = 1:numExperiments
        result = experimentResults{i};
        dailyMakespans = [];
        
        if isfield(result, 'experimentData')
            expData = result.experimentData;
            if isfield(expData, 'fullResultsContainer')
                resultsContainer = expData.fullResultsContainer;
                dateKeys = keys(resultsContainer);
                
                for j = 1:length(dateKeys)
                    dateStr = dateKeys{j};
                    dayResult = resultsContainer(dateStr);
                    
                    if isfield(dayResult, 'makespan')
                        dailyMakespans = [dailyMakespans, dayResult.makespan / 60]; % Convert to hours
                    end
                end
            end
        end
        
        metricData{i} = dailyMakespans;
        
        if isempty(dailyMakespans)
            fprintf('Warning: No makespan metrics found for experiment %d\n', i);
        end
    end
else
    % Extract average makespan
    metricData = zeros(numExperiments, 1);
    
    for i = 1:numExperiments
        result = experimentResults{i};
        
        if isfield(result, 'analysisResults')
            analysisRes = result.analysisResults;
            if isfield(analysisRes, 'scheduleAnalysis')
                schedAnalysis = analysisRes.scheduleAnalysis;
                if isfield(schedAnalysis, 'avgMakespan')
                    metricData(i) = schedAnalysis.avgMakespan / 60; % Convert to hours
                else
                    fprintf('Warning: No average makespan found for experiment %d\n', i);
                    metricData(i) = NaN;
                end
            else
                fprintf('Warning: No average makespan found for experiment %d\n', i);
                metricData(i) = NaN;
            end
        else
            fprintf('Warning: No average makespan found for experiment %d\n', i);
            metricData(i) = NaN;
        end
    end
end
end

function [metricData, metricLabel, metricUnit] = extractLabUtilizationMetrics(experimentResults, showIndividualOps)
% Extract lab utilization metrics
metricLabel = 'Lab Utilization';
metricUnit = 'percentage';
numExperiments = length(experimentResults);

if showIndividualOps
    % Extract utilization for each date as individual data points
    metricData = cell(numExperiments, 1);
    
    for i = 1:numExperiments
        result = experimentResults{i};
        dailyUtilizations = [];
        
        if isfield(result, 'experimentData')
            expData = result.experimentData;
            if isfield(expData, 'fullResultsContainer')
                resultsContainer = expData.fullResultsContainer;
                dateKeys = keys(resultsContainer);
                
                for j = 1:length(dateKeys)
                    dateStr = dateKeys{j};
                    dayResult = resultsContainer(dateStr);
                    
                    if isfield(dayResult, 'labUtilization')
                        dailyUtilizations = [dailyUtilizations, dayResult.labUtilization * 100]; % Convert to percentage
                    end
                end
            end
        end
        
        metricData{i} = dailyUtilizations;
        
        if isempty(dailyUtilizations)
            fprintf('Warning: No lab utilization metrics found for experiment %d\n', i);
        end
    end
else
    % Extract average lab utilization
    metricData = zeros(numExperiments, 1);
    
    for i = 1:numExperiments
        result = experimentResults{i};
        
        if isfield(result, 'analysisResults')
            analysisRes = result.analysisResults;
            if isfield(analysisRes, 'scheduleAnalysis')
                schedAnalysis = analysisRes.scheduleAnalysis;
                if isfield(schedAnalysis, 'avgLabUtilization')
                    metricData(i) = schedAnalysis.avgLabUtilization * 100; % Convert to percentage
                else
                    fprintf('Warning: No average lab utilization found for experiment %d\n', i);
                    metricData(i) = NaN;
                end
            else
                fprintf('Warning: No average lab utilization found for experiment %d\n', i);
                metricData(i) = NaN;
            end
        else
            fprintf('Warning: No average lab utilization found for experiment %d\n', i);
            metricData(i) = NaN;
        end
    end
end
end

function avgValue = calculateAverageIdleToTurnover(result)
% Calculate average idle to turnover ratio from individual operators
avgValue = NaN;

if isfield(result, 'analysisResults')
    analysisRes = result.analysisResults;
    if isfield(analysisRes, 'comprehensiveOperatorMetrics')
        compMetrics = analysisRes.comprehensiveOperatorMetrics;
        operatorNames = fieldnames(compMetrics);
        
        validValues = [];
        for i = 1:length(operatorNames)
            opName = operatorNames{i};
            opData = compMetrics.(opName);
            
            if isfield(opData, 'medianIdleTimePerTurnover')
                idleValue = opData.medianIdleTimePerTurnover;
                if ~isnan(idleValue)
                    validValues = [validValues, idleValue];
                end
            end
        end
        
        if ~isempty(validValues)
            avgValue = mean(validValues);
        end
    end
end
end

function createBarPlot(metricData, experimentNames, metricLabel, metricUnit, showIndividualOps)
% Create bar plot
if showIndividualOps && iscell(metricData)
    % Create box and whisker plots with separate boxes for each experiment
    allData = [];
    allGroups = [];
    
    for i = 1:length(metricData)
        if ~isempty(metricData{i})
            allData = [allData, metricData{i}];
            allGroups = [allGroups, repmat(i, 1, length(metricData{i}))];
        end
    end
    
    if ~isempty(allData)
        boxplot(allData, allGroups, 'Labels', experimentNames);
        ylabel(sprintf('%s (%s)', metricLabel, metricUnit));
    else
        text(0.5, 0.5, 'No data available', 'HorizontalAlignment', 'center', 'Units', 'normalized');
    end
else
    % Handle both cell array and regular array data
    if iscell(metricData)
        % Create box and whisker plots for each experiment (cell array data)
        allData = [];
        allGroups = [];
        
        for i = 1:length(metricData)
            if ~isempty(metricData{i})
                allData = [allData, metricData{i}];
                allGroups = [allGroups, repmat(i, 1, length(metricData{i}))];
            end
        end
        
        if ~isempty(allData)
            boxplot(allData, allGroups, 'Labels', experimentNames);
            ylabel(sprintf('%s (%s)', metricLabel, metricUnit));
        else
            text(0.5, 0.5, 'No data available', 'HorizontalAlignment', 'center', 'Units', 'normalized');
        end
    else
        % Create simple bar plot for regular array data
        validData = ~isnan(metricData);
        if any(validData)
            bar(find(validData), metricData(validData));
            set(gca, 'XTick', find(validData));
            set(gca, 'XTickLabel', experimentNames(validData));
            ylabel(sprintf('%s (%s)', metricLabel, metricUnit));
            title(sprintf('%s by Experiment', metricLabel));
            grid on;
        else
            text(0.5, 0.5, 'No data available', 'HorizontalAlignment', 'center', 'Units', 'normalized');
        end
    end
end
beautifyBoxPlot(gcf,gca,[4 4]);
end

function createBoxPlot(metricData, experimentNames, metricLabel, metricUnit, showIndividualOps)
% Create box plot
if showIndividualOps && iscell(metricData)
    % Prepare data for box plot with cell array data
    allData = [];
    allGroups = [];
    
    for i = 1:length(metricData)
        if ~isempty(metricData{i})
            allData = [allData, metricData{i}];
            allGroups = [allGroups, repmat(i, 1, length(metricData{i}))];
        end
    end
    
    if ~isempty(allData)
        boxplot(allData, allGroups, 'Labels', experimentNames);
        ylabel(sprintf('%s (%s)', metricLabel, metricUnit));
    else
        text(0.5, 0.5, 'No data available', 'HorizontalAlignment', 'center', 'Units', 'normalized');
    end
else
    % Handle both cell array and regular array data
    allData = [];
    allGroups = [];
    
    if iscell(metricData)
        % For cell array data, create box plot showing distribution across experiments
        for i = 1:length(metricData)
            if ~isempty(metricData{i})
                allData = [allData, metricData{i}];
                allGroups = [allGroups, repmat(i, 1, length(metricData{i}))];
            end
        end
    else
        % For regular array data, treat each experiment as single data point
        for i = 1:length(metricData)
            if ~isnan(metricData(i))
                allData = [allData, metricData(i)];
                allGroups = [allGroups, i];
            end
        end
    end
    
    if ~isempty(allData)
        boxplot(allData, allGroups, 'Labels', experimentNames);
        ylabel(sprintf('%s (%s)', metricLabel, metricUnit));
    else
        text(0.5, 0.5, 'No data available', 'HorizontalAlignment', 'center', 'Units', 'normalized');
    end
end
beautifyBoxPlot(gcf,gca,[4 4]);
end

function createLinePlot(metricData, experimentNames, metricLabel, metricUnit, showIndividualOps)
% Create line plot
if showIndividualOps && iscell(metricData)
    hold on;
    colors = lines(length(metricData));
    
    for i = 1:length(metricData)
        if ~isempty(metricData{i})
            x = 1:length(metricData{i});
            plot(x, metricData{i}, 'o-', 'Color', colors(i,:), 'LineWidth', 2, ...
                'DisplayName', experimentNames{i});
        end
    end
    
    xlabel('Data Point Index');
    ylabel(sprintf('%s (%s)', metricLabel, metricUnit));
    legend('Location', 'best');
    hold off;
else
    % Create line plot connecting average values
    validMask = ~isnan(metricData);
    if any(validMask)
        plot(1:length(metricData), metricData, 'o-', 'LineWidth', 2, 'MarkerSize', 8);
        set(gca, 'XTick', 1:length(experimentNames), 'XTickLabel', experimentNames);
        xtickangle(45);
        ylabel(sprintf('%s (%s)', metricLabel, metricUnit));
        
        % Add value labels
        for i = 1:length(metricData)
            if ~isnan(metricData(i))
                text(i, metricData(i), sprintf('%.2f', metricData(i)), ...
                    'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom');
            end
        end
    else
        text(0.5, 0.5, 'No data available', 'HorizontalAlignment', 'center', 'Units', 'normalized');
    end
end
end

function [metricData, metricLabel, metricUnit] = extractMedianDailyIdleTimeMetrics(experimentResults, showIndividualOps)
% Extract median of total daily idle time metrics (sum across all operators per day)
metricLabel = 'Median Total Daily Idle Time';
metricUnit = 'minutes';
numExperiments = length(experimentResults);

if showIndividualOps
    % Extract total daily idle time for each date as individual data points
    metricData = cell(numExperiments, 1);
    
    for i = 1:numExperiments
        result = experimentResults{i};
        dailyTotalIdleTimes = [];
        
        if isfield(result, 'analysisResults')
            analysisRes = result.analysisResults;
            if isfield(analysisRes, 'scheduleAnalysis')
                schedAnalysis = analysisRes.scheduleAnalysis;
                if isfield(schedAnalysis, 'dailyEfficiency') && isfield(schedAnalysis.dailyEfficiency, 'byDate')
                    dailyEffMap = schedAnalysis.dailyEfficiency.byDate;
                    dateKeys = keys(dailyEffMap);
                    
                    for j = 1:length(dateKeys)
                        dayData = dailyEffMap(dateKeys{j});
                        if isfield(dayData, 'overallDeptTotalOperatorIdleTimeDaily') && ~isnan(dayData.overallDeptTotalOperatorIdleTimeDaily)
                            dailyTotalIdleTimes(end+1) = dayData.overallDeptTotalOperatorIdleTimeDaily;
                        end
                    end
                end
            end
        end
        
        metricData{i} = dailyTotalIdleTimes;
    end
else
    % Extract median of total daily idle times across all dates
    metricData = zeros(numExperiments, 1);
    
    for i = 1:numExperiments
        result = experimentResults{i};
        dailyTotalIdleTimes = [];
        
        if isfield(result, 'analysisResults')
            analysisRes = result.analysisResults;
            if isfield(analysisRes, 'scheduleAnalysis')
                schedAnalysis = analysisRes.scheduleAnalysis;
                if isfield(schedAnalysis, 'dailyEfficiency') && isfield(schedAnalysis.dailyEfficiency, 'byDate')
                    dailyEffMap = schedAnalysis.dailyEfficiency.byDate;
                    dateKeys = keys(dailyEffMap);
                    
                    for j = 1:length(dateKeys)
                        dayData = dailyEffMap(dateKeys{j});
                        if isfield(dayData, 'overallDeptTotalOperatorIdleTimeDaily') && ~isnan(dayData.overallDeptTotalOperatorIdleTimeDaily)
                            dailyTotalIdleTimes(end+1) = dayData.overallDeptTotalOperatorIdleTimeDaily;
                        end
                    end
                end
            end
        end
        
        if ~isempty(dailyTotalIdleTimes)
            metricData(i) = median(dailyTotalIdleTimes);
        else
            fprintf('Warning: No total daily idle time found for experiment %d\n', i);
            metricData(i) = NaN;
        end
    end
end
end

