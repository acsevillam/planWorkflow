classdef ResourceSampler < handle
    % ResourceSampler Samples RSS for the MATLAB process tree via ps.

    properties (Access = private)
        config
        pid
        timerHandle = []
        samples
        lastUnavailableCause = ''
        isFinished = false
    end

    methods (Static)
        function sampler = start(config)
            if nargin < 1
                config = struct();
            end
            sampler = planWorkflow.resources.ResourceSampler(config);
            sampler.startInternal();
        end

        function summary = disabledSummary()
            summary = planWorkflow.resources.ResourceSampler.emptySummary();
            summary.enabled = false;
            summary.source = 'disabled';
        end

        function summary = summaryFromSamples(samples,keepSamples)
            if nargin < 2
                keepSamples = false;
            end
            summary = planWorkflow.resources.ResourceSampler.emptySummary();
            summary.enabled = true;
            summary.source = 'process_tree_rss_ps';
            summary.sampleCount = numel(samples);
            if isempty(samples)
                summary.source = 'unavailable';
                summary.unavailableCause = 'No resource samples were recorded.';
                return;
            end

            valid = [samples.available];
            if ~any(valid)
                summary.source = 'unavailable';
                causes = {samples.unavailableCause};
                causes = causes(~cellfun(@isempty,causes));
                if isempty(causes)
                    summary.unavailableCause = ...
                        'No process-tree RSS sample was available.';
                else
                    summary.unavailableCause = causes{end};
                end
                return;
            end

            validSamples = samples(valid);
            summary.startMainProcessMemoryBytes = ...
                validSamples(1).mainProcessMemoryBytes;
            summary.endMainProcessMemoryBytes = ...
                validSamples(end).mainProcessMemoryBytes;
            summary.highWaterMainProcessMemoryBytes = max( ...
                [validSamples.mainProcessMemoryBytes]);
            summary.startChildProcessMemoryBytes = ...
                validSamples(1).childProcessMemoryBytes;
            summary.endChildProcessMemoryBytes = ...
                validSamples(end).childProcessMemoryBytes;
            summary.highWaterChildProcessMemoryBytes = max( ...
                [validSamples.childProcessMemoryBytes]);
            summary.startTotalProcessMemoryBytes = ...
                validSamples(1).totalProcessMemoryBytes;
            summary.endTotalProcessMemoryBytes = ...
                validSamples(end).totalProcessMemoryBytes;
            summary.highWaterTotalProcessMemoryBytes = max( ...
                [validSamples.totalProcessMemoryBytes]);
            summary.childProcessBuckets = ...
                planWorkflow.resources.ResourceSampler.summarizeChildBuckets( ...
                validSamples);
            if keepSamples
                summary.samples = samples;
            end
        end

        function sample = processTreeSample(pid,includeChildProcesses)
            if nargin < 2
                includeChildProcesses = true;
            end
            sample = planWorkflow.resources.ResourceSampler.emptySample();
            sample.timestamp = char(datetime('now','Format', ...
                'yyyy-MM-dd HH:mm:ss.SSS'));
            sample.source = 'process_tree_rss_ps';

            try
                [status,output] = system('ps -axo pid=,ppid=,rss=,comm=');
                if status ~= 0 || isempty(output)
                    sample.unavailableCause = ...
                        'ps command did not return process data.';
                    return;
                end
                table = planWorkflow.resources.ResourceSampler.parsePs(output);
                pid = double(pid);
                mainIx = find([table.pid] == pid,1);
                if isempty(mainIx)
                    sample.unavailableCause = sprintf( ...
                        'Process %d was not present in ps output.',pid);
                    return;
                end
                childPids = [];
                if includeChildProcesses
                    childPids = ...
                        planWorkflow.resources.ResourceSampler.descendantPids( ...
                        table,pid);
                end
                sample.available = true;
                sample.mainPid = pid;
                sample.childPids = childPids;
                sample.mainProcessMemoryBytes = ...
                    double(table(mainIx).rssKb) * 1024;
                childBytes = 0;
                buckets = ...
                    planWorkflow.resources.ResourceSampler.emptyChildBuckets();
                for i = 1:numel(childPids)
                    childIx = find([table.pid] == childPids(i),1);
                    if ~isempty(childIx)
                        childRssBytes = double(table(childIx).rssKb) * 1024;
                        childBytes = childBytes + childRssBytes;
                        bucketName = ...
                            planWorkflow.resources.ResourceSampler.childBucket( ...
                            table(childIx).command);
                        buckets = ...
                            planWorkflow.resources.ResourceSampler.addChildBucket( ...
                            buckets,bucketName,childRssBytes);
                    end
                end
                sample.childProcessMemoryBytes = childBytes;
                sample.totalProcessMemoryBytes = ...
                    sample.mainProcessMemoryBytes + childBytes;
                sample.childProcessBuckets = buckets;
            catch ME
                sample.unavailableCause = ME.message;
            end
        end

        function summary = emptySummary()
            summary = struct();
            summary.enabled = true;
            summary.source = 'unavailable';
            summary.unavailableCause = '';
            summary.sampleCount = 0;
            summary.startMainProcessMemoryBytes = NaN;
            summary.endMainProcessMemoryBytes = NaN;
            summary.highWaterMainProcessMemoryBytes = NaN;
            summary.startChildProcessMemoryBytes = NaN;
            summary.endChildProcessMemoryBytes = NaN;
            summary.highWaterChildProcessMemoryBytes = NaN;
            summary.startTotalProcessMemoryBytes = NaN;
            summary.endTotalProcessMemoryBytes = NaN;
            summary.highWaterTotalProcessMemoryBytes = NaN;
            summary.childProcessBuckets = ...
                planWorkflow.resources.ResourceSampler.emptyChildBucketSummary();
            summary.samples = [];
        end
    end

    methods
        function obj = ResourceSampler(config)
            if isstruct(config) && isfield(config,'memory')
                resources = planWorkflow.config.Resources.normalize(config);
                obj.config = resources.memory;
            else
                obj.config = planWorkflow.config.Resources.normalize( ...
                    struct('memory',config)).memory;
            end
            obj.pid = feature('getpid');
            obj.samples = ...
                planWorkflow.resources.ResourceSampler.emptySample();
            obj.samples(:) = [];
        end

        function delete(obj)
            obj.stopTimer();
        end

        function summary = finish(obj)
            if obj.isFinished
                summary = obj.summary();
                return;
            end
            if obj.config.enabled
                obj.sampleNow();
            end
            obj.stopTimer();
            obj.isFinished = true;
            summary = obj.summary();
        end

        function summary = summary(obj)
            if ~obj.config.enabled
                summary = ...
                    planWorkflow.resources.ResourceSampler.disabledSummary();
                return;
            end
            summary = planWorkflow.resources.ResourceSampler.summaryFromSamples( ...
                obj.samples,obj.config.keepSamples);
            if strcmp(summary.source,'unavailable') && ...
                    ~isempty(obj.lastUnavailableCause)
                summary.unavailableCause = obj.lastUnavailableCause;
            end
        end
    end

    methods (Access = private)
        function startInternal(obj)
            if ~obj.config.enabled
                return;
            end
            obj.sampleNow();
            if obj.config.samplePeriodSeconds <= 0
                return;
            end
            try
                obj.timerHandle = timer( ...
                    'ExecutionMode','fixedSpacing', ...
                    'Period',obj.config.samplePeriodSeconds, ...
                    'BusyMode','drop', ...
                    'TimerFcn',@(~,~) obj.sampleNow());
                start(obj.timerHandle);
            catch ME
                obj.lastUnavailableCause = ...
                    ['Timer sampling unavailable: ' ME.message];
            end
        end

        function sampleNow(obj)
            sample = planWorkflow.resources.ResourceSampler.processTreeSample( ...
                obj.pid,obj.config.includeChildProcesses);
            if ~sample.available
                obj.lastUnavailableCause = sample.unavailableCause;
            end
            obj.samples(end + 1) = sample;
        end

        function stopTimer(obj)
            try
                if ~isempty(obj.timerHandle) && isvalid(obj.timerHandle)
                    stop(obj.timerHandle);
                    delete(obj.timerHandle);
                end
            catch
            end
            obj.timerHandle = [];
        end
    end

    methods (Static, Access = private)
        function sample = emptySample()
            sample = struct();
            sample.timestamp = '';
            sample.source = 'process_tree_rss_ps';
            sample.available = false;
            sample.unavailableCause = '';
            sample.mainPid = NaN;
            sample.childPids = [];
            sample.mainProcessMemoryBytes = NaN;
            sample.childProcessMemoryBytes = NaN;
            sample.totalProcessMemoryBytes = NaN;
            sample.childProcessBuckets = ...
                planWorkflow.resources.ResourceSampler.emptyChildBuckets();
        end

        function buckets = emptyChildBuckets()
            buckets = struct();
            bucketNames = ...
                planWorkflow.resources.ResourceSampler.childBucketNames();
            for bucketIx = 1:numel(bucketNames)
                bucketName = bucketNames{bucketIx};
                buckets.([bucketName 'MemoryBytes']) = 0;
                buckets.([bucketName 'Count']) = 0;
            end
        end

        function summary = emptyChildBucketSummary()
            summary = struct();
            bucketNames = ...
                planWorkflow.resources.ResourceSampler.childBucketNames();
            for bucketIx = 1:numel(bucketNames)
                bucketName = bucketNames{bucketIx};
                summary.(bucketName) = struct( ...
                    'startMemoryBytes',NaN, ...
                    'endMemoryBytes',NaN, ...
                    'highWaterMemoryBytes',NaN, ...
                    'startCount',NaN, ...
                    'endCount',NaN, ...
                    'highWaterCount',NaN);
            end
        end

        function names = childBucketNames()
            names = {'parallelWorker','windowRenderer', ...
                'matlabHelper','other'};
        end

        function bucketName = childBucket(command)
            command = lower(char(command));
            if contains(command,'matlabwindowhelper') || ...
                    contains(command,'renderer')
                bucketName = 'windowRenderer';
            elseif contains(command,'matlab') && ...
                    (contains(command,'worker') || ...
                    contains(command,'parallel') || ...
                    contains(command,'maci64'))
                bucketName = 'parallelWorker';
            elseif contains(command,'matlab')
                bucketName = 'matlabHelper';
            else
                bucketName = 'other';
            end
        end

        function buckets = addChildBucket(buckets,bucketName,memoryBytes)
            buckets.([bucketName 'MemoryBytes']) = ...
                buckets.([bucketName 'MemoryBytes']) + memoryBytes;
            buckets.([bucketName 'Count']) = ...
                buckets.([bucketName 'Count']) + 1;
        end

        function summary = summarizeChildBuckets(samples)
            summary = ...
                planWorkflow.resources.ResourceSampler.emptyChildBucketSummary();
            if isempty(samples)
                return;
            end
            bucketNames = ...
                planWorkflow.resources.ResourceSampler.childBucketNames();
            for bucketIx = 1:numel(bucketNames)
                bucketName = bucketNames{bucketIx};
                memoryField = [bucketName 'MemoryBytes'];
                countField = [bucketName 'Count'];
                memories = zeros(1,numel(samples));
                counts = zeros(1,numel(samples));
                for sampleIx = 1:numel(samples)
                    if ~isfield(samples(sampleIx),'childProcessBuckets') || ...
                            ~isstruct(samples(sampleIx).childProcessBuckets)
                        continue;
                    end
                    buckets = samples(sampleIx).childProcessBuckets;
                    if isfield(buckets,memoryField)
                        memories(sampleIx) = buckets.(memoryField);
                    end
                    if isfield(buckets,countField)
                        counts(sampleIx) = buckets.(countField);
                    end
                end
                summary.(bucketName).startMemoryBytes = memories(1);
                summary.(bucketName).endMemoryBytes = memories(end);
                summary.(bucketName).highWaterMemoryBytes = max(memories);
                summary.(bucketName).startCount = counts(1);
                summary.(bucketName).endCount = counts(end);
                summary.(bucketName).highWaterCount = max(counts);
            end
        end

        function table = parsePs(output)
            lines = regexp(output,'\r?\n','split');
            table = struct('pid',{},'ppid',{},'rssKb',{},'command',{});
            for i = 1:numel(lines)
                line = strtrim(lines{i});
                if isempty(line)
                    continue;
                end
                tokens = regexp(line, ...
                    '^(\d+)\s+(\d+)\s+(\d+)\s*(.*)$', ...
                    'tokens','once');
                if isempty(tokens)
                    continue;
                end
                table(end + 1) = struct( ...
                    'pid',str2double(tokens{1}), ...
                    'ppid',str2double(tokens{2}), ...
                    'rssKb',str2double(tokens{3}), ...
                    'command',tokens{4}); %#ok<AGROW>
            end
        end

        function descendants = descendantPids(table,pid)
            descendants = [];
            frontier = pid;
            while ~isempty(frontier)
                children = [];
                pids = [table.pid];
                ppids = [table.ppid];
                for i = 1:numel(frontier)
                    children = [children pids(ppids == frontier(i))]; %#ok<AGROW>
                end
                children = setdiff(unique(children),[pid descendants]);
                descendants = [descendants children]; %#ok<AGROW>
                frontier = children;
            end
        end
    end
end
