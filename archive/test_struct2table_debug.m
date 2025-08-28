% Debug struct2table issue
% Version: 2.1.0

fprintf('=== Debugging struct2table issue ===\n');

% Load and analyze data first
load('data/historicalEPData.mat');
analysisResults = analyzeHistoricalData(historicalData);

% Test createStatisticalDataset with minimal verbose output
fprintf('Testing createStatisticalDataset...\n');
try
    statisticalData = createStatisticalDataset(analysisResults, ...
        'ExportToCSV', false, 'ExportToTable', false, 'Verbose', false);
    fprintf('✓ createStatisticalDataset completed successfully\n');
    
    % Check if we have comprehensive metrics
    if isfield(analysisResults, 'comprehensiveOperatorMetrics')
        fprintf('✓ Using comprehensive operator metrics\n');
        opNames = fieldnames(analysisResults.comprehensiveOperatorMetrics);
        fprintf('  Found %d operators with comprehensive metrics\n', length(opNames));
        
        % Test with first operator
        firstOp = opNames{1};
        opMetrics = analysisResults.comprehensiveOperatorMetrics.(firstOp);
        fprintf('  First operator: %s\n', firstOp);
        fprintf('    Fields: %s\n', strjoin(fieldnames(opMetrics), ', '));
    end
    
catch ME
    fprintf('✗ Error in createStatisticalDataset: %s\n', ME.message);
    fprintf('Stack trace:\n');
    for i = 1:length(ME.stack)
        fprintf('  %s:%d in %s\n', ME.stack(i).file, ME.stack(i).line, ME.stack(i).name);
    end
end

fprintf('\nTest complete.\n');