classdef DosePulling
    % DosePulling Runs objective dose-pulling without Engine-shaped deps.

    methods (Static)
        function context = defaultContext(runConfig,logFn)
            context = planWorkflow.precompute.DosePulling.context( ...
                runConfig, ...
                @(dij,cst,pln,initialWeights) ...
                planWorkflow.precompute.DosePullingOptimizer.run( ...
                runConfig,dij,cst,pln,initialWeights), ...
                @(ct,cst,stf,pln,resultGUI,showFigures) ...
                planWorkflow.precompute.DosePullingAnalyzer.run( ...
                runConfig,ct,cst,stf,pln,resultGUI,showFigures), ...
                @(cst,pln,resultGUI,ctScenProb,iteration,robustData) ...
                planWorkflow.precompute.DosePullingMetrics.robust( ...
                runConfig,cst,pln,resultGUI,ctScenProb,iteration, ...
                robustData), ...
                @(metrics) ...
                planWorkflow.precompute.DosePullingPolicy.robustNeedsUpdate( ...
                runConfig,metrics), ...
                logFn);
        end

        function context = context(runConfig,optimizer,analyzer,metrics, ...
                policy,logger)
            context = struct();
            context.runConfig = runConfig;
            context.optimizer = ...
                planWorkflow.precompute.DosePulling.requireFunction( ...
                optimizer,'optimizer');
            context.analyzer = ...
                planWorkflow.precompute.DosePulling.requireFunction( ...
                analyzer,'analyzer');
            context.metrics = ...
                planWorkflow.precompute.DosePulling.requireFunction( ...
                metrics,'metrics');
            context.policy = ...
                planWorkflow.precompute.DosePulling.requireFunction( ...
                policy,'policy');
            context.log = planWorkflow.precompute.DosePulling.requireFunction( ...
                logger,'logger');
        end

        function [cst,report] = runReference(context,ct,cst,dij,stf,pln)
            runConfig = context.runConfig;
            maxIterations = runConfig.dose_pulling_max_iter;
            targetNames = ...
                planWorkflow.precompute.DosePullingUtils.asCellstr( ...
                runConfig.dose_pulling1_target);
            criteria = ...
                planWorkflow.precompute.DosePullingUtils.expandCellToCount( ...
                runConfig.dose_pulling1_criteria,numel(targetNames), ...
                'dose_pulling1_criteria');
            limits = ...
                planWorkflow.precompute.DosePullingUtils.expandNumericToCount( ...
                runConfig.dose_pulling1_limit,numel(targetNames), ...
                'dose_pulling1_limit');

            resultGUI = context.optimizer(dij,cst,pln,[]);
            [resultGUI,dvh,qi] = context.analyzer(ct,cst,stf,pln, ...
                resultGUI,false);
            targetIx = ...
                planWorkflow.precompute.DosePullingUtils.findQiTargets( ...
                qi,targetNames);
            history = planWorkflow.precompute.DosePulling.referenceHistory( ...
                qi,targetIx,criteria,0,targetNames,limits);
            planWorkflow.precompute.DosePulling.logReferenceProgress( ...
                context,history(end),'initial');

            iteration = runConfig.dose_pulling1_start + 1;
            while iteration <= maxIterations && ...
                    planWorkflow.precompute.DosePulling.referenceNeedsUpdate( ...
                    qi,targetIx,criteria,limits)
                [cst,optimizationFlag] = planWorkflow.structures.pullDose( ...
                    cst,1);
                if ~optimizationFlag
                    context.log(sprintf(['Dose pulling step 1 stopped at ' ...
                        'iteration %d because planWorkflow.structures.' ...
                        'pullDose did not update any objective.'], ...
                        iteration));
                    break;
                end

                resultGUI = context.optimizer(dij,cst,pln,resultGUI.w);
                [resultGUI,dvh,qi] = context.analyzer( ...
                    ct,cst,stf,pln,resultGUI,false);
                history(end + 1) = ...
                    planWorkflow.precompute.DosePulling.referenceHistory( ...
                    qi,targetIx,criteria,iteration,targetNames,limits); %#ok<AGROW>
                planWorkflow.precompute.DosePulling.logReferenceProgress( ...
                    context,history(end),'after pull');
                iteration = iteration + 1;
            end

            converged = ...
                ~planWorkflow.precompute.DosePulling.referenceNeedsUpdate( ...
                qi,targetIx,criteria,limits);
            planWorkflow.precompute.DosePulling.logSummary( ...
                context,1,converged,numel(history) - 1);

            report = struct();
            report.initialWeights = resultGUI.w;
            report.dvh = dvh;
            report.qi = qi;
            report.history = history;
            report.converged = converged;
            report.iterations = numel(history) - 1;
        end

        function [robustData,report] = runRobust(context,robustData)
            runConfig = context.runConfig;
            maxIterations = runConfig.dose_pulling_max_iter;
            numVariants = numel(robustData.planConfig.variants);
            robustData.initialWeights = cell(1,numVariants);

            report = struct();
            report.plans = cell(1,numVariants);

            cst = robustData.cst;
            previousWeights = cell(1,numVariants);
            histories = cell(1,numVariants);
            [resultGUIByVariant,metricsByVariant,histories] = ...
                planWorkflow.precompute.DosePulling.evaluateRobustVariants( ...
                context,robustData,cst,previousWeights,0,histories, ...
                numVariants,'initial');

            iteration = runConfig.dose_pulling2_start + 1;
            while iteration <= maxIterations && ...
                    planWorkflow.precompute.DosePulling.anyRobustVariantNeedsUpdate( ...
                    context,metricsByVariant)
                [cst,optimizationFlag] = ...
                    planWorkflow.structures.pullDose(cst,2);
                if ~optimizationFlag
                    context.log(sprintf(['Dose pulling step 2 stopped at ' ...
                        'iteration %d because planWorkflow.structures.' ...
                        'pullDose did not update any objective.'], ...
                        iteration));
                    break;
                end

                previousWeights = ...
                    planWorkflow.precompute.DosePulling.resultWeights( ...
                    resultGUIByVariant);
                [resultGUIByVariant,metricsByVariant,histories] = ...
                    planWorkflow.precompute.DosePulling.evaluateRobustVariants( ...
                    context,robustData,cst,previousWeights,iteration, ...
                    histories,numVariants,'after pull');
                iteration = iteration + 1;
            end

            robustData.cst = cst;
            robustData.initialWeights = ...
                planWorkflow.precompute.DosePulling.resultWeights( ...
                resultGUIByVariant);
            for variantIx = 1:numVariants
                history = histories{variantIx};
                metrics = metricsByVariant{variantIx};
                converged = ~context.policy(metrics);
                planWorkflow.precompute.DosePulling.logSummary( ...
                    context,2,converged,numel(history) - 1,variantIx, ...
                    numVariants);

                report.plans{variantIx} = struct( ...
                    'history',history, ...
                    'converged',converged, ...
                    'iterations',numel(history) - 1);
            end
        end
    end

    methods (Static, Access = private)
        function [resultGUIByVariant,metricsByVariant,histories] = ...
                evaluateRobustVariants(context,robustData,cst, ...
                previousWeights,iteration,histories,numVariants,label)
            resultGUIByVariant = cell(1,numVariants);
            metricsByVariant = cell(1,numVariants);
            for variantIx = 1:numVariants
                planForOptimization = ...
                    planWorkflow.optimization.VariantPlanFactory.build( ...
                    robustData,variantIx);
                initialWeights = [];
                if numel(previousWeights) >= variantIx
                    initialWeights = previousWeights{variantIx};
                end
                resultGUI = context.optimizer( ...
                    robustData.dij,cst,planForOptimization,initialWeights);
                resultGUIByVariant{variantIx} = resultGUI;
                metrics = context.metrics( ...
                    cst,planForOptimization,resultGUI, ...
                    robustData.ctScenProb,iteration,robustData);
                metrics.planIndex = variantIx;
                metricsByVariant{variantIx} = metrics;
                histories{variantIx} = ...
                    planWorkflow.precompute.DosePulling.appendHistory( ...
                    histories{variantIx},metrics);
                planWorkflow.precompute.DosePulling.logRobustProgress( ...
                    context,metrics,variantIx,numVariants,label);
            end
        end

        function history = appendHistory(history,metrics)
            if isempty(history)
                history = metrics;
            else
                history(end + 1) = metrics;
            end
        end

        function tf = anyRobustVariantNeedsUpdate(context,metricsByVariant)
            tf = false;
            for variantIx = 1:numel(metricsByVariant)
                if context.policy(metricsByVariant{variantIx})
                    tf = true;
                    return;
                end
            end
        end

        function weights = resultWeights(resultGUIByVariant)
            weights = cell(1,numel(resultGUIByVariant));
            for variantIx = 1:numel(resultGUIByVariant)
                resultGUI = resultGUIByVariant{variantIx};
                if isstruct(resultGUI) && isfield(resultGUI,'w')
                    weights{variantIx} = resultGUI.w;
                end
            end
        end

        function history = referenceHistory(qi,targetIx,criteria, ...
                iteration,targetNames,limits)
            values = zeros(1,numel(targetIx));
            for i = 1:numel(targetIx)
                values(i) = qi(targetIx(i)).(criteria{i});
            end

            history = struct();
            history.step = 1;
            history.iteration = iteration;
            history.targetNames = targetNames;
            history.criteria = criteria;
            history.limits = limits;
            history.values = values;
            history.isSatisfied = all(values >= limits);
        end

        function tf = referenceNeedsUpdate(qi,targetIx,criteria,limits)
            values = zeros(1,numel(targetIx));
            for i = 1:numel(targetIx)
                values(i) = qi(targetIx(i)).(criteria{i});
            end
            tf = any(values < limits);
        end

        function logReferenceProgress(context,entry,label)
            if entry.iteration == 0
                iterationText = 'initial criteria';
            else
                iterationText = sprintf('%s, iteration %d',label,entry.iteration);
            end
            context.log(sprintf('Dose pulling step 1 %s: %s.', ...
                iterationText, ...
                planWorkflow.precompute.DosePulling.formatCriteria( ...
                entry.targetNames,entry.criteria,entry.values,entry.limits)));
        end

        function logRobustProgress(context,metrics,planIx,numPlans,label)
            if metrics.iteration == 0
                iterationText = 'initial criteria';
            else
                iterationText = sprintf('%s, iteration %d',label,metrics.iteration);
            end
            context.log(sprintf('Dose pulling step 2 plan %d/%d %s: %s.', ...
                planIx,numPlans,iterationText, ...
                planWorkflow.precompute.DosePulling.formatRobustCriteria( ...
                metrics)));
        end

        function logSummary(context,step,converged,numPulls,planIx,numPlans)
            if converged
                statusText = 'converged';
            else
                statusText = 'stopped without convergence';
            end

            if nargin < 5
                context.log(sprintf('Dose pulling step %d %s after %d pulls.', ...
                    step,statusText,numPulls));
            else
                context.log(sprintf(['Dose pulling step %d plan %d/%d %s after ' ...
                    '%d pulls.'],step,planIx,numPlans,statusText,numPulls));
            end
        end

        function text = formatCriteria(targetNames,criteria,values,limits)
            parts = cell(1,numel(values));
            for i = 1:numel(values)
                if values(i) >= limits(i)
                    statusText = 'ok';
                else
                    statusText = 'below limit';
                end
                parts{i} = sprintf('%s(%s)=%.6g, limit=%.6g, gap=%+.6g [%s]', ...
                    criteria{i},targetNames{i},values(i),limits(i), ...
                    values(i) - limits(i),statusText);
            end
            text = strjoin(parts,'; ');
        end

        function text = formatRobustCriteria(metrics)
            parts = cell(1,numel(metrics.selectedValues));
            for i = 1:numel(metrics.selectedValues)
                if metrics.selectedValues(i) >= metrics.limits(i)
                    statusText = 'ok';
                else
                    statusText = 'below limit';
                end

                if strcmp(metrics.selectedCriterion,'meanQiTarget')
                    companionText = sprintf('minQiTarget=%.6g', ...
                        metrics.minQiTarget(i));
                else
                    companionText = sprintf('meanQiTarget=%.6g', ...
                        metrics.meanQiTarget(i));
                end

                parts{i} = sprintf(['%s(%s/%s)=%.6g, %s, limit=%.6g, ' ...
                    'gap=%+.6g [%s]'],metrics.selectedCriterion, ...
                    metrics.targetNames{i},metrics.criteria{i}, ...
                    metrics.selectedValues(i),companionText,metrics.limits(i), ...
                    metrics.selectedValues(i) - metrics.limits(i),statusText);
            end
            text = strjoin(parts,'; ');
        end

        function value = requireFunction(value,name)
            if ~isa(value,'function_handle')
                error('planWorkflow:precompute:DosePulling:InvalidContext', ...
                    'DosePulling context requires function "%s".',name);
            end
        end
    end
end
