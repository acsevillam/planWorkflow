classdef StageParameterPanelController < handle
    % StageParameterPanelController Owns simple stage-parameter panels.

    properties (Access = private)
        Panels
        RunConfig
        Template
        OnConfigChanged
        OnInvalid
    end

    methods (Static)
        function obj = create(parents,runConfig,template,onConfigChanged, ...
                onInvalid)
            obj = planWorkflow.gui.StageParameterPanelController( ...
                parents,runConfig,template,onConfigChanged,onInvalid);
        end
    end

    methods
        function obj = StageParameterPanelController(parents,runConfig, ...
                template,onConfigChanged,onInvalid)
            if nargin < 4 || isempty(onConfigChanged)
                onConfigChanged = @(runConfig) [];
            end
            if nargin < 5 || isempty(onInvalid)
                onInvalid = @(message,title) errordlg(message,title);
            end
            obj.RunConfig = runConfig;
            obj.Template = template;
            obj.OnConfigChanged = onConfigChanged;
            obj.OnInvalid = onInvalid;

            callbacks = planWorkflow.gui.StageParameterPanels.callbacks( ...
                struct('samplingLinkChanged', ...
                @(src,event) obj.refreshSampling(src,event), ...
                'samplingAcquisitionTypeChanged', ...
                @(src,event) obj.refreshSamplingCaseIds(src,event), ...
                'samplingScenarioModeChanged', ...
                @(src,event) obj.refreshSampling(src,event), ...
                'analysisTargetModeChanged', ...
                @(src,event) obj.refreshAnalysis(src,event), ...
                'dosePullingToggleChanged', ...
                @(src,event) obj.refreshDosePulling(src,event)), ...
                struct('sampling',@(src,event) obj.syncSampling(src,event), ...
                'analysis',@(src,event) obj.syncAnalysis(src,event), ...
                'dosePulling',@(src,event) obj.syncDosePulling(src,event), ...
                'optimize',@(src,event) obj.syncOptimize(src,event)));
            obj.Panels = planWorkflow.gui.StageParameterPanels.create( ...
                parents,runConfig,template,callbacks);
        end

        function loadAll(obj)
            planWorkflow.gui.StageParameterPanels.loadAll( ...
                obj.Panels,obj.RunConfig,obj.Template);
        end

        function setRunConfig(obj,runConfig)
            obj.RunConfig = runConfig;
        end

        function setTemplate(obj,template)
            obj.Template = template;
        end

        function runConfig = runConfig(obj)
            runConfig = obj.RunConfig;
        end

        function runConfig = syncAll(obj,runConfig)
            if nargin >= 2
                obj.RunConfig = runConfig;
            end
            obj.syncDosePullingInternal();
            obj.syncOptimizeInternal();
            obj.syncSamplingInternal();
            obj.syncAnalysisInternal();
            obj.OnConfigChanged(obj.RunConfig);
            runConfig = obj.RunConfig;
        end

        function tableHandle = activeParameterPanel(obj,selectedTopTab)
            tableHandle = planWorkflow.gui.StageParameterPanels.activeParameterPanel( ...
                obj.Panels,selectedTopTab);
        end

        function controls = controls(obj)
            controls = planWorkflow.gui.StageParameterPanels.controls( ...
                obj.Panels);
        end

        function controls = analysisControls(obj)
            controls = planWorkflow.gui.StageParameterPanels.analysisControls( ...
                obj.Panels);
        end

        function loadAnalysis(obj,varargin)
            planWorkflow.gui.StageParameterPanels.loadAnalysis( ...
                obj.Panels,obj.RunConfig.analysis,obj.Template, ...
                obj.RunConfig);
        end

        function refreshSampling(obj,varargin)
            obj.apply(@() obj.refreshSamplingInternal());
        end

        function refreshSamplingCaseIds(obj,varargin)
            obj.apply(@() obj.refreshSamplingCaseIdsInternal());
        end

        function refreshAnalysis(obj,varargin)
            planWorkflow.gui.StageParameterPanels.refreshAnalysis(obj.Panels);
        end

        function refreshDosePulling(obj,varargin)
            planWorkflow.gui.StageParameterPanels.refreshDosePulling(obj.Panels);
        end

        function syncDosePulling(obj,varargin)
            obj.apply(@() obj.syncDosePullingInternal());
        end

        function syncOptimize(obj,varargin)
            obj.apply(@() obj.syncOptimizeInternal());
        end

        function syncSampling(obj,varargin)
            obj.apply(@() obj.syncSamplingInternal());
        end

        function syncAnalysis(obj,varargin)
            obj.apply(@() obj.syncAnalysisInternal());
        end

        function runConfig = syncAnalysisStrict(obj,runConfig)
            if nargin >= 2
                obj.RunConfig = runConfig;
            end
            obj.syncAnalysisInternal();
            runConfig = obj.RunConfig;
        end
    end

    methods (Access = private)
        function apply(obj,action)
            try
                action();
                obj.OnConfigChanged(obj.RunConfig);
            catch ME
                obj.OnInvalid(ME.message,'Invalid workflow settings');
            end
        end

        function syncDosePullingInternal(obj)
            obj.RunConfig = ...
                planWorkflow.gui.StageParameterPanels.syncDosePulling( ...
                obj.Panels,obj.RunConfig);
        end

        function syncOptimizeInternal(obj)
            obj.RunConfig = ...
                planWorkflow.gui.StageParameterPanels.syncOptimize( ...
                obj.Panels,obj.RunConfig);
        end

        function syncSamplingInternal(obj)
            obj.RunConfig = ...
                planWorkflow.gui.StageParameterPanels.syncSampling( ...
                obj.Panels,obj.RunConfig);
        end

        function syncAnalysisInternal(obj)
            obj.RunConfig.analysis = ...
                planWorkflow.gui.StageParameterPanels.syncAnalysis( ...
                obj.Panels,obj.RunConfig.analysis);
        end

        function refreshSamplingInternal(obj)
            obj.RunConfig = ...
                planWorkflow.gui.StageParameterPanels.refreshSampling( ...
                obj.Panels,obj.RunConfig);
        end

        function refreshSamplingCaseIdsInternal(obj)
            obj.RunConfig = ...
                planWorkflow.gui.StageParameterPanels.refreshSamplingCaseIds( ...
                obj.Panels,obj.RunConfig);
        end
    end
end
