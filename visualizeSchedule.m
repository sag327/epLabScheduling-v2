function visualizeSchedule(schedule, varargin)
% Create a Gantt chart visualization of the EP lab schedule
%
% Inputs:
%   schedule - Schedule structure from scheduleEPCases()
%   
% Optional Parameters (Name-Value pairs):
%   'Title' - Chart title (default: 'EP Lab Schedule')
%   'ShowLabels' - Show case ID labels on bars (default: true)
%   'TimeRange' - [startTime, endTime] datetime array (default: auto)
%   'FontSize' - Font size for labels (default: 8)
%   'FigureSize' - [width, height] in pixels (default: [1200, 800])
%   'ShowHistorical' - Show actual historical schedule alongside optimized (default: false)
%   'HistoricalData' - Historical data structure (required if ShowHistorical is true)
%   'Debug' - Show debug output (default: false)
%
% Example:
%   cases = getCasesByDate('05-01-2025');
%   [schedule, metrics] = scheduleEPCases(cases);
%   visualizeSchedule(schedule, 'Title', 'May 1st Schedule');

% Parse input parameters
p = inputParser;
addRequired(p, 'schedule', @isstruct);
addParameter(p, 'Title', 'EP Lab Schedule', @ischar);
addParameter(p, 'ShowLabels', true, @islogical);
addParameter(p, 'TimeRange', [], @(x) isempty(x) || (isdatetime(x) && length(x) == 2));
addParameter(p, 'FontSize', 8, @(x) isnumeric(x) && x > 0);
addParameter(p, 'FigureSize', [1200, 800], @(x) isnumeric(x) && length(x) == 2);
addParameter(p, 'ShowHistorical', false, @islogical);
addParameter(p, 'HistoricalData', struct(), @isstruct);
addParameter(p, 'Debug', false, @islogical);

parse(p, schedule, varargin{:});

% Extract parameters
chartTitle = p.Results.Title;
showLabels = p.Results.ShowLabels;
timeRange = p.Results.TimeRange;
fontSize = p.Results.FontSize;
figSize = p.Results.FigureSize;
showHistorical = p.Results.ShowHistorical;
historicalData = p.Results.HistoricalData;
debugMode = p.Results.Debug;

% Validate input
if isempty(schedule)
    fprintf('No schedule data to visualize.\n');
    return;
end

% Validate historical data if requested
if showHistorical
    if ~isfield(historicalData, 'procedureStartTimeOfDay') || ~isfield(historicalData, 'procedureCompleteTimeOfDay')
        error('HistoricalData must contain procedureStartTimeOfDay and procedureCompleteTimeOfDay fields for historical visualization');
    end
    if debugMode
        fprintf('Historical visualization enabled with %d historical cases\n', length(historicalData.caseID));
    end
end

% Get unique labs and operators
labs = unique([schedule.lab]);
operators = unique({schedule.operator});
numLabs = length(labs);

% Create color map for operators
colors = lines(length(operators));
operatorColorMap = containers.Map();
for i = 1:length(operators)
    operatorColorMap(operators{i}) = colors(i,:);
end

% Set up time range
if isempty(timeRange)
    if ~isempty(schedule)
        allTimes = [schedule.setupStart, schedule.postEnd];
        scheduleStart = min(allTimes);
        scheduleEnd = max(allTimes);
        
        % Start 1 hour before first case, end 1 hour after last case
        timeRange = [scheduleStart - hours(1), scheduleEnd + hours(1)];
    else
        % Default range if no schedule (7 AM to 8 PM)
        baseDate = datetime(2024, 1, 1);
        timeRange = [datetime(baseDate.Year, baseDate.Month, baseDate.Day, 7, 0, 0), ...
                    datetime(baseDate.Year, baseDate.Month, baseDate.Day, 20, 0, 0)];
    end
end

% Create figure with subplots
fig = figure('Name', 'EP Lab Schedule Analysis', ...
    'Position', [100, 100, figSize(1), figSize(2)], ...
    'Color', 'white');

% Determine layout based on whether historical comparison is requested
if showHistorical
    % Side-by-side layout: Historical (left), Optimized (right), Operator timelines (bottom)
    ax_hist = subplot(3, 2, [1 3], 'Parent', fig, 'Color', 'white'); % Historical - left column
    hold(ax_hist, 'on');
    ax_opt = subplot(3, 2, [2 4], 'Parent', fig, 'Color', 'white'); % Optimized - right column
    hold(ax_opt, 'on');
    ax_operators = subplot(3, 2, [5 6], 'Parent', fig, 'Color', 'white'); % Operators - bottom row
    
    % Store both axes
    ax = ax_opt; % Main axis for compatibility
    
    if debugMode
        fprintf('Creating side-by-side historical vs optimized comparison\n');
    end
else
    % Original layout: Lab Gantt chart (top, larger), Operator timelines (bottom, smaller)
    ax1 = subplot(3, 1, [1 2], 'Parent', fig, 'Color', 'white'); % Takes up 2/3 of the space
    hold(ax1, 'on');
    
    % Store the main axes reference for compatibility
    ax = ax1;
    ax_operators = subplot(3, 1, 3, 'Parent', fig, 'Color', 'white'); % Takes up 1/3 of the space
end

fprintf('Creating Gantt chart for %d cases across %d labs...\n', length(schedule), numLabs);

% Draw schedule bars for each case
for i = 1:length(schedule)
    case_item = schedule(i);
    lab = case_item.lab;
    
    % Convert times to numeric values for plotting (hours since midnight)
    setupStart_num = str2double(datestr(case_item.setupStart, 'HH')) + str2double(datestr(case_item.setupStart, 'MM'))/60;
    procStart_num = str2double(datestr(case_item.procStart, 'HH')) + str2double(datestr(case_item.procStart, 'MM'))/60;
    procEnd_num = str2double(datestr(case_item.procEnd, 'HH')) + str2double(datestr(case_item.procEnd, 'MM'))/60;
    postEnd_num = str2double(datestr(case_item.postEnd, 'HH')) + str2double(datestr(case_item.postEnd, 'MM'))/60;
    
    % Get operator color
    operatorColor = operatorColorMap(case_item.operator);
    grayColor = [0.7, 0.7, 0.7];
    
    % Bar parameters
    barWidth = 0.8;
    xPos = lab;
    
    % Draw setup time (gray)
    setupDuration = procStart_num - setupStart_num;
    if setupDuration > 0
        rectangle(ax, 'Position', [xPos - barWidth/2, setupStart_num, barWidth, setupDuration], ...
            'FaceColor', grayColor, 'EdgeColor', 'black', 'LineWidth', 0.5);
    end
    
    % Draw procedure time (operator color)
    procDuration = procEnd_num - procStart_num;
    rectangle(ax, 'Position', [xPos - barWidth/2, procStart_num, barWidth, procDuration], ...
        'FaceColor', operatorColor, 'EdgeColor', 'black', 'LineWidth', 1);
    
    % Draw post-procedure time (gray)
    postDuration = postEnd_num - procEnd_num;
    if postDuration > 0
        rectangle(ax, 'Position', [xPos - barWidth/2, procEnd_num, barWidth, postDuration], ...
            'FaceColor', grayColor, 'EdgeColor', 'black', 'LineWidth', 0.5);
    end
    
    % Add case label if requested
    if showLabels
        % Place label in the middle of the procedure time
        labelY = procStart_num + procDuration/2;
        labelX = xPos;
        
        % Extract last name only from operator name
        % Handle cases like "LAST1 LAST2, FIRST" - use the second last name (LAST2)
        commaParts = strsplit(case_item.operator, ',');
        if length(commaParts) >= 1
            lastNamePart = strtrim(commaParts{1}); % Everything before the comma
            spaceParts = strsplit(lastNamePart, ' ');
            if length(spaceParts) >= 2
                lastName = spaceParts{2}; % Second last name (e.g., GHAZVINI from MONIREDDIN GHAZVINI)
            else
                lastName = spaceParts{1}; % Single last name
            end
        else
            lastName = case_item.operator; % Fallback to full name
        end
        
        % Determine admission status indicator
        admissionIndicator = '';
        if isfield(case_item, 'admissionStatus') && ~isempty(case_item.admissionStatus)
            status = case_item.admissionStatus;
            if strcmpi(status, 'Hospital Outpatient Surgery (Amb Proc)') || strcmpi(status, 'Hospital Outpatient Surgery')
                admissionIndicator = ' (OP)';
            elseif strcmpi(status, 'Inpatient') || strcmpi(status, 'Inpatient Pediatric') || strcmpi(status, 'Observation') || strcmpi(status, 'ip') || strcmpi(status, 'in')
                admissionIndicator = ' (IP)';
            end
        end
        
        % Create label text with admission status indicator
        labelText = sprintf('%s%s\n%s', case_item.caseID, admissionIndicator, lastName);
        
        text(ax, labelX, labelY, labelText, ...
            'HorizontalAlignment', 'center', ...
            'VerticalAlignment', 'middle', ...
            'FontSize', fontSize, ...
            'FontWeight', 'bold', ...
            'Color', 'white', ...
            'BackgroundColor', 'none');
    end
end

% Format axes
set(ax, 'YDir', 'reverse'); % Earliest time at top

% Set time range - convert to hours since midnight
timeStart_num = str2double(datestr(timeRange(1), 'HH')) + str2double(datestr(timeRange(1), 'MM'))/60;
timeEnd_num = str2double(datestr(timeRange(2), 'HH')) + str2double(datestr(timeRange(2), 'MM'))/60;

% Handle cases that go past midnight (add 24 hours)
if timeEnd_num < timeStart_num
    timeEnd_num = timeEnd_num + 24;
end

% Ensure valid range
if timeStart_num >= timeEnd_num
    timeEnd_num = timeStart_num + 1; % At least 1 hour range
end

% Debug output to verify time range
if debugMode
    fprintf('Time range: %.2f to %.2f hours (%.1f hour span)\n', ...
        timeStart_num, timeEnd_num, timeEnd_num - timeStart_num);
    fprintf('Schedule times: %s to %s\n', ...
        datestr(timeRange(1), 'HH:MM'), datestr(timeRange(2), 'HH:MM'));
end

ylim(ax, [timeStart_num, timeEnd_num]);

% Set lab range
xlim(ax, [min(labs) - 0.5, max(labs) + 0.5]);

% Create time labels (every hour from 7 AM)
timeStart_hour = floor(timeStart_num); % Start from actual start time  
timeEnd_hour = ceil(timeEnd_num);

% Generate hourly ticks
hourTicks = timeStart_hour:1:timeEnd_hour;
hourLabels = cell(length(hourTicks), 1);
for i = 1:length(hourTicks)
    hour = hourTicks(i);
    displayHour = mod(hour, 24);
    
    if hour >= 24
        hourLabels{i} = sprintf('%02d:00 (+1)', displayHour); % Next day indicator
    else
        hourLabels{i} = sprintf('%02d:00', displayHour);
    end
end

yticks(ax, hourTicks);
yticklabels(ax, hourLabels);

% Add custom gray horizontal lines at each hour (behind cases)
xlimits = xlim(ax);
gridLines = [];
for h = hourTicks
    gridLine = line(ax, xlimits, [h, h], 'Color', [0.8, 0.8, 0.8], 'LineStyle', '-', ...
        'LineWidth', 0.5, 'HandleVisibility', 'off');
    gridLines(end+1) = gridLine;
end
% Send grid lines to back
for i = 1:length(gridLines)
    uistack(gridLines(i), 'bottom');
end

% Map physical labs to display labels (Lab 1, Lab 2, Lab 10, Lab 11, Lab 14)
labDisplayMap = [1, 2, 10, 11, 14]; % Fixed lab numbers to display
displayLabs = cell(length(labs), 1);
for i = 1:length(labs)
    if i <= length(labDisplayMap)
        displayLabs{i} = sprintf('Lab %d', labDisplayMap(i));
    else
        displayLabs{i} = sprintf('Lab %d', labs(i)); % Fallback for extra labs
    end
end

% Remove x-axis ticks and labels from main chart
xticks(ax, []); % Remove x-axis ticks entirely

% Add lab column headers inside the plot box (near top)
yTop = timeStart_num + 0.5; % Position inside plot, near top
for i = 1:length(labs)
    text(ax, labs(i), yTop, displayLabs{i}, ...
        'HorizontalAlignment', 'center', ...
        'VerticalAlignment', 'middle', ...
        'FontSize', fontSize + 2, ...
        'FontWeight', 'bold', ...
        'Color', 'black', ...
        'BackgroundColor', [1, 1, 1, 0.9]); % White background for visibility
    if debugMode
        fprintf('Added lab header "%s" at position (%d, %.1f)\n', displayLabs{i}, labs(i), yTop);
    end
end

if debugMode
    fprintf('Applied changes:\n');
    fprintf('  - Removed x-axis labels (empty xticklabels)\n');
    fprintf('  - Added lab headers: %s\n', strjoin(displayLabs, ', '));
    fprintf('  - Time range adjusted to: %.2f to %.2f hours\n', timeStart_num, timeEnd_num);
end

% No axis labels

% Grid lines will be added before drawing cases

% Set axis colors and add bounding box (no default grid to avoid conflicts)
set(ax, 'XColor', 'black', 'YColor', 'black', 'Box', 'on', 'LineWidth', 1);

% No legend - removed as requested

% Add summary text
summaryText = sprintf('Cases: %d | Labs: %d | Operators: %d', ...
    length(schedule), numLabs, length(operators));

% Calculate schedule span
scheduleSpan = timeEnd_num - timeStart_num;
if scheduleSpan > 0
    summaryText = [summaryText, sprintf(' | Span: %.1f hrs', scheduleSpan)];
end

% Determine automatic title based on context
if strcmp(chartTitle, 'EP Lab Schedule') % Default title, so auto-determine
    if showHistorical
        autoTitle = 'Historical EP Lab Schedule';
    else
        autoTitle = 'Simulated EP Lab Schedule';
    end
else
    autoTitle = chartTitle; % Use user-provided title
end

% Add title in standard location
title(ax, autoTitle, 'FontSize', 16, 'FontWeight', 'bold', 'Color', 'black');

% Add summary annotation in bottom right corner
xlimits = xlim(ax);
ylimits = ylim(ax);
text(ax, xlimits(2) - 0.1, ylimits(2) - 0.2, summaryText, ...
    'HorizontalAlignment', 'right', 'VerticalAlignment', 'bottom', ...
    'FontSize', 12, 'FontWeight', 'normal', 'Color', [0.4, 0.4, 0.4], ...
    'BackgroundColor', [1, 1, 1, 0.8]); % Semi-transparent white background

% Add 6 PM line if relevant
sixPM_num = 18.0; % 6 PM = 18:00
if sixPM_num >= timeStart_num && sixPM_num <= timeEnd_num
    line(xlim, [sixPM_num, sixPM_num], 'Color', 'red', 'LineStyle', '--', ...
        'LineWidth', 2, 'DisplayName', '6 PM Cutoff');
    
    % Add 6 PM label
    text(max(xlim) - 0.1, sixPM_num + 0.1, '6 PM', ...
        'HorizontalAlignment', 'right', 'VerticalAlignment', 'bottom', ...
        'FontSize', 10, 'FontWeight', 'bold', 'Color', 'red');
end

hold(ax, 'off');

%% ===== OPERATOR TIMELINE SUBPLOT =====

% Create second subplot for operator timelines
ax2 = subplot(3, 1, 3, 'Parent', fig, 'Color', 'white'); % Takes up 1/3 of the space
hold(ax2, 'on');

fprintf('Creating operator timeline chart...\n');

% Calculate operator schedules and idle times
operatorData = calculateOperatorTimelines(schedule, timeRange, debugMode);

% Plot operator timelines
plotOperatorTimelines(ax2, operatorData, operatorColorMap, timeRange, fontSize, debugMode);

hold(ax2, 'off');

% Display summary statistics
fprintf('\nSchedule Visualization Summary:\n');
fprintf('  Total cases plotted: %d\n', length(schedule));
fprintf('  Labs used: %s\n', mat2str(labs));
fprintf('  Operators: %d (%s)\n', length(operators), strjoin(operators, ', '));
fprintf('  Time span: %s to %s\n', ...
    datestr(timeRange(1), 'HH:MM'), datestr(timeRange(2), 'HH:MM'));

% Check for overtime cases
overtimeCases = 0;
for i = 1:length(schedule)
    try
        caseEndTime = schedule(i).postEnd;
        if isdatetime(caseEndTime)
            % Use datestr and str2double as alternative to hour() function
            hourStr = datestr(caseEndTime, 'HH');
            endHour = str2double(hourStr);
            if endHour >= 18 % After 6 PM
                overtimeCases = overtimeCases + 1;
            end
        end
    catch ME
        fprintf('Warning: Could not process end time for case %d: %s\n', i, ME.message);
    end
end

if overtimeCases > 0
    fprintf('  WARNING: %d cases extend past 6 PM\n', overtimeCases);
end

fprintf('Schedule visualization created successfully!\n');

end

%% ===== HELPER FUNCTIONS FOR OPERATOR TIMELINES =====

function operatorData = calculateOperatorTimelines(schedule, timeRange, debugMode)
% Calculate timeline data for each operator including idle times between cases only

if isempty(schedule)
    operatorData = struct();
    return;
end

% Get unique operators
operators = unique({schedule.operator});
operatorData = struct();

for i = 1:length(operators)
    op = operators{i};
    
    % Create valid field name by removing invalid characters
    fieldName = matlab.lang.makeValidName(op);
    
    % Get all cases for this operator
    opCases = schedule(strcmp({schedule.operator}, op));
    
    if isempty(opCases)
        continue;
    end
    
    % Sort cases by start time
    [~, sortIdx] = sort([opCases.setupStart]);
    opCases = opCases(sortIdx);
    
    % Calculate working periods and idle periods
    workingPeriods = [];
    idlePeriods = [];
    totalIdleTime = 0;
    
    dayStart = timeRange(1);
    dayEnd = timeRange(2);
    
    for j = 1:length(opCases)
        % For idle time calculation, only consider procedure time (not setup/post/turnover)
        procStart = opCases(j).procStart;
        procEnd = opCases(j).procEnd;
        
        % Convert to numeric hours for calculations
        procStart_num = str2double(datestr(procStart, 'HH')) + str2double(datestr(procStart, 'MM'))/60;
        procEnd_num = str2double(datestr(procEnd, 'HH')) + str2double(datestr(procEnd, 'MM'))/60;
        
        workingPeriods(end+1,:) = [procStart_num, procEnd_num];
        
        % Calculate idle time between procedure end and next procedure start only
        if j > 1
            % Idle time between procedure end and next procedure start
            prevProcEnd_num = workingPeriods(j-1, 2);
            if procStart_num > prevProcEnd_num
                idleTime = procStart_num - prevProcEnd_num;
                if idleTime > 0.05 % Only count gaps > 3 minutes
                    idlePeriods(end+1,:) = [prevProcEnd_num, procStart_num];
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
    
    % Store operator data using valid field name
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

function plotOperatorTimelines(ax, operatorData, operatorColorMap, timeRange, fontSize, debugMode)
% Plot operator timeline chart with idle time highlighting

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
    originalName = opData.originalName; % Get the original operator name
    yPos = i;
    
    % Get operator color using original name
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
    
    % Plot idle periods (gray bars with pattern)
    for j = 1:size(opData.idlePeriods, 1)
        idleStart = opData.idlePeriods(j, 1);
        idleEnd = opData.idlePeriods(j, 2);
        idleDuration = idleEnd - idleStart;
        
        % Draw idle period as hatched rectangle
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
    
    % Extract last name for consistency (actual labels are set below)
    commaParts = strsplit(originalName, ',');
    if length(commaParts) >= 1
        lastNamePart = strtrim(commaParts{1});
        spaceParts = strsplit(lastNamePart, ' ');
        if length(spaceParts) >= 2
            lastName = spaceParts{2}; % Second last name
        else
            lastName = spaceParts{1}; % Single last name
        end
    else
        lastName = originalName; % Fallback
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
set(ax, 'YDir', 'normal'); % Normal direction (bottom to top)

% Set time range
timeStart_num = str2double(datestr(timeRange(1), 'HH')) + str2double(datestr(timeRange(1), 'MM'))/60;
timeEnd_num = str2double(datestr(timeRange(2), 'HH')) + str2double(datestr(timeRange(2), 'MM'))/60;

% Handle cases that go past midnight
if timeEnd_num < timeStart_num
    timeEnd_num = timeEnd_num + 24;
end

xlim([timeStart_num, timeEnd_num + 2]); % Extra space for annotations
ylim([0.5, numOperators + 0.5]);

% Create operator labels with disambiguation for duplicate last names
operatorLabels = cell(numOperators, 1);

% First pass: extract last names
lastNames = cell(numOperators, 1);
originalNames = cell(numOperators, 1);
for i = 1:numOperators
    fieldName = fieldNames{i};
    originalName = operatorData.(fieldName).originalName;
    originalNames{i} = originalName;
    
    commaParts = strsplit(originalName, ',');
    if length(commaParts) >= 1
        lastNamePart = strtrim(commaParts{1});
        spaceParts = strsplit(lastNamePart, ' ');
        if length(spaceParts) >= 2
            lastNames{i} = spaceParts{2}; % Second last name
        else
            lastNames{i} = spaceParts{1}; % Single last name
        end
    else
        lastNames{i} = originalName; % Fallback
    end
end

% Second pass: add first names/initials for duplicates
for i = 1:numOperators
    lastName = lastNames{i};
    
    % Check if this last name appears multiple times
    duplicateIndices = find(strcmp(lastNames, lastName));
    
    if length(duplicateIndices) > 1
        % Add full first name for disambiguation
        originalName = originalNames{i};
        commaParts = strsplit(originalName, ',');
        if length(commaParts) >= 2
            firstNamePart = strtrim(commaParts{2});
            if ~isempty(firstNamePart)
                operatorLabels{i} = sprintf('%s, %s', lastName, firstNamePart); % Last name + full first name
            else
                operatorLabels{i} = lastName;
            end
        else
            operatorLabels{i} = lastName;
        end
    else
        operatorLabels{i} = lastName; % No duplicates, use last name only
    end
end

yticks(1:numOperators);
yticklabels(operatorLabels);

% Time ticks (same as main chart)
timeStart_hour = floor(timeStart_num);
timeEnd_hour = ceil(timeEnd_num);
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

xticks(hourTicks);
xticklabels(hourLabels);

% Labels and formatting
xlabel('Time of Day');
% ylabel removed as requested
title('Operator Utilization Timeline (Gray = Idle Time)', ...
    'FontSize', 16, 'FontWeight', 'bold', 'Color', 'black');

% Add grid and formatting
grid on;
set(ax, 'GridAlpha', 0.3, 'XColor', 'black', 'YColor', 'black', 'Box', 'on', 'LineWidth', 1);

% Add 6 PM line if relevant
sixPM_num = 18.0;
if sixPM_num >= timeStart_num && sixPM_num <= timeEnd_num
    line([sixPM_num, sixPM_num], ylim, 'Color', 'red', 'LineStyle', '--', ...
        'LineWidth', 1, 'DisplayName', '6 PM Cutoff');
end

end