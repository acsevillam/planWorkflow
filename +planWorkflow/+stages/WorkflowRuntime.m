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
    end

    methods
        function obj = WorkflowRuntime(taskRunner,logFn, ...
                reportGuiStageProgressFn)
            if nargin < 3 || isempty(reportGuiStageProgressFn)
                reportGuiStageProgressFn = @(varargin) [];
            end
            obj.TaskRunner = taskRunner;
            obj.LogFn = logFn;
            obj.ReportGuiStageProgressFn = reportGuiStageProgressFn;

            planWorkflow.stages.ContextValidator.requireFunctionHandle( ...
                taskRunner,'runtime','runMeasuredPlanTask');
            planWorkflow.stages.ContextValidator.requireFunctionHandle( ...
                logFn,'runtime','log');
            planWorkflow.stages.ContextValidator.requireFunctionHandle( ...
                reportGuiStageProgressFn,'runtime', ...
                'reportGuiStageProgress');
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
