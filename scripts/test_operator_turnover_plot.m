function test_operator_turnover_plot()
% Focused regression checks for the operator-turnover plotting option.
scriptFolder = fileparts(mfilename('fullpath'));
addpath(scriptFolder);

originalVisibility = get(groot, 'DefaultFigureVisible');
set(groot, 'DefaultFigureVisible', 'off');
cleanup = onCleanup(@() cleanupFigures(originalVisibility));

analysisResults = createSyntheticAnalysisResults();

plotAnalysisResults(analysisResults, 'CreateOperatorTurnoverPlot', true);
assertTurnoverFigure([2; 0; 5], 'Day');

supportedBins = {'week', 'month', 'quarter', 'year'};
for binIdx = 1:length(supportedBins)
    plotAnalysisResults(analysisResults, 'CreateOperatorTurnoverPlot', true, ...
        'TimeBin', supportedBins{binIdx});
    assertTurnoverFigure([2; 0; 5], capitalizeTestLabel(supportedBins{binIdx}));
end

missingResults = struct('timeSeriesAnalysis', struct());
didError = false;
try
    plotAnalysisResults(missingResults, 'CreateOperatorTurnoverPlot', true, 'TimeBin', 'month');
catch ME
    didError = contains(ME.message, 'Rerun analyzeHistoricalData with HistoricalSchedules');
end
assert(didError, 'Missing turnover results should raise an actionable rerun-analysis error.');

fprintf('test_operator_turnover_plot passed\n');
end

function analysisResults = createSyntheticAnalysisResults()
analysisResults = struct();
analysisResults.timeSeriesAnalysis = struct();
supportedBins = {'day', 'week', 'month', 'quarter', 'year'};
for binIdx = 1:length(supportedBins)
    series = struct();
    series.binStartDates = datetime(2026, [1 2 3], 1).';
    series.binLabels = {'Bin 1'; 'Bin 2'; 'Bin 3'};
    series.department = struct('totalOperatorTurnovers', [2; 0; 5]);
    analysisResults.timeSeriesAnalysis.(supportedBins{binIdx}) = series;
end
end

function assertTurnoverFigure(expectedYData, expectedBinLabel)
fig = findobj(groot, 'Type', 'figure', 'Tag', 'OperatorTurnoverFigure');
assert(isscalar(fig), 'Expected one operator turnover figure.');
series = findobj(fig, 'Tag', 'OperatorTurnoverSeries');
assert(isscalar(series), 'Expected one turnover-count series.');
assert(isequal(series.YData(:), expectedYData), ...
    'Turnover series should display stored total operator turnover counts.');
ax = findobj(fig, 'Type', 'axes');
assert(strcmp(ax.YLabel.String, 'Operator turnovers (count)'), ...
    'Turnover y-axis should state that values are counts.');
assert(contains(ax.Title.String, expectedBinLabel), ...
    'Turnover title should state the selected time bin.');
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
