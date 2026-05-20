function [cst,report] = normalizeNames(cst,runConfig,ct)

if nargin < 3
    ct = [];
end

normalizationConfig = ...
    planWorkflow.structures.loadNormalizationConfig(runConfig.description);
report = emptyReport(normalizationConfig.description);
[cst,report] = applyNormalizationConfig(cst,normalizationConfig,report);
cst = applyDerivedStructures(cst,normalizationConfig,runConfig,ct);
cst = reindexCst(cst);

end

function [cst,report] = applyNormalizationConfig( ...
    cst,normalizationConfig,report)
for it = size(cst,1):-1:1
    originalName = char(cst{it,2});
    lookupKey = planWorkflow.structures.normalizationKey(originalName);

    if isKey(normalizationConfig.aliasMap,lookupKey)
        normalizedName = normalizationConfig.aliasMap(lookupKey);
        if ~strcmp(originalName,normalizedName)
            report.renamed(end + 1,1) = struct( ...
                'row',it, ...
                'originalName',originalName, ...
                'normalizedName',normalizedName);
        end
        cst{it,2} = normalizedName;
    elseif normalizationConfig.dropUnsupported
        report.dropped(end + 1,1) = struct( ...
            'row',it, ...
            'name',originalName, ...
            'reason',sprintf('unsupported %s structure', ...
            normalizationConfig.description));
        cst(it,:) = [];
    end
end
end

function report = emptyReport(description)
report = struct();
report.description = char(description);
report.renamed = repmat(struct( ...
    'row',[],'originalName','','normalizedName',''),0,1);
report.dropped = repmat(struct( ...
    'row',[],'name','','reason',''),0,1);
end

function cst = applyDerivedStructures(cst,normalizationConfig,runConfig,ct)
for derivedIx = 1:numel(normalizationConfig.derivedStructures)
    derivedSpec = normalizationConfig.derivedStructures(derivedIx);
    switch char(derivedSpec.kind)
        case 'skinFromBody'
            cst = applySkinFromBody(cst,derivedSpec,runConfig,ct);
        otherwise
            error('planWorkflow:structures:normalizeNames:UnknownDerivedStructure', ...
                'Unknown derived structure kind "%s".', ...
                char(derivedSpec.kind));
    end
end
end

function cst = applySkinFromBody(cst,derivedSpec,runConfig,ct)
if isempty(ct)
    return;
end

skinName = char(derivedSpec.name);
existingSkin = strcmp(cst(:,2),skinName);
if any(existingSkin)
    if ~logical(getOptionalSpecValue(derivedSpec,'replaceExisting',false))
        return;
    end
    cst(existingSkin,:) = [];
end

sourceName = char(derivedSpec.source);
ixSource = find(strcmp(cst(:,2),sourceName),1);
if isempty(ixSource)
    return;
end

metadata.name = skinName;
metadata.type = char(derivedSpec.type);
metadata.visibleColor = double(derivedSpec.visibleColor(:)');

skinArgs = {'mode',getSkinMode(runConfig,derivedSpec)};
defaultThicknessMm = getOptionalSpecValue(derivedSpec, ...
    'defaultThicknessMm',[]);
skinThicknessMm = getRunConfigValue(runConfig, ...
    char(derivedSpec.thicknessField),defaultThicknessMm);
if isempty(skinThicknessMm)
    skinThicknessMm = defaultThicknessMm;
end
if ~isempty(skinThicknessMm)
    skinArgs = [skinArgs {'thicknessMm',skinThicknessMm}];
end
if logical(getOptionalSpecValue(derivedSpec,'excludeCtBoundaryZ',false))
    skinArgs = [skinArgs {'excludeCtBoundaryZ',true}];
end

if strcmp(char(skinArgs{2}),'targetRegion')
    targetIndex = getSkinTargetIndex(cst,runConfig,derivedSpec);
    skinArgs = [skinArgs {'targetIndex',targetIndex}];
    targetDistanceMm = getTargetDistanceMm(runConfig,derivedSpec);
    if ~isempty(targetDistanceMm)
        skinArgs = [skinArgs {'targetDistanceMm',targetDistanceMm}];
    end
end

[cst,~] = planWorkflow.structures.createSkin( ...
    ixSource,cst,ct,metadata,skinArgs{:});
end

function skinMode = getSkinMode(runConfig,derivedSpec)
skinMode = getRunConfigValue(runConfig, ...
    char(derivedSpec.modeField),char(derivedSpec.defaultMode));
if isempty(skinMode)
    skinMode = char(derivedSpec.defaultMode);
end
skinMode = char(skinMode);
end

function targetIndex = getSkinTargetIndex(cst,runConfig,derivedSpec)
targetName = getPlanTargetName(runConfig,derivedSpec);
targetIndex = find(strcmp(cst(:,2),targetName),1);

if isempty(targetIndex)
    error('planWorkflow:structures:normalizeNames:MissingSkinTarget', ...
        'A valid target structure is required when skinMode is targetRegion.');
end
end

function targetDistanceMm = getTargetDistanceMm(runConfig,derivedSpec)
defaultTargetDistanceMm = getOptionalSpecValue(derivedSpec, ...
    'defaultTargetDistanceMm',[]);
targetDistanceMm = getRunConfigValue(runConfig, ...
    char(derivedSpec.targetDistanceField),defaultTargetDistanceMm);
if isempty(targetDistanceMm)
    targetDistanceMm = defaultTargetDistanceMm;
end
end

function targetName = getPlanTargetName(runConfig,derivedSpec)
targetName = char(getRunConfigValue(runConfig, ...
    char(derivedSpec.targetField),''));
if ~isempty(targetName)
    return;
end

targetName = char(getOptionalSpecValue(derivedSpec,'defaultTarget',''));
if ~isempty(targetName)
    return;
end

try
    template = planWorkflow.templates.PlanTemplate.resolve(runConfig);
    targetName = char(template.primaryTarget);
catch
    targetName = '';
end
end

function value = getRunConfigValue(runConfig,fieldName,defaultValue)
if isstruct(runConfig) && isfield(runConfig,fieldName)
    value = runConfig.(fieldName);
else
    value = defaultValue;
end
end

function value = getOptionalSpecValue(spec,fieldName,defaultValue)
if isstruct(spec) && isfield(spec,fieldName)
    value = spec.(fieldName);
else
    value = defaultValue;
end
end

function cst = reindexCst(cst)
for it = 1:size(cst,1)
    cst{it,1}=it-1;
end
end
