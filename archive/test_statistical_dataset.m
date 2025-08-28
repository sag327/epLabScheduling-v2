% Test script for the comprehensive statistical dataset creation
% Version: 2.1.0
%
% This script demonstrates how to use createStatisticalDataset.m for
% predictive modeling and statistical analysis of EP lab operator performance

fprintf('=== EP Lab Statistical Dataset Test ===\n\n');

%% Step 1: Load and analyze historical data
fprintf('Step 1: Loading historical data...\n');

% Load historical data (adjust path as needed)
try
    load('data/historicalEPData.mat');
    fprintf('  Loaded historical data with %d cases\n', length(historicalData.caseID));
catch
    fprintf('  Error: Could not load historical data. Please ensure data files are available.\n');
    fprintf('  This test requires historicalEPData.mat to be present.\n');
    return;
end

%% Step 2: Perform comprehensive analysis
fprintf('\nStep 2: Performing comprehensive analysis...\n');

try
    analysisResults = analyzeHistoricalData(historicalData);
    fprintf('  Analysis completed successfully\n');
    
    % Check if we have operator analysis
    if isfield(analysisResults, 'operatorAnalysis')
        operatorNames = fieldnames(analysisResults.operatorAnalysis);
        fprintf('  Found %d operators in analysis\n', length(operatorNames));
    else
        fprintf('  Warning: No operator analysis found\n');
        return;
    end
catch ME
    fprintf('  Error during analysis: %s\n', ME.message);
    return;
end

%% Step 3: Create comprehensive statistical dataset
fprintf('\nStep 3: Creating comprehensive statistical dataset...\n');

try
    % Create the dataset with all options enabled
    statisticalData = createStatisticalDataset(analysisResults, ...
        'ExportToCSV', true, ...
        'OutputFile', 'ep_lab_statistical_dataset.csv', ...
        'ExportToTable', true, ...
        'IncludeCorrelations', true, ...
        'Verbose', true);
    
    fprintf('  Statistical dataset created successfully!\n');
    
catch ME
    fprintf('  Error creating statistical dataset: %s\n', ME.message);
    return;
end

%% Step 4: Explore the dataset structure
fprintf('\nStep 4: Exploring dataset structure...\n');

if isfield(statisticalData, 'operatorTable')
    dataTable = statisticalData.operatorTable;
    fprintf('  Dataset dimensions: %d operators × %d variables\n', ...
        height(dataTable), width(dataTable));
    
    % Display variable categories
    varNames = dataTable.Properties.VariableNames;
    
    % Categorize variables
    performanceVars = varNames(contains(varNames, {'Idle', 'Flip', 'Utilization', 'Overtime', 'Cases'}));
    procedureVars = varNames(contains(varNames, 'Proc_'));
    caseVars = varNames(contains(varNames, {'Inpatient', 'Outpatient', 'Diversity'}));
    
    fprintf('  Performance metrics: %d variables\n', length(performanceVars));
    fprintf('  Procedure-specific metrics: %d variables\n', length(procedureVars));
    fprintf('  Case mix metrics: %d variables\n', length(caseVars));
    
    % Show first few rows
    fprintf('\n  First 5 operators (key metrics):\n');
    keyVars = {'OperatorName', 'TotalCases', 'AvgIdleTimePerTurnover', 'AvgFlipToTurnoverRatio', 'UtilizationRate'};
    availableKeyVars = intersect(keyVars, varNames, 'stable');
    
    if ~isempty(availableKeyVars)
        disp(dataTable(1:min(5, height(dataTable)), availableKeyVars));
    end
end

%% Step 5: Demonstrate statistical analysis examples
fprintf('\nStep 5: Example statistical analyses...\n');

if isfield(statisticalData, 'operatorTable') && height(statisticalData.operatorTable) > 3
    dataTable = statisticalData.operatorTable;
    
    % Example 1: Correlation between idle time and flip-to-turnover ratio
    if ismember('AvgIdleTimePerDay', dataTable.Properties.VariableNames) && ...
       ismember('AvgFlipToTurnoverRatio', dataTable.Properties.VariableNames)
        
        idleTime = dataTable.AvgIdleTimePerDay;
        flipRatio = dataTable.AvgFlipToTurnoverRatio;
        
        % Remove NaN values for correlation
        validIdx = ~isnan(idleTime) & ~isnan(flipRatio);
        if sum(validIdx) > 2
            corrCoeff = corr(idleTime(validIdx), flipRatio(validIdx));
            fprintf('  Example 1: Correlation between idle time and flip ratio: r = %.3f\n', corrCoeff);
        end
    end
    
    % Example 2: Mean comparison between high and low case volume operators
    if ismember('TotalCases', dataTable.Properties.VariableNames) && ...
       ismember('UtilizationRate', dataTable.Properties.VariableNames)
        
        totalCases = dataTable.TotalCases;
        utilizationRate = dataTable.UtilizationRate;
        
        medianCases = median(totalCases);
        highVolumeOps = utilizationRate(totalCases >= medianCases);
        lowVolumeOps = utilizationRate(totalCases < medianCases);
        
        if ~isempty(highVolumeOps) && ~isempty(lowVolumeOps)
            highVolMean = mean(highVolumeOps, 'omitnan');
            lowVolMean = mean(lowVolumeOps, 'omitnan');
            fprintf('  Example 2: Utilization - High volume ops: %.1f%%, Low volume ops: %.1f%%\n', ...
                highVolMean*100, lowVolMean*100);
        end
    end
    
    % Example 3: Procedure diversity analysis
    if ismember('ProcedureDiversityIndex', dataTable.Properties.VariableNames) && ...
       ismember('AvgIdleTimePerDay', dataTable.Properties.VariableNames)
        
        diversityIndex = dataTable.ProcedureDiversityIndex;
        idleTime = dataTable.AvgIdleTimePerDay;
        
        validIdx = ~isnan(diversityIndex) & ~isnan(idleTime);
        if sum(validIdx) > 2
            corrCoeff = corr(diversityIndex(validIdx), idleTime(validIdx));
            fprintf('  Example 3: Correlation between procedure diversity and idle time: r = %.3f\n', corrCoeff);
        end
    end
    
    % Example 4: Idle time per turnover analysis (key efficiency metric)
    if ismember('AvgIdleTimePerTurnover', dataTable.Properties.VariableNames) && ...
       ismember('AvgFlipToTurnoverRatio', dataTable.Properties.VariableNames)
        
        idlePerTurnover = dataTable.AvgIdleTimePerTurnover;
        flipRatio = dataTable.AvgFlipToTurnoverRatio;
        
        validIdx = ~isnan(idlePerTurnover) & ~isnan(flipRatio);
        if sum(validIdx) > 2
            corrCoeff = corr(idlePerTurnover(validIdx), flipRatio(validIdx));
            fprintf('  Example 4: Correlation between idle time per turnover and flip ratio: r = %.3f\n', corrCoeff);
            
            % Show summary stats for this key metric
            validIdlePerTurnover = idlePerTurnover(validIdx);
            if ~isempty(validIdlePerTurnover)
                fprintf('    Idle time per turnover: mean=%.1f min, median=%.1f min, range=%.1f-%.1f min\n', ...
                    mean(validIdlePerTurnover), median(validIdlePerTurnover), ...
                    min(validIdlePerTurnover), max(validIdlePerTurnover));
            end
        end
    end
end

%% Step 6: Display correlation matrix highlights
fprintf('\nStep 6: Key correlations with operator efficiency...\n');

if isfield(statisticalData, 'correlationMatrix') && ~isempty(statisticalData.correlationMatrix)
    corrMatrix = statisticalData.correlationMatrix.matrix;
    varNames = statisticalData.correlationMatrix.variableNames;
    
    % Find correlations with key performance metrics
    performanceMetrics = {'AvgFlipToTurnoverRatio', 'UtilizationRate', 'AvgIdleTimePerTurnover', 'AvgIdleTimePerDay'};
    
    for pm = 1:length(performanceMetrics)
        perfMetric = performanceMetrics{pm};
        
        if ismember(perfMetric, varNames)
            perfIdx = find(strcmp(varNames, perfMetric));
            correlations = corrMatrix(perfIdx, :);
            
            % Sort by absolute correlation value
            [sortedCorr, sortIdx] = sort(abs(correlations), 'descend');
            
            fprintf('\n  Top correlations with %s:\n', perfMetric);
            
            % Show top 5 correlations (excluding self-correlation)
            count = 0;
            for i = 1:length(sortIdx)
                idx = sortIdx(i);
                if count >= 5 || sortedCorr(i) < 0.1
                    break;
                end
                
                if ~strcmp(varNames{idx}, perfMetric) % Skip self-correlation
                    fprintf('    %s: r = %.3f\n', varNames{idx}, correlations(idx));
                    count = count + 1;
                end
            end
        end
    end
end

%% Step 7: Summary and recommendations
fprintf('\n=== Summary and Statistical Modeling Recommendations ===\n');
fprintf('\nThis comprehensive dataset enables various statistical analyses:\n\n');

fprintf('1. PREDICTIVE MODELING:\n');
fprintf('   - Predict operator idle time using case mix, procedure types, and scheduling patterns\n');
fprintf('   - Model flip-to-turnover ratios based on procedure complexity and operator experience\n');
fprintf('   - Forecast overtime risk using historical patterns and case volumes\n\n');

fprintf('2. CORRELATION ANALYSIS:\n');
fprintf('   - Identify procedure types associated with higher/lower efficiency\n');
fprintf('   - Analyze relationships between case diversity and operator performance\n');
fprintf('   - Examine inpatient/outpatient mix effects on scheduling efficiency\n\n');

fprintf('3. REGRESSION MODELING:\n');
fprintf('   - Multiple regression to identify key predictors of operator efficiency\n');
fprintf('   - Logistic regression for binary outcomes (overtime vs. no overtime)\n');
fprintf('   - Time series analysis for trend identification\n\n');

fprintf('4. CLUSTERING ANALYSIS:\n');
fprintf('   - Group operators by performance profiles\n');
fprintf('   - Identify operator archetypes based on case mix and efficiency\n');
fprintf('   - Segment operators for targeted interventions\n\n');

if isfield(statisticalData, 'exportFiles') && ~isempty(statisticalData.exportFiles)
    fprintf('EXPORTED FILES:\n');
    for i = 1:length(statisticalData.exportFiles)
        fprintf('  - %s\n', statisticalData.exportFiles{i});
    end
    fprintf('\nThese files can be imported into R, Python, SPSS, or other statistical software.\n');
end

fprintf('\nTest completed successfully!\n');