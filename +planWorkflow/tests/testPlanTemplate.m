function tests = testPlanTemplate
tests = functiontests(localfunctions);
end

function testUnknownTemplateIsRejected(testCase)
verifyError(testCase,@() ...
    planWorkflow.templates.PlanTemplate.loadForDescription( ...
    'prostate','does_not_exist'), ...
    'planWorkflow:templates:PlanTemplate:UnknownTemplate');
end

function testTemplateIdWithDescriptionIsRejected(testCase)
runConfig = baseRunConfig();
runConfig.plan_template = 'prostate/interval2_001';

verifyError(testCase,@() ...
    planWorkflow.templates.PlanTemplate.validateRunConfigSelection( ...
    runConfig),'planWorkflow:templates:PlanTemplate:InvalidTemplateId');
end

function testTemplateIsLoadedFromComponentFolder(testCase)
templateClassFile = which('planWorkflow.templates.PlanTemplate');
templateRoot = fullfile(fileparts(templateClassFile),'json');
templateFolder = fullfile(templateRoot,'prostate','interval2_001');
beamsFile = fullfile(templateRoot,'prostate','shared','beams_base.json');
referenceObjectivesFile = fullfile(templateRoot,'prostate','shared', ...
    'objectives_reference_base.json');
structuresFile = fullfile(templateRoot,'prostate','shared', ...
    'structures_base.json');

template = planWorkflow.templates.PlanTemplate.loadForDescription('prostate','interval2_001');

verifyTrue(testCase,ismember('prostate', ...
    planWorkflow.templates.PlanTemplate.availableDescriptions()));
verifyFalse(testCase,any(strcmp( ...
    planWorkflow.templates.PlanTemplate.availableTemplateIds('prostate'), ...
    'shared')));
verifyTrue(testCase,isfolder(templateFolder));
verifyTrue(testCase,isfolder(fullfile(templateRoot,'prostate','shared')));
verifyFalse(testCase,isfile(fullfile(templateRoot,'prostate/interval2_001.json')));
verifyTrue(testCase,isfile(fullfile(templateFolder,'metadata.json')));
verifyTrue(testCase,isfile(beamsFile));
verifyFalse(testCase,isfile(fullfile(templateFolder,'beams.json')));
verifyTrue(testCase,isfile(fullfile(templateFolder,'objectives.json')));
verifyTrue(testCase,isfile(structuresFile));
verifyFalse(testCase,isfile(fullfile(templateFolder,'structures.json')));
verifyFalse(testCase,isfile(fullfile(templateFolder,'rings.json')));
verifyFalse(testCase,contains(fileread(fullfile(templateFolder, ...
    'metadata.json')),'"prescriptionDose"'));
verifyFalse(testCase,contains(fileread(fullfile(templateFolder, ...
    'metadata.json')),'"radiationMode"'));
verifyTrue(testCase,contains(fileread(fullfile(templateFolder, ...
    'metadata.json')),'"components"'));
verifyTrue(testCase,contains(fileread(beamsFile),'"radiationModes"'));
verifyFalse(testCase,contains(fileread(beamsFile),'"radiationMode"'));
verifyFalse(testCase,contains(fileread(structuresFile),'"objectives"'));
verifyFalse(testCase,contains(fileread(structuresFile),'"primaryTarget"'));
verifyFalse(testCase,contains(fileread(structuresFile),'"targets"'));
verifyFalse(testCase,contains(fileread(structuresFile),'"targetOnly"'));
verifyFalse(testCase,contains(fileread(structuresFile),'"fallbackRole"'));
verifyFalse(testCase,contains(fileread(structuresFile),'"ptvUnion"'));
verifyFalse(testCase,contains(fileread(structuresFile),'"oarStructSel"'));
verifyTrue(testCase,contains(fileread(structuresFile),'"rings"'));
objectivesText = fileread(fullfile(templateFolder,'objectives.json'));
verifyTrue(testCase,contains(objectivesText,'"target"'));
verifyTrue(testCase,contains(objectivesText,'"prescriptionDose"'));
verifyTrue(testCase,contains(objectivesText,'"dosePulling"'));
verifyTrue(testCase,contains(objectivesText,'"objectiveSets"'));
verifyTrue(testCase,contains(objectivesText,'"ref"'));
verifyFalse(testCase,contains(objectivesText,'"enabled"'));
verifyFalse(testCase,contains(objectivesText,'"structureObjectives"'));
verifyFalse(testCase,contains(objectivesText,'"ringObjectives"'));
verifyTrue(testCase,contains(fileread(referenceObjectivesFile), ...
    '"structureObjectives"'));
verifyTrue(testCase,contains(fileread(referenceObjectivesFile), ...
    '"ringObjectives"'));
verifyFalse(testCase,contains(objectivesText,'"objectiveLevels"'));
verifyFalse(testCase,contains(objectivesText,'"objectiveLevelFactor"'));
verifyFalse(testCase,contains(objectivesText,'"kind"'));
verifyFalse(testCase,contains(objectivesText,'"terms"'));
verifyFalse(testCase,contains(objectivesText,'"dpStart"'));
verifyTrue(testCase,isfield(template,'beamSets'));
verifyTrue(testCase,isfield(template,'structures'));
verifyTrue(testCase,isfield(template,'rings'));
verifyTrue(testCase,isfield(template,'objectiveSets'));
verifyFalse(testCase,isfield(template.structures,'objectives'));
verifyFalse(testCase,isfield(template.rings,'objectives'));
end

function testReferenceOnlyTemplateIsValid(testCase)
template = planWorkflow.templates.PlanTemplate.loadForDescription( ...
    'prostate','interval2_001');
template.objectiveSets = rmfield(template.objectiveSets,'robustPlans');

planWorkflow.templates.PlanTemplate.validateTemplate(template,template.id);
verifyEmpty(testCase, ...
    planWorkflow.templates.PlanTemplate.robustObjectiveSets(template));
verifyEqual(testCase, ...
    planWorkflow.templates.PlanTemplate.objectiveSetNames(template), ...
    {'reference'});
end

function testSharedTemplateComponentsAreResolved(testCase)
templateClassFile = which('planWorkflow.templates.PlanTemplate');
templateRoot = fullfile(fileparts(templateClassFile),'json');
breastRoot = fullfile(templateRoot,'breast');
templateFolder = fullfile(breastRoot,'interval2_001');

templateIds = planWorkflow.templates.PlanTemplate.availableTemplateIds( ...
    'breast');
template = planWorkflow.templates.PlanTemplate.loadForDescription( ...
    'breast','interval2_001');

verifyTrue(testCase,isfolder(fullfile(breastRoot,'shared')));
verifyFalse(testCase,any(strcmp(templateIds,'shared')));
verifyTrue(testCase,contains(fileread(fullfile(templateFolder, ...
    'metadata.json')),'"components"'));
verifyFalse(testCase,isfile(fullfile(templateFolder,'beams.json')));
verifyFalse(testCase,isfile(fullfile(templateFolder,'structures.json')));
verifyTrue(testCase,isfile(fullfile(templateFolder,'objectives.json')));
verifyTrue(testCase,isfile(fullfile(breastRoot,'shared', ...
    'objectives_reference_base.json')));
verifyTrue(testCase,contains(fileread(fullfile(templateFolder, ...
    'objectives.json')),'"ref"'));
verifyEqual(testCase,template.prescriptionDose,42.56,'AbsTol',1e-12);
verifyEqual(testCase,template.primaryTarget,'CTV');
verifyEqual(testCase,template.objectiveSets.robustPlans(1).id, ...
    'Interval2');
verifyEqual(testCase,template.objectiveSets.robustPlans(1).label, ...
    'INTERVAL2');
verifyTrue(testCase,any(strcmp({template.structures.name},'RIGHT LUNG')));
verifyTrue(testCase,any(strcmp({template.structures.name}, ...
    'CONTRALATERAL BREAST')));
end

function testHeadAndNeckTemplatesUseSharedClinicalObjectives(testCase)
templateClassFile = which('planWorkflow.templates.PlanTemplate');
templateRoot = fullfile(fileparts(templateClassFile),'json');
templateFolder = fullfile(templateRoot,'h&n','interval2_001');

templateIds = planWorkflow.templates.PlanTemplate.availableTemplateIds('h&n');
template = planWorkflow.templates.PlanTemplate.loadForDescription( ...
    'h&n','interval2_001');

verifyTrue(testCase,ismember('h&n', ...
    planWorkflow.templates.PlanTemplate.availableDescriptions()));
verifyFalse(testCase,any(strcmp(templateIds,'shared')));
verifyTrue(testCase,isfile(fullfile(templateFolder,'objectives.json')));
verifyTrue(testCase,contains(fileread(fullfile(templateFolder, ...
    'objectives.json')),'"ref"'));
verifyEqual(testCase,template.prescriptionDose,50);
verifyEqual(testCase,template.primaryTarget,'CTV');
verifyTrue(testCase,any(strcmp({template.structures.name},'LEFT PAROTID')));
verifyTrue(testCase,any(strcmp({template.structures.name},'RIGHT PAROTID')));
verifyTrue(testCase,any(strcmp({template.structures.name},'SPINAL CORD')));
verifyTrue(testCase,any(strcmp({template.structures.name},'BRAINSTEM')));

referenceGroups = template.objectiveSets.reference.structureObjectives;
ctvIx = find(strcmp({referenceGroups.name},'CTV'),1);
ptvIx = find(strcmp({referenceGroups.name},'PTV'),1);
parotidIx = find(strcmp({referenceGroups.name},'LEFT PAROTID'),1);
cordIx = find(strcmp({referenceGroups.name},'SPINAL CORD'),1);
brainstemIx = find(strcmp({referenceGroups.name},'BRAINSTEM'),1);

verifyEqual(testCase, ...
    referenceGroups(ctvIx).objectives(1).parameters.vMinPercent,98);
verifyEqual(testCase, ...
    referenceGroups(ptvIx).objectives(1).parameters.vMinPercent,95);
verifyEqual(testCase, ...
    referenceGroups(parotidIx).objectives(1).type, ...
    'matRad_MeanDose');
verifyEqual(testCase, ...
    referenceGroups(parotidIx).objectives(1).parameters.dMeanRef,11);
verifyEqual(testCase, ...
    referenceGroups(cordIx).objectives(1).parameters.dRef,32);
verifyEqual(testCase, ...
    referenceGroups(brainstemIx).objectives(1).parameters.dRef,39);

robustGroups = template.objectiveSets.robustPlans(1).structureObjectives;
ctvIx = find(strcmp({robustGroups.name},'CTV'),1);
verifyEqual(testCase,robustGroups(ctvIx).objectives(1).type, ...
    'matRad_SquaredBertoluzzaDeviation');
verifyEqual(testCase, ...
    robustGroups(ctvIx).objectives(1).properties.robustness, ...
    'INTERVAL2');
end

function testHeadAndNeckSharedBeamsDeclareParticleRadiationModes(testCase)
template = planWorkflow.templates.PlanTemplate.loadForDescription( ...
    'h&n','interval2_001');

verifyEqual(testCase, ...
    planWorkflow.templates.PlanTemplate.radiationModeIds(template), ...
    {'photons','protons','helium','carbon'});
verifyEqual(testCase, ...
    planWorkflow.templates.PlanTemplate.defaultBeamSetForRadiationMode( ...
    template,'photons'),'7F');
verifyEqual(testCase, ...
    planWorkflow.templates.PlanTemplate.defaultBeamSetForRadiationMode( ...
    template,'carbon'),'2F');
verifyEqual(testCase, ...
    planWorkflow.templates.PlanTemplate.defaultMachineForRadiationMode( ...
    template,'carbon'),'Generic');
verifyEqual(testCase, ...
    planWorkflow.templates.PlanTemplate.defaultBioModelForRadiationMode( ...
    template,'carbon'),'LEM');

beamIx = find(strcmp({template.beamSets.id},'2F'),1);
verifyNotEmpty(testCase,beamIx);
verifyEqual(testCase,template.beamSets(beamIx).gantryAngles(:)',[90 270]);
verifyEqual(testCase,template.beamSets(beamIx).numOfFractions,25);
end

function testProstateTemplateDefinesVisibleColors(testCase)
template = planWorkflow.templates.PlanTemplate.loadForDescription( ...
    'prostate','interval2_001');
structureNames = {template.structures.name};

verifyEqual(testCase, ...
    template.structures(strcmp(structureNames,'BODY')).visibleColor(:)', ...
    [0 1 0]);
verifyEqual(testCase, ...
    template.structures(strcmp(structureNames,'CTV')).visibleColor(:)', ...
    [1 0 0]);
verifyEqual(testCase, ...
    template.structures(strcmp(structureNames,'PTV')).visibleColor(:)', ...
    [0 0.816 1],'AbsTol',1e-12);
verifyEqual(testCase, ...
    template.structures(strcmp(structureNames,'BLADDER')).visibleColor(:)', ...
    [1 1 0]);
verifyEqual(testCase, ...
    template.structures(strcmp(structureNames,'RECTUM')).visibleColor(:)', ...
    [0.502 0.251 0.251], ...
    'AbsTol',1e-12);
end

function testInvalidJsonIsRejected(testCase)
fixture = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
templateFolder = fullfile(fixture.Folder,'invalid_template');
mkdir(templateFolder);
templateFile = fullfile(templateFolder,'metadata.json');
fid = fopen(templateFile,'w');
fprintf(fid,'{invalid json');
fclose(fid);

verifyError(testCase,@() planWorkflow.templates.PlanTemplate.loadFromFolder( ...
    templateFolder,'invalid'),'planWorkflow:templates:PlanTemplate:InvalidJson');
end

function testNonStandardStructureFlagsAreRejected(testCase)
templateFolder = copyTemplateFixture(testCase);
structuresFile = sharedStructuresFile(templateFolder);
structures = jsondecode(fileread(structuresFile));
structures.structures(1).targetOnly = false;
structures.structures(1).fallbackRole = '';
writeJson(structuresFile,structures);

verifyError(testCase,@() planWorkflow.templates.PlanTemplate.loadFromFolder( ...
    templateFolder,'interval2_001'), ...
    'planWorkflow:templates:PlanTemplate:UnsupportedField');
end

function testUnsupportedBeamSetIsRejected(testCase)
runConfig = baseRunConfig();
runConfig.plan_beams = '13F';

verifyError(testCase,@() planWorkflow.templates.PlanTemplate.validateRunConfigSelection( ...
    runConfig),'planWorkflow:templates:PlanTemplate:UnknownBeamSet');
end

function testRadiationModeIsValidatedAgainstTemplateSet(testCase)
runConfig = baseRunConfig();
runConfig.radiationMode = 'carbon';

planWorkflow.templates.PlanTemplate.validateRunConfigSelection(runConfig);

runConfig.radiationMode = 'electrons';
verifyError(testCase,@() ...
    planWorkflow.templates.PlanTemplate.validateRunConfigSelection( ...
    runConfig),'planWorkflow:templates:PlanTemplate:RadiationModeMismatch');
end

function testUnsupportedObjectiveTargetIsRejected(testCase)
templateFolder = copyTemplateFixture(testCase);
objectivesFile = fullfile(templateFolder,'objectives.json');
objectives = jsondecode(fileread(objectivesFile));
objectives.target = 'GTV';
writeJson(objectivesFile,objectives);

verifyError(testCase,@() planWorkflow.templates.PlanTemplate.loadFromFolder( ...
    templateFolder,'interval2_001'), ...
    'planWorkflow:templates:PlanTemplate:UnknownTarget');
end

function testTemplateJsonCanDefineBooleanStructures(testCase)
templateFolder = copyTemplateFixture(testCase);
structuresFile = sharedStructuresFile(templateFolder);
structures = jsondecode(fileread(structuresFile));
structures.structures = addStructureOperationField(structures.structures);
derivedStructure = structures.structures(1);
derivedStructure.name = 'PTV_MINUS_CTV';
derivedStructure.role = 'OAR';
derivedStructure.priority = 4;
derivedStructure.operation = 'PTV-CTV';
structures.structures(end + 1) = derivedStructure;
writeJson(structuresFile,structures);

objectivesFile = fullfile(templateFolder,'objectives.json');
objectives = jsondecode(fileread(objectivesFile));
derivedObjectives = objectives.objectiveSets.reference.structureObjectives(1);
derivedObjectives.name = 'PTV_MINUS_CTV';
derivedObjectives.objectives = {};
objectives.objectiveSets = appendObjectiveGroupToSets( ...
    objectives.objectiveSets,'structureObjectives',derivedObjectives);
writeJson(objectivesFile,objectives);

template = planWorkflow.templates.PlanTemplate.loadFromFolder( ...
    templateFolder,'interval2_001');

structureIx = find(strcmp({template.structures.name},'PTV_MINUS_CTV'));
verifyEqual(testCase,template.structures(structureIx).operation, ...
    'PTV-CTV');
end

function testProstateNineFieldBeamSetIsApplied(testCase)
runConfig = baseRunConfig();
ct = makeCt([7 7 7]);
cst = makeProstateCst(ct.cubeDim);
pln = struct();

pln = planWorkflow.templates.PlanTemplate.applyBeams( ...
    runConfig,pln,ct,cst);

verifyEqual(testCase,pln.numOfFractions,39);
verifyEqual(testCase,pln.propStf.gantryAngles,0:40:320);
verifyEqual(testCase,pln.propStf.couchAngles,zeros(1,9));
verifyEqual(testCase,pln.propStf.bixelWidth,5);
verifyEqual(testCase,pln.propStf.numOfBeams,9);
verifySize(testCase,pln.propStf.isoCenter,[9 3]);
end

function testProstateSharedBeamsDeclareParticleRadiationModes(testCase)
template = planWorkflow.templates.PlanTemplate.loadForDescription( ...
    'prostate','interval2_001');

verifyEqual(testCase,template.radiationModes, ...
    struct( ...
    'id',{'photons'; 'protons'; 'helium'; 'carbon'}, ...
    'defaultBeamSet',{'9F'; '2F'; '2F'; '2F'}, ...
    'machine',{'Generic'; 'Generic'; 'Generic'; 'Generic'}, ...
    'bioModel',{'none'; 'constRBE'; 'HEL'; 'LEM'}));
verifyEqual(testCase, ...
    planWorkflow.templates.PlanTemplate.radiationModeIds(template), ...
    {'photons','protons','helium','carbon'});
verifyEqual(testCase, ...
    planWorkflow.templates.PlanTemplate.defaultBeamSetForRadiationMode( ...
    template,'carbon'),'2F');
verifyEqual(testCase, ...
    planWorkflow.templates.PlanTemplate.defaultMachineForRadiationMode( ...
    template,'carbon'),'Generic');
verifyEqual(testCase, ...
    planWorkflow.templates.PlanTemplate.defaultBioModelForRadiationMode( ...
    template,'carbon'),'LEM');

beamIx = find(strcmp({template.beamSets.id},'2F'),1);
verifyNotEmpty(testCase,beamIx);
verifyEqual(testCase,template.beamSets(beamIx).gantryAngles(:)',[90 270]);
verifyEqual(testCase,template.beamSets(beamIx).couchAngles(:)',[0 0]);
end

function testPtvTemplateUsesSharedProstateBeams(testCase)
template = planWorkflow.templates.PlanTemplate.loadForDescription( ...
    'prostate','PTV_001');

verifyEqual(testCase, ...
    planWorkflow.templates.PlanTemplate.radiationModeIds(template), ...
    {'photons','protons','helium','carbon'});
verifyFalse(testCase,isfield(template.beamSets,'radiationMode'));
end

function testInterval2TemplateCreatesParticleSpecificPlans(testCase)
cases = particlePlanCases();
ct = makeCt([7 7 7]);
cst = makeProstateCst(ct.cubeDim);

for i = 1:size(cases,1)
    template = planWorkflow.templates.PlanTemplate.loadForDescription( ...
        'prostate','interval2_001');
    runConfig = particleRunConfig(cases{i,1});

    [pln,quantityOpt] = planWorkflow.plan.Plan.create( ...
        runConfig,ct,cst,template);

    verifyEqual(testCase,pln.radiationMode,cases{i,1});
    verifyEqual(testCase,pln.propDoseCalc.engine,'HongPB');
    verifyEqual(testCase,quantityOpt,'RBExD');
    verifyEqual(testCase,pln.bioParam.model,cases{i,2});
    verifyEqual(testCase,pln.machine,'Generic');
    verifyEqual(testCase,pln.propDoseCalc.calcLET,cases{i,3});
    verifyEqual(testCase,pln.propStf.numOfBeams,2);
    verifyEqual(testCase,pln.propStf.gantryAngles,[90 270]);
end
end

function testProstateObjectivesAreAppliedFromTemplate(testCase)
runConfig = baseRunConfig();
runConfig.dose_pulling1 = true;
runConfig.dose_pulling1_start = 10;
cst = makeProstateCst([7 7 7]);

[cst,objectiveInfo] = planWorkflow.templates.PlanTemplate.applyObjectives( ...
    runConfig,[],cst);

verifyEqual(testCase,objectiveInfo.templateId,'interval2_001');
verifyEqual(testCase,objectiveInfo.beamSetId,'9F');
verifyEqual(testCase,objectiveInfo.targetName,'CTV');
verifyEqual(testCase,objectiveInfo.prescriptionDose,78);
verifyEqual(testCase,objectiveInfo.robustOarNames, ...
    {'BLADDER','RECTUM'});
verifyEqual(testCase,cst{objectiveInfo.ixBody,5}.Priority,5);
verifyEqual(testCase,cst{objectiveInfo.ixTarget,3},'TARGET');
verifyEqual(testCase,cst{objectiveInfo.ixTarget,5}.Priority,1);
verifyFalse(testCase,cst{objectiveInfo.ixTarget,6}{1}.dosePulling);
verifyEqual(testCase,cst{objectiveInfo.ixTarget,6}{1}.penalty,30);
verifyEqual(testCase,cst{objectiveInfo.ixTarget,6}{1}.parameters{1},78);
verifyEqual(testCase,cst{objectiveInfo.ixTarget,6}{2}.parameters{1},78);

ixBladder = strcmp(cst(:,2),'BLADDER');
ixRectum = strcmp(cst(:,2),'RECTUM');
verifyEqual(testCase,cst{ixBladder,5}.Priority,3);
verifyEqual(testCase,cst{ixBladder,6}{1}.parameters{2},3.75);
verifyEqual(testCase,cst{ixRectum,6}{1}.parameters{2},5);
verifyEqual(testCase,cst{strcmp(cst(:,2),'PTV'),3},'TARGET');
verifyEmpty(testCase,cst{strcmp(cst(:,2),'PTV'),6});
end

function testDisabledObjectivesAreSkipped(testCase)
runConfig = baseRunConfig();
template = planWorkflow.templates.PlanTemplate.loadForDescription( ...
    'prostate','interval2_001');
objectiveSet = planWorkflow.templates.PlanTemplate.objectiveSet( ...
    template,'reference');
ctvIx = find(strcmp({objectiveSet.structureObjectives.name},'CTV'),1);
objective = objectiveFromGroup( ...
    template.objectiveSets.reference.structureObjectives(ctvIx),1);
objective.enabled = false;
template.objectiveSets.reference.structureObjectives(ctvIx) = ...
    setObjectiveInGroup( ...
    template.objectiveSets.reference.structureObjectives(ctvIx), ...
    1,objective);
cst = makeProstateCst([7 7 7]);

[cst,objectiveInfo] = planWorkflow.templates.PlanTemplate.applyObjectives( ...
    runConfig,[],cst,template);

verifyNumElements(testCase,cst{objectiveInfo.ixTarget,6},3);
verifyEqual(testCase,cst{objectiveInfo.ixTarget,6}{1}.className, ...
    'DoseObjectives.matRad_SquaredDeviation');
verifyFalse(testCase,cst{objectiveInfo.ixTarget,6}{1}.dosePulling);
end

function testBooleanStructuresAreAppliedFromTemplate(testCase)
runConfig = baseRunConfig();
template = planWorkflow.templates.PlanTemplate.loadForDescription( ...
    'prostate','interval2_001');
template.structures = addStructureOperationField(template.structures);
derivedStructure = template.structures(1);
derivedStructure.name = 'PTV_MINUS_CTV';
derivedStructure.role = 'OAR';
derivedStructure.priority = 4;
derivedStructure.operation = 'PTV-CTV';
template.structures(end + 1) = derivedStructure;
template.objectiveSets = appendEmptyObjectiveGroupToSets( ...
    template.objectiveSets,'structureObjectives','PTV_MINUS_CTV');
cst = makeProstateCst([7 7 7]);

cst = planWorkflow.templates.PlanTemplate.applyObjectives( ...
    runConfig,[],cst,template);

ixDerived = strcmp(cst(:,2),'PTV_MINUS_CTV');
expectedVoxels = setdiff(cst{strcmp(cst(:,2),'PTV'),4}{1}, ...
    cst{strcmp(cst(:,2),'CTV'),4}{1});
verifyEqual(testCase,cst{ixDerived,4}{1},expectedVoxels);
verifyEqual(testCase,cst{ixDerived,3},'OAR');
verifyEqual(testCase,cst{ixDerived,5}.Priority,4);
end

function testBooleanStructuresCanUseUnion(testCase)
runConfig = baseRunConfig();
template = planWorkflow.templates.PlanTemplate.loadForDescription( ...
    'prostate','interval2_001');
template.structures = addStructureOperationField(template.structures);
derivedStructure = template.structures(1);
derivedStructure.name = 'CTV_PLUS_PTV';
derivedStructure.role = 'TARGET';
derivedStructure.priority = 2;
derivedStructure.operation = 'CTV+PTV';
template.structures(end + 1) = derivedStructure;
template.objectiveSets = appendEmptyObjectiveGroupToSets( ...
    template.objectiveSets,'structureObjectives','CTV_PLUS_PTV');
cst = makeProstateCst([7 7 7]);

cst = planWorkflow.templates.PlanTemplate.applyObjectives( ...
    runConfig,[],cst,template);

ixDerived = strcmp(cst(:,2),'CTV_PLUS_PTV');
expectedVoxels = union(cst{strcmp(cst(:,2),'CTV'),4}{1}, ...
    cst{strcmp(cst(:,2),'PTV'),4}{1});
verifyEqual(testCase,cst{ixDerived,4}{1},expectedVoxels);
verifyEqual(testCase,cst{ixDerived,3},'TARGET');
end

function testBooleanStructureMissingOperandIsRejected(testCase)
runConfig = baseRunConfig();
template = planWorkflow.templates.PlanTemplate.loadForDescription( ...
    'prostate','interval2_001');
template.structures = addStructureOperationField(template.structures);
derivedStructure = template.structures(1);
derivedStructure.name = 'INVALID_DERIVED';
derivedStructure.role = 'OAR';
derivedStructure.priority = 4;
derivedStructure.operation = 'PTV-MISSING';
template.structures(end + 1) = derivedStructure;
template.objectiveSets = appendEmptyObjectiveGroupToSets( ...
    template.objectiveSets,'structureObjectives','INVALID_DERIVED');
cst = makeProstateCst([7 7 7]);

verifyError(testCase,@() ...
    planWorkflow.templates.PlanTemplate.applyObjectives( ...
    runConfig,[],cst,template), ...
    'planWorkflow:templates:PlanTemplate:MissingBooleanOperand');
end

function testDosePullingStartValuesAreAppliedFromChannels(testCase)
runConfig = baseRunConfig();
runConfig.dose_pulling1 = true;
runConfig.dose_pulling2 = true;
runConfig.dose_pulling1_start = 4;
runConfig.dose_pulling2_start = 2;
cst = makeProstateCst([7 7 7]);

[cst,objectiveInfo] = planWorkflow.templates.PlanTemplate.applyObjectives( ...
    runConfig,[],cst);

ixBladder = find(strcmp(cst(:,2),'BLADDER'));
verifyFalse(testCase,cst{objectiveInfo.ixTarget,6}{1}.dosePulling);
verifyEqual(testCase,cst{objectiveInfo.ixTarget,6}{1}.penalty,30);
verifyEqual(testCase,cst{ixBladder,6}{1}.parameters{2},1.5);
verifyEqual(testCase,cst{ixBladder,6}{1}.objectivePullingRate{2},0.375);
end

function testDisabledDosePullingChannelsDoNotRequireHiddenStartFields(testCase)
runConfig = baseRunConfig();
runConfig.dose_pulling1 = false;
runConfig.dose_pulling2 = false;
runConfig = rmfield(runConfig,{'dose_pulling1_start','dose_pulling2_start'});
template = planWorkflow.templates.PlanTemplate.loadForDescription( ...
    'prostate','interval2_001');
cst = makeProstateCst([7 7 7]);

verifyWarningFree(testCase,@() ...
    planWorkflow.templates.PlanTemplate.validateEffectiveTemplate( ...
    template,runConfig));

[cst,objectiveInfo] = planWorkflow.templates.PlanTemplate.applyObjectives( ...
    runConfig,[],cst,template);
ixBladder = find(strcmp(cst(:,2),'BLADDER'),1);
verifyFalse(testCase,cst{objectiveInfo.ixTarget,6}{1}.dosePulling);
verifyFalse(testCase,cst{ixBladder,6}{1}.dosePulling);
end

function testUnknownDosePullingChannelIsRejected(testCase)
templateFolder = copyTemplateFixture(testCase);
objectivesFile = fullfile(templateFolder,'objectives.json');
objectives = jsondecode(fileread(objectivesFile));
objective = objectiveFromGroup( ...
    objectives.objectiveSets.reference.structureObjectives(4),1);
objective.dosePulling.channel = 'missing_channel';
objectives.objectiveSets.reference.structureObjectives(4) = ...
    setObjectiveInGroup( ...
    objectives.objectiveSets.reference.structureObjectives(4), ...
    1,objective);
writeJson(objectivesFile,objectives);

verifyError(testCase,@() planWorkflow.templates.PlanTemplate.loadFromFolder( ...
    templateFolder,'interval2_001'), ...
    'planWorkflow:templates:PlanTemplate:UnknownDosePullingChannel');
end

function testInvalidObjectiveParameterNameIsRejected(testCase)
templateFolder = copyTemplateFixture(testCase);
objectivesFile = fullfile(templateFolder,'objectives.json');
objectives = jsondecode(fileread(objectivesFile));
objective = objectiveFromGroup( ...
    objectives.objectiveSets.reference.structureObjectives(2),1);
objective.parameters.badParameter = 1;
objectives.objectiveSets.reference.structureObjectives(2) = ...
    setObjectiveInGroup( ...
    objectives.objectiveSets.reference.structureObjectives(2), ...
    1,objective);
writeJson(objectivesFile,objectives);

verifyError(testCase,@() planWorkflow.templates.PlanTemplate.loadFromFolder( ...
    templateFolder,'interval2_001'), ...
    'planWorkflow:templates:PlanTemplate:UnsupportedField');
end

function testMissingObjectiveEnabledIsRejected(testCase)
templateFolder = copyTemplateFixture(testCase);
objectivesFile = fullfile(templateFolder,'objectives.json');
objectives = jsondecode(fileread(objectivesFile));
objective = objectiveFromGroup( ...
    objectives.objectiveSets.reference.structureObjectives(2),1);
objective = rmfield(objective,'enabled');
objectives.objectiveSets.reference.structureObjectives(2) = ...
    setObjectiveInGroup( ...
    objectives.objectiveSets.reference.structureObjectives(2), ...
    1,objective);
writeJson(objectivesFile,objectives);

verifyError(testCase,@() planWorkflow.templates.PlanTemplate.loadFromFolder( ...
    templateFolder,'interval2_001'), ...
    'planWorkflow:templates:PlanTemplate:MissingField');
end

function testInvalidObjectiveEnabledIsRejected(testCase)
templateFolder = copyTemplateFixture(testCase);
objectivesFile = fullfile(templateFolder,'objectives.json');
objectives = jsondecode(fileread(objectivesFile));
objective = objectiveFromGroup( ...
    objectives.objectiveSets.reference.structureObjectives(2),1);
objective.enabled = 1;
objectives.objectiveSets.reference.structureObjectives(2) = ...
    setObjectiveInGroup( ...
    objectives.objectiveSets.reference.structureObjectives(2), ...
    1,objective);
writeJson(objectivesFile,objectives);

verifyError(testCase,@() planWorkflow.templates.PlanTemplate.loadFromFolder( ...
    templateFolder,'interval2_001'), ...
    'planWorkflow:templates:PlanTemplate:InvalidLogicalValue');
end

function testSupportedObjectiveRobustnessValuesMatchMatRad(testCase)
verifyEqual(testCase, ...
    planWorkflow.templates.PlanTemplate.supportedObjectiveRobustnessValues(), ...
    planWorkflow.matRadCapabilitiesReader.supportedObjectiveRobustnessValues());
verifyTrue(testCase,any(strcmp( ...
    planWorkflow.templates.PlanTemplate.supportedObjectiveTypes(), ...
    'matRad_SquaredBertoluzzaDeviation')));
end

function testObjectiveRobustnessValuesAreClassSpecific(testCase)
verifyEqual(testCase, ...
    planWorkflow.templates.PlanTemplate.supportedObjectiveRobustnessValuesForType( ...
    'matRad_SquaredBertoluzzaDeviation'), ...
    DoseObjectives.matRad_SquaredBertoluzzaDeviation.availableRobustness());
end

function testUnsupportedObjectiveRobustnessIsRejected(testCase)
templateFolder = copyTemplateFixture(testCase);
objectivesFile = fullfile(templateFolder,'objectives.json');
objectives = jsondecode(fileread(objectivesFile));
objective = objectiveFromGroup( ...
    objectives.objectiveSets.reference.structureObjectives(2),1);
objective.properties.robustness = 'invalid_robustness';
objectives.objectiveSets.reference.structureObjectives(2) = ...
    setObjectiveInGroup( ...
    objectives.objectiveSets.reference.structureObjectives(2), ...
    1,objective);
writeJson(objectivesFile,objectives);

verifyError(testCase,@() planWorkflow.templates.PlanTemplate.loadFromFolder( ...
    templateFolder,'interval2_001'), ...
    'planWorkflow:templates:PlanTemplate:UnsupportedRobustness');
end

function testObjectiveSpecificRobustnessIsRejected(testCase)
templateFolder = copyTemplateFixture(testCase);
objectivesFile = fullfile(templateFolder,'objectives.json');
objectives = jsondecode(fileread(objectivesFile));
objective = objectiveFromGroup( ...
    objectives.objectiveSets.reference.structureObjectives(2),1);
objective.type = 'matRad_SquaredBertoluzzaDeviation';
objective.parameters = struct('penalty',10,'dRef', ...
    struct('ref','prescriptionDose'));
objective.properties.robustness = 'COWC';
objectives.objectiveSets.reference.structureObjectives(2) = ...
    setObjectiveInGroup( ...
    objectives.objectiveSets.reference.structureObjectives(2), ...
    1,objective);
writeJson(objectivesFile,objectives);

verifyError(testCase,@() planWorkflow.templates.PlanTemplate.loadFromFolder( ...
    templateFolder,'interval2_001'), ...
    'planWorkflow:templates:PlanTemplate:UnsupportedRobustness');
end

function testBertoluzzaObjectiveCanBeBuiltFromTemplate(testCase)
templateFolder = copyTemplateFixture(testCase);
objectivesFile = fullfile(templateFolder,'objectives.json');
objectives = jsondecode(fileread(objectivesFile));
objective = objectiveFromGroup( ...
    objectives.objectiveSets.robustPlans(1).structureObjectives(2),1);
objective.type = 'matRad_SquaredBertoluzzaDeviation';
objective.parameters = struct('penalty',10,'dRef', ...
    struct('ref','prescriptionDose'));
objective.properties.robustness = 'INTERVAL3';
if isfield(objective,'dosePulling')
    objective = rmfield(objective,'dosePulling');
end
objectives.objectiveSets.robustPlans(1).structureObjectives(2).objectives = {objective};
writeJson(objectivesFile,objectives);

template = planWorkflow.templates.PlanTemplate.loadFromFolder( ...
    templateFolder,'interval2_001');
runConfig = baseRunConfig();
cst = makeProstateCst([7 7 7]);

[cst,objectiveInfo] = planWorkflow.templates.PlanTemplate.applyObjectives( ...
    runConfig,[],cst,template,'Interval2');

verifyEqual(testCase,cst{objectiveInfo.ixTarget,6}{1}.className, ...
    'DoseObjectives.matRad_SquaredBertoluzzaDeviation');
verifyEqual(testCase,cst{objectiveInfo.ixTarget,6}{1}.robustness, ...
    'INTERVAL3');
end

function testRobustPenaltyVectorIsAcceptedAndMaterialized(testCase)
template = penaltyVariantTemplate([10 30]);

planWorkflow.templates.PlanTemplate.validateTemplate(template,template.id);

objectiveSet = planWorkflow.templates.PlanTemplate.objectiveSet( ...
    template,'Interval2');
variants = planWorkflow.templates.ObjectivePenaltyVariants.variantsWithPenalties( ...
    objectiveSet, ...
    planWorkflow.config.RobustPlanConfig.defaultVariants('INTERVAL2'), ...
    'INTERVAL2');
verifyNumElements(testCase,variants,2);

runConfig = baseRunConfig();
cst = makeProstateCst([7 7 7]);
[cst,objectiveInfo] = planWorkflow.templates.PlanTemplate.applyObjectives( ...
    runConfig,[],cst,template,'Interval2');
verifyEqual(testCase,cst{objectiveInfo.ixTarget,6}{1}.penalty,10);

cst = makeProstateCst([7 7 7]);
[cst,objectiveInfo] = planWorkflow.templates.PlanTemplate.applyObjectives( ...
    runConfig,[],cst,template,'Interval2',variants(2));
verifyEqual(testCase,cst{objectiveInfo.ixTarget,6}{1}.penalty,30);
end

function testPenaltyVectorInReferenceIsRejected(testCase)
template = planWorkflow.templates.PlanTemplate.loadForDescription( ...
    'prostate','interval2_001');
template.objectiveSets.reference = setObjectiveParameter( ...
    template.objectiveSets.reference,'structureObjectives','CTV', ...
    1,'penalty',[10 30]);

verifyError(testCase,@() ...
    planWorkflow.templates.PlanTemplate.validateTemplate( ...
    template,template.id), ...
    'planWorkflow:templates:PlanTemplate:InvalidNumericValue');
end

function testNonPenaltyVectorInRobustObjectiveIsRejected(testCase)
template = planWorkflow.templates.PlanTemplate.loadForDescription( ...
    'prostate','interval2_001');
template.objectiveSets.robustPlans(1) = setObjectiveParameter( ...
    template.objectiveSets.robustPlans(1),'structureObjectives', ...
    'BLADDER',1,'dRef',[60 65]);

verifyError(testCase,@() ...
    planWorkflow.templates.PlanTemplate.validateTemplate( ...
    template,template.id), ...
    'planWorkflow:templates:PlanTemplate:InvalidNumericValue');
end

function testPenaltyVectorWithDosePulling2IsRejected(testCase)
template = planWorkflow.templates.PlanTemplate.loadForDescription( ...
    'prostate','interval2_001');
template.objectiveSets.robustPlans(1) = setObjectiveParameter( ...
    template.objectiveSets.robustPlans(1),'structureObjectives', ...
    'CTV',1,'penalty',[10 30]);

verifyError(testCase,@() ...
    planWorkflow.templates.PlanTemplate.validateTemplate( ...
    template,template.id), ...
    'planWorkflow:templates:PlanTemplate:PenaltyVectorDosePulling2');
end

function testPenaltyVariantsExpandInDeterministicCartesianOrder(testCase)
template = penaltyVariantTemplate([10 30],[100 200]);
objectiveSet = planWorkflow.templates.PlanTemplate.objectiveSet( ...
    template,'Interval2');
baseVariants = [ ...
    struct('id','theta_5','label','theta1=5','theta1',5) ...
    struct('id','theta_10','label','theta1=10','theta1',10)];

variants = planWorkflow.templates.ObjectivePenaltyVariants.variantsWithPenalties( ...
    objectiveSet,baseVariants,'INTERVAL2');

expectedIds = {'theta_5_v1_p1','theta_5_v1_p2', ...
    'theta_5_v1_p3','theta_5_v1_p4','theta_10_v2_p1', ...
    'theta_10_v2_p2','theta_10_v2_p3','theta_10_v2_p4'};
verifyEqual(testCase,{variants.id},expectedIds);
verifyEqual(testCase,penaltyValuesByVariant(variants), ...
    [10 100; 10 200; 30 100; 30 200; ...
     10 100; 10 200; 30 100; 30 200]);
verifyEqual(testCase,variants(5).baseVariantIndex,2);
verifyEqual(testCase,variants(1).baseVariantId,'theta_5');
verifyEqual(testCase,variants(2).label, ...
    'theta1=5 / penalties=10,200');

materialized = ...
    planWorkflow.templates.ObjectivePenaltyVariants.materializeObjectiveSet( ...
    objectiveSet,variants(3));
verifyEqual(testCase,objectiveParameter(materialized, ...
    'structureObjectives','CTV',1,'penalty'),30);
verifyEqual(testCase,objectiveParameter(materialized, ...
    'ringObjectives','RING 0 - 20 mm',1,'penalty'),100);

runConfig = struct();
runConfig.precompute = planWorkflow.config.RobustPlanConfig.defaults();
plan = planWorkflow.config.RobustPlanConfig.defaultPlan();
plan.id = 'Interval2';
plan.label = 'Interval2';
plan.objectiveSetName = 'Interval2';
plan.variants = baseVariants;
runConfig.precompute.robustPlans = plan;

runConfig = ...
    planWorkflow.config.WorkflowContractValidator.alignRobustPlansWithTemplate( ...
    runConfig,template);
alignedPlan = runConfig.precompute.robustPlans(1);
verifyEqual(testCase,{alignedPlan.variants.id},{'theta_5','theta_10'});
verifyEqual(testCase,{alignedPlan.variantsWithPenalties.id},expectedIds);
verifyEqual(testCase, ...
    planWorkflow.config.RobustPlanConfig.variantWithPenaltyCount( ...
    alignedPlan),8);
verifyEqual(testCase, ...
    planWorkflow.templates.ObjectivePenaltyVariants.summary(alignedPlan), ...
    'Robust variants: 2 | Penalty combinations: 4 | Total variants: 8');
end

function testTooManyPenaltyCombinationsAreRejected(testCase)
maxCount = ...
    planWorkflow.templates.ObjectivePenaltyVariants.maxPenaltyCombinationCount();
template = penaltyVariantTemplate(1:(maxCount + 1));

verifyError(testCase,@() ...
    planWorkflow.templates.PlanTemplate.validateTemplate( ...
    template,template.id), ...
    ['planWorkflow:templates:ObjectivePenaltyVariants:' ...
    'TooManyPenaltyCombinations']);
end

function testExpandedPenaltyVariantsAreCapped(testCase)
maxPenaltyCombinations = ...
    planWorkflow.templates.ObjectivePenaltyVariants.maxPenaltyCombinationCount();
maxExpandedVariants = ...
    planWorkflow.templates.ObjectivePenaltyVariants.maxExpandedVariantCount();
template = penaltyVariantTemplate(1:maxPenaltyCombinations);
objectiveSet = planWorkflow.templates.PlanTemplate.objectiveSet( ...
    template,'Interval2');
variantCount = floor(maxExpandedVariants / maxPenaltyCombinations) + 1;
baseVariants = repmat(struct('id','theta_1','label','theta1=1', ...
    'theta1',1),1,variantCount);
for variantIx = 1:variantCount
    baseVariants(variantIx).id = sprintf('theta_%d',variantIx);
    baseVariants(variantIx).label = sprintf('theta1=%d',variantIx);
    baseVariants(variantIx).theta1 = variantIx;
end

verifyError(testCase,@() ...
    planWorkflow.templates.ObjectivePenaltyVariants.variantsWithPenalties( ...
    objectiveSet,baseVariants,'INTERVAL2'), ...
    ['planWorkflow:templates:ObjectivePenaltyVariants:' ...
    'TooManyVariantsWithPenalties']);
end

function testProb2OptimizationFunctionsCanBeBuilt(testCase)
assumeTrue(testCase,exist('DoseObjectives.matRad_MeanVariance','class') == 8);
assumeTrue(testCase,exist('DoseConstraints.matRad_MinMaxMeanVariance', ...
    'class') == 8);

objectiveTypes = planWorkflow.templates.ObjectiveFactory.supportedObjectiveTypes();
verifyTrue(testCase,any(strcmp(objectiveTypes,'matRad_MeanVariance')));
verifyTrue(testCase,any(strcmp(objectiveTypes, ...
    'matRad_MinMaxMeanVariance')));
verifyEqual(testCase, ...
    planWorkflow.templates.PlanTemplate.supportedObjectiveRobustnessValuesForType( ...
    'matRad_MeanVariance'),{'PROB2'});
verifyEqual(testCase, ...
    planWorkflow.templates.PlanTemplate.supportedObjectiveRobustnessValuesForType( ...
    'matRad_MinMaxMeanVariance'),{'PROB2'});

meanVariance = planWorkflow.templates.ObjectiveFactory.constructObjective( ...
    'matRad_MeanVariance',{7});
minMaxMeanVariance = ...
    planWorkflow.templates.ObjectiveFactory.constructObjective( ...
    'matRad_MinMaxMeanVariance',{0.1,2.5});

verifyEqual(testCase, ...
    planWorkflow.templates.ObjectiveFactory.parameterNamesForObjectiveType( ...
    'matRad_MeanVariance'),{'penalty'});
verifyEqual(testCase, ...
    planWorkflow.templates.ObjectiveFactory.parameterNamesForObjectiveType( ...
    'matRad_MinMaxMeanVariance'), ...
    {'minMeanVariance','maxMeanVariance'});
verifyEqual(testCase,meanVariance.className, ...
    'DoseObjectives.matRad_MeanVariance');
verifyEqual(testCase,minMaxMeanVariance.className, ...
    'DoseConstraints.matRad_MinMaxMeanVariance');
end

function testIntervalTemplatesUseMatRadIntervalTargets(testCase)
templateIds = {'interval2_001','interval3_001'};
robustnessValues = {'INTERVAL2','INTERVAL3'};
availableIds = planWorkflow.templates.PlanTemplate.availableTemplateIds( ...
    'prostate');

for i = 1:numel(templateIds)
    verifyTrue(testCase,any(strcmp(availableIds,templateIds{i})));
    template = planWorkflow.templates.PlanTemplate.loadForDescription( ...
        'prostate',templateIds{i});
    referenceObjectives = objectivesForStructure( ...
        template,'reference',char(template.primaryTarget));
    robustSetName = firstRobustObjectiveSetName(template);
    robustObjectives = objectivesForStructure( ...
        template,robustSetName,char(template.primaryTarget));
    robustObjective = templateObjectiveAt(robustObjectives,1);

    verifyEqual(testCase,char(template.primaryTarget),'CTV');
    verifyEqual(testCase,numel(robustObjectives),1);
    verifyGreaterThanOrEqual(testCase,numel(referenceObjectives),1);
    verifyEqual(testCase,char(robustObjective.type), ...
        'matRad_SquaredBertoluzzaDeviation');
    verifyEqual(testCase,char(robustObjective.properties.robustness), ...
        robustnessValues{i});
end
end

function testIntervalReferencesAreAligned(testCase)
interval2Template = planWorkflow.templates.PlanTemplate.loadForDescription( ...
    'prostate','interval2_001');
ptvTemplate = planWorkflow.templates.PlanTemplate.loadForDescription( ...
    'prostate','PTV_001');
interval3Template = planWorkflow.templates.PlanTemplate.loadForDescription( ...
    'prostate','interval3_001');

verifyEqual(testCase,ptvTemplate.objectiveSets.reference, ...
    interval2Template.objectiveSets.reference);
verifyEqual(testCase,interval3Template.objectiveSets.reference, ...
    interval2Template.objectiveSets.reference);
end

function testIntervalReferencePtvObjectivesAreDisabled(testCase)
templateIds = {'interval2_001','PTV_001','interval3_001'};
for i = 1:numel(templateIds)
    template = planWorkflow.templates.PlanTemplate.loadForDescription( ...
        'prostate',templateIds{i});
    objectives = objectivesForStructure(template,'reference','PTV');
    verifyTrue(testCase,allObjectiveEnabledValues(objectives,false));
end
end

function testPtvTemplateRobustObjectivesUsePtvSetWithPtvActive(testCase)
interval2Template = planWorkflow.templates.PlanTemplate.loadForDescription( ...
    'prostate','interval2_001');
ptvTemplate = planWorkflow.templates.PlanTemplate.loadForDescription( ...
    'prostate','PTV_001');
expectedRobust = robustPtvReferenceSet( ...
    interval2Template.objectiveSets.reference);
expectedRobust.id = 'PTV';
expectedRobust.label = 'PTV';

verifyEqual(testCase,canonicalObjectiveSet(ptvTemplate.objectiveSets.robustPlans(1)), ...
    canonicalObjectiveSet(expectedRobust));

ptvObjectives = objectivesForStructure(ptvTemplate,'PTV','PTV');
verifyTrue(testCase,allObjectiveEnabledValues(ptvObjectives,true));
ptvMinDvh = objectiveWithType(ptvObjectives,'matRad_MinDVH');
verifyEqual(testCase,ptvMinDvh.dosePulling.channel,'dose_pulling_2');
verifyEqual(testCase,ptvMinDvh.dosePulling.rates.penalty,10);
end

function testComparisonTemplateDefinesPtvAndIntervalPlans(testCase)
interval2Template = planWorkflow.templates.PlanTemplate.loadForDescription( ...
    'prostate','interval2_001');
comparisonTemplate = planWorkflow.templates.PlanTemplate.loadForDescription( ...
    'prostate','comparison_001');

verifyEqual(testCase,{comparisonTemplate.objectiveSets.robustPlans.id}, ...
    {'PTV','Minimax','Stochastic','cMinimax','MeanVariance', ...
    'Interval2','Interval3'});
verifyEqual(testCase,{comparisonTemplate.objectiveSets.robustPlans.label}, ...
    {'PTV','COWC','Stochastic','c-Minimax', ...
    'MeanVariance','Interval2','Interval3'});

expectedPtv = robustPtvReferenceSet( ...
    interval2Template.objectiveSets.reference);
expectedPtv.id = 'PTV';
expectedPtv.label = 'PTV';
verifyEqual(testCase,canonicalObjectiveSet( ...
    comparisonTemplate.objectiveSets.robustPlans(1)), ...
    canonicalObjectiveSet(expectedPtv));

expectedInterval = interval2Template.objectiveSets.robustPlans(1);
expectedInterval.id = 'Interval2';
expectedInterval.label = 'Interval2';
intervalIx = find(strcmp({comparisonTemplate.objectiveSets.robustPlans.id}, ...
    'Interval2'),1);
verifyEqual(testCase,canonicalObjectiveSet( ...
    comparisonTemplate.objectiveSets.robustPlans(intervalIx)), ...
    canonicalObjectiveSet(expectedInterval));
verifyEqual(testCase,dosePullingChannels(comparisonTemplate,'reference'), ...
    {'dose_pulling_1'});
verifyEqual(testCase,dosePullingChannels(comparisonTemplate,'PTV'), ...
    {'dose_pulling_2'});
verifyEqual(testCase,dosePullingChannels(comparisonTemplate,'Interval2'), ...
    {'dose_pulling_2'});
end

function testBreastComparisonTemplateDefinesFullRobustSet(testCase)
comparisonTemplate = planWorkflow.templates.PlanTemplate.loadForDescription( ...
    'breast','comparison_001');

expectedIds = {'PTV','Minimax','Stochastic','cMinimax', ...
    'MeanVariance','Interval2','Interval3'};
expectedLabels = {'PTV','COWC','Stochastic','c-Minimax', ...
    'MeanVariance','INTERVAL2','INTERVAL3'};
expectedModes = {'none','COWC','STOCH','c-COWC','PROB2', ...
    'INTERVAL2','INTERVAL3'};

verifyEqual(testCase,{comparisonTemplate.objectiveSets.robustPlans.id}, ...
    expectedIds);
verifyEqual(testCase,{comparisonTemplate.objectiveSets.robustPlans.label}, ...
    expectedLabels);
for planIx = 1:numel(expectedIds)
    contract = ...
        planWorkflow.templates.ObjectiveRobustnessContract.forTemplateObjectiveSet( ...
        comparisonTemplate,expectedIds{planIx});
    verifyEqual(testCase,contract.robustnessMode,expectedModes{planIx});
end
verifyEqual(testCase,dosePullingChannels(comparisonTemplate,'reference'), ...
    {'dose_pulling_1'});
verifyEqual(testCase,dosePullingChannels(comparisonTemplate,'PTV'), ...
    {'dose_pulling_2'});
verifyEqual(testCase,dosePullingChannels(comparisonTemplate,'Interval2'), ...
    {'dose_pulling_2'});
verifyEqual(testCase,dosePullingChannels(comparisonTemplate,'Interval3'), ...
    {'dose_pulling_2'});
end

function testBreastSingleRobustnessTemplatesMirrorComparisonPlans(testCase)
comparisonTemplate = planWorkflow.templates.PlanTemplate.loadForDescription( ...
    'breast','comparison_001');
comparisonPlans = comparisonTemplate.objectiveSets.robustPlans;
singleTemplates = { ...
    'PTV_001','PTV'; ...
    'COWC_001','Minimax'; ...
    'STOCH_001','Stochastic'; ...
    'cCOWC_001','cMinimax'; ...
    'PROB2_001','MeanVariance'; ...
    'interval2_001','Interval2'; ...
    'interval3_001','Interval3'};

for templateIx = 1:size(singleTemplates,1)
    templateId = singleTemplates{templateIx,1};
    objectiveSetName = singleTemplates{templateIx,2};
    singleTemplate = planWorkflow.templates.PlanTemplate.loadForDescription( ...
        'breast',templateId);
    singlePlans = singleTemplate.objectiveSets.robustPlans;
    comparisonIx = find(strcmp({comparisonPlans.id},objectiveSetName),1);

    assertEqual(testCase,numel(singlePlans),1);
    assertFalse(testCase,isempty(comparisonIx));
    verifyEqual(testCase,singleTemplate.objectiveSets.reference, ...
        comparisonTemplate.objectiveSets.reference);
    verifyEqual(testCase,canonicalObjectiveSet(singlePlans(1)), ...
        canonicalObjectiveSet(comparisonPlans(comparisonIx)));
end
end

function testObjectiveSetDosePullingChannelsAreSeparated(testCase)
templateIds = {'interval2_001','PTV_001','interval3_001'};
for i = 1:numel(templateIds)
    template = planWorkflow.templates.PlanTemplate.loadForDescription( ...
        'prostate',templateIds{i});
    robustSetName = firstRobustObjectiveSetName(template);
    verifyEqual(testCase,dosePullingChannels(template,'reference'), ...
        {'dose_pulling_1'});
    verifyEqual(testCase,dosePullingChannels(template,robustSetName), ...
        {'dose_pulling_2'});
end
end

function testTemplateDerivedRingsAreCreated(testCase)
runConfig = baseRunConfig();
ct = makeCt([7 7 7]);
cst = makeProstateCst(ct.cubeDim);

[cst,objectiveInfo] = planWorkflow.templates.PlanTemplate.applyObjectives( ...
    runConfig,[],cst);
[cst,objectiveInfo] = planWorkflow.templates.PlanTemplate.addDerivedStructures( ...
    runConfig,cst,ct,objectiveInfo);

verifyEqual(testCase,cst{objectiveInfo.ixRing1,2},'RING 0 - 20 mm');
verifyEqual(testCase,cst{objectiveInfo.ixRing2,2},'RING 20 - 50 mm');
verifyEqual(testCase,cst{objectiveInfo.ixRing1,5}.Priority,4);
verifyEqual(testCase,cst{objectiveInfo.ixRing1,6}{1}.parameters{1},85.8, ...
    'AbsTol',1e-12);
verifyEqual(testCase,cst{objectiveInfo.ixRing2,6}{1}.parameters{1},78);
end

function testExistingRingColorUsesTemplateColor(testCase)
runConfig = baseRunConfig();
ct = makeCt([7 7 7]);
cst = makeProstateCst(ct.cubeDim);
template = planWorkflow.templates.PlanTemplate.loadForDescription( ...
    'prostate','interval2_001');

[cst,objectiveInfo] = planWorkflow.templates.PlanTemplate.applyObjectives( ...
    runConfig,[],cst,template);
ringIx = size(cst,1) + 1;
cst{ringIx,1} = ringIx - 1;
cst{ringIx,2} = 'RING 0 - 20 mm';
cst{ringIx,3} = 'OAR';
cst{ringIx,4}{1} = [];
cst{ringIx,5} = struct('Priority',9,'Visible',true, ...
    'visibleColor',[0.9 0.8 0.7]);
cst{ringIx,6} = [];

cst = planWorkflow.templates.PlanTemplate.addDerivedStructures( ...
    runConfig,cst,ct,objectiveInfo,template);

verifyEqual(testCase,cst{ringIx,5}.visibleColor, ...
    [0 1 0.502],'AbsTol',1e-12);
end

function template = penaltyVariantTemplate(structurePenalties,ringPenalties)
if nargin < 2
    ringPenalties = [];
end
template = planWorkflow.templates.PlanTemplate.loadForDescription( ...
    'prostate','interval2_001');
template.objectiveSets.robustPlans(1) = setObjectiveParameter( ...
    template.objectiveSets.robustPlans(1),'structureObjectives', ...
    'CTV',1,'penalty',structurePenalties);
template.objectiveSets.robustPlans(1) = removeDosePulling( ...
    template.objectiveSets.robustPlans(1));
if ~isempty(ringPenalties)
    template.objectiveSets.robustPlans(1) = setObjectiveParameter( ...
        template.objectiveSets.robustPlans(1),'ringObjectives', ...
        'RING 0 - 20 mm',1,'penalty',ringPenalties);
end
end

function objectiveSet = setObjectiveParameter( ...
        objectiveSet,groupField,groupName,objectiveIx,parameterName,value)
groups = objectiveSet.(groupField);
groupIx = find(strcmp({groups.name},char(groupName)),1);
if isempty(groupIx)
    error('testPlanTemplate:MissingObjectiveGroup', ...
        'Missing objective group "%s".',char(groupName));
end
objective = objectiveFromGroup(groups(groupIx),objectiveIx);
objective.parameters.(parameterName) = value;
groups(groupIx) = setObjectiveInGroup( ...
    groups(groupIx),objectiveIx,objective);
objectiveSet.(groupField) = groups;
end

function value = objectiveParameter( ...
        objectiveSet,groupField,groupName,objectiveIx,parameterName)
groups = objectiveSet.(groupField);
groupIx = find(strcmp({groups.name},char(groupName)),1);
objective = objectiveFromGroup(groups(groupIx),objectiveIx);
value = objective.parameters.(parameterName);
end

function values = penaltyValuesByVariant(variants)
values = zeros(numel(variants),2);
for variantIx = 1:numel(variants)
    values(variantIx,:) = ...
        planWorkflow.templates.ObjectivePenaltyVariants.penaltyValues( ...
        variants(variantIx));
end
end

function runConfig = baseRunConfig()
runConfig = struct();
runConfig.plan_template = 'interval2_001';
runConfig.radiationMode = 'photons';
runConfig.description = 'prostate';
runConfig.plan_beams = '9F';
runConfig.dose_pulling1_start = 0;
runConfig.dose_pulling2_start = 0;
end

function templateFolder = copyTemplateFixture(testCase)
fixture = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
templateClassFile = which('planWorkflow.templates.PlanTemplate');
templateFolder = fullfile(fixture.Folder,'prostate','interval2_001');
mkdir(fileparts(templateFolder));
copyfile(fullfile(fileparts(templateClassFile),'json','prostate','interval2_001'), ...
    templateFolder);
copyfile(fullfile(fileparts(templateClassFile),'json','prostate','shared'), ...
    fullfile(fileparts(templateFolder),'shared'));
template = planWorkflow.templates.PlanTemplate.loadFromFolder( ...
    templateFolder,'interval2_001');
components = planWorkflow.templates.PlanTemplate.toComponents( ...
    template,'prostate','interval2_001');
writeJson(fullfile(templateFolder,'objectives.json'), ...
    components.objectives);
end

function structuresFile = sharedStructuresFile(templateFolder)
structuresFile = fullfile(fileparts(templateFolder),'shared', ...
    'structures_base.json');
end

function writeJson(jsonFile,value)
fid = fopen(jsonFile,'w');
cleanup = onCleanup(@() fclose(fid));
fprintf(fid,'%s',jsonencode(value));
end

function structures = addStructureOperationField(structures)
if ~isfield(structures,'operation')
    structures(1).operation = '';
end
end

function objectiveSets = appendEmptyObjectiveGroupToSets( ...
        objectiveSets,groupField,groupName)
group = struct('name',char(groupName),'objectives',{{}});
objectiveSets = appendObjectiveGroupToSets(objectiveSets,groupField,group);
end

function objectiveSets = appendObjectiveGroupToSets( ...
        objectiveSets,groupField,group)
objectiveSets.reference.(groupField)(end + 1) = group;
for i = 1:numel(objectiveSets.robustPlans)
    objectiveSets.robustPlans(i).(groupField)(end + 1) = group;
end
end

function objectives = objectivesForStructure(template,objectiveSetName, ...
        structureName)
objectiveSet = planWorkflow.templates.PlanTemplate.objectiveSet( ...
    template,objectiveSetName);
groupIx = find(strcmp({objectiveSet.structureObjectives.name}, ...
    structureName),1);
objectives = objectiveSet.structureObjectives(groupIx).objectives;
end

function objective = templateObjectiveAt(objectives,index)
if iscell(objectives)
    objective = objectives{index};
else
    objective = objectives(index);
end
end

function objective = objectiveWithType(objectives,objectiveType)
for i = 1:numel(objectives)
    candidate = templateObjectiveAt(objectives,i);
    if strcmp(char(candidate.type),objectiveType)
        objective = candidate;
        return;
    end
end
error('testPlanTemplate:MissingObjectiveType', ...
    'Missing objective type "%s".',objectiveType);
end

function tf = allObjectiveEnabledValues(objectives,expectedValue)
values = false(1,numel(objectives));
for i = 1:numel(objectives)
    objective = templateObjectiveAt(objectives,i);
    values(i) = logical(objective.enabled);
end
tf = all(values == logical(expectedValue));
end

function objective = objectiveFromGroup(group,index)
objective = templateObjectiveAt(group.objectives,index);
end

function group = setObjectiveInGroup(group,index,objective)
objectives = group.objectives;
if ~iscell(objectives)
    objectives = num2cell(objectives);
end
objectives{index} = objective;
group.objectives = objectives;
end

function objectiveSet = robustPtvReferenceSet(referenceSet)
objectiveSet = referenceSet;
objectiveSet.structureObjectives = ...
    robustPtvReferenceGroups(objectiveSet.structureObjectives);
objectiveSet.ringObjectives = removeDosePullingFromGroups( ...
    objectiveSet.ringObjectives);
end

function groups = robustPtvReferenceGroups(groups)
for groupIx = 1:numel(groups)
    objectives = groups(groupIx).objectives;
    for objectiveIx = 1:numel(objectives)
        objective = templateObjectiveAt(objectives,objectiveIx);
        if strcmp(char(groups(groupIx).name),'PTV')
            objective.enabled = true;
            if strcmp(char(objective.type),'matRad_MinDVH')
                objective.dosePulling = struct('channel','dose_pulling_2', ...
                    'rates',struct('penalty',10));
            elseif isfield(objective,'dosePulling')
                objective = rmfield(objective,'dosePulling');
            end
        elseif isfield(objective,'dosePulling')
            objective = rmfield(objective,'dosePulling');
        end
        objectives = setObjectiveAt(objectives,objectiveIx,objective);
    end
    groups(groupIx).objectives = objectives;
end
end

function objectiveSet = canonicalObjectiveSet(objectiveSet)
objectiveSet.structureObjectives = canonicalObjectiveGroups( ...
    objectiveSet.structureObjectives);
objectiveSet.ringObjectives = canonicalObjectiveGroups( ...
    objectiveSet.ringObjectives);
end

function groups = canonicalObjectiveGroups(groups)
for groupIx = 1:numel(groups)
    if ~iscell(groups(groupIx).objectives)
        groups(groupIx).objectives = num2cell(groups(groupIx).objectives);
    end
end
end

function objectives = setObjectiveAt(objectives,index,objective)
if iscell(objectives)
    objectives{index} = objective;
elseif isequal(sort(fieldnames(objectives)),sort(fieldnames(objective)))
    objectives(index) = objective;
else
    objectives = num2cell(objectives);
    objectives{index} = objective;
end
end

function objectiveSet = removeDosePulling(objectiveSet)
objectiveSet.structureObjectives = removeDosePullingFromGroups( ...
    objectiveSet.structureObjectives);
objectiveSet.ringObjectives = removeDosePullingFromGroups( ...
    objectiveSet.ringObjectives);
end

function groups = removeDosePullingFromGroups(groups)
for groupIx = 1:numel(groups)
    objectives = groups(groupIx).objectives;
    if iscell(objectives)
        for objectiveIx = 1:numel(objectives)
            objective = objectives{objectiveIx};
            if isfield(objective,'dosePulling')
                objective = rmfield(objective,'dosePulling');
            end
            objectives{objectiveIx} = objective;
        end
    elseif isfield(objectives,'dosePulling')
        objectives = rmfield(objectives,'dosePulling');
    end
    groups(groupIx).objectives = objectives;
end
end

function channels = dosePullingChannels(template,objectiveSetName)
objectiveSet = planWorkflow.templates.PlanTemplate.objectiveSet( ...
    template,objectiveSetName);
channels = {};
channels = appendDosePullingChannels( ...
    channels,objectiveSet.structureObjectives);
channels = appendDosePullingChannels(channels,objectiveSet.ringObjectives);
channels = unique(channels,'stable');
end

function objectiveSetName = firstRobustObjectiveSetName(template)
robustObjectiveSets = ...
    planWorkflow.templates.PlanTemplate.robustObjectiveSets(template);
objectiveSetName = char(robustObjectiveSets(1).id);
end

function channels = appendDosePullingChannels(channels,groups)
for groupIx = 1:numel(groups)
    objectives = groups(groupIx).objectives;
    for objectiveIx = 1:numel(objectives)
        objective = templateObjectiveAt(objectives,objectiveIx);
        if isfield(objective,'dosePulling') && ~isempty(objective.dosePulling)
            channels{end + 1} = char(objective.dosePulling.channel); %#ok<AGROW>
        end
    end
end
end

function cases = particlePlanCases()
cases = { ...
    'protons','constRBE',false; ...
    'carbon','LEM',true; ...
    'helium','HEL',true};
end

function runConfig = particleRunConfig(radiationMode)
runConfig = baseRunConfig();
runConfig.plan_template = 'interval2_001';
runConfig.radiationMode = radiationMode;
runConfig.plan_beams = '2F';
runConfig.machine = 'Generic';
runConfig.bioModel = particleBioModel(radiationMode);
runConfig.doseResolution = [5 5 5];
runConfig.hlutFileName = 'matRad_default.hlut';
runConfig.optimizer = 'IPOPT';
runConfig.reference_scen_mode = 'nomScen';
runConfig.reference_ctActive = false;
runConfig.reference_ctReferenceScenId = 1;
runConfig.reference_setupActive = false;
runConfig.reference_rangeActive = false;
runConfig.reference_gantryActive = false;
runConfig.reference_couchActive = false;
runConfig.reference_shiftSD = [5 10 5];
runConfig.reference_wcSigma = 1;
runConfig.reference_rangeAbsSD = 0;
runConfig.reference_rangeRelSD = 0;
runConfig.reference_numOfRangeGridPoints = 1;
runConfig.reference_gantryAngleSD = 0;
runConfig.reference_couchAngleSD = 0;
runConfig.reference_random_size = 50;
runConfig.reference_randomSeed = [];
end

function bioModel = particleBioModel(radiationMode)
cases = particlePlanCases();
caseIx = find(strcmp(cases(:,1),char(radiationMode)),1);
bioModel = cases{caseIx,2};
end

function ct = makeCt(cubeDim)
ct = struct();
ct.cubeDim = cubeDim;
ct.resolution = struct('x',1,'y',1,'z',1);
ct.numOfCtScen = 1;
end

function cst = makeProstateCst(cubeDim)
cst = cell(5,6);
cst = setStructure(cst,1,'BODY','OAR',find(true(cubeDim)),5);
cst = setStructure(cst,2,'CTV','TARGET',sub2ind(cubeDim,4,4,4),1);
cst = setStructure(cst,3,'PTV','TARGET',sub2ind(cubeDim,[3 4 5],[4 4 4],[4 4 4]),2);
cst = setStructure(cst,4,'BLADDER','OAR',sub2ind(cubeDim,2,4,4),3);
cst = setStructure(cst,5,'RECTUM','OAR',sub2ind(cubeDim,6,4,4),3);
end

function cst = setStructure(cst,ix,name,type,voxels,priority)
cst{ix,1} = ix - 1;
cst{ix,2} = name;
cst{ix,3} = type;
cst{ix,4}{1} = voxels(:);
cst{ix,5} = struct('Priority',priority,'Visible',true, ...
    'visibleColor',[0 1 0]);
cst{ix,6} = [];
end
