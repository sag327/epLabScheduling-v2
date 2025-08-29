function batchResults = run_batch_experiments(configFunction, varargin)
    % RUN_BATCH_EXPERIMENTS - Execute multiple experiments from a configuration function
    %
    % This function runs batch experiments using existing working scripts
    %
    % Syntax:
    %   results = run_batch_experiments(@turnover_study)
    %   results = run_batch_experiments(@lab_capacity_study, 'SaveResults', true)
    %
    % Inputs:
    %   configFunction - Function handle that returns array of config structs
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
    
    % Add paths to existing scripts
    addpath('experiments/configs');
    addpath('experiments/runners');
    addpath('scripts');
    addpath('data');
    addpath('clinicalData');
    
    % Get experiment configurations
    fprintf('Loading experiment configurations...\n');
    configs = configFunction();
    numExperiments = length(configs);
    fprintf('Found %d experiments to run\n', numExperiments);
    
    % Create batch output directory
    if isempty(outputDir)
        timestamp = datestr(now, 'yyyy-mm-dd_HHMMSS');
        functionName = func2str(configFunction);
        outputDir = fullfile('experiments', 'results', ...
            sprintf('%s_batch_%s', timestamp, functionName));
    end
    
    if saveResults && ~exist(outputDir, 'dir')
        mkdir(outputDir);
    end
    
    % Initialize batch results
    batchResults = struct();
    batchResults.configFunction = func2str(configFunction);
    batchResults.numExperiments = numExperiments;
    batchResults.timestamp = datestr(now);
    batchResults.outputDir = outputDir;
    batchResults.experiments = cell(numExperiments, 1);
    
    % Run each experiment
    fprintf('\n=== Running Batch Experiments ===\n');
    for i = 1:numExperiments
        config = configs{i};
        fprintf('\n--- Experiment %d/%d: %s ---\n', i, numExperiments, config.experimentName);
        
        try
            % Create experiment-specific output directory
            expOutputDir = fullfile(outputDir, sprintf('exp_%02d_%s', i, config.experimentName));
            
            % Run single experiment
            results = run_experiment(config, 'SaveResults', saveResults, 'OutputDir', expOutputDir);
            
            % Store results
            batchResults.experiments{i} = results;
            
            % Display quick summary
            fprintf('  Results: Makespan=%.1fh, Cases=%d, LabUtil=%.1f%%\n', ...
                results.metrics.makespan/60, ...
                results.metrics.numCasesScheduled, ...
                results.metrics.avgLabUtilization);
            
        catch ME
            fprintf('  ERROR in experiment %d: %s\n', i, ME.message);
            batchResults.experiments{i} = struct('error', ME.message, 'config', config);
        end
    end
    
    % Calculate batch summary statistics
    fprintf('\n=== Batch Summary ===\n');
    batchResults.summary = calculateBatchSummary(batchResults);
    displayBatchSummary(batchResults.summary);
    
    % Save batch results
    if saveResults
        fprintf('\nSaving batch results to: %s\n', outputDir);
        save(fullfile(outputDir, 'batch_results.mat'), 'batchResults');
        
        % Save summary table
        saveBatchSummaryTable(batchResults, outputDir);
    end
    
    fprintf('\nBatch experiments completed!\n');
end

function summary = calculateBatchSummary(batchResults)
    % Calculate summary statistics across all experiments
    
    summary = struct();
    
    % Extract successful experiments
    successfulExps = {};
    for i = 1:length(batchResults.experiments)
        exp = batchResults.experiments{i};
        if ~isfield(exp, 'error') && isfield(exp, 'metrics')
            successfulExps{end+1} = exp;
        end
    end
    
    summary.numSuccessful = length(successfulExps);
    summary.numFailed = batchResults.numExperiments - summary.numSuccessful;
    
    if summary.numSuccessful > 0
        % Extract metrics
        makespans = cellfun(@(x) x.metrics.makespan, successfulExps);
        labUtils = cellfun(@(x) x.metrics.avgLabUtilization, successfulExps);
        numCases = cellfun(@(x) x.metrics.numCasesScheduled, successfulExps);
        
        % Calculate statistics
        summary.makespan = struct();
        summary.makespan.mean = mean(makespans);
        summary.makespan.std = std(makespans);
        summary.makespan.min = min(makespans);
        summary.makespan.max = max(makespans);
        
        summary.labUtilization = struct();
        summary.labUtilization.mean = mean(labUtils);
        summary.labUtilization.std = std(labUtils);
        summary.labUtilization.min = min(labUtils);
        summary.labUtilization.max = max(labUtils);
        
        summary.numCases = struct();
        summary.numCases.mean = mean(numCases);
        summary.numCases.std = std(numCases);
        summary.numCases.min = min(numCases);
        summary.numCases.max = max(numCases);
    end
end

function displayBatchSummary(summary)
    % Display batch summary statistics
    
    fprintf('Successful experiments: %d\n', summary.numSuccessful);
    fprintf('Failed experiments: %d\n', summary.numFailed);
    
    if summary.numSuccessful > 0
        fprintf('\nMakespan (hours):\n');
        fprintf('  Mean: %.2f ± %.2f\n', summary.makespan.mean/60, summary.makespan.std/60);
        fprintf('  Range: %.2f - %.2f\n', summary.makespan.min/60, summary.makespan.max/60);
        
        fprintf('\nLab Utilization (%%):\n');
        fprintf('  Mean: %.1f ± %.1f\n', summary.labUtilization.mean, summary.labUtilization.std);
        fprintf('  Range: %.1f - %.1f\n', summary.labUtilization.min, summary.labUtilization.max);
        
        fprintf('\nCases Scheduled:\n');
        fprintf('  Mean: %.1f ± %.1f\n', summary.numCases.mean, summary.numCases.std);
        fprintf('  Range: %.0f - %.0f\n', summary.numCases.min, summary.numCases.max);
    end
end

function saveBatchSummaryTable(batchResults, outputDir)
    % Save summary table as CSV for easy analysis
    
    % Extract data from successful experiments
    experimentNames = {};
    makespans = [];
    labUtils = [];
    numCases = [];
    
    for i = 1:length(batchResults.experiments)
        exp = batchResults.experiments{i};
        if ~isfield(exp, 'error') && isfield(exp, 'metrics')
            experimentNames{end+1} = exp.config.experimentName;
            makespans(end+1) = exp.metrics.makespan / 60; % Convert to hours
            labUtils(end+1) = exp.metrics.avgLabUtilization;
            numCases(end+1) = exp.metrics.numCasesScheduled;
        end
    end
    
    % Create table
    if ~isempty(experimentNames)
        summaryTable = table(experimentNames', makespans', labUtils', numCases', ...
            'VariableNames', {'Experiment', 'Makespan_Hours', 'Lab_Utilization_Pct', 'Cases_Scheduled'});
        
        % Save as CSV
        csvFile = fullfile(outputDir, 'batch_summary.csv');
        writetable(summaryTable, csvFile);
        fprintf('Summary table saved to: %s\n', csvFile);
    end
end