function [optimizedSchedule, results, historicalComparison] = rescheduleHistoricalCases(historicalData, varargin)
% Re-schedules historical cases using optimization algorithms
% Takes cleaned historical data and creates optimized schedules
% Compares optimized schedules with original historical performance
%
% Usage:
%   [schedule, results] = rescheduleHistoricalCases(historicalData)
%   [schedule, results, comparison] = rescheduleHistoricalCases(historicalData, 'TargetDate', '05-01-2025')
%   [schedule, results, comparison] = rescheduleHistoricalCases(historicalData, 'NumLabs', 3, 'TurnoverTime', 20)
%
% Parameters:
%   historicalData - Historical data structure from analyzeHistoricalData
%   TargetDate - Specific date to re-schedule (default: all dates)
%   NumLabs - Number of labs to use for optimization (default: auto-detect from historical data)
%   TurnoverTime - Turnover time between cases in minutes (default: 15)
%   LabStartTimes - Cell array of start times for each lab (default: {'8:00', '8:00', ...})
%   OptimizationMethod - 'makespan', 'utilization', or 'balanced' (default: 'balanced')
%   OptimizationMetric - 'operatorIdle', 'labIdle', 'makespan', 'operatorOvertime' (default: 'operatorIdle')
%   CompareWithHistorical - Whether to compare with historical schedules (default: true)
%   ShowProgress - Whether to show progress during optimization (default: true)
%
% Outputs:
%   optimizedSchedule - Optimized schedule structure
%   results - Optimization results and metrics
%   historicalComparison - Comparison between optimized and historical schedules

% Set default parameters
targetDate = '';
numLabs = 0;
turnoverTime = 15;
optimizationMethod = 'balanced';
optimizationMetric = 'operatorIdle';  % Default optimization metric for scheduleHistoricalCases
compareWithHistorical = true;
showProgress = true;
labStartTimes = {};

% Parse optional parameters
i = 1;
while i <= length(varargin)
    if ischar(varargin{i}) || isstring(varargin{i})
        switch lower(char(varargin{i}))
            case 'targetdate'
                targetDate = char(varargin{i+1});
                i = i + 2;
            case 'numlabs'
                numLabs = varargin{i+1};
                i = i + 2;
            case 'turnovertime'
                turnoverTime = varargin{i+1};
                i = i + 2;
            case 'optimizationmethod'
                optimizationMethod = char(varargin{i+1});
                i = i + 2;
            case 'comparewithhistorical'
                compareWithHistorical = varargin{i+1};
                i = i + 2;
            case 'showprogress'
                showProgress = varargin{i+1};
                i = i + 2;
            case 'labstarttimes'
                labStartTimes = varargin{i+1};
                i = i + 2;
            case 'optimizationmetric'
                optimizationMetric = char(varargin{i+1});
                i = i + 2;
            otherwise
                error('Unknown parameter: %s', char(varargin{i}));
        end
    else
        i = i + 1;
    end
end


fprintf('=== HISTORICAL CASE RE-SCHEDULING ===\n');
fprintf('Optimization method: %s\n', optimizationMethod);
fprintf('Turnover time: %d minutes\n', turnoverTime);

% Determine which dates to process
if isempty(targetDate)
    % Process all dates
    uniqueDates = unique(string(historicalData.date));
    uniqueDates = uniqueDates(~ismissing(uniqueDates));
    fprintf('Processing all %d unique dates in dataset\n', length(uniqueDates));
    processAllDates = true;
else
    % Process specific date
    uniqueDates = string(targetDate);
    fprintf('Processing specific date: %s\n', targetDate);
    processAllDates = false;
end

% Auto-detect number of labs if not specified
if numLabs == 0
    if isfield(historicalData, 'room') && ~all(ismissing(historicalData.room))
        uniqueRooms = unique(historicalData.room(~ismissing(historicalData.room)));
        numLabs = length(uniqueRooms);
        fprintf('Auto-detected %d labs from historical room assignments\n', numLabs);
    else
        numLabs = 3; % Default fallback
        fprintf('No room data available, using default %d labs\n', numLabs);
    end
else
    fprintf('Using specified %d labs\n', numLabs);
end

% Initialize results storage
if processAllDates
    optimizedSchedule = containers.Map();
    results = containers.Map();
    if compareWithHistorical
        historicalComparison = containers.Map();
    else
        historicalComparison = [];
    end
else
    optimizedSchedule = [];
    results = [];
    historicalComparison = [];
end

% Process each date
successCount = 0;
errorCount = 0;

if showProgress && processAllDates
    fprintf('\nProgress: [');
    progressLength = 50;
    lastProgress = 0;
end

for i = 1:length(uniqueDates)
    dateStr = char(uniqueDates(i));
    
    try
        % Extract cases for this date
        casesForDate = extractCasesForDate(historicalData, dateStr);
        
        if isempty(casesForDate)
            if showProgress
                fprintf('Skipping %s - no cases found\n', dateStr);
            end
            continue;
        end
        
        if showProgress && ~processAllDates
            fprintf('\nOptimizing schedule for %s (%d cases)...\n', dateStr, length(casesForDate));
        end
        
        % Create optimized schedule for this date
        [daySchedule, dayResults] = optimizeSingleDaySchedule(casesForDate, numLabs, ...
            turnoverTime, optimizationMethod, labStartTimes, optimizationMetric);
        
        % Compare with historical if requested
        dayComparison = [];
        if compareWithHistorical
            dayComparison = compareWithHistoricalSchedule(historicalData, dateStr, ...
                daySchedule, dayResults, turnoverTime);
        end
        
        % Store results
        if processAllDates
            optimizedSchedule(dateStr) = daySchedule;
            results(dateStr) = dayResults;
            if compareWithHistorical
                historicalComparison(dateStr) = dayComparison;
            end
        else
            optimizedSchedule = daySchedule;
            results = dayResults;
            historicalComparison = dayComparison;
        end
        
        successCount = successCount + 1;
        
        if showProgress && ~processAllDates
            displaySingleDateResults(dateStr, dayResults, dayComparison);
        end
        
    catch ME
        if showProgress
            fprintf('Error processing %s: %s\n', dateStr, ME.message);
        end
        errorCount = errorCount + 1;
    end
    
    % Update progress bar for multi-date processing
    if showProgress && processAllDates
        progress = i / length(uniqueDates);
        currentProgress = floor(progress * progressLength);
        
        for j = (lastProgress + 1):currentProgress
            fprintf('=');
        end
        lastProgress = currentProgress;
    end
end

if showProgress && processAllDates
    fprintf('] 100%%\n');
end

% Display summary results
fprintf('\nRe-scheduling complete!\n');
fprintf('  Successfully processed: %d dates\n', successCount);
if errorCount > 0
    fprintf('  Errors: %d dates\n', errorCount);
end

if processAllDates && successCount > 0
    displayAggregateResults(results, historicalComparison, compareWithHistorical);
end

end

%% Helper Functions

function casesForDate = extractCasesForDate(historicalData, targetDate)
% Extract cases for a specific date and convert to scheduling format

% Convert target date to match historical data format
if contains(targetDate, '-') && length(targetDate) == 10
    parts = split(targetDate, '-');
    if length(parts) == 3
        try
            % Convert MM-DD-YYYY to datetime, then to dd-mmm-yyyy format
            month = str2double(parts{1});
            day = str2double(parts{2});
            year = str2double(parts{3});
            dt = datetime(year, month, day);
            targetDateFormatted = string(datestr(dt, 'dd-mmm-yyyy'));
        catch
            error('Invalid date format. Use MM-DD-YYYY (e.g., "05-01-2025")');
        end
    else
        error('Invalid date format. Use MM-DD-YYYY (e.g., "05-01-2025")');
    end
else
    try
        dt = datetime(targetDate);
        targetDateFormatted = string(datestr(dt, 'dd-mmm-yyyy'));
    catch
        error('Invalid date format. Use MM-DD-YYYY (e.g., "05-01-2025")');
    end
end

% Find matching cases
dateMatches = strcmp(string(historicalData.date), targetDateFormatted);
matchingIndices = find(dateMatches);

if isempty(matchingIndices)
    casesForDate = [];
    return;
end

% Convert to format expected by scheduleHistoricalCases
casesForDate = struct();
for i = 1:length(matchingIndices)
    idx = matchingIndices(i);
    
    casesForDate(i).caseID = char(historicalData.caseID(idx));
    casesForDate(i).operator = char(historicalData.surgeon(idx));
    casesForDate(i).procedure = char(historicalData.procedure(idx));
    casesForDate(i).service = char(historicalData.service(idx));
    casesForDate(i).location = char(historicalData.location(idx));
    
    % Use historical times, with fallbacks for missing data
    casesForDate(i).setupTime = ensureValidTime(historicalData.setupTime(idx), 30);
    casesForDate(i).procTime = ensureValidTime(historicalData.procedureTime(idx), 120);
    casesForDate(i).postTime = ensureValidTime(historicalData.postTime(idx), 15);
    
    % Add admission status if available
    if isfield(historicalData, 'admissionStatus') && ~ismissing(historicalData.admissionStatus(idx))
        casesForDate(i).admissionStatus = char(historicalData.admissionStatus(idx));
    else
        casesForDate(i).admissionStatus = 'Unknown';
    end
    
    % Add required priority field (default to empty for normal priority)
    casesForDate(i).priority = [];
    
    % Add preferred lab field (default to empty for no preference)
    casesForDate(i).preferredLab = [];
    
    % Add any other required fields with defaults
    casesForDate(i).estimatedTime = casesForDate(i).setupTime + casesForDate(i).procTime + casesForDate(i).postTime;
end

end

function [schedule, results] = optimizeSingleDaySchedule(cases, numLabs, turnoverTime, method, labStartTimes, optimizationMetric)
% Optimize schedule for a single day using scheduleHistoricalCases

% Create default lab start times if not provided
if isempty(labStartTimes)
    labStartTimes = repmat({'8:00'}, 1, numLabs);
end

% Use the standard scheduleHistoricalCases function with available parameters
[schedule, results] = scheduleHistoricalCases(cases, 'numLabs', numLabs, 'turnoverTime', turnoverTime, 'labStartTimes', labStartTimes, 'optimizationMetric', optimizationMetric);

end

function comparison = compareWithHistoricalSchedule(historicalData, dateStr, optimizedSchedule, optimizedResults, turnoverTime)
% Compare optimized schedule with historical schedule

try
    % Reconstruct historical schedule for comparison
    [historicalSchedule, historicalResults] = reconstructHistoricalSchedule(historicalData, dateStr, ...
        'TurnoverTime', turnoverTime, 'Debug', false);
    
    % Create comparison structure
    comparison = struct();
    comparison.date = dateStr;
    comparison.historical = historicalResults;
    comparison.optimized = optimizedResults;
    
    % Calculate improvements
    if ~isempty(historicalResults) && isfield(historicalResults, 'makespan') && historicalResults.makespan > 0
        comparison.makespanImprovement = (historicalResults.makespan - optimizedResults.makespan) / historicalResults.makespan * 100;
        comparison.utilizationImprovement = (optimizedResults.meanLabUtilization - historicalResults.meanLabUtilization) * 100;
        
        % Compare schedule end times
        comparison.historicalEndTime = historicalResults.scheduleEnd;
        comparison.optimizedEndTime = optimizedResults.scheduleEnd;
        comparison.endTimeImprovement = (historicalResults.scheduleEnd - optimizedResults.scheduleEnd);
        
        comparison.valid = true;
    else
        comparison.valid = false;
    end
    
catch ME
    comparison = struct();
    comparison.date = dateStr;
    comparison.valid = false;
    comparison.error = ME.message;
end

end

function displaySingleDateResults(dateStr, results, comparison)
% Display results for a single date

fprintf('\n--- Results for %s ---\n', dateStr);
fprintf('Optimized Schedule:\n');
fprintf('  Makespan: %.1f hours\n', results.makespan/60);
fprintf('  Lab utilization: %.1f%%\n', results.meanLabUtilization*100);
fprintf('  Schedule end: %s\n', formatTime(results.scheduleEnd));

if ~isempty(comparison) && comparison.valid
    fprintf('\nComparison with Historical:\n');
    fprintf('  Makespan improvement: %.1f%% (%.1f hours saved)\n', ...
        comparison.makespanImprovement, (comparison.historical.makespan - results.makespan)/60);
    fprintf('  Utilization improvement: %.1f percentage points\n', comparison.utilizationImprovement);
    fprintf('  End time improvement: %.1f minutes earlier\n', comparison.endTimeImprovement);
end

end

function displayAggregateResults(results, comparisons, hasComparisons)
% Display aggregate results across all dates

fprintf('\n=== AGGREGATE OPTIMIZATION RESULTS ===\n');

resultValues = values(results);
totalMakespan = 0;
totalUtilization = 0;
validDates = 0;

for i = 1:length(resultValues)
    res = resultValues{i};
    if isfield(res, 'makespan') && isfield(res, 'meanLabUtilization')
        totalMakespan = totalMakespan + res.makespan;
        totalUtilization = totalUtilization + res.meanLabUtilization;
        validDates = validDates + 1;
    end
end

if validDates > 0
    fprintf('Optimization Summary:\n');
    fprintf('  Average makespan: %.1f hours\n', (totalMakespan/60)/validDates);
    fprintf('  Average lab utilization: %.1f%%\n', (totalUtilization/validDates)*100);
    fprintf('  Valid dates processed: %d\n', validDates);
    
    if hasComparisons && ~isempty(comparisons)
        comparisonValues = values(comparisons);
        totalMakespanImprovement = 0;
        totalUtilizationImprovement = 0;
        validComparisons = 0;
        
        for i = 1:length(comparisonValues)
            comp = comparisonValues{i};
            if isfield(comp, 'valid') && comp.valid
                totalMakespanImprovement = totalMakespanImprovement + comp.makespanImprovement;
                totalUtilizationImprovement = totalUtilizationImprovement + comp.utilizationImprovement;
                validComparisons = validComparisons + 1;
            end
        end
        
        if validComparisons > 0
            fprintf('\nHistorical Comparison Summary:\n');
            fprintf('  Average makespan improvement: %.1f%%\n', totalMakespanImprovement/validComparisons);
            fprintf('  Average utilization improvement: %.1f percentage points\n', totalUtilizationImprovement/validComparisons);
            fprintf('  Valid comparisons: %d\n', validComparisons);
        end
    end
end

end

%% Utility Functions

function validTime = ensureValidTime(timeValue, defaultValue)
% Ensure valid time values with defaults for missing data
if isnan(timeValue) || timeValue <= 0
    validTime = defaultValue;
else
    validTime = timeValue;
end
end

function timeStr = formatTime(minutes)
% Format time for display
hours = floor(minutes / 60);
mins = mod(minutes, 60);
timeStr = sprintf('%02d:%02d', hours, mins);
end