function analysisResults = analyzeHistoricalData(historicalData, varargin)
% Analyzes historical procedure data and schedule structures
% Provides comprehensive statistical analysis, schedule performance metrics, 
% and operator insights for EP lab operations
%
% Syntax:
%   analyzeHistoricalData(historicalData)
%   analyzeHistoricalData(historicalData, Name, Value, ...)
%
% Required Input:
%   historicalData - Historical data structure from loadHistoricalDataFromFile
%                   Must contain fields: caseID, date, surgeon, procedure
%
% Name-Value Parameters:
%   'HistoricalSchedules' - containers.Map with reconstructed schedules (default: [])
%                          Optional. Enables schedule performance analysis.
%   'ShowStats'          - logical, display detailed statistics (default: true)
%   'SaveReport'         - logical, save analysis to text file (default: false)  
%   'ReportFile'         - char/string, output file name (default: 'historical_analysis_report.txt')
%
% Examples:
%   % Basic analysis (data only)
%   [historicalData, ~] = loadHistoricalDataFromFile();
%   analyzeHistoricalData(historicalData);
%
%   % Full analysis with schedules
%   [historicalData, schedules] = loadHistoricalDataFromFile();
%   analyzeHistoricalData(historicalData, 'HistoricalSchedules', schedules);
%
%   % Save report without displaying
%   analyzeHistoricalData(historicalData, 'HistoricalSchedules', schedules, ...
%                        'ShowStats', false, 'SaveReport', true, ...
%                        'ReportFile', 'ep_lab_analysis.txt');
%
% Output:
%   analysisResults - Structure containing comprehensive analysis results:
%     .datasetSummary     - Basic dataset statistics
%     .procedureAnalysis  - Procedure type and duration statistics
%     .surgeonAnalysis    - Surgeon workload and performance metrics
%     .timeAnalysis       - Time duration and scheduling patterns
%     .roomAnalysis       - Room utilization statistics
%     .scheduleAnalysis   - Schedule performance metrics (if schedules provided)
%     .operatorAnalysis   - Operator workload and idle time (if schedules provided)
%     .labFlipAnalysis    - Lab switching and flip statistics (if schedules provided)
%
%   Also displays analysis summary if ShowStats is true
%
% See also: loadHistoricalDataFromFile, reconstructHistoricalSchedule

% Parse input arguments using inputParser
p = inputParser;

% Required input validation
addRequired(p, 'historicalData', @(x) isstruct(x) && isfield(x, 'caseID'));

% Optional parameters with validation
addParameter(p, 'HistoricalSchedules', [], @(x) isempty(x) || (isa(x, 'containers.Map') && ~isempty(x)));
addParameter(p, 'ShowStats', true, @(x) islogical(x) && isscalar(x));
addParameter(p, 'SaveReport', false, @(x) islogical(x) && isscalar(x));
addParameter(p, 'ReportFile', 'historical_analysis_report.txt', @(x) ischar(x) || isstring(x));

% Parse the inputs
parse(p, historicalData, varargin{:});

% Extract parsed parameters
historicalSchedules = p.Results.HistoricalSchedules;
showStats = p.Results.ShowStats;
saveReport = p.Results.SaveReport;
reportFile = char(p.Results.ReportFile);

fprintf('=== HISTORICAL DATA ANALYSIS ===\n');

% Validate that required fields exist
requiredFields = {'caseID', 'date', 'surgeon', 'procedure'};
for i = 1:length(requiredFields)
    if ~isfield(historicalData, requiredFields{i})
        error('Missing required field in historicalData: %s', requiredFields{i});
    end
end

fprintf('Analyzing historical data structure with %d cases\n', length(historicalData.caseID));

% Initialize results structure
analysisResults = struct();

% Perform detailed statistical analysis
[analysisResults.datasetSummary, analysisResults.procedureAnalysis, ...
 analysisResults.surgeonAnalysis, analysisResults.timeAnalysis, ...
 analysisResults.roomAnalysis] = performDetailedAnalysis(historicalData, showStats);

% Perform schedule analysis if historical schedules are provided
if ~isempty(historicalSchedules)
    [analysisResults.scheduleAnalysis, analysisResults.operatorAnalysis, ...
     analysisResults.labFlipAnalysis] = performScheduleAnalysis(historicalData, historicalSchedules, showStats);
else
    analysisResults.scheduleAnalysis = [];
    analysisResults.operatorAnalysis = [];
    analysisResults.labFlipAnalysis = [];
end

% Save analysis report if requested
if saveReport
    saveAnalysisReport(historicalData, reportFile);
    fprintf('\nAnalysis report saved to %s\n', reportFile);
end

fprintf('\nHistorical data analysis complete!\n');

end

%% Detailed Analysis Function
function [datasetSummary, procedureAnalysis, surgeonAnalysis, timeAnalysis, roomAnalysis] = performDetailedAnalysis(historicalData, showStats)
    if showStats
        fprintf('\n=== DETAILED STATISTICAL ANALYSIS ===\n');
    end
    
    % Initialize output structures
    datasetSummary = struct();
    procedureAnalysis = struct();
    surgeonAnalysis = struct();
    timeAnalysis = struct();
    roomAnalysis = struct();
    
    % Basic summary statistics
    datasetSummary.totalCases = length(historicalData.caseID);
    datasetSummary.dateRange = [min(historicalData.date), max(historicalData.date)];
    datasetSummary.uniqueSurgeons = length(unique(historicalData.surgeon));
    datasetSummary.uniqueProcedures = length(unique(historicalData.procedure));
    
    if isfield(historicalData, 'room')
        datasetSummary.uniqueRooms = length(unique(historicalData.room(~ismissing(historicalData.room))));
    else
        datasetSummary.uniqueRooms = 0;
    end
    
    if showStats
        fprintf('\nDataset Summary:\n');
        fprintf('  Total cases: %d\n', datasetSummary.totalCases);
        fprintf('  Date range: %s to %s\n', string(datasetSummary.dateRange(1)), string(datasetSummary.dateRange(2)));
        fprintf('  Unique surgeons: %d\n', datasetSummary.uniqueSurgeons);
        fprintf('  Unique procedures: %d\n', datasetSummary.uniqueProcedures);
        fprintf('  Unique rooms: %d\n', datasetSummary.uniqueRooms);
    end
    
    % Date distribution analysis
    uniqueDates = unique(historicalData.date);
    uniqueDates = uniqueDates(~ismissing(uniqueDates));
    datasetSummary.uniqueDates = length(uniqueDates);
    datasetSummary.analyzedDates = uniqueDates;
    
    % Cases per day statistics
    casesPerDay = zeros(length(uniqueDates), 1);
    for i = 1:length(uniqueDates)
        casesPerDay(i) = sum(historicalData.date == uniqueDates(i));
    end
    
    datasetSummary.casesPerDay = struct();
    datasetSummary.casesPerDay.mean = mean(casesPerDay);
    datasetSummary.casesPerDay.median = median(casesPerDay);
    datasetSummary.casesPerDay.min = min(casesPerDay);
    datasetSummary.casesPerDay.max = max(casesPerDay);
    datasetSummary.casesPerDay.std = std(casesPerDay);
    
    if showStats
        fprintf('\n--- Date Distribution Analysis ---\n');
        fprintf('  Number of unique dates: %d\n', datasetSummary.uniqueDates);
        fprintf('  Cases per day - Mean: %.1f, Median: %.1f, Range: %d-%d\n', ...
            datasetSummary.casesPerDay.mean, datasetSummary.casesPerDay.median, ...
            datasetSummary.casesPerDay.min, datasetSummary.casesPerDay.max);
    end
    
    % Procedure type distribution
    [procedures, ~, idx] = unique(historicalData.procedure);
    counts = accumarray(idx, 1);
    [counts, sortIdx] = sort(counts, 'descend');
    procedures = procedures(sortIdx);
    
    procedureAnalysis.procedures = procedures;
    procedureAnalysis.counts = counts;
    procedureAnalysis.percentages = (counts / datasetSummary.totalCases) * 100;
    
    if showStats
        fprintf('\n--- Procedure Type Analysis ---\n');
        fprintf('Top 10 Procedure Types:\n');
        for i = 1:min(10, length(procedures))
            fprintf('  %s: %d cases (%.1f%%)\n', procedures{i}, counts(i), procedureAnalysis.percentages(i));
        end
    end
    
    % Surgeon analysis
    if showStats
        fprintf('\n--- Surgeon Analysis ---\n');
    end
    [surgeons, ~, idx] = unique(historicalData.surgeon);
    surgeonCounts = accumarray(idx, 1);
    [surgeonCounts, sortIdx] = sort(surgeonCounts, 'descend');
    surgeons = surgeons(sortIdx);
    
    % Store surgeon analysis results
    surgeonAnalysis.surgeons = surgeons;
    surgeonAnalysis.caseCounts = surgeonCounts;
    surgeonAnalysis.percentages = (surgeonCounts / length(historicalData.caseID)) * 100;
    
    if showStats
        fprintf('Top 5 Most Active Surgeons:\n');
        for i = 1:min(5, length(surgeons))
            fprintf('  %s: %d cases (%.1f%%)\n', surgeons{i}, surgeonCounts(i), ...
                surgeonAnalysis.percentages(i));
        end
    end
    
    % Time statistics
    if showStats
        fprintf('\n--- Time Duration Analysis ---\n');
    end
    validSetupTimes = historicalData.setupTime(~isnan(historicalData.setupTime));
    validProcTimes = historicalData.procedureTime(~isnan(historicalData.procedureTime));
    validPostTimes = historicalData.postTime(~isnan(historicalData.postTime));
    
    % Store time analysis results
    timeAnalysis.setupTime = struct('mean', mean(validSetupTimes), 'median', median(validSetupTimes), ...
        'std', std(validSetupTimes), 'min', min(validSetupTimes), 'max', max(validSetupTimes));
    timeAnalysis.procedureTime = struct('mean', mean(validProcTimes), 'median', median(validProcTimes), ...
        'std', std(validProcTimes), 'min', min(validProcTimes), 'max', max(validProcTimes));
    timeAnalysis.postTime = struct('mean', mean(validPostTimes), 'median', median(validPostTimes), ...
        'std', std(validPostTimes), 'min', min(validPostTimes), 'max', max(validPostTimes));
    
    if showStats
        fprintf('Setup Time - Mean: %.1f, Median: %.1f, Std: %.1f, Range: %.1f-%.1f minutes\n', ...
            timeAnalysis.setupTime.mean, timeAnalysis.setupTime.median, timeAnalysis.setupTime.std, ...
            timeAnalysis.setupTime.min, timeAnalysis.setupTime.max);
        fprintf('Procedure Time - Mean: %.1f, Median: %.1f, Std: %.1f, Range: %.1f-%.1f minutes\n', ...
            timeAnalysis.procedureTime.mean, timeAnalysis.procedureTime.median, timeAnalysis.procedureTime.std, ...
            timeAnalysis.procedureTime.min, timeAnalysis.procedureTime.max);
        fprintf('Post Time - Mean: %.1f, Median: %.1f, Std: %.1f, Range: %.1f-%.1f minutes\n', ...
            timeAnalysis.postTime.mean, timeAnalysis.postTime.median, timeAnalysis.postTime.std, ...
            timeAnalysis.postTime.min, timeAnalysis.postTime.max);
    end
    
    % Time of day analysis
    if showStats
        fprintf('\n--- Time of Day Analysis ---\n');
    end
    validStartTimes = historicalData.procedureStartTimeOfDay(~ismissing(historicalData.procedureStartTimeOfDay));
    validCompleteTimes = historicalData.procedureCompleteTimeOfDay(~ismissing(historicalData.procedureCompleteTimeOfDay));
    
    % Store time of day analysis results
    timeAnalysis.startTimes = struct('earliest', [], 'latest', [], 'peakHour', [], 'peakCount', []);
    timeAnalysis.completeTimes = struct('earliest', [], 'latest', []);
    
    if ~isempty(validStartTimes)
        timeAnalysis.startTimes.earliest = min(validStartTimes);
        timeAnalysis.startTimes.latest = max(validStartTimes);
        
        % Analyze peak hours
        try
            % Convert duration to datetime for hour extraction
            startTimes24h = datetime('today') + validStartTimes;
            startHours = hour(startTimes24h);
            [hourCounts, ~] = histcounts(startHours, 0:24);
            [maxCount, peakHour] = max(hourCounts);
            timeAnalysis.startTimes.peakHour = peakHour-1;
            timeAnalysis.startTimes.peakCount = maxCount;
        catch
            timeAnalysis.startTimes.peakHour = [];
            timeAnalysis.startTimes.peakCount = [];
        end
        
        if ~isempty(validCompleteTimes)
            timeAnalysis.completeTimes.earliest = min(validCompleteTimes);
            timeAnalysis.completeTimes.latest = max(validCompleteTimes);
        end
        
        if showStats
            fprintf('Procedure Start Times:\n');
            fprintf('  Earliest: %s, Latest: %s\n', string(timeAnalysis.startTimes.earliest), string(timeAnalysis.startTimes.latest));
            if ~isempty(timeAnalysis.startTimes.peakHour)
                fprintf('  Peak hours: %d:00 (%d procedures)\n', timeAnalysis.startTimes.peakHour, timeAnalysis.startTimes.peakCount);
            else
                fprintf('  Peak hours: Unable to calculate\n');
            end
            
            fprintf('Procedure Complete Times:\n');
            fprintf('  Earliest: %s, Latest: %s\n', string(timeAnalysis.completeTimes.earliest), string(timeAnalysis.completeTimes.latest));
        end
    end
    
    % Room utilization analysis
    if showStats
        fprintf('\n--- Room Utilization Analysis ---\n');
    end
    if ~all(ismissing(historicalData.room))
        validRooms = historicalData.room(~ismissing(historicalData.room));
        [rooms, ~, idx] = unique(validRooms);
        roomCounts = accumarray(idx, 1);
        [roomCounts, sortIdx] = sort(roomCounts, 'descend');
        rooms = rooms(sortIdx);
        
        % Store room analysis results
        roomAnalysis.rooms = rooms;
        roomAnalysis.caseCounts = roomCounts;
        roomAnalysis.percentages = (roomCounts / length(validRooms)) * 100;
        roomAnalysis.totalValidRooms = length(validRooms);
        
        if showStats
            fprintf('Room Usage Distribution:\n');
            for i = 1:length(rooms)
                fprintf('  %s: %d cases (%.1f%%)\n', rooms{i}, roomCounts(i), ...
                    roomAnalysis.percentages(i));
            end
        end
    else
        roomAnalysis.rooms = {};
        roomAnalysis.caseCounts = [];
        roomAnalysis.percentages = [];
        roomAnalysis.totalValidRooms = 0;
        
        if showStats
            fprintf('  No room assignment data available\n');
        end
    end
    
    % Admission status analysis
    fprintf('\n--- Admission Status Analysis ---\n');
    if ~isempty(historicalData.admissionStatus) && ~all(ismissing(historicalData.admissionStatus))
        validAdmissionStatuses = historicalData.admissionStatus(~ismissing(historicalData.admissionStatus) & ~strcmp(historicalData.admissionStatus, ''));
        if ~isempty(validAdmissionStatuses)
            [statuses, ~, idx] = unique(validAdmissionStatuses);
            counts = accumarray(idx, 1);
            [counts, sortIdx] = sort(counts, 'descend');
            statuses = statuses(sortIdx);
            
            for i = 1:length(statuses)
                fprintf('  %s: %d cases (%.1f%%)\n', statuses{i}, counts(i), ...
                    (counts(i)/length(validAdmissionStatuses))*100);
            end
        else
            fprintf('  All admission status values are empty/missing\n');
        end
    else
        fprintf('  No admission status data available\n');
    end
end

%% Schedule Analysis Function
function [scheduleAnalysis, operatorAnalysis, labFlipAnalysis] = performScheduleAnalysis(historicalData, historicalSchedules, showStats)
    % Initialize output structures
    scheduleAnalysis = struct();
    operatorAnalysis = struct();
    labFlipAnalysis = struct();
    
    if showStats
        fprintf('\n=== HISTORICAL SCHEDULE ANALYSIS ===\n');
    end
    
    % Extract all schedule data and sort chronologically
    scheduleKeys = keys(historicalSchedules);
    
    % Convert date strings to datetime objects for proper sorting
    scheduleDates = datetime(scheduleKeys, 'InputFormat', 'dd-MMM-yyyy');
    [~, sortIdx] = sort(scheduleDates);
    scheduleKeys = scheduleKeys(sortIdx);
    
    numSchedules = length(scheduleKeys);
    
    scheduleAnalysis.totalDatesWithSchedules = numSchedules;
    scheduleAnalysis.analyzedScheduleDates = scheduleKeys;
    
    if showStats
        fprintf('\nSchedule Overview:\n');
        fprintf('  Total dates with schedules: %d\n', numSchedules);
    end
    
    if numSchedules == 0
        if showStats
            fprintf('  No schedules available for analysis\n');
        end
        return;
    end
    
    % Initialize aggregation variables
    allOperatorIdleTimes = [];
    allLabUtilizations = [];
    allMakespans = [];
    allScheduleSpans = [];
    overtimeDays = 0;
    totalDailyOvertime = 0;
    
    % Initialize enhanced analysis structures
    operatorIdleStats = containers.Map();
    operatorFlipStats = containers.Map();
    operatorCaseStats = containers.Map();
    operatorWorkTimeStats = containers.Map();
    dailyLabFlips = zeros(1, numSchedules);
    
    % Get all unique operators across all schedules for consistent arrays
    allOperators = {};
    for i = 1:numSchedules
        scheduleKey = scheduleKeys{i};
        scheduleData = historicalSchedules(scheduleKey);
        if isfield(scheduleData, 'schedule') && isfield(scheduleData.schedule, 'operators')
            dayOperators = keys(scheduleData.schedule.operators);
            allOperators = union(allOperators, dayOperators);
        end
    end
    
    % Initialize arrays for all operators with NaN values
    for opIdx = 1:length(allOperators)
        opName = allOperators{opIdx};
        operatorIdleStats(opName) = NaN(1, numSchedules);
        operatorFlipStats(opName) = NaN(1, numSchedules);
        operatorCaseStats(opName) = NaN(1, numSchedules);
        operatorWorkTimeStats(opName) = NaN(1, numSchedules);
    end
    
    % Collect room performance data
    roomStats = containers.Map();
    
    fprintf('\n--- Daily Schedule Performance ---\n');
    
    for i = 1:numSchedules
        scheduleKey = scheduleKeys{i};
        scheduleData = historicalSchedules(scheduleKey);
        
        if ~isfield(scheduleData, 'results') || ~isfield(scheduleData, 'schedule')
            continue;
        end
        
        results = scheduleData.results;
        schedule = scheduleData.schedule;
        
        % Aggregate schedule metrics
        if isfield(results, 'makespan')
            allMakespans = [allMakespans, results.makespan];
        end
        if isfield(results, 'meanLabUtilization')
            allLabUtilizations = [allLabUtilizations, results.meanLabUtilization];
        end
        if isfield(results, 'scheduleEnd') && results.scheduleEnd/60 > 18
            overtimeDays = overtimeDays + 1;
            totalDailyOvertime = totalDailyOvertime + (results.scheduleEnd/60 - 18);
        end
        
        % Analyze operator performance for this day  
        if isfield(schedule, 'operators')
            
            % Calculate operator idle times and lab flips
            [dayIdleStats, dayFlipStats, dayLabFlipsCount] = analyzeOperatorIdleTimeAndFlips(schedule.operators, schedule.labs);
            
            % Store daily lab flips for this date
            dailyLabFlips(i) = dayLabFlipsCount;
            
            % Update statistics for operators active on this day
            activeOperators = keys(schedule.operators);
            for opIdx = 1:length(activeOperators)
                opName = activeOperators{opIdx};
                
                % Get current arrays for this operator
                idleArray = operatorIdleStats(opName);
                flipArray = operatorFlipStats(opName);
                caseArray = operatorCaseStats(opName);
                workTimeArray = operatorWorkTimeStats(opName);
                
                % Calculate and store case count and work time
                opSchedule = schedule.operators(opName);
                [numCases, totalWorkTime] = calculateOperatorDayStats(opSchedule);
                
                % Only set values if operator actually had cases
                if numCases > 0
                    caseArray(i) = numCases;
                    
                    % Store idle time (if operator was active)
                    if isKey(dayIdleStats, opName)
                        idleArray(i) = dayIdleStats(opName);
                    else
                        idleArray(i) = 0;  % Active but no idle time
                    end
                    
                    % Store lab flip count (set to 0 if no flips, but operator was active)
                    if isKey(dayFlipStats, opName)
                        flipArray(i) = dayFlipStats(opName);
                    else
                        flipArray(i) = 0;  % Active but no lab flips
                    end
                    
                    % Store work time if available
                    if totalWorkTime > 0
                        workTimeArray(i) = totalWorkTime;
                    else
                        workTimeArray(i) = 0;  % Active but no recorded work time
                    end
                end
                
                % Update the maps with modified arrays
                operatorIdleStats(opName) = idleArray;
                operatorFlipStats(opName) = flipArray;
                operatorCaseStats(opName) = caseArray;
                operatorWorkTimeStats(opName) = workTimeArray;
            end
        end
        
        % Analyze room utilization for this day
        if isfield(schedule, 'labs')
            analyzeRoomUtilization(schedule.labs, roomStats, scheduleKey);
        end
    end
    
    % Display aggregate schedule statistics
    if ~isempty(allMakespans)
        fprintf('Average daily makespan: %.1f hours (range: %.1f - %.1f)\n', ...
            mean(allMakespans)/60, min(allMakespans)/60, max(allMakespans)/60);
    end
    
    if ~isempty(allLabUtilizations)
        fprintf('Average lab utilization: %.1f%% (range: %.1f%% - %.1f%%)\n', ...
            mean(allLabUtilizations)*100, min(allLabUtilizations)*100, max(allLabUtilizations)*100);
    end
    
    fprintf('Overtime days: %d of %d (%.1f%%)\n', overtimeDays, numSchedules, (overtimeDays/numSchedules)*100);
    if overtimeDays > 0
        fprintf('Average daily overtime: %.1f hours\n', totalDailyOvertime/overtimeDays);
    end
    
    % Display operator performance analysis
    displayOperatorAnalysis(operatorCaseStats, operatorWorkTimeStats, scheduleKeys);
    
    % Display room utilization analysis
    displayRoomAnalysis(roomStats);
    
    % Display operator idle time and lab flip analysis
    displayOperatorIdleTimeAndFlipAnalysis(operatorIdleStats, operatorFlipStats, dailyLabFlips, showStats);
    
    % Perform procedure duration analysis by operator
    performProcedureDurationAnalysis(historicalData);
    
    % Populate structured return values
    scheduleAnalysis.avgMakespan = mean(allMakespans);
    scheduleAnalysis.makespanRange = [min(allMakespans), max(allMakespans)];
    scheduleAnalysis.avgLabUtilization = mean(allLabUtilizations);
    scheduleAnalysis.utilizationRange = [min(allLabUtilizations), max(allLabUtilizations)];
    scheduleAnalysis.overtimeDays = overtimeDays;
    scheduleAnalysis.overtimePercentage = (overtimeDays/numSchedules)*100;
    scheduleAnalysis.avgDailyOvertime = totalDailyOvertime/max(overtimeDays, 1);
    
    operatorAnalysis.idleTimeStats = operatorIdleStats;
    operatorAnalysis.caseStats = operatorCaseStats;
    operatorAnalysis.workTimeStats = operatorWorkTimeStats;
    operatorAnalysis.analyzedDates = scheduleKeys;
    
    % Calculate averages for multi-procedure days
    operatorAnalysis.multiProcedureDayAverages = calculateMultiProcedureAverages(...
        operatorCaseStats, operatorIdleStats, operatorFlipStats);
    
    labFlipAnalysis.operatorFlipStats = operatorFlipStats;
    labFlipAnalysis.dailyLabFlips = dailyLabFlips;
    labFlipAnalysis.avgDailyFlips = mean(dailyLabFlips);
    labFlipAnalysis.totalFlips = sum(dailyLabFlips);
    labFlipAnalysis.analyzedDates = scheduleKeys;
end

function averages = calculateMultiProcedureAverages(operatorCaseStats, operatorIdleStats, operatorFlipStats)
    % Calculate averages for operators on multi-procedure days only
    % A multi-procedure day is defined as a day when an operator had more than one case
    
    averages = containers.Map();
    
    if isempty(operatorCaseStats)
        return;
    end
    
    operatorNames = keys(operatorCaseStats);
    
    for i = 1:length(operatorNames)
        opName = operatorNames{i};
        
        % Get arrays for this operator
        caseArray = operatorCaseStats(opName);
        idleArray = operatorIdleStats(opName);
        flipArray = operatorFlipStats(opName);
        
        % Find days with more than one procedure (multi-procedure days)
        multiProcDayMask = caseArray > 1;
        
        % Initialize averages for this operator
        opAverages = struct();
        opAverages.avgIdleTime = NaN;
        opAverages.avgFlips = NaN;
        opAverages.multiProcedureDays = sum(multiProcDayMask);
        
        if any(multiProcDayMask)
            % Calculate averages only for multi-procedure days
            multiProcIdleTimes = idleArray(multiProcDayMask);
            multiProcFlips = flipArray(multiProcDayMask);
            
            % Only calculate averages if we have valid (non-NaN) data
            validIdleTimes = multiProcIdleTimes(~isnan(multiProcIdleTimes));
            validFlips = multiProcFlips(~isnan(multiProcFlips));
            
            if ~isempty(validIdleTimes)
                opAverages.avgIdleTime = mean(validIdleTimes);
            end
            
            if ~isempty(validFlips)
                opAverages.avgFlips = mean(validFlips);
            end
        end
        
        averages(opName) = opAverages;
    end
end

function [numCases, totalWorkTime] = calculateOperatorDayStats(opSchedule)
    % Calculate number of cases and total work time for an operator on a given day
    numCases = 0;
    totalWorkTime = 0;
    
    try
        if isstruct(opSchedule) && length(opSchedule) == 1
            % Single case struct
            numCases = 1;
            if isfield(opSchedule, 'caseInfo') && isfield(opSchedule.caseInfo, 'procTime')
                totalWorkTime = opSchedule.caseInfo.procTime;
            end
        elseif isstruct(opSchedule) && length(opSchedule) > 1
            % Array of structs
            numCases = length(opSchedule);
            for j = 1:length(opSchedule)
                if isfield(opSchedule(j), 'caseInfo') && isfield(opSchedule(j).caseInfo, 'procTime')
                    totalWorkTime = totalWorkTime + opSchedule(j).caseInfo.procTime;
                end
            end
        end
    catch
        % If there's an error parsing the schedule, default to 0
        numCases = 0;
        totalWorkTime = 0;
    end
end


function analyzeRoomUtilization(labs, roomStats, dateKey)
    for labIdx = 1:length(labs)
        if ~isempty(labs{labIdx})
            labKey = sprintf('Lab_%d', labIdx);
            
            if ~isKey(roomStats, labKey)
                roomStats(labKey) = struct('totalCases', 0, 'totalActiveTime', 0, 'days', 0, 'utilizationSum', 0);
            end
            
            stats = roomStats(labKey);
            labCases = labs{labIdx};
            
            if ~isempty(labCases)
                stats.totalCases = stats.totalCases + length(labCases);
                
                % Calculate active time for this lab on this day
                if length(labCases) > 0
                    activeTime = labCases(end).endTime - labCases(1).startTime;
                    stats.totalActiveTime = stats.totalActiveTime + activeTime;
                end
                
                stats.days = stats.days + 1;
            end
            
            roomStats(labKey) = stats;
        end
    end
end

function displayOperatorAnalysis(operatorCaseStats, operatorWorkTimeStats, analyzedDates)
    fprintf('\n--- Operator Performance Analysis ---\n');
    
    if isempty(operatorCaseStats)
        fprintf('No operator data available\n');
        return;
    end
    
    operatorNames = keys(operatorCaseStats);
    
    % Sort operators by total cases
    operatorTotalCases = zeros(length(operatorNames), 1);
    for i = 1:length(operatorNames)
        caseArray = operatorCaseStats(operatorNames{i});
        operatorTotalCases(i) = sum(caseArray);
    end
    [~, sortIdx] = sort(operatorTotalCases, 'descend');
    
    fprintf('Operator workload summary:\n');
    for i = 1:min(10, length(sortIdx))
        idx = sortIdx(i);
        opName = operatorNames{idx};
        caseArray = operatorCaseStats(opName);
        workTimeArray = operatorWorkTimeStats(opName);
        
        totalCases = sum(caseArray);
        activeDays = sum(caseArray > 0);
        avgCasesPerActiveDay = totalCases / max(activeDays, 1);
        
        validWorkTimes = workTimeArray(~isnan(workTimeArray));
        avgWorkTimePerActiveDay = mean(validWorkTimes);
        
        fprintf('  %s: %d cases over %d active days (avg %.1f cases/day, %.1f min work/day)\n', ...
            opName, totalCases, activeDays, avgCasesPerActiveDay, avgWorkTimePerActiveDay);
    end
end

function displayRoomAnalysis(roomStats)
    fprintf('\n--- Room Utilization Analysis ---\n');
    
    if isempty(roomStats)
        fprintf('No room data available\n');
        return;
    end
    
    roomNames = keys(roomStats);
    
    fprintf('Room usage summary:\n');
    for i = 1:length(roomNames)
        roomName = roomNames{i};
        stats = roomStats(roomName);
        
        if stats.days > 0
            avgCasesPerDay = stats.totalCases / stats.days;
            avgActiveTimePerDay = stats.totalActiveTime / stats.days;
            
            fprintf('  %s: %d cases over %d days (avg %.1f cases/day, %.1f hours active/day)\n', ...
                roomName, stats.totalCases, stats.days, avgCasesPerDay, avgActiveTimePerDay/60);
        end
    end
end

function performProcedureDurationAnalysis(historicalData)
    fprintf('\n--- Procedure Duration Analysis by Operator ---\n');
    
    % Get unique procedures and operators
    uniqueProcedures = unique(historicalData.procedure);
    uniqueOperators = unique(historicalData.surgeon);
    
    fprintf('\nProcedure duration statistics:\n');
    
    % Overall procedure statistics
    for i = 1:min(10, length(uniqueProcedures))
        procedure = uniqueProcedures{i};
        procedureIndices = strcmp(historicalData.procedure, procedure);
        procedureTimes = historicalData.procedureTime(procedureIndices);
        validTimes = procedureTimes(~isnan(procedureTimes) & procedureTimes > 0);
        
        if ~isempty(validTimes)
            p50 = prctile(validTimes, 50);
            p75 = prctile(validTimes, 75);
            p90 = prctile(validTimes, 90);
            
            fprintf('  %s (%d cases): P50=%.1f, P75=%.1f, P90=%.1f min\n', ...
                procedure, length(validTimes), p50, p75, p90);
        end
    end
    
    % Operator-specific procedure analysis for top operators
    fprintf('\n--- Operator-Specific Procedure Analysis ---\n');
    
    % Get top 5 operators by case count
    operatorCounts = zeros(length(uniqueOperators), 1);
    for i = 1:length(uniqueOperators)
        operatorCounts(i) = sum(strcmp(historicalData.surgeon, uniqueOperators{i}));
    end
    [~, sortIdx] = sort(operatorCounts, 'descend');
    topOperators = uniqueOperators(sortIdx(1:min(5, length(sortIdx))));
    
    for opIdx = 1:length(topOperators)
        operator = topOperators{opIdx};
        operatorIndices = strcmp(historicalData.surgeon, operator);
        
        fprintf('\n%s:\n', operator);
        
        % Get procedures for this operator
        operatorProcedures = unique(historicalData.procedure(operatorIndices));
        
        for procIdx = 1:min(5, length(operatorProcedures))
            procedure = operatorProcedures{procIdx};
            
            % Get times for this operator and procedure combination
            combinedIndices = operatorIndices & strcmp(historicalData.procedure, procedure);
            procedureTimes = historicalData.procedureTime(combinedIndices);
            validTimes = procedureTimes(~isnan(procedureTimes) & procedureTimes > 0);
            
            if length(validTimes) >= 3  % Need at least 3 cases for meaningful percentiles
                p50 = prctile(validTimes, 50);
                p75 = prctile(validTimes, 75);
                p90 = prctile(validTimes, 90);
                
                fprintf('  %s (%d cases): P50=%.1f, P75=%.1f, P90=%.1f min\n', ...
                    procedure, length(validTimes), p50, p75, p90);
            end
        end
    end
end

%% Helper Functions
function saveAnalysisReport(historicalData, reportFile)
% Save analysis report to text file
fprintf('Saving analysis report to %s...\n', reportFile);

% Redirect output to file
diary(reportFile);
diary on;

fprintf('=== HISTORICAL DATA ANALYSIS REPORT ===\n');
fprintf('Generated on: %s\n\n', datestr(now));

% Perform the same analysis as displayed
performDetailedAnalysis(historicalData);

diary off;
end

%% Display Operator Idle Time and Lab Flip Analysis
function displayOperatorIdleTimeAndFlipAnalysis(operatorIdleStats, operatorFlipStats, dailyLabFlips, showStats)
    if ~showStats
        return;
    end
    
    fprintf('\n--- Operator Idle Time and Lab Flip Analysis ---\n');
    
    % Display operator idle time statistics
    if ~isempty(operatorIdleStats)
        fprintf('\nOperator idle time statistics:\n');
        operatorNames = keys(operatorIdleStats);
        
        for i = 1:length(operatorNames)
            opName = operatorNames{i};
            idleTimes = operatorIdleStats(opName);
            
            if ~isempty(idleTimes) && any(idleTimes > 0)
                validIdleTimes = idleTimes(idleTimes > 0);
                fprintf('  %s: Avg idle time %.1f min (range: %.1f-%.1f min, %d days)\n', ...
                    opName, mean(validIdleTimes), min(validIdleTimes), max(validIdleTimes), length(validIdleTimes));
            end
        end
    end
    
    % Display lab flip statistics
    if ~isempty(operatorFlipStats)
        fprintf('\nOperator lab flip statistics:\n');
        operatorNames = keys(operatorFlipStats);
        
        for i = 1:length(operatorNames)
            opName = operatorNames{i};
            flipCounts = operatorFlipStats(opName);
            
            if ~isempty(flipCounts) && any(flipCounts > 0)
                validFlips = flipCounts(flipCounts > 0);
                fprintf('  %s: Avg %.1f lab flips/day (range: %d-%d flips, %d days with flips)\n', ...
                    opName, mean(validFlips), min(validFlips), max(validFlips), length(validFlips));
            end
        end
    end
    
    % Display daily lab flip statistics
    if ~isempty(dailyLabFlips)
        fprintf('\nDaily lab flip summary:\n');
        fprintf('  Total lab flips across all days: %d\n', sum(dailyLabFlips));
        fprintf('  Average lab flips per day: %.1f\n', mean(dailyLabFlips));
        fprintf('  Range: %d-%d flips per day\n', min(dailyLabFlips), max(dailyLabFlips));
        fprintf('  Days with lab flips: %d of %d (%.1f%%)\n', ...
            sum(dailyLabFlips > 0), length(dailyLabFlips), (sum(dailyLabFlips > 0)/length(dailyLabFlips))*100);
    end
end

%% Operator Idle Time and Lab Flip Analysis
function [idleStats, flipStats, totalLabFlips] = analyzeOperatorIdleTimeAndFlips(operators, labs)
    % Initialize outputs
    idleStats = containers.Map();
    flipStats = containers.Map();
    totalLabFlips = 0;
    
    operatorNames = keys(operators);
    
    for i = 1:length(operatorNames)
        opName = operatorNames{i};
        opSchedule = operators(opName);
        
        % Initialize operator stats
        idleStats(opName) = 0;
        flipStats(opName) = 0;
        
        % Get operator's schedule for the day
        if isstruct(opSchedule) && length(opSchedule) == 1
            % Single case - no idle time or flips
            continue;
        elseif isstruct(opSchedule) && length(opSchedule) > 1
            % Multiple cases - analyze idle time and lab flips
            totalIdleTime = 0;
            labFlipCount = 0;
            
            % Sort cases by start time
            if isfield(opSchedule(1), 'caseInfo')
                startTimes = [];
                for j = 1:length(opSchedule)
                    if isfield(opSchedule(j).caseInfo, 'startTime')
                        startTimes(j) = opSchedule(j).caseInfo.startTime;
                    else
                        startTimes(j) = 0;
                    end
                end
                [~, sortIdx] = sort(startTimes);
                sortedSchedule = opSchedule(sortIdx);
                
                % Calculate idle time between consecutive cases
                for j = 1:length(sortedSchedule)-1
                    currentCase = sortedSchedule(j);
                    nextCase = sortedSchedule(j+1);
                    
                    if isfield(currentCase.caseInfo, 'endTime') && isfield(nextCase.caseInfo, 'startTime')
                        idleTime = nextCase.caseInfo.startTime - currentCase.caseInfo.endTime;
                        if idleTime > 0
                            totalIdleTime = totalIdleTime + idleTime;
                        end
                    end
                    
                    % Check for lab flip (different labs for consecutive cases)
                    if isfield(currentCase, 'lab') && isfield(nextCase, 'lab')
                        if currentCase.lab ~= nextCase.lab
                            labFlipCount = labFlipCount + 1;
                            totalLabFlips = totalLabFlips + 1;
                        end
                    end
                end
            end
            
            idleStats(opName) = totalIdleTime;
            flipStats(opName) = labFlipCount;
        end
    end
    
    % Count total daily lab flips across all operators
    % This is already counted in the loop above via totalLabFlips
end