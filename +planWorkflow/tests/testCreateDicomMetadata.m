function tests = testCreateDicomMetadata
tests = functiontests(localfunctions);
end

function testOptimizationMetadataIsMerged(testCase)
runConfig = baseRunConfig();
runConfig.dicomMetadata = struct( ...
    'patientID','PATIENT-1', ...
    'useDoseGrid',false);

metadata = planWorkflow.io.createDicomMetadata(runConfig,'optimization');

verifyEqual(testCase,metadata.resolution,[3 3 3]);
verifyEqual(testCase,metadata.patientID,'PATIENT-1');
verifyFalse(testCase,metadata.useDoseGrid);
end

function testDicomMetadataResolutionOverridesDefault(testCase)
runConfig = baseRunConfig();
runConfig.dicomMetadata = struct('resolution',[2 2 2]);

metadata = planWorkflow.io.createDicomMetadata(runConfig,'optimization');

verifyEqual(testCase,metadata.resolution,[2 2 2]);
end

function testSamplingMetadataOverridesOptimizationMetadata(testCase)
runConfig = baseRunConfig();
runConfig.dicomMetadata = struct('ctSeriesUIDs',{{'optimization-series'}});
runConfig.sampling_dicomMetadata = struct('ctSeriesUIDs',{{'sampling-series'}});

metadata = planWorkflow.io.createDicomMetadata(runConfig,'sampling');

verifyEqual(testCase,metadata.ctSeriesUIDs,{'sampling-series'});
end

function testSamplingFallsBackToOptimizationMetadataForSameCase(testCase)
runConfig = baseRunConfig();
runConfig.dicomMetadata = struct('rtssUIDs',{{'rtss-1'}});

metadata = planWorkflow.io.createDicomMetadata(runConfig,'sampling');

verifyEqual(testCase,metadata.rtssUIDs,{'rtss-1'});
end

function testSamplingDoesNotReuseOptimizationMetadataForDifferentCase(testCase)
runConfig = baseRunConfig();
runConfig.sampling_caseID = 'sampling-case';
runConfig.dicomMetadata = struct('patientID','PATIENT-1');

metadata = planWorkflow.io.createDicomMetadata(runConfig,'sampling');

verifyFalse(testCase,isfield(metadata,'patientID'));
end

function testMissingResolutionIsRejected(testCase)
runConfig = rmfield(baseRunConfig(),'resolution');

verifyError(testCase, ...
    @() planWorkflow.io.createDicomMetadata(runConfig,'optimization'), ...
    'planWorkflow:io:createDicomMetadata:MissingResolution');
end

function runConfig = baseRunConfig()
runConfig = struct();
runConfig.caseID = 'case';
runConfig.sampling_caseID = 'case';
runConfig.resolution = [3 3 3];
runConfig.dicomMetadata = struct();
runConfig.sampling_dicomMetadata = struct();
end
