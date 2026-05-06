classdef ContextValidator
    % ContextValidator Validates stage context mechanics without stage schemas.

    methods (Static)
        function context = base(stageName,runConfig,stageData,taskRunner,logFn)
            context = struct();
            context.stageName = char(stageName);
            context.runConfig = runConfig;
            context.data = stageData;
            context.log = logFn;
            context.runMeasuredPlanTask = taskRunner;
            planWorkflow.stages.ContextValidator.requireFields( ...
                context,{'runConfig','data','log', ...
                'runMeasuredPlanTask'},char(stageName));
            planWorkflow.stages.ContextValidator.requireFunctionHandle( ...
                taskRunner,char(stageName),'runMeasuredPlanTask');
            planWorkflow.stages.ContextValidator.requireFunctionHandle( ...
                logFn,char(stageName),'log');
        end

        function requireFields(context,fieldNames,stageName)
            if ~isstruct(context) || ~isscalar(context)
                error(['planWorkflow:stages:ContextValidator:' ...
                    'InvalidContext'], ...
                    'Stage "%s" requires a scalar context struct.', ...
                    char(stageName));
            end
            for fieldIx = 1:numel(fieldNames)
                fieldName = fieldNames{fieldIx};
                if ~isfield(context,fieldName) || ...
                        isempty(context.(fieldName))
                    error(['planWorkflow:stages:ContextValidator:' ...
                        'MissingDependency'], ...
                        'Stage "%s" requires context.%s.', ...
                        char(stageName),fieldName);
                end
            end
        end

        function stageData = dataSlice(data,requiredFields,optionalFields,stageName)
            if nargin < 3
                optionalFields = {};
            end
            if nargin < 4
                stageName = 'stage';
            end
            if isempty(data)
                data = struct();
            end
            if ~isstruct(data) || ~isscalar(data)
                error(['planWorkflow:stages:ContextValidator:' ...
                    'InvalidData'], ...
                    'Stage "%s" requires workflow data to be a scalar struct.', ...
                    char(stageName));
            end

            for fieldIx = 1:numel(requiredFields)
                fieldName = requiredFields{fieldIx};
                if ~isfield(data,fieldName) || isempty(data.(fieldName))
                    error(['planWorkflow:stages:ContextValidator:' ...
                        'MissingData'], ...
                        'Stage "%s" requires data.%s.', ...
                        char(stageName),char(fieldName));
                end
            end

            fieldNames = [requiredFields optionalFields];
            stageData = struct();
            for fieldIx = 1:numel(fieldNames)
                fieldName = fieldNames{fieldIx};
                if isfield(data,fieldName)
                    stageData.(fieldName) = data.(fieldName);
                end
            end
        end

        function requireFunctionHandle(value,stageName,fieldName)
            if ~isa(value,'function_handle')
                error(['planWorkflow:stages:ContextValidator:' ...
                    'InvalidDependency'], ...
                    'Stage "%s" requires context.%s to be a function handle.', ...
                    char(stageName),char(fieldName));
            end
        end

        function requireObjectMethods(value,methodNames,contextName)
            for methodIx = 1:numel(methodNames)
                methodName = methodNames{methodIx};
                if ~ismethod(value,methodName)
                    error(['planWorkflow:stages:ContextValidator:' ...
                        'MissingDependency'], ...
                        '%s must implement method %s.', ...
                        char(contextName),methodName);
                end
            end
        end

        function template = planTemplate(runConfig,data)
            if isstruct(data) && isfield(data,'planTemplate') && ...
                    ~isempty(data.planTemplate)
                template = data.planTemplate;
                return;
            end

            template = planWorkflow.templates.PlanTemplate.resolve( ...
                runConfig);
        end
    end
end
