function configs = lab_capacity_study()
    % LAB_CAPACITY_STUDY - Generate configurations for lab capacity study
    % 
    % Creates multiple configurations to test different numbers of labs
    % using existing scripts from scripts/ directory
    
    baseConfig = configureExperiment();
    
    % Test different numbers of labs
    numLabsValues = [2, 3, 4, 5];
    configs = cell(length(numLabsValues), 1);
    
    for i = 1:length(numLabsValues)
        config = baseConfig;
        config.experimentName = sprintf('labs_%d', numLabsValues(i));
        config.description = sprintf('Lab capacity study: %d labs', numLabsValues(i));
        config.numLabs = numLabsValues(i);
        config.verboseOutput = false;  % Less verbose for batch runs
        configs{i} = config;
    end
    
end