classdef RobustStrategySpec
    % RobustStrategySpec Canonical robust-strategy parameter metadata.

    methods (Static)
        function specs = variantParameterSpecs(strategy)
            switch char(strategy)
                case 'c-COWC'
                    specs = [ ...
                        planWorkflow.config.RobustStrategySpec.spec( ...
                        'p1','p1','numericVector',1,true,{}) ...
                        planWorkflow.config.RobustStrategySpec.spec( ...
                        'p2','p2','numericVector',1,true,{})];
                case 'INTERVAL2'
                    specs = ...
                        planWorkflow.config.RobustStrategySpec.spec( ...
                        'theta1','theta1','numericVector',1.0,true,{});
                case 'INTERVAL3'
                    specs = [ ...
                        planWorkflow.config.RobustStrategySpec.spec( ...
                        'theta1','theta1','numericVector',1.0,true,{}) ...
                        planWorkflow.config.RobustStrategySpec.spec( ...
                        'theta2','theta2','numericVector',1.0,true,{})];
                case 'PROB2'
                    specs = planWorkflow.config.RobustStrategySpec.emptySpec();
                otherwise
                    specs = planWorkflow.config.RobustStrategySpec.emptySpec();
            end
        end

        function fields = variantParameterFields(strategy)
            specs = ...
                planWorkflow.config.RobustStrategySpec.variantParameterSpecs( ...
                strategy);
            fields = {specs.name};
        end

        function fields = allVariantParameterFields()
            strategies = ...
                planWorkflow.matRadCapabilitiesReader.supportedWorkflowRobustnessModes();
            fields = {};
            for strategyIx = 1:numel(strategies)
                fields = [fields, ...
                    planWorkflow.config.RobustStrategySpec.variantParameterFields( ...
                    strategies{strategyIx})]; %#ok<AGROW>
            end
            fields = unique(fields,'stable');
        end

        function variant = defaultVariant(strategy,variantIx)
            if nargin < 2 || isempty(variantIx)
                variantIx = 1;
            end
            variant = struct('id',sprintf('variant_%d',variantIx), ...
                'label',sprintf('Variant %d',variantIx));
            specs = ...
                planWorkflow.config.RobustStrategySpec.variantParameterSpecs( ...
                strategy);
            for specIx = 1:numel(specs)
                variant.(specs(specIx).name) = specs(specIx).default;
            end
        end

        function specs = strategyOptionSpecs(strategy)
            switch char(strategy)
                case 'INTERVAL2'
                    specs = ...
                        planWorkflow.config.RobustStrategySpec.spec( ...
                        'radiusMode','RadiusMode','char','std',true, ...
                        {'std','extreme'});
                case 'INTERVAL3'
                    specs = [ ...
                        planWorkflow.config.RobustStrategySpec.spec( ...
                        'radiusMode','RadiusMode','char','std',true, ...
                        {'std','extreme'}) ...
                        planWorkflow.config.RobustStrategySpec.spec( ...
                        'KMode','KMode','char','dynamic',true, ...
                        {'dynamic','static'}) ...
                        planWorkflow.config.RobustStrategySpec.spec( ...
                        'kmax','KMax','numericScalar',10,true,{}) ...
                        planWorkflow.config.RobustStrategySpec.spec( ...
                        'retentionThreshold','RetentionThreshold', ...
                        'numericScalar',1.0,true,{})];
                otherwise
                    specs = planWorkflow.config.RobustStrategySpec.emptySpec();
            end
        end

        function fields = strategyOptionFields(strategy)
            specs = ...
                planWorkflow.config.RobustStrategySpec.strategyOptionSpecs( ...
                strategy);
            fields = {specs.name};
        end

        function fields = allStrategyOptionFields()
            strategies = ...
                planWorkflow.matRadCapabilitiesReader.supportedWorkflowRobustnessModes();
            fields = {};
            for strategyIx = 1:numel(strategies)
                fields = [fields, ...
                    planWorkflow.config.RobustStrategySpec.strategyOptionFields( ...
                    strategies{strategyIx})]; %#ok<AGROW>
            end
            fields = unique(fields,'stable');
        end

        function specs = allParameterSpecs()
            strategies = ...
                planWorkflow.matRadCapabilitiesReader.supportedWorkflowRobustnessModes();
            specs = planWorkflow.config.RobustStrategySpec.emptySpec();
            names = {};
            for strategyIx = 1:numel(strategies)
                strategySpecs = [ ...
                    planWorkflow.config.RobustStrategySpec.variantParameterSpecs( ...
                    strategies{strategyIx}) ...
                    planWorkflow.config.RobustStrategySpec.strategyOptionSpecs( ...
                    strategies{strategyIx})];
                for specIx = 1:numel(strategySpecs)
                    if any(strcmp(strategySpecs(specIx).name,names))
                        continue;
                    end
                    specs(end + 1) = strategySpecs(specIx); %#ok<AGROW>
                    names{end + 1} = strategySpecs(specIx).name; %#ok<AGROW>
                end
            end
        end

        function values = optionValues(strategy,fieldName)
            specs = ...
                planWorkflow.config.RobustStrategySpec.strategyOptionSpecs( ...
                strategy);
            values = {};
            for specIx = 1:numel(specs)
                if strcmp(specs(specIx).name,char(fieldName))
                    values = specs(specIx).optionValues;
                    return;
                end
            end
        end

        function options = defaultStrategyOptions(strategy)
            if nargin < 1 || isempty(strategy)
                error(['planWorkflow:config:RobustStrategySpec:' ...
                    'MissingStrategy'], ...
                    'defaultStrategyOptions requires an explicit strategy.');
            end
            specs = ...
                planWorkflow.config.RobustStrategySpec.strategyOptionSpecs( ...
                strategy);
            options = struct();
            for specIx = 1:numel(specs)
                options.(specs(specIx).name) = specs(specIx).default;
            end
        end

        function options = normalizeStrategyOptions(strategy,options,context)
            if nargin < 2 || isempty(options)
                options = struct();
            end
            if nargin < 3 || isempty(context)
                context = 'robustnessOptions';
            end
            if ~isstruct(options) || ~isscalar(options)
                error('planWorkflow:config:RobustPlanConfig:InvalidStrategyOptions', ...
                    '%s must be a scalar struct.',context);
            end

            specs = ...
                planWorkflow.config.RobustStrategySpec.strategyOptionSpecs( ...
                strategy);
            allowed = {specs.name};
            planWorkflow.config.RobustStrategySpec.assertAllowedFields( ...
                options,allowed,context);
            if isempty(specs)
                options = struct();
                return;
            end

            defaults = ...
                planWorkflow.config.RobustStrategySpec.defaultStrategyOptions( ...
                strategy);
            options = planWorkflow.config.RobustStrategySpec.mergeDefaults( ...
                options,defaults);
            for specIx = 1:numel(specs)
                fieldName = specs(specIx).name;
                valueContext = [context '.' fieldName];
                switch fieldName
                    case {'KMode','radiusMode'}
                        options.(fieldName) = ...
                            planWorkflow.config.RobustStrategySpec.requiredText( ...
                            options.(fieldName),valueContext);
                        if ~any(strcmp(options.(fieldName), ...
                                specs(specIx).optionValues))
                            error('planWorkflow:config:RobustPlanConfig:InvalidStrategyOption', ...
                                '%s must be one of: %s.',valueContext, ...
                                strjoin(specs(specIx).optionValues,', '));
                        end
                    case 'kmax'
                        options.(fieldName) = ...
                            planWorkflow.config.RobustStrategySpec.positiveIntegerScalar( ...
                            options.(fieldName),valueContext);
                    otherwise
                        options.(fieldName) = ...
                            planWorkflow.config.RobustStrategySpec.nonnegativeNumericScalar( ...
                            options.(fieldName),valueContext);
                end
            end
        end

        function fields = visibleParameterFields(strategy,options)
            if nargin < 2 || isempty(options)
                options = struct();
            end
            fields = ...
                planWorkflow.config.RobustStrategySpec.variantParameterFields( ...
                strategy);
            optionFields = ...
                planWorkflow.config.RobustStrategySpec.strategyOptionFields( ...
                strategy);
            if isempty(optionFields)
                return;
            end
            fields = [fields,optionFields];
            if isfield(options,'radiusMode') && ...
                    strcmpi(char(options.radiusMode),'extreme')
                fields(strcmp(fields,'KMode')) = [];
                fields(strcmp(fields,'kmax')) = [];
                fields(strcmp(fields,'retentionThreshold')) = [];
                return;
            end
            if isfield(options,'KMode') && strcmpi(char(options.KMode),'static')
                fields(strcmp(fields,'retentionThreshold')) = [];
            end
        end

        function pln = applyVariantToPlan(pln,planConfig,variantIx)
            if ~isfield(pln,'propOpt') || ~isstruct(pln.propOpt)
                pln.propOpt = struct();
            end
            variant = ...
                planWorkflow.config.RobustPlanConfig.variantWithPenalty( ...
                planConfig,variantIx);
            robustnessMode = ...
                planWorkflow.config.RobustStrategySpec.modeFromSource( ...
                planConfig);
            fields = ...
                planWorkflow.config.RobustStrategySpec.variantParameterFields( ...
                robustnessMode);
            for fieldIx = 1:numel(fields)
                pln.propOpt.(fields{fieldIx}) = variant.(fields{fieldIx});
            end
        end

        function options = optionsForPanel(source)
            strategy = planWorkflow.config.RobustStrategySpec.modeFromSource( ...
                source);
            options = ...
                planWorkflow.config.RobustStrategySpec.defaultStrategyOptions( ...
                strategy);
            if isstruct(source) && isfield(source,'robustnessOptions') && ...
                    isstruct(source.robustnessOptions) && ...
                    isscalar(source.robustnessOptions)
                options = ...
                    planWorkflow.config.RobustStrategySpec.mergeDefaults( ...
                    source.robustnessOptions,options);
            end
        end

        function mode = modeFromSource(source)
            mode = 'none';
            if ~isstruct(source)
                return;
            end
            if isfield(source,'robustnessMode') && ...
                    ~isempty(source.robustnessMode)
                mode = char(source.robustnessMode);
            elseif isfield(source,'robustness') && ...
                    ~isempty(source.robustness)
                mode = char(source.robustness);
            elseif isfield(source,'reference_robustness') && ...
                    ~isempty(source.reference_robustness)
                mode = char(source.reference_robustness);
            end
        end
    end

    methods (Static, Access = private)
        function spec = spec(name,label,type,defaultValue,required, ...
                optionValues)
            spec = struct('name',char(name), ...
                'label',char(label), ...
                'type',char(type), ...
                'default',defaultValue, ...
                'required',logical(required), ...
                'optionValues',{optionValues});
        end

        function specs = emptySpec()
            specs = struct('name',{},'label',{},'type',{}, ...
                'default',{},'required',{},'optionValues',{});
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

        function merged = mergeDefaults(value,defaults)
            merged = value;
            fields = fieldnames(defaults);
            for i = 1:numel(fields)
                if ~isfield(merged,fields{i}) || isempty(merged.(fields{i}))
                    merged.(fields{i}) = defaults.(fields{i});
                end
            end
        end

        function value = requiredText(value,context)
            if ~(ischar(value) || (isstring(value) && isscalar(value)))
                error('planWorkflow:config:RobustPlanConfig:InvalidText', ...
                    '%s must be text.',context);
            end
            value = regexprep(strtrim(char(string(value))),'\s+',' ');
            if isempty(value)
                error('planWorkflow:config:RobustPlanConfig:InvalidText', ...
                    '%s must be non-empty text.',context);
            end
        end

        function value = positiveIntegerScalar(value,context)
            if ~(isnumeric(value) && isscalar(value) && isfinite(value) && ...
                    value >= 1 && round(value) == value)
                error('planWorkflow:config:RobustPlanConfig:InvalidPositiveInteger', ...
                    '%s must be a positive integer scalar.',context);
            end
        end

        function value = finiteNumericScalar(value,context)
            if ~(isnumeric(value) && isscalar(value) && isfinite(value))
                error('planWorkflow:config:RobustPlanConfig:InvalidNumericScalar', ...
                    '%s must be a finite numeric scalar.',context);
            end
        end

        function value = nonnegativeNumericScalar(value,context)
            value = ...
                planWorkflow.config.RobustStrategySpec.finiteNumericScalar( ...
                value,context);
            if value < 0
                error('planWorkflow:config:RobustPlanConfig:InvalidNumericScalar', ...
                    '%s must be a non-negative numeric scalar.',context);
            end
        end
    end
end
