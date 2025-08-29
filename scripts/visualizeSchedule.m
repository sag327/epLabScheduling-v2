function visualizeSchedule(schedule, varargin)
% Create a Gantt chart visualization of the optimized EP lab schedule
% Version: 2.1.0
%
% Inputs:
%   schedule - Schedule structure from scheduleHistoricalCases()
%   results - Results structure from scheduleHistoricalCases()
%   
% Optional Parameters (Name-Value pairs):
%   'Title' - Chart title (default: 'Optimized EP Lab Schedule')
%   'ShowLabels' - Show case ID labels on bars (default: true)
%   'TimeRange' - [startTime, endTime] in minutes since midnight (default: auto)
%   'FontSize' - Font size for labels (default: 8)
%   'FigureSize' - [width, height] in pixels (default: [1200, 800])
%   'ShowTurnover' - Show turnover time as separate segments (default: false)
%   'Debug' - Show debug output (default: false)
%
% Example:
%   cases = getCasesByDate('05-01-2025');
%   [schedule, results] = scheduleHistoricalCases(cases);
%   visualizeOptimizedSchedule(schedule, results, 'Title', 'May 1st Optimized Schedule');

% Parse input parameters
p = inputParser;
addRequired(p, 'schedule', @isstruct);
addOptional(p,'results',@isstruct);
%addRequired(p, 'results', @isstruct);
addParameter(p, 'Title', 'EP Lab Schedule', @ischar);
addParameter(p, 'ShowLabels', true, @islogical);
addParameter(p, 'TimeRange', [], @(x) isempty(x) || (isnumeric(x) && length(x) == 2));
addParameter(p, 'FontSize', 8, @(x) isnumeric(x) && x > 0);
addParameter(p, 'FigureSize', [1200, 800], @(x) isnumeric(x) && length(x) == 2);
addParameter(p, 'ShowTurnover', false, @islogical);
addParameter(p, 'Debug', false, @islogical);

%parse(p, schedule, results, varargin{:});
parse(p, schedule, varargin{:});

% if historicalSchedule object is passed, separate into schedule and
% results 
if ~isequal(exist('results'),1)
    if isfield(schedule,'results')
        results = schedule.results;
        schedule = schedule.schedule;
    else
        fprintf('Valid input data not provided.')
        return;
    end
end

% Extract parameters
chartTitle = p.Results.Title;
showLabels = p.Results.ShowLabels;
timeRange = p.Results.TimeRange;
fontSize = p.Results.FontSize;
figSize = p.Results.FigureSize;
showTurnover = p.Results.ShowTurnover;
debugMode = p.Results.Debug;

% Validate input
if isempty(schedule.labs) || all(cellfun(@isempty, schedule.labs))
    fprintf('No schedule data to visualize.\n');
    return;
end

% Extract data from schedule structure
allCases = [];
numLabs = length(schedule.labs);

% Collect all cases from all labs
for j = 1:numLabs
    if ~isempty(schedule.labs{j})
        labCases = schedule.labs{j};
        for k = 1:length(labCases)
            caseInfo = labCases(k);
            caseInfo.lab = j;  % Add lab number
            allCases = [allCases; caseInfo];
        end
    end
end

if isempty(allCases)
    fprintf('No cases found in schedule.\n');
    return;
end

% Get unique operators
operatorNames = {allCases.operator};
uniqueOperators = unique(operatorNames);
numOperators = length(uniqueOperators);

% Create color map for operators
colors = lines(numOperators);
operatorColorMap = containers.Map();
for i = 1:numOperators
    operatorColorMap(uniqueOperators{i}) = colors(i,:);
end

% Set up time range (convert to hours for plotting)
if isempty(timeRange)
    allStartTimes = [allCases.startTime];
    allEndTimes = [allCases.endTime];
    scheduleStart = min(allStartTimes);
    scheduleEnd = max(allEndTimes);
    
    % Convert to hours and add buffer
    scheduleStartHour = (scheduleStart - 60) / 60;  % 1 hour before
    scheduleEndHour = (scheduleEnd + 60) / 60;      % 1 hour after
else
    scheduleStartHour = timeRange(1) / 60;
    scheduleEndHour = timeRange(2) / 60;
end

% Create figure with subplots
fig = figure('Name', 'EP Lab Schedule Visualization', ...
    'Position', [100, 100, figSize(1), figSize(2)], ...
    'Color', 'white');

% Main Gantt chart (top 2/3)
ax1 = subplot(3, 1, [1 2], 'Parent', fig, 'Color', 'white');
hold(ax1, 'on');

% Operator timeline (bottom 1/3)
ax2 = subplot(3, 1, 3, 'Parent', fig, 'Color', 'white');
hold(ax2, 'on');

if debugMode
    fprintf('Creating Gantt chart for %d cases across %d labs...\n', length(allCases), numLabs);
end

% Set up axes limits and time labels first
set(ax1, 'YDir', 'reverse'); % Earliest time at top
ylim(ax1, [scheduleStartHour, scheduleEndHour]);
xlim(ax1, [0.5, numLabs + 0.5]);

% Create time labels (every hour)
timeStart_hour = floor(scheduleStartHour);
timeEnd_hour = ceil(scheduleEndHour);
hourTicks = timeStart_hour:1:timeEnd_hour;

% Add grid lines BEFORE drawing rectangles so they appear behind
xlimits = xlim(ax1);
for h = hourTicks
    line(ax1, xlimits, [h, h], 'Color', [0.8, 0.8, 0.8], 'LineStyle', '-', ...
        'LineWidth', 0.5, 'HandleVisibility', 'off');
end

% Define colors
grayColor = [0.7, 0.7, 0.7];           % Setup/post time
turnoverColor = [0.9, 0.9, 0.5];       % Turnover time
idleColor = [0.95, 0.95, 0.95];        % Lab idle time

% Draw schedule bars for each case
for i = 1:length(allCases)
    caseItem = allCases(i);
    lab = caseItem.lab;
    
    % Convert times to hours for plotting
    setupStart_hour = caseItem.startTime / 60;
    procStart_hour = caseItem.procStartTime / 60;
    procEnd_hour = caseItem.procEndTime / 60;
    
    % Calculate end times
    postEnd_hour = (caseItem.procEndTime + caseItem.postTime) / 60;
    if isfield(caseItem, 'turnoverTime') && showTurnover
        turnoverEnd_hour = (caseItem.procEndTime + caseItem.postTime + caseItem.turnoverTime) / 60;
    else
        turnoverEnd_hour = postEnd_hour;
    end
    
    % Get operator color
    operatorColor = operatorColorMap(caseItem.operator);
    
    % Bar parameters
    barWidth = 0.8;
    xPos = lab;
    
    % Draw setup time (gray)
    setupDuration = procStart_hour - setupStart_hour;
    if setupDuration > 0
        rectangle(ax1, 'Position', [xPos - barWidth/2, setupStart_hour, barWidth, setupDuration], ...
            'FaceColor', grayColor, 'EdgeColor', 'black', 'LineWidth', 0.5);
    end
    
    % Draw procedure time (operator color)
    procDuration = procEnd_hour - procStart_hour;
    rectangle(ax1, 'Position', [xPos - barWidth/2, procStart_hour, barWidth, procDuration], ...
        'FaceColor', operatorColor, 'EdgeColor', 'black', 'LineWidth', 1);
    
    % Draw post-procedure time (gray)
    postDuration = postEnd_hour - procEnd_hour;
    if postDuration > 0
        rectangle(ax1, 'Position', [xPos - barWidth/2, procEnd_hour, barWidth, postDuration], ...
            'FaceColor', grayColor, 'EdgeColor', 'black', 'LineWidth', 0.5);
    end
    
    % Draw turnover time (yellow) if enabled and exists
    if showTurnover && isfield(caseItem, 'turnoverTime') && caseItem.turnoverTime > 0
        turnoverDuration = turnoverEnd_hour - postEnd_hour;
        if turnoverDuration > 0
            rectangle(ax1, 'Position', [xPos - barWidth/2, postEnd_hour, barWidth, turnoverDuration], ...
                'FaceColor', turnoverColor, 'EdgeColor', 'black', 'LineWidth', 0.5);
        end
    end
    
    % Add case label if requested
    if showLabels
        % Place label in the middle of the procedure time
        labelY = procStart_hour + procDuration/2;
        labelX = xPos;
        
        % Extract last name from operator (handle various name formats)
        operatorName = caseItem.operator;
        
        % Handle formats like "LAST, FIRST" or "FIRST LAST" or "FIRST MIDDLE LAST"
        if contains(operatorName, ',')
            % Format: "LAST, FIRST" - take everything before comma
            nameParts = strsplit(operatorName, ',');
            lastNamePart = strtrim(nameParts{1});
            % Handle multiple last names like "SMITH JONES"
            lastNameWords = strsplit(lastNamePart, ' ');
            if length(lastNameWords) > 1
                lastName = lastNameWords{end}; % Take the last word
            else
                lastName = lastNamePart;
            end
        else
            % Format: "FIRST LAST" or "FIRST MIDDLE LAST"
            nameParts = strsplit(operatorName, ' ');
            if length(nameParts) > 1
                lastName = nameParts{end}; % Take the last word
            else
                lastName = operatorName; % Single name
            end
        end
        
        % Create label text with case ID and last name
        labelText = sprintf('%s\n%s', caseItem.caseID, lastName);
        
        text(ax1, labelX, labelY, labelText, ...
            'HorizontalAlignment', 'center', ...
            'VerticalAlignment', 'middle', ...
            'FontSize', fontSize, ...
            'FontWeight', 'bold', ...
            'Color', 'white', ...
            'BackgroundColor', 'none');
    end
end

% Finish formatting main axes with labels
hourLabels = cell(length(hourTicks), 1);
for i = 1:length(hourTicks)
    hour = hourTicks(i);
    displayHour = mod(hour, 24);
    if hour >= 24
        hourLabels{i} = sprintf('%02d:00 (+1)', displayHour);
    else
        hourLabels{i} = sprintf('%02d:00', displayHour);
    end
end

yticks(ax1, hourTicks);
yticklabels(ax1, hourLabels);
ax1.XAxis.Color = 'black';
ax1.YAxis.Color = 'black';

% Lab labels
xticks(ax1, 1:numLabs);
labLabels = cell(numLabs, 1);
for i = 1:numLabs
    labLabels{i} = sprintf('Lab %d', i);
end
xticklabels(ax1, labLabels);

% Extract date from cases and add to title
scheduleDate = '';
if ~isempty(allCases) && isfield(allCases(1), 'date') && ~isempty(allCases(1).date)
    % Get date from first case (all cases should be from same date)
    dateStr = allCases(1).date;
    try
        % Parse and format the date nicely
        if ischar(dateStr) || isstring(dateStr)
            dt = datetime(dateStr, 'InputFormat', 'dd-MMM-yyyy');
            scheduleDate = sprintf(' - %s', datestr(dt, 'mmm dd, yyyy'));
        end
    catch
        % If date parsing fails, use the raw date string
        scheduleDate = sprintf(' - %s', char(dateStr));
    end
end

% Add title with date and formatting
titleWithDate = sprintf('%s%s', chartTitle, scheduleDate);
title(ax1, titleWithDate, 'FontSize', 16, 'FontWeight', 'bold', 'Color', 'black');
xlabel(ax1, '');  % No x-label for main chart
ylabel(ax1, 'Time of Day', 'Color', 'black');

% Add summary statistics
summaryText = sprintf('Cases: %d | Labs: %d | Operators: %d | Makespan: %.1f hrs', ...
    length(allCases), numLabs, numOperators, results.makespan/60);

% Add 6 PM line if relevant
sixPM_hour = 18.0;
if sixPM_hour >= scheduleStartHour && sixPM_hour <= scheduleEndHour
    line(ax1, xlimits, [sixPM_hour, sixPM_hour], 'Color', 'red', 'LineStyle', '--', ...
        'LineWidth', 2, 'DisplayName', '6 PM Cutoff');
    text(ax1, max(xlimits) - 0.1, sixPM_hour + 0.1, '6 PM', ...
        'HorizontalAlignment', 'right', 'VerticalAlignment', 'bottom', ...
        'FontSize', 10, 'FontWeight', 'bold', 'Color', 'red');
end

% Add summary text
text(ax1, max(xlimits) - 0.1, max(ylim(ax1)) - 0.2, summaryText, ...
    'HorizontalAlignment', 'right', 'VerticalAlignment', 'bottom', ...
    'FontSize', 10, 'Color', [0.4, 0.4, 0.4], ...
    'BackgroundColor', [1, 1, 1, 0.8]);

hold(ax1, 'off');

%% ===== OPERATOR TIMELINE SUBPLOT =====

% Calculate operator schedules
operatorData = calculateOptimizedOperatorTimelines(schedule, uniqueOperators, scheduleStartHour, scheduleEndHour, debugMode);

% Plot operator timelines
plotOptimizedOperatorTimelines(ax2, operatorData, operatorColorMap, scheduleStartHour, scheduleEndHour, fontSize, debugMode);

hold(ax2, 'off');

% Display summary statistics
fprintf('\nOptimized Schedule Visualization Summary:\n');
fprintf('  Total cases plotted: %d\n', length(allCases));
fprintf('  Labs used: %d\n', numLabs);
fprintf('  Operators: %d (%s)\n', numOperators, strjoin(uniqueOperators, ', '));
fprintf('  Makespan: %.1f hours\n', results.makespan/60);
fprintf('  Mean lab utilization: %.1f%%\n', results.meanLabUtilization*100);
fprintf('  Total operator idle time: %.1f hours\n', results.totalOperatorIdleTime/60);
fprintf('  Total operator overtime: %.1f hours\n', results.totalOperatorOvertime/60);

% Check for overtime cases
overtimeCases = 0;
for i = 1:length(allCases)
    if allCases(i).endTime/60 >= 18 % After 6 PM
        overtimeCases = overtimeCases + 1;
    end
end

if overtimeCases > 0
    fprintf('  WARNING: %d cases extend past 6 PM\n', overtimeCases);
end

fprintf('Optimized schedule visualization created successfully!\n');

end

%% ===== HELPER FUNCTIONS =====

function operatorData = calculateOptimizedOperatorTimelines(schedule, uniqueOperators, scheduleStartHour, scheduleEndHour, debugMode)
% Calculate timeline data for each operator from optimized schedule

operatorData = struct();

for i = 1:length(uniqueOperators)
    op = uniqueOperators{i};
    
    % Create valid field name
    fieldName = matlab.lang.makeValidName(op);
    
    % Get all cases for this operator across all labs
    opCases = [];
    for j = 1:length(schedule.labs)
        if ~isempty(schedule.labs{j})
            labCases = schedule.labs{j};
            for k = 1:length(labCases)
                if strcmp(labCases(k).operator, op)
                    caseInfo = labCases(k);
                    caseInfo.lab = j;
                    opCases = [opCases; caseInfo];
                end
            end
        end
    end
    
    if isempty(opCases)
        continue;
    end
    
    % Sort cases by procedure start time
    [~, sortIdx] = sort([opCases.procStartTime]);
    opCases = opCases(sortIdx);
    
    % Calculate working periods and idle periods (convert to hours)
    workingPeriods = [];
    idlePeriods = [];
    totalIdleTime = 0;
    
    for j = 1:length(opCases)
        procStart_hour = opCases(j).procStartTime / 60;
        procEnd_hour = opCases(j).procEndTime / 60;
        
        workingPeriods(end+1,:) = [procStart_hour, procEnd_hour];
        
        % Calculate idle time between procedure end and next procedure start
        if j > 1
            prevProcEnd_hour = workingPeriods(j-1, 2);
            if procStart_hour > prevProcEnd_hour
                idleTime = procStart_hour - prevProcEnd_hour;
                if idleTime > 0.05 % Only count gaps > 3 minutes
                    idlePeriods(end+1,:) = [prevProcEnd_hour, procStart_hour];
                    totalIdleTime = totalIdleTime + idleTime;
                end
            end
        end
    end
    
    % Calculate summary statistics
    totalWorkTime = sum(workingPeriods(:,2) - workingPeriods(:,1));
    firstCaseStart = min(workingPeriods(:,1));
    lastCaseEnd = max(workingPeriods(:,2));
    totalSpan = lastCaseEnd - firstCaseStart;
    
    % Store operator data
    operatorData.(fieldName) = struct(...
        'originalName', op, ...
        'cases', opCases, ...
        'workingPeriods', workingPeriods, ...
        'idlePeriods', idlePeriods, ...
        'totalIdleTime', totalIdleTime, ...
        'totalWorkTime', totalWorkTime, ...
        'totalSpan', totalSpan, ...
        'firstStart', firstCaseStart, ...
        'lastEnd', lastCaseEnd);
    
    if debugMode
        fprintf('  %s: %.1f hrs work, %.1f hrs idle, %.1f%% utilization\n', ...
            op, totalWorkTime, totalIdleTime, (totalWorkTime/totalSpan)*100);
    end
end

end

function plotOptimizedOperatorTimelines(ax, operatorData, operatorColorMap, scheduleStartHour, scheduleEndHour, fontSize, debugMode)
% Plot operator timeline chart for optimized schedule

fieldNames = fieldnames(operatorData);
if isempty(fieldNames)
    return;
end

numOperators = length(fieldNames);
barHeight = 0.8;
idleColor = [0.9, 0.9, 0.9]; % Light gray for idle time
idleEdgeColor = [0.7, 0.7, 0.7]; % Darker gray edge

% Plot each operator's timeline
for i = 1:numOperators
    fieldName = fieldNames{i};
    opData = operatorData.(fieldName);
    originalName = opData.originalName;
    yPos = i;
    
    % Get operator color
    if isKey(operatorColorMap, originalName)
        opColor = operatorColorMap(originalName);
    else
        opColor = [0.5, 0.5, 0.5]; % Default gray
    end
    
    % Plot working periods (colored bars)
    for j = 1:size(opData.workingPeriods, 1)
        workStart = opData.workingPeriods(j, 1);
        workEnd = opData.workingPeriods(j, 2);
        workDuration = workEnd - workStart;
        
        rectangle('Position', [workStart, yPos - barHeight/2, workDuration, barHeight], ...
            'FaceColor', opColor, 'EdgeColor', 'black', 'LineWidth', 1);
    end
    
    % Plot idle periods (gray bars)
    for j = 1:size(opData.idlePeriods, 1)
        idleStart = opData.idlePeriods(j, 1);
        idleEnd = opData.idlePeriods(j, 2);
        idleDuration = idleEnd - idleStart;
        
        rectangle('Position', [idleStart, yPos - barHeight/2, idleDuration, barHeight], ...
            'FaceColor', idleColor, 'EdgeColor', idleEdgeColor, 'LineWidth', 1, ...
            'LineStyle', '--');
        
        % Add idle time annotation if significant (> 15 minutes)
        if idleDuration > 0.25
            idleMid = idleStart + idleDuration/2;
            idleText = sprintf('%.1fh', idleDuration);
            text(ax, idleMid, yPos, idleText, ...
                'HorizontalAlignment', 'center', ...
                'VerticalAlignment', 'middle', ...
                'FontSize', fontSize-1, ...
                'FontWeight', 'bold', ...
                'Color', [0.4, 0.4, 0.4]);
        end
    end
    
    % Add total idle time annotation at the end
    if opData.totalIdleTime > 0.05
        totalIdleText = sprintf('Total Idle: %.1fh', opData.totalIdleTime);
        text(ax, opData.lastEnd + 0.2, yPos, totalIdleText, ...
            'HorizontalAlignment', 'left', ...
            'VerticalAlignment', 'middle', ...
            'FontSize', fontSize-1, ...
            'FontWeight', 'bold', ...
            'Color', [0.6, 0.3, 0.3], ...
            'BackgroundColor', [1, 1, 0.8]);
    end
end

% Format axes
set(ax, 'YDir', 'normal');
xlim(ax, [scheduleStartHour, scheduleEndHour + 2]); % Extra space for annotations
ylim(ax, [0.5, numOperators + 0.5]);

% Create operator labels (extract last names)
operatorLabels = cell(numOperators, 1);
for i = 1:numOperators
    fieldName = fieldNames{i};
    originalName = operatorData.(fieldName).originalName;
    
    % Extract last name (same logic as top plot)
    if contains(originalName, ',')
        % Format: "LAST, FIRST" - take everything before comma
        nameParts = strsplit(originalName, ',');
        lastNamePart = strtrim(nameParts{1});
        % Handle multiple last names like "SMITH JONES"
        lastNameWords = strsplit(lastNamePart, ' ');
        if length(lastNameWords) > 1
            operatorLabels{i} = lastNameWords{end}; % Take the last word
        else
            operatorLabels{i} = lastNamePart;
        end
    else
        % Format: "FIRST LAST" or "FIRST MIDDLE LAST"
        nameParts = strsplit(originalName, ' ');
        if length(nameParts) > 1
            operatorLabels{i} = nameParts{end}; % Take the last word
        else
            operatorLabels{i} = originalName; % Single name
        end
    end
end

yticks(ax, 1:numOperators);
yticklabels(ax, operatorLabels);

% Time ticks (same as main chart)
timeStart_hour = floor(scheduleStartHour);
timeEnd_hour = ceil(scheduleEndHour);
hourTicks = timeStart_hour:1:timeEnd_hour;
hourLabels = cell(length(hourTicks), 1);
for i = 1:length(hourTicks)
    hour = hourTicks(i);
    displayHour = mod(hour, 24);
    if hour >= 24
        hourLabels{i} = sprintf('%02d:00 (+1)', displayHour);
    else
        hourLabels{i} = sprintf('%02d:00', displayHour);
    end
end

xticks(ax, hourTicks);
xticklabels(ax, hourLabels);

% Labels and formatting
xlabel(ax, 'Time of Day', 'Color', 'black');
title(ax, 'Operator Utilization Timeline', ...
    'FontSize', 14, 'FontWeight', 'bold', 'Color', 'black');

% Add grid and formatting
grid(ax, 'on');
set(ax, 'GridAlpha', 0.3, 'XColor', 'black', 'YColor', 'black', 'Box', 'on', 'LineWidth', 1);
ax.XAxis.Color = 'black';
ax.YAxis.Color = 'black';

% Add 6 PM line if relevant
sixPM_hour = 18.0;
if sixPM_hour >= scheduleStartHour && sixPM_hour <= scheduleEndHour
    line(ax, [sixPM_hour, sixPM_hour], ylim(ax), 'Color', 'red', 'LineStyle', '--', ...
        'LineWidth', 1, 'DisplayName', '6 PM Cutoff');
end

end