classdef ConfigValue
    % ConfigValue Shared scalar configuration value normalization.

    methods (Static)
        function value = logicalScalar(value,context,errorId)
            if nargin < 3 || isempty(errorId)
                error(['planWorkflow:config:ConfigValue:' ...
                    'MissingErrorId'], ...
                    'logicalScalar requires an explicit errorId.');
            end
            if nargin < 2 || isempty(context)
                context = 'value';
            end
            context = char(string(context));
            errorId = char(string(errorId));

            if islogical(value) && isscalar(value)
                return;
            end

            if isnumeric(value) && isscalar(value) && isfinite(value) && ...
                    (value == 0 || value == 1)
                value = logical(value);
                return;
            end

            if ischar(value) || (isstring(value) && isscalar(value))
                switch lower(strtrim(char(string(value))))
                    case {'true','1','yes','on'}
                        value = true;
                        return;
                    case {'false','0','no','off'}
                        value = false;
                        return;
                end
            end

            error(errorId,'%s must be scalar logical.',context);
        end
    end
end
