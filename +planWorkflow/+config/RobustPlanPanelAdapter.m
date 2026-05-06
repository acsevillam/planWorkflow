classdef RobustPlanPanelAdapter
    % RobustPlanPanelAdapter Converts between flat GUI rows and robust config.

    methods (Static)
        function config = referencePanelConfig(runConfig)
            reference = ...
                planWorkflow.config.RobustPlanConfig.referenceFromRunConfig( ...
                runConfig);
            config = struct();
            config.reference_label = reference.label;
            config.reference_robustness = reference.strategy;
            config = ...
                planWorkflow.config.RobustPlanPanelAdapter.copyScenarioToPanel( ...
                config,reference.scenario,'reference');
            config = ...
                planWorkflow.config.RobustPlanPanelAdapter.copyVariantToPanel( ...
                config,reference.variants(1),'reference');
            config = ...
                planWorkflow.config.RobustPlanPanelAdapter.copyOptionsToPanel( ...
                config,reference,'reference');
        end

        function config = defaultReferencePanelConfig()
            runConfig = struct();
            runConfig.precompute = struct();
            runConfig.precompute.reference = ...
                planWorkflow.config.RobustPlanConfig.defaultReference();
            config = ...
                planWorkflow.config.RobustPlanPanelAdapter.referencePanelConfig( ...
                runConfig);
        end

        function runConfig = applyReferencePanelConfig(runConfig,config)
            if ~isfield(runConfig,'precompute') || ...
                    ~isstruct(runConfig.precompute)
                runConfig.precompute = ...
                    planWorkflow.config.RobustPlanConfig.defaults();
            end

            reference = ...
                planWorkflow.config.RobustPlanConfig.defaultReference();
            reference.label = ...
                planWorkflow.config.RobustPlanPanelAdapter.normalizeLabel( ...
                config.reference_label,false);
            reference.strategy = char(config.reference_robustness);
            reference.scenario = ...
                planWorkflow.config.RobustPlanPanelAdapter.scenarioFromPanel( ...
                config,'reference',config.reference_scen_mode);
            reference.strategyOptions = ...
                planWorkflow.config.RobustPlanPanelAdapter.optionsFromPanel( ...
                config,reference.strategy,'reference');
            reference.variants = ...
                planWorkflow.config.RobustPlanPanelAdapter.variantsFromPanel( ...
                config,reference.strategy,'reference',1);
            runConfig.precompute.reference = ...
                planWorkflow.config.RobustPlanConfig.normalizeReference( ...
                reference);
        end

        function plan = defaultPlanFromRunConfig(~,objectiveSet)
            plan = planWorkflow.config.RobustPlanConfig.defaultPlan();
            plan.id = char(objectiveSet.id);
            plan.label = char(objectiveSet.label);
            plan.objectiveSetName = char(objectiveSet.id);
        end

        function config = defaultPlanPanelConfig(objectiveSet)
            plan = ...
                planWorkflow.config.RobustPlanPanelAdapter.defaultPlanFromRunConfig( ...
                struct(),objectiveSet);
            config = ...
                planWorkflow.config.RobustPlanPanelAdapter.planPanelConfig( ...
                plan);
        end

        function plan = completePlan(plan,runConfig)
            defaults = ...
                planWorkflow.config.RobustPlanPanelAdapter.defaultPlanFromRunConfig( ...
                runConfig,struct('id',plan.id,'label',plan.label));
            plan = planWorkflow.config.RobustPlanPanelAdapter.mergeMissing( ...
                plan,defaults);
            if ~isfield(plan,'variants') || isempty(plan.variants)
                plan.variants = defaults.variants;
            end
            plan = ...
                planWorkflow.config.RobustPlanConfig.normalizePlan(plan,1);
        end

        function config = planPanelConfig(plan)
            if isfield(plan,'strategy')
                config = struct('id',plan.id,'label',plan.label, ...
                    'objectiveSetName',plan.objectiveSetName, ...
                    'robustness',plan.strategy);
                config = ...
                    planWorkflow.config.RobustPlanPanelAdapter.copyScenarioToPanel( ...
                    config,plan.scenario,'');
                config.variants = plan.variants;
                config.strategyOptions = plan.strategyOptions;
            else
                config = plan;
            end

            variants = planWorkflow.config.RobustPlanPanelAdapter.panelVariants( ...
                config);
            fields = ...
                planWorkflow.config.RobustStrategySpec.allVariantParameterFields();
            for i = 1:numel(fields)
                config.(fields{i}) = ...
                    planWorkflow.config.RobustPlanPanelAdapter.variantValues( ...
                    variants,fields{i},1);
            end
            config = ...
                planWorkflow.config.RobustPlanPanelAdapter.copyOptionsToPanel( ...
                config,plan,'');
        end

        function plan = planFromPanelConfig(config)
            plan = planWorkflow.config.RobustPlanConfig.defaultPlan();
            plan.id = char(config.id);
            plan.label = ...
                planWorkflow.config.RobustPlanPanelAdapter.normalizeLabel( ...
                config.label,true);
            plan.objectiveSetName = char(config.objectiveSetName);
            plan.strategy = char(config.robustness);
            plan.scenario = ...
                planWorkflow.config.RobustPlanPanelAdapter.scenarioFromPanel( ...
                config,'',config.scen_mode);
            plan.strategyOptions = ...
                planWorkflow.config.RobustPlanPanelAdapter.optionsFromPanel( ...
                config,plan.strategy,'');
            plan.variants = ...
                planWorkflow.config.RobustPlanPanelAdapter.variantsFromPanel( ...
                config,plan.strategy,'',[]);
            plan = ...
                planWorkflow.config.RobustPlanConfig.normalizePlan(plan,1);
        end

        function options = strategyOptionsForPanel(config)
            strategy = ...
                planWorkflow.config.RobustPlanPanelAdapter.strategyFromPanelSource( ...
                config);
            activeOptions = ...
                planWorkflow.config.RobustStrategySpec.defaultStrategyOptions( ...
                strategy);
            if isstruct(config) && isfield(config,'strategyOptions') && ...
                    isstruct(config.strategyOptions) && ...
                    isscalar(config.strategyOptions)
                activeOptions = ...
                    planWorkflow.config.RobustPlanPanelAdapter.mergeMissing( ...
                    config.strategyOptions,activeOptions);
            end

            options = ...
                planWorkflow.config.RobustPlanPanelAdapter.defaultPanelOptions();
            fields = fieldnames(activeOptions);
            for i = 1:numel(fields)
                options.(fields{i}) = activeOptions.(fields{i});
            end
        end
    end

    methods (Static, Access = private)
        function config = copyScenarioToPanel(config,scenario,prefix)
            scenario = ...
                planWorkflow.config.ScenarioSpec.matRadScenario( ...
                scenario);
            fields = fieldnames(scenario);
            for i = 1:numel(fields)
                fieldName = fields{i};
                if strcmp(fieldName,'scen_mode')
                    fieldName = 'mode';
                end
                config.(planWorkflow.config.ScenarioSpec.panelFieldName( ...
                    prefix,fieldName)) = scenario.(fields{i});
            end
        end

        function scenario = scenarioFromPanel(config,prefix,mode)
            scenario = ...
                planWorkflow.config.ScenarioSpec.defaults(mode);
            fields = fieldnames(scenario);
            fields(strcmp(fields,'mode')) = [];
            for i = 1:numel(fields)
                panelField = ...
                    planWorkflow.config.ScenarioSpec.panelFieldName( ...
                    prefix,fields{i});
                if isfield(config,panelField)
                    scenario.(fields{i}) = config.(panelField);
                end
            end
        end

        function config = copyVariantToPanel(config,variant,prefix)
            fields = ...
                planWorkflow.config.RobustStrategySpec.allVariantParameterFields();
            for i = 1:numel(fields)
                fieldName = fields{i};
                config.(planWorkflow.config.RobustPlanPanelAdapter.prefixed( ...
                    prefix,fieldName)) = ...
                    planWorkflow.config.RobustPlanPanelAdapter.valueOrDefault( ...
                    variant,fieldName,1);
            end
        end

        function config = copyOptionsToPanel(config,source,prefix)
            options = ...
                planWorkflow.config.RobustPlanPanelAdapter.strategyOptionsForPanel( ...
                source);
            fields = ...
                planWorkflow.config.RobustStrategySpec.allStrategyOptionFields();
            for i = 1:numel(fields)
                fieldName = fields{i};
                config.(planWorkflow.config.RobustPlanPanelAdapter.prefixed( ...
                    prefix,fieldName)) = options.(fieldName);
            end
        end

        function strategy = strategyFromPanelSource(config)
            strategy = 'none';
            if ~isstruct(config)
                return;
            end
            if isfield(config,'strategy') && ~isempty(config.strategy)
                strategy = char(config.strategy);
            elseif isfield(config,'robustness') && ~isempty(config.robustness)
                strategy = char(config.robustness);
            elseif isfield(config,'reference_robustness') && ...
                    ~isempty(config.reference_robustness)
                strategy = char(config.reference_robustness);
            end
        end

        function options = defaultPanelOptions()
            specs = planWorkflow.config.RobustStrategySpec.allParameterSpecs();
            fields = ...
                planWorkflow.config.RobustStrategySpec.allStrategyOptionFields();
            options = struct();
            for i = 1:numel(fields)
                specIx = find(strcmp({specs.name},fields{i}),1);
                if isempty(specIx)
                    options.(fields{i}) = [];
                else
                    options.(fields{i}) = specs(specIx).default;
                end
            end
        end

        function options = optionsFromPanel(config,strategy,prefix)
            optionFields = ...
                planWorkflow.config.RobustStrategySpec.strategyOptionFields( ...
                strategy);
            options = struct();
            if isempty(optionFields)
                return;
            end
            defaults = ...
                planWorkflow.config.RobustStrategySpec.defaultStrategyOptions( ...
                strategy);
            for i = 1:numel(optionFields)
                fieldName = optionFields{i};
                options.(fieldName) = ...
                    planWorkflow.config.RobustPlanPanelAdapter.valueOrDefault( ...
                    config, ...
                    planWorkflow.config.RobustPlanPanelAdapter.prefixed( ...
                    prefix,fieldName),defaults.(fieldName));
            end
        end

        function variants = variantsFromPanel(config,strategy,prefix,forcedCount)
            if nargin < 4 || isempty(forcedCount)
                forcedCount = ...
                    planWorkflow.config.RobustPlanPanelAdapter.variantCount( ...
                    config,strategy,prefix);
            end
            variants = repmat( ...
                planWorkflow.config.RobustPlanConfig.defaultVariant( ...
                strategy,1),1,forcedCount);
            parameterFields = ...
                planWorkflow.config.RobustStrategySpec.variantParameterFields( ...
                strategy);
            for i = 1:forcedCount
                variants(i).id = sprintf('variant_%d',i);
                variants(i).label = sprintf('Variant %d',i);
                for fieldIx = 1:numel(parameterFields)
                    fieldName = parameterFields{fieldIx};
                    variants(i).(fieldName) = ...
                        planWorkflow.config.RobustPlanPanelAdapter.indexed( ...
                        planWorkflow.config.RobustPlanPanelAdapter.valueOrDefault( ...
                        config, ...
                        planWorkflow.config.RobustPlanPanelAdapter.prefixed( ...
                        prefix,fieldName),variants(i).(fieldName)),i);
                end
            end
        end

        function variants = panelVariants(config)
            if isfield(config,'variants') && ~isempty(config.variants) && ...
                    isstruct(config.variants)
                variants = config.variants(:)';
            else
                variants = ...
                    planWorkflow.config.RobustPlanPanelAdapter.variantsFromPanel( ...
                    config,config.robustness,'',[]);
            end
        end

        function count = variantCount(config,strategy,prefix)
            fields = ...
                planWorkflow.config.RobustStrategySpec.variantParameterFields( ...
                strategy);
            count = 1;
            for i = 1:numel(fields)
                value = ...
                    planWorkflow.config.RobustPlanPanelAdapter.valueOrDefault( ...
                    config, ...
                    planWorkflow.config.RobustPlanPanelAdapter.prefixed( ...
                    prefix,fields{i}),1);
                count = max(count,numel(value));
            end
        end

        function values = variantValues(variants,fieldName,defaultValue)
            values = repmat(defaultValue,1,numel(variants));
            for i = 1:numel(variants)
                if isfield(variants(i),fieldName)
                    values(i) = variants(i).(fieldName);
                end
            end
        end

        function value = indexed(values,index)
            values = values(:)';
            value = values(min(index,numel(values)));
        end

        function value = valueOrDefault(config,fieldName,defaultValue)
            if isstruct(config) && isfield(config,fieldName) && ...
                    ~isempty(config.(fieldName))
                value = config.(fieldName);
            else
                value = defaultValue;
            end
        end

        function merged = mergeMissing(value,defaults)
            merged = value;
            fields = fieldnames(defaults);
            for i = 1:numel(fields)
                if ~isfield(merged,fields{i}) || isempty(merged.(fields{i}))
                    merged.(fields{i}) = defaults.(fields{i});
                end
            end
        end

        function fieldName = prefixed(prefix,fieldName)
            if isempty(prefix)
                return;
            end
            fieldName = [char(prefix) '_' char(fieldName)];
        end

        function label = normalizeLabel(label,requireNonEmpty)
            label = regexprep(strtrim(char(string(label))),'\s+',' ');
            if requireNonEmpty && isempty(label)
                error('planWorkflow:config:RobustPlanPanelAdapter:InvalidPlanLabel', ...
                    'Plan label must be non-empty.');
            end
        end
    end
end
