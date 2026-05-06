function tests = testApplyPlanObjectives
tests = functiontests(localfunctions);
end

function testPlanObjectivesReplaceImportedDefaults(testCase)
samplingCst = minimalCst();
samplingCst{1,3} = 'TARGET';
samplingCst{1,6}{1} = struct(DoseObjectives.matRad_SquaredDeviation(800,30));
samplingCst{2,3} = 'TARGET';
samplingCst{2,6}{1} = struct(DoseObjectives.matRad_SquaredDeviation(800,30));

planCst = samplingCst;
planCst{1,3} = 'TARGET';
planCst{1,5}.Priority = 1;
planCst{1,6}{1} = struct(DoseObjectives.matRad_SquaredDeviation(1,78));
planCst{2,3} = 'OAR';
planCst{2,5}.Priority = 2;
planCst{2,6} = [];

analysisCst = planWorkflow.structures.applyPlanObjectives( ...
    samplingCst,planCst);

verifyEqual(testCase,analysisCst{1,4},samplingCst{1,4});
verifyEqual(testCase,analysisCst{1,3},'TARGET');
verifyEqual(testCase,analysisCst{1,5}.Priority,1);
verifyEqual(testCase,analysisCst{1,6}{1}.parameters{1},78);
verifyEqual(testCase,analysisCst{2,3},'OAR');
verifyEmpty(testCase,analysisCst{2,6});
end

function testUnmatchedStructuresDoNotKeepStaleObjectives(testCase)
samplingCst = minimalCst();
samplingCst(3,:) = samplingCst(2,:);
samplingCst{3,1} = 3;
samplingCst{3,2} = 'EXTRA';
samplingCst{3,6}{1} = struct(DoseObjectives.matRad_SquaredDeviation(800,30));

planCst = samplingCst(1:2,:);

analysisCst = planWorkflow.structures.applyPlanObjectives( ...
    samplingCst,planCst);

verifyEmpty(testCase,analysisCst{3,6});
end

function testDuplicatePlanNamesAreRejected(testCase)
samplingCst = minimalCst();
planCst = samplingCst;
planCst{2,2} = planCst{1,2};

verifyError(testCase,@() planWorkflow.structures.applyPlanObjectives( ...
    samplingCst,planCst),'planWorkflow:structures:DuplicateStructureName');
end

function cst = minimalCst()
cst = cell(2,6);
cst{1,1} = 1;
cst{1,2} = 'CTV';
cst{1,3} = 'TARGET';
cst{1,4}{1} = [1 2 3];
cst{1,5} = struct();
cst{1,6} = [];
cst{2,1} = 2;
cst{2,2} = 'PTV';
cst{2,3} = 'TARGET';
cst{2,4}{1} = [1 2 3 4];
cst{2,5} = struct();
cst{2,6} = [];
end
