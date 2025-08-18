function labMappings = getHistoricalLabMappings(historicalSchedules)
% Extract and consolidate lab mappings from historical schedules
%
% Input:
%   historicalSchedules - Map containing historical schedule data
%
% Output:
%   labMappings - Structure containing:
%     .globalMapping - Map of all unique rooms with their assigned lab numbers
%     .dateSpecificMappings - Map showing lab mappings for each date
%     .roomUsageStats - Statistics about room usage across dates
%
% Example:
%   [~, schedules] = loadHistoricalDataFromFile('procedureDurationsB.xlsx');
%   mappings = getHistoricalLabMappings(schedules);

if isempty(historicalSchedules) || historicalSchedules.Count == 0
    labMappings = struct();
    fprintf('No historical schedules provided\n');
    return;
end

% Initialize output structure
labMappings = struct();
labMappings.globalMapping = containers.Map();
labMappings.dateSpecificMappings = containers.Map();
labMappings.roomUsageStats = struct();

% Collect all unique room names across all dates
allRooms = {};
dates = keys(historicalSchedules);

fprintf('Analyzing lab mappings across %d dates...\n', length(dates));

% First pass: collect all unique rooms
for i = 1:length(dates)
    dateStr = dates{i};
    scheduleData = historicalSchedules(dateStr);
    
    if isfield(scheduleData, 'labMapping')
        labMapping = scheduleData.labMapping;
        labIndices = keys(labMapping);
        
        for j = 1:length(labIndices)
            labIdx = labIndices{j};
            roomName = labMapping(labIdx);
            
            if ~ismember(roomName, allRooms)
                allRooms{end+1} = roomName;
            end
        end
    end
end

% Create global lab numbering for all unique rooms
allRooms = sort(allRooms); % Sort alphabetically for consistency
globalLabMapping = containers.Map();

for i = 1:length(allRooms)
    globalLabMapping(allRooms{i}) = i;
end

labMappings.globalMapping = globalLabMapping;

fprintf('Found %d unique rooms across all dates:\n', length(allRooms));
for i = 1:length(allRooms)
    fprintf('  Lab %d: %s\n', i, allRooms{i});
end

% Second pass: record date-specific mappings and usage statistics
roomUsageCount = containers.Map();
for i = 1:length(allRooms)
    roomUsageCount(allRooms{i}) = 0;
end

for i = 1:length(dates)
    dateStr = dates{i};
    scheduleData = historicalSchedules(dateStr);
    
    if isfield(scheduleData, 'labMapping')
        labMapping = scheduleData.labMapping;
        
        % Store date-specific mapping
        labMappings.dateSpecificMappings(dateStr) = labMapping;
        
        % Count room usage
        labIndices = keys(labMapping);
        for j = 1:length(labIndices)
            labIdx = labIndices{j};
            roomName = labMapping(labIdx);
            
            currentCount = roomUsageCount(roomName);
            roomUsageCount(roomName) = currentCount + 1;
        end
    end
end

% Create room usage statistics
roomNames = keys(roomUsageCount);
usageCounts = cell2mat(values(roomUsageCount));

labMappings.roomUsageStats.roomNames = roomNames;
labMappings.roomUsageStats.usageCounts = usageCounts;
labMappings.roomUsageStats.totalDates = length(dates);

% Calculate usage percentages
usagePercentages = (usageCounts / length(dates)) * 100;
labMappings.roomUsageStats.usagePercentages = usagePercentages;

% Display usage statistics
fprintf('\nRoom Usage Statistics:\n');
[sortedUsage, sortIdx] = sort(usageCounts, 'descend');
sortedRooms = roomNames(sortIdx);
sortedPercentages = usagePercentages(sortIdx);

for i = 1:length(sortedRooms)
    globalLabNum = globalLabMapping(sortedRooms{i});
    fprintf('  Lab %d (%s): %d days (%.1f%%)\n', ...
        globalLabNum, sortedRooms{i}, sortedUsage(i), sortedPercentages(i));
end

% Save mappings to file
outputFile = './data/historicalLabMappings.mat';
save(outputFile, 'labMappings');
fprintf('\nLab mappings saved to %s\n', outputFile);

end