classdef RobustPlanCatalog
    % RobustPlanCatalog Build robust-plan presets from plan templates.

    methods (Static)
        function plans = select(description,templateId,planKeys,varargin)
            % select Return robust plans selected from a template catalog.
            %
            % planKeys can be a char/string scalar, a cell array, or "all".
            % Keys are matched against robust objective-set ids first, then
            % labels. Particle workflows must pass a robustScenario
            % explicitly because range uncertainty is modality policy, not a
            % template property.

            options = planWorkflow.config.RobustPlanCatalog.parseOptions( ...
                varargin{:});
            template = planWorkflow.templates.PlanTemplate.loadForDescription( ...
                description,templateId);
            [plans,contracts] = ...
                planWorkflow.config.RobustPlanCatalog.plansFromTemplate( ...
                template,options);
            selectedIx = ...
                planWorkflow.config.RobustPlanCatalog.selectedPlanIndices( ...
                plans,planKeys);
            plans = plans(selectedIx);
            contracts = contracts(selectedIx);
            planWorkflow.config.RobustPlanCatalog.assertScenarioPolicy( ...
                plans,options);
            plans = planWorkflow.config.RobustPlanConfig.normalizePlans( ...
                plans,contracts);
        end

        function plans = all(description,templateId,varargin)
            plans = planWorkflow.config.RobustPlanCatalog.select( ...
                description,templateId,'all',varargin{:});
        end

        function planKeys = normalizePlanKeys(planKeys)
            if nargin < 1 || isempty(planKeys)
                planKeys = {'all'};
                return;
            end
            if ischar(planKeys) || (isstring(planKeys) && isscalar(planKeys))
                planKeys = {char(string(planKeys))};
            elseif isstring(planKeys)
                planKeys = cellstr(planKeys(:)');
            elseif iscell(planKeys)
                planKeys = cellfun(@(v) char(string(v)),planKeys(:)', ...
                    'UniformOutput',false);
            else
                error(['planWorkflow:config:RobustPlanCatalog:' ...
                    'InvalidPlanKeys'], ...
                    'planKeys must be text, a string array, or a cell array.');
            end
            if isempty(planKeys)
                planKeys = {'all'};
            end
        end

        function validateSelectedPlans(runConfig,description,templateId, ...
                expectedPlanKeys,varargin)
            options = planWorkflow.config.RobustPlanCatalog.parseOptions( ...
                varargin{:});
            actualPlans = ...
                planWorkflow.config.RobustPlanConfig.plansFromRunConfig( ...
                runConfig);
            robustScenarioArgs = ...
                planWorkflow.config.RobustPlanCatalog.robustScenarioArgs( ...
                options);
            expectedPlans = planWorkflow.config.RobustPlanCatalog.select( ...
                description,templateId,expectedPlanKeys, ...
                'nominalScenario',options.nominalScenario, ...
                'radiationMode',options.radiationMode,robustScenarioArgs{:});

            if numel(actualPlans) ~= numel(expectedPlans)
                error(['planWorkflow:config:RobustPlanCatalog:' ...
                    'UnexpectedPlanCount'], ...
                    ['Expected %d robust plan(s), but found %d after ' ...
                     'workflow configuration editing.'], ...
                    numel(expectedPlans),numel(actualPlans));
            end

            for planIx = 1:numel(expectedPlans)
                actualPlan = actualPlans(planIx);
                expectedPlan = expectedPlans(planIx);
                if ~strcmp(char(actualPlan.objectiveSetName), ...
                        char(expectedPlan.objectiveSetName))
                    error(['planWorkflow:config:RobustPlanCatalog:' ...
                        'UnexpectedPlan'], ...
                        'Expected robust plan "%s" at position %d, found "%s".', ...
                        char(expectedPlan.objectiveSetName),planIx, ...
                        char(actualPlan.objectiveSetName));
                end
                if ~strcmp(char(actualPlan.robustnessMode), ...
                        char(expectedPlan.robustnessMode))
                    error(['planWorkflow:config:RobustPlanCatalog:' ...
                        'UnexpectedRobustnessMode'], ...
                        ['Robust plan "%s" changed robustness mode from ' ...
                         '"%s" to "%s".'], ...
                        char(expectedPlan.objectiveSetName), ...
                        char(expectedPlan.robustnessMode), ...
                        char(actualPlan.robustnessMode));
                end
                if logical(options.strict)
                    planWorkflow.config.RobustPlanCatalog.assertStrictPlan( ...
                        actualPlan,expectedPlan);
                end
            end
        end
    end

    methods (Static, Access = private)
        function options = parseOptions(varargin)
            options = struct();
            options.nominalScenario = ...
                planWorkflow.config.RobustPlanCatalog.nominalScenario();
            options.robustScenario = ...
                planWorkflow.config.RobustPlanCatalog.robustScenario();
            options.robustScenarioExplicit = false;
            options.radiationMode = 'photons';
            options.strict = false;

            if mod(numel(varargin),2) ~= 0
                error(['planWorkflow:config:RobustPlanCatalog:' ...
                    'InvalidOptions'], ...
                    'Options must be name-value pairs.');
            end
            allowedOptions = {'nominalScenario','robustScenario', ...
                'radiationMode','strict'};
            for i = 1:2:numel(varargin)
                name = char(string(varargin{i}));
                if ~any(strcmp(name,allowedOptions))
                    error(['planWorkflow:config:RobustPlanCatalog:' ...
                        'InvalidOptions'], ...
                        'Unknown option "%s".',name);
                end
                if strcmp(name,'robustScenario')
                    options.robustScenarioExplicit = ~isempty(varargin{i + 1});
                end
                options.(name) = varargin{i + 1};
            end
            options.nominalScenario = ...
                planWorkflow.config.ScenarioSpec.normalize( ...
                options.nominalScenario, ...
                planWorkflow.config.RobustPlanCatalog.nominalScenario(), ...
                'nominalScenario');
            options.robustScenario = ...
                planWorkflow.config.ScenarioSpec.normalize( ...
                options.robustScenario, ...
                planWorkflow.config.RobustPlanCatalog.robustScenario(), ...
                'robustScenario');
            options.strict = ...
                planWorkflow.config.ConfigValue.logicalScalar( ...
                options.strict,'RobustPlanCatalog.strict', ...
                'planWorkflow:config:RobustPlanCatalog:InvalidOptions');
            options.radiationMode = ...
                planWorkflow.config.RobustPlanCatalog.normalizeRadiationMode( ...
                options.radiationMode);
        end

        function args = robustScenarioArgs(options)
            if isfield(options,'robustScenarioExplicit') && ...
                    logical(options.robustScenarioExplicit)
                args = {'robustScenario',options.robustScenario};
            else
                args = {};
            end
        end

        function assertScenarioPolicy(plans,options)
            if isempty(plans) || ...
                    ~planWorkflow.config.RobustPlanCatalog.isParticleMode( ...
                    options.radiationMode)
                return;
            end
            hasRobustPlan = false;
            for planIx = 1:numel(plans)
                hasRobustPlan = hasRobustPlan || ...
                    ~strcmp(char(plans(planIx).robustnessMode),'none');
            end
            if hasRobustPlan && ...
                    ~logical(options.robustScenarioExplicit)
                error(['planWorkflow:config:RobustPlanCatalog:' ...
                    'MissingParticleRobustScenario'], ...
                    ['Particle robust-plan catalog selection for "%s" ' ...
                     'requires an explicit robustScenario, including the ' ...
                     'range-uncertainty policy.'], ...
                    char(options.radiationMode));
            end
        end

        function radiationMode = normalizeRadiationMode(radiationMode)
            if isempty(radiationMode)
                radiationMode = 'photons';
                return;
            end
            if ~(ischar(radiationMode) || ...
                    (isstring(radiationMode) && isscalar(radiationMode)))
                error(['planWorkflow:config:RobustPlanCatalog:' ...
                    'InvalidOptions'], ...
                    'RobustPlanCatalog.radiationMode must be text.');
            end
            radiationMode = lower(strtrim(char(string(radiationMode))));
            supported = ...
                planWorkflow.config.RobustPlanCatalog.supportedRadiationModes();
            if ~any(strcmp(radiationMode,supported))
                error(['planWorkflow:config:RobustPlanCatalog:' ...
                    'InvalidRadiationMode'], ...
                    ['RobustPlanCatalog.radiationMode "%s" is invalid. ' ...
                     'Supported values are: %s.'], ...
                    radiationMode,strjoin(supported,', '));
            end
        end

        function tf = isParticleMode(radiationMode)
            particleModes = ...
                planWorkflow.config.RobustPlanCatalog.supportedRadiationModes();
            particleModes = setdiff(particleModes,{'photons'},'stable');
            tf = any(strcmp(char(radiationMode),particleModes));
        end

        function modes = supportedRadiationModes()
            modes = {'photons','protons','carbon','helium'};
        end

        function [plans,contracts] = plansFromTemplate(template,options)
            objectiveSets = template.objectiveSets.robustPlans;
            if isempty(objectiveSets)
                plans = repmat( ...
                    planWorkflow.config.RobustPlanConfig.defaultPlan(),1,0);
                contracts = repmat( ...
                    planWorkflow.config.RobustPlanConfig.defaultRobustnessContract(), ...
                    1,0);
                return;
            end
            if iscell(objectiveSets)
                objectiveSets = [objectiveSets{:}];
            end

            plans = repmat( ...
                planWorkflow.config.RobustPlanConfig.defaultPlan(), ...
                1,numel(objectiveSets));
            contracts = repmat( ...
                planWorkflow.config.RobustPlanConfig.defaultRobustnessContract(), ...
                1,numel(objectiveSets));
            for planIx = 1:numel(objectiveSets)
                objectiveSet = objectiveSets(planIx);
                contracts(planIx) = ...
                    planWorkflow.templates.ObjectiveRobustnessContract.forObjectiveSet( ...
                    objectiveSet);
                plans(planIx) = ...
                    planWorkflow.config.RobustPlanCatalog.planFromObjectiveSet( ...
                    objectiveSet,contracts(planIx),options,planIx);
            end
            plans = planWorkflow.config.RobustPlanCatalog.uniquifyPlanIds( ...
                plans);
        end

        function plan = planFromObjectiveSet(objectiveSet,contract, ...
                options,planIx)
            plan = planWorkflow.config.RobustPlanConfig.defaultPlan();
            objectiveSetId = planWorkflow.config.RobustPlanCatalog.objectiveSetId( ...
                objectiveSet,planIx);
            plan.label = ...
                planWorkflow.config.RobustPlanCatalog.objectiveSetLabel( ...
                objectiveSet,plan.label);
            plan.objectiveSetName = objectiveSetId;
            plan = planWorkflow.config.RobustPlanConfig.applyRobustnessContract( ...
                plan,contract);
            plan.id = planWorkflow.config.RobustPlanCatalog.canonicalPlanId( ...
                objectiveSet,plan);
            if strcmp(char(plan.robustnessMode),'none')
                plan.scenario = options.nominalScenario;
            else
                plan.scenario = options.robustScenario;
            end
            plan.dosePrecompute = ...
                planWorkflow.config.RobustPlanCatalog.dosePrecompute( ...
                plan.robustnessMode);
            plan.robustnessOptions = ...
                planWorkflow.config.RobustPlanConfig.defaultRobustnessOptions( ...
                plan.robustnessMode);
            plan.variants = ...
                planWorkflow.config.RobustPlanCatalog.variants( ...
                plan.robustnessMode);
        end

        function scenario = nominalScenario()
            scenario = planWorkflow.config.ScenarioSpec.defaults('nomScen');
            scenario.ctActive = false;
            scenario.setupActive = false;
            scenario.rangeActive = false;
            scenario.gantryActive = false;
            scenario.couchActive = false;
        end

        function scenario = robustScenario()
            scenario = planWorkflow.config.ScenarioSpec.defaults('impScen5');
            scenario.ctActive = true;
            scenario.setupActive = true;
            scenario.rangeActive = false;
            scenario.gantryActive = false;
            scenario.couchActive = false;
        end

        function dosePrecompute = dosePrecompute(robustnessMode)
            dosePrecompute = ...
                planWorkflow.config.RobustPlanConfig.defaultDosePrecompute();
            if any(strcmp(char(robustnessMode), ...
                    {'PROB2','INTERVAL2','INTERVAL3'}))
                dosePrecompute.useScenarioBatch = true;
            end
        end

        function variants = variants(robustnessMode)
            switch char(robustnessMode)
                case 'c-COWC'
                    variants = ...
                        planWorkflow.config.RobustPlanCatalog.cCowcVariants();
                case 'INTERVAL2'
                    variants = ...
                        planWorkflow.config.RobustPlanCatalog.interval2Variants();
                case 'INTERVAL3'
                    variants = ...
                        planWorkflow.config.RobustPlanCatalog.interval3Variants();
                otherwise
                    variants = ...
                        planWorkflow.config.RobustPlanConfig.defaultVariants( ...
                        robustnessMode);
            end
        end

        function variants = cCowcVariants()
            values = 1:13;
            variants = repmat(struct('id','','label','','p1',1,'p2',1), ...
                1,numel(values));
            for i = 1:numel(values)
                p2 = values(i);
                variants(i).id = sprintf('p1_1_p2_%d',p2);
                variants(i).label = sprintf('p1=1 - p2=%d',p2);
                variants(i).p1 = 1;
                variants(i).p2 = p2;
            end
        end

        function variants = interval2Variants()
            values = planWorkflow.config.RobustPlanCatalog.intervalThetaValues();
            variants = repmat(struct('id','','label','','theta1',1), ...
                1,numel(values));
            for i = 1:numel(values)
                theta1 = values(i);
                variants(i).id = ['theta1_' ...
                    planWorkflow.config.RobustPlanCatalog.numericToken(theta1)];
                variants(i).label = ['theta1=' ...
                    planWorkflow.config.RobustPlanCatalog.numericLabel(theta1)];
                variants(i).theta1 = theta1;
            end
        end

        function variants = interval3Variants()
            values = planWorkflow.config.RobustPlanCatalog.intervalThetaValues();
            variants = repmat( ...
                struct('id','','label','','theta1',1,'theta2',1), ...
                1,numel(values));
            for i = 1:numel(values)
                theta1 = values(i);
                token = ...
                    planWorkflow.config.RobustPlanCatalog.numericToken(theta1);
                variants(i).id = ['theta1_' token '_theta2_1'];
                variants(i).label = ['theta1=' ...
                    planWorkflow.config.RobustPlanCatalog.numericLabel(theta1) ...
                    ' - theta2=1'];
                variants(i).theta1 = theta1;
                variants(i).theta2 = 1;
            end
        end

        function values = intervalThetaValues()
            values = [1 2 5 10 20 0.01 0.02 0.05 0.1 0.2 0.5 50];
        end

        function indices = selectedPlanIndices(plans,planKeys)
            planKeys = planWorkflow.config.RobustPlanCatalog.normalizePlanKeys( ...
                planKeys);
            if numel(planKeys) == 1 && ...
                    any(strcmpi(planKeys{1},{'all','*'}))
                indices = 1:numel(plans);
                return;
            end
            indices = zeros(1,numel(planKeys));
            for keyIx = 1:numel(planKeys)
                indices(keyIx) = ...
                    planWorkflow.config.RobustPlanCatalog.planIndex( ...
                    plans,planKeys{keyIx});
            end
        end

        function ix = planIndex(plans,planKey)
            ids = {plans.id};
            names = {plans.objectiveSetName};
            labels = {plans.label};
            ix = find(strcmp(ids,planKey),1);
            if isempty(ix)
                ix = find(strcmp(names,planKey),1);
            end
            if isempty(ix)
                ix = find(strcmp(labels,planKey),1);
            end
            if isempty(ix)
                ix = find(strcmpi(ids,planKey),1);
            end
            if isempty(ix)
                ix = find(strcmpi(names,planKey),1);
            end
            if isempty(ix)
                ix = find(strcmpi(labels,planKey),1);
            end
            if isempty(ix)
                error(['planWorkflow:config:RobustPlanCatalog:' ...
                    'UnknownPlan'], ...
                    'Unknown robust plan "%s". Available plans are: %s.', ...
                    char(planKey), ...
                    planWorkflow.config.RobustPlanCatalog.availablePlanText( ...
                    plans));
            end
        end

        function id = canonicalPlanId(objectiveSet,plan)
            switch char(plan.robustnessMode)
                case 'none'
                    id = planWorkflow.config.RobustPlanCatalog.nonePlanId( ...
                        objectiveSet,plan);
                case 'COWC'
                    id = 'COWC';
                case 'STOCH'
                    id = 'STOCH';
                case 'c-COWC'
                    id = 'cCOWC';
                case 'PROB2'
                    id = 'PROB2';
                case 'INTERVAL2'
                    id = 'INTERVAL2';
                case 'INTERVAL3'
                    id = 'INTERVAL3';
                otherwise
                    id = ...
                        planWorkflow.config.RobustPlanCatalog.sanitizePlanId( ...
                        plan.robustnessMode);
            end
        end

        function id = nonePlanId(objectiveSet,plan)
            candidates = {plan.objectiveSetName,plan.label};
            if isstruct(objectiveSet) && isfield(objectiveSet,'id') && ...
                    ~isempty(objectiveSet.id)
                candidates{end + 1} = objectiveSet.id;
            end
            if isstruct(objectiveSet) && isfield(objectiveSet,'label') && ...
                    ~isempty(objectiveSet.label)
                candidates{end + 1} = objectiveSet.label;
            end
            for candidateIx = 1:numel(candidates)
                candidate = char(string(candidates{candidateIx}));
                if strcmpi(candidate,'PTV')
                    id = 'PTV';
                    return;
                end
            end
            id = planWorkflow.config.RobustPlanCatalog.sanitizePlanId( ...
                plan.objectiveSetName);
        end

        function plans = uniquifyPlanIds(plans)
            ids = cell(1,numel(plans));
            for planIx = 1:numel(plans)
                baseId = char(plans(planIx).id);
                id = baseId;
                duplicateIx = 1;
                while any(strcmp(ids(1:planIx - 1),id))
                    duplicateIx = duplicateIx + 1;
                    id = sprintf('%s_%d',baseId,duplicateIx);
                end
                plans(planIx).id = id;
                ids{planIx} = id;
            end
        end

        function id = sanitizePlanId(value)
            id = regexprep(char(string(value)),'[^A-Za-z0-9_]+','');
            if isempty(id)
                id = 'robustPlan';
            end
        end

        function text = availablePlanText(plans)
            labels = cell(1,numel(plans));
            for planIx = 1:numel(plans)
                labels{planIx} = sprintf('%s (%s, %s)', ...
                    char(plans(planIx).id), ...
                    char(plans(planIx).objectiveSetName), ...
                    char(plans(planIx).label));
            end
            text = strjoin(labels,', ');
        end

        function id = objectiveSetId(objectiveSet,planIx)
            id = '';
            if isfield(objectiveSet,'id') && ~isempty(objectiveSet.id)
                id = char(objectiveSet.id);
            end
            if isempty(id)
                id = sprintf('robust_%d',planIx);
            end
        end

        function label = objectiveSetLabel(objectiveSet,defaultLabel)
            label = defaultLabel;
            if isfield(objectiveSet,'label') && ~isempty(objectiveSet.label)
                label = char(objectiveSet.label);
            end
        end

        function assertStrictPlan(actualPlan,expectedPlan)
            if ~isequaln(actualPlan.variants,expectedPlan.variants)
                error(['planWorkflow:config:RobustPlanCatalog:' ...
                    'UnexpectedPlanConfig'], ...
                    'Robust plan "%s" has unexpected variants.', ...
                    char(expectedPlan.objectiveSetName));
            end
            if logical(actualPlan.dosePrecompute.useScenarioBatch) ~= ...
                    logical(expectedPlan.dosePrecompute.useScenarioBatch)
                error(['planWorkflow:config:RobustPlanCatalog:' ...
                    'UnexpectedPlanConfig'], ...
                    ['Robust plan "%s" has unexpected scenario-batch ' ...
                     'configuration.'], ...
                    char(expectedPlan.objectiveSetName));
            end
        end

        function token = numericToken(value)
            token = strrep( ...
                planWorkflow.config.RobustPlanCatalog.numericLabel(value), ...
                '.','p');
        end

        function label = numericLabel(value)
            label = sprintf('%g',value);
        end
    end
end
