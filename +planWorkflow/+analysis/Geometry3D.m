classdef Geometry3D
    % Geometry3D Builds and persists the patient geometry 3D figure.

    methods (Static)
        function filePath = save(rootPath,ct,cst,analysis)
            if nargin < 4
                analysis = planWorkflow.config.Analysis.defaults();
            end
            analysis = planWorkflow.config.Analysis.normalize(analysis);
            filePath = '';
            if ~analysis.figures.save || isempty(rootPath)
                return;
            end

            cstPlot = planWorkflow.analysis.Geometry3D.plottableCst(ct,cst);
            if isempty(cstPlot)
                return;
            end

            fig = [];
            try
                outputFolder = fullfile(char(rootPath),'geometry_analysis');
                if ~isfolder(outputFolder)
                    mkdir(outputFolder);
                end

                targetFile = fullfile(outputFolder,'geometry_3d.fig');
                fig = figure('Visible', ...
                    planWorkflow.analysis.Figures.figureVisibility(analysis));
                set(fig,'Tag','planWorkflowAnalysisFigure', ...
                    'Color',[1 1 1],'Position',[10 10 720 620]);
                axesHandle = axes('Parent',fig);

                surfaceCst = ...
                    planWorkflow.analysis.Geometry3D.surfaceCst(cstPlot);
                patches = {};
                if ~isempty(surfaceCst)
                    guiCleanup = ...
                        planWorkflow.analysis.Geometry3D.temporarilyDisableMatRadGui(); %#ok<NASGU>
                    patches = matRad_plotVois3D(axesHandle,ct,surfaceCst,[]);
                end
                planWorkflow.analysis.Geometry3D.formatSurfacePatches( ...
                    surfaceCst,patches);
                skinPatches = ...
                    planWorkflow.analysis.Geometry3D.plotVoxelSkins( ...
                    axesHandle,ct,cstPlot);
                if isempty(patches) && isempty(skinPatches)
                    close(fig);
                    fig = [];
                    return;
                end
                planWorkflow.analysis.Geometry3D.formatAxes(axesHandle);
                savefig(fig,targetFile);
                filePath = targetFile;
            catch
                filePath = '';
            end

            if ~isempty(fig) && ishghandle(fig) && ...
                    (analysis.figures.closeAfterSave || isempty(filePath))
                close(fig);
            end
        end

        function cstPlot = plottableCst(ct,cst)
            cstPlot = cell(0,0);
            if ~isstruct(ct) || ~iscell(cst) || size(cst,2) < 5
                return;
            end

            cubeDim = planWorkflow.analysis.Geometry3D.cubeDim(ct);
            if isempty(cubeDim)
                return;
            end

            cstPlot = cell(0,size(cst,2));
            rowCount = 0;
            for i = 1:size(cst,1)
                [isPlottable,rowData] = ...
                    planWorkflow.analysis.Geometry3D.plottableRow( ...
                    cst(i,:),cubeDim);
                if ~isPlottable
                    continue;
                end

                rowCount = rowCount + 1;
                cstPlot(rowCount,1:size(rowData,2)) = rowData;
            end

            cstPlot = cstPlot(1:rowCount,:);
            if isempty(cstPlot)
                return;
            end
            if size(cstPlot,2) >= 8
                cstPlot = cstPlot(:,1:7);
            end
        end
    end

    methods (Static, Access = private)
        function cubeDim = cubeDim(ct)
            cubeDim = [];
            if isfield(ct,'cubeDim') && ~isempty(ct.cubeDim)
                cubeDim = double(ct.cubeDim(:)');
            elseif isfield(ct,'cubeHU') && ~isempty(ct.cubeHU)
                cubeDim = double(size(ct.cubeHU{1}));
            end

            if numel(cubeDim) ~= 3 || any(~isfinite(cubeDim)) || ...
                    any(cubeDim < 1) || any(cubeDim ~= round(cubeDim))
                cubeDim = [];
            end
        end

        function [tf,rowData] = plottableRow(rowData,cubeDim)
            tf = false;
            if isempty(rowData) || size(rowData,2) < 5
                return;
            end
            if planWorkflow.analysis.Geometry3D.isIgnored(rowData{1,3})
                return;
            end
            if isempty(rowData{1,4}) || ~iscell(rowData{1,4}) || ...
                    isempty(rowData{1,4}{1}) || ~isnumeric(rowData{1,4}{1})
                return;
            end

            voxels = unique(double(rowData{1,4}{1}(:)));
            voxelLimit = prod(cubeDim);
            validVoxels = isfinite(voxels) & voxels >= 1 & ...
                voxels <= voxelLimit & voxels == round(voxels);
            voxels = voxels(validVoxels);
            if isempty(voxels) || numel(voxels) >= voxelLimit
                return;
            end

            contours = rowData{1,4};
            contours{1} = voxels;
            rowData{1,4} = contours;
            tf = true;
        end

        function tf = isIgnored(typeName)
            if isstring(typeName) && isscalar(typeName)
                typeName = char(typeName);
            end
            tf = ischar(typeName) && strcmpi(strtrim(typeName),'IGNORED');
        end

        function cstSurface = surfaceCst(cstPlot)
            cstSurface = cstPlot;
            keep = true(size(cstPlot,1),1);
            for i = 1:size(cstPlot,1)
                keep(i) = ~planWorkflow.analysis.Geometry3D.isSkin(cstPlot{i,2});
            end
            cstSurface = cstSurface(keep,:);
        end

        function formatSurfacePatches(cstPlot,patches)
            for i = 1:numel(patches)
                if i > size(cstPlot,1) || isempty(patches{i}) || ...
                        ~ishghandle(patches{i})
                    continue;
                end

                set(patches{i},'DisplayName',char(cstPlot{i,2}), ...
                    'FaceAlpha', ...
                    planWorkflow.analysis.Geometry3D.faceAlpha(cstPlot{i,2}));
            end
        end

        function formatAxes(axesHandle)
            title(axesHandle,'Geometry 3D','Interpreter','none');
            xlabel(axesHandle,'x [mm]');
            ylabel(axesHandle,'y [mm]');
            zlabel(axesHandle,'z [mm]');
            grid(axesHandle,'on');
            axis(axesHandle,'equal');
            axis(axesHandle,'vis3d');
            view(axesHandle,3);
            set(axesHandle,'YDir','reverse','Box','on');
            try
                camlight(axesHandle,'headlight');
                lighting(axesHandle,'gouraud');
            catch
            end

            patchHandles = findobj(axesHandle,'Type','patch');
            if ~isempty(patchHandles)
                try
                    legend(axesHandle,flipud(patchHandles), ...
                        'Location','eastoutside','Interpreter','none');
                catch
                end
            end
        end

        function patches = plotVoxelSkins(axesHandle,ct,cstPlot)
            patches = gobjects(0);
            cubeDim = planWorkflow.analysis.Geometry3D.cubeDim(ct);
            spacing = planWorkflow.analysis.Geometry3D.spacing(ct);
            if isempty(cubeDim) || isempty(spacing)
                return;
            end

            wasHold = ishold(axesHandle);
            hold(axesHandle,'on');
            for i = 1:size(cstPlot,1)
                if ~planWorkflow.analysis.Geometry3D.isSkin(cstPlot{i,2})
                    continue;
                end

                [faces,vertices] = ...
                    planWorkflow.analysis.Geometry3D.voxelBoundaryMesh( ...
                    cstPlot{i,4}{1},cubeDim,spacing);
                if isempty(faces)
                    continue;
                end

                color = planWorkflow.analysis.Geometry3D.structureColor( ...
                    cstPlot{i,5});
                patches(end + 1) = patch('Faces',faces, ...
                    'Vertices',vertices, ...
                    'FaceColor',color, ...
                    'EdgeColor','none', ...
                    'FaceAlpha', ...
                    planWorkflow.analysis.Geometry3D.faceAlpha(cstPlot{i,2}), ...
                    'DisplayName',char(cstPlot{i,2}), ...
                    'Parent',axesHandle); %#ok<AGROW>
            end
            if ~wasHold
                hold(axesHandle,'off');
            end
        end

        function [faces,vertices] = voxelBoundaryMesh(voxels,cubeDim,spacing)
            mask = false(cubeDim);
            voxels = unique(double(voxels(:)));
            voxels = voxels(isfinite(voxels) & voxels >= 1 & ...
                voxels <= prod(cubeDim) & voxels == round(voxels));
            mask(voxels) = true;

            faces = zeros(0,4);
            vertices = zeros(0,3);
            directions = [ ...
                0 -1 0; ...
                0 1 0; ...
                -1 0 0; ...
                1 0 0; ...
                0 0 -1; ...
                0 0 1];
            for directionIx = 1:size(directions,1)
                offset = directions(directionIx,:);
                exposedMask = mask & ...
                    ~planWorkflow.analysis.Geometry3D.shiftMask(mask,offset);
                exposedVoxels = find(exposedMask);
                if isempty(exposedVoxels)
                    continue;
                end

                [directionFaces,directionVertices] = ...
                    planWorkflow.analysis.Geometry3D.voxelFaces( ...
                    exposedVoxels,cubeDim,spacing,offset);
                directionFaces = directionFaces + size(vertices,1);
                vertices = [vertices; directionVertices]; %#ok<AGROW>
                faces = [faces; directionFaces]; %#ok<AGROW>
            end
        end

        function [faces,vertices] = voxelFaces(voxels,cubeDim,spacing,offset)
            [row,column,slice] = ind2sub(cubeDim,voxels);
            centers = [column(:) * spacing(1), ...
                row(:) * spacing(2),slice(:) * spacing(3)];
            halfSpacing = spacing / 2;
            vertexOffsets = ...
                planWorkflow.analysis.Geometry3D.faceVertexOffsets( ...
                offset,halfSpacing);

            faceCount = numel(voxels);
            vertices = zeros(faceCount * 4,3);
            faces = reshape(1:(faceCount * 4),4,faceCount)';
            for i = 1:faceCount
                vertexRows = (i - 1) * 4 + (1:4);
                vertices(vertexRows,:) = centers(i,:) + vertexOffsets;
            end
        end

        function offsets = faceVertexOffsets(offset,halfSpacing)
            hx = halfSpacing(1);
            hy = halfSpacing(2);
            hz = halfSpacing(3);
            if offset(2) < 0
                offsets = [-hx -hy -hz; -hx -hy hz; -hx hy hz; -hx hy -hz];
            elseif offset(2) > 0
                offsets = [hx -hy -hz; hx hy -hz; hx hy hz; hx -hy hz];
            elseif offset(1) < 0
                offsets = [-hx -hy -hz; hx -hy -hz; hx -hy hz; -hx -hy hz];
            elseif offset(1) > 0
                offsets = [-hx hy -hz; -hx hy hz; hx hy hz; hx hy -hz];
            elseif offset(3) < 0
                offsets = [-hx -hy -hz; -hx hy -hz; hx hy -hz; hx -hy -hz];
            else
                offsets = [-hx -hy hz; hx -hy hz; hx hy hz; -hx hy hz];
            end
        end

        function shiftedMask = shiftMask(mask,offset)
            shiftedMask = false(size(mask));

            [srcY,dstY] = ...
                planWorkflow.analysis.Geometry3D.shiftedRanges( ...
                size(mask,1),offset(1));
            [srcX,dstX] = ...
                planWorkflow.analysis.Geometry3D.shiftedRanges( ...
                size(mask,2),offset(2));
            [srcZ,dstZ] = ...
                planWorkflow.analysis.Geometry3D.shiftedRanges( ...
                size(mask,3),offset(3));

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

        function spacing = spacing(ct)
            spacing = [];
            if isfield(ct,'resolution') && ...
                    all(isfield(ct.resolution,{'x','y','z'}))
                spacing = [ct.resolution.x ct.resolution.y ct.resolution.z];
            end
            if isempty(spacing) || numel(spacing) ~= 3 || ...
                    any(~isfinite(spacing)) || any(spacing <= 0)
                spacing = [];
            end
        end

        function alpha = faceAlpha(name)
            name = upper(strtrim(char(name)));
            if any(strcmp(name,{'BODY','EXTERNAL'}))
                alpha = 0.12;
            elseif strcmp(name,'SKIN')
                alpha = 0.25;
            else
                alpha = 0.45;
            end
        end

        function tf = isSkin(name)
            tf = strcmpi(strtrim(char(name)),'SKIN');
        end

        function color = structureColor(properties)
            color = [1 0.501960784313726 1];
            if isstruct(properties) && isfield(properties,'visibleColor') && ...
                    isnumeric(properties.visibleColor) && ...
                    numel(properties.visibleColor) == 3
                color = double(properties.visibleColor(:)');
            end
        end

        function cleanupObj = temporarilyDisableMatRadGui()
            cleanupObj = [];
            if exist('MatRad_Config','class') ~= 8
                return;
            end

            try
                cfg = MatRad_Config.instance();
                previousDisableGui = cfg.disableGUI;
                cfg.disableGUI = true;
                cleanupObj = onCleanup( ...
                    @() planWorkflow.analysis.Geometry3D.restoreMatRadGui( ...
                    cfg,previousDisableGui));
            catch
                cleanupObj = [];
            end
        end

        function restoreMatRadGui(cfg,previousDisableGui)
            try
                cfg.disableGUI = previousDisableGui;
            catch
            end
        end
    end
end
