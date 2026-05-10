classdef ValueFormat
    % ValueFormat Shared text formatting for workflow GUI models.

    methods (Static)
        function text = text(value)
            if isempty(value)
                text = '-';
            elseif ischar(value)
                text = value;
            elseif isstring(value) && isscalar(value)
                text = char(value);
            elseif isnumeric(value) || islogical(value)
                text = mat2str(value);
            else
                text = char(string(value));
            end
        end

        function text = attempts(value)
            if isnumeric(value) && isscalar(value) && isfinite(value)
                text = sprintf('%d',round(double(value)));
            else
                text = planWorkflow.gui.ValueFormat.text(value);
            end
        end

        function text = seconds(value)
            if isnumeric(value) && isscalar(value) && isfinite(value)
                text = sprintf('%.3f',double(value));
            else
                text = '-';
            end
        end

        function text = ratio(value)
            if isnumeric(value) && isscalar(value) && isfinite(value)
                text = sprintf('%.3f',double(value));
            else
                text = '-';
            end
        end

        function text = megabytes(value)
            if isnumeric(value) && isscalar(value) && isfinite(value)
                text = sprintf('%.2f',double(value) / 1024^2);
            else
                text = '-';
            end
        end
    end
end
