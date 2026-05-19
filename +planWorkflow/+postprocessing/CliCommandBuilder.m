classdef CliCommandBuilder
    % CliCommandBuilder Builds safe CLI calls for Python postprocessing.

    methods (Static)
        function config = defaultConfig()
            config = struct();
            config.pythonExecutable = ...
                planWorkflow.postprocessing.CliCommandBuilder.defaultPythonExecutable();
            config.pythonPath = ...
                planWorkflow.postprocessing.CliCommandBuilder.defaultPythonPath();
            config.matFiles = {};
            config.outputDir = ...
                planWorkflow.postprocessing.CliCommandBuilder.defaultOutputDir();
            config.endpointEnabled = true;
            config.timeEnabled = true;
            config.dijEnabled = true;
            config.endpointStat = 'por';
            config.endpointFilter = 'all';
            config.timeMode = 'all';
            config.timeValue = 'relative';
            config.sizeValue = 'relative';
            config.filters = ...
                planWorkflow.postprocessing.CliCommandBuilder.emptyFilters();
        end

        function outputDir = defaultOutputDir()
            timestamp = char(datetime('now','Format','yyyyMMdd_HHmmss'));
            outputDir = fullfile(tempdir,'planworkflow_postprocessing_gui', ...
                timestamp);
        end

        function pythonPath = pythonPackagePath()
            planWorkflowRoot = ...
                planWorkflow.postprocessing.CliCommandBuilder.planWorkflowRoot();
            pythonPath = fullfile(planWorkflowRoot,'postprocessing');
        end

        function pythonExecutable = defaultPythonExecutable()
            planWorkflowRoot = ...
                planWorkflow.postprocessing.CliCommandBuilder.planWorkflowRoot();
            if ispc
                pythonExecutable = fullfile(planWorkflowRoot,'.venv', ...
                    'Scripts','python.exe');
            else
                pythonExecutable = fullfile(planWorkflowRoot,'.venv','bin','python');
            end
        end

        function pythonPath = defaultPythonPath()
            pythonPath = ...
                planWorkflow.postprocessing.CliCommandBuilder.pythonPackagePath();
        end

        function commands = buildCommands(config)
            config = planWorkflow.postprocessing.CliCommandBuilder.normalizeConfig(config);
            commands = {};
            if config.endpointEnabled
                commands{end + 1} = ...
                    planWorkflow.postprocessing.CliCommandBuilder.buildCommand( ...
                    config,{'--figure','endpoint','--stat', ...
                    config.endpointStat,'--filter',config.endpointFilter});
            end
            if config.timeEnabled
                commands{end + 1} = ...
                    planWorkflow.postprocessing.CliCommandBuilder.buildCommand( ...
                    config,{'--figure','time','--time-mode', ...
                    config.timeMode,'--time-value',config.timeValue});
            end
            if config.dijEnabled
                commands{end + 1} = ...
                    planWorkflow.postprocessing.CliCommandBuilder.buildCommand( ...
                    config,{'--figure','dij','--size-value', ...
                    config.sizeValue});
            end
            if isempty(commands)
                error('planWorkflow:postprocessing:CliCommandBuilder:NoFigures', ...
                    'Select at least one postprocessing figure.');
            end
        end

        function filters = filtersFromTableRows(rows)
            filters = planWorkflow.postprocessing.CliCommandBuilder.emptyFilters();
            if isempty(rows)
                return;
            end
            for i = 1:size(rows,1)
                mode = planWorkflow.postprocessing.CliCommandBuilder.cellText(rows,i,1);
                field = planWorkflow.postprocessing.CliCommandBuilder.cellText(rows,i,2);
                values = planWorkflow.postprocessing.CliCommandBuilder.cellText(rows,i,3);
                if isempty(strtrim(field)) && isempty(strtrim(values))
                    continue;
                end
                if isempty(strtrim(field)) || isempty(strtrim(values))
                    error('planWorkflow:postprocessing:CliCommandBuilder:InvalidFilter', ...
                        'Filter rows require both field and values.');
                end
                mode = lower(strtrim(mode));
                if isempty(mode)
                    mode = 'include';
                end
                planWorkflow.postprocessing.CliCommandBuilder.validateChoice( ...
                    mode,{'include','exclude'},'filter mode');
                filters(end + 1) = struct('mode',mode, ...
                    'field',strtrim(field),'values',strtrim(values)); %#ok<AGROW>
            end
        end

        function quoted = shellQuote(value)
            value = char(value);
            if ispc
                quoted = ['"' strrep(value,'"','\"') '"'];
                return;
            end
            singleQuote = char(39);
            escaped = strrep(value,singleQuote, ...
                [singleQuote '"' singleQuote '"' singleQuote]);
            quoted = [singleQuote escaped singleQuote];
        end
    end

    methods (Static, Access = private)
        function config = normalizeConfig(config)
            defaults = planWorkflow.postprocessing.CliCommandBuilder.defaultConfig();
            config = planWorkflow.postprocessing.CliCommandBuilder.mergeDefaults( ...
                config,defaults);
            config.matFiles = ...
                planWorkflow.postprocessing.CliCommandBuilder.asCellstr(config.matFiles);
            config.matFiles = config.matFiles(:)';
            if isempty(config.matFiles)
                error('planWorkflow:postprocessing:CliCommandBuilder:NoInputs', ...
                    'Select at least one workflow_results.mat file.');
            end
            for i = 1:numel(config.matFiles)
                if ~isfile(config.matFiles{i})
                    error('planWorkflow:postprocessing:CliCommandBuilder:MissingInput', ...
                        'Missing workflow_results.mat file: %s',config.matFiles{i});
                end
            end
            if isempty(strtrim(char(config.outputDir)))
                error('planWorkflow:postprocessing:CliCommandBuilder:MissingOutputDir', ...
                    'Select an output directory.');
            end
            config.pythonExecutable = char(config.pythonExecutable);
            config.pythonPath = char(config.pythonPath);
            config.outputDir = char(config.outputDir);
            planWorkflow.postprocessing.CliCommandBuilder.validatePythonExecutable( ...
                config.pythonExecutable);
            config.endpointStat = lower(char(config.endpointStat));
            config.endpointFilter = lower(char(config.endpointFilter));
            config.timeMode = lower(char(config.timeMode));
            config.timeValue = lower(char(config.timeValue));
            config.sizeValue = lower(char(config.sizeValue));
            config.endpointEnabled = logical(config.endpointEnabled);
            config.timeEnabled = logical(config.timeEnabled);
            config.dijEnabled = logical(config.dijEnabled);
            planWorkflow.postprocessing.CliCommandBuilder.validateChoice( ...
                config.endpointStat,{'por','mean','max','all'},'endpoint stat');
            planWorkflow.postprocessing.CliCommandBuilder.validateChoice( ...
                config.endpointFilter,{'all','dominant','both'},'endpoint filter');
            planWorkflow.postprocessing.CliCommandBuilder.validateChoice( ...
                config.timeMode,{'precompute_dij_time','optimization_rtpi','all','both'}, ...
                'time mode');
            planWorkflow.postprocessing.CliCommandBuilder.validateChoice( ...
                config.timeValue,{'absolute','relative','both'},'time value');
            planWorkflow.postprocessing.CliCommandBuilder.validateChoice( ...
                config.sizeValue,{'absolute','relative','both'},'size value');
            if ~isfield(config,'filters') || isempty(config.filters)
                config.filters = ...
                    planWorkflow.postprocessing.CliCommandBuilder.emptyFilters();
            end
        end

        function command = buildCommand(config,figureArgs)
            commonArgs = [{'--mat'} config.matFiles ...
                {'--out-dir',config.outputDir}];
            filterArgs = ...
                planWorkflow.postprocessing.CliCommandBuilder.filterArguments(config.filters);
            args = [{'-m','planworkflow_postprocessing'} ...
                commonArgs figureArgs filterArgs];
            executable = {config.pythonExecutable};
            parts = [executable args];
            quotedParts = cell(size(parts));
            for i = 1:numel(parts)
                quotedParts{i} = ...
                    planWorkflow.postprocessing.CliCommandBuilder.shellQuote(parts{i});
            end
            command = [ ...
                planWorkflow.postprocessing.CliCommandBuilder.environmentPrefix(config.pythonPath) ...
                strjoin(quotedParts,' ')];
        end

        function args = filterArguments(filters)
            args = {};
            for i = 1:numel(filters)
                mode = lower(char(filters(i).mode));
                switch mode
                    case 'include'
                        flag = '--where';
                    case 'exclude'
                        flag = '--exclude';
                    otherwise
                        error('planWorkflow:postprocessing:CliCommandBuilder:InvalidFilterMode', ...
                            'Unsupported filter mode: %s',mode);
                end
                args = [args {flag, ...
                    sprintf('%s=%s',char(filters(i).field), ...
                    char(filters(i).values))}]; %#ok<AGROW>
            end
        end

        function prefix = environmentPrefix(pythonPath)
            pythonPath = char(pythonPath);
            if isempty(pythonPath)
                prefix = '';
                return;
            end
            if ispc
                prefix = ['set "PYTHONPATH=' strrep(pythonPath,'"','\"') '" && '];
            else
                prefix = ['PYTHONPATH=' ...
                    planWorkflow.postprocessing.CliCommandBuilder.shellQuote(pythonPath) ...
                    ' '];
            end
        end

        function config = mergeDefaults(config,defaults)
            if nargin < 1 || isempty(config)
                config = struct();
            end
            fields = fieldnames(defaults);
            for i = 1:numel(fields)
                field = fields{i};
                if ~isfield(config,field) || isempty(config.(field))
                    config.(field) = defaults.(field);
                end
            end
        end

        function values = asCellstr(values)
            if isempty(values)
                values = {};
            elseif ischar(values)
                values = {values};
            elseif isstring(values)
                values = cellstr(values);
            end
        end

        function filters = emptyFilters()
            filters = struct('mode',{},'field',{},'values',{});
        end

        function validateChoice(value,choices,label)
            if ~any(strcmp(value,choices))
                error('planWorkflow:postprocessing:CliCommandBuilder:InvalidChoice', ...
                    'Unsupported %s: %s',label,value);
            end
        end

        function validatePythonExecutable(pythonExecutable)
            pythonExecutable = char(pythonExecutable);
            if isempty(strtrim(pythonExecutable)) || ~isfile(pythonExecutable)
                error(['planWorkflow:postprocessing:CliCommandBuilder:' ...
                    'MissingPythonExecutable'], ...
                    ['Python executable does not exist: %s. Select a valid ' ...
                    'Python executable or create the repository-local .venv ' ...
                    'for planWorkflow postprocessing.'],pythonExecutable);
            end
        end

        function value = cellText(rows,row,column)
            value = '';
            if row <= size(rows,1) && column <= size(rows,2) && ...
                    ~isempty(rows{row,column})
                value = char(rows{row,column});
            end
        end

        function planWorkflowRoot = planWorkflowRoot()
            classFile = which('planWorkflow.postprocessing.CliCommandBuilder');
            planWorkflowRoot = fileparts(fileparts(fileparts(classFile)));
        end
    end
end
