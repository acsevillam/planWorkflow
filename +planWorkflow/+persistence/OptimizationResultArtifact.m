classdef OptimizationResultArtifact
    % OptimizationResultArtifact Stores completed optimization units for resume.

    properties (Constant)
        SchemaName = 'planWorkflow.optimizationResult.v1'
        SchemaVersion = 1
    end

    methods (Static)
        function cachePath = cachePath(runConfig)
            cachePath = [];
            if isstruct(runConfig) && isfield(runConfig,'cacheRootPath')
                cachePath = runConfig.cacheRootPath;
            end
        end

        function [resultGUI,reused] = cachedResult( ...
                runConfig,cachePath,unitKey,unitInfo,optimizationInput)
            resultGUI = struct();
            reused = false;
            if nargin < 2 || isempty(cachePath)
                cachePath = ...
                    planWorkflow.persistence.OptimizationResultArtifact.cachePath( ...
                    runConfig);
            end
            if isempty(cachePath)
                return;
            end
            cacheFile = ...
                planWorkflow.persistence.OptimizationResultArtifact.cacheFile( ...
                cachePath,unitKey);
            if exist(cacheFile,'file') ~= 2 || ...
                    planWorkflow.persistence.OptimizationResultArtifact.isTmpFile( ...
                    cacheFile)
                return;
            end

            try
                loaded = load(cacheFile,'resultGUI', ...
                    'optimizationResultMetadata');
                if ~isfield(loaded,'resultGUI') || ...
                        ~isfield(loaded,'optimizationResultMetadata')
                    return;
                end
                expected = ...
                    planWorkflow.persistence.OptimizationResultArtifact.metadata( ...
                    runConfig,unitInfo,optimizationInput,loaded.resultGUI);
                if ~planWorkflow.persistence.OptimizationResultArtifact.isCompatibleMetadata( ...
                        loaded.optimizationResultMetadata,expected)
                    return;
                end
                planWorkflow.persistence.OptimizationResultArtifact.validateResult( ...
                    loaded.resultGUI,expected);
                resultGUI = loaded.resultGUI;
                reused = true;
            catch
                resultGUI = struct();
                reused = false;
            end
        end

        function resultGUI = persistResult(resultGUI,runConfig,cachePath, ...
                unitKey,unitInfo,optimizationInput)
            if nargin < 3 || isempty(cachePath)
                cachePath = ...
                    planWorkflow.persistence.OptimizationResultArtifact.cachePath( ...
                    runConfig);
            end
            if isempty(cachePath)
                return;
            end
            resultGUI = planWorkflow.results.ResultGUICompactor.compact( ...
                resultGUI);
            metadata = ...
                planWorkflow.persistence.OptimizationResultArtifact.metadata( ...
                runConfig,unitInfo,optimizationInput,resultGUI);
            planWorkflow.persistence.OptimizationResultArtifact.validateResult( ...
                resultGUI,metadata);
            payload = struct();
            payload.resultGUI = resultGUI;
            payload.optimizationResultMetadata = metadata;
            cacheFile = ...
                planWorkflow.persistence.OptimizationResultArtifact.cacheFile( ...
                cachePath,unitKey);
            planWorkflow.persistence.OptimizationResultArtifact.ensureFolder( ...
                fileparts(cacheFile));
            planWorkflow.persistence.OptimizationResultArtifact.atomicSave( ...
                cacheFile,payload);
        end

        function hash = optimizationInputRefHash(input)
            signature = struct();
            signature.dijKind = ...
                planWorkflow.persistence.OptimizationResultArtifact.textField( ...
                input,'dijKind');
            signature.source = ...
                planWorkflow.persistence.OptimizationResultArtifact.textField( ...
                input,'source');
            signature.totalNumOfBixels = ...
                planWorkflow.persistence.OptimizationResultArtifact.totalNumOfBixels( ...
                input);
            signature.stf = ...
                planWorkflow.persistence.OptimizationResultArtifact.stfIdentity( ...
                input);
            signature.cst = ...
                planWorkflow.persistence.OptimizationResultArtifact.cstIdentity( ...
                input);
            signature.pln = ...
                planWorkflow.persistence.OptimizationResultArtifact.planIdentity( ...
                input);
            signature.ctReferenceView = ...
                planWorkflow.persistence.OptimizationResultArtifact.optionalField( ...
                input,'ctReferenceView',struct());
            hash = planWorkflow.cache.CacheIdentity.valueHash(signature);
        end

        function unitInfo = normalizeUnitInfo(unitInfo)
            defaults = struct('role','','planId','','variantId','', ...
                'label','','planIndex',0,'variantIndex',0,'unitKey','');
            if ~isstruct(unitInfo) || ~isscalar(unitInfo)
                unitInfo = struct();
            end
            fields = fieldnames(defaults);
            for fieldIx = 1:numel(fields)
                fieldName = fields{fieldIx};
                if ~isfield(unitInfo,fieldName)
                    unitInfo.(fieldName) = defaults.(fieldName);
                end
            end
            textFields = {'role','planId','variantId','label','unitKey'};
            for fieldIx = 1:numel(textFields)
                fieldName = textFields{fieldIx};
                unitInfo.(fieldName) = char(unitInfo.(fieldName));
            end
        end
    end

    methods (Static, Access = private)
        function cacheFile = cacheFile(cachePath,unitKey)
            cacheFile = fullfile(cachePath,'optimization_results', ...
                [planWorkflow.persistence.OptimizationResultArtifact.safeName( ...
                unitKey) '.mat']);
        end

        function metadata = metadata(runConfig,unitInfo,optimizationInput, ...
                resultGUI)
            unitInfo = ...
                planWorkflow.persistence.OptimizationResultArtifact.normalizeUnitInfo( ...
                unitInfo);
            metadata = struct();
            metadata.schema = ...
                planWorkflow.persistence.OptimizationResultArtifact.SchemaName;
            metadata.schemaVersion = ...
                planWorkflow.persistence.OptimizationResultArtifact.SchemaVersion;
            metadata.role = unitInfo.role;
            metadata.planId = unitInfo.planId;
            metadata.variantId = unitInfo.variantId;
            metadata.label = unitInfo.label;
            metadata.planIndex = unitInfo.planIndex;
            metadata.variantIndex = unitInfo.variantIndex;
            metadata.unitKey = unitInfo.unitKey;
            metadata.dijKind = ...
                planWorkflow.persistence.OptimizationResultArtifact.textField( ...
                optimizationInput,'dijKind');
            metadata.optimizationInputRefHash = ...
                planWorkflow.persistence.OptimizationResultArtifact.optimizationInputRefHash( ...
                optimizationInput);
            metadata.totalNumOfBixels = ...
                planWorkflow.persistence.OptimizationResultArtifact.totalNumOfBixels( ...
                optimizationInput);
            metadata.resultWeightCount = ...
                planWorkflow.persistence.OptimizationResultArtifact.resultWeightCount( ...
                resultGUI);
            metadata.workflowIdentity = ...
                planWorkflow.persistence.OptimizationResultArtifact.workflowIdentity( ...
                runConfig);
            metadata.workflowIdentityHash = ...
                planWorkflow.cache.CacheIdentity.valueHash( ...
                metadata.workflowIdentity);
            metadata.createdAt = char(datetime('now','Format', ...
                'yyyy-MM-dd HH:mm:ss'));
        end

        function tf = isCompatibleMetadata(actual,expected)
            tf = isstruct(actual) && isstruct(expected) && ...
                planWorkflow.persistence.OptimizationResultArtifact.equalField( ...
                actual,expected,'schema') && ...
                planWorkflow.persistence.OptimizationResultArtifact.equalField( ...
                actual,expected,'schemaVersion') && ...
                planWorkflow.persistence.OptimizationResultArtifact.equalField( ...
                actual,expected,'role') && ...
                planWorkflow.persistence.OptimizationResultArtifact.equalField( ...
                actual,expected,'planId') && ...
                planWorkflow.persistence.OptimizationResultArtifact.equalField( ...
                actual,expected,'variantId') && ...
                planWorkflow.persistence.OptimizationResultArtifact.equalField( ...
                actual,expected,'planIndex') && ...
                planWorkflow.persistence.OptimizationResultArtifact.equalField( ...
                actual,expected,'variantIndex') && ...
                planWorkflow.persistence.OptimizationResultArtifact.equalField( ...
                actual,expected,'dijKind') && ...
                planWorkflow.persistence.OptimizationResultArtifact.equalField( ...
                actual,expected,'optimizationInputRefHash') && ...
                planWorkflow.persistence.OptimizationResultArtifact.equalField( ...
                actual,expected,'totalNumOfBixels') && ...
                planWorkflow.persistence.OptimizationResultArtifact.equalField( ...
                actual,expected,'resultWeightCount') && ...
                planWorkflow.persistence.OptimizationResultArtifact.equalField( ...
                actual,expected,'workflowIdentityHash');
        end

        function tf = equalField(left,right,fieldName)
            tf = isfield(left,fieldName) && isfield(right,fieldName) && ...
                isequal(left.(fieldName),right.(fieldName));
        end

        function validateResult(resultGUI,metadata)
            if ~isstruct(resultGUI) || ~isfield(resultGUI,'w') || ...
                    isempty(resultGUI.w)
                error(['planWorkflow:persistence:OptimizationResultArtifact:' ...
                    'MissingWeights'], ...
                    'Optimization result artifact requires resultGUI.w.');
            end
            if ~isempty(metadata.totalNumOfBixels) && ...
                    ~planWorkflow.persistence.OptimizationResultArtifact.weightsMatchBixels( ...
                    resultGUI.w,metadata.totalNumOfBixels)
                error(['planWorkflow:persistence:OptimizationResultArtifact:' ...
                    'WeightSteeringMismatch'], ...
                    ['Optimization result has %d weights, but the input ' ...
                     'expects %d bixels.'],numel(resultGUI.w), ...
                    metadata.totalNumOfBixels);
            end
        end

        function tf = weightsMatchBixels(weights,totalNumOfBixels)
            tf = numel(weights) == totalNumOfBixels || ...
                (isscalar(weights) && isequal(weights,totalNumOfBixels));
        end

        function identity = workflowIdentity(runConfig)
            identity = struct();
            fields = {'runId','description','caseID','radiationMode', ...
                'workflowType','plan_template','plan_template_hash', ...
                'plan_beams','machine','bioModel'};
            for fieldIx = 1:numel(fields)
                fieldName = fields{fieldIx};
                if isstruct(runConfig) && isfield(runConfig,fieldName)
                    identity.(fieldName) = runConfig.(fieldName);
                end
            end
        end

        function count = totalNumOfBixels(input)
            count = [];
            if ~isstruct(input)
                return;
            end
            if isfield(input,'stf') && ~isempty(input.stf)
                count = ...
                    planWorkflow.precompute.OptimizationInput.totalNumOfBixels( ...
                    input.stf);
            end
            if isempty(count) && isfield(input,'dijRef') && ...
                    isfield(input.dijRef,'totalNumOfBixels')
                count = input.dijRef.totalNumOfBixels;
            end
            if isempty(count) && isfield(input,'dijInline') && ...
                    isfield(input.dijInline,'totalNumOfBixels')
                count = input.dijInline.totalNumOfBixels;
            end
            if isempty(count) && isfield(input,'dij') && ~isempty(input.dij)
                count = ...
                    planWorkflow.precompute.OptimizationInput.totalNumOfBixels( ...
                    input.dij);
            end
        end

        function count = resultWeightCount(resultGUI)
            count = [];
            if isstruct(resultGUI) && isfield(resultGUI,'w')
                count = numel(resultGUI.w);
            end
        end

        function identity = stfIdentity(input)
            identity = struct();
            if isstruct(input) && isfield(input,'stf') && ~isempty(input.stf)
                identity = planWorkflow.cache.DoseInfluenceCache.stfSignature( ...
                    input.stf);
            end
        end

        function identity = cstIdentity(input)
            identity = struct();
            if isstruct(input) && isfield(input,'cst') && ~isempty(input.cst)
                identity = planWorkflow.cache.CacheIdentity.cstIdentity( ...
                    input.cst);
            end
        end

        function identity = planIdentity(input)
            identity = struct();
            if ~isstruct(input) || ~isfield(input,'pln') || ...
                    ~isstruct(input.pln)
                return;
            end
            pln = input.pln;
            identity.radiationMode = ...
                planWorkflow.persistence.OptimizationResultArtifact.textField( ...
                pln,'radiationMode');
            identity.machine = ...
                planWorkflow.persistence.OptimizationResultArtifact.textField( ...
                pln,'machine');
            if isfield(pln,'numOfFractions')
                identity.numOfFractions = pln.numOfFractions;
            end
            if isfield(pln,'propStf')
                identity.propStf = pln.propStf;
            end
            if isfield(pln,'propOpt') && isstruct(pln.propOpt)
                propOpt = pln.propOpt;
                heavyFields = {'dij','dij_prob','dij_interval'};
                for fieldIx = 1:numel(heavyFields)
                    if isfield(propOpt,heavyFields{fieldIx})
                        propOpt = rmfield(propOpt,heavyFields{fieldIx});
                    end
                end
                identity.propOpt = propOpt;
            end
        end

        function value = textField(input,fieldName)
            value = '';
            if isstruct(input) && isfield(input,fieldName) && ...
                    ~isempty(input.(fieldName))
                value = char(input.(fieldName));
            end
        end

        function value = optionalField(input,fieldName,defaultValue)
            value = defaultValue;
            if isstruct(input) && isfield(input,fieldName)
                value = input.(fieldName);
            end
        end

        function ensureFolder(folderPath)
            if ~isfolder(folderPath)
                mkdir(folderPath);
            end
        end

        function atomicSave(cacheFile,payload)
            tmpFile = [cacheFile '.tmp'];
            if exist(tmpFile,'file') == 2
                delete(tmpFile);
            end
            cleanup = onCleanup(@() ...
                planWorkflow.persistence.OptimizationResultArtifact.deleteTmpFile( ...
                tmpFile));
            builtin('save',tmpFile,'-struct','payload','-v7.3');
            movefile(tmpFile,cacheFile,'f');
            clear cleanup;
        end

        function deleteTmpFile(tmpFile)
            if exist(tmpFile,'file') == 2
                delete(tmpFile);
            end
        end

        function tf = isTmpFile(fileName)
            fileName = char(fileName);
            tf = numel(fileName) >= 4 && strcmp(fileName(end-3:end),'.tmp');
        end

        function value = safeName(value)
            value = regexprep(char(value),'[^A-Za-z0-9_.-]','_');
            if isempty(value)
                value = 'unnamed';
            end
        end
    end
end
