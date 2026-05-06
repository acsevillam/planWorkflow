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
if any(strcmp(cst(:,2),skinName))
    return;
end

sourceName = char(derivedSpec.source);
ixSource = find(strcmp(cst(:,2),sourceName),1);
if isempty(ixSource)
    return;
end

metadata.name = skinName;
metadata.type = char(derivedSpec.type);
metadata.visibleColor = double(derivedSpec.visibleColor(:)');

skinArgs = {'mode',getRunConfigValue(runConfig, ...
    char(derivedSpec.modeField),char(derivedSpec.defaultMode))};
skinThicknessMm = getRunConfigValue(runConfig, ...
    char(derivedSpec.thicknessField),[]);
if ~isempty(skinThicknessMm)
    skinArgs = [skinArgs {'thicknessMm',skinThicknessMm}];
end

if strcmp(char(skinArgs{2}),'targetRegion')
    targetIndex = getSkinTargetIndex(cst,runConfig,derivedSpec);
    skinArgs = [skinArgs {'targetIndex',targetIndex, ...
        'targetDistanceMm',getRunConfigValue(runConfig, ...
        char(derivedSpec.targetDistanceField), ...
        derivedSpec.defaultTargetDistanceMm)}];
end

[cst,~] = planWorkflow.structures.createSkin( ...
    ixSource,cst,ct,metadata,skinArgs{:});
end

function targetIndex = getSkinTargetIndex(cst,runConfig,derivedSpec)
targetName = getPlanTargetName(runConfig,derivedSpec);
targetIndex = find(strcmp(cst(:,2),targetName),1);

if isempty(targetIndex)
    error('planWorkflow:structures:normalizeNames:MissingSkinTarget', ...
        'A valid target structure is required when skinMode is targetRegion.');
end
end

function targetName = getPlanTargetName(runConfig,derivedSpec)
targetName = char(getRunConfigValue(runConfig, ...
    char(derivedSpec.targetField),''));
if ~isempty(targetName)
    return;
end

try
    template = planWorkflow.templates.PlanTemplate.resolve(runConfig);
    targetName = char(template.primaryTarget);
catch
    targetName = char(derivedSpec.defaultTarget);
end
end

function value = getRunConfigValue(runConfig,fieldName,defaultValue)
if isstruct(runConfig) && isfield(runConfig,fieldName)
    value = runConfig.(fieldName);
else
    value = defaultValue;
end
end

function cst = reindexCst(cst)
for it = 1:size(cst,1)
    cst{it,1}=it-1;
end
end
