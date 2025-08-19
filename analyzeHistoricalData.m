function analyzeHistoricalData(historicalData, varargin)
% Analyzes historical procedure data structure
% Focuses purely on statistical analysis and insights
% Does NOT perform any schedule reconstruction or optimization
%
% Usage:
%   analyzeHistoricalData(historicalData)
%   analyzeHistoricalData(historicalData, 'ShowStats', true)
%   analyzeHistoricalData(historicalData, 'SaveReport', true, 'ReportFile', 'analysis_report.txt')
%
% Inputs:
%   historicalData - Historical data structure from loadHistoricalDataFromFile
%
% Parameters:
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
showStats = true;
saveReport = false;
reportFile = 'historical_analysis_report.txt';

% Parse optional parameters
i = 1;
while i <= length(varargin)
    if ischar(varargin{i}) || isstring(varargin{i})
        switch lower(char(varargin{i}))
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