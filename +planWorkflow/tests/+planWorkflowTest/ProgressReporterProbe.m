classdef ProgressReporterProbe < handle
    % ProgressReporterProbe Captures GUI progress calls for tests.

    properties
        Events = {}
        Messages = {}
        Results = []
        LastFraction = 0
        StopRequested = false
    end

    methods
        function stageStarted(obj,stageName,index,total)
            obj.Events{end + 1} = { ...
                'stageStarted',stageName,index,total};
            obj.LastFraction = (index - 1) / total;
        end

        function stageProgress(obj,stageName,fraction,message) %#ok<INUSD>
            obj.Events{end + 1} = { ...
                'stageProgress',stageName,fraction};
            obj.LastFraction = fraction;
        end

        function stageCompleted(obj,stageName,index,total,wallTimeSeconds) %#ok<INUSD>
            obj.Events{end + 1} = { ...
                'stageCompleted',stageName,index,total};
            obj.LastFraction = index / total;
        end

        function stageFailed(obj,stageName,index,total,message) %#ok<INUSD>
            obj.Events{end + 1} = { ...
                'stageFailed',stageName,index,total};
            obj.LastFraction = (index - 1) / total;
        end

        function log(obj,message)
            obj.Messages{end + 1} = char(message);
        end

        function showResults(obj,results)
            obj.Events{end + 1} = {'showResults'};
            obj.Results = results;
        end

        function requestStop(obj)
            obj.StopRequested = true;
        end

        function tf = isStopRequested(obj)
            tf = obj.StopRequested;
        end
    end
end
