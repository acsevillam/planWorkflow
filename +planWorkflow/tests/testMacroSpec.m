function tests = testMacroSpec
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
macroRoot = localMacroRoot();
assumeTrue(testCase,isfolder(macroRoot));
addpath(fullfile(macroRoot,'shared','specs'));
testCase.TestData.macroRoot = macroRoot;
end

function testNormalizeAcceptsCatalogSpec(testCase)
spec = macroSpecCatalog('breast.photons.4136_mct.COWC', ...
    'profile','testing');

verifyEqual(testCase,spec.profile,'testing');
verifyEqual(testCase,spec.id,'testing.breast.photons.4136_mct.COWC');
verifyEqual(testCase,spec.baseId,'breast.photons.4136_mct.COWC');
verifyEqual(testCase,spec.site,'breast');
verifyEqual(testCase,spec.description,'breast');
verifyEqual(testCase,spec.executionMode,'run');
verifyEqual(testCase,spec.planKeys,{'COWC'});
verifyTrue(testCase,spec.openGui);
end

function testNormalizeRejectsMissingFields(testCase)
spec = macroSpecCatalog('breast.photons.4136_mct.COWC', ...
    'profile','testing');
spec = rmfield(spec,'planKeys');

verifyError(testCase,@() planWorkflow.macros.MacroSpec.normalize(spec), ...
    'planWorkflow:macros:MacroSpec:MissingField');
end

function testNormalizeRejectsInvalidProfile(testCase)
spec = macroSpecCatalog('breast.photons.4136_mct.COWC', ...
    'profile','testing');
spec.profile = 'dev';

verifyError(testCase,@() planWorkflow.macros.MacroSpec.normalize(spec), ...
    'planWorkflow:macros:MacroSpec:InvalidProfile');
end

function testNormalizeRejectsInvalidExecutionMode(testCase)
spec = macroSpecCatalog('breast.photons.4136_mct.COWC', ...
    'profile','testing');
spec.executionMode = 'dryRun';

verifyError(testCase,@() planWorkflow.macros.MacroSpec.normalize(spec), ...
    'planWorkflow:macros:MacroSpec:InvalidExecutionMode');
end

function testNormalizeRejectsInconsistentSiteDescription(testCase)
spec = macroSpecCatalog('head_and_neck.photons.2.INTERVAL2', ...
    'profile','testing');
spec.description = 'head_and_neck';

verifyError(testCase,@() planWorkflow.macros.MacroSpec.normalize(spec), ...
    ['planWorkflow:macros:MacroSpec:' ...
    'InconsistentSiteDescription']);
end

function macroRoot = localMacroRoot()
testFolder = fileparts(mfilename('fullpath'));
packageFolder = fileparts(testFolder);
planWorkflowRoot = fileparts(packageFolder);
matRadRoot = fileparts(fileparts(planWorkflowRoot));
macroRoot = fullfile(matRadRoot,'userdata','macros');
end
