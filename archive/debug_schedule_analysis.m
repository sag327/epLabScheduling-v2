% Debug schedule analysis when historicalSchedules IS being passed
% Version: 1.0.0

fprintf('=== Debugging Schedule Analysis Issue ===\n');

% Load data
load('data/historicalEPData.mat');
fprintf('Historical data loaded: %d cases\n', length(historicalData.date));

% Check if historicalSchedules exists in the workspace or data file
if exist('historicalSchedules', 'var')
    fprintf('historicalSchedules variable exists in workspace\n');
    if isa(historicalSchedules, 'containers.Map')
        fprintf('historicalSchedules is a containers.Map with %d entries\n', length(historicalSchedules));
        scheduleKeys = keys(historicalSchedules);
        fprintf('Schedule keys: ');
        for i = 1:min(3, length(scheduleKeys))
            fprintf('%s ', scheduleKeys{i});
        end
        if length(scheduleKeys) > 3
            fprintf('... and %d more', length(scheduleKeys) - 3);
        end
        fprintf('\n');
    else
        fprintf('historicalSchedules exists but is not a containers.Map (class: %s)\n', class(historicalSchedules));
    end
elseif isfield(historicalData, 'historicalSchedules')
    fprintf('historicalSchedules found as field in historicalData\n');
    historicalSchedules = historicalData.historicalSchedules;
else
    fprintf('❌ ERROR: historicalSchedules not found anywhere!\n');
    fprintf('This could explain why schedule analysis is failing.\n');
    
    fprintf('\nAvailable variables in workspace:\n');
    whos
    
    fprintf('\nFields in historicalData:\n');
    fields = fieldnames(historicalData);
    for i = 1:length(fields)
        fprintf('  %s\n', fields{i});
    end
    
    fprintf('\n=== SOLUTION ===\n');
    fprintf('You need to load or create historicalSchedules.\n');
    fprintf('This should be a containers.Map with reconstructed schedule data.\n');
    return;
end

% Try calling analyzeHistoricalData with schedules
fprintf('\n=== Testing Schedule Analysis ===\n');
try
    fprintf('Calling analyzeHistoricalData with historicalSchedules...\n');
    analysisResults = analyzeHistoricalData(historicalData, 'HistoricalSchedules', historicalSchedules, 'ShowStats', false);
    
    fprintf('✅ analyzeHistoricalData completed successfully\n');
    
    % Check what was created
    if isfield(analysisResults, 'operatorAnalysis')
        fprintf('✅ operatorAnalysis field exists\n');
        
        if isfield(analysisResults.operatorAnalysis, 'multiProcedureDayAverages')
            fprintf('✅ multiProcedureDayAverages exists\n');
            averages = analysisResults.operatorAnalysis.multiProcedureDayAverages;
            operatorNames = keys(averages);
            fprintf('   Number of operators: %d\n', length(operatorNames));
            
            % Check a sample operator
            if ~isempty(operatorNames)
                sampleOp = operatorNames{1};
                sampleData = averages(sampleOp);
                fprintf('   Sample operator: %s\n', sampleOp);
                fprintf('     multiProcedureDays: %d\n', sampleData.multiProcedureDays);
                fprintf('     avgFlips: %.2f\n', sampleData.avgFlips);
                fprintf('     medianIdleTime: %.2f\n', sampleData.medianIdleTime);
                fprintf('     flipToTurnoverRatio: %.2f\n', sampleData.flipToTurnoverRatio);
            end
        else
            fprintf('❌ multiProcedureDayAverages MISSING\n');
            fprintf('Available fields in operatorAnalysis:\n');
            opAnalysisFields = fieldnames(analysisResults.operatorAnalysis);
            for i = 1:length(opAnalysisFields)
                fprintf('     %s\n', opAnalysisFields{i});
            end
        end
    else
        fprintf('❌ operatorAnalysis field MISSING\n');
        fprintf('Available fields in analysisResults:\n');
        resultFields = fieldnames(analysisResults);
        for i = 1:length(resultFields)
            fprintf('   %s\n', resultFields{i});
        end
    end
    
catch ME
    fprintf('❌ ERROR in analyzeHistoricalData:\n');
    fprintf('   %s\n', ME.message);
    fprintf('   File: %s, Line: %d\n', ME.stack(1).file, ME.stack(1).line);
end

fprintf('\nDiagnostic complete!\n');