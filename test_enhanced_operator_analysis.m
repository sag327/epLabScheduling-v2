function test_enhanced_operator_analysis()
% Test the enhanced operator metrics analysis functionality

fprintf('=== TESTING ENHANCED OPERATOR ANALYSIS ===\n');

try
    % Load historical data
    fprintf('Loading historical data...\n');
    [historicalData, schedules] = loadHistoricalDataFromFile();
    
    fprintf('Loaded %d cases from historical data\n', length(historicalData.caseID));
    
    % Test basic operator metrics analysis (without schedules)
    fprintf('\n--- Testing basic operator metrics analysis ---\n');
    resultsBasic = analyzeHistoricalData(historicalData, 'ShowStats', false);
    
    % Verify the new fields exist
    if isfield(resultsBasic, 'operatorMetrics')
        fprintf('✓ operatorMetrics field exists\n');
        operatorNames = fieldnames(resultsBasic.operatorMetrics);
        fprintf('  Found %d operators in metrics\n', length(operatorNames));
        
        % Display first operator's metrics as example
        if ~isempty(operatorNames)
            firstOp = operatorNames{1};
            opData = resultsBasic.operatorMetrics.(firstOp);
            fprintf('  Example operator: %s\n', opData.operatorName);
            fprintf('    Total cases: %d\n', opData.totalCases);
            if opData.setupTime.validCount > 0
                fprintf('    Setup time: Mean=%.1f, Median=%.1f min\n', ...
                    opData.setupTime.mean, opData.setupTime.median);
            end
            if opData.procedureTime.validCount > 0
                fprintf('    Procedure time: Mean=%.1f, Median=%.1f min\n', ...
                    opData.procedureTime.mean, opData.procedureTime.median);
            end
        end
    else
        fprintf('✗ operatorMetrics field missing\n');
    end
    
    % Verify plotting data structure
    if isfield(resultsBasic, 'operatorPlottingData')
        fprintf('✓ operatorPlottingData field exists\n');
        plotData = resultsBasic.operatorPlottingData;
        if isfield(plotData, 'operatorNames') && isfield(plotData, 'setupTime')
            fprintf('  Plotting data contains %d operators\n', length(plotData.operatorNames));
            
            % Show some sample plotting arrays
            validSetupMeans = plotData.setupTime.mean(~isnan(plotData.setupTime.mean));
            if ~isempty(validSetupMeans)
                fprintf('  Setup time means range: %.1f - %.1f min\n', ...
                    min(validSetupMeans), max(validSetupMeans));
            end
            
            validProcMeans = plotData.procedureTime.mean(~isnan(plotData.procedureTime.mean));
            if ~isempty(validProcMeans)
                fprintf('  Procedure time means range: %.1f - %.1f min\n', ...
                    min(validProcMeans), max(validProcMeans));
            end
        end
    else
        fprintf('✗ operatorPlottingData field missing\n');
    end
    
    % Test with schedules if available
    if ~isempty(schedules)
        fprintf('\n--- Testing with schedule data ---\n');
        resultsFull = analyzeHistoricalData(historicalData, ...
            'HistoricalSchedules', schedules, 'ShowStats', false);
        
        % Check if idle time analysis is still working
        if isfield(resultsFull, 'operatorAnalysis') && ...
           isfield(resultsFull.operatorAnalysis, 'idleTimeStats')
            fprintf('✓ Schedule-based operator analysis preserved\n');
        end
    end
    
    % Test example plotting usage
    fprintf('\n--- Testing plotting data usage ---\n');
    if exist('resultsBasic', 'var') && isfield(resultsBasic, 'operatorPlottingData')
        testPlottingExample(resultsBasic.operatorPlottingData);
    end
    
    fprintf('\n=== ENHANCED OPERATOR ANALYSIS TEST COMPLETE ===\n');
    
catch ME
    fprintf('ERROR during testing: %s\n', ME.message);
    fprintf('Stack trace:\n');
    for i = 1:length(ME.stack)
        fprintf('  %s line %d: %s\n', ME.stack(i).file, ME.stack(i).line, ME.stack(i).name);
    end
    rethrow(ME);
end

end

function testPlottingExample(plotData)
    % Demonstrate how to use the plotting data structure
    fprintf('Example plotting data usage:\n');
    
    if isfield(plotData, 'operatorNames') && length(plotData.operatorNames) >= 3
        fprintf('  Top 3 operators by case volume:\n');
        for i = 1:3
            opName = plotData.operatorNames{i};
            totalCases = plotData.totalCases(i);
            setupMean = plotData.setupTime.mean(i);
            procMean = plotData.procedureTime.mean(i);
            
            fprintf('    %s: %d cases', opName, totalCases);
            if ~isnan(setupMean)
                fprintf(', Setup=%.1f min', setupMean);
            end
            if ~isnan(procMean)
                fprintf(', Proc=%.1f min', procMean);
            end
            fprintf('\n');
        end
        
        % Show how to create a simple comparison
        validSetupIndices = ~isnan(plotData.setupTime.mean);
        if sum(validSetupIndices) >= 2
            validNames = plotData.operatorNames(validSetupIndices);
            validSetupMeans = plotData.setupTime.mean(validSetupIndices);
            fprintf('  Setup time comparison (first 3 with valid data):\n');
            for i = 1:min(3, length(validNames))
                fprintf('    %s: %.1f min\n', validNames{i}, validSetupMeans(i));
            end
        end
    end
end