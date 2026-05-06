classdef OptimizePanel
    % OptimizePanel Owns optimization GUI parameter contracts.

    methods (Static)
        function tableHandle = create(parent,position,runConfig,callbacks)
            if nargin < 4
                callbacks = struct();
            end
            tableHandle = planWorkflow.gui.ParameterPanelRenderer.create( ...
                parent,position, ...
                planWorkflow.gui.panels.OptimizePanel.specs(), ...
                planWorkflow.gui.panels.OptimizePanel.optionSets( ...
                runConfig),struct(),callbacks);
        end

        function specs = specs()
            specs = planWorkflow.gui.ParameterPanelSpecAdapter.fromSchema( ...
                planWorkflow.config.WorkflowParameterSchema.optimizeSpecs());
        end

        function load(tableHandle,runConfig)
            planWorkflow.gui.ParameterPanelRenderer.load( ...
                tableHandle,runConfig, ...
                planWorkflow.gui.panels.OptimizePanel.optionSets( ...
                runConfig),struct());
        end

        function runConfig = sync(tableHandle,runConfig)
            runConfig = planWorkflow.gui.ParameterPanelRenderer.toConfig( ...
                runConfig,tableHandle);
        end

        function optionSets = optionSets(runConfig)
            optionSets = ...
                planWorkflow.gui.WorkflowParameterOptions.optimizeOptionSets( ...
                runConfig);
        end
    end
end
