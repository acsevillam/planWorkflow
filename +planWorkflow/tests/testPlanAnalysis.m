function tests = testPlanAnalysis
tests = functiontests(localfunctions);
end

function testResolveQuantityUsesOptimizationQuantity(testCase)
pln.propOpt.quantityOpt = 'physicalDose';
pln.propOpt.quantityVis = 'RBExDose';
resultGUI.RBExDose = 1;

quantity = planWorkflow.analysis.PlanAnalysis.resolveQuantity(pln,resultGUI);

verifyEqual(testCase,quantity,'physicalDose');
end

function testResolveQuantityUsesExplicitPreparedFallback(testCase)
pln = struct();

quantity = planWorkflow.analysis.PlanAnalysis.resolveQuantity(pln,'RBExDose');

verifyEqual(testCase,quantity,'RBExDose');
end

function testDoseQuantityResolverUsesOptimizationQuantity(testCase)
runConfig = struct();
runConfig.radiationMode = 'protons';
runConfig.bioModel = 'constRBE';
runConfig.analysisQuantity = 'physicalDose';
runConfig.quantityOpt = 'RBExDose';

quantity = planWorkflow.plan.DoseQuantityResolver.fromRunConfig(runConfig);

verifyEqual(testCase,quantity,'RBExDose');
end

function testDoseQuantityResolverUsesMatRadQuantityVisForEndpoints(testCase)
runConfig = struct();
runConfig.radiationMode = 'photons';
runConfig.bioModel = 'none';
runConfig.quantityOpt = 'effect';
info = planWorkflow.plan.DoseQuantityResolver.bioModelInfoFromRunConfig( ...
    runConfig);

verifyEqual(testCase, ...
    planWorkflow.plan.DoseQuantityResolver.fromRunConfig(runConfig), ...
    'effect');
verifyEqual(testCase, ...
    planWorkflow.plan.DoseQuantityResolver.visualFromRunConfig( ...
    runConfig),'physicalDose');
verifyEqual(testCase,info.quantityVis,'physicalDose');
verifyEqual(testCase,double(info.bioOpt),1);
end

function testDoseQuantityResolverRejectsIncompatibleQuantity(testCase)
runConfig = struct();
runConfig.radiationMode = 'protons';
runConfig.bioModel = 'constRBE';
runConfig.quantityOpt = 'physicalDose';

verifyError(testCase,@() ...
    planWorkflow.plan.DoseQuantityResolver.fromRunConfig(runConfig), ...
    'planWorkflow:plan:DoseQuantityResolver:IncompatibleQuantity');
end

function testDoseQuantityResolverRejectsAnalysisQuantityAsInput(testCase)
runConfig = struct();
runConfig.analysisQuantity = 'RBExDose';

quantity = planWorkflow.plan.DoseQuantityResolver.fromRunConfig(runConfig);

verifyEmpty(testCase,quantity);
verifyError(testCase,@() ...
    planWorkflow.plan.DoseQuantityResolver.requireFromRunConfig( ...
    runConfig,'test runConfig'), ...
    'planWorkflow:plan:DoseQuantityResolver:MissingQuantity');
end

function testDoseQuantityResolverUsesBioModelContract(testCase)
physicalConfig = struct('radiationMode','photons','bioModel','none');
rbexdConfig = struct('radiationMode','protons','bioModel','constRBE');
protonPhysicalConfig = struct('radiationMode','protons', ...
    'bioModel','none','quantityOpt','physicalDose');

verifyEqual(testCase, ...
    planWorkflow.plan.DoseQuantityResolver.fromRunConfig( ...
    physicalConfig),'physicalDose');
verifyEqual(testCase, ...
    planWorkflow.plan.DoseQuantityResolver.fromRunConfig( ...
    rbexdConfig),'RBExDose');
verifyEqual(testCase, ...
    planWorkflow.plan.DoseQuantityResolver.fromRunConfig( ...
    protonPhysicalConfig),'physicalDose');
end

function testDoseQuantityResolverUsesCapabilityMetadata(testCase)
verifyEqual(testCase, ...
    planWorkflow.matRadCapabilitiesReader.doseQuantityForBioModel( ...
    'photons','none'),'physicalDose');
photonQuantities = ...
    planWorkflow.matRadCapabilitiesReader.supportedDoseQuantities( ...
    'photons','none');
verifyTrue(testCase,any(strcmp(photonQuantities,'physicalDose')));
verifyTrue(testCase,any(strcmp(photonQuantities,'RBExDose')));
verifyEqual(testCase, ...
    planWorkflow.matRadCapabilitiesReader.doseQuantityForBioModel( ...
    'helium','HEL'),'RBExDose');
carbonLEMQuantities = ...
    planWorkflow.matRadCapabilitiesReader.supportedDoseQuantities( ...
    'carbon','LEM');
verifyTrue(testCase,any(strcmp(carbonLEMQuantities,'effect')));
verifyTrue(testCase,any(strcmp(carbonLEMQuantities,'RBExDose')));
verifyEqual(testCase, ...
    planWorkflow.matRadCapabilitiesReader.doseQuantityForBioModel( ...
    'protons','none'),'physicalDose');
verifyEqual(testCase, ...
    planWorkflow.matRadCapabilitiesReader.supportedDoseQuantities( ...
    'protons','none'),{'physicalDose'});
verifyEqual(testCase, ...
    planWorkflow.matRadCapabilitiesReader.defaultBioModel( ...
    'protons'),'constRBE');
verifyEqual(testCase, ...
    planWorkflow.matRadCapabilitiesReader.doseQuantityForBioModel( ...
    'photons','constRBE'),'RBExDose');
verifyTrue(testCase,any(strcmp( ...
    planWorkflow.matRadCapabilitiesReader.supportedDoseQuantityNames(), ...
    'effect')));
end

function testDoseQuantityResolverDefaultsRunConfigQuantity(testCase)
runConfig = struct('radiationMode','protons','bioModel','none', ...
    'quantityOpt','RBExDose');

runConfig = planWorkflow.plan.DoseQuantityResolver.applyDefaultToRunConfig( ...
    runConfig,true);

verifyEqual(testCase,runConfig.quantityOpt,'physicalDose');

carbonConfig = struct('radiationMode','carbon','bioModel','LEM', ...
    'quantityOpt','effect');
carbonConfig = planWorkflow.plan.DoseQuantityResolver.applyDefaultToRunConfig( ...
    carbonConfig,true);

verifyEqual(testCase,carbonConfig.quantityOpt,'RBExDose');
end

function testResolveQuantityRejectsImplicitResultFields(testCase)
pln.propOpt.quantityVis = 'RBExDose';
resultGUI.RBExDose = 1;

verifyError(testCase,@() ...
    planWorkflow.analysis.PlanAnalysis.resolveQuantity(pln,resultGUI), ...
    'planWorkflow:analysis:PlanAnalysis:MissingOptimizationQuantity');
end

function testPlanAnalysisStoresEndpointQuantityFromQuantityVis(testCase)
analysisConfig = planWorkflow.config.Analysis.defaults();
analysisConfig.evaluationMode = 'perFraction';
cst = cell(1,6);
cst{1,1} = 1;
cst{1,2} = 1;
cst{1,3} = 'PTV';
cst{1,4} = {true(1,1,1)};
cst{1,5} = struct();
cst{1,6} = {};
ct.cubeDim = [1 1 1];
pln.numOfFractions = 1;
pln.propOpt.quantityOpt = 'effect';
pln.propOpt.quantityVis = 'physicalDose';
resultGUI.effect = 2;
resultGUI.physicalDose = 1;

[resultGUIAnalysis,~,~] = planWorkflow.analysis.PlanAnalysis.run( ...
    analysisConfig,ct,cst,struct(),pln,resultGUI,false,'effect');

verifyEqual(testCase,resultGUIAnalysis.analysisQuantity,'effect');
verifyEqual(testCase,resultGUIAnalysis.endpointQuantity,'physicalDose');
verifyTrue(testCase,isfield(resultGUIAnalysis,'endpointDvh'));
end
