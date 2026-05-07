classdef DosePullingScoring
    % DosePullingScoring Scores candidate dose-pulling steps.

    methods (Static)
        function result = resultFromValues(step,values,limits,oarScore)
            shortfall = max(0,limits - values);
            diff = values - limits;

            result = planWorkflow.precompute.DosePullingScoring.emptyResult();
            result.step = step;
            result.iteration = step;
            result.value = values(1);
            result.values = values;
            result.limit = limits(1);
            result.limits = limits;
            result.primaryScore = sum(shortfall.^2);
            result.limitDiffSq = sum(diff.^2);
            result.oarScore = oarScore;
            result.isSatisfied = all(shortfall == 0);
        end

        function results = annotateSelectionScores(results,targetTol, ...
                runConfig)
            if isempty(results)
                return;
            end

            primary = [results.primaryScore];
            oar = [results.oarScore];
            step = [results.step];
            pNorm = planWorkflow.precompute.DosePullingScoring.normalize01( ...
                primary);
            oNorm = planWorkflow.precompute.DosePullingScoring.normalize01( ...
                oar);
            stepNorm = planWorkflow.precompute.DosePullingScoring.normalize01( ...
                step);

            switch lower(char(runConfig.dose_pulling_selection_policy))
                case 'normalizedknee'
                    score = sqrt(pNorm.^2 + oNorm.^2);
                    score(primary <= targetTol^2) = ...
                        oNorm(primary <= targetTol^2);
                case 'lexicographic'
                    score = pNorm + 1e-6 * oNorm + 1e-9 * stepNorm;
                    score(primary <= targetTol^2) = ...
                        oNorm(primary <= targetTol^2) + ...
                        1e-6 * stepNorm(primary <= targetTol^2);
                case 'weightedsum'
                    targetComponent = pNorm;
                    targetComponent(primary <= targetTol^2) = 0;
                    score = ...
                        planWorkflow.precompute.DosePullingScoring.configNumber( ...
                        runConfig,'dose_pulling_target_weight',1.0) * ...
                        targetComponent + ...
                        planWorkflow.precompute.DosePullingScoring.configNumber( ...
                        runConfig,'dose_pulling_oar_weight',1.0) * oNorm + ...
                        planWorkflow.precompute.DosePullingScoring.configNumber( ...
                        runConfig,'dose_pulling_step_weight',0.0) * stepNorm;
                otherwise
                    error(['planWorkflow:precompute:DosePulling:' ...
                        'UnknownSelectionPolicy'], ...
                        'Unknown dose_pulling_selection_policy "%s".', ...
                        runConfig.dose_pulling_selection_policy);
            end

            for i = 1:numel(results)
                results(i).selectionScore = score(i) + ...
                    1e-6 * results(i).step / max(1,max([results.step]));
                if ~results(i).isFeasible
                    results(i).selectionScore = Inf;
                end
            end
        end

        function best = chooseBest(results,targetTol,runConfig)
            pool = results([results.isFeasible]);
            if isempty(pool)
                pool = results;
            end

            policy = lower(char(runConfig.dose_pulling_selection_policy));
            satisfied = pool([pool.primaryScore] <= targetTol^2);
            if ~isempty(satisfied) && ~strcmp(policy,'weightedsum')
                pool = satisfied;
            end

            switch policy
                case {'normalizedknee','lexicographic','weightedsum'}
                    score = [pool.selectionScore];
                otherwise
                    error(['planWorkflow:precompute:DosePulling:' ...
                        'UnknownSelectionPolicy'], ...
                        'Unknown dose_pulling_selection_policy "%s".', ...
                        runConfig.dose_pulling_selection_policy);
            end

            [~,ix] = min(score);
            best = pool(ix);
            ties = pool(abs([pool.selectionScore] - ...
                best.selectionScore) <= 1e-9);
            if numel(ties) > 1
                sortData = [[ties.primaryScore]' [ties.oarScore]' ...
                    [ties.step]'];
                [~,ix] = sortrows(sortData,[1 2 3]);
                best = ties(ix(1));
            end
        end

        function score = oarObjectiveScoreFromDose(cst,doseCube,pln, ...
                pullingStep,targetNames)
            objectives = ...
                planWorkflow.precompute.DosePullingScoring.oarObjectives( ...
                cst,pullingStep,targetNames);
            score = 0;
            numOfFractions = ...
                planWorkflow.precompute.DosePullingScoring.numOfFractions( ...
                pln);
            for i = 1:numel(objectives)
                doseValues = ...
                    planWorkflow.precompute.DosePullingScoring.structureDoseValues( ...
                    cst,objectives(i).row,doseCube);
                if isempty(doseValues)
                    continue;
                end
                doseValues = doseValues .* numOfFractions;
                score = score + ...
                    planWorkflow.precompute.DosePullingScoring.objectiveDoseScore( ...
                    objectives(i).objective,doseValues);
            end
        end

        function tf = oarObjectiveFeasible(cst,pullingStep,targetNames, ...
                runConfig)
            objectives = ...
                planWorkflow.precompute.DosePullingScoring.oarObjectives( ...
                cst,pullingStep,targetNames);
            maxVmaxPercent = ...
                planWorkflow.precompute.DosePullingScoring.configNumber( ...
                runConfig,'dose_pulling_max_vmax_percent',100);
            tf = true;
            for i = 1:numel(objectives)
                objective = objectives(i).objective;
                if ~contains( ...
                        planWorkflow.precompute.DosePullingScoring.objectiveClassName( ...
                        objective),'matRad_MaxDVH')
                    continue;
                end
                params = ...
                    planWorkflow.precompute.DosePullingScoring.objectiveField( ...
                    objective,'parameters',{});
                if numel(params) < 2 || ~isnumeric(params{2})
                    continue;
                end
                vmax = params{2};
                if isfinite(vmax) && vmax > maxVmaxPercent
                    tf = false;
                    return;
                end
            end
        end

        function value = dosePullingVmax(cst,structureName,pullingStep)
            value = NaN;
            objective = ...
                planWorkflow.precompute.DosePullingScoring.firstDosePullingObjective( ...
                cst,structureName,pullingStep);
            if isempty(objective)
                return;
            end
            params = ...
                planWorkflow.precompute.DosePullingScoring.objectiveField( ...
                objective,'parameters',{});
            if iscell(params) && numel(params) >= 2 && isnumeric(params{2})
                value = params{2};
            end
        end

        function value = dosePullingPenalty(cst,structureName,pullingStep)
            value = NaN;
            objective = ...
                planWorkflow.precompute.DosePullingScoring.firstDosePullingObjective( ...
                cst,structureName,pullingStep);
            if isempty(objective)
                return;
            end
            value = ...
                planWorkflow.precompute.DosePullingScoring.objectiveField( ...
                objective,'penalty',NaN);
        end

        function names = oarNames(cst,pullingStep,targetNames)
            objectives = ...
                planWorkflow.precompute.DosePullingScoring.oarObjectives( ...
                cst,pullingStep,targetNames);
            names = {objectives.structureName};
            names = unique(names,'stable');
        end

        function doseCube = analysisDoseCube(resultGUI)
            if isfield(resultGUI,'analysisQuantity') && ...
                    isfield(resultGUI,resultGUI.analysisQuantity)
                doseCube = resultGUI.(resultGUI.analysisQuantity);
            elseif isfield(resultGUI,'physicalDose')
                doseCube = resultGUI.physicalDose;
            elseif isfield(resultGUI,'RBExDose')
                doseCube = resultGUI.RBExDose;
            else
                error(['planWorkflow:precompute:DosePulling:' ...
                    'MissingDoseCube'], ...
                    'Dose pulling could not find an analysis dose cube.');
            end
        end

        function doseCube = robustCenterDoseCube(resultGUI,robustData)
            if isfield(robustData,'dij_interval') && ...
                    isfield(robustData.dij_interval,'center') && ...
                    isfield(robustData,'dij_intervalContext') && ...
                    isfield(robustData.dij_intervalContext,'doseGrid') && ...
                    isfield(resultGUI,'w')
                doseVector = robustData.dij_interval.center * resultGUI.w;
                doseCube = reshape(full(doseVector), ...
                    robustData.dij_intervalContext.doseGrid.dimensions);
                return;
            end

            if isfield(resultGUI,'analysisQuantity') && ...
                    isfield(resultGUI,resultGUI.analysisQuantity)
                doseCube = resultGUI.(resultGUI.analysisQuantity);
                return;
            end

            doseFields = fieldnames(resultGUI);
            doseFieldIx = find(startsWith(doseFields,'physicalDose_') | ...
                startsWith(doseFields,'RBExDose_'),1);
            if ~isempty(doseFieldIx)
                doseCube = resultGUI.(doseFields{doseFieldIx});
                return;
            end

            doseCube = ...
                planWorkflow.precompute.DosePullingScoring.analysisDoseCube( ...
                resultGUI);
        end

        function result = emptyResult()
            result = struct('step',NaN,'iteration',NaN, ...
                'value',NaN,'values',[], ...
                'limit',NaN,'limits',[],'primaryScore',NaN, ...
                'limitDiffSq',NaN,'oarScore',NaN, ...
                'selectionScore',NaN,'isSatisfied',false, ...
                'isFeasible',true,'targetNames',{{}},'criteria',{{}}, ...
                'criteriaLabels',{{}}, ...
                'rectumPull',NaN,'bladderPull',NaN, ...
                'channelObjective',NaN,'meanQiTarget',[], ...
                'minQiTarget',[],'metricsByVariant',{{}});
        end
    end

    methods (Static, Access = private)
        function value = configNumber(runConfig,fieldName,defaultValue)
            value = defaultValue;
            if isfield(runConfig,fieldName) && ~isempty(runConfig.(fieldName))
                value = runConfig.(fieldName);
            end
        end

        function values = normalize01(values)
            lo = min(values);
            hi = max(values);
            if hi - lo < eps
                values = zeros(size(values));
            else
                values = (values - lo) ./ (hi - lo);
            end
        end

        function numOfFractions = numOfFractions(pln)
            numOfFractions = 1;
            if isstruct(pln) && isfield(pln,'numOfFractions') && ...
                    ~isempty(pln.numOfFractions)
                numOfFractions = pln.numOfFractions;
            end
            if ~(isnumeric(numOfFractions) && isscalar(numOfFractions) && ...
                    isfinite(numOfFractions) && numOfFractions > 0)
                error(['planWorkflow:precompute:DosePulling:' ...
                    'InvalidNumOfFractions'], ...
                    'pln.numOfFractions must be a positive finite scalar.');
            end
        end

        function doseValues = structureDoseValues(cst,row,doseCube)
            indices = cst{row,4};
            if iscell(indices)
                if isempty(indices) || isempty(indices{1})
                    doseValues = [];
                    return;
                end
                indices = indices{1};
            end
            indices = indices(:);
            indices = indices(indices >= 1 & indices <= numel(doseCube));
            doseValues = doseCube(indices);
            doseValues = doseValues(isfinite(doseValues));
        end

        function score = objectiveDoseScore(objective,doseValues)
            className = ...
                planWorkflow.precompute.DosePullingScoring.objectiveClassName( ...
                objective);
            parameters = ...
                planWorkflow.precompute.DosePullingScoring.objectiveField( ...
                objective,'parameters',{});
            penalty = ...
                planWorkflow.precompute.DosePullingScoring.objectiveField( ...
                objective,'penalty',1);
            if contains(className,'matRad_MaxDVH') && numel(parameters) >= 1
                score = penalty * ...
                    planWorkflow.precompute.DosePullingScoring.volumeAtDosePercent( ...
                    doseValues,parameters{1});
            elseif contains(className,'matRad_MeanDose')
                score = penalty * mean(doseValues);
            elseif contains(className,'matRad_SquaredOverdosing') && ...
                    numel(parameters) >= 1
                score = penalty * mean(max(doseValues - parameters{1},0).^2);
            elseif contains(className,'matRad_MinDVH') && numel(parameters) >= 1
                score = penalty * max(0,parameters{1} - min(doseValues));
            else
                score = penalty * mean(doseValues);
            end
        end

        function value = volumeAtDosePercent(doseValues,doseReference)
            value = 100 * nnz(doseValues >= doseReference) / ...
                max(1,numel(doseValues));
        end

        function objective = firstDosePullingObjective(cst,structureName, ...
                pullingStep)
            objective = [];
            for row = 1:size(cst,1)
                if ~strcmp(cst{row,2},structureName) || ...
                        size(cst,2) < 6 || isempty(cst{row,6})
                    continue;
                end
                for objIx = 1:numel(cst{row,6})
                    candidate = cst{row,6}{objIx};
                    if planWorkflow.precompute.DosePullingScoring.isDosePullingObjective( ...
                            candidate,pullingStep)
                        objective = candidate;
                        return;
                    end
                end
            end
        end

        function objectives = oarObjectives(cst,pullingStep,targetNames)
            objectives = repmat(struct('structureName','','row',NaN, ...
                'objective',[]),1,0);
            for row = 1:size(cst,1)
                structureName = cst{row,2};
                if any(strcmp(structureName,targetNames))
                    continue;
                end
                if size(cst,2) < 6 || isempty(cst{row,6})
                    continue;
                end
                for objIx = 1:numel(cst{row,6})
                    objective = cst{row,6}{objIx};
                    if planWorkflow.precompute.DosePullingScoring.isDosePullingObjective( ...
                            objective,pullingStep)
                        objectives(end + 1) = struct( ...
                            'structureName',structureName,'row',row, ...
                            'objective',objective); %#ok<AGROW>
                    end
                end
            end
        end

        function tf = isDosePullingObjective(objective,pullingStep)
            tf = ...
                planWorkflow.precompute.DosePullingScoring.objectiveField( ...
                objective,'dosePulling',false) && ...
                planWorkflow.precompute.DosePullingScoring.objectiveField( ...
                objective,'pullingStep',NaN) == pullingStep;
        end

        function className = objectiveClassName(objective)
            className = ...
                planWorkflow.precompute.DosePullingScoring.objectiveField( ...
                objective,'className','');
            if isempty(className) && isobject(objective)
                className = class(objective);
            end
        end

        function value = objectiveField(objective,fieldName,defaultValue)
            if isstruct(objective) && isfield(objective,fieldName)
                value = objective.(fieldName);
            elseif isobject(objective) && isprop(objective,fieldName)
                value = objective.(fieldName);
            else
                value = defaultValue;
            end
        end
    end
end
