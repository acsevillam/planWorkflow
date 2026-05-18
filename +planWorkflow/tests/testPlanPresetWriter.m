function tests = testPlanPresetWriter
tests = functiontests(localfunctions);
end

function testSaveWritesTemplateComponentsAndMacro(testCase)
fixture = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
templateRoot = fullfile(fixture.Folder,'templates');
macroFolder = fullfile(fixture.Folder,'macros');
runConfig = baseRunConfig(fixture.Folder);
runConfig.analysis.figures.sliceControl = true;
template = planWorkflow.templates.PlanTemplate.loadForDescription( ...
    'prostate','interval2_001');
template.prescriptionDose = 70;
beamIx = find(strcmp({template.beamSets.id},'9F'),1);
template.beamSets(beamIx).numOfFractions = 35;

result = planWorkflow.gui.PlanPresetWriter.save( ...
    template,runConfig,'v2','runProstateV2Workflow', ...
    'templateRoot',templateRoot,'macroFolder',macroFolder);

verifyTrue(testCase,isfolder(result.templateFolder));
verifyTrue(testCase,isfile(fullfile(result.templateFolder, ...
    'metadata.json')));
verifyTrue(testCase,isfile(fullfile(result.templateFolder, ...
    'beams.json')));
verifyTrue(testCase,isfile(fullfile(result.templateFolder, ...
    'objectives.json')));
verifyTrue(testCase,isfile(fullfile(result.templateFolder, ...
    'structures.json')));
verifyTrue(testCase,isfile(result.macroFile));

metadataText = fileread(fullfile(result.templateFolder, ...
    'metadata.json'));
objectivesText = fileread(fullfile(result.templateFolder, ...
    'objectives.json'));
verifyFalse(testCase,contains(metadataText,'prescriptionDose'));
verifyTrue(testCase,contains(objectivesText,'"prescriptionDose": 70'));

loaded = planWorkflow.templates.PlanTemplate.loadFromFolder( ...
    result.templateFolder,'v2');
verifyEqual(testCase,loaded.id,'v2');
verifyEqual(testCase,loaded.description,'prostate');
verifyEqual(testCase,loaded.prescriptionDose,70);
verifyEqual(testCase,loaded.beamSets(beamIx).numOfFractions,35);

macroText = fileread(result.macroFile);
verifyTrue(testCase,contains(macroText, ...
    'function runProstateV2Workflow(varargin)'));
verifyTrue(testCase,contains(macroText, ...
    "helperFolder = fullfile(macroRoot,'helpers');"));
verifyTrue(testCase,contains(macroText, ...
    "userDataRoot = fileparts(macroRoot);"));
verifyTrue(testCase,contains(macroText, ...
    "macroDefaults.caseID = '3482';"));
verifyFalse(testCase,contains(macroText, ...
    "macroDefaults.randomSeed"));
verifyTrue(testCase,contains(macroText, ...
    "workflowConfig.prepare.caseID = macroOptions.caseID;"));
verifyTrue(testCase,contains(macroText, ...
    "workflowConfig.rootPath = macroOptions.rootPath;"));
verifyTrue(testCase,contains(macroText, ...
    "workflowConfig.cacheRootPath = macroOptions.cacheRootPath;"));
verifyTrue(testCase,contains(macroText, ...
    "workflowConfig.prepare.plan_template = 'v2';"));
verifyTrue(testCase,contains(macroText, ...
    "workflowConfig.prepare.quantityOpt = 'physicalDose';"));
verifyTrue(testCase,contains(macroText, ...
    "workflowConfig.precompute.doseResolution = [3 3 3];"));
verifyTrue(testCase,contains(macroText, ...
    "workflowConfig.precompute.reference.scenario.mode = 'nomScen';"));
verifyTrue(testCase,contains(macroText, ...
    "workflowConfig.precompute.reference.label = '';"));
verifyFalse(testCase,contains(macroText, ...
    'workflowConfig.precompute.reference = struct'));
verifyTrue(testCase,contains(macroText, ...
    "workflowConfig.precompute.robustPlans.Interval2.label = 'Interval2';"));
verifyTrue(testCase,contains(macroText, ...
    "workflowConfig.precompute.robustPlans.Interval2.objectiveSetName = 'Interval2';"));
verifyFalse(testCase,contains(macroText, ...
    'workflowConfig.precompute.robustPlans.Interval2.strategy'));
verifyFalse(testCase,contains(macroText, ...
    'workflowConfig.precompute.robustPlans.Interval2.robustnessMode'));
verifyFalse(testCase,contains(macroText,'variantsWithPenalties'));
verifyTrue(testCase,contains(macroText, ...
    "workflowConfig.precompute.robustPlans.Interval2.variants.theta1 = 5;"));
verifyFalse(testCase,contains(macroText, ...
    'workflowConfig.precompute.robustPlans = struct'));
verifyFalse(testCase,contains(macroText, ...
    'workflowConfig.precompute.robustPlans(1) = struct'));
verifyFalse(testCase,contains(macroText,'strategyOptions'));
verifyFalse(testCase,contains(macroText,'optimization4D'));
verifyFalse(testCase,contains(macroText,'jsondecode('));
verifyFalse(testCase,contains(macroText, ...
    'workflowConfig.precompute.robust_scen_mode'));
verifyTrue(testCase,contains(macroText, ...
    "workflowConfig.pullDose.step1Target = {'CTV'};"));
verifyTrue(testCase,contains(macroText, ...
    "workflowConfig.pullDose.strategy = 'heuristicMultiObjective';"));
verifyFalse(testCase,contains(macroText,'scale_factor'));
verifyTrue(testCase,contains(macroText, ...
    "workflowConfig.sampling.sampling_scen_mode = 'impScen_permuted5';"));
verifyTrue(testCase,contains(macroText, ...
    "workflowConfig.analysis.figures.sliceControl = true;"));
verifyTrue(testCase,contains(macroText, ...
    "workflow.gui();"));
end

function testSavePreservesPenaltyArraysAndMacroSkipsInternalVariants(testCase)
fixture = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
templateRoot = fullfile(fixture.Folder,'templates');
macroFolder = fullfile(fixture.Folder,'macros');
runConfig = baseRunConfig(fixture.Folder);
template = planWorkflow.templates.PlanTemplate.loadForDescription( ...
    'prostate','interval2_001');
template = setRobustPenaltyVector(template,[10 30 100]);

result = planWorkflow.gui.PlanPresetWriter.save( ...
    template,runConfig,'penaltySweep','runPenaltySweepWorkflow', ...
    'templateRoot',templateRoot,'macroFolder',macroFolder);

writtenObjectives = jsondecode(fileread(fullfile( ...
    result.templateFolder,'objectives.json')));
robustSet = writtenObjectives.objectiveSets.robustPlans(1);
ctvIx = find(strcmp({robustSet.structureObjectives.name},'CTV'),1);
writtenPenalty = ...
    robustSet.structureObjectives(ctvIx).objectives(1).parameters.penalty;
verifyEqual(testCase,writtenPenalty(:)',[10 30 100]);

macroText = fileread(result.macroFile);
verifyFalse(testCase,contains(macroText,'variantsWithPenalties'));
verifyTrue(testCase,contains(macroText, ...
    "workflowConfig.precompute.robustPlans.Interval2.variants.theta1 = 5;"));
end

function testSaveMacroDoesNotWriteDerived4DOptimization(testCase)
fixture = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
macroFolder = fullfile(fixture.Folder,'macros');
runConfig = baseRunConfig(fixture.Folder);
runConfig.precompute.reference.scenario.ctActive = true;
runConfig.precompute.robustPlans.scenario.ctActive = true;

result = planWorkflow.gui.PlanPresetWriter.saveMacro( ...
    runConfig,'interval2_001','runProstate4DWorkflow', ...
    'macroFolder',macroFolder);

macroText = fileread(result.macroFile);
verifyTrue(testCase,contains(macroText, ...
    "workflowConfig.precompute.reference.scenario.ctActive = true;"));
verifyTrue(testCase,contains(macroText, ...
    "workflowConfig.precompute.robustPlans.Interval2.scenario.ctActive = true;"));
verifyFalse(testCase,contains(macroText,'optimization4D'));
end

function testSaveMacroValidatesCanonicalContractBeforeExport(testCase)
fixture = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
macroFolder = fullfile(fixture.Folder,'macros');
runConfig = baseRunConfig(fixture.Folder);
runConfig.precompute.robustPlans.strategy = 'INTERVAL2';

verifyError(testCase,@() planWorkflow.gui.PlanPresetWriter.saveMacro( ...
    runConfig,'interval2_001','runInvalidHiddenFieldWorkflow', ...
    'macroFolder',macroFolder), ...
	'planWorkflow:config:RobustPlanConfig:UnsupportedField');
end

function testSaveMacroValidatesClinicalEndpointsBeforeExport(testCase)
fixture = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
macroFolder = fullfile(fixture.Folder,'macros');
runConfig = baseRunConfig(fixture.Folder);
runConfig.analysis.endpoints = struct( ...
    'structureNames',{{'CTV'}}, ...
    'metric','Dmean', ...
    'kind','mean', ...
    'unit','Gy');

verifyError(testCase,@() planWorkflow.gui.PlanPresetWriter.saveMacro( ...
    runConfig,'interval2_001','runInvalidEndpointWorkflow', ...
    'macroFolder',macroFolder), ...
    'planWorkflow:analysis:ClinicalEndpointCatalog:MissingEndpointField');
end

function testSaveMacroRejectsRequiredEndpointMissingFromTemplate(testCase)
fixture = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
macroFolder = fullfile(fixture.Folder,'macros');
runConfig = baseRunConfig(fixture.Folder);
runConfig.analysis.endpoints = struct( ...
    'structureNames',{{'MISSING_OAR'}}, ...
    'metric','Dmean', ...
    'kind','mean', ...
    'goal','lowerIsBetter', ...
    'doseQuantity','physicalDose', ...
    'outputDoseMode','totalDose', ...
    'unit','Gy');

verifyError(testCase,@() planWorkflow.gui.PlanPresetWriter.saveMacro( ...
    runConfig,'interval2_001','runMissingEndpointStructureWorkflow', ...
    'macroFolder',macroFolder), ...
    ['planWorkflow:analysis:EndpointStructureContract:' ...
     'MissingRequiredStructure']);
end

function testSaveMacroAllowsOptionalEndpointMissingFromTemplate(testCase)
fixture = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
macroFolder = fullfile(fixture.Folder,'macros');
runConfig = baseRunConfig(fixture.Folder);
runConfig.analysis.endpoints = struct( ...
    'structureNames',{{'MISSING_OAR'}}, ...
    'metric','Dmean', ...
    'kind','mean', ...
    'goal','lowerIsBetter', ...
    'doseQuantity','physicalDose', ...
    'outputDoseMode','totalDose', ...
    'unit','Gy', ...
    'required',false);

result = planWorkflow.gui.PlanPresetWriter.saveMacro( ...
    runConfig,'interval2_001','runOptionalEndpointWorkflow', ...
    'macroFolder',macroFolder);

verifyTrue(testCase,isfile(result.macroFile));
end

function testSaveMacroRequiresLoadableTemplate(testCase)
fixture = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
macroFolder = fullfile(fixture.Folder,'macros');
templateRoot = fullfile(fixture.Folder,'templates');
runConfig = baseRunConfig(fixture.Folder);

verifyError(testCase,@() planWorkflow.gui.PlanPresetWriter.saveMacro( ...
    runConfig,'missing_template','runMissingTemplateWorkflow', ...
    'templateRoot',templateRoot,'macroFolder',macroFolder), ...
    'planWorkflow:gui:PlanPresetWriter:UnknownTemplate');
end

function testMacroOptionsSupportNameValueAndStructOnly(testCase)
defaults = struct('caseID','3482','rootPath','/tmp/userdata', ...
    'cacheRootPath','/tmp/userdata/output/cache');

options = planWorkflow.gui.PlanPresetWriter.parseMacroOptions( ...
    defaults,'caseID','4136','rootPath','/tmp/alt');
verifyEqual(testCase,options.caseID,'4136');
verifyEqual(testCase,options.rootPath,'/tmp/alt');
verifyEqual(testCase,options.cacheRootPath,'/tmp/alt/output/cache');

options = planWorkflow.gui.PlanPresetWriter.parseMacroOptions( ...
    defaults,struct('cacheRootPath','/tmp/cache'));
verifyEqual(testCase,options.caseID,'3482');
verifyEqual(testCase,options.rootPath,'/tmp/userdata');
verifyEqual(testCase,options.cacheRootPath,'/tmp/cache');

verifyError(testCase,@() planWorkflow.gui.PlanPresetWriter.parseMacroOptions( ...
    defaults,'4136','/tmp/rejected'), ...
    'planWorkflow:gui:PlanPresetWriter:InvalidMacroOptions');

verifyError(testCase,@() planWorkflow.gui.PlanPresetWriter.parseMacroOptions( ...
    defaults,'randomSeed',42), ...
    'planWorkflow:gui:PlanPresetWriter:InvalidMacroOptions');
end

function testMacroPreservesDistinctRandomSeeds(testCase)
fixture = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
runConfig = baseRunConfig(fixture.Folder);
runConfig.precompute.reference.scenario.randomSeed = 11;
runConfig.sampling_scen_mode = 'random';
runConfig.sampling_randomSeed = 44;

robustOne = robustPlanConfig();
robustOne.scenario.randomSeed = 22;
robustTwo = robustPlanConfig();
robustTwo.id = 'robust_2';
robustTwo.label = 'Robust 2';
robustTwo.objectiveSetName = 'robust_2';
robustTwo.scenario.randomSeed = 33;
robustTwo = planWorkflow.config.RobustPlanConfig.normalizePlan( ...
    robustTwo,2);
runConfig.precompute.robustPlans = [robustOne robustTwo];

macroText = planWorkflow.gui.PlanPresetWriter.macroText( ...
    'runSeedWorkflow',runConfig,'interval2_001');

verifyTrue(testCase,contains(macroText, ...
    "workflowConfig.precompute.reference.scenario.randomSeed = 11;"));
verifyTrue(testCase,contains(macroText, ...
    "workflowConfig.precompute.robustPlans.Interval2.scenario.randomSeed = 22;"));
verifyTrue(testCase,contains(macroText, ...
    "workflowConfig.precompute.robustPlans.robust_2.scenario.randomSeed = 33;"));
verifyTrue(testCase,contains(macroText, ...
    "workflowConfig.sampling.sampling_randomSeed = 44;"));
verifyFalse(testCase,contains(macroText,'macroOptions.randomSeed'));
end

function testMacroExportsCtScenarioProbabilitiesPerScenario(testCase)
fixture = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
runConfig = baseRunConfig(fixture.Folder);
runConfig.precompute.reference.scenario.ctActive = true;
runConfig.precompute.reference.scenario.ctScenProb = [0.25 0.75];
runConfig.precompute.robustPlans.scenario.ctScenProb = [0.1 0.9];
runConfig.sampling_ctScenProb = [0.6 0.4];

macroText = planWorkflow.gui.PlanPresetWriter.macroText( ...
    'runCtProbWorkflow',runConfig,'interval2_001');

verifyTrue(testCase,contains(macroText, ...
    "workflowConfig.precompute.reference.scenario.ctScenProb = [0.25 0.75];"));
verifyTrue(testCase,contains(macroText, ...
    "workflowConfig.precompute.robustPlans.Interval2.scenario.ctScenProb = [0.1 0.9];"));
verifyTrue(testCase,contains(macroText, ...
    "workflowConfig.sampling.sampling_ctScenProb = [0.6 0.4];"));
end

function testMacroExportsOnlyNonDefaultDosePrecomputeFields(testCase)
fixture = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
runConfig = baseRunConfig(fixture.Folder);
runConfig.precompute.robustPlans.dosePrecompute.useScenarioBatch = true;
runConfig.precompute.robustPlans.dosePrecompute.SecondPassStrategy = ...
    'recompute';

macroText = planWorkflow.gui.PlanPresetWriter.macroText( ...
    'runScenarioBatchWorkflow',runConfig,'interval2_001');

verifyTrue(testCase,contains(macroText, ...
    "workflowConfig.precompute.robustPlans.Interval2.dosePrecompute.useScenarioBatch = true;"));
verifyTrue(testCase,contains(macroText, ...
    "workflowConfig.precompute.robustPlans.Interval2.dosePrecompute.SecondPassStrategy = 'recompute';"));
verifyFalse(testCase,contains(macroText, ...
    'workflowConfig.precompute.robustPlans.Interval2.dosePrecompute.KeepCache'));
verifyFalse(testCase,contains(macroText, ...
    'workflowConfig.precompute.robustPlans.Interval2.dosePrecompute.CacheRoot'));
end

function testSaveRejectsExistingTemplateAndMacro(testCase)
fixture = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
templateRoot = fullfile(fixture.Folder,'templates');
macroFolder = fullfile(fixture.Folder,'macros');
runConfig = baseRunConfig(fixture.Folder);
template = planWorkflow.templates.PlanTemplate.loadForDescription( ...
    'prostate','interval2_001');

planWorkflow.gui.PlanPresetWriter.save( ...
    template,runConfig,'v2','runProstateV2Workflow', ...
    'templateRoot',templateRoot,'macroFolder',macroFolder);

verifyError(testCase,@() planWorkflow.gui.PlanPresetWriter.save( ...
    template,runConfig,'v2','runProstateV3Workflow', ...
    'templateRoot',templateRoot,'macroFolder',macroFolder), ...
    'planWorkflow:templates:PlanTemplate:TemplateExists');
verifyError(testCase,@() planWorkflow.gui.PlanPresetWriter.save( ...
    template,runConfig,'v3','runProstateV2Workflow', ...
    'templateRoot',templateRoot,'macroFolder',macroFolder), ...
    'planWorkflow:gui:PlanPresetWriter:MacroExists');
end

function testSaveRejectsDuplicateValues(testCase)
fixture = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
templateRoot = fullfile(fixture.Folder,'templates');
macroFolder = fullfile(fixture.Folder,'macros');
runConfig = baseRunConfig(fixture.Folder);
template = planWorkflow.templates.PlanTemplate.loadForDescription( ...
    'prostate','interval2_001');

planWorkflow.gui.PlanPresetWriter.save( ...
    template,runConfig,'v2','runProstateV2Workflow', ...
    'templateRoot',templateRoot,'macroFolder',macroFolder);

verifyError(testCase,@() planWorkflow.gui.PlanPresetWriter.save( ...
    template,runConfig,'v3','runProstateV3Workflow', ...
    'templateRoot',templateRoot,'macroFolder',macroFolder), ...
    'planWorkflow:gui:PlanPresetWriter:TemplateValuesExist');
verifyError(testCase,@() planWorkflow.gui.PlanPresetWriter.saveTemplate( ...
    template,runConfig,'v3', ...
    'templateRoot',templateRoot,'macroFolder',macroFolder), ...
    'planWorkflow:gui:PlanPresetWriter:TemplateValuesExist');
verifyError(testCase,@() planWorkflow.gui.PlanPresetWriter.saveMacro( ...
    runConfig,'v2','runProstateV2CopyWorkflow', ...
    'templateRoot',templateRoot,'macroFolder',macroFolder), ...
    'planWorkflow:gui:PlanPresetWriter:MacroValuesExist');
end

function testSaveTemplateAndMacroCanRunIndependently(testCase)
fixture = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
templateRoot = fullfile(fixture.Folder,'templates');
macroFolder = fullfile(fixture.Folder,'macros');
runConfig = baseRunConfig(fixture.Folder);
template = planWorkflow.templates.PlanTemplate.loadForDescription( ...
    'prostate','interval2_001');

templateResult = planWorkflow.gui.PlanPresetWriter.saveTemplate( ...
    template,runConfig,'v2', ...
    'templateRoot',templateRoot,'macroFolder',macroFolder);

verifyTrue(testCase,isfolder(templateResult.templateFolder));
verifyFalse(testCase,isfile(fullfile(macroFolder, ...
    'runProstateV2Workflow.m')));

macroResult = planWorkflow.gui.PlanPresetWriter.saveMacro( ...
    runConfig,'v2','runProstateV2Workflow', ...
    'templateRoot',templateRoot,'macroFolder',macroFolder);

verifyTrue(testCase,isfile(macroResult.macroFile));
macroText = fileread(macroResult.macroFile);
verifyTrue(testCase,contains(macroText, ...
    "workflowConfig.prepare.plan_template = 'v2';"));
end

function testExportNameStatusReportsExistingTemplateAndMacro(testCase)
fixture = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
templateRoot = fullfile(fixture.Folder,'templates');
macroFolder = fullfile(fixture.Folder,'macros');
runConfig = baseRunConfig(fixture.Folder);
template = planWorkflow.templates.PlanTemplate.loadForDescription( ...
    'prostate','interval2_001');

planWorkflow.gui.PlanPresetWriter.save( ...
    template,runConfig,'v2','runProstateV2Workflow', ...
    'templateRoot',templateRoot,'macroFolder',macroFolder);

status = planWorkflow.gui.PlanPresetWriter.exportNameStatus( ...
    template,runConfig,'v2','runProstateV2Workflow', ...
    'templateRoot',templateRoot,'macroFolder',macroFolder);
verifyFalse(testCase,status.valid);
verifyTrue(testCase,status.templateExists);
verifyTrue(testCase,status.macroExists);
verifyTrue(testCase,status.templateSameNameSameValues);
verifyTrue(testCase,status.macroSameNameSameValues);
verifyTrue(testCase,contains(status.templateMessage, ...
    'template with this name already exists with the same values'));
verifyTrue(testCase,contains(status.macroMessage, ...
    'macro with this name already exists with the same values'));
verifyEqual(testCase,status.templateSeverity,'error');
verifyEqual(testCase,status.macroSeverity,'error');

status = planWorkflow.gui.PlanPresetWriter.exportNameStatus( ...
    template,runConfig,'v3','runProstateV3Workflow', ...
    'templateRoot',templateRoot,'macroFolder',macroFolder);
verifyFalse(testCase,status.valid);
verifyFalse(testCase,status.templateExists);
verifyFalse(testCase,status.macroExists);
verifyFalse(testCase,status.canExportTemplate);
verifyFalse(testCase,status.canExportMacro);
verifyFalse(testCase,status.canExportBoth);
verifyEqual(testCase,status.templateSameValueIds,{'v2'});
verifyTrue(testCase,contains(status.templateMessage, ...
    'Same template values already exist as: v2'));
verifyEqual(testCase,status.templateSeverity,'error');
verifyTrue(testCase,contains(status.macroMessage, ...
    'Macro-only export requires an existing template name'));

changedTemplate = template;
changedTemplate.prescriptionDose = changedTemplate.prescriptionDose + 1;
status = planWorkflow.gui.PlanPresetWriter.exportNameStatus( ...
    changedTemplate,runConfig,'v3','runProstateV3Workflow', ...
    'templateRoot',templateRoot,'macroFolder',macroFolder);
verifyTrue(testCase,status.valid);
verifyTrue(testCase,status.canExportTemplate);
verifyFalse(testCase,status.canExportMacro);
verifyTrue(testCase,status.canExportBoth);
verifyEmpty(testCase,status.templateSameValueIds);
end

function testExportNameStatusReportsSameMacroValues(testCase)
fixture = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
templateRoot = fullfile(fixture.Folder,'templates');
macroFolder = fullfile(fixture.Folder,'macros');
runConfig = baseRunConfig(fixture.Folder);
template = planWorkflow.templates.PlanTemplate.loadForDescription( ...
    'prostate','interval2_001');

planWorkflow.gui.PlanPresetWriter.save( ...
    template,runConfig,'v2','runProstateV2Workflow', ...
    'templateRoot',templateRoot,'macroFolder',macroFolder);

status = planWorkflow.gui.PlanPresetWriter.exportNameStatus( ...
    template,runConfig,'v2','runProstateV2CopyWorkflow', ...
    'templateRoot',templateRoot,'macroFolder',macroFolder);

verifyFalse(testCase,status.valid);
verifyTrue(testCase,status.templateExists);
verifyFalse(testCase,status.macroExists);
verifyFalse(testCase,status.canExportMacro);
verifyEqual(testCase,status.macroSameValueNames, ...
    {'runProstateV2Workflow'});
verifyTrue(testCase,contains(status.macroMessage, ...
    'Same macro values already exist as: runProstateV2Workflow'));
verifyEqual(testCase,status.macroSeverity,'error');
end

function testExportNameStatusReportsInvalidNames(testCase)
fixture = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
runConfig = baseRunConfig(fixture.Folder);
template = planWorkflow.templates.PlanTemplate.loadForDescription( ...
    'prostate','interval2_001');

status = planWorkflow.gui.PlanPresetWriter.exportNameStatus( ...
    template,runConfig,'bad name','bad macro name', ...
    'templateRoot',fullfile(fixture.Folder,'templates'), ...
    'macroFolder',fullfile(fixture.Folder,'macros'));

verifyFalse(testCase,status.valid);
verifyTrue(testCase,contains(status.templateMessage, ...
    'Template name must start'));
verifyTrue(testCase,contains(status.macroMessage, ...
    'Macro name must be a valid MATLAB function name'));
end

function testInvalidPresetNamesAreRejected(testCase)
fixture = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
runConfig = baseRunConfig(fixture.Folder);
template = planWorkflow.templates.PlanTemplate.loadForDescription( ...
    'prostate','interval2_001');

verifyError(testCase,@() planWorkflow.gui.PlanPresetWriter.save( ...
    template,runConfig,'bad name','runValidWorkflow', ...
    'templateRoot',fullfile(fixture.Folder,'templates'), ...
    'macroFolder',fullfile(fixture.Folder,'macros')), ...
    'planWorkflow:gui:PlanPresetWriter:InvalidTemplateId');
verifyError(testCase,@() planWorkflow.gui.PlanPresetWriter.save( ...
    template,runConfig,'v2','bad macro name', ...
    'templateRoot',fullfile(fixture.Folder,'templates'), ...
    'macroFolder',fullfile(fixture.Folder,'macros')), ...
    'planWorkflow:gui:PlanPresetWriter:InvalidMacroName');
end

function testDefaultPresetNamesAreValid(testCase)
fixture = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
runConfig = baseRunConfig(fixture.Folder);

names = planWorkflow.gui.PlanPresetWriter.defaultPresetNames(runConfig);

verifyTrue(testCase,isvarname(names.macroName));
verifyNotEmpty(testCase,regexp(names.templateId, ...
    '^[A-Za-z][A-Za-z0-9_-]*$','once'));
end

function runConfig = baseRunConfig(rootPath)
runConfig = struct();
runConfig.radiationMode = 'photons';
runConfig.description = 'prostate';
runConfig.caseID = '3482';
runConfig.AcquisitionType = 'dicom';
runConfig.dicomMetadata = struct();
runConfig.hlutFileName = 'matRad_default.hlut';
runConfig.plan_template = 'interval2_001';
runConfig.machine = 'Generic';
runConfig.bioModel = 'none';
runConfig.quantityOpt = 'physicalDose';
runConfig.plan_beams = '9F';
runConfig.resolution = [3 3 3];
runConfig.runId = '';
runConfig.rootPath = rootPath;
runConfig.outputRootPath = fullfile(rootPath,'output');
runConfig.patientDataPath = fullfile(rootPath,'patients');
runConfig.cacheRootPath = fullfile(rootPath,'output','cache');

runConfig.doseResolution = [3 3 3];
runConfig.precompute = planWorkflow.config.RobustPlanConfig.defaults();
runConfig.precompute.robustPlans = robustPlanConfig();
runConfig.useCache = true;
runConfig.writeCache = true;

runConfig.dose_pulling1 = true;
runConfig.dose_pulling1_target = {'CTV'};
runConfig.dose_pulling1_criteria = {'COV1'};
runConfig.dose_pulling1_limit = 0.90;
runConfig.dose_pulling1_start = 10;
runConfig.dose_pulling2 = false;
runConfig.dose_pulling2_target = {'CTV'};
runConfig.dose_pulling2_criteria = 'meanQiTarget';
runConfig.dose_pulling2_limit = 0.80;
runConfig.dose_pulling2_start = 0;
runConfig.dose_pulling_max_iter = 100;
runConfig.dose_pulling_strategy = 'heuristicMultiObjective';
runConfig.dose_pulling_search_schedule = 'exponential';
runConfig.dose_pulling_local_window = 8;
runConfig.dose_pulling_patience = 3;
runConfig.dose_pulling_target_tol = 1e-3;
runConfig.dose_pulling_selection_policy = 'normalizedKnee';
runConfig.dose_pulling_target_weight = 1.0;
runConfig.dose_pulling_oar_weight = 1.0;
runConfig.dose_pulling_step_weight = 1e-6;
runConfig.dose_pulling_max_vmax_percent = 100;
runConfig.dose_pulling_use_warm_start = true;

runConfig.optimizer = 'IPOPT';
runConfig.sampling_linkToOptimization = true;
runConfig.sampling_caseID = '3482';
runConfig.sampling_AcquisitionType = 'dicom';
runConfig.sampling_dicomMetadata = struct();
runConfig.sampling_scen_mode = 'impScen_permuted5';
runConfig.sampling_ctActive = true;
runConfig.sampling_ctReferenceScenId = 1;
runConfig.sampling_ctScenProb = [];
runConfig.sampling_setupActive = true;
runConfig.sampling_rangeActive = false;
runConfig.sampling_gantryActive = false;
runConfig.sampling_couchActive = false;
runConfig.sampling_shiftSD = [5 10 5];
runConfig.sampling_wcSigma = 1.5;
runConfig.sampling_rangeAbsSD = 0;
runConfig.sampling_rangeRelSD = 0;
runConfig.sampling_numOfRangeGridPoints = 1;
runConfig.sampling_gantryAngleSD = 0;
runConfig.sampling_couchAngleSD = 0;
runConfig.sampling_size = 50;
runConfig.sampling_randomSeed = [];

runConfig.analysis = planWorkflow.config.Analysis.defaults();
runConfig.analysis.evaluationMode = 'total';
runConfig.analysis.robustnessTargetMode = 'include';
runConfig.analysis.robustnessTargets = {'CTV'};
end

function plan = robustPlanConfig()
plan = planWorkflow.config.RobustPlanConfig.defaultPlan();
plan.id = 'Interval2';
plan.label = 'Interval2';
plan.objectiveSetName = 'Interval2';
plan.variants = struct('id','theta_5','label','theta1=5', ...
    'theta1',5);
contract = planWorkflow.config.RobustPlanConfig.defaultRobustnessContract();
contract.robustnessMode = 'INTERVAL2';
contract.hasNominalObjectives = true;
contract.requiresNominalDij = true;
contract.requiresIntervalDij = true;
contract.requiresProbDij = false;
plan = planWorkflow.config.RobustPlanConfig.normalizePlan(plan,1,contract);
end

function template = setRobustPenaltyVector(template,penalties)
groups = template.objectiveSets.robustPlans(1).structureObjectives;
ctvIx = find(strcmp({groups.name},'CTV'),1);
objectives = groups(ctvIx).objectives;
if ~iscell(objectives)
    objectives = num2cell(objectives);
end
objective = objectives{1};
objective.parameters.penalty = penalties;
if isfield(objective,'dosePulling')
    objective = rmfield(objective,'dosePulling');
end
objectives{1} = objective;
groups(ctvIx).objectives = objectives;
template.objectiveSets.robustPlans(1).structureObjectives = groups;
end
