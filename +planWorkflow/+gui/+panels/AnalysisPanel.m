classdef AnalysisPanel
    % AnalysisPanel Owns analysis GUI parameter contracts.

    methods (Static)
        function tableHandle = create(parent,position,analysis,template, ...
                runConfig,callbacks)
            if nargin < 5
                runConfig = struct();
            end
            if nargin < 6
                callbacks = struct();
            end
            tableHandle = planWorkflow.gui.ParameterPanelRenderer.create( ...
                parent,position, ...
                planWorkflow.gui.panels.AnalysisPanel.specs(), ...
                planWorkflow.gui.panels.AnalysisPanel.optionSets( ...
                analysis,template,runConfig),struct(),callbacks);
        end

        function specs = specs()
            specs = planWorkflow.gui.ParameterPanelSpecAdapter.fromSchema( ...
                planWorkflow.config.WorkflowParameterSchema.analysisSpecs());
        end

	        function load(tableHandle,analysis,template,runConfig)
	            if nargin < 4
	                runConfig = struct();
	            end
	            planWorkflow.gui.ParameterPanelRenderer.load( ...
	                tableHandle,analysis, ...
	                planWorkflow.gui.panels.AnalysisPanel.optionSets( ...
	                analysis,template,runConfig),struct());
	            planWorkflow.gui.panels.AnalysisPanel.refresh(tableHandle, ...
	                analysis,runConfig);
	        end

        function analysis = sync(tableHandle,analysis)
            analysis = planWorkflow.gui.ParameterPanelRenderer.toConfig( ...
                analysis,tableHandle);
            analysis.endpointsFile = ...
                planWorkflow.analysis.ClinicalEndpointCatalog.normalizeFileSelection( ...
                analysis.endpointsFile);
            if strcmp(char(analysis.robustnessTargetMode),'all')
                analysis.robustnessTargets = [];
            end
        end

	        function refresh(tableHandle,analysis,runConfig)
	            targetMode = ...
	                planWorkflow.gui.ParameterPanelRenderer.fieldValue( ...
	                tableHandle,'robustnessTargetMode');
	            fields = planWorkflow.gui.panels.AnalysisPanel.visibleFields( ...
	                targetMode);
	            planWorkflow.gui.ParameterPanelRenderer.setVisibleFields( ...
	                tableHandle,fields);
	            if nargin >= 3
	                planWorkflow.gui.panels.AnalysisPanel.refreshEndpointFileHelp( ...
	                    tableHandle,analysis,runConfig);
	            end
	        end

        function optionSets = optionSets(analysis,template,runConfig)
            if nargin < 2
                template = struct();
            end
            if nargin < 3
                runConfig = struct();
            end
            optionSets = ...
                planWorkflow.gui.WorkflowParameterOptions.analysisOptionSets( ...
                analysis,template,runConfig);
        end

	        function fields = visibleFields(targetMode)
	            fields = ...
	                planWorkflow.config.WorkflowParameterSchema.analysisVisibleFields( ...
	                targetMode);
	        end

	        function refreshEndpointFileHelp(tableHandle,analysis,runConfig)
	            status = ...
	                planWorkflow.gui.WorkflowParameterOptions.endpointFileSelectionStatus( ...
	                analysis,runConfig);
	            helpText = planWorkflow.gui.HelpText.parameter('endpointsFile');
	            if ~status.isCompatible && ~isempty(status.message)
	                helpText = sprintf('%s\n%s',helpText,status.message);
	            end
	            planWorkflow.gui.ParameterPanelRenderer.setFieldHelpText( ...
	                tableHandle,'endpointsFile',helpText);
	        end
	    end
	end
