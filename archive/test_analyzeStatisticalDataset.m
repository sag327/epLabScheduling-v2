% Test script for analyzeStatisticalDataset.m
% This script tests the statistical analysis function with sample data

fprintf('Testing analyzeStatisticalDataset.m...\n\n');

try
    % Test 1: Load existing statistical data
    fprintf('=== Test 1: Loading statistical data ===\n');
    
    % Check if we have existing statistical data
    if exist('statisticalData.csv', 'file')
        fprintf('Loading data from CSV...\n');
        dataTable = readtable('statisticalData.csv');
        
        % Convert to the expected structure format
        testStatData = struct();
        testStatData.operatorTable = dataTable;
        
        fprintf('Data loaded successfully - %d operators, %d variables\n', ...
            height(dataTable), width(dataTable));
    else
        fprintf('No existing CSV found, generating sample data...\n');
        
        % Create minimal sample data for testing
        testStatData = createSampleStatisticalData();
        fprintf('Sample data created - %d operators\n', length(testStatData.operatorTable.OperatorName));
    end
    
    % Test 2: Basic analysis with default parameters
    fprintf('\n=== Test 2: Basic analysis with regression ===\n');
    
    results1 = analyzeStatisticalDataset(testStatData);
    
    fprintf('Analysis completed with default parameters\n');
    fprintf('Results summary:\n');
    fprintf('  Total procedure types: %d\n', results1.summaryStats.totalProcedureTypes);
    fprintf('  Analyzed procedure types: %d\n', results1.summaryStats.analyzedProcedureTypes);
    fprintf('  Skipped procedure types: %d\n', results1.summaryStats.skippedProcedureTypes);
    
    if isfield(results1, 'regressionAnalysis') && results1.regressionAnalysis.performed
        if isfield(results1.regressionAnalysis, 'success') && results1.regressionAnalysis.success
            fprintf('  Regression analysis performed: Success\n');
            fprintf('    R² = %.3f, p = %.4f\n', results1.regressionAnalysis.rSquared, results1.regressionAnalysis.pValue);
        else
            fprintf('  Regression analysis performed: Failed\n');
        end
    else
        fprintf('  Regression analysis: Not performed\n');
    end
    
    % Test 3: Stricter filtering
    fprintf('\n=== Test 3: Stricter filtering ===\n');
    
    results2 = analyzeStatisticalDataset(testStatData, ...
        'MinProceduresPerOperator', 10, ...
        'MinOperatorsPerProcedure', 5, ...
        'Verbose', true);
    
    fprintf('Stricter analysis completed\n');
    fprintf('Results with stricter filtering:\n');
    fprintf('  Analyzed procedure types: %d\n', results2.summaryStats.analyzedProcedureTypes);
    
    % Test 4: Specific procedure types
    fprintf('\n=== Test 4: Specific procedure analysis ===\n');
    
    % Get some available procedure names
    if results1.summaryStats.analyzedProcedureTypes > 0
        testProcedures = results1.summaryStats.analyzedProcedureNames(1:min(2, end));
        
        results3 = analyzeStatisticalDataset(testStatData, ...
            'ProcedureTypes', testProcedures, ...
            'MinProceduresPerOperator', 3, ...
            'Verbose', true);
        
        fprintf('Specific procedure analysis completed\n');
        fprintf('Focused on procedures: %s\n', strjoin(testProcedures, ', '));
    else
        fprintf('No procedures available for specific analysis test\n');
    end
    
    % Test 5: Custom target variable for regression
    fprintf('\n=== Test 5: Custom target variable ===\n');
    
    results4 = analyzeStatisticalDataset(testStatData, ...
        'TargetVariable', 'AvgCasesPerDay', ...
        'MinProceduresPerOperator', 3, ...
        'Verbose', true);
    
    fprintf('Custom target analysis completed\n');
    
    % Test 6: Regression disabled
    fprintf('\n=== Test 6: Regression disabled ===\n');
    
    results5 = analyzeStatisticalDataset(testStatData, ...
        'PerformRegression', false, ...
        'Verbose', false);
    
    if results5.regressionAnalysis.performed
        fprintf('Analysis without regression: Failed to disable\n');
    else
        fprintf('Analysis without regression: Successfully disabled\n');
    end
    
    % Test 7: Export functionality
    fprintf('\n=== Test 7: Export functionality ===\n');
    
    results6 = analyzeStatisticalDataset(testStatData, ...
        'ExportResults', true, ...
        'OutputFile', 'test_analysis_results.mat', ...
        'Verbose', false);
    
    if exist('test_analysis_results.mat', 'file')
        fprintf('Export successful - file created\n');
        delete('test_analysis_results.mat'); % Clean up
    else
        fprintf('Export failed - file not created\n');
    end
    
    fprintf('\n=== All Tests Completed Successfully ===\n');
    
catch ME
    fprintf('\nERROR during testing: %s\n', ME.message);
    fprintf('Stack trace:\n');
    for i = 1:length(ME.stack)
        fprintf('  %s (line %d)\n', ME.stack(i).name, ME.stack(i).line);
    end
end

function testStatData = createSampleStatisticalData()
% Create sample statistical data for testing when real data isn't available

fprintf('Creating sample statistical dataset...\n');

% Create sample data with 10 operators
numOps = 10;
operatorNames = cell(numOps, 1);
for i = 1:numOps
    operatorNames{i} = sprintf('TestOperator_%d', i);
end

% Initialize basic fields
data = struct();
data.OperatorName = operatorNames;
data.OperatorID = (1:numOps)';
data.TotalCases = randi([50, 200], numOps, 1);
data.TotalWorkingDays = randi([30, 100], numOps, 1);

% Add realistic variables for regression testing
data.AvgCasesPerDay = data.TotalCases ./ data.TotalWorkingDays + 0.5*randn(numOps, 1);
data.AvgFlipToTurnoverRatio = 25 + 15*randn(numOps, 1); % Main target variable
data.AvgIdleTimePerDay = 100 + 50*randn(numOps, 1);
data.AvgOvertimePerDay = max(0, 20 + 30*randn(numOps, 1));
data.UtilizationRate = 0.7 + 0.2*randn(numOps, 1);
data.AvgIdleTimePerTurnover = 30 + 20*randn(numOps, 1);
data.MultiProcedureDaysPct = 100*rand(numOps, 1);
data.AvgProcedureTime = 60 + 30*randn(numOps, 1);
data.AvgSetupTime = 25 + 10*randn(numOps, 1);
data.AvgPostTime = 15 + 8*randn(numOps, 1);

% Add some procedure-specific count fields
procedureTypes = {'ABLATION_ATRIALFIBRILLATION', 'PMIMPLANTDUAL', 'ICDIMPLANTDUAL'};

for p = 1:length(procedureTypes)
    procName = procedureTypes{p};
    
    % Generate realistic procedure counts (some operators have 0)
    counts = zeros(numOps, 1);
    activeOps = rand(numOps, 1) > 0.3; % 70% of operators do this procedure
    counts(activeOps) = randi([1, 25], sum(activeOps), 1);
    
    data.(['Proc_' procName '_Count']) = counts;
    data.(['Proc_' procName '_Proportion']) = counts ./ data.TotalCases;
    
    % Add duration metrics (only for operators who do the procedure)
    avgDuration = nan(numOps, 1);
    medianDuration = nan(numOps, 1);
    avgSetup = nan(numOps, 1);
    avgPost = nan(numOps, 1);
    
    hasProc = counts > 0;
    avgDuration(hasProc) = 60 + 40 * randn(sum(hasProc), 1);
    medianDuration(hasProc) = avgDuration(hasProc) + 10 * randn(sum(hasProc), 1);
    avgSetup(hasProc) = 30 + 10 * randn(sum(hasProc), 1);
    avgPost(hasProc) = 15 + 5 * randn(sum(hasProc), 1);
    
    data.(['Proc_' procName '_AvgDuration']) = avgDuration;
    data.(['Proc_' procName '_MedianDuration']) = medianDuration;
    data.(['Proc_' procName '_AvgSetup']) = avgSetup;
    data.(['Proc_' procName '_AvgPost']) = avgPost;
end

% Convert to table
dataTable = struct2table(data);

% Create structure in expected format
testStatData = struct();
testStatData.operatorTable = dataTable;

fprintf('Sample data created with %d operators and %d procedure types\n', ...
    numOps, length(procedureTypes));

end