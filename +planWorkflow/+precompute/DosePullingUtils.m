classdef DosePullingUtils
    % DosePullingUtils Shared validation and lookup helpers for dose pulling.

    methods (Static)
        function values = expandNumericToCount(values,count,fieldName)
            values = values(:)';
            if isscalar(values)
                values = repmat(values,1,count);
            end
            if numel(values) ~= count
                error('planWorkflow:precompute:DosePulling:InvalidConfigLength', ...
                    '%s must be scalar or contain %d values.',fieldName,count);
            end
        end

        function values = expandCellToCount(values,count,fieldName)
            values = planWorkflow.precompute.DosePullingUtils.asCellstr(values);
            if isscalar(values) && count > 1
                values = repmat(values,1,count);
            end
            if numel(values) ~= count
                error('planWorkflow:precompute:DosePulling:InvalidConfigLength', ...
                    '%s must be scalar or contain %d values.',fieldName,count);
            end
        end

        function values = asCellstr(values)
            if isstring(values)
                values = cellstr(values);
            elseif ischar(values)
                values = {values};
            end
        end

        function targetIx = findQiTargets(qi,targetNames)
            targetNames = ...
                planWorkflow.precompute.DosePullingUtils.asCellstr( ...
                targetNames);
            targetIx = zeros(1,numel(targetNames));

            for targetIt = 1:numel(targetNames)
                for qiIt = 1:numel(qi)
                    if strcmp(qi(qiIt).name,targetNames{targetIt})
                        targetIx(targetIt) = qiIt;
                        break;
                    end
                end

                if targetIx(targetIt) == 0
                    error('planWorkflow:precompute:DosePulling:MissingTarget', ...
                        ['Dose pulling target "%s" was not found in ' ...
                         'quality indicators.'],targetNames{targetIt});
                end
            end
        end
    end
end
