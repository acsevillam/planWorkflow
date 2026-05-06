classdef DosePullingReportLogger
    % DosePullingReportLogger Formats dose-pulling reports.

    methods (Static)
        function logReference(logFn,report)
            if ~isfield(report,'history') || isempty(report.history)
                logFn('Dose pulling step 1 results: no history available.');
                return;
            end

            finalEntry = report.history(end);
            logFn(sprintf(['Dose pulling step 1 results: converged=%s, ' ...
                'pulls=%d, final %s.'], ...
                planWorkflow.precompute.DosePullingReportLogger.logicalText( ...
                report.converged),report.iterations, ...
                planWorkflow.precompute.DosePullingReportLogger.referenceCriteria( ...
                finalEntry.targetNames,finalEntry.criteria, ...
                finalEntry.values,finalEntry.limits)));
        end

        function logRobust(logFn,report)
            if ~isfield(report,'plans') || isempty(report.plans)
                logFn('Dose pulling step 2 results: no robust plans available.');
                return;
            end

            for planIx = 1:numel(report.plans)
                planReport = report.plans{planIx};
                if ~isfield(planReport,'history') || ...
                        isempty(planReport.history)
                    logFn(sprintf(['Dose pulling step 2 plan %d results: ' ...
                        'no history available.'],planIx));
                    continue;
                end

                finalMetrics = planReport.history(end);
                logFn(sprintf(['Dose pulling step 2 plan %d results: ' ...
                    'converged=%s, pulls=%d, final %s.'],planIx, ...
                    planWorkflow.precompute.DosePullingReportLogger.logicalText( ...
                    planReport.converged),planReport.iterations, ...
                    planWorkflow.precompute.DosePullingReportLogger.robustCriteria( ...
                    finalMetrics)));
            end
        end

        function text = referenceCriteria(targetNames,criteria,values,limits)
            parts = cell(1,numel(values));
            for i = 1:numel(values)
                if values(i) >= limits(i)
                    statusText = 'ok';
                else
                    statusText = 'below limit';
                end

                parts{i} = sprintf('%s(%s)=%.6g, limit=%.6g, gap=%+.6g [%s]', ...
                    criteria{i},targetNames{i},values(i),limits(i), ...
                    values(i) - limits(i),statusText);
            end

            text = strjoin(parts,'; ');
        end

        function text = robustCriteria(metrics)
            parts = cell(1,numel(metrics.selectedValues));
            for i = 1:numel(metrics.selectedValues)
                if metrics.selectedValues(i) >= metrics.limits(i)
                    statusText = 'ok';
                else
                    statusText = 'below limit';
                end

                if strcmp(metrics.selectedCriterion,'meanQiTarget')
                    companionText = sprintf('minQiTarget=%.6g', ...
                        metrics.minQiTarget(i));
                else
                    companionText = sprintf('meanQiTarget=%.6g', ...
                        metrics.meanQiTarget(i));
                end

                parts{i} = sprintf(['%s(%s/%s)=%.6g, %s, limit=%.6g, ' ...
                    'gap=%+.6g [%s]'],metrics.selectedCriterion, ...
                    metrics.targetNames{i},metrics.criteria{i}, ...
                    metrics.selectedValues(i),companionText,metrics.limits(i), ...
                    metrics.selectedValues(i) - metrics.limits(i),statusText);
            end

            text = strjoin(parts,'; ');
        end

        function text = logicalText(value)
            if value
                text = 'true';
            else
                text = 'false';
            end
        end
    end
end
