function tests = testAnalysisConfig
tests = functiontests(localfunctions);
end

function testNormalizeAddsDefaultsAndCanonicalEvaluationMode(testCase)
analysis = planWorkflow.config.Analysis.normalize(struct('evaluationMode','perFraction'));

verifyEqual(testCase,analysis.evaluationMode,'perFraction');
verifyEqual(testCase,analysis.gammaCriteria,[3 3]);
verifyEqual(testCase,analysis.robustnessCriteria,[5 5]);
verifyEqual(testCase,analysis.robustnessTargetMode,'all');
verifyEqual(testCase,analysis.robustnessTargets,[]);
verifyTrue(testCase,isfield(analysis,'doseWindowDvh'));
verifyTrue(testCase,isfield(analysis,'doseWindowExpectedDoseDifference'));
verifyFalse(testCase,isfield(analysis,'doseWindowUvh'));
verifyEqual(testCase,analysis.figures.save,true);
verifyEqual(testCase,analysis.figures.visible,'auto');
verifyEqual(testCase,analysis.figures.closeAfterSave,true);
end

function testNormalizeRejectsUnsupportedFields(testCase)
verifyError(testCase, ...
    @() planWorkflow.config.Analysis.normalize(struct('sampling',true)), ...
    'planWorkflow:config:Analysis:UnsupportedField');
end

function testNormalizeFigurePolicy(testCase)
analysis = planWorkflow.config.Analysis.normalize(struct( ...
    'figures',struct('save',false,'visible',false)));

verifyFalse(testCase,analysis.figures.save);
verifyEqual(testCase,analysis.figures.visible,'off');
verifyTrue(testCase,analysis.figures.closeAfterSave);
end

function testNormalizeRejectsUnsupportedFigureFields(testCase)
verifyError(testCase, ...
    @() planWorkflow.config.Analysis.normalize(struct( ...
    'figures',struct('legacy',true))), ...
    'planWorkflow:config:Analysis:UnsupportedFigureField');
end

function testPrescriptionDefaultsUseTotalDose(testCase)
pln = struct('numOfFractions',20);
analysis = planWorkflow.config.Analysis.applyPrescriptionDefaults( ...
    struct('evaluationMode','total'),80,pln);

verifyEqual(testCase,analysis.doseWindow,[0 100],'AbsTol',1e-12);
verifyEqual(testCase,analysis.doseWindowDvh,[0 128],'AbsTol',1e-12);
verifyEqual(testCase,analysis.doseWindowUncertainty,[0 40],'AbsTol',1e-12);
verifyEqual(testCase,analysis.doseWindowExpectedDoseDifference,[-40 40], ...
    'AbsTol',1e-12);
end

function testPrescriptionDefaultsUsePerFractionDose(testCase)
pln = struct('numOfFractions',20);
analysis = planWorkflow.config.Analysis.applyPrescriptionDefaults( ...
    struct('evaluationMode','perFraction'),80,pln);

verifyEqual(testCase,analysis.doseWindow,[0 5],'AbsTol',1e-12);
verifyEqual(testCase,analysis.doseWindowDvh,[0 6.4],'AbsTol',1e-12);
verifyEqual(testCase,analysis.doseWindowUncertainty,[0 2],'AbsTol',1e-12);
verifyEqual(testCase,analysis.doseWindowExpectedDoseDifference,[-2 2], ...
    'AbsTol',1e-12);
end
