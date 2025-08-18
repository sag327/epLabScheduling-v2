% Test script for midnight constraint performance impact
% This script compares optimization performance with and without midnight constraint

clear; clc;

fprintf('=== Testing Midnight Constraint Performance Impact ===\n\n');

% Create sample cases that would normally extend past midnight
cases = struct();

% Case 1: Dr. Smith - Long Ablation
cases(1).operator = 'Dr. Smith';
cases(1).caseID = 'EP001';
cases(1).procTime = 240; % 4 hours
cases(1).setupTime = 30;
cases(1).postTime = 15;
cases(1).procedure = 'Complex Atrial Fibrillation Ablation';
cases(1).location = 'EP Lab';
cases(1).service = 'Electrophysiology';
cases(1).admissionStatus = 'Outpatient';
cases(1).priority = [];
cases(1).preferredLab = [];

% Case 2: Dr. Johnson - ICD
cases(2).operator = 'Dr. Johnson';
cases(2).caseID = 'EP002';
cases(2).procTime = 150; % 2.5 hours
cases(2).setupTime = 25;
cases(2).postTime = 15;
cases(2).procedure = 'ICD Implant';
cases(2).location = 'EP Lab';
cases(2).service = 'Electrophysiology';
cases(2).admissionStatus = 'Inpatient';
cases(2).priority = 1; % Priority case
cases(2).preferredLab = [];

% Case 3: Dr. Wilson - EP Study
cases(3).operator = 'Dr. Wilson';
cases(3).caseID = 'EP003';
cases(3).procTime = 90;
cases(3).setupTime = 20;
cases(3).postTime = 10;
cases(3).procedure = 'EP Study';
cases(3).location = 'EP Lab';
cases(3).service = 'Electrophysiology';
cases(3).admissionStatus = 'Outpatient';
cases(3).priority = [];
cases(3).preferredLab = [];

% Case 4: Dr. Smith - Pacemaker
cases(4).operator = 'Dr. Smith';
cases(4).caseID = 'EP004';
cases(4).procTime = 120;
cases(4).setupTime = 20;
cases(4).postTime = 10;
cases(4).procedure = 'Pacemaker Implant';
cases(4).location = 'EP Lab';
cases(4).service = 'Electrophysiology';
cases(4).admissionStatus = 'Outpatient';
cases(4).priority = [];
cases(4).preferredLab = [];

% Case 5: Dr. Johnson - SVT Ablation
cases(5).operator = 'Dr. Johnson';
cases(5).caseID = 'EP005';
cases(5).procTime = 180; % 3 hours
cases(5).setupTime = 30;
cases(5).postTime = 15;
cases(5).procedure = 'SVT Ablation';
cases(5).location = 'EP Lab';
cases(5).service = 'Electrophysiology';
cases(5).admissionStatus = 'Outpatient';
cases(5).priority = [];
cases(5).preferredLab = [];

% Case 6: Dr. Wilson - Another procedure
cases(6).operator = 'Dr. Wilson';
cases(6).caseID = 'EP006';
cases(6).procTime = 75;
cases(6).setupTime = 15;
cases(6).postTime = 10;
cases(6).procedure = 'Device Check';
cases(6).location = 'EP Lab';
cases(6).service = 'Electrophysiology';
cases(6).admissionStatus = 'Outpatient';
cases(6).priority = [];
cases(6).preferredLab = [];

fprintf('Created %d sample cases with total procedure time: %.1f hours\n\n', ...
    length(cases), sum([cases.procTime])/60);

% Common parameters for both tests
commonParams = {'numLabs', 2, 'labStartTimes', {'8:00', '8:00'}, 'verbose', true};

% Test 1: WITHOUT midnight constraint
fprintf('=== Test 1: WITHOUT Midnight Constraint ===\n');
tic;
try
    [schedule1, results1] = scheduleHistoricalCases(cases, commonParams{:}, 'enforceMiddnight', false);
    time1 = toc;
    fprintf('✓ Test 1 completed in %.2f seconds\n', time1);
    
    % Check for cases past midnight
    pastMidnight1 = 0;
    allCases1 = [];
    for j = 1:length(schedule1.labs)
        if ~isempty(schedule1.labs{j})
            allCases1 = [allCases1; schedule1.labs{j}];
        end
    end
    
    for i = 1:length(allCases1)
        if allCases1(i).endTime > 1440 % Past midnight
            pastMidnight1 = pastMidnight1 + 1;
        end
    end
    
    fprintf('  Cases scheduled: %d/%d\n', length(allCases1), length(cases));
    fprintf('  Cases past midnight: %d\n', pastMidnight1);
    fprintf('  Makespan: %.1f hours\n', results1.makespan/60);
    fprintf('  Lab utilization: %.1f%%\n', results1.meanLabUtilization*100);
    
catch ME
    time1 = toc;
    fprintf('✗ Test 1 failed in %.2f seconds: %s\n', time1, ME.message);
    schedule1 = [];
    results1 = struct();
end

fprintf('\n');

% Test 2: WITH midnight constraint
fprintf('=== Test 2: WITH Midnight Constraint ===\n');
tic;
try
    [schedule2, results2] = scheduleHistoricalCases(cases, commonParams{:}, 'enforceMiddnight', true);
    time2 = toc;
    fprintf('✓ Test 2 completed in %.2f seconds\n', time2);
    
    % Check for cases past midnight
    pastMidnight2 = 0;
    allCases2 = [];
    for j = 1:length(schedule2.labs)
        if ~isempty(schedule2.labs{j})
            allCases2 = [allCases2; schedule2.labs{j}];
        end
    end
    
    for i = 1:length(allCases2)
        if allCases2(i).endTime > 1440 % Past midnight
            pastMidnight2 = pastMidnight2 + 1;
        end
    end
    
    fprintf('  Cases scheduled: %d/%d\n', length(allCases2), length(cases));
    fprintf('  Cases past midnight: %d\n', pastMidnight2);
    fprintf('  Makespan: %.1f hours\n', results2.makespan/60);
    fprintf('  Lab utilization: %.1f%%\n', results2.meanLabUtilization*100);
    
catch ME
    time2 = toc;
    fprintf('✗ Test 2 failed in %.2f seconds: %s\n', time2, ME.message);
    schedule2 = [];
    results2 = struct();
end

% Performance comparison
fprintf('\n=== Performance Comparison ===\n');
if exist('time1', 'var') && exist('time2', 'var')
    speedup = time1 / time2;
    if speedup > 1
        fprintf('Midnight constraint is %.2fx FASTER (%.2f vs %.2f seconds)\n', speedup, time1, time2);
    else
        fprintf('Midnight constraint is %.2fx SLOWER (%.2f vs %.2f seconds)\n', 1/speedup, time2, time1);
    end
    
    timeReduction = time1 - time2;
    percentReduction = (timeReduction / time1) * 100;
    fprintf('Time reduction: %.2f seconds (%.1f%%)\n', timeReduction, percentReduction);
end

% Solution quality comparison
fprintf('\n=== Solution Quality Comparison ===\n');
if exist('results1', 'var') && exist('results2', 'var') && ~isempty(fieldnames(results1)) && ~isempty(fieldnames(results2))
    fprintf('WITHOUT midnight constraint:\n');
    fprintf('  Makespan: %.1f hours\n', results1.makespan/60);
    fprintf('  Lab utilization: %.1f%%\n', results1.meanLabUtilization*100);
    fprintf('  Operator idle time: %.1f hours\n', results1.totalOperatorIdleTime/60);
    
    fprintf('\nWITH midnight constraint:\n');
    fprintf('  Makespan: %.1f hours\n', results2.makespan/60);
    fprintf('  Lab utilization: %.1f%%\n', results2.meanLabUtilization*100);
    fprintf('  Operator idle time: %.1f hours\n', results2.totalOperatorIdleTime/60);
    
    % Constraint impact
    makespanReduction = (results1.makespan - results2.makespan) / 60;
    fprintf('\nConstraint Impact:\n');
    fprintf('  Makespan reduction: %.1f hours\n', makespanReduction);
    fprintf('  Utilization change: %.1f percentage points\n', ...
        results2.meanLabUtilization*100 - results1.meanLabUtilization*100);
end

% Problem size analysis
fprintf('\n=== Problem Size Analysis ===\n');
fprintf('Time horizon without constraint: %.1f hours\n', 20); % Default from original
fprintf('Time horizon with constraint: %.1f hours\n', 24);   % Fixed to midnight

totalCaseTime = sum([cases.procTime] + [cases.setupTime] + [cases.postTime]) + length(cases)*15; % Include turnover
fprintf('Total case time (including turnover): %.1f hours\n', totalCaseTime/60);
fprintf('Theoretical minimum makespan: %.1f hours\n', totalCaseTime/60/2); % 2 labs

% Test feasibility
fprintf('\n=== Feasibility Analysis ===\n');
if totalCaseTime/60 > 16 % 24 hours - 8 hour start time
    fprintf('WARNING: Cases may not fit within single day (need %.1f hours, only %.1f available)\n', ...
        totalCaseTime/60, 16);
else
    fprintf('Cases should fit within single day (need %.1f hours, %.1f available)\n', ...
        totalCaseTime/60, 16);
end

fprintf('\n=== Testing Complete ===\n');

% Example usage
fprintf('\n=== Example Usage ===\n');
fprintf('%% Schedule with midnight constraint (default):\n');
fprintf('[schedule, results] = scheduleHistoricalCases(cases);\n\n');

fprintf('%% Schedule without midnight constraint:\n');
fprintf('[schedule, results] = scheduleHistoricalCases(cases, ''enforceMiddnight'', false);\n\n');

fprintf('%% Compare performance:\n');
fprintf('tic; scheduleHistoricalCases(cases, ''enforceMiddnight'', false); time1 = toc;\n');
fprintf('tic; scheduleHistoricalCases(cases, ''enforceMiddnight'', true); time2 = toc;\n');
fprintf('fprintf(''Speedup: %.2fx\\n'', time1/time2);\n\n');