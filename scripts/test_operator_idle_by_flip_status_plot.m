function test_operator_idle_by_flip_status_plot()
% Focused regression checks for the flip-stratified operator idle plot.
scriptFolder = fileparts(mfilename('fullpath'));
addpath(scriptFolder);

originalVisibility = get(groot, 'DefaultFigureVisible');
set(groot, 'DefaultFigureVisible', 'off');
cleanup = onCleanup(@() cleanupFigures(originalVisibility));

analysisResults = createSyntheticAnalysisResults();

plotAnalysisResults(analysisResults, 'CreateOperatorIdleByFlipStatusPlot', true);
assertFlipStatusFigure([10; NaN; 0], [25; 30; 0], [15; NaN; 0], 'Median', 'Day');

supportedBins = {'week', 'month', 'quarter', 'year'};
for binIdx = 1:length(supportedBins)
    plotAnalysisResults(analysisResults, 'CreateOperatorIdleByFlipStatusPlot', true, ...
        'TimeBin', supportedBins{binIdx}, 'FlipIdleStatistic', 'mean');
    assertFlipStatusFigure([12; NaN; 0], [27; 33; 0], [15; NaN; 0], ...
        'Mean', capitalizeTestLabel(supportedBins{binIdx}));
end

plotAnalysisResults(analysisResults, 'CreateOperatorTurnoverPlot', true, ...
    'CreateOperatorIdleByFlipStatusPlot', true, 'TimeBin', 'month');
assert(isscalar(findobj(groot, 'Type', 'figure', 'Tag', 'OperatorTurnoverFigure')), ...
    'A requested turnover plot should be retained when the flip-status plot is also requested.');
assert(isscalar(findobj(groot, 'Type', 'figure', 'Tag', 'OperatorIdleByFlipStatusFigure')), ...
    'A requested flip-status plot should be created alongside other optional plots.');
close(findobj(groot, 'Type', 'figure'));

missingResults = struct('timeSeriesAnalysis', struct());
didError = false;
try
    plotAnalysisResults(missingResults, 'CreateOperatorIdleByFlipStatusPlot', true, ...
        'TimeBin', 'month');
catch ME
    didError = contains(ME.message, 'Rerun analyzeHistoricalData with HistoricalSchedules');
end
assert(didError, 'Missing flip-status results should raise an actionable rerun-analysis error.');

didError = false;
try
    plotAnalysisResults(analysisResults, 'CreateOperatorIdleByFlipStatusPlot', true, ...
        'FlipIdleStatistic', 'invalid');
catch
    didError = true;
end
assert(didError, 'An invalid FlipIdleStatistic value should be rejected.');

fprintf('test_operator_idle_by_flip_status_plot passed\n');
end

function analysisResults = createSyntheticAnalysisResults()
analysisResults = struct();
analysisResults.timeSeriesAnalysis = struct();
supportedBins = {'day', 'week', 'month', 'quarter', 'year'};
for binIdx = 1:length(supportedBins)
    series = struct();
    series.binStartDates = datetime(2026, [1 2 3], 1).';
    series.binLabels = {'Bin 1'; 'Bin 2'; 'Bin 3'};
    series.department = struct();
    series.department.totalOperatorTurnovers = [2; 0; 5];
    series.department.operatorIdleByFlipStatus = struct( ...
        'flipped', struct('meanIdleMinutes', [12; NaN; 0], ...
            'medianIdleMinutes', [10; NaN; 0]), ...
        'notFlipped', struct('meanIdleMinutes', [27; 33; 0], ...
            'medianIdleMinutes', [25; 30; 0]), ...
        'meanMinutesSavedPerFlip', [15; NaN; 0], ...
        'medianMinutesSavedPerFlip', [15; NaN; 0]);
    analysisResults.timeSeriesAnalysis.(supportedBins{binIdx}) = series;
end
end

function assertFlipStatusFigure(expectedFlipped, expectedNotFlipped, expectedSaved, expectedStatistic, expectedBin)
fig = findobj(groot, 'Type', 'figure', 'Tag', 'OperatorIdleByFlipStatusFigure');
assert(isscalar(fig), 'Expected one operator idle-by-flip figure.');
flippedSeries = findobj(fig, 'Tag', 'OperatorIdleFlippedSeries');
notFlippedSeries = findobj(fig, 'Tag', 'OperatorIdleNotFlippedSeries');
savedSeries = findobj(fig, 'Tag', 'OperatorIdleMinutesSavedSeries');
assert(isequaln(flippedSeries.YData(:), expectedFlipped), ...
    'Flip-status plot should display the selected flipped idle statistic.');
assert(isequaln(notFlippedSeries.YData(:), expectedNotFlipped), ...
    'Flip-status plot should display the selected non-flipped idle statistic.');
assert(isequaln(savedSeries.YData(:), expectedSaved), ...
    'Saved-minutes plot should preserve gaps and valid zero differences.');
axesObjects = findobj(fig, 'Type', 'axes');
titleText = arrayfun(@(ax) string(ax.Title.String), axesObjects);
assert(any(contains(titleText, expectedStatistic)) && any(contains(titleText, expectedBin)), ...
    'Plot title should state the statistic and selected time bin.');
close(fig);
end

function label = capitalizeTestLabel(timeBin)
label = timeBin;
label(1) = upper(label(1));
end

function cleanupFigures(originalVisibility)
close(findobj(groot, 'Type', 'figure'));
set(groot, 'DefaultFigureVisible', originalVisibility);
end
