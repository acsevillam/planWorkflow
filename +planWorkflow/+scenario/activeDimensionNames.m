function names = activeDimensionNames(runConfig)
% activeDimensionNames Convert planWorkflow config flags to matRad dimensions.

if isfield(runConfig,'scenarioDimensionActive') && ...
        ~isempty(runConfig.scenarioDimensionActive)
    names = normalizeNames(runConfig.scenarioDimensionActive);
    return;
end

names = {};
if getLogicalConfigValue(runConfig,'ctActive',true)
    names{end + 1} = 'ct';
end
if getLogicalConfigValue(runConfig,'setupActive',true)
    names{end + 1} = 'setup';
end
if getLogicalConfigValue(runConfig,'rangeActive',false)
    names{end + 1} = 'range';
end
if getLogicalConfigValue(runConfig,'gantryActive',false)
    names{end + 1} = 'gantry';
end
if getLogicalConfigValue(runConfig,'couchActive',false)
    names{end + 1} = 'couch';
end
end

function value = getLogicalConfigValue(config,fieldName,defaultValue)
if isfield(config,fieldName) && ~isempty(config.(fieldName))
    value = config.(fieldName);
else
    value = defaultValue;
end

if ischar(value) || (isstring(value) && isscalar(value))
    value = strcmpi(char(value),'true');
end
value = logical(value);
if ~isscalar(value)
    error('planWorkflow:scenario:InvalidDimensionActiveFlag', ...
        'Scenario dimension flag "%s" must be scalar logical.',fieldName);
end
end

function names = normalizeNames(names)
if ischar(names)
    names = {names};
elseif isstring(names)
    names = cellstr(names(:)');
elseif ~iscell(names)
    error('planWorkflow:scenario:InvalidDimensionActiveNames', ...
        'scenarioDimensionActive must be a cellstr, string array, or char.');
end
names = names(:)';
end
