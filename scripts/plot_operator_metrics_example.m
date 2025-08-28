function plot_operator_metrics_example()
% Example demonstrating how to plot operator metrics from enhanced analysis

fprintf('=== OPERATOR METRICS PLOTTING EXAMPLES ===\n');

try
    % Load historical data and run analysis
    fprintf('Loading data and running analysis...\n');
    [historicalData, ~] = loadHistoricalDataFromFile();
    results = analyzeHistoricalData(historicalData, 'ShowStats', false);
    
    % Extract the plotting data
    plotData = results.operatorPlottingData;
    
    fprintf('Creating operator metric plots...\n');
    
    % Example 1: Bar chart of mean procedure times by operator
    figure('Name', 'Mean Procedure Times by Operator', 'Position', [100, 100, 1200, 600]);
    
    % Get top 10 operators by case volume
    topN = min(10, length(plotData.operatorNames));
    topOperators = plotData.operatorNames(1:topN);
    topProcTimes = plotData.procedureTime.mean(1:topN);
    topStdTimes = plotData.procedureTime.std(1:topN);
    topCaseCounts = plotData.totalCases(1:topN);
    
    % Remove operators with no valid procedure time data
    validMask = ~isnan(topProcTimes);
    topOperators = topOperators(validMask);
    topProcTimes = topProcTimes(validMask);
    topStdTimes = topStdTimes(validMask);
    topCaseCounts = topCaseCounts(validMask);
    
    if ~isempty(topOperators)
        subplot(2, 2, 1);
        bar(topProcTimes);
        hold on;
        errorbar(1:length(topProcTimes), topProcTimes, topStdTimes, 'k.', 'LineWidth', 1.5);
        set(gca, 'XTickLabel', topOperators, 'XTickLabelRotation', 45);
        ylabel('Mean Procedure Time (minutes)');
        title('Mean Procedure Times by Operator (±1 std)');
        grid on;
        
        % Add case count annotations
        for i = 1:length(topOperators)
            text(i, topProcTimes(i) + topStdTimes(i) + 5, sprintf('%d cases', topCaseCounts(i)), ...
                'HorizontalAlignment', 'center', 'FontSize', 8);
        end
    end
    
    % Example 2: Setup vs Procedure time scatter plot
    subplot(2, 2, 2);
    validSetup = ~isnan(plotData.setupTime.mean);
    validProc = ~isnan(plotData.procedureTime.mean);
    validBoth = validSetup & validProc;
    
    if sum(validBoth) > 0
        scatter(plotData.setupTime.mean(validBoth), plotData.procedureTime.mean(validBoth), ...
            plotData.totalCases(validBoth), 'filled', 'alpha', 0.6);
        xlabel('Mean Setup Time (minutes)');
        ylabel('Mean Procedure Time (minutes)');
        title('Setup vs Procedure Time (bubble size = case count)');
        grid on;
        
        % Add operator labels for top operators
        topIndices = find(validBoth);
        topIndices = topIndices(1:min(5, length(topIndices)));
        for i = topIndices'
            text(plotData.setupTime.mean(i), plotData.procedureTime.mean(i), ...
                strrep(plotData.operatorNames{i}, ', ', ',\n'), ...
                'FontSize', 8, 'HorizontalAlignment', 'center');
        end
    end
    
    % Example 3: Box plot of procedure times (using individual values)
    subplot(2, 2, 3);
    % Select top 5 operators with sufficient data
    boxData = {};
    boxLabels = {};
    validCount = 0;
    
    for i = 1:min(5, length(plotData.operatorNames))
        procValues = plotData.procedureTime.allValues{i};
        if length(procValues) >= 5  % Need at least 5 cases for meaningful box plot
            validCount = validCount + 1;
            boxData{validCount} = procValues;
            boxLabels{validCount} = plotData.operatorNames{i};
        end
    end
    
    if validCount > 0
        boxplot([boxData{:}], 'Labels', boxLabels);
        ylabel('Procedure Time (minutes)');
        title('Procedure Time Distribution (Top Operators)');
        set(gca, 'XTickLabelRotation', 45);
        grid on;
    end
    
    % Example 4: Efficiency ratios
    subplot(2, 2, 4);
    validRatios = ~isnan(plotData.efficiency.setupToProcRatio);
    
    if sum(validRatios) > 0
        ratioOperators = plotData.operatorNames(validRatios);
        ratioValues = plotData.efficiency.setupToProcRatio(validRatios);
        ratioCases = plotData.totalCases(validRatios);
        
        % Sort by case count for better visualization
        [~, sortIdx] = sort(ratioCases, 'descend');
        topRatioN = min(8, length(sortIdx));
        
        bar(ratioValues(sortIdx(1:topRatioN)));
        set(gca, 'XTickLabel', ratioOperators(sortIdx(1:topRatioN)), 'XTickLabelRotation', 45);
        ylabel('Setup/Procedure Time Ratio');
        title('Setup Efficiency by Operator');
        grid on;
        
        % Add horizontal line at ratio = 0.5 (setup = 50% of procedure time)
        hold on;
        yline(0.5, 'r--', 'LineWidth', 2, 'Alpha', 0.7);
        legend('Setup/Proc Ratio', '50% Reference', 'Location', 'best');
    end
    
    sgtitle(sprintf('Operator Performance Metrics (%d operators, %d total cases)', ...
        length(plotData.operatorNames), sum(plotData.totalCases)));
    
    fprintf('✓ Created comprehensive operator metrics visualization\n');
    
    % Show summary statistics
    fprintf('\n--- Summary Statistics ---\n');
    fprintf('Total operators analyzed: %d\n', length(plotData.operatorNames));
    fprintf('Operators with valid setup time data: %d\n', sum(~isnan(plotData.setupTime.mean)));
    fprintf('Operators with valid procedure time data: %d\n', sum(~isnan(plotData.procedureTime.mean)));
    fprintf('Overall setup time range: %.1f - %.1f minutes\n', ...
        min(plotData.setupTime.mean), max(plotData.setupTime.mean));
    fprintf('Overall procedure time range: %.1f - %.1f minutes\n', ...
        min(plotData.procedureTime.mean), max(plotData.procedureTime.mean));
    
    % Example of accessing individual operator data
    fprintf('\n--- Example: Detailed data for top operator ---\n');
    topOpName = plotData.operatorNames{1};
    fprintf('Operator: %s\n', topOpName);
    fprintf('Total cases: %d\n', plotData.totalCases(1));
    if ~isnan(plotData.setupTime.mean(1))
        fprintf('Setup time: Mean=%.1f, Median=%.1f, P90=%.1f min\n', ...
            plotData.setupTime.mean(1), plotData.setupTime.median(1), plotData.setupTime.p90(1));
    end
    if ~isnan(plotData.procedureTime.mean(1))
        fprintf('Procedure time: Mean=%.1f, Median=%.1f, P90=%.1f min\n', ...
            plotData.procedureTime.mean(1), plotData.procedureTime.median(1), plotData.procedureTime.p90(1));
    end
    
    fprintf('\n=== PLOTTING EXAMPLE COMPLETE ===\n');
    
catch ME
    fprintf('ERROR during plotting: %s\n', ME.message);
    rethrow(ME);
end

end