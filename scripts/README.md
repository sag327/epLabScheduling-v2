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

- `plotAnalysisResults.m` - General analysis plotting
- `plot_operator_metrics_example.m` - Operator metrics visualization example
- `quickFlipsChart.m` - Quick chart generation for flip metrics

## Total: 14 MATLAB Scripts
All production scripts are now organized in this single location for better project structure.

---
**Note**: Debug and test scripts are located in the `/archive/` folder.