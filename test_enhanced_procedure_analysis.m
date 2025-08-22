function test_enhanced_procedure_analysis()
% Test the enhanced procedure-specific time analysis functionality

fprintf('=== TESTING ENHANCED PROCEDURE ANALYSIS ===\n');

try
    % Load historical data
    fprintf('Loading historical data...\n');
    [historicalData, ~] = loadHistoricalDataFromFile();
    
    fprintf('Loaded %d cases from historical data\n', length(historicalData.caseID));
    
    % Test enhanced analysis with procedure breakdowns
    fprintf('\n--- Testing enhanced procedure analysis ---\n');
    results = analyzeHistoricalData(historicalData, 'ShowStats', true);
    
    % Verify the new fields exist
    expectedFields = {'procedureTimeAnalysis', 'procedureTimeByOperator', 'procedurePlottingData'};
    
    for i = 1:length(expectedFields)
        fieldName = expectedFields{i};
        if isfield(results, fieldName)
            fprintf('✓ %s field exists\n', fieldName);
        else
            fprintf('✗ %s field missing\n', fieldName);
        end
    end
    
    % Test global procedure analysis
    if isfield(results, 'procedureTimeAnalysis')
        procAnalysis = results.procedureTimeAnalysis;
        procFields = fieldnames(procAnalysis);
        fprintf('  Found %d procedure types in global analysis\n', length(procFields));
        
        % Display example procedure statistics
        if ~isempty(procFields)
            firstProc = procFields{1};
            procData = procAnalysis.(firstProc);
            fprintf('  Example procedure: %s\n', procData.procedureName);
            fprintf('    Total cases: %d\n', procData.totalCases);
            if procData.procedureTime.validCount > 0
                fprintf('    Procedure time: Mean=%.1f, Median=%.1f, P25=%.1f, P75=%.1f, P90=%.1f min\n', ...
                    procData.procedureTime.mean, procData.procedureTime.median, ...
                    procData.procedureTime.p25, procData.procedureTime.p75, procData.procedureTime.p90);
            end
        end
    end
    
    % Test per-operator procedure analysis
    if isfield(results, 'procedureTimeByOperator')
        opProcAnalysis = results.procedureTimeByOperator;
        opFields = fieldnames(opProcAnalysis);
        fprintf('  Found %d operators in per-operator procedure analysis\n', length(opFields));
        
        % Display example operator-procedure statistics
        if ~isempty(opFields)
            firstOp = opFields{1};
            opData = opProcAnalysis.(firstOp);
            fprintf('  Example operator: %s (%d total cases)\n', opData.operatorName, opData.totalCases);
            
            % Get procedure fields for this operator
            opProcFields = fieldnames(opData);
            opProcFields = opProcFields(~strcmp(opProcFields, 'operatorName') & ~strcmp(opProcFields, 'totalCases'));
            
            if ~isempty(opProcFields)
                firstOpProc = opProcFields{1};
                procData = opData.(firstOpProc);
                fprintf('    Example procedure: %s (%d cases)\n', procData.procedureName, procData.caseCount);
                if procData.procedureTime.validCount > 0
                    fprintf('      Procedure time: Mean=%.1f, P25=%.1f, P75=%.1f, P90=%.1f min\n', ...
                        procData.procedureTime.mean, procData.procedureTime.p25, ...
                        procData.procedureTime.p75, procData.procedureTime.p90);
                end
            end
        end
    end
    
    % Test procedure plotting data
    if isfield(results, 'procedurePlottingData')
        plotData = results.procedurePlottingData;
        fprintf('  Testing procedure plotting data structure...\n');
        
        % Test global plotting data
        if isfield(plotData, 'global') && isfield(plotData.global, 'procedureNames')
            numGlobalProcs = length(plotData.global.procedureNames);
            fprintf('    Global plotting data: %d procedures\n', numGlobalProcs);
            
            if numGlobalProcs > 0
                % Show some example data ranges
                validProcMeans = plotData.global.procedureTime.mean(~isnan(plotData.global.procedureTime.mean));
                if ~isempty(validProcMeans)
                    fprintf('    Global procedure time means range: %.1f - %.1f min\n', ...
                        min(validProcMeans), max(validProcMeans));
                end
                
                validSetupMeans = plotData.global.setupTime.mean(~isnan(plotData.global.setupTime.mean));
                if ~isempty(validSetupMeans)
                    fprintf('    Global setup time means range: %.1f - %.1f min\n', ...
                        min(validSetupMeans), max(validSetupMeans));
                end
            end
        end
        
        % Test operator-specific plotting data
        if isfield(plotData, 'byOperator')
            opPlotFields = fieldnames(plotData.byOperator);
            fprintf('    Operator-specific plotting data: %d operators\n', length(opPlotFields));
            
            if ~isempty(opPlotFields)
                firstOpPlot = opPlotFields{1};
                opPlotData = plotData.byOperator.(firstOpPlot);
                if isfield(opPlotData, 'procedureNames')
                    fprintf('      Example operator %s: %d procedures\n', ...
                        opPlotData.operatorName, length(opPlotData.procedureNames));
                end
            end
        end
    end
    
    % Test example usage for plotting
    fprintf('\n--- Testing example plotting usage ---\n');
    if isfield(results, 'procedurePlottingData')
        testProcedurePlottingExample(results.procedurePlottingData);
    end
    
    % Test combined operator and procedure analysis
    fprintf('\n--- Testing combined analysis access ---\n');
    if isfield(results, 'operatorPlottingData') && isfield(results, 'procedurePlottingData')
        testCombinedAnalysisExample(results.operatorPlottingData, results.procedurePlottingData);
    end
    
    fprintf('\n=== ENHANCED PROCEDURE ANALYSIS TEST COMPLETE ===\n');
    
catch ME
    fprintf('ERROR during testing: %s\n', ME.message);
    fprintf('Stack trace:\n');
    for i = 1:length(ME.stack)
        fprintf('  %s line %d: %s\n', ME.stack(i).file, ME.stack(i).line, ME.stack(i).name);
    end
    rethrow(ME);
end

end

function testProcedurePlottingExample(procedurePlottingData)
    % Demonstrate how to use the procedure plotting data structure
    fprintf('Example procedure plotting data usage:\n');
    
    % Global procedure analysis example
    if isfield(procedurePlottingData, 'global') && ...
       isfield(procedurePlottingData.global, 'procedureNames') && ...
       length(procedurePlottingData.global.procedureNames) >= 3
        
        fprintf('  Top 3 procedures globally by case volume:\n');
        globalData = procedurePlottingData.global;
        for i = 1:3
            procName = globalData.procedureNames{i};
            totalCases = globalData.totalCases(i);
            setupMean = globalData.setupTime.mean(i);
            procMean = globalData.procedureTime.mean(i);
            procP75 = globalData.procedureTime.p75(i);
            procP90 = globalData.procedureTime.p90(i);
            
            fprintf('    %s: %d cases', procName, totalCases);
            if ~isnan(setupMean)
                fprintf(', Setup=%.1f min', setupMean);
            end
            if ~isnan(procMean)
                fprintf(', Proc=%.1f min (P75=%.1f, P90=%.1f)', procMean, procP75, procP90);
            end
            fprintf('\n');
        end
    end
    
    % Operator-specific procedure example
    if isfield(procedurePlottingData, 'byOperator')
        opFields = fieldnames(procedurePlottingData.byOperator);
        if ~isempty(opFields)
            firstOp = opFields{1};
            opData = procedurePlottingData.byOperator.(firstOp);
            
            fprintf('  Example operator %s procedure breakdown:\n', opData.operatorName);
            numProcs = min(3, length(opData.procedureNames));
            for i = 1:numProcs
                procName = opData.procedureNames{i};
                caseCount = opData.caseCounts(i);
                procMean = opData.procedureTime.mean(i);
                procMedian = opData.procedureTime.median(i);
                
                fprintf('    %s: %d cases', procName, caseCount);
                if ~isnan(procMean)
                    fprintf(', Avg=%.1f min, Median=%.1f min', procMean, procMedian);
                end
                fprintf('\n');
            end
        end
    end
end

function testCombinedAnalysisExample(operatorData, procedureData)
    % Demonstrate combining operator and procedure analysis
    fprintf('Example combined analysis:\n');
    
    % Find most common procedure
    if isfield(procedureData, 'global') && isfield(procedureData.global, 'procedureNames')
        mostCommonProc = procedureData.global.procedureNames{1};
        fprintf('  Most common procedure: %s\n', mostCommonProc);
        
        % Find operators who perform this procedure
        opFields = fieldnames(procedureData.byOperator);
        operatorsForProc = {};
        
        for i = 1:length(opFields)
            opField = opFields{i};
            opData = procedureData.byOperator.(opField);
            
            % Check if this operator performs the most common procedure
            procIdx = find(strcmp(opData.procedureNames, mostCommonProc));
            if ~isempty(procIdx)
                operatorsForProc{end+1} = opData.operatorName;
            end
        end
        
        fprintf('    Operators who perform %s: %d operators\n', mostCommonProc, length(operatorsForProc));
        for i = 1:min(3, length(operatorsForProc))
            fprintf('      %s\n', operatorsForProc{i});
        end
    end
    
    % Cross-reference with operator efficiency
    if isfield(operatorData, 'operatorNames') && length(operatorData.operatorNames) >= 3
        fprintf('  Top 3 operators by volume with their efficiency:\n');
        for i = 1:3
            opName = operatorData.operatorNames{i};
            totalCases = operatorData.totalCases(i);
            setupRatio = operatorData.efficiency.setupToProcRatio(i);
            
            fprintf('    %s: %d cases', opName, totalCases);
            if ~isnan(setupRatio)
                fprintf(', Setup/Proc efficiency=%.2f', setupRatio);
            end
            fprintf('\n');
        end
    end
end