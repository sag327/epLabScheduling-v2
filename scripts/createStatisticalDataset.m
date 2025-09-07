function statisticalData = createStatisticalDataset(analysisResults, varargin)
% Create a comprehensive statistical dataset for predictive modeling
% Version: 3.0.0
%
% This function consolidates comprehensive operator metrics into a structured format
% suitable for statistical analysis, regression modeling, and machine learning.
% REQUIRES comprehensive metrics from analyzeHistoricalData.m (no fallback support).
%
% Inputs:
%   analysisResults - Results structure from analyzeHistoricalData.m with comprehensiveOperatorMetrics
%
% Optional Parameters:
%   'ExportToCSV' - Export to CSV file (default: false)
%   'ExportToTable' - Export to MATLAB table (default: true)
%   'OutputFile' - CSV filename (default: 'statistical_dataset.csv')
%   'IncludeCorrelations' - Include correlation matrix (default: true)
%   'Verbose' - Show detailed output (default: true)
%
% Output:
%   statisticalData - Structure containing:
%     .operatorTable - Main table with one row per operator
%     .summaryStats - Summary statistics for all variables
%     .correlationMatrix - Correlation matrix of numeric variables
%     .variableDescriptions - Description of each variable
%     .exportFiles - List of exported files
%
% Example:
%   % Load and analyze data
%   load('data/historicalEPData.mat');
%   analysisResults = analyzeHistoricalData(historicalData);
%   
%   % Create statistical dataset (now includes comprehensive metrics automatically)
%   statData = createStatisticalDataset(analysisResults, ...
%       'ExportToCSV', true, 'OutputFile', 'ep_lab_stats.csv');
%   
%   % Access the data
%   operatorData = statData.operatorTable;
%   correlations = statData.correlationMatrix;

% Parse input parameters
p = inputParser;
addRequired(p, 'analysisResults', @isstruct);
addParameter(p, 'ExportToCSV', false, @islogical);
addParameter(p, 'ExportToTable', true, @islogical);
addParameter(p, 'OutputFile', 'statistical_dataset.csv', @ischar);
addParameter(p, 'IncludeCorrelations', true, @islogical);
addParameter(p, 'Verbose', true, @islogical);

parse(p, analysisResults, varargin{:});

exportToCSV = p.Results.ExportToCSV;
exportToTable = p.Results.ExportToTable;
outputFile = p.Results.OutputFile;
includeCorrelations = p.Results.IncludeCorrelations;
verbose = p.Results.Verbose;

% Initialize output structure
statisticalData = struct();
statisticalData.exportFiles = {};

if verbose
    fprintf('Creating comprehensive statistical dataset...\n');
end

% Validate input - look for comprehensive metrics first, then fall back to basic analysis
if isfield(analysisResults, 'comprehensiveOperatorMetrics') && ~isempty(analysisResults.comprehensiveOperatorMetrics)
    % Use the enhanced comprehensive metrics
    comprehensiveMetrics = analysisResults.comprehensiveOperatorMetrics;
    operatorNames = fieldnames(comprehensiveMetrics);
    
    if verbose
    fprintf('Using comprehensive operator metrics from enhanced analysis\n');
    end
    
else
    error('analysisResults must contain comprehensiveOperatorMetrics. Run analyzeHistoricalData.m to generate comprehensive metrics.');
end

numOperators = length(operatorNames);

if verbose
    fprintf('Processing %d operators...\n', numOperators);
end

% Initialize data collection arrays
data = struct();

% Primary identifiers
data.OperatorName = cell(numOperators, 1);
data.OperatorID = (1:numOperators)';
data.OperatorGroup = cell(numOperators, 1); % categorical/group label (from hardcoded mapping)

% Working pattern metrics
data.TotalWorkingDays = zeros(numOperators, 1);
data.TotalCases = zeros(numOperators, 1);
data.AvgCasesPerDay = zeros(numOperators, 1);
data.MedianCasesPerDay = zeros(numOperators, 1);
data.StdCasesPerDay = zeros(numOperators, 1);

% Time-based performance metrics
data.AvgIdleTimePerDay = NaN(numOperators, 1);
data.MedianIdleTimePerDay = NaN(numOperators, 1);
data.StdIdleTimePerDay = NaN(numOperators, 1);
data.P25IdleTimePerDay = NaN(numOperators, 1);
data.P75IdleTimePerDay = NaN(numOperators, 1);
data.P90IdleTimePerDay = NaN(numOperators, 1);
data.MinIdleTimePerDay = NaN(numOperators, 1);
data.MaxIdleTimePerDay = NaN(numOperators, 1);
data.AvgOvertimePerDay = zeros(numOperators, 1);
data.MedianOvertimePerDay = zeros(numOperators, 1);
data.StdOvertimePerDay = zeros(numOperators, 1);
data.AvgWorkTimePerDay = NaN(numOperators, 1);
data.MedianWorkTimePerDay = NaN(numOperators, 1);

% Efficiency metrics
data.AvgFlipToTurnoverRatio = NaN(numOperators, 1);
data.MedianFlipToTurnoverRatio = NaN(numOperators, 1);
data.StdFlipToTurnoverRatio = NaN(numOperators, 1);
data.P25FlipToTurnoverRatio = NaN(numOperators, 1);
data.P75FlipToTurnoverRatio = NaN(numOperators, 1);
data.P90FlipToTurnoverRatio = NaN(numOperators, 1);
data.MinFlipToTurnoverRatio = NaN(numOperators, 1);
data.MaxFlipToTurnoverRatio = NaN(numOperators, 1);
data.AvgCasesPerHour = zeros(numOperators, 1);
data.UtilizationRate = NaN(numOperators, 1);

% Idle time per turnover metrics (key efficiency indicators)
data.AvgIdleTimePerTurnover = NaN(numOperators, 1);
data.MedianIdleTimePerTurnover = NaN(numOperators, 1);
data.StdIdleTimePerTurnover = NaN(numOperators, 1);
data.P25IdleTimePerTurnover = NaN(numOperators, 1);
data.P75IdleTimePerTurnover = NaN(numOperators, 1);
data.P90IdleTimePerTurnover = NaN(numOperators, 1);
data.MinIdleTimePerTurnover = NaN(numOperators, 1);
data.MaxIdleTimePerTurnover = NaN(numOperators, 1);

% Multi-procedure day metrics
data.MultiProcedureDays = zeros(numOperators, 1);
data.MultiProcedureDaysPct = zeros(numOperators, 1);
data.DaysWithOvertime = zeros(numOperators, 1);
data.DaysWithOvertimePct = zeros(numOperators, 1);

% Case mix metrics - Inpatient/Outpatient proportions
data.InpatientCases = zeros(numOperators, 1);
data.OutpatientCases = zeros(numOperators, 1);
data.InpatientProportion = zeros(numOperators, 1);
data.OutpatientProportion = zeros(numOperators, 1);

% Procedure diversity metrics
data.UniqueProcedureTypes = zeros(numOperators, 1);
data.ProcedureDiversityIndex = zeros(numOperators, 1); % Shannon diversity

% Overall procedure time metrics
data.AvgProcedureTime = NaN(numOperators, 1);
data.MedianProcedureTime = NaN(numOperators, 1);
data.StdProcedureTime = NaN(numOperators, 1);
data.P25ProcedureTime = NaN(numOperators, 1);
data.P75ProcedureTime = NaN(numOperators, 1);
data.P90ProcedureTime = NaN(numOperators, 1);

% Overall setup and post time metrics
data.AvgSetupTime = NaN(numOperators, 1);
data.MedianSetupTime = NaN(numOperators, 1);
data.StdSetupTime = NaN(numOperators, 1);
data.AvgPostTime = NaN(numOperators, 1);
data.MedianPostTime = NaN(numOperators, 1);
data.StdPostTime = NaN(numOperators, 1);

% Initialize procedure-specific metrics arrays
procedureTypes = {};
if isfield(analysisResults, 'procedureAnalysis')
    procedureTypes = fieldnames(analysisResults.procedureAnalysis);
end

% Create procedure-specific metric fields
for proc = 1:length(procedureTypes)
    procName = procedureTypes{proc};
    safeProcName = matlab.lang.makeValidName(['Proc_' procName]);
    
    % Count and proportion
    data.([safeProcName '_Count']) = zeros(numOperators, 1);
    data.([safeProcName '_Proportion']) = zeros(numOperators, 1);
    
    % Duration metrics
    data.([safeProcName '_AvgDuration']) = NaN(numOperators, 1);
    data.([safeProcName '_MedianDuration']) = NaN(numOperators, 1);
    data.([safeProcName '_StdDuration']) = NaN(numOperators, 1);
    
    % Setup time metrics
    data.([safeProcName '_AvgSetup']) = NaN(numOperators, 1);
    data.([safeProcName '_MedianSetup']) = NaN(numOperators, 1);
    
    % Post time metrics
    data.([safeProcName '_AvgPost']) = NaN(numOperators, 1);
    data.([safeProcName '_MedianPost']) = NaN(numOperators, 1);
end

% Process each operator
if verbose
    fprintf('Extracting metrics for each operator:\n');
end

% Collect operator group names for one-hot encoding after loop
operatorGroupNames = cell(numOperators, 1);

for i = 1:numOperators
    opName = operatorNames{i};
    
    if verbose
    fprintf('  %s (%d/%d)\n', opName, i, numOperators);
    end
    
    % Basic identifiers
    data.OperatorName{i} = opName;
    
    %% EXTRACT FROM COMPREHENSIVE METRICS
    opMetrics = comprehensiveMetrics.(opName);

    % Operator group label from analysis results (robust coercion)
    if isfield(opMetrics, 'operatorGroup') && ~isempty(opMetrics.operatorGroup)
        grp = opMetrics.operatorGroup;
        try
            if iscategorical(grp)
                grp = string(grp);
            end
            if isstring(grp)
                if ~ismissing(grp) && strlength(grp) > 0
                    grp = char(grp);
                else
                    grp = 'Other';
                end
            elseif ~ischar(grp)
                s = string(grp);
                if ~ismissing(s) && strlength(s) > 0
                    grp = char(s);
                else
                    grp = 'Other';
                end
            end
        catch
            grp = 'Other';
        end
        data.OperatorGroup{i} = grp;
        operatorGroupNames{i} = grp;
    else
        data.OperatorGroup{i} = 'Other';
        operatorGroupNames{i} = 'Other';
    end
    
    % Basic working pattern metrics
    data.TotalCases(i) = getField(opMetrics, 'totalCases', 0);
    data.TotalWorkingDays(i) = getField(opMetrics, 'workingDays', 0);
    data.AvgCasesPerDay(i) = getField(opMetrics, 'avgCasesPerDay', 0);
    data.MedianCasesPerDay(i) = getField(opMetrics, 'medianCasesPerDay', 0);
    data.StdCasesPerDay(i) = getField(opMetrics, 'stdCasesPerDay', 0);
    
    % Time-based performance metrics
    data.AvgIdleTimePerDay(i) = getField(opMetrics, 'avgIdleTimePerDay', NaN);
    data.MedianIdleTimePerDay(i) = getField(opMetrics, 'medianIdleTimePerDay', NaN);
    data.StdIdleTimePerDay(i) = getField(opMetrics, 'stdIdleTimePerDay', NaN);
    data.P25IdleTimePerDay(i) = getField(opMetrics, 'p25IdleTimePerDay', NaN);
    data.P75IdleTimePerDay(i) = getField(opMetrics, 'p75IdleTimePerDay', NaN);
    data.P90IdleTimePerDay(i) = getField(opMetrics, 'p90IdleTimePerDay', NaN);
    data.MinIdleTimePerDay(i) = getField(opMetrics, 'minIdleTimePerDay', NaN);
    data.MaxIdleTimePerDay(i) = getField(opMetrics, 'maxIdleTimePerDay', NaN);
    data.AvgOvertimePerDay(i) = getField(opMetrics, 'avgOvertimePerDay', 0);
    data.MedianOvertimePerDay(i) = getField(opMetrics, 'medianOvertimePerDay', 0);
    data.StdOvertimePerDay(i) = getField(opMetrics, 'stdOvertimePerDay', 0);
    data.AvgWorkTimePerDay(i) = getField(opMetrics, 'avgWorkTimePerDay', NaN);
    data.MedianWorkTimePerDay(i) = getField(opMetrics, 'medianWorkTimePerDay', NaN);
    
    % Efficiency metrics
    data.AvgFlipToTurnoverRatio(i) = getField(opMetrics, 'avgFlipToTurnoverRatio', NaN);
    data.MedianFlipToTurnoverRatio(i) = getField(opMetrics, 'medianFlipToTurnoverRatio', NaN);
    data.StdFlipToTurnoverRatio(i) = getField(opMetrics, 'stdFlipToTurnoverRatio', NaN);
    data.P25FlipToTurnoverRatio(i) = getField(opMetrics, 'p25FlipToTurnoverRatio', NaN);
    data.P75FlipToTurnoverRatio(i) = getField(opMetrics, 'p75FlipToTurnoverRatio', NaN);
    data.P90FlipToTurnoverRatio(i) = getField(opMetrics, 'p90FlipToTurnoverRatio', NaN);
    data.MinFlipToTurnoverRatio(i) = getField(opMetrics, 'minFlipToTurnoverRatio', NaN);
    data.MaxFlipToTurnoverRatio(i) = getField(opMetrics, 'maxFlipToTurnoverRatio', NaN);
    data.AvgCasesPerHour(i) = getField(opMetrics, 'avgCasesPerHour', 0);
    data.UtilizationRate(i) = getField(opMetrics, 'utilizationRate', NaN);
    
    % Idle time per turnover metrics (key efficiency indicators)
    data.AvgIdleTimePerTurnover(i) = getField(opMetrics, 'avgIdleTimePerTurnover', NaN);
    data.MedianIdleTimePerTurnover(i) = getField(opMetrics, 'medianIdleTimePerTurnover', NaN);
    data.StdIdleTimePerTurnover(i) = getField(opMetrics, 'stdIdleTimePerTurnover', NaN);
    data.P25IdleTimePerTurnover(i) = getField(opMetrics, 'p25IdleTimePerTurnover', NaN);
    data.P75IdleTimePerTurnover(i) = getField(opMetrics, 'p75IdleTimePerTurnover', NaN);
    data.P90IdleTimePerTurnover(i) = getField(opMetrics, 'p90IdleTimePerTurnover', NaN);
    data.MinIdleTimePerTurnover(i) = getField(opMetrics, 'minIdleTimePerTurnover', NaN);
    data.MaxIdleTimePerTurnover(i) = getField(opMetrics, 'maxIdleTimePerTurnover', NaN);
    
    % Multi-procedure day metrics
    data.MultiProcedureDays(i) = getField(opMetrics, 'multiProcedureDays', 0);
    data.MultiProcedureDaysPct(i) = getField(opMetrics, 'multiProcedureDaysPct', 0);
    data.DaysWithOvertime(i) = getField(opMetrics, 'daysWithOvertime', 0);
    data.DaysWithOvertimePct(i) = getField(opMetrics, 'daysWithOvertimePct', 0);
    
    % Case mix metrics
    data.InpatientCases(i) = getField(opMetrics, 'inpatientCases', 0);
    data.OutpatientCases(i) = getField(opMetrics, 'outpatientCases', 0);
    data.InpatientProportion(i) = getField(opMetrics, 'inpatientProportion', 0);
    data.OutpatientProportion(i) = getField(opMetrics, 'outpatientProportion', 0);
    
    % Procedure diversity metrics
    data.UniqueProcedureTypes(i) = getField(opMetrics, 'uniqueProcedureTypes', 0);
    data.ProcedureDiversityIndex(i) = getField(opMetrics, 'procedureDiversityIndex', 0);
    
    % Overall procedure time metrics
    data.AvgProcedureTime(i) = getField(opMetrics, 'avgProcedureTime', NaN);
    data.MedianProcedureTime(i) = getField(opMetrics, 'medianProcedureTime', NaN);
    data.StdProcedureTime(i) = getField(opMetrics, 'stdProcedureTime', NaN);
    data.P25ProcedureTime(i) = getField(opMetrics, 'p25ProcedureTime', NaN);
    data.P75ProcedureTime(i) = getField(opMetrics, 'p75ProcedureTime', NaN);
    data.P90ProcedureTime(i) = getField(opMetrics, 'p90ProcedureTime', NaN);
    
    % Overall setup and post time metrics
    data.AvgSetupTime(i) = getField(opMetrics, 'avgSetupTime', NaN);
    data.MedianSetupTime(i) = getField(opMetrics, 'medianSetupTime', NaN);
    data.StdSetupTime(i) = getField(opMetrics, 'stdSetupTime', NaN);
    data.AvgPostTime(i) = getField(opMetrics, 'avgPostTime', NaN);
    data.MedianPostTime(i) = getField(opMetrics, 'medianPostTime', NaN);
    data.StdPostTime(i) = getField(opMetrics, 'stdPostTime', NaN);
    
    % Extract procedure-specific metrics dynamically
    metricFields = fieldnames(opMetrics);
    procSpecificFields = metricFields(startsWith(metricFields, 'proc_'));
    
    for f = 1:length(procSpecificFields)
        fieldName = procSpecificFields{f};
        % Convert to standard naming convention
        standardName = regexprep(fieldName, '^proc_', 'Proc_');
        
        % Initialize field if it doesn't exist
        if ~isfield(data, standardName)
            data.(standardName) = NaN(numOperators, 1);
        end
        
        data.(standardName)(i) = opMetrics.(fieldName);
    end
end

% Sanitize OperatorGroup values to avoid empty numeric cells (ensure text labels)
for i = 1:numOperators
    g = data.OperatorGroup{i};
    if isstring(g)
        if ismissing(g) || strlength(g) == 0
            data.OperatorGroup{i} = 'Other';
        else
            data.OperatorGroup{i} = char(g);
        end
    elseif ischar(g)
        if isempty(g)
            data.OperatorGroup{i} = 'Other';
        end
    elseif iscategorical(g)
        if isundefined(g)
            data.OperatorGroup{i} = 'Other';
        else
            data.OperatorGroup{i} = char(string(g));
        end
    else
        % Any non-text type defaults to 'Other'
        data.OperatorGroup{i} = 'Other';
    end
end

% Create one-hot encoded group variables for multivariate analysis
% Normalize group names defensively to avoid string conversion errors
cleanGroups = cell(numOperators, 1);
for i = 1:numOperators
    g = operatorGroupNames{i};
    try
        if isstring(g)
            gs = strtrim(g);
            if strlength(gs) == 0
                cleanGroups{i} = 'Other';
            else
                cleanGroups{i} = char(gs);
            end
        elseif ischar(g)
            if isempty(strtrim(g))
                cleanGroups{i} = 'Other';
            else
                cleanGroups{i} = strtrim(g);
            end
        else
            % Attempt conversion; fallback to 'Other' on failure
            gs = string(g);
            if ismissing(gs) || strlength(gs) == 0
                cleanGroups{i} = 'Other';
            else
                cleanGroups{i} = char(gs);
            end
        end
    catch
        cleanGroups{i} = 'Other';
    end
end

uniqueGroups = unique(string(cleanGroups));
uniqueGroups = uniqueGroups(~ismissing(uniqueGroups) & uniqueGroups ~= "");
for g = 1:length(uniqueGroups)
    gName = char(uniqueGroups(g));
    safeField = matlab.lang.makeValidName(['Group_' gName]);
    data.(safeField) = zeros(numOperators, 1);
    for i = 1:numOperators
        if strcmpi(data.OperatorGroup{i}, gName)
            data.(safeField)(i) = 1;
        end
    end
end

%% Helper function for safe field access
function value = getField(structure, fieldName, defaultValue)
    if isfield(structure, fieldName)
    value = structure.(fieldName);
    if isempty(value)
        value = defaultValue;
    end
    else
    value = defaultValue;
    end
end

if verbose
    fprintf('Creating data table and calculating summary statistics...\n');
end

% Convert to table if requested
if exportToTable
    try
    % Ensure all fields have the same number of rows and compatible types
    fieldNames = fieldnames(data);
    for f = 1:length(fieldNames)
        fieldData = data.(fieldNames{f});
        
        % Handle different field types
        if iscell(fieldData)
            % Ensure cell array has correct length
            if length(fieldData) < numOperators
                % Pad with empty strings
                fieldData((length(fieldData)+1):numOperators) = {''};
            elseif length(fieldData) > numOperators
                fieldData = fieldData(1:numOperators);
            end
            % Ensure it's a column vector
            if size(fieldData, 2) > size(fieldData, 1)
                fieldData = fieldData';
            end
            
        elseif isnumeric(fieldData) || islogical(fieldData)
            % Ensure numeric array has correct length
            if length(fieldData) < numOperators
                if isnumeric(fieldData)
                    fieldData((length(fieldData)+1):numOperators) = NaN;
                else
                    fieldData((length(fieldData)+1):numOperators) = false;
                end
            elseif length(fieldData) > numOperators
                fieldData = fieldData(1:numOperators);
            end
            % Ensure it's a column vector
            if size(fieldData, 2) > size(fieldData, 1)
                fieldData = fieldData';
            end
            
        else
            % For other types, convert to string if possible
            if ~iscell(fieldData)
                if ischar(fieldData) || isstring(fieldData)
                    fieldData = cellstr(fieldData);
                else
                    fieldData = repmat({''}, numOperators, 1);
                end
            end
        end
        
        data.(fieldNames{f}) = fieldData;
    end
    
    statisticalData.operatorTable = struct2table(data);
    % Ensure OperatorGroup is a categorical/text variable (not coerced to numeric)
    if ismember('OperatorGroup', statisticalData.operatorTable.Properties.VariableNames)
        og = statisticalData.operatorTable.OperatorGroup;
        % Convert cellstr or string to categorical
        if iscell(og)
            statisticalData.operatorTable.OperatorGroup = categorical(og);
        elseif isstring(og)
            statisticalData.operatorTable.OperatorGroup = categorical(cellstr(og));
        elseif iscategorical(og)
            % already categorical
        else
            % Fallback: make categorical from char array or other types
            try
                statisticalData.operatorTable.OperatorGroup = categorical(cellstr(og));
            catch
                % As a last resort, set to 'Other'
                statisticalData.operatorTable.OperatorGroup = categorical(repmat({'Other'}, height(statisticalData.operatorTable), 1));
            end
        end
    end
    
    catch ME
    if verbose
        fprintf('Warning: Could not create table - %s\n', ME.message);
        fprintf('Returning data as structure instead\n');
    end
    statisticalData.operatorTable = data;
    end
    
    % Add variable descriptions
    statisticalData.variableDescriptions = createVariableDescriptions(procedureTypes);
end

% Calculate summary statistics
statisticalData.summaryStats = calculateSummaryStatistics(data, verbose);

% Calculate correlation matrix if requested
if includeCorrelations
    if verbose
    fprintf('Calculating correlation matrix...\n');
    end
    statisticalData.correlationMatrix = calculateCorrelationMatrix(data, verbose);
end

% Export to CSV if requested
if exportToCSV
    if verbose
    fprintf('Exporting to CSV file: %s\n', outputFile);
    end
    
    % Prefer writing the prepared operatorTable if it exists and is a table
    if exportToTable && isfield(statisticalData, 'operatorTable') && istable(statisticalData.operatorTable)
        writetable(statisticalData.operatorTable, outputFile);
    else
        % Convert struct to table for CSV export (robust fallback)
        try
            tempTable = struct2table(data);
            % Ensure OperatorGroup is categorical/text for export
            if ismember('OperatorGroup', tempTable.Properties.VariableNames)
                og = tempTable.OperatorGroup;
                if iscell(og)
                    tempTable.OperatorGroup = categorical(og);
                elseif isstring(og)
                    tempTable.OperatorGroup = categorical(cellstr(og));
                elseif ~iscategorical(og)
                    tempTable.OperatorGroup = categorical(repmat({'Other'}, height(tempTable), 1));
                end
            end
            writetable(tempTable, outputFile);
        catch ME
            warning('Falling back to writestruct for export due to: %s', ME.message);
            try
                % writestruct requires JSON or XML; switch to JSON alongside CSV base name
                [outDir, outName, ~] = fileparts(outputFile);
                if isempty(outDir); outDir = pwd; end
                jsonFile = fullfile(outDir, [outName '.json']);
                writestruct(data, jsonFile, 'FileType', 'json');
                % Update outputFile to reflect actual exported file
                outputFile = jsonFile;
            catch ME2
                error('Failed to export dataset: %s', ME2.message);
            end
        end
    end
    
    statisticalData.exportFiles{end+1} = outputFile;
    
    % Also export variable descriptions
    [~, name, ~] = fileparts(outputFile);
    descFile = [name '_variable_descriptions.txt'];
    exportVariableDescriptions(statisticalData.variableDescriptions, descFile);
    statisticalData.exportFiles{end+1} = descFile;
end

% Mark first todo as completed and move to next
if verbose
    fprintf('\nStatistical dataset creation completed successfully!\n');
    fprintf('Dataset contains %d operators and %d variables\n', numOperators, length(fieldnames(data)));
    if ~isempty(statisticalData.exportFiles)
    fprintf('Exported files:\n');
    for i = 1:length(statisticalData.exportFiles)
        fprintf('  %s\n', statisticalData.exportFiles{i});
    end
    end
end

end

%% Helper Functions

function descriptions = createVariableDescriptions(procedureTypes)
% Create descriptions for all variables in the dataset

descriptions = struct();
descriptions.OperatorName = 'Name/identifier of the operator';
descriptions.OperatorID = 'Numeric ID for the operator';
descriptions.OperatorGroup = 'Operator group label (hardcoded mapping; default "Other")';

% Working pattern metrics
descriptions.TotalWorkingDays = 'Total number of working days in dataset';
descriptions.TotalCases = 'Total number of cases performed';
descriptions.AvgCasesPerDay = 'Average number of cases per working day';
descriptions.MedianCasesPerDay = 'Median number of cases per working day';
descriptions.StdCasesPerDay = 'Standard deviation of cases per day';

% Time-based performance metrics
descriptions.AvgIdleTimePerDay = 'Average idle time per day (minutes)';
descriptions.MedianIdleTimePerDay = 'Median idle time per day (minutes)';
descriptions.StdIdleTimePerDay = 'Standard deviation of idle time per day (minutes)';
descriptions.P25IdleTimePerDay = '25th percentile of idle time per day (minutes)';
descriptions.P75IdleTimePerDay = '75th percentile of idle time per day (minutes)';
descriptions.P90IdleTimePerDay = '90th percentile of idle time per day (minutes)';
descriptions.MinIdleTimePerDay = 'Minimum idle time per day (minutes)';
descriptions.MaxIdleTimePerDay = 'Maximum idle time per day (minutes)';
descriptions.AvgOvertimePerDay = 'Average overtime per day (minutes)';
descriptions.MedianOvertimePerDay = 'Median overtime per day (minutes)';
descriptions.StdOvertimePerDay = 'Standard deviation of overtime per day';
descriptions.AvgWorkTimePerDay = 'Average total work time per day (minutes)';
descriptions.MedianWorkTimePerDay = 'Median total work time per day (minutes)';

% Efficiency metrics
descriptions.AvgFlipToTurnoverRatio = 'Average flip-to-turnover ratio (%)';
descriptions.MedianFlipToTurnoverRatio = 'Median flip-to-turnover ratio (%)';
descriptions.StdFlipToTurnoverRatio = 'Standard deviation of flip-to-turnover ratio (%)';
descriptions.P25FlipToTurnoverRatio = '25th percentile of flip-to-turnover ratio (%)';
descriptions.P75FlipToTurnoverRatio = '75th percentile of flip-to-turnover ratio (%)';
descriptions.P90FlipToTurnoverRatio = '90th percentile of flip-to-turnover ratio (%)';
descriptions.MinFlipToTurnoverRatio = 'Minimum flip-to-turnover ratio (%)';
descriptions.MaxFlipToTurnoverRatio = 'Maximum flip-to-turnover ratio (%)';
descriptions.AvgCasesPerHour = 'Average cases processed per hour';
descriptions.UtilizationRate = 'Overall utilization rate (0-1)';

% Idle time per turnover metrics (key efficiency indicators)
descriptions.AvgIdleTimePerTurnover = 'Average idle time per case turnover (minutes) - key efficiency metric';
descriptions.MedianIdleTimePerTurnover = 'Median idle time per case turnover (minutes) - key efficiency metric';
descriptions.StdIdleTimePerTurnover = 'Standard deviation of idle time per turnover (minutes)';
descriptions.P25IdleTimePerTurnover = '25th percentile of idle time per turnover (minutes)';
descriptions.P75IdleTimePerTurnover = '75th percentile of idle time per turnover (minutes)';
descriptions.P90IdleTimePerTurnover = '90th percentile of idle time per turnover (minutes)';
descriptions.MinIdleTimePerTurnover = 'Minimum idle time per turnover (minutes)';
descriptions.MaxIdleTimePerTurnover = 'Maximum idle time per turnover (minutes)';

% Multi-procedure day metrics
descriptions.MultiProcedureDays = 'Number of days with multiple procedures';
descriptions.MultiProcedureDaysPct = 'Percentage of days with multiple procedures';
descriptions.DaysWithOvertime = 'Number of days with overtime';
descriptions.DaysWithOvertimePct = 'Percentage of days with overtime';

% Case mix metrics
descriptions.InpatientCases = 'Number of inpatient cases';
descriptions.OutpatientCases = 'Number of outpatient cases';
descriptions.InpatientProportion = 'Proportion of cases that are inpatient (0-1)';
descriptions.OutpatientProportion = 'Proportion of cases that are outpatient (0-1)';

% Procedure diversity
descriptions.UniqueProcedureTypes = 'Number of unique procedure types performed';
descriptions.ProcedureDiversityIndex = 'Shannon diversity index for procedure types';

% Procedure-specific metrics
for proc = 1:length(procedureTypes)
    procName = procedureTypes{proc};
    safeProcName = matlab.lang.makeValidName(['Proc_' procName]);
    
    descriptions.([safeProcName '_Count']) = sprintf('Number of %s procedures', procName);
    descriptions.([safeProcName '_Proportion']) = sprintf('Proportion of cases that are %s', procName);
    descriptions.([safeProcName '_AvgDuration']) = sprintf('Average duration for %s (minutes)', procName);
    descriptions.([safeProcName '_MedianDuration']) = sprintf('Median duration for %s (minutes)', procName);
    descriptions.([safeProcName '_StdDuration']) = sprintf('Std deviation of duration for %s', procName);
    descriptions.([safeProcName '_AvgSetup']) = sprintf('Average setup time for %s (minutes)', procName);
    descriptions.([safeProcName '_MedianSetup']) = sprintf('Median setup time for %s (minutes)', procName);
    descriptions.([safeProcName '_AvgPost']) = sprintf('Average post time for %s (minutes)', procName);
    descriptions.([safeProcName '_MedianPost']) = sprintf('Median post time for %s (minutes)', procName);
end

% Add descriptions for group one-hot variables
if exist('uniqueGroups','var') && ~isempty(uniqueGroups)
    for g = 1:length(uniqueGroups)
        gName = char(uniqueGroups(g));
        safeField = matlab.lang.makeValidName(['Group_' gName]);
        descriptions.(safeField) = sprintf('One-hot indicator for operator group: %s', gName);
    end
end

end

function summaryStats = calculateSummaryStatistics(data, verbose)
% Calculate summary statistics for all numeric variables

fieldNames = fieldnames(data);
summaryStats = struct();

for i = 1:length(fieldNames)
    fieldName = fieldNames{i};
    fieldData = data.(fieldName);
    
    if isnumeric(fieldData) && ~islogical(fieldData)
    % Calculate summary statistics
    stats = struct();
    stats.mean = mean(fieldData, 'omitnan');
    stats.median = median(fieldData, 'omitnan');
    stats.std = std(fieldData, 'omitnan');
    stats.min = min(fieldData, [], 'omitnan');
    stats.max = max(fieldData, [], 'omitnan');
    stats.p25 = prctile(fieldData, 25);
    stats.p75 = prctile(fieldData, 75);
    stats.n = sum(~isnan(fieldData));
    stats.missing = sum(isnan(fieldData));
    
    summaryStats.(fieldName) = stats;
    end
end

if verbose
    fprintf('Summary statistics calculated for %d numeric variables\n', length(fieldnames(summaryStats)));
end

end

function correlationMatrix = calculateCorrelationMatrix(data, verbose)
% Calculate correlation matrix for numeric variables

fieldNames = fieldnames(data);
numericFields = {};
numericData = [];

% Extract numeric fields
for i = 1:length(fieldNames)
    fieldName = fieldNames{i};
    fieldData = data.(fieldName);
    
    if isnumeric(fieldData) && ~islogical(fieldData) && length(fieldData) > 1
    numericFields{end+1} = fieldName;
    numericData(:, end+1) = fieldData;
    end
end

if isempty(numericData)
    correlationMatrix = [];
    return;
end

% Calculate correlation matrix
corrMatrix = corr(numericData, 'type', 'Pearson', 'rows', 'pairwise');

% Create structure
correlationMatrix = struct();
correlationMatrix.matrix = corrMatrix;
correlationMatrix.variableNames = numericFields;
correlationMatrix.size = size(corrMatrix);

    if verbose
        fprintf('Correlation matrix calculated for %d numeric variables\n', length(numericFields));
    end

end

function exportVariableDescriptions(descriptions, filename)
% Export variable descriptions to text file

fid = fopen(filename, 'w');
if fid == -1
    warning('Could not create variable descriptions file: %s', filename);
    return;
end

fprintf(fid, 'EP Lab Statistical Dataset - Variable Descriptions\n');
fprintf(fid, '=================================================\n\n');

fieldNames = fieldnames(descriptions);
for i = 1:length(fieldNames)
    fprintf(fid, '%-40s: %s\n', fieldNames{i}, descriptions.(fieldNames{i}));
end

fprintf(fid, '\nGenerated: %s\n', datestr(now));
fclose(fid);

end
