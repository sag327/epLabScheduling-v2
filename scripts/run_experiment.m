function results = run_experiment(config, varargin)
    % RUN_EXPERIMENT - Execute a single scheduling experiment
    % 
    % This runner uses existing working scripts:
    % - scripts/loadHistoricalDataFromFile.m for data loading
    % - scripts/rescheduleHistoricalCases.m for real data optimization
    % - scripts/scheduleHistoricalCases.m for synthetic data optimization
    %
    % Syntax:
    %   results = run_experiment(config)
    %   results = run_experiment(config, 'SaveResults', true)
    %
    % Inputs:
    %   config - Configuration struct from config functions
    %   
    % Optional Parameters:
    %   'SaveResults' - Save results to disk (default: true)
    %   'OutputDir' - Custom output directory (default: auto-generated)
    
    % Parse optional arguments
    p = inputParser;
    addParameter(p, 'SaveResults', true, @islogical);
    addParameter(p, 'OutputDir', '', @ischar);
    parse(p, varargin{:});
    
    saveResults = p.Results.SaveResults;
    outputDir = p.Results.OutputDir;
    
    fprintf('Running experiment: %s\n', config.experimentName);
    fprintf('Description: %s\n', config.description);
    
    % Add paths (already in scripts directory)
    addpath('data');
    addpath('clinicalData');
    
    % Create timestamped output directory
    if isempty(outputDir)
        timestamp = datestr(now, 'yyyy-mm-dd_HHMMSS');
        outputDir = fullfile('experiments', 'results', ...
            sprintf('%s_%s', timestamp, config.experimentName));
    end
    
    if saveResults && ~exist(outputDir, 'dir')
        mkdir(outputDir);
    end
    
    % Run experiment based on data type
    tic;
    if config.useSyntheticData
        [schedule, scheduleResults] = runSyntheticExperiment(config);
    else
        [schedule, scheduleResults] = runRealDataExperiment(config);
    end
    optimizationTime = toc;
    
    % Calculate enhanced metrics
    fprintf('Calculating performance metrics...\n');
    metrics = calculate_experiment_metrics(schedule, scheduleResults, config);
    metrics.optimizationTime = optimizationTime;
    
    % Store results
    results = struct();
    results.config = config;
    results.schedule = schedule;
    results.scheduleResults = scheduleResults;
    results.metrics = metrics;
    results.outputDir = outputDir;
    results.timestamp = datestr(now);
    
    % Save results if requested
    if saveResults
        fprintf('Saving results to: %s\n', outputDir);
        save(fullfile(outputDir, 'experiment_results.mat'), 'results');
        
        % Save summary
        summary = struct();
        summary.experimentName = config.experimentName;
        summary.description = config.description;
        summary.makespan = metrics.makespan;
        summary.numCases = metrics.numCasesScheduled;
        summary.labUtilization = metrics.avgLabUtilization;
        summary.timestamp = results.timestamp;
        save(fullfile(outputDir, 'summary.mat'), 'summary');
    end
    
    fprintf('Experiment completed successfully!\n\n');
end

function [schedule, scheduleResults] = runSyntheticExperiment(config)
    % Run experiment with synthetic data using scheduleHistoricalCases
    
    fprintf('Creating synthetic test cases...\n');
    
    % Create synthetic cases (simple implementation)
    numCases = 5;
    cases = struct();
    operators = {'Dr. Smith', 'Dr. Johnson', 'Dr. Brown'};
    procedures = {'Ablation', 'PM Implant', 'ICD Implant'};
    
    for i = 1:numCases
        cases(i).caseID = sprintf('CASE_%03d', i);
        cases(i).operator = operators{randi(length(operators))};
        cases(i).procedure = procedures{randi(length(procedures))};
        cases(i).setupTime = 20 + randi(20);  % 20-40 minutes
        cases(i).procTime = 60 + randi(120);  % 60-180 minutes
        cases(i).postTime = 10 + randi(20);   % 10-30 minutes
        cases(i).admissionStatus = 'Hospital Outpatient Surgery (Amb Proc)';
        cases(i).priority = [];
        cases(i).preferredLab = [];
    end
    
    fprintf('Created %d synthetic test cases\n', numCases);
    
    % Convert start time to lab start times format
    startHour = floor(config.startTime / 60);
    startMin = mod(config.startTime, 60);
    startTimeStr = sprintf('%d:%02d', startHour, startMin);
    labStartTimes = repmat({startTimeStr}, 1, config.numLabs);
    
    fprintf('Running scheduling optimization...\n');
    [schedule, scheduleResults] = scheduleHistoricalCases(cases, ...
        'turnoverTime', config.turnoverTime, ...
        'numLabs', config.numLabs, ...
        'labStartTimes', labStartTimes, ...
        'verbose', config.verboseOutput);
end

function [schedule, scheduleResults] = runRealDataExperiment(config)
    % Run experiment with real data using existing working scripts
    
    fprintf('Loading historical data using existing workflow...\n');
    
    % Check if we have cached data
    cachedDataFile = fullfile('data', 'historicalEPData.mat');
    if exist(cachedDataFile, 'file')
        fprintf('Loading cached historical data...\n');
        load(cachedDataFile, 'historicalData');
    else
        fprintf('Processing Excel file: %s\n', config.dataFile);
        % Use the existing loadHistoricalDataFromFile function
        [historicalData, ~] = loadHistoricalDataFromFile(config.dataFile);
    end
    
    % Get available dates
    uniqueDates = unique(historicalData.date);
    if isempty(uniqueDates)
        error('No dates found in historical data');
    end
    
    % Use first available date for the experiment
    targetDate = datestr(uniqueDates(1), 'dd-mmm-yyyy');
    fprintf('Using cases from date: %s\n', targetDate);
    
    fprintf('Running scheduling optimization...\n');
    % Use the existing rescheduleHistoricalCases function
    [schedule, scheduleResults] = rescheduleHistoricalCases(historicalData, ...
        'TargetDate', targetDate, ...
        'NumLabs', config.numLabs, ...
        'TurnoverTime', config.turnoverTime, ...
        'ShowProgress', config.verboseOutput);
end