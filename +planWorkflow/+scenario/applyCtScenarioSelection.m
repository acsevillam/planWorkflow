function applyCtScenarioSelection(multScen,ct,runConfig)
% applyCtScenarioSelection Select active CT scenarios for a matRad model.

ctActive = getLogicalConfigValue(runConfig,'ctActive',true);
if ctActive
    ctScenProb = getConfigValue(runConfig,'ctScenProb',[]);
    multScen.ctScenProb = ...
        planWorkflow.config.ScenarioSpec.ctScenProbMatrix( ...
        ctScenProb,ct,'ctScenProb');
    return;
end

ctScenProb = getConfigValue(runConfig,'ctScenProb',[]);
if ~isempty(ctScenProb)
    error('planWorkflow:scenario:IncompatibleCtScenProb', ...
        ['ctScenProb is only valid when ctActive is true. Use ' ...
         'ctReferenceScenId for a single CT scenario.']);
end
ctReferenceScenId = getConfigValue(runConfig,'ctReferenceScenId',1);
validateCtReferenceScenId(ctReferenceScenId,ct);
multScen.ctScenProb = [ctReferenceScenId 1];
end

function validateCtReferenceScenId(ctReferenceScenId,ct)
valid = isnumeric(ctReferenceScenId) && isscalar(ctReferenceScenId) && ...
    isfinite(ctReferenceScenId) && ctReferenceScenId >= 1 && ...
    round(ctReferenceScenId) == ctReferenceScenId;
if ~valid
    error('planWorkflow:scenario:InvalidCtReferenceScenario', ...
        'ctReferenceScenId must be a positive integer scalar.');
end

if nargin >= 2 && ~isempty(ct) && isfield(ct,'numOfCtScen') && ...
        ctReferenceScenId > ct.numOfCtScen
    error('planWorkflow:scenario:InvalidCtReferenceScenario', ...
        'ctReferenceScenId %d exceeds ct.numOfCtScen %d.', ...
        ctReferenceScenId,ct.numOfCtScen);
end
end

function value = getConfigValue(config,fieldName,defaultValue)
if isfield(config,fieldName) && ~isempty(config.(fieldName))
    value = config.(fieldName);
else
    value = defaultValue;
end
end

function value = getLogicalConfigValue(config,fieldName,defaultValue)
value = getConfigValue(config,fieldName,defaultValue);
if ischar(value) || (isstring(value) && isscalar(value))
    value = any(strcmpi(char(value),{'true','1','yes','on'}));
end
value = logical(value);
if ~isscalar(value)
    error('planWorkflow:scenario:InvalidCtActiveFlag', ...
        'ctActive must be scalar logical.');
end
end
