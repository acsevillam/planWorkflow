classdef WorkflowRuntime
    % WorkflowRuntime Minimal operational callbacks shared by stages.
    %
    % Stage-specific paths, caches, templates and analysis services are built
    % by the owning stage. This port only exposes lifecycle callbacks that
    % belong to the workflow runner itself.

    properties (Access = private)
        TaskRunner
        LogFn
        ReportGuiStageProgressFn
        CheckpointFn
    end

    methods
        function obj = WorkflowRuntime(taskRunner,logFn, ...
                reportGuiStageProgressFn,checkpointFn)
            if nargin < 3 || isempty(reportGuiStageProgressFn)
                reportGuiStageProgressFn = @(varargin) [];
            end
            if nargin < 4 || isempty(checkpointFn)
                checkpointFn = @(varargin) [];
            end
            obj.TaskRunner = taskRunner;
            obj.LogFn = logFn;
            obj.ReportGuiStageProgressFn = reportGuiStageProgressFn;
            obj.CheckpointFn = checkpointFn;

            planWorkflow.stages.ContextValidator.requireFunctionHandle( ...
                taskRunner,'runtime','runMeasuredPlanTask');
            planWorkflow.stages.ContextValidator.requireFunctionHandle( ...
                logFn,'runtime','log');
            planWorkflow.stages.ContextValidator.requireFunctionHandle( ...
                reportGuiStageProgressFn,'runtime', ...
                'reportGuiStageProgress');
            planWorkflow.stages.ContextValidator.requireFunctionHandle( ...
                checkpointFn,'runtime','checkpoint');
        end

        function fn = taskRunner(obj)
            fn = obj.TaskRunner;
        end

        function fn = logFn(obj)
            fn = obj.LogFn;
        end

        function fn = reportGuiStageProgressFn(obj)
            fn = obj.ReportGuiStageProgressFn;
        end

        function fn = checkpointFn(obj)
            fn = obj.CheckpointFn;
        end
    end

    methods (Static)
        function tf = isRuntime(value)
            tf = isa(value,'planWorkflow.stages.WorkflowRuntime');
        end

        function require(runtime)
            if ~planWorkflow.stages.WorkflowRuntime.isRuntime(runtime)
                error(['planWorkflow:stages:WorkflowRuntime:' ...
                    'InvalidRuntime'], ...
                    'Expected a planWorkflow.stages.WorkflowRuntime.');
            end
        end
    end
end
