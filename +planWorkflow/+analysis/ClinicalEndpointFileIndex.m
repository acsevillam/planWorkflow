classdef ClinicalEndpointFileIndex
    % ClinicalEndpointFileIndex Cached endpoint-file discovery.

    methods (Static)
        function files = files(folder)
            if nargin < 1 || isempty(folder)
                folder = planWorkflow.analysis.ClinicalEndpointCatalog.folder();
            end
            folder = char(folder);

            persistent cachedFolder cachedSignature cachedFiles
            endpointFiles = dir(fullfile(folder,'*.json'));
            signature = ...
                planWorkflow.analysis.ClinicalEndpointFileIndex.fileListSignature( ...
                endpointFiles);
            if ischar(cachedFolder) && strcmp(folder,cachedFolder) && ...
                    ~isempty(cachedFiles) && ...
                    isequal(signature,cachedSignature)
                files = cachedFiles;
                return;
            end

            files = repmat( ...
                planWorkflow.analysis.ClinicalEndpointFileIndex.fileTemplate(), ...
                1,0);
            for fileIx = 1:numel(endpointFiles)
                filePath = fullfile(endpointFiles(fileIx).folder, ...
                    endpointFiles(fileIx).name);
                [metadataDoseQuantities,metadataError] = ...
                    planWorkflow.analysis.ClinicalEndpointFileIndex.scanMetadata( ...
                    filePath);
                [contractDoseQuantities,contractError] = ...
                    planWorkflow.analysis.ClinicalEndpointFileIndex.scanContract( ...
                    filePath);
                doseQuantities = metadataDoseQuantities;
                if isempty(contractError)
                    doseQuantities = contractDoseQuantities;
                end
                files(end + 1) = struct( ...
                    'name',endpointFiles(fileIx).name, ...
                    'path',filePath, ...
                    'doseQuantities',{doseQuantities}, ...
                    'metadataValid',isempty(metadataError), ...
                    'metadataErrorMessage',metadataError, ...
                    'contractValid',isempty(contractError), ...
                    'contractErrorMessage',contractError, ...
                    'isValid',isempty(metadataError) && ...
                    isempty(contractError), ...
                    'errorMessage', ...
                    planWorkflow.analysis.ClinicalEndpointFileIndex.combinedErrorMessage( ...
                    metadataError,contractError)); %#ok<AGROW>
            end

            cachedFolder = folder;
            cachedSignature = signature;
            cachedFiles = files;
        end

        function files = filesForDoseQuantity(doseQuantity,folder)
            if nargin < 2
                folder = [];
            end
            if nargin < 1
                doseQuantity = '';
            end
            indexedFiles = ...
                planWorkflow.analysis.ClinicalEndpointFileIndex.files(folder);
            files = repmat( ...
                planWorkflow.analysis.ClinicalEndpointFileIndex.fileTemplate(), ...
                1,0);
            for fileIx = 1:numel(indexedFiles)
                if ~indexedFiles(fileIx).contractValid
                    continue;
                end
                fileDoseQuantities = indexedFiles(fileIx).doseQuantities;
                if ~isempty(doseQuantity) && ~any(strcmp( ...
                        fileDoseQuantities,char(doseQuantity)))
                    continue;
                end
                files(end + 1) = indexedFiles(fileIx); %#ok<AGROW>
            end
        end

        function files = invalidFiles(folder)
            if nargin < 1
                folder = [];
            end
            indexedFiles = ...
                planWorkflow.analysis.ClinicalEndpointFileIndex.files(folder);
            files = indexedFiles(~[indexedFiles.isValid]);
        end

        function doseQuantities = fileDoseQuantities(filePath)
            filePath = ...
                planWorkflow.analysis.ClinicalEndpointCatalog.resolveFile( ...
                filePath);
            if isempty(filePath) || ~isfile(filePath)
                doseQuantities = {};
                return;
            end

            endpointFiles = ...
                planWorkflow.analysis.ClinicalEndpointFileIndex.files( ...
                fileparts(filePath));
            matchIx = find(strcmp({endpointFiles.path},char(filePath)),1);
            if ~isempty(matchIx)
                if ~endpointFiles(matchIx).metadataValid
                    error(['planWorkflow:analysis:ClinicalEndpointFileIndex:' ...
                        'InvalidEndpointFile'], ...
                        'Clinical endpoint file "%s" is invalid: %s', ...
                        endpointFiles(matchIx).name, ...
                        endpointFiles(matchIx).metadataErrorMessage);
                end
                doseQuantities = endpointFiles(matchIx).doseQuantities;
                return;
            end

            doseQuantities = ...
                planWorkflow.analysis.ClinicalEndpointFileIndex.fileDoseQuantitiesFromFile( ...
                filePath);
        end
    end

    methods (Static, Access = private)
        function template = fileTemplate()
            template = struct('name','','path','','doseQuantities',{{}}, ...
                'metadataValid',true,'metadataErrorMessage','', ...
                'contractValid',true,'contractErrorMessage','', ...
                'isValid',true,'errorMessage','');
        end

        function [doseQuantities,errorMessage] = scanMetadata(filePath)
            errorMessage = '';
            try
                doseQuantities = ...
                    planWorkflow.analysis.ClinicalEndpointFileIndex.fileDoseQuantitiesFromFile( ...
                    filePath);
            catch ME
                doseQuantities = {};
                errorMessage = ME.message;
            end
        end

        function [doseQuantities,errorMessage] = scanContract(filePath)
            errorMessage = '';
            try
                endpoints = ...
                    planWorkflow.analysis.ClinicalEndpointCatalog.loadFile( ...
                    filePath);
                doseQuantities = {};
                for endpointIx = 1:numel(endpoints)
                    doseQuantities{end + 1} = ...
                        endpoints(endpointIx).doseQuantity; %#ok<AGROW>
                end
                doseQuantities = unique(doseQuantities,'stable');
            catch ME
                doseQuantities = {};
                errorMessage = ME.message;
            end
        end

        function message = combinedErrorMessage(metadataError,contractError)
            errors = {};
            if ~isempty(metadataError)
                errors{end + 1} = metadataError; %#ok<AGROW>
            end
            if ~isempty(contractError)
                errors{end + 1} = contractError; %#ok<AGROW>
            end
            message = strjoin(errors,' ');
        end

        function signature = fileListSignature(files)
            parts = cell(1,numel(files));
            for fileIx = 1:numel(files)
                parts{fileIx} = sprintf('%s:%0.17g:%d', ...
                    files(fileIx).name,files(fileIx).datenum, ...
                    files(fileIx).bytes);
            end
            signature = strjoin(parts,'|');
        end

        function doseQuantities = fileDoseQuantitiesFromFile(filePath)
            document = jsondecode(fileread(filePath));
            rawEndpoints = ...
                planWorkflow.analysis.ClinicalEndpointFileIndex.endpointRecords( ...
                document,filePath);
            if isempty(rawEndpoints)
                doseQuantities = {};
                return;
            end
            doseQuantities = cell(1,numel(rawEndpoints));
            for endpointIx = 1:numel(rawEndpoints)
                if ~isfield(rawEndpoints(endpointIx),'doseQuantity') || ...
                        isempty(rawEndpoints(endpointIx).doseQuantity)
                    error(['planWorkflow:analysis:ClinicalEndpointFileIndex:' ...
                        'MissingDoseQuantity'], ...
                        ['Clinical endpoint file "%s" endpoint %d does not ' ...
                         'declare doseQuantity.'],char(filePath),endpointIx);
                end
                doseQuantities{endpointIx} = ...
                    planWorkflow.plan.DoseQuantityResolver.normalizeQuantity( ...
                    rawEndpoints(endpointIx).doseQuantity);
            end
            doseQuantities = unique(doseQuantities,'stable');
        end

        function rawEndpoints = endpointRecords(document,filePath)
            if isstruct(document) && isfield(document,'endpoints')
                rawEndpoints = document.endpoints;
            else
                rawEndpoints = document;
            end
            if isempty(rawEndpoints)
                rawEndpoints = struct([]);
                return;
            end
            if iscell(rawEndpoints)
                if ~all(cellfun(@isstruct,rawEndpoints))
                    error(['planWorkflow:analysis:ClinicalEndpointFileIndex:' ...
                        'InvalidEndpointFile'], ...
                        'Clinical endpoint file "%s" endpoints must be structs.', ...
                        char(filePath));
                end
                rawEndpoints = [rawEndpoints{:}];
            end
            if ~isstruct(rawEndpoints)
                error(['planWorkflow:analysis:ClinicalEndpointFileIndex:' ...
                    'InvalidEndpointFile'], ...
                    'Clinical endpoint file "%s" must define endpoint structs.', ...
                    char(filePath));
            end
        end
    end
end
