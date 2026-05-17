classdef MacroSpec
    % MacroSpec Public macro specification contract.

    methods (Static)
        function spec = normalize(spec)
            if nargin < 1 || ~isstruct(spec) || ~isscalar(spec)
                error('planWorkflow:macros:MacroSpec:InvalidSpec', ...
                    'MacroSpec must be a scalar struct.');
            end

            required = planWorkflow.macros.MacroSpec.requiredFields();
            for i = 1:numel(required)
                if ~isfield(spec,required{i})
                    error('planWorkflow:macros:MacroSpec:MissingField', ...
                        'MacroSpec is missing "%s".',required{i});
                end
            end

            textFields = {'id','profile','site','description', ...
                'modality','caseID','planTemplate'};
            for i = 1:numel(textFields)
                fieldName = textFields{i};
                spec.(fieldName) = ...
                    planWorkflow.macros.MacroSpec.textScalar( ...
                    spec.(fieldName),['MacroSpec.' fieldName]);
            end

            spec.profile = lower(spec.profile);
            if ~any(strcmp(spec.profile,{'prod','testing'}))
                error('planWorkflow:macros:MacroSpec:InvalidProfile', ...
                    'MacroSpec.profile must be "prod" or "testing".');
            end

            if isfield(spec,'executionMode')
                spec.executionMode = ...
                    planWorkflow.macros.MacroSpec.textScalar( ...
                    spec.executionMode,'MacroSpec.executionMode');
                if ~strcmp(spec.executionMode,'run')
                    error(['planWorkflow:macros:MacroSpec:' ...
                        'InvalidExecutionMode'], ...
                        'MacroSpec.executionMode must be "run".');
                end
            else
                spec.executionMode = 'run';
            end

            planWorkflow.macros.MacroSpec.validateSiteDescription( ...
                spec.site,spec.description);
            spec.planKeys = ...
                planWorkflow.config.RobustPlanCatalog.normalizePlanKeys( ...
                spec.planKeys);

            spec.prepare = planWorkflow.macros.MacroSpec.scalarStruct( ...
                spec.prepare,'MacroSpec.prepare');
            spec.prepare = planWorkflow.macros.MacroSpec.normalizePrepare( ...
                spec.prepare,spec);
            spec.modality = spec.prepare.radiationMode;

            spec.nominalScenario = ...
                planWorkflow.macros.MacroSpec.normalizeScenario( ...
                spec.nominalScenario,'MacroSpec.nominalScenario','nomScen');
            spec.robustScenario = ...
                planWorkflow.macros.MacroSpec.normalizeScenario( ...
                spec.robustScenario,'MacroSpec.robustScenario','impScen5');

            stageFields = {'precompute','reference','pullDose','optimize', ...
                'sampling','analysis'};
            for i = 1:numel(stageFields)
                fieldName = stageFields{i};
                spec.(fieldName) = ...
                    planWorkflow.macros.MacroSpec.scalarStruct( ...
                    spec.(fieldName),['MacroSpec.' fieldName]);
            end

            spec.openGui = planWorkflow.macros.MacroSpec.optionalLogical( ...
                spec,'openGui',false);
            spec.lockPlanSet = planWorkflow.macros.MacroSpec.optionalLogical( ...
                spec,'lockPlanSet',true);
            spec.allowCustomRobustPlans = ...
                planWorkflow.macros.MacroSpec.optionalLogical( ...
                spec,'allowCustomRobustPlans',false);
            if ~isfield(spec,'randomSeed')
                spec.randomSeed = [];
            end
            planWorkflow.macros.MacroSpec.validateRandomSeed( ...
                spec.randomSeed,'MacroSpec.randomSeed');
            if ~isfield(spec,'rootPath')
                spec.rootPath = '';
            end
            if ~isempty(spec.rootPath)
                spec.rootPath = planWorkflow.macros.MacroSpec.textScalar( ...
                    spec.rootPath,'MacroSpec.rootPath');
            end
        end

        function fields = requiredFields()
            fields = {'id','profile','site','description','modality', ...
                'caseID','planTemplate','planKeys','prepare', ...
                'nominalScenario','robustScenario','precompute', ...
                'reference','pullDose','optimize','sampling','analysis'};
        end
    end

    methods (Static, Access = private)
        function value = textScalar(value,context)
            if ~(ischar(value) || (isstring(value) && isscalar(value)))
                error('planWorkflow:macros:MacroSpec:InvalidText', ...
                    '%s must be a text scalar.',context);
            end
            value = char(string(value));
            if isempty(value)
                error('planWorkflow:macros:MacroSpec:InvalidText', ...
                    '%s must not be empty.',context);
            end
        end

        function value = scalarStruct(value,context)
            if ~isstruct(value) || ~isscalar(value)
                error('planWorkflow:macros:MacroSpec:InvalidStruct', ...
                    '%s must be a scalar struct.',context);
            end
        end

        function validateSiteDescription(site,description)
            switch char(site)
                case 'breast'
                    expected = 'breast';
                case 'prostate'
                    expected = 'prostate';
                case 'head_and_neck'
                    expected = 'h&n';
                otherwise
                    error('planWorkflow:macros:MacroSpec:InvalidSite', ...
                        ['MacroSpec.site must be "breast", "prostate", ' ...
                         'or "head_and_neck".']);
            end
            if ~strcmp(char(description),expected)
                error(['planWorkflow:macros:MacroSpec:' ...
                    'InconsistentSiteDescription'], ...
                    'MacroSpec.site "%s" requires description "%s".', ...
                    char(site),expected);
            end
        end

        function prepare = normalizePrepare(prepare,spec)
            if isfield(prepare,'caseID') && ...
                    ~strcmp(char(string(prepare.caseID)),spec.caseID)
                error(['planWorkflow:macros:MacroSpec:' ...
                    'InconsistentPrepare'], ...
                    'MacroSpec.prepare.caseID must match MacroSpec.caseID.');
            end
            if isfield(prepare,'description') && ...
                    ~strcmp(char(string(prepare.description)), ...
                    spec.description)
                error(['planWorkflow:macros:MacroSpec:' ...
                    'InconsistentPrepare'], ...
                    ['MacroSpec.prepare.description must match ' ...
                     'MacroSpec.description.']);
            end
            if isfield(prepare,'plan_template') && ...
                    ~strcmp(char(string(prepare.plan_template)), ...
                    spec.planTemplate)
                error(['planWorkflow:macros:MacroSpec:' ...
                    'InconsistentPrepare'], ...
                    ['MacroSpec.prepare.plan_template must match ' ...
                     'MacroSpec.planTemplate.']);
            end
            if isfield(prepare,'radiationMode') && ...
                    ~strcmp(char(string(prepare.radiationMode)), ...
                    spec.modality)
                error(['planWorkflow:macros:MacroSpec:' ...
                    'InconsistentPrepare'], ...
                    ['MacroSpec.prepare.radiationMode must match ' ...
                     'MacroSpec.modality.']);
            end

            prepare.caseID = spec.caseID;
            prepare.description = spec.description;
            prepare.plan_template = spec.planTemplate;
            prepare.radiationMode = spec.modality;
            if ~isfield(prepare,'AcquisitionType') || ...
                    isempty(prepare.AcquisitionType)
                prepare.AcquisitionType = 'dicom';
            end
            if ~isfield(prepare,'hlutFileName') || ...
                    isempty(prepare.hlutFileName)
                prepare.hlutFileName = 'matRad_default.hlut';
            end
            if ~isfield(prepare,'dicomMetadata') || ...
                    isempty(prepare.dicomMetadata)
                prepare.dicomMetadata = struct();
            end
            if ~isfield(prepare,'resolution') || isempty(prepare.resolution)
                prepare.resolution = [3 3 3];
            end
        end

        function scenario = normalizeScenario(scenario,context,defaultMode)
            if ~isstruct(scenario) || ~isscalar(scenario)
                error('planWorkflow:macros:MacroSpec:InvalidScenario', ...
                    '%s must be a scalar struct.',context);
            end
            if isfield(scenario,'mode') && ~isempty(scenario.mode)
                defaultMode = scenario.mode;
            end
            defaults = planWorkflow.config.ScenarioSpec.defaults(defaultMode);
            scenario = planWorkflow.config.ScenarioSpec.normalize( ...
                scenario,defaults,context);
        end

        function value = optionalLogical(spec,fieldName,defaultValue)
            if isfield(spec,fieldName)
                value = spec.(fieldName);
            else
                value = defaultValue;
            end
            value = planWorkflow.config.ConfigValue.logicalScalar( ...
                value,['MacroSpec.' fieldName], ...
                'planWorkflow:macros:MacroSpec:InvalidLogical');
        end

        function validateRandomSeed(value,context)
            if isempty(value)
                return;
            end
            if ~(isnumeric(value) && isscalar(value) && ...
                    isfinite(value) && value >= 0 && floor(value) == value)
                error('planWorkflow:macros:MacroSpec:InvalidRandomSeed', ...
                    '%s must be empty or a non-negative integer scalar.', ...
                    context);
            end
        end
    end
end
