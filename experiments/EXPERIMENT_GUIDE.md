# EP Scheduling Experiments Guide

This directory contains an experiment framework for testing EP scheduling optimization with different parameters and configurations. **The framework uses existing working scripts** from the `scripts/` directory to ensure reliability and consistency.

## Directory Structure

```
experiments/
├── configs/           # Experiment configuration files
├── results/          # Output directories (auto-created)
├── analysis/         # Analysis scripts (future)
└── EXPERIMENT_GUIDE.md

scripts/              # All experiment runners are in main scripts directory
├── runSchedulingExperiment.m          # Single experiment runner
├── run_batch_experiments.m   # Batch experiment runner  
├── calculate_experiment_metrics.m  # Enhanced metrics calculation
└── (other existing scripts...)
```

## Key Design Philosophy

**The experiment framework is a wrapper around existing working scripts:**
- Uses `scripts/loadHistoricalDataFromFile.m` for data loading
- Uses `scripts/rescheduleHistoricalCases.m` for real data experiments
- Uses `scripts/scheduleHistoricalCases.m` for synthetic data experiments
- Adds enhanced metrics and batch processing capabilities

## Quick Start

### 1. Single Experiment

```matlab
% Add experiment paths
addpath('experiments/configs');
addpath('scripts');

% Run baseline experiment
config = configureExperiment();
results = runSchedulingExperiment(config);

% View results
fprintf('Makespan: %.1f hours\\n', results.metrics.makespan/60);
fprintf('Lab utilization: %.1f%%\\n', results.metrics.avgLabUtilization);
```

### 2. Batch Experiments

```matlab
% Run turnover time study
batchResults = run_batch_experiments(@turnover_study);

% Run lab capacity study  
batchResults = run_batch_experiments(@lab_capacity_study);
```

## Configuration Files

### `configureExperiment.m`
Default experiment configuration:
- 3 labs, 15-minute turnover
- Uses real data from `clinicalData/testProcedureDurations-3day.xlsx`
- 8:00 AM - 6:00 PM schedule window

### `turnover_study.m`
Tests different turnover times: 5, 10, 15, 20, 30 minutes

### `lab_capacity_study.m`  
Tests different numbers of labs: 2, 3, 4, 5 labs

## Creating Custom Configurations

```matlab
function config = my_custom_config()
    config = configureExperiment();  % Start with baseline
    
    % Modify parameters
    config.experimentName = 'custom_test';
    config.description = 'My custom experiment';
    config.numLabs = 4;
    config.turnoverTime = 20;
    
    % Use synthetic data instead of real data
    config.useSyntheticData = true;
end
```

## Enhanced Metrics

The experiment framework calculates comprehensive metrics:

### Basic Metrics
- `makespan`: Total schedule duration
- `numCasesScheduled`: Number of cases scheduled
- `avgLabUtilization`: Average lab utilization percentage

### EP-Specific Metrics
- `operatorIdleToTurnoverRatio`: Operator idle time / total turnover time
- `flipToTurnoverRatio`: Lab transitions / (cases × turnover time)
- `casesPerHour`: Throughput metric
- `procedureTimeEfficiency`: Actual procedure time / total scheduled time
- `overtimeMinutes`: Time beyond scheduled hours

### Composite Scores
- `efficiencyScore`: Combined schedule and resource efficiency
- `utilizationScore`: Overall utilization score

## Results Structure

Each experiment produces:
```matlab
results = struct(
    'config',           % Original configuration
    'schedule',         % Detailed schedule from optimization
    'scheduleResults',  % Results from scheduling algorithm
    'metrics',          % Enhanced calculated metrics
    'outputDir',        % Where results are saved
    'timestamp'         % When experiment was run
);
```

## Batch Processing

Batch experiments automatically:
1. Run all configurations in sequence
2. Calculate summary statistics across experiments
3. Save individual and batch results
4. Generate CSV summary table for analysis

## Data Handling

### Real Data Mode (Default)
- Loads data using `scripts/loadHistoricalDataFromFile.m`
- Caches processed data in `data/historicalEPData.mat`
- Uses `scripts/rescheduleHistoricalCases.m` for optimization

### Synthetic Data Mode
- Creates simple synthetic test cases
- Uses `scripts/scheduleHistoricalCases.m` for optimization
- Useful for testing and validation

## Output Files

For each experiment:
- `experiment_results.mat`: Complete results structure
- `summary.mat`: Key metrics summary

For batch experiments:
- `batch_results.mat`: All experiment results
- `batch_summary.csv`: Summary table for analysis

## Integration with Existing Scripts

The experiment framework maintains full compatibility with existing scripts:

1. **Data Loading**: Uses the same `loadHistoricalDataFromFile.m` that was working before
2. **Optimization**: Uses the same `rescheduleHistoricalCases.m` and `scheduleHistoricalCases.m`
3. **No Changes**: Existing scripts are used as-is, no modifications required
4. **Enhanced Output**: Adds comprehensive metrics on top of existing results

## Example Workflows

### Parameter Sensitivity Analysis
```matlab
% Test different turnover times
turnoverResults = run_batch_experiments(@turnover_study);

% Test different lab capacities  
capacityResults = run_batch_experiments(@lab_capacity_study);

% Compare results
fprintf('Turnover impact: %.1f%% efficiency range\\n', 
    range([turnoverResults.experiments{:}.metrics.efficiencyScore]));
```

### Custom Experiments
```matlab
% Create custom configuration
function configs = my_study()
    base = configureExperiment();
    configs = {};
    
    % Test combinations of labs and turnover
    for numLabs = 2:5
        for turnover = [10, 20, 30]
            config = base;
            config.experimentName = sprintf('labs%d_turn%d', numLabs, turnover);
            config.numLabs = numLabs;
            config.turnoverTime = turnover;
            configs{end+1} = config;
        end
    end
end

% Run the study
results = run_batch_experiments(@my_study);
```

## Troubleshooting

### Common Issues

1. **"Cannot find scripts"**: Ensure you're running from project root directory
2. **"Data file not found"**: Check that clinical data files exist in `clinicalData/`
3. **"Scheduling failed"**: Check that existing scripts work individually first

### Validation
```matlab
% Test that existing scripts work
addpath('scripts');
[historicalData, ~] = loadHistoricalDataFromFile('clinicalData/testProcedureDurations-3day.xlsx');
fprintf('Loaded %d cases successfully\\n', length(historicalData.caseID));
```

## Future Enhancements

- Visualization generation
- Statistical analysis tools
- Automated report generation
- Parameter optimization algorithms