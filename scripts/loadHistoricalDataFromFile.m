function [historicalData, historicalSchedules] = loadHistoricalDataFromFile(varargin)
% Creates a .mat file with cleaned historical data from Excel file
% Converts column names to human-readable format
% Also reconstructs actual historical schedules for each day
%
% Usage:
%   historicalData = loadHistoricalDataFromFile()  % Uses default 'procedureDurationsB.xlsx'
%   [historicalData, schedules] = loadHistoricalDataFromFile('path/to/mydata.xlsx')
%   [historicalData, schedules] = loadHistoricalDataFromFile('FilePath', 'path/to/mydata.xlsx')
%
% Parameters:
%   FilePath - Path to Excel file containing historical procedure data
%          [    Default: 'procedureDurationsB.xlsx'
%   CreateSchedules - Whether to reconstruct historical schedules (default: true)
%   TurnoverTime - Estimated turnover time for historical schedules (default: 15 minutes)
%   Debug - Show debug output during schedule reconstruction (default: false)
%
% Outputs:
%   historicalData - Cleaned historical data structure
%   historicalSchedules - Map containing reconstructed schedules for each date
%                        (only returned if CreateSchedules is true)

% Parse input arguments
p = inputParser;
addOptional(p, 'FilePath', 'procedureDurationsB.xlsx', @(x) ischar(x) || isstring(x));
addParameter(p, 'CreateSchedules', true, @islogical);
addParameter(p, 'TurnoverTime', 15, @(x) isnumeric(x) && x >= 0);
addParameter(p, 'Debug', false, @islogical);
parse(p, varargin{:});

filename = char(p.Results.FilePath);
createSchedules = p.Results.CreateSchedules;
turnoverTime = p.Results.TurnoverTime;
debugMode = p.Results.Debug;

fprintf('Loading historical data from Excel file: %s\n', filename);

% Load the Excel file
if ~exist(filename, 'file')
    error('File %s not found', filename);
end

try
    % Read with proper header row (row 10 in Excel)
    % Use readtable with header row specification - this automatically detects data end
    rawData = readtable(filename, 'HeaderLines', 9);
    
    % Remove any completely empty rows that might have been read
    % Check for rows where all key columns are empty/NaN
    validRows = ~(ismissing(rawData{:,1}) & ismissing(rawData{:,2}) & ismissing(rawData{:,3}));
    rawData = rawData(validRows, :);
    fprintf('Loaded %d records from %s\n', height(rawData), filename);
    
    % Show actual MATLAB variable names
    fprintf('\nActual MATLAB variable names:\n');
    for i = 1:length(rawData.Properties.VariableNames)
        fprintf('  %d: %s\n', i, rawData.Properties.VariableNames{i});
    end
    
    % Debug: Show what we're looking for
    fprintf('\nLooking for Case ID column...\n');
    caseIDColumns = rawData.Properties.VariableNames(contains(lower(rawData.Properties.VariableNames), 'case'));
    if ~isempty(caseIDColumns)
        fprintf('Found case-related columns: %s\n', strjoin(caseIDColumns, ', '));
    else
        fprintf('No case-related columns found\n');
    end
    
    % Search for columns that might contain admission status
    fprintf('\nSearching for admission-related columns:\n');
    allColumns = rawData.Properties.VariableNames;
    admissionKeywords = {'admission', 'patient', 'class', 'slices', 'inpatient', 'outpatient'};
    
    for keyword = admissionKeywords
        matchingCols = allColumns(contains(lower(allColumns), lower(keyword{1})));
        if ~isempty(matchingCols)
            fprintf('  Columns containing "%s": %s\n', keyword{1}, strjoin(matchingCols, ', '));
        end
    end
    
    % Debug: Check caseID field
    fprintf('\nFirst 5 Case IDs:\n');
    for i = 1:min(5, height(rawData))
        caseIdVal = rawData.CaseID(i);
        fprintf('  %d: "%s" (class: %s, length: %d)\n', i, caseIdVal, class(caseIdVal), strlength(string(caseIdVal)));
    end
    
catch ME
    error('Error reading Excel file: %s', ME.message);
end

% Create cleaned data structure with human-readable field names
historicalData = struct();

% Basic case information
% Find the Case ID column dynamically
caseIDColumn = '';
possibleCaseIDColumns = {'CaseID', 'Case_ID', 'Case ID', 'CaseId', 'case_id', 'case_ID'};
for col = possibleCaseIDColumns
    if ismember(col{1}, rawData.Properties.VariableNames)
        caseIDColumn = col{1};
        break;
    end
end

% If not found by exact match, try partial matching
if isempty(caseIDColumn)
    caseIDColumns = rawData.Properties.VariableNames(contains(lower(rawData.Properties.VariableNames), 'case'));
    if ~isempty(caseIDColumns)
        caseIDColumn = caseIDColumns{1}; % Use first match
    end
end

if isempty(caseIDColumn)
    error('Could not find Case ID column in the data');
end

fprintf('Using Case ID column: %s\n', caseIDColumn);

% Clean caseID field to handle encoding issues
cleanCaseIDs = string(rawData.(caseIDColumn));
% Remove any non-printable characters
for i = 1:length(cleanCaseIDs)
    if ismissing(cleanCaseIDs(i)) || strlength(cleanCaseIDs(i)) == 0
        cleanCaseIDs(i) = sprintf('Case_%d', i);
    else
        % Remove non-ASCII characters that might cause display issues
        cleanStr = regexprep(char(cleanCaseIDs(i)), '[^\x20-\x7E]', '');
        if isempty(cleanStr)
            cleanCaseIDs(i) = sprintf('Case_%d', i);
        else
            cleanCaseIDs(i) = string(cleanStr);
        end
    end
end
% Helper function to find column dynamically
findColumn = @(possibleNames) findColumnByName(rawData.Properties.VariableNames, possibleNames);

historicalData.caseID = cleanCaseIDs;
historicalData.date = rawData.Date;
historicalData.surgeon = rawData.(findColumn({'Primary_Surgeon', 'PrimarySurgeon', 'Primary Surgeon'}));
historicalData.procedure = rawData.(findColumn({'Procedure_Primary', 'Procedure_Primary_', 'Procedure (Primary)'}));
historicalData.service = rawData.Service;
historicalData.location = rawData.(findColumn({'Case_Location', 'CaseLocation', 'Case Location'}));
historicalData.room = rawData.(findColumn({'Room'}));

% Admission status (inpatient/outpatient)
% Try multiple possible column names for admission status
admissionColumn = '';
possibleColumns = {'Admission_Patient_Class', 'AdmissionPatientClass', 'Admission Patient Class', 'SlicesByAdmissionPatientClass', 'SlicesbyAdmissionPatientClass', 'Slices by Admission Patient Class', 'AdmissionStatus', 'Admission Status'};

for col = possibleColumns
    if ismember(col{1}, rawData.Properties.VariableNames)
        admissionColumn = col{1};
        break;
    end
end

if ~isempty(admissionColumn)
    historicalData.admissionStatus = rawData.(admissionColumn);
    fprintf('Using admission status from column: %s\n', admissionColumn);
else
    % Default to empty if not present in file
    historicalData.admissionStatus = strings(height(rawData), 1);
    fprintf('Warning: No admission status column found (tried: %s), using empty values\n', ...
        strjoin(possibleColumns, ', '));
end

% Time measurements (all in minutes)
historicalData.setupTime = rawData.(findColumn({'In_Room_to_Procedure_Start_Minutes', 'InRoomToProcedureStart_Minutes_', 'In Room to Procedure Start (Minutes)'}));
historicalData.procedureTime = rawData.(findColumn({'Procedure_Start_to_Procedure_Complete_Minutes', 'ProcedureStartToProcedureComplete_Minutes_', 'Procedure Start to Procedure Complete (Minutes)'}));
historicalData.postTime = rawData.(findColumn({'Procedure_Complete_to_Out_of_Room_Minutes', 'ProcedureCompleteToOutOfRoom_Minutes_', 'Procedure Complete to Out of Room (Minutes)'}));
historicalData.totalRoomTime = rawData.(findColumn({'In_Room_to_Out_of_Room_Minutes', 'InRoomToOutOfRoom_Minutes_', 'In Room to Out of Room (Minutes)'}));
historicalData.anesthesiaTime = rawData.(findColumn({'In_Room_to_Anesthesia_Induction_Minutes', 'InRoomToAnesthesiaInduction_Minutes_', 'In Room to Anesthesia Induction (Minutes)'})); % Best available match

% Extract procedure start and end times (time of day only)
procedureStartTimestamps = rawData.(findColumn({'Procedure_Start_Date_and_Time', 'ProcedureStartDateAndTime', 'Procedure Start Date and Time'}));
procedureCompleteTimestamps = rawData.(findColumn({'Procedure_Complete_Date_and_Time', 'ProcedureCompleteDateAndTime', 'Procedure Complete Date and Time'}));

% Filter out cases with missing start times before processing
validStartTimeIndices = ~ismissing(procedureStartTimestamps);
fprintf('Filtering out %d cases with missing start times (keeping %d of %d cases)\n', ...
    sum(~validStartTimeIndices), sum(validStartTimeIndices), length(validStartTimeIndices));

% Apply filter to all data fields
fieldNames = fieldnames(historicalData);
for i = 1:length(fieldNames)
    field = fieldNames{i};
    if length(historicalData.(field)) == length(validStartTimeIndices)
        historicalData.(field) = historicalData.(field)(validStartTimeIndices);
    end
end

% Also filter the timestamp arrays
procedureStartTimestamps = procedureStartTimestamps(validStartTimeIndices);
procedureCompleteTimestamps = procedureCompleteTimestamps(validStartTimeIndices);

% Convert timestamps to time of day (duration from midnight)
historicalData.procedureStartTimeOfDay = timeofday(procedureStartTimestamps);
historicalData.procedureCompleteTimeOfDay = timeofday(procedureCompleteTimestamps);

% Also keep full timestamps for reference
historicalData.procedureStartTimestamp = procedureStartTimestamps;
historicalData.procedureCompleteTimestamp = procedureCompleteTimestamps;

% Add summary statistics
fprintf('\nData Summary:\n');
fprintf('  Total cases: %d\n', length(historicalData.caseID));
fprintf('  Date range: %s to %s\n', string(min(historicalData.date)), string(max(historicalData.date)));
fprintf('  Unique surgeons: %d\n', length(unique(historicalData.surgeon)));
fprintf('  Unique procedures: %d\n', length(unique(historicalData.procedure)));

% Show procedure type distribution
[procedures, ~, idx] = unique(historicalData.procedure);
counts = accumarray(idx, 1);
[counts, sortIdx] = sort(counts, 'descend');
procedures = procedures(sortIdx);

fprintf('\nTop 10 Procedure Types:\n');
for i = 1:min(10, length(procedures))
    fprintf('  %s: %d cases\n', procedures{i}, counts(i));
end

% Show time statistics
validSetupTimes = historicalData.setupTime(~isnan(historicalData.setupTime));
validProcTimes = historicalData.procedureTime(~isnan(historicalData.procedureTime));
validPostTimes = historicalData.postTime(~isnan(historicalData.postTime));

fprintf('\nTime Statistics (minutes):\n');
fprintf('  Setup Time - Mean: %.1f, Median: %.1f, Range: %.1f-%.1f\n', ...
    mean(validSetupTimes), median(validSetupTimes), min(validSetupTimes), max(validSetupTimes));
fprintf('  Procedure Time - Mean: %.1f, Median: %.1f, Range: %.1f-%.1f\n', ...
    mean(validProcTimes), median(validProcTimes), min(validProcTimes), max(validProcTimes));
fprintf('  Post Time - Mean: %.1f, Median: %.1f, Range: %.1f-%.1f\n', ...
    mean(validPostTimes), median(validPostTimes), min(validPostTimes), max(validPostTimes));

% Show procedure time of day statistics
validStartTimes = historicalData.procedureStartTimeOfDay(~ismissing(historicalData.procedureStartTimeOfDay));
validCompleteTimes = historicalData.procedureCompleteTimeOfDay(~ismissing(historicalData.procedureCompleteTimeOfDay));

if ~isempty(validStartTimes)
    fprintf('\nProcedure Time of Day Statistics:\n');
    fprintf('  Start Times - Earliest: %s, Latest: %s\n', ...
        string(min(validStartTimes)), string(max(validStartTimes)));
    fprintf('  Complete Times - Earliest: %s, Latest: %s\n', ...
        string(min(validCompleteTimes)), string(max(validCompleteTimes)));
end

% Show admission status distribution
if ~isempty(admissionColumn)
    validAdmissionStatuses = historicalData.admissionStatus(~ismissing(historicalData.admissionStatus) & ~strcmp(historicalData.admissionStatus, ''));
    if ~isempty(validAdmissionStatuses)
        [statuses, ~, idx] = unique(validAdmissionStatuses);
        counts = accumarray(idx, 1);
        [counts, sortIdx] = sort(counts, 'descend');
        statuses = statuses(sortIdx);
        
        fprintf('\nAdmission Status Distribution:\n');
        for i = 1:length(statuses)
            fprintf('  %s: %d cases\n', statuses{i}, counts(i));
        end
    else
        fprintf('\nAdmission Status: All values are empty/missing\n');
    end
else
    fprintf('\nAdmission Status: Column not found in data\n');
end

% Save to .mat file
outputFile = './data/historicalEPData.mat';
if ~isfolder('./data')
    mkdir('./data');
end
save(outputFile, 'historicalData');
fprintf('\nData saved to %s\n', outputFile);

% Create field description
fieldDescriptions = struct();
fieldDescriptions.caseID = 'Unique case identifier';
fieldDescriptions.date = 'Procedure date';
fieldDescriptions.surgeon = 'Primary surgeon/operator';
fieldDescriptions.procedure = 'Type of procedure performed';
fieldDescriptions.service = 'Medical service (typically Cardiovascular)';
fieldDescriptions.location = 'EP lab location';
fieldDescriptions.admissionStatus = 'Patient admission status (Hospital Outpatient Surgery/Inpatient/etc.)';
fieldDescriptions.setupTime = 'Time from room entry to procedure start (minutes)';
fieldDescriptions.procedureTime = 'Actual procedure duration (minutes)';
fieldDescriptions.postTime = 'Time from procedure end to room exit (minutes)';
fieldDescriptions.totalRoomTime = 'Total time in room (minutes)';
fieldDescriptions.anesthesiaTime = 'Time from room entry to anesthesia induction (minutes)';
fieldDescriptions.procedureStartTimeOfDay = 'Time of day when procedure started (duration from midnight)';
fieldDescriptions.procedureCompleteTimeOfDay = 'Time of day when procedure completed (duration from midnight)';
fieldDescriptions.procedureStartTimestamp = 'Full timestamp when procedure started';
fieldDescriptions.procedureCompleteTimestamp = 'Full timestamp when procedure completed';

% Save descriptions to separate file
save('./data/historicalEPDataDescriptions.mat', 'fieldDescriptions');
fprintf('Field descriptions saved to historicalEPDataDescriptions.mat\n');

fprintf('\nData structure created successfully!\n');

% Reconstruct historical schedules if requested
if createSchedules
    fprintf('\n=== RECONSTRUCTING HISTORICAL SCHEDULES ===\n');
    historicalSchedules = reconstructAllHistoricalSchedules(historicalData, turnoverTime, debugMode);
    
    % Save historical schedules to file
    scheduleOutputFile = './data/historicalEPSchedules.mat';
    save(scheduleOutputFile, 'historicalSchedules');
    fprintf('Historical schedules saved to %s\n', scheduleOutputFile);
    
    % Generate and save lab mappings
    fprintf('\nGenerating lab mappings...\n');
    labMappings = getHistoricalLabMappings(historicalSchedules);
else
    historicalSchedules = containers.Map();
end

fprintf('\nData loading complete!\n');

end

%% Helper function to reconstruct all historical schedules
function historicalSchedules = reconstructAllHistoricalSchedules(historicalData, turnoverTime, debugMode)
    % Get unique dates
    uniqueDates = string(unique(historicalData.date));
    uniqueDates = uniqueDates(~ismissing(uniqueDates));
    
    fprintf('Reconstructing schedules for %d unique dates...\n', length(uniqueDates));
    
    % Initialize schedule storage
    historicalSchedules = containers.Map();
    
    % Progress tracking
    if ~debugMode
        fprintf('Progress: [');
        progressLength = 50;
        lastProgress = 0;
    end
    
    successCount = 0;
    errorCount = 0;
    
    for i = 1:length(uniqueDates)
        dateStr = char(uniqueDates(i));
        
        try
            % Convert date format for reconstructHistoricalSchedule function
            % From 'dd-mmm-yyyy' to 'MM-DD-YYYY'
            dt = datetime(dateStr, 'InputFormat', 'dd-MMM-yyyy');
            dateForFunction = sprintf('%02d-%02d-%04d', month(dt), day(dt), year(dt));
            
            % Reconstruct schedule for this date
            [schedule, results] = reconstructHistoricalSchedule(historicalData, dateForFunction, ...
                'TurnoverTime', turnoverTime, 'Debug', false);
            
            % Store schedule and results
            scheduleData = struct();
            scheduleData.schedule = schedule;
            scheduleData.results = results;
            scheduleData.date = dateStr;
            scheduleData.numCases = results.totalCases;
            
            % Store lab mapping information
            if isfield(schedule, 'labMapping')
                scheduleData.labMapping = schedule.labMapping;
                scheduleData.numLabs = schedule.numLabs;
            end
            
            historicalSchedules(dateStr) = scheduleData;
            successCount = successCount + 1;
            
            if debugMode
                fprintf('  %s: %d cases, %.1f hour span\n', dateStr, results.totalCases, results.makespan/60);
            end
            
        catch ME
            if debugMode
                fprintf('  Error processing %s: %s\n', dateStr, ME.message);
            end
            errorCount = errorCount + 1;
        end
        
        % Update progress bar
        if ~debugMode
            progress = i / length(uniqueDates);
            currentProgress = floor(progress * progressLength);
            
            for j = (lastProgress + 1):currentProgress
                fprintf('=');
            end
            lastProgress = currentProgress;
        end
    end
    
    if ~debugMode
        fprintf('] 100%%\n');
    end
    
    fprintf('Schedule reconstruction complete!\n');
    fprintf('  Successfully processed: %d dates\n', successCount);
    if errorCount > 0
        fprintf('  Errors: %d dates\n', errorCount);
    end
    
    % Display summary statistics
    if successCount > 0
        fprintf('\nHistorical Schedule Summary:\n');
        
        % Calculate aggregate statistics
        totalCases = 0;
        totalSpanTime = 0;
        datesWithOvertime = 0;
        scheduleData = values(historicalSchedules);
        
        for i = 1:length(scheduleData)
            data = scheduleData{i};
            totalCases = totalCases + data.results.totalCases;
            totalSpanTime = totalSpanTime + data.results.makespan;
            
            if data.results.scheduleEnd/60 > 18 % After 6 PM
                datesWithOvertime = datesWithOvertime + 1;
            end
        end
        
        fprintf('  Total cases across all dates: %d\n', totalCases);
        fprintf('  Average cases per day: %.1f\n', totalCases / successCount);
        fprintf('  Average schedule span: %.1f hours\n', (totalSpanTime/60) / successCount);
        fprintf('  Days with overtime (past 6 PM): %d (%.1f%%)\n', ...
            datesWithOvertime, (datesWithOvertime / successCount) * 100);
    end
end

function columnName = findColumnByName(availableColumns, possibleNames)
% Helper function to find a column by trying multiple possible names
columnName = '';
for name = possibleNames
    if ismember(name{1}, availableColumns)
        columnName = name{1};
        return;
    end
end
if isempty(columnName)
    error('Could not find column matching any of: %s', strjoin(possibleNames, ', '));
end
end