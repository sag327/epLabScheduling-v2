% Test script for scheduleHistoricalCases.m
% This script demonstrates how to use the scheduling function with sample data

clear; clc;

fprintf('=== Testing scheduleHistoricalCases.m ===\n\n');

% Create sample historical cases data
fprintf('Creating sample case data...\n');

cases = struct();

% Case 1: Dr. Smith - Ablation
cases(1).operator = 'Dr. Smith';
cases(1).caseID = 'EP001';
cases(1).procTime = 180; % 3 hours
cases(1).setupTime = 30;
cases(1).postTime = 15;
cases(1).procedure = 'Atrial Fibrillation Ablation';
cases(1).location = 'EP Lab';
cases(1).service = 'Electrophysiology';
cases(1).admissionStatus = 'Outpatient';
cases(1).priority = []; % Normal priority
cases(1).preferredLab = []; % No lab preference

% Case 2: Dr. Johnson - Pacemaker
cases(2).operator = 'Dr. Johnson';
cases(2).caseID = 'EP002';
cases(2).procTime = 90; % 1.5 hours
cases(2).setupTime = 20;
cases(2).postTime = 10;
cases(2).procedure = 'Pacemaker Implant';
cases(2).location = 'EP Lab';
cases(2).service = 'Electrophysiology';
cases(2).admissionStatus = 'Outpatient';
cases(2).priority = 1; % Must be first case
cases(2).preferredLab = []; % No lab preference

% Case 3: Dr. Smith - ICD
cases(3).operator = 'Dr. Smith';
cases(3).caseID = 'EP003';
cases(3).procTime = 120; % 2 hours
cases(3).setupTime = 25;
cases(3).postTime = 15;
cases(3).procedure = 'ICD Implant';
cases(3).location = 'EP Lab';
cases(3).service = 'Electrophysiology';
cases(3).admissionStatus = 'Inpatient';
cases(3).priority = []; % Normal priority
cases(3).preferredLab = 2; % Must be in lab 2

% Case 4: Dr. Wilson - EP Study
cases(4).operator = 'Dr. Wilson';
cases(4).caseID = 'EP004';
cases(4).procTime = 60; % 1 hour
cases(4).setupTime = 15;
cases(4).postTime = 10;
cases(4).procedure = 'EP Study';
cases(4).location = 'EP Lab';
cases(4).service = 'Electrophysiology';
cases(4).admissionStatus = 'Outpatient';
cases(4).priority = []; % Normal priority
cases(4).preferredLab = []; % No lab preference

% Case 5: Dr. Johnson - SVT Ablation
cases(5).operator = 'Dr. Johnson';
cases(5).caseID = 'EP005';
cases(5).procTime = 150; % 2.5 hours
cases(5).setupTime = 30;
cases(5).postTime = 15;
cases(5).procedure = 'SVT Ablation';
cases(5).location = 'EP Lab';
cases(5).service = 'Electrophysiology';
cases(5).admissionStatus = 'Outpatient';
cases(5).priority = []; % Normal priority
cases(5).preferredLab = []; % No lab preference

fprintf('Created %d sample cases\n\n', length(cases));

% Test 1: Basic scheduling with default parameters
fprintf('=== Test 1: Default scheduling (3 labs, minimize operator idle time) ===\n');
try
    [schedule1, results1] = scheduleHistoricalCases(cases);
    fprintf('✓ Test 1 passed\n\n');
catch ME
    fprintf('✗ Test 1 failed: %s\n\n', ME.message);
end

% Test 2: Schedule only outpatient cases
fprintf('=== Test 2: Outpatient cases only ===\n');
try
    [schedule2, results2] = scheduleHistoricalCases(cases, 'caseFilter', 'outpatient');
    fprintf('✓ Test 2 passed\n\n');
catch ME
    fprintf('✗ Test 2 failed: %s\n\n', ME.message);
end

% Test 3: Different optimization metric (lab idle time)
fprintf('=== Test 3: Minimize lab idle time ===\n');
try
    [schedule3, results3] = scheduleHistoricalCases(cases, 'optimizationMetric', 'labIdle');
    fprintf('✓ Test 3 passed\n\n');
catch ME
    fprintf('✗ Test 3 failed: %s\n\n', ME.message);
end

% Test 4: Custom lab configuration
fprintf('=== Test 4: Custom lab configuration (2 labs, different start times) ===\n');
try
    [schedule4, results4] = scheduleHistoricalCases(cases, ...
        'numLabs', 2, ...
        'labStartTimes', {'7:30', '8:00'}, ...
        'optimizationMetric', 'makespan');
    fprintf('✓ Test 4 passed\n\n');
catch ME
    fprintf('✗ Test 4 failed: %s\n\n', ME.message);
end

% Test 5: Minimize operator overtime
fprintf('=== Test 5: Minimize operator overtime (4-hour limit) ===\n');
try
    [schedule5, results5] = scheduleHistoricalCases(cases, ...
        'optimizationMetric', 'operatorOvertime', ...
        'maxOperatorTime', 240); % 4 hours
    fprintf('✓ Test 5 passed\n\n');
catch ME
    fprintf('✗ Test 5 failed: %s\n\n', ME.message);
end

% Test 6: Quiet mode
fprintf('=== Test 6: Quiet mode (verbose=false) ===\n');
try
    [schedule6, results6] = scheduleHistoricalCases(cases, 'verbose', false);
    fprintf('✓ Test 6 passed - no detailed output shown\n\n');
catch ME
    fprintf('✗ Test 6 failed: %s\n\n', ME.message);
end

% Test 7: Edge case - empty cases
fprintf('=== Test 7: Edge case - empty cases array ===\n');
try
    emptyCases = [];  % Use empty array instead of empty struct
    [scheduleEmpty, resultsEmpty] = scheduleHistoricalCases(emptyCases, 'verbose', false);
    fprintf('✓ Test 7 passed - handled empty cases\n\n');
catch ME
    fprintf('✗ Test 7 failed: %s\n\n', ME.message);
end

% Summary comparison
fprintf('=== Summary Comparison ===\n');
if exist('results1', 'var')
    fprintf('Default scheduling:\n');
    fprintf('  Makespan: %.1f hours\n', results1.makespan/60);
    fprintf('  Lab utilization: %.1f%%\n', results1.meanLabUtilization*100);
    fprintf('  Operator idle time: %.1f hours\n', results1.totalOperatorIdleTime/60);
    fprintf('  Operator overtime: %.1f hours\n', results1.totalOperatorOvertime/60);
end

if exist('results2', 'var')
    fprintf('\nOutpatient only scheduling:\n');
    fprintf('  Makespan: %.1f hours\n', results2.makespan/60);
    fprintf('  Lab utilization: %.1f%%\n', results2.meanLabUtilization*100);
    fprintf('  Operator idle time: %.1f hours\n', results2.totalOperatorIdleTime/60);
    fprintf('  Operator overtime: %.1f hours\n', results2.totalOperatorOvertime/60);
end

if exist('results3', 'var')
    fprintf('\nLab idle minimization:\n');
    fprintf('  Makespan: %.1f hours\n', results3.makespan/60);
    fprintf('  Lab utilization: %.1f%%\n', results3.meanLabUtilization*100);
    fprintf('  Operator idle time: %.1f hours\n', results3.totalOperatorIdleTime/60);
    fprintf('  Operator overtime: %.1f hours\n', results3.totalOperatorOvertime/60);
end

fprintf('\n=== Testing Complete ===\n');

% Example usage display
fprintf('\n=== Example Usage ===\n');
fprintf('%% Load historical data and schedule for a specific date:\n');
fprintf('cases = getCasesByDate(''02-15-2025'');\n');
fprintf('[schedule, results] = scheduleHistoricalCases(cases);\n\n');

fprintf('%% Schedule only outpatient cases with 2 labs:\n');
fprintf('[schedule, results] = scheduleHistoricalCases(cases, ...\n');
fprintf('    ''caseFilter'', ''outpatient'', ...\n');
fprintf('    ''numLabs'', 2, ...\n');
fprintf('    ''labStartTimes'', {{''7:00'', ''8:00''}});\n\n');

fprintf('%% Minimize makespan with custom operator time limit:\n');
fprintf('[schedule, results] = scheduleHistoricalCases(cases, ...\n');
fprintf('    ''optimizationMetric'', ''makespan'', ...\n');
fprintf('    ''maxOperatorTime'', 360); %% 6 hours\n\n');