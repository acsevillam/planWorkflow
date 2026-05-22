function tests = testResourceLifecycle
tests = functiontests(localfunctions);
end

function testResultGUICompactorDropsOptimizationDoseCubes(testCase)
resultGUI = struct();
resultGUI.w = [1; 2; 3];
resultGUI.wUnsequenced = [3; 2; 1];
resultGUI.usedOptimizer = struct('name','stub');
resultGUI.info = struct('iterations',4);
resultGUI.physicalDose = ones(2,2,2);
resultGUI.physicalDose_scen1 = ones(2,2,2);
resultGUI.doseToWater_beam1 = ones(2,2,2);
resultGUI.effect = ones(2,2,2);
resultGUI.RBExDose_scen2 = ones(2,2,2);
resultGUI.LET = ones(2,2,2);
resultGUI.smallMetadata = 'kept';

compact = planWorkflow.results.ResultGUICompactor.compact(resultGUI);

verifyEqual(testCase,compact.w,[1; 2; 3]);
verifyEqual(testCase,compact.wUnsequenced,[3; 2; 1]);
verifyTrue(testCase,isfield(compact,'usedOptimizer'));
verifyTrue(testCase,isfield(compact,'info'));
verifyEqual(testCase,compact.smallMetadata,'kept');
verifyFalse(testCase,isfield(compact,'physicalDose'));
verifyFalse(testCase,isfield(compact,'physicalDose_scen1'));
verifyFalse(testCase,isfield(compact,'doseToWater_beam1'));
verifyFalse(testCase,isfield(compact,'effect'));
verifyFalse(testCase,isfield(compact,'RBExDose_scen2'));
verifyFalse(testCase,isfield(compact,'LET'));
end

function testWeightValidationDoesNotRequireFullDij(testCase)
owner.optimizationInput = struct();
owner.optimizationInput.ct = struct('numOfCtScen',1);
owner.optimizationInput.cst = {1};
owner.optimizationInput.pln = struct('propStf',struct());
owner.optimizationInput.stf = struct('totalNumOfBixels',3);
owner.optimizationInput.dijKind = 'nominal';
owner.optimizationInput.source = 'reference';
owner.optimizationInput.dijRef = struct( ...
    'artifactKind',planWorkflow.persistence.WorkflowDataArtifact.RefKind, ...
    'totalNumOfBixels',3);
resultGUI = struct('w',[1; 2; 3]);

input = planWorkflow.precompute.OptimizationInput.requireLight( ...
    owner,'reference sampling');
planWorkflow.precompute.OptimizationInput.assertWeightSteeringMatch( ...
    input,resultGUI,'reference','','reference sampling');

verifyError(testCase,@() ...
    planWorkflow.precompute.OptimizationInput.requireFullDij( ...
    owner,'reference analysis',struct(),'',owner), ...
    'planWorkflow:precompute:OptimizationInput:FullDijNotAllowed');
end

function testSamplingDataCompactorDropsAnalyzedPayloads(testCase)
sample = struct();
sample.label = 'INTERVAL3';
sample.mSampDose = single(ones(4,3));
sample.caSamp = repmat(struct('qi',1,'dvh',1),1,3);
sample.resultGUINomScen = struct('physicalDose',ones(2,2,1));
sample.pln = struct('subIx',[1; 2; 3; 4]);

samplingData = struct();
samplingData.ct = struct('cubeDim',[2 2 1],'numOfCtScen',1,'refScen',1);
samplingData.cst = cell(2,6);
samplingData.multScen = struct('totNumScen',3);
samplingData.reference = sample;
samplingData.robust = {sample};

compact = planWorkflow.results.SamplingDataCompactor.compactSamplingData( ...
    samplingData);

verifyFalse(testCase,isfield(compact,'ct'));
verifyFalse(testCase,isfield(compact,'cst'));
verifyFalse(testCase,isfield(compact,'multScen'));
verifyFalse(testCase,isfield(compact.reference,'mSampDose'));
verifyFalse(testCase,isfield(compact.reference,'caSamp'));
verifyFalse(testCase,isfield(compact.reference,'resultGUINomScen'));
verifyEqual(testCase, ...
    compact.reference.samplingPayloadSummary.numSampleVoxels,4);
verifyEqual(testCase, ...
    compact.robust{1}.samplingPayloadSummary.numSamples,3);
end

function testSamplingPayloadArtifactRoundTripsCompactedData(testCase)
fixture = testCase.applyFixture( ...
    matlab.unittest.fixtures.TemporaryFolderFixture);
cachePath = fullfile(fixture.Folder,'cache');
runConfig = struct('cacheRootPath',cachePath,'runId','sampling-artifact');
samplingData = samplingPayloadFixture();

compact = ...
    planWorkflow.persistence.SamplingPayloadArtifact.compactSamplingData( ...
    samplingData,runConfig,cachePath);

verifyFalse(testCase,isfield(compact,'ct'));
verifyFalse(testCase,isfield(compact,'cst'));
verifyFalse(testCase,isfield(compact,'multScen'));
verifyTrue(testCase,isfield(compact,'samplingPayloadRef'));
verifyTrue(testCase,isfield(compact.reference,'samplingPayloadRef'));
verifyTrue(testCase,isfield(compact.robust{1},'samplingPayloadRef'));
verifyFalse(testCase,isfield(compact.reference,'caSamp'));
verifyEqual(testCase,compact.reference.samplingPayloadRef.role, ...
    'reference');
verifyEqual(testCase,compact.reference.samplingPayloadRef.label, ...
    'INTERVAL3');
verifyEqual(testCase,compact.reference.samplingPayloadRef.numSamples,3);
verifyTrue(testCase,exist(fullfile(cachePath, ...
    compact.samplingPayloadRef.cacheRelativeFile),'file') == 2);
verifyTrue(testCase,exist(fullfile(cachePath, ...
    compact.reference.samplingPayloadRef.cacheRelativeFile),'file') == 2);

materialized = ...
    planWorkflow.persistence.SamplingPayloadArtifact.materializeSamplingData( ...
    compact,runConfig,cachePath);

verifyEqual(testCase,materialized.ct,samplingData.ct);
verifyEqual(testCase,materialized.cst,samplingData.cst);
verifyEqual(testCase,materialized.multScen,samplingData.multScen);
verifyEqual(testCase,materialized.reference.caSamp, ...
    samplingData.reference.caSamp);
verifyEqual(testCase,materialized.reference.mSampDose, ...
    samplingData.reference.mSampDose);
verifyEqual(testCase,materialized.reference.resultGUINomScen, ...
    samplingData.reference.resultGUINomScen);
verifyEqual(testCase,materialized.robust{1}.mSampDose, ...
    samplingData.robust{1}.mSampDose);
end

function testSamplingPayloadArtifactCompactsSampleUnitForResume(testCase)
fixture = testCase.applyFixture( ...
    matlab.unittest.fixtures.TemporaryFolderFixture);
cachePath = fullfile(fixture.Folder,'cache');
runConfig = struct('cacheRootPath',cachePath,'runId','sampling-unit');
samplingData = samplingPayloadFixture();
sample = samplingData.reference;
sample.label = 'reference';
sample.planId = 'PTV_001';
sample.variantId = 'ref_nomScen';
sample.role = 'reference';
unitInfo = struct( ...
    'role','reference', ...
    'planId',sample.planId, ...
    'variantId',sample.variantId, ...
    'label',sample.label, ...
    'unitIndex',1, ...
    'unitKey','reference_001_PTV_001_ref_nomScen');

compact = ...
    planWorkflow.persistence.SamplingPayloadArtifact.compactSampleUnit( ...
    sample,runConfig,cachePath,unitInfo.unitKey,unitInfo);

verifyTrue(testCase,isfield(compact,'samplingPayloadRef'));
verifyFalse(testCase,isfield(compact,'caSamp'));
verifyFalse(testCase,isfield(compact,'mSampDose'));
verifyFalse(testCase,isfield(compact,'resultGUINomScen'));
verifyTrue(testCase,exist(fullfile(cachePath, ...
    compact.samplingPayloadRef.cacheRelativeFile),'file') == 2);

[cached,found] = ...
    planWorkflow.persistence.SamplingPayloadArtifact.cachedSampleUnit( ...
    runConfig,cachePath,unitInfo.unitKey,unitInfo);

verifyTrue(testCase,found);
verifyEqual(testCase,cached.planId,'PTV_001');
verifyEqual(testCase,cached.variantId,'ref_nomScen');
verifyEqual(testCase,cached.pln,sample.pln);
verifyFalse(testCase,isfield(cached,'mSampDose'));

materialized = ...
    planWorkflow.persistence.SamplingPayloadArtifact.materializeSampleUnit( ...
    cached,runConfig,cachePath);

verifyEqual(testCase,materialized.mSampDose,sample.mSampDose);
verifyEqual(testCase,materialized.caSamp,sample.caSamp);
verifyEqual(testCase,materialized.resultGUINomScen, ...
    sample.resultGUINomScen);

tmpFiles = dir(fullfile(cachePath,'sampling_payloads','**','*.tmp'));
verifyEmpty(testCase,tmpFiles);

delete(fullfile(cachePath,compact.samplingPayloadRef.cacheRelativeFile));
[~,foundAfterDelete] = ...
    planWorkflow.persistence.SamplingPayloadArtifact.cachedSampleUnit( ...
    runConfig,cachePath,unitInfo.unitKey,unitInfo);
verifyFalse(testCase,foundAfterDelete);
end

function testSamplingPayloadArtifactErrorsWhenRefFileIsMissing(testCase)
fixture = testCase.applyFixture( ...
    matlab.unittest.fixtures.TemporaryFolderFixture);
cachePath = fullfile(fixture.Folder,'cache');
runConfig = struct('cacheRootPath',cachePath,'runId','sampling-artifact');
compact = ...
    planWorkflow.persistence.SamplingPayloadArtifact.compactSamplingData( ...
    samplingPayloadFixture(),runConfig,cachePath);
payloadFile = fullfile(cachePath, ...
    compact.reference.samplingPayloadRef.cacheRelativeFile);
delete(payloadFile);

verifyError(testCase,@() ...
    planWorkflow.persistence.SamplingPayloadArtifact.materializeSamplingData( ...
    compact,runConfig,cachePath), ...
    ['planWorkflow:persistence:SamplingPayloadArtifact:' ...
    'MissingPayloadFile']);
end

function testStageLifecycleCompactsSamplingPayloadAfterSample(testCase)
fixture = testCase.applyFixture( ...
    matlab.unittest.fixtures.TemporaryFolderFixture);
cachePath = fullfile(fixture.Folder,'cache');
runConfig = struct('cacheRootPath',cachePath,'runId','sample-stage');
patch = struct();
patch.data = struct('sampling',samplingPayloadFixture());

patch = planWorkflow.resources.StageDataLifecycle.afterStage( ...
    'sample',patch,runConfig,[]);

verifyFalse(testCase,isfield(patch.data.sampling,'ct'));
verifyTrue(testCase,isfield(patch.data.sampling,'samplingPayloadRef'));
verifyTrue(testCase,isfield(patch.data.sampling.reference, ...
    'samplingPayloadRef'));
verifyTrue(testCase,exist(fullfile(cachePath, ...
    patch.data.sampling.reference.samplingPayloadRef.cacheRelativeFile), ...
    'file') == 2);
end

function testSamplingResultCompactorDropsDoseCubes(testCase)
doseStat = struct();
doseStat.meanCubeW = [1 2 3];
doseStat.stdCubeW = [0.1 0.2 0.3];
doseStat.meanCube = [1 2 3];
doseStat.stdCube = [0 0 0];
doseStat.sampleMask = [true false true];
doseStat.gammaAnalysis = struct( ...
    'gammaPassRate',95, ...
    'cube1',ones(2), ...
    'cube2',ones(2), ...
    'gammaCube',ones(2));
doseStat.robustnessAnalysis = struct( ...
    'sourceCube',ones(2), ...
    'index1',struct('robustnessIndex',0.5));
planResults = struct('doseStat',doseStat);

compact = ...
    planWorkflow.results.SamplingDataCompactor.compactPlanSamplingResults( ...
    planResults);

verifyFalse(testCase,isfield(compact.doseStat,'meanCubeW'));
verifyFalse(testCase,isfield(compact.doseStat,'stdCubeW'));
verifyFalse(testCase,isfield(compact.doseStat.gammaAnalysis,'gammaCube'));
verifyFalse(testCase,isfield(compact.doseStat.robustnessAnalysis, ...
    'sourceCube'));
verifyEqual(testCase,compact.doseStat.summary.meanCubeWMax,3);
verifyEqual(testCase,compact.doseStat.summary.stdCubeWMax,0.3, ...
    'AbsTol',1e-12);
verifyEqual(testCase,compact.doseStat.gammaAnalysis.gammaPassRate,95);
verifyEqual(testCase, ...
    compact.doseStat.robustnessAnalysis.index1.robustnessIndex,0.5);
end

function samplingData = samplingPayloadFixture()
sample = struct();
sample.label = 'INTERVAL3';
sample.mSampDose = single(reshape(1:12,4,3));
sample.caSamp = repmat(struct('qi',1,'dvh',1),1,3);
sample.resultGUINomScen = struct('physicalDose',ones(2,2,1));
sample.pln = struct('subIx',[1; 2; 3; 4]);

samplingData = struct();
samplingData.ct = struct( ...
    'cubeDim',[2 2 1], ...
    'numOfCtScen',1, ...
    'refScen',1, ...
    'z',1, ...
    'resolution',struct('z',1));
samplingData.cst = cell(2,6);
samplingData.multScen = struct('totNumScen',3);
samplingData.reference = sample;

robustSample = sample;
robustSample.label = 'ROBUST';
robustSample.mSampDose = single(2 * reshape(1:12,4,3));
samplingData.robust = {robustSample};
end
