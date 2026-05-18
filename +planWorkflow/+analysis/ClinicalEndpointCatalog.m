classdef ClinicalEndpointCatalog
    % ClinicalEndpointCatalog Loads clinical endpoint definitions.

    methods (Static)
        function endpoints = forRunConfig(runConfig,endpointQuantity)
            if nargin < 2
                endpointQuantity = '';
            end
            endpoints = struct([]);
            if ~isstruct(runConfig)
                return;
            end

            hasExplicitEndpoints = false;
            if isfield(runConfig,'analysis') && ...
                    isstruct(runConfig.analysis) && ...
                    isfield(runConfig.analysis,'endpointsFile') && ...
                    ~planWorkflow.analysis.ClinicalEndpointCatalog.isEmptyFileSelection( ...
                    runConfig.analysis.endpointsFile)
                fileEndpoints = ...
                    planWorkflow.analysis.ClinicalEndpointCatalog.loadFile( ...
                    runConfig.analysis.endpointsFile);
                endpoints = ...
                    planWorkflow.analysis.ClinicalEndpointCatalog.appendEndpoints( ...
                    endpoints,fileEndpoints);
                hasExplicitEndpoints = true;
            end

            if isfield(runConfig,'analysis') && ...
                    isstruct(runConfig.analysis) && ...
                    isfield(runConfig.analysis,'endpoints') && ...
                    ~isempty(runConfig.analysis.endpoints)
                inlineEndpoints = ...
                    planWorkflow.analysis.ClinicalEndpointCatalog.normalize( ...
                    runConfig.analysis.endpoints, ...
                    'runConfig.analysis.endpoints');
                endpoints = ...
                    planWorkflow.analysis.ClinicalEndpointCatalog.appendEndpoints( ...
                    endpoints,inlineEndpoints);
                hasExplicitEndpoints = true;
            end

            if ~hasExplicitEndpoints && isfield(runConfig,'description') && ...
                    ~isempty(runConfig.description)
                endpoints = ...
                    planWorkflow.analysis.ClinicalEndpointCatalog.loadDescription( ...
                    runConfig.description);
            end
            endpoints = ...
                planWorkflow.analysis.ClinicalEndpointCatalog.filterByDoseQuantity( ...
                endpoints,endpointQuantity);
        end

        function endpoints = loadDescription(description)
            endpoints = struct([]);
            filePath = ...
                planWorkflow.analysis.ClinicalEndpointCatalog.descriptionFile( ...
                description);
            if isempty(filePath)
                return;
            end
            endpoints = ...
                planWorkflow.analysis.ClinicalEndpointCatalog.loadFile( ...
                filePath);
        end

        function endpoints = loadFile(filePath)
            filePath = ...
                planWorkflow.analysis.ClinicalEndpointCatalog.resolveFile( ...
                filePath);
            if isempty(filePath)
                endpoints = struct([]);
                return;
            end
            if ~isfile(filePath)
                error(['planWorkflow:analysis:ClinicalEndpointCatalog:' ...
                    'MissingEndpointFile'], ...
                    'Clinical endpoint file "%s" does not exist.', ...
                    char(filePath));
            end

            document = jsondecode(fileread(filePath));
            if isstruct(document) && isfield(document,'endpoints')
                rawEndpoints = document.endpoints;
            else
                rawEndpoints = document;
            end
            endpoints = ...
                planWorkflow.analysis.ClinicalEndpointCatalog.normalize( ...
                rawEndpoints,char(filePath));
        end

        function filePath = resolveFile(filePath)
            if planWorkflow.analysis.ClinicalEndpointCatalog.isEmptyFileSelection( ...
                    filePath)
                filePath = '';
                return;
            end
            filePath = char(filePath);
            if isfile(filePath)
                return;
            end
            catalogPath = fullfile( ...
                planWorkflow.analysis.ClinicalEndpointCatalog.folder(), ...
                filePath);
            if isfile(catalogPath)
                filePath = catalogPath;
            end
        end

        function tf = isEmptyFileSelection(filePath)
            if isempty(filePath)
                tf = true;
                return;
            end
            value = lower(strtrim(char(filePath)));
            tf = isempty(value) || any(strcmp(value, ...
                {'none','<none>','no endpoints'}));
        end

        function filePath = normalizeFileSelection(filePath)
            if planWorkflow.analysis.ClinicalEndpointCatalog.isEmptyFileSelection( ...
                    filePath)
                filePath = '';
            else
                filePath = char(filePath);
            end
        end

        function files = filesForDoseQuantity(doseQuantity)
            if nargin < 1
                doseQuantity = '';
            end
            files = ...
                planWorkflow.analysis.ClinicalEndpointFileIndex.filesForDoseQuantity( ...
                doseQuantity);
        end

        function names = fileNamesForDoseQuantity(doseQuantity)
            if nargin < 1 || ...
                    ~planWorkflow.analysis.ClinicalEndpointCatalog.supportsDoseQuantity( ...
                    doseQuantity)
                names = {'none'};
                return;
            end
            files = ...
                planWorkflow.analysis.ClinicalEndpointCatalog.filesForDoseQuantity( ...
                doseQuantity);
            names = [{'none'} {files.name}];
        end

        function doseQuantities = fileDoseQuantities(filePath)
            filePath = ...
                planWorkflow.analysis.ClinicalEndpointCatalog.resolveFile( ...
                filePath);
            if isempty(filePath) || ~isfile(filePath)
                doseQuantities = {};
                return;
            end
            doseQuantities = ...
                planWorkflow.analysis.ClinicalEndpointFileIndex.fileDoseQuantities( ...
                filePath);
        end

        function filePath = descriptionFile(description)
            filePath = '';
            folder = planWorkflow.analysis.ClinicalEndpointCatalog.folder();
            candidates = ...
                planWorkflow.analysis.ClinicalEndpointCatalog.fileCandidates( ...
                description);
            for i = 1:numel(candidates)
                candidate = fullfile(folder,candidates{i});
                if isfile(candidate)
                    filePath = candidate;
                    return;
                end
            end
        end

        function folder = folder()
            folder = fullfile(fileparts(mfilename('fullpath')), ...
                'endpoints');
        end

        function candidates = fileCandidates(description)
            description = lower(strtrim(char(description)));
            safeName = regexprep(description,'[^a-z0-9]+','_');
            safeName = regexprep(safeName,'(^_+|_+$)','');
            candidates = unique({[description '.json'], ...
                [safeName '.json']},'stable');
        end

        function tf = supportsDoseQuantity(doseQuantity)
            tf = any(strcmp(char(doseQuantity), ...
                planWorkflow.analysis.ClinicalEndpointCatalog.supportedDoseQuantities()));
        end

        function quantities = supportedDoseQuantities()
            quantities = {'physicalDose','RBExDose'};
        end

        function endpoints = appendEndpoints(endpoints,newEndpoints)
            if isempty(newEndpoints)
                return;
            end
            if isempty(endpoints)
                endpoints = reshape(newEndpoints,1,[]);
            else
                endpoints = [reshape(endpoints,1,[]) ...
                    reshape(newEndpoints,1,[])];
            end
        end

        function endpoints = filterByDoseQuantity(endpoints,doseQuantity)
            if isempty(endpoints) || nargin < 2 || isempty(doseQuantity)
                return;
            end
            doseQuantity = char(doseQuantity);
            keep = strcmp({endpoints.doseQuantity},doseQuantity);
            endpoints = endpoints(keep);
        end

        function endpoints = normalize(rawEndpoints,context)
            if nargin < 2
                context = 'endpoints';
            end
            if isempty(rawEndpoints)
                endpoints = struct([]);
                return;
            end
            if iscell(rawEndpoints)
                if ~all(cellfun(@isstruct,rawEndpoints))
                    error(['planWorkflow:analysis:ClinicalEndpointCatalog:' ...
                        'InvalidEndpoints'], ...
                        '%s must be a struct array.',char(context));
                end
                endpointTemplate = struct('structureNames',{{}}, ...
                    'metric','','kind','','goal','','doseQuantity','', ...
                    'threshold',NaN,'thresholdUnit','', ...
                    'thresholdMode','','unit','','outputDoseMode','', ...
                    'required',true);
                endpoints = repmat(endpointTemplate,1,numel(rawEndpoints));
                for i = 1:numel(rawEndpoints)
                    endpointContext = sprintf('%s(%d)',char(context),i);
                    endpoints(i) = ...
                        planWorkflow.analysis.ClinicalEndpointCatalog.normalizeEndpoint( ...
                        rawEndpoints{i},endpointContext);
                end
                return;
            end
            if ~isstruct(rawEndpoints)
                error(['planWorkflow:analysis:ClinicalEndpointCatalog:' ...
                    'InvalidEndpoints'], ...
                    '%s must be a struct array.',char(context));
            end

            endpointTemplate = struct('structureNames',{{}}, ...
                'metric','','kind','','goal','','doseQuantity','', ...
                'threshold',NaN,'thresholdUnit','', ...
                'thresholdMode','','unit','','outputDoseMode','', ...
                'required',true);
            endpoints = repmat(endpointTemplate,1,numel(rawEndpoints));
            for i = 1:numel(rawEndpoints)
                endpointContext = sprintf('%s(%d)',char(context),i);
                endpoints(i) = ...
                    planWorkflow.analysis.ClinicalEndpointCatalog.normalizeEndpoint( ...
                    rawEndpoints(i),endpointContext);
            end
        end

        function endpoint = normalizeEndpoint(rawEndpoint,context)
            requiredFields = {'structureNames','metric','kind','goal', ...
                'doseQuantity','unit'};
            for i = 1:numel(requiredFields)
                if ~isfield(rawEndpoint,requiredFields{i}) || ...
                        isempty(rawEndpoint.(requiredFields{i}))
                    error(['planWorkflow:analysis:ClinicalEndpointCatalog:' ...
                        'MissingEndpointField'], ...
                        '%s requires field "%s".',char(context), ...
                        requiredFields{i});
                end
            end

            endpoint = struct();
            endpoint.structureNames = ...
                planWorkflow.analysis.ClinicalEndpointCatalog.cellstrValue( ...
                rawEndpoint.structureNames);
            endpoint.metric = char(rawEndpoint.metric);
            endpoint.kind = char(rawEndpoint.kind);
            endpoint.goal = char(rawEndpoint.goal);
            endpoint.doseQuantity = char(rawEndpoint.doseQuantity);
            endpoint.unit = char(rawEndpoint.unit);
            endpoint.threshold = NaN;
            endpoint.thresholdUnit = '';
            endpoint.thresholdMode = '';
            endpoint.outputDoseMode = '';
            endpoint.required = true;
            if isfield(rawEndpoint,'threshold') && ...
                    ~isempty(rawEndpoint.threshold)
                endpoint.threshold = rawEndpoint.threshold;
            end
            if isfield(rawEndpoint,'thresholdUnit') && ...
                    ~isempty(rawEndpoint.thresholdUnit)
                endpoint.thresholdUnit = char(rawEndpoint.thresholdUnit);
            end
            if isfield(rawEndpoint,'thresholdMode') && ...
                    ~isempty(rawEndpoint.thresholdMode)
                endpoint.thresholdMode = char(rawEndpoint.thresholdMode);
            end
            if isfield(rawEndpoint,'outputDoseMode') && ...
                    ~isempty(rawEndpoint.outputDoseMode)
                endpoint.outputDoseMode = char(rawEndpoint.outputDoseMode);
            end
            if isfield(rawEndpoint,'required') && ...
                    ~isempty(rawEndpoint.required)
                endpoint.required = ...
                    planWorkflow.analysis.ClinicalEndpointCatalog.logicalValue( ...
                    rawEndpoint.required,context);
            end
            planWorkflow.analysis.ClinicalEndpointCatalog.validateEndpoint( ...
                endpoint,context);
        end

        function values = cellstrValue(value)
            if ischar(value) || isstring(value)
                values = cellstr(value);
                return;
            end
            if iscell(value)
                values = cellfun(@char,value,'UniformOutput',false);
                return;
            end
            error(['planWorkflow:analysis:ClinicalEndpointCatalog:' ...
                'InvalidStructureNames'], ...
                'Endpoint structureNames must be text or a cell array.');
        end

        function validateEndpoint(endpoint,context)
            supportedKinds = {'V','D','mean','max'};
            if ~any(strcmp(endpoint.kind,supportedKinds))
                error(['planWorkflow:analysis:ClinicalEndpointCatalog:' ...
                    'InvalidEndpointKind'], ...
                    '%s has unsupported kind "%s". Supported kinds are: %s.', ...
                    char(context),endpoint.kind,strjoin(supportedKinds,', '));
            end
            planWorkflow.analysis.ClinicalEndpointCatalog.validateGoal( ...
                endpoint,context);
            if any(strcmp(endpoint.kind,{'V','D'})) && ...
                    ~(isnumeric(endpoint.threshold) && ...
                    isscalar(endpoint.threshold) && ...
                    isfinite(endpoint.threshold))
                error(['planWorkflow:analysis:ClinicalEndpointCatalog:' ...
                    'InvalidEndpointThreshold'], ...
                    '%s kind "%s" requires a finite scalar threshold.', ...
                    char(context),endpoint.kind);
            end
            if strcmp(endpoint.kind,'V')
                planWorkflow.analysis.ClinicalEndpointCatalog.validateDoseThreshold( ...
                    endpoint,context);
            elseif strcmp(endpoint.kind,'D')
                planWorkflow.analysis.ClinicalEndpointCatalog.validateVolumeThreshold( ...
                    endpoint,context);
            end
            if any(strcmp(endpoint.kind,{'D','mean','max'}))
                planWorkflow.analysis.ClinicalEndpointCatalog.validateOutputDoseMode( ...
                    endpoint,context);
            end
        end

        function validateDoseThreshold(endpoint,context)
            if isempty(endpoint.thresholdUnit) || ...
                    isempty(endpoint.thresholdMode)
                error(['planWorkflow:analysis:ClinicalEndpointCatalog:' ...
                    'MissingEndpointThresholdSemantics'], ...
                    ['%s kind "V" requires thresholdUnit and ' ...
                     'thresholdMode.'],char(context));
            end
            supportedModes = {'totalDose','perFractionDose'};
            expectedUnit = ...
                planWorkflow.analysis.ClinicalEndpointCatalog.doseUnit( ...
                endpoint.doseQuantity,context);
            if ~strcmp(endpoint.thresholdUnit,expectedUnit) || ...
                    ~any(strcmp(endpoint.thresholdMode,supportedModes))
                error(['planWorkflow:analysis:ClinicalEndpointCatalog:' ...
                    'InvalidEndpointThresholdSemantics'], ...
                    ['%s kind "V" supports thresholdUnit "%s" and ' ...
                     'thresholdMode totalDose or perFractionDose.'], ...
                    char(context),expectedUnit);
            end
        end

        function validateVolumeThreshold(endpoint,context)
            if isempty(endpoint.thresholdUnit) || ...
                    isempty(endpoint.thresholdMode)
                error(['planWorkflow:analysis:ClinicalEndpointCatalog:' ...
                    'MissingEndpointThresholdSemantics'], ...
                    ['%s kind "D" requires thresholdUnit and ' ...
                     'thresholdMode.'],char(context));
            end
            if ~strcmp(endpoint.thresholdUnit,'%') || ...
                    ~strcmp(endpoint.thresholdMode,'volumePercent')
                error(['planWorkflow:analysis:ClinicalEndpointCatalog:' ...
                    'InvalidEndpointThresholdSemantics'], ...
                    ['%s kind "D" supports thresholdUnit "%%" and ' ...
                     'thresholdMode "volumePercent".'],char(context));
            end
        end

        function validateOutputDoseMode(endpoint,context)
            supportedModes = {'totalDose','perFractionDose'};
            if isempty(endpoint.outputDoseMode) || ...
                    ~any(strcmp(endpoint.outputDoseMode,supportedModes))
                error(['planWorkflow:analysis:ClinicalEndpointCatalog:' ...
                    'InvalidEndpointOutputDoseMode'], ...
                    ['%s kind "%s" must define outputDoseMode as ' ...
                     'totalDose or perFractionDose.'], ...
                    char(context),char(endpoint.kind));
            end
            expectedUnit = ...
                planWorkflow.analysis.ClinicalEndpointCatalog.doseUnit( ...
                endpoint.doseQuantity,context);
            if ~strcmp(endpoint.unit,expectedUnit)
                error(['planWorkflow:analysis:ClinicalEndpointCatalog:' ...
                    'InvalidEndpointOutputUnit'], ...
                    '%s kind "%s" must use output unit "%s".', ...
                    char(context),char(endpoint.kind),expectedUnit);
            end
        end

        function value = logicalValue(rawValue,context)
            if islogical(rawValue) && isscalar(rawValue)
                value = rawValue;
                return;
            end
            if isnumeric(rawValue) && isscalar(rawValue) && ...
                    isfinite(rawValue) && any(rawValue == [0 1])
                value = logical(rawValue);
                return;
            end
            if ischar(rawValue) || (isstring(rawValue) && isscalar(rawValue))
                switch lower(strtrim(char(rawValue)))
                    case {'true','1','yes','on'}
                        value = true;
                        return;
                    case {'false','0','no','off'}
                        value = false;
                        return;
                end
            end
            error(['planWorkflow:analysis:ClinicalEndpointCatalog:' ...
                'InvalidEndpointRequired'], ...
                '%s.required must be a scalar logical value.',char(context));
        end

        function unit = doseUnit(doseQuantity,context)
            switch char(doseQuantity)
                case 'physicalDose'
                    unit = 'Gy';
                case 'RBExDose'
                    unit = 'Gy(RBE)';
                otherwise
                    error(['planWorkflow:analysis:ClinicalEndpointCatalog:' ...
                        'InvalidEndpointDoseQuantity'], ...
                        ['%s has unsupported clinical endpoint ' ...
                         'doseQuantity "%s". The workflow can optimize ' ...
                         'other matRad quantities, but clinical endpoint ' ...
                         'units are currently defined only for: %s.'], ...
                        char(context),char(doseQuantity), ...
                        strjoin( ...
                        planWorkflow.analysis.ClinicalEndpointCatalog.supportedDoseQuantities(), ...
                        ', '));
            end
        end

        function validateGoal(endpoint,context)
            supportedGoals = {'lowerIsBetter','higherIsBetter','reportOnly'};
            if ~any(strcmp(endpoint.goal,supportedGoals))
                error(['planWorkflow:analysis:ClinicalEndpointCatalog:' ...
                    'InvalidEndpointGoal'], ...
                    ['%s has unsupported goal "%s". Supported goals are: ' ...
                     '%s.'],char(context),char(endpoint.goal), ...
                    strjoin(supportedGoals,', '));
            end
        end
    end
end
