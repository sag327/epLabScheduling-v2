# MATLAB Scripts

This folder contains all MATLAB script files (.m files) for the EP scheduling project.

## Core Analysis Scripts (4 files)
Main production scripts for the EP scheduling system:

- `analyzeHistoricalData.m` - Core historical data analysis function
- `analyzeStatisticalDataset.m` - Statistical analysis with comprehensive summary tables
- `createStatisticalDataset.m` - Creates statistical dataset for analysis
- `scheduleHistoricalCases.m` - Main scheduling optimization function

## Batch Processing & Utilities (7 files)
Supporting scripts for batch operations and data handling:

- `batchProcessHistoricalCases.m` - Batch processing of historical cases
- `getCasesByDate.m` - Utility to extract cases by date
- `getHistoricalLabMappings.m` - Lab mapping utility function
- `loadHistoricalDataFromFile.m` - Data loading utility
- `reconstructHistoricalSchedule.m` - Schedule reconstruction utility
- `rescheduleHistoricalCases.m` - Rescheduling utility
- `visualizeSchedule.m` - Schedule visualization function

## Visualization & Plotting (3 files)
Scripts for creating charts and visualizations:

- `plotAnalysisResults.m` - Retrospective operator and department plotting
- `plot_operator_metrics_example.m` - Operator metrics visualization example
- `quickFlipsChart.m` - Quick chart generation for flip metrics

### Retrospective plotting examples

```matlab
% Optional: restrict all analysis and downstream plots to a date range
analysisResultsWindow = analyzeHistoricalData(historicalData, ...
    'HistoricalSchedules', historicalSchedules, ...
    'DateRange', [datetime(2025,10,1), datetime(2026,3,31)]);

% Optional: restrict analysis to weekdays only within a date range
analysisResultsWeekdays = analyzeHistoricalData(historicalData, ...
    'HistoricalSchedules', historicalSchedules, ...
    'DateRange', ["01-Oct-2025", "31-Mar-2026"], ...
    'WeekdaysOnly', true);

% Optional: remove selected operators from operator-level summaries/plots only
% Department metrics still include all cases in the date/weekday cohort.
analysisResultsFiltered = analyzeHistoricalData(historicalData, ...
    'HistoricalSchedules', historicalSchedules, ...
    'ExcludeOperators', {'OPERATOR, NAME'});

% Optional: remove low-volume operators from operator-level summaries/plots only
analysisResultsMinVolume = analyzeHistoricalData(historicalData, ...
    'HistoricalSchedules', historicalSchedules, ...
    'MinOperatorTotalCases', 10);

% All parsed analysis options are recorded for logging/reproducibility
disp(analysisResultsFiltered.inputOptions);

% The analysis run precomputes time-series summaries at every supported interval
disp(analysisResults.timeSeriesAnalysis.month.department);

% Department operating metrics are available for day/week/month/quarter/year bins
quarterly = analysisResults.timeSeriesAnalysis.quarter.department;
disp(quarterly.totalOperatorTurnovers);                         % Operator turnovers
disp(quarterly.volume.totalProcedures);                          % Department volume
disp(quarterly.duration.medianProcedureDurationMinutes);         % Procedure start-to-complete
disp(quarterly.throughput.proceduresPerDepartmentOperatingHour); % Service-line throughput
disp(quarterly.throughput.proceduresPerActiveLabHour);           % Capacity-adjusted throughput
disp(quarterly.bottleneck);                                      % Time-component totals

% Default output: two manuscript-ready figures
% 1) Department quarterly time series; 2) two-panel association figure
%    containing department and operator-level associations without identity labels
plotAnalysisResults(analysisResults);

% Time-series mode only displays time-series figures
plotAnalysisResults(analysisResults, 'CreateTimeSeriesPlot', true);

% Select a stored display interval: day, week, month, quarter, or year
plotAnalysisResults(analysisResultsWindow, ...
    'CreateTimeSeriesPlot', true, ...
    'TimeBin', 'month');

% Display each operator's binned trends in addition to the cohort summaries
plotAnalysisResults(analysisResults, ...
    'CreateTimeSeriesPlot', true, ...
    'TimeBin', 'quarter', ...
    'ShowIndividualOperatorTraces', true);

% Manuscript-quality primary figure: department process and outcome metrics
% Uses quarterly bins by default when TimeBin is omitted.
plotAnalysisResults(analysisResults, ...
    'CreateManuscriptTimeSeriesFigure', true);

% Manuscript-quality combined association figure with vector PDF export.
% ExportPath is a filename prefix; this writes ep_flip_association.pdf.
plotAnalysisResults(analysisResults, ...
    'CreateManuscriptAssociationFigure', true, ...
    'TimeBin', 'quarter', ...
    'ExportPath', 'ep_flip', ...
    'ExportFormat', 'pdf');

% Operator initials in panel B of the combined association figure are opt-in
plotAnalysisResults(analysisResults, ...
    'CreateManuscriptAssociationFigure', true, ...
    'ShowOperatorInitialLabels', true);

% Former exploratory operator bar summary
plotAnalysisResults(analysisResults, ...
    'CreateOperatorSummaryFigure', true);
```

`analyzeHistoricalData` creates denominator-preserving time-series summaries for day, week, month, quarter, and year. Within each bin, flip ratio is computed as summed lab flips divided by summed operator turnover opportunities, idle time per turnover uses summed idle minutes and turnovers, procedure duration means/medians use pooled valid observed procedure start-to-complete observations, and throughput uses pooled procedures divided by pooled operating-hour denominators. Procedures per department operating hour is the service-line throughput measure; procedures per active lab-hour is retained as its capacity-adjusted companion.

The `bottleneck` output stores summed valid observed setup, procedure, post-procedure, operator idle, and observed same-lab inter-case minutes. An observed same-lab inter-case interval is the reconstructed wheels-out–to–next-wheels-in gap in a single lab and is included only when both adjacent room-boundary component times are valid; it should not be interpreted as separately measured cleaning/turnover work or independently measured unused room time. Metric definitions are stored in `analysisResults.metricDefinitions`.

`plotAnalysisResults` defaults to a two-figure manuscript suite: a department time-series figure and a combined two-panel association figure. Department manuscript panels use full-department flip and pooled idle-time metrics and are unaffected by operator-level exclusions; the operator panel uses the included operator cohort, pooled flip ratios, median idle time per turnover, and square-root-scaled point size based on turnover opportunities. Operator initials are displayed only when explicitly requested. Use `'ExportFormat', 'tiff', 'ExportResolution', 600` for high-resolution raster submission output. Individual exploratory operator traces retain gaps for bins without turnover opportunities. Date-window and weekday filtering belong in `analyzeHistoricalData`, so summaries and plots stay consistent.

## Total: 14 MATLAB Scripts
All production scripts are now organized in this single location for better project structure.

---
**Note**: Debug and test scripts are located in the `/archive/` folder.
