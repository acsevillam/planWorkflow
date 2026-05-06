classdef NormalizationReportLogger
    % NormalizationReportLogger Emits structured VOI normalization reports.

    methods (Static)
        function log(logFn,title,report)
            if nargin < 1 || isempty(logFn) || nargin < 3 || ...
                    ~planWorkflow.structures.NormalizationReportLogger.hasEntries( ...
                    report)
                return;
            end
            planWorkflow.structures.NormalizationReportLogger.emit( ...
                logFn,sprintf('%s:',char(title)));

            if isfield(report,'renamed')
                for i = 1:numel(report.renamed)
                    entry = report.renamed(i);
                    planWorkflow.structures.NormalizationReportLogger.emit( ...
                        logFn,sprintf('  renamed "%s" -> "%s"', ...
                        char(entry.originalName), ...
                        char(entry.normalizedName)));
                end
            end

            if isfield(report,'dropped')
                for i = 1:numel(report.dropped)
                    entry = report.dropped(i);
                    planWorkflow.structures.NormalizationReportLogger.emit( ...
                        logFn,sprintf('  dropped "%s": %s', ...
                        char(entry.name),char(entry.reason)));
                end
            end
        end

        function tf = hasEntries(report)
            tf = isstruct(report) && ...
                ((isfield(report,'renamed') && ~isempty(report.renamed)) || ...
                 (isfield(report,'dropped') && ~isempty(report.dropped)));
        end

        function emit(logFn,message)
            logFn(char(message));
        end
    end
end
