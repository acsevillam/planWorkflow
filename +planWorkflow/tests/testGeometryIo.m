function tests = testGeometryIo
tests = functiontests(localfunctions);
end

function testSaveGeometryUpdatesMatAndPreservesExtraVariables(testCase)
fixture = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
runConfig = baseRunConfig(fixture.Folder);
patientRoot = fullfile(runConfig.patientDataPath,runConfig.description);
mkdir(patientRoot);

ct = struct('cubeDim',[1 1 1]);
cst = cell(1,6);
cst{1,1} = 1;
cst{1,2} = 'CTV';
cst{1,3} = 'TARGET';
cst{1,4}{1} = 1;
cst{1,5} = struct();
cst{1,6}{1} = struct(DoseObjectives.matRad_SquaredDeviation(800,30));
importMetadata = struct('patientID','original');
save(fullfile(patientRoot,'case.mat'),'ct','cst','importMetadata');

cst{1,6}{1} = struct(DoseObjectives.matRad_SquaredDeviation(1,78));
planWorkflow.io.saveGeometry(runConfig,"optimization",ct,cst);

snapshot = load(fullfile(patientRoot,'case.mat'));
verifyEqual(testCase,snapshot.importMetadata.patientID,'original');
verifyEqual(testCase,snapshot.cst{1,6}{1}.parameters{1},78);
end

function testSaveGeometryIgnoresDicomAcquisition(testCase)
fixture = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
runConfig = baseRunConfig(fixture.Folder);
runConfig.AcquisitionType = 'dicom';

ct = struct();
cst = cell(0,6);
planWorkflow.io.saveGeometry(runConfig,"optimization",ct,cst);

verifyFalse(testCase,isfile(fullfile(runConfig.patientDataPath, ...
    runConfig.description,'case.mat')));
end

function runConfig = baseRunConfig(rootFolder)
runConfig = struct();
runConfig.description = 'synthetic';
runConfig.caseID = 'case';
runConfig.AcquisitionType = 'mat';
runConfig.sampling_caseID = 'case';
runConfig.sampling_AcquisitionType = 'mat';
runConfig.patientDataPath = fullfile(rootFolder,'patients');
end
