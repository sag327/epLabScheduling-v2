function results = runSchedulingExperiment(config, varargin)
    % RUNSCHEDULINGEXPERIMENT - Execute a single scheduling experiment
    % 
    % This runner uses existing working scripts:
    % - scripts/loadHistoricalDataFromFile.m for data loading
    % - scripts/rescheduleHistoricalCases.m for optimization
    %
    % Syntax:
    %   results = runSchedulingExperiment(config)
    %   results = runSchedulingExperiment(config, 'SaveResults', true)
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
    %addpath('clinicalData');
    
    % Create timestamped output directory
    if isempty(outputDir)
        timestamp = datestr(now, 'yyyy-mm-dd_HHMMSS');
        outputDir = fullfile('experiments', 'results', ...
            sprintf('%s_%s', timestamp, config.experimentName));
    end
    
    if saveResults && ~exist(outputDir, 'dir')
        mkdir(outputDir);
    end
    
    % Run experiment with real data
    tic;
    [schedule, scheduleResults, experimentData] = runRealDataExperiment(config);
    optimizationTime = toc;
    
    % Calculate enhanced metrics using the same script as historical analysis
    fprintf('Calculating performance metrics using analyzeHistoricalData...\n');
    
    % Convert to format expected by analyzeHistoricalData (always multi-date)
    analysisScheduleContainer = createAnalysisScheduleContainer(experimentData.fullScheduleContainer, experimentData.fullResultsContainer);
    analysisResults = analyzeHistoricalData(experimentData.historicalData, ...
        'HistoricalSchedules', analysisScheduleContainer, ...
        'ShowStats', false);
    
    % Store analysis results without flattening
    analysisResults.optimizationTime = optimizationTime;
    
    % Store simplified results structure
    results = struct();
    
    % Core experiment data
    results.config = config;
    results.timestamp = datestr(now);
    results.outputDir = outputDir;
    results.experimentData = experimentData;
    
    % Store analysis results without flattening (preserves structure from analyzeHistoricalData)
    results.analysisResults = analysisResults;
    
    % Schedule data (same format as loadHistoricalDataFromFile)
    results.schedule = createHistoricalScheduleContainer(experimentData.fullScheduleContainer, experimentData.fullResultsContainer);
    
    % Save results if requested
    if saveResults
        fprintf('Saving results to: %s\n', outputDir);
        save(fullfile(outputDir, 'experiment_results.mat'), 'results');
        
        % Save summary using structured results
        summary = struct();
        summary.experimentName = config.experimentName;
        summary.description = config.description;
        summary.optimizationTime = results.analysisResults.optimizationTime;
        summary.timestamp = results.timestamp;
        
        % Add key metrics from structured analysis
        if isfield(results.analysisResults, 'scheduleAnalysis')
            if isfield(results.analysisResults.scheduleAnalysis, 'avgMakespan')
                summary.avgMakespan = results.analysisResults.scheduleAnalysis.avgMakespan;
            end
            if isfield(results.analysisResults.scheduleAnalysis, 'avgLabUtilization')
                summary.avgLabUtilization = results.analysisResults.scheduleAnalysis.avgLabUtilization;
            end
        end
        
        if isfield(results.analysisResults, 'operatorAnalysis')
            if isfield(results.analysisResults.operatorAnalysis, 'operatorIdleToTurnoverRatio')
                summary.operatorIdleToTurnoverRatio = results.analysisResults.operatorAnalysis.operatorIdleToTurnoverRatio;
            end
        end
        save(fullfile(outputDir, 'summary.mat'), 'summary');
    end
    
    fprintf('Experiment completed successfully!\n\n');
end


function [schedule, scheduleResults, experimentData] = runRealDataExperiment(config)
    % Run experiment with real data using existing working scripts
    
    fprintf('Loading historical data...\n');

    % Suppress output during data loading
    evalc_output = evalc('[historicalData, ~] = loadHistoricalDataFromFile(config.dataFile);');
    
    % Get available dates
    uniqueDates = unique(historicalData.date);
    if isempty(uniqueDates)
        error('No dates found in historical data');
    end
    
    % Process all dates by default (no TargetDate parameter)
    fprintf('Processing all %d dates in dataset\n', length(uniqueDates));
    
    fprintf('Optimizing schedules for %d dates...\n', length(uniqueDates));
    
    % Create custom progress tracking
    [schedule, scheduleResults] = optimizeWithProgress(historicalData, config, uniqueDates);
    
    % Verify we got containers from multi-date optimization
    if ~isa(schedule, 'containers.Map') || ~isa(scheduleResults, 'containers.Map')
        error('Expected containers.Map from multi-date optimization');
    end
    
    dateKeys = keys(scheduleResults);
    if isempty(dateKeys)
        error('No successful optimizations found in results');
    end
    
    fprintf('Successfully processed %d dates\n', length(dateKeys));
    
    % Return experiment metadata
    experimentData = struct();
    experimentData.targetDate = 'All dates';
    experimentData.dataSource = 'real';
    experimentData.historicalData = historicalData;
    experimentData.fullScheduleContainer = schedule;
    experimentData.fullResultsContainer = scheduleResults;
end

function analysisContainer = createAnalysisScheduleContainer(scheduleContainer, resultsContainer)
    % Create container format expected by analyzeHistoricalData (matches loadHistoricalDataFromFile format)
    
    analysisContainer = containers.Map();
    
    dateKeys = keys(scheduleContainer);
    for i = 1:length(dateKeys)
        dateStr = dateKeys{i};
        
        % Create structure exactly like loadHistoricalDataFromFile creates
        scheduleData = struct();
        scheduleData.schedule = scheduleContainer(dateStr);
        scheduleData.results = resultsContainer(dateStr);
        scheduleData.date = dateStr;
        
        % Calculate case count from schedule (since totalCases field doesn't exist)
        totalCases = 0;
        schedule_i = scheduleContainer(dateStr);
        if isfield(schedule_i, 'labs') && ~isempty(schedule_i.labs)
            for j = 1:length(schedule_i.labs)
                if ~isempty(schedule_i.labs{j})
                    totalCases = totalCases + length(schedule_i.labs{j});
                end
            end
        end
        scheduleData.numCases = totalCases;
        
        % Add lab mapping if available
        if isfield(scheduleContainer(dateStr), 'labMapping')
            scheduleData.labMapping = scheduleContainer(dateStr).labMapping;
            scheduleData.numLabs = scheduleContainer(dateStr).numLabs;
        end
        
        analysisContainer(dateStr) = scheduleData;
    end
end

function historicalScheduleContainer = createHistoricalScheduleContainer(scheduleContainer, resultsContainer)
    % Create a container that works exactly like historicalSchedules from loadHistoricalDataFromFile
    % This allows the same syntax: results.schedule('03-Jul-2025')
    
    historicalScheduleContainer = containers.Map();
    
    dateKeys = keys(scheduleContainer);
    for i = 1:length(dateKeys)
        dateStr = dateKeys{i};
        
        % Create structure compatible with visualizeSchedule (same as loadHistoricalDataFromFile)
        scheduleData = struct();
        scheduleData.schedule = scheduleContainer(dateStr);
        scheduleData.results = resultsContainer(dateStr);
        scheduleData.date = dateStr;
        
        % Add basic case count for compatibility
        sched = scheduleData.schedule;
        if isfield(sched, 'labs') && ~isempty(sched.labs)
            totalCases = 0;
            for j = 1:length(sched.labs)
                if ~isempty(sched.labs{j})
                    totalCases = totalCases + length(sched.labs{j});
                end
            end
            scheduleData.numCases = totalCases;
        else
            scheduleData.numCases = 0;
        end
        
        historicalScheduleContainer(dateStr) = scheduleData;
    end
end

function [schedule, scheduleResults] = optimizeWithProgress(historicalData, config, uniqueDates)
    % Custom optimization with progress bar for each date
    
    numDates = length(uniqueDates);
    progressLength = 50;
    fprintf('Progress: [');
    
    % Initialize containers
    schedule = containers.Map();
    scheduleResults = containers.Map();
    
    for i = 1:numDates
        dateStr = char(uniqueDates(i));
        
        % Optimize single date with suppressed output
        % Build parameter list for rescheduleHistoricalCases
        paramList = {'TargetDate', dateStr, 'NumLabs', config.numLabs, 'TurnoverTime', config.turnoverTime, 'ShowProgress', false};

        % Add lab start times if defined in config
        if isfield(config, 'startTime') && iscell(config.startTime)
            paramList = [paramList, {'LabStartTimes', config.startTime}];
        end

        % Add optimization metric if defined in config
        if isfield(config, 'optimizationMetric')
            paramList = [paramList, {'OptimizationMetric', config.optimizationMetric}];
        end
        
        evalc_output = evalc('[daySchedule, dayResults] = rescheduleHistoricalCases(historicalData, paramList{:});');
        
        % Store results
        schedule(dateStr) = daySchedule;
        scheduleResults(dateStr) = dayResults;
        
        % Update progress bar
        progress = i / numDates;
        currentProgress = floor(progress * progressLength);
        expectedProgress = floor((i-1) / numDates * progressLength);
        
        % Print new progress characters
        for j = (expectedProgress + 1):currentProgress
            fprintf('=');
        end
    end
    
    % Complete progress bar
    fprintf('] 100%%\n');
end