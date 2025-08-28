function cases = getCasesByDate(targetDate, historicalData)
% Extract cases from historicalEPData for a specific date
% Version: 2.1.0
% 
% Inputs:
%   targetDate - Date string (e.g., '2025-02-15') or datetime object
%   historicalData - Structure from historicalEPData.mat (optional, will load if not provided)
%
% Output:
%   cases - Structure array with fields suitable for scheduleHistoricalCases():
%           operator, caseID, procTime, setupTime, postTime, procedure, location,
%           service, totalRoomTime, date, admissionStatus, priority, preferredLab
%
% Usage Example:
%   % Get cases for a specific date
%   cases = getCasesByDate('2025-02-15');
%   
%   % Schedule the cases
%   [schedule, results] = scheduleHistoricalCases(cases);
%   
%   % Visualize the schedule
%   visualizeSchedule(schedule, results);

% Load historical data if not provided
if nargin < 2 || isempty(historicalData)
    if exist('historicalEPData.mat', 'file')
        fprintf('Loading historical data from historicalEPData.mat...\n');
        load('historicalEPData.mat', 'historicalData');
    else
        error('historicalEPData.mat not found. Run createHistoricalDataMat() first.');
    end
end

% Convert target date to the format stored in historical data (dd-mmm-yyyy)
if ischar(targetDate) || isstring(targetDate)
    % Handle different input formats
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
                targetDate = string(datestr(dt, 'dd-mmm-yyyy'));
                fprintf('Converted input date %s to format: %s\n', targetStr, targetDate);
            catch
                error('Invalid date format. Use MM-DD-YYYY (e.g., "02-15-2025")');
            end
        else
            error('Invalid date format. Use MM-DD-YYYY (e.g., "02-15-2025")');
        end
    else
        % Try to parse as is and convert to expected format
        try
            dt = datetime(targetStr);
            targetDate = string(datestr(dt, 'dd-mmm-yyyy'));
            fprintf('Converted input date %s to format: %s\n', targetStr, targetDate);
        catch
            error('Invalid date format. Use MM-DD-YYYY (e.g., "02-15-2025")');
        end
    end
    
elseif isdatetime(targetDate)
    targetDate = string(datestr(targetDate, 'dd-mmm-yyyy'));
    fprintf('Converted datetime input to format: %s\n', targetDate);
else
    error('targetDate must be a string, char array, or datetime object');
end

% Find cases matching the target date
dateMatches = strcmp(string(historicalData.date), targetDate);
numMatches = sum(dateMatches);

if numMatches == 0
    fprintf('No cases found for date: %s\n', targetDate);
    
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
    
    cases = struct();
    return;
end

fprintf('Found %d cases for date: %s\n', numMatches, targetDate);

% Extract matching cases
matchingIndices = find(dateMatches);
cases = struct();

for i = 1:numMatches
    idx = matchingIndices(i);
    
    % Core scheduling fields (required by scheduler)
    cases(i).operator = char(historicalData.surgeon(idx));
    cases(i).caseID = char(historicalData.caseID(idx));
    cases(i).procTime = historicalData.procedureTime(idx);
    cases(i).setupTime = historicalData.setupTime(idx);
    cases(i).postTime = historicalData.postTime(idx);
    
    % Additional information fields
    cases(i).procedure = char(historicalData.procedure(idx));
    cases(i).location = char(historicalData.location(idx));
    cases(i).service = char(historicalData.service(idx));
    cases(i).totalRoomTime = historicalData.totalRoomTime(idx);
    cases(i).date = char(historicalData.date(idx));
    
    % Admission status
    if isfield(historicalData, 'admissionStatus') && ~isempty(historicalData.admissionStatus)
        cases(i).admissionStatus = char(historicalData.admissionStatus(idx));
    else
        cases(i).admissionStatus = ''; % Default to empty if not available
    end
    
    % Handle missing/invalid times with reasonable defaults
    if isnan(cases(i).procTime) || cases(i).procTime <= 0
        cases(i).procTime = 120; % Default 2 hours
        fprintf('  Warning: Case %s has invalid procedure time, using default 120 min\n', cases(i).caseID);
    end
    
    if isnan(cases(i).setupTime) || cases(i).setupTime <= 0
        cases(i).setupTime = 30; % Default 30 minutes
        fprintf('  Warning: Case %s has invalid setup time, using default 30 min\n', cases(i).caseID);
    end
    
    if isnan(cases(i).postTime) || cases(i).postTime <= 0
        cases(i).postTime = 15; % Default 15 minutes
        fprintf('  Warning: Case %s has invalid post time, using default 15 min\n', cases(i).caseID);
    end
    
    % Priority and lab preference fields (empty by default)
    % Priority values:
    %   - Empty/missing: Normal scheduling order
    %   - 1: Must be first case for this operator (any lab)
    %   - Higher numbers: Higher priority in scheduling order
    cases(i).priority = []; % No default priority
    cases(i).preferredLab = []; % No default lab preference
end

% Display summary
fprintf('\nCase Summary for %s:\n', targetDate);

% Operator summary
operators = {cases.operator};
uniqueOperators = unique(operators);
fprintf('  Operators (%d): ', length(uniqueOperators));
for op = uniqueOperators
    opCases = sum(strcmp(operators, op));
    fprintf('%s(%d) ', op{1}, opCases);
end
fprintf('\n');

% Procedure summary
procedures = {cases.procedure};
uniqueProcedures = unique(procedures);
fprintf('  Procedure Types (%d):\n', length(uniqueProcedures));
for proc = uniqueProcedures
    procCases = sum(strcmp(procedures, proc));
    fprintf('    %s: %d cases\n', proc{1}, procCases);
end

% Time summary
totalProcTime = sum([cases.procTime]);
totalSetupTime = sum([cases.setupTime]);
totalPostTime = sum([cases.postTime]);
totalTime = totalSetupTime + totalProcTime + totalPostTime;

fprintf('  Time Summary:\n');
fprintf('    Total Procedure Time: %.1f hours\n', totalProcTime/60);
fprintf('    Total Setup Time: %.1f hours\n', totalSetupTime/60);
fprintf('    Total Post Time: %.1f hours\n', totalPostTime/60);
fprintf('    Grand Total: %.1f hours\n', totalTime/60);
fprintf('    Average Case Duration: %.1f minutes\n', mean([cases.procTime]));

% Location summary
locations = {cases.location};
uniqueLocations = unique(locations);
fprintf('  Locations: ');
for loc = uniqueLocations
    locCases = sum(strcmp(locations, loc));
    fprintf('%s(%d) ', loc{1}, locCases);
end
fprintf('\n');

% Admission status summary
admissionStatuses = {cases.admissionStatus};
nonEmptyStatuses = admissionStatuses(~cellfun(@isempty, admissionStatuses));
if ~isempty(nonEmptyStatuses)
    uniqueStatuses = unique(nonEmptyStatuses);
    fprintf('  Admission Status: ');
    for status = uniqueStatuses
        statusCases = sum(strcmp(admissionStatuses, status));
        fprintf('%s(%d) ', status{1}, statusCases);
    end
    fprintf('\n');
else
    fprintf('  Admission Status: Not available\n');
end

fprintf('\nCases structure created with %d cases ready for EP scheduler.\n', numMatches);

end