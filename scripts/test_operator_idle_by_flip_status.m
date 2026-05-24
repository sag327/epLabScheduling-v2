function test_operator_idle_by_flip_status()
% Regression checks for flip-stratified operator idle summaries.
scriptFolder = fileparts(mfilename('fullpath'));
projectFolder = fileparts(scriptFolder);
addpath(scriptFolder);
load(fullfile(projectFolder, 'data', 'historicalEPData.mat'), 'historicalData');
load(fullfile(projectFolder, 'data', 'historicalEPSchedules.mat'), 'historicalSchedules');

consoleOutput = evalc(['results = analyzeHistoricalData(historicalData, ' ...
    '''HistoricalSchedules'', historicalSchedules, ''ShowStats'', true);']);
summary = results.scheduleAnalysis.dailyEfficiency.summary.operatorIdleByFlipStatus;
assert(summary.flipped.count == 29);
assert(summary.notFlipped.count == 22);
assert(abs(summary.flipped.meanIdleMinutes - 61.3448275862069) < 1e-6);
assert(abs(summary.flipped.medianIdleMinutes - 45) < 1e-6);
assert(abs(summary.notFlipped.meanIdleMinutes - 82.5909090909091) < 1e-6);
assert(abs(summary.notFlipped.medianIdleMinutes - 83) < 1e-6);
assert(abs(summary.meanMinutesSavedPerFlip - 21.2460815047022) < 1e-6);
assert(abs(summary.medianMinutesSavedPerFlip - 38) < 1e-6);
assert(contains(consoleOutput, '--- Operator Idle Time by Lab Flip Status ---'));
assert(contains(consoleOutput, 'With lab flip: 29 transitions'));
assert(contains(consoleOutput, 'Without lab flip: 22 transitions'));

supportedBins = {'day', 'week', 'month', 'quarter', 'year'};
for binIdx = 1:length(supportedBins)
    binned = results.timeSeriesAnalysis.(supportedBins{binIdx}).department.operatorIdleByFlipStatus;
    assert(sum(binned.flipped.count) == summary.flipped.count);
    assert(sum(binned.notFlipped.count) == summary.notFlipped.count);
    assert(abs(sum(binned.flipped.totalIdleMinutes) - summary.flipped.totalIdleMinutes) < 1e-10);
    assert(abs(sum(binned.notFlipped.totalIdleMinutes) - summary.notFlipped.totalIdleMinutes) < 1e-10);
end

excluded = analyzeHistoricalData(historicalData, 'HistoricalSchedules', historicalSchedules, ...
    'ShowStats', false, 'ExcludeOperators', {'GAETA, STEPHEN A'});
excludedSummary = excluded.scheduleAnalysis.dailyEfficiency.summary.operatorIdleByFlipStatus;
assert(excludedSummary.flipped.count == summary.flipped.count);
assert(excludedSummary.notFlipped.count == summary.notFlipped.count);

reportFile = [tempname '.txt'];
cleanup = onCleanup(@() removeReportFile(reportFile));
analyzeHistoricalData(historicalData, 'HistoricalSchedules', historicalSchedules, ...
    'ShowStats', false, 'SaveReport', true, 'ReportFile', reportFile);
reportText = fileread(reportFile);
assert(contains(reportText, '--- Operator Idle Time by Lab Flip Status ---'));
assert(contains(reportText, 'median-based 38.0 min'));

fprintf('test_operator_idle_by_flip_status passed\n');
end

function removeReportFile(reportFile)
if exist(reportFile, 'file')
    delete(reportFile);
end
end
