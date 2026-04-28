function tests = testAnalysisConfig
tests = functiontests(localfunctions);
end

function testNormalizeAddsDefaultsAndCanonicalDisplayDoseMode(testCase)
analysis = robOpt.config.Analysis.normalize(struct('displayDoseMode','perFraction'));

verifyEqual(testCase,analysis.displayDoseMode,'perFraction');
verifyEqual(testCase,analysis.gammaCriteria,[3 3]);
verifyEqual(testCase,analysis.robustnessCriteria,[5 5]);
verifyTrue(testCase,isfield(analysis,'doseWindowDvh'));
end

function testNormalizeRejectsUnsupportedFields(testCase)
verifyError(testCase, ...
    @() robOpt.config.Analysis.normalize(struct('sampling',true)), ...
    'robOpt:config:Analysis:UnsupportedField');
end

function testPrescriptionDefaultsUseTotalDose(testCase)
pln = struct('numOfFractions',20);
analysis = robOpt.config.Analysis.applyPrescriptionDefaults( ...
    struct('displayDoseMode','total'),80,pln);

verifyEqual(testCase,analysis.doseWindow,[0 100],'AbsTol',1e-12);
verifyEqual(testCase,analysis.doseWindowDvh,[0 128],'AbsTol',1e-12);
verifyEqual(testCase,analysis.doseWindowUncertainty,[0 40],'AbsTol',1e-12);
end

function testPrescriptionDefaultsUsePerFractionDose(testCase)
pln = struct('numOfFractions',20);
analysis = robOpt.config.Analysis.applyPrescriptionDefaults( ...
    struct('displayDoseMode','perFraction'),80,pln);

verifyEqual(testCase,analysis.doseWindow,[0 5],'AbsTol',1e-12);
verifyEqual(testCase,analysis.doseWindowDvh,[0 6.4],'AbsTol',1e-12);
verifyEqual(testCase,analysis.doseWindowUncertainty,[0 2],'AbsTol',1e-12);
end
