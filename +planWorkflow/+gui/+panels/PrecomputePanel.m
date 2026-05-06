classdef PrecomputePanel
    % PrecomputePanel Owns GUI-facing precompute parameter contracts.

    methods (Static)
        function specs = specs()
            specs = planWorkflow.gui.ParameterPanelSpecAdapter.fromSchema( ...
                planWorkflow.config.WorkflowParameterSchema.precomputeSpecs());
        end

        function specs = transversalSpecs()
            schemaSpecs = planWorkflow.config.WorkflowParameterSchema.precomputeTransversalSpecs();
            specs = planWorkflow.gui.ParameterPanelSpecAdapter.fromSchema( ...
                schemaSpecs);
        end

        function specs = referenceSpecs()
            schemaSpecs = planWorkflow.config.WorkflowParameterSchema.precomputeReferenceSpecs();
            specs = planWorkflow.gui.ParameterPanelSpecAdapter.fromSchema( ...
                schemaSpecs);
        end

        function specs = robustSpecs()
            schemaSpecs = planWorkflow.config.WorkflowParameterSchema.precomputeRobustSpecs();
            specs = planWorkflow.gui.ParameterPanelSpecAdapter.fromSchema( ...
                schemaSpecs);
        end

        function specs = robustnessStrategySpecs(prefix)
            schemaSpecs = ...
                planWorkflow.config.WorkflowParameterSchema.robustnessStrategySpecs( ...
                prefix);
            specs = planWorkflow.gui.ParameterPanelSpecAdapter.fromSchema( ...
                schemaSpecs);
        end

        function specs = robustnessParameterSpecs(prefix)
            schemaSpecs = ...
                planWorkflow.config.WorkflowParameterSchema.robustnessParameterSpecs( ...
                prefix);
            specs = planWorkflow.gui.ParameterPanelSpecAdapter.fromSchema( ...
                schemaSpecs);
        end

        function specs = scenarioSpecs(prefix)
            specs = planWorkflow.gui.ParameterPanelSpecAdapter.fromSchema( ...
                planWorkflow.config.WorkflowParameterSchema.scenarioSpecs( ...
                prefix));
        end

        function optionSets = optionSets(runConfig,planConfig)
            if nargin < 2
                planConfig = [];
            end
            optionSets = ...
                planWorkflow.gui.WorkflowParameterOptions.precomputeOptionSets( ...
                runConfig,planConfig);
        end

        function fields = transversalVisibleFields()
            fields = planWorkflow.config.WorkflowParameterSchema.precomputeTransversalVisibleFields();
        end

        function fields = referenceVisibleFields( ...
                robustness,scenMode,dimensionConfig,KMode)
            if nargin < 1 || isempty(robustness)
                robustness = 'none';
            end
            if nargin < 2 || isempty(scenMode)
                scenMode = 'nomScen';
            end
            if nargin < 3
                dimensionConfig = struct();
            end
            if nargin < 4 || isempty(KMode)
                KMode = 'dynamic';
            end
            fields = ...
                planWorkflow.config.WorkflowParameterSchema.precomputeReferenceVisibleFields( ...
                robustness,scenMode, ...
                dimensionConfig,KMode);
        end

        function fields = robustVisibleFields( ...
                robustness,scenMode,dimensionConfig,KMode)
            if nargin < 3
                dimensionConfig = struct();
            end
            if nargin < 4 || isempty(KMode)
                KMode = 'dynamic';
            end
            fields = ...
                planWorkflow.config.WorkflowParameterSchema.precomputeRobustVisibleFields( ...
                robustness,scenMode, ...
                dimensionConfig,KMode);
        end

        function fields = robustnessVisibleFields(robustness,prefix,KMode)
            if nargin < 2
                prefix = '';
            end
            if nargin < 3 || isempty(KMode)
                KMode = 'dynamic';
            end
            fields = ...
                planWorkflow.config.WorkflowParameterSchema.robustnessVisibleFields( ...
                robustness,prefix,KMode);
        end

        function specs = robustnessParameterMetadata()
            specs = planWorkflow.config.RobustStrategySpec.allParameterSpecs();
        end

        function values = strategyOptionValues(strategy,fieldName)
            values = planWorkflow.config.RobustStrategySpec.optionValues( ...
                strategy,fieldName);
        end

        function layout = actionLayout()
            layout = struct();
            layout.addRobustPlanButton = [0.70 0.925 0.13 0.050];
            layout.deleteRobustPlanButton = [0.84 0.925 0.13 0.050];
            layout.tabGroup = [0.02 0.04 0.96 0.86];
        end

        function titleText = referencePlanTabTitle(label)
            label = ...
                planWorkflow.config.WorkflowContractValidator.normalizeReferencePlanLabel( ...
                label);
            if isempty(label)
                titleText = 'Reference';
            else
                titleText = ['Reference (' label ')'];
            end
        end
    end
end
