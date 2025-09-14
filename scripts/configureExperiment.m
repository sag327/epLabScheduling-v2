function experimentConfig = configureExperiment()
    % CONFIGUREEXPERIMENT - Default experiment configuration
    %
    % This configuration uses existing working scripts from scripts/ directory:
    % - scripts/loadHistoricalDataFromFile.m for data loading
    % - scripts/rescheduleHistoricalCases.m for optimization with real data
    % - scripts/scheduleHistoricalCases.m for optimization with synthetic data

    experimentConfig = struct();
    
    % Experiment metadata
    experimentConfig.experimentName = 'turnoverTime-30';
    experimentConfig.description = 'optimized schedule with turnover time 30 minutes';

    % Data configuration
    experimentConfig.dataFile = '~/Documents/codeProjects/epScheduling/clinicalData/procedureDurations-Q1-Q2-2025.xlsx';  % Use real data by default
    %experimentConfig.dataFile = '~/Documents/codeProjects/epScheduling/clinicalData/testProcedureDurations-7day.xlsx';

    % Scheduling parameters
    experimentConfig.numLabs = 5;           % Number of EP labs
    experimentConfig.startTime = {'8:00','8:00','8:00','8:00','8:00'};  % Lab start times (cell array of strings)
    experimentConfig.endTime = 1439;        % End time in minutes (6:00 PM)
    experimentConfig.turnoverTime = 30;     % Turnover time between cases (minutes)

    % Experiment options
    experimentConfig.verboseOutput = false;  % Show detailed optimization output
    experimentConfig.generatePlots = false; % Generate visualizations (future enhancement)
    experimentConfig.saveResults = true;    % Save experiment results
    
end