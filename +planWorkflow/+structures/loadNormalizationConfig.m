function config = loadNormalizationConfig(description)

description = normalizeDescription(description);
configFile = fullfile(fileparts(mfilename('fullpath')),'json', ...
    [description '.json']);

if ~isfile(configFile)
    error('planWorkflow:structures:loadNormalizationConfig:MissingConfig', ...
        'Missing structure normalization config for "%s": %s', ...
        description,configFile);
end

try
    spec = jsondecode(fileread(configFile));
catch ME
    error('planWorkflow:structures:loadNormalizationConfig:InvalidJson', ...
        'Could not decode structure normalization JSON "%s": %s', ...
        configFile,ME.message);
end

validateRequiredFields(spec,{'schemaVersion','description', ...
    'outputStructures','aliases'},configFile);

if ~strcmp(description,normalizeDescription(spec.description))
    error('planWorkflow:structures:loadNormalizationConfig:DescriptionMismatch', ...
        'Structure normalization file "%s" declares description "%s".', ...
        configFile,char(spec.description));
end

outputStructures = asCellstr(spec.outputStructures);
if isempty(outputStructures)
    error('planWorkflow:structures:loadNormalizationConfig:EmptyOutputs', ...
        'Structure normalization file "%s" has no output structures.', ...
        configFile);
end

config = struct();
config.description = description;
config.outputStructures = outputStructures;
config.dropUnsupported = getOptionalField(spec,'dropUnsupported',true);
config.aliasMap = buildAliasMap(spec.aliases,outputStructures,configFile);
config.derivedStructures = getOptionalField(spec,'derivedStructures', ...
    struct([]));

end

function description = normalizeDescription(description)
description = lower(strtrim(char(description)));
if isempty(description) || contains(description,'..') || ...
        contains(description,'/') || contains(description,'\')
    error('planWorkflow:structures:loadNormalizationConfig:InvalidDescription', ...
        'Invalid structure normalization description "%s".',description);
end
end

function aliasMap = buildAliasMap(aliasSpecs,outputStructures,configFile)
aliasMap = containers.Map('KeyType','char','ValueType','char');

for aliasIx = 1:numel(aliasSpecs)
    validateRequiredFields(aliasSpecs(aliasIx),{'structure','values'}, ...
        configFile);
    structureName = char(aliasSpecs(aliasIx).structure);
    if ~any(strcmp(outputStructures,structureName))
        error('planWorkflow:structures:loadNormalizationConfig:UnknownOutput', ...
            'Alias target "%s" is not listed in outputStructures in "%s".', ...
            structureName,configFile);
    end

    values = asCellstr(aliasSpecs(aliasIx).values);
    for valueIx = 1:numel(values)
        addAlias(aliasMap,values{valueIx},structureName,configFile);
    end
end
end

function addAlias(aliasMap,alias,structureName,configFile)
lookupKey = planWorkflow.structures.normalizationKey(alias);
if isempty(lookupKey)
    return;
end

if isKey(aliasMap,lookupKey) && ...
        ~strcmp(aliasMap(lookupKey),structureName)
    error('planWorkflow:structures:loadNormalizationConfig:DuplicateAlias', ...
        ['Structure normalization alias "%s" maps to both "%s" ' ...
        'and "%s" in "%s".'],char(alias),aliasMap(lookupKey), ...
        structureName,configFile);
end

aliasMap(lookupKey) = structureName;
end

function validateRequiredFields(spec,fieldNames,context)
missing = fieldNames(~isfield(spec,fieldNames));
if ~isempty(missing)
    error('planWorkflow:structures:loadNormalizationConfig:MissingField', ...
        'Missing required field "%s" in %s.',missing{1},context);
end
end

function value = getOptionalField(spec,fieldName,defaultValue)
if isstruct(spec) && isfield(spec,fieldName)
    value = spec.(fieldName);
else
    value = defaultValue;
end
end

function values = asCellstr(value)
if iscell(value)
    values = cellfun(@char,value,'UniformOutput',false);
elseif isstring(value)
    values = cellstr(value);
elseif ischar(value)
    values = {value};
else
    values = {};
end
end
