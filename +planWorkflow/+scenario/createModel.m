function multScen = createModel(ct,scenarioMode,runConfig,workflowStage)
% createModel Build matRad scenario model objects.
%
% This factory uses the current matRad scenario classes directly and keeps all
% uncertainty settings explicit in the created model object.

if nargin < 4 || isempty(workflowStage)
    workflowStage = 'optimization';
end

scenarioMode = char(scenarioMode);
workflowStage = char(workflowStage);
validWorkflowStages = {'optimization','sampling'};
if ~any(strcmp(workflowStage,validWorkflowStages))
    error('planWorkflow:scenario:createModel:UnsupportedWorkflowStage', ...
        'Unsupported workflow stage "%s". Use optimization or sampling.', ...
        workflowStage);
end

shiftSD = getConfigValue(runConfig,'shiftSD',[2.25 2.25 2.25]);
wcSigma = getConfigValue(runConfig,'wcSigma',1.0);
rangeAbsSD = getConfigValue(runConfig,'rangeAbsSD',0);
rangeRelSD = getConfigValue(runConfig,'rangeRelSD',0);
rangeGridPoints = getConfigValue(runConfig,'numOfRangeGridPoints',1);
[rangeAbsSD,rangeRelSD] = ensurePositiveRangeUncertainty(rangeAbsSD,rangeRelSD);

if strcmp(workflowStage,'sampling')
    wcSigma = getConfigValue(runConfig,'sampling_wcSigma',wcSigma);
end

switch scenarioMode
    case 'nomScen'
        multScen = matRad_NominalScenario(ct);

    case 'wcScen'
        multScen = matRad_WorstCaseScenarios(ct);
        multScen.wcSigma = wcSigma;
        multScen.shiftSD = shiftSD;
        multScen.rangeAbsSD = rangeAbsSD;
        multScen.rangeRelSD = rangeRelSD;
        multScen.numOfRangeGridPoints = rangeGridPoints;
        multScen.combinations = 'none';
        multScen.combineRange = true;
        multScen.updateScenarios();

    case {'impScen','impScen5','impScen7','impScen_permuted5','impScen_permuted7', ...
          'impScen_truncated','impScen5_truncated','impScen7_truncated', ...
          'impScen_permuted5_truncated','impScen_permuted7_truncated'}
        if isTruncatedImportanceMode(scenarioMode)
            multScen = matRad_TruncatedImportanceScenarios(ct);
        else
            multScen = matRad_ImportanceScenarios(ct);
        end
        multScen.wcSigma = wcSigma;
        multScen.shiftSD = shiftSD;
        multScen.rangeAbsSD = rangeAbsSD;
        multScen.rangeRelSD = rangeRelSD;
        [setupGridPoints,combinations] = importanceScenarioSettings(scenarioMode);
        multScen.numOfSetupGridPoints = setupGridPoints;
        multScen.numOfRangeGridPoints = rangeGridPoints;
        multScen.combinations = combinations;
        multScen.combineRange = true;
        multScen.updateScenarios();

    case 'random'
        multScen = matRad_RandomScenarios(ct);
        multScen.shiftSD = shiftSD;
        multScen.rangeAbsSD = rangeAbsSD;
        multScen.rangeRelSD = rangeRelSD;
        multScen.nSamples = getConfigValue(runConfig,'sampling_size',50);
        multScen.includeNominalScenario = true;

    otherwise
        error('planWorkflow:scenario:createModel:UnsupportedScenarioMode', ...
            ['Unsupported scenario mode "%s". Use nomScen, wcScen, ' ...
             'impScen, impScen5, impScen7, impScen_permuted5, ' ...
             'impScen_permuted7, their *_truncated variants, or random.'], ...
             scenarioMode);
end
end

function [rangeAbsSD,rangeRelSD] = ensurePositiveRangeUncertainty(rangeAbsSD,rangeRelSD)
% Scenario probability calculation uses a Cholesky factor. Keep the
% covariance positive definite while one range grid point keeps range shifts
% nominal.
if rangeAbsSD == 0
    rangeAbsSD = eps;
end

if rangeRelSD == 0
    rangeRelSD = eps;
end
end

function value = getConfigValue(config,fieldName,defaultValue)
if isfield(config,fieldName) && ~isempty(config.(fieldName))
    value = config.(fieldName);
else
    value = defaultValue;
end
end

function isTruncated = isTruncatedImportanceMode(scenarioMode)
isTruncated = ~isempty(regexp(scenarioMode,'_truncated$','once'));
end

function [setupGridPoints,combinations] = importanceScenarioSettings(scenarioMode)
scenarioMode = regexprep(scenarioMode,'_truncated$','');
setupGridPoints = 9;
combinations = 'none';

switch scenarioMode
    case 'impScen5'
        setupGridPoints = 5;
    case 'impScen7'
        setupGridPoints = 7;
    case 'impScen_permuted5'
        setupGridPoints = 5;
        combinations = 'shift';
    case 'impScen_permuted7'
        setupGridPoints = 7;
        combinations = 'shift';
end
end
