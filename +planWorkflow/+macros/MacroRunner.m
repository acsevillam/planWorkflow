classdef MacroRunner
    % MacroRunner Build and execute workflow macro specifications.

    methods (Static)
        function [workflowConfig,macroOptions] = build(spec,varargin)
            spec = planWorkflow.macros.MacroSpec.normalize(spec);
            macroOptions = ...
                planWorkflow.macros.MacroRunner.parseOptions( ...
                spec,varargin{:});

            workflowConfig = struct();
            workflowConfig.rootPath = macroOptions.rootPath;
            workflowConfig.outputRootPath = ...
                fullfile(macroOptions.rootPath,'output');
            workflowConfig.patientDataPath = ...
                fullfile(macroOptions.rootPath,'patients');
            workflowConfig.cacheRootPath = macroOptions.cacheRootPath;

            workflowConfig.prepare = spec.prepare;
            workflowConfig.prepare.caseID = macroOptions.caseID;
            workflowConfig.prepare.plan_template = macroOptions.planTemplate;
            if isfield(macroOptions.overrides,'prepare')
                workflowConfig.prepare = ...
                    planWorkflow.macros.MacroRunner.mergeStructs( ...
                    workflowConfig.prepare,macroOptions.overrides.prepare);
                macroOptions.planTemplate = ...
                    workflowConfig.prepare.plan_template;
                macroOptions.overrides = ...
                    rmfield(macroOptions.overrides,'prepare');
            end

            optimizationScenario = ...
                planWorkflow.macros.MacroRunner.applyScenarioPatch( ...
                spec.robustScenario,macroOptions.optimizationScenario, ...
                'optimizationScenario');
            macroOptions.optimizationScenario = optimizationScenario;

            workflowConfig.precompute = spec.precompute;
            workflowConfig.precompute.reference = spec.reference;
            workflowConfig.precompute.robustPlans = ...
                planWorkflow.config.RobustPlanCatalog.select( ...
                workflowConfig.prepare.description, ...
                workflowConfig.prepare.plan_template, ...
                macroOptions.planKeys, ...
                'nominalScenario',spec.nominalScenario, ...
                'robustScenario',optimizationScenario, ...
                'radiationMode',workflowConfig.prepare.radiationMode);
            workflowConfig.precompute = ...
                planWorkflow.macros.MacroRunner.defaultCacheFlags( ...
                workflowConfig.precompute);

            workflowConfig.pullDose = spec.pullDose;
            workflowConfig.optimize = spec.optimize;
            workflowConfig.sampling = ...
                planWorkflow.macros.MacroRunner.applySamplingScenarioPatch( ...
                spec.sampling,macroOptions.samplingScenario);
            macroOptions.samplingScenario = ...
                planWorkflow.config.ScenarioSpec.fromRunConfig( ...
                workflowConfig.sampling,'sampling');
            if ~isempty(macroOptions.randomSeed)
                workflowConfig.sampling.sampling_randomSeed = ...
                    macroOptions.randomSeed;
            end
            workflowConfig.analysis = spec.analysis;

            workflowConfig = ...
                planWorkflow.macros.MacroRunner.applyOverrides( ...
                workflowConfig,macroOptions);
        end

        function result = run(spec,varargin)
            spec = planWorkflow.macros.MacroSpec.normalize(spec);
            [workflowConfig,macroOptions] = ...
                planWorkflow.macros.MacroRunner.build( ...
                spec,varargin{:});

            result = struct();
            result.workflow = [];
            result.workflowConfig = workflowConfig;
            result.macroOptions = macroOptions;
            result.executionMode = spec.executionMode;
            result.profile = spec.profile;

            workflow = planWorkflow.Workflow(workflowConfig);
            cleanupObj = onCleanup(@() workflow.releaseMemory()); %#ok<NASGU>
            if logical(macroOptions.openGui)
                workflow.gui();
            end

            planWorkflow.macros.MacroRunner.validatePlanSet( ...
                workflow.runConfig,spec,macroOptions);

            workflow.prepare();
            workflow.precompute();
            workflow.pullDose();
            workflow.optimize();
            workflow.sample();
            workflow.analyze();
            workflow.save();
            workflow.releaseMemory();

            result.workflow = workflow;
            result.workflowConfig = workflow.runConfig;
        end
    end

    methods (Static, Access = private)
        function options = parseOptions(spec,varargin)
            defaults = planWorkflow.macros.MacroRunner.defaultOptions(spec);
            options = defaults;
            provided = struct();
            fields = fieldnames(defaults);
            for i = 1:numel(fields)
                provided.(fields{i}) = false;
            end

            if isempty(varargin)
                options = planWorkflow.macros.MacroRunner.normalizeOptions( ...
                    options);
                return;
            end

            if numel(varargin) == 1 && isstruct(varargin{1})
                [options,provided] = ...
                    planWorkflow.macros.MacroRunner.applyPatch( ...
                    options,provided,varargin{1});
            else
                [options,provided] = ...
                    planWorkflow.macros.MacroRunner.applyNameValue( ...
                    options,provided,varargin{:});
            end

            if provided.rootPath && ~provided.cacheRootPath && ...
                    strcmp(char(defaults.cacheRootPath), ...
                    fullfile(char(defaults.rootPath),'output','cache'))
                options.cacheRootPath = ...
                    fullfile(options.rootPath,'output','cache');
            end
            options = planWorkflow.macros.MacroRunner.normalizeOptions( ...
                options);
        end

        function defaults = defaultOptions(spec)
            rootPath = spec.rootPath;
            if isempty(rootPath)
                rootPath = planWorkflow.macros.MacroRunner.defaultRootPath();
            end
            defaults = struct();
            defaults.caseID = spec.caseID;
            defaults.rootPath = rootPath;
            defaults.cacheRootPath = fullfile(rootPath,'output','cache');
            defaults.randomSeed = spec.randomSeed;
            defaults.planKeys = spec.planKeys;
            defaults.planTemplate = spec.planTemplate;
            defaults.openGui = spec.openGui;
            defaults.optimizationScenario = struct();
            defaults.samplingScenario = struct();
            defaults.lockPlanSet = spec.lockPlanSet;
            defaults.overrides = struct();
            defaults.allowCustomRobustPlans = spec.allowCustomRobustPlans;
        end

        function rootPath = defaultRootPath()
            rootPath = '';
            if exist('MatRad_Config','class') == 8
                matRadCfg = MatRad_Config.instance();
                rootPath = matRadCfg.primaryUserFolder;
            end
            if isempty(rootPath)
                rootPath = pwd();
            end
        end

        function [options,provided] = applyNameValue( ...
                options,provided,varargin)
            if mod(numel(varargin),2) ~= 0
                error('planWorkflow:macros:MacroRunner:InvalidOptions', ...
                    'Macro options must be name-value pairs.');
            end
            patch = struct();
            for i = 1:2:numel(varargin)
                if ~(ischar(varargin{i}) || ...
                        (isstring(varargin{i}) && isscalar(varargin{i})))
                    error(['planWorkflow:macros:MacroRunner:' ...
                        'InvalidOptions'], ...
                        'Macro option names must be text scalars.');
                end
                name = char(string(varargin{i}));
                if ~isvarname(name)
                    error(['planWorkflow:macros:MacroRunner:' ...
                        'InvalidOptions'], ...
                        'Invalid macro option name "%s".',name);
                end
                patch.(name) = varargin{i + 1};
            end
            [options,provided] = ...
                planWorkflow.macros.MacroRunner.applyPatch( ...
                options,provided,patch);
        end

        function [options,provided] = applyPatch(options,provided,patch)
            if ~isstruct(patch) || ~isscalar(patch)
                error('planWorkflow:macros:MacroRunner:InvalidOptions', ...
                    'Macro option patch must be a scalar struct.');
            end
            patchFields = fieldnames(patch);
            for i = 1:numel(patchFields)
                fieldName = patchFields{i};
                if any(strcmp(fieldName, ...
                        planWorkflow.macros.MacroRunner.stageNames()))
                    if ~isstruct(patch.(fieldName)) || ...
                            ~isscalar(patch.(fieldName))
                        error(['planWorkflow:macros:MacroRunner:' ...
                            'InvalidOptions'], ...
                            'Stage override "%s" must be a scalar struct.', ...
                            fieldName);
                    end
                    if ~isfield(options.overrides,fieldName) || ...
                            isempty(options.overrides.(fieldName))
                        options.overrides.(fieldName) = struct();
                    end
                    options.overrides.(fieldName) = ...
                        planWorkflow.macros.MacroRunner.mergeStructs( ...
                        options.overrides.(fieldName),patch.(fieldName));
                    provided.overrides = true;
                elseif any(strcmp(fieldName, ...
                        planWorkflow.macros.MacroRunner.allowedFields()))
                    if strcmp(fieldName,'overrides')
                        if ~isstruct(patch.overrides) || ...
                                ~isscalar(patch.overrides)
                            error(['planWorkflow:macros:MacroRunner:' ...
                                'InvalidOptions'], ...
                                'overrides must be a scalar struct.');
                        end
                        options.overrides = ...
                            planWorkflow.macros.MacroRunner.mergeStructs( ...
                            options.overrides,patch.overrides);
                    else
                        options.(fieldName) = patch.(fieldName);
                    end
                    if isfield(provided,fieldName)
                        provided.(fieldName) = true;
                    end
                else
                    error('planWorkflow:macros:MacroRunner:InvalidOptions', ...
                        'Unknown macro option "%s".',fieldName);
                end
            end
        end

        function options = normalizeOptions(options)
            textFields = {'caseID','rootPath','cacheRootPath', ...
                'planTemplate'};
            for i = 1:numel(textFields)
                fieldName = textFields{i};
                if ~(ischar(options.(fieldName)) || ...
                        (isstring(options.(fieldName)) && ...
                        isscalar(options.(fieldName))))
                    error(['planWorkflow:macros:MacroRunner:' ...
                        'InvalidOptions'], ...
                        '%s must be a text scalar.',fieldName);
                end
                options.(fieldName) = char(string(options.(fieldName)));
            end
            options.planKeys = ...
                planWorkflow.config.RobustPlanCatalog.normalizePlanKeys( ...
                options.planKeys);
            options.openGui = ...
                planWorkflow.config.ConfigValue.logicalScalar( ...
                options.openGui,'openGui', ...
                'planWorkflow:macros:MacroRunner:InvalidOptions');
            options.lockPlanSet = ...
                planWorkflow.config.ConfigValue.logicalScalar( ...
                options.lockPlanSet,'lockPlanSet', ...
                'planWorkflow:macros:MacroRunner:InvalidOptions');
            options.allowCustomRobustPlans = ...
                planWorkflow.config.ConfigValue.logicalScalar( ...
                options.allowCustomRobustPlans, ...
                'allowCustomRobustPlans', ...
                'planWorkflow:macros:MacroRunner:InvalidOptions');
            if ~isempty(options.randomSeed)
                if ~(isnumeric(options.randomSeed) && ...
                        isscalar(options.randomSeed) && ...
                        isfinite(options.randomSeed) && ...
                        options.randomSeed >= 0 && ...
                        floor(options.randomSeed) == options.randomSeed)
                    error(['planWorkflow:macros:MacroRunner:' ...
                        'InvalidOptions'], ...
                        ['randomSeed must be empty or a non-negative ' ...
                         'integer scalar.']);
                end
            end
            if ~isstruct(options.overrides) || ~isscalar(options.overrides)
                error('planWorkflow:macros:MacroRunner:InvalidOptions', ...
                    'overrides must be a scalar struct.');
            end
            options.optimizationScenario = ...
                planWorkflow.macros.MacroRunner.normalizeScenarioPatch( ...
                options.optimizationScenario,'optimizationScenario');
            options.samplingScenario = ...
                planWorkflow.macros.MacroRunner.normalizeScenarioPatch( ...
                options.samplingScenario,'samplingScenario');
        end

        function precompute = defaultCacheFlags(precompute)
            if ~isfield(precompute,'useCache')
                precompute.useCache = true;
            end
            if ~isfield(precompute,'writeCache')
                precompute.writeCache = true;
            end
        end

        function workflowConfig = applyOverrides(workflowConfig,macroOptions)
            if isempty(fieldnames(macroOptions.overrides))
                return;
            end
            if isfield(macroOptions.overrides,'precompute') && ...
                    isfield(macroOptions.overrides.precompute, ...
                    'robustPlans') && ...
                    ~logical(macroOptions.allowCustomRobustPlans)
                error(['planWorkflow:macros:MacroRunner:' ...
                    'CustomRobustPlansDisabled'], ...
                    ['precompute.robustPlans overrides require ' ...
                     'allowCustomRobustPlans=true.']);
            end
            workflowConfig = planWorkflow.macros.MacroRunner.mergeStructs( ...
                workflowConfig,macroOptions.overrides);
        end

        function validatePlanSet(runConfig,spec,macroOptions)
            if ~logical(macroOptions.lockPlanSet) || ...
                    logical(macroOptions.allowCustomRobustPlans)
                return;
            end

            description = spec.description;
            if isstruct(runConfig) && isfield(runConfig,'description') && ...
                    ~isempty(runConfig.description)
                description = runConfig.description;
            end
            templateId = macroOptions.planTemplate;
            if isstruct(runConfig) && isfield(runConfig,'plan_template') && ...
                    ~isempty(runConfig.plan_template)
                templateId = runConfig.plan_template;
            end
            radiationMode = spec.modality;
            if isstruct(runConfig) && isfield(runConfig,'radiationMode') && ...
                    ~isempty(runConfig.radiationMode)
                radiationMode = runConfig.radiationMode;
            end

            planWorkflow.config.RobustPlanCatalog.validateSelectedPlans( ...
                runConfig,description,templateId, ...
                macroOptions.planKeys, ...
                'nominalScenario',spec.nominalScenario, ...
                'robustScenario',macroOptions.optimizationScenario, ...
                'radiationMode',radiationMode);
        end

        function scenario = applyScenarioPatch(baseScenario,patch,context)
            scenario = planWorkflow.macros.MacroRunner.mergeStructs( ...
                baseScenario,patch);
            scenario = planWorkflow.config.ScenarioSpec.normalize( ...
                scenario,baseScenario,context);
        end

        function sampling = applySamplingScenarioPatch(sampling,patch)
            if isempty(fieldnames(patch))
                return;
            end
            baseScenario = planWorkflow.config.ScenarioSpec.fromRunConfig( ...
                sampling,'sampling');
            scenario = planWorkflow.macros.MacroRunner.applyScenarioPatch( ...
                baseScenario,patch,'samplingScenario');
            sampling = planWorkflow.config.ScenarioSpec.applyToRunConfig( ...
                sampling,'sampling',scenario);
        end

        function patch = normalizeScenarioPatch(patch,context)
            if isempty(patch)
                patch = struct();
            end
            if ~isstruct(patch) || ~isscalar(patch)
                error('planWorkflow:macros:MacroRunner:InvalidOptions', ...
                    '%s must be a scalar struct.',context);
            end
        end

        function merged = mergeStructs(base,patch)
            if nargin < 1 || isempty(base)
                base = struct();
            end
            if nargin < 2 || isempty(patch)
                merged = base;
                return;
            end
            if ~isstruct(base) || ~isstruct(patch)
                merged = patch;
                return;
            end
            if ~(isscalar(base) && isscalar(patch))
                merged = patch;
                return;
            end

            merged = base;
            fields = fieldnames(patch);
            for i = 1:numel(fields)
                fieldName = fields{i};
                if isfield(merged,fieldName)
                    merged.(fieldName) = ...
                        planWorkflow.macros.MacroRunner.mergeStructs( ...
                        merged.(fieldName),patch.(fieldName));
                else
                    merged.(fieldName) = patch.(fieldName);
                end
            end
        end

        function fields = allowedFields()
            fields = {'caseID','rootPath','cacheRootPath','randomSeed', ...
                'planKeys','planTemplate','openGui','lockPlanSet', ...
                'optimizationScenario','samplingScenario','overrides', ...
                'allowCustomRobustPlans'};
        end

        function fields = stageNames()
            fields = {'prepare','precompute','pullDose','optimize', ...
                'sampling','analysis'};
        end
    end
end
