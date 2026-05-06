classdef SamplingEvaluationSpec
    % SamplingEvaluationSpec Validates the transversal sampling geometry.

    methods (Static)
        function validateSamplingCst(cst,planEntry)
            if ~iscell(cst) || size(cst,2) < 3 || isempty(cst)
                planWorkflow.sampling.SamplingEvaluationSpec.throwMismatch( ...
                    planEntry,'cst', ...
                    'sampling cst must be a non-empty cell array with name and role columns');
            end

            seenNames = containers.Map('KeyType','char','ValueType','logical');
            for structureIx = 1:size(cst,1)
                name = planWorkflow.sampling.SamplingEvaluationSpec.structureName( ...
                    cst,structureIx);
                if isempty(name)
                    planWorkflow.sampling.SamplingEvaluationSpec.throwMismatch( ...
                        planEntry,sprintf('row %d',structureIx), ...
                        'missing structure name');
                end

                lookupName = lower(name);
                if isKey(seenNames,lookupName)
                    planWorkflow.sampling.SamplingEvaluationSpec.throwMismatch( ...
                        planEntry,name,'duplicate structure name');
                end
                seenNames(lookupName) = true;

                role = planWorkflow.sampling.SamplingEvaluationSpec.structureRole( ...
                    cst,structureIx);
                if isempty(role)
                    planWorkflow.sampling.SamplingEvaluationSpec.throwMismatch( ...
                        planEntry,name,'missing structure role');
                end
                if ~any(strcmp(role,{'OAR','TARGET'}))
                    planWorkflow.sampling.SamplingEvaluationSpec.throwMismatch( ...
                        planEntry,name, ...
                        sprintf('unsupported structure role "%s"',role));
                end
            end
        end

        function validateStructureRequirements(cst,requirements,planEntry)
            for requirementIx = 1:numel(requirements)
                alternatives = requirements(requirementIx).alternatives;
                if planWorkflow.sampling.SamplingEvaluationSpec.hasAnyStructure( ...
                        cst,alternatives)
                    continue;
                end
                if ~planWorkflow.sampling.SamplingEvaluationSpec.isRequired( ...
                        requirements(requirementIx))
                    continue;
                end

                planWorkflow.sampling.SamplingEvaluationSpec.throwMismatch( ...
                    planEntry, ...
                    strjoin(alternatives,' or '), ...
                    sprintf('missing required %s', ...
                    requirements(requirementIx).label));
            end
        end

        function tf = isRequired(requirement)
            tf = true;
            if isstruct(requirement) && isfield(requirement,'required') && ...
                    ~isempty(requirement.required)
                tf = logical(requirement.required);
            end
        end

        function tf = hasAnyStructure(cst,structureNames)
            tf = false;
            if ischar(structureNames) || isstring(structureNames)
                structureNames = cellstr(structureNames);
            end
            for nameIx = 1:numel(structureNames)
                if planWorkflow.sampling.SamplingEvaluationSpec.findStructure( ...
                        cst,structureNames{nameIx}) > 0
                    tf = true;
                    return;
                end
            end
        end

        function ix = findStructure(cst,structureName)
            ix = 0;
            if ~iscell(cst) || size(cst,2) < 2
                return;
            end
            for structureIx = 1:size(cst,1)
                if ~isempty(cst{structureIx,2}) && ...
                        strcmpi(char(cst{structureIx,2}), ...
                        char(structureName))
                    ix = structureIx;
                    return;
                end
            end
        end
    end

    methods (Static, Access = private)
        function name = structureName(cst,rowIx)
            name = '';
            if size(cst,2) >= 2 && ~isempty(cst{rowIx,2})
                name = strtrim(char(cst{rowIx,2}));
            end
        end

        function role = structureRole(cst,rowIx)
            role = '';
            if size(cst,2) >= 3 && ~isempty(cst{rowIx,3})
                role = upper(strtrim(char(cst{rowIx,3})));
            end
        end

        function throwMismatch(planEntry,structureName,reason)
            error(['planWorkflow:sampling:SamplingService:' ...
                'SamplingStructureMismatch'], ...
                ['Sampling structures do not match plan "%s" ' ...
                 '(planId "%s", variantId "%s"): %s "%s". ' ...
                 'Sampling is a transversal comparison and every ' ...
                 'sampled plan must share the configured evaluation ' ...
                 'structures.'], ...
                char(planEntry.label),char(planEntry.planId), ...
                char(planEntry.variantId),char(reason), ...
                char(structureName));
        end
    end
end
