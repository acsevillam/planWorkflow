function tests = testWorkflowMacroArchitecture
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
macroRoot = localMacroRoot();
assumeTrue(testCase,isfolder(macroRoot));
addpath(fullfile(macroRoot,'shared','common'));
addpath(fullfile(macroRoot,'shared','breast'));
addpath(fullfile(macroRoot,'shared','prostate'));
testCase.TestData.macroRoot = macroRoot;
end

function testBreastSingleConfigWithStageOverrides(testCase)
macroRoot = testCase.TestData.macroRoot;
prepareConfig = photonBreastPrepareConfig('4136_mct','COWC_001');
profile = breastWorkflowProfile('testBreast', ...
    fullfile(macroRoot,'shared','breast'), ...
    prepareConfig,{'COWC'},'single');

[workflowConfig,macroOptions] = buildWorkflowMacroConfig(profile, ...
    'openGui',false, ...
    'sampling',struct('sampling_shiftSD',[3 6 3]));

verifyFalse(testCase,macroOptions.openGui);
verifyEqual(testCase,workflowConfig.prepare.caseID,'4136_mct');
verifyEqual(testCase,workflowConfig.precompute.robustPlans.objectiveSetName, ...
    'Minimax');
verifyEqual(testCase,workflowConfig.precompute.robustPlans.id,'COWC');
verifyEqual(testCase,workflowConfig.sampling.sampling_shiftSD,[3 6 3]);
end

function testProstateMultiplePlanSelection(testCase)
macroRoot = testCase.TestData.macroRoot;
prepareConfig = protonProstatePrepareConfig( ...
    prostateMctPrepareConfig('comparison_001'));
profile = prostateWorkflowProfile('testProstate', ...
    fullfile(macroRoot,'shared','prostate'), ...
    prepareConfig,{'all'},'multiple');

workflowConfig = buildWorkflowMacroConfig(profile, ...
    struct('planKeys',{{'PTV','INTERVAL2'}},'openGui',false));

verifyEqual(testCase,{workflowConfig.precompute.robustPlans.objectiveSetName}, ...
    {'PTV','Interval2'});
verifyEqual(testCase,{workflowConfig.precompute.robustPlans.id}, ...
    {'PTV','INTERVAL2'});
verifyEqual(testCase,workflowConfig.prepare.radiationMode,'protons');
verifyEqual(testCase,workflowConfig.prepare.quantityOpt,'RBExD');
end

function testCustomRobustPlanOverrideRequiresOptIn(testCase)
macroRoot = testCase.TestData.macroRoot;
prepareConfig = photonBreastPrepareConfig('4136_mct','PTV_001');
profile = breastWorkflowProfile('testBreast', ...
    fullfile(macroRoot,'shared','breast'),prepareConfig,{'PTV'},'single');
override = struct('precompute',struct('robustPlans',struct()));

verifyError(testCase,@() buildWorkflowMacroConfig(profile,override), ...
    'planWorkflow:macros:CustomRobustPlansDisabled');
workflowConfig = buildWorkflowMacroConfig(profile, ...
    mergeWorkflowMacroStructs(override, ...
    struct('allowCustomRobustPlans',true)));
verifyTrue(testCase,isfield(workflowConfig.precompute,'robustPlans'));
end

function testMacroOptionsRejectPositionalArguments(testCase)
macroRoot = testCase.TestData.macroRoot;
prepareConfig = photonBreastPrepareConfig('4136_mct','PTV_001');
profile = breastWorkflowProfile('testBreast', ...
    fullfile(macroRoot,'shared','breast'),prepareConfig,{'PTV'},'single');

verifyError(testCase,@() buildWorkflowMacroConfig( ...
    profile,'4136_mct','/tmp/userdata'), ...
    'planWorkflow:macros:InvalidMacroOptions');
end

function macroRoot = localMacroRoot()
testFolder = fileparts(mfilename('fullpath'));
packageFolder = fileparts(testFolder);
planWorkflowRoot = fileparts(packageFolder);
matRadRoot = fileparts(fileparts(planWorkflowRoot));
macroRoot = fullfile(matRadRoot,'userdata','macros');
end
