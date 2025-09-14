%% TEST_EXPERIMENTS - Verify experiments structure works correctly
%
% This script tests the experiment framework to ensure it properly integrates
% with existing working scripts from the scripts/ directory
%
% Run this script to verify the setup is working correctly

fprintf('=== Testing EP Scheduling Experiments Framework ===\n\n');

% Add required paths (all scripts now in scripts/ directory)

%% Test 1: Configuration Loading
fprintf('1. Testing configuration loading...\n');
try
    config = configureExperiment();
    fprintf('   ✓ Baseline config loaded: %s\n', config.experimentName);
    
    configs = turnover_study();
    fprintf('   ✓ Turnover study configs: %d configurations\n', length(configs));
    
    configs = lab_capacity_study();
    fprintf('   ✓ Lab capacity study configs: %d configurations\n', length(configs));
    
    fprintf('   SUCCESS: All configurations loaded\n\n');
catch ME
    fprintf('   ❌ ERROR: %s\n\n', ME.message);
    return;
end

%% Test 2: Single Experiment - Synthetic Data
fprintf('2. Testing single experiment with synthetic data...\n');
try
    config = configureExperiment();
    config.useSyntheticData = true;
    config.verboseOutput = false;
    
    results = runSchedulingExperiment(config, 'SaveResults', false);
    
    fprintf('   ✓ Experiment completed\n');
    fprintf('     - Makespan: %.1f hours\n', results.metrics.makespan/60);
    fprintf('     - Cases: %d\n', results.metrics.numCasesScheduled);
    fprintf('     - Utilization: %.1f%%\n', results.metrics.avgLabUtilization);
    fprintf('   SUCCESS: Synthetic data experiment works\n\n');
catch ME
    fprintf('   ❌ ERROR: %s\n\n', ME.message);
    return;
end

%% Test 3: Single Experiment - Real Data  
fprintf('3. Testing single experiment with real data...\n');
try
    config = configureExperiment();
    config.useSyntheticData = false;
    config.verboseOutput = false;
    
    results = runSchedulingExperiment(config, 'SaveResults', false);
    
    fprintf('   ✓ Experiment completed\n');
    fprintf('     - Makespan: %.1f hours\n', results.metrics.makespan/60);
    fprintf('     - Cases: %d\n', results.metrics.numCasesScheduled);  
    fprintf('     - Utilization: %.1f%%\n', results.metrics.avgLabUtilization);
    fprintf('   SUCCESS: Real data experiment works\n\n');
catch ME
    fprintf('   ❌ ERROR: %s\n\n', ME.message);
    return;
end

%% Test 4: Enhanced Metrics
fprintf('4. Testing enhanced EP-specific metrics...\n');
try
    metrics = results.metrics;
    
    fprintf('   ✓ Basic metrics:\n');
    fprintf('     - Makespan: %.1f hours\n', metrics.makespan/60);
    fprintf('     - Cases scheduled: %d\n', metrics.numCasesScheduled);
    fprintf('     - Average lab utilization: %.1f%%\n', metrics.avgLabUtilization);
    
    fprintf('   ✓ EP-specific metrics:\n');
    fprintf('     - Operator idle to turnover ratio: %.3f\n', metrics.operatorIdleToTurnoverRatio);
    fprintf('     - Flip to turnover ratio: %.3f\n', metrics.flipToTurnoverRatio);  
    fprintf('     - Cases per hour: %.1f\n', metrics.casesPerHour);
    fprintf('     - Efficiency score: %.1f%%\n', metrics.efficiencyScore);
    
    fprintf('   SUCCESS: Enhanced metrics calculated\n\n');
catch ME
    fprintf('   ❌ ERROR: %s\n\n', ME.message);
    return;
end

%% Test 5: Integration with Existing Scripts
fprintf('5. Testing integration with existing scripts...\n');
try
    % Test direct usage of existing scripts (all in current directory)
    
    [historicalData, ~] = loadHistoricalDataFromFile('clinicalData/testProcedureDurations-3day.xlsx');
    fprintf('   ✓ loadHistoricalDataFromFile works: %d cases loaded\n', length(historicalData.caseID));
    
    uniqueDates = unique(historicalData.date);
    targetDate = datestr(uniqueDates(1), 'dd-mmm-yyyy');
    
    [schedule, scheduleResults] = rescheduleHistoricalCases(historicalData, ...
        'TargetDate', targetDate, 'NumLabs', 3, 'TurnoverTime', 15, 'ShowProgress', false);
    
    if ~isempty(scheduleResults) && isstruct(scheduleResults)
        fprintf('   ✓ rescheduleHistoricalCases works: makespan %.1f hours\n', scheduleResults.makespan/60);
    else
        error('rescheduleHistoricalCases returned empty results');
    end
    
    fprintf('   SUCCESS: Existing scripts integration verified\n\n');
catch ME
    fprintf('   ❌ ERROR: %s\n\n', ME.message);
    return;
end

%% Summary
fprintf('=== ALL TESTS PASSED ===\n');
fprintf('The experiments framework is working correctly and properly\n');
fprintf('integrates with existing working scripts from scripts/ directory.\n\n');

fprintf('Ready to run:\n');
fprintf('• Single experiments: results = runSchedulingExperiment(configureExperiment());\n');
fprintf('• Batch experiments: batchResults = run_batch_experiments(@turnover_study);\n');
fprintf('• Custom configurations: Edit config files in scripts/\n\n');

fprintf('See experiments/EXPERIMENT_GUIDE.md for detailed usage instructions.\n');