classdef OptimizerOptions
    % OptimizerOptions Normalizes the planWorkflow-to-matRad option contract.

    methods (Static)
        function options = normalize(options)
            if nargin < 1 || isempty(options)
                options = struct();
                return;
            end
            if ~isstruct(options) || ~isscalar(options)
                error(['planWorkflow:config:OptimizerOptions:' ...
                    'InvalidOptimizerOptions'], ...
                    'runConfig.optimizerOptions must be a scalar struct.');
            end
        end
    end
end
