function config = baseline_config()
    % BASELINE_CONFIG - Baseline experiment configuration
    % 
    % This configuration uses existing working scripts from scripts/ directory:
    % - scripts/loadHistoricalDataFromFile.m for data loading
    % - scripts/rescheduleHistoricalCases.m for optimization with real data
    % - scripts/scheduleHistoricalCases.m for optimization with synthetic data
    
    config = struct();
    
    % Experiment metadata
    config.experimentName = 'baseline';
    config.description = 'Baseline EP scheduling experiment using existing scripts';
    
    % Data configuration
    config.dataFile = 'clinicalData/testProcedureDurations-3day.xlsx';  % Use real data by default
    config.useSyntheticData = false;  % Set to true to use synthetic data instead
    
    % Scheduling parameters
    config.numLabs = 3;           % Number of EP labs
    config.startTime = 480;       % Start time in minutes (8:00 AM)
    config.endTime = 1080;        % End time in minutes (6:00 PM)
    config.turnoverTime = 15;     % Turnover time between cases (minutes)
    
    % Experiment options
    config.verboseOutput = true;  % Show detailed optimization output
    config.generatePlots = false; % Generate visualizations (future enhancement)
    config.saveResults = true;    % Save experiment results
    
end