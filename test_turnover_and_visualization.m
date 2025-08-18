% Test script for turnover time and visualization
% This script tests the enhanced scheduling function with turnover time
% and demonstrates the new visualization

clear; clc;

fprintf('=== Testing Turnover Time and Visualization ===\n\n');

% Create sample cases
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
cases(1).priority = [];
cases(1).preferredLab = [];

% Case 2: Dr. Johnson - Pacemaker (priority case)
cases(2).operator = 'Dr. Johnson';
cases(2).caseID = 'EP002';
cases(2).procTime = 90;
cases(2).setupTime = 20;
cases(2).postTime = 10;
cases(2).procedure = 'Pacemaker Implant';
cases(2).location = 'EP Lab';
cases(2).service = 'Electrophysiology';
cases(2).admissionStatus = 'Outpatient';
cases(2).priority = 1; % Must be first
cases(2).preferredLab = [];

% Case 3: Dr. Smith - ICD
cases(3).operator = 'Dr. Smith';
cases(3).caseID = 'EP003';
cases(3).procTime = 120;
cases(3).setupTime = 25;
cases(3).postTime = 15;
cases(3).procedure = 'ICD Implant';
cases(3).location = 'EP Lab';
cases(3).service = 'Electrophysiology';
cases(3).admissionStatus = 'Inpatient';
cases(3).priority = [];
cases(3).preferredLab = 2; % Must be in lab 2

% Case 4: Dr. Wilson - EP Study
cases(4).operator = 'Dr. Wilson';
cases(4).caseID = 'EP004';
cases(4).procTime = 60;
cases(4).setupTime = 15;
cases(4).postTime = 10;
cases(4).procedure = 'EP Study';
cases(4).location = 'EP Lab';
cases(4).service = 'Electrophysiology';
cases(4).admissionStatus = 'Outpatient';
cases(4).priority = [];
cases(4).preferredLab = [];

% Case 5: Dr. Johnson - SVT Ablation
cases(5).operator = 'Dr. Johnson';
cases(5).caseID = 'EP005';
cases(5).procTime = 150;
cases(5).setupTime = 30;
cases(5).postTime = 15;
cases(5).procedure = 'SVT Ablation';
cases(5).location = 'EP Lab';
cases(5).service = 'Electrophysiology';
cases(5).admissionStatus = 'Outpatient';
cases(5).priority = [];
cases(5).preferredLab = [];

fprintf('Created %d sample cases\n\n', length(cases));

% Test 1: Default turnover time (15 minutes)
fprintf('=== Test 1: Default turnover time (15 minutes) ===\n');
try
    [schedule1, results1] = scheduleHistoricalCases(cases, 'numLabs', 3, 'labStartTimes', {'8:00', '8:00', '8:00'});
    fprintf('✓ Test 1 passed - Default turnover time\n');
    
    % Visualize the schedule
    fprintf('Creating visualization with default settings...\n');
    visualizeOptimizedSchedule(schedule1, results1, 'Title', 'Schedule with 15min Turnover');
    
catch ME
    fprintf('✗ Test 1 failed: %s\n', ME.message);
end

% Test 2: Custom turnover time (30 minutes)
fprintf('\n=== Test 2: Custom turnover time (30 minutes) ===\n');
try
    [schedule2, results2] = scheduleHistoricalCases(cases, 'numLabs', 3, 'labStartTimes', {'8:00', '8:00', '8:00'}, 'turnoverTime', 30);
    fprintf('✓ Test 2 passed - 30-minute turnover time\n');
    
    % Visualize the schedule
    fprintf('Creating visualization with 30-minute turnover...\n');
    visualizeOptimizedSchedule(schedule2, results2, 'Title', 'Schedule with 30min Turnover');
    
catch ME
    fprintf('✗ Test 2 failed: %s\n', ME.message);
end

% Test 3: No turnover time (0 minutes)
fprintf('\n=== Test 3: No turnover time (0 minutes) ===\n');
try
    [schedule3, results3] = scheduleHistoricalCases(cases, 'numLabs', 3, 'labStartTimes', {'8:00', '8:00', '8:00'}, 'turnoverTime', 0);
    fprintf('✓ Test 3 passed - No turnover time\n');
    
    % Visualize the schedule
    fprintf('Creating visualization with no turnover...\n');
    visualizeOptimizedSchedule(schedule3, results3, 'Title', 'Schedule with No Turnover', 'ShowTurnover', false);
    
catch ME
    fprintf('✗ Test 3 failed: %s\n', ME.message);
end

% Test 4: Visualization options
fprintf('\n=== Test 4: Visualization with custom options ===\n');
try
    % Use the 15-minute turnover schedule
    visualizeOptimizedSchedule(schedule1, results1, ...
        'Title', 'Custom Visualization Options', ...
        'ShowLabels', true, ...
        'ShowTurnover', true, ...
        'FontSize', 10, ...
        'Debug', true);
    
    fprintf('✓ Test 4 passed - Custom visualization options\n');
    
catch ME
    fprintf('✗ Test 4 failed: %s\n', ME.message);
end

% Comparison summary
fprintf('\n=== Turnover Time Impact Summary ===\n');
if exist('results1', 'var') && exist('results2', 'var') && exist('results3', 'var')
    fprintf('15-minute turnover:\n');
    fprintf('  Makespan: %.1f hours\n', results1.makespan/60);
    fprintf('  Lab utilization: %.1f%%\n', results1.meanLabUtilization*100);
    fprintf('  Operator idle time: %.1f hours\n', results1.totalOperatorIdleTime/60);
    
    fprintf('\n30-minute turnover:\n');
    fprintf('  Makespan: %.1f hours\n', results2.makespan/60);
    fprintf('  Lab utilization: %.1f%%\n', results2.meanLabUtilization*100);
    fprintf('  Operator idle time: %.1f hours\n', results2.totalOperatorIdleTime/60);
    
    fprintf('\nNo turnover:\n');
    fprintf('  Makespan: %.1f hours\n', results3.makespan/60);
    fprintf('  Lab utilization: %.1f%%\n', results3.meanLabUtilization*100);
    fprintf('  Operator idle time: %.1f hours\n', results3.totalOperatorIdleTime/60);
    
    % Calculate impact
    makespanIncrease15 = (results1.makespan - results3.makespan) / 60;
    makespanIncrease30 = (results2.makespan - results3.makespan) / 60;
    
    fprintf('\nTurnover Impact:\n');
    fprintf('  15-min turnover adds: %.1f hours to makespan\n', makespanIncrease15);
    fprintf('  30-min turnover adds: %.1f hours to makespan\n', makespanIncrease30);
end

fprintf('\n=== Testing Complete ===\n');

% Example usage display
fprintf('\n=== Example Usage ===\n');
fprintf('%% Schedule with custom turnover time:\n');
fprintf('[schedule, results] = scheduleHistoricalCases(cases, ''turnoverTime'', 20);\n\n');

fprintf('%% Visualize the optimized schedule:\n');
fprintf('visualizeOptimizedSchedule(schedule, results, ''Title'', ''My Schedule'');\n\n');

fprintf('%% Visualize with custom options:\n');
fprintf('visualizeOptimizedSchedule(schedule, results, ...\n');
fprintf('    ''ShowTurnover'', true, ...\n');
fprintf('    ''FontSize'', 12, ...\n');
fprintf('    ''ShowLabels'', true);\n\n');