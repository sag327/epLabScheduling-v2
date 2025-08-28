function analysisResults = analyzeStatisticalDataset(statisticalData, varargin)
% Analyze statistical dataset with filtering based on procedure counts
% Version: 1.0.0
%
% This function performs statistical analysis on the output from createStatisticalDataset.m
% with configurable filtering parameters to ensure meaningful analysis.
%
% Inputs:
%   statisticalData - Output structure from createStatisticalDataset.m
%
% Optional Parameters:
%   'MinProceduresPerOperator' - Minimum number of procedures of each type 
%                                an operator must have to be included (default: 10)
%   'MinOperatorsPerProcedure' - Minimum number of operators with required 
%                                procedure count for analysis (default: 5)
%   'ProcedureTypes' - Cell array of specific procedure types to analyze 
%                      (default: analyze all available)
%   'TargetVariable' - Variable of interest for regression analysis 
%                      (default: 'AvgFlipToTurnoverRatio')
%   'PerformRegression' - Perform multi-variable regression analysis (default: true)
%   'Verbose' - Show detailed output (default: true)
%   'ExportResults' - Export results to file (default: false)
%   'OutputFile' - Results filename (default: 'statistical_analysis_results.mat')
%
% Output:
%   analysisResults - Structure containing:
%     .filteredData - Filtered dataset used for analysis
%     .procedureAnalysis - Analysis results for each procedure type
%     .summaryStats - Overall summary statistics
%     .filteringStats - Information about filtering applied
%     .regressionAnalysis - Multi-variable regression results
%     .parameters - Analysis parameters used
%
% Example:
%   % Load statistical data
%   load('data/historicalEPData.mat');
%   analysisResults = analyzeHistoricalData(historicalData);
%   statData = createStatisticalDataset(analysisResults);
%   
%   % Analyze with default parameters
%   results = analyzeStatisticalDataset(statData);
%   
%   % Analyze with custom filtering
%   results = analyzeStatisticalDataset(statData, ...
%       'MinProceduresPerOperator', 10, ...
%       'MinOperatorsPerProcedure', 5, ...
%       'ProcedureTypes', {'ABLATION_ATRIALFIBRILLATION', 'PMIMPLANTDUAL'});

% Parse input parameters
p = inputParser;
addRequired(p, 'statisticalData', @isstruct);
addParameter(p, 'MinProceduresPerOperator', 10, @(x) isnumeric(x) && x > 0);
addParameter(p, 'MinOperatorsPerProcedure', 5, @(x) isnumeric(x) && x > 0);
addParameter(p, 'ProcedureTypes', {}, @iscell);
addParameter(p, 'TargetVariable', 'AvgFlipToTurnoverRatio', @ischar);
addParameter(p, 'PerformRegression', true, @islogical);
addParameter(p, 'Verbose', true, @islogical);
addParameter(p, 'ExportResults', false, @islogical);
addParameter(p, 'OutputFile', 'statistical_analysis_results.mat', @ischar);

parse(p, statisticalData, varargin{:});

minProcPerOp = p.Results.MinProceduresPerOperator;
minOpsPerProc = p.Results.MinOperatorsPerProcedure;
procedureTypes = p.Results.ProcedureTypes;
targetVariable = p.Results.TargetVariable;
performRegression = p.Results.PerformRegression;
verbose = p.Results.Verbose;
exportResults = p.Results.ExportResults;
outputFile = p.Results.OutputFile;

% Initialize output structure
analysisResults = struct();
analysisResults.parameters = struct();
analysisResults.parameters.MinProceduresPerOperator = minProcPerOp;
analysisResults.parameters.MinOperatorsPerProcedure = minOpsPerProc;
analysisResults.parameters.ProcedureTypes = procedureTypes;
analysisResults.parameters.TargetVariable = targetVariable;
analysisResults.parameters.PerformRegression = performRegression;
analysisResults.parameters.Verbose = verbose;

if verbose
    fprintf('Analyzing statistical dataset...\n');
    fprintf('Parameters:\n');
    fprintf('  Min procedures per operator: %d\n', minProcPerOp);
    fprintf('  Min operators per procedure: %d\n', minOpsPerProc);
end

% Validate input
if ~isfield(statisticalData, 'operatorTable')
    error('statisticalData must contain operatorTable field from createStatisticalDataset.m');
end

% Get data table
if istable(statisticalData.operatorTable)
    dataTable = statisticalData.operatorTable;
    data = table2struct(dataTable, 'ToScalar', true);
else
    data = statisticalData.operatorTable;
end

numOperators = length(data.OperatorName);

if verbose
    fprintf('Total operators in dataset: %d\n', numOperators);
end

% Identify procedure-specific count fields
allFields = fieldnames(data);
procCountFields = allFields(contains(allFields, 'Proc_') & contains(allFields, '_Count'));

% Extract procedure names
procedureNames = {};
for i = 1:length(procCountFields)
    fieldName = procCountFields{i};
    procName = regexprep(fieldName, '^Proc_(.+)_Count$', '$1');
    procedureNames{end+1} = procName;
end

% Filter procedure types if specified
if ~isempty(procedureTypes)
    validProcTypes = {};
    for i = 1:length(procedureTypes)
        if any(strcmp(procedureNames, procedureTypes{i}))
            validProcTypes{end+1} = procedureTypes{i};
        else
            if verbose
                fprintf('Warning: Procedure type "%s" not found in dataset\n', procedureTypes{i});
            end
        end
    end
    procedureNames = validProcTypes;
end

if verbose
    fprintf('Analyzing %d procedure types\n', length(procedureNames));
end

% Initialize analysis results
analysisResults.procedureAnalysis = struct();
analysisResults.filteringStats = struct();
analysisResults.filteringStats.totalOperators = numOperators;
analysisResults.filteringStats.analyzedProcedures = procedureNames;

% Analyze each procedure type
for p = 1:length(procedureNames)
    procName = procedureNames{p};
    countField = ['Proc_' procName '_Count'];
    
    if verbose
        fprintf('\nAnalyzing procedure: %s\n', procName);
    end
    
    % Get procedure counts for all operators
    procCounts = data.(countField);
    
    % Find operators with sufficient procedures
    validOperators = procCounts >= minProcPerOp;
    numValidOps = sum(validOperators);
    
    if verbose
        fprintf('  Operators with >= %d procedures: %d\n', minProcPerOp, numValidOps);
    end
    
    % Check if we have enough operators for analysis
    if numValidOps < minOpsPerProc
        if verbose
            fprintf('  Skipping - insufficient operators (need %d, have %d)\n', minOpsPerProc, numValidOps);
        end
        analysisResults.procedureAnalysis.(procName) = struct();
        analysisResults.procedureAnalysis.(procName).analyzed = false;
        analysisResults.procedureAnalysis.(procName).reason = sprintf('Insufficient operators (%d < %d)', numValidOps, minOpsPerProc);
        continue;
    end
    
    % Create filtered dataset for this procedure
    filteredIndices = find(validOperators);
    
    % Initialize procedure analysis
    procAnalysis = struct();
    procAnalysis.analyzed = true;
    procAnalysis.numOperators = numValidOps;
    procAnalysis.operatorNames = data.OperatorName(filteredIndices);
    procAnalysis.filteredIndices = filteredIndices;
    
    % Get all related fields for this procedure
    procFields = allFields(contains(allFields, ['Proc_' procName '_']));
    
    % Extract metrics for valid operators
    procMetrics = struct();
    for f = 1:length(procFields)
        fieldName = procFields{f};
        metricName = regexprep(fieldName, ['^Proc_' procName '_'], '');
        
        fieldData = data.(fieldName);
        validData = fieldData(validOperators);
        
        % Remove NaN values for statistical calculations
        validData = validData(~isnan(validData));
        
        if ~isempty(validData)
            procMetrics.(metricName) = struct();
            procMetrics.(metricName).data = validData;
            procMetrics.(metricName).n = length(validData);
            procMetrics.(metricName).mean = mean(validData);
            procMetrics.(metricName).median = median(validData);
            procMetrics.(metricName).std = std(validData);
            procMetrics.(metricName).min = min(validData);
            procMetrics.(metricName).max = max(validData);
            procMetrics.(metricName).p25 = prctile(validData, 25);
            procMetrics.(metricName).p75 = prctile(validData, 75);
            procMetrics.(metricName).p90 = prctile(validData, 90);
        end
    end
    
    procAnalysis.metrics = procMetrics;
    
    % Calculate operator performance rankings
    if isfield(procMetrics, 'Count') && isfield(procMetrics, 'AvgDuration')
        countData = procMetrics.Count.data;
        durationData = procMetrics.AvgDuration.data;
        
        % Efficiency score (higher count, lower duration is better)
        if length(countData) == length(durationData) && all(durationData > 0)
            efficiencyScore = countData ./ durationData;
            procAnalysis.efficiencyRankings = struct();
            procAnalysis.efficiencyRankings.scores = efficiencyScore;
            procAnalysis.efficiencyRankings.operators = procAnalysis.operatorNames;
            
            % Sort by efficiency
            [sortedScores, sortIdx] = sort(efficiencyScore, 'descend');
            procAnalysis.efficiencyRankings.rankedOperators = procAnalysis.operatorNames(sortIdx);
            procAnalysis.efficiencyRankings.rankedScores = sortedScores;
        end
    end
    
    % Store procedure analysis
    analysisResults.procedureAnalysis.(procName) = procAnalysis;
    
    if verbose
        fprintf('  Analysis complete - %d operators included\n', numValidOps);
        if isfield(procMetrics, 'Count')
            fprintf('    Count: mean=%.1f, median=%.1f, range=[%.0f-%.0f]\n', ...
                procMetrics.Count.mean, procMetrics.Count.median, ...
                procMetrics.Count.min, procMetrics.Count.max);
        end
        if isfield(procMetrics, 'AvgDuration')
            fprintf('    Avg Duration: mean=%.1f min, median=%.1f min, range=[%.1f-%.1f] min\n', ...
                procMetrics.AvgDuration.mean, procMetrics.AvgDuration.median, ...
                procMetrics.AvgDuration.min, procMetrics.AvgDuration.max);
        end
    end
end

% Create summary statistics across all analyzed procedures
analyzedProcNames = {};
for p = 1:length(procedureNames)
    procName = procedureNames{p};
    if isfield(analysisResults.procedureAnalysis, procName) && ...
       analysisResults.procedureAnalysis.(procName).analyzed
        analyzedProcNames{end+1} = procName;
    end
end

analysisResults.summaryStats = struct();
analysisResults.summaryStats.totalProcedureTypes = length(procedureNames);
analysisResults.summaryStats.analyzedProcedureTypes = length(analyzedProcNames);
analysisResults.summaryStats.skippedProcedureTypes = length(procedureNames) - length(analyzedProcNames);
analysisResults.summaryStats.analyzedProcedureNames = analyzedProcNames;

% Calculate cross-procedure statistics
if ~isempty(analyzedProcNames)
    crossProcStats = struct();
    
    % Operator participation across procedures
    allParticipatingOps = {};
    for p = 1:length(analyzedProcNames)
        procName = analyzedProcNames{p};
        allParticipatingOps = [allParticipatingOps; analysisResults.procedureAnalysis.(procName).operatorNames];
    end
    
    [uniqueOps, ~, idx] = unique(allParticipatingOps);
    participationCounts = accumarray(idx, 1);
    
    crossProcStats.uniqueOperators = length(uniqueOps);
    crossProcStats.operatorNames = uniqueOps;
    crossProcStats.procedureParticipation = participationCounts;
    crossProcStats.avgParticipationPerOperator = mean(participationCounts);
    
    analysisResults.summaryStats.crossProcedureStats = crossProcStats;
end

% Perform multi-variable regression analysis
if performRegression
    if verbose
        fprintf('\n=== REGRESSION ANALYSIS ===\n');
        fprintf('Target variable: %s\n', targetVariable);
    end
    
    analysisResults.regressionAnalysis = performRegressionAnalysis(data, targetVariable, verbose);
else
    analysisResults.regressionAnalysis = struct();
    analysisResults.regressionAnalysis.performed = false;
end

% Store filtered data information
analysisResults.filteredData = struct();
analysisResults.filteredData.originalOperators = numOperators;
analysisResults.filteredData.parameters = analysisResults.parameters;

if verbose
    fprintf('\n=== ANALYSIS SUMMARY ===\n');
    fprintf('Total procedure types: %d\n', analysisResults.summaryStats.totalProcedureTypes);
    fprintf('Analyzed procedure types: %d\n', analysisResults.summaryStats.analyzedProcedureTypes);
    fprintf('Skipped procedure types: %d\n', analysisResults.summaryStats.skippedProcedureTypes);
    
    if isfield(analysisResults.summaryStats, 'crossProcedureStats')
        fprintf('Unique operators in analysis: %d\n', analysisResults.summaryStats.crossProcedureStats.uniqueOperators);
        fprintf('Avg procedures per operator: %.1f\n', analysisResults.summaryStats.crossProcedureStats.avgParticipationPerOperator);
    end
    
    fprintf('\nAnalyzed procedures:\n');
    for i = 1:length(analyzedProcNames)
        procName = analyzedProcNames{i};
        numOps = analysisResults.procedureAnalysis.(procName).numOperators;
        fprintf('  %s: %d operators\n', procName, numOps);
    end
end

% Export results if requested
if exportResults
    if verbose
        fprintf('\nExporting results to: %s\n', outputFile);
    end
    save(outputFile, 'analysisResults');
    analysisResults.exportFile = outputFile;
end

if verbose
    fprintf('\nAnalysis completed successfully!\n');
end

end

function regressionResults = performRegressionAnalysis(data, targetVariable, verbose)
% Perform multi-variable regression analysis to identify correlates
% of the target variable (default: AvgFlipToTurnoverRatio)

regressionResults = struct();
regressionResults.performed = true;
regressionResults.targetVariable = targetVariable;

% Check if target variable exists
if ~isfield(data, targetVariable)
    if verbose
        fprintf('Warning: Target variable "%s" not found in data\n', targetVariable);
    end
    regressionResults.performed = false;
    regressionResults.error = sprintf('Target variable "%s" not found', targetVariable);
    return;
end

% Get target variable data
targetData = data.(targetVariable);
validTargetIdx = ~isnan(targetData) & ~isinf(targetData);

if sum(validTargetIdx) < 5
    if verbose
        fprintf('Warning: Insufficient valid target data (need >= 5, have %d)\n', sum(validTargetIdx));
    end
    regressionResults.performed = false;
    regressionResults.error = 'Insufficient valid target data';
    return;
end

% Identify potential predictor variables with focus on general metrics and key procedures
allFields = fieldnames(data);
excludeFields = {'OperatorName', 'OperatorID', targetVariable};

% Define priority fields - general performance metrics and key procedures
generalPerformanceMetrics = {
    'TotalWorkingDays', 'TotalCases', 'AvgCasesPerDay', 'MedianCasesPerDay', 'StdCasesPerDay', ...
    'AvgIdleTimePerDay', 'MedianIdleTimePerDay', 'StdIdleTimePerDay', ...
    'P25IdleTimePerDay', 'P75IdleTimePerDay', 'P90IdleTimePerDay', ...
    'AvgOvertimePerDay', 'MedianOvertimePerDay', 'StdOvertimePerDay', ...
    'AvgWorkTimePerDay', 'MedianWorkTimePerDay', ...
    'AvgFlipToTurnoverRatio', 'MedianFlipToTurnoverRatio', 'StdFlipToTurnoverRatio', ...
    'P25FlipToTurnoverRatio', 'P75FlipToTurnoverRatio', 'P90FlipToTurnoverRatio', ...
    'AvgCasesPerHour', 'UtilizationRate', ...
    'AvgIdleTimePerTurnover', 'MedianIdleTimePerTurnover', 'StdIdleTimePerTurnover', ...
    'MultiProcedureDays', 'MultiProcedureDaysPct', 'DaysWithOvertime', 'DaysWithOvertimePct', ...
    'InpatientCases', 'OutpatientCases', 'InpatientProportion', 'OutpatientProportion', ...
    'UniqueProcedureTypes', 'ProcedureDiversityIndex', ...
    'AvgProcedureTime', 'MedianProcedureTime', 'StdProcedureTime', ...
    'AvgSetupTime', 'MedianSetupTime', 'StdSetupTime', ...
    'AvgPostTime', 'MedianPostTime', 'StdPostTime'
};

% Key procedure types to include (atrial fibrillation and dual chamber pacemaker)
keyProcedurePatterns = {
    'Proc_ABLATION_ATRIALFIBRILLATION_', 
    'Proc_PMIMPLANTDUAL_'
};

potentialPredictors = {};
for i = 1:length(allFields)
    fieldName = allFields{i};
    
    % Skip excluded fields
    if any(strcmp(fieldName, excludeFields))
        continue;
    end
    
    % Determine if field should be included
    includeField = false;
    
    % Include general performance metrics
    if any(strcmp(fieldName, generalPerformanceMetrics))
        includeField = true;
    end
    
    % Include key procedure-specific fields
    for p = 1:length(keyProcedurePatterns)
        if startsWith(fieldName, keyProcedurePatterns{p})
            includeField = true;
            break;
        end
    end
    
    % Skip if not in priority list
    if ~includeField
        continue;
    end
    
    % Check if field is numeric and has sufficient valid data
    fieldData = data.(fieldName);
    if isnumeric(fieldData)
        validFieldIdx = ~isnan(fieldData) & ~isinf(fieldData);
        commonValidIdx = validTargetIdx & validFieldIdx;
        
        if sum(commonValidIdx) >= 3 % Lowered threshold for better analysis
            % Check for sufficient variance
            commonFieldData = fieldData(commonValidIdx);
            if std(commonFieldData) > 1e-10 % Not constant
                potentialPredictors{end+1} = fieldName;
            end
        end
    end
end

if verbose
    fprintf('Found %d potential predictor variables\n', length(potentialPredictors));
    
    % Count different types of predictors
    generalCount = 0;
    afCount = 0;
    pmCount = 0;
    
    for i = 1:length(potentialPredictors)
        varName = potentialPredictors{i};
        if any(strcmp(varName, generalPerformanceMetrics))
            generalCount = generalCount + 1;
        elseif startsWith(varName, 'Proc_ABLATION_ATRIALFIBRILLATION_')
            afCount = afCount + 1;
        elseif startsWith(varName, 'Proc_PMIMPLANTDUAL_')
            pmCount = pmCount + 1;
        end
    end
    
    fprintf('  General performance metrics: %d\n', generalCount);
    fprintf('  Atrial fibrillation metrics: %d\n', afCount);
    fprintf('  Dual chamber pacemaker metrics: %d\n', pmCount);
end

if length(potentialPredictors) < 1
    regressionResults.performed = false;
    regressionResults.error = 'No suitable predictor variables found';
    return;
end

% Calculate correlations with target variable
correlations = struct();
correlations.variables = potentialPredictors;
correlations.coefficients = zeros(length(potentialPredictors), 1);
correlations.pValues = zeros(length(potentialPredictors), 1);

targetValidData = targetData(validTargetIdx);

for i = 1:length(potentialPredictors)
    predVar = potentialPredictors{i};
    predData = data.(predVar);
    
    % Find common valid indices
    predValidIdx = ~isnan(predData) & ~isinf(predData);
    commonIdx = validTargetIdx & predValidIdx;
    
    if sum(commonIdx) >= 5
        commonTarget = targetData(commonIdx);
        commonPred = predData(commonIdx);
        
        [r, p] = corr(commonTarget, commonPred, 'Type', 'Pearson');
        correlations.coefficients(i) = r;
        correlations.pValues(i) = p;
    else
        correlations.coefficients(i) = NaN;
        correlations.pValues(i) = NaN;
    end
end

% Sort by absolute correlation strength
[~, sortIdx] = sort(abs(correlations.coefficients), 'descend', 'MissingPlacement', 'last');
correlations.rankedVariables = correlations.variables(sortIdx);
correlations.rankedCoefficients = correlations.coefficients(sortIdx);
correlations.rankedPValues = correlations.pValues(sortIdx);

% Filter out perfect/near-perfect correlations to avoid multicollinearity
perfectCorrThreshold = 0.99;
validForRegression = ~isnan(correlations.rankedCoefficients) & ...
                    abs(correlations.rankedCoefficients) < perfectCorrThreshold;

% Also check for multicollinearity among predictors themselves
filteredVars = {};
filteredCoeffs = [];
filteredPVals = [];

for i = 1:length(correlations.rankedVariables)
    if ~validForRegression(i)
        continue; % Skip invalid or perfect correlations with target
    end
    
    currentVar = correlations.rankedVariables{i};
    currentCoeff = correlations.rankedCoefficients(i);
    currentPVal = correlations.rankedPValues(i);
    
    % Check correlation with already selected predictors
    addVariable = true;
    for j = 1:length(filteredVars)
        % Calculate correlation between current variable and already selected ones
        existingVar = filteredVars{j};
        
        % Get data for both variables
        currentData = data.(currentVar);
        existingData = data.(existingVar);
        
        % Find common valid indices
        currentValidIdx = ~isnan(currentData) & ~isinf(currentData) & validTargetIdx;
        existingValidIdx = ~isnan(existingData) & ~isinf(existingData) & validTargetIdx;
        commonIdx = currentValidIdx & existingValidIdx;
        
        if sum(commonIdx) >= 3
            [rPred, ~] = corr(currentData(commonIdx), existingData(commonIdx), 'Type', 'Pearson');
            if abs(rPred) >= perfectCorrThreshold
                addVariable = false;
                if verbose
                    fprintf('  Excluding %s (r=%.3f with %s, avoiding multicollinearity)\n', ...
                        currentVar, rPred, existingVar);
                end
                break;
            end
        end
    end
    
    if addVariable
        filteredVars{end+1} = currentVar;
        filteredCoeffs(end+1) = currentCoeff;
        filteredPVals(end+1) = currentPVal;
    end
end

% Update correlation structure with filtered results
correlations.filteredVariables = filteredVars;
correlations.filteredCoefficients = filteredCoeffs;
correlations.filteredPValues = filteredPVals;

% Select top predictors for regression (max 10 or 1/3 of observations)
maxPredictors = min(10, floor(sum(validTargetIdx) / 3));
numValidCorrelations = length(filteredVars);

if numValidCorrelations == 0
    regressionResults.performed = false;
    regressionResults.error = 'No valid correlations found after filtering perfect correlations';
    return;
end

numPredictors = min(maxPredictors, numValidCorrelations);
selectedPredictors = filteredVars(1:numPredictors);

if verbose
    fprintf('Selected %d predictors for regression analysis (after filtering multicollinearity)\n', numPredictors);
    fprintf('Top correlations:\n');
    for i = 1:min(5, numPredictors)
        fprintf('  %s: r=%.3f, p=%.3f\n', ...
            filteredVars{i}, ...
            filteredCoeffs(i), ...
            filteredPVals(i));
    end
    
    % Report filtering statistics
    numExcluded = length(correlations.rankedVariables) - length(filteredVars);
    if numExcluded > 0
        fprintf('Excluded %d variables due to perfect/near-perfect correlations (|r| >= %.2f)\n', ...
            numExcluded, perfectCorrThreshold);
    end
end

% Build regression matrix
regressionMatrix = zeros(sum(validTargetIdx), numPredictors);
commonValidIdx = validTargetIdx;

for i = 1:numPredictors
    predVar = selectedPredictors{i};
    predData = data.(predVar);
    
    % Update common valid indices
    predValidIdx = ~isnan(predData) & ~isinf(predData);
    commonValidIdx = commonValidIdx & predValidIdx;
end

% Final check for sufficient data
if sum(commonValidIdx) < numPredictors + 2
    if verbose
        fprintf('Warning: Insufficient observations for regression (%d needed, %d available)\n', ...
            numPredictors + 2, sum(commonValidIdx));
    end
    regressionResults.performed = false;
    regressionResults.error = 'Insufficient observations for regression';
    return;
end

% Extract final data for regression
finalTarget = targetData(commonValidIdx);
finalPredictors = zeros(length(finalTarget), numPredictors);

for i = 1:numPredictors
    predVar = selectedPredictors{i};
    finalPredictors(:, i) = data.(predVar)(commonValidIdx);
end

% Perform multiple linear regression
try
    % Ensure data is properly formatted and check for any issues
    if any(~isfinite(finalTarget)) || any(~isfinite(finalPredictors(:)))
        error('Input data contains non-finite values (NaN or Inf)');
    end
    
    % Check for constant predictors
    for i = 1:size(finalPredictors, 2)
        if std(finalPredictors(:, i)) < 1e-12
            error('Predictor %d (%s) is essentially constant', i, selectedPredictors{i});
        end
    end
    
    % Prepare design matrix (add intercept column)
    X = [ones(length(finalTarget), 1), finalPredictors];
    
    % Use regress function with proper error checking
    [b, bint, r, rint, stats] = regress(finalTarget, X);
    
    regressionResults.success = true;
    regressionResults.coefficients = b;
    regressionResults.confidenceIntervals = bint;
    regressionResults.residuals = r;
    regressionResults.residualIntervals = rint;
    regressionResults.stats = stats; % [R^2, F-stat, p-value, error variance]
    regressionResults.selectedPredictors = selectedPredictors;
    regressionResults.numObservations = length(finalTarget);
    regressionResults.rSquared = stats(1);
    regressionResults.fStat = stats(2);
    regressionResults.pValue = stats(3);
    
    % Create summary table for regression results (including ALL tested correlations)
    % Create a comprehensive summary table including all correlations, not just those used in regression
    regressionResults.summaryTable = createComprehensiveRegressionSummaryTable(...
        correlations.variables, correlations.coefficients, correlations.pValues, ...
        selectedPredictors, b(2:end), bint(2:end, :), targetVariable);
    
    
    if verbose
        fprintf('\nRegression Results:\n');
        fprintf('R² = %.3f, F = %.2f, p = %.4f\n', stats(1), stats(2), stats(3));
        fprintf('Number of observations: %d\n', length(finalTarget));
        
        % Display summary table
        fprintf('\n=== Regression Summary Table ===\n');
        disp(regressionResults.summaryTable);
        
        fprintf('\nCoefficients:\n');
        fprintf('  Intercept: %.4f [%.4f, %.4f]\n', b(1), bint(1,1), bint(1,2));
        for i = 1:numPredictors
            fprintf('  %s: %.4f [%.4f, %.4f]\n', ...
                selectedPredictors{i}, b(i+1), bint(i+1,1), bint(i+1,2));
        end
    end
    
catch ME
    regressionResults.success = false;
    regressionResults.error = ME.message;
    
    if verbose
        fprintf('Regression failed: %s\n', ME.message);
    end
end

% Store correlation results
regressionResults.correlationAnalysis = correlations;

end

function summaryTable = createRegressionSummaryTable(predictorNames, correlations, correlationPValues, coefficients, confidenceIntervals, targetVariable)
% Create a summary table of regression results with correlations and confidence intervals

numPredictors = length(predictorNames);

% Create table data
Predictor = predictorNames(:);
Correlation = correlations(:);
Correlation_PValue = correlationPValues(:);
Regression_Coefficient = coefficients(:);
CI_Lower = confidenceIntervals(:, 1);
CI_Upper = confidenceIntervals(:, 2);
CI_Width = CI_Upper - CI_Lower;

% Calculate significance indicators
Correlation_Significant = Correlation_PValue < 0.05;
Significant = cell(numPredictors, 1);
for i = 1:numPredictors
    if Correlation_Significant(i)
        if abs(Correlation(i)) >= 0.7
            Significant{i} = '***'; % Strong significant correlation
        elseif abs(Correlation(i)) >= 0.5
            Significant{i} = '**';  % Moderate significant correlation
        else
            Significant{i} = '*';   % Weak significant correlation
        end
    else
        Significant{i} = '';        % Not significant
    end
end

% Create the table
summaryTable = table(Predictor, Correlation, Correlation_PValue, Significant, ...
    Regression_Coefficient, CI_Lower, CI_Upper, CI_Width, ...
    'VariableNames', {'Predictor', 'Correlation', 'Corr_PValue', 'Significance', ...
    'Coefficient', 'CI_Lower', 'CI_Upper', 'CI_Width'});

% Sort by absolute correlation strength
[~, sortIdx] = sort(abs(summaryTable.Correlation), 'descend');
summaryTable = summaryTable(sortIdx, :);

end

function summaryTable = createComprehensiveRegressionSummaryTable(allPredictorNames, allCorrelations, allCorrelationPValues, selectedPredictors, selectedCoefficients, selectedConfidenceIntervals, targetVariable)
% Create a comprehensive summary table including ALL tested correlations and regression results for selected predictors

numAllPredictors = length(allPredictorNames);

% Create table data for all predictors
Predictor = allPredictorNames(:);
Correlation = allCorrelations(:);
Corr_PValue = allCorrelationPValues(:);

% Initialize regression columns with NaN
Coefficient = nan(numAllPredictors, 1);
CI_Lower = nan(numAllPredictors, 1);
CI_Upper = nan(numAllPredictors, 1);
InRegression = false(numAllPredictors, 1);

% Fill in regression results for selected predictors
for i = 1:length(selectedPredictors)
    % Find index of this selected predictor in the all predictors list
    idx = find(strcmp(allPredictorNames, selectedPredictors{i}), 1);
    if ~isempty(idx)
        Coefficient(idx) = selectedCoefficients(i);
        CI_Lower(idx) = selectedConfidenceIntervals(i, 1);
        CI_Upper(idx) = selectedConfidenceIntervals(i, 2);
        InRegression(idx) = true;
    end
end

CI_Width = CI_Upper - CI_Lower;

% Calculate significance indicators based on correlation p-values
Correlation_Significant = Corr_PValue < 0.05;
Significance = cell(numAllPredictors, 1);
for i = 1:numAllPredictors
    if Correlation_Significant(i)
        if abs(Correlation(i)) >= 0.7
            Significance{i} = '***'; % Strong significant correlation
        elseif abs(Correlation(i)) >= 0.5
            Significance{i} = '**';  % Moderate significant correlation
        else
            Significance{i} = '*';   % Weak significant correlation
        end
    else
        Significance{i} = '';        % Not significant
    end
end

% Create the comprehensive table
summaryTable = table(Predictor, Correlation, Corr_PValue, Significance, ...
    InRegression, Coefficient, CI_Lower, CI_Upper, CI_Width, ...
    'VariableNames', {'Predictor', 'Correlation', 'Corr_PValue', 'Significance', ...
    'InRegression', 'Coefficient', 'CI_Lower', 'CI_Upper', 'CI_Width'});

% Sort by absolute correlation strength (strongest first)
[~, sortIdx] = sort(abs(summaryTable.Correlation), 'descend');
summaryTable = summaryTable(sortIdx, :);

end
