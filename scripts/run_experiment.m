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
        [schedule, scheduleResults, experimentData] = runSyntheticExperiment(config);
    else
        [schedule, scheduleResults, experimentData] = runRealDataExperiment(config);
    end
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

function [schedule, scheduleResults, experimentData] = runSyntheticExperiment(config)
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
    
    % Return experiment metadata
    experimentData = struct();
    experimentData.targetDate = 'Synthetic';
    experimentData.dataSource = 'synthetic';
end

function [schedule, scheduleResults, experimentData] = runRealDataExperiment(config)
    % Run experiment with real data using existing working scripts
    
    fprintf('Loading historical data using...\n');

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
        if ~isempty(scheduleData.schedule.labs)
            totalCases = 0;
            for j = 1:length(scheduleData.schedule.labs)
                if ~isempty(scheduleData.schedule.labs{j})
                    totalCases = totalCases + length(scheduleData.schedule.labs{j});
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
        evalc_output = evalc('[daySchedule, dayResults] = rescheduleHistoricalCases(historicalData, ''TargetDate'', dateStr, ''NumLabs'', config.numLabs, ''TurnoverTime'', config.turnoverTime, ''ShowProgress'', false);');
        
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