function tests = testGeometry3D
tests = functiontests(localfunctions);
end

function testSaveGeometry3DFigureCreatesFileAndPreservesCst(testCase)
fixture = testCase.applyFixture( ...
    matlab.unittest.fixtures.TemporaryFolderFixture);
ct = makeCt([7 7 7]);
cst = makeGeometryCst(ct.cubeDim);
originalCst = cst;
analysis = makeFigureAnalysis(true);

filePath = planWorkflow.analysis.Geometry3D.save( ...
    fixture.Folder,ct,cst,analysis);

verifyEqual(testCase,filePath, ...
    fullfile(fixture.Folder,'geometry_analysis','geometry_3d.fig'));
verifyTrue(testCase,isfile(filePath));
verifyEqual(testCase,cst,originalCst);
verifyEqual(testCase,size(cst,2),6);

fig = openfig(filePath,'new','invisible');
cleanupFig = onCleanup(@() closeFigure(fig));
axesHandles = findall(fig,'Type','axes');

verifyNotEmpty(testCase,axesHandles);
verifyTrue(testCase,any(strcmp(axesTitles(axesHandles),'Geometry 3D')));
end

function testSaveGeometry3DPlotsSkinVoxelExactly(testCase)
fixture = testCase.applyFixture( ...
    matlab.unittest.fixtures.TemporaryFolderFixture);
ct = makeCt([7 7 7]);
cst = makeSingleVoxelSkinCst(ct.cubeDim);
analysis = makeFigureAnalysis(true);

filePath = planWorkflow.analysis.Geometry3D.save( ...
    fixture.Folder,ct,cst,analysis);

fig = openfig(filePath,'new','invisible');
cleanupFig = onCleanup(@() closeFigure(fig));
skinPatch = findobj(fig,'Type','patch','DisplayName','SKIN');
vertices = unique(get(skinPatch(1),'Vertices'),'rows');
faces = get(skinPatch(1),'Faces');

verifyNotEmpty(testCase,skinPatch);
verifyEqual(testCase,size(faces,1),6);
verifyEqual(testCase,unique(vertices(:,1))',[3.5 4.5]);
verifyEqual(testCase,unique(vertices(:,2))',[3.5 4.5]);
verifyEqual(testCase,unique(vertices(:,3))',[3.5 4.5]);
end

function testSaveGeometry3DRespectsSaveFalse(testCase)
fixture = testCase.applyFixture( ...
    matlab.unittest.fixtures.TemporaryFolderFixture);
ct = makeCt([7 7 7]);
cst = makeGeometryCst(ct.cubeDim);
analysis = makeFigureAnalysis(false);

filePath = planWorkflow.analysis.Geometry3D.save( ...
    fixture.Folder,ct,cst,analysis);

verifyEmpty(testCase,filePath);
verifyFalse(testCase,isfolder( ...
    fullfile(fixture.Folder,'geometry_analysis')));
end

function ct = makeCt(cubeDim)
ct = struct();
ct.cubeDim = cubeDim;
ct.resolution = struct('x',1,'y',1,'z',1);
end

function cst = makeGeometryCst(cubeDim)
cst = cell(0,6);
bodyMask = false(cubeDim);
bodyMask(2:6,2:6,:) = true;
cst = addStructure(cst,'BODY','OAR',find(bodyMask),[0.8 0.8 0.8]);

targetMask = false(cubeDim);
targetMask(3:5,3:5,3:5) = true;
cst = addStructure(cst,'CTV','TARGET',find(targetMask),[1 0 0]);

ignoredMask = false(cubeDim);
ignoredMask(1,1,1) = true;
cst = addStructure(cst,'IGNORED HELP','IGNORED',find(ignoredMask),[0 0 0]);
end

function cst = makeSingleVoxelSkinCst(cubeDim)
cst = cell(0,6);
bodyMask = false(cubeDim);
bodyMask(2:6,2:6,2:6) = true;
cst = addStructure(cst,'BODY','OAR',find(bodyMask),[0.8 0.8 0.8]);
cst = addStructure(cst,'SKIN','OAR',sub2ind(cubeDim,4,4,4), ...
    [1 0.501960784313726 1]);
end

function cst = addStructure(cst,name,type,voxels,color)
ix = size(cst,1) + 1;
cst{ix,1} = ix - 1;
cst{ix,2} = name;
cst{ix,3} = type;
cst{ix,4}{1} = voxels(:);
cst{ix,5} = struct('Priority',1,'Visible',true,'visibleColor',color);
cst{ix,6} = {};
end

function analysis = makeFigureAnalysis(saveFigures)
analysis = planWorkflow.config.Analysis.defaults();
analysis.figures.save = saveFigures;
analysis.figures.visible = 'off';
analysis.figures.closeAfterSave = true;
end

function titles = axesTitles(axesHandles)
titles = cell(numel(axesHandles),1);
for i = 1:numel(axesHandles)
    titleText = get(get(axesHandles(i),'Title'),'String');
    if iscell(titleText)
        titleText = strjoin(titleText,newline);
    end
    titles{i} = char(titleText);
end
end

function closeFigure(fig)
if ~isempty(fig) && ishghandle(fig)
    close(fig);
end
end
