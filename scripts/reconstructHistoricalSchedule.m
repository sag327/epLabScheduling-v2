function [historicalSchedule, results] = reconstructHistoricalSchedule(historicalData, targetDate, varargin)
% Reconstruct the actual historical schedule for a specific date
% Creates a schedule structure in the same format as scheduleHistoricalCases
%
% Inputs:
%   historicalData - Historical data structure from loadHistoricalDataFromFile
%   targetDate - Date string (e.g., '05-01-2025') or datetime object
%
% Optional Parameters (Name-Value pairs):
%   'TurnoverTime' - Estimated turnover time between cases (default: 15 minutes)
%   'Debug' - Show debug output (default: false)
%
% Outputs:
%   historicalSchedule - Schedule structure matching scheduleHistoricalCases format:
%     .labs - Cell array of lab schedules (indexed by room number)
%     .operators - Map of operator schedules
%   results - Results structure with historical performance metrics
%
% Example:
%   historicalData = loadHistoricalDataFromFile('procedureDurationsB.xlsx');
%   [schedule, results] = reconstructHistoricalSchedule(historicalData, '05-01-2025');

% Parse input parameters
p = inputParser;
addRequired(p, 'historicalData', @isstruct);
addRequired(p, 'targetDate');
addParameter(p, 'TurnoverTime', 15, @(x) isnumeric(x) && x >= 0);
addParameter(p, 'Debug', false, @islogical);

parse(p, historicalData, targetDate, varargin{:});

% Extract parameters
turnoverTime = p.Results.TurnoverTime;
debugMode = p.Results.Debug;

% Convert target date to the format stored in historical data
if ischar(targetDate) || isstring(targetDate)
    targetStr = char(targetDate);
    
    % Check if input is in MM-DD-YYYY format
    if contains(targetStr, '-') && length(targetStr) == 10
        parts = split(targetStr, '-');
        if length(parts) == 3
            try
                % Convert MM-DD-YYYY to datetime, then to dd-mmm-yyyy format
                month = str2double(parts{1});
                day = str2double(parts{2});
                year = str2double(parts{3});
                dt = datetime(year, month, day);
                targetDateFormatted = string(datestr(dt, 'dd-mmm-yyyy'));
                if debugMode
                    fprintf('Converted input date %s to format: %s\n', targetStr, targetDateFormatted);
                end
            catch
                error('Invalid date format. Use MM-DD-YYYY (e.g., "05-01-2025")');
            end
        else
            error('Invalid date format. Use MM-DD-YYYY (e.g., "05-01-2025")');
        end
    else
        % Try to parse as is and convert to expected format
        try
            dt = datetime(targetStr);
            targetDateFormatted = string(datestr(dt, 'dd-mmm-yyyy'));
            if debugMode
                fprintf('Converted input date %s to format: %s\n', targetStr, targetDateFormatted);
            end
        catch
            error('Invalid date format. Use MM-DD-YYYY (e.g., "05-01-2025")');
        end
    end
elseif isdatetime(targetDate)
    targetDateFormatted = string(datestr(targetDate, 'dd-mmm-yyyy'));
    if debugMode
        fprintf('Converted datetime input to format: %s\n', targetDateFormatted);
    end
else
    error('targetDate must be a string, char array, or datetime object');
end

% Find cases matching the target date
dateMatches = strcmp(string(historicalData.date), targetDateFormatted);
numMatches = sum(dateMatches);

if numMatches == 0
    fprintf('No cases found for date: %s\n', targetDateFormatted);
    
    % Show available dates
    uniqueDates = unique(string(historicalData.date));
    uniqueDates = uniqueDates(~ismissing(uniqueDates));
    fprintf('Available dates in dataset:\n');
    for i = 1:min(10, length(uniqueDates))
        casesOnDate = sum(strcmp(string(historicalData.date), uniqueDates(i)));
        fprintf('  %s (%d cases)\n', uniqueDates(i), casesOnDate);
    end
    if length(uniqueDates) > 10
        fprintf('  ... and %d more dates\n', length(uniqueDates) - 10);
    end
    
    historicalSchedule = struct('labs', {{}}, 'operators', containers.Map());
    results = struct();
    return;
end

fprintf('Reconstructing historical schedule for %s (%d cases)\n', targetDateFormatted, numMatches);

% Extract matching cases and filter out those with missing start times
matchingIndices = find(dateMatches);
validStartTimeIndices = ~ismissing(historicalData.procedureStartTimeOfDay(matchingIndices));
filteredIndices = matchingIndices(validStartTimeIndices);
numValidCases = length(filteredIndices);

if numValidCases < numMatches
    fprintf('Filtering out %d cases with missing start times (keeping %d of %d cases)\n', ...
        numMatches - numValidCases, numValidCases, numMatches);
end

if numValidCases == 0
    fprintf('No cases with valid start times found for date: %s\n', targetDateFormatted);
    historicalSchedule = struct('labs', {{}}, 'operators', containers.Map());
    results = struct();
    return;
end

fprintf('Reconstructing historical schedule for %s (%d valid cases)\n', targetDateFormatted, numValidCases);

historicalCases = struct();

for i = 1:numValidCases
    idx = filteredIndices(i);
    
    % Basic case information
    historicalCases(i).caseID = char(historicalData.caseID(idx));
    historicalCases(i).operator = char(historicalData.surgeon(idx));
    historicalCases(i).procedure = char(historicalData.procedure(idx));
    historicalCases(i).service = char(historicalData.service(idx));
    historicalCases(i).location = char(historicalData.location(idx));
    
    % Room assignment (this is the key difference from optimized scheduling)
    if isfield(historicalData, 'room') && ~ismissing(historicalData.room(idx))
        historicalCases(i).roomAssignment = char(historicalData.room(idx));
    else
        historicalCases(i).roomAssignment = 'Unknown';
    end
    
    % Time information from historical data
    historicalCases(i).setupTime = ensureValidTime(historicalData.setupTime(idx), 30);
    historicalCases(i).procTime = ensureValidTime(historicalData.procedureTime(idx), 120);
    historicalCases(i).postTime = ensureValidTime(historicalData.postTime(idx), 15);
    
    % Extract actual start and end times from historical timestamps
    if ~ismissing(historicalData.procedureStartTimeOfDay(idx))
        % Convert duration to minutes since midnight
        startTimeOfDay = historicalData.procedureStartTimeOfDay(idx);
        historicalCases(i).actualProcStartTime = minutes(startTimeOfDay);
        
        % Calculate other times based on actual procedure start
        historicalCases(i).actualStartTime = historicalCases(i).actualProcStartTime - historicalCases(i).setupTime;
        historicalCases(i).actualProcEndTime = historicalCases(i).actualProcStartTime + historicalCases(i).procTime;
        historicalCases(i).actualEndTime = historicalCases(i).actualProcEndTime + historicalCases(i).postTime;
    else
        % Fallback if no actual times available
        fprintf('Warning: No actual start time for case %s, using estimated times\n', historicalCases(i).caseID);
        historicalCases(i).actualStartTime = NaN;
        historicalCases(i).actualProcStartTime = NaN;
        historicalCases(i).actualProcEndTime = NaN;
        historicalCases(i).actualEndTime = NaN;
    end
    
    % Store estimated turnover time
    historicalCases(i).turnoverTime = turnoverTime;
    
    % Add admission status if available
    if isfield(historicalData, 'admissionStatus') && ~ismissing(historicalData.admissionStatus(idx))
        historicalCases(i).admissionStatus = char(historicalData.admissionStatus(idx));
    else
        historicalCases(i).admissionStatus = 'Unknown';
    end
end

% Determine number of unique rooms used and create mapping
if isfield(historicalData, 'room')
    historicalRooms = historicalData.room(filteredIndices);
    historicalRooms = historicalRooms(~ismissing(historicalRooms));
    if ~isempty(historicalRooms)
        uniqueRooms = unique(historicalRooms);
        numLabs = length(uniqueRooms);
        if debugMode
            fprintf('Historical rooms used: %s\n', strjoin(string(uniqueRooms), ', '));
        end
    else
        numLabs = 1; % Default to 1 room if no room data
        uniqueRooms = {'Unknown Room'};
    end
else
    numLabs = 1; % Default to 1 room if no room data
    uniqueRooms = {'Unknown Room'};
end

% Create room mapping (room name -> lab index, lab index -> room name)
roomToLabMap = containers.Map();
labToRoomMap = containers.Map('KeyType', 'int32', 'ValueType', 'char');

for i = 1:numLabs
    roomName = char(uniqueRooms{i});
    roomToLabMap(roomName) = i;
    labToRoomMap(i) = roomName;
end

if debugMode
    fprintf('Room mapping created:\n');
    for i = 1:numLabs
        fprintf('  Lab %d -> %s\n', i, labToRoomMap(i));
    end
end

% Initialize schedule structure
historicalSchedule = struct();
historicalSchedule.labs = cell(numLabs, 1);
historicalSchedule.operators = containers.Map();

% Add lab mapping information
historicalSchedule.labMapping = labToRoomMap; % Lab index -> actual room name
historicalSchedule.numLabs = numLabs;

% Assign cases to rooms based on historical room assignments
for i = 1:numValidCases
    caseInfo = historicalCases(i);
    
    % Determine lab index from room assignment
    if isKey(roomToLabMap, caseInfo.roomAssignment)
        labIdx = roomToLabMap(caseInfo.roomAssignment);
    else
        labIdx = 1; % Default to lab 1 if room not found
        if debugMode
            fprintf('Unknown room "%s" for case %s, assigning to lab 1\n', ...
                caseInfo.roomAssignment, caseInfo.caseID);
        end
    end
    
    % Create case info structure matching scheduleHistoricalCases format
    scheduleCase = struct();
    scheduleCase.caseID = caseInfo.caseID;
    scheduleCase.operator = caseInfo.operator;
    scheduleCase.procedure = caseInfo.procedure;
    
    % Use actual historical times if available, otherwise use estimated times
    if ~isnan(caseInfo.actualStartTime)
        scheduleCase.startTime = caseInfo.actualStartTime;
        scheduleCase.procStartTime = caseInfo.actualProcStartTime;
        scheduleCase.procEndTime = caseInfo.actualProcEndTime;
        scheduleCase.endTime = caseInfo.actualEndTime + turnoverTime; % Add turnover
    else
        % Use estimated times (this shouldn't happen often with good historical data)
        scheduleCase.startTime = 8 * 60; % Default start at 8 AM
        scheduleCase.procStartTime = scheduleCase.startTime + caseInfo.setupTime;
        scheduleCase.procEndTime = scheduleCase.procStartTime + caseInfo.procTime;
        scheduleCase.endTime = scheduleCase.procEndTime + caseInfo.postTime + turnoverTime;
    end
    
    scheduleCase.setupTime = caseInfo.setupTime;
    scheduleCase.procTime = caseInfo.procTime;
    scheduleCase.postTime = caseInfo.postTime;
    scheduleCase.turnoverTime = turnoverTime;
    
    % Add admission status
    scheduleCase.admissionStatus = caseInfo.admissionStatus;
    
    % Add to lab schedule
    if isempty(historicalSchedule.labs{labIdx})
        historicalSchedule.labs{labIdx} = scheduleCase;
    else
        historicalSchedule.labs{labIdx}(end+1) = scheduleCase;
    end
    
    % Add to operator schedule
    if isKey(historicalSchedule.operators, caseInfo.operator)
        opSchedule = historicalSchedule.operators(caseInfo.operator);
        if isstruct(opSchedule) && isfield(opSchedule, 'lab')
            % Convert single struct to array
            opSchedule = [opSchedule, struct('lab', labIdx, 'caseInfo', scheduleCase)];
        else
            opSchedule(end+1) = struct('lab', labIdx, 'caseInfo', scheduleCase);
        end
        historicalSchedule.operators(caseInfo.operator) = opSchedule;
    else
        historicalSchedule.operators(caseInfo.operator) = struct('lab', labIdx, 'caseInfo', scheduleCase);
    end
end

% Sort cases within each lab by start time
for j = 1:numLabs
    if ~isempty(historicalSchedule.labs{j})
        [~, sortIdx] = sort([historicalSchedule.labs{j}.startTime]);
        historicalSchedule.labs{j} = historicalSchedule.labs{j}(sortIdx);
    end
end

% Calculate performance metrics
results = calculateHistoricalMetrics(historicalSchedule, historicalCases, debugMode);

% Display summary
if debugMode
    fprintf('\n=== HISTORICAL SCHEDULE RECONSTRUCTION SUMMARY ===\n');
    fprintf('Date: %s\n', targetDateFormatted);
    fprintf('Total cases: %d\n', numValidCases);
    fprintf('Labs used: %d\n', numLabs);
    
    % Show lab mapping
    fprintf('Lab mapping:\n');
    for i = 1:numLabs
        casesInLab = length(historicalSchedule.labs{i});
        fprintf('  Lab %d: %s (%d cases)\n', i, labToRoomMap(i), casesInLab);
    end
    
    fprintf('Operators: %d\n', length(keys(historicalSchedule.operators)));
    fprintf('Schedule span: %.1f hours (%.1f to %.1f)\n', ...
        results.makespan/60, results.scheduleStart/60, results.scheduleEnd/60);
    
    if results.scheduleEnd/60 > 18
        overtimeHours = results.scheduleEnd/60 - 18;
        fprintf('WARNING: Schedule extends %.1f hours past 6 PM\n', overtimeHours);
    end
end

fprintf('Historical schedule reconstruction complete!\n');

end

%% Helper function to ensure valid time values
function validTime = ensureValidTime(timeValue, defaultValue)
    if isnan(timeValue) || timeValue <= 0
        validTime = defaultValue;
    else
        validTime = timeValue;
    end
end

%% Helper function to calculate historical performance metrics
function results = calculateHistoricalMetrics(schedule, historicalCases, debugMode)
    results = struct();
    
    % Find schedule start and end times
    allStartTimes = [];
    allEndTimes = [];
    
    for j = 1:length(schedule.labs)
        if ~isempty(schedule.labs{j})
            labCases = schedule.labs{j};
            allStartTimes = [allStartTimes, [labCases.startTime]];
            allEndTimes = [allEndTimes, [labCases.endTime]];
        end
    end
    
    if ~isempty(allStartTimes)
        results.scheduleStart = min(allStartTimes);
        results.scheduleEnd = max(allEndTimes);
        results.makespan = results.scheduleEnd - results.scheduleStart;
    else
        results.scheduleStart = 0;
        results.scheduleEnd = 0;
        results.makespan = 0;
    end
    
    % Calculate lab utilization
    numLabs = length(schedule.labs);
    labUtilization = zeros(numLabs, 1);
    
    for j = 1:numLabs
        if ~isempty(schedule.labs{j})
            labCases = schedule.labs{j};
            totalCaseTime = sum([labCases.procTime]) + sum([labCases.setupTime]) + sum([labCases.postTime]);
            if results.makespan > 0
                labUtilization(j) = totalCaseTime / results.makespan;
            end
        end
    end
    
    results.labUtilization = labUtilization;
    results.meanLabUtilization = mean(labUtilization);
    
    % Calculate operator metrics
    operatorNames = keys(schedule.operators);
    results.totalOperatorIdleTime = 0;
    results.totalOperatorOvertime = 0;
    
    for i = 1:length(operatorNames)
        % For now, set basic operator metrics (could be enhanced later)
        results.totalOperatorIdleTime = results.totalOperatorIdleTime + 0; % Placeholder
        results.totalOperatorOvertime = results.totalOperatorOvertime + 0; % Placeholder
    end
    
    % Additional metrics
    results.totalCases = length(historicalCases);
    results.totalOperators = length(operatorNames);
    results.optimizationMetric = 'historical';
    results.objectiveValue = NaN;
    
    if debugMode
        fprintf('  Historical metrics calculated:\n');
        fprintf('    Makespan: %.1f hours\n', results.makespan/60);
        fprintf('    Mean lab utilization: %.1f%%\n', results.meanLabUtilization*100);
        fprintf('    Schedule start: %s\n', formatTime(results.scheduleStart));
        fprintf('    Schedule end: %s\n', formatTime(results.scheduleEnd));
    end
end

%% Helper function to format time for display
function timeStr = formatTime(minutes)
    hours = floor(minutes / 60);
    mins = mod(minutes, 60);
    timeStr = sprintf('%02d:%02d', hours, mins);
end