function configs = turnover_study()
    % TURNOVER_STUDY - Generate configurations for turnover time study
    % 
    % Creates multiple configurations to test different turnover times
    % using existing scripts from scripts/ directory
    
    baseConfig = baseline_config();
    
    % Test different turnover times
    turnoverTimes = [5, 10, 15, 20, 30];
    configs = cell(length(turnoverTimes), 1);
    
    for i = 1:length(turnoverTimes)
        config = baseConfig;
        config.experimentName = sprintf('turnover_%dmin', turnoverTimes(i));
        config.description = sprintf('Turnover time study: %d minutes', turnoverTimes(i));
        config.turnoverTime = turnoverTimes(i);
        config.verboseOutput = false;  % Less verbose for batch runs
        configs{i} = config;
    end
    
end