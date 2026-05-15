classdef StageConfigSchema
    % StageConfigSchema Canonical workflow-stage config contract.

    methods (Static)
        function descriptors = descriptors()
            descriptors = struct( ...
                'publicName',{'prepare','precompute','pullDose', ...
                'optimize','sampling','analysis'}, ...
                'engineName',{'prepare','precompute','pullDose', ...
                'optimize','sample','analyze'}, ...
                'completedName',{'prepared','precomputed', ...
                'dose_pulled','optimized','sampled','analyzed'}, ...
                'displayLabel',{'Prepare','Precompute','Dose pulling', ...
                'Optimize','Sampling','Analysis'}, ...
                'macroTitle',{'Prepare stage','Precompute stage', ...
                'Dose-pulling stage','Optimize stage','Sample stage', ...
                'Analyze stage'}, ...
                'workflowMethod',{'prepare','precompute','pullDose', ...
                'optimize','sample','analyze'}, ...
                'stageClass',{'planWorkflow.stages.PrepareStage', ...
                'planWorkflow.stages.PrecomputeStage', ...
                'planWorkflow.stages.PullDoseStage', ...
                'planWorkflow.stages.OptimizeStage', ...
                'planWorkflow.stages.SamplingStage', ...
                'planWorkflow.stages.AnalyzeStage'});
        end

        function names = publicStageNames()
            descriptors = planWorkflow.config.StageConfigSchema.descriptors();
            names = {descriptors.publicName};
        end

        function names = engineStageNames()
            descriptors = planWorkflow.config.StageConfigSchema.descriptors();
            names = {descriptors.engineName};
        end

        function descriptor = descriptor(stageName)
            publicName = ...
                planWorkflow.config.StageConfigSchema.canonicalStageName( ...
                stageName);
            descriptors = planWorkflow.config.StageConfigSchema.descriptors();
            ix = find(strcmp({descriptors.publicName},publicName),1);
            descriptor = descriptors(ix);
        end

        function fields = macroFields(stageName,runConfig)
            stageName = ...
                planWorkflow.config.StageConfigSchema.canonicalStageName( ...
                stageName);
            switch stageName
                case 'prepare'
                    fields = ...
                        planWorkflow.config.StageConfigSchema.presetFields( ...
                        'prepare');
                case 'precompute'
                    fields = ...
                        planWorkflow.config.WorkflowParameterSchema.precomputeExportFields( ...
                        runConfig);
                case 'pullDose'
                    fields = ...
                        planWorkflow.config.WorkflowParameterSchema.dosePullingVisibleFields( ...
                        runConfig.dose_pulling1,runConfig.dose_pulling2, ...
                        runConfig.dose_pulling_strategy, ...
                        runConfig.dose_pulling_selection_policy);
                    fields = ...
                        planWorkflow.config.StageConfigSchema.sourceFieldsForTargets( ...
                        'pullDose',fields);
                case 'optimize'
                    fields = {'optimizer','optimizerOptions'};
                case 'sampling'
                    fields = ...
                        planWorkflow.config.WorkflowParameterSchema.samplingParameterFields( ...
                        runConfig.sampling_linkToOptimization, ...
                        runConfig.sampling_scen_mode,runConfig);
                    fields = ...
                        planWorkflow.config.StageConfigSchema.sourceFieldsForTargets( ...
                        'sampling',fields);
                case 'analysis'
                    fields = ...
                        planWorkflow.config.WorkflowParameterSchema.analysisVisibleFields( ...
                        runConfig.analysis.robustnessTargetMode);
            end
        end

        function stageName = canonicalStageName(stageName)
            stageName = char(stageName);
            stageName = planWorkflow.config.StageConfigSchema.publicName( ...
                stageName);
            supported = planWorkflow.config.StageConfigSchema.publicStageNames();
            if ~any(strcmp(stageName,supported))
                error('planWorkflow:config:StageConfigSchema:UnknownStage', ...
                    ['Unknown workflowConfig stage "%s". Supported ' ...
                     'stages are: %s.'],stageName,strjoin(supported,', '));
            end
        end

        function publicName = publicName(stageName)
            stageName = char(stageName);
            descriptors = planWorkflow.config.StageConfigSchema.descriptors();
            publicName = stageName;
            for i = 1:numel(descriptors)
                if strcmp(stageName,descriptors(i).engineName)
                    publicName = descriptors(i).publicName;
                    return;
                end
            end
        end

        function engineStageName = engineStageName(stageName)
            publicName = ...
                planWorkflow.config.StageConfigSchema.canonicalStageName( ...
                stageName);
            descriptors = planWorkflow.config.StageConfigSchema.descriptors();
            ix = find(strcmp({descriptors.publicName},publicName),1);
            engineStageName = descriptors(ix).engineName;
        end

        function label = stageLabel(stageName)
            try
                publicName = ...
                    planWorkflow.config.StageConfigSchema.canonicalStageName( ...
                    stageName);
            catch
                label = char(stageName);
                return;
            end
            descriptors = planWorkflow.config.StageConfigSchema.descriptors();
            ix = find(strcmp({descriptors.publicName},publicName),1);
            label = descriptors(ix).displayLabel;
        end

        function completedName = completedName(stageName)
            publicName = ...
                planWorkflow.config.StageConfigSchema.canonicalStageName( ...
                stageName);
            descriptors = planWorkflow.config.StageConfigSchema.descriptors();
            ix = find(strcmp({descriptors.publicName},publicName),1);
            completedName = descriptors(ix).completedName;
        end

        function completedNames = completedNamesFrom(stageName)
            publicName = ...
                planWorkflow.config.StageConfigSchema.canonicalStageName( ...
                stageName);
            descriptors = planWorkflow.config.StageConfigSchema.descriptors();
            ix = find(strcmp({descriptors.publicName},publicName),1);
            completedNames = {descriptors(ix:end).completedName};
        end

        function stageName = stageNameFromCompleted(completedName)
            descriptors = planWorkflow.config.StageConfigSchema.descriptors();
            ix = find(strcmp({descriptors.completedName}, ...
                char(completedName)),1);
            if isempty(ix)
                stageName = '';
            else
                stageName = descriptors(ix).engineName;
            end
        end

        function fields = fields(stageName,analysisDefaults)
            stageName = ...
                planWorkflow.config.StageConfigSchema.canonicalStageName( ...
                stageName);
            switch stageName
                case 'prepare'
                    fields = ...
                        planWorkflow.config.WorkflowParameterSchema.prepareFields();
                case 'precompute'
                    fields = {'doseResolution','useCache','writeCache', ...
                        'reference','robustPlans'};
                case 'pullDose'
                    fields = planWorkflow.config.StageConfigSchema.sourceFields( ...
                        'pullDose');
                case 'optimize'
                    fields = {'optimizer','optimizerOptions'};
                case 'sampling'
                    fields = planWorkflow.config.StageConfigSchema.sourceFields( ...
                        'sampling');
                case 'analysis'
                    if nargin < 2 || isempty(analysisDefaults)
                        fields = {};
                    else
                        fields = fieldnames(analysisDefaults)';
                    end
            end
        end

        function replacement = unsupportedFieldReplacement(stageName,fieldName)
            stageName = ...
                planWorkflow.config.StageConfigSchema.canonicalStageName( ...
                stageName);
            fieldName = char(fieldName);
            replacement = '';
            if strcmp(stageName,'prepare') && strcmp(fieldName,'n_cores')
                replacement = ...
                    ['resources.sampling.workerUpperBound or ' ...
                     'resources.sampling.autoLimitWorkers'];
            end
        end

        function fields = presetFields(stageName,analysisDefaults)
            if nargin < 2
                analysisDefaults = [];
            end
            fields = planWorkflow.config.StageConfigSchema.fields( ...
                stageName,analysisDefaults);
            if strcmp(char(stageName),'precompute')
                fields(strcmp(fields,'bixelWidth')) = [];
            end
        end

        function map = fieldMap(stageName)
            stageName = ...
                planWorkflow.config.StageConfigSchema.canonicalStageName( ...
                stageName);
            switch stageName
                case 'pullDose'
                    map = { ...
                        'step1Enabled','dose_pulling1'; ...
                        'step1Target','dose_pulling1_target'; ...
                        'step1Criteria','dose_pulling1_criteria'; ...
                        'step1Limit','dose_pulling1_limit'; ...
                        'step1Start','dose_pulling1_start'; ...
                        'step2Enabled','dose_pulling2'; ...
                        'step2Target','dose_pulling2_target'; ...
                        'step2Criteria','dose_pulling2_criteria'; ...
                        'step2Limit','dose_pulling2_limit'; ...
                        'step2Start','dose_pulling2_start'; ...
                        'maxIterations','dose_pulling_max_iter'; ...
                        'strategy','dose_pulling_strategy'; ...
                        'searchSchedule','dose_pulling_search_schedule'; ...
                        'localWindow','dose_pulling_local_window'; ...
                        'patience','dose_pulling_patience'; ...
                        'targetTol','dose_pulling_target_tol'; ...
                        'selectionPolicy','dose_pulling_selection_policy'; ...
                        'targetWeight','dose_pulling_target_weight'; ...
                        'oarWeight','dose_pulling_oar_weight'; ...
                        'stepWeight','dose_pulling_step_weight'; ...
                        'maxVmaxPercent', ...
                        'dose_pulling_max_vmax_percent'; ...
                        'useWarmStart','dose_pulling_use_warm_start'};
                case 'sampling'
                    map = { ...
                        'caseID','sampling_caseID'; ...
                        'AcquisitionType','sampling_AcquisitionType'; ...
                        'dicomMetadata','sampling_dicomMetadata'; ...
                        'sampling_dicomMetadata','sampling_dicomMetadata'; ...
                        'linkToOptimization','sampling_linkToOptimization'; ...
                        'sampling_linkToOptimization', ...
                        'sampling_linkToOptimization'};
                    scenarioFields = ...
                        planWorkflow.config.ScenarioSpec.matRadFields();
                    for fieldIx = 1:numel(scenarioFields)
                        fieldName = scenarioFields{fieldIx};
                        sourceField = ...
                            planWorkflow.config.ScenarioSpec.runFieldName( ...
                            'sampling', ...
                            planWorkflow.config.StageConfigSchema.scenarioSourceName( ...
                            fieldName));
                        map(end + 1,:) = {sourceField,sourceField}; %#ok<AGROW>
                    end
                otherwise
                    map = cell(0,2);
            end
        end

        function fields = sourceFields(stageName)
            map = planWorkflow.config.StageConfigSchema.fieldMap(stageName);
            fields = map(:,1)';
        end

        function targetField = targetField(stageName,sourceField)
            map = planWorkflow.config.StageConfigSchema.fieldMap(stageName);
            ix = find(strcmp(map(:,1),char(sourceField)),1);
            if isempty(ix)
                targetField = char(sourceField);
            else
                targetField = map{ix,2};
            end
        end

        function sourceField = sourceField(stageName,targetField)
            map = planWorkflow.config.StageConfigSchema.fieldMap(stageName);
            ix = find(strcmp(map(:,2),char(targetField)),1);
            if isempty(ix)
                sourceField = char(targetField);
            else
                sourceField = map{ix,1};
            end
        end

        function fields = sourceFieldsForTargets(stageName,targetFields)
            fields = cell(1,numel(targetFields));
            for fieldIx = 1:numel(targetFields)
                fields{fieldIx} = ...
                    planWorkflow.config.StageConfigSchema.sourceField( ...
                    stageName,targetFields{fieldIx});
            end
            fields = unique(fields,'stable');
        end

        function patch = mapToRunConfig(stageName,stageConfig)
            stageName = ...
                planWorkflow.config.StageConfigSchema.canonicalStageName( ...
                stageName);
            switch stageName
                case {'prepare','optimize'}
                    patch = stageConfig;
                case 'precompute'
                    patch = struct();
                    rootFields = {'doseResolution','useCache','writeCache'};
                    for fieldIx = 1:numel(rootFields)
                        fieldName = rootFields{fieldIx};
                        if isfield(stageConfig,fieldName)
                            patch.(fieldName) = stageConfig.(fieldName);
                            stageConfig = rmfield(stageConfig,fieldName);
                        end
                    end
                    if ~isempty(fieldnames(stageConfig))
                        patch.precompute = stageConfig;
                    end
                case {'pullDose','sampling'}
                    patch = planWorkflow.config.StageConfigSchema.mapFields( ...
                        stageConfig, ...
                        planWorkflow.config.StageConfigSchema.fieldMap( ...
                        stageName));
                otherwise
                    patch = struct();
            end
        end

        function stageConfig = mapFromRunConfig(stageName,fields,runConfig)
            stageName = ...
                planWorkflow.config.StageConfigSchema.canonicalStageName( ...
                stageName);
            stageConfig = struct();
            for fieldIx = 1:numel(fields)
                fieldName = fields{fieldIx};
                [configField,value] = ...
                    planWorkflow.config.StageConfigSchema.valueFromRunConfig( ...
                    stageName,fieldName,runConfig);
                if isempty(configField)
                    continue;
                end
                stageConfig.(configField) = value;
            end
        end

        function [configField,value] = valueFromRunConfig( ...
                stageName,fieldName,runConfig)
            configField = fieldName;
            switch char(stageName)
                case 'precompute'
                    if any(strcmp(fieldName,{'reference','robustPlans'}))
                        if isfield(runConfig,'precompute') && ...
                                isfield(runConfig.precompute,fieldName)
                            value = runConfig.precompute.(fieldName);
                        else
                            configField = '';
                            value = [];
                        end
                    else
                        [configField,value] = ...
                            planWorkflow.config.StageConfigSchema.simpleField( ...
                            runConfig,fieldName);
                    end
                case {'pullDose','sampling'}
                    targetField = ...
                        planWorkflow.config.StageConfigSchema.targetField( ...
                        stageName,fieldName);
                    [configField,value] = ...
                        planWorkflow.config.StageConfigSchema.simpleField( ...
                        runConfig,targetField);
                    if ~isempty(configField)
                        configField = fieldName;
                    end
                case 'analysis'
                    if isfield(runConfig,'analysis') && ...
                            isfield(runConfig.analysis,fieldName)
                        value = runConfig.analysis.(fieldName);
                    else
                        configField = '';
                        value = [];
                    end
                otherwise
                    [configField,value] = ...
                        planWorkflow.config.StageConfigSchema.simpleField( ...
                        runConfig,fieldName);
            end
        end
    end

    methods (Static, Access = private)
        function output = mapFields(input,fieldMap)
            output = struct();
            for i = 1:size(fieldMap,1)
                sourceField = fieldMap{i,1};
                targetField = fieldMap{i,2};
                if isfield(input,sourceField)
                    output.(targetField) = input.(sourceField);
                end
            end
        end

        function [configField,value] = simpleField(runConfig,fieldName)
            configField = fieldName;
            if ~isfield(runConfig,fieldName)
                configField = '';
                value = [];
                return;
            end
            value = runConfig.(fieldName);
        end

        function fieldName = scenarioSourceName(fieldName)
            if strcmp(fieldName,'scen_mode')
                fieldName = 'mode';
            end
        end
    end
end
