function [schedule, results] = scheduleHistoricalCases(cases, varargin)
% Optimal scheduling of EP cases using integer linear programming
%
% Inputs:
%   cases - Structure array from getCasesByDate.m
%   
% Optional parameters (name-value pairs):
%   'numLabs' - Number of EP labs available (default: 5)
%   'labStartTimes' - Cell array of start times for each lab (default: {'8:00', '8:00', '8:00'})
%   'optimizationMetric' - Metric to optimize:
%       'operatorIdle' - Minimize operator idle time (default)
%       'labIdle' - Minimize lab idle time
%       'makespan' - Minimize total schedule duration
%       'operatorOvertime' - Minimize operator overtime beyond 8 hours
%   'caseFilter' - Filter cases by type:
%       'all' - Schedule all cases (default)
%       'outpatient' - Only schedule outpatient cases
%       'inpatient' - Only schedule inpatient cases
%   'maxOperatorTime' - Maximum time per operator in minutes (default: 480, 8 hours)
%   'verbose' - Display detailed output (default: true)
%
% Outputs:
%   schedule - Structure with scheduling results
%   results - Optimization results and statistics

% Parse input arguments
p = inputParser;
addRequired(p, 'cases', @isstruct);
addParameter(p, 'numLabs', 5, @(x) isnumeric(x) && x > 0);
addParameter(p, 'labStartTimes', {'8:00', '8:00', '8:00','8:00','8:00'}, @iscell);
addParameter(p, 'optimizationMetric', 'operatorIdle', @(x) ismember(x, {'operatorIdle', 'labIdle', 'makespan', 'operatorOvertime'}));
addParameter(p, 'caseFilter', 'all', @(x) ismember(x, {'all', 'outpatient', 'inpatient'}));
addParameter(p, 'maxOperatorTime', 480, @(x) isnumeric(x) && x > 0);
addParameter(p, 'verbose', true, @islogical);

parse(p, cases, varargin{:});

numLabs = p.Results.numLabs;
labStartTimes = p.Results.labStartTimes;
optimizationMetric = p.Results.optimizationMetric;
caseFilter = p.Results.caseFilter;
maxOperatorTime = p.Results.maxOperatorTime;
verbose = p.Results.verbose;

if verbose
    fprintf('\n=== EP Case Scheduling Optimization ===\n');
    fprintf('Input: %d cases\n', length(cases));
    fprintf('Labs: %d\n', numLabs);
    fprintf('Optimization metric: %s\n', optimizationMetric);
    fprintf('Case filter: %s\n', caseFilter);
end

% Validate lab start times
if length(labStartTimes) ~= numLabs
    error('Number of lab start times must match number of labs');
end

% Filter cases based on admission status
if ~strcmp(caseFilter, 'all')
    originalCaseCount = length(cases);
    if strcmp(caseFilter, 'outpatient')
        cases = cases(strcmp({cases.admissionStatus}, 'Outpatient') | cellfun(@isempty, {cases.admissionStatus}));
    elseif strcmp(caseFilter, 'inpatient')
        cases = cases(strcmp({cases.admissionStatus}, 'Inpatient'));
    end
    if verbose
        fprintf('Filtered to %d %s cases\n', length(cases), caseFilter);
    end
end

if isempty(cases)
    fprintf('No cases to schedule after filtering.\n');
    schedule = struct();
    results = struct();
    return;
end

% Extract case data
numCases = length(cases);
operators = {cases.operator};
uniqueOperators = unique(operators);
numOperators = length(uniqueOperators);

if verbose
    fprintf('Cases: %d\n', numCases);
    fprintf('Operators: %d\n', numOperators);
end

% Convert lab start times to minutes since midnight
labStartMinutes = zeros(numLabs, 1);
for i = 1:numLabs
    timeStr = labStartTimes{i};
    timeParts = split(timeStr, ':');
    labStartMinutes(i) = str2double(timeParts{1}) * 60 + str2double(timeParts{2});
end

% Create operator mapping
operatorMap = containers.Map(uniqueOperators, 1:numOperators);

% Extract case properties
caseProcTimes = [cases.procTime];
caseSetupTimes = [cases.setupTime];
casePostTimes = [cases.postTime];
caseOperators = cellfun(@(x) operatorMap(x), operators);

% Handle priorities (1 = must be first, empty = normal)
casePriorities = zeros(numCases, 1);
for i = 1:numCases
    if ~isempty(cases(i).priority) && ~isnan(cases(i).priority)
        casePriorities(i) = cases(i).priority;
    end
end

% Handle lab preferences
labPreferences = zeros(numCases, numLabs);
for i = 1:numCases
    if ~isempty(cases(i).preferredLab) && ~isnan(cases(i).preferredLab)
        prefLab = cases(i).preferredLab;
        if prefLab >= 1 && prefLab <= numLabs
            labPreferences(i, prefLab) = 1;
        end
    else
        labPreferences(i, :) = 1;
    end
end

% Estimate schedule horizon (all cases in sequence + buffer)
totalProcTime = sum(caseProcTimes);
maxHorizon = max(labStartMinutes) + totalProcTime + 120;

% Create time grid (10-minute intervals)
timeStep = 10;
timeHorizon = ceil(maxHorizon / timeStep) * timeStep;
timeSlots = 0:timeStep:timeHorizon;
numTimeSlots = length(timeSlots);

if verbose
    fprintf('Time horizon: %.1f hours (%d time slots)\n', timeHorizon/60, numTimeSlots);
end

% Decision variables
% x(i,j,t) = 1 if case i starts in lab j at time slot t
numVars = numCases * numLabs * numTimeSlots;

% Variable bounds (all binary)
lb = zeros(numVars, 1);
ub = ones(numVars, 1);
intcon = 1:numVars;

% Helper function to get variable index
getVarIndex = @(case_idx, lab_idx, time_idx) ...
    (case_idx - 1) * numLabs * numTimeSlots + ...
    (lab_idx - 1) * numTimeSlots + time_idx;

% Constraint matrices
Aeq = [];
beq = [];
A = [];
b = [];

% Constraint 1: Each case must be scheduled exactly once
if verbose
    fprintf('Building constraint 1 (case assignment)...');
end
for i = 1:numCases
    row = zeros(1, numVars);
    for j = 1:numLabs
        for t = 1:numTimeSlots
            if labPreferences(i, j) == 1
                row(getVarIndex(i, j, t)) = 1;
            end
        end
    end
    Aeq = [Aeq; row];
    beq = [beq; 1];
    if verbose && mod(i, ceil(numCases/10)) == 0
        fprintf(' %.0f%%', 100*i/numCases);
    end
end
if verbose
    fprintf(' Complete\n');
end

% Constraint 2: Lab capacity (one case at a time per lab)
if verbose
    fprintf('Building constraint 2 (lab capacity)...');
end
totalConstraint2Steps = numLabs * numTimeSlots;
currentStep = 0;
for j = 1:numLabs
    for t = 1:numTimeSlots
        currentTime = timeSlots(t);
        row = zeros(1, numVars);
        
        for i = 1:numCases
            caseEndTime = currentTime + caseSetupTimes(i) + caseProcTimes(i) + casePostTimes(i);
            
            for t_start = 1:numTimeSlots
                startTime = timeSlots(t_start);
                if startTime <= currentTime && ...
                   startTime + caseSetupTimes(i) + caseProcTimes(i) + casePostTimes(i) > currentTime && ...
                   labPreferences(i, j) == 1
                    row(getVarIndex(i, j, t_start)) = 1;
                end
            end
        end
        
        A = [A; row];
        b = [b; 1];
        currentStep = currentStep + 1;
        if verbose && mod(currentStep, ceil(totalConstraint2Steps/20)) == 0
            fprintf(' %.0f%%', 100*currentStep/totalConstraint2Steps);
        end
    end
end
if verbose
    fprintf(' Complete\n');
end

% Constraint 3: Operator availability (one lab at a time during procedure)
if verbose
    fprintf('Building constraint 3 (operator availability)...');
end
totalConstraint3Steps = numOperators * numTimeSlots;
currentStep = 0;
for op = 1:numOperators
    opCases = find(caseOperators == op);
    
    for t = 1:numTimeSlots
        currentTime = timeSlots(t);
        row = zeros(1, numVars);
        
        for case_idx = opCases
            for j = 1:numLabs
                for t_start = 1:numTimeSlots
                    startTime = timeSlots(t_start);
                    procStartTime = startTime + caseSetupTimes(case_idx);
                    procEndTime = procStartTime + caseProcTimes(case_idx);
                    
                    if procStartTime <= currentTime && procEndTime > currentTime && ...
                       labPreferences(case_idx, j) == 1
                        row(getVarIndex(case_idx, j, t_start)) = 1;
                    end
                end
            end
        end
        
        A = [A; row];
        b = [b; 1];
        currentStep = currentStep + 1;
        if verbose && mod(currentStep, ceil(totalConstraint3Steps/10)) == 0
            fprintf(' %.0f%%', 100*currentStep/totalConstraint3Steps);
        end
    end
end
if verbose
    fprintf(' Complete\n');
end

% Constraint 4: Lab start time constraints
if verbose
    fprintf('Building constraint 4 (lab start times)...');
end
for j = 1:numLabs
    labStart = labStartMinutes(j);
    for i = 1:numCases
        for t = 1:numTimeSlots
            if timeSlots(t) < labStart && labPreferences(i, j) == 1
                row = zeros(1, numVars);
                row(getVarIndex(i, j, t)) = 1;
                A = [A; row];
                b = [b; 0];
            end
        end
    end
end
if verbose
    fprintf(' Complete\n');
end

% Constraint 5: Symmetry breaking (prefer lower-numbered labs to reduce search space)
% Since labs are identical, ensure total usage of lab j >= total usage of lab j+1
if verbose
    fprintf('Building constraint 5 (symmetry breaking)...');
end
for j = 1:numLabs-1
    row = zeros(1, numVars);
    for i = 1:numCases
        for t = 1:numTimeSlots
            if labPreferences(i, j) == 1
                row(getVarIndex(i, j, t)) = row(getVarIndex(i, j, t)) + 1;
            end
            if labPreferences(i, j+1) == 1
                row(getVarIndex(i, j+1, t)) = row(getVarIndex(i, j+1, t)) - 1;
            end
        end
    end
    A = [A; -row];  % -row because we want lab j >= lab j+1, so lab j+1 - lab j <= 0
    b = [b; 0];
end
if verbose
    fprintf(' Complete\n');
end

% Constraint 6: Priority constraints (priority 1 cases must be first for operator)
if verbose
    fprintf('Building constraint 6 (priority constraints)...');
end
for op = 1:numOperators
    opCases = find(caseOperators == op);
    priorityCases = opCases(casePriorities(opCases) == 1);
    
    for priorityCase = priorityCases
        for normalCase = opCases
            if normalCase ~= priorityCase && casePriorities(normalCase) ~= 1
                for j = 1:numLabs
                    for t_priority = 1:numTimeSlots
                        for t_normal = 1:t_priority
                            if labPreferences(priorityCase, j) == 1 && labPreferences(normalCase, j) == 1
                                row = zeros(1, numVars);
                                row(getVarIndex(priorityCase, j, t_priority)) = 1;
                                row(getVarIndex(normalCase, j, t_normal)) = 1;
                                A = [A; row];
                                b = [b; 1];
                            end
                        end
                    end
                end
            end
        end
    end
end
if verbose
    fprintf(' Complete\n');
end

% Objective function
if verbose
    fprintf('Building objective function (%s)...', optimizationMetric);
end
f = zeros(numVars, 1);

switch optimizationMetric
    case 'operatorIdle'
        % Minimize total operator idle time
        for op = 1:numOperators
            opCases = find(caseOperators == op);
            
            % Add penalty for gaps between cases
            for i = 1:length(opCases)-1
                for j = 1:length(opCases)-i
                    case1 = opCases(i);
                    case2 = opCases(i+j);
                    
                    for lab1 = 1:numLabs
                        for lab2 = 1:numLabs
                            for t1 = 1:numTimeSlots
                                for t2 = t1+1:numTimeSlots
                                    if labPreferences(case1, lab1) == 1 && labPreferences(case2, lab2) == 1
                                        gapPenalty = (timeSlots(t2) - timeSlots(t1) - caseProcTimes(case1)) / 1000;
                                        f(getVarIndex(case1, lab1, t1)) = f(getVarIndex(case1, lab1, t1)) + gapPenalty;
                                        f(getVarIndex(case2, lab2, t2)) = f(getVarIndex(case2, lab2, t2)) + gapPenalty;
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
        
    case 'labIdle'
        % Minimize lab idle time by preferring earlier slots
        for i = 1:numCases
            for j = 1:numLabs
                for t = 1:numTimeSlots
                    if labPreferences(i, j) == 1
                        f(getVarIndex(i, j, t)) = timeSlots(t) / 1000;
                    end
                end
            end
        end
        
    case 'makespan'
        % Minimize total schedule duration
        for i = 1:numCases
            for j = 1:numLabs
                for t = 1:numTimeSlots
                    if labPreferences(i, j) == 1
                        caseEndTime = timeSlots(t) + caseSetupTimes(i) + caseProcTimes(i) + casePostTimes(i);
                        f(getVarIndex(i, j, t)) = caseEndTime / 1000;
                    end
                end
            end
        end
        
    case 'operatorOvertime'
        % Minimize operator time beyond maxOperatorTime
        for op = 1:numOperators
            opCases = find(caseOperators == op);
            
            for case_idx = opCases
                for j = 1:numLabs
                    for t = 1:numTimeSlots
                        if labPreferences(case_idx, j) == 1
                            caseEndTime = timeSlots(t) + caseProcTimes(case_idx);
                            if caseEndTime > maxOperatorTime
                                overtimePenalty = (caseEndTime - maxOperatorTime) / 100;
                                f(getVarIndex(case_idx, j, t)) = f(getVarIndex(case_idx, j, t)) + overtimePenalty;
                            end
                        end
                    end
                end
            end
        end
end
if verbose
    fprintf(' Complete\n');
end

if verbose
    fprintf('Optimization problem size: %d variables, %d constraints\n', numVars, size(A,1) + size(Aeq,1));
    fprintf('Solving integer linear program...\n');
end

% Solve optimization problem
if verbose
    fprintf('Solving optimization problem...');
end
options = optimoptions('intlinprog', 'Display', 'off', 'MaxTime', 300);

try
    [x, fval, exitflag, output] = intlinprog(f, intcon, A, b, Aeq, beq, lb, ub, options);
    
    if exitflag <= 0
        warning('Optimization did not converge to optimal solution (exitflag: %d)', exitflag);
    end
    
catch ME
    fprintf('Optimization failed: %s\n', ME.message);
    fprintf('Falling back to greedy heuristic...\n');
    [schedule, results] = greedySchedule(cases, numLabs, labStartMinutes, caseFilter, verbose);
    return;
end

% Parse solution
if verbose
    fprintf(' Optimization complete\n');
    fprintf('Parsing solution...');
end
schedule = struct();
schedule.labs = cell(numLabs, 1);
schedule.operators = containers.Map();

for i = 1:numCases
    for j = 1:numLabs
        for t = 1:numTimeSlots
            varIdx = getVarIndex(i, j, t);
            if abs(x(varIdx) - 1) < 1e-6
                startTime = timeSlots(t);
                
                caseInfo = struct();
                caseInfo.caseID = cases(i).caseID;
                caseInfo.operator = cases(i).operator;
                caseInfo.procedure = cases(i).procedure;
                caseInfo.startTime = startTime;
                caseInfo.setupTime = cases(i).setupTime;
                caseInfo.procTime = cases(i).procTime;
                caseInfo.postTime = cases(i).postTime;
                caseInfo.endTime = startTime + caseInfo.setupTime + caseInfo.procTime + caseInfo.postTime;
                caseInfo.procStartTime = startTime + caseInfo.setupTime;
                caseInfo.procEndTime = caseInfo.procStartTime + caseInfo.procTime;
                
                if isempty(schedule.labs{j})
                    schedule.labs{j} = caseInfo;
                else
                    schedule.labs{j}(end+1) = caseInfo;
                end
                
                if isKey(schedule.operators, cases(i).operator)
                    opSchedule = schedule.operators(cases(i).operator);
                    opSchedule(end+1) = struct('lab', j, 'caseInfo', caseInfo);
                    schedule.operators(cases(i).operator) = opSchedule;
                else
                    schedule.operators(cases(i).operator) = struct('lab', j, 'caseInfo', caseInfo);
                end
                break;
            end
        end
    end
end

% Sort schedules by start time
for j = 1:numLabs
    if ~isempty(schedule.labs{j})
        [~, sortIdx] = sort([schedule.labs{j}.startTime]);
        schedule.labs{j} = schedule.labs{j}(sortIdx);
    end
end

% Calculate results
if verbose
    fprintf(' Complete\n');
    fprintf('Calculating schedule metrics...');
end
results = calculateScheduleMetrics(schedule, numLabs, labStartMinutes, uniqueOperators, maxOperatorTime, timeHorizon);
results.optimizationMetric = optimizationMetric;
results.objectiveValue = fval;
results.exitflag = exitflag;
results.solverOutput = output;

% Display results
if verbose
    fprintf(' Complete\n');
    displayScheduleResults(schedule, results, numLabs, labStartTimes, uniqueOperators);
end

end

function [schedule, results] = greedySchedule(cases, numLabs, labStartMinutes, caseFilter, verbose)
% Fallback greedy scheduling algorithm

if verbose
    fprintf('Using greedy scheduling heuristic...\n');
end

schedule = struct();
schedule.labs = cell(numLabs, 1);
schedule.operators = containers.Map();

% Sort cases by priority then by procedure time
casePriorities = zeros(length(cases), 1);
for i = 1:length(cases)
    if ~isempty(cases(i).priority) && ~isnan(cases(i).priority)
        casePriorities(i) = cases(i).priority;
    end
end

[~, sortIdx] = sortrows([casePriorities, -[cases.procTime]'], [1, 2]);
sortedCases = cases(sortIdx);

% Track lab availability
labEndTimes = labStartMinutes;

% Schedule each case
for i = 1:length(sortedCases)
    case_i = sortedCases(i);
    
    % Find best lab (earliest available)
    bestLab = 1;
    bestStartTime = labEndTimes(1);
    
    if ~isempty(case_i.preferredLab) && ~isnan(case_i.preferredLab)
        bestLab = case_i.preferredLab;
        bestStartTime = labEndTimes(bestLab);
    else
        for j = 2:numLabs
            if labEndTimes(j) < bestStartTime
                bestLab = j;
                bestStartTime = labEndTimes(j);
            end
        end
    end
    
    % Schedule case
    caseInfo = struct();
    caseInfo.caseID = case_i.caseID;
    caseInfo.operator = case_i.operator;
    caseInfo.procedure = case_i.procedure;
    caseInfo.startTime = bestStartTime;
    caseInfo.setupTime = case_i.setupTime;
    caseInfo.procTime = case_i.procTime;
    caseInfo.postTime = case_i.postTime;
    caseInfo.endTime = bestStartTime + caseInfo.setupTime + caseInfo.procTime + caseInfo.postTime;
    caseInfo.procStartTime = bestStartTime + caseInfo.setupTime;
    caseInfo.procEndTime = caseInfo.procStartTime + caseInfo.procTime;
    
    if isempty(schedule.labs{bestLab})
        schedule.labs{bestLab} = caseInfo;
    else
        schedule.labs{bestLab}(end+1) = caseInfo;
    end
    
    if isKey(schedule.operators, case_i.operator)
        opSchedule = schedule.operators(case_i.operator);
        opSchedule(end+1) = struct('lab', bestLab, 'caseInfo', caseInfo);
        schedule.operators(case_i.operator) = opSchedule;
    else
        schedule.operators(case_i.operator) = struct('lab', bestLab, 'caseInfo', caseInfo);
    end
    
    labEndTimes(bestLab) = caseInfo.endTime;
end

% Calculate results
operators = {cases.operator};
uniqueOperators = unique(operators);
maxHorizon = max(labEndTimes) + 60;
results = calculateScheduleMetrics(schedule, numLabs, labStartMinutes, uniqueOperators, 480, maxHorizon);
results.optimizationMetric = 'greedy';
results.objectiveValue = NaN;

end

function results = calculateScheduleMetrics(schedule, numLabs, labStartMinutes, uniqueOperators, maxOperatorTime, timeHorizon)
% Calculate scheduling performance metrics

results = struct();

% Lab utilization
labUtilization = zeros(numLabs, 1);
labIdleTime = zeros(numLabs, 1);
labEndTimes = zeros(numLabs, 1);

for j = 1:numLabs
    if ~isempty(schedule.labs{j})
        labCases = schedule.labs{j};
        totalProcTime = sum([labCases.procTime]);
        labStart = labStartMinutes(j);
        labEnd = max([labCases.endTime]);
        labEndTimes(j) = labEnd;
        
        if labEnd > labStart
            labUtilization(j) = totalProcTime / (labEnd - labStart);
            
            % Calculate idle time between cases
            idleTime = 0;
            for k = 1:length(labCases)-1
                gap = labCases(k+1).startTime - labCases(k).endTime;
                if gap > 0
                    idleTime = idleTime + gap;
                end
            end
            labIdleTime(j) = idleTime;
        end
    else
        labEndTimes(j) = labStartMinutes(j);
    end
end

results.labUtilization = labUtilization;
results.meanLabUtilization = mean(labUtilization);
results.totalLabIdleTime = sum(labIdleTime);

% Operator metrics
operatorIdleTime = zeros(length(uniqueOperators), 1);
operatorOvertime = zeros(length(uniqueOperators), 1);
operatorTotalTime = zeros(length(uniqueOperators), 1);

for i = 1:length(uniqueOperators)
    operator = uniqueOperators{i};
    
    if isKey(schedule.operators, operator)
        opSchedule = schedule.operators(operator);
        
        if length(opSchedule) > 1
            % Sort by procedure start time
            procStartTimes = arrayfun(@(x) x.caseInfo.procStartTime, opSchedule);
            [~, sortIdx] = sort(procStartTimes);
            opSchedule = opSchedule(sortIdx);
            
            % Calculate idle time between procedures
            idleTime = 0;
            for k = 1:length(opSchedule)-1
                gap = opSchedule(k+1).caseInfo.procStartTime - opSchedule(k).caseInfo.procEndTime;
                if gap > 0
                    idleTime = idleTime + gap;
                end
            end
            operatorIdleTime(i) = idleTime;
        end
        
        % Calculate total working time and overtime
        totalProcTime = sum(arrayfun(@(x) x.caseInfo.procTime, opSchedule));
        operatorTotalTime(i) = totalProcTime;
        
        if totalProcTime > maxOperatorTime
            operatorOvertime(i) = totalProcTime - maxOperatorTime;
        end
    end
end

results.operatorIdleTime = operatorIdleTime;
results.totalOperatorIdleTime = sum(operatorIdleTime);
results.meanOperatorIdleTime = mean(operatorIdleTime);
results.operatorOvertime = operatorOvertime;
results.totalOperatorOvertime = sum(operatorOvertime);

% Schedule span
results.scheduleStart = min(labStartMinutes);
results.scheduleEnd = max(labEndTimes);
results.makespan = results.scheduleEnd - results.scheduleStart;

end

function displayScheduleResults(schedule, results, numLabs, labStartTimes, uniqueOperators)
% Display detailed scheduling results

fprintf('\n=== Scheduling Results ===\n');

% Lab schedules
for j = 1:numLabs
    fprintf('\nLab %d (Start: %s):\n', j, labStartTimes{j});
    
    if isempty(schedule.labs{j})
        fprintf('  No cases scheduled\n');
    else
        labCases = schedule.labs{j};
        for k = 1:length(labCases)
            case_k = labCases(k);
            startTimeStr = sprintf('%02d:%02d', floor(case_k.startTime/60), mod(case_k.startTime, 60));
            endTimeStr = sprintf('%02d:%02d', floor(case_k.endTime/60), mod(case_k.endTime, 60));
            
            fprintf('  %s-%s: %s (%s) - %s [%d min]\n', ...
                startTimeStr, endTimeStr, case_k.caseID, case_k.operator, ...
                case_k.procedure, case_k.procTime);
        end
        fprintf('  Lab utilization: %.1f%%\n', results.labUtilization(j) * 100);
    end
end

% Operator schedules
fprintf('\n=== Operator Schedules ===\n');
for i = 1:length(uniqueOperators)
    operator = uniqueOperators{i};
    fprintf('\n%s:\n', operator);
    
    if isKey(schedule.operators, operator)
        opSchedule = schedule.operators(operator);
        
        % Sort by procedure start time
        procStartTimes = arrayfun(@(x) x.caseInfo.procStartTime, opSchedule);
        [~, sortIdx] = sort(procStartTimes);
        opSchedule = opSchedule(sortIdx);
        
        for k = 1:length(opSchedule)
            case_k = opSchedule(k).caseInfo;
            lab = opSchedule(k).lab;
            
            procStartStr = sprintf('%02d:%02d', floor(case_k.procStartTime/60), mod(case_k.procStartTime, 60));
            procEndStr = sprintf('%02d:%02d', floor(case_k.procEndTime/60), mod(case_k.procEndTime, 60));
            
            fprintf('  %s-%s (Lab %d): %s - %s [%d min]\n', ...
                procStartStr, procEndStr, lab, case_k.caseID, case_k.procedure, case_k.procTime);
        end
        
        if results.operatorOvertime(i) > 0
            fprintf('  Overtime: %.1f hours\n', results.operatorOvertime(i)/60);
        end
        if results.operatorIdleTime(i) > 0
            fprintf('  Idle time: %.1f hours\n', results.operatorIdleTime(i)/60);
        end
    else
        fprintf('  No cases assigned\n');
    end
end

% Summary statistics
fprintf('\n=== Summary Statistics ===\n');
fprintf('Schedule span: %.1f hours\n', results.makespan/60);
fprintf('Mean lab utilization: %.1f%%\n', results.meanLabUtilization * 100);
fprintf('Total lab idle time: %.1f hours\n', results.totalLabIdleTime/60);
fprintf('Total operator idle time: %.1f hours\n', results.totalOperatorIdleTime/60);
fprintf('Total operator overtime: %.1f hours\n', results.totalOperatorOvertime/60);

if isfield(results, 'objectiveValue') && ~isnan(results.objectiveValue)
    fprintf('Objective value: %.4f\n', results.objectiveValue);
end

end