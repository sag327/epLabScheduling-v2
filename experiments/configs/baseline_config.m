function config = baseline_config()
    % BASELINE_CONFIG - Baseline experiment configuration
    % 
    % This configuration uses existing working scripts from scripts/ directory:
    % - scripts/loadHistoricalDataFromFile.m for data loading
    % - scripts/rescheduleHistoricalCases.m for optimization with real data
    % - scripts/scheduleHistoricalCases.m for optimization with synthetic data
    
    config = struct();
    
    % Experiment metadata
    config.experimentName = 'labCount-5';
    config.description = 'EP scheduling experiment: varying number of labs';
    
    % Data configuration
    config.dataFile = '~/Documents/codeProjects/epScheduling/clinicalData/procedureDurations-Q1-Q2-2025.xlsx';  % Use real data by default
    %config.dataFile = '~/Documents/codeProjects/epScheduling/clinicalData/testProcedureDurations-7day.xlsx';  
    config.useSyntheticData = false;  % Set to true to use synthetic data instead
    
    % Scheduling parameters
    config.numLabs = 5;           % Number of EP labs
    config.startTime = 480;       % Start time in minutes (8:00 AM)
    config.endTime = 1439;        % End time in minutes (6:00 PM)
    config.turnoverTime = 15;     % Turnover time between cases (minutes)
    
    % Experiment options
    config.verboseOutput = false;  % Show detailed optimization output
    config.generatePlots = false; % Generate visualizations (future enhancement)
    config.saveResults = true;    % Save experiment results
    
end