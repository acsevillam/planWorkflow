classdef Figures
    % Figures Sampling-analysis figure generation and persistence.

    methods (Static)
        function figureFiles = saveSamplingAnalysisFigures(analysisFolder,label, ...
                gammaFig,robustnessFig1,robustnessFig2,samplingData,sample, ...
                doseStat,analysis,slice)
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
            evaluationScale = planWorkflow.analysis.Figures.evaluationScale( ...
                sample.pln,analysis);
            figureFiles.gamma = planWorkflow.analysis.Figures.saveFigureIfValid( ...
                gammaFig,fullfile(analysisFolder,[label '_gamma.fig']));
            figureFiles.robustness1 = planWorkflow.analysis.Figures.saveFigureIfValid( ...
                robustnessFig1,fullfile(analysisFolder,[label '_robustness1.fig']));
            figureFiles.robustness2 = planWorkflow.analysis.Figures.saveFigureIfValid( ...
                robustnessFig2,fullfile(analysisFolder,[label '_robustness2.fig']));
            figureFiles.meanDose = planWorkflow.analysis.Figures.saveDoseStatisticFigure( ...
                samplingData.ct,samplingData.cst, ...
                doseStat.meanCubeW * evaluationScale, ...
                analysis.doseWindow,slice, ...
                fullfile(analysisFolder,[label '_mean_dose.fig']), ...
                ['Mean dose for ' label], ...
                'Expected Dose [Gy]',1.5);
            figureFiles.stdDose = planWorkflow.analysis.Figures.saveDoseStatisticFigure( ...
                samplingData.ct,samplingData.cst, ...
                doseStat.stdCubeW * evaluationScale, ...
                analysis.doseWindowUncertainty,slice, ...
                fullfile(analysisFolder,[label '_std_dose.fig']), ...
                ['Standard deviation dose for ' label], ...
                'Dose uncertainty [Gy]',1.2);
            figureFiles.dvhMultiscenario = ...
                planWorkflow.analysis.Figures.saveSamplingDvhFigure( ...
                samplingData.cst,sample,evaluationScale, ...
                analysis.doseWindowDvh, ...
                'multiscenario', ...
                fullfile(analysisFolder,[label '_dvh_multiscenario.fig']), ...
                ['Multi-scenario DVH for ' label]);
            figureFiles.dvhTrustband = ...
                planWorkflow.analysis.Figures.saveSamplingDvhFigure( ...
                samplingData.cst,sample,evaluationScale, ...
                analysis.doseWindowDvh, ...
                'trustband', ...
                fullfile(analysisFolder,[label '_dvh_trustband.fig']), ...
                ['Trust band DVH for ' label]);
        end

        function filePath = saveFigureIfValid(fig,filePath)
            if isempty(fig) || ~ishghandle(fig)
                filePath = '';
                return;
            end

            savefig(fig,filePath);
            close(fig);
        end

        function filePath = saveDoseStatisticFigure(ct,cst,doseCube,doseWindow, ...
                slice,filePath,titleText,colorbarLabel,lineWidth)
            if isempty(doseCube)
                filePath = '';
                return;
            end

            fig = figure;
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

            filePath = planWorkflow.analysis.Figures.saveFigureIfValid(fig,filePath);
        end

        function filePath = saveSamplingDvhFigure(cst,sample,evaluationScale, ...
                doseWindow,dvhType,filePath,titleText)
            if isempty(sample.caSamp)
                filePath = '';
                return;
            end

            fig = figure;
            set(fig,'Color',[1 1 1],'Position',[10 10 600 400]);
            scenarios = 1:numel(sample.caSamp);
            matRad_showDVHFromSampling(sample.caSamp,evaluationScale,cst,sample.pln, ...
                scenarios,doseWindow,dvhType,1);
            title(titleText,'Interpreter','none');

            filePath = planWorkflow.analysis.Figures.saveFigureIfValid(fig,filePath);
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
end
