function metrics = calculate_experiment_metrics(schedule, scheduleResults, config)
    % CALCULATE_EXPERIMENT_METRICS - Calculate comprehensive metrics for EP scheduling experiments
    %
    % Inputs:
    %   schedule - Schedule structure from scheduling optimization
    %   scheduleResults - Results structure from scheduling optimization  
    %   config - Experiment configuration
    %
    % Outputs:
    %   metrics - Structure containing calculated performance metrics
    
    % Initialize metrics structure
    metrics = struct();
    
    % Validate inputs
    if isempty(scheduleResults) || ~isstruct(scheduleResults)
        error('scheduleResults is empty or not a struct. Check that scheduling succeeded.');
    end
    
    if ~isfield(scheduleResults, 'makespan')
        error('scheduleResults missing makespan field. Available fields: %s', strjoin(fieldnames(scheduleResults), ', '));
    end
    
    % Basic schedule metrics
    metrics.makespan = scheduleResults.makespan;
    
    % Extract all cases from labs
    allCases = [];
    if isfield(schedule, 'labs') && ~isempty(schedule.labs)
        for i = 1:length(schedule.labs)
            if ~isempty(schedule.labs{i})
                labCases = schedule.labs{i};
                if isempty(allCases)
                    allCases = labCases;
                else
                    % Concatenate struct arrays
                    for j = 1:length(labCases)
                        allCases(end+1) = labCases(j);
                    end
                end
            end
        end
    end
    
    metrics.numCasesScheduled = length(allCases);
    if ~isempty(allCases)
        metrics.totalProcedureTime = sum([allCases.procTime]);
    else
        metrics.totalProcedureTime = 0;
    end
    
    % Lab utilization metrics
    numLabs = config.numLabs;
    metrics.numLabsUsed = 0;
    labUtilization = zeros(numLabs, 1);
    
    if isfield(schedule, 'labs') && ~isempty(schedule.labs)
        for i = 1:min(numLabs, length(schedule.labs))
            if ~isempty(schedule.labs{i})
                metrics.numLabsUsed = metrics.numLabsUsed + 1;
                labCases = schedule.labs{i};
                labTotalTime = sum([labCases.procTime]);
                if metrics.makespan > 0
                    labUtilization(i) = labTotalTime / metrics.makespan * 100;
                end
            end
        end
    end
    
    if metrics.numLabsUsed > 0
        metrics.avgLabUtilization = mean(labUtilization(labUtilization > 0));
        metrics.maxLabUtilization = max(labUtilization);
        metrics.minLabUtilization = min(labUtilization(labUtilization > 0));
        metrics.labUtilizationStd = std(labUtilization(labUtilization > 0));
    else
        metrics.avgLabUtilization = 0;
        metrics.maxLabUtilization = 0;
        metrics.minLabUtilization = 0;
        metrics.labUtilizationStd = 0;
    end
    
    % Timing efficiency metrics
    if ~isempty(allCases)
        % Calculate gaps between cases
        allStartTimes = [allCases.startTime];
        allEndTimes = [allCases.endTime];
        [~, sortIdx] = sort(allStartTimes);
        sortedStartTimes = allStartTimes(sortIdx);
        sortedEndTimes = allEndTimes(sortIdx);
        
        gaps = [];
        for i = 2:length(sortedStartTimes)
            gap = sortedStartTimes(i) - sortedEndTimes(i-1);
            if gap > 0
                gaps = [gaps; gap];
            end
        end
        
        if ~isempty(gaps)
            metrics.avgGapBetweenCases = mean(gaps);
            metrics.totalIdleTime = sum(gaps);
            metrics.scheduleEfficiency = (metrics.totalProcedureTime / ...
                (metrics.totalProcedureTime + metrics.totalIdleTime)) * 100;
        else
            metrics.avgGapBetweenCases = 0;
            metrics.totalIdleTime = 0;
            metrics.scheduleEfficiency = 100;
        end
    else
        metrics.avgGapBetweenCases = 0;
        metrics.totalIdleTime = 0;
        metrics.scheduleEfficiency = 0;
    end
    
    % Overtime analysis
    if isfield(config, 'endTime')
        dailyEndTime = config.endTime;
        if ~isempty(allCases)
            latestEnd = max([allCases.endTime]);
            if latestEnd > dailyEndTime
                metrics.overtimeMinutes = latestEnd - dailyEndTime;
                metrics.overtimeHours = metrics.overtimeMinutes / 60;
            else
                metrics.overtimeMinutes = 0;
                metrics.overtimeHours = 0;
            end
        else
            metrics.overtimeMinutes = 0;
            metrics.overtimeHours = 0;
        end
    else
        metrics.overtimeMinutes = 0;
        metrics.overtimeHours = 0;
    end
    
    % Turnover impact
    expectedTurnoverTime = max(0, (metrics.numCasesScheduled - 1) * config.turnoverTime);
    metrics.totalTurnoverTime = expectedTurnoverTime;
    if metrics.makespan > 0
        metrics.turnoverImpactPercent = (expectedTurnoverTime / metrics.makespan) * 100;
    else
        metrics.turnoverImpactPercent = 0;
    end
    
    % Configuration parameters for reference
    metrics.configParams = struct();
    metrics.configParams.numLabs = config.numLabs;
    metrics.configParams.turnoverTime = config.turnoverTime;
    if isfield(config, 'endTime') && isfield(config, 'startTime')
        metrics.configParams.sessionLength = config.endTime - config.startTime;
    end
    metrics.configParams.startTime = config.startTime;
    
    % Quality metrics from scheduleResults if available
    if isfield(scheduleResults, 'objectiveValue')
        metrics.objectiveValue = scheduleResults.objectiveValue;
    end
    
    if isfield(scheduleResults, 'feasible')
        metrics.feasible = scheduleResults.feasible;
    else
        metrics.feasible = true; % Assume feasible if not specified
    end
    
    % Resource efficiency
    if isfield(config, 'endTime') && isfield(config, 'startTime')
        totalAvailableTime = config.numLabs * (config.endTime - config.startTime);
        metrics.resourceUtilization = (metrics.totalProcedureTime / totalAvailableTime) * 100;
    else
        metrics.resourceUtilization = 0;
    end
    
    % EP-specific advanced metrics
    
    % 1. Operator idle time to turnover ratio
    if ~isempty(allCases) && config.turnoverTime > 0
        operators = {allCases.operator};
        uniqueOperators = unique(operators);
        totalOperatorIdleTime = 0;
        
        for opIdx = 1:length(uniqueOperators)
            opCases = allCases(strcmp(operators, uniqueOperators{opIdx}));
            if length(opCases) > 1
                % Sort operator cases by start time
                [~, sortIdx] = sort([opCases.startTime]);
                sortedOpCases = opCases(sortIdx);
                
                % Calculate idle time between consecutive cases
                for i = 2:length(sortedOpCases)
                    idleTime = sortedOpCases(i).startTime - sortedOpCases(i-1).endTime;
                    if idleTime > 0
                        totalOperatorIdleTime = totalOperatorIdleTime + idleTime;
                    end
                end
            end
        end
        
        metrics.totalOperatorIdleTime = totalOperatorIdleTime;
        if metrics.totalTurnoverTime > 0
            metrics.operatorIdleToTurnoverRatio = totalOperatorIdleTime / metrics.totalTurnoverTime;
        else
            metrics.operatorIdleToTurnoverRatio = 0;
        end
    else
        metrics.totalOperatorIdleTime = 0;
        metrics.operatorIdleToTurnoverRatio = 0;
    end
    
    % 2. Flip to turnover ratio (operator transitions between labs)
    if ~isempty(allCases) && config.turnoverTime > 0
        totalFlips = 0;
        operators = {allCases.operator};
        uniqueOperators = unique(operators);
        
        for opIdx = 1:length(uniqueOperators)
            opCases = allCases(strcmp(operators, uniqueOperators{opIdx}));
            if length(opCases) > 1
                % Sort operator cases by start time
                [~, sortIdx] = sort([opCases.startTime]);
                sortedOpCases = opCases(sortIdx);
                
                % Count lab changes (flips)
                for i = 2:length(sortedOpCases)
                    prevLab = find_case_lab(sortedOpCases(i-1), schedule);
                    currLab = find_case_lab(sortedOpCases(i), schedule);
                    if prevLab ~= currLab
                        totalFlips = totalFlips + 1;
                    end
                end
            end
        end
        
        metrics.totalFlips = totalFlips;
        if (metrics.numCasesScheduled * config.turnoverTime) > 0
            metrics.flipToTurnoverRatio = totalFlips / (metrics.numCasesScheduled * config.turnoverTime);
        else
            metrics.flipToTurnoverRatio = 0;
        end
    else
        metrics.totalFlips = 0;
        metrics.flipToTurnoverRatio = 0;
    end
    
    % 3. Lab throughput metrics
    if ~isempty(allCases)
        % Cases per hour (total cases / makespan in hours)
        if metrics.makespan > 0
            metrics.casesPerHour = metrics.numCasesScheduled / (metrics.makespan / 60);
        else
            metrics.casesPerHour = 0;
        end
        
        % Per-lab throughput
        metrics.perLabThroughput = zeros(numLabs, 1);
        if isfield(schedule, 'labs') && ~isempty(schedule.labs)
            for i = 1:min(numLabs, length(schedule.labs))
                if ~isempty(schedule.labs{i})
                    labCases = schedule.labs{i};
                    labMakespan = max([labCases.endTime]) - min([labCases.startTime]);
                    if labMakespan > 0
                        metrics.perLabThroughput(i) = length(labCases) / (labMakespan / 60);
                    end
                end
            end
        end
        metrics.avgLabThroughput = mean(metrics.perLabThroughput(metrics.perLabThroughput > 0));
        metrics.maxLabThroughput = max(metrics.perLabThroughput);
        
        % Procedure time efficiency (actual procedure time / total scheduled time)
        totalScheduledTime = metrics.makespan * metrics.numLabsUsed;
        if totalScheduledTime > 0
            metrics.procedureTimeEfficiency = (metrics.totalProcedureTime / totalScheduledTime) * 100;
        else
            metrics.procedureTimeEfficiency = 0;
        end
        
        % Average case cycle time (time from start to finish including setup/post)
        allCycleTimes = [allCases.endTime] - [allCases.startTime];
        metrics.avgCaseCycleTime = mean(allCycleTimes);
        metrics.maxCaseCycleTime = max(allCycleTimes);
        metrics.minCaseCycleTime = min(allCycleTimes);
    else
        metrics.casesPerHour = 0;
        metrics.perLabThroughput = zeros(numLabs, 1);
        metrics.avgLabThroughput = 0;
        metrics.maxLabThroughput = 0;
        metrics.procedureTimeEfficiency = 0;
        metrics.avgCaseCycleTime = 0;
        metrics.maxCaseCycleTime = 0;
        metrics.minCaseCycleTime = 0;
    end
    
    % Summary scores (composite metrics)
    metrics.efficiencyScore = (metrics.scheduleEfficiency + metrics.resourceUtilization) / 2;
    metrics.utilizationScore = metrics.avgLabUtilization;
    
    % Add timestamp
    metrics.calculatedAt = datestr(now);
end

function labNum = find_case_lab(caseInfo, schedule)
    % Helper function to find which lab a case is assigned to
    labNum = 0;
    if isfield(schedule, 'labs') && ~isempty(schedule.labs)
        for i = 1:length(schedule.labs)
            if ~isempty(schedule.labs{i})
                labCases = schedule.labs{i};
                for j = 1:length(labCases)
                    if strcmp(labCases(j).caseID, caseInfo.caseID)
                        labNum = i;
                        return;
                    end
                end
            end
        end
    end
end