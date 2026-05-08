classdef ResourceDetails
    % ResourceDetails Builds resource metadata for planWorkflow tasks.

    methods (Static)
        function detail = planTask(stageName,taskName,taskOutputs)
            detail = '';
            if nargin < 3 || ~iscell(taskOutputs)
                taskOutputs = {};
            end

            detailData = struct();
            if strcmp(char(stageName),'precompute')
                detailData = ...
                    planWorkflow.performance.ResourceDetails.precomputeTask( ...
                    taskName,taskOutputs);
            elseif strcmp(char(stageName),'optimize') && ...
                    strcmp(char(taskName),'fluenceOptimization')
                detailData = ...
                    planWorkflow.performance.ResourceDetails.optimizationTask( ...
                    taskOutputs);
            end

            if ~isempty(fieldnames(detailData))
                detail = jsonencode(detailData);
            end
        end

        function detailData = precomputeTask(taskName,taskOutputs)
            detailData = struct();
            switch char(taskName)
                case 'doseInfluence'
                    detailData = ...
                        planWorkflow.performance.ResourceDetails.appendDoseInfluence( ...
                        detailData,'dij', ...
                        planWorkflow.performance.ResourceDetails.taskOutput( ...
                        taskOutputs,1));
                case 'robustDoseInfluence'
                    detailData = ...
                        planWorkflow.performance.ResourceDetails.appendDoseInfluence( ...
                        detailData,'dij_robust', ...
                        planWorkflow.performance.ResourceDetails.taskOutput( ...
                        taskOutputs,1));
                case 'intervalDoseInfluence'
                    robustData = ...
                        planWorkflow.performance.ResourceDetails.taskOutput( ...
                        taskOutputs,1);
                    detailData = ...
                        planWorkflow.performance.ResourceDetails.appendRobustData( ...
                        detailData,robustData,true);
                case 'intervalDoseInfluenceCacheRead'
                    robustData = ...
                        planWorkflow.performance.ResourceDetails.taskOutput( ...
                        taskOutputs,2);
                    detailData = ...
                        planWorkflow.performance.ResourceDetails.appendRobustData( ...
                        detailData,robustData,false);
                case 'prob2DoseInfluence'
                    robustData = ...
                        planWorkflow.performance.ResourceDetails.taskOutput( ...
                        taskOutputs,1);
                    detailData = ...
                        planWorkflow.performance.ResourceDetails.appendRobustData( ...
                        detailData,robustData,true);
                case 'prob2DoseInfluenceCacheRead'
                    robustData = ...
                        planWorkflow.performance.ResourceDetails.taskOutput( ...
                        taskOutputs,2);
                    detailData = ...
                        planWorkflow.performance.ResourceDetails.appendRobustData( ...
                        detailData,robustData,false);
            end
        end

        function detailData = optimizationTask(taskOutputs)
            detailData = struct();
            resultGUI = planWorkflow.performance.ResourceDetails.taskOutput( ...
                taskOutputs,1);
            iterations = ...
                planWorkflow.performance.ResourceDetails.optimizationIterationCount( ...
                resultGUI);
            if ~isempty(iterations)
                detailData.iterations = iterations;
            end
        end

        function detailData = appendRobustData(detailData,robustData, ...
                includeRobustDij)
            if ~isstruct(robustData)
                return;
            end
            if includeRobustDij && isfield(robustData,'dij')
                detailData = ...
                    planWorkflow.performance.ResourceDetails.appendDoseInfluence( ...
                    detailData,'dij_robust',robustData.dij);
            end
            if isfield(robustData,'dij_interval')
                detailData = ...
                    planWorkflow.performance.ResourceDetails.appendDoseInfluence( ...
                    detailData,'dij_interval',robustData.dij_interval);
            end
            if isfield(robustData,'dij_prob2')
                detailData = ...
                    planWorkflow.performance.ResourceDetails.appendDoseInfluence( ...
                    detailData,'dij_prob2',robustData.dij_prob2);
            end
        end

        function detailData = appendDoseInfluence(detailData,label,value)
            if isempty(value)
                return;
            end

            resourceData = ...
                planWorkflow.performance.ResourceDetails.doseInfluence(value);
            if isempty(fieldnames(resourceData))
                return;
            end
            detailData.(char(label)) = resourceData;
        end

        function data = doseInfluence(value)
            if planWorkflow.performance.ResourceDetails.isProb2DoseInfluence( ...
                    value)
                data = ...
                    planWorkflow.performance.ResourceDetails.prob2DoseInfluence( ...
                    value);
            elseif planWorkflow.performance.ResourceDetails.isIntervalDoseInfluence( ...
                    value)
                data = ...
                    planWorkflow.performance.ResourceDetails.intervalDoseInfluence( ...
                    value);
            else
                data = ...
                    planWorkflow.performance.ResourceDetails.standardDoseInfluence( ...
                    value);
            end
        end

        function tf = isIntervalDoseInfluence(value)
            tf = isstruct(value) && isfield(value,'center');
        end

        function tf = isProb2DoseInfluence(value)
            tf = isstruct(value) && isfield(value,'expected') && ...
                isfield(value,'Omega');
        end

        function data = standardDoseInfluence(value)
            data = struct();
            scenarioCount = ...
                planWorkflow.performance.ResourceDetails.doseInfluenceScenarioCount( ...
                value);
            if ~isempty(scenarioCount)
                data.numberOfScenarios = scenarioCount;
            end

            matrixValue = ...
                planWorkflow.performance.ResourceDetails.primaryDoseInfluenceMatrix( ...
                value);
            if ~isempty(matrixValue)
                data.matrix = ...
                    planWorkflow.performance.ResourceDetails.matrixResourceData( ...
                    matrixValue);
            end
            data.size = planWorkflow.performance.ResourceDetails.sizeResourceData( ...
                value);
        end

        function data = intervalDoseInfluence(value)
            data = struct();
            scenarioCount = ...
                planWorkflow.performance.ResourceDetails.intervalDoseInfluenceScenarioCount( ...
                value);
            if ~isempty(scenarioCount)
                data.numberOfScenarios = scenarioCount;
            end
            if isfield(value,'center') && ~isempty(value.center)
                data.center = ...
                    planWorkflow.performance.ResourceDetails.matrixResourceData( ...
                    value.center);
            end
            if isfield(value,'radius') && ~isempty(value.radius)
                data.radius = ...
                    planWorkflow.performance.ResourceDetails.matrixResourceData( ...
                    value.radius);
            end

            radiusComponents = ...
                planWorkflow.performance.ResourceDetails.intervalRadiusComponents( ...
                value);
            if ~isempty(fieldnames(radiusComponents))
                data.radiusComponents = radiusComponents;
            end
            data.totalSize = ...
                planWorkflow.performance.ResourceDetails.sizeResourceData(value);
        end

        function data = prob2DoseInfluence(value)
            data = struct();
            scenarioCount = ...
                planWorkflow.performance.ResourceDetails.compactDoseInfluenceScenarioCount( ...
                value);
            if ~isempty(scenarioCount)
                data.numberOfScenarios = scenarioCount;
            end
            if isfield(value,'expected') && ~isempty(value.expected)
                data.expected = ...
                    planWorkflow.performance.ResourceDetails.matrixResourceData( ...
                    value.expected);
            end
            omegaComponents = ...
                planWorkflow.performance.ResourceDetails.prob2OmegaComponents( ...
                value);
            if ~isempty(fieldnames(omegaComponents))
                data.omegaComponents = omegaComponents;
            end
            data.totalSize = ...
                planWorkflow.performance.ResourceDetails.sizeResourceData(value);
        end

        function data = intervalRadiusComponents(dijInterval)
            data = struct();
            source = ...
                planWorkflow.performance.ResourceDetails.radiusComponentSource( ...
                dijInterval);
            if isempty(fieldnames(source))
                return;
            end

            componentCount = ...
                planWorkflow.performance.ResourceDetails.componentCount( ...
                source,{'OARSubIx','OARRadiusRank','OARRadiusFactor'});
            if componentCount == 0
                return;
            end

            totalBytes = 0;

            numericFields = {'OARSubIx','OARRadiusRank'};
            for fieldIx = 1:numel(numericFields)
                fieldName = numericFields{fieldIx};
                fieldData = ...
                    planWorkflow.performance.ResourceDetails.componentNumericSummary( ...
                    source,fieldName);
                if ~isempty(fieldnames(fieldData))
                    data.(fieldName) = fieldData;
                end
                totalBytes = totalBytes + ...
                    planWorkflow.performance.ResourceDetails.componentCollectionBytes( ...
                    source,fieldName);
            end

            matrixFields = {'OARRadiusFactor'};
            for fieldIx = 1:numel(matrixFields)
                fieldName = matrixFields{fieldIx};
                fieldData = ...
                    planWorkflow.performance.ResourceDetails.componentMatrixSummary( ...
                    source,fieldName);
                if ~isempty(fieldnames(fieldData))
                    data.(fieldName) = fieldData;
                end
                totalBytes = totalBytes + ...
                    planWorkflow.performance.ResourceDetails.componentCollectionBytes( ...
                    source,fieldName);
            end

            if planWorkflow.performance.ResourceDetails.hasOARRadiusFactors( ...
                    source)
                data.representation = 'OARRadiusFactors';
                data.memoryModel = 'retainedOARRadiusFactors';
            end
            data.count = componentCount;
            data.totalSize = ...
                planWorkflow.performance.ResourceDetails.sizeResourceDataFromBytes( ...
                totalBytes);
        end

        function data = prob2OmegaComponents(dijProb2)
            data = struct();
            source = struct();
            if ~isstruct(dijProb2)
                return;
            end
            if isfield(dijProb2,'voiSubIx')
                source.voiSubIx = dijProb2.voiSubIx;
            end
            if isfield(dijProb2,'Omega')
                source.Omega = dijProb2.Omega;
            end

            componentCount = ...
                planWorkflow.performance.ResourceDetails.componentCount( ...
                source,{'voiSubIx','Omega'});
            if componentCount == 0
                return;
            end

            totalBytes = 0;
            voiData = ...
                planWorkflow.performance.ResourceDetails.componentNumericSummary( ...
                source,'voiSubIx');
            if ~isempty(fieldnames(voiData))
                data.voiSubIx = voiData;
            end
            totalBytes = totalBytes + ...
                planWorkflow.performance.ResourceDetails.componentCollectionBytes( ...
                source,'voiSubIx');

            omegaData = ...
                planWorkflow.performance.ResourceDetails.componentMatrixSummary( ...
                source,'Omega');
            if ~isempty(fieldnames(omegaData))
                data.Omega = omegaData;
            end
            totalBytes = totalBytes + ...
                planWorkflow.performance.ResourceDetails.componentCollectionBytes( ...
                source,'Omega');

            data.representation = 'probabilisticOmegaByStructure';
            data.count = componentCount;
            data.totalSize = ...
                planWorkflow.performance.ResourceDetails.sizeResourceDataFromBytes( ...
                totalBytes);
        end

        function source = radiusComponentSource(dijInterval)
            source = struct();
            if ~isstruct(dijInterval)
                return;
            end

            if isfield(dijInterval,'OARSubIx')
                source.OARSubIx = dijInterval.OARSubIx;
            end
            fields = {'OARRadiusRank','OARRadiusFactor'};
            for fieldIx = 1:numel(fields)
                fieldName = fields{fieldIx};
                if isfield(dijInterval,fieldName)
                    source.(fieldName) = dijInterval.(fieldName);
                end
            end
        end

        function count = componentCount(source,fields)
            count = 0;
            for fieldIx = 1:numel(fields)
                fieldName = fields{fieldIx};
                if ~isfield(source,fieldName)
                    continue;
                end
                value = source.(fieldName);
                if iscell(value)
                    count = max(count,numel(value));
                elseif isnumeric(value) || islogical(value)
                    if isvector(value)
                        count = max(count,numel(value));
                    else
                        count = max(count,1);
                    end
                end
            end
        end

        function tf = hasOARRadiusFactors(source)
            requiredFields = {'OARRadiusRank','OARRadiusFactor'};
            tf = isstruct(source) && all(isfield(source,requiredFields));
        end

        function data = componentNumericSummary(source,fieldName)
            data = struct();
            values = ...
                planWorkflow.performance.ResourceDetails.componentCollectionValues( ...
                source,fieldName);
            if isempty(values)
                return;
            end

            numericValues = [];
            for valueIx = 1:numel(values)
                value = values{valueIx};
                if ~(isnumeric(value) || islogical(value)) || isempty(value)
                    continue;
                end
                numericValues = [numericValues; double(value(:))]; %#ok<AGROW>
            end
            numericValues = numericValues(isfinite(numericValues));
            if isempty(numericValues)
                return;
            end

            data.count = numel(numericValues);
            data.min = min(numericValues);
            data.max = max(numericValues);
            data.sum = sum(numericValues);
            data.mean = mean(numericValues);
        end

        function data = componentMatrixSummary(source,fieldName)
            data = struct();
            values = ...
                planWorkflow.performance.ResourceDetails.componentCollectionValues( ...
                source,fieldName);
            if isempty(values)
                return;
            end

            count = 0;
            totalRows = 0;
            totalColumns = 0;
            maxRows = 0;
            maxColumns = 0;
            totalElements = 0;
            totalNonzeros = 0;
            totalBytes = 0;
            for valueIx = 1:numel(values)
                value = values{valueIx};
                if isempty(value) || ...
                        ~(isnumeric(value) || islogical(value) || issparse(value))
                    continue;
                end
                valueSize = size(value);
                rows = valueSize(1);
                columns = 1;
                if numel(valueSize) >= 2
                    columns = valueSize(2);
                end
                count = count + 1;
                totalRows = totalRows + rows;
                totalColumns = totalColumns + columns;
                maxRows = max(maxRows,rows);
                maxColumns = max(maxColumns,columns);
                totalElements = totalElements + numel(value);
                totalNonzeros = totalNonzeros + nnz(value);
                totalBytes = totalBytes + ...
                    planWorkflow.performance.ResourceDetails.matlabVariableBytes( ...
                    value);
            end
            if count == 0
                return;
            end

            data.count = count;
            data.totalRows = totalRows;
            data.totalColumns = totalColumns;
            data.maxRows = maxRows;
            data.maxColumns = maxColumns;
            data.totalElements = totalElements;
            data.totalNonzeros = totalNonzeros;
            data.totalSize = ...
                planWorkflow.performance.ResourceDetails.sizeResourceDataFromBytes( ...
                totalBytes);
        end

        function values = componentCollectionValues(source,fieldName)
            values = {};
            if ~isstruct(source) || ~isfield(source,fieldName)
                return;
            end

            fieldValue = source.(fieldName);
            if iscell(fieldValue)
                values = reshape(fieldValue,1,[]);
            else
                values = {fieldValue};
            end
        end

        function bytes = componentCollectionBytes(source,fieldName)
            bytes = 0;
            values = ...
                planWorkflow.performance.ResourceDetails.componentCollectionValues( ...
                source,fieldName);
            for valueIx = 1:numel(values)
                value = values{valueIx};
                if isempty(value)
                    continue;
                end
                bytes = bytes + ...
                    planWorkflow.performance.ResourceDetails.matlabVariableBytes( ...
                    value);
            end
        end

        function count = doseInfluenceScenarioCount(value)
            count = [];
            if ~isstruct(value)
                return;
            end
            if isfield(value,'numOfScenarios') && ...
                    isnumeric(value.numOfScenarios) && ...
                    isscalar(value.numOfScenarios)
                count = value.numOfScenarios;
                return;
            end
            if isfield(value,'scenarioModel') && ...
                    ~isempty(value.scenarioModel) && ...
                    ismethod(value.scenarioModel,'numScenarios')
                try
                    count = value.scenarioModel.numScenarios();
                    return;
                catch
                end
            end
            if isfield(value,'physicalDose') && ~isempty(value.physicalDose)
                physicalDose = value.physicalDose;
                if iscell(physicalDose)
                    count = numel(physicalDose);
                end
            end
        end

        function count = intervalDoseInfluenceScenarioCount(value)
            count = ...
                planWorkflow.performance.ResourceDetails.compactDoseInfluenceScenarioCount( ...
                value);
        end

        function count = compactDoseInfluenceScenarioCount(value)
            count = [];
            if ~isstruct(value)
                return;
            end
            if isfield(value,'scenarioDijIx') && ~isempty(value.scenarioDijIx)
                count = numel(value.scenarioDijIx);
            elseif isfield(value,'scenarioWeights') && ...
                    ~isempty(value.scenarioWeights)
                count = numel(value.scenarioWeights);
            end
        end

        function matrixValue = primaryDoseInfluenceMatrix(value)
            matrixValue = [];
            if isnumeric(value) || islogical(value) || issparse(value)
                matrixValue = value;
                return;
            end
            if ~isstruct(value)
                return;
            end

            if isfield(value,'physicalDose') && ~isempty(value.physicalDose)
                physicalDose = value.physicalDose;
                if iscell(physicalDose)
                    for doseIx = 1:numel(physicalDose)
                        if ~isempty(physicalDose{doseIx})
                            matrixValue = physicalDose{doseIx};
                            return;
                        end
                    end
                else
                    matrixValue = physicalDose;
                    return;
                end
            end

            if isfield(value,'numOfScenarios') && ...
                    isfield(value,'totalNumOfBixels') && ...
                    isnumeric(value.numOfScenarios) && ...
                    isnumeric(value.totalNumOfBixels)
                matrixValue = sparse(value.numOfScenarios, ...
                    value.totalNumOfBixels);
            end
        end

        function data = matrixResourceData(value)
            valueSize = size(value);
            rows = valueSize(1);
            columns = 1;
            if numel(valueSize) >= 2
                columns = valueSize(2);
            end

            data = struct();
            data.rows = rows;
            data.columns = columns;
            data.dimensions = sprintf('%dx%d',rows,columns);
            data.size = ...
                planWorkflow.performance.ResourceDetails.sizeResourceData(value);
        end

        function iterations = optimizationIterationCount(resultGUI)
            iterations = [];
            if ~isstruct(resultGUI) || ~isfield(resultGUI,'info') || ...
                    ~isstruct(resultGUI.info)
                return;
            end

            info = resultGUI.info;
            fields = {'iterations','iteration','iter','niter', ...
                'numIterations','funcCount'};
            for fieldIx = 1:numel(fields)
                fieldName = fields{fieldIx};
                if isfield(info,fieldName) && isnumeric(info.(fieldName)) && ...
                        isscalar(info.(fieldName)) && ...
                        isfinite(info.(fieldName))
                    iterations = info.(fieldName);
                    return;
                end
            end
        end

        function value = taskOutput(taskOutputs,index)
            value = [];
            if iscell(taskOutputs) && numel(taskOutputs) >= index
                value = taskOutputs{index};
            end
        end

        function data = sizeResourceData(value)
            data = ...
                planWorkflow.performance.ResourceDetails.sizeResourceDataFromBytes( ...
                planWorkflow.performance.ResourceDetails.matlabVariableBytes( ...
                value));
        end

        function data = sizeResourceDataFromBytes(bytes)
            if ~(isnumeric(bytes) && isscalar(bytes) && isfinite(bytes))
                bytes = 0;
            end
            data = struct();
            data.bytes = double(bytes);
            data.megabytes = double(bytes) / 1024^2;
            data.text = sprintf('%.2f MB',data.megabytes);
        end

        function bytes = matlabVariableBytes(value)
            variableInfo = whos('value');
            bytes = variableInfo.bytes;
        end

    end
end
