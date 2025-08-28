% Test corrected flip-to-turnover ratio calculation
% Version: 2.1.0

fprintf('=== Testing Corrected Flip-to-Turnover Ratio Calculation ===\n');

% Load and analyze data
load('data/historicalEPData.mat');
fprintf('Testing corrected flip-to-turnover ratio calculation...\n');
analysisResults = analyzeHistoricalData(historicalData);

if isfield(analysisResults, 'comprehensiveOperatorMetrics')
    fprintf('✓ Comprehensive metrics available\n');
    opNames = fieldnames(analysisResults.comprehensiveOperatorMetrics);
    
    fprintf('\nSampling first 5 operators to verify filtering:\n');
    for i = 1:min(5, length(opNames))
        opName = opNames{i};
        opMetrics = analysisResults.comprehensiveOperatorMetrics.(opName);
        
        fprintf('\n%s:\n', opMetrics.name);
        fprintf('  Total cases: %d\n', opMetrics.totalCases);
        fprintf('  Working days: %d\n', opMetrics.workingDays);
        fprintf('  Multi-procedure days: %d\n', opMetrics.multiProcedureDays);
        
        if ~isempty(opMetrics.dailyCaseCounts)
            fprintf('  Daily case counts length: %d\n', length(opMetrics.dailyCaseCounts));
            multiProcDays = sum(opMetrics.dailyCaseCounts > 1);
            fprintf('  Multi-proc days (calculated): %d\n', multiProcDays);
        end
        
        if ~isempty(opMetrics.dailyFlipRatios)
            fprintf('  Daily flip ratios count: %d (should match multi-proc days)\n', length(opMetrics.dailyFlipRatios));
            fprintf('  Flip ratio - Mean: %.1f%%, Median: %.1f%%, Std: %.1f%%\n', ...
                opMetrics.avgFlipToTurnoverRatio, opMetrics.medianFlipToTurnoverRatio, opMetrics.stdFlipToTurnoverRatio);
            
            % Verify the logic: flip ratios should only be from multi-procedure days
            expectedFlipRatios = opMetrics.multiProcedureDays;
            actualFlipRatios = length(opMetrics.dailyFlipRatios);
            
            if actualFlipRatios <= expectedFlipRatios
                fprintf('  ✓ Flip ratio filtering working correctly (%d <= %d)\n', actualFlipRatios, expectedFlipRatios);
            else
                fprintf('  ⚠ Flip ratio count higher than expected (%d > %d)\n', actualFlipRatios, expectedFlipRatios);
            end
        else
            fprintf('  No flip ratios calculated (operator may not have multi-procedure days with flips)\n');
        end
        
        if ~isempty(opMetrics.dailyIdleTimePerTurnover)
            fprintf('  Daily idle/turnover count: %d (should also match multi-proc days)\n', length(opMetrics.dailyIdleTimePerTurnover));
            fprintf('  Idle/turnover - Mean: %.1f min, Median: %.1f min\n', ...
                opMetrics.avgIdleTimePerTurnover, opMetrics.medianIdleTimePerTurnover);
        else
            fprintf('  No idle time per turnover calculated\n');
        end
    end
    
    fprintf('\n=== Summary ===\n');
    fprintf('Both flip-to-turnover ratio and idle time per turnover should now only\n');
    fprintf('include data from days where the operator had more than one procedure.\n');
    fprintf('Test complete!\n');
    
else
    fprintf('✗ No comprehensive metrics available\n');
end