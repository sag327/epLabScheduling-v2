% Test script for improved optimization and visualization
clear; clc;

fprintf('=== Testing Improved Optimization and Visualization ===\n\n');

% Create test cases
cases = struct();
cases(1).operator = 'Dr. Smith';
cases(1).caseID = 'EP001';
cases(1).procTime = 180; % 3 hours
cases(1).setupTime = 30;
cases(1).postTime = 15;
cases(1).procedure = 'Atrial Fibrillation Ablation';
cases(1).location = 'EP Lab';
cases(1).service = 'EP';
cases(1).admissionStatus = 'Outpatient';
cases(1).priority = [];
cases(1).preferredLab = [];

cases(2).operator = 'Dr. Johnson';
cases(2).caseID = 'EP002';
cases(2).procTime = 90; % 1.5 hours
cases(2).setupTime = 20;
cases(2).postTime = 10;
cases(2).procedure = 'Pacemaker Implant';
cases(2).location = 'EP Lab';
cases(2).service = 'EP';
cases(2).admissionStatus = 'Outpatient';
cases(2).priority = 1; % Priority case
cases(2).preferredLab = [];

cases(3).operator = 'Dr. Smith';
cases(3).caseID = 'EP003';
cases(3).procTime = 120; % 2 hours
cases(3).setupTime = 25;
cases(3).postTime = 15;
cases(3).procedure = 'ICD Implant';
cases(3).location = 'EP Lab';
cases(3).service = 'EP';
cases(3).admissionStatus = 'Inpatient';
cases(3).priority = [];
cases(3).preferredLab = [];

fprintf('Created %d test cases\n\n', length(cases));

% Test the improved optimization
fprintf('Testing improved operator idle time optimization...\n');
try
    [schedule, results] = scheduleHistoricalCases(cases, ...
        'numLabs', 2, ...
        'labStartTimes', {'8:00', '8:00'}, ...
        'optimizationMetric', 'operatorIdle');
    
    fprintf('✓ Optimization completed successfully\n');
    
    % Create visualization
    fprintf('Creating visualization...\n');
    visualizeOptimizedSchedule(schedule, results, ...
        'Title', 'Improved Operator Idle Optimization', ...
        'ShowLabels', true);
    
    fprintf('✓ Visualization created\n');
    
    % Analyze the schedule for idle time
    fprintf('\n=== Schedule Analysis ===\n');
    
    % Check if Dr. Smith's cases are scheduled close together
    drSmithCases = [];
    for j = 1:length(schedule.labs)
        if ~isempty(schedule.labs{j})
            labCases = schedule.labs{j};
            for k = 1:length(labCases)
                if strcmp(labCases(k).operator, 'Dr. Smith')
                    caseInfo = labCases(k);
                    caseInfo.lab = j;
                    drSmithCases = [drSmithCases; caseInfo];
                end
            end
        end
    end
    
    if length(drSmithCases) >= 2
        % Sort by procedure start time
        [~, sortIdx] = sort([drSmithCases.procStartTime]);
        drSmithCases = drSmithCases(sortIdx);
        
        % Calculate idle time between Dr. Smith's cases
        idleTime = drSmithCases(2).procStartTime - drSmithCases(1).procEndTime;
        fprintf('Dr. Smith idle time between cases: %.1f hours\n', idleTime/60);
        
        if idleTime < 60 % Less than 1 hour
            fprintf('✓ Good: Cases are scheduled close together\n');
        else
            fprintf('⚠ Warning: Large gap between cases\n');
        end
    end
    
    % Check overall start times
    allCases = [];
    for j = 1:length(schedule.labs)
        if ~isempty(schedule.labs{j})
            labCases = schedule.labs{j};
            for k = 1:length(labCases)
                allCases = [allCases; labCases(k)];
            end
        end
    end
    
    earliestStart = min([allCases.startTime]);
    latestEnd = max([allCases.endTime]);
    
    fprintf('Schedule span: %.1f hours (%.0f to %.0f minutes)\n', ...
        (latestEnd - earliestStart)/60, earliestStart, latestEnd);
    
    % Check if cases start early
    if earliestStart <= 480 + 60 % Within 1 hour of 8 AM
        fprintf('✓ Good: Cases start early in the day\n');
    else
        fprintf('⚠ Warning: Cases start late in the day\n');
    end
    
catch ME
    fprintf('✗ Test failed: %s\n', ME.message);
end

fprintf('\n=== Testing Complete ===\n');