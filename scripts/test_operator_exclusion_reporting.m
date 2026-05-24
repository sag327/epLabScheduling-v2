function test_operator_exclusion_reporting()
% Focused checks for user-visible operator exclusion reporting.
scriptFolder = fileparts(mfilename('fullpath'));
projectFolder = fileparts(scriptFolder);
addpath(scriptFolder);
load(fullfile(projectFolder, 'data', 'historicalEPData.mat'), 'historicalData');
load(fullfile(projectFolder, 'data', 'historicalEPSchedules.mat'), 'historicalSchedules');

requestedOperators = {'GAETA, STEPHEN A', 'NOT A REAL OPERATOR'};
consoleOutput = evalc(['results = analyzeHistoricalData(historicalData, ' ...
    '''HistoricalSchedules'', historicalSchedules, ''ShowStats'', false, ' ...
    '''ExcludeOperators'', requestedOperators);']);
assert(contains(consoleOutput, '--- Operator-Level Exclusions ---'));
assert(contains(consoleOutput, 'Requested via ExcludeOperators: GAETA, STEPHEN A; NOT A REAL OPERATOR'));
assert(contains(consoleOutput, 'Matched requested operators to exclude: GAETA, STEPHEN A'));
assert(contains(consoleOutput, 'Requested operators not found and not excluded: NOT A REAL OPERATOR'));
assert(contains(consoleOutput, 'Excluded from returned/downstream: operator metrics/plots'));
assert(contains(consoleOutput, 'Preserved in: dataset, procedure-wide, surgeon, time, and room summaries'));
assert(contains(consoleOutput, 'calculation-time console summaries may show the inclusive source cohort'));
assert(~isfield(results.operatorMetrics, matlab.lang.makeValidName('GAETA, STEPHEN A')));

thresholdOutput = evalc(['analyzeHistoricalData(historicalData, ' ...
    '''HistoricalSchedules'', historicalSchedules, ''ShowStats'', false, ' ...
    '''MinOperatorTotalCases'', 2);']);
assert(contains(thresholdOutput, 'Minimum operator total-case threshold: 2 cases'));
assert(contains(thresholdOutput, 'Operators below threshold to exclude:'));
assert(contains(thresholdOutput, 'RASHID, HAROON'));

reportFile = [tempname '.txt'];
cleanup = onCleanup(@() removeReportFile(reportFile));
analyzeHistoricalData(historicalData, 'HistoricalSchedules', historicalSchedules, ...
    'ShowStats', false, 'ExcludeOperators', requestedOperators, ...
    'SaveReport', true, 'ReportFile', reportFile);
reportText = fileread(reportFile);
assert(contains(reportText, '--- Operator-Level Exclusions ---'));
assert(contains(reportText, 'Final operators excluded from operator-level analyses: GAETA, STEPHEN A'));

fprintf('test_operator_exclusion_reporting passed\n');
end

function removeReportFile(reportFile)
if exist(reportFile, 'file')
    delete(reportFile);
end
end
