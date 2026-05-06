classdef DosePullingPanel
    % DosePullingPanel Owns dose-pulling GUI parameter contracts.

    methods (Static)
        function tableHandle = create(parent,position,callbacks)
            if nargin < 3
                callbacks = struct();
            end
            tableHandle = planWorkflow.gui.ParameterPanelRenderer.create( ...
                parent,position, ...
                planWorkflow.gui.panels.DosePullingPanel.specs(), ...
                struct(),struct(),callbacks);
        end

        function specs = specs()
            specs = planWorkflow.gui.ParameterPanelSpecAdapter.fromSchema( ...
                planWorkflow.config.WorkflowParameterSchema.dosePullingSpecs());
        end

        function load(tableHandle,runConfig)
            planWorkflow.gui.ParameterPanelRenderer.load( ...
                tableHandle,runConfig,struct(),struct());
            planWorkflow.gui.panels.DosePullingPanel.refresh(tableHandle);
        end

        function runConfig = sync(tableHandle,runConfig)
            runConfig = planWorkflow.gui.ParameterPanelRenderer.toConfig( ...
                runConfig,tableHandle);
        end

        function refresh(tableHandle)
            channel1Enabled = ...
                planWorkflow.gui.ParameterPanelRenderer.fieldValue( ...
                tableHandle,'dose_pulling1');
            channel2Enabled = ...
                planWorkflow.gui.ParameterPanelRenderer.fieldValue( ...
                tableHandle,'dose_pulling2');
            fields = planWorkflow.gui.panels.DosePullingPanel.visibleFields( ...
                channel1Enabled,channel2Enabled);
            planWorkflow.gui.ParameterPanelRenderer.setVisibleFields( ...
                tableHandle,fields);
        end

        function fields = visibleFields(channel1Enabled,channel2Enabled)
            fields = ...
                planWorkflow.config.WorkflowParameterSchema.dosePullingVisibleFields( ...
                channel1Enabled,channel2Enabled);
        end
    end
end
