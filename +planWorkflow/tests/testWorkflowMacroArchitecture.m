function tests = testWorkflowMacroArchitecture
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
macroRoot = localMacroRoot();
assumeTrue(testCase,isfolder(macroRoot));
addpath(fullfile(macroRoot,'shared','specs'));
addpath(fullfile(macroRoot,'helpers'));
testCase.TestData.macroRoot = macroRoot;
end

function testBuildBreastSingleConfigWithStageOverrides(testCase)
spec = macroSpecCatalog('breast.photons.4136_mct.COWC', ...
    'profile','testing');

[workflowConfig,macroOptions] = ...
    planWorkflow.macros.MacroRunner.build(spec, ...
    'sampling',struct('sampling_shiftSD',[3 6 3]));

verifyTrue(testCase,macroOptions.openGui);
verifyEqual(testCase,workflowConfig.prepare.caseID,'4136_mct');
verifyEqual(testCase,workflowConfig.precompute.robustPlans.id,'COWC');
verifyEqual(testCase, ...
    workflowConfig.precompute.robustPlans.objectiveSetName,'Minimax');
verifyEqual(testCase,workflowConfig.sampling.sampling_shiftSD,[3 6 3]);
end

function testBuildProstateParticleMultiplePlanSelection(testCase)
spec = macroSpecCatalog('prostate.protons.3482.multiple', ...
    'profile','testing');

workflowConfig = planWorkflow.macros.MacroRunner.build( ...
    spec,struct('planKeys',{{'PTV','INTERVAL2'}}));

verifyEqual(testCase,{workflowConfig.precompute.robustPlans.id}, ...
    {'PTV','INTERVAL2'});
verifyEqual(testCase, ...
    {workflowConfig.precompute.robustPlans.objectiveSetName}, ...
    {'PTV','Interval2'});
verifyEqual(testCase,workflowConfig.prepare.radiationMode,'protons');
verifyEqual(testCase,workflowConfig.prepare.quantityOpt,'RBExDose');
end

function testCCowcVariantsFollowWorstCaseScenarioCount(testCase)
robustScenario = struct('mode','wcScen', ...
    'ctActive',true, ...
    'setupActive',true, ...
    'rangeActive',false, ...
    'gantryActive',false, ...
    'couchActive',false);

plans = planWorkflow.config.RobustPlanCatalog.select( ...
    'prostate','comparison_001','cMinimax', ...
    'robustScenario',robustScenario, ...
    'radiationMode','photons');

verifyEqual(testCase,cCowcP2Values(plans),1:7);
end

function testCCowcVariantsPreserveDefaultImportanceScenarioSweep(testCase)
plans = planWorkflow.config.RobustPlanCatalog.select( ...
    'prostate','comparison_001','cMinimax', ...
    'radiationMode','photons');

verifyEqual(testCase,cCowcP2Values(plans),1:13);
end

function testCCowcVariantsStrideLargeScenarioCounts(testCase)
robustScenario = planWorkflow.config.ScenarioSpec.defaults('impScen5');
robustScenario.ctScenProb = [0.5 0.5];

plans = planWorkflow.config.RobustPlanCatalog.select( ...
    'prostate','comparison_001','cMinimax', ...
    'robustScenario',robustScenario, ...
    'radiationMode','photons');

verifyEqual(testCase,cCowcP2Values(plans),[1:2:25 26]);
end

function testProstatePhotonMultipleWcScenCMinimaxUsesSevenScenarios(testCase)
spec = macroSpecCatalog('prostate.photons.3482.multiple', ...
    'profile','testing');
optimizationScenario = struct('mode','wcScen', ...
    'ctActive',true, ...
    'setupActive',true, ...
    'rangeActive',false, ...
    'gantryActive',false, ...
    'couchActive',false);

workflowConfig = planWorkflow.macros.MacroRunner.build( ...
    spec,'optimizationScenario',optimizationScenario);
p2Values = cCowcP2Values(workflowConfig.precompute.robustPlans);

verifyEqual(testCase,p2Values,1:7);
verifyFalse(testCase,any(p2Values > 7));
end

function testBuildHeadAndNeckConfig(testCase)
spec = macroSpecCatalog('head_and_neck.photons.2.INTERVAL2', ...
    'profile','testing');

workflowConfig = planWorkflow.macros.MacroRunner.build(spec);

verifyEqual(testCase,workflowConfig.prepare.description,'h&n');
verifyEqual(testCase,workflowConfig.prepare.caseID,'2');
verifyEqual(testCase,workflowConfig.prepare.plan_template,'interval2_001');
verifyEqual(testCase,workflowConfig.precompute.robustPlans.id,'INTERVAL2');
end

function testTestingProfileBuildsRunConfigWithOverrides(testCase)
spec = macroSpecCatalog('prostate.photons.3482.INTERVAL2', ...
    'profile','testing');
workflowConfig = planWorkflow.macros.MacroRunner.build(spec);

verifyEqual(testCase,spec.profile,'testing');
verifyEqual(testCase,spec.executionMode,'run');
verifyTrue(testCase,spec.openGui);
verifyEqual(testCase,workflowConfig.prepare.caseID,'3482');
verifyEqual(testCase,workflowConfig.precompute.robustPlans.id, ...
    'INTERVAL2');
verifyEqual(testCase,workflowConfig.precompute.doseResolution,[5 5 5]);
end

function testCustomRobustPlanOverrideRequiresOptIn(testCase)
spec = macroSpecCatalog('breast.photons.4136_mct.PTV', ...
    'profile','testing');
override = struct('precompute',struct('robustPlans',struct()));

verifyError(testCase,@() ...
    planWorkflow.macros.MacroRunner.build(spec,override), ...
    'planWorkflow:macros:MacroRunner:CustomRobustPlansDisabled');
workflowConfig = planWorkflow.macros.MacroRunner.build( ...
    spec,mergeStructs(override,struct('allowCustomRobustPlans',true)));
verifyTrue(testCase,isfield(workflowConfig.precompute,'robustPlans'));
end

function testCatalogHasReusableSpecsForAllProfiles(testCase)
requiredIds = { ...
    'breast.photons.4136_mct.COWC', ...
    'prostate.photons.3482.multiple', ...
    'prostate.protons.1_mct.COWC', ...
    'prostate.carbon.1_mct.PTV', ...
    'prostate.helium.1_mct.PTV', ...
    'head_and_neck.photons.2.INTERVAL2'};

ids = macroSpecCatalog('ids');
for i = 1:numel(requiredIds)
    verifyTrue(testCase,any(strcmp(ids,requiredIds{i})),requiredIds{i});
    verifyEqual(testCase, ...
        macroSpecCatalog(requiredIds{i},'profile','prod').profile,'prod');
    verifyEqual(testCase, ...
        macroSpecCatalog(requiredIds{i},'profile','testing').profile, ...
        'testing');
end
end

function testWrapperDeclaresProfileAndGuiDefaults(testCase)
macroRoot = testCase.TestData.macroRoot;
wrapperFile = fullfile(macroRoot,'head_and_neck','photons', ...
    'runHeadNeckPhotonInterval2Workflow.m');
[specId,profile,openGui,optimizationScenario,samplingScenario, ...
    selector] = ...
    wrapperSpecAndProfile(wrapperFile);
verifyNotEmpty(testCase,specId);
verifyNotEmpty(testCase,profile);
verifyTrue(testCase,islogical(openGui) && isscalar(openGui));
verifyEqual(testCase,selector.site,'head_and_neck');
verifyEqual(testCase,selector.particleType,'photons');
verifyEqual(testCase,selector.caseID,'2');
verifyEqual(testCase,selector.robustness,'INTERVAL2');
verifyEqual(testCase,selector.samplingProfile,'default');
spec = macroSpecCatalog(specId,'profile',profile);
[workflowConfig,macroOptions] = ...
    planWorkflow.macros.MacroRunner.build( ...
    spec,'openGui',openGui, ...
    'optimizationScenario',optimizationScenario, ...
    'samplingScenario',samplingScenario);

verifyEqual(testCase,spec.profile,'prod');
verifyEqual(testCase,spec.executionMode,'run');
verifyEqual(testCase,macroOptions.openGui,openGui);
verifyEqual(testCase,macroOptions.optimizationScenario.ctActive, ...
    optimizationScenario.ctActive);
verifyEqual(testCase,macroOptions.samplingScenario.ctActive, ...
    samplingScenario.ctActive);
verifyEqual(testCase,workflowConfig.prepare.description,'h&n');
verifyEqual(testCase,workflowConfig.precompute.robustPlans.id, ...
    'INTERVAL2');
end

function testAllWrappersPointToValidSpecs(testCase)
macroRoot = testCase.TestData.macroRoot;
wrapperFiles = [ ...
    matlabWrapperFiles(fullfile(macroRoot,'breast')); ...
    matlabWrapperFiles(fullfile(macroRoot,'prostate')); ...
    matlabWrapperFiles(fullfile(macroRoot,'head_and_neck'))];
verifyNotEmpty(testCase,wrapperFiles);

functionNames = cell(size(wrapperFiles));
for i = 1:numel(wrapperFiles)
    [~,functionNames{i}] = fileparts(wrapperFiles{i});
    wrapperText = fileread(wrapperFiles{i});
    [specId,profile,openGui,optimizationScenario,samplingScenario, ...
        selector] = ...
        wrapperSpecAndProfile(wrapperFiles{i});
    verifyWrapperHasSectionComments(testCase,wrapperText,wrapperFiles{i});
    verifyNotEmpty(testCase,specId,wrapperFiles{i});
    verifyNotEmpty(testCase,profile,wrapperFiles{i});
    verifyWrapperSelector(testCase,selector,wrapperFiles{i});
    verifyTrue(testCase,islogical(openGui) && isscalar(openGui), ...
        wrapperFiles{i});
    verifyScenarioToggleStruct(testCase,optimizationScenario, ...
        wrapperFiles{i});
    verifyScenarioToggleStruct(testCase,samplingScenario, ...
        wrapperFiles{i});
    spec = macroSpecCatalog(specId,'profile',profile);
    verifyTrue(testCase,any(strcmp(profile,{'prod','testing'})), ...
        wrapperFiles{i});
    verifyEqual(testCase,spec.executionMode,'run',wrapperFiles{i});
    verifyTrue(testCase,spec.openGui,wrapperFiles{i});
end
verifyEqual(testCase,numel(unique(functionNames)), ...
    numel(functionNames));
end

function verifyWrapperHasSectionComments(testCase,text,diagnostic)
requiredComments = { ...
    '% Path setup.', ...
    '% Execution defaults.', ...
    '% MacroSpec selectors.', ...
    '% Optimization scenario toggles.', ...
    '% Sampling scenario toggles.', ...
    '% Resolve the MacroSpec and run the complete workflow.'};
for i = 1:numel(requiredComments)
    verifyTrue(testCase,contains(text,requiredComments{i}), ...
        diagnostic);
end
end

function testNoProfileSpecificWrapperFolders(testCase)
macroRoot = testCase.TestData.macroRoot;

verifyFalse(testCase,isfolder(fullfile(macroRoot,'prod')));
verifyFalse(testCase,isfolder(fullfile(macroRoot,'testing')));
end

function testWrapperOpenGuiDefaultCanBeOverridden(testCase)
macroRoot = testCase.TestData.macroRoot;
wrapperFile = fullfile(macroRoot,'breast','photons', ...
    'runBreastPhotonMctMultipleWorkflow.m');
[specId,profile,openGui] = wrapperSpecAndProfile(wrapperFile);
spec = macroSpecCatalog(specId,'profile',profile);

[~,macroOptions] = planWorkflow.macros.MacroRunner.build( ...
    spec,'openGui',openGui,'openGui',false);

verifyTrue(testCase,openGui);
verifyFalse(testCase,macroOptions.openGui);
end

function testWrapperProfileDefaultCanBeOverridden(testCase)
macroRoot = testCase.TestData.macroRoot;
wrapperFile = fullfile(macroRoot,'breast','photons', ...
    'runBreastPhotonMctMultipleWorkflow.m');
[specId,profile,~] = wrapperSpecAndProfile(wrapperFile);

prodSpec = macroSpecCatalog(specId,'profile',profile);
testingSpec = macroSpecCatalog(specId,'profile','testing');
prodConfig = planWorkflow.macros.MacroRunner.build(prodSpec);
testingConfig = planWorkflow.macros.MacroRunner.build(testingSpec);

verifyEqual(testCase,profile,'prod');
verifyEqual(testCase,prodConfig.precompute.doseResolution,[3 3 3]);
verifyEqual(testCase,testingConfig.precompute.doseResolution,[5 5 5]);
end

function testWrapperScenarioFlagsDriveOptimizationAndSampling(testCase)
macroRoot = testCase.TestData.macroRoot;
wrapperFile = fullfile(macroRoot,'prostate','protons', ...
    'runProstateProtonMctCOWCWorkflow.m');
[specId,profile,~,optimizationScenario,samplingScenario] = ...
    wrapperSpecAndProfile(wrapperFile);
spec = macroSpecCatalog(specId,'profile',profile);

workflowConfig = planWorkflow.macros.MacroRunner.build( ...
    spec,'optimizationScenario',optimizationScenario, ...
    'samplingScenario',samplingScenario);

verifyTrue(testCase,workflowConfig.precompute.robustPlans.scenario.rangeActive);
verifyTrue(testCase,workflowConfig.sampling.sampling_rangeActive);
verifyTrue(testCase,workflowConfig.sampling.sampling_gantryActive);
verifyTrue(testCase,workflowConfig.sampling.sampling_couchActive);
end

function testNoAnglesWrapperUsesSamplingProfileSelector(testCase)
macroRoot = testCase.TestData.macroRoot;
wrapperFile = fullfile(macroRoot,'prostate','protons', ...
    'runProstateProtonMctCOWCNoAnglesWorkflow.m');
[specId,~,~,~,~,selector] = wrapperSpecAndProfile(wrapperFile);

verifyEqual(testCase,selector.robustness,'COWC');
verifyEqual(testCase,selector.samplingProfile,'noAngles');
verifyEqual(testCase,specId,'prostate.protons.1_mct.COWC_noAngles');
end

function testMacroJobResolvesBaseWithParameterSets(testCase)
job = struct();
job.id = 'breastJob';
job.profile = 'testing';
job.openGui = false;
job.site = 'breast';
job.particleType = 'photons';
job.caseID = '4136_mct';
job.samplingProfile = 'default';
job.optimizationScenario = defaultToggleScenario(false,false,false);
job.samplingScenario = defaultToggleScenario(false,false,false);
job.parameterSets = repmat(struct('label','','robustness',''),1,3);
job.parameterSets(1).label = 'ptv';
job.parameterSets(1).robustness = 'PTV';
job.parameterSets(2).label = 'cowc';
job.parameterSets(2).robustness = 'COWC';
job.parameterSets(3).label = 'ccowc';
job.parameterSets(3).robustness = 'cCOWC';

jobPlan = resolveWorkflowMacroJob(job,'rootPath','/tmp/macro-job');

verifyEqual(testCase,{jobPlan.runs.specId}, ...
    {'breast.photons.4136_mct.PTV', ...
     'breast.photons.4136_mct.COWC', ...
     'breast.photons.4136_mct.cCOWC'});
verifyEqual(testCase,{jobPlan.runs.profile},{'testing','testing', ...
    'testing'});
verifyFalse(testCase,jobPlan.runs(1).openGui);
verifyTrue(testCase,any(strcmp(jobPlan.runs(1).args,'rootPath')));
end

function testMacroJobResolvesMultipleBasesWithParameterSets(testCase)
job = struct();
job.id = 'multiBaseJob';
job.profile = 'testing';
job.openGui = false;
job.optimizationScenario = defaultToggleScenario(false,false,false);
job.samplingScenario = defaultToggleScenario(false,false,false);
job.bases = repmat(struct('label','','site','','particleType','', ...
    'caseID','','samplingProfile','default'),1,2);
job.bases(1).label = 'breast';
job.bases(1).site = 'breast';
job.bases(1).particleType = 'photons';
job.bases(1).caseID = '4136_mct';
job.bases(2).label = 'hn';
job.bases(2).site = 'head_and_neck';
job.bases(2).particleType = 'photons';
job.bases(2).caseID = '2';
job.parameterSets = repmat(struct('label','','robustness',''),1,2);
job.parameterSets(1).robustness = 'PTV';
job.parameterSets(2).robustness = 'INTERVAL2';

jobPlan = resolveWorkflowMacroJob(job);

verifyEqual(testCase,{jobPlan.runs.specId}, ...
    {'breast.photons.4136_mct.PTV', ...
     'breast.photons.4136_mct.INTERVAL2', ...
     'head_and_neck.photons.2.PTV', ...
     'head_and_neck.photons.2.INTERVAL2'});
verifyEqual(testCase,{jobPlan.runs.label}, ...
    {'breast_PTV','breast_INTERVAL2','hn_PTV','hn_INTERVAL2'});
end

function testMacroJobParameterSetsCanVaryCaseId(testCase)
job = struct();
job.id = 'caseSweepJob';
job.profile = 'testing';
job.openGui = false;
job.site = 'breast';
job.particleType = 'photons';
job.robustness = 'multiple';
job.samplingProfile = 'default';
job.optimizationScenario = defaultToggleScenario(false,false,false);
job.samplingScenario = defaultToggleScenario(false,false,false);
job.parameterSets = repmat(struct('label','','caseID',''),1,2);
job.parameterSets(1).caseID = '4136_mct';
job.parameterSets(2).caseID = '4136';

jobPlan = resolveWorkflowMacroJob(job);

verifyEqual(testCase,{jobPlan.runs.specId}, ...
    {'breast.photons.4136_mct.multiple', ...
     'breast.photons.4136.multiple'});
verifyEqual(testCase,{jobPlan.runs.label},{'4136_mct','4136'});
end

function testScenarioFlagsCanBeOverridden(testCase)
macroRoot = testCase.TestData.macroRoot;
wrapperFile = fullfile(macroRoot,'prostate','protons', ...
    'runProstateProtonMctCOWCWorkflow.m');
[specId,profile,~,optimizationScenario,samplingScenario] = ...
    wrapperSpecAndProfile(wrapperFile);
spec = macroSpecCatalog(specId,'profile',profile);

workflowConfig = planWorkflow.macros.MacroRunner.build( ...
    spec, ...
    'optimizationScenario',optimizationScenario, ...
    'samplingScenario',samplingScenario, ...
    'optimizationScenario',struct('rangeActive',false), ...
    'samplingScenario',struct('gantryActive',false, ...
    'couchActive',false));

verifyFalse(testCase, ...
    workflowConfig.precompute.robustPlans.scenario.rangeActive);
verifyFalse(testCase,workflowConfig.sampling.sampling_gantryActive);
verifyFalse(testCase,workflowConfig.sampling.sampling_couchActive);
end

function testProdSpecDefaultsToRunWithGui(testCase)
spec = macroSpecCatalog('breast.photons.4136_mct.COWC');

verifyEqual(testCase,spec.profile,'prod');
verifyEqual(testCase,spec.executionMode,'run');
verifyTrue(testCase,spec.openGui);
end

function testDoseResolutionFollowsProfile(testCase)
prodSpec = macroSpecCatalog('breast.photons.4136.multiple', ...
    'profile','prod');
testingSpec = macroSpecCatalog('breast.photons.4136.multiple', ...
    'profile','testing');

prodConfig = planWorkflow.macros.MacroRunner.build(prodSpec);
testingConfig = planWorkflow.macros.MacroRunner.build(testingSpec);

verifyEqual(testCase,prodConfig.precompute.doseResolution,[3 3 3]);
verifyEqual(testCase,testingConfig.precompute.doseResolution,[5 5 5]);
end

function testMacroOptionsRejectPositionalArguments(testCase)
spec = macroSpecCatalog('breast.photons.4136_mct.PTV', ...
    'profile','testing');

verifyError(testCase,@() planWorkflow.macros.MacroRunner.build( ...
    spec,'4136_mct','/tmp/userdata'), ...
    'planWorkflow:macros:MacroRunner:InvalidOptions');
end

function [specId,profile,openGui,optimizationScenario,samplingScenario, ...
        selector] = ...
        wrapperSpecAndProfile(wrapperFile)
text = fileread(wrapperFile);
selector = wrapperSelectorDefaults(text);
hasSpecId = ~isempty(regexp(text, ...
    ['specId\s*=\s*macroSpecId\(\s*\.\.\.\s*' ...
     'site\s*,\s*particleType\s*,\s*caseID\s*,\s*robustness\s*,\s*' ...
     'samplingProfile\s*\)\s*;'], ...
    'once'));
hasRunWorkflowSpec = ~isempty(regexp(text, ...
    'runWorkflowMacroSpec\(\s*\.\.\.\s*specId\s*[,)]', ...
    'once'));
profileTokens = regexp(text,'profile\s*=\s*''(prod|testing)''\s*;', ...
    'tokens','once');
guiTokens = regexp(text,'openGui\s*=\s*(true|false)\s*;', ...
    'tokens','once');
optimizationScenario = wrapperScenarioDefaults( ...
    text,'optimizationScenario');
samplingScenario = wrapperScenarioDefaults(text,'samplingScenario');
if ~hasSpecId || ~hasRunWorkflowSpec || isempty(profileTokens) || ...
        isempty(selector)
    specId = '';
    profile = '';
    openGui = [];
else
    specId = macroSpecId(selector.site,selector.particleType, ...
        selector.caseID,selector.robustness,selector.samplingProfile);
    profile = profileTokens{1};
    if isempty(guiTokens)
        openGui = [];
    else
        openGui = strcmp(guiTokens{1},'true');
    end
end
end

function selector = wrapperSelectorDefaults(text)
selector = struct();
fields = {'site','particleType','caseID','robustness','samplingProfile'};
for i = 1:numel(fields)
    tokens = regexp(text, ...
        [fields{i} '\s*=\s*''([^'']+)''\s*;'], ...
        'tokens','once');
    if isempty(tokens)
        selector = [];
        return;
    end
    selector.(fields{i}) = tokens{1};
end
end

function scenario = wrapperScenarioDefaults(text,variableName)
scenario = struct();
fields = {'ctActive','setupActive','rangeActive','gantryActive', ...
    'couchActive'};
for i = 1:numel(fields)
    tokens = regexp(text, ...
        [variableName '[\s\S]*?''' fields{i} ''',\s*(true|false)'], ...
        'tokens','once');
    if isempty(tokens)
        return;
    end
    scenario.(fields{i}) = strcmp(tokens{1},'true');
end
end

function verifyScenarioToggleStruct(testCase,scenario,diagnostic)
fields = {'ctActive','setupActive','rangeActive','gantryActive', ...
    'couchActive'};
verifyEqual(testCase,sort(fieldnames(scenario)),sort(fields(:)), ...
    diagnostic);
for i = 1:numel(fields)
    verifyTrue(testCase,islogical(scenario.(fields{i})) && ...
        isscalar(scenario.(fields{i})),diagnostic);
end
end

function values = cCowcP2Values(plans)
planIds = {plans.id};
planIx = find(strcmp(planIds,'cCOWC'),1);
if isempty(planIx)
    objectiveSetNames = {plans.objectiveSetName};
    planIx = find(strcmp(objectiveSetNames,'cMinimax'),1);
end
if isempty(planIx)
    error('testWorkflowMacroArchitecture:MissingCCowcPlan', ...
        'Expected a c-COWC/cMinimax plan.');
end
values = [plans(planIx).variants.p2];
end

function verifyWrapperSelector(testCase,selector,diagnostic)
fields = {'site','particleType','caseID','robustness','samplingProfile'};
verifyEqual(testCase,sort(fieldnames(selector)),sort(fields(:)), ...
    diagnostic);
verifyTrue(testCase, ...
    any(strcmp(selector.site,{'breast','prostate','head_and_neck'})), ...
    diagnostic);
verifyTrue(testCase, ...
    any(strcmp(selector.particleType, ...
    {'photons','protons','carbon','helium'})),diagnostic);
verifyTrue(testCase, ...
    any(strcmp(selector.samplingProfile,{'default','noAngles'})), ...
    diagnostic);
for i = 1:numel(fields)
    verifyTrue(testCase,ischar(selector.(fields{i})) && ...
        ~isempty(selector.(fields{i})),diagnostic);
end
end

function scenario = defaultToggleScenario(ctActive,rangeActive,withAngles)

scenario = struct( ...
    'ctActive',ctActive, ...
    'setupActive',true, ...
    'rangeActive',rangeActive, ...
    'gantryActive',withAngles, ...
    'couchActive',withAngles);

end

function merged = mergeStructs(base,patch)
merged = base;
fields = fieldnames(patch);
for i = 1:numel(fields)
    fieldName = fields{i};
    if isfield(merged,fieldName) && isstruct(merged.(fieldName)) && ...
            isstruct(patch.(fieldName)) && isscalar(merged.(fieldName)) && ...
            isscalar(patch.(fieldName))
        merged.(fieldName) = mergeStructs(merged.(fieldName), ...
            patch.(fieldName));
    else
        merged.(fieldName) = patch.(fieldName);
    end
end
end

function files = matlabWrapperFiles(folder)
listing = dir(fullfile(folder,'**','*.m'));
files = cell(numel(listing),1);
for i = 1:numel(listing)
    files{i} = fullfile(listing(i).folder,listing(i).name);
end
end

function macroRoot = localMacroRoot()
testFolder = fileparts(mfilename('fullpath'));
packageFolder = fileparts(testFolder);
planWorkflowRoot = fileparts(packageFolder);
matRadRoot = fileparts(fileparts(planWorkflowRoot));
macroRoot = fullfile(matRadRoot,'userdata','macros');
end
