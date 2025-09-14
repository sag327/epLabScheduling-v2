function analysisResults = analyzeHistoricalData(historicalData, varargin)
% Analyzes historical procedure data and schedule structures
% Provides comprehensive statistical analysis, schedule performance metrics, 
% and operator insights for EP lab operations
% Version: 2.1.0
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
%     .datasetSummary         - Basic dataset statistics
%     .procedureAnalysis      - Procedure type and duration statistics
%     .surgeonAnalysis        - Surgeon workload and performance metrics
%     .timeAnalysis           - Time duration and scheduling patterns
%     .roomAnalysis           - Room utilization statistics
%     .operatorMetrics        - Comprehensive operator-level metrics (setup, procedure, post times)
%     .operatorPlottingData   - Arrays organized by operator for easy plotting and visualization
%     .procedureTimeAnalysis  - Global procedure time statistics (mean, median, P25, P75, P90)
%     .procedureTimeByOperator - Procedure time statistics broken down by operator
%     .procedurePlottingData  - Arrays organized by procedure for easy plotting (global & by operator)
%     .scheduleAnalysis       - Schedule performance metrics (if schedules provided)
%     .operatorAnalysis       - Operator workload and idle time (if schedules provided)
%     .labFlipAnalysis        - Lab switching and flip statistics (if schedules provided)
%       - scheduleAnalysis.dailyEfficiency:
%           .byDate(date) with department-wide daily metrics across all labs/operators:
%               overallDeptTotalOperatorIdleTimeDaily, overallDeptMedianOperatorIdleTimeDaily,
%               overallDeptTotalTurnoversDaily, overallDeptIdleToTurnoverRatioDaily, 
%               overallDeptTotalLabFlipsDaily, overallDeptFlipToTurnoverRatioDaily, 
%               overallDeptMakespanDaily, overallDeptTotalRoomBusyTimeDaily (setup+proc+post),
%               overallDeptAvgConcurrentLabsDaily, overallDeptNumLabsActiveDaily,
%               overallDeptOperatorsWithOutpatientDaily
%           .summary with means/stds and correlations:
%               mean/std of idleToTurnover, flipToTurnover, avgConcurrentLabs; and
%               corrIdle_vs_FlipTurnover, corrIdle_vs_AvgConcurrentLabs (pearson/spearman)
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

% Perform comprehensive operator metrics analysis
operatorMetrics = performOperatorMetricsAnalysis(historicalData, showStats);

% Store operator metrics in analysis results
analysisResults.operatorMetrics = operatorMetrics;

% Create plotting-ready data structure for easy visualization
analysisResults.operatorPlottingData = createOperatorPlottingData(operatorMetrics);

% Perform comprehensive procedure-specific analysis
[procedureAnalysisGlobal, procedureAnalysisByOperator] = performProcedureTimeAnalysis(historicalData, showStats);

% Store procedure analysis results
analysisResults.procedureTimeAnalysis = procedureAnalysisGlobal;
analysisResults.procedureTimeByOperator = procedureAnalysisByOperator;

% Create procedure plotting data for easy visualization
analysisResults.procedurePlottingData = createProcedurePlottingData(procedureAnalysisGlobal, procedureAnalysisByOperator);

% Perform schedule analysis if historical schedules are provided
if ~isempty(historicalSchedules)
    [analysisResults.scheduleAnalysis, analysisResults.operatorAnalysis, ...
     analysisResults.labFlipAnalysis] = performScheduleAnalysis(historicalData, historicalSchedules, showStats);
else
    analysisResults.scheduleAnalysis = [];
    analysisResults.operatorAnalysis = [];
    analysisResults.labFlipAnalysis = [];
end

% Create comprehensive operator metrics for statistical analysis
if showStats
    fprintf('\n=== CREATING COMPREHENSIVE OPERATOR METRICS ===\n');
end
analysisResults.comprehensiveOperatorMetrics = createComprehensiveOperatorMetrics(historicalData, analysisResults.operatorAnalysis, showStats);

% Calculate operator efficiency summary using comprehensive metrics
analysisResults.scheduleAnalysis.operatorEfficiencySummary = calculateOperatorEfficiencySummary([], [], [], analysisResults.comprehensiveOperatorMetrics);

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
    procedureAnalysis.countsStd = std(counts);
    procedureAnalysis.percentagesStd = std(procedureAnalysis.percentages);
    
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
    surgeonAnalysis.caseCountsStd = std(surgeonCounts);
    surgeonAnalysis.percentagesStd = std(surgeonAnalysis.percentages);
    
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
        roomAnalysis.caseCountsStd = std(roomCounts);
        roomAnalysis.percentagesStd = std(roomAnalysis.percentages);
        
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
        roomAnalysis.caseCountsStd = NaN;
        roomAnalysis.percentagesStd = NaN;
        
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
    
    % Department-wide daily efficiency collectors
    dailyEfficiencyMap = containers.Map();
    dailyIdleToTurnoverList = NaN(1, numSchedules);
    dailyFlipToTurnoverList = NaN(1, numSchedules);
    dailyAvgConcurrentLabsList = NaN(1, numSchedules);
    
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

            % --- Department-wide daily efficiency metrics (overallDept, per-day) ---
            % Sum operator idle minutes across operators
            totalOperatorIdle = 0;
            try
                idleVals = values(dayIdleStats);
                if ~isempty(idleVals)
                    totalOperatorIdle = sum(cell2mat(idleVals));
                end
            catch
                totalOperatorIdle = 0;
            end

            % Compute turnovers, room busy time (setup+proc+post), active labs, and fallback makespan bounds
            totalTurnovers = 0;
            totalRoomBusyTime = 0;
            numLabsActive = 0;
            earliestStart = inf;
            latestEnd = -inf;
            if isfield(schedule, 'labs') && ~isempty(schedule.labs)
                for labIdx = 1:length(schedule.labs)
                    labCases = schedule.labs{labIdx};
                    if ~isempty(labCases)
                        numLabsActive = numLabsActive + 1;
                        totalTurnovers = totalTurnovers + max(length(labCases) - 1, 0);
                        for c = 1:length(labCases)
                            if isfield(labCases(c), 'startTime') && isfield(labCases(c), 'endTime')
                                totalRoomBusyTime = totalRoomBusyTime + max(labCases(c).endTime - labCases(c).startTime, 0);
                                earliestStart = min(earliestStart, labCases(c).startTime);
                                latestEnd = max(latestEnd, labCases(c).endTime);
                            end
                        end
                    end
                end
            end

            % Prefer recorded makespan; fallback to computed span if needed
            makespanDay = NaN;
            if isfield(results, 'makespan') && ~isempty(results.makespan)
                makespanDay = results.makespan;
            elseif isfinite(earliestStart) && isfinite(latestEnd) && latestEnd > earliestStart
                makespanDay = latestEnd - earliestStart;
            end

            % Ratios (NaN when turnovers = 0)
            if totalTurnovers > 0
                idleToTurnover = totalOperatorIdle / totalTurnovers;
                flipToTurnover = dayLabFlipsCount / totalTurnovers;
            else
                idleToTurnover = NaN;
                flipToTurnover = NaN;
            end

            % Avg concurrent labs includes setup+proc+post
            if ~isnan(makespanDay) && makespanDay > 0
                avgConcurrentLabs = totalRoomBusyTime / makespanDay;
            else
                avgConcurrentLabs = NaN;
            end

            % Calculate median of individual operator idle times
            medianOperatorIdle = NaN;
            try
                idleVals = values(dayIdleStats);
                if ~isempty(idleVals)
                    idleArray = cell2mat(idleVals);
                    if ~isempty(idleArray)
                        medianOperatorIdle = median(idleArray);
                    end
                end
            catch
                medianOperatorIdle = NaN;
            end

            % Persist daily overall department metrics
            dayEff = struct();
            dayEff.overallDeptTotalOperatorIdleTimeDaily = totalOperatorIdle;
            dayEff.overallDeptMedianOperatorIdleTimeDaily = medianOperatorIdle;
            dayEff.overallDeptTotalTurnoversDaily = totalTurnovers;
            dayEff.overallDeptIdleToTurnoverRatioDaily = idleToTurnover;
            dayEff.overallDeptTotalLabFlipsDaily = dayLabFlipsCount;
            dayEff.overallDeptFlipToTurnoverRatioDaily = flipToTurnover;
            dayEff.overallDeptMakespanDaily = makespanDay;
            dayEff.overallDeptTotalRoomBusyTimeDaily = totalRoomBusyTime;
            dayEff.overallDeptAvgConcurrentLabsDaily = avgConcurrentLabs;
            dayEff.overallDeptNumLabsActiveDaily = numLabsActive;
            
            % Calculate number of operators with outpatient procedures this day
            operatorsWithOutpatient = 0;
            if isfield(schedule, 'operators')
                activeOperators = keys(schedule.operators);
                for opIdx = 1:length(activeOperators)
                    opName = activeOperators{opIdx};
                    opSchedule = schedule.operators(opName);
                    
                    % Check if operator has any outpatient procedures
                    hasOutpatient = false;
                    if isstruct(opSchedule) && length(opSchedule) > 0
                        for caseIdx = 1:length(opSchedule)
                            if isfield(opSchedule(caseIdx), 'caseInfo') && isfield(opSchedule(caseIdx).caseInfo, 'admissionStatus')
                                admissionStatus = string(opSchedule(caseIdx).caseInfo.admissionStatus);
                                if contains(admissionStatus, 'Outpatient', 'IgnoreCase', true)
                                    hasOutpatient = true;
                                    break;
                                end
                            end
                        end
                    end
                    
                    if hasOutpatient
                        operatorsWithOutpatient = operatorsWithOutpatient + 1;
                    end
                end
            end
            dayEff.overallDeptOperatorsWithOutpatientDaily = operatorsWithOutpatient;
            
            % Calculate effective outpatient operators
            % Sum outpatient procedure durations by operator, normalize to 8-hour equivalent
            effectiveOutpatientOperators = 0;
            if isfield(schedule, 'operators')
                activeOperators = keys(schedule.operators);
                for opIdx = 1:length(activeOperators)
                    opName = activeOperators{opIdx};
                    opSchedule = schedule.operators(opName);
                    
                    % Convert to array if it's a single struct
                    if ~isfield(opSchedule, 'lab') && length(opSchedule) == 1 && isstruct(opSchedule)
                        opSchedule = [opSchedule];
                    end
                    
                    totalOutpatientProcTime = 0;
                    
                    % Sum procedure time for outpatient cases only
                    for caseIdx = 1:length(opSchedule)
                        if isfield(opSchedule(caseIdx), 'caseInfo')
                            caseInfo = opSchedule(caseIdx).caseInfo;
                        else
                            caseInfo = opSchedule(caseIdx);
                        end
                        
                        % Check if this is an outpatient case
                        isOutpatient = false;
                        if isfield(caseInfo, 'admissionStatus')
                            admissionStatus = caseInfo.admissionStatus;
                            if contains(lower(admissionStatus), {'outpatient', 'amb proc', 'ambulatory'})
                                isOutpatient = true;
                            end
                        end
                        
                        if isOutpatient && isfield(caseInfo, 'procTime')
                            totalOutpatientProcTime = totalOutpatientProcTime + caseInfo.procTime;
                        end
                    end
                    
                    % Convert to 8-hour equivalent (normalize by 480 minutes = 8 hours)
                    if totalOutpatientProcTime > 0
                        operatorEquivalent = totalOutpatientProcTime / (8 * 60); % 8 hours = 480 minutes
                        effectiveOutpatientOperators = effectiveOutpatientOperators + operatorEquivalent;
                    end
                end
            end
            dayEff.overallDeptEffectiveOutpatientOperatorsDaily = effectiveOutpatientOperators;
            
            % Calculate flip potential: active labs minus effective outpatient operators
            flipPotential = numLabsActive - effectiveOutpatientOperators;
            dayEff.overallDeptFlipPotentialDaily = flipPotential;
            
            dailyEfficiencyMap(scheduleKey) = dayEff;

            % Collect for summary/correlation
            dailyIdleToTurnoverList(i) = idleToTurnover;
            dailyFlipToTurnoverList(i) = flipToTurnover;
            dailyAvgConcurrentLabsList(i) = avgConcurrentLabs;
            
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
                    
                    % Store idle time (only if operator had multiple cases, since single-case days can't have idle time)
                    if isKey(dayIdleStats, opName)
                        idleArray(i) = dayIdleStats(opName);
                    else
                        % Operator not in dayIdleStats means they had single case this day - leave as NaN
                        % idleArray(i) remains NaN (from initialization)
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
        fprintf('Average daily makespan: %.1f±%.1f hours (range: %.1f - %.1f)\n', ...
            mean(allMakespans)/60, std(allMakespans)/60, min(allMakespans)/60, max(allMakespans)/60);
    end
    
    if ~isempty(allLabUtilizations)
        fprintf('Average lab utilization: %.1f±%.1f%% (range: %.1f%% - %.1f%%)\n', ...
            mean(allLabUtilizations)*100, std(allLabUtilizations)*100, min(allLabUtilizations)*100, max(allLabUtilizations)*100);
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
    
    
    % Populate structured return values
    scheduleAnalysis.avgMakespan = mean(allMakespans);
    scheduleAnalysis.makespanStd = std(allMakespans);
    scheduleAnalysis.makespanRange = [min(allMakespans), max(allMakespans)];
    scheduleAnalysis.avgLabUtilization = mean(allLabUtilizations);
    scheduleAnalysis.labUtilizationStd = std(allLabUtilizations);
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
    
    % Note: Operator efficiency summary will be calculated after comprehensive metrics are created
    
    % Calculate lab efficiency summary statistics
    scheduleAnalysis.labEfficiencySummary = calculateLabEfficiencySummary(allLabUtilizations, allMakespans, scheduleKeys, historicalSchedules);

    % Department-wide daily efficiency summary and attachment
    dailySummary = struct();
    dailySummary.nDays = numSchedules;
    validIdle = isfinite(dailyIdleToTurnoverList);
    validFlip = isfinite(dailyFlipToTurnoverList);
    validConc = isfinite(dailyAvgConcurrentLabsList);
    dailySummary.nDaysWithTurnovers = sum(validIdle);

    if any(validIdle)
        v = dailyIdleToTurnoverList(validIdle);
        dailySummary.meanIdleToTurnover = mean(v);
        dailySummary.stdIdleToTurnover = std(v);
    else
        dailySummary.meanIdleToTurnover = NaN;
        dailySummary.stdIdleToTurnover = NaN;
    end
    if any(validFlip)
        v = dailyFlipToTurnoverList(validFlip);
        dailySummary.meanFlipToTurnover = mean(v);
        dailySummary.stdFlipToTurnover = std(v);
    else
        dailySummary.meanFlipToTurnover = NaN;
        dailySummary.stdFlipToTurnover = NaN;
    end
    if any(validConc)
        v = dailyAvgConcurrentLabsList(validConc);
        dailySummary.meanAvgConcurrentLabs = mean(v);
        dailySummary.stdAvgConcurrentLabs = std(v);
    else
        dailySummary.meanAvgConcurrentLabs = NaN;
        dailySummary.stdAvgConcurrentLabs = NaN;
    end

    % Correlations
    mask1 = isfinite(dailyIdleToTurnoverList) & isfinite(dailyFlipToTurnoverList);
    if sum(mask1) >= 2
        x = dailyIdleToTurnoverList(mask1)'; y = dailyFlipToTurnoverList(mask1)';
        [rP, pP] = corr(x, y, 'Type', 'Pearson');
        [rS, pS] = corr(x, y, 'Type', 'Spearman');
        dailySummary.corrIdle_vs_FlipTurnover = struct('pearson_r', rP, 'pearson_p', pP, 'spearman_r', rS, 'spearman_p', pS);
    else
        dailySummary.corrIdle_vs_FlipTurnover = struct('pearson_r', NaN, 'pearson_p', NaN, 'spearman_r', NaN, 'spearman_p', NaN);
    end
    mask2 = isfinite(dailyIdleToTurnoverList) & isfinite(dailyAvgConcurrentLabsList);
    if sum(mask2) >= 2
        x = dailyIdleToTurnoverList(mask2)'; y = dailyAvgConcurrentLabsList(mask2)';
        [rP, pP] = corr(x, y, 'Type', 'Pearson');
        [rS, pS] = corr(x, y, 'Type', 'Spearman');
        dailySummary.corrIdle_vs_AvgConcurrentLabs = struct('pearson_r', rP, 'pearson_p', pP, 'spearman_r', rS, 'spearman_p', pS);
    else
        dailySummary.corrIdle_vs_AvgConcurrentLabs = struct('pearson_r', NaN, 'pearson_p', NaN, 'spearman_r', NaN, 'spearman_p', NaN);
    end

    scheduleAnalysis.dailyEfficiency = struct();
    scheduleAnalysis.dailyEfficiency.byDate = dailyEfficiencyMap;
    scheduleAnalysis.dailyEfficiency.summary = dailySummary;

    if showStats
        fprintf('\n--- Daily Department Efficiency Summary ---\n');
        fprintf('  Days analyzed: %d (with turnovers: %d)\n', dailySummary.nDays, dailySummary.nDaysWithTurnovers);
        fprintf('  Idle/Turnover (min/turnover): mean %.2f, std %.2f\n', dailySummary.meanIdleToTurnover, dailySummary.stdIdleToTurnover);
        fprintf('  Flip/Turnover: mean %.2f, std %.2f\n', dailySummary.meanFlipToTurnover, dailySummary.stdFlipToTurnover);
        fprintf('  Avg concurrent labs (setup+proc+post): mean %.2f, std %.2f\n', dailySummary.meanAvgConcurrentLabs, dailySummary.stdAvgConcurrentLabs);
        ci = dailySummary.corrIdle_vs_FlipTurnover;
        fprintf('  Corr Idle vs Flip/Turnover: Pearson r=%.3f (p=%.3f), Spearman r=%.3f (p=%.3f)\n', ci.pearson_r, ci.pearson_p, ci.spearman_r, ci.spearman_p);
        cj = dailySummary.corrIdle_vs_AvgConcurrentLabs;
        fprintf('  Corr Idle vs Avg Concurrent Labs: Pearson r=%.3f (p=%.3f), Spearman r=%.3f (p=%.3f)\n', cj.pearson_r, cj.pearson_p, cj.spearman_r, cj.spearman_p);
    end
    
    labFlipAnalysis.operatorFlipStats = operatorFlipStats;
    labFlipAnalysis.dailyLabFlips = dailyLabFlips;
    labFlipAnalysis.avgDailyFlips = mean(dailyLabFlips);
    labFlipAnalysis.dailyFlipsStd = std(dailyLabFlips);
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
        opAverages.medianIdleTime = NaN;
        opAverages.avgFlips = NaN;
        opAverages.avgCasesPerMultiProcDay = NaN;
        opAverages.flipToTurnoverRatio = NaN;
        opAverages.multiProcedureDays = sum(multiProcDayMask);
        
        if any(multiProcDayMask)
            % Calculate averages only for multi-procedure days
            multiProcIdleTimes = idleArray(multiProcDayMask);
            multiProcFlips = flipArray(multiProcDayMask);
            multiProcCases = caseArray(multiProcDayMask);
            
            % Only calculate averages if we have valid (non-NaN) data
            validIdleTimes = multiProcIdleTimes(~isnan(multiProcIdleTimes));
            validFlips = multiProcFlips(~isnan(multiProcFlips));
            validCases = multiProcCases(~isnan(multiProcCases));
            
            if ~isempty(validIdleTimes)
                opAverages.avgIdleTime = mean(validIdleTimes);
                opAverages.medianIdleTime = median(validIdleTimes);
            end
            
            if ~isempty(validFlips)
                opAverages.avgFlips = mean(validFlips);
            else
                % If no valid flips but we have multi-procedure days, set avgFlips to 0
                opAverages.avgFlips = 0;
            end
            
            if ~isempty(validCases)
                opAverages.avgCasesPerMultiProcDay = mean(validCases);
                
                % Calculate flip to turnover ratio using Method 1: mean of daily ratios
                if ~isempty(validFlips) && ~isempty(validCases) && length(validFlips) == length(validCases)
                    % Calculate daily flip-to-turnover ratios
                    dailyRatios = [];
                    for j = 1:length(validCases)
                        turnovers = validCases(j) - 1;
                        if turnovers > 0
                            dailyRatios(end+1) = validFlips(j) / turnovers;
                        end
                    end
                    
                    if ~isempty(dailyRatios)
                        opAverages.flipToTurnoverRatio = mean(dailyRatios);
                    else
                        opAverages.flipToTurnoverRatio = 0;
                    end
                else
                    % If no valid flips or cases mismatch, ratio is 0
                    opAverages.flipToTurnoverRatio = 0;
                end
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
        operatorTotalCases(i) = sum(caseArray, 'omitnan');
    end
    [~, sortIdx] = sort(operatorTotalCases, 'descend');
    
    fprintf('Operator workload summary:\n');
    for i = 1:length(sortIdx)
        idx = sortIdx(i);
        opName = operatorNames{idx};
        caseArray = operatorCaseStats(opName);
        workTimeArray = operatorWorkTimeStats(opName);
        
        totalCases = sum(caseArray, 'omitnan');
        activeDays = sum(caseArray > 0);
        avgCasesPerActiveDay = totalCases / max(activeDays, 1);
        stdCasesPerActiveDay = std(caseArray(caseArray > 0));
        medianCasesPerActiveDay = median(caseArray(caseArray > 0));
        
        validWorkTimes = workTimeArray(~isnan(workTimeArray));
        avgWorkTimePerActiveDay = mean(validWorkTimes);
        stdWorkTimePerActiveDay = std(validWorkTimes);
        medianWorkTimePerActiveDay = median(validWorkTimes);
        
        fprintf('  %s: %d cases over %d active days (avg %.1f±%.1f, median %.1f cases/day; avg %.1f±%.1f, median %.1f min work/day)\n', ...
            opName, totalCases, activeDays, avgCasesPerActiveDay, stdCasesPerActiveDay, medianCasesPerActiveDay, ...
            avgWorkTimePerActiveDay, stdWorkTimePerActiveDay, medianWorkTimePerActiveDay);
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

function operatorMetrics = performOperatorMetricsAnalysis(historicalData, showStats)
    if showStats
        fprintf('\n=== COMPREHENSIVE OPERATOR METRICS ANALYSIS ===\n');
    end
    
    % Get unique operators
    uniqueOperators = unique(historicalData.surgeon);
    uniqueOperators = uniqueOperators(~ismissing(uniqueOperators) & ~strcmp(uniqueOperators, ''));
    
    % Initialize operator metrics structure
    operatorMetrics = struct();
    
    for opIdx = 1:length(uniqueOperators)
        operator = uniqueOperators{opIdx};
        operatorIndices = strcmp(historicalData.surgeon, operator);
        
        % Initialize metrics for this operator
        opMetrics = struct();
        opMetrics.operatorName = operator;
        opMetrics.totalCases = sum(operatorIndices);
        
        % Extract all time metrics for this operator
        opSetupTimes = historicalData.setupTime(operatorIndices);
        opProcTimes = historicalData.procedureTime(operatorIndices);
        opPostTimes = historicalData.postTime(operatorIndices);
        
        % Remove invalid/missing values
        validSetup = opSetupTimes(~isnan(opSetupTimes) & opSetupTimes > 0);
        validProc = opProcTimes(~isnan(opProcTimes) & opProcTimes > 0);
        validPost = opPostTimes(~isnan(opPostTimes) & opPostTimes > 0);
        
        % Setup time metrics
        if ~isempty(validSetup)
            opMetrics.setupTime = struct(...
                'mean', mean(validSetup), ...
                'median', median(validSetup), ...
                'std', std(validSetup), ...
                'min', min(validSetup), ...
                'max', max(validSetup), ...
                'p25', prctile(validSetup, 25), ...
                'p75', prctile(validSetup, 75), ...
                'p90', prctile(validSetup, 90), ...
                'validCount', length(validSetup), ...
                'allValues', validSetup);
        else
            opMetrics.setupTime = struct('validCount', 0, 'allValues', []);
        end
        
        % Procedure time metrics
        if ~isempty(validProc)
            opMetrics.procedureTime = struct(...
                'mean', mean(validProc), ...
                'median', median(validProc), ...
                'std', std(validProc), ...
                'min', min(validProc), ...
                'max', max(validProc), ...
                'p25', prctile(validProc, 25), ...
                'p75', prctile(validProc, 75), ...
                'p90', prctile(validProc, 90), ...
                'validCount', length(validProc), ...
                'allValues', validProc);
        else
            opMetrics.procedureTime = struct('validCount', 0, 'allValues', []);
        end
        
        % Post-procedure time metrics
        if ~isempty(validPost)
            opMetrics.postTime = struct(...
                'mean', mean(validPost), ...
                'median', median(validPost), ...
                'std', std(validPost), ...
                'min', min(validPost), ...
                'max', max(validPost), ...
                'p25', prctile(validPost, 25), ...
                'p75', prctile(validPost, 75), ...
                'p90', prctile(validPost, 90), ...
                'validCount', length(validPost), ...
                'allValues', validPost);
        else
            opMetrics.postTime = struct('validCount', 0, 'allValues', []);
        end
        
        % Total case time (sum of setup + procedure + post)
        totalCaseTimes = [];
        for caseIdx = 1:length(opSetupTimes)
            setupT = opSetupTimes(caseIdx);
            procT = opProcTimes(caseIdx);
            postT = opPostTimes(caseIdx);
            
            % Only include if all three components are valid
            if ~isnan(setupT) && ~isnan(procT) && ~isnan(postT) && setupT > 0 && procT > 0 && postT > 0
                totalCaseTimes = [totalCaseTimes, setupT + procT + postT];
            end
        end
        
        if ~isempty(totalCaseTimes)
            opMetrics.totalCaseTime = struct(...
                'mean', mean(totalCaseTimes), ...
                'median', median(totalCaseTimes), ...
                'std', std(totalCaseTimes), ...
                'min', min(totalCaseTimes), ...
                'max', max(totalCaseTimes), ...
                'p25', prctile(totalCaseTimes, 25), ...
                'p75', prctile(totalCaseTimes, 75), ...
                'p90', prctile(totalCaseTimes, 90), ...
                'validCount', length(totalCaseTimes), ...
                'allValues', totalCaseTimes);
        else
            opMetrics.totalCaseTime = struct('validCount', 0, 'allValues', []);
        end
        
        % Procedure type analysis for this operator
        opProcedures = historicalData.procedure(operatorIndices);
        opProcedures = opProcedures(~ismissing(opProcedures) & ~strcmp(opProcedures, ''));
        [uniqueProcs, ~, procIdx] = unique(opProcedures);
        procCounts = accumarray(procIdx, 1);
        [procCounts, sortIdx] = sort(procCounts, 'descend');
        uniqueProcs = uniqueProcs(sortIdx);
        
        opMetrics.procedureTypes = struct(...
            'procedures', {uniqueProcs}, ...
            'counts', procCounts, ...
            'percentages', (procCounts / length(opProcedures)) * 100);
        
        % Service/location analysis
        if isfield(historicalData, 'service')
            opServices = historicalData.service(operatorIndices);
            opServices = opServices(~ismissing(opServices) & ~strcmp(opServices, ''));
            if ~isempty(opServices)
                [uniqueServices, ~, serviceIdx] = unique(opServices);
                serviceCounts = accumarray(serviceIdx, 1);
                opMetrics.services = struct(...
                    'services', {uniqueServices}, ...
                    'counts', serviceCounts);
            else
                opMetrics.services = struct('services', {{}}, 'counts', []);
            end
        end
        
        % Room analysis
        if isfield(historicalData, 'room')
            opRooms = historicalData.room(operatorIndices);
            opRooms = opRooms(~ismissing(opRooms) & ~strcmp(opRooms, ''));
            if ~isempty(opRooms)
                [uniqueRooms, ~, roomIdx] = unique(opRooms);
                roomCounts = accumarray(roomIdx, 1);
                opMetrics.rooms = struct(...
                    'rooms', {uniqueRooms}, ...
                    'counts', roomCounts);
            else
                opMetrics.rooms = struct('rooms', {{}}, 'counts', []);
            end
        end
        
        % Calculate efficiency metrics
        if opMetrics.setupTime.validCount > 0 && opMetrics.procedureTime.validCount > 0
            setupToProcRatio = opMetrics.setupTime.mean / opMetrics.procedureTime.mean;
            if opMetrics.postTime.validCount > 0
                postToProcRatio = opMetrics.postTime.mean / opMetrics.procedureTime.mean;
            else
                postToProcRatio = NaN;
            end
            opMetrics.efficiency = struct(...
                'setupToProcRatio', setupToProcRatio, ...
                'postToProcRatio', postToProcRatio);
        else
            opMetrics.efficiency = struct('setupToProcRatio', NaN, 'postToProcRatio', NaN);
        end
        
        % Store in main structure using valid field name
        fieldName = matlab.lang.makeValidName(operator);
        operatorMetrics.(fieldName) = opMetrics;
    end
    
    % Display summary if requested
    if showStats
        displayOperatorMetricsSummary(operatorMetrics);
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

function displayOperatorMetricsSummary(operatorMetrics)
    fprintf('\n--- Comprehensive Operator Metrics Summary ---\n');
    
    operatorNames = fieldnames(operatorMetrics);
    if isempty(operatorNames)
        fprintf('No operator metrics available\n');
        return;
    end
    
    % Sort operators by total case count
    totalCases = zeros(length(operatorNames), 1);
    for i = 1:length(operatorNames)
        totalCases(i) = operatorMetrics.(operatorNames{i}).totalCases;
    end
    [~, sortIdx] = sort(totalCases, 'descend');
    
    fprintf('\nTop operators by case volume:\n');
    for i = 1:min(10, length(sortIdx))
        idx = sortIdx(i);
        opName = operatorNames{idx};
        opData = operatorMetrics.(opName);
        
        fprintf('\n%s (%d total cases):\n', opData.operatorName, opData.totalCases);
        
        % Setup time
        if opData.setupTime.validCount > 0
            fprintf('  Setup time: Mean=%.1f±%.1f min, Median=%.1f min (P25=%.1f, P75=%.1f, P90=%.1f)\n', ...
                opData.setupTime.mean, opData.setupTime.std, opData.setupTime.median, ...
                opData.setupTime.p25, opData.setupTime.p75, opData.setupTime.p90);
        else
            fprintf('  Setup time: No valid data\n');
        end
        
        % Procedure time
        if opData.procedureTime.validCount > 0
            fprintf('  Procedure time: Mean=%.1f±%.1f min, Median=%.1f min (P25=%.1f, P75=%.1f, P90=%.1f)\n', ...
                opData.procedureTime.mean, opData.procedureTime.std, opData.procedureTime.median, ...
                opData.procedureTime.p25, opData.procedureTime.p75, opData.procedureTime.p90);
        else
            fprintf('  Procedure time: No valid data\n');
        end
        
        % Post time
        if opData.postTime.validCount > 0
            fprintf('  Post time: Mean=%.1f±%.1f min, Median=%.1f min (P25=%.1f, P75=%.1f, P90=%.1f)\n', ...
                opData.postTime.mean, opData.postTime.std, opData.postTime.median, ...
                opData.postTime.p25, opData.postTime.p75, opData.postTime.p90);
        else
            fprintf('  Post time: No valid data\n');
        end
        
        % Total case time
        if opData.totalCaseTime.validCount > 0
            fprintf('  Total case time: Mean=%.1f±%.1f min, Median=%.1f min\n', ...
                opData.totalCaseTime.mean, opData.totalCaseTime.std, opData.totalCaseTime.median);
        else
            fprintf('  Total case time: No valid data\n');
        end
        
        % Top procedures
        if ~isempty(opData.procedureTypes.procedures)
            fprintf('  Top procedures: ');
            for j = 1:min(3, length(opData.procedureTypes.procedures))
                fprintf('%s (%d cases)', opData.procedureTypes.procedures{j}, opData.procedureTypes.counts(j));
                if j < min(3, length(opData.procedureTypes.procedures))
                    fprintf(', ');
                end
            end
            fprintf('\n');
        end
        
        % Efficiency ratios
        if ~isnan(opData.efficiency.setupToProcRatio)
            fprintf('  Efficiency: Setup/Proc ratio=%.2f', opData.efficiency.setupToProcRatio);
            if ~isnan(opData.efficiency.postToProcRatio)
                fprintf(', Post/Proc ratio=%.2f', opData.efficiency.postToProcRatio);
            end
            fprintf('\n');
        end
    end
end

function plotData = createOperatorPlottingData(operatorMetrics)
    % Creates structured data arrays for easy plotting of operator metrics
    % Returns a structure with arrays organized for plotting
    
    operatorNames = fieldnames(operatorMetrics);
    numOperators = length(operatorNames);
    
    if numOperators == 0
        plotData = struct();
        return;
    end
    
    % Initialize arrays
    plotData = struct();
    plotData.operatorNames = cell(numOperators, 1);
    plotData.totalCases = zeros(numOperators, 1);
    
    % Time metrics arrays
    plotData.setupTime = struct();
    plotData.setupTime.mean = NaN(numOperators, 1);
    plotData.setupTime.median = NaN(numOperators, 1);
    plotData.setupTime.std = NaN(numOperators, 1);
    plotData.setupTime.p25 = NaN(numOperators, 1);
    plotData.setupTime.p75 = NaN(numOperators, 1);
    plotData.setupTime.p90 = NaN(numOperators, 1);
    plotData.setupTime.allValues = cell(numOperators, 1);
    
    plotData.procedureTime = struct();
    plotData.procedureTime.mean = NaN(numOperators, 1);
    plotData.procedureTime.median = NaN(numOperators, 1);
    plotData.procedureTime.std = NaN(numOperators, 1);
    plotData.procedureTime.p25 = NaN(numOperators, 1);
    plotData.procedureTime.p75 = NaN(numOperators, 1);
    plotData.procedureTime.p90 = NaN(numOperators, 1);
    plotData.procedureTime.allValues = cell(numOperators, 1);
    
    plotData.postTime = struct();
    plotData.postTime.mean = NaN(numOperators, 1);
    plotData.postTime.median = NaN(numOperators, 1);
    plotData.postTime.std = NaN(numOperators, 1);
    plotData.postTime.p25 = NaN(numOperators, 1);
    plotData.postTime.p75 = NaN(numOperators, 1);
    plotData.postTime.p90 = NaN(numOperators, 1);
    plotData.postTime.allValues = cell(numOperators, 1);
    
    plotData.totalCaseTime = struct();
    plotData.totalCaseTime.mean = NaN(numOperators, 1);
    plotData.totalCaseTime.median = NaN(numOperators, 1);
    plotData.totalCaseTime.std = NaN(numOperators, 1);
    plotData.totalCaseTime.p25 = NaN(numOperators, 1);
    plotData.totalCaseTime.p75 = NaN(numOperators, 1);
    plotData.totalCaseTime.p90 = NaN(numOperators, 1);
    plotData.totalCaseTime.allValues = cell(numOperators, 1);
    
    % Efficiency ratios
    plotData.efficiency = struct();
    plotData.efficiency.setupToProcRatio = NaN(numOperators, 1);
    plotData.efficiency.postToProcRatio = NaN(numOperators, 1);
    
    % Fill arrays
    for i = 1:numOperators
        opName = operatorNames{i};
        opData = operatorMetrics.(opName);
        
        plotData.operatorNames{i} = opData.operatorName;
        plotData.totalCases(i) = opData.totalCases;
        
        % Setup time data
        if opData.setupTime.validCount > 0
            plotData.setupTime.mean(i) = opData.setupTime.mean;
            plotData.setupTime.median(i) = opData.setupTime.median;
            plotData.setupTime.std(i) = opData.setupTime.std;
            plotData.setupTime.p25(i) = opData.setupTime.p25;
            plotData.setupTime.p75(i) = opData.setupTime.p75;
            plotData.setupTime.p90(i) = opData.setupTime.p90;
            plotData.setupTime.allValues{i} = opData.setupTime.allValues;
        else
            plotData.setupTime.allValues{i} = [];
        end
        
        % Procedure time data
        if opData.procedureTime.validCount > 0
            plotData.procedureTime.mean(i) = opData.procedureTime.mean;
            plotData.procedureTime.median(i) = opData.procedureTime.median;
            plotData.procedureTime.std(i) = opData.procedureTime.std;
            plotData.procedureTime.p25(i) = opData.procedureTime.p25;
            plotData.procedureTime.p75(i) = opData.procedureTime.p75;
            plotData.procedureTime.p90(i) = opData.procedureTime.p90;
            plotData.procedureTime.allValues{i} = opData.procedureTime.allValues;
        else
            plotData.procedureTime.allValues{i} = [];
        end
        
        % Post time data
        if opData.postTime.validCount > 0
            plotData.postTime.mean(i) = opData.postTime.mean;
            plotData.postTime.median(i) = opData.postTime.median;
            plotData.postTime.std(i) = opData.postTime.std;
            plotData.postTime.p25(i) = opData.postTime.p25;
            plotData.postTime.p75(i) = opData.postTime.p75;
            plotData.postTime.p90(i) = opData.postTime.p90;
            plotData.postTime.allValues{i} = opData.postTime.allValues;
        else
            plotData.postTime.allValues{i} = [];
        end
        
        % Total case time data
        if opData.totalCaseTime.validCount > 0
            plotData.totalCaseTime.mean(i) = opData.totalCaseTime.mean;
            plotData.totalCaseTime.median(i) = opData.totalCaseTime.median;
            plotData.totalCaseTime.std(i) = opData.totalCaseTime.std;
            plotData.totalCaseTime.p25(i) = opData.totalCaseTime.p25;
            plotData.totalCaseTime.p75(i) = opData.totalCaseTime.p75;
            plotData.totalCaseTime.p90(i) = opData.totalCaseTime.p90;
            plotData.totalCaseTime.allValues{i} = opData.totalCaseTime.allValues;
        else
            plotData.totalCaseTime.allValues{i} = [];
        end
        
        % Efficiency ratios
        plotData.efficiency.setupToProcRatio(i) = opData.efficiency.setupToProcRatio;
        plotData.efficiency.postToProcRatio(i) = opData.efficiency.postToProcRatio;
    end
    
    % Sort all arrays by total cases (descending)
    [~, sortIdx] = sort(plotData.totalCases, 'descend');
    
    plotData.operatorNames = plotData.operatorNames(sortIdx);
    plotData.totalCases = plotData.totalCases(sortIdx);
    
    plotData.setupTime.mean = plotData.setupTime.mean(sortIdx);
    plotData.setupTime.median = plotData.setupTime.median(sortIdx);
    plotData.setupTime.std = plotData.setupTime.std(sortIdx);
    plotData.setupTime.p25 = plotData.setupTime.p25(sortIdx);
    plotData.setupTime.p75 = plotData.setupTime.p75(sortIdx);
    plotData.setupTime.p90 = plotData.setupTime.p90(sortIdx);
    plotData.setupTime.allValues = plotData.setupTime.allValues(sortIdx);
    
    plotData.procedureTime.mean = plotData.procedureTime.mean(sortIdx);
    plotData.procedureTime.median = plotData.procedureTime.median(sortIdx);
    plotData.procedureTime.std = plotData.procedureTime.std(sortIdx);
    plotData.procedureTime.p25 = plotData.procedureTime.p25(sortIdx);
    plotData.procedureTime.p75 = plotData.procedureTime.p75(sortIdx);
    plotData.procedureTime.p90 = plotData.procedureTime.p90(sortIdx);
    plotData.procedureTime.allValues = plotData.procedureTime.allValues(sortIdx);
    
    plotData.postTime.mean = plotData.postTime.mean(sortIdx);
    plotData.postTime.median = plotData.postTime.median(sortIdx);
    plotData.postTime.std = plotData.postTime.std(sortIdx);
    plotData.postTime.p25 = plotData.postTime.p25(sortIdx);
    plotData.postTime.p75 = plotData.postTime.p75(sortIdx);
    plotData.postTime.p90 = plotData.postTime.p90(sortIdx);
    plotData.postTime.allValues = plotData.postTime.allValues(sortIdx);
    
    plotData.totalCaseTime.mean = plotData.totalCaseTime.mean(sortIdx);
    plotData.totalCaseTime.median = plotData.totalCaseTime.median(sortIdx);
    plotData.totalCaseTime.std = plotData.totalCaseTime.std(sortIdx);
    plotData.totalCaseTime.p25 = plotData.totalCaseTime.p25(sortIdx);
    plotData.totalCaseTime.p75 = plotData.totalCaseTime.p75(sortIdx);
    plotData.totalCaseTime.p90 = plotData.totalCaseTime.p90(sortIdx);
    plotData.totalCaseTime.allValues = plotData.totalCaseTime.allValues(sortIdx);
    
    plotData.efficiency.setupToProcRatio = plotData.efficiency.setupToProcRatio(sortIdx);
    plotData.efficiency.postToProcRatio = plotData.efficiency.postToProcRatio(sortIdx);
end

function [globalProcedureAnalysis, procedureAnalysisByOperator] = performProcedureTimeAnalysis(historicalData, showStats)
    % Comprehensive procedure time analysis - global and per operator
    
    if showStats
        fprintf('\n=== COMPREHENSIVE PROCEDURE TIME ANALYSIS ===\n');
    end
    
    % Get unique procedures and operators
    uniqueProcedures = unique(historicalData.procedure);
    uniqueProcedures = uniqueProcedures(~ismissing(uniqueProcedures) & ~strcmp(uniqueProcedures, ''));
    
    uniqueOperators = unique(historicalData.surgeon);
    uniqueOperators = uniqueOperators(~ismissing(uniqueOperators) & ~strcmp(uniqueOperators, ''));
    
    %% GLOBAL PROCEDURE ANALYSIS
    globalProcedureAnalysis = struct();
    
    if showStats
        fprintf('\n--- Global Procedure Time Statistics ---\n');
    end
    
    for procIdx = 1:length(uniqueProcedures)
        procedure = uniqueProcedures{procIdx};
        procIndices = strcmp(historicalData.procedure, procedure);
        
        % Get time data for all time components
        setupTimes = historicalData.setupTime(procIndices);
        procTimes = historicalData.procedureTime(procIndices);
        postTimes = historicalData.postTime(procIndices);
        
        % Remove invalid/missing values
        validSetup = setupTimes(~isnan(setupTimes) & setupTimes > 0);
        validProc = procTimes(~isnan(procTimes) & procTimes > 0);
        validPost = postTimes(~isnan(postTimes) & postTimes > 0);
        
        % Initialize procedure structure
        procStats = struct();
        procStats.procedureName = procedure;
        procStats.totalCases = sum(procIndices);
        
        % Setup time statistics
        if ~isempty(validSetup)
            procStats.setupTime = struct(...
                'mean', mean(validSetup), ...
                'median', median(validSetup), ...
                'std', std(validSetup), ...
                'min', min(validSetup), ...
                'max', max(validSetup), ...
                'p25', prctile(validSetup, 25), ...
                'p75', prctile(validSetup, 75), ...
                'p90', prctile(validSetup, 90), ...
                'validCount', length(validSetup), ...
                'allValues', validSetup);
        else
            procStats.setupTime = struct('validCount', 0, 'allValues', []);
        end
        
        % Procedure time statistics
        if ~isempty(validProc)
            procStats.procedureTime = struct(...
                'mean', mean(validProc), ...
                'median', median(validProc), ...
                'std', std(validProc), ...
                'min', min(validProc), ...
                'max', max(validProc), ...
                'p25', prctile(validProc, 25), ...
                'p75', prctile(validProc, 75), ...
                'p90', prctile(validProc, 90), ...
                'validCount', length(validProc), ...
                'allValues', validProc);
        else
            procStats.procedureTime = struct('validCount', 0, 'allValues', []);
        end
        
        % Post time statistics
        if ~isempty(validPost)
            procStats.postTime = struct(...
                'mean', mean(validPost), ...
                'median', median(validPost), ...
                'std', std(validPost), ...
                'min', min(validPost), ...
                'max', max(validPost), ...
                'p25', prctile(validPost, 25), ...
                'p75', prctile(validPost, 75), ...
                'p90', prctile(validPost, 90), ...
                'validCount', length(validPost), ...
                'allValues', validPost);
        else
            procStats.postTime = struct('validCount', 0, 'allValues', []);
        end
        
        % Total case time
        totalCaseTimes = [];
        for caseIdx = 1:length(setupTimes)
            setupT = setupTimes(caseIdx);
            procT = procTimes(caseIdx);
            postT = postTimes(caseIdx);
            
            if ~isnan(setupT) && ~isnan(procT) && ~isnan(postT) && setupT > 0 && procT > 0 && postT > 0
                totalCaseTimes = [totalCaseTimes, setupT + procT + postT];
            end
        end
        
        if ~isempty(totalCaseTimes)
            procStats.totalCaseTime = struct(...
                'mean', mean(totalCaseTimes), ...
                'median', median(totalCaseTimes), ...
                'std', std(totalCaseTimes), ...
                'min', min(totalCaseTimes), ...
                'max', max(totalCaseTimes), ...
                'p25', prctile(totalCaseTimes, 25), ...
                'p75', prctile(totalCaseTimes, 75), ...
                'p90', prctile(totalCaseTimes, 90), ...
                'validCount', length(totalCaseTimes), ...
                'allValues', totalCaseTimes);
        else
            procStats.totalCaseTime = struct('validCount', 0, 'allValues', []);
        end
        
        % Store using valid field name
        fieldName = matlab.lang.makeValidName(procedure);
        globalProcedureAnalysis.(fieldName) = procStats;
        
        % Display if requested
        if showStats && procStats.procedureTime.validCount >= 5
            fprintf('%s (%d cases):\n', procedure, procStats.totalCases);
            if procStats.setupTime.validCount > 0
                fprintf('  Setup: Mean=%.1f, Median=%.1f, P25=%.1f, P75=%.1f, P90=%.1f min\n', ...
                    procStats.setupTime.mean, procStats.setupTime.median, ...
                    procStats.setupTime.p25, procStats.setupTime.p75, procStats.setupTime.p90);
            end
            if procStats.procedureTime.validCount > 0
                fprintf('  Procedure: Mean=%.1f, Median=%.1f, P25=%.1f, P75=%.1f, P90=%.1f min\n', ...
                    procStats.procedureTime.mean, procStats.procedureTime.median, ...
                    procStats.procedureTime.p25, procStats.procedureTime.p75, procStats.procedureTime.p90);
            end
            if procStats.postTime.validCount > 0
                fprintf('  Post: Mean=%.1f, Median=%.1f, P25=%.1f, P75=%.1f, P90=%.1f min\n', ...
                    procStats.postTime.mean, procStats.postTime.median, ...
                    procStats.postTime.p25, procStats.postTime.p75, procStats.postTime.p90);
            end
        end
    end
    
    %% PROCEDURE ANALYSIS BY OPERATOR
    procedureAnalysisByOperator = struct();
    
    if showStats
        fprintf('\n--- Procedure Time Analysis by Operator ---\n');
    end
    
    for opIdx = 1:length(uniqueOperators)
        operator = uniqueOperators{opIdx};
        operatorIndices = strcmp(historicalData.surgeon, operator);
        
        % Get procedures for this operator
        operatorProcedures = historicalData.procedure(operatorIndices);
        operatorProcedures = operatorProcedures(~ismissing(operatorProcedures) & ~strcmp(operatorProcedures, ''));
        uniqueOpProcedures = unique(operatorProcedures);
        
        % Initialize operator structure
        opProcAnalysis = struct();
        opProcAnalysis.operatorName = operator;
        opProcAnalysis.totalCases = sum(operatorIndices);
        
        % Analyze each procedure for this operator
        for procIdx = 1:length(uniqueOpProcedures)
            procedure = uniqueOpProcedures{procIdx};
            
            % Get indices for this operator and procedure combination
            combinedIndices = operatorIndices & strcmp(historicalData.procedure, procedure);
            
            % Get time data
            setupTimes = historicalData.setupTime(combinedIndices);
            procTimes = historicalData.procedureTime(combinedIndices);
            postTimes = historicalData.postTime(combinedIndices);
            
            % Remove invalid/missing values
            validSetup = setupTimes(~isnan(setupTimes) & setupTimes > 0);
            validProc = procTimes(~isnan(procTimes) & procTimes > 0);
            validPost = postTimes(~isnan(postTimes) & postTimes > 0);
            
            % Only include if we have sufficient data
            if length(validProc) >= 3  % Need at least 3 cases for meaningful statistics
                procOpStats = struct();
                procOpStats.procedureName = procedure;
                procOpStats.caseCount = sum(combinedIndices);
                
                % Setup time statistics
                if ~isempty(validSetup)
                    procOpStats.setupTime = struct(...
                        'mean', mean(validSetup), ...
                        'median', median(validSetup), ...
                        'std', std(validSetup), ...
                        'p25', prctile(validSetup, 25), ...
                        'p75', prctile(validSetup, 75), ...
                        'p90', prctile(validSetup, 90), ...
                        'validCount', length(validSetup), ...
                        'allValues', validSetup);
                else
                    procOpStats.setupTime = struct('validCount', 0, 'allValues', []);
                end
                
                % Procedure time statistics
                if ~isempty(validProc)
                    procOpStats.procedureTime = struct(...
                        'mean', mean(validProc), ...
                        'median', median(validProc), ...
                        'std', std(validProc), ...
                        'p25', prctile(validProc, 25), ...
                        'p75', prctile(validProc, 75), ...
                        'p90', prctile(validProc, 90), ...
                        'validCount', length(validProc), ...
                        'allValues', validProc);
                else
                    procOpStats.procedureTime = struct('validCount', 0, 'allValues', []);
                end
                
                % Post time statistics
                if ~isempty(validPost)
                    procOpStats.postTime = struct(...
                        'mean', mean(validPost), ...
                        'median', median(validPost), ...
                        'std', std(validPost), ...
                        'p25', prctile(validPost, 25), ...
                        'p75', prctile(validPost, 75), ...
                        'p90', prctile(validPost, 90), ...
                        'validCount', length(validPost), ...
                        'allValues', validPost);
                else
                    procOpStats.postTime = struct('validCount', 0, 'allValues', []);
                end
                
                % Total case time (only if all three components are available)
                totalCaseTimes = [];
                for caseIdx = 1:length(setupTimes)
                    setupT = setupTimes(caseIdx);
                    procT = procTimes(caseIdx);
                    postT = postTimes(caseIdx);
                    
                    if ~isnan(setupT) && ~isnan(procT) && ~isnan(postT) && setupT > 0 && procT > 0 && postT > 0
                        totalCaseTimes = [totalCaseTimes, setupT + procT + postT];
                    end
                end
                
                if ~isempty(totalCaseTimes)
                    procOpStats.totalCaseTime = struct(...
                        'mean', mean(totalCaseTimes), ...
                        'median', median(totalCaseTimes), ...
                        'std', std(totalCaseTimes), ...
                        'p25', prctile(totalCaseTimes, 25), ...
                        'p75', prctile(totalCaseTimes, 75), ...
                        'p90', prctile(totalCaseTimes, 90), ...
                        'validCount', length(totalCaseTimes), ...
                        'allValues', totalCaseTimes);
                else
                    procOpStats.totalCaseTime = struct('validCount', 0, 'allValues', []);
                end
                
                % Store using valid field name
                procFieldName = matlab.lang.makeValidName(procedure);
                opProcAnalysis.(procFieldName) = procOpStats;
            end
        end
        
        % Store operator analysis using valid field name
        opFieldName = matlab.lang.makeValidName(operator);
        procedureAnalysisByOperator.(opFieldName) = opProcAnalysis;
        
        % Display top procedures for this operator if requested
        if showStats && opProcAnalysis.totalCases >= 10
            opProcFields = fieldnames(opProcAnalysis);
            procFields = opProcFields(~strcmp(opProcFields, 'operatorName') & ~strcmp(opProcFields, 'totalCases'));
            
            if ~isempty(procFields)
                fprintf('\n%s (%d total cases):\n', operator, opProcAnalysis.totalCases);
                for i = 1:min(3, length(procFields))  % Show top 3 procedures
                    procField = procFields{i};
                    procData = opProcAnalysis.(procField);
                    if procData.procedureTime.validCount > 0
                        setupMean = NaN;
                        if procData.setupTime.validCount > 0
                            setupMean = procData.setupTime.mean;
                        end
                        postMean = NaN;
                        if procData.postTime.validCount > 0
                            postMean = procData.postTime.mean;
                        end
                        
                        fprintf('  %s (%d cases): Setup=%.1f, Proc=%.1f (P25=%.1f, P75=%.1f, P90=%.1f), Post=%.1f min\n', ...
                            procData.procedureName, procData.caseCount, ...
                            setupMean, procData.procedureTime.mean, ...
                            procData.procedureTime.p25, procData.procedureTime.p75, procData.procedureTime.p90, ...
                            postMean);
                    end
                end
            end
        end
    end
    
    if showStats
        fprintf('\nProcedure time analysis complete!\n');
        fprintf('Global analysis: %d procedure types\n', length(fieldnames(globalProcedureAnalysis)));
        fprintf('Per-operator analysis: %d operators\n', length(fieldnames(procedureAnalysisByOperator)));
    end
end

function procedurePlottingData = createProcedurePlottingData(globalAnalysis, operatorAnalysis)
    % Creates structured data arrays for easy plotting of procedure metrics
    
    procedurePlottingData = struct();
    
    % Global procedure plotting data
    globalFields = fieldnames(globalAnalysis);
    numProcedures = length(globalFields);
    
    if numProcedures > 0
        % Initialize global arrays
        global_data = struct();
        global_data.procedureNames = cell(numProcedures, 1);
        global_data.totalCases = zeros(numProcedures, 1);
        
        % Time metrics arrays for global data
        time_metrics = {'setupTime', 'procedureTime', 'postTime', 'totalCaseTime'};
        for metric = time_metrics
            metricName = metric{1};
            global_data.(metricName) = struct();
            global_data.(metricName).mean = NaN(numProcedures, 1);
            global_data.(metricName).median = NaN(numProcedures, 1);
            global_data.(metricName).std = NaN(numProcedures, 1);
            global_data.(metricName).p25 = NaN(numProcedures, 1);
            global_data.(metricName).p75 = NaN(numProcedures, 1);
            global_data.(metricName).p90 = NaN(numProcedures, 1);
            global_data.(metricName).allValues = cell(numProcedures, 1);
        end
        
        % Fill global arrays
        for i = 1:numProcedures
            procField = globalFields{i};
            procData = globalAnalysis.(procField);
            
            global_data.procedureNames{i} = procData.procedureName;
            global_data.totalCases(i) = procData.totalCases;
            
            % Fill time metrics
            for metric = time_metrics
                metricName = metric{1};
                if procData.(metricName).validCount > 0
                    global_data.(metricName).mean(i) = procData.(metricName).mean;
                    global_data.(metricName).median(i) = procData.(metricName).median;
                    global_data.(metricName).std(i) = procData.(metricName).std;
                    global_data.(metricName).p25(i) = procData.(metricName).p25;
                    global_data.(metricName).p75(i) = procData.(metricName).p75;
                    global_data.(metricName).p90(i) = procData.(metricName).p90;
                    global_data.(metricName).allValues{i} = procData.(metricName).allValues;
                else
                    global_data.(metricName).allValues{i} = [];
                end
            end
        end
        
        % Sort by total cases (descending)
        [~, sortIdx] = sort(global_data.totalCases, 'descend');
        
        global_data.procedureNames = global_data.procedureNames(sortIdx);
        global_data.totalCases = global_data.totalCases(sortIdx);
        
        for metric = time_metrics
            metricName = metric{1};
            global_data.(metricName).mean = global_data.(metricName).mean(sortIdx);
            global_data.(metricName).median = global_data.(metricName).median(sortIdx);
            global_data.(metricName).std = global_data.(metricName).std(sortIdx);
            global_data.(metricName).p25 = global_data.(metricName).p25(sortIdx);
            global_data.(metricName).p75 = global_data.(metricName).p75(sortIdx);
            global_data.(metricName).p90 = global_data.(metricName).p90(sortIdx);
            global_data.(metricName).allValues = global_data.(metricName).allValues(sortIdx);
        end
        
        procedurePlottingData.global = global_data;
    else
        procedurePlottingData.global = struct();
    end
    
    % Operator-specific procedure plotting data
    operatorFields = fieldnames(operatorAnalysis);
    procedurePlottingData.byOperator = struct();
    
    for opIdx = 1:length(operatorFields)
        opField = operatorFields{opIdx};
        opData = operatorAnalysis.(opField);
        
        % Get procedure fields for this operator (exclude metadata fields)
        opProcFields = fieldnames(opData);
        opProcFields = opProcFields(~strcmp(opProcFields, 'operatorName') & ~strcmp(opProcFields, 'totalCases'));
        
        if ~isempty(opProcFields)
            numOpProcs = length(opProcFields);
            
            % Initialize operator-specific arrays
            op_plot_data = struct();
            op_plot_data.operatorName = opData.operatorName;
            op_plot_data.totalCases = opData.totalCases;
            op_plot_data.procedureNames = cell(numOpProcs, 1);
            op_plot_data.caseCounts = zeros(numOpProcs, 1);
            
            % Time metrics arrays for operator data
            for metric = time_metrics
                metricName = metric{1};
                op_plot_data.(metricName) = struct();
                op_plot_data.(metricName).mean = NaN(numOpProcs, 1);
                op_plot_data.(metricName).median = NaN(numOpProcs, 1);
                op_plot_data.(metricName).std = NaN(numOpProcs, 1);
                op_plot_data.(metricName).p25 = NaN(numOpProcs, 1);
                op_plot_data.(metricName).p75 = NaN(numOpProcs, 1);
                op_plot_data.(metricName).p90 = NaN(numOpProcs, 1);
                op_plot_data.(metricName).allValues = cell(numOpProcs, 1);
            end
            
            % Fill operator arrays
            for j = 1:numOpProcs
                procField = opProcFields{j};
                procData = opData.(procField);
                
                op_plot_data.procedureNames{j} = procData.procedureName;
                op_plot_data.caseCounts(j) = procData.caseCount;
                
                % Fill time metrics
                for metric = time_metrics
                    metricName = metric{1};
                    if procData.(metricName).validCount > 0
                        op_plot_data.(metricName).mean(j) = procData.(metricName).mean;
                        op_plot_data.(metricName).median(j) = procData.(metricName).median;
                        op_plot_data.(metricName).std(j) = procData.(metricName).std;
                        op_plot_data.(metricName).p25(j) = procData.(metricName).p25;
                        op_plot_data.(metricName).p75(j) = procData.(metricName).p75;
                        op_plot_data.(metricName).p90(j) = procData.(metricName).p90;
                        op_plot_data.(metricName).allValues{j} = procData.(metricName).allValues;
                    else
                        op_plot_data.(metricName).allValues{j} = [];
                    end
                end
            end
            
            % Sort by case count (descending)
            [~, sortIdx] = sort(op_plot_data.caseCounts, 'descend');
            
            op_plot_data.procedureNames = op_plot_data.procedureNames(sortIdx);
            op_plot_data.caseCounts = op_plot_data.caseCounts(sortIdx);
            
            for metric = time_metrics
                metricName = metric{1};
                op_plot_data.(metricName).mean = op_plot_data.(metricName).mean(sortIdx);
                op_plot_data.(metricName).median = op_plot_data.(metricName).median(sortIdx);
                op_plot_data.(metricName).std = op_plot_data.(metricName).std(sortIdx);
                op_plot_data.(metricName).p25 = op_plot_data.(metricName).p25(sortIdx);
                op_plot_data.(metricName).p75 = op_plot_data.(metricName).p75(sortIdx);
                op_plot_data.(metricName).p90 = op_plot_data.(metricName).p90(sortIdx);
                op_plot_data.(metricName).allValues = op_plot_data.(metricName).allValues(sortIdx);
            end
            
            procedurePlottingData.byOperator.(opField) = op_plot_data;
        end
    end
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
                fprintf('  %s: Avg idle time %.1f±%.1f, median %.1f min (range: %.1f-%.1f min, %d days)\n', ...
                    opName, mean(validIdleTimes), std(validIdleTimes), median(validIdleTimes), min(validIdleTimes), max(validIdleTimes), length(validIdleTimes));
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
                fprintf('  %s: Avg %.1f±%.1f, median %.1f lab flips/day (range: %d-%d flips, %d days with flips)\n', ...
                    opName, mean(validFlips), std(validFlips), median(validFlips), min(validFlips), max(validFlips), length(validFlips));
            end
        end
    end
    
    % Display daily lab flip statistics
    if ~isempty(dailyLabFlips)
        fprintf('\nDaily lab flip summary:\n');
        fprintf('  Total lab flips across all days: %d\n', sum(dailyLabFlips));
        fprintf('  Average lab flips per day: %.1f±%.1f, median %.1f\n', mean(dailyLabFlips), std(dailyLabFlips), median(dailyLabFlips));
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
        
        % Get operator's schedule for the day
        if isstruct(opSchedule) && length(opSchedule) == 1
            % Single case - no idle time or flips possible, don't add to stats
            continue;
        elseif isstruct(opSchedule) && length(opSchedule) > 1
            % Multiple cases - initialize stats and analyze idle time and lab flips
            idleStats(opName) = 0;
            flipStats(opName) = 0;
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
                    
                    if isfield(currentCase.caseInfo, 'procEndTime') && isfield(nextCase.caseInfo, 'procStartTime')
                        idleTime = nextCase.caseInfo.procStartTime - currentCase.caseInfo.procEndTime;
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

%% Comprehensive Operator Metrics Function
function comprehensiveMetrics = createComprehensiveOperatorMetrics(historicalData, operatorAnalysis, showStats)
% Create detailed operator metrics for statistical analysis
% This function extracts comprehensive metrics directly from raw historical data
% and combines them with schedule-based analysis

if showStats
    fprintf('Creating comprehensive metrics for statistical analysis...\n');
end

% Initialize output structure
comprehensiveMetrics = struct();

% Operator group mapping (hardcoded). Edit getOperatorGroupMap() to maintain groups.
operatorGroupMap = getOperatorGroupMap();

% Get unique operators from historical data
if isfield(historicalData, 'surgeon')
    allOperators = string(historicalData.surgeon);
    uniqueOperators = unique(allOperators(~ismissing(allOperators)));
    uniqueOperators = cellstr(uniqueOperators);
else
    if showStats
        fprintf('  Warning: No surgeon field found in historical data\n');
    end
    uniqueOperators = {};
    return;
end

numOperators = length(uniqueOperators);
if showStats
    fprintf('  Processing %d operators from historical data...\n', numOperators);
end

% Initialize metrics structure for each operator
for i = 1:numOperators
    opName = uniqueOperators{i};
    safeOpName = matlab.lang.makeValidName(opName);
    
    if showStats && mod(i, 10) == 1
        fprintf('    Processing operator %d/%d: %s\n', i, numOperators, opName);
    end
    
    % Find all cases for this operator
    operatorMask = strcmp(string(historicalData.surgeon), opName);
    opCases = find(operatorMask);
    
    if isempty(opCases)
        continue;
    end
    
    % Initialize operator metrics
    opMetrics = struct();
    opMetrics.name = opName;
    % Assign operator group (defaults to 'Other' if not mapped)
    if isKey(operatorGroupMap, opName)
        opMetrics.operatorGroup = operatorGroupMap(opName);
    else
        opMetrics.operatorGroup = 'Other';
    end
    opMetrics.totalCases = length(opCases);
    
    %% BASIC WORKING PATTERN METRICS
    % Get unique working dates
    opDates = historicalData.date(opCases);
    uniqueDates = unique(string(opDates(~ismissing(opDates))));
    opMetrics.workingDays = length(uniqueDates);
    opMetrics.workingDates = uniqueDates;
    
    % Calculate cases per day statistics
    dailyCaseCounts = [];
    for d = 1:length(uniqueDates)
        dateStr = uniqueDates{d};
        casesThisDate = sum(strcmp(string(opDates), dateStr));
        dailyCaseCounts(end+1) = casesThisDate;
    end
    
    opMetrics.avgCasesPerDay = mean(dailyCaseCounts);
    opMetrics.medianCasesPerDay = median(dailyCaseCounts);
    opMetrics.stdCasesPerDay = std(dailyCaseCounts);
    opMetrics.minCasesPerDay = min(dailyCaseCounts);
    opMetrics.maxCasesPerDay = max(dailyCaseCounts);
    opMetrics.dailyCaseCounts = dailyCaseCounts;
    
    % Multi-procedure day analysis
    opMetrics.multiProcedureDays = sum(dailyCaseCounts > 1);
    opMetrics.multiProcedureDaysPct = (sum(dailyCaseCounts > 1) / length(dailyCaseCounts)) * 100;
    
    % Store the actual dates that had multiple procedures
    multiProcMask = dailyCaseCounts > 1;
    opMetrics.multiProcedureDates = uniqueDates(multiProcMask);
    opMetrics.multiProcedureDateCounts = dailyCaseCounts(multiProcMask);
    
    %% PROCEDURE DURATION METRICS
    procTimes = historicalData.procedureTime(opCases);
    validProcTimes = procTimes(~isnan(procTimes) & procTimes > 0);
    
    if ~isempty(validProcTimes)
        opMetrics.avgProcedureTime = mean(validProcTimes);
        opMetrics.medianProcedureTime = median(validProcTimes);
        opMetrics.stdProcedureTime = std(validProcTimes);
        opMetrics.p25ProcedureTime = prctile(validProcTimes, 25);
        opMetrics.p75ProcedureTime = prctile(validProcTimes, 75);
        opMetrics.p90ProcedureTime = prctile(validProcTimes, 90);
    else
        opMetrics.avgProcedureTime = NaN;
        opMetrics.medianProcedureTime = NaN;
        opMetrics.stdProcedureTime = NaN;
        opMetrics.p25ProcedureTime = NaN;
        opMetrics.p75ProcedureTime = NaN;
        opMetrics.p90ProcedureTime = NaN;
    end
    
    %% SETUP AND POST TIME METRICS
    setupTimes = historicalData.setupTime(opCases);
    validSetupTimes = setupTimes(~isnan(setupTimes) & setupTimes > 0);
    
    if ~isempty(validSetupTimes)
        opMetrics.avgSetupTime = mean(validSetupTimes);
        opMetrics.medianSetupTime = median(validSetupTimes);
        opMetrics.stdSetupTime = std(validSetupTimes);
    else
        opMetrics.avgSetupTime = NaN;
        opMetrics.medianSetupTime = NaN;
        opMetrics.stdSetupTime = NaN;
    end
    
    postTimes = historicalData.postTime(opCases);
    validPostTimes = postTimes(~isnan(postTimes) & postTimes > 0);
    
    if ~isempty(validPostTimes)
        opMetrics.avgPostTime = mean(validPostTimes);
        opMetrics.medianPostTime = median(validPostTimes);
        opMetrics.stdPostTime = std(validPostTimes);
    else
        opMetrics.avgPostTime = NaN;
        opMetrics.medianPostTime = NaN;
        opMetrics.stdPostTime = NaN;
    end
    
    %% CASE MIX ANALYSIS
    % Inpatient vs Outpatient analysis
    if isfield(historicalData, 'admissionStatus')
        admissionStatuses = string(historicalData.admissionStatus(opCases));
        
        inpatientMask = contains(admissionStatuses, 'Inpatient', 'IgnoreCase', true);
        outpatientMask = contains(admissionStatuses, 'Outpatient', 'IgnoreCase', true);
        
        opMetrics.inpatientCases = sum(inpatientMask);
        opMetrics.outpatientCases = sum(outpatientMask);
        
        totalStatusCases = opMetrics.inpatientCases + opMetrics.outpatientCases;
        if totalStatusCases > 0
            opMetrics.inpatientProportion = opMetrics.inpatientCases / totalStatusCases;
            opMetrics.outpatientProportion = opMetrics.outpatientCases / totalStatusCases;
        else
            opMetrics.inpatientProportion = 0.5; % Default
            opMetrics.outpatientProportion = 0.5;
        end
    else
        opMetrics.inpatientCases = 0;
        opMetrics.outpatientCases = 0;
        opMetrics.inpatientProportion = 0.5;
        opMetrics.outpatientProportion = 0.5;
    end
    
    %% PROCEDURE TYPE DIVERSITY ANALYSIS
    if isfield(historicalData, 'procedure')
        procedures = string(historicalData.procedure(opCases));
        uniqueProcedures = unique(procedures(~ismissing(procedures)));
        
        opMetrics.uniqueProcedureTypes = length(uniqueProcedures);
        
        % Calculate Shannon diversity index
        procedureFreq = [];
        for p = 1:length(uniqueProcedures)
            freq = sum(strcmp(procedures, uniqueProcedures{p}));
            procedureFreq(end+1) = freq;
        end
        
        totalProcs = sum(procedureFreq);
        if totalProcs > 0
            proportions = procedureFreq / totalProcs;
            shannonIndex = -sum(proportions .* log(proportions + eps)); % Add eps to avoid log(0)
            opMetrics.procedureDiversityIndex = shannonIndex;
        else
            opMetrics.procedureDiversityIndex = 0;
        end
        
        % Store procedure-specific metrics
        opMetrics.procedureTypes = uniqueProcedures;
        opMetrics.procedureCounts = procedureFreq;
        
        % Calculate procedure-specific duration metrics
        for p = 1:length(uniqueProcedures)
            procType = uniqueProcedures{p};
            safeProcName = matlab.lang.makeValidName(procType);
            
            procMask = strcmp(procedures, procType);
            procIndices = opCases(procMask);
            
            % Duration metrics for this procedure type
            procDurations = historicalData.procedureTime(procIndices);
            validDurations = procDurations(~isnan(procDurations) & procDurations > 0);
            
            if ~isempty(validDurations)
                opMetrics.(['proc_' safeProcName '_Count']) = length(validDurations);
                opMetrics.(['proc_' safeProcName '_Proportion']) = length(validDurations) / opMetrics.totalCases;
                opMetrics.(['proc_' safeProcName '_AvgDuration']) = mean(validDurations);
                opMetrics.(['proc_' safeProcName '_MedianDuration']) = median(validDurations);
                opMetrics.(['proc_' safeProcName '_StdDuration']) = std(validDurations);
            else
                opMetrics.(['proc_' safeProcName '_Count']) = 0;
                opMetrics.(['proc_' safeProcName '_Proportion']) = 0;
                opMetrics.(['proc_' safeProcName '_AvgDuration']) = NaN;
                opMetrics.(['proc_' safeProcName '_MedianDuration']) = NaN;
                opMetrics.(['proc_' safeProcName '_StdDuration']) = NaN;
            end
            
            % Setup time metrics for this procedure type
            procSetupTimes = historicalData.setupTime(procIndices);
            validSetupTimes = procSetupTimes(~isnan(procSetupTimes) & procSetupTimes > 0);
            
            if ~isempty(validSetupTimes)
                opMetrics.(['proc_' safeProcName '_AvgSetup']) = mean(validSetupTimes);
                opMetrics.(['proc_' safeProcName '_MedianSetup']) = median(validSetupTimes);
            else
                opMetrics.(['proc_' safeProcName '_AvgSetup']) = NaN;
                opMetrics.(['proc_' safeProcName '_MedianSetup']) = NaN;
            end
            
            % Post time metrics for this procedure type
            procPostTimes = historicalData.postTime(procIndices);
            validPostTimes = procPostTimes(~isnan(procPostTimes) & procPostTimes > 0);
            
            if ~isempty(validPostTimes)
                opMetrics.(['proc_' safeProcName '_AvgPost']) = mean(validPostTimes);
                opMetrics.(['proc_' safeProcName '_MedianPost']) = median(validPostTimes);
            else
                opMetrics.(['proc_' safeProcName '_AvgPost']) = NaN;
                opMetrics.(['proc_' safeProcName '_MedianPost']) = NaN;
            end
        end
    else
        opMetrics.uniqueProcedureTypes = 1;
        opMetrics.procedureDiversityIndex = 0;
        opMetrics.procedureTypes = {};
        opMetrics.procedureCounts = [];
    end
    
    %% SCHEDULE-BASED PERFORMANCE METRICS
    % Extract metrics from existing operator analysis if available
    if ~isempty(operatorAnalysis) && isfield(operatorAnalysis, 'multiProcedureDayAverages')
        if isKey(operatorAnalysis.multiProcedureDayAverages, opName)
            scheduleMetrics = operatorAnalysis.multiProcedureDayAverages(opName);
            
            if isfield(scheduleMetrics, 'avgIdleTime')
                opMetrics.avgIdleTimePerDay = scheduleMetrics.avgIdleTime;
            else
                opMetrics.avgIdleTimePerDay = NaN;
            end
            
            if isfield(scheduleMetrics, 'medianIdleTime')
                opMetrics.medianIdleTimePerDay = scheduleMetrics.medianIdleTime;
            else
                opMetrics.medianIdleTimePerDay = opMetrics.avgIdleTimePerDay;
            end
            
            if isfield(scheduleMetrics, 'flipToTurnoverRatio')
                opMetrics.avgFlipToTurnoverRatio = scheduleMetrics.flipToTurnoverRatio * 100; % Convert to percentage
            else
                opMetrics.avgFlipToTurnoverRatio = NaN;
            end
        else
            opMetrics.avgIdleTimePerDay = NaN;
            opMetrics.medianIdleTimePerDay = NaN;
            opMetrics.avgFlipToTurnoverRatio = NaN;
        end
        
        % Get detailed idle time statistics from arrays if available
        if isfield(operatorAnalysis, 'idleTimeStats') && isKey(operatorAnalysis.idleTimeStats, opName)
            fullIdleArray = operatorAnalysis.idleTimeStats(opName);
            
            % Filter idleArray to only include dates where this operator worked
            % idleArray has entries for ALL schedule dates, but we only want operator's working dates
            if isfield(operatorAnalysis, 'analyzedDates')
                allScheduleDates = operatorAnalysis.analyzedDates;
                operatorIdleArray = [];
                
                for d = 1:length(uniqueDates)
                    dateStr = uniqueDates{d};
                    % Find this date in the schedule dates
                    dateIdx = find(strcmp(allScheduleDates, dateStr), 1);
                    if ~isempty(dateIdx) && dateIdx <= length(fullIdleArray)
                        operatorIdleArray(d) = fullIdleArray(dateIdx);
                    else
                        operatorIdleArray(d) = NaN;  % Date not in schedule or no data
                    end
                end
                
                opMetrics.dailyIdleTimes = operatorIdleArray;
            else
                % Fallback: use full array (shouldn't happen)
                opMetrics.dailyIdleTimes = fullIdleArray;
            end
            
            validIdle = opMetrics.dailyIdleTimes(~isnan(opMetrics.dailyIdleTimes));
            
            if ~isempty(validIdle)
                
                % Calculate comprehensive statistics
                opMetrics.stdIdleTimePerDay = std(validIdle);
                opMetrics.p25IdleTimePerDay = prctile(validIdle, 25);
                opMetrics.p75IdleTimePerDay = prctile(validIdle, 75);
                opMetrics.p90IdleTimePerDay = prctile(validIdle, 90);
                opMetrics.minIdleTimePerDay = min(validIdle);
                opMetrics.maxIdleTimePerDay = max(validIdle);
                
                if isnan(opMetrics.avgIdleTimePerDay)
                    opMetrics.avgIdleTimePerDay = mean(validIdle);
                    opMetrics.medianIdleTimePerDay = median(validIdle);
                end
            else
                opMetrics.dailyIdleTimes = [];
                opMetrics.stdIdleTimePerDay = NaN;
                opMetrics.p25IdleTimePerDay = NaN;
                opMetrics.p75IdleTimePerDay = NaN;
                opMetrics.p90IdleTimePerDay = NaN;
                opMetrics.minIdleTimePerDay = NaN;
                opMetrics.maxIdleTimePerDay = NaN;
            end
        else
            opMetrics.dailyIdleTimes = [];
            opMetrics.stdIdleTimePerDay = NaN;
            opMetrics.p25IdleTimePerDay = NaN;
            opMetrics.p75IdleTimePerDay = NaN;
            opMetrics.p90IdleTimePerDay = NaN;
            opMetrics.minIdleTimePerDay = NaN;
            opMetrics.maxIdleTimePerDay = NaN;
        end
        
        % Get detailed flip ratio statistics from arrays if available
        if isfield(operatorAnalysis, 'operatorFlipStats') && isKey(operatorAnalysis.operatorFlipStats, opName)
            flipArray = operatorAnalysis.operatorFlipStats(opName);
            
            % Only include flip ratios from multi-procedure days (where turnovers actually occur)
            if ~isempty(opMetrics.dailyCaseCounts) && length(flipArray) == length(opMetrics.dailyCaseCounts)
                % Calculate actual flip-to-turnover ratios for multi-procedure days only
                multiProcDayFlipRatios = [];
                for d = 1:length(opMetrics.dailyCaseCounts)
                    if opMetrics.dailyCaseCounts(d) > 1 && ~isnan(flipArray(d))
                        turnovers = opMetrics.dailyCaseCounts(d) - 1;
                        flipRatio = flipArray(d) / turnovers;
                        multiProcDayFlipRatios(end+1) = flipRatio;
                    end
                end
                validFlipRatios = multiProcDayFlipRatios;
            else
                % Fallback: cannot calculate proper ratios without case counts
                validFlipRatios = [];
            end
            
            if ~isempty(validFlipRatios)
                % Store the daily flip ratio array for further analysis (only multi-procedure days)
                opMetrics.dailyFlipRatios = validFlipRatios * 100; % Convert to percentage
                
                % Calculate comprehensive flip ratio statistics
                opMetrics.medianFlipToTurnoverRatio = median(validFlipRatios) * 100;
                opMetrics.stdFlipToTurnoverRatio = std(validFlipRatios) * 100;
                opMetrics.p25FlipToTurnoverRatio = prctile(validFlipRatios, 25) * 100;
                opMetrics.p75FlipToTurnoverRatio = prctile(validFlipRatios, 75) * 100;
                opMetrics.p90FlipToTurnoverRatio = prctile(validFlipRatios, 90) * 100;
                opMetrics.minFlipToTurnoverRatio = min(validFlipRatios) * 100;
                opMetrics.maxFlipToTurnoverRatio = max(validFlipRatios) * 100;
                
                % Only set if not already calculated from multiProcedureDayAverages
                if isnan(opMetrics.avgFlipToTurnoverRatio)
                    opMetrics.avgFlipToTurnoverRatio = mean(validFlipRatios) * 100;
                end
            else
                opMetrics.dailyFlipRatios = [];
                opMetrics.medianFlipToTurnoverRatio = opMetrics.avgFlipToTurnoverRatio;
                opMetrics.stdFlipToTurnoverRatio = NaN;
                opMetrics.p25FlipToTurnoverRatio = NaN;
                opMetrics.p75FlipToTurnoverRatio = NaN;
                opMetrics.p90FlipToTurnoverRatio = NaN;
                opMetrics.minFlipToTurnoverRatio = NaN;
                opMetrics.maxFlipToTurnoverRatio = NaN;
            end
        else
            opMetrics.dailyFlipRatios = [];
            opMetrics.medianFlipToTurnoverRatio = opMetrics.avgFlipToTurnoverRatio;
            opMetrics.stdFlipToTurnoverRatio = NaN;
            opMetrics.p25FlipToTurnoverRatio = NaN;
            opMetrics.p75FlipToTurnoverRatio = NaN;
            opMetrics.p90FlipToTurnoverRatio = NaN;
            opMetrics.minFlipToTurnoverRatio = NaN;
            opMetrics.maxFlipToTurnoverRatio = NaN;
        end
    else
        opMetrics.avgIdleTimePerDay = NaN;
        opMetrics.medianIdleTimePerDay = NaN;
        opMetrics.stdIdleTimePerDay = NaN;
        opMetrics.p25IdleTimePerDay = NaN;
        opMetrics.p75IdleTimePerDay = NaN;
        opMetrics.p90IdleTimePerDay = NaN;
        opMetrics.minIdleTimePerDay = NaN;
        opMetrics.maxIdleTimePerDay = NaN;
        opMetrics.dailyIdleTimes = [];
        
        opMetrics.avgFlipToTurnoverRatio = NaN;
        opMetrics.medianFlipToTurnoverRatio = NaN;
        opMetrics.stdFlipToTurnoverRatio = NaN;
        opMetrics.p25FlipToTurnoverRatio = NaN;
        opMetrics.p75FlipToTurnoverRatio = NaN;
        opMetrics.p90FlipToTurnoverRatio = NaN;
        opMetrics.minFlipToTurnoverRatio = NaN;
        opMetrics.maxFlipToTurnoverRatio = NaN;
        opMetrics.dailyFlipRatios = [];
    end
    
    %% CALCULATED EFFICIENCY METRICS
    % Cases per hour (assuming 8-hour work day)
    if opMetrics.avgCasesPerDay > 0
        opMetrics.avgCasesPerHour = opMetrics.avgCasesPerDay / 8;
    else
        opMetrics.avgCasesPerHour = 0;
    end
    
    % Utilization rate estimate
    totalMinutesPerDay = 8 * 60; % 480 minutes
    if ~isnan(opMetrics.avgIdleTimePerDay) && opMetrics.avgIdleTimePerDay >= 0
        opMetrics.utilizationRate = (totalMinutesPerDay - opMetrics.avgIdleTimePerDay) / totalMinutesPerDay;
        opMetrics.utilizationRate = max(0, min(1, opMetrics.utilizationRate)); % Clamp between 0 and 1
    else
        opMetrics.utilizationRate = NaN;
    end
    
    % Work time estimates
    if ~isnan(opMetrics.avgIdleTimePerDay)
        opMetrics.avgWorkTimePerDay = totalMinutesPerDay - opMetrics.avgIdleTimePerDay;
        opMetrics.medianWorkTimePerDay = opMetrics.avgWorkTimePerDay; % Estimate
    else
        opMetrics.avgWorkTimePerDay = NaN;
        opMetrics.medianWorkTimePerDay = NaN;
    end
    
    % Calculate idle time per turnover metrics (key efficiency metric)
    if opMetrics.multiProcedureDays > 0 && ~isnan(opMetrics.avgIdleTimePerDay) && ~isnan(opMetrics.medianIdleTimePerDay)
        % Calculate average turnovers per multi-procedure day
        avgCasesPerMultiProcDay = 0;
        if length(dailyCaseCounts) > 0
            multiProcDayCounts = dailyCaseCounts(dailyCaseCounts > 1);
            if ~isempty(multiProcDayCounts)
                avgCasesPerMultiProcDay = mean(multiProcDayCounts);
            end
        end
        
        if avgCasesPerMultiProcDay > 1
            % Initialize with NaN - will be properly calculated from daily data if available
            opMetrics.avgIdleTimePerTurnover = NaN;
            opMetrics.medianIdleTimePerTurnover = NaN;
            
            % Calculate comprehensive idle time per turnover statistics if daily data is available
            if ~isempty(opMetrics.dailyIdleTimes) && length(opMetrics.dailyIdleTimes) == length(dailyCaseCounts)
                % Calculate daily idle time per turnover for multi-procedure days
                dailyIdlePerTurnover = [];
                for d = 1:length(dailyCaseCounts)
                    if dailyCaseCounts(d) > 1 && ~isnan(opMetrics.dailyIdleTimes(d))
                        turnovers = dailyCaseCounts(d) - 1;
                        if turnovers > 0
                            dailyIdlePerTurnover(end+1) = opMetrics.dailyIdleTimes(d) / turnovers;
                        end
                    end
                end
                
                if ~isempty(dailyIdlePerTurnover)
                    opMetrics.dailyIdleTimePerTurnover = dailyIdlePerTurnover;
                    opMetrics.stdIdleTimePerTurnover = std(dailyIdlePerTurnover);
                    opMetrics.p25IdleTimePerTurnover = prctile(dailyIdlePerTurnover, 25);
                    opMetrics.p75IdleTimePerTurnover = prctile(dailyIdlePerTurnover, 75);
                    opMetrics.p90IdleTimePerTurnover = prctile(dailyIdlePerTurnover, 90);
                    opMetrics.minIdleTimePerTurnover = min(dailyIdlePerTurnover);
                    opMetrics.maxIdleTimePerTurnover = max(dailyIdlePerTurnover);
                    
                    % Recalculate means from daily data for accuracy
                    opMetrics.avgIdleTimePerTurnover = mean(dailyIdlePerTurnover);
                    opMetrics.medianIdleTimePerTurnover = median(dailyIdlePerTurnover);
                else
                    opMetrics.dailyIdleTimePerTurnover = [];
                    opMetrics.stdIdleTimePerTurnover = NaN;
                    opMetrics.p25IdleTimePerTurnover = NaN;
                    opMetrics.p75IdleTimePerTurnover = NaN;
                    opMetrics.p90IdleTimePerTurnover = NaN;
                    opMetrics.minIdleTimePerTurnover = NaN;
                    opMetrics.maxIdleTimePerTurnover = NaN;
                end
            else
                opMetrics.dailyIdleTimePerTurnover = [];
                opMetrics.stdIdleTimePerTurnover = NaN;
                opMetrics.p25IdleTimePerTurnover = NaN;
                opMetrics.p75IdleTimePerTurnover = NaN;
                opMetrics.p90IdleTimePerTurnover = NaN;
                opMetrics.minIdleTimePerTurnover = NaN;
                opMetrics.maxIdleTimePerTurnover = NaN;
            end
        else
            opMetrics.avgIdleTimePerTurnover = NaN;
            opMetrics.medianIdleTimePerTurnover = NaN;
            opMetrics.dailyIdleTimePerTurnover = [];
            opMetrics.stdIdleTimePerTurnover = NaN;
            opMetrics.p25IdleTimePerTurnover = NaN;
            opMetrics.p75IdleTimePerTurnover = NaN;
            opMetrics.p90IdleTimePerTurnover = NaN;
            opMetrics.minIdleTimePerTurnover = NaN;
            opMetrics.maxIdleTimePerTurnover = NaN;
        end
    else
        opMetrics.avgIdleTimePerTurnover = NaN;
        opMetrics.medianIdleTimePerTurnover = NaN;
        opMetrics.dailyIdleTimePerTurnover = [];
        opMetrics.stdIdleTimePerTurnover = NaN;
        opMetrics.p25IdleTimePerTurnover = NaN;
        opMetrics.p75IdleTimePerTurnover = NaN;
        opMetrics.p90IdleTimePerTurnover = NaN;
        opMetrics.minIdleTimePerTurnover = NaN;
        opMetrics.maxIdleTimePerTurnover = NaN;
    end
    
    % Set other metrics to defaults (not available from current data)
    opMetrics.avgOvertimePerDay = 0; % Would need schedule times to calculate
    opMetrics.medianOvertimePerDay = 0;
    opMetrics.stdOvertimePerDay = 0;
    opMetrics.daysWithOvertime = 0;
    opMetrics.daysWithOvertimePct = 0;
    
    % Store the operator metrics
    comprehensiveMetrics.(safeOpName) = opMetrics;
end

function operatorGroupMap = getOperatorGroupMap()
% Returns a containers.Map mapping operator names to group labels.
% Edit this mapping to reflect your institution's operator groupings.
% Example:
%   map('Doe, John MD') = 'EP Faculty';
%   map('Smith, Jane MD') = 'Anesthesiology';
%   map('Fellow, Alex MD') = 'EP Fellows';

operatorGroupMap = containers.Map();

% TODO: Populate with your actual operator-to-group assignments.
% operatorGroupMap('Operator Name 1') = 'Group A';
% operatorGroupMap('Operator Name 2') = 'Group B';
% operatorGroupMap('Operator Name 3') = 'Group A';

operatorGroupMap('GAETA, STEPHEN A') = 'IMG';
operatorGroupMap('HELD, ELIZABETH') = 'IMG';
operatorGroupMap('KUMAR, VINEET') = 'IMG';
operatorGroupMap('ATWATER, BRETT D') = 'IMG';
operatorGroupMap('YANG, EUNICE') = 'IMG';
operatorGroupMap('HOLLIS, ZACHARY T') = 'IMG';
operatorGroupMap('WISH, MARC') = 'IMG';
operatorGroupMap('ILKHANOFF, LEONARD') = 'IMG';

operatorGroupMap('RASHID, HAROON') = 'VH';
operatorGroupMap('FEIN, ADAM S') = 'VH';
operatorGroupMap('MCSWAIN, ROBERT L') = 'VH';
operatorGroupMap('LEE, JAE I') = 'VH';
operatorGroupMap('SANDESARA, CHIRAG M') = 'VH';
operatorGroupMap('DUC, JAMES') = 'VH';

operatorGroupMap('ARSHAD, AYSHA') = 'Carient';
operatorGroupMap('LEE, JOSEPH C') = 'Carient';

operatorGroupMap('COHEN, MITCHELL I') = 'Peds';
operatorGroupMap('PRZYBYLSKI, ROBERT G') = 'Peds';

operatorGroupMap('MONIREDDIN GHAZVINI, MOHAMMAD') = 'Community EP';
operatorGroupMap('KABADI, RAJIV A') = 'Medstar';
operatorGroupMap('STROUSE, DAVID A') = 'Medstar';

end

if showStats
    fprintf('  Comprehensive metrics created for %d operators\n', length(fieldnames(comprehensiveMetrics)));
    fprintf('  Each operator has detailed procedure-specific metrics and case mix analysis\n');
end

end

function operatorSummary = calculateOperatorEfficiencySummary(~, ~, ~, comprehensiveOperatorMetrics)
    % Calculate summary efficiency statistics across all operators using comprehensive metrics
    
    operatorNames = fieldnames(comprehensiveOperatorMetrics);
    
    % Collect metrics from comprehensive operator metrics
    allIdleToTurnoverRatios = [];
    
    for i = 1:length(operatorNames)
        safeOpName = operatorNames{i};
        compMetrics = comprehensiveOperatorMetrics.(safeOpName);
        
        % Idle to turnover ratios (same as working plotAnalysisResults)
        if isfield(compMetrics, 'medianIdleTimePerTurnover') && ~isnan(compMetrics.medianIdleTimePerTurnover)
            allIdleToTurnoverRatios = [allIdleToTurnoverRatios, compMetrics.medianIdleTimePerTurnover];
        end
    end
    
    % Calculate summary statistics
    operatorSummary = struct();
    
    % Idle time to turnover ratio statistics (minutes per turnover)
    if ~isempty(allIdleToTurnoverRatios)
        operatorSummary.idleToTurnoverRatio.mean = mean(allIdleToTurnoverRatios);
        operatorSummary.idleToTurnoverRatio.median = median(allIdleToTurnoverRatios);
        operatorSummary.idleToTurnoverRatio.std = std(allIdleToTurnoverRatios);
        operatorSummary.idleToTurnoverRatio.range = [min(allIdleToTurnoverRatios), max(allIdleToTurnoverRatios)];
        operatorSummary.idleToTurnoverRatio.count = length(allIdleToTurnoverRatios);
    else
        operatorSummary.idleToTurnoverRatio = struct('mean', NaN, 'median', NaN, 'std', NaN, 'range', [NaN, NaN], 'count', 0);
    end
    
    % Idle to turnover ratio statistics
    if ~isempty(allIdleToTurnoverRatios)
        operatorSummary.idleToTurnoverRatio.mean = mean(allIdleToTurnoverRatios);
        operatorSummary.idleToTurnoverRatio.median = median(allIdleToTurnoverRatios);
        operatorSummary.idleToTurnoverRatio.std = std(allIdleToTurnoverRatios);
        operatorSummary.idleToTurnoverRatio.range = [min(allIdleToTurnoverRatios), max(allIdleToTurnoverRatios)];
    else
        operatorSummary.idleToTurnoverRatio = struct('mean', NaN, 'median', NaN, 'std', NaN, 'range', [NaN, NaN]);
    end
    
    operatorSummary.totalOperators = length(operatorNames);
    operatorSummary.totalObservations = length(allIdleToTurnoverRatios);
end

function labSummary = calculateLabEfficiencySummary(allLabUtilizations, allMakespans, scheduleKeys, historicalSchedules)
    % Calculate lab efficiency summary statistics
    
    % Collect procedures per hour across all dates and labs
    allProceduresPerHour = [];
    totalProcedures = 0;
    totalLabHours = 0;
    
    for i = 1:length(scheduleKeys)
        dateStr = scheduleKeys{i};
        if isKey(historicalSchedules, dateStr)
            scheduleData = historicalSchedules(dateStr);
            schedule = scheduleData.schedule;
            results = scheduleData.results;
            
            % Count procedures across all labs for this date
            dayProcedures = 0;
            if isfield(schedule, 'labs') && ~isempty(schedule.labs)
                for labIdx = 1:length(schedule.labs)
                    if ~isempty(schedule.labs{labIdx})
                        dayProcedures = dayProcedures + length(schedule.labs{labIdx});
                    end
                end
            end
            
            % Calculate procedures per hour for this date
            if isfield(results, 'makespan') && results.makespan > 0
                dayProceduresPerHour = dayProcedures / (results.makespan / 60);
                allProceduresPerHour = [allProceduresPerHour, dayProceduresPerHour];
                
                totalProcedures = totalProcedures + dayProcedures;
                totalLabHours = totalLabHours + (results.makespan / 60);
            end
        end
    end
    
    % Calculate summary statistics
    labSummary = struct();
    
    % Lab utilization statistics (already calculated)
    labSummary.utilization.mean = mean(allLabUtilizations);
    labSummary.utilization.median = median(allLabUtilizations);
    labSummary.utilization.std = std(allLabUtilizations);
    labSummary.utilization.range = [min(allLabUtilizations), max(allLabUtilizations)];
    
    % Procedures per hour statistics
    if ~isempty(allProceduresPerHour)
        labSummary.proceduresPerHour.mean = mean(allProceduresPerHour);
        labSummary.proceduresPerHour.median = median(allProceduresPerHour);
        labSummary.proceduresPerHour.std = std(allProceduresPerHour);
        labSummary.proceduresPerHour.range = [min(allProceduresPerHour), max(allProceduresPerHour)];
        labSummary.proceduresPerHour.overall = totalProcedures / totalLabHours;
    else
        labSummary.proceduresPerHour = struct('mean', NaN, 'median', NaN, 'std', NaN, 'range', [NaN, NaN], 'overall', NaN);
    end
    
    % Makespan statistics (already calculated)
    labSummary.makespan.mean = mean(allMakespans);
    labSummary.makespan.median = median(allMakespans);
    labSummary.makespan.std = std(allMakespans);
    labSummary.makespan.range = [min(allMakespans), max(allMakespans)];
    
    labSummary.totalDates = length(scheduleKeys);
    labSummary.totalProcedures = totalProcedures;
    labSummary.totalLabHours = totalLabHours;
end
