classdef MacroFileResolver
    % MacroFileResolver Finds and inspects planWorkflow macro files.

    methods (Static)
        function folder = defaultMacroFolder()
            candidates = {};
            if exist('MatRad_Config','class') == 8
                try
                    cfg = MatRad_Config.instance();
                    candidates{end + 1} = ...
                        fullfile(cfg.primaryUserFolder,'macros');
                catch
                end
            end

            classFile = which('planWorkflow.macros.MacroFileResolver');
            planWorkflowRoot = fileparts(fileparts(fileparts(classFile)));
            candidates{end + 1} = ...
                fullfile(fileparts(fileparts(planWorkflowRoot)), ...
                'userdata','macros');
            candidates{end + 1} = fullfile(pwd,'userdata','macros');
            candidates{end + 1} = pwd;

            folder = candidates{end};
            for i = 1:numel(candidates)
                if isfolder(candidates{i})
                    folder = ...
                        planWorkflow.macros.MacroFileResolver.absolutePath( ...
                        candidates{i});
                    return;
                end
            end
        end

        function entries = discover(paths)
            paths = planWorkflow.macros.MacroFileResolver.asCellstr(paths);
            files = {};
            for i = 1:numel(paths)
                currentPath = char(paths{i});
                if isempty(currentPath)
                    continue;
                end
                if isfile(currentPath)
                    [~,~,ext] = fileparts(currentPath);
                    if strcmpi(ext,'.m')
                        files{end + 1} = ...
                            planWorkflow.macros.MacroFileResolver.absolutePath( ...
                            currentPath); %#ok<AGROW>
                    end
                    continue;
                end
                if ~isfolder(currentPath)
                    error('planWorkflow:macros:MacroFileResolver:MissingPath', ...
                        'Macro path does not exist: %s',currentPath);
                end
                files = [files ...
                    planWorkflow.macros.MacroFileResolver.discoverFolder( ...
                    currentPath)]; %#ok<AGROW>
            end
            files = planWorkflow.macros.MacroFileResolver.uniquePaths(files);
            entries = planWorkflow.macros.MacroFileResolver.entriesFromFiles( ...
                files);
        end

        function rows = tableRows(entries,baseFolder)
            if nargin < 2
                baseFolder = '';
            end
            rows = cell(numel(entries),3);
            for i = 1:numel(entries)
                rows(i,:) = {sprintf('%d',i),entries(i).functionName, ...
                    planWorkflow.macros.MacroFileResolver.relativeFolder( ...
                    entries(i).folder,baseFolder)};
            end
        end

        function entries = filterEntries(entries,query)
            query = lower(strtrim(char(string(query))));
            if isempty(query) || isempty(entries)
                return;
            end
            terms = regexp(query,'\s+','split');
            keep = false(1,numel(entries));
            for i = 1:numel(entries)
                entryText = lower(strjoin({entries(i).functionName, ...
                    entries(i).folder,entries(i).filePath},' '));
                termMatches = cellfun(@(term) contains(entryText,term), ...
                    terms);
                keep(i) = all(termMatches);
            end
            entries = entries(keep);
        end

        function metadata = inspect(filePath)
            filePath = planWorkflow.macros.MacroFileResolver.absolutePath( ...
                filePath);
            if ~isfile(filePath)
                error('planWorkflow:macros:MacroFileResolver:MissingFile', ...
                    'Macro file does not exist: %s',filePath);
            end
            [folder,fileName,ext] = fileparts(filePath);
            if ~strcmpi(ext,'.m')
                error('planWorkflow:macros:MacroFileResolver:InvalidFile', ...
                    'Macro file must be a MATLAB .m file: %s',filePath);
            end

            text = fileread(filePath);
            functionName = ...
                planWorkflow.macros.MacroFileResolver.functionNameFromText( ...
                text);
            defaults = ...
                planWorkflow.macros.MacroFileResolver.defaultsFromText(text);
            isSupportFile = ...
                planWorkflow.macros.MacroFileResolver.isSupportFile(filePath);
            isBuilderUtility = strcmp(functionName,'openWorkflowMacroBuilder');
            usesMacroSpecRunner = contains(text,'runWorkflowMacroSpec');
            usesMacroJobRunner = contains(text,'runWorkflowMacroJob');
            isWorkflowMacro = ~isSupportFile && ~isBuilderUtility && ...
                (usesMacroSpecRunner || usesMacroJobRunner || ...
                contains(text,'planWorkflow.Workflow') || ...
                endsWith(functionName,'Workflow') || ...
                endsWith(functionName,'Job'));
            supportedOptions = struct( ...
                'caseID',true, ...
                'profile',usesMacroSpecRunner || usesMacroJobRunner, ...
                'rootPath',true, ...
                'cacheRootPath',true, ...
                'openGui',usesMacroSpecRunner && contains(text,'openGui'));

            metadata = struct();
            metadata.filePath = filePath;
            metadata.folder = folder;
            metadata.fileName = [fileName ext];
            metadata.expectedFunctionName = fileName;
            metadata.functionName = functionName;
            metadata.hasFunction = ~isempty(functionName);
            metadata.validFunctionName = ~isempty(functionName) && ...
                isvarname(functionName);
            metadata.nameMatchesFile = strcmp(functionName,fileName);
            metadata.isWorkflowMacro = isWorkflowMacro;
            metadata.isSupportFile = isSupportFile;
            metadata.isBuilderUtility = isBuilderUtility;
            metadata.defaults = defaults;
            metadata.supportedOptions = supportedOptions;
        end

        function metadata = validate(filePath)
            metadata = planWorkflow.macros.MacroFileResolver.inspect(filePath);
            if ~metadata.hasFunction
                error('planWorkflow:macros:MacroFileResolver:MissingFunction', ...
                    'Macro file does not define a top-level function: %s', ...
                    metadata.filePath);
            end
            if ~metadata.validFunctionName
                error('planWorkflow:macros:MacroFileResolver:InvalidFunction', ...
                    'Invalid macro function name "%s".',metadata.functionName);
            end
            if ~metadata.nameMatchesFile
                error('planWorkflow:macros:MacroFileResolver:NameMismatch', ...
                    ['Macro function "%s" must match file name "%s" ', ...
                    'for safe feval execution.'], ...
                    metadata.functionName,metadata.expectedFunctionName);
            end
            if ~metadata.isWorkflowMacro
                error('planWorkflow:macros:MacroFileResolver:NotWorkflowMacro', ...
                    'File does not look like a planWorkflow macro: %s', ...
                    metadata.filePath);
            end
        end

        function rows = summaryRows(metadata)
            defaults = metadata.defaults;
            rows = { ...
                'File',metadata.fileName; ...
                'Folder',metadata.folder; ...
                'Function',metadata.functionName; ...
                'Case ID',defaults.caseID; ...
                'Root path default',defaults.rootPath; ...
                'Cache path default',defaults.cacheRootPath; ...
                'Open GUI default', ...
                planWorkflow.macros.MacroFileResolver.valueText( ...
                defaults.openGui); ...
                'Profile',defaults.profile; ...
                'Site',defaults.site; ...
                'Radiation mode',defaults.particleType; ...
                'Robustness',defaults.robustness; ...
                'Sampling profile',defaults.samplingProfile; ...
                'Supports profile option', ...
                planWorkflow.macros.MacroFileResolver.valueText( ...
                metadata.supportedOptions.profile); ...
                'Supports openGui option', ...
                planWorkflow.macros.MacroFileResolver.valueText( ...
                metadata.supportedOptions.openGui)};
        end

        function args = executionArguments(metadata,options)
            if nargin < 2 || isempty(options)
                options = struct();
            end
            textFields = {'caseID','rootPath','cacheRootPath'};
            args = cell(1,2 * numel(textFields) + 4);
            argCount = 0;
            for i = 1:numel(textFields)
                field = textFields{i};
                if isfield(options,field) && ...
                        ~isempty(strtrim(char(options.(field))))
                    args(argCount + 1:argCount + 2) = ...
                        {field,char(options.(field))};
                    argCount = argCount + 2;
                end
            end
            if isfield(options,'profile') && ...
                    metadata.supportedOptions.profile && ...
                    ~isempty(strtrim(char(options.profile)))
                args(argCount + 1:argCount + 2) = ...
                    {'profile',char(options.profile)};
                argCount = argCount + 2;
            end
            if isfield(options,'openGui') && ...
                    metadata.supportedOptions.openGui
                args(argCount + 1:argCount + 2) = ...
                    {'openGui',logical(options.openGui)};
                argCount = argCount + 2;
            end
            args = args(1:argCount);
        end
    end

    methods (Static, Access = private)
        function entries = entriesFromFiles(files)
            emptyEntry = struct('functionName','','folder','', ...
                'filePath','');
            entries = emptyEntry([]);
            if isempty(files)
                return;
            end
            [~,order] = sort(lower(files));
            files = files(order);
            entries = repmat(emptyEntry,1,numel(files));
            entryCount = 0;
            for i = 1:numel(files)
                metadata = planWorkflow.macros.MacroFileResolver.inspect( ...
                    files{i});
                if ~metadata.isWorkflowMacro
                    continue;
                end
                functionName = metadata.functionName;
                if isempty(functionName)
                    [~,functionName] = fileparts(files{i});
                end
                entryCount = entryCount + 1;
                entries(entryCount) = struct('functionName',functionName, ...
                    'folder',metadata.folder,'filePath',metadata.filePath);
            end
            entries = entries(1:entryCount);
        end

        function files = discoverFolder(folder)
            folder = ...
                planWorkflow.macros.MacroFileResolver.absolutePath(folder);
            entries = dir(fullfile(folder,'**','*.m'));
            files = cell(1,numel(entries));
            fileCount = 0;
            for i = 1:numel(entries)
                filePath = ...
                    planWorkflow.macros.MacroFileResolver.absolutePath( ...
                    fullfile(entries(i).folder,entries(i).name));
                isSupportFile = ...
                    planWorkflow.macros.MacroFileResolver.isSupportFile( ...
                    filePath);
                isExcludedFile = planWorkflow.macros.MacroFileResolver.isAutoDiscoveryExcludedFile(filePath);
                if isSupportFile || isExcludedFile
                    continue;
                end
                fileCount = fileCount + 1;
                files{fileCount} = filePath;
            end
            files = files(1:fileCount);
        end

        function defaults = defaultsFromText(text)
            fields = {'caseID','rootPath','cacheRootPath','openGui', ...
                'profile','site','particleType','robustness', ...
                'samplingProfile'};
            defaults = struct();
            for i = 1:numel(fields)
                defaults.(fields{i}) = '';
            end
            defaults.openGui = [];

            lines = regexp(text,'\r\n|\n|\r','split');
            for i = 1:numel(lines)
                line = strtrim(lines{i});
                tokens = regexp(line, ...
                    ['^(?:macroDefaults\.)?(' strjoin(fields,'|') ...
                    ')\s*=\s*(.*?);\s*(?:%.*)?$'], ...
                    'tokens','once');
                if isempty(tokens)
                    continue;
                end
                fieldName = tokens{1};
                defaults.(fieldName) = ...
                    planWorkflow.macros.MacroFileResolver.parseValue( ...
                    strtrim(tokens{2}));
            end
        end

        function value = parseValue(expression)
            value = char(expression);
            stringToken = regexp(value,'^''((?:''''|[^''])*)''$', ...
                'tokens','once');
            if ~isempty(stringToken)
                value = strrep(stringToken{1},'''''''','''');
                return;
            end
            switch lower(value)
                case 'true'
                    value = true;
                case 'false'
                    value = false;
            end
        end

        function functionName = functionNameFromText(text)
            tokens = regexp(text, ...
                ['(?m)^\s*function\s+(?:(?:\[[^\]]*\]|\w+)\s*=\s*)?' ...
                '([A-Za-z]\w*)\s*(?:\(|$)'], ...
                'tokens','once');
            functionName = '';
            if ~isempty(tokens)
                functionName = tokens{1};
            end
        end

        function text = valueText(value)
            if islogical(value)
                if value
                    text = 'true';
                else
                    text = 'false';
                end
            elseif isempty(value)
                text = '';
            else
                text = char(string(value));
            end
        end

        function tf = isSupportFile(filePath)
            parts = planWorkflow.macros.MacroFileResolver.pathParts(filePath);
            tf = any(strcmp(parts,'helpers')) || any(strcmp(parts,'shared'));
        end

        function tf = isAutoDiscoveryExcludedFile(filePath)
            parts = planWorkflow.macros.MacroFileResolver.pathParts(filePath);
            tf = any(strcmp(parts,'jobs'));
        end

        function parts = pathParts(filePath)
            normalized = strrep(char(filePath),'\','/');
            parts = regexp(normalized,'/','split');
            parts = parts(~cellfun('isempty',parts));
        end

        function paths = asCellstr(paths)
            if nargin < 1 || isempty(paths)
                paths = {};
            elseif ischar(paths)
                paths = {paths};
            elseif isstring(paths)
                paths = cellstr(paths);
            end
        end

        function paths = uniquePaths(paths)
            result = {};
            seen = containers.Map('KeyType','char','ValueType','logical');
            for i = 1:numel(paths)
                path = char(paths{i});
                key = path;
                if ispc
                    key = lower(key);
                end
                if ~isKey(seen,key)
                    seen(key) = true;
                    result{end + 1} = path; %#ok<AGROW>
                end
            end
            paths = result;
        end

        function folder = relativeFolder(folder,baseFolder)
            folder = char(folder);
            baseFolder = char(string(baseFolder));
            if isempty(baseFolder) || ~isfolder(baseFolder)
                return;
            end

            folderAbs = planWorkflow.macros.MacroFileResolver.absolutePath( ...
                folder);
            baseAbs = planWorkflow.macros.MacroFileResolver.absolutePath( ...
                baseFolder);
            folderNorm = ...
                planWorkflow.macros.MacroFileResolver.normalizedPath( ...
                folderAbs);
            baseNorm = planWorkflow.macros.MacroFileResolver.normalizedPath( ...
                baseAbs);
            folderKey = folderNorm;
            baseKey = baseNorm;
            if ispc
                folderKey = lower(folderKey);
                baseKey = lower(baseKey);
            end

            if strcmp(folderKey,baseKey)
                folder = '.';
                return;
            end
            basePrefix = [baseKey '/'];
            if startsWith(folderKey,basePrefix)
                folder = strrep(folderNorm(numel(baseNorm) + 2:end), ...
                    '/',filesep);
            end
        end

        function path = normalizedPath(path)
            path = strrep(char(path),'\','/');
            while numel(path) > 1 && endsWith(path,'/')
                path = path(1:end - 1);
            end
        end

        function path = absolutePath(path)
            path = char(path);
            try
                fileObj = java.io.File(path);
                path = char(fileObj.getCanonicalPath());
            catch
                if isfolder(path)
                    currentFolder = pwd;
                    cleanupObj = onCleanup(@() cd(currentFolder));
                    cd(path);
                    path = pwd;
                    clear cleanupObj;
                else
                    [folder,name,ext] = fileparts(path);
                    folder = ...
                        planWorkflow.macros.MacroFileResolver.absolutePath( ...
                        folder);
                    path = fullfile(folder,[name ext]);
                end
            end
        end
    end
end
