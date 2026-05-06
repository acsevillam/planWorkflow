classdef PlanLabels
    % PlanLabels Formats user-facing workflow result labels.

    methods (Static)
        function label = referencePlanDisplayLabel(referenceConfig)
            label = 'Reference';
            if isstruct(referenceConfig) && isfield(referenceConfig,'label') && ...
                    ~isempty(referenceConfig.label)
                referenceLabel = regexprep( ...
                    strtrim(char(string(referenceConfig.label))),'\s+',' ');
                if ~isempty(referenceLabel)
                    label = sprintf('Reference (%s)',referenceLabel);
                end
            end
        end

        function label = robustResultLabel(planConfig,variantIx)
            label = planWorkflow.results.PlanLabels.planLabel( ...
                planConfig,sprintf('Robust %d',variantIx));
            if ~isstruct(planConfig) || ~isfield(planConfig,'variants') || ...
                    isempty(planConfig.variants)
                return;
            end

            variants = planConfig.variants;
            variant = variants(min(variantIx,numel(variants)));
            strategy = '';
            if isfield(planConfig,'strategy')
                strategy = char(planConfig.strategy);
            end

            suffix = planWorkflow.results.PlanLabels.robustVariantSuffix( ...
                strategy,variant);
            if ~isempty(suffix)
                label = [label ' (' suffix ')'];
            elseif numel(variants) > 1 && isfield(variant,'label') && ...
                    ~isempty(variant.label)
                label = [label ' (' char(variant.label) ')'];
            end
        end

        function label = robustResultLabelFromRunConfig( ...
                runConfig,resultIx,fallbackLabel)
            if nargin < 3
                fallbackLabel = sprintf('robust_%d',resultIx);
            end
            label = char(fallbackLabel);

            robustPlans = ...
                planWorkflow.config.RobustPlanConfig.plansFromRunConfig( ...
                runConfig);
            if isempty(robustPlans)
                return;
            end

            resultCount = 0;
            robustPlans = robustPlans(:)';
            for planIx = 1:numel(robustPlans)
                planConfig = robustPlans(planIx);
                numVariants = 1;
                if isfield(planConfig,'variants') && ...
                        ~isempty(planConfig.variants)
                    numVariants = numel(planConfig.variants);
                end
                for variantIx = 1:numVariants
                    resultCount = resultCount + 1;
                    if resultCount == resultIx
                        label = ...
                            planWorkflow.results.PlanLabels.robustResultLabel( ...
                            planConfig,variantIx);
                        return;
                    end
                end
            end
        end

        function label = planTimingLabel(runConfig,label,role, ...
                robustPlanId,variantId)
            label = char(label);
            if ~strcmp(char(role),'robust') || isempty(char(variantId))
                return;
            end

            robustPlans = ...
                planWorkflow.config.RobustPlanConfig.plansFromRunConfig( ...
                runConfig);
            for planIx = 1:numel(robustPlans)
                planConfig = robustPlans(planIx);
                if ~strcmp(char(planConfig.id),char(robustPlanId)) || ...
                        isempty(planConfig.variants)
                    continue;
                end

                variants = planConfig.variants;
                for variantIx = 1:numel(variants)
                    if strcmp(char(variants(variantIx).id),char(variantId))
                        label = ...
                            planWorkflow.results.PlanLabels.robustResultLabel( ...
                            planConfig,variantIx);
                        return;
                    end
                end
            end
        end

        function label = planLabel(planConfig,defaultLabel)
            label = char(defaultLabel);
            if isstruct(planConfig) && isfield(planConfig,'label') && ...
                    ~isempty(planConfig.label)
                label = char(planConfig.label);
            end
        end

        function suffix = robustVariantSuffix(robustness,variant)
            suffix = '';
            switch char(robustness)
                case 'INTERVAL2'
                    if isfield(variant,'theta1')
                        suffix = ['theta1=' ...
                            planWorkflow.results.PlanLabels.numberText( ...
                            variant.theta1)];
                    end
                case 'INTERVAL3'
                    if isfield(variant,'theta1') && isfield(variant,'theta2')
                        suffix = ['theta1=' ...
                            planWorkflow.results.PlanLabels.numberText( ...
                            variant.theta1) ', theta2=' ...
                            planWorkflow.results.PlanLabels.numberText( ...
                            variant.theta2)];
                    end
                case 'c-COWC'
                    if isfield(variant,'p1') && isfield(variant,'p2')
                        suffix = ['p1=' ...
                            planWorkflow.results.PlanLabels.numberText( ...
                            variant.p1) ', p2=' ...
                            planWorkflow.results.PlanLabels.numberText( ...
                            variant.p2)];
                    end
            end
        end

        function text = numberText(value)
            text = strtrim(num2str(value,'%g'));
        end
    end
end
