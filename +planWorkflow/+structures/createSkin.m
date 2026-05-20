function [cst,ixSkin,skinInfo] = createSkin(ixBody,cst,ct,metadata,varargin)
% createSkin creates a patient-surface skin VOI.
%
% call
%   [cst,ixSkin,skinInfo] = planWorkflow.structures.createSkin(ixBody,cst,ct,metadata)
%   [cst,ixSkin,skinInfo] = planWorkflow.structures.createSkin(ixBody,cst,ct,metadata,'mode','targetRegion','targetIndex',ixTarget,'targetDistanceMm',distanceMm)
%
% input
%   ixBody:   row index of the body/external VOI in the cst struct
%   cst:      matRad cst struct
%   ct:       matRad ct struct with cubeDim and resolution fields
%   metadata: struct with fields name, type and visibleColor for the created
%             skin VOI
%
% name-value input
%   mode:               'full' or 'targetRegion' (default: 'full')
%   targetIndex:        target row index required for targetRegion mode
%   thicknessMm:        optional skin shell thickness in mm (default: one voxel)
%   targetDistanceMm:   maximum target-to-skin distance in mm in targetRegion
%                       mode (default: 30)
%   connectivity:      voxel connectivity, one of 6, 18, or 26 (default: 26)
%   excludeCtBoundaryZ: remove skin voxels on the first and last CT slice
%                       (default: false)
%
%   targetRegion mode selects skin voxels within targetDistanceMm from the
%   target, keeps one connected component per target, and fills holes on that
%   skin surface component.
%
% output
%   cst:      updated matRad cst struct
%   ixSkin:   row index of the created skin VOI
%   skinInfo: struct with full and selected skin voxel indices per scenario

options = parseOptions(varargin{:});
validateInputs(ixBody,cst,ct,metadata,options);

cubeDim = getCubeDim(ct);
spacing = getVoxelSpacingByDimension(ct);
nScen = numel(cst{ixBody,4});

skinInfo = struct();
skinInfo.mode = options.mode;
skinInfo.targetDistanceMm = options.targetDistanceMm;
skinInfo.fullVoxels = cell(1,nScen);
skinInfo.selectedVoxels = cell(1,nScen);
skinInfo.anchorVoxel = cell(1,nScen);
skinInfo.candidateVoxels = cell(1,nScen);
skinInfo.boundaryPolicy = 'inVolumeAirOnly';
skinInfo.excludeCtBoundaryZ = options.excludeCtBoundaryZ;

for scen = 1:nScen
    bodyVoxels = getScenarioVoxels(cst,ixBody,scen);
    bodyMask = false(cubeDim);
    bodyMask(bodyVoxels) = true;

    skinMask = createSurfaceMask(bodyMask,spacing,options);
    if options.excludeCtBoundaryZ
        skinMask = removeCtBoundaryZ(skinMask);
    end
    fullSkinVoxels = find(skinMask);

    switch options.mode
        case 'full'
            selectedSkinVoxels = fullSkinVoxels;
            anchorVoxel = [];
        case 'targetRegion'
            targetVoxels = getScenarioVoxels(cst,options.targetIndex,scen);
            [selectedSkinVoxels,anchorVoxel,candidateSkinVoxels] = ...
                selectTargetRegion(skinMask,targetVoxels,cubeDim,spacing,options);
    end

    skinInfo.fullVoxels{scen} = fullSkinVoxels;
    skinInfo.selectedVoxels{scen} = selectedSkinVoxels;
    skinInfo.anchorVoxel{scen} = anchorVoxel;
    if strcmp(options.mode,'targetRegion')
        skinInfo.candidateVoxels{scen} = candidateSkinVoxels;
    else
        skinInfo.candidateVoxels{scen} = fullSkinVoxels;
    end
end

ixSkin = size(cst,1) + 1;
cst{ixSkin,1} = cst{end,1} + 1;
cst{ixSkin,2} = metadata.name;
cst{ixSkin,3} = metadata.type;
cst{ixSkin,4} = skinInfo.selectedVoxels;
cst{ixSkin,5} = cst{ixBody,5};
cst{ixSkin,5}.visibleColor = metadata.visibleColor;

if size(cst,2) >= 6
    cst{ixSkin,6} = {};
end

end

function options = parseOptions(varargin)

p = inputParser;
addParameter(p,'mode','full',@(v) ischar(v) || isstring(v));
addParameter(p,'targetIndex',[],@(v) isempty(v) || ...
    (isnumeric(v) && isscalar(v) && isfinite(v)));
addParameter(p,'thicknessMm',[],@(v) isempty(v) || isValidPositiveSize(v));
addParameter(p,'targetDistanceMm',30,@(v) isnumeric(v) && isscalar(v) && ...
    isfinite(v) && v > 0);
addParameter(p,'connectivity',26,@(v) isnumeric(v) && isscalar(v) && ...
    any(v == [6 18 26]));
addParameter(p,'excludeCtBoundaryZ',false,@isValidLogicalScalar);
parse(p,varargin{:});

options = p.Results;
options.mode = validatestring(char(options.mode),{'full','targetRegion'});
options.excludeCtBoundaryZ = logical(options.excludeCtBoundaryZ);

end

function validateInputs(ixBody,cst,ct,metadata,options)

if ~iscell(cst) || size(cst,2) < 5
    error('planWorkflow:structures:createSkin:InvalidCst', ...
        'cst must be a matRad cst cell array with at least five columns.');
end

validateStructureIndex(ixBody,cst,'ixBody');

if ~isfield(ct,'cubeDim') && ~isfield(ct,'cubeHU')
    error('planWorkflow:structures:createSkin:InvalidCt', ...
        'ct must contain cubeDim or cubeHU.');
end

requiredFields = {'name','type','visibleColor'};
for i = 1:numel(requiredFields)
    if ~isstruct(metadata) || ~isfield(metadata,requiredFields{i})
        error('planWorkflow:structures:createSkin:InvalidMetadata', ...
            'metadata must contain name, type, and visibleColor fields.');
    end
end

if strcmp(options.mode,'targetRegion')
    validateStructureIndex(options.targetIndex,cst,'targetIndex');
end

end

function validateStructureIndex(index,cst,indexName)

if ~isnumeric(index) || ~isscalar(index) || ~isfinite(index) || ...
        index < 1 || index ~= round(index) || index > size(cst,1)
    error('planWorkflow:structures:createSkin:InvalidStructureIndex', ...
        '%s must be a valid row index in cst.',indexName);
end

if size(cst,2) < 4 || isempty(cst{index,4}) || ~iscell(cst{index,4})
    error('planWorkflow:structures:createSkin:MissingVoxels', ...
        'cst{%d,4} must contain scenario voxel indices.',index);
end

end

function cubeDim = getCubeDim(ct)

if isfield(ct,'cubeDim') && ~isempty(ct.cubeDim)
    cubeDim = double(ct.cubeDim);
elseif isfield(ct,'cubeHU') && ~isempty(ct.cubeHU)
    cubeDim = size(ct.cubeHU{1});
else
    error('planWorkflow:structures:createSkin:InvalidCt', ...
        'ct must contain cubeDim or cubeHU.');
end

end

function spacing = getVoxelSpacingByDimension(ct)

if isfield(ct,'resolution') && all(isfield(ct.resolution,{'x','y','z'}))
    spacing = [ct.resolution.y ct.resolution.x ct.resolution.z];
else
    spacing = [1 1 1];
end

end

function voxels = getScenarioVoxels(cst,index,scen)

contours = cst{index,4};
if numel(contours) >= scen
    voxels = contours{scen};
elseif isscalar(contours)
    voxels = contours{1};
else
    error('planWorkflow:structures:createSkin:MissingScenario', ...
        'cst{%d,4} does not contain scenario %d.',index,scen);
end

voxels = unique(voxels(:));

end

function surfaceMask = createSurfaceMask(bodyMask,spacing,options)

offsets = createErosionOffsets(spacing,options);
erodedMask = erodeMask(bodyMask,offsets);
surfaceMask = bodyMask & ~erodedMask;

end

function mask = removeCtBoundaryZ(mask)

if size(mask,3) < 1
    return;
end

mask(:,:,1) = false;
mask(:,:,end) = false;

end

function offsets = createErosionOffsets(spacing,options)

if isempty(options.thicknessMm)
    offsets = createConnectivityOffsets(options.connectivity);
    return;
end

radius = getRadiusByDimension(options.thicknessMm);
maxOffset = ceil(radius ./ spacing);
offsets = [];

for dy = -maxOffset(1):maxOffset(1)
    for dx = -maxOffset(2):maxOffset(2)
        for dz = -maxOffset(3):maxOffset(3)
            if dy == 0 && dx == 0 && dz == 0
                continue;
            end

            normalizedDistance = ((dy * spacing(1)) / radius(1))^2 + ...
                ((dx * spacing(2)) / radius(2))^2 + ...
                ((dz * spacing(3)) / radius(3))^2;
            if normalizedDistance <= 1
                offsets(end+1,:) = [dy dx dz]; %#ok<AGROW>
            end
        end
    end
end

end

function radius = getRadiusByDimension(thicknessMm)

if isstruct(thicknessMm)
    if ~all(isfield(thicknessMm,{'x','y','z'}))
        error('planWorkflow:structures:createSkin:InvalidThickness', ...
            'thicknessMm struct must contain x, y, and z fields.');
    end
    radius = [thicknessMm.y thicknessMm.x thicknessMm.z];
elseif isscalar(thicknessMm)
    radius = repmat(double(thicknessMm),1,3);
elseif isnumeric(thicknessMm) && numel(thicknessMm) == 3
    thicknessMm = double(thicknessMm(:)');
    radius = [thicknessMm(2) thicknessMm(1) thicknessMm(3)];
else
    error('planWorkflow:structures:createSkin:InvalidThickness', ...
        'thicknessMm must be a positive scalar, [x y z] vector, or struct.');
end

if any(radius <= 0)
    error('planWorkflow:structures:createSkin:InvalidThickness', ...
        'thicknessMm values must be positive.');
end

end

function tf = isValidPositiveSize(value)

if isstruct(value)
    tf = all(isfield(value,{'x','y','z'})) && ...
        all([value.x value.y value.z] > 0);
else
    tf = isnumeric(value) && all(isfinite(value(:))) && ...
        (isscalar(value) || numel(value) == 3) && all(value(:) > 0);
end

end

function tf = isValidLogicalScalar(value)

tf = (islogical(value) || isnumeric(value)) && isscalar(value) && ...
    isfinite(value) && (value == 0 || value == 1);

end

function offsets = createConnectivityOffsets(connectivity)

offsets = [];
for dy = -1:1
    for dx = -1:1
        for dz = -1:1
            cityBlockDistance = abs(dy) + abs(dx) + abs(dz);
            if cityBlockDistance == 0
                continue;
            end
            if connectivity == 6 && cityBlockDistance > 1
                continue;
            end
            if connectivity == 18 && cityBlockDistance > 2
                continue;
            end
            offsets(end+1,:) = [dy dx dz]; %#ok<AGROW>
        end
    end
end

end

function erodedMask = erodeMask(mask,offsets)

erodedMask = mask;
for i = 1:size(offsets,1)
    [shiftedMask,inVolumeMask] = shiftMaskInVolume(mask,offsets(i,:));
    erodedMask = erodedMask & (~inVolumeMask | shiftedMask);
end

end

function [shiftedMask,inVolumeMask] = shiftMaskInVolume(mask,offset)

shiftedMask = false(size(mask));
inVolumeMask = false(size(mask));

[srcY,dstY] = shiftedRanges(size(mask,1),offset(1));
[srcX,dstX] = shiftedRanges(size(mask,2),offset(2));
[srcZ,dstZ] = shiftedRanges(size(mask,3),offset(3));

shiftedMask(dstY,dstX,dstZ) = mask(srcY,srcX,srcZ);
inVolumeMask(dstY,dstX,dstZ) = true;

end

function shiftedMask = shiftMask(mask,offset)

shiftedMask = false(size(mask));

[srcY,dstY] = shiftedRanges(size(mask,1),offset(1));
[srcX,dstX] = shiftedRanges(size(mask,2),offset(2));
[srcZ,dstZ] = shiftedRanges(size(mask,3),offset(3));

shiftedMask(dstY,dstX,dstZ) = mask(srcY,srcX,srcZ);

end

function [sourceRange,destinationRange] = shiftedRanges(n,delta)

if delta >= 0
    sourceRange = 1:(n - delta);
    destinationRange = (1 + delta):n;
else
    sourceRange = (1 - delta):n;
    destinationRange = 1:(n + delta);
end

end

function [selectedSkinVoxels,anchorVoxel,candidateSkinVoxels] = ...
    selectTargetRegion(skinMask,targetVoxels,cubeDim,spacing,options)

if ~any(skinMask(:)) || isempty(targetVoxels)
    selectedSkinVoxels = [];
    anchorVoxel = [];
    candidateSkinVoxels = [];
    return;
end

targetMask = false(cubeDim);
targetMask(targetVoxels) = true;
targetNeighborhoodMask = dilateMaskByDistance( ...
    targetMask,spacing,options.targetDistanceMm);
candidateMask = skinMask & targetNeighborhoodMask;
candidateSkinVoxels = find(candidateMask);

if isempty(candidateSkinVoxels)
    selectedSkinVoxels = [];
    anchorVoxel = [];
    return;
end

candidateCoordinates = voxelCoordinatesMm(candidateSkinVoxels,cubeDim,spacing);
targetCoordinates = voxelCoordinatesMm(targetVoxels,cubeDim,spacing);
distanceToTarget = minDistanceToPoints(candidateCoordinates,targetCoordinates);

[~,anchorPosition] = min(distanceToTarget);
anchorVoxel = candidateSkinVoxels(anchorPosition);

connectedMask = keepConnectedComponent(candidateMask,anchorVoxel, ...
    options.connectivity);
connectedMask = fillSurfaceHoles(connectedMask,skinMask,options.connectivity);
selectedSkinVoxels = find(connectedMask);

end

function dilatedMask = dilateMaskByDistance(mask,spacing,distanceMm)

offsets = createDistanceOffsets(spacing,distanceMm,true);
dilatedMask = false(size(mask));

for i = 1:size(offsets,1)
    dilatedMask = dilatedMask | shiftMask(mask,offsets(i,:));
end

end

function offsets = createDistanceOffsets(spacing,distanceMm,includeOrigin)

maxOffset = ceil(distanceMm ./ spacing);
offsets = [];

for dy = -maxOffset(1):maxOffset(1)
    for dx = -maxOffset(2):maxOffset(2)
        for dz = -maxOffset(3):maxOffset(3)
            if ~includeOrigin && dy == 0 && dx == 0 && dz == 0
                continue;
            end

            distance = sqrt((dy * spacing(1))^2 + ...
                (dx * spacing(2))^2 + (dz * spacing(3))^2);
            if distance <= distanceMm
                offsets(end+1,:) = [dy dx dz]; %#ok<AGROW>
            end
        end
    end
end

end

function distances = minDistanceToPoints(points,referencePoints)

blockSize = 500;
distancesSquared = inf(size(points,1),1);

for firstRef = 1:blockSize:size(referencePoints,1)
    lastRef = min(size(referencePoints,1),firstRef + blockSize - 1);
    refBlock = referencePoints(firstRef:lastRef,:);
    for pointIx = 1:size(points,1)
        delta = refBlock - points(pointIx,:);
        distancesSquared(pointIx) = min(distancesSquared(pointIx), ...
            min(sum(delta.^2,2)));
    end
end

distances = sqrt(distancesSquared);

end

function componentMask = keepConnectedComponent(mask,anchorVoxel,connectivity)

componentMask = false(size(mask));
if isempty(anchorVoxel) || ~mask(anchorVoxel)
    return;
end

offsets = createConnectivityOffsets(connectivity);
queue = anchorVoxel;
componentMask(anchorVoxel) = true;
mask(anchorVoxel) = false;
queuePosition = 1;

while queuePosition <= numel(queue)
    voxel = queue(queuePosition);
    queuePosition = queuePosition + 1;
    [y,x,z] = ind2sub(size(mask),voxel);

    for i = 1:size(offsets,1)
        neighborY = y + offsets(i,1);
        neighborX = x + offsets(i,2);
        neighborZ = z + offsets(i,3);
        if neighborY < 1 || neighborY > size(mask,1) || ...
                neighborX < 1 || neighborX > size(mask,2) || ...
                neighborZ < 1 || neighborZ > size(mask,3)
            continue;
        end

        neighborVoxel = sub2ind(size(mask),neighborY,neighborX,neighborZ);
        if mask(neighborVoxel)
            mask(neighborVoxel) = false;
            componentMask(neighborVoxel) = true;
            queue(end+1,1) = neighborVoxel; %#ok<AGROW>
        end
    end
end

end

function selectedMask = fillSurfaceHoles(selectedMask,skinMask,connectivity)

remainingMask = skinMask & ~selectedMask;
components = getConnectedComponents(remainingMask,connectivity);
if numel(components) <= 1
    return;
end

componentSizes = cellfun(@numel,components);
[~,outsideIx] = max(componentSizes);

for i = 1:numel(components)
    if i ~= outsideIx
        selectedMask(components{i}) = true;
    end
end

end

function components = getConnectedComponents(mask,connectivity)

components = {};
while any(mask(:))
    seed = find(mask,1);
    componentMask = keepConnectedComponent(mask,seed,connectivity);
    componentVoxels = find(componentMask);
    components{end+1} = componentVoxels; %#ok<AGROW>
    mask(componentVoxels) = false;
end

end

function coordinates = voxelCoordinatesMm(voxels,cubeDim,spacing)

[y,x,z] = ind2sub(cubeDim,voxels);
coordinates = [double(y(:)) * spacing(1), ...
    double(x(:)) * spacing(2), ...
    double(z(:)) * spacing(3)];

end
