% Test script specifically for the improved regression analysis
fprintf('Testing focused regression analysis...\n\n');

try
    % Load historical data and run analysis
    fprintf('=== Loading and analyzing data ===\n');
    load('data/historicalEPData.mat');
    analysisResults = analyzeHistoricalData(historicalData);
    statData = createStatisticalDataset(analysisResults, 'Verbose', false);
    fprintf('Data loaded and processed\n');
    
    % Test the updated regression analysis with focus on general metrics
    fprintf('\n=== Testing improved regression analysis ===\n');
    
    results = analyzeStatisticalDataset(statData, ...
        'MinProceduresPerOperator', 1, ...
        'MinOperatorsPerProcedure', 1, ...
        'TargetVariable', 'AvgFlipToTurnoverRatio', ...
        'PerformRegression', true, ...
        'Verbose', true);
    
    fprintf('\n=== Regression Results Summary ===\n');
    if isfield(results, 'regressionAnalysis') && results.regressionAnalysis.performed
        reg = results.regressionAnalysis;
        
        if isfield(reg, 'success') && reg.success
            fprintf('✓ Regression analysis SUCCESSFUL\n');
            fprintf('R² = %.3f (%.1f%% of variance explained)\n', reg.rSquared, reg.rSquared*100);
            fprintf('F-statistic = %.2f, p-value = %.6f\n', reg.fStat, reg.pValue);
            fprintf('Number of observations: %d\n', reg.numObservations);
            fprintf('Number of predictors: %d\n', length(reg.selectedPredictors));
            
            fprintf('\nTop predictors selected:\n');
            for i = 1:min(5, length(reg.selectedPredictors))
                fprintf('  %d. %s\n', i, reg.selectedPredictors{i});
            end
            
            if reg.pValue < 0.05
                fprintf('\n✓ Model is statistically significant (p < 0.05)\n');
            else
                fprintf('\n⚠ Model is not statistically significant (p >= 0.05)\n');
            end
            
        elseif isfield(reg, 'error')
            fprintf('✗ Regression failed: %s\n', reg.error);
        else
            fprintf('✗ Regression completed but success status unknown\n');
        end
    else
        fprintf('✗ Regression analysis was not performed\n');
        if isfield(results, 'regressionAnalysis') && isfield(results.regressionAnalysis, 'error')
            fprintf('Error: %s\n', results.regressionAnalysis.error);
        end
    end
    
    % Test with different target variables
    fprintf('\n=== Testing different target variables ===\n');
    
    targetVars = {'AvgCasesPerDay', 'AvgIdleTimePerDay', 'UtilizationRate'};
    
    for i = 1:length(targetVars)
        fprintf('\nTesting target: %s\n', targetVars{i});
        
        testResults = analyzeStatisticalDataset(statData, ...
            'TargetVariable', targetVars{i}, ...
            'MinProceduresPerOperator', 1, ...
            'MinOperatorsPerProcedure', 1, ...
            'Verbose', false);
        
        if testResults.regressionAnalysis.performed
            if isfield(testResults.regressionAnalysis, 'success') && testResults.regressionAnalysis.success
                fprintf('  ✓ Success: R² = %.3f, p = %.4f\n', ...
                    testResults.regressionAnalysis.rSquared, ...
                    testResults.regressionAnalysis.pValue);
            else
                fprintf('  ✗ Failed: %s\n', testResults.regressionAnalysis.error);
            end
        else
            fprintf('  ✗ Not performed: %s\n', testResults.regressionAnalysis.error);
        end
    end
    
    fprintf('\n=== Test completed ===\n');
    
catch ME
    fprintf('\nERROR: %s\n', ME.message);
    fprintf('Stack trace:\n');
    for i = 1:length(ME.stack)
        fprintf('  %s (line %d)\n', ME.stack(i).name, ME.stack(i).line);
    end
end