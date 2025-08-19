function analyzeHistoricalData(historicalData, varargin)
% Analyzes historical procedure data and schedule structures
% Focuses on statistical analysis, schedule performance, and operator insights
% Does NOT perform any schedule reconstruction or optimization
%
% Usage:
%   analyzeHistoricalData(historicalData)
%   analyzeHistoricalData(historicalData, 'HistoricalSchedules', schedules)
%   analyzeHistoricalData(historicalData, 'HistoricalSchedules', schedules, 'ShowStats', true)
%
% Inputs:
%   historicalData - Historical data structure from loadHistoricalDataFromFile
%
% Parameters:
%   HistoricalSchedules - Historical schedules structure (optional)
%   ShowStats - Whether to display detailed statistics (default: true)
%   SaveReport - Whether to save analysis report to file (default: false)
%   ReportFile - File name for analysis report (default: 'historical_analysis_report.txt')
%
% Outputs:
%   None - Function displays analysis and optionally saves report

% Validate input
if ~isstruct(historicalData)
    error('historicalData must be a structure from loadHistoricalDataFromFile');
end

% Set default parameters
historicalSchedules = [];
showStats = true;
saveReport = false;
reportFile = 'historical_analysis_report.txt';

% Parse optional parameters
i = 1;
while i <= length(varargin)
    if ischar(varargin{i}) || isstring(varargin{i})
        switch lower(char(varargin{i}))
            case 'historicalschedules'
                historicalSchedules = varargin{i+1};
                i = i + 2;
            case 'showstats'
                showStats = varargin{i+1};
                i = i + 2;
            case 'savereport'
                saveReport = varargin{i+1};
                i = i + 2;
            case 'reportfile'
                reportFile = char(varargin{i+1});
                i = i + 2;
            otherwise
                error('Unknown parameter: %s', char(varargin{i}));
        end
    else
        i = i + 1;
    end
end

fprintf('=== HISTORICAL DATA ANALYSIS ===\n');

% Validate that required fields exist
requiredFields = {'caseID', 'date', 'surgeon', 'procedure'};
for i = 1:length(requiredFields)
    if ~isfield(historicalData, requiredFields{i})
        error('Missing required field in historicalData: %s', requiredFields{i});
    end
end

fprintf('Analyzing historical data structure with %d cases\n', length(historicalData.caseID));

% Perform detailed statistical analysis
if showStats
    performDetailedAnalysis(historicalData);
    
    % Perform schedule analysis if historical schedules are provided
    if ~isempty(historicalSchedules)
        performScheduleAnalysis(historicalData, historicalSchedules);
    end
end

% Save analysis report if requested
if saveReport
    saveAnalysisReport(historicalData, reportFile);
    fprintf('\nAnalysis report saved to %s\n', reportFile);
end

fprintf('\nHistorical data analysis complete!\n');

end

%% Detailed Analysis Function
function performDetailedAnalysis(historicalData)
    fprintf('\n=== DETAILED STATISTICAL ANALYSIS ===\n');
    
    % Basic summary statistics
    fprintf('\nDataset Summary:\n');
    fprintf('  Total cases: %d\n', length(historicalData.caseID));
    fprintf('  Date range: %s to %s\n', string(min(historicalData.date)), string(max(historicalData.date)));
    fprintf('  Unique surgeons: %d\n', length(unique(historicalData.surgeon)));
    fprintf('  Unique procedures: %d\n', length(unique(historicalData.procedure)));
    fprintf('  Unique rooms: %d\n', length(unique(historicalData.room(~ismissing(historicalData.room)))));
    
    % Date distribution analysis
    fprintf('\n--- Date Distribution Analysis ---\n');
    uniqueDates = unique(historicalData.date);
    uniqueDates = uniqueDates(~ismissing(uniqueDates));
    fprintf('  Number of unique dates: %d\n', length(uniqueDates));
    
    % Cases per day statistics
    casesPerDay = zeros(length(uniqueDates), 1);
    for i = 1:length(uniqueDates)
        casesPerDay(i) = sum(historicalData.date == uniqueDates(i));
    end
    
    fprintf('  Cases per day - Mean: %.1f, Median: %.1f, Range: %d-%d\n', ...
        mean(casesPerDay), median(casesPerDay), min(casesPerDay), max(casesPerDay));
    
    % Show procedure type distribution
    fprintf('\n--- Procedure Type Analysis ---\n');
    [procedures, ~, idx] = unique(historicalData.procedure);
    counts = accumarray(idx, 1);
    [counts, sortIdx] = sort(counts, 'descend');
    procedures = procedures(sortIdx);
    
    fprintf('Top 10 Procedure Types:\n');
    for i = 1:min(10, length(procedures))
        fprintf('  %s: %d cases (%.1f%%)\n', procedures{i}, counts(i), ...
            (counts(i)/length(historicalData.caseID))*100);
    end
    
    % Surgeon analysis
    fprintf('\n--- Surgeon Analysis ---\n');
    [surgeons, ~, idx] = unique(historicalData.surgeon);
    surgeonCounts = accumarray(idx, 1);
    [surgeonCounts, sortIdx] = sort(surgeonCounts, 'descend');
    surgeons = surgeons(sortIdx);
    
    fprintf('Top 5 Most Active Surgeons:\n');
    for i = 1:min(5, length(surgeons))
        fprintf('  %s: %d cases (%.1f%%)\n', surgeons{i}, surgeonCounts(i), ...
            (surgeonCounts(i)/length(historicalData.caseID))*100);
    end
    
    % Time statistics
    fprintf('\n--- Time Duration Analysis ---\n');
    validSetupTimes = historicalData.setupTime(~isnan(historicalData.setupTime));
    validProcTimes = historicalData.procedureTime(~isnan(historicalData.procedureTime));
    validPostTimes = historicalData.postTime(~isnan(historicalData.postTime));
    
    fprintf('Setup Time - Mean: %.1f, Median: %.1f, Std: %.1f, Range: %.1f-%.1f minutes\n', ...
        mean(validSetupTimes), median(validSetupTimes), std(validSetupTimes), ...
        min(validSetupTimes), max(validSetupTimes));
    fprintf('Procedure Time - Mean: %.1f, Median: %.1f, Std: %.1f, Range: %.1f-%.1f minutes\n', ...
        mean(validProcTimes), median(validProcTimes), std(validProcTimes), ...
        min(validProcTimes), max(validProcTimes));
    fprintf('Post Time - Mean: %.1f, Median: %.1f, Std: %.1f, Range: %.1f-%.1f minutes\n', ...
        mean(validPostTimes), median(validPostTimes), std(validPostTimes), ...
        min(validPostTimes), max(validPostTimes));
    
    % Time of day analysis
    fprintf('\n--- Time of Day Analysis ---\n');
    validStartTimes = historicalData.procedureStartTimeOfDay(~ismissing(historicalData.procedureStartTimeOfDay));
    validCompleteTimes = historicalData.procedureCompleteTimeOfDay(~ismissing(historicalData.procedureCompleteTimeOfDay));
    
    if ~isempty(validStartTimes)
        fprintf('Procedure Start Times:\n');
        fprintf('  Earliest: %s, Latest: %s\n', string(min(validStartTimes)), string(max(validStartTimes)));
        fprintf('  Peak hours: ');
        
        % Analyze peak hours
        try
            % Convert duration to datetime for hour extraction
            startTimes24h = datetime('today') + validStartTimes;
            startHours = hour(startTimes24h);
            [hourCounts, ~] = histcounts(startHours, 0:24);
            [maxCount, peakHour] = max(hourCounts);
            fprintf('%d:00 (%d procedures)\n', peakHour-1, maxCount);
        catch
            fprintf('Unable to calculate peak hours\n');
        end
        
        fprintf('Procedure Complete Times:\n');
        fprintf('  Earliest: %s, Latest: %s\n', string(min(validCompleteTimes)), string(max(validCompleteTimes)));
    end
    
    % Room utilization analysis
    fprintf('\n--- Room Utilization Analysis ---\n');
    if ~all(ismissing(historicalData.room))
        validRooms = historicalData.room(~ismissing(historicalData.room));
        [rooms, ~, idx] = unique(validRooms);
        roomCounts = accumarray(idx, 1);
        [roomCounts, sortIdx] = sort(roomCounts, 'descend');
        rooms = rooms(sortIdx);
        
        fprintf('Room Usage Distribution:\n');
        for i = 1:length(rooms)
            fprintf('  %s: %d cases (%.1f%%)\n', rooms{i}, roomCounts(i), ...
                (roomCounts(i)/length(validRooms))*100);
        end
    else
        fprintf('  No room assignment data available\n');
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
function performScheduleAnalysis(historicalData, historicalSchedules)
    fprintf('\n=== HISTORICAL SCHEDULE ANALYSIS ===\n');
    
    % Extract all schedule data
    scheduleKeys = keys(historicalSchedules);
    numSchedules = length(scheduleKeys);
    
    fprintf('\nSchedule Overview:\n');
    fprintf('  Total dates with schedules: %d\n', numSchedules);
    
    if numSchedules == 0
        fprintf('  No schedules available for analysis\n');
        return;
    end
    
    % Initialize aggregation variables
    allOperatorIdleTimes = [];
    allLabUtilizations = [];
    allMakespans = [];
    allScheduleSpans = [];
    overtimeDays = 0;
    totalDailyOvertime = 0;
    
    % Collect operator and room performance data
    operatorStats = containers.Map();
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
            analyzeOperatorPerformance(schedule.operators, operatorStats);
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
    displayOperatorAnalysis(operatorStats);
    
    % Display room utilization analysis
    displayRoomAnalysis(roomStats);
    
    % Perform procedure duration analysis by operator
    performProcedureDurationAnalysis(historicalData);
end

function analyzeOperatorPerformance(operators, operatorStats)
    operatorNames = keys(operators);
    
    for i = 1:length(operatorNames)
        opName = operatorNames{i};
        opSchedule = operators(opName);
        
        if ~isKey(operatorStats, opName)
            operatorStats(opName) = struct('totalCases', 0, 'totalIdleTime', 0, 'totalWorkTime', 0, 'days', 0);
        end
        
        stats = operatorStats(opName);
        
        % Count cases for this operator on this day
        try
            if isstruct(opSchedule) && length(opSchedule) == 1
                % Single case struct
                if isfield(opSchedule, 'caseInfo')
                    numCases = 1;
                    if isfield(opSchedule.caseInfo, 'procTime')
                        totalProcTime = opSchedule.caseInfo.procTime;
                    else
                        totalProcTime = 0;
                    end
                else
                    numCases = 1;
                    totalProcTime = 0;
                end
            elseif isstruct(opSchedule) && length(opSchedule) > 1
                % Array of structs
                numCases = length(opSchedule);
                totalProcTime = 0;
                for j = 1:length(opSchedule)
                    if isfield(opSchedule(j), 'caseInfo') && isfield(opSchedule(j).caseInfo, 'procTime')
                        totalProcTime = totalProcTime + opSchedule(j).caseInfo.procTime;
                    end
                end
            else
                numCases = 0;
                totalProcTime = 0;
            end
        catch
            numCases = 0;
            totalProcTime = 0;
        end
        
        stats.totalCases = stats.totalCases + numCases;
        stats.totalWorkTime = stats.totalWorkTime + totalProcTime;
        stats.days = stats.days + 1;
        
        operatorStats(opName) = stats;
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

function displayOperatorAnalysis(operatorStats)
    fprintf('\n--- Operator Performance Analysis ---\n');
    
    if isempty(operatorStats)
        fprintf('No operator data available\n');
        return;
    end
    
    operatorNames = keys(operatorStats);
    
    % Sort operators by total cases
    operatorCases = zeros(length(operatorNames), 1);
    for i = 1:length(operatorNames)
        stats = operatorStats(operatorNames{i});
        operatorCases(i) = stats.totalCases;
    end
    [~, sortIdx] = sort(operatorCases, 'descend');
    
    fprintf('Operator workload summary:\n');
    for i = 1:min(10, length(sortIdx))
        idx = sortIdx(i);
        opName = operatorNames{idx};
        stats = operatorStats(opName);
        
        avgCasesPerDay = stats.totalCases / stats.days;
        avgWorkTimePerDay = stats.totalWorkTime / stats.days;
        
        fprintf('  %s: %d cases over %d days (avg %.1f cases/day, %.1f min work/day)\n', ...
            opName, stats.totalCases, stats.days, avgCasesPerDay, avgWorkTimePerDay);
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