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

rawRunConfig = runConfig;
runConfig = canonicalScenarioConfig(rawRunConfig,scenarioMode);
scenarioMode = runConfig.scen_mode;
shiftSD = runConfig.shiftSD;
wcSigma = runConfig.wcSigma;
rangeAbsSD = runConfig.rangeAbsSD;
rangeRelSD = runConfig.rangeRelSD;
gantryAngleSD = runConfig.gantryAngleSD;
couchAngleSD = runConfig.couchAngleSD;
rangeGridPoints = runConfig.numOfRangeGridPoints;
randomSize = runConfig.random_size;
randomSeed = runConfig.randomSeed;
numOfBeams = getConfigValue(rawRunConfig,'numOfBeams',0);
activeDimensionNames = planWorkflow.scenario.activeDimensionNames( ...
    runConfig);

if strcmp(workflowStage,'sampling')
    wcSigma = getConfigValue(rawRunConfig,'sampling_wcSigma',wcSigma);
    randomSize = getConfigValue(rawRunConfig,'sampling_size',randomSize);
    runConfig.ctScenProb = getConfigValue(rawRunConfig, ...
        'sampling_ctScenProb',runConfig.ctScenProb);
end

validateAngularDimensionSupport(scenarioMode,activeDimensionNames, ...
    numOfBeams);
validateGriddedScenarioSupport(scenarioMode,runConfig);

switch scenarioMode
    case 'nomScen'
        multScen = matRad_createScenarioModel(ct,'nomScen');
        multScen = applyScenarioDimensions(multScen,activeDimensionNames, ...
            shiftSD,rangeAbsSD,rangeRelSD,gantryAngleSD,couchAngleSD, ...
            numOfBeams);
        planWorkflow.scenario.applyCtScenarioSelection( ...
            multScen,ct,runConfig);

    case 'wcScen'
        multScen = matRad_createScenarioModel(ct,'wcScen');
        multScen = applyScenarioDimensions(multScen,activeDimensionNames, ...
            shiftSD,rangeAbsSD,rangeRelSD,gantryAngleSD,couchAngleSD, ...
            numOfBeams);
        planWorkflow.scenario.applyCtScenarioSelection( ...
            multScen,ct,runConfig);
        multScen.wcSigma = wcSigma;
        multScen.numOfRangeGridPoints = rangeGridPoints;
        multScen.combinations = 'none';
        multScen.combineRange = true;
        multScen.updateScenarios();

    case {'impScen','impScen5','impScen7','impScen_permuted5','impScen_permuted7', ...
          'impScen_permuted5_truncated','impScen_permuted7_truncated'}
        if isTruncatedImportanceMode(scenarioMode)
            multScen = matRad_createScenarioModel(ct,'truncatedImpScen');
        else
            multScen = matRad_createScenarioModel(ct,'impScen');
        end
        multScen = applyScenarioDimensions(multScen,activeDimensionNames, ...
            shiftSD,rangeAbsSD,rangeRelSD,gantryAngleSD,couchAngleSD, ...
            numOfBeams);
        planWorkflow.scenario.applyCtScenarioSelection( ...
            multScen,ct,runConfig);
        multScen.wcSigma = wcSigma;
        [setupGridPoints,combinations] = importanceScenarioSettings(scenarioMode);
        multScen.numOfSetupGridPoints = setupGridPoints;
        multScen.numOfRangeGridPoints = rangeGridPoints;
        multScen.combinations = combinations;
        multScen.combineRange = true;
        multScen.updateScenarios();

    case {'random','truncatedRndScen'}
        multScen = matRad_createScenarioModel( ...
            ct,sampledScenarioMatRadName(scenarioMode));
        multScen = applyScenarioDimensions(multScen,activeDimensionNames, ...
            shiftSD,rangeAbsSD,rangeRelSD,gantryAngleSD,couchAngleSD, ...
            numOfBeams);
        planWorkflow.scenario.applyCtScenarioSelection( ...
            multScen,ct,runConfig);
        multScen.nSamples = randomSize;
        multScen.includeNominalScenario = true;
        applyRandomSeed(multScen,randomSeed);

    otherwise
        error('planWorkflow:scenario:createModel:UnsupportedScenarioMode', ...
            ['Unsupported scenario mode "%s". Use nomScen, wcScen, ' ...
             'impScen, impScen5, impScen7, impScen_permuted5, ' ...
             'impScen_permuted7, permuted *_truncated variants, ' ...
             'random, or truncatedRndScen.'], ...
             scenarioMode);
end
end

function validateGriddedScenarioSupport(scenarioMode,runConfig)
if ~isLegacyGriddedScenarioMode(scenarioMode)
    return;
end

activeDimensionNames = planWorkflow.scenario.activeDimensionNames( ...
    runConfig);
if ~any(strcmp(activeDimensionNames,'setup')) || ...
        ~any(strcmp(activeDimensionNames,'range'))
    error('planWorkflow:scenario:createModel:InvalidGriddedDimensions', ...
        ['The current matRad gridded scenario models require active ' ...
         'setup and range dimensions. Use random or truncatedRndScen ' ...
         'for sparse or extended dimension subsets.']);
end

shiftSD = getConfigValue(runConfig,'shiftSD',[5 10 5]);
rangeAbsSD = getConfigValue(runConfig,'rangeAbsSD',1);
rangeRelSD = getConfigValue(runConfig,'rangeRelSD',3.5);
numOfRangeGridPoints = getConfigValue(runConfig,'numOfRangeGridPoints',3);
validUncertaintyScale = all(shiftSD(:) > 0) && ...
    rangeAbsSD > 0 && rangeRelSD > 0;
if ~validUncertaintyScale
    error('planWorkflow:scenario:createModel:InvalidGriddedScale', ...
        ['The current matRad gridded scenario models require positive ' ...
         'setup and range uncertainty scales.']);
end

validRangeGrid = isnumeric(numOfRangeGridPoints) && ...
    isscalar(numOfRangeGridPoints) && isfinite(numOfRangeGridPoints) && ...
    round(numOfRangeGridPoints) == numOfRangeGridPoints && ...
    numOfRangeGridPoints >= 3;
if ~validRangeGrid
    error('planWorkflow:scenario:createModel:InvalidRangeGrid', ...
        ['The current matRad gridded scenario models require at least ' ...
         'three range grid points to preserve non-singleton legacy ' ...
         'ct/setup/range storage.']);
end
end

function tf = isLegacyGriddedScenarioMode(scenarioMode)
tf = any(strcmp(char(scenarioMode), ...
    {'wcScen','impScen','impScen5','impScen7', ...
     'impScen_permuted5','impScen_permuted7', ...
     'impScen_permuted5_truncated','impScen_permuted7_truncated'}));
end

function modelName = sampledScenarioMatRadName(scenarioMode)
switch char(scenarioMode)
    case 'random'
        modelName = 'rndScen';
    case 'truncatedRndScen'
        modelName = 'truncatedRndScen';
end
end

function tf = isSampledScenarioMode(scenarioMode)
tf = any(strcmp(char(scenarioMode),{'random','truncatedRndScen'}));
end

function applyRandomSeed(multScen,randomSeed)
if isempty(randomSeed)
    return;
end

if ~isprop(multScen,'randomSeed')
    error('planWorkflow:scenario:createModel:MissingRandomSeedApi', ...
        ['The loaded matRad random scenario model does not expose ' ...
         'randomSeed. Update matRad before using reproducible random ' ...
         'scenario generation.']);
end

multScen.randomSeed = randomSeed;
end

function multScen = applyScenarioDimensions(multScen,activeDimensionNames, ...
        shiftSD,rangeAbsSD,rangeRelSD,gantryAngleSD,couchAngleSD, ...
        numOfBeams)
if ~isprop(multScen,'scenarioDimensionActive')
    error('planWorkflow:scenario:createModel:MissingScenarioDimensionApi', ...
        ['The loaded matRad scenario model does not expose ' ...
         'scenarioDimensionActive. Update matRad before using planWorkflow.']);
end

if any(strcmp(activeDimensionNames,'gantry')) || ...
        any(strcmp(activeDimensionNames,'couch'))
    requiredProperties = {'numOfBeams','gantryAngleSD','couchAngleSD'};
    for i = 1:numel(requiredProperties)
        if ~isprop(multScen,requiredProperties{i})
            error('planWorkflow:scenario:createModel:MissingAngularDimensionApi', ...
                ['The loaded matRad scenario model does not expose %s. ' ...
                 'Update matRad before using gantry/couch uncertainty.'], ...
                 requiredProperties{i});
        end
    end
end

if isprop(multScen,'numOfBeams')
    multScen.numOfBeams = numOfBeams;
end
multScen.scenarioDimensionActive = activeDimensionNames;
if isprop(multScen,'gantryAngleSD')
    multScen.gantryAngleSD = gantryAngleSD;
end
if isprop(multScen,'couchAngleSD')
    multScen.couchAngleSD = couchAngleSD;
end
multScen.shiftSD = shiftSD;
multScen.rangeAbsSD = rangeAbsSD;
multScen.rangeRelSD = rangeRelSD;
end

function validateAngularDimensionSupport(scenarioMode,activeDimensionNames, ...
        numOfBeams)
angularActive = any(strcmp(activeDimensionNames,'gantry')) || ...
    any(strcmp(activeDimensionNames,'couch'));
if ~angularActive
    return;
end

if ~isSampledScenarioMode(scenarioMode)
    error(['planWorkflow:scenario:createModel:' ...
        'AngularDimensionsRequireSampledScenario'], ...
        ['gantry/couch uncertainty dimensions are currently supported only ' ...
         'for sampled random scenario models.']);
end

validNumOfBeams = isnumeric(numOfBeams) && isscalar(numOfBeams) && ...
    isfinite(numOfBeams) && round(numOfBeams) == numOfBeams && ...
    numOfBeams >= 1;
if ~validNumOfBeams
    error('planWorkflow:scenario:createModel:MissingBeamCount', ...
        ['Active gantry/couch uncertainty dimensions require numOfBeams ' ...
         'to be a positive integer.']);
end
end

function value = getConfigValue(config,fieldName,defaultValue)
if isfield(config,fieldName) && ~isempty(config.(fieldName))
    value = config.(fieldName);
else
    value = defaultValue;
end
end

function config = canonicalScenarioConfig(config,scenarioMode)
if ~isempty(scenarioMode)
    config.mode = scenarioMode;
elseif isfield(config,'scen_mode')
    config.mode = config.scen_mode;
elseif ~isfield(config,'mode')
    config.mode = 'wcScen';
end
defaults = planWorkflow.config.ScenarioSpec.defaults(config.mode);
scenarioFields = planWorkflow.config.ScenarioSpec.fields();
scenario = struct();
for fieldIx = 1:numel(scenarioFields)
    fieldName = scenarioFields{fieldIx};
    if isfield(config,fieldName)
        scenario.(fieldName) = config.(fieldName);
    end
end
scenario = planWorkflow.config.ScenarioSpec.normalize( ...
    scenario,defaults,'scenario');
config = planWorkflow.config.ScenarioSpec.matRadScenario(scenario);
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
