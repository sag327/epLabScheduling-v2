% Debug why dailyFlipRatios is empty despite multi-procedure days
% Focused on Stephen Gaeta with 3-day dataset
% Version: 1.0.0

fprintf('=== Debugging Daily Flip Ratios Issue ===\n');

% This diagnostic assumes you're using testProcedureDurations-3day.xlsx
if ~exist('historicalSchedules', 'var')
    fprintf('ERROR: historicalSchedules variable not found in workspace\n');
    fprintf('Load testProcedureDurations-3day.xlsx and create historicalSchedules first\n');
    return;
end

% Load data
load('data/historicalEPData.mat');

% Run analysis
fprintf('Running analyzeHistoricalData with 3-day dataset...\n');
analysisResults = analyzeHistoricalData(historicalData, 'HistoricalSchedules', historicalSchedules, 'ShowStats', false);

% Focus on Stephen Gaeta
targetOperator = 'Stephen Gaeta';
safeOpName = matlab.lang.makeValidName(targetOperator);

fprintf('\n=== Checking %s ===\n', targetOperator);

% Check if operator exists in comprehensive metrics
if isfield(analysisResults, 'comprehensiveOperatorMetrics') && ...
   isfield(analysisResults.comprehensiveOperatorMetrics, safeOpName)
    
    opData = analysisResults.comprehensiveOperatorMetrics.(safeOpName);
    
    fprintf('Multi-procedure days: %d\n', opData.multiProcedureDays);
    
    % Check daily case counts
    if isfield(opData, 'dailyCaseCounts')
        fprintf('dailyCaseCounts: [%s] (length: %d)\n', ...
            mat2str(opData.dailyCaseCounts), length(opData.dailyCaseCounts));
        multiProcMask = opData.dailyCaseCounts > 1;
        fprintf('Days with >1 case: %d\n', sum(multiProcMask));
        if any(multiProcMask)
            fprintf('Multi-proc case counts: [%s]\n', mat2str(opData.dailyCaseCounts(multiProcMask)));
        end
    else
        fprintf('❌ dailyCaseCounts field missing\n');
    end
    
    % Check daily flip ratios
    if isfield(opData, 'dailyFlipRatios')
        fprintf('dailyFlipRatios: [%s] (length: %d)\n', ...
            mat2str(opData.dailyFlipRatios), length(opData.dailyFlipRatios));
        if isempty(opData.dailyFlipRatios)
            fprintf('❌ PROBLEM: dailyFlipRatios is empty!\n');
        end
    else
        fprintf('❌ dailyFlipRatios field missing\n');
    end
    
    % Check if lab flip analysis exists
    fprintf('\n=== Checking Lab Flip Analysis ===\n');
    if isfield(analysisResults, 'labFlipAnalysis')
        fprintf('✅ labFlipAnalysis exists\n');
        
        if isfield(analysisResults.labFlipAnalysis, 'operatorFlipStats')
            fprintf('✅ operatorFlipStats exists\n');
            flipStats = analysisResults.labFlipAnalysis.operatorFlipStats;
            
            if isKey(flipStats, targetOperator)
                fprintf('✅ %s found in operatorFlipStats\n', targetOperator);
                flipArray = flipStats(targetOperator);
                fprintf('Flip array: [%s] (length: %d)\n', mat2str(flipArray), length(flipArray));
                
                % Check if flip array has valid data
                validFlips = ~isnan(flipArray);
                fprintf('Valid flip entries: %d\n', sum(validFlips));
                if any(validFlips)
                    fprintf('Valid flip values: [%s]\n', mat2str(flipArray(validFlips)));
                end
            else
                fprintf('❌ %s NOT found in operatorFlipStats\n', targetOperator);
                flipKeys = keys(flipStats);
                fprintf('Available operators in flipStats: %s\n', strjoin(flipKeys, ', '));
            end
        else
            fprintf('❌ operatorFlipStats field missing\n');
        end
    else
        fprintf('❌ labFlipAnalysis field missing\n');
    end
    
    % Check the calculation logic manually
    fprintf('\n=== Manual Calculation Check ===\n');
    if isfield(opData, 'dailyCaseCounts') && ...
       isfield(analysisResults, 'labFlipAnalysis') && ...
       isfield(analysisResults.labFlipAnalysis, 'operatorFlipStats') && ...
       isKey(analysisResults.labFlipAnalysis.operatorFlipStats, targetOperator)
        
        caseCounts = opData.dailyCaseCounts;
        flipArray = analysisResults.labFlipAnalysis.operatorFlipStats(targetOperator);
        
        fprintf('Attempting manual calculation:\n');
        manualFlipRatios = [];
        
        for i = 1:length(caseCounts)
            cases = caseCounts(i);
            if i <= length(flipArray)
                flips = flipArray(i);
            else
                flips = NaN;
            end
            
            fprintf('  Day %d: %d cases, %.0f flips', i, cases, flips);
            
            if cases > 1 && ~isnan(flips)
                turnovers = cases - 1;
                flipRatio = flips / turnovers;
                manualFlipRatios(end+1) = flipRatio;
                fprintf(' -> Ratio: %.3f (%.1f%%)\n', flipRatio, flipRatio * 100);
            else
                fprintf(' -> No ratio (need >1 case and valid flips)\n');
            end
        end
        
        fprintf('Expected dailyFlipRatios (as percentages): [%s]\n', mat2str(manualFlipRatios * 100));
        
        if isempty(manualFlipRatios)
            fprintf('❌ Manual calculation also produces empty array!\n');
            fprintf('Root cause: Either no multi-procedure days OR no valid flip data\n');
        else
            fprintf('✅ Expected %d flip ratio values\n', length(manualFlipRatios));
        end
    else
        fprintf('Cannot perform manual calculation - missing required data\n');
    end
    
else
    fprintf('❌ %s not found in comprehensive metrics\n', targetOperator);
    if isfield(analysisResults, 'comprehensiveOperatorMetrics')
        availableOps = fieldnames(analysisResults.comprehensiveOperatorMetrics);
        fprintf('Available operators: %s\n', strjoin(availableOps, ', '));
    end
end

fprintf('\n=== SUMMARY ===\n');
fprintf('This diagnostic will help identify if the issue is:\n');
fprintf('1. Missing lab flip analysis data\n');
fprintf('2. Operator name mismatch in flip stats\n');
fprintf('3. Array length mismatch between cases and flips\n');
fprintf('4. Logic error in flip ratio calculation\n');

fprintf('\nDiagnostic complete!\n');