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
%   'turnoverTime' - Room turnover time between cases in minutes (default: 15)
%   'enforceMiddnight' - Ensure all cases complete before midnight (default: true)
%   'verbose' - Display detailed output (default: true)
%
% Outputs:
%   schedule - Structure with scheduling results
%   results - Optimization results and statistics

% Parse input arguments
p = inputParser;
addRequired(p, 'cases', @(x) isstruct(x) || isempty(x));
addParameter(p, 'numLabs', 5, @(x) isnumeric(x) && x > 0);
addParameter(p, 'labStartTimes', {'8:00', '8:00', '8:00','8:00','8:00'}, @iscell);
addParameter(p, 'optimizationMetric', 'operatorIdle', @(x) ismember(x, {'operatorIdle', 'labIdle', 'makespan', 'operatorOvertime'}));
addParameter(p, 'caseFilter', 'all', @(x) ismember(x, {'all', 'outpatient', 'inpatient'}));
addParameter(p, 'maxOperatorTime', 480, @(x) isnumeric(x) && x > 0);
addParameter(p, 'turnoverTime', 15, @(x) isnumeric(x) && x >= 0);
addParameter(p, 'enforceMiddnight', true, @islogical);
addParameter(p, 'verbose', true, @islogical);

parse(p, cases, varargin{:});

numLabs = p.Results.numLabs;
labStartTimes = p.Results.labStartTimes;
optimizationMetric = p.Results.optimizationMetric;
caseFilter = p.Results.caseFilter;
maxOperatorTime = p.Results.maxOperatorTime;
turnoverTime = p.Results.turnoverTime;
enforceMiddnight = p.Results.enforceMiddnight;
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
        cases = cases(strcmp({cases.admissionStatus}, 'Hospital Outpatient Surgery (Amb Proc)') | cellfun(@isempty, {cases.admissionStatus}));
    elseif strcmp(caseFilter, 'inpatient')
        cases = cases(strcmp({cases.admissionStatus}, 'Inpatient'));
    end
    if verbose
        fprintf('Filtered to %d %s cases\n', length(cases), caseFilter);
    end
end

if isempty(cases)
    if verbose
        fprintf('No cases to schedule after filtering.\n');
    end
    
    % Convert lab start times to minutes since midnight for empty case
    labStartMinutes = zeros(numLabs, 1);
    for i = 1:numLabs
        timeStr = labStartTimes{i};
        timeParts = split(timeStr, ':');
        labStartMinutes(i) = str2double(timeParts{1}) * 60 + str2double(timeParts{2});
    end
    
    schedule = struct();
    schedule.labs = cell(numLabs, 1);
    schedule.operators = containers.Map();
    results = struct();
    results.labUtilization = zeros(numLabs, 1);
    results.meanLabUtilization = 0;
    results.totalLabIdleTime = 0;
    results.operatorIdleTime = [];
    results.totalOperatorIdleTime = 0;
    results.meanOperatorIdleTime = 0;
    results.operatorOvertime = [];
    results.totalOperatorOvertime = 0;
    results.scheduleStart = min(labStartMinutes);
    results.scheduleEnd = min(labStartMinutes);
    results.makespan = 0;
    results.optimizationMetric = optimizationMetric;
    results.objectiveValue = 0;
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
if enforceMiddnight
    % Constrain to midnight (1440 minutes = 24 hours)
    maxHorizon = 1440;  % 24:00 (midnight)
else
    maxHorizon = max(labStartMinutes) + totalProcTime + 120;
end

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

% Pre-filter valid time slots for each lab to reduce computation
validTimeSlots = cell(numLabs, 1);
for j = 1:numLabs
    labStart = labStartMinutes(j);
    validTimeSlots{j} = find(timeSlots >= labStart);
end

% Estimate constraint counts for sparse matrix pre-allocation
numConstraint1 = numCases;  % Each case scheduled once
numConstraint2 = numLabs * numTimeSlots;  % Lab capacity
numConstraint3 = numOperators * numTimeSlots;  % Operator availability

% Constraint 4: Lab start time constraints (only invalid time slots)
numConstraint4 = 0;
for j = 1:numLabs
    labStart = labStartMinutes(j);
    invalidTimeSlots = find(timeSlots < labStart);
    numConstraint4 = numConstraint4 + length(invalidTimeSlots) * sum(labPreferences(:, j));
end
numConstraint4 = max(0, numConstraint4);  % Ensure non-negative

numConstraint5 = max(0, numLabs - 1);  % Symmetry breaking

% Constraint 6 (priority) - estimate based on priority cases
priorityCaseCount = sum(casePriorities == 1);
if priorityCaseCount > 0
    numConstraint6 = priorityCaseCount * (numCases - priorityCaseCount) * numLabs * 10;  % Conservative estimate
else
    numConstraint6 = 0;
end

totalConstraints = numConstraint1 + numConstraint2 + numConstraint3 + numConstraint4 + numConstraint5 + numConstraint6;
totalEqConstraints = numConstraint1;

if verbose
    fprintf('Estimated constraints: %d equality, %d inequality\n', totalEqConstraints, totalConstraints - totalEqConstraints);
    fprintf('Pre-allocating sparse matrices...\n');
end

% Pre-allocate sparse constraint matrices
% Estimate 5-10 non-zeros per constraint row on average
avgNonZerosPerRow = min(10, numVars/10);
Aeq = spalloc(totalEqConstraints, numVars, totalEqConstraints * avgNonZerosPerRow);
beq = zeros(totalEqConstraints, 1);
A = spalloc(totalConstraints - totalEqConstraints, numVars, (totalConstraints - totalEqConstraints) * avgNonZerosPerRow);
b = zeros(totalConstraints - totalEqConstraints, 1);

% Track current row indices
eqRowIdx = 0;
ineqRowIdx = 0;

% Constraint 1: Each case must be scheduled exactly once
if verbose
    fprintf('Building constraint 1 (case assignment)...');
end
for i = 1:numCases
    eqRowIdx = eqRowIdx + 1;
    for j = 1:numLabs
        if labPreferences(i, j) == 1
            % Only consider valid time slots for this lab
            for t = validTimeSlots{j}
                Aeq(eqRowIdx, getVarIndex(i, j, t)) = 1;
            end
        end
    end
    beq(eqRowIdx) = 1;
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

% Build constraints in parallel for each lab
labConstraints = cell(numLabs, 1);
labConstraintCounts = zeros(numLabs, 1);

parfor j = 1:numLabs
    labRows = [];
    labValues = [];
    labCols = [];
    constraintCount = 0;
    
    validTimes = validTimeSlots{j};
    for t_idx = 1:length(validTimes)
        t = validTimes(t_idx);
        currentTime = timeSlots(t);
        constraintCount = constraintCount + 1;
        
        for i = 1:numCases
            if labPreferences(i, j) == 1
                for t_start = validTimes
                    startTime = timeSlots(t_start);
                    caseEndTime = startTime + caseSetupTimes(i) + caseProcTimes(i) + casePostTimes(i) + turnoverTime;
                    
                    if startTime <= currentTime && caseEndTime > currentTime
                        varIdx = getVarIndex(i, j, t_start);
                        labRows = [labRows; constraintCount];
                        labCols = [labCols; varIdx];
                        labValues = [labValues; 1];
                    end
                end
            end
        end
    end
    
    if isempty(labRows)
        % Create empty sparse matrix with correct dimensions
        labConstraints{j} = sparse(constraintCount, numVars);
    else
        labConstraints{j} = sparse(labRows, labCols, labValues, constraintCount, numVars);
    end
    labConstraintCounts(j) = constraintCount;
end

% Combine lab constraints
totalLabConstraints = sum(labConstraintCounts);
if totalLabConstraints > 0
    % Calculate total non-zeros
    totalNonZeros = 0;
    for j = 1:numLabs
        if ~isempty(labConstraints{j})
            totalNonZeros = totalNonZeros + nnz(labConstraints{j});
        end
    end
    
    labConstraintMatrix = spalloc(totalLabConstraints, numVars, totalNonZeros);
    currentRow = 0;
    for j = 1:numLabs
        if labConstraintCounts(j) > 0
            rows = currentRow + (1:labConstraintCounts(j));
            labConstraintMatrix(rows, :) = labConstraints{j};
            currentRow = currentRow + labConstraintCounts(j);
        end
    end
    
    % Add to main constraint matrix
    A(ineqRowIdx + (1:totalLabConstraints), :) = labConstraintMatrix;
    b(ineqRowIdx + (1:totalLabConstraints)) = 1;
    ineqRowIdx = ineqRowIdx + totalLabConstraints;
end

if verbose
    fprintf(' Complete\n');
end

% Constraint 3: Operator availability (one lab at a time during procedure)
if verbose
    fprintf('Building constraint 3 (operator availability)...');
end

% Build constraints in parallel for each operator
operatorConstraints = cell(numOperators, 1);
operatorConstraintCounts = zeros(numOperators, 1);

parfor op = 1:numOperators
    opCases = find(caseOperators == op);
    if isempty(opCases)
        operatorConstraints{op} = sparse(0, numVars);
        operatorConstraintCounts(op) = 0;
        continue;
    end
    
    opRows = [];
    opValues = [];
    opCols = [];
    constraintCount = 0;
    
    for t = 1:numTimeSlots
        currentTime = timeSlots(t);
        constraintCount = constraintCount + 1;
        
        for case_idx = opCases
            for j = 1:numLabs
                if labPreferences(case_idx, j) == 1
                    validTimes = validTimeSlots{j};
                    for t_start = validTimes
                        startTime = timeSlots(t_start);
                        procStartTime = startTime + caseSetupTimes(case_idx);
                        procEndTime = procStartTime + caseProcTimes(case_idx);
                        
                        if procStartTime <= currentTime && procEndTime > currentTime
                            varIdx = getVarIndex(case_idx, j, t_start);
                            opRows = [opRows; constraintCount];
                            opCols = [opCols; varIdx];
                            opValues = [opValues; 1];
                        end
                    end
                end
            end
        end
    end
    
    if isempty(opRows)
        % Create empty sparse matrix with correct dimensions
        operatorConstraints{op} = sparse(constraintCount, numVars);
    else
        operatorConstraints{op} = sparse(opRows, opCols, opValues, constraintCount, numVars);
    end
    operatorConstraintCounts(op) = constraintCount;
end

% Combine operator constraints
totalOpConstraints = sum(operatorConstraintCounts);
if totalOpConstraints > 0
    % Calculate total non-zeros safely
    totalNonZeros = 0;
    for op = 1:numOperators
        if ~isempty(operatorConstraints{op})
            totalNonZeros = totalNonZeros + nnz(operatorConstraints{op});
        end
    end
    
    opConstraintMatrix = spalloc(totalOpConstraints, numVars, totalNonZeros);
    currentRow = 0;
    for op = 1:numOperators
        if operatorConstraintCounts(op) > 0
            rows = currentRow + (1:operatorConstraintCounts(op));
            opConstraintMatrix(rows, :) = operatorConstraints{op};
            currentRow = currentRow + operatorConstraintCounts(op);
        end
    end
    
    % Add to main constraint matrix
    A(ineqRowIdx + (1:totalOpConstraints), :) = opConstraintMatrix;
    b(ineqRowIdx + (1:totalOpConstraints)) = 1;
    ineqRowIdx = ineqRowIdx + totalOpConstraints;
end

if verbose
    fprintf(' Complete\n');
end

% Constraint 4: Lab start time constraints
if verbose
    fprintf('Building constraint 4 (lab start times)...');
end

% Build constraint 4 with proper vector handling
constraint4Rows = [];
constraint4Cols = [];

for j = 1:numLabs
    labStart = labStartMinutes(j);
    invalidTimeSlots = find(timeSlots < labStart);
    
    for i = 1:numCases
        if labPreferences(i, j) == 1
            % Add one constraint per invalid time slot
            numInvalidSlots = length(invalidTimeSlots);
            if numInvalidSlots > 0
                % Add constraint indices (one per invalid slot)
                startConstraintIdx = length(constraint4Rows) + 1;
                endConstraintIdx = startConstraintIdx + numInvalidSlots - 1;
                newRows = (startConstraintIdx:endConstraintIdx)';
                
                % Add variable indices
                newCols = arrayfun(@(t) getVarIndex(i, j, t), invalidTimeSlots);
                
                constraint4Rows = [constraint4Rows; newRows];
                constraint4Cols = [constraint4Cols; newCols(:)];
            end
        end
    end
end

if ~isempty(constraint4Rows)
    constraint4Values = ones(length(constraint4Rows), 1);
    numConstraint4 = max(constraint4Rows);
    constraint4Matrix = sparse(constraint4Rows, constraint4Cols, constraint4Values, numConstraint4, numVars);
    A(ineqRowIdx + (1:numConstraint4), :) = constraint4Matrix;
    b(ineqRowIdx + (1:numConstraint4)) = 0;
    ineqRowIdx = ineqRowIdx + numConstraint4;
end

if verbose
    fprintf(' Complete\n');
end

% Constraint 5: Symmetry breaking (prefer lower-numbered labs to reduce search space)
% Since labs are identical, ensure total usage of lab j >= total usage of lab j+1
if verbose
    fprintf('Building constraint 5 (symmetry breaking)...');
end

constraint5Count = numLabs - 1;
if constraint5Count > 0
    % Estimate number of non-zeros for pre-allocation
    totalEntries = 0;
    for j = 1:numLabs-1
        for i = 1:numCases
            if labPreferences(i, j) == 1
                totalEntries = totalEntries + length(validTimeSlots{j});
            end
            if labPreferences(i, j+1) == 1
                totalEntries = totalEntries + length(validTimeSlots{j+1});
            end
        end
    end
    
    rows = zeros(totalEntries, 1);
    cols = zeros(totalEntries, 1);
    values = zeros(totalEntries, 1);
    entryIdx = 0;
    
    for j = 1:numLabs-1
        for i = 1:numCases
            for t = validTimeSlots{j}
                if labPreferences(i, j) == 1
                    entryIdx = entryIdx + 1;
                    rows(entryIdx) = j;
                    cols(entryIdx) = getVarIndex(i, j, t);
                    values(entryIdx) = -1;  % Negative because we want lab j+1 - lab j <= 0
                end
            end
            for t = validTimeSlots{j+1}
                if labPreferences(i, j+1) == 1
                    entryIdx = entryIdx + 1;
                    rows(entryIdx) = j;
                    cols(entryIdx) = getVarIndex(i, j+1, t);
                    values(entryIdx) = 1;
                end
            end
        end
    end
    
    % Trim to actual size
    rows = rows(1:entryIdx);
    cols = cols(1:entryIdx);
    values = values(1:entryIdx);
    
    constraint5Matrix = sparse(rows, cols, values, constraint5Count, numVars);
    A(ineqRowIdx + (1:constraint5Count), :) = constraint5Matrix;
    b(ineqRowIdx + (1:constraint5Count)) = 0;
    ineqRowIdx = ineqRowIdx + constraint5Count;
end

if verbose
    fprintf(' Complete\n');
end

% Constraint 6: Priority constraints (priority 1 cases must be first for operator)
if verbose
    fprintf('Building constraint 6 (priority constraints)...');
end

% Count priority constraints and pre-allocate
constraint6Count = 0;
totalEntries = 0;

% First pass: count constraints and entries
for op = 1:numOperators
    opCases = find(caseOperators == op);
    priorityCases = opCases(casePriorities(opCases) == 1);
    
    for priorityCase = priorityCases
        for normalCase = opCases
            if normalCase ~= priorityCase && casePriorities(normalCase) ~= 1
                for j = 1:numLabs
                    if labPreferences(priorityCase, j) == 1 && labPreferences(normalCase, j) == 1
                        validTimesJ = validTimeSlots{j};
                        numValidTimes = length(validTimesJ);
                        numConstraintsForThisPair = sum(1:numValidTimes);  % triangular number
                        constraint6Count = constraint6Count + numConstraintsForThisPair;
                        totalEntries = totalEntries + 2 * numConstraintsForThisPair;  % 2 variables per constraint
                    end
                end
            end
        end
    end
end

if constraint6Count > 0
    rows = zeros(totalEntries, 1);
    cols = zeros(totalEntries, 1);
    values = ones(totalEntries, 1);
    constraintIdx = 0;
    entryIdx = 0;
    
    % Second pass: build constraints
    for op = 1:numOperators
        opCases = find(caseOperators == op);
        priorityCases = opCases(casePriorities(opCases) == 1);
        
        for priorityCase = priorityCases
            for normalCase = opCases
                if normalCase ~= priorityCase && casePriorities(normalCase) ~= 1
                    for j = 1:numLabs
                        if labPreferences(priorityCase, j) == 1 && labPreferences(normalCase, j) == 1
                            validTimesJ = validTimeSlots{j};
                            for t_priority_idx = 1:length(validTimesJ)
                                t_priority = validTimesJ(t_priority_idx);
                                for t_normal_idx = 1:t_priority_idx
                                    t_normal = validTimesJ(t_normal_idx);
                                    
                                    constraintIdx = constraintIdx + 1;
                                    
                                    % Priority case variable
                                    entryIdx = entryIdx + 1;
                                    rows(entryIdx) = constraintIdx;
                                    cols(entryIdx) = getVarIndex(priorityCase, j, t_priority);
                                    
                                    % Normal case variable
                                    entryIdx = entryIdx + 1;
                                    rows(entryIdx) = constraintIdx;
                                    cols(entryIdx) = getVarIndex(normalCase, j, t_normal);
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    
    % Trim to actual size
    rows = rows(1:entryIdx);
    cols = cols(1:entryIdx);
    values = values(1:entryIdx);
    
    constraint6Matrix = sparse(rows, cols, values, constraintIdx, numVars);
    A(ineqRowIdx + (1:constraintIdx), :) = constraint6Matrix;
    b(ineqRowIdx + (1:constraintIdx)) = 1;
    ineqRowIdx = ineqRowIdx + constraintIdx;
end

if verbose
    fprintf(' Complete\n');
end

% Constraint 7: Midnight completion constraint (all cases must finish before 24:00)
if enforceMiddnight
    if verbose
        fprintf('Building constraint 7 (midnight completion)...');
    end
    
    midnightMinutes = 1440;  % 24:00 = 1440 minutes
    constraint7Rows = [];
    constraint7Cols = [];
    
    for i = 1:numCases
        for j = 1:numLabs
            if labPreferences(i, j) == 1
                for t = validTimeSlots{j}
                    startTime = timeSlots(t);
                    caseEndTime = startTime + caseSetupTimes(i) + caseProcTimes(i) + casePostTimes(i) + turnoverTime;
                    
                    % If this assignment would cause the case to end after midnight, add constraint to prevent it
                    if caseEndTime > midnightMinutes
                        constraint7Rows = [constraint7Rows; length(constraint7Rows) + 1];
                        constraint7Cols = [constraint7Cols; getVarIndex(i, j, t)];
                    end
                end
            end
        end
    end
    
    if ~isempty(constraint7Rows)
        constraint7Values = ones(length(constraint7Rows), 1);
        numConstraint7 = max(constraint7Rows);
        constraint7Matrix = sparse(constraint7Rows, constraint7Cols, constraint7Values, numConstraint7, numVars);
        A(ineqRowIdx + (1:numConstraint7), :) = constraint7Matrix;
        b(ineqRowIdx + (1:numConstraint7)) = 0;  % These assignments are forbidden (≤ 0)
        ineqRowIdx = ineqRowIdx + numConstraint7;
    end
    
    if verbose
        fprintf(' Complete\n');
    end
end

% Objective function
if verbose
    fprintf('Building objective function (%s)...', optimizationMetric);
end
f = zeros(numVars, 1);

switch optimizationMetric
    case 'operatorIdle'
        % Minimize total operator idle time by preferring earlier start times
        % This encourages compact scheduling which naturally minimizes gaps
        for i = 1:numCases
            for j = 1:numLabs
                for t = validTimeSlots{j}
                    if labPreferences(i, j) == 1
                        % Penalty increases with later start times
                        % This encourages scheduling cases as early as possible
                        timePenalty = timeSlots(t) / 1000;
                        f(getVarIndex(i, j, t)) = f(getVarIndex(i, j, t)) + timePenalty;
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

% Trim constraint matrices to actual size\nAeq = Aeq(1:eqRowIdx, :);\nbeq = beq(1:eqRowIdx);\nA = A(1:ineqRowIdx, :);\nb = b(1:ineqRowIdx);\n\nif verbose\n    fprintf('Final problem size: %d variables, %d constraints (%d equality, %d inequality)\\n', ...\n        numVars, eqRowIdx + ineqRowIdx, eqRowIdx, ineqRowIdx);\n    fprintf('Constraint matrix sparsity: %.2f%% (A), %.2f%% (Aeq)\\n', ...\n        100*(1-nnz(A)/numel(A)), 100*(1-nnz(Aeq)/numel(Aeq)));\n    fprintf('Solving integer linear program...\\n');\nend

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
    [schedule, results] = greedySchedule(cases, numLabs, labStartMinutes, caseFilter, verbose, turnoverTime, enforceMiddnight);
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
                caseInfo.endTime = startTime + caseInfo.setupTime + caseInfo.procTime + caseInfo.postTime + turnoverTime;
                caseInfo.procStartTime = startTime + caseInfo.setupTime;
                caseInfo.procEndTime = caseInfo.procStartTime + caseInfo.procTime;
                caseInfo.turnoverTime = turnoverTime;
                
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

function [schedule, results] = greedySchedule(cases, numLabs, labStartMinutes, caseFilter, verbose, turnoverTime, enforceMiddnight)
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
    
    % Find best lab (earliest available) that respects midnight constraint
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
    
    % Check midnight constraint if enforced
    if enforceMiddnight
        caseEndTime = bestStartTime + case_i.setupTime + case_i.procTime + case_i.postTime + turnoverTime;
        if caseEndTime > 1440  % After midnight
            fprintf('Warning: Case %s cannot be scheduled before midnight - skipping\n', case_i.caseID);
            continue;  % Skip this case
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
    caseInfo.endTime = bestStartTime + caseInfo.setupTime + caseInfo.procTime + caseInfo.postTime + turnoverTime;
    caseInfo.procStartTime = bestStartTime + caseInfo.setupTime;
    caseInfo.procEndTime = caseInfo.procStartTime + caseInfo.procTime;
    caseInfo.turnoverTime = turnoverTime;
    
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