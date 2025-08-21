function debug_specific_day()
% Debug idle time calculation for a specific day

fprintf('=== Debugging Specific Day ===\n');

% Load data
try
    scheduleFile = load('data/historicalEPSchedules.mat');
    historicalSchedules = scheduleFile.historicalSchedules;
    fprintf('Loaded schedules for %d dates\n', length(keys(historicalSchedules)));
catch ME
    fprintf('Error loading schedules: %s\n', ME.message);
    return;
end

% Test specific date: 03-Jan-2025 (which showed high idle times)
testDate = '03-Jan-2025';
if ~isKey(historicalSchedules, testDate)
    fprintf('Date %s not found in schedules\n', testDate);
    return;
end

fprintf('\nAnalyzing: %s\n', testDate);
daySchedule = historicalSchedules(testDate);

if ~isfield(daySchedule, 'schedule') || ~isfield(daySchedule.schedule, 'operators')
    fprintf('No operator data found for this date\n');
    return;
end

operators = daySchedule.schedule.operators;
operatorNames = keys(operators);
fprintf('Operators: %s\n', strjoin(operatorNames, ', '));

% Analyze each operator's schedule in detail
for i = 1:length(operatorNames)
    opName = operatorNames{i};
    opSchedule = operators(opName);
    
    fprintf('\n--- %s ---\n', opName);
    
    if isstruct(opSchedule) && length(opSchedule) > 1
        fprintf('Number of cases: %d\n', length(opSchedule));
        
        % Extract and sort cases by start time
        cases = [];
        for j = 1:length(opSchedule)
            case_data = opSchedule(j);
            if isfield(case_data, 'caseInfo')
                caseInfo = case_data.caseInfo;
                cases(j).startTime = caseInfo.startTime;
                cases(j).endTime = caseInfo.endTime;
                cases(j).lab = case_data.lab;
                cases(j).caseID = caseInfo.caseID;
                cases(j).procTime = caseInfo.procTime;
            end
        end
        
        % Sort by start time
        [~, sortIdx] = sort([cases.startTime]);
        cases = cases(sortIdx);
        
        % Show case details and calculate idle time
        totalIdleTime = 0;
        labFlips = 0;
        
        fprintf('Case schedule:\n');
        for j = 1:length(cases)
            startHour = floor(cases(j).startTime / 60);
            startMin = mod(cases(j).startTime, 60);
            endHour = floor(cases(j).endTime / 60);
            endMin = mod(cases(j).endTime, 60);
            
            fprintf('  Case %d (Lab %d): %02d:%02d - %02d:%02d (%.0f min)\n', ...
                j, cases(j).lab, startHour, startMin, endHour, endMin, cases(j).procTime);
            
            % Calculate idle time to next case
            if j < length(cases)
                idleTime = cases(j+1).startTime - cases(j).endTime;
                fprintf('    -> Idle time to next case: %.1f min\n', idleTime);
                if idleTime > 0
                    totalIdleTime = totalIdleTime + idleTime;
                end
                
                % Check for lab flip
                if cases(j).lab ~= cases(j+1).lab
                    labFlips = labFlips + 1;
                    fprintf('    -> Lab flip from %d to %d\n', cases(j).lab, cases(j+1).lab);
                end
            end
        end
        
        fprintf('Total idle time: %.1f min\n', totalIdleTime);
        fprintf('Lab flips: %d\n', labFlips);
        
        % Check if this matches the calculated values from analysis
        if length(cases) > 1
            avgTurnovers = length(cases) - 1;
            idlePerTurnover = totalIdleTime / avgTurnovers;
            fprintf('Idle time per turnover: %.1f min\n', idlePerTurnover);
        end
        
    elseif isstruct(opSchedule) && length(opSchedule) == 1
        fprintf('Single case - no idle time\n');
    else
        fprintf('No valid schedule data\n');
    end
end

end