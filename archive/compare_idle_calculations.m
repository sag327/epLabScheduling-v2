function compare_idle_calculations()
% Compare current vs correct idle time calculation

fprintf('=== Comparing Idle Time Calculations ===\n');

% Load data
try
    scheduleFile = load('data/historicalEPSchedules.mat');
    historicalSchedules = scheduleFile.historicalSchedules;
catch ME
    fprintf('Error loading schedules: %s\n', ME.message);
    return;
end

% Test specific date and operator
testDate = '03-Jan-2025';
targetOperator = 'ARSHAD, AYSHA';

if ~isKey(historicalSchedules, testDate)
    fprintf('Date not found\n');
    return;
end

daySchedule = historicalSchedules(testDate);
if ~isfield(daySchedule, 'schedule') || ~isfield(daySchedule.schedule, 'operators')
    fprintf('No operator data\n');
    return;
end

operators = daySchedule.schedule.operators;
if ~isKey(operators, targetOperator)
    fprintf('Operator not found\n');
    return;
end

opSchedule = operators(targetOperator);
if ~(isstruct(opSchedule) && length(opSchedule) > 1)
    fprintf('Not enough cases\n');
    return;
end

fprintf('Analyzing %s on %s (%d cases)\n', targetOperator, testDate, length(opSchedule));

% Extract and sort cases
cases = [];
for j = 1:length(opSchedule)
    case_data = opSchedule(j);
    if isfield(case_data, 'caseInfo')
        caseInfo = case_data.caseInfo;
        cases(j).startTime = caseInfo.startTime;           % Room entry
        cases(j).endTime = caseInfo.endTime;               % Room exit (includes turnover)
        cases(j).procStartTime = caseInfo.procStartTime;   % Procedure start
        cases(j).procEndTime = caseInfo.procEndTime;       % Procedure end
        cases(j).lab = case_data.lab;
        cases(j).caseID = caseInfo.caseID;
        cases(j).setupTime = caseInfo.setupTime;
        cases(j).procTime = caseInfo.procTime;
        cases(j).postTime = caseInfo.postTime;
        cases(j).turnoverTime = caseInfo.turnoverTime;
    end
end

% Sort by start time
[~, sortIdx] = sort([cases.startTime]);
cases = cases(sortIdx);

fprintf('\nDetailed Case Timeline:\n');
currentIdleTime = 0;  % Current calculation (endTime -> startTime)
correctIdleTime = 0;  % Correct calculation (procEndTime -> procStartTime)

for j = 1:length(cases)
    c = cases(j);
    
    % Convert times to hours:minutes for display
    roomStart = sprintf('%02d:%02d', floor(c.startTime/60), mod(c.startTime, 60));
    procStart = sprintf('%02d:%02d', floor(c.procStartTime/60), mod(c.procStartTime, 60));
    procEnd = sprintf('%02d:%02d', floor(c.procEndTime/60), mod(c.procEndTime, 60));
    roomEnd = sprintf('%02d:%02d', floor(c.endTime/60), mod(c.endTime, 60));
    
    fprintf('\nCase %d (Lab %d):\n', j, c.lab);
    fprintf('  Room Entry:    %s (startTime)\n', roomStart);
    fprintf('  Proc Start:    %s (+%d setup)\n', procStart, c.setupTime);
    fprintf('  Proc End:      %s (+%d proc)\n', procEnd, c.procTime);
    fprintf('  Room Exit:     %s (+%d post +%d turnover)\n', roomEnd, c.postTime, c.turnoverTime);
    
    % Calculate idle times to next case
    if j < length(cases)
        next = cases(j+1);
        
        % Current method: room exit -> room entry
        currentGap = next.startTime - c.endTime;
        if currentGap > 0
            currentIdleTime = currentIdleTime + currentGap;
        end
        
        % Correct method: procedure end -> procedure start
        correctGap = next.procStartTime - c.procEndTime;
        if correctGap > 0
            correctIdleTime = correctIdleTime + correctGap;
        end
        
        fprintf('  --> Current method (room exit to room entry): %.1f min\n', currentGap);
        fprintf('  --> Correct method (proc end to proc start): %.1f min\n', correctGap);
        fprintf('  --> Difference: %.1f min\n', correctGap - currentGap);
        
        if c.lab ~= next.lab
            fprintf('  --> Lab flip from %d to %d\n', c.lab, next.lab);
        end
    end
end

fprintf('\n=== Summary ===\n');
fprintf('Current total idle time: %.1f min\n', currentIdleTime);
fprintf('Correct total idle time: %.1f min\n', correctIdleTime);
fprintf('Difference: %.1f min\n', correctIdleTime - currentIdleTime);

% Calculate per-turnover ratios
numTurnovers = length(cases) - 1;
if numTurnovers > 0
    fprintf('\nPer-turnover averages:\n');
    fprintf('Current method: %.1f min per turnover\n', currentIdleTime / numTurnovers);
    fprintf('Correct method: %.1f min per turnover\n', correctIdleTime / numTurnovers);
end

end