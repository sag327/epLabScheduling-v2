% Simple test to show the comprehensive summary table functionality
fprintf('=== Testing Comprehensive Summary Table ===\n\n');

try
    % Load and prepare data
    load('data/historicalEPData.mat');
    analysisResults = analyzeHistoricalData(historicalData);
    statData = createStatisticalDataset(analysisResults, 'Verbose', false);
    
    % Test with comprehensive analysis
    results = analyzeStatisticalDataset(statData, ...
        'MinProceduresPerOperator', 2, ...
        'MinOperatorsPerProcedure', 2, ...
        'TargetVariable', 'AvgCasesPerDay', ...
        'PerformRegression', true, ...
        'Verbose', false);
    
    if results.regressionAnalysis.performed && isfield(results.regressionAnalysis, 'success') && results.regressionAnalysis.success
        
        reg = results.regressionAnalysis;
        fprintf('✅ REGRESSION SUCCESS: R² = %.3f, p = %.6f\n\n', reg.rSquared, reg.pValue);
        
        if isfield(reg, 'summaryTable') && ismember('InRegression', reg.summaryTable.Properties.VariableNames)
            
            inRegCount = sum(reg.summaryTable.InRegression);
            totalCount = height(reg.summaryTable);
            
            fprintf('📊 COMPREHENSIVE SUMMARY TABLE:\n');
            fprintf('Total variables tested: %d\n', totalCount);
            fprintf('Variables used in regression: %d\n\n', inRegCount);
            
            % Show detailed breakdown
            sigCount = sum(reg.summaryTable.Corr_PValue < 0.05);
            strongCorr = sum(abs(reg.summaryTable.Correlation) >= 0.7 & reg.summaryTable.Corr_PValue < 0.05);
            moderateCorr = sum(abs(reg.summaryTable.Correlation) >= 0.5 & abs(reg.summaryTable.Correlation) < 0.7 & reg.summaryTable.Corr_PValue < 0.05);
            
            fprintf('Statistical Summary:\n');
            fprintf('  Statistically significant correlations: %d/%d (%.1f%%)\n', sigCount, totalCount, 100*sigCount/totalCount);
            fprintf('  Strong correlations (|r| ≥ 0.7, p < 0.05): %d\n', strongCorr);
            fprintf('  Moderate correlations (0.5 ≤ |r| < 0.7, p < 0.05): %d\n', moderateCorr);
            fprintf('  Variables selected for regression: %d\n', inRegCount);
            fprintf('  Variables NOT in regression: %d\n\n', totalCount - inRegCount);
            
            % Show table with detailed formatting
            fprintf('%-30s %8s %8s %5s %6s %10s %12s %12s\n', ...
                'Predictor', 'Corr', 'p-val', 'Sig', 'InReg', 'Coeff', 'CI_Lower', 'CI_Upper');
            fprintf('%s\n', repmat('-', 100, 1));
            
            % Show top 20 correlations
            for i = 1:min(20, height(reg.summaryTable))
                row = reg.summaryTable(i, :);
                
                % Format predictor name
                predName = row.Predictor{1};
                if length(predName) > 30
                    predName = [predName(1:27) '...'];
                end
                
                % Format regression status
                inRegStr = '';
                if row.InRegression
                    inRegStr = 'YES';
                else
                    inRegStr = 'no';
                end
                
                % Format coefficients
                coeffStr = '';
                ciLowStr = '';
                ciHighStr = '';
                if ~isnan(row.Coefficient)
                    coeffStr = sprintf('%10.4f', row.Coefficient);
                    ciLowStr = sprintf('%12.4f', row.CI_Lower);
                    ciHighStr = sprintf('%12.4f', row.CI_Upper);
                else
                    coeffStr = '      N/A';
                    ciLowStr = '        N/A';
                    ciHighStr = '        N/A';
                end
                
                fprintf('%-30s %8.3f %8.3f %5s %6s %s %s %s\n', ...
                    predName, row.Correlation, row.Corr_PValue, row.Significance{1}, ...
                    inRegStr, coeffStr, ciLowStr, ciHighStr);
            end
            
            if height(reg.summaryTable) > 20
                fprintf('... (%d more variables not shown)\n', height(reg.summaryTable) - 20);
            end
            
            fprintf('\n✅ SUCCESS: Summary table now includes ALL %d tested correlations!\n', totalCount);
            fprintf('Previously, only the %d regression predictors would have been shown.\n', inRegCount);
            
        else
            fprintf('❌ Summary table missing or missing InRegression column\n');
        end
        
    else
        fprintf('❌ Regression analysis failed\n');
        if isfield(results.regressionAnalysis, 'error')
            fprintf('Error: %s\n', results.regressionAnalysis.error);
        end
    end
    
catch ME
    fprintf('❌ ERROR: %s\n', ME.message);
    for i = 1:length(ME.stack)
        fprintf('  %s (line %d)\n', ME.stack(i).name, ME.stack(i).line);
    end
end