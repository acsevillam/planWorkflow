classdef EndpointStructureContract
    % EndpointStructureContract Shared clinical-endpoint structure contract.

    methods (Static)
        function endpoints = endpoints(runConfig,endpointQuantity)
            if nargin < 2
                endpointQuantity = '';
            end
            endpoints = ...
                planWorkflow.analysis.ClinicalEndpointCatalog.forRunConfig( ...
                runConfig,endpointQuantity);
        end

        function requirements = requirements(runConfig,endpointQuantity)
            if nargin < 2
                endpointQuantity = '';
            end
            requirements = ...
                planWorkflow.analysis.EndpointStructureContract.fromEndpoints( ...
                planWorkflow.analysis.EndpointStructureContract.endpoints( ...
                runConfig,endpointQuantity));
        end

        function requirements = fromEndpoints(endpoints)
            requirements = ...
                planWorkflow.analysis.EndpointStructureContract.emptyRequirement();
            for endpointIx = 1:numel(endpoints)
                requirements(end + 1) = ...
                    planWorkflow.analysis.EndpointStructureContract.requirement( ...
                    endpoints(endpointIx)); %#ok<AGROW>
            end
        end

        function validateTemplate(template,runConfig,endpointQuantity)
            if nargin < 3
                endpointQuantity = '';
            end
            requirements = ...
                planWorkflow.analysis.EndpointStructureContract.requirements( ...
                runConfig,endpointQuantity);
            if isempty(requirements)
                return;
            end
            availableNames = ...
                planWorkflow.analysis.EndpointStructureContract.templateNames( ...
                template);
            planWorkflow.analysis.EndpointStructureContract.validateNames( ...
                availableNames,requirements, ...
                sprintf('template "%s"',char(template.id)));
        end

        function validateNames(availableNames,requirements,context)
            availableNames = ...
                planWorkflow.analysis.EndpointStructureContract.textCell( ...
                availableNames);
            for requirementIx = 1:numel(requirements)
                if planWorkflow.analysis.EndpointStructureContract.hasAnyName( ...
                        availableNames,requirements(requirementIx).alternatives)
                    continue;
                end
                if ~requirements(requirementIx).required
                    continue;
                end
                error(['planWorkflow:analysis:EndpointStructureContract:' ...
                    'MissingRequiredStructure'], ...
                    ['Clinical endpoint contract for %s requires %s ' ...
                     'with one of these structures: %s.'], ...
                    char(context),char(requirements(requirementIx).label), ...
                    strjoin(requirements(requirementIx).alternatives,', '));
            end
        end

        function names = templateNames(template)
            names = {};
            if isstruct(template) && isfield(template,'structures')
                names = ...
                    planWorkflow.analysis.EndpointStructureContract.appendNames( ...
                    names,template.structures);
            end
            if isstruct(template) && isfield(template,'rings')
                names = ...
                    planWorkflow.analysis.EndpointStructureContract.appendNames( ...
                    names,template.rings);
            end
        end

        function names = appendNames(names,items)
            for itemIx = 1:numel(items)
                if isfield(items(itemIx),'name') && ...
                        ~isempty(items(itemIx).name)
                    names{end + 1} = char(items(itemIx).name); %#ok<AGROW>
                end
            end
        end

        function requirement = requirement(endpoint)
            requirement = ...
                planWorkflow.analysis.EndpointStructureContract.emptyRequirement();
            requirement(1).label = sprintf('clinical endpoint %s', ...
                char(endpoint.metric));
            requirement(1).alternatives = ...
                planWorkflow.analysis.EndpointStructureContract.textCell( ...
                endpoint.structureNames);
            requirement(1).required = ...
                planWorkflow.analysis.EndpointStructureContract.isRequired( ...
                endpoint);
            requirement(1).source = 'clinicalEndpoint';
            requirement(1).metric = char(endpoint.metric);
            requirement(1).kind = char(endpoint.kind);
        end

        function requirements = emptyRequirement()
            requirements = repmat(struct( ...
                'label','', ...
                'alternatives',{{}}, ...
                'required',true, ...
                'source','', ...
                'metric','', ...
                'kind',''),0,1);
        end

        function tf = isRequired(endpoint)
            tf = true;
            if isstruct(endpoint) && isfield(endpoint,'required') && ...
                    ~isempty(endpoint.required)
                tf = logical(endpoint.required);
            end
        end

        function tf = hasAnyName(availableNames,requestedNames)
            tf = false;
            availableNames = ...
                planWorkflow.analysis.EndpointStructureContract.lowerTextCell( ...
                availableNames);
            requestedNames = ...
                planWorkflow.analysis.EndpointStructureContract.lowerTextCell( ...
                requestedNames);
            for nameIx = 1:numel(requestedNames)
                if any(strcmp(availableNames,requestedNames{nameIx}))
                    tf = true;
                    return;
                end
            end
        end

        function values = textCell(values)
            if isempty(values)
                values = {};
            elseif ischar(values) || isstring(values)
                values = cellstr(values);
            elseif iscell(values)
                values = cellfun(@char,values,'UniformOutput',false);
            else
                values = cellstr(string(values));
            end
            values = reshape(values,1,[]);
        end

        function values = lowerTextCell(values)
            values = ...
                planWorkflow.analysis.EndpointStructureContract.textCell(values);
            values = cellfun(@(value) lower(strtrim(char(value))), ...
                values,'UniformOutput',false);
        end
    end
end
