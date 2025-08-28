% Test table creation specifically
% Version: 2.1.0

fprintf('=== Testing table creation ===\n');

% Load and analyze data first
load('data/historicalEPData.mat');
analysisResults = analyzeHistoricalData(historicalData);

% Test with table creation enabled
fprintf('Testing table creation...\n');
try
    statisticalData = createStatisticalDataset(analysisResults, ...
        'ExportToCSV', false, 'ExportToTable', true, 'Verbose', true);
    fprintf('✓ Table creation successful\n');
    
    if isfield(statisticalData, 'operatorTable')
        fprintf('✓ operatorTable field exists\n');
        if istable(statisticalData.operatorTable)
            fprintf('✓ operatorTable is a valid MATLAB table\n');
            fprintf('  Table dimensions: %d x %d\n', height(statisticalData.operatorTable), width(statisticalData.operatorTable));
        else
            fprintf('✗ operatorTable is not a table, it is: %s\n', class(statisticalData.operatorTable));
        end
    else
        fprintf('✗ operatorTable field missing\n');
    end
    
catch ME
    fprintf('✗ Error in table creation: %s\n', ME.message);
    fprintf('Error location: %s:%d in %s\n', ME.stack(1).file, ME.stack(1).line, ME.stack(1).name);
end

fprintf('Test complete.\n');