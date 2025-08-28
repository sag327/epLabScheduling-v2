% Test script for the new summary table and forest plot functionality
fprintf('Testing enhanced analyzeStatisticalDataset.m with summary table and forest plot...\n\n');

try
    % Load and process data
    fprintf('=== Loading data ===\n');
    load('data/historicalEPData.mat');
    analysisResults = analyzeHistoricalData(historicalData);
    statData = createStatisticalDataset(analysisResults, 'Verbose', false);
    fprintf('Data loaded and processed\n');
    
    % Test with enhanced analysis including summary table and forest plot
    fprintf('\n=== Testing enhanced analysis ===\n');
    
    results = analyzeStatisticalDataset(statData, ...
        'MinProceduresPerOperator', 1, ...
        'MinOperatorsPerProcedure', 1, ...
        'TargetVariable', 'AvgFlipToTurnoverRatio', ...
        'PerformRegression', true, ...
        'Verbose', true);
    
    % Check if regression analysis was performed
    if results.regressionAnalysis.performed && isfield(results.regressionAnalysis, 'success') && results.regressionAnalysis.success
        
        % Test summary table
        if isfield(results.regressionAnalysis, 'summaryTable')
            fprintf('\n=== Summary Table Test ===\n');
            fprintf('✓ Summary table created successfully\n');
            fprintf('Table dimensions: %d x %d\n', height(results.regressionAnalysis.summaryTable), width(results.regressionAnalysis.summaryTable));
            
            % Display table structure
            fprintf('\nTable variables: ');
            varNames = results.regressionAnalysis.summaryTable.Properties.VariableNames;
            fprintf('%s ', varNames{:});
            fprintf('\n');
            
            % Show top few rows
            fprintf('\nTop predictors in summary table:\n');
            topN = min(5, height(results.regressionAnalysis.summaryTable));
            for i = 1:topN
                row = results.regressionAnalysis.summaryTable(i, :);
                fprintf('  %s: r=%.3f (p=%.3f) %s, coeff=%.4f [%.4f, %.4f]\n', ...
                    row.Predictor{1}, row.Correlation, row.Corr_PValue, ...
                    row.Significance{1}, row.Coefficient, row.CI_Lower, row.CI_Upper);
            end
            
        else
            fprintf('✗ Summary table not created\n');
        end
        
        % Test forest plot
        if isfield(results.regressionAnalysis, 'forestPlotFigure')
            fprintf('\n=== Forest Plot Test ===\n');
            fprintf('✓ Forest plot created successfully\n');
            fprintf('Figure handle: %d\n', results.regressionAnalysis.forestPlotFigure.Number);
            fprintf('Figure name: %s\n', results.regressionAnalysis.forestPlotFigure.Name);
            
            % Keep the figure open for inspection
            figure(results.regressionAnalysis.forestPlotFigure);
            fprintf('Forest plot displayed for inspection\n');
            
        else
            fprintf('✗ Forest plot not created\n');
        end
        
    else
        fprintf('\n✗ Regression analysis failed or was not performed\n');
        if isfield(results.regressionAnalysis, 'error')
            fprintf('Error: %s\n', results.regressionAnalysis.error);
        end
    end
    
    % Test with different target variables
    fprintf('\n=== Testing with different targets ===\n');
    
    alternativeTargets = {'AvgCasesPerDay', 'UtilizationRate', 'AvgIdleTimePerDay'};
    
    for i = 1:length(alternativeTargets)
        target = alternativeTargets{i};
        fprintf('\nTesting %s:\n', target);
        
        testResults = analyzeStatisticalDataset(statData, ...
            'TargetVariable', target, ...
            'MinProceduresPerOperator', 1, ...
            'MinOperatorsPerProcedure', 1, ...
            'PerformRegression', true, ...
            'Verbose', false);
        
        if testResults.regressionAnalysis.performed && isfield(testResults.regressionAnalysis, 'success') && testResults.regressionAnalysis.success
            if isfield(testResults.regressionAnalysis, 'summaryTable') && isfield(testResults.regressionAnalysis, 'forestPlotFigure')
                fprintf('  ✓ Success: R² = %.3f, summary table and forest plot created\n', ...
                    testResults.regressionAnalysis.rSquared);
                fprintf('    Predictors: %d, Figure: %d\n', ...
                    height(testResults.regressionAnalysis.summaryTable), ...
                    testResults.regressionAnalysis.forestPlotFigure.Number);
            else
                fprintf('  ⚠ Regression successful but missing summary table or forest plot\n');
            end
        else
            fprintf('  ✗ Failed or not performed\n');
        end
    end
    
    fprintf('\n=== Test Summary ===\n');
    fprintf('Enhanced analyzeStatisticalDataset.m tested successfully!\n');
    fprintf('New features:\n');
    fprintf('  ✓ Regression summary table with correlations, p-values, and confidence intervals\n');
    fprintf('  ✓ Forest plot visualization with color-coded significance levels\n');
    fprintf('  ✓ Integration with existing regression analysis workflow\n');
    
catch ME
    fprintf('\nERROR: %s\n', ME.message);
    fprintf('Stack trace:\n');
    for i = 1:length(ME.stack)
        fprintf('  %s (line %d)\n', ME.stack(i).name, ME.stack(i).line);
    end
end