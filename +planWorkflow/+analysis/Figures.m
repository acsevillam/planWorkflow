classdef Figures
    % Figures Sampling-analysis figure generation and persistence.

    methods (Static)
        function figureFiles = saveSamplingAnalysisFigures(analysisFolder,label, ...
                gammaFig,robustnessFig1,robustnessFig2,samplingData,sample, ...
                doseStat,analysis,slice)
            analysis = planWorkflow.config.Analysis.normalize(analysis);
            if ~isfolder(analysisFolder)
                mkdir(analysisFolder);
            end

            figureFiles = struct( ...
                'gamma','', ...
                'robustness1','', ...
                'robustness2','', ...
                'meanDose','', ...
                'stdDose','', ...
                'dvhMultiscenario','', ...
                'dvhTrustband','');
            if ~analysis.figures.save
                planWorkflow.analysis.Figures.saveFigureIfValid( ...
                    gammaFig,'',analysis);
                planWorkflow.analysis.Figures.saveFigureIfValid( ...
                    robustnessFig1,'',analysis);
                planWorkflow.analysis.Figures.saveFigureIfValid( ...
                    robustnessFig2,'',analysis);
                return;
            end
            evaluationScale = planWorkflow.analysis.Figures.evaluationScale( ...
                sample.pln,analysis);
            figureFiles.gamma = planWorkflow.analysis.Figures.saveFigureIfValid( ...
                gammaFig,fullfile(analysisFolder,[label '_gamma.fig']), ...
                analysis);
            figureFiles.robustness1 = planWorkflow.analysis.Figures.saveFigureIfValid( ...
                robustnessFig1,fullfile(analysisFolder,[label '_robustness1.fig']), ...
                analysis);
            figureFiles.robustness2 = planWorkflow.analysis.Figures.saveFigureIfValid( ...
                robustnessFig2,fullfile(analysisFolder,[label '_robustness2.fig']), ...
                analysis);
            figureFiles.meanDose = planWorkflow.analysis.Figures.saveDoseStatisticFigure( ...
                samplingData.ct,samplingData.cst, ...
                doseStat.meanCubeW * evaluationScale, ...
                analysis.doseWindow,slice, ...
                fullfile(analysisFolder,[label '_mean_dose.fig']), ...
                ['Mean dose for ' label], ...
                'Expected Dose [Gy]',1.5,analysis);
            figureFiles.stdDose = planWorkflow.analysis.Figures.saveDoseStatisticFigure( ...
                samplingData.ct,samplingData.cst, ...
                doseStat.stdCubeW * evaluationScale, ...
                analysis.doseWindowUncertainty,slice, ...
                fullfile(analysisFolder,[label '_std_dose.fig']), ...
                ['Standard deviation dose for ' label], ...
                'Dose uncertainty [Gy]',1.2,analysis);
            figureFiles.dvhMultiscenario = ...
                planWorkflow.analysis.Figures.saveSamplingDvhFigure( ...
                samplingData.cst,sample,evaluationScale, ...
                analysis.doseWindowDvh, ...
                'multiscenario', ...
                fullfile(analysisFolder,[label '_dvh_multiscenario.fig']), ...
                ['Multi-scenario DVH for ' label],analysis);
            figureFiles.dvhTrustband = ...
                planWorkflow.analysis.Figures.saveSamplingDvhFigure( ...
                samplingData.cst,sample,evaluationScale, ...
                analysis.doseWindowDvh, ...
                'trustband', ...
                fullfile(analysisFolder,[label '_dvh_trustband.fig']), ...
                ['Trust band DVH for ' label],analysis);
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

        function filePath = saveDoseStatisticFigure(ct,cst,doseCube,doseWindow, ...
                slice,filePath,titleText,colorbarLabel,lineWidth,analysis)
            if nargin < 10
                analysis = planWorkflow.config.Analysis.defaults();
            end
            if isempty(doseCube)
                filePath = '';
                return;
            end

            fig = figure('Visible', ...
                planWorkflow.analysis.Figures.figureVisibility(analysis));
            set(fig,'Tag','planWorkflowAnalysisFigure');
            set(fig,'Color',[1 1 1],'Position',[10 10 550 400]);
            ax = axes('Parent',fig);
            plane = 3;
            numSlices = ct.cubeDim(3);
            doseWindow = planWorkflow.analysis.Figures.resolveDoseWindow( ...
                doseCube,doseWindow);
            doseIsoLevels = planWorkflow.analysis.Figures.resolveDoseIsoLevels( ...
                doseCube);

            matRad_plotSliceWrapper(ax,ct,cst,1,doseCube,plane,slice,[],[], ...
                colorcube,[],doseWindow,doseIsoLevels,[],colorbarLabel,[], ...
                'LineWidth',lineWidth);
            title(ax,titleText,'Interpreter','none');

            if numSlices > 1
                sliderStep = planWorkflow.analysis.Figures.sliderStep(numSlices);
                slider = uicontrol('Parent',fig,'Style','slider', ...
                    'Position',[50 5 420 23], ...
                    'value',slice,'min',1,'max',numSlices, ...
                    'SliderStep',sliderStep);
                slider.Callback = @(es,ed) matRad_plotSliceWrapper(ax,ct,cst,1, ...
                    doseCube,plane,round(es.Value),[],[],colorcube,[], ...
                    doseWindow,doseIsoLevels,[],colorbarLabel,[], ...
                    'LineWidth',lineWidth);
            end

            filePath = planWorkflow.analysis.Figures.saveFigureIfValid( ...
                fig,filePath,analysis);
        end

        function filePath = saveSamplingDvhFigure(cst,sample,evaluationScale, ...
                doseWindow,dvhType,filePath,titleText,analysis)
            if nargin < 8
                analysis = planWorkflow.config.Analysis.defaults();
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

            filePath = planWorkflow.analysis.Figures.saveFigureIfValid( ...
                fig,filePath,analysis);
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

        function doseWindow = resolveDoseWindow(doseCube,doseWindow)
            finiteDose = doseCube(isfinite(doseCube));
            if isempty(finiteDose)
                maxDose = 1;
            else
                maxDose = max(finiteDose(:));
            end

            if isempty(doseWindow)
                doseWindow = [0 maxDose];
            else
                doseWindow = doseWindow(:)';
            end

            if numel(doseWindow) < 2
                doseWindow = [0 maxDose];
            end

            if ~all(isfinite(doseWindow(1:2))) || doseWindow(2) <= doseWindow(1)
                doseWindow = [0 max(maxDose,1)];
            end
        end

        function doseIsoLevels = resolveDoseIsoLevels(doseCube)
            finiteDose = doseCube(isfinite(doseCube));
            if isempty(finiteDose)
                doseIsoLevels = [];
                return;
            end

            maxDose = max(finiteDose(:));
            if maxDose <= 0
                doseIsoLevels = [];
            else
                doseIsoLevels = linspace(0.1 * maxDose,maxDose,10);
            end
        end

        function sliderStep = sliderStep(numSlices)
            if numSlices > 1
                sliderStep = [1/(numSlices - 1) 1/(numSlices - 1)];
            else
                sliderStep = [1 1];
            end
        end

    end

    methods (Static, Access = private)
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
    end
end
