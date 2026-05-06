function tests = testCreateSkin
tests = functiontests(localfunctions);
end

function testFullSkinUsesPatientSurface(testCase)
ct = makeCt([5 5 5]);
cst = makeBodyCst(ct.cubeDim);
metadata = makeSkinMetadata();

[updatedCst,ixSkin,skinInfo] = planWorkflow.structures.createSkin(1,cst,ct,metadata);

verifyEqual(testCase,ixSkin,2);
verifyEqual(testCase,updatedCst{ixSkin,2},'SKIN');
verifyEqual(testCase,updatedCst{ixSkin,3},'OAR');
verifyEqual(testCase,numel(updatedCst{ixSkin,4}{1}),98);
verifyEqual(testCase,numel(skinInfo.fullVoxels{1}),98);
verifyEqual(testCase,updatedCst{ixSkin,4},skinInfo.fullVoxels);
verifyFalse(testCase,any(updatedCst{ixSkin,4}{1} == sub2ind(ct.cubeDim,3,3,3)));
end

function testTargetRegionIsCompactSkinSubsetNearTarget(testCase)
ct = makeCt([7 7 7]);
cst = makeBodyCst(ct.cubeDim);
cst = addStructure(cst,'TARGET','TARGET',sub2ind(ct.cubeDim,2,4,4));
metadata = makeSkinMetadata();

[updatedCst,ixSkin,skinInfo] = planWorkflow.structures.createSkin( ...
    1,cst,ct,metadata,'mode','targetRegion','targetIndex',2, ...
    'targetDistanceMm',1.1);

fullSkin = skinInfo.fullVoxels{1};
selectedSkin = updatedCst{ixSkin,4}{1};
expectedAnchor = sub2ind(ct.cubeDim,1,4,4);

verifyLessThan(testCase,numel(selectedSkin),numel(fullSkin));
verifyTrue(testCase,all(ismember(selectedSkin,fullSkin)));
verifyEqual(testCase,skinInfo.anchorVoxel{1},expectedAnchor);
verifyEqual(testCase,selectedSkin,expectedAnchor);
end

function testTargetRegionFillsSurfaceHoles(testCase)
ct = makeCt([7 7 7]);
cst = makeBodyCst(ct.cubeDim);
targetVoxels = makeTargetRingVoxels(ct.cubeDim);
cst = addStructure(cst,'TARGET','TARGET',targetVoxels);
metadata = makeSkinMetadata();

[updatedCst,ixSkin] = planWorkflow.structures.createSkin( ...
    1,cst,ct,metadata,'mode','targetRegion','targetIndex',2, ...
    'targetDistanceMm',1.1);

selectedSkin = updatedCst{ixSkin,4}{1};
holeVoxel = sub2ind(ct.cubeDim,1,4,4);

verifyEqual(testCase,numel(selectedSkin),9);
verifyTrue(testCase,ismember(holeVoxel,selectedSkin));
end

function testMultipleScenariosAreProcessed(testCase)
ct = makeCt([4 4 4]);
cst = makeBodyCst(ct.cubeDim);
cst{1,4}{2} = find(makeInnerCubeMask(ct.cubeDim,2:3,2:3,2:3));
metadata = makeSkinMetadata();

[updatedCst,ixSkin,skinInfo] = planWorkflow.structures.createSkin(1,cst,ct,metadata);

verifyEqual(testCase,numel(updatedCst{ixSkin,4}),2);
verifyEqual(testCase,numel(updatedCst{ixSkin,4}{1}),56);
verifyEqual(testCase,numel(updatedCst{ixSkin,4}{2}),8);
verifyEqual(testCase,updatedCst{ixSkin,4},skinInfo.fullVoxels);
end

function testTargetRegionRequiresTargetIndex(testCase)
ct = makeCt([5 5 5]);
cst = makeBodyCst(ct.cubeDim);
metadata = makeSkinMetadata();

verifyError(testCase, ...
    @() planWorkflow.structures.createSkin(1,cst,ct,metadata, ...
    'mode','targetRegion'), ...
    'planWorkflow:structures:createSkin:InvalidStructureIndex');
end

function testNormalizeNamesMapsBreastSkinToBodyAndCreatesSkin(testCase)
ct = makeCt([5 5 5]);
cst = makeBreastCst(ct.cubeDim);
runConfig = struct('description','breast','skinMode','full');

updatedCst = planWorkflow.structures.normalizeNames(cst,runConfig,ct);
skinIx = find(strcmp(updatedCst(:,2),'SKIN'),1);

verifyNotEmpty(testCase,skinIx);
verifyEqual(testCase,numel(updatedCst{skinIx,4}{1}),98);
verifyTrue(testCase,strcmp(updatedCst{1,2},'BODY') || ...
    any(strcmp(updatedCst(:,2),'BODY')));
end

function testBreastNormalizationConfigMapsAliases(testCase)
config = planWorkflow.structures.loadNormalizationConfig('breast');
rightLungKey = planWorkflow.structures.normalizationKey('pulmon derecho');
leftLungKey = planWorkflow.structures.normalizationKey('PULMON IZQUIERDO');
skinKey = planWorkflow.structures.normalizationKey('Skin');

verifyEqual(testCase,config.aliasMap(rightLungKey),'RIGHT LUNG');
verifyEqual(testCase,config.aliasMap(leftLungKey),'LEFT LUNG');
verifyEqual(testCase,config.aliasMap(skinKey),'BODY');
verifyTrue(testCase,any(strcmp(config.outputStructures,'SKIN')));
verifyEqual(testCase,char(config.derivedStructures(1).kind), ...
    'skinFromBody');
end

function testProstateNormalizationDropsStructuresOutsideConfig(testCase)
ct = makeCt([5 5 5]);
cst = cell(0,6);
cst = addStructure(cst,'PROSTATA','TARGET',sub2ind(ct.cubeDim,2,2,2));
cst = addStructure(cst,'Tabla','OAR',sub2ind(ct.cubeDim,3,3,3));
runConfig = struct('description','prostate');

[updatedCst,report] = planWorkflow.structures.normalizeNames( ...
    cst,runConfig,ct);

verifyEqual(testCase,updatedCst(:,2),{'CTV'});
verifyEqual(testCase,cell2mat(updatedCst(:,1))',0);
verifyEqual(testCase,{report.renamed.originalName},{'PROSTATA'});
verifyEqual(testCase,{report.renamed.normalizedName},{'CTV'});
verifyEqual(testCase,{report.dropped.name},{'Tabla'});
verifyTrue(testCase,contains(report.dropped(1).reason,'unsupported'));
end

function testNormalizationReportLoggerEmitsRenamesAndDrops(testCase)
report = struct();
report.renamed = struct('row',1,'originalName','PROSTATA', ...
    'normalizedName','CTV');
report.dropped = struct('row',2,'name','Tabla', ...
    'reason','unsupported prostate structure');
messages = {};

planWorkflow.structures.NormalizationReportLogger.log( ...
    @capture,'Optimization structure normalization',report);

text = strjoin(messages,newline);
verifyTrue(testCase,contains(text, ...
    'Optimization structure normalization:'));
verifyTrue(testCase,contains(text,'renamed "PROSTATA" -> "CTV"'));
verifyTrue(testCase,contains(text, ...
    'dropped "Tabla": unsupported prostate structure'));

    function capture(message)
        messages{end + 1} = message; %#ok<AGROW>
    end
end

function testNormalizeNamesSupportsHeadAndNeckPatientStructures(testCase)
ct = makeCt([5 5 5]);
cst = makeHeadAndNeckCst(ct.cubeDim);
runConfig = struct('description','h&n');

updatedCst = planWorkflow.structures.normalizeNames(cst,runConfig,ct);
structureNames = updatedCst(:,2);

verifyEqual(testCase,structureNames(:), ...
    {'BRAINSTEM';'MANDIBLE';'LEFT PAROTID';'RIGHT PAROTID'; ...
    'SPINAL CORD';'BODY';'CTVT';'CTVN';'CTV';'PTV'});
verifyFalse(testCase,any(strcmp(structureNames,'Tabla')));
verifyFalse(testCase,any(strcmp(structureNames,'Upper pallet')));
verifyEqual(testCase,cell2mat(updatedCst(:,1))',0:9);
end

function ct = makeCt(cubeDim)
ct = struct();
ct.cubeDim = cubeDim;
ct.resolution = struct('x',1,'y',1,'z',1);
end

function cst = makeBodyCst(cubeDim)
cst = cell(1,6);
cst{1,1} = 0;
cst{1,2} = 'BODY';
cst{1,3} = 'OAR';
cst{1,4}{1} = find(true(cubeDim));
cst{1,5} = struct('Priority',5,'Visible',true,'visibleColor',[1 1 1]);
cst{1,6} = {};
end

function cst = makeBreastCst(cubeDim)
cst = makeBodyCst(cubeDim);
cst{1,2} = 'Skin';
cst = addStructure(cst,'PTV','TARGET',sub2ind(cubeDim,2,3,3));
cst = addStructure(cst,'SENO IZQUIERDO','TARGET',sub2ind(cubeDim,3,3,3));
end

function cst = makeHeadAndNeckCst(cubeDim)
cst = cell(0,6);
cst = addStructure(cst,'Brainstem','OAR',sub2ind(cubeDim,1,1,1));
cst = addStructure(cst,'Mandible','OAR',sub2ind(cubeDim,1,1,2));
cst = addStructure(cst,'ParotidGland (Left)','OAR',sub2ind(cubeDim,1,1,3));
cst = addStructure(cst,'ParotidGland (Right)','OAR',sub2ind(cubeDim,1,1,4));
cst = addStructure(cst,'SpinalCord','OAR',sub2ind(cubeDim,1,1,5));
cst = addStructure(cst,'External','OAR',find(true(cubeDim)));
cst = addStructure(cst,'CTVT','TARGET',sub2ind(cubeDim,2,2,1));
cst = addStructure(cst,'CTVN','TARGET',sub2ind(cubeDim,2,2,2));
cst = addStructure(cst,'CTV50','TARGET',sub2ind(cubeDim,2,2,3));
cst = addStructure(cst,'PTV50','TARGET',sub2ind(cubeDim,2,2,4));
cst = addStructure(cst,'Tabla','OAR',sub2ind(cubeDim,3,3,1));
cst = addStructure(cst,'Upper pallet','OAR',sub2ind(cubeDim,3,3,2));
cst = addStructure(cst,'Lower pallet Radixact','OAR',sub2ind(cubeDim,3,3,3));
cst = addStructure(cst,'HOTSPOT F1','OAR',sub2ind(cubeDim,3,3,4));
cst = addStructure(cst,'Aux','OAR',sub2ind(cubeDim,3,3,5));
cst = addStructure(cst,'Loc','OAR',sub2ind(cubeDim,4,4,1));
cst = addStructure(cst,'Iso','OAR',sub2ind(cubeDim,4,4,2));
cst = addStructure(cst,'DSCP','OAR',sub2ind(cubeDim,4,4,3));
end

function cst = addStructure(cst,name,type,voxels)
ix = size(cst,1) + 1;
cst{ix,1} = ix - 1;
cst{ix,2} = name;
cst{ix,3} = type;
cst{ix,4}{1} = voxels(:);
cst{ix,5} = struct('Priority',1,'Visible',true,'visibleColor',[0 1 0]);
cst{ix,6} = {};
end

function metadata = makeSkinMetadata()
metadata = struct('name','SKIN','type','OAR','visibleColor',[1 0.5 1]);
end

function mask = makeInnerCubeMask(cubeDim,yRange,xRange,zRange)
mask = false(cubeDim);
mask(yRange,xRange,zRange) = true;
end

function voxels = makeTargetRingVoxels(cubeDim)
[x,z] = meshgrid(3:5,3:5);
y = 2 * ones(size(x));
voxels = sub2ind(cubeDim,y(:),x(:),z(:));
centerVoxel = sub2ind(cubeDim,2,4,4);
voxels(voxels == centerVoxel) = [];
end
