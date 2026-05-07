function tests = testArchitectureRefactor
tests = functiontests(localfunctions);
end

function testPrecomputeStageContextRejectsMissingStageData(testCase)
runConfig = minimalRunConfig();
taskRunner = @(varargin) [];
logFn = @(message) [];
cache = planWorkflow.cache.DoseInfluenceCacheService( ...
    runConfig,tempdir,logFn);

verifyError(testCase,@() planWorkflow.stages.PrecomputeStage.context( ...
    runConfig,struct(),taskRunner,logFn,struct(),tempdir,cache), ...
    'planWorkflow:stages:ContextValidator:MissingData');
end

function testPrecomputeStageContextRejectsIncompleteCacheContract(testCase)
runConfig = minimalRunConfig();
data = minimalPreparedData();
taskRunner = @(varargin) [];
logFn = @(message) [];

verifyError(testCase,@() planWorkflow.stages.PrecomputeStage.context( ...
    runConfig,data,taskRunner,logFn,struct(),tempdir,struct()), ...
    'planWorkflow:stages:ContextValidator:MissingDependency');
end

function testStageOwnsDependencyValidation(testCase)
runConfig = minimalRunConfig();
data = minimalPreparedData();

verifyError(testCase,@() planWorkflow.stages.PrepareStage.workflowContext( ...
    runConfig,data,@(varargin) [],@(~) [],[]), ...
    'planWorkflow:stages:ContextValidator:MissingDependency');
end

function testDoseInfluenceCacheServiceBuildsDescriptorWithoutEngine(testCase)
runConfig = minimalRunConfig();
cache = planWorkflow.cache.DoseInfluenceCacheService( ...
    runConfig,tempdir,@(~) []);

descriptor = cache.descriptor('reference',struct());

verifyEqual(testCase,descriptor.artifact.kind,'reference');
verifyEqual(testCase,descriptor.identity.patient.description, ...
    runConfig.description);
verifyNotEmpty(testCase,descriptor.identityHash);
end

function testStageDescriptorsOwnDisplayLabels(testCase)
descriptors = planWorkflow.config.StageConfigSchema.descriptors();

verifyTrue(testCase,isfield(descriptors,'displayLabel'));
for stageIx = 1:numel(descriptors)
    verifyEqual(testCase, ...
        planWorkflow.config.StageConfigSchema.stageLabel( ...
        descriptors(stageIx).engineName), ...
        descriptors(stageIx).displayLabel);
end
end

function testStageExecutorUsesDescriptorRunner(testCase)
runtime = minimalRuntime();
data = struct('planTemplate',struct());

verifyError(testCase,@() planWorkflow.stages.StageExecutor.run( ...
    'precompute',minimalRunConfig(),data,runtime), ...
	'planWorkflow:stages:ContextValidator:MissingData');
end

function testStageContextKeepsOnlyDeclaredData(testCase)
runConfig = minimalRunConfig();
data = minimalPreparedData();
data.unrelated = true;
taskRunner = @(varargin) [];
logFn = @(message) [];
cache = planWorkflow.cache.DoseInfluenceCacheService( ...
    runConfig,tempdir,logFn);

context = planWorkflow.stages.PrecomputeStage.context( ...
    runConfig,data,taskRunner,logFn,struct(),tempdir,cache);

verifyFalse(testCase,isfield(context.data,'unrelated'));
verifyTrue(testCase,isfield(context.data,'ct'));
verifyTrue(testCase,isfield(context.data,'pln'));
end

function testVariantPlanFactoryIsCanonicalVariantBuilder(testCase)
robustData = struct();
robustData.pln = struct('propOpt',struct());
robustData.planConfig = robustPlanConfig();
variantResult = struct('variantId','theta_5');

factoryPln = planWorkflow.optimization.VariantPlanFactory.build( ...
    robustData,1);
resolverPln = planWorkflow.results.VariantPlanResolver.resolve( ...
    robustData,variantResult);

verifyEqual(testCase,factoryPln.propOpt.theta1,5);
verifyEqual(testCase,resolverPln.propOpt.theta1, ...
    factoryPln.propOpt.theta1);
end

function testWorkflowParameterSchemaParsesEditableValues(testCase)
verifyTrue(testCase, ...
    planWorkflow.config.WorkflowParameterSchema.parseValue( ...
    'true','logical','useCache'));
verifyEqual(testCase, ...
    planWorkflow.config.WorkflowParameterSchema.parseValue( ...
    '[2 3 4]','resolution','doseResolution'),[2 3 4]);
verifyEqual(testCase, ...
    planWorkflow.config.WorkflowParameterSchema.parseValue( ...
    '{"a":1}','structJson','dicomMetadata').a,1);
end

function testClinicalEndpointFileIndexReportsInvalidFiles(testCase)
fixture = testCase.applyFixture( ...
    matlab.unittest.fixtures.TemporaryFolderFixture);
endpointFile = fullfile(fixture.Folder,'broken.json');
writeText(endpointFile,'{"endpoints":[{"metric":"V60"}]}');

files = planWorkflow.analysis.ClinicalEndpointFileIndex.files( ...
    fixture.Folder);
invalidFiles = ...
    planWorkflow.analysis.ClinicalEndpointFileIndex.invalidFiles( ...
    fixture.Folder);
matchingFiles = ...
    planWorkflow.analysis.ClinicalEndpointFileIndex.filesForDoseQuantity( ...
    'physicalDose',fixture.Folder);

verifyEqual(testCase,numel(files),1);
verifyFalse(testCase,files(1).isValid);
verifyFalse(testCase,files(1).metadataValid);
verifyFalse(testCase,files(1).contractValid);
verifyNotEmpty(testCase,files(1).errorMessage);
verifyEqual(testCase,numel(invalidFiles),1);
verifyEmpty(testCase,matchingFiles);
verifyError(testCase,@() ...
    planWorkflow.analysis.ClinicalEndpointFileIndex.fileDoseQuantities( ...
    endpointFile), ...
    'planWorkflow:analysis:ClinicalEndpointFileIndex:InvalidEndpointFile');
end

function testClinicalEndpointFileIndexSeparatesMetadataAndContractValidity(testCase)
fixture = testCase.applyFixture( ...
    matlab.unittest.fixtures.TemporaryFolderFixture);
endpointFile = fullfile(fixture.Folder,'metadata_only.json');
writeText(endpointFile, ...
    ['{"endpoints":[{"doseQuantity":"physicalDose",' ...
     '"metric":"Unsupported"}]}']);

files = planWorkflow.analysis.ClinicalEndpointFileIndex.files( ...
    fixture.Folder);
doseQuantities = ...
    planWorkflow.analysis.ClinicalEndpointFileIndex.fileDoseQuantities( ...
    endpointFile);

verifyTrue(testCase,files(1).metadataValid);
verifyFalse(testCase,files(1).contractValid);
verifyFalse(testCase,files(1).isValid);
verifyEqual(testCase,doseQuantities,{'physicalDose'});
verifyEmpty(testCase, ...
    planWorkflow.analysis.ClinicalEndpointFileIndex.filesForDoseQuantity( ...
    'physicalDose',fixture.Folder));
verifyError(testCase,@() ...
    planWorkflow.analysis.ClinicalEndpointCatalog.loadFile(endpointFile), ...
    'planWorkflow:analysis:ClinicalEndpointCatalog:MissingEndpointField');
end

function testEndpointOptionsUseCanonicalDoseQuantityResolver(testCase)
analysis = planWorkflow.config.Analysis.defaults();
analysis.endpointsFile = 'prostate.json';
runConfig = minimalRunConfig();
runConfig.radiationMode = 'protons';
runConfig.bioModel = 'constRBE';

verifyEqual(testCase, ...
    planWorkflow.plan.DoseQuantityResolver.fromRunConfig(runConfig), ...
    'RBExD');
optionSets = planWorkflow.gui.WorkflowParameterOptions.analysisOptionSets( ...
    analysis,struct(),runConfig);

verifyEqual(testCase,optionSets.endpointsFile.values{2},'none');
verifyFalse(testCase,any(strcmp( ...
    optionSets.endpointsFile.validValues,'prostate.json')));
verifyTrue(testCase,any(strcmp( ...
    optionSets.endpointsFile.values,'prostate.json')));

runConfig.radiationMode = 'photons';
runConfig.bioModel = 'none';
runConfig.quantityOpt = 'effect';
verifyEqual(testCase, ...
    planWorkflow.plan.DoseQuantityResolver.fromRunConfig(runConfig), ...
    'effect');
verifyEqual(testCase, ...
    planWorkflow.plan.DoseQuantityResolver.visualFromRunConfig(runConfig), ...
    'physicalDose');
optionSets = planWorkflow.gui.WorkflowParameterOptions.analysisOptionSets( ...
    analysis,struct(),runConfig);
verifyTrue(testCase,any(strcmp( ...
    optionSets.endpointsFile.validValues,'prostate.json')));
end

function testClinicalEndpointRowsAreModeledOutsideReporter(testCase)
planResults = struct();
planResults.evaluationModeBase = 'perFraction';
planResults.evaluationMode = 'perFraction';
planResults.evaluationScale = 1;
planResults.numOfFractions = 30;
planResults.analysisQuantity = 'physicalDose';
planResults.cstStat = struct('name','BLADDER','dvhStat',struct( ...
    'mean',struct('doseGrid',[0 1 2 3], ...
    'volumePoints',[100 100 50 0]), ...
    'min',struct('doseGrid',[0 1 2 3], ...
    'volumePoints',[100 100 50 0]), ...
    'max',struct('doseGrid',[0 1 2 3], ...
    'volumePoints',[100 100 50 0])));
runConfig = minimalRunConfig();
runConfig.analysis.endpoints = struct( ...
    'structureNames',{{'BLADDER'}}, ...
    'metric','V1', ...
    'kind','V', ...
    'goal','lowerIsBetter', ...
    'doseQuantity','physicalDose', ...
    'threshold',1, ...
    'thresholdUnit','Gy', ...
    'thresholdMode','perFractionDose', ...
    'unit','%');

rows = planWorkflow.gui.ClinicalEndpointTableModel.rows( ...
    planResults,runConfig,[]);

verifyEqual(testCase,rows(1,1:2),{'BLADDER','V1'});
verifyEqual(testCase,rows{1,3},100);
end

function testTextLayoutIsSharedByGuiConsumers(testCase)
topic = 'DosePulling JSON';
wrapColumn = planWorkflow.gui.TextLayout.objectiveHelpTextWrapColumn();
expectedText = planWorkflow.gui.TextLayout.helpTextForDisplay( ...
    planWorkflow.gui.HelpText.objective(topic),wrapColumn);

verifyEqual(testCase, ...
    planWorkflow.gui.panels.PreparePanel.objectiveHelpTextForDisplay( ...
    topic),expectedText);
verifyGreaterThan(testCase, ...
    planWorkflow.gui.TextLayout.helpTextHeightForDisplay( ...
    expectedText,wrapColumn),0);
end

function runConfig = minimalRunConfig()
precompute = planWorkflow.config.RobustPlanConfig.defaults();
runConfig = struct();
runConfig.description = 'prostate';
runConfig.caseID = 'testCase';
runConfig.AcquisitionType = 'mat';
runConfig.dicomMetadata = struct();
runConfig.radiationMode = 'photons';
runConfig.machine = 'Generic';
runConfig.bioModel = 'none';
runConfig.plan_beams = 'testBeams';
runConfig.plan_template = 'testTemplate';
runConfig.workflowType = 'robust';
runConfig.runId = 'testRun';
runConfig.outputRootPath = tempdir;
runConfig.cacheRootPath = tempdir;
runConfig.doseResolution = [3 3 3];
runConfig.precompute = precompute;
end

function data = minimalPreparedData()
data = struct();
data.ct = struct();
data.cst = {'idx','BODY','OAR',[]};
data.pln = struct();
data.stf = struct('totalNumOfBixels',1);
end

function runtime = minimalRuntime()
runtime = planWorkflow.stages.WorkflowRuntime( ...
    @(varargin) [],@(message) [], ...
    @(stageName,fraction,message) []);
end

function plan = robustPlanConfig()
plan = planWorkflow.config.RobustPlanConfig.defaultPlan();
plan.id = 'robust_1';
plan.label = 'Robust 1';
plan.objectiveSetName = 'robust_1';
plan.robustnessMode = 'INTERVAL2';
plan.variants = struct('id','theta_5','label','theta1=5', ...
    'theta1',5);
plan = planWorkflow.config.RobustPlanConfig.normalizePlan(plan,1);
end

function writeText(filePath,text)
fid = fopen(filePath,'w');
cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid,'%s',text);
end
