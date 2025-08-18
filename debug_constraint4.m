% Debug Constraint 4 issues
clear; clc;

% Create minimal test case
cases = struct();
cases(1).operator = 'Dr. Smith';
cases(1).caseID = 'EP001';
cases(1).procTime = 180;
cases(1).setupTime = 30;
cases(1).postTime = 15;
cases(1).procedure = 'Test';
cases(1).location = 'EP Lab';
cases(1).service = 'EP';
cases(1).admissionStatus = 'Outpatient';
cases(1).priority = [];
cases(1).preferredLab = [];

numLabs = 3;
labStartTimes = {'8:00', '8:00', '8:00'};
timeStep = 10;
maxHorizon = 600; % 10 hours

% Convert times
timeHorizon = ceil(maxHorizon / timeStep) * timeStep;
timeSlots = 0:timeStep:timeHorizon;
numTimeSlots = length(timeSlots);

labStartMinutes = [480, 480, 480]; % 8:00 AM

% Pre-filter valid time slots
validTimeSlots = cell(numLabs, 1);
for j = 1:numLabs
    labStart = labStartMinutes(j);
    validTimeSlots{j} = find(timeSlots >= labStart);
end

% Lab preferences (all labs allowed)
labPreferences = ones(1, numLabs);
numCases = 1;

fprintf('Debugging Constraint 4 construction...\n');
fprintf('Time slots: %d\n', numTimeSlots);
fprintf('Valid time slots for each lab:\n');
for j = 1:numLabs
    fprintf('  Lab %d: %d valid slots (from slot %d)\n', j, length(validTimeSlots{j}), validTimeSlots{j}(1));
end

% Test constraint 4 logic
constraint4Rows = [];
constraint4Cols = [];
constraintIdx = 0;

for j = 1:numLabs
    labStart = labStartMinutes(j);
    invalidTimeSlots = find(timeSlots < labStart);
    fprintf('Lab %d: %d invalid time slots\n', j, length(invalidTimeSlots));
    
    for i = 1:numCases
        if labPreferences(i, j) == 1
            for t = invalidTimeSlots'
                constraintIdx = constraintIdx + 1;
                constraint4Rows = [constraint4Rows; constraintIdx];
                % Calculate variable index
                varIdx = (i - 1) * numLabs * numTimeSlots + (j - 1) * numTimeSlots + t;
                constraint4Cols = [constraint4Cols; varIdx];
                fprintf('  Constraint %d: case %d, lab %d, time %d -> var %d\n', constraintIdx, i, j, t, varIdx);
            end
        end
    end
end

fprintf('Total constraint 4 entries: %d\n', constraintIdx);
fprintf('Rows length: %d\n', length(constraint4Rows));
fprintf('Cols length: %d\n', length(constraint4Cols));

if constraintIdx > 0 && length(constraint4Rows) == length(constraint4Cols)
    constraint4Values = ones(length(constraint4Rows), 1);
    fprintf('Values length: %d\n', length(constraint4Values));
    fprintf('All vector lengths match - constraint 4 should work!\n');
else
    fprintf('ERROR: Vector length mismatch!\n');
end