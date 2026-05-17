classdef DoseQuantityResolver
    % DoseQuantityResolver Canonical optimization/analysis dose quantity rules.

    methods (Static)
        function quantity = fromRunConfig(runConfig)
            quantity = '';
            if ~isstruct(runConfig)
                return;
            end

            quantity = ...
                planWorkflow.plan.DoseQuantityResolver.explicitQuantity( ...
                runConfig,'quantityOpt');
            bioModel = ...
                planWorkflow.plan.DoseQuantityResolver.bioModelFromRunConfig( ...
                runConfig);
            if ~isempty(quantity)
                if ~isempty(bioModel)
                    radiationMode = ...
                        planWorkflow.plan.DoseQuantityResolver.textField( ...
                        runConfig,'radiationMode');
                    planWorkflow.plan.DoseQuantityResolver.assertSupported( ...
                        quantity,radiationMode,bioModel);
                end
                return;
            end

            if ~isempty(bioModel)
                radiationMode = ...
                    planWorkflow.plan.DoseQuantityResolver.textField( ...
                    runConfig,'radiationMode');
                quantity = ...
                    planWorkflow.plan.DoseQuantityResolver.fromBioModel( ...
                    radiationMode,bioModel);
                return;
            end

            quantity = '';
        end

        function quantity = requireFromRunConfig(runConfig,context)
            quantity = ...
                planWorkflow.plan.DoseQuantityResolver.fromRunConfig( ...
                runConfig);
            if isempty(quantity)
                if nargin < 2 || isempty(context)
                    context = 'runConfig';
                end
                error('planWorkflow:plan:DoseQuantityResolver:MissingQuantity', ...
                    ['%s does not define an optimization dose quantity. ' ...
                     'Set quantityOpt or a valid radiationMode/bioModel.'], ...
                    char(context));
            end
        end

        function quantity = fromPlan(pln,optimizationQuantity)
            if nargin < 2
                optimizationQuantity = '';
            end

            quantity = '';
            if isstruct(pln) && isfield(pln,'propOpt') && ...
                    isstruct(pln.propOpt) && isfield(pln.propOpt,'quantityOpt')
                quantity = ...
                    planWorkflow.plan.DoseQuantityResolver.normalizeQuantity( ...
                    pln.propOpt.quantityOpt);
            end
            if isempty(quantity) && isstruct(pln) && isfield(pln,'bioParam')
                quantity = ...
                    planWorkflow.plan.DoseQuantityResolver.bioParamField( ...
                    pln.bioParam,'quantityOpt');
            end
            if isempty(quantity)
                quantity = ...
                    planWorkflow.plan.DoseQuantityResolver.normalizeQuantity( ...
                    optimizationQuantity);
            end
            if isempty(quantity)
                error('planWorkflow:plan:DoseQuantityResolver:MissingQuantity', ...
                    ['Plan analysis requires the optimization quantity ' ...
                     'from pln.propOpt.quantityOpt or prepared ' ...
                     'data.quantityOpt.']);
            end
        end

        function quantity = visualFromRunConfig(runConfig)
            info = ...
                planWorkflow.plan.DoseQuantityResolver.bioModelInfoFromRunConfig( ...
                runConfig);
            quantity = info.quantityVis;
        end

        function info = bioModelInfoFromRunConfig(runConfig)
            info = struct('bioOpt','','quantityVis','');
            if ~isstruct(runConfig)
                return;
            end
            optimizationQuantity = ...
                planWorkflow.plan.DoseQuantityResolver.fromRunConfig( ...
                runConfig);
            if isempty(optimizationQuantity)
                return;
            end
            radiationMode = ...
                planWorkflow.plan.DoseQuantityResolver.textField( ...
                runConfig,'radiationMode');
            bioModel = ...
                planWorkflow.plan.DoseQuantityResolver.bioModelFromRunConfig( ...
                runConfig);
            if isempty(radiationMode) || isempty(bioModel)
                info.quantityVis = optimizationQuantity;
                return;
            end

            info.quantityVis = ...
                planWorkflow.plan.DoseQuantityResolver.visualQuantity( ...
                optimizationQuantity);
            info.bioOpt = ...
                planWorkflow.plan.DoseQuantityResolver.legacyBioOpt( ...
                optimizationQuantity);
        end

        function quantity = visualFromPlan(pln,optimizationQuantity)
            if nargin < 2
                optimizationQuantity = '';
            end
            quantity = '';
            if isstruct(pln) && isfield(pln,'propOpt') && ...
                    isstruct(pln.propOpt) && ...
                    isfield(pln.propOpt,'quantityVis') && ...
                    ~isempty(pln.propOpt.quantityVis)
                quantity = ...
                    planWorkflow.plan.DoseQuantityResolver.normalizeQuantity( ...
                    pln.propOpt.quantityVis);
            end
            if isempty(quantity) && isstruct(pln) && isfield(pln,'bioParam')
                quantity = ...
                    planWorkflow.plan.DoseQuantityResolver.visualFromBioParam( ...
                    pln.bioParam,optimizationQuantity);
            end
            if isempty(quantity)
                quantity = ...
                    planWorkflow.plan.DoseQuantityResolver.normalizeQuantity( ...
                    optimizationQuantity);
            end
        end

        function quantity = fromBioModel(radiationMode,bioModel)
            quantity = ...
                planWorkflow.matRadCapabilitiesReader.doseQuantityForBioModel( ...
                radiationMode,bioModel);
        end

        function quantities = supportedForRunConfig(runConfig)
            quantities = {};
            if ~isstruct(runConfig)
                return;
            end
            bioModel = ...
                planWorkflow.plan.DoseQuantityResolver.bioModelFromRunConfig( ...
                runConfig);
            if isempty(bioModel)
                return;
            end
            radiationMode = ...
                planWorkflow.plan.DoseQuantityResolver.textField( ...
                runConfig,'radiationMode');
            if isempty(radiationMode)
                return;
            end
            quantities = ...
                planWorkflow.matRadCapabilitiesReader.supportedDoseQuantities( ...
                radiationMode,bioModel);
        end

        function runConfig = applyDefaultToRunConfig(runConfig,forceDefault)
            if nargin < 2
                forceDefault = false;
            end
            quantities = ...
                planWorkflow.plan.DoseQuantityResolver.supportedForRunConfig( ...
                runConfig);
            if isempty(quantities)
                return;
            end
            quantity = ...
                planWorkflow.plan.DoseQuantityResolver.explicitQuantity( ...
                runConfig,'quantityOpt');
            if forceDefault || isempty(quantity)
                runConfig.quantityOpt = ...
                    planWorkflow.plan.DoseQuantityResolver.fromBioModel( ...
                    runConfig.radiationMode, ...
                    planWorkflow.plan.DoseQuantityResolver.bioModelFromRunConfig( ...
                    runConfig));
                return;
            end
            planWorkflow.plan.DoseQuantityResolver.assertSupported( ...
                quantity,runConfig.radiationMode, ...
                planWorkflow.plan.DoseQuantityResolver.bioModelFromRunConfig( ...
                runConfig));
            runConfig.quantityOpt = quantity;
        end

        function quantity = normalizeQuantity(value)
            quantity = '';
            if ischar(value)
                quantity = char(value);
            elseif isstring(value) && isscalar(value)
                quantity = char(value);
            else
                return;
            end
            supported = ...
                planWorkflow.matRadCapabilitiesReader.supportedDoseQuantityNames();
            if ~any(strcmp(quantity,supported))
                error('planWorkflow:plan:DoseQuantityResolver:InvalidQuantity', ...
                    'Unsupported dose quantity "%s". Supported values are: %s.', ...
                    quantity,strjoin(supported,', '));
            end
        end
    end

    methods (Static, Access = private)
        function quantity = explicitQuantity(runConfig,fieldName)
            quantity = '';
            if isfield(runConfig,fieldName) && ~isempty(runConfig.(fieldName))
                quantity = ...
                    planWorkflow.plan.DoseQuantityResolver.normalizeQuantity( ...
                    runConfig.(fieldName));
            end
        end

        function bioModel = bioModelFromRunConfig(runConfig)
            bioModel = ...
                planWorkflow.plan.DoseQuantityResolver.textField( ...
                runConfig,'bioModel');
            if ~isempty(bioModel)
                return;
            end

            radiationMode = ...
                planWorkflow.plan.DoseQuantityResolver.textField( ...
                runConfig,'radiationMode');
            if isempty(radiationMode)
                return;
            end
            try
                bioModel = ...
                    planWorkflow.matRadCapabilitiesReader.defaultBioModel( ...
                    radiationMode);
            catch
                bioModel = '';
            end
        end

        function value = textField(source,fieldName)
            value = '';
            if isstruct(source) && isfield(source,fieldName) && ...
                    ~isempty(source.(fieldName))
                rawValue = source.(fieldName);
                if ischar(rawValue)
                    value = rawValue;
                elseif isstring(rawValue) && isscalar(rawValue)
                    value = char(rawValue);
                end
            end
        end

        function value = bioParamField(bioParam,fieldName)
            value = '';
            if isstruct(bioParam) && isfield(bioParam,fieldName)
                value = planWorkflow.plan.DoseQuantityResolver.normalizeQuantity( ...
                    bioParam.(fieldName));
            elseif isobject(bioParam) && isprop(bioParam,fieldName) && ...
                    ~any(strcmp(fieldName,{'quantityOpt','quantityVis'}))
                value = planWorkflow.plan.DoseQuantityResolver.normalizeQuantity( ...
                    bioParam.(fieldName));
            elseif isobject(bioParam) && strcmp(fieldName,'quantityOpt') && ...
                    isprop(bioParam,'defaultReportQuantity')
                value = ...
                    planWorkflow.plan.DoseQuantityResolver.normalizeQuantity( ...
                    planWorkflow.plan.DoseQuantityResolver.toWorkflowQuantity( ...
                    bioParam.defaultReportQuantity));
            end
        end

        function value = bioParamRawField(bioParam,fieldName)
            value = '';
            if isstruct(bioParam) && isfield(bioParam,fieldName)
                value = bioParam.(fieldName);
            elseif isobject(bioParam) && isprop(bioParam,fieldName)
                value = bioParam.(fieldName);
            end
        end

        function quantity = visualFromBioParam(bioParam,fallback)
            if nargin < 2
                fallback = '';
            end
            quantity = ...
                planWorkflow.plan.DoseQuantityResolver.bioParamField( ...
                bioParam,'quantityVis');
            if isempty(quantity)
                quantity = ...
                    planWorkflow.plan.DoseQuantityResolver.visualQuantity( ...
                    fallback);
            end
        end

        function quantity = visualQuantity(optimizationQuantity)
            quantity = ...
                planWorkflow.plan.DoseQuantityResolver.normalizeQuantity( ...
                optimizationQuantity);
            if any(strcmp(quantity,{'effect','BED'}))
                quantity = 'physicalDose';
            end
        end

        function bioOpt = legacyBioOpt(optimizationQuantity)
            switch char(optimizationQuantity)
                case 'effect'
                    bioOpt = 1;
                case {'RBExD','RBExDose'}
                    bioOpt = 2;
                otherwise
                    bioOpt = [];
            end
        end

        function quantity = toWorkflowQuantity(quantity)
            quantity = char(quantity);
            if strcmp(quantity,'RBExDose')
                quantity = 'RBExD';
            end
        end

        function assertSupported(quantity,radiationMode,bioModel)
            supportedQuantities = ...
                planWorkflow.matRadCapabilitiesReader.supportedDoseQuantities( ...
                radiationMode,bioModel);
            if any(strcmp(quantity,supportedQuantities))
                return;
            end
            error(['planWorkflow:plan:DoseQuantityResolver:' ...
                'IncompatibleQuantity'], ...
                ['quantityOpt "%s" is incompatible with radiationMode ' ...
                 '"%s" and bioModel "%s". Supported quantities are: %s.'], ...
                char(quantity),char(radiationMode),char(bioModel), ...
                strjoin(supportedQuantities,', '));
        end
    end
end
