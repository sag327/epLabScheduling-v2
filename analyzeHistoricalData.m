function historicalData = analyzeHistoricalData(varargin)
% Loads and analyzes historical procedure data from Excel file
% Focuses purely on data loading, cleaning, and statistical analysis
% Does NOT perform any schedule reconstruction or optimization
%
% Usage:
%   historicalData = analyzeHistoricalData()  % Uses default 'procedureDurationsB.xlsx'
%   historicalData = analyzeHistoricalData('path/to/mydata.xlsx')
%   historicalData = analyzeHistoricalData('FilePath', 'path/to/mydata.xlsx')
%   historicalData = analyzeHistoricalData('FilePath', 'data.xlsx', 'ShowStats', false)
%
% Parameters:
%   FilePath - Path to Excel file containing historical procedure data
%              Default: 'procedureDurationsB.xlsx'
%   ShowStats - Whether to display detailed statistics (default: true)
%   SaveData - Whether to save data to .mat file (default: true)
%
% Outputs:
%   historicalData - Cleaned historical data structure with analysis

% Parse input arguments
p = inputParser;
addOptional(p, 'FilePath', 'procedureDurationsB.xlsx', @(x) ischar(x) || isstring(x));
addParameter(p, 'ShowStats', true, @islogical);
addParameter(p, 'SaveData', true, @islogical);
parse(p, varargin{:});

filename = char(p.Results.FilePath);
showStats = p.Results.ShowStats;
saveData = p.Results.SaveData;

fprintf('=== HISTORICAL DATA ANALYSIS ===\n');
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
    
    if showStats
        % Show actual MATLAB variable names
        fprintf('\nColumn Analysis:\n');
        for i = 1:length(rawData.Properties.VariableNames)
            fprintf('  %d: %s\n', i, rawData.Properties.VariableNames{i});
        end
    end
    
catch ME
    error('Error reading Excel file: %s', ME.message);
end

% Create cleaned data structure with human-readable field names
historicalData = struct();

% Helper function to find column dynamically
findColumn = @(possibleNames) findColumnByName(rawData.Properties.VariableNames, possibleNames);

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
    fprintf('Warning: No admission status column found, using empty values\n');
end

% Time measurements (all in minutes)
historicalData.setupTime = rawData.(findColumn({'In_Room_to_Procedure_Start_Minutes', 'InRoomToProcedureStart_Minutes_', 'In Room to Procedure Start (Minutes)'}));
historicalData.procedureTime = rawData.(findColumn({'Procedure_Start_to_Procedure_Complete_Minutes', 'ProcedureStartToProcedureComplete_Minutes_', 'Procedure Start to Procedure Complete (Minutes)'}));
historicalData.postTime = rawData.(findColumn({'Procedure_Complete_to_Out_of_Room_Minutes', 'ProcedureCompleteToOutOfRoom_Minutes_', 'Procedure Complete to Out of Room (Minutes)'}));
historicalData.totalRoomTime = rawData.(findColumn({'In_Room_to_Out_of_Room_Minutes', 'InRoomToOutOfRoom_Minutes_', 'In Room to Out of Room (Minutes)'}));
historicalData.anesthesiaTime = rawData.(findColumn({'In_Room_to_Anesthesia_Induction_Minutes', 'InRoomToAnesthesiaInduction_Minutes_', 'In Room to Anesthesia Induction (Minutes)'}));

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

% Perform detailed statistical analysis
if showStats
    performDetailedAnalysis(historicalData);
end

% Save data if requested
if saveData
    % Save to .mat file
    outputFile = './data/historicalEPData_analysis.mat';
    if ~isfolder('./data')
        mkdir('./data');
    end
    save(outputFile, 'historicalData');
    fprintf('\nAnalysis data saved to %s\n', outputFile);
    
    % Create and save field descriptions
    fieldDescriptions = createFieldDescriptions();
    save('./data/historicalEPDataDescriptions_analysis.mat', 'fieldDescriptions');
    fprintf('Field descriptions saved to historicalEPDataDescriptions_analysis.mat\n');
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

%% Helper Functions
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

function fieldDescriptions = createFieldDescriptions()
% Create field description structure
fieldDescriptions = struct();
fieldDescriptions.caseID = 'Unique case identifier';
fieldDescriptions.date = 'Procedure date';
fieldDescriptions.surgeon = 'Primary surgeon/operator';
fieldDescriptions.procedure = 'Type of procedure performed';
fieldDescriptions.service = 'Medical service (typically Cardiovascular)';
fieldDescriptions.location = 'EP lab location';
fieldDescriptions.room = 'Room assignment for the procedure';
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
end