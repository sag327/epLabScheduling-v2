% Test script for logging system functionality
% Version: 2.1.0

fprintf('Testing logging system...\n');

% Create a log file
timestamp = datestr(now, 'yyyymmdd_HHMMSS');
logFile = sprintf('test_log_%s.txt', timestamp);
fid = fopen(logFile, 'w');
if fid == -1
    error('Could not create test log file: %s', logFile);
end

% Write header
fprintf(fid, '=================================================================\n');
fprintf(fid, 'Test Log for Version System\n');
fprintf(fid, 'Generated: %s\n', datestr(now, 'yyyy-mm-dd HH:MM:SS'));
fprintf(fid, '=================================================================\n\n');
fclose(fid);

% Test version extraction function
try
    % Get version information from key scripts
    fprintf('Testing getScriptVersions function...\n');
    
    % Test individual script version extraction
    scripts = {'batchProcessHistoricalCases.m', 'scheduleHistoricalCases.m', 'analyzeHistoricalData.m'};
    
    fid = fopen(logFile, 'a');
    fprintf(fid, 'SCRIPT VERSIONS (Manual Test):\n');
    fprintf(fid, '==============================\n');
    
    for i = 1:length(scripts)
        scriptName = scripts{i};
        [~, name, ~] = fileparts(scriptName);
        
        fprintf('Checking %s...\n', scriptName);
        
        if exist(scriptName, 'file')
            scriptFid = fopen(scriptName, 'r');
            version = 'Unknown';
            
            if scriptFid ~= -1
                for j = 1:10  % Check first 10 lines
                    line = fgetl(scriptFid);
                    if ischar(line) && contains(line, 'Version:')
                        % Extract version number
                        versionMatch = regexp(line, 'Version:\s*([^\s]+)', 'tokens');
                        if ~isempty(versionMatch)
                            version = versionMatch{1}{1};
                            break;
                        end
                    end
                end
                fclose(scriptFid);
            end
            
            fprintf(fid, '%-30s: %s\n', name, version);
            fprintf('  Found version: %s\n', version);
        else
            fprintf(fid, '%-30s: Not Found\n', name);
            fprintf('  File not found\n');
        end
    end
    
    % Add MATLAB info
    fprintf(fid, '\nSYSTEM INFO:\n');
    fprintf(fid, '============\n');
    try
        matlabVer = version('-release');
        fprintf(fid, 'MATLAB Version: %s\n', matlabVer);
    catch
        fprintf(fid, 'MATLAB Version: Unknown\n');
    end
    fprintf(fid, 'Computer: %s\n', computer);
    
    fclose(fid);
    
    fprintf('Test completed successfully!\n');
    fprintf('Test log saved to: %s\n', logFile);
    
catch ME
    fprintf('Error during test: %s\n', ME.message);
    if exist('fid', 'var') && fid ~= -1
        fclose(fid);
    end
end