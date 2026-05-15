classdef DosePullingStepSearch
    % DosePullingStepSearch Evaluates candidate dose-pulling steps.

    methods (Static)
        function search = run(runConfig,initialState,evaluator)
            maxIter = runConfig.dose_pulling_max_iter;
            targetTol = runConfig.dose_pulling_target_tol;
            localWindow = runConfig.dose_pulling_local_window;
            patience = runConfig.dose_pulling_patience;
            schedule = ...
                planWorkflow.precompute.DosePullingStepSearch.coarseSchedule( ...
                runConfig,maxIter);

            [results,states,stopReason] = ...
                planWorkflow.precompute.DosePullingStepSearch.runCoarseSearch( ...
                evaluator,initialState,schedule,targetTol,patience);

            results = ...
                planWorkflow.precompute.DosePullingScoring.annotateSelectionScores( ...
                results,targetTol,runConfig);
            best = planWorkflow.precompute.DosePullingScoring.chooseBest( ...
                results,targetTol,runConfig);
            [leftStep,rightStep] = ...
                planWorkflow.precompute.DosePullingStepSearch.localBracket( ...
                best.step,maxIter,localWindow);
            localCandidates = ...
                planWorkflow.precompute.DosePullingStepSearch.localWindowCandidates( ...
                leftStep,rightStep,[results.step]);

            if ~isempty(localCandidates)
                leftState = ...
                    planWorkflow.precompute.DosePullingStepSearch.stateAtOrBefore( ...
                    states,min(localCandidates));
                [localResults,localStates] = ...
                    planWorkflow.precompute.DosePullingStepSearch.runSequentialCandidates( ...
                    evaluator,leftState,localCandidates);
                [results,states] = ...
                    planWorkflow.precompute.DosePullingStepSearch.mergeResults( ...
                    results,states,localResults,localStates);
            end

            results = ...
                planWorkflow.precompute.DosePullingScoring.annotateSelectionScores( ...
                results,targetTol,runConfig);
            best = planWorkflow.precompute.DosePullingScoring.chooseBest( ...
                results,targetTol,runConfig);
            stopReason = ...
                planWorkflow.precompute.DosePullingStepSearch.canonicalStopReason( ...
                best,stopReason,maxIter);

            search = struct();
            search.results = ...
                planWorkflow.precompute.DosePullingStepSearch.sortByStep( ...
                results);
            search.states = ...
                planWorkflow.precompute.DosePullingStepSearch.sortByStep( ...
                states);
            search.best = best;
            search.bestState = ...
                planWorkflow.precompute.DosePullingStepSearch.stateAtStep( ...
                search.states,best.step);
            search.coarseSchedule = schedule;
            search.stopReason = stopReason;
            search.trace = ...
                planWorkflow.precompute.DosePullingStepSearch.traceFromResults( ...
                search.results,best,stopReason);
            search.localBracket = [leftStep rightStep];
        end

        function schedule = coarseSchedule(runConfig,maxIter)
            switch lower(char(runConfig.dose_pulling_search_schedule))
                case 'exponential'
                    schedule = unique([0 1 2 4 8 16 32 64 maxIter]);
                    schedule = schedule(schedule <= maxIter);
                otherwise
                    error(['planWorkflow:precompute:DosePulling:' ...
                        'UnknownSearchSchedule'], ...
                        'Unknown dose_pulling_search_schedule "%s".', ...
                        runConfig.dose_pulling_search_schedule);
            end
        end
    end

    methods (Static, Access = private)
        function [results,states,stopReason] = runCoarseSearch( ...
                evaluator,state,schedule,targetTol,patience)
            results = [];
            states = [];
            bestPrimary = Inf;
            misses = 0;
            stopReason = 'maxIterReached';

            for i = 1:numel(schedule)
                [state,result] = evaluator(state,schedule(i));
                results = ...
                    planWorkflow.precompute.DosePullingStepSearch.appendStruct( ...
                    results,result);
                states = ...
                    planWorkflow.precompute.DosePullingStepSearch.appendStruct( ...
                    states,state);

                if result.primaryScore < bestPrimary - targetTol^2
                    bestPrimary = result.primaryScore;
                    misses = 0;
                else
                    misses = misses + 1;
                end

                if result.primaryScore == 0
                    stopReason = 'converged';
                    break;
                end
                if misses >= patience
                    stopReason = 'stagnated';
                    break;
                end
            end
        end

        function stopReason = canonicalStopReason(best,coarseStopReason, ...
                maxIter)
            if isfield(best,'isSatisfied') && best.isSatisfied && ...
                    (~isfield(best,'isFeasible') || best.isFeasible)
                stopReason = 'converged';
                return;
            end
            if isfield(best,'isFeasible') && ~best.isFeasible
                stopReason = 'infeasible';
                return;
            end
            if strcmp(char(coarseStopReason),'stagnated')
                stopReason = 'stagnated';
                return;
            end
            if isfield(best,'step') && best.step >= maxIter
                stopReason = 'maxIterReached';
                return;
            end
            stopReason = 'maxIterReached';
        end

        function trace = traceFromResults(results,best,stopReason)
            trace = struct('step',{},'metrics',{},'isFeasible',{}, ...
                'candidate',{},'isSelected',{},'stopReason',{});
            for i = 1:numel(results)
                result = results(i);
                metrics = struct();
                fields = {'values','limits','primaryScore','limitDiffSq', ...
                    'oarScore','isSatisfied','selectionScore', ...
                    'targetScore','oarPenaltyScore','stepPenaltyScore'};
                for fieldIx = 1:numel(fields)
                    fieldName = fields{fieldIx};
                    if isfield(result,fieldName)
                        metrics.(fieldName) = result.(fieldName);
                    end
                end
                trace(i).step = result.step; %#ok<AGROW>
                trace(i).metrics = metrics;
                if isfield(result,'isFeasible')
                    trace(i).isFeasible = result.isFeasible;
                else
                    trace(i).isFeasible = true;
                end
                trace(i).candidate = ...
                    planWorkflow.precompute.DosePullingStepSearch.candidateSummary( ...
                    result);
                trace(i).isSelected = result.step == best.step;
                trace(i).stopReason = char(stopReason);
            end
        end

        function candidate = candidateSummary(result)
            candidate = struct();
            fields = {'targetNames','criteria','criteriaLabels', ...
                'selectedCriterion','meanQiTarget','minQiTarget', ...
                'rectumPull','bladderPull','channelObjective'};
            for fieldIx = 1:numel(fields)
                fieldName = fields{fieldIx};
                if isfield(result,fieldName)
                    candidate.(fieldName) = result.(fieldName);
                end
            end
        end

        function [results,states] = runSequentialCandidates( ...
                evaluator,state,candidates)
            candidates = sort(candidates);
            results = [];
            states = [];
            for i = 1:numel(candidates)
                [state,result] = evaluator(state,candidates(i));
                results = ...
                    planWorkflow.precompute.DosePullingStepSearch.appendStruct( ...
                    results,result);
                states = ...
                    planWorkflow.precompute.DosePullingStepSearch.appendStruct( ...
                    states,state);
            end
        end

        function [leftStep,rightStep] = localBracket( ...
                bestStep,maxIter,localWindow)
            leftStep = max(0,bestStep - localWindow);
            rightStep = min(maxIter,bestStep + localWindow);
        end

        function candidates = localWindowCandidates( ...
                leftStep,rightStep,evaluatedSteps)
            candidates = leftStep:rightStep;
            candidates(ismember(candidates,evaluatedSteps)) = [];
        end

        function [results,states] = mergeResults( ...
                results,states,newResults,newStates)
            for i = 1:numel(newResults)
                ix = find([results.step] == newResults(i).step,1);
                if isempty(ix)
                    results = ...
                        planWorkflow.precompute.DosePullingStepSearch.appendStruct( ...
                        results,newResults(i));
                    states = ...
                        planWorkflow.precompute.DosePullingStepSearch.appendStruct( ...
                        states,newStates(i));
                else
                    results(ix) = newResults(i);
                    states(ix) = newStates(i);
                end
            end
        end

        function array = appendStruct(array,item)
            if isempty(array)
                array = item;
            else
                item = orderfields(item,array(1));
                array(end + 1) = item;
            end
        end

        function sorted = sortByStep(values)
            if isempty(values)
                sorted = values;
                return;
            end
            [~,ix] = sort([values.step]);
            sorted = values(ix);
        end

        function state = stateAtOrBefore(states,step)
            steps = [states.step];
            eligible = find(steps <= step);
            if isempty(eligible)
                error(['planWorkflow:precompute:DosePulling:' ...
                    'MissingStepState'], ...
                    'No dose-pulling state exists at or before step %d.', ...
                    step);
            end
            [~,localIx] = max(steps(eligible));
            state = states(eligible(localIx));
        end

        function state = stateAtStep(states,step)
            ix = find([states.step] == step,1);
            if isempty(ix)
                state = ...
                    planWorkflow.precompute.DosePullingStepSearch.stateAtOrBefore( ...
                    states,step);
            else
                state = states(ix);
            end
        end
    end
end
