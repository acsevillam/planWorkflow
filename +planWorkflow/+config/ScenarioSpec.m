classdef ScenarioSpec
    % ScenarioSpec Canonical scenario configuration metadata.

    methods (Static)
        function fields = fields()
            fields = {'mode','ctActive','ctReferenceScenId', ...
                'ctScenProb', ...
                'setupActive','rangeActive','gantryActive','couchActive', ...
                'shiftSD','wcSigma', ...
                'rangeAbsSD','rangeRelSD','numOfRangeGridPoints', ...
                'gantryAngleSD','couchAngleSD','random_size', ...
                'randomSeed'};
        end

        function fields = matRadFields()
            fields = planWorkflow.config.ScenarioSpec.fields();
            fields{strcmp(fields,'mode')} = 'scen_mode';
        end

        function scenario = defaults(mode)
            if nargin < 1 || isempty(mode)
                mode = 'wcScen';
            end
            scenario = struct( ...
                'mode',char(mode), ...
                'ctActive',true, ...
                'ctReferenceScenId',1, ...
                'ctScenProb',[], ...
                'setupActive',true, ...
                'rangeActive',false, ...
                'gantryActive',false, ...
                'couchActive',false, ...
                'shiftSD',[5 10 5], ...
                'wcSigma',1.0, ...
                'rangeAbsSD',0, ...
                'rangeRelSD',0, ...
                'numOfRangeGridPoints',1, ...
                'gantryAngleSD',0, ...
                'couchAngleSD',0, ...
                'random_size',50, ...
                'randomSeed',[]);
        end

        function scenario = normalize(scenario,defaults,context)
            if nargin < 2 || isempty(defaults)
                defaults = planWorkflow.config.ScenarioSpec.defaults();
            end
            if nargin < 3 || isempty(context)
                context = 'scenario';
            end
            if isempty(scenario)
                scenario = struct();
            end
            if ~isstruct(scenario) || ~isscalar(scenario)
                error('planWorkflow:config:ScenarioSpec:InvalidScenario', ...
                    '%s must be a scalar struct.',context);
            end

            planWorkflow.config.ScenarioSpec.assertAllowedFields( ...
                scenario,fieldnames(defaults)',context);
            scenario = planWorkflow.config.ScenarioSpec.mergeDefaults( ...
                scenario,defaults);
            if ~isfield(scenario,'ctScenProb')
                scenario.ctScenProb = [];
            end
            scenario.mode = char(scenario.mode);
            planWorkflow.config.ScenarioSpec.validateMode( ...
                scenario.mode,[context '.mode']);
            scenario.ctActive = planWorkflow.config.ConfigValue.logicalScalar( ...
                scenario.ctActive,[context '.ctActive'], ...
                'planWorkflow:config:ScenarioSpec:InvalidLogical');
            scenario.ctReferenceScenId = ...
                planWorkflow.config.ScenarioSpec.positiveIntegerScalar( ...
                scenario.ctReferenceScenId,[context '.ctReferenceScenId']);
            scenario.ctScenProb = ...
                planWorkflow.config.ScenarioSpec.normalizeCtScenProb( ...
                scenario.ctScenProb,[context '.ctScenProb']);
            if ~scenario.ctActive && ~isempty(scenario.ctScenProb)
                error(['planWorkflow:config:ScenarioSpec:' ...
                    'IncompatibleCtScenProb'], ...
                    ['%s.ctScenProb is only valid when %s.ctActive is ' ...
                     'true. Use %s.ctReferenceScenId for a single CT ' ...
                     'scenario.'],context,context,context);
            end

            activeFields = planWorkflow.scenario.dimensionActiveFields();
            for i = 1:numel(activeFields)
                fieldName = activeFields{i};
                scenario.(fieldName) = ...
                    planWorkflow.config.ConfigValue.logicalScalar( ...
                    scenario.(fieldName),[context '.' fieldName], ...
                    'planWorkflow:config:ScenarioSpec:InvalidLogical');
            end

            numericFields = {'shiftSD','wcSigma','rangeAbsSD', ...
                'rangeRelSD','numOfRangeGridPoints','gantryAngleSD', ...
                'couchAngleSD','random_size'};
            for i = 1:numel(numericFields)
                fieldName = numericFields{i};
                scenario.(fieldName) = ...
                    planWorkflow.config.ScenarioSpec.numericValue( ...
                    scenario.(fieldName),[context '.' fieldName]);
            end
            scenario.numOfRangeGridPoints = ...
                planWorkflow.config.ScenarioSpec.positiveIntegerScalar( ...
                scenario.numOfRangeGridPoints, ...
                [context '.numOfRangeGridPoints']);
            scenario.random_size = ...
                planWorkflow.config.ScenarioSpec.positiveIntegerScalar( ...
                scenario.random_size,[context '.random_size']);
            scenario.randomSeed = ...
                planWorkflow.config.ScenarioSpec.optionalNonnegativeIntegerScalar( ...
                scenario.randomSeed,[context '.randomSeed']);
        end

        function matrix = ctScenProbMatrix(ctScenProb,ct,context)
            if nargin < 2
                ct = [];
            end
            if nargin < 3 || isempty(context)
                context = 'ctScenProb';
            end
            ctScenProb = planWorkflow.config.ScenarioSpec.normalizeCtScenProb( ...
                ctScenProb,context);
            if isempty(ctScenProb)
                ctScenProb = planWorkflow.config.ScenarioSpec.uniformCtScenProb( ...
                    ct);
            end
            planWorkflow.config.ScenarioSpec.validateCtScenProbLength( ...
                ctScenProb,ct,context);
            matrix = [(1:numel(ctScenProb))' ctScenProb(:)];
        end

        function ctScenProb = normalizeCtScenProb(ctScenProb,context)
            if nargin < 2 || isempty(context)
                context = 'ctScenProb';
            end
            if isempty(ctScenProb)
                ctScenProb = [];
                return;
            end
            if ~(isnumeric(ctScenProb) && isvector(ctScenProb) && ...
                    all(isfinite(ctScenProb(:))) && ...
                    all(ctScenProb(:) >= 0))
                error(['planWorkflow:config:ScenarioSpec:' ...
                    'InvalidCtScenProb'], ...
                    '%s must be empty or a finite non-negative vector.', ...
                    context);
            end
            totalProbability = sum(ctScenProb(:));
            if abs(totalProbability - 1) > 1e-10
                error(['planWorkflow:config:ScenarioSpec:' ...
                    'InvalidCtScenProb'], ...
                    '%s must sum to 1.',context);
            end
            ctScenProb = ctScenProb(:)';
        end

        function scenario = matRadScenario(scenario)
            scenario = planWorkflow.config.ScenarioSpec.normalize( ...
                scenario,scenario,'scenario');
            scenario.scen_mode = char(scenario.mode);
            scenario = rmfield(scenario,'mode');
        end

        function scenario = fromRunConfig(runConfig,prefix,defaults)
            if nargin < 3 || isempty(defaults)
                mode = [];
                modeField = ...
                    planWorkflow.config.ScenarioSpec.runFieldName( ...
                    prefix,'mode');
                if isstruct(runConfig) && isfield(runConfig,modeField)
                    mode = runConfig.(modeField);
                end
                defaults = planWorkflow.config.ScenarioSpec.defaults(mode);
            end
            scenario = struct();
            fields = planWorkflow.config.ScenarioSpec.fields();
            for i = 1:numel(fields)
                fieldName = fields{i};
                runFieldName = ...
                    planWorkflow.config.ScenarioSpec.runFieldName( ...
                    prefix,fieldName);
                if isstruct(runConfig) && isfield(runConfig,runFieldName)
                    scenario.(fieldName) = runConfig.(runFieldName);
                else
                    scenario.(fieldName) = defaults.(fieldName);
                end
            end
        end

        function runConfig = applyToRunConfig(runConfig,prefix,scenario)
            fields = fieldnames(scenario);
            for i = 1:numel(fields)
                fieldName = fields{i};
                runFieldName = ...
                    planWorkflow.config.ScenarioSpec.runFieldName( ...
                    prefix,fieldName);
                runConfig.(runFieldName) = scenario.(fieldName);
            end
        end

        function runFieldName = runFieldName(prefix,fieldName)
            if strcmp(fieldName,'mode')
                fieldName = 'scen_mode';
            end
            if strcmp(prefix,'sampling') && strcmp(fieldName,'random_size')
                runFieldName = 'sampling_size';
            elseif isempty(prefix)
                runFieldName = fieldName;
            else
                runFieldName = [char(prefix) '_' char(fieldName)];
            end
        end

        function scenario = withBeamCount(scenario,pln)
            scenario.numOfBeams = planWorkflow.plan.Plan.numOfBeams(pln);
        end

        function basis = basisMetadata(scenarioConfig,effectiveCtScenProb)
            if nargin < 2
                effectiveCtScenProb = [];
            end
            basis = struct();
            basis.scenarioMode = char(scenarioConfig.scen_mode);
            basis.wcSigma = scenarioConfig.wcSigma;
            basis.ctActive = scenarioConfig.ctActive;
            basis.ctReferenceScenId = scenarioConfig.ctReferenceScenId;
            basis.ctScenProb = [];
            basis.ctScenProbMode = ...
                planWorkflow.config.ScenarioSpec.ctScenProbMode( ...
                scenarioConfig,effectiveCtScenProb);
            if isfield(scenarioConfig,'ctScenProb')
                basis.ctScenProb = scenarioConfig.ctScenProb;
            end
            if ~isempty(effectiveCtScenProb)
                basis.ctScenProb = effectiveCtScenProb;
            end
            basis.scenarioDimensionActive = ...
                planWorkflow.scenario.activeDimensionNames(scenarioConfig);
            basis.shiftSD = scenarioConfig.shiftSD;
            basis.rangeAbsSD = scenarioConfig.rangeAbsSD;
            basis.rangeRelSD = scenarioConfig.rangeRelSD;
            basis.numOfRangeGridPoints = ...
                scenarioConfig.numOfRangeGridPoints;
            basis.gantryAngleSD = scenarioConfig.gantryAngleSD;
            basis.couchAngleSD = scenarioConfig.couchAngleSD;
            basis.randomSize = scenarioConfig.random_size;
            basis.randomSeed = scenarioConfig.randomSeed;
            basis.numOfBeams = 0;
            if isfield(scenarioConfig,'numOfBeams')
                basis.numOfBeams = scenarioConfig.numOfBeams;
            end
        end

        function fields = visiblePanelFields(scenMode,prefix,dimensionConfig)
            if nargin < 2
                prefix = '';
            end
            if nargin < 3
                dimensionConfig = struct();
            end
            dimensionConfig = ...
                planWorkflow.config.ScenarioSpec.completeDimensionConfig( ...
                dimensionConfig);
            fields = [{'scenarioModeSection', ...
                planWorkflow.config.ScenarioSpec.panelFieldName( ...
                prefix,'scen_mode')}, ...
                planWorkflow.config.ScenarioSpec.scenarioFields( ...
                scenMode,prefix,dimensionConfig)];
            fields = unique(fields,'stable');
        end

        function fields = scenarioFields(scenMode,prefix,dimensionConfig)
            dimensionConfig = ...
                planWorkflow.config.ScenarioSpec.completeDimensionConfig( ...
                dimensionConfig);
            fields = planWorkflow.config.ScenarioSpec.selectionFields( ...
                scenMode,prefix);
            switch char(scenMode)
                case 'nomScen'
                    parameterFields = ...
                        planWorkflow.config.ScenarioSpec.ctParameterFields( ...
                        prefix,dimensionConfig);
                case 'random'
                    parameterFields = [ ...
                        planWorkflow.config.ScenarioSpec.parameterFields( ...
                        prefix,dimensionConfig), ...
                        {planWorkflow.config.ScenarioSpec.panelFieldName( ...
                        prefix,'random_size'), ...
                        planWorkflow.config.ScenarioSpec.panelFieldName( ...
                        prefix,'randomSeed')}];
                otherwise
                    parameterFields = ...
                        planWorkflow.config.ScenarioSpec.parameterFields( ...
                        prefix,dimensionConfig);
                    if planWorkflow.config.ScenarioSpec.anyDimensionActive( ...
                            dimensionConfig)
                        parameterFields = [parameterFields, ...
                            {planWorkflow.config.ScenarioSpec.panelFieldName( ...
                            prefix,'wcSigma')}];
                    end
                    if dimensionConfig.rangeActive
                        parameterFields = [parameterFields, ...
                            {planWorkflow.config.ScenarioSpec.panelFieldName( ...
                            prefix,'numOfRangeGridPoints')}];
                    end
            end
            if ~isempty(parameterFields)
                fields = [fields,{'scenarioParameterSection'}, ...
                    parameterFields];
            end
        end

        function fields = selectionFields(scenMode,prefix)
            fields = {'scenarioSelectionSection', ...
                planWorkflow.config.ScenarioSpec.panelFieldName( ...
                prefix,'ctActive')};
            if ~strcmp(char(scenMode),'nomScen')
                fields = [fields, ...
                    {planWorkflow.config.ScenarioSpec.panelFieldName( ...
                    prefix,'setupActive'), ...
                    planWorkflow.config.ScenarioSpec.panelFieldName( ...
                    prefix,'rangeActive')}];
                if strcmp(char(scenMode),'random')
                    fields = [fields, ...
                        {planWorkflow.config.ScenarioSpec.panelFieldName( ...
                        prefix,'gantryActive'), ...
                        planWorkflow.config.ScenarioSpec.panelFieldName( ...
                        prefix,'couchActive')}];
                end
            end
        end

        function fields = parameterFields(prefix,dimensionConfig)
            dimensionConfig = ...
                planWorkflow.config.ScenarioSpec.completeDimensionConfig( ...
                dimensionConfig);
            fields = planWorkflow.config.ScenarioSpec.ctParameterFields( ...
                prefix,dimensionConfig);
            if dimensionConfig.setupActive
                fields{end + 1} = ...
                    planWorkflow.config.ScenarioSpec.panelFieldName( ...
                    prefix,'shiftSD');
            end
            if dimensionConfig.rangeActive
                fields = [fields, ...
                    {planWorkflow.config.ScenarioSpec.panelFieldName( ...
                    prefix,'rangeAbsSD'), ...
                    planWorkflow.config.ScenarioSpec.panelFieldName( ...
                    prefix,'rangeRelSD')}];
            end
            if dimensionConfig.gantryActive
                fields{end + 1} = ...
                    planWorkflow.config.ScenarioSpec.panelFieldName( ...
                    prefix,'gantryAngleSD');
            end
            if dimensionConfig.couchActive
                fields{end + 1} = ...
                    planWorkflow.config.ScenarioSpec.panelFieldName( ...
                    prefix,'couchAngleSD');
            end
        end

        function fields = ctParameterFields(prefix,dimensionConfig)
            dimensionConfig = ...
                planWorkflow.config.ScenarioSpec.completeDimensionConfig( ...
                dimensionConfig);
            fields = {};
            if dimensionConfig.ctActive
                fields{end + 1} = ...
                    planWorkflow.config.ScenarioSpec.panelFieldName( ...
                    prefix,'ctScenProb');
            else
                fields{end + 1} = ...
                    planWorkflow.config.ScenarioSpec.panelFieldName( ...
                    prefix,'ctReferenceScenId');
            end
        end

        function dimensionConfig = completeDimensionConfig(dimensionConfig)
            defaults = planWorkflow.config.ScenarioSpec.defaults();
            fields = [{'ctActive','ctReferenceScenId'}, ...
                planWorkflow.scenario.dimensionActiveFields()];
            for i = 1:numel(fields)
                fieldName = fields{i};
                if ~isfield(dimensionConfig,fieldName) || ...
                        isempty(dimensionConfig.(fieldName))
                    dimensionConfig.(fieldName) = defaults.(fieldName);
                end
                if strcmp(fieldName,'ctReferenceScenId')
                    dimensionConfig.(fieldName) = ...
                        planWorkflow.config.ScenarioSpec.positiveIntegerScalar( ...
                        dimensionConfig.(fieldName),fieldName);
                else
                    dimensionConfig.(fieldName) = ...
                        planWorkflow.config.ConfigValue.logicalScalar( ...
                        dimensionConfig.(fieldName),fieldName, ...
                        'planWorkflow:config:ScenarioSpec:InvalidLogical');
                end
            end
        end

        function fieldName = panelFieldName(prefix,fieldName)
            if strcmp(fieldName,'mode')
                fieldName = 'scen_mode';
            end
            if strcmp(fieldName,'random_size')
                if strcmp(prefix,'sampling')
                    fieldName = 'sampling_size';
                elseif ~isempty(prefix)
                    fieldName = [char(prefix) '_random_size'];
                end
                return;
            end
            if strcmp(fieldName,'randomSeed')
                if strcmp(prefix,'sampling')
                    fieldName = 'sampling_randomSeed';
                elseif ~isempty(prefix)
                    fieldName = [char(prefix) '_randomSeed'];
                end
                return;
            end
            if ~isempty(prefix)
                fieldName = [char(prefix) '_' char(fieldName)];
            end
        end
    end

    methods (Static, Access = private)
        function tf = anyDimensionActive(dimensionConfig)
            tf = dimensionConfig.setupActive || dimensionConfig.rangeActive || ...
                dimensionConfig.gantryActive || dimensionConfig.couchActive;
        end

        function validateMode(mode,context)
            supported = ...
                planWorkflow.matRadCapabilitiesReader.supportedScenarioModes();
            if ~any(strcmp(char(mode),supported))
                error('planWorkflow:config:ScenarioSpec:UnsupportedMode', ...
                    'Unsupported %s "%s". Supported modes are: %s.', ...
                    context,char(mode),strjoin(supported,', '));
            end
        end

        function assertAllowedFields(config,allowed,context)
            fields = fieldnames(config);
            for i = 1:numel(fields)
                if ~any(strcmp(fields{i},allowed))
                    error('planWorkflow:config:ScenarioSpec:UnsupportedField', ...
                        'Unsupported %s field "%s".',context,fields{i});
                end
            end
        end

        function merged = mergeDefaults(value,defaults)
            merged = value;
            fields = fieldnames(defaults);
            for i = 1:numel(fields)
                fieldName = fields{i};
                if ~isfield(merged,fieldName) || isempty(merged.(fieldName))
                    merged.(fieldName) = defaults.(fieldName);
                end
            end
        end

        function value = numericValue(value,context)
            if ~(isnumeric(value) && ~isempty(value) && ...
                    all(isfinite(value(:))))
                error('planWorkflow:config:ScenarioSpec:InvalidNumeric', ...
                    '%s must be finite numeric.',context);
            end
        end

        function value = positiveIntegerScalar(value,context)
            if ~(isnumeric(value) && isscalar(value) && isfinite(value) && ...
                    value >= 1 && round(value) == value)
                error(['planWorkflow:config:ScenarioSpec:' ...
                    'InvalidPositiveInteger'], ...
                    '%s must be a positive integer scalar.',context);
            end
        end

        function value = optionalNonnegativeIntegerScalar(value,context)
            if isempty(value)
                value = [];
                return;
            end
            if ~(isnumeric(value) && isscalar(value) && isfinite(value) && ...
                    value >= 0 && round(value) == value)
                error(['planWorkflow:config:ScenarioSpec:' ...
                    'InvalidOptionalInteger'], ...
                    '%s must be empty or a non-negative integer scalar.', ...
                    context);
            end
        end

        function values = uniformCtScenProb(ct)
            numOfCtScen = 1;
            if nargin >= 1 && ~isempty(ct) && isfield(ct,'numOfCtScen') && ...
                    ~isempty(ct.numOfCtScen)
                numOfCtScen = ct.numOfCtScen;
            end
            if ~(isnumeric(numOfCtScen) && isscalar(numOfCtScen) && ...
                    isfinite(numOfCtScen) && numOfCtScen >= 1 && ...
                    round(numOfCtScen) == numOfCtScen)
                error(['planWorkflow:config:ScenarioSpec:' ...
                    'InvalidCtScenarioCount'], ...
                    'ct.numOfCtScen must be a positive integer scalar.');
            end
            values = ones(1,numOfCtScen) / numOfCtScen;
        end

        function mode = ctScenProbMode(scenarioConfig,effectiveCtScenProb)
            if ~isfield(scenarioConfig,'ctActive') || ...
                    ~logical(scenarioConfig.ctActive)
                mode = 'reference';
                return;
            end
            if isfield(scenarioConfig,'ctScenProb') && ...
                    ~isempty(scenarioConfig.ctScenProb)
                mode = 'explicit';
                return;
            end
            if ~isempty(effectiveCtScenProb)
                mode = 'uniform';
            else
                mode = 'default';
            end
        end

        function validateCtScenProbLength(ctScenProb,ct,context)
            if nargin < 3 || isempty(context)
                context = 'ctScenProb';
            end
            if nargin < 2 || isempty(ct) || ~isfield(ct,'numOfCtScen') || ...
                    isempty(ct.numOfCtScen)
                return;
            end
            numOfCtScen = ct.numOfCtScen;
            if numel(ctScenProb) ~= numOfCtScen
                error(['planWorkflow:config:ScenarioSpec:' ...
                    'InvalidCtScenProb'], ...
                    ['%s must contain one probability per CT scenario ' ...
                     '(%d values expected, %d received).'], ...
                    context,numOfCtScen,numel(ctScenProb));
            end
        end
    end
end
