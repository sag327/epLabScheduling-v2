function test_bottleneck_decomposition_plot()
% Focused regression checks for the bottleneck decomposition plotting option.
scriptFolder = fileparts(mfilename('fullpath'));
addpath(scriptFolder);

originalVisibility = get(groot, 'DefaultFigureVisible');
set(groot, 'DefaultFigureVisible', 'off');
cleanup = onCleanup(@() cleanupFigures(originalVisibility));

analysisResults = createSyntheticAnalysisResults();

plotAnalysisResults(analysisResults, 'CreateBottleneckDecompositionPlot', true);
fig = findobj(groot, 'Type', 'figure', 'Tag', 'BottleneckDecompositionFigure');
assert(isscalar(fig), 'Expected one aggregate bottleneck figure.');
labels = getPercentageLabels(fig);
expectedAggregateLabels = sort(["13.3%", "13.3%", "20.0%", "53.3%"]);
assert(isequal(sort(labels), expectedAggregateLabels), ...
    'Aggregate percentage labels do not match the full-period totals.');
assert(length(findobj(fig, '-regexp', 'Tag', '^BottleneckComponent')) == 4, ...
    'Expected four aggregate stacked components.');
close(fig);

supportedBins = {'day', 'week', 'month', 'quarter', 'year'};
for binIdx = 1:length(supportedBins)
    plotAnalysisResults(analysisResults, 'CreateBottleneckDecompositionPlot', true, ...
        'TimeBin', supportedBins{binIdx});
    fig = findobj(groot, 'Type', 'figure', 'Tag', 'BottleneckDecompositionFigure');
    assert(isscalar(fig), 'Expected one binned bottleneck figure.');
    ax = findobj(fig, 'Type', 'axes');
    assert(strcmp(ax.YLabel.String, 'Duration (minutes)'), ...
        'Default binned bottleneck scale should remain absolute minutes.');
    labels = getPercentageLabels(fig);
    assert(length(labels) == 7, ...
        'Zero-total or zero-component bins should be omitted from percentage labels.');
    assert(length(findobj(fig, '-regexp', 'Tag', '^BottleneckComponent')) == 4, ...
        'Expected four binned stacked components.');
    close(fig);
end

plotAnalysisResults(analysisResults, 'CreateBottleneckDecompositionPlot', true, ...
    'TimeBin', 'month', 'BottleneckScale', 'percent');
fig = findobj(groot, 'Type', 'figure', 'Tag', 'BottleneckDecompositionFigure');
ax = findobj(fig, 'Type', 'axes');
assert(strcmp(ax.YLabel.String, 'Share of bin duration (%)'), ...
    'Percentage scale should label the y-axis as share of bin duration.');
percentageData = getComponentYData(fig, 3);
assert(all(abs(sum(percentageData([1 3], :), 2) - 100) < 1e-10), ...
    'Each populated percent-mode bin should sum to 100 percent.');
assert(all(isnan(percentageData(2, :))), ...
    'A zero-total percent-mode bin should be rendered as a gap.');
assert(length(getPercentageLabels(fig)) == 7, ...
    'A zero-total percent-mode bin should not receive percentage labels.');
close(fig);

plotAnalysisResults(analysisResults, 'CreateBottleneckDecompositionPlot', true, ...
    'TimeBin', 'month', 'BottleneckScale', 'per_case');
fig = findobj(groot, 'Type', 'figure', 'Tag', 'BottleneckDecompositionFigure');
ax = findobj(fig, 'Type', 'axes');
assert(strcmp(ax.YLabel.String, 'Duration per procedure (minutes/procedure)'), ...
    'Per-case scale should identify the denominator in the y-axis label.');
perCaseData = getComponentYData(fig, 3);
expectedPerCase = [1 3 1 0; NaN NaN NaN NaN; 3 9 3 5];
assert(isequaln(perCaseData, expectedPerCase), ...
    'Per-case component heights should equal component totals divided by procedures in each bin.');
close(fig);

plotAnalysisResults(analysisResults, 'CreateBottleneckDecompositionPlot', true, ...
    'BottleneckScale', 'per_case');
fig = findobj(groot, 'Type', 'figure', 'Tag', 'BottleneckDecompositionFigure');
aggregatePerCase = getComponentYData(fig, 1);
assert(all(abs(aggregatePerCase - [3 8 2 2]) < 1e-10, 'all'), ...
    'An unbinned per-case plot should divide full-period totals by full-period procedures.');
close(fig);

singleBinResults = analysisResults;
singleBinResults.timeSeriesAnalysis.quarter = createBinnedSeries( ...
    datetime(2026, 1, 1), {'Q1 2026'}, [10 20 30 40], 5);
plotAnalysisResults(singleBinResults, 'CreateBottleneckDecompositionPlot', true, ...
    'TimeBin', 'quarter', 'BottleneckScale', 'percent');
fig = findobj(groot, 'Type', 'figure', 'Tag', 'BottleneckDecompositionFigure');
assert(isscalar(fig) && length(getPercentageLabels(fig)) == 4, ...
    'A one-bin explicit area plot should display all four nonzero component labels.');
percentageData = getComponentYData(fig, 1);
assert(abs(sum(percentageData(1, :)) - 100) < 1e-10, ...
    'A one-bin percentage plot should sum to 100 percent.');
close(fig);

missingResults = struct('timeSeriesAnalysis', struct());
didError = false;
try
    plotAnalysisResults(missingResults, 'CreateBottleneckDecompositionPlot', true);
catch ME
    didError = contains(ME.message, 'Rerun analyzeHistoricalData with HistoricalSchedules');
end
assert(didError, 'Missing bottleneck results should raise an actionable rerun-analysis error.');

didError = false;
try
    plotAnalysisResults(analysisResults, 'CreateBottleneckDecompositionPlot', true, ...
        'TimeBin', 'month', 'BottleneckScale', 'invalid');
catch
    didError = true;
end
assert(didError, 'An invalid BottleneckScale value should be rejected.');

fprintf('test_bottleneck_decomposition_plot passed\n');
end

function analysisResults = createSyntheticAnalysisResults()
analysisResults = struct();
analysisResults.timeSeriesAnalysis = struct();

dayValues = [10 30 10 0; 20 50 10 20];
analysisResults.timeSeriesAnalysis.day = createBinnedSeries( ...
    datetime(2026, 1, [1 2]), {'01-Jan-2026', '02-Jan-2026'}, dayValues, [4; 6]);

binnedValues = [10 30 10 0; 0 0 0 0; 15 45 15 25];
binUnits = {'week', 'month', 'quarter', 'year'};
for unitIdx = 1:length(binUnits)
    analysisResults.timeSeriesAnalysis.(binUnits{unitIdx}) = createBinnedSeries( ...
        datetime(2026, [1 2 3], 1), {'Bin 1', 'Bin 2', 'Bin 3'}, binnedValues, [10; 0; 5]);
end
end

function series = createBinnedSeries(binDates, binLabels, values, procedureCounts)
series = struct();
series.binStartDates = binDates(:);
series.binLabels = binLabels(:);
series.department = struct();
series.department.volume = struct('totalProcedures', procedureCounts(:));
series.department.bottleneck = struct( ...
    'totalSetupMinutes', values(:, 1), ...
    'totalProcedureMinutes', values(:, 2), ...
    'totalPostMinutes', values(:, 3), ...
    'totalObservedSameLabInterCaseMinutes', values(:, 4));
end

function labels = getPercentageLabels(fig)
labelObjects = findobj(fig, 'Tag', 'BottleneckPercentageLabel');
labels = strings(1, length(labelObjects));
for labelIdx = 1:length(labelObjects)
    labels(labelIdx) = string(labelObjects(labelIdx).String);
end
end

function componentData = getComponentYData(fig, numSourceBins)
componentData = NaN(numSourceBins, 4);
for componentIdx = 1:4
    component = findobj(fig, 'Tag', sprintf('BottleneckComponent%d', componentIdx));
    yData = component.YData;
    componentData(:, componentIdx) = yData(1:numSourceBins).';
end
end

function cleanupFigures(originalVisibility)
close(findobj(groot, 'Type', 'figure'));
set(groot, 'DefaultFigureVisible', originalVisibility);
end
