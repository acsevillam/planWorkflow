function [cst,flag] = pullDose(cst,pullingStep)
% pullDose applies one cumulative dose pulling increment.
%
% Each call applies one increment to objectives with dosePulling enabled and
% matching pullingStep. Repeated calls with the same pullingStep
% intentionally accumulate the configured rates. Missing pulling fields are
% treated as disabled or zero rates.

flag = false;

for i = 1:size(cst,1)
    if ~isempty(cst{i,4}{1})
        for j = 1:numel(cst{i,6})
            objective = cst{i,6}{j};
            if shouldApplyDosePulling(objective,pullingStep)
                [objective,objectiveWasUpdated] = applyDosePullingIncrement(objective);
                flag = flag || objectiveWasUpdated;
                cst{i,6}{j} = objective;
            end
        end
    end
end
end

function tf = shouldApplyDosePulling(objective,pullingStep)
tf = false;

dosePulling = getObjectiveField(objective,'dosePulling',false);
if ~islogical(dosePulling) && ~(isnumeric(dosePulling) && isscalar(dosePulling))
    return;
end

if ~logical(dosePulling)
    return;
end

objectivePullingStep = getObjectiveField(objective,'pullingStep',[]);
tf = isnumeric(objectivePullingStep) && isscalar(objectivePullingStep) && ...
    objectivePullingStep == pullingStep;
end

function [objective,wasUpdated] = applyDosePullingIncrement(objective)
wasUpdated = false;

if hasObjectiveField(objective,'parameters')
    parameters = getObjectiveField(objective,'parameters',{});
    pullingRates = getObjectiveField(objective,'objectivePullingRate',{});
    parametersWereUpdated = false;

    if iscell(parameters)
        for k = 1:numel(parameters)
            pullingRate = getCellValue(pullingRates,k,[]);
            [parameter,parameterWasUpdated] = applyNonnegativeIncrement(parameters{k},pullingRate);
            if parameterWasUpdated
                parameters{k} = parameter;
                parametersWereUpdated = true;
                wasUpdated = true;
            end
        end
    end

    if parametersWereUpdated
        objective = setObjectiveField(objective,'parameters',parameters);
    end
end

if hasObjectiveField(objective,'penalty')
    penaltyPullingRate = getObjectiveField(objective,'penaltyPullingRate',[]);
    penalty = getObjectiveField(objective,'penalty',[]);
    [penalty,penaltyWasUpdated] = applyNonnegativeIncrement(penalty,penaltyPullingRate);
    if penaltyWasUpdated
        objective = setObjectiveField(objective,'penalty',penalty);
        wasUpdated = true;
    end
end
end

function [value,wasUpdated] = applyNonnegativeIncrement(value,increment)
wasUpdated = false;

if ~isnumeric(value) || ~isscalar(value) || ~isfinite(value) || ...
        ~isnumeric(increment) || ~isscalar(increment) || ...
        ~isfinite(increment) || increment == 0
    return;
end

newValue = max(0,value + increment);
if newValue ~= value
    value = newValue;
    wasUpdated = true;
end
end

function value = getObjectiveField(objective,fieldName,defaultValue)
if hasObjectiveField(objective,fieldName)
    value = objective.(fieldName);
else
    value = defaultValue;
end
end

function objective = setObjectiveField(objective,fieldName,value)
if hasObjectiveField(objective,fieldName)
    objective.(fieldName) = value;
end
end

function tf = hasObjectiveField(objective,fieldName)
tf = (isstruct(objective) && isfield(objective,fieldName)) || ...
    (isobject(objective) && isprop(objective,fieldName));
end

function value = getCellValue(values,index,defaultValue)
if iscell(values) && numel(values) >= index
    value = values{index};
else
    value = defaultValue;
end
end
