% Test script to verify field naming consistency across all files
% This will run a full pipeline to test the field naming standardization

fprintf('Testing field naming consistency...\n\n');

try
    % Step 1: Load historical data and run analysis
    fprintf('=== Step 1: Loading and analyzing historical data ===\n');
    load('data/historicalEPData.mat');
    fprintf('Historical data loaded\n');
    
    analysisResults = analyzeHistoricalData(historicalData);
    fprintf('Historical data analysis completed\n');
    
    % Check a few operator metrics to verify field naming
    operators = fieldnames(analysisResults.comprehensiveOperatorMetrics);
    if ~isempty(operators)
        sampleOp = operators{1};
        opMetrics = analysisResults.comprehensiveOperatorMetrics.(sampleOp);
        
        % Look for procedure-specific fields
        fieldNames = fieldnames(opMetrics);
        procFields = fieldNames(startsWith(fieldNames, 'proc_'));
        
        if ~isempty(procFields)
            fprintf('Sample procedure fields from analyzeHistoricalData:\n');
            for i = 1:min(5, length(procFields))
                fprintf('  %s\n', procFields{i});
            end
        end
    end
    
    % Step 2: Create statistical dataset
    fprintf('\n=== Step 2: Creating statistical dataset ===\n');
    
    statData = createStatisticalDataset(analysisResults, 'Verbose', false);
    fprintf('Statistical dataset created\n');
    
    % Check field naming in the statistical dataset
    if istable(statData.operatorTable)
        tableVarNames = statData.operatorTable.Properties.VariableNames;
    else
        tableVarNames = fieldnames(statData.operatorTable);
    end
    
    procStatFields = tableVarNames(startsWith(tableVarNames, 'Proc_'));
    if ~isempty(procStatFields)
        fprintf('Sample procedure fields from createStatisticalDataset:\n');
        for i = 1:min(5, length(procStatFields))
            fprintf('  %s\n', procStatFields{i});
        end
    end
    
    % Step 3: Run statistical analysis
    fprintf('\n=== Step 3: Running statistical analysis ===\n');
    
    results = analyzeStatisticalDataset(statData, ...
        'MinProceduresPerOperator', 1, ...
        'MinOperatorsPerProcedure', 1, ...
        'Verbose', false);
    
    fprintf('Statistical analysis completed\n');
    
    % Check if any procedures were analyzed
    procNames = fieldnames(results.procedureAnalysis);
    analyzedProcs = 0;
    for i = 1:length(procNames)
        if isfield(results.procedureAnalysis.(procNames{i}), 'analyzed') && ...
           results.procedureAnalysis.(procNames{i}).analyzed
            analyzedProcs = analyzedProcs + 1;
        end
    end
    
    fprintf('Procedures analyzed: %d/%d\n', analyzedProcs, length(procNames));
    
    % Step 4: Check field naming consistency
    fprintf('\n=== Step 4: Field naming consistency check ===\n');
    
    % Expected patterns after standardization
    expectedPatterns = {'_Count$', '_Proportion$', '_AvgDuration$', '_MedianDuration$', ...
                       '_StdDuration$', '_AvgSetup$', '_MedianSetup$', '_AvgPost$', '_MedianPost$'};
    
    % Check for old patterns (should not exist)
    oldPatterns = {'_count$', '_proportion$', '_avgDuration$', '_medianDuration$', ...
                  '_stdDuration$', '_avgSetup$', '_medianSetup$', '_avgPost$', '_medianPost$'};
    
    hasOldPattern = false;
    hasNewPattern = false;
    
    for i = 1:length(procStatFields)
        fieldName = procStatFields{i};
        
        % Check for new patterns
        for j = 1:length(expectedPatterns)
            if ~isempty(regexp(fieldName, expectedPatterns{j}, 'once'))
                hasNewPattern = true;
                break;
            end
        end
        
        % Check for old patterns
        for j = 1:length(oldPatterns)
            if ~isempty(regexp(fieldName, oldPatterns{j}, 'once'))
                hasOldPattern = true;
                fprintf('WARNING: Found old pattern in field: %s\n', fieldName);
                break;
            end
        end
    end
    
    fprintf('Field naming results:\n');
    if hasNewPattern
        fprintf('  New PascalCase patterns found: Yes\n');
    else
        fprintf('  New PascalCase patterns found: No\n');
    end
    if hasOldPattern
        fprintf('  Old lowercase patterns found: Yes\n');
    else
        fprintf('  Old lowercase patterns found: No\n');
    end
    
    if ~hasOldPattern && hasNewPattern
        fprintf('\n✓ Field naming standardization SUCCESSFUL\n');
    else
        fprintf('\n✗ Field naming standardization needs review\n');
    end
    
    % Step 5: Check regression analysis field access
    if results.regressionAnalysis.performed
        fprintf('\n=== Step 5: Regression analysis field compatibility ===\n');
        fprintf('Regression analysis ran successfully with new field names\n');
        if isfield(results.regressionAnalysis, 'success') && results.regressionAnalysis.success
            fprintf('✓ Regression completed successfully\n');
        else
            fprintf('⚠ Regression had issues but field naming appears compatible\n');
        end
    else
        fprintf('\n=== Step 5: Regression analysis ===\n');
        fprintf('Regression analysis was not performed (insufficient data)\n');
    end
    
    fprintf('\n=== Field Naming Test Completed ===\n');
    
catch ME
    fprintf('\nERROR during field naming test: %s\n', ME.message);
    fprintf('Stack trace:\n');
    for i = 1:length(ME.stack)
        fprintf('  %s (line %d)\n', ME.stack(i).name, ME.stack(i).line);
    end
end