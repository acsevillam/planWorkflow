classdef RobustPlanConfig
    % RobustPlanConfig Normalizes the canonical robust-plan workflow contract.

    methods (Static)
        function precompute = defaults()
            precompute = struct();
            precompute.reference = planWorkflow.config.RobustPlanConfig.defaultReference();
            precompute.robustPlans = repmat( ...
                planWorkflow.config.RobustPlanConfig.defaultPlan(),1,0);
        end

        function reference = defaultReference()
            referenceScenario = ...
                planWorkflow.config.RobustPlanConfig.defaultScenario( ...
                'nomScen');
            referenceScenario.ctActive = false;
            referenceScenario.setupActive = false;
            referenceScenario.rangeActive = false;
            referenceScenario.gantryActive = false;
            referenceScenario.couchActive = false;
            reference = struct( ...
                'label','', ...
                'strategy','none', ...
                'optimization4D', ...
                planWorkflow.config.RobustPlanConfig.defaultOptimization4D(), ...
                'scenario',referenceScenario, ...
                'strategyOptions',struct(), ...
                'variants', ...
                planWorkflow.config.RobustPlanConfig.defaultVariants( ...
                'none'));
        end

        function plan = defaultPlan()
            plan = struct( ...
                'id','', ...
                'label','', ...
                'objectiveSetName','', ...
                'strategy','none', ...
                'optimization4D', ...
                planWorkflow.config.RobustPlanConfig.defaultOptimization4D(), ...
                'scenario', ...
                planWorkflow.config.RobustPlanConfig.defaultScenario( ...
                'wcScen'), ...
                'strategyOptions',struct(), ...
                'variants',[]);
        end

        function scenario = defaultScenario(mode)
            if nargin < 1 || isempty(mode)
                mode = 'wcScen';
            end
            scenario = planWorkflow.config.ScenarioSpec.defaults(mode);
        end

        function options = defaultStrategyOptions(strategy)
            if nargin < 1 || isempty(strategy)
                error(['planWorkflow:config:RobustPlanConfig:' ...
                    'MissingStrategy'], ...
                    'defaultStrategyOptions requires an explicit strategy.');
            end
            options = ...
                planWorkflow.config.RobustStrategySpec.defaultStrategyOptions( ...
                strategy);
        end

        function options = defaultOptimization4D()
            options = struct( ...
                'enabled',false, ...
                'scen4D','all');
        end

        function variants = defaultVariants(strategy)
            if nargin < 1 || isempty(strategy)
                strategy = 'none';
            end
            variants = planWorkflow.config.RobustPlanConfig.defaultVariant( ...
                strategy,1);
        end

        function variant = defaultVariant(strategy,variantIx)
            if nargin < 2 || isempty(variantIx)
                variantIx = 1;
            end
            variant = ...
                planWorkflow.config.RobustStrategySpec.defaultVariant( ...
                strategy,variantIx);
        end

        function fields = variantParameterFields(strategy)
            fields = ...
                planWorkflow.config.RobustStrategySpec.variantParameterFields( ...
                strategy);
        end

        function fields = allVariantParameterFields()
            fields = ...
                planWorkflow.config.RobustStrategySpec.allVariantParameterFields();
        end

        function precompute = normalizePrecompute(precompute)
            if nargin < 1 || isempty(precompute)
                precompute = struct();
            end
            if ~isstruct(precompute) || ~isscalar(precompute)
                error('planWorkflow:config:RobustPlanConfig:InvalidPrecompute', ...
                    'config.precompute must be a scalar struct.');
            end

            planWorkflow.config.RobustPlanConfig.assertNoLegacyFields( ...
                precompute,'config.precompute');

            defaults = planWorkflow.config.RobustPlanConfig.defaults();
            precompute = planWorkflow.config.RobustPlanConfig.mergeDefaults( ...
                precompute,defaults);
            precompute.reference = ...
                planWorkflow.config.RobustPlanConfig.normalizeReference( ...
                precompute.reference);
            precompute.robustPlans = ...
                planWorkflow.config.RobustPlanConfig.normalizePlans( ...
                precompute.robustPlans);
        end

        function reference = normalizeReference(reference)
            if nargin < 1 || isempty(reference)
                reference = struct();
            end
            if ~isstruct(reference) || ~isscalar(reference)
                error('planWorkflow:config:RobustPlanConfig:InvalidReference', ...
                    'config.precompute.reference must be a scalar struct.');
            end

            planWorkflow.config.RobustPlanConfig.assertNoLegacyFields( ...
                reference,'config.precompute.reference');
            allowed = {'label','strategy','optimization4D','scenario', ...
                'strategyOptions','variants'};
            planWorkflow.config.RobustPlanConfig.assertAllowedFields( ...
                reference,allowed,'config.precompute.reference');
            defaults = planWorkflow.config.RobustPlanConfig.defaultReference();
            reference = planWorkflow.config.RobustPlanConfig.mergeDefaults( ...
                reference,defaults);
            reference.label = ...
                planWorkflow.config.RobustPlanConfig.optionalText( ...
                reference.label,'config.precompute.reference.label');
            reference.strategy = ...
                planWorkflow.config.RobustPlanConfig.strategyText( ...
                reference.strategy,'config.precompute.reference.strategy');
            reference.scenario = ...
                planWorkflow.config.RobustPlanConfig.normalizeScenario( ...
                reference.scenario,defaults.scenario, ...
                'config.precompute.reference.scenario');
            reference.optimization4D = ...
                planWorkflow.config.RobustPlanConfig.optimization4DFromScenario( ...
                reference.scenario);
            reference.strategyOptions = ...
                planWorkflow.config.RobustPlanConfig.normalizeStrategyOptionsForStrategy( ...
                reference.strategy,reference.strategyOptions, ...
                'config.precompute.reference');
            reference.variants = ...
                planWorkflow.config.RobustPlanConfig.normalizeVariants( ...
                reference.variants,reference.strategy, ...
                'config.precompute.reference.variants');
        end

        function plans = normalizePlans(plans)
            if nargin < 1 || isempty(plans)
                plans = repmat( ...
                    planWorkflow.config.RobustPlanConfig.defaultPlan(),1,0);
                return;
            end
            if ~isstruct(plans)
                error('planWorkflow:config:RobustPlanConfig:InvalidRobustPlans', ...
                    'config.precompute.robustPlans must be a struct array.');
            end

            if planWorkflow.config.RobustPlanConfig.isNamedPlanStruct(plans)
                plans = planWorkflow.config.RobustPlanConfig.namedPlansToArray( ...
                    plans);
            end

            plans = plans(:)';
            normalized = repmat( ...
                planWorkflow.config.RobustPlanConfig.defaultPlan(), ...
                1,numel(plans));
            ids = cell(1,numel(plans));
            for planIx = 1:numel(plans)
                normalized(planIx) = ...
                    planWorkflow.config.RobustPlanConfig.normalizePlan( ...
                    plans(planIx),planIx);
                ids{planIx} = char(normalized(planIx).id);
            end
            if numel(unique(ids)) ~= numel(ids)
                error('planWorkflow:config:RobustPlanConfig:DuplicateRobustPlanId', ...
                    'config.precompute.robustPlans ids must be unique.');
            end
            plans = normalized;
        end

        function plan = normalizePlan(plan,planIx)
            if nargin < 2 || isempty(planIx)
                planIx = 1;
            end
            if ~isstruct(plan) || ~isscalar(plan)
                error('planWorkflow:config:RobustPlanConfig:InvalidRobustPlan', ...
                    'Each robust plan must be a scalar struct.');
            end
            planWorkflow.config.RobustPlanConfig.assertNoLegacyFields( ...
                plan,'config.precompute.robustPlans');
            allowed = {'id','label','objectiveSetName','strategy', ...
                'optimization4D','scenario','strategyOptions','variants'};
            planWorkflow.config.RobustPlanConfig.assertAllowedFields( ...
                plan,allowed,'config.precompute.robustPlans');

            defaults = planWorkflow.config.RobustPlanConfig.defaultPlan();
            defaults.id = sprintf('robust_%d',planIx);
            defaults.label = sprintf('Robust %d',planIx);
            defaults.objectiveSetName = defaults.id;
            plan = planWorkflow.config.RobustPlanConfig.mergeDefaults( ...
                plan,defaults);

            plan.id = planWorkflow.config.RobustPlanConfig.identifierText( ...
                plan.id,'config.precompute.robustPlans.id');
            plan.label = planWorkflow.config.RobustPlanConfig.requiredText( ...
                plan.label,'config.precompute.robustPlans.label');
            plan.objectiveSetName = ...
                planWorkflow.config.RobustPlanConfig.identifierText( ...
                plan.objectiveSetName, ...
                'config.precompute.robustPlans.objectiveSetName');
            plan.strategy = planWorkflow.config.RobustPlanConfig.strategyText( ...
                plan.strategy,'config.precompute.robustPlans.strategy');
            plan.scenario = ...
                planWorkflow.config.RobustPlanConfig.normalizeScenario( ...
                plan.scenario,defaults.scenario, ...
                'config.precompute.robustPlans.scenario');
            plan.optimization4D = ...
                planWorkflow.config.RobustPlanConfig.optimization4DFromScenario( ...
                plan.scenario);
            plan.strategyOptions = ...
                planWorkflow.config.RobustPlanConfig.normalizeStrategyOptionsForStrategy( ...
                plan.strategy,plan.strategyOptions, ...
                'config.precompute.robustPlans');
            plan.variants = ...
                planWorkflow.config.RobustPlanConfig.normalizeVariants( ...
                plan.variants,plan.strategy, ...
                'config.precompute.robustPlans.variants');
        end

        function scenario = normalizeScenario(scenario,defaults,context)
            if nargin < 2 || isempty(defaults)
                defaults = ...
                    planWorkflow.config.RobustPlanConfig.defaultScenario();
            end
            if nargin < 3
                context = 'scenario';
            end
            scenario = planWorkflow.config.ScenarioSpec.normalize( ...
                scenario,defaults,context);
        end

        function scenario = matRadScenario(scenario)
            scenario = planWorkflow.config.ScenarioSpec.matRadScenario( ...
                scenario);
        end

        function options = normalizeStrategyOptions(strategy,options)
            if nargin < 1 || isempty(strategy)
                error(['planWorkflow:config:RobustPlanConfig:' ...
                    'MissingStrategy'], ...
                    'normalizeStrategyOptions requires an explicit strategy.');
            end
            if nargin < 2 || isempty(options)
                options = struct();
            end
            if ~isstruct(options) || ~isscalar(options)
                error('planWorkflow:config:RobustPlanConfig:InvalidStrategyOptions', ...
                    'strategyOptions must be a scalar struct.');
            end
            options = ...
                planWorkflow.config.RobustStrategySpec.normalizeStrategyOptions( ...
                strategy,options,'strategyOptions');
        end

        function options = optimization4DFromScenario(scenario)
            options = ...
                planWorkflow.config.RobustPlanConfig.defaultOptimization4D();
            if isstruct(scenario) && isfield(scenario,'ctActive') && ...
                    logical(scenario.ctActive)
                options.enabled = true;
                options.scen4D = 'all';
            end
        end

        function options = normalizeStrategyOptionsForStrategy( ...
                strategy,options,context)
            if nargin < 2 || isempty(options)
                options = struct();
            end
            if nargin < 3 || isempty(context)
                context = 'robustPlan';
            end
            if ~isstruct(options) || ~isscalar(options)
                error('planWorkflow:config:RobustPlanConfig:InvalidStrategyOptions', ...
                    '%s.strategyOptions must be a scalar struct.',context);
            end
            options = ...
                planWorkflow.config.RobustStrategySpec.normalizeStrategyOptions( ...
                strategy,options,[context '.strategyOptions']);
        end

        function variants = normalizeVariants(variants,strategy,context)
            if nargin < 3
                context = 'variants';
            end
            if isempty(variants)
                variants = ...
                    planWorkflow.config.RobustPlanConfig.defaultVariants( ...
                    strategy);
            end
            if ~isstruct(variants) || isempty(variants)
                error('planWorkflow:config:RobustPlanConfig:InvalidVariants', ...
                    '%s must contain at least one variant.',context);
            end
            variants = variants(:)';
            normalized = repmat( ...
                planWorkflow.config.RobustPlanConfig.defaultVariant( ...
                strategy,1),1,numel(variants));
            ids = cell(1,numel(variants));
            for variantIx = 1:numel(variants)
                normalized(variantIx) = ...
                    planWorkflow.config.RobustPlanConfig.normalizeVariant( ...
                    variants(variantIx),strategy,variantIx,context);
                ids{variantIx} = char(normalized(variantIx).id);
            end
            if numel(unique(ids)) ~= numel(ids)
                error('planWorkflow:config:RobustPlanConfig:DuplicateVariantId', ...
                    '%s ids must be unique.',context);
            end
            variants = normalized;
        end

        function variant = normalizeVariant(variant,strategy,variantIx,context)
            if ~isstruct(variant) || ~isscalar(variant)
                error('planWorkflow:config:RobustPlanConfig:InvalidVariant', ...
                    '%s entries must be scalar structs.',context);
            end
            variantContext = sprintf('%s(%d)',context,variantIx);
            defaultVariant = ...
                planWorkflow.config.RobustPlanConfig.defaultVariant( ...
                strategy,variantIx);
            allowed = fieldnames(defaultVariant)';
            planWorkflow.config.RobustPlanConfig.assertAllowedFields( ...
                variant,allowed,variantContext);
            required = ...
                planWorkflow.config.RobustPlanConfig.requiredVariantFields( ...
                strategy);
            for fieldIx = 1:numel(required)
                fieldName = required{fieldIx};
                if ~isfield(variant,fieldName) || isempty(variant.(fieldName))
                    error('planWorkflow:config:RobustPlanConfig:MissingVariantParameter', ...
                        '%s.%s is required for %s variants.', ...
                        variantContext,fieldName,char(strategy));
                end
            end
            variant = planWorkflow.config.RobustPlanConfig.mergeDefaults( ...
                variant,defaultVariant);
            variant.id = planWorkflow.config.RobustPlanConfig.identifierText( ...
                variant.id,[variantContext '.id']);
            variant.label = planWorkflow.config.RobustPlanConfig.requiredText( ...
                variant.label,[variantContext '.label']);

            for fieldIx = 1:numel(required)
                fieldName = required{fieldIx};
                variant.(fieldName) = finiteNumericScalar( ...
                    variant.(fieldName),[variantContext '.' fieldName]);
            end
        end

        function runConfig = variantRunConfig(runConfig,plan,variantIx)
            % Transient adapter for existing strategy implementations.
            variant = plan.variants(variantIx);
            runConfig.strategy = char(plan.strategy);
            runConfig.variant = variant;
            if ~isempty(fieldnames(plan.strategyOptions))
                runConfig.strategyOptions = plan.strategyOptions;
            elseif isfield(runConfig,'strategyOptions')
                runConfig = rmfield(runConfig,'strategyOptions');
            end
        end

        function plans = plansFromRunConfig(runConfig)
            plans = repmat( ...
                planWorkflow.config.RobustPlanConfig.defaultPlan(),1,0);
            if isstruct(runConfig) && isfield(runConfig,'precompute') && ...
                    isstruct(runConfig.precompute) && ...
                    isfield(runConfig.precompute,'robustPlans')
                plans = ...
                    planWorkflow.config.RobustPlanConfig.normalizePlans( ...
                    runConfig.precompute.robustPlans);
            end
        end

        function reference = referenceFromRunConfig(runConfig)
            if isstruct(runConfig) && isfield(runConfig,'precompute') && ...
                    isstruct(runConfig.precompute) && ...
                    isfield(runConfig.precompute,'reference')
                reference = ...
                    planWorkflow.config.RobustPlanConfig.normalizeReference( ...
                    runConfig.precompute.reference);
            else
                reference = planWorkflow.config.RobustPlanConfig.defaultReference();
            end
        end

        function names = strategyNames(plans)
            names = cell(1,numel(plans));
            for i = 1:numel(plans)
                names{i} = char(plans(i).strategy);
            end
        end

        function label = pathLabel(plans)
            if isempty(plans)
                label = 'none';
                return;
            end
            parts = cell(1,numel(plans));
            for i = 1:numel(plans)
                parts{i} = [char(plans(i).id) '_' char(plans(i).strategy)];
            end
            label = strjoin(parts,'+');
        end

        function assertNoLegacyFields(config,context)
            legacyFields = {'robustness','robust_scen_mode', ...
                'p1','p2','theta1','theta2','KMode','kmax', ...
                'retentionThreshold'};
            replacements = {'strategy','scenario.mode', ...
                'variants.p1','variants.p2','variants.theta1', ...
                'variants.theta2','strategyOptions.KMode', ...
                'strategyOptions.kmax', ...
                'strategyOptions.retentionThreshold'};
            for i = 1:numel(legacyFields)
                if isfield(config,legacyFields{i})
                    error('planWorkflow:config:RobustPlanConfig:LegacyField', ...
                        ['Legacy robust config field "%s.%s" is not ' ...
                         'supported. Use "%s.%s" instead.'], ...
                        context,legacyFields{i},context,replacements{i});
                end
            end
        end

        function assertAllowedFields(config,allowed,context)
            fields = fieldnames(config);
            for i = 1:numel(fields)
                if ~any(strcmp(fields{i},allowed))
                    error('planWorkflow:config:RobustPlanConfig:UnsupportedField', ...
                        'Unsupported %s field "%s".',context,fields{i});
                end
            end
        end
    end

    methods (Static, Access = private)
        function tf = isNamedPlanStruct(plans)
            tf = false;
            if ~isscalar(plans)
                return;
            end
            planFields = fieldnames(plans);
            allowed = {'id','label','objectiveSetName','strategy', ...
                'optimization4D','scenario','strategyOptions','variants'};
            if isempty(planFields) || all(ismember(planFields,allowed))
                return;
            end
            for i = 1:numel(planFields)
                fieldValue = plans.(planFields{i});
                if ~isvarname(planFields{i}) || ~isstruct(fieldValue) || ...
                        ~isscalar(fieldValue)
                    return;
                end
            end
            tf = true;
        end

        function plans = namedPlansToArray(namedPlans)
            ids = fieldnames(namedPlans);
            plans = repmat( ...
                planWorkflow.config.RobustPlanConfig.defaultPlan(), ...
                1,numel(ids));
            for planIx = 1:numel(ids)
                planId = ids{planIx};
                plan = namedPlans.(planId);
                if isfield(plan,'id') && ~strcmp(char(plan.id),planId)
                    error('planWorkflow:config:RobustPlanConfig:RobustPlanIdMismatch', ...
                        ['config.precompute.robustPlans.%s.id must match ' ...
                         'the robust plan field name.'],planId);
                end
                plan.id = planId;
                if ~isfield(plan,'objectiveSetName') || ...
                        isempty(plan.objectiveSetName)
                    plan.objectiveSetName = planId;
                end
                plans(planIx) = ...
                    planWorkflow.config.RobustPlanConfig.normalizePlan( ...
                    plan,planIx);
            end
        end

        function merged = mergeDefaults(value,defaults)
            merged = value;
            fields = fieldnames(defaults);
            for i = 1:numel(fields)
                fieldName = fields{i};
                if ~isfield(merged,fieldName) || isempty(merged.(fieldName))
                    merged.(fieldName) = defaults.(fieldName);
                elseif isstruct(merged.(fieldName)) && ...
                        isstruct(defaults.(fieldName)) && ...
                        isscalar(merged.(fieldName)) && ...
                        isscalar(defaults.(fieldName))
                    merged.(fieldName) = ...
                        planWorkflow.config.RobustPlanConfig.mergeDefaults( ...
                        merged.(fieldName),defaults.(fieldName));
                end
            end
        end

        function value = optionalText(value,context)
            if ~(ischar(value) || (isstring(value) && isscalar(value)))
                error('planWorkflow:config:RobustPlanConfig:InvalidText', ...
                    '%s must be text.',context);
            end
            value = regexprep(strtrim(char(string(value))),'\s+',' ');
        end

        function value = requiredText(value,context)
            value = planWorkflow.config.RobustPlanConfig.optionalText( ...
                value,context);
            if isempty(value)
                error('planWorkflow:config:RobustPlanConfig:InvalidText', ...
                    '%s must be non-empty text.',context);
            end
        end

        function value = identifierText(value,context)
            value = planWorkflow.config.RobustPlanConfig.requiredText( ...
                value,context);
            if ~isvarname(value)
                error('planWorkflow:config:RobustPlanConfig:InvalidIdentifier', ...
                    '%s must be a valid MATLAB identifier.',context);
            end
        end

        function value = strategyText(value,context)
            value = planWorkflow.config.RobustPlanConfig.requiredText( ...
                value,context);
            supported = ...
                planWorkflow.matRadCapabilitiesReader.supportedWorkflowRobustnessModes();
            if ~any(strcmp(value,supported))
                error('planWorkflow:config:RobustPlanConfig:UnknownStrategy', ...
                    'Unknown robust optimization strategy "%s" in %s.', ...
                        value,context);
            end
        end

        function fields = requiredVariantFields(strategy)
            fields = ...
                planWorkflow.config.RobustStrategySpec.variantParameterFields( ...
                strategy);
        end

    end
end

function value = logicalScalar(value,context)
if ischar(value) || (isstring(value) && isscalar(value))
    switch lower(char(value))
        case {'true','1','yes','on'}
            value = true;
        case {'false','0','no','off'}
            value = false;
        otherwise
            error('planWorkflow:config:RobustPlanConfig:InvalidLogical', ...
                '%s must be scalar logical.',context);
    end
else
    value = logical(value);
end
if ~isscalar(value)
    error('planWorkflow:config:RobustPlanConfig:InvalidLogical', ...
        '%s must be scalar logical.',context);
end
end

function value = positiveIntegerScalar(value,context)
if ~(isnumeric(value) && isscalar(value) && isfinite(value) && ...
        value >= 1 && round(value) == value)
    error('planWorkflow:config:RobustPlanConfig:InvalidPositiveInteger', ...
        '%s must be a positive integer scalar.',context);
end
end

function value = positiveIntegerVector(value,context)
if ~(isnumeric(value) && isvector(value) && ~isempty(value) && ...
        all(isfinite(value(:))) && all(value(:) >= 1) && ...
        all(round(value(:)) == value(:)))
    error('planWorkflow:config:RobustPlanConfig:InvalidPositiveIntegerVector', ...
        '%s must be a numeric vector of positive integer scenario indices.', ...
        context);
end
value = value(:)';
end

function value = optionalNonnegativeIntegerScalar(value,context)
if isempty(value)
    value = [];
    return;
end
if ~(isnumeric(value) && isscalar(value) && isfinite(value) && ...
        value >= 0 && round(value) == value)
    error('planWorkflow:config:RobustPlanConfig:InvalidOptionalInteger', ...
        '%s must be empty or a non-negative integer scalar.',context);
end
end

function value = finiteNumericScalar(value,context)
if ~(isnumeric(value) && isscalar(value) && isfinite(value))
    error('planWorkflow:config:RobustPlanConfig:InvalidNumericScalar', ...
        '%s must be a finite numeric scalar.',context);
end
end

function value = nonnegativeNumericScalar(value,context)
value = finiteNumericScalar(value,context);
if value < 0
    error('planWorkflow:config:RobustPlanConfig:InvalidNumericScalar', ...
        '%s must be a non-negative numeric scalar.',context);
end
end
