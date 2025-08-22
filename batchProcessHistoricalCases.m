function batchResults = batchProcessHistoricalCases(varargin)
% Batch process historical EP cases data by running scheduleHistoricalCases for each day
% Version: 2.1.0
%
% Usage:
%   batchResults = batchProcessHistoricalCases()  % Interactive mode - prompts for data source
%   batchResults = batchProcessHistoricalCases('DataSource', 'file')  % Use historicalEPData.mat
%   batchResults = batchProcessHistoricalCases('DataSource', 'variable', 'Data', myData)  % Use provided data
%   batchResults = batchProcessHistoricalCases('SaveFile', 'my_results.mat')  % Custom save file
%
% Optional Parameters (Name-Value pairs):
%   'DataSource' - 'file', 'variable', or 'interactive' (default: 'interactive')
%   'Data' - Historical data structure (required if DataSource is 'variable')
%   'SaveFile' - Output filename (default: 'batch_scheduling_results_YYYYMMDD_HHMMSS.mat')
%   'TurnoverTime' - Room turnover time in minutes (default: 15)
%   'CaseFilter' - 'all', 'outpatient', 'inpatient' (default: 'all')
%   'PrioritizeOutpatient' - Schedule outpatient cases first, then remaining cases (default: false)
%   'Debug' - Show debug output (default: false)
%   'limitDays' - Limit analysis to a specified number of days for testing
%   purposes 
%
% Outputs:
%   batchResults - Structure containing:
%     .dailyResults - Cell array of daily scheduling results
%     .dailySchedules - containers.Map formatted for analyzeHistoricalData.m compatibility
%     .caseData - Historical data structure compatible with analyzeHistoricalData.m
%     .processedDates - Cell array of processed dates
%     .summaryStats - Summary statistics across all days
%     .parameters - Processing parameters used
%     .processingTime - Total processing time
%
% Example:
%   % Process all historical data with 30-minute turnover
%   results = batchProcessHistoricalCases('TurnoverTime', 30);
%
%   % Process with outpatient prioritization
%   results = batchProcessHistoricalCases('PrioritizeOutpatient', true);
%
%   % Process specific dataset
%   load('myData.mat');
%   results = batchProcessHistoricalCases('DataSource', 'variable', 'Data', myData);
%
%   % Use results with analyzeHistoricalData for comprehensive analysis
%   batchResults = batchProcessHistoricalCases();
%   analysisResults = analyzeHistoricalData(batchResults.caseData, ...
%                                          'HistoricalSchedules', batchResults.dailySchedules);

% Parse input parameters
p = inputParser;
addParameter(p, 'DataSource', 'interactive', @(x) ismember(x, {'file', 'variable', 'interactive'}));
addParameter(p, 'Data', struct(), @isstruct);
addParameter(p, 'SaveFile', '', @ischar);
addParameter(p, 'TurnoverTime', 15, @(x) isnumeric(x) && x >= 0);
addParameter(p, 'CaseFilter', 'all', @(x) ismember(x, {'all', 'outpatient', 'inpatient'}));
addParameter(p, 'PrioritizeOutpatient', false, @islogical);
addParameter(p, 'Debug', false, @islogical);
addParameter(p, 'limitDays', -1, @isnumeric);

parse(p, varargin{:});

% Extract parameters
dataSource = p.Results.DataSource;
userData = p.Results.Data;
saveFile = p.Results.SaveFile;
turnoverTime = p.Results.TurnoverTime;
caseFilter = p.Results.CaseFilter;
prioritizeOutpatient = p.Results.PrioritizeOutpatient;
debugMode = p.Results.Debug;
limitDays = p.Results.limitDays;

fprintf('=== EP Lab Batch Scheduling Processor ===\n\n');

% Start timing
startTime = tic;

% Create log file and collect version information
logFile = createLogFile();
logVersionInfo(logFile);
logParameters(logFile, turnoverTime, caseFilter, prioritizeOutpatient, dataSource, debugMode, limitDays);

% Get historical data based on source
switch dataSource
    case 'interactive'
        fprintf('Select data source:\n');
        fprintf('1. Load from historicalEPData.mat file\n');
        fprintf('2. Use data from workspace variable\n');
        choice = input('Enter choice (1 or 2): ');
        
        if choice == 1
            dataSource = 'file';
        elseif choice == 2
            dataSource = 'variable';
            varName = input('Enter variable name: ', 's');
            if evalin('base', sprintf('exist(''%s'', ''var'')', varName))
                userData = evalin('base', varName);
                fprintf('Loaded data from variable: %s\n', varName);
            else
                error('Variable %s not found in workspace', varName);
            end
        else
            error('Invalid choice. Must be 1 or 2.');
        end
        
    case 'variable'
        if isempty(fieldnames(userData))
            error('Data parameter is required when DataSource is ''variable''');
        end
end

% Load data from file if needed
if strcmp(dataSource, 'file')
    fprintf('Loading historical data from file...\n');
    try
        if exist('data/historicalEPData.mat', 'file')
            load('data/historicalEPData.mat', 'cases');
            userData = cases;
            fprintf('Loaded %d cases from data/historicalEPData.mat\n', length(userData));
        elseif exist('historicalEPData.mat', 'file')
            load('historicalEPData.mat', 'cases');
            userData = cases;
            fprintf('Loaded %d cases from historicalEPData.mat\n', length(userData));
        else
            error('Cannot find historicalEPData.mat file');
        end
    catch ME
        error('Failed to load historical data: %s', ME.message);
    end
end

% Validate data structure
if ~isstruct(userData) || isempty(userData)
    error('Historical data must be a non-empty structure array');
end

% Check for required fields and map them if needed
dataFields = fieldnames(userData);

% Define field mappings (expected -> possible alternatives)
fieldMappings = struct();
fieldMappings.caseID = {'caseID', 'caseId', 'case_id', 'id', 'ID'};
fieldMappings.procedureDate = {'procedureDate', 'procedure_date', 'date', 'procDate', 'surgeryDate'};
fieldMappings.operatorName = {'operatorName', 'operator_name', 'surgeon', 'surgeonName', 'physician', 'provider'};
fieldMappings.procedureDuration = {'procedureDuration', 'procedure_duration', 'procedureTime', 'duration', 'procTime', 'time'};

% Find actual field names in the data
actualFields = struct();
mappingUsed = struct();

expectedFields = fieldnames(fieldMappings);
for i = 1:length(expectedFields)
    expectedField = expectedFields{i};
    possibleFields = fieldMappings.(expectedField);
    
    % Find which field exists in the data
    foundField = '';
    for j = 1:length(possibleFields)
        if ismember(possibleFields{j}, dataFields)
            foundField = possibleFields{j};
            break;
        end
    end
    
    if isempty(foundField)
        error('Cannot find required field ''%s''. Tried: %s\nAvailable fields: %s', ...
            expectedField, strjoin(possibleFields, ', '), strjoin(dataFields, ', '));
    end
    
    actualFields.(expectedField) = foundField;
    mappingUsed.(expectedField) = foundField;
end

% Display field mappings
fprintf('Field mappings used:\n');
mappingFields = fieldnames(mappingUsed);
for i = 1:length(mappingFields)
    if ~strcmp(mappingFields{i}, mappingUsed.(mappingFields{i}))
        fprintf('  %s -> %s\n', mappingFields{i}, mappingUsed.(mappingFields{i}));
    end
end

% Standardize field names if needed
if ~isequal(actualFields.caseID, 'caseID') || ...
   ~isequal(actualFields.procedureDate, 'procedureDate') || ...
   ~isequal(actualFields.operatorName, 'operatorName') || ...
   ~isequal(actualFields.procedureDuration, 'procedureDuration')
    
    fprintf('Standardizing field names...\n');
    for i = 1:length(userData)
        % Map fields to standard names
        if ~strcmp(actualFields.caseID, 'caseID')
            userData(i).caseID = userData(i).(actualFields.caseID);
        end
        if ~strcmp(actualFields.procedureDate, 'procedureDate')
            userData(i).procedureDate = userData(i).(actualFields.procedureDate);
        end
        if ~strcmp(actualFields.operatorName, 'operatorName')
            userData(i).operatorName = userData(i).(actualFields.operatorName);
        end
        if ~strcmp(actualFields.procedureDuration, 'procedureDuration')
            userData(i).procedureDuration = userData(i).(actualFields.procedureDuration);
        end
    end
end

% Determine data structure format and actual number of cases
if numel(userData) == 1 && isstruct(userData)
    % Single structure with array fields (e.g., userData.procedureDate is an array)
    fprintf('Detected single structure with array fields\n');
    
    % Determine number of cases from array fields
    fieldNames = fieldnames(userData);
    numCases = 0;
    for f = 1:length(fieldNames)
        fieldData = userData.(fieldNames{f});
        if length(fieldData) > numCases
            numCases = length(fieldData);
        end
    end
    fprintf('Found %d cases in data structure\n', numCases);
    
    if isdatetime(userData.procedureDate)
        allDates = userData.procedureDate;
        uniqueDates = unique(allDates);
    else
        % Handle cell array of dates
        if iscell(userData.procedureDate)
            allDates = userData.procedureDate;
            uniqueDates = unique(allDates);
            if ischar(uniqueDates{1})
                uniqueDates = datetime(uniqueDates, 'InputFormat', 'MM-dd-yyyy');
            end
        else
            % Handle other string formats
            allDates = userData.procedureDate;
            uniqueDates = unique(allDates);
            uniqueDates = datetime(uniqueDates, 'InputFormat', 'MM-dd-yyyy');
        end
    end
    
    % Convert to structure array format for easier processing
    fprintf('Converting to structure array format...\n');
    % Use the number of cases we already detected
    if ~exist('numCases', 'var')
        numCases = length(userData.procedureDate);
    end
    newUserData = struct();
    
    fieldNames = fieldnames(userData);
    for f = 1:length(fieldNames)
        fieldName = fieldNames{f};
        fieldData = userData.(fieldName);
        if length(fieldData) == numCases
            for i = 1:numCases
                if iscell(fieldData)
                    newUserData(i).(fieldName) = fieldData{i};
                else
                    newUserData(i).(fieldName) = fieldData(i);
                end
            end
        else
            % Replicate scalar values
            for i = 1:numCases
                newUserData(i).(fieldName) = fieldData;
            end
        end
    end
    userData = newUserData;
    fprintf('Converted %d cases to structure array\n', numCases);
    
else
    % Structure array format (e.g., userData(i).procedureDate)
    fprintf('Detected structure array format\n');
    numCases = length(userData);
    fprintf('Found %d cases in structure array\n', numCases);
    
    if isdatetime(userData(1).procedureDate)
        allDates = [userData.procedureDate];
        uniqueDates = unique(allDates);
    else
        % Handle string/char dates
        allDates = {userData.procedureDate};
        uniqueDates = unique(allDates);
        if ischar(uniqueDates{1})
            uniqueDates = datetime(uniqueDates, 'InputFormat', 'MM-dd-yyyy');
        end
    end
end

uniqueDates = uniqueDates(:); % Column vector

numDays = length(uniqueDates);

% Display processing parameters
fprintf('\nProcessing %d historical cases...\n', numCases);
fprintf('Parameters:\n');
fprintf('  Turnover time: %d minutes\n', turnoverTime);
fprintf('  Case filter: %s\n', caseFilter);
if debugMode
    fprintf('  Debug mode: enabled\n');
else
    fprintf('  Debug mode: disabled\n');
end
fprintf('\nFound cases across %d unique dates\n', numDays);
fprintf('Date range: %s to %s\n\n', ...
    datestr(min(uniqueDates), 'mm-dd-yyyy'), ...
    datestr(max(uniqueDates), 'mm-dd-yyyy'));

if limitDays ~= -1
    fprintf('Limiting number of days analyzed to %d\n',limitDays)
    numDays = limitDays;
end

% Initialize results storage
dailyResults = cell(numDays, 1);
dailySchedules = cell(numDays, 1);
processedDates = cell(numDays, 1);
processingErrors = cell(numDays, 1);

% Suppress output during processing
if ~debugMode
    originalWarningState = warning('off', 'all');
end

% Process each day
fprintf('Processing daily schedules:\n');
fprintf('[');
progressBarLength = 50;
lastProgressPos = 0;

for i = 1:numDays
    currentDate = uniqueDates(i);
    dateStr = datestr(currentDate, 'mm-dd-yyyy');
    
    try
        % Get cases for this date (userData is now guaranteed to be structure array)
        try
            if isdatetime(userData(1).procedureDate)
                % Handle datetime array
                procedureDates = [userData.procedureDate];
                dayIndices = procedureDates == currentDate;
            else
                % Handle string/char array
                procedureDates = {userData.procedureDate};
                dayIndices = strcmp(procedureDates, dateStr);
            end
            
            dayCases = userData(dayIndices);
            
            % Convert dayCases to the format expected by scheduleHistoricalCases
            dayCases = convertToSchedulerFormat(dayCases);
            
        catch indexError
            if debugMode
                fprintf('Index error for date %s: %s. Using fallback method...\n', dateStr, indexError.message);
            end
            % Fallback: manually find matching cases
            dayCases = [];
            for k = 1:length(userData)
                if isdatetime(userData(k).procedureDate)
                    if userData(k).procedureDate == currentDate
                        dayCases = [dayCases; userData(k)];
                    end
                else
                    if strcmp(userData(k).procedureDate, dateStr)
                        dayCases = [dayCases; userData(k)];
                    end
                end
            end
            
            % Convert dayCases to the format expected by scheduleHistoricalCases
            if ~isempty(dayCases)
                dayCases = convertToSchedulerFormat(dayCases);
            end
        end
        
        if isempty(dayCases)
            if debugMode
                fprintf('No cases found for %s, skipping...\n', dateStr);
            end
            continue;
        end
        
        % Capture output from scheduleHistoricalCases
        if debugMode
            [schedule, results] = scheduleHistoricalCases(dayCases, ...
                'turnoverTime', turnoverTime, ...
                'caseFilter', caseFilter, ...
                'prioritizeOutpatient', prioritizeOutpatient, ...
                'verbose', false); % Suppress even in debug mode for batch
        else
            % Completely suppress output
            evalc('[schedule, results] = scheduleHistoricalCases(dayCases, ''turnoverTime'', turnoverTime, ''caseFilter'', caseFilter, ''prioritizeOutpatient'', prioritizeOutpatient, ''verbose'', false);');
        end
        
        % Store results
        dailyResults{i} = results;
        dailySchedules{i} = schedule;
        processedDates{i} = dateStr;
        
        % Store additional metadata
        dailyResults{i}.dateStr = dateStr;
        dailyResults{i}.numCases = length(dayCases);
        dailyResults{i}.turnoverTime = turnoverTime;
        dailyResults{i}.caseFilter = caseFilter;
        dailyResults{i}.operators = keys(schedule.operators);
        
    catch ME
        if debugMode
            fprintf('Error processing %s: %s\n', dateStr, ME.message);
        end
        processingErrors{i} = ME.message;
        processedDates{i} = dateStr;
    end
    
    % Update progress bar
    progress = i / numDays;
    currentProgressPos = floor(progress * progressBarLength);
    
    % Add new progress characters
    for j = (lastProgressPos + 1):currentProgressPos
        fprintf('=');
    end
    lastProgressPos = currentProgressPos;
end

% Complete progress bar
fprintf('] 100%%\n\n');

% Restore warning state
if ~debugMode
    warning(originalWarningState);
end

% Remove empty cells
validIndices = ~cellfun(@isempty, processedDates);
dailyResults = dailyResults(validIndices);
dailySchedules = dailySchedules(validIndices);
processedDates = processedDates(validIndices);
processingErrors = processingErrors(validIndices);

% Count successful vs failed processing
successfulDays = sum(~cellfun(@isempty, dailyResults));
failedDays = sum(~cellfun(@isempty, processingErrors));

fprintf('Processing complete!\n');
fprintf('Successfully processed: %d days\n', successfulDays);
if failedDays > 0
    fprintf('Failed to process: %d days\n', failedDays);
end

% Calculate summary statistics
fprintf('\nCalculating summary statistics...\n');
summaryStats = calculateSummaryStats(dailyResults, dailySchedules);

% Create final results structure
batchResults = struct();
batchResults.dailyResults = dailyResults;

% Format dailySchedules to match analyzeHistoricalData.m expected format
batchResults.dailySchedules = formatSchedulesForAnalysis(dailySchedules, dailyResults, processedDates);

% Create caseData structure compatible with analyzeHistoricalData.m
batchResults.caseData = createCaseDataStructure(userData);

batchResults.processedDates = processedDates;
batchResults.processingErrors = processingErrors(~cellfun(@isempty, processingErrors));
batchResults.summaryStats = summaryStats;
batchResults.parameters = struct(...
    'turnoverTime', turnoverTime, ...
    'caseFilter', caseFilter, ...
    'prioritizeOutpatient', prioritizeOutpatient, ...
    'dataSource', dataSource, ...
    'debugMode', debugMode, ...
    'totalDaysFound', numDays, ...
    'successfulDays', successfulDays, ...
    'failedDays', failedDays);
batchResults.processingTime = toc(startTime);

% Generate save filename if not provided
if isempty(saveFile)
    timestamp = datestr(now, 'yyyymmdd_HHMMSS');
    saveFile = sprintf('batch_scheduling_results_%s.mat', timestamp);
end

% Save results
fprintf('Saving results to: %s\n', saveFile);
save(saveFile, 'batchResults', '-v7.3');

% Display summary
fprintf('\n=== BATCH PROCESSING SUMMARY ===\n');
fprintf('Total processing time: %.1f seconds\n', batchResults.processingTime);
fprintf('Average time per day: %.2f seconds\n', batchResults.processingTime / successfulDays);
fprintf('\nDaily Statistics (successful days only):\n');
fprintf('  Average cases per day: %.1f\n', summaryStats.avgCasesPerDay);
fprintf('  Average makespan: %.1f hours\n', summaryStats.avgMakespan);
fprintf('  Average lab utilization: %.1f%%\n', summaryStats.avgLabUtilization * 100);
fprintf('  Average operator idle time: %.1f hours\n', summaryStats.avgOperatorIdleTime);
fprintf('  Days with overtime: %d (%.1f%%)\n', summaryStats.daysWithOvertime, ...
    (summaryStats.daysWithOvertime / successfulDays) * 100);

% Display operator-specific statistics
if isfield(summaryStats, 'operatorStats') && ~isempty(summaryStats.operatorStats)
    fprintf('\n=== OPERATOR-SPECIFIC STATISTICS ===\n');
    operatorFields = fieldnames(summaryStats.operatorStats);
    
    % Sort operators by total cases (descending)
    operatorTotalCases = [];
    for i = 1:length(operatorFields)
        operatorTotalCases(i) = summaryStats.operatorStats.(operatorFields{i}).totalCases;
    end
    [~, sortIdx] = sort(operatorTotalCases, 'descend');
    
    for i = 1:length(sortIdx)
        opField = operatorFields{sortIdx(i)};
        opStats = summaryStats.operatorStats.(opField);
        
        fprintf('\n%s:\n', opStats.name);
        fprintf('  Total cases: %d (%.1f cases/day avg)\n', opStats.totalCases, opStats.avgCasesPerDay);
        fprintf('  Working days: %d\n', opStats.workingDays);
        fprintf('  Work time: %.1f hrs total (%.1f hrs/day avg)\n', opStats.totalWorkTime, opStats.avgWorkTimePerDay);
        fprintf('  Idle time: %.1f hrs total (%.1f hrs/day avg)\n', opStats.totalIdleTime, opStats.avgIdleTimePerDay);
        fprintf('  Overtime: %.1f hrs total (%.1f hrs/day avg, %d days with OT)\n', ...
            opStats.totalOvertime, opStats.avgOvertimePerDay, opStats.daysWithOvertime);
        fprintf('  Efficiency: %.1f cases/hour, %.1f%% utilization\n', ...
            opStats.avgCasesPerHour, opStats.utilizationRate * 100);
    end
end

fprintf('\nResults saved to: %s\n', saveFile);
fprintf('Batch processing complete!\n');

% Log completion and results summary
logCompletion(logFile, batchResults, toc(startTime));

end

%% Logging Functions

function logFile = createLogFile()
% Create a log file with timestamp
timestamp = datestr(now, 'yyyymmdd_HHMMSS');
logFile = sprintf('batch_processing_log_%s.txt', timestamp);
fid = fopen(logFile, 'w');
if fid == -1
    warning('Could not create log file: %s. Logging to console instead.', logFile);
    logFile = '';
    return;
end

% Write header
fprintf(fid, '=================================================================\n');
fprintf(fid, 'EP Lab Batch Processing Log\n');
fprintf(fid, 'Generated: %s\n', datestr(now, 'yyyy-mm-dd HH:MM:SS'));
fprintf(fid, '=================================================================\n\n');
fclose(fid);

fprintf('Created log file: %s\n', logFile);
end

function logVersionInfo(logFile)
% Log version information for all key scripts
if isempty(logFile)
    return;
end

fid = fopen(logFile, 'a');
if fid == -1
    return;
end

fprintf(fid, 'SCRIPT VERSIONS:\n');
fprintf(fid, '================\n');

try
    % Get version information from key scripts
    versions = getScriptVersions();
    fieldNames = fieldnames(versions);
    for i = 1:length(fieldNames)
        scriptName = fieldNames{i};
        version = versions.(scriptName);
        fprintf(fid, '%-30s: %s\n', scriptName, version);
    end
catch ME
    fprintf(fid, 'Error getting script versions: %s\n', ME.message);
end

fprintf(fid, '\n');
fclose(fid);
end

function logParameters(logFile, turnoverTime, caseFilter, prioritizeOutpatient, dataSource, debugMode, limitDays)
% Log processing parameters
if isempty(logFile)
    return;
end

fid = fopen(logFile, 'a');
if fid == -1
    return;
end

fprintf(fid, 'PROCESSING PARAMETERS:\n');
fprintf(fid, '=====================\n');
fprintf(fid, 'Data Source:           %s\n', dataSource);
fprintf(fid, 'Turnover Time:         %d minutes\n', turnoverTime);
fprintf(fid, 'Case Filter:           %s\n', caseFilter);
fprintf(fid, 'Prioritize Outpatient: %s\n', string(prioritizeOutpatient));
fprintf(fid, 'Debug Mode:            %s\n', string(debugMode));
if limitDays > 0
    fprintf(fid, 'Limited Days:          %d\n', limitDays);
else
    fprintf(fid, 'Limited Days:          No limit\n');
end
fprintf(fid, '\n');

fclose(fid);
end

function logCompletion(logFile, batchResults, processingTime)
% Log completion summary and results
if isempty(logFile)
    return;
end

fid = fopen(logFile, 'a');
if fid == -1
    return;
end

fprintf(fid, 'PROCESSING RESULTS:\n');
fprintf(fid, '==================\n');
fprintf(fid, 'Total Processing Time: %.2f seconds\n', processingTime);
fprintf(fid, 'Processed Dates:       %d\n', length(batchResults.processedDates));
fprintf(fid, 'Successful Days:       %d\n', batchResults.parameters.successfulDays);
fprintf(fid, 'Failed Days:           %d\n', batchResults.parameters.failedDays);

if isfield(batchResults, 'summaryStats')
    stats = batchResults.summaryStats;
    if isfield(stats, 'numDaysProcessed')
        fprintf(fid, 'Days Processed:        %d\n', stats.numDaysProcessed);
    end
    if isfield(stats, 'avgCasesPerDay')
        fprintf(fid, 'Avg Cases per Day:     %.1f\n', stats.avgCasesPerDay);
    end
    if isfield(stats, 'avgMakespan')
        fprintf(fid, 'Avg Makespan:          %.1f hours\n', stats.avgMakespan / 60);
    end
    if isfield(stats, 'avgLabUtilization')
        fprintf(fid, 'Avg Lab Utilization:   %.1f%%\n', stats.avgLabUtilization * 100);
    end
end

% Log any processing errors
if isfield(batchResults, 'processingErrors') && ~isempty(batchResults.processingErrors)
    fprintf(fid, '\nPROCESSING ERRORS:\n');
    fprintf(fid, '=================\n');
    for i = 1:length(batchResults.processingErrors)
        fprintf(fid, 'Error %d: %s\n', i, batchResults.processingErrors{i});
    end
end

fprintf(fid, '\nLog completed: %s\n', datestr(now, 'yyyy-mm-dd HH:MM:SS'));
fprintf(fid, '=================================================================\n');

fclose(fid);
fprintf('Processing log saved to: %s\n', logFile);
end

function versions = getScriptVersions()
% Extract version numbers from key scripts
versions = struct();

% List of key scripts to check
scripts = {
    'batchProcessHistoricalCases.m'
    'scheduleHistoricalCases.m'
    'analyzeHistoricalData.m'
    'plotAnalysisResults.m'
    'getCasesByDate.m'
    'visualizeSchedule.m'
};

for i = 1:length(scripts)
    scriptName = scripts{i};
    [~, name, ~] = fileparts(scriptName);
    
    try
        % Read the first few lines of the script to find version
        if exist(scriptName, 'file')
            fid = fopen(scriptName, 'r');
            if fid == -1
                versions.(matlab.lang.makeValidName(name)) = 'File Open Error';
                continue;
            end
            
            version = 'Unknown';
            
            for j = 1:10  % Check first 10 lines
                line = fgetl(fid);
                if ischar(line) && contains(line, 'Version:')
                    % Extract version number
                    versionMatch = regexp(line, 'Version:\s*([^\s]+)', 'tokens');
                    if ~isempty(versionMatch)
                        version = versionMatch{1}{1};
                        break;
                    end
                end
            end
            fclose(fid);
            versions.(matlab.lang.makeValidName(name)) = version;
        else
            versions.(matlab.lang.makeValidName(name)) = 'Not Found';
        end
    catch ME
        versions.(matlab.lang.makeValidName(name)) = sprintf('Error: %s', ME.message);
    end
end

% Add MATLAB version
try
    matlabVersion = version('-release');
    versions.MATLAB_Version = matlabVersion;
catch ME
    versions.MATLAB_Version = sprintf('Unknown (%s)', ME.message);
end
versions.Computer_Architecture = computer;
end

%% Helper function to calculate summary statistics
function summaryStats = calculateSummaryStats(dailyResults, dailySchedules)
    % Remove empty results
    validResults = dailyResults(~cellfun(@isempty, dailyResults));
    validSchedules = dailySchedules(~cellfun(@isempty, dailySchedules));
    
    if isempty(validResults)
        summaryStats = struct();
        return;
    end
    
    % Extract metrics
    makespans = cellfun(@(x) x.makespan/60, validResults); % Convert to hours
    labUtilizations = cellfun(@(x) x.meanLabUtilization, validResults);
    operatorIdleTimes = cellfun(@(x) x.totalOperatorIdleTime/60, validResults); % Convert to hours
    operatorOvertimes = cellfun(@(x) x.totalOperatorOvertime/60, validResults); % Convert to hours
    numCases = cellfun(@(x) x.numCases, validResults);
    
    % Count days with overtime
    daysWithOvertime = sum(operatorOvertimes > 0);
    
    % Calculate summary statistics
    summaryStats = struct();
    summaryStats.numDaysProcessed = length(validResults);
    summaryStats.avgCasesPerDay = mean(numCases);
    summaryStats.stdCasesPerDay = std(numCases);
    summaryStats.minCasesPerDay = min(numCases);
    summaryStats.maxCasesPerDay = max(numCases);
    
    summaryStats.avgMakespan = mean(makespans);
    summaryStats.stdMakespan = std(makespans);
    summaryStats.minMakespan = min(makespans);
    summaryStats.maxMakespan = max(makespans);
    
    summaryStats.avgLabUtilization = mean(labUtilizations);
    summaryStats.stdLabUtilization = std(labUtilizations);
    summaryStats.minLabUtilization = min(labUtilizations);
    summaryStats.maxLabUtilization = max(labUtilizations);
    
    summaryStats.avgOperatorIdleTime = mean(operatorIdleTimes);
    summaryStats.stdOperatorIdleTime = std(operatorIdleTimes);
    summaryStats.totalOperatorIdleTime = sum(operatorIdleTimes);
    
    summaryStats.avgOperatorOvertime = mean(operatorOvertimes);
    summaryStats.totalOperatorOvertime = sum(operatorOvertimes);
    summaryStats.daysWithOvertime = daysWithOvertime;
    
    % Percentiles
    summaryStats.makespan_p25 = prctile(makespans, 25);
    summaryStats.makespan_p75 = prctile(makespans, 75);
    summaryStats.labUtil_p25 = prctile(labUtilizations, 25);
    summaryStats.labUtil_p75 = prctile(labUtilizations, 75);
    
    % Calculate operator-specific statistics
    fprintf('  Calculating operator-specific statistics...\n');
    summaryStats.operatorStats = calculateOperatorStats(validResults, validSchedules);
end

%% Helper function to calculate operator-specific statistics
function operatorStats = calculateOperatorStats(dailyResults, dailySchedules)
    % Initialize containers for each metric
    operatorDailyData = containers.Map(); % operatorName -> Map(dateStr -> struct with detailed data)
    
    for dayIdx = 1:length(dailyResults)
        dayResult = dailyResults{dayIdx};
        daySchedule = dailySchedules{dayIdx};
        
        % Skip if no valid schedule
        if ~isfield(daySchedule, 'labs') || isempty(daySchedule.labs)
            continue;
        end
        
        dayStr = dayResult.dateStr;
        
        % Collect all cases for each operator on this day
        operatorCasesByDay = containers.Map();
        
        % Process each lab to find operator cases
        for labIdx = 1:length(daySchedule.labs)
            labCases = daySchedule.labs{labIdx};
            if isempty(labCases)
                continue;
            end
            
            % Process each case in this lab
            for caseIdx = 1:length(labCases)
                caseInfo = labCases(caseIdx);
                operatorName = caseInfo.operator;
                
                % Initialize operator if first time seeing them
                if ~isKey(operatorCasesByDay, operatorName)
                    operatorCasesByDay(operatorName) = struct('procStartTime', {}, 'procEndTime', {}, 'procTime', {}, 'lab', {});
                end
                
                % Add case info with timing data
                caseData = struct();
                caseData.procStartTime = caseInfo.procStartTime;
                caseData.procEndTime = caseInfo.procEndTime;
                caseData.procTime = caseInfo.procTime;
                caseData.lab = labIdx;
                
                operatorCases = operatorCasesByDay(operatorName);
                if isempty(operatorCases)
                    operatorCases = caseData;
                else
                    operatorCases(end+1) = caseData;
                end
                operatorCasesByDay(operatorName) = operatorCases;
            end
        end
        
        % Calculate daily statistics for each operator
        operatorNames = keys(operatorCasesByDay);
        for opIdx = 1:length(operatorNames)
            operatorName = operatorNames{opIdx};
            operatorCases = operatorCasesByDay(operatorName);
            
            % Initialize operator in main data structure
            if ~isKey(operatorDailyData, operatorName)
                operatorDailyData(operatorName) = containers.Map();
            end
            
            % Calculate daily metrics
            dailyMetrics = calculateOperatorDailyMetrics(operatorCases);
            dailyMetrics.date = dayStr;
            
            % Store in main data structure
            operatorMap = operatorDailyData(operatorName);
            operatorMap(dayStr) = dailyMetrics;
            operatorDailyData(operatorName) = operatorMap;
        end
    end
    
    % Calculate summary statistics for each operator
    operatorNames = keys(operatorDailyData);
    operatorStats = struct();
    
    for opIdx = 1:length(operatorNames)
        operatorName = operatorNames{opIdx};
        
        % Clean operator name for field name
        fieldName = matlab.lang.makeValidName(operatorName);
        
        % Get daily data for this operator
        operatorMap = operatorDailyData(operatorName);
        dailyDates = keys(operatorMap);
        
        % Extract daily statistics
        dailyCases = [];
        dailyWorkTimes = [];
        dailyIdleTimes = [];
        dailyOvertimes = [];
        
        for dayIdx = 1:length(dailyDates)
            dayData = operatorMap(dailyDates{dayIdx});
            dailyCases(end+1) = dayData.cases;
            dailyWorkTimes(end+1) = dayData.workTime;
            dailyIdleTimes(end+1) = dayData.idleTime;
            dailyOvertimes(end+1) = dayData.overtime;
        end
        
        % Basic statistics
        operatorStats.(fieldName).name = operatorName;
        operatorStats.(fieldName).totalCases = sum(dailyCases);
        operatorStats.(fieldName).workingDays = length(dailyDates);
        
        if ~isempty(dailyCases)
            operatorStats.(fieldName).avgCasesPerDay = mean(dailyCases);
            operatorStats.(fieldName).maxCasesPerDay = max(dailyCases);
            operatorStats.(fieldName).minCasesPerDay = min(dailyCases);
        else
            operatorStats.(fieldName).avgCasesPerDay = 0;
            operatorStats.(fieldName).maxCasesPerDay = 0;
            operatorStats.(fieldName).minCasesPerDay = 0;
        end
        
        % Work time statistics
        if ~isempty(dailyWorkTimes)
            operatorStats.(fieldName).totalWorkTime = sum(dailyWorkTimes);
            operatorStats.(fieldName).avgWorkTimePerDay = mean(dailyWorkTimes);
            operatorStats.(fieldName).maxWorkTimePerDay = max(dailyWorkTimes);
            operatorStats.(fieldName).minWorkTimePerDay = min(dailyWorkTimes);
        else
            operatorStats.(fieldName).totalWorkTime = 0;
            operatorStats.(fieldName).avgWorkTimePerDay = 0;
            operatorStats.(fieldName).maxWorkTimePerDay = 0;
            operatorStats.(fieldName).minWorkTimePerDay = 0;
        end
        
        % Idle time statistics
        if ~isempty(dailyIdleTimes)
            operatorStats.(fieldName).totalIdleTime = sum(dailyIdleTimes);
            operatorStats.(fieldName).avgIdleTimePerDay = mean(dailyIdleTimes);
            operatorStats.(fieldName).maxIdleTimePerDay = max(dailyIdleTimes);
            operatorStats.(fieldName).minIdleTimePerDay = min(dailyIdleTimes);
        else
            operatorStats.(fieldName).totalIdleTime = 0;
            operatorStats.(fieldName).avgIdleTimePerDay = 0;
            operatorStats.(fieldName).maxIdleTimePerDay = 0;
            operatorStats.(fieldName).minIdleTimePerDay = 0;
        end
        
        % Overtime statistics
        if ~isempty(dailyOvertimes)
            operatorStats.(fieldName).totalOvertime = sum(dailyOvertimes);
            operatorStats.(fieldName).avgOvertimePerDay = mean(dailyOvertimes);
            operatorStats.(fieldName).daysWithOvertime = sum(dailyOvertimes > 0);
        else
            operatorStats.(fieldName).totalOvertime = 0;
            operatorStats.(fieldName).avgOvertimePerDay = 0;
            operatorStats.(fieldName).daysWithOvertime = 0;
        end
        
        % Efficiency metrics (basic version)
        if operatorStats.(fieldName).avgWorkTimePerDay > 0
            operatorStats.(fieldName).avgCasesPerHour = operatorStats.(fieldName).avgCasesPerDay / operatorStats.(fieldName).avgWorkTimePerDay;
        else
            operatorStats.(fieldName).avgCasesPerHour = 0;
        end
        
        % Utilization rate (assuming 8-hour workday)
        standardWorkDay = 8; % hours
        if operatorStats.(fieldName).avgWorkTimePerDay > 0
            operatorStats.(fieldName).utilizationRate = min(1.0, operatorStats.(fieldName).avgWorkTimePerDay / standardWorkDay);
        else
            operatorStats.(fieldName).utilizationRate = 0;
        end
    end
end

%% Helper function to calculate daily metrics for an operator
function dailyMetrics = calculateOperatorDailyMetrics(operatorCases)
    % Calculate detailed daily metrics for a single operator
    
    if isempty(operatorCases)
        dailyMetrics = struct('cases', 0, 'workTime', 0, 'idleTime', 0, 'overtime', 0);
        return;
    end
    
    % Sort cases by procedure start time
    startTimes = [operatorCases.procStartTime];
    [~, sortIdx] = sort(startTimes);
    sortedCases = operatorCases(sortIdx);
    
    % Basic metrics
    numCases = length(sortedCases);
    totalProcTime = sum([sortedCases.procTime]); % in minutes
    
    % Calculate idle time between consecutive cases
    totalIdleTime = 0; % in minutes
    
    if numCases > 1
        for i = 2:numCases
            prevEndTime = sortedCases(i-1).procEndTime;
            currentStartTime = sortedCases(i).procStartTime;
            
            % Only count as idle time if it's the same operator and gap > 5 minutes
            if currentStartTime > prevEndTime
                gapTime = currentStartTime - prevEndTime;
                if gapTime > 5 % Only count gaps > 5 minutes as idle time
                    totalIdleTime = totalIdleTime + gapTime;
                end
            end
        end
    end
    
    % Calculate overtime (time after 6 PM = 18*60 = 1080 minutes since midnight)
    overtimeCutoff = 18 * 60; % 6 PM in minutes since midnight
    totalOvertime = 0; % in minutes
    
    for i = 1:numCases
        caseEndTime = sortedCases(i).procEndTime;
        if caseEndTime > overtimeCutoff
            % Case extends past 6 PM
            caseStartTime = sortedCases(i).procStartTime;
            if caseStartTime >= overtimeCutoff
                % Entire case is overtime
                totalOvertime = totalOvertime + sortedCases(i).procTime;
            else
                % Part of case is overtime
                overtimePortion = caseEndTime - overtimeCutoff;
                totalOvertime = totalOvertime + overtimePortion;
            end
        end
    end
    
    % Create daily metrics structure
    dailyMetrics = struct();
    dailyMetrics.cases = numCases;
    dailyMetrics.workTime = totalProcTime / 60; % Convert to hours
    dailyMetrics.idleTime = totalIdleTime / 60; % Convert to hours  
    dailyMetrics.overtime = totalOvertime / 60; % Convert to hours
    
    % Additional timing info
    dailyMetrics.firstCaseStart = sortedCases(1).procStartTime;
    dailyMetrics.lastCaseEnd = sortedCases(end).procEndTime;
    dailyMetrics.spanTime = (dailyMetrics.lastCaseEnd - dailyMetrics.firstCaseStart) / 60; % Total span in hours
end

%% Helper function to convert cases to scheduler format
function schedulerCases = convertToSchedulerFormat(inputCases)
    % Convert cases from batch processing format to the format expected by scheduleHistoricalCases
    % (same format as output by getCasesByDate.m)
    
    if isempty(inputCases)
        schedulerCases = struct();
        return;
    end
    
    numCases = length(inputCases);
    schedulerCases = struct();
    
    for i = 1:numCases
        case_data = inputCases(i);
        
        % Core scheduling fields (required by scheduler)
        schedulerCases(i).operator = ensureChar(case_data.operatorName);
        schedulerCases(i).caseID = ensureChar(case_data.caseID);
        schedulerCases(i).procTime = ensureNumeric(case_data.procedureDuration, 120); % Default 2 hours
        
        % Setup and post times with defaults
        if isfield(case_data, 'setupTime')
            schedulerCases(i).setupTime = ensureNumeric(case_data.setupTime, 30);
        else
            schedulerCases(i).setupTime = 30; % Default 30 minutes
        end
        
        if isfield(case_data, 'postTime')
            schedulerCases(i).postTime = ensureNumeric(case_data.postTime, 15);
        else
            schedulerCases(i).postTime = 15; % Default 15 minutes
        end
        
        % Additional information fields with defaults
        if isfield(case_data, 'procedure')
            schedulerCases(i).procedure = ensureChar(case_data.procedure);
        else
            schedulerCases(i).procedure = 'Unknown';
        end
        
        if isfield(case_data, 'location')
            schedulerCases(i).location = ensureChar(case_data.location);
        else
            schedulerCases(i).location = 'EP Lab';
        end
        
        if isfield(case_data, 'service')
            schedulerCases(i).service = ensureChar(case_data.service);
        else
            schedulerCases(i).service = 'EP';
        end
        
        if isfield(case_data, 'totalRoomTime')
            schedulerCases(i).totalRoomTime = ensureNumeric(case_data.totalRoomTime, schedulerCases(i).setupTime + schedulerCases(i).procTime + schedulerCases(i).postTime);
        else
            schedulerCases(i).totalRoomTime = schedulerCases(i).setupTime + schedulerCases(i).procTime + schedulerCases(i).postTime;
        end
        
        % Date field
        if isfield(case_data, 'procedureDate')
            if isdatetime(case_data.procedureDate)
                schedulerCases(i).date = datestr(case_data.procedureDate, 'dd-mmm-yyyy');
            else
                schedulerCases(i).date = ensureChar(case_data.procedureDate);
            end
        else
            schedulerCases(i).date = '';
        end
        
        % Admission status
        if isfield(case_data, 'admissionStatus')
            schedulerCases(i).admissionStatus = ensureChar(case_data.admissionStatus);
        else
            schedulerCases(i).admissionStatus = '';
        end
        
        % Priority and lab preference fields (empty by default)
        schedulerCases(i).priority = [];
        schedulerCases(i).preferredLab = [];
    end
end

%% Helper function to ensure field is character array
function result = ensureChar(input)
    if ischar(input)
        result = input;
    elseif isstring(input)
        result = char(input);
    elseif iscell(input) && ~isempty(input)
        result = char(input{1});
    else
        result = '';
    end
end

%% Helper function to ensure field is numeric with default
function result = ensureNumeric(input, defaultValue)
    if isnumeric(input) && ~isnan(input) && input > 0
        result = input;
    else
        result = defaultValue;
    end
end

%% Helper function to format schedules for analyzeHistoricalData.m
function formattedSchedules = formatSchedulesForAnalysis(dailySchedules, dailyResults, processedDates)
% Format dailySchedules to match the expected format of historicalSchedules from loadHistoricalDataFromFile.m
% Expected format: containers.Map with dateStr as key and struct with fields:
%   .schedule, .results, .date, .numCases

formattedSchedules = containers.Map();

for i = 1:length(processedDates)
    if ~isempty(processedDates{i}) && ~isempty(dailySchedules{i}) && ~isempty(dailyResults{i})
        originalDateStr = processedDates{i};
        
        % Convert date format from mm-dd-yyyy to dd-MMM-yyyy to match loadHistoricalDataFromFile.m
        try
            dt = datetime(originalDateStr, 'InputFormat', 'MM-dd-yyyy');
            dateStr = char(dt, 'dd-MMM-yyyy');
        catch
            % If parsing fails, use original
            dateStr = originalDateStr;
        end
        
        % Create schedule data structure matching loadHistoricalDataFromFile format
        scheduleData = struct();
        scheduleData.schedule = dailySchedules{i};
        scheduleData.results = dailyResults{i};
        scheduleData.date = dateStr;
        scheduleData.numCases = dailyResults{i}.numCases;
        
        % Add lab mapping information if available
        if isfield(dailySchedules{i}, 'labMapping')
            scheduleData.labMapping = dailySchedules{i}.labMapping;
        end
        if isfield(dailySchedules{i}, 'numLabs')
            scheduleData.numLabs = dailySchedules{i}.numLabs;
        end
        
        formattedSchedules(dateStr) = scheduleData;
    end
end

fprintf('Formatted %d daily schedules for analysis compatibility\n', formattedSchedules.Count);
end

%% Helper function to create caseData structure compatible with analyzeHistoricalData.m
function caseData = createCaseDataStructure(userData)
% Create a caseData structure that matches the format expected by analyzeHistoricalData.m
% Expected format: struct with fields matching historicalData from loadHistoricalDataFromFile.m

if isempty(userData)
    caseData = struct();
    return;
end

numCases = length(userData);
fprintf('Creating caseData structure from %d cases...\n', numCases);

% Initialize the case data structure with required fields
caseData = struct();

% Core identification fields
caseData.caseID = cell(numCases, 1);
caseData.date = NaT(numCases, 1);
caseData.surgeon = cell(numCases, 1);

% Procedure information
caseData.procedure = cell(numCases, 1);
caseData.service = cell(numCases, 1);
caseData.location = cell(numCases, 1);

% Timing information (in minutes)
caseData.setupTime = zeros(numCases, 1);
caseData.procedureTime = zeros(numCases, 1);
caseData.postTime = zeros(numCases, 1);
caseData.totalRoomTime = zeros(numCases, 1);
caseData.anesthesiaTime = zeros(numCases, 1);

% Time of day information (required by analyzeHistoricalData.m)
caseData.procedureStartTimeOfDay = duration(NaN(numCases, 1), 0, 0);
caseData.procedureCompleteTimeOfDay = duration(NaN(numCases, 1), 0, 0);
caseData.procedureStartTimestamp = NaT(numCases, 1);
caseData.procedureCompleteTimestamp = NaT(numCases, 1);

% Additional optional fields
caseData.admissionStatus = cell(numCases, 1);
caseData.room = cell(numCases, 1);

% Populate the structure from userData
for i = 1:numCases
    case_data = userData(i);
    
    % Core fields
    caseData.caseID{i} = ensureChar(case_data.caseID);
    
    % Handle date field - store as datetime to match loadHistoricalDataFromFile.m
    if isfield(case_data, 'procedureDate')
        if isdatetime(case_data.procedureDate)
            caseData.date(i) = case_data.procedureDate;
        else
            % Convert from mm-dd-yyyy format to datetime
            dateStr = ensureChar(case_data.procedureDate);
            if ~isempty(dateStr) && length(dateStr) == 10 && contains(dateStr, '-')
                try
                    % Parse mm-dd-yyyy format and convert to datetime
                    caseData.date(i) = datetime(dateStr, 'InputFormat', 'MM-dd-yyyy');
                catch
                    % If parsing fails, use NaT
                    caseData.date(i) = NaT;
                end
            else
                caseData.date(i) = NaT;
            end
        end
    else
        caseData.date(i) = NaT;
    end
    
    caseData.surgeon{i} = ensureChar(case_data.operatorName);
    
    % Procedure information with defaults
    if isfield(case_data, 'procedure')
        caseData.procedure{i} = ensureChar(case_data.procedure);
    else
        caseData.procedure{i} = 'Unknown';
    end
    
    if isfield(case_data, 'service')
        caseData.service{i} = ensureChar(case_data.service);
    else
        caseData.service{i} = 'EP';
    end
    
    if isfield(case_data, 'location')
        caseData.location{i} = ensureChar(case_data.location);
    else
        caseData.location{i} = 'EP Lab';
    end
    
    % Timing information
    caseData.setupTime(i) = ensureNumeric(getFieldSafe(case_data, 'setupTime'), 30);
    caseData.procedureTime(i) = ensureNumeric(case_data.procedureDuration, 120);
    caseData.postTime(i) = ensureNumeric(getFieldSafe(case_data, 'postTime'), 15);
    
    % Calculate total room time
    if isfield(case_data, 'totalRoomTime')
        caseData.totalRoomTime(i) = ensureNumeric(case_data.totalRoomTime, ...
            caseData.setupTime(i) + caseData.procedureTime(i) + caseData.postTime(i));
    else
        caseData.totalRoomTime(i) = caseData.setupTime(i) + caseData.procedureTime(i) + caseData.postTime(i);
    end
    
    % Anesthesia time (default to setup time if not available)
    caseData.anesthesiaTime(i) = ensureNumeric(getFieldSafe(case_data, 'anesthesiaTime'), caseData.setupTime(i));
    
    % Calculate time-of-day information based on scheduled times
    if isfield(case_data, 'startTime')
        % Parse start time from case data (expecting time in minutes from start of day)
        startTimeMinutes = ensureNumeric(case_data.startTime, 8*60); % Default to 8 AM
        caseData.procedureStartTimeOfDay(i) = duration(0, startTimeMinutes, 0);
        caseData.procedureStartTimestamp(i) = caseData.date(i) + caseData.procedureStartTimeOfDay(i);
        
        % Calculate completion time
        completionTimeMinutes = startTimeMinutes + caseData.setupTime(i) + caseData.procedureTime(i);
        caseData.procedureCompleteTimeOfDay(i) = duration(0, completionTimeMinutes, 0);
        caseData.procedureCompleteTimestamp(i) = caseData.date(i) + caseData.procedureCompleteTimeOfDay(i);
    else
        % Use default values if timing information is not available
        caseData.procedureStartTimeOfDay(i) = duration(NaN, 0, 0);
        caseData.procedureCompleteTimeOfDay(i) = duration(NaN, 0, 0);
        caseData.procedureStartTimestamp(i) = NaT;
        caseData.procedureCompleteTimestamp(i) = NaT;
    end
    
    % Optional fields
    if isfield(case_data, 'admissionStatus')
        caseData.admissionStatus{i} = ensureChar(case_data.admissionStatus);
    else
        caseData.admissionStatus{i} = '';
    end
    
    if isfield(case_data, 'room')
        caseData.room{i} = ensureChar(case_data.room);
    else
        caseData.room{i} = '';
    end
end

fprintf('Created caseData structure with %d cases\n', numCases);

% Show basic statistics
uniqueDates = unique(caseData.date);
uniqueSurgeons = unique(caseData.surgeon);
uniqueProcedures = unique(caseData.procedure);

fprintf('caseData Summary:\n');
fprintf('  Unique dates: %d\n', length(uniqueDates(~strcmp(uniqueDates, ''))));
fprintf('  Unique surgeons: %d\n', length(uniqueSurgeons(~strcmp(uniqueSurgeons, ''))));
fprintf('  Unique procedures: %d\n', length(uniqueProcedures(~strcmp(uniqueProcedures, ''))));

end

%% Helper function to safely get field value
function value = getFieldSafe(structure, fieldName)
if isfield(structure, fieldName)
    value = structure.(fieldName);
else
    value = NaN;
end
end