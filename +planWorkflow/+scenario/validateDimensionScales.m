function validateDimensionScales(runConfig)
% validateDimensionScales Enforce positive scales for active dimensions.

activeNames = planWorkflow.scenario.activeDimensionNames(runConfig);

if any(strcmp(activeNames,'setup')) && ...
        any(getConfigValue(runConfig,'shiftSD',[0 0 0]) <= 0)
    error('planWorkflow:scenario:InvalidActiveDimensionScale', ...
        'setupActive requires all shiftSD components to be positive.');
end

if any(strcmp(activeNames,'range')) && ...
        (getConfigValue(runConfig,'rangeAbsSD',0) <= 0 || ...
        getConfigValue(runConfig,'rangeRelSD',0) <= 0)
    error('planWorkflow:scenario:InvalidActiveDimensionScale', ...
        'rangeActive requires rangeAbsSD and rangeRelSD to be positive.');
end

if any(strcmp(activeNames,'gantry')) && ...
        getConfigValue(runConfig,'gantryAngleSD',0) <= 0
    error('planWorkflow:scenario:InvalidActiveDimensionScale', ...
        'gantryActive requires gantryAngleSD to be positive.');
end

if any(strcmp(activeNames,'couch')) && ...
        getConfigValue(runConfig,'couchAngleSD',0) <= 0
    error('planWorkflow:scenario:InvalidActiveDimensionScale', ...
        'couchActive requires couchAngleSD to be positive.');
end
end

function value = getConfigValue(config,fieldName,defaultValue)
if isfield(config,fieldName) && ~isempty(config.(fieldName))
    value = config.(fieldName);
else
    value = defaultValue;
end
end
