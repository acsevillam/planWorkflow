function tests = testSamplingAnalysisReanalysis
tests = functiontests(localfunctions);
end

function testRecalculateAnalysisMaterializesSamplingAfterReleaseMemory(testCase)
cleanup = installSamplingAnalysisStubs(testCase); %#ok<NASGU>
workflow = planWorkflowTest.SamplingAnalysisWorkflow( ...
    baseSamplingConfig(testCase));

workflow.prepare();
workflow.precompute();
workflow.pullDose();
workflow.optimize();
workflow.sample();
workflow.analyze();

verifyCompactedSamplingData(testCase,workflow.data.sampling, ...
    workflow.cachePath);
dataSnapshot = load(workflow.dataFile,'data');
verifyCompactedSamplingData(testCase,dataSnapshot.data.sampling, ...
    workflow.cachePath);

workflow.releaseMemory();
workflow.recalculateAnalysis();

verifyEqual(testCase,workflow.data.results.analysisCount,2);
verifyEqual(testCase, ...
    workflow.data.results.sampling.reference.meta.sampleDoseSum,36);
verifyEqual(testCase, ...
    workflow.data.results.sampling.robust{1}.meta.sampleDoseSum,72);
verifyCompactedSamplingData(testCase,workflow.data.sampling, ...
    workflow.cachePath);
end

function testRecalculateAnalysisMaterializesSamplingAfterResume(testCase)
cleanup = installSamplingAnalysisStubs(testCase); %#ok<NASGU>
workflow = planWorkflowTest.SamplingAnalysisWorkflow( ...
    baseSamplingConfig(testCase));

workflow.prepare();
workflow.precompute();
workflow.pullDose();
workflow.optimize();
workflow.sample();
workflow.analyze();

resumed = planWorkflow.WorkflowBase.resumeFrom(workflow.stateFile);
verifyClass(testCase,resumed, ...
    'planWorkflowTest.SamplingAnalysisWorkflow');
verifyCompactedSamplingData(testCase,resumed.data.sampling, ...
    resumed.cachePath);

resumed.recalculateAnalysis();

verifyEqual(testCase,resumed.data.results.analysisCount,2);
verifyEqual(testCase, ...
    resumed.data.results.sampling.reference.meta.numSamples,2);
verifyEqual(testCase, ...
    resumed.data.results.sampling.robust{1}.meta.numSamples,2);
verifyCompactedSamplingData(testCase,resumed.data.sampling, ...
    resumed.cachePath);
end

function verifyCompactedSamplingData(testCase,samplingData,cachePath)
verifyTrue(testCase,isfield(samplingData,'samplingPayloadRef'));
verifyTrue(testCase,isfield(samplingData.reference,'samplingPayloadRef'));
verifyTrue(testCase,isfield(samplingData.robust{1}, ...
    'samplingPayloadRef'));
verifyFalse(testCase,isfield(samplingData,'ct'));
verifyFalse(testCase,isfield(samplingData,'cst'));
verifyFalse(testCase,isfield(samplingData,'multScen'));
verifyFalse(testCase,isfield(samplingData.reference,'caSamp'));
verifyFalse(testCase,isfield(samplingData.reference,'mSampDose'));
verifyFalse(testCase,isfield(samplingData.reference,'resultGUINomScen'));
verifyFalse(testCase,isfield(samplingData.robust{1},'caSamp'));
verifyPayloadRefFile(testCase,cachePath,samplingData.samplingPayloadRef);
verifyPayloadRefFile(testCase,cachePath, ...
    samplingData.reference.samplingPayloadRef);
verifyPayloadRefFile(testCase,cachePath, ...
    samplingData.robust{1}.samplingPayloadRef);
end

function verifyPayloadRefFile(testCase,cachePath,ref)
verifyTrue(testCase, ...
    planWorkflow.persistence.SamplingPayloadArtifact.isRef(ref));
verifyTrue(testCase, ...
    exist(fullfile(cachePath,ref.cacheRelativeFile),'file') == 2);
end

function config = baseSamplingConfig(testCase)
fixture = testCase.applyFixture( ...
    matlab.unittest.fixtures.TemporaryFolderFixture);
config = struct();
config.outputRootPath = fullfile(fixture.Folder,'output');
config.cacheRootPath = fullfile(fixture.Folder,'cache');
config.runId = 'sampling-reanalysis-test';
config.analysis = planWorkflow.config.Analysis.defaults();
config.analysis.figures.save = false;
config.analysis.figures.visible = 'off';
config.quantityOpt = 'physicalDose';
end

function cleanup = installSamplingAnalysisStubs(testCase)
fixture = testCase.applyFixture( ...
    matlab.unittest.fixtures.TemporaryFolderFixture);
writeMatRadSamplingAnalysisStub(fixture.Folder);
writeMatRadEvaluationModeStub(fixture.Folder);
addpath(fixture.Folder,'-begin');
clear matRad_samplingAnalysis matRad_convertToEvaluationMode;
cleanup = onCleanup(@() cleanupSamplingAnalysisStubs(fixture.Folder));
end

function writeMatRadSamplingAnalysisStub(folder)
fid = fopen(fullfile(folder,'matRad_samplingAnalysis.m'),'w');
fprintf(fid,[ ...
    'function [cstStat,doseStat,meta,gammaFig,robustnessFig1, ...\n' ...
    '    robustnessFig2] = matRad_samplingAnalysis(~,~,~,caSamp, ...\n' ...
    '    mSampDose,resultGUINomScen,varargin)\n' ...
    'dvh = struct(''doseGrid'',[0; 1; 2],''volumePoints'',[100; 50; 0]);\n' ...
    'cstStat = struct(''name'',''CTV'',''dvhStat'',struct(''mean'',dvh,''std'',dvh));\n' ...
    'doseStat = struct();\n' ...
    'doseStat.meanCubeW = reshape([1 2 3 4],[2 2 1]);\n' ...
    'doseStat.stdCubeW = zeros(2,2,1);\n' ...
    'doseStat.meanCube = doseStat.meanCubeW;\n' ...
    'doseStat.stdCube = doseStat.stdCubeW;\n' ...
    'doseStat.sampleMask = true(2,2,1);\n' ...
    'doseStat.sampleCoverageFraction = 1;\n' ...
    'doseStat.gammaAnalysis = struct(''gammaPassRate'',100,''gammaCube'',ones(2));\n' ...
    'doseStat.robustnessAnalysis = struct(''index1'',struct(''robustnessIndex'',1));\n' ...
    'meta = struct();\n' ...
    'meta.numSamples = numel(caSamp);\n' ...
    'meta.sampleDoseSum = double(sum(mSampDose(:)));\n' ...
    'meta.nominalFieldCount = numel(fieldnames(resultGUINomScen));\n' ...
    'gammaFig = [];\n' ...
    'robustnessFig1 = [];\n' ...
    'robustnessFig2 = [];\n' ...
    'end\n']);
fclose(fid);
end

function writeMatRadEvaluationModeStub(folder)
fid = fopen(fullfile(folder,'matRad_convertToEvaluationMode.m'),'w');
fprintf(fid,[ ...
    'function [value,mode] = matRad_convertToEvaluationMode(value,~,mode)\n' ...
    'if nargin < 3 || isempty(mode)\n' ...
    '    mode = ''perFraction'';\n' ...
    'end\n' ...
    'mode = char(mode);\n' ...
    'end\n']);
fclose(fid);
end

function cleanupSamplingAnalysisStubs(folder)
pathEntries = strsplit(path,pathsep);
if any(strcmp(pathEntries,folder))
    rmpath(folder);
end
clear matRad_samplingAnalysis matRad_convertToEvaluationMode;
end
