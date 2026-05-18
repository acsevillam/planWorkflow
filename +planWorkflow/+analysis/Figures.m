classdef Figures
    % Figures Sampling-analysis figure generation and persistence.

    methods (Static)
        function figureFiles = saveSamplingAnalysisFigures(analysisFolder,label, ...
                figures,samplingData,sample,analysis,doseStat,meta)
            analysis = planWorkflow.config.Analysis.normalize(analysis);
            if nargin < 7
                doseStat = struct();
            end
            if nargin < 8
                meta = struct();
            end
            if ~isfolder(analysisFolder)
                mkdir(analysisFolder);
            end

            meanFig = planWorkflow.analysis.Figures.figureField( ...
                figures,'mean');
            stdFig = planWorkflow.analysis.Figures.figureField( ...
                figures,'std');
            nominalFig = planWorkflow.analysis.Figures.figureField( ...
                figures,'nominal');
            robustnessIndex1Fig = planWorkflow.analysis.Figures.figureField( ...
                figures,'robustness','index1');
            robustnessIndex2Fig = planWorkflow.analysis.Figures.figureField( ...
                figures,'robustness','index2');
            doseDifferenceFig = ...
                planWorkflow.analysis.Figures.figureField( ...
                figures,'doseDifference');

            figureFiles = struct( ...
                'robustness1','', ...
                'robustness2','', ...
                'meanDose','', ...
                'stdDose','', ...
                'nominalDose','', ...
                'expectedDoseDifference','', ...
                'dvhMultiscenario','', ...
                'dvhTrustband','');
            planWorkflow.analysis.Figures.annotatePlanFigureTitle( ...
                meanFig,label);
            planWorkflow.analysis.Figures.annotatePlanFigureTitle( ...
                stdFig,label);
            planWorkflow.analysis.Figures.annotatePlanFigureTitle( ...
                nominalFig,label);
            planWorkflow.analysis.Figures.annotatePlanFigureTitle( ...
                robustnessIndex1Fig,label);
            planWorkflow.analysis.Figures.annotatePlanFigureTitle( ...
                robustnessIndex2Fig,label);
            planWorkflow.analysis.Figures.annotatePlanFigureTitle( ...
                doseDifferenceFig,label);
            planWorkflow.analysis.Figures.installSamplingSliceControls( ...
                figures,samplingData,sample,analysis,doseStat,meta,label);
            if ~analysis.figures.save
                planWorkflow.analysis.Figures.saveFigureIfValid( ...
                    meanFig,'',analysis);
                planWorkflow.analysis.Figures.saveFigureIfValid( ...
                    stdFig,'',analysis);
                planWorkflow.analysis.Figures.saveFigureIfValid( ...
                    nominalFig,'',analysis);
                planWorkflow.analysis.Figures.saveFigureIfValid( ...
                    robustnessIndex1Fig,'',analysis);
                planWorkflow.analysis.Figures.saveFigureIfValid( ...
                    robustnessIndex2Fig,'',analysis);
                planWorkflow.analysis.Figures.saveFigureIfValid( ...
                    doseDifferenceFig,'',analysis);
                return;
            end
            evaluationScale = planWorkflow.analysis.Figures.evaluationScale( ...
                sample.pln,analysis);
            figureFiles.meanDose = planWorkflow.analysis.Figures.saveFigureIfValid( ...
                meanFig,fullfile(analysisFolder,[label '_mean_dose.fig']), ...
                analysis);
            figureFiles.stdDose = planWorkflow.analysis.Figures.saveFigureIfValid( ...
                stdFig,fullfile(analysisFolder,[label '_std_dose.fig']), ...
                analysis);
            figureFiles.nominalDose = planWorkflow.analysis.Figures.saveFigureIfValid( ...
                nominalFig,fullfile(analysisFolder,[label '_nominal_dose.fig']), ...
                analysis);
            figureFiles.robustness1 = planWorkflow.analysis.Figures.saveFigureIfValid( ...
                robustnessIndex1Fig,fullfile(analysisFolder,[label '_robustness1.fig']), ...
                analysis);
            figureFiles.robustness2 = planWorkflow.analysis.Figures.saveFigureIfValid( ...
                robustnessIndex2Fig,fullfile(analysisFolder,[label '_robustness2.fig']), ...
                analysis);
            figureFiles.expectedDoseDifference = ...
                planWorkflow.analysis.Figures.saveFigureIfValid( ...
                doseDifferenceFig,fullfile(analysisFolder, ...
                [label '_expected_dose_difference.fig']),analysis);
            figureFiles.dvhMultiscenario = ...
                planWorkflow.analysis.Figures.saveSamplingDvhFigure( ...
                samplingData.cst,sample,evaluationScale, ...
                analysis.doseWindowDvh, ...
                'multiscenario', ...
                fullfile(analysisFolder,[label '_dvh_multiscenario.fig']), ...
                'Sampled multi-scenario DVH',analysis,label);
            figureFiles.dvhTrustband = ...
                planWorkflow.analysis.Figures.saveSamplingDvhFigure( ...
                samplingData.cst,sample,evaluationScale, ...
                analysis.doseWindowDvh, ...
                'trustband', ...
                fullfile(analysisFolder,[label '_dvh_trustband.fig']), ...
                'Sampled DVH trust band',analysis,label);
        end

        function filePath = saveFigureIfValid(fig,filePath,analysis)
            if nargin < 3
                analysis = planWorkflow.config.Analysis.defaults();
            end
            analysis = planWorkflow.config.Analysis.normalize(analysis);
            if isempty(fig) || ~ishghandle(fig)
                filePath = '';
                return;
            end

            try
                set(fig,'Tag','planWorkflowAnalysisFigure');
            catch
            end
            if analysis.figures.save
                savefig(fig,filePath);
            else
                filePath = '';
            end
            if analysis.figures.closeAfterSave
                close(fig);
            end
        end

        function filePath = saveSamplingDvhFigure(cst,sample,evaluationScale, ...
                doseWindow,dvhType,filePath,titleText,analysis,label)
            if nargin < 8
                analysis = planWorkflow.config.Analysis.defaults();
            end
            if nargin < 9
                label = '';
            end
            if isempty(sample.caSamp)
                filePath = '';
                return;
            end

            fig = figure('Visible', ...
                planWorkflow.analysis.Figures.figureVisibility(analysis));
            set(fig,'Tag','planWorkflowAnalysisFigure');
            set(fig,'Color',[1 1 1],'Position',[10 10 600 400]);
            scenarios = 1:numel(sample.caSamp);
            matRad_showDVHFromSampling(sample.caSamp,evaluationScale,cst,sample.pln, ...
                scenarios,doseWindow,dvhType,1);
            title(titleText,'Interpreter','none');
            planWorkflow.analysis.Figures.annotatePlanFigureTitle(fig,label);

            filePath = planWorkflow.analysis.Figures.saveFigureIfValid( ...
                fig,filePath,analysis);
        end

        function annotatePlanFigureTitle(fig,label)
            if isempty(fig) || ~ishghandle(fig)
                return;
            end

            axesHandle = planWorkflow.analysis.Figures.primaryAxes(fig);
            if isempty(axesHandle)
                return;
            end

            titleHandle = get(axesHandle,'Title');
            titleLines = planWorkflow.analysis.Figures.titleLines( ...
                get(titleHandle,'String'));
            titleLines = ...
                planWorkflow.analysis.Figures.removePlanRobustnessTitleLines( ...
                titleLines,label);
            titleLines{end + 1,1} = ...
                planWorkflow.analysis.Figures.planRobustnessTitleLine(label);
            title(axesHandle,titleLines,'Interpreter','none');
        end

        function titleText = planRobustnessTitleLine(label)
            titleText = planWorkflow.analysis.Figures.humanizePlanRobustnessLabel( ...
                label);
        end

        function labelText = humanizePlanRobustnessLabel(label)
            if isempty(label)
                labelText = 'unspecified plan';
                return;
            end

            labelText = strtrim(char(label));
            if isempty(labelText)
                labelText = 'unspecified plan';
                return;
            end

            switch lower(labelText)
                case 'reference'
                    labelText = 'Reference plan';
                case 'nominal'
                    labelText = 'Nominal plan';
                otherwise
                    labelText = regexprep(labelText,'_+',' ');
            end
        end

        function varargout = withFigurePolicy(analysis,fn)
            analysis = planWorkflow.config.Analysis.normalize(analysis);
            previousVisible = get(0,'DefaultFigureVisible');
            cleanup = onCleanup(@() set(0,'DefaultFigureVisible', ...
                previousVisible));
            set(0,'DefaultFigureVisible', ...
                planWorkflow.analysis.Figures.figureVisibility(analysis));
            if nargout > 0
                [varargout{1:nargout}] = fn();
            else
                fn();
            end
            clear cleanup;
        end

        function visible = figureVisibility(analysis)
            analysis = planWorkflow.config.Analysis.normalize(analysis);
            switch char(analysis.figures.visible)
                case 'on'
                    visible = 'on';
                case 'off'
                    visible = 'off';
                otherwise
                    if planWorkflow.analysis.Figures.hasInteractiveFigureSession()
                        visible = 'on';
                    else
                        visible = 'off';
                    end
            end
        end

        function tf = shouldShowPlanAnalysisFigures(analysis)
            analysis = planWorkflow.config.Analysis.normalize(analysis);
            tf = strcmp(char(analysis.figures.visible),'on') && ...
                planWorkflow.analysis.Figures.hasInteractiveFigureSession();
        end

        function closeWorkflowFigures()
            figs = findall(0,'Type','figure','Tag','planWorkflowAnalysisFigure');
            for i = 1:numel(figs)
                try
                    close(figs(i));
                catch
                end
            end
        end

        function scale = evaluationScale(pln,analysis)
            scale = matRad_convertToEvaluationMode(1,pln,analysis.evaluationMode);
        end

        function updateSliceFigure(source,~)
            fig = ancestor(source,'figure');
            if isempty(fig) || ~ishghandle(fig) || ...
                    ~isappdata(fig,'planWorkflowSlicePayload')
                return;
            end
            payload = getappdata(fig,'planWorkflowSlicePayload');
            slice = round(get(source,'Value'));
            planWorkflow.analysis.Figures.redrawSliceFigure( ...
                fig,payload,slice);
        end

        function redrawSliceFigure(fig,payload,slice)
            if isempty(fig) || ~ishghandle(fig) || ~isstruct(payload)
                return;
            end
            slice = planWorkflow.analysis.Figures.clampSlice( ...
                slice,payload.sliceMax);
            payload.slice = slice;
            setappdata(fig,'planWorkflowSlicePayload',payload);
            planWorkflow.analysis.Figures.updateSliceControlValues( ...
                fig,payload);

            axesHandle = planWorkflow.analysis.Figures.primaryAxes(fig);
            if isempty(axesHandle) || ~ishghandle(axesHandle)
                axesHandle = axes('Parent',fig);
            end
            planWorkflow.analysis.Figures.clearSpatialAxes(fig,axesHandle);

            switch char(payload.kind)
                case 'dose'
                    matRad_plotSamplingDoseCubeAnalysis( ...
                        payload.doseAnalysis,payload.doseCube, ...
                        payload.ct,payload.cst,slice, ...
                        'plane',payload.plane, ...
                        'axesHandle',axesHandle);
                case 'robustness'
                    matRad_plotSamplingRobustnessAnalysis( ...
                        payload.robustnessAnalysis,payload.ct, ...
                        payload.cst,slice, ...
                        'method',payload.method, ...
                        'plane',payload.plane, ...
                        'axesHandle',axesHandle);
                case 'expectedDoseDifference'
                    matRad_plotExpectedDoseDifferenceAnalysis( ...
                        payload.expectedDoseDifferenceAnalysis, ...
                        payload.ct,payload.cst,slice, ...
                        'plane',payload.plane, ...
                        'doseWindow',payload.doseWindow, ...
                        'displayScale',payload.displayScale, ...
                        'axesHandle',axesHandle);
            end
            planWorkflow.analysis.Figures.annotatePlanFigureTitle( ...
                fig,payload.label);
        end

    end

    methods (Static, Access = private)
        function installSamplingSliceControls(figures,samplingData,sample, ...
                analysis,doseStat,meta,label)
            if ~analysis.figures.sliceControl
                return;
            end
            commonPayload = planWorkflow.analysis.Figures.commonSlicePayload( ...
                samplingData,sample,meta,label);
            if isempty(commonPayload)
                return;
            end

            planWorkflow.analysis.Figures.installSliceControl( ...
                planWorkflow.analysis.Figures.figureField(figures,'mean'), ...
                planWorkflow.analysis.Figures.doseSlicePayload( ...
                commonPayload,doseStat,'meanAnalysis','meanCubeW'));
            planWorkflow.analysis.Figures.installSliceControl( ...
                planWorkflow.analysis.Figures.figureField(figures,'std'), ...
                planWorkflow.analysis.Figures.doseSlicePayload( ...
                commonPayload,doseStat,'stdAnalysis','stdCubeW'));
            planWorkflow.analysis.Figures.installSliceControl( ...
                planWorkflow.analysis.Figures.figureField(figures,'nominal'), ...
                planWorkflow.analysis.Figures.nominalSlicePayload( ...
                commonPayload,doseStat,sample,meta));
            planWorkflow.analysis.Figures.installSliceControl( ...
                planWorkflow.analysis.Figures.figureField( ...
                figures,'robustness','index1'), ...
                planWorkflow.analysis.Figures.robustnessSlicePayload( ...
                commonPayload,doseStat,'index1'));
            planWorkflow.analysis.Figures.installSliceControl( ...
                planWorkflow.analysis.Figures.figureField( ...
                figures,'robustness','index2'), ...
                planWorkflow.analysis.Figures.robustnessSlicePayload( ...
                commonPayload,doseStat,'index2'));
            planWorkflow.analysis.Figures.installSliceControl( ...
                planWorkflow.analysis.Figures.figureField( ...
                figures,'doseDifference'), ...
                planWorkflow.analysis.Figures.expectedDoseDifferenceSlicePayload( ...
                commonPayload,doseStat,meta));
        end

        function payload = commonSlicePayload(samplingData,sample,meta,label)
            payload = [];
            if ~isstruct(samplingData) || ~isfield(samplingData,'ct') || ...
                    ~isstruct(samplingData.ct) || ...
                    ~isfield(samplingData.ct,'cubeDim') || ...
                    isempty(samplingData.ct.cubeDim)
                return;
            end
            plane = planWorkflow.analysis.Figures.fieldOrDefault( ...
                meta,'plane',3);
            if plane < 1 || plane > numel(samplingData.ct.cubeDim)
                return;
            end
            sliceMax = samplingData.ct.cubeDim(plane);
            if sliceMax < 2
                return;
            end
            slice = planWorkflow.analysis.Figures.fieldOrDefault( ...
                meta,'slice',[]);
            if isempty(slice)
                return;
            end

            payload = struct();
            payload.ct = samplingData.ct;
            payload.cst = planWorkflow.analysis.Figures.samplingPlotCst( ...
                samplingData,sample);
            payload.plane = plane;
            payload.sliceMax = sliceMax;
            payload.slice = planWorkflow.analysis.Figures.clampSlice( ...
                slice,sliceMax);
            payload.label = char(label);
        end

        function cst = samplingPlotCst(samplingData,sample)
            if isstruct(sample) && isfield(sample,'resultGUINomScen') && ...
                    isstruct(sample.resultGUINomScen) && ...
                    isfield(sample.resultGUINomScen,'cst') && ...
                    ~isempty(sample.resultGUINomScen.cst)
                cst = sample.resultGUINomScen.cst;
            elseif isstruct(samplingData) && isfield(samplingData,'cst')
                cst = samplingData.cst;
            else
                cst = {};
            end
        end

        function payload = doseSlicePayload(commonPayload,doseStat, ...
                analysisField,cubeField)
            payload = [];
            if isempty(commonPayload) || ~isstruct(doseStat) || ...
                    ~isfield(doseStat,analysisField) || ...
                    ~isfield(doseStat,cubeField)
                return;
            end
            payload = commonPayload;
            payload.kind = 'dose';
            payload.doseAnalysis = doseStat.(analysisField);
            payload.doseCube = doseStat.(cubeField);
        end

        function payload = nominalSlicePayload(commonPayload,doseStat, ...
                sample,meta)
            payload = [];
            if isempty(commonPayload) || ~isstruct(doseStat) || ...
                    ~isfield(doseStat,'nominalAnalysis') || ...
                    ~isstruct(sample) || ~isfield(sample,'resultGUINomScen')
                return;
            end
            quantity = planWorkflow.analysis.Figures.analysisQuantity(meta);
            if isempty(quantity) || ...
                    ~isfield(sample.resultGUINomScen,quantity)
                return;
            end
            payload = commonPayload;
            payload.kind = 'dose';
            payload.doseAnalysis = doseStat.nominalAnalysis;
            payload.doseCube = sample.resultGUINomScen.(quantity);
        end

        function quantity = analysisQuantity(meta)
            quantity = '';
            if isstruct(meta) && isfield(meta,'analysisContext') && ...
                    isstruct(meta.analysisContext) && ...
                    isfield(meta.analysisContext,'quantity')
                quantity = char(meta.analysisContext.quantity);
            end
        end

        function payload = robustnessSlicePayload(commonPayload,doseStat, ...
                method)
            payload = [];
            if isempty(commonPayload) || ~isstruct(doseStat) || ...
                    ~isfield(doseStat,'robustnessAnalysis')
                return;
            end
            payload = commonPayload;
            payload.kind = 'robustness';
            payload.robustnessAnalysis = doseStat.robustnessAnalysis;
            payload.method = char(method);
        end

        function payload = expectedDoseDifferenceSlicePayload( ...
                commonPayload,doseStat,meta)
            payload = [];
            if isempty(commonPayload) || ~isstruct(doseStat) || ...
                    ~isfield(doseStat,'expectedDoseDifferenceAnalysis')
                return;
            end
            payload = commonPayload;
            payload.kind = 'expectedDoseDifference';
            payload.expectedDoseDifferenceAnalysis = ...
                doseStat.expectedDoseDifferenceAnalysis;
            payload.doseWindow = planWorkflow.analysis.Figures.fieldOrDefault( ...
                meta,'doseDifferenceWindow',[]);
            payload.displayScale = planWorkflow.analysis.Figures.fieldOrDefault( ...
                meta,'displayScale',1);
        end

        function installSliceControl(fig,payload)
            if isempty(fig) || ~ishghandle(fig) || isempty(payload)
                return;
            end
            setappdata(fig,'planWorkflowSlicePayload',payload);
            planWorkflow.analysis.Figures.ensureSliceControls(fig,payload);
        end

        function ensureSliceControls(fig,payload)
            slider = findobj(fig,'Tag','planWorkflowSliceSlider');
            if isempty(slider) || ~ishghandle(slider)
                slider = uicontrol('Parent',fig,'Style','slider', ...
                    'Units','normalized', ...
                    'Position',[0.16 0.02 0.62 0.04], ...
                    'Tag','planWorkflowSliceSlider', ...
                    'Callback', ...
                    @(source,event) planWorkflow.analysis.Figures.updateSliceFigure( ...
                    source,event));
            end
            label = findobj(fig,'Tag','planWorkflowSliceLabel');
            if isempty(label) || ~ishghandle(label)
                label = uicontrol('Parent',fig,'Style','text', ...
                    'Units','normalized', ...
                    'Position',[0.79 0.015 0.19 0.045], ...
                    'HorizontalAlignment','left', ...
                    'BackgroundColor',[1 1 1], ...
                    'Tag','planWorkflowSliceLabel');
            end
            caption = findobj(fig,'Tag','planWorkflowSliceCaption');
            if isempty(caption) || ~ishghandle(caption)
                uicontrol('Parent',fig,'Style','text', ...
                    'Units','normalized', ...
                    'Position',[0.02 0.015 0.12 0.045], ...
                    'String','Slice', ...
                    'HorizontalAlignment','left', ...
                    'BackgroundColor',[1 1 1], ...
                    'Tag','planWorkflowSliceCaption');
            end

            set(slider,'Min',1,'Max',payload.sliceMax, ...
                'Value',payload.slice, ...
                'SliderStep',planWorkflow.analysis.Figures.sliderStep( ...
                payload.sliceMax));
            set(label,'String',planWorkflow.analysis.Figures.sliceLabel( ...
                payload.slice,payload.sliceMax));
        end

        function updateSliceControlValues(fig,payload)
            slider = findobj(fig,'Tag','planWorkflowSliceSlider');
            if ~isempty(slider) && ishghandle(slider)
                set(slider,'Value',payload.slice);
            end
            label = findobj(fig,'Tag','planWorkflowSliceLabel');
            if ~isempty(label) && ishghandle(label)
                set(label,'String',planWorkflow.analysis.Figures.sliceLabel( ...
                    payload.slice,payload.sliceMax));
            end
        end

        function clearSpatialAxes(fig,axesHandle)
            delete(findall(fig,'Type','ColorBar'));
            delete(findall(fig,'Type','colorbar'));
            delete(findall(fig,'Tag','Colorbar'));
            delete(findall(fig,'Type','Legend'));
            cla(axesHandle);
        end

        function value = fieldOrDefault(source,fieldName,defaultValue)
            if isstruct(source) && isfield(source,fieldName) && ...
                    ~isempty(source.(fieldName))
                value = source.(fieldName);
            else
                value = defaultValue;
            end
        end

        function slice = clampSlice(slice,sliceMax)
            slice = round(double(slice));
            slice = min(max(slice,1),sliceMax);
        end

        function step = sliderStep(sliceMax)
            fineStep = 1 / max(sliceMax - 1,1);
            step = [fineStep min(10 * fineStep,1)];
        end

        function text = sliceLabel(slice,sliceMax)
            text = sprintf('%d / %d',slice,sliceMax);
        end

        function fig = figureField(figures,varargin)
            fig = [];
            value = figures;
            for i = 1:numel(varargin)
                if ~isstruct(value) || ~isfield(value,varargin{i})
                    return;
                end
                value = value.(varargin{i});
            end
            if ~isempty(value) && ishghandle(value)
                fig = value;
            end
        end

        function tf = hasInteractiveFigureSession()
            tf = false;
            if exist('matRad_isInteractiveSession','file') == 2
                try
                    tf = matRad_isInteractiveSession( ...
                        'requireFigureWindows',true);
                    return;
                catch
                end
            end
            try
                cfg = MatRad_Config.instance();
                if cfg.disableGUI
                    return;
                end
            catch
            end
            try
                if exist('feature','builtin') == 5 && ...
                        ~feature('ShowFigureWindows')
                    return;
                end
            catch
                return;
            end
            tf = true;
        end

        function axesHandles = mainAxes(fig)
            axesHandles = findall(fig,'Type','Axes');
            if isempty(axesHandles)
                return;
            end
            tags = get(axesHandles,'Tag');
            if ischar(tags)
                tags = {tags};
            end
            axesHandles = axesHandles(~strcmp(tags,'Colorbar'));
        end

        function axesHandle = primaryAxes(fig)
            axesHandles = planWorkflow.analysis.Figures.mainAxes(fig);
            if isempty(axesHandles)
                axesHandle = [];
                return;
            end

            axesHandle = axesHandles(1);
            for i = 1:numel(axesHandles)
                titleHandle = get(axesHandles(i),'Title');
                if ~isempty(planWorkflow.analysis.Figures.titleLines( ...
                        get(titleHandle,'String')))
                    axesHandle = axesHandles(i);
                    return;
                end
            end
        end

        function lines = titleLines(titleText)
            if iscell(titleText)
                lines = titleText(:);
            elseif ischar(titleText)
                lines = cellstr(titleText);
            else
                lines = {char(titleText)};
            end
            lines = lines(:);
            lines = lines(~cellfun(@isempty,lines));
        end

        function lines = removePlanRobustnessTitleLines(lines,label)
            legacyPrefixPattern = ['^\s*' 'Plan\s+robustness\s*:'];
            titleText = planWorkflow.analysis.Figures.planRobustnessTitleLine( ...
                label);
            keep = true(size(lines));
            for i = 1:numel(lines)
                keep(i) = isempty(regexp(char(lines{i}), ...
                    legacyPrefixPattern,'once')) && ...
                    ~strcmp(char(lines{i}),titleText);
            end
            lines = lines(keep);
        end
    end
end
