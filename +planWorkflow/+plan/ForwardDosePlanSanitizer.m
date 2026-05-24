classdef ForwardDosePlanSanitizer
    % ForwardDosePlanSanitizer Removes optimization-only plan payloads.

    methods (Static)
        function pln = sanitize(pln)
            if ~isstruct(pln) || ~isfield(pln,'propOpt') || ...
                    ~isstruct(pln.propOpt)
                return;
            end

            optimizationOnlyFields = {'scen4D','dij_interval','dij_prob'};
            for fieldIx = 1:numel(optimizationOnlyFields)
                fieldName = optimizationOnlyFields{fieldIx};
                if isfield(pln.propOpt,fieldName)
                    pln.propOpt = rmfield(pln.propOpt,fieldName);
                end
            end
        end
    end
end
