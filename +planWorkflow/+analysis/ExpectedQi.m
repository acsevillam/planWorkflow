classdef ExpectedQi
    % ExpectedQi Quality indicators derived from the expected DVH curve.

    methods (Static)
        function expectedQi = fromCstStat(cstStat,cst,pln)
            expectedQi = struct([]);
            if isempty(cstStat)
                return;
            end

            expectedQi = repmat(struct('name',''),1,numel(cstStat));
            for i = 1:numel(cstStat)
                expectedQi(i).name = planWorkflow.analysis.ExpectedQi.structTextField( ...
                    cstStat(i),{'name','VOIname'},sprintf('structure_%d',i));

                if ~isfield(cstStat(i),'dvhStat') || ...
                        ~isfield(cstStat(i).dvhStat,'mean') || ...
                        isempty(cstStat(i).dvhStat.mean)
                    continue;
                end

                dvh = cstStat(i).dvhStat.mean;
                if ~isfield(dvh,'doseGrid') || ~isfield(dvh,'volumePoints')
                    continue;
                end

                doseGrid = dvh.doseGrid(:);
                volumePoints = dvh.volumePoints(:);
                expectedQi(i).mean = planWorkflow.analysis.ExpectedQi.meanDoseFromDvh( ...
                    doseGrid,volumePoints);
                expectedQi(i).std = planWorkflow.analysis.ExpectedQi.stdDoseFromDvh( ...
                    doseGrid,volumePoints);
                expectedQi(i).min = planWorkflow.analysis.ExpectedQi.minDoseFromDvh( ...
                    doseGrid,volumePoints);
                expectedQi(i).max = planWorkflow.analysis.ExpectedQi.maxDoseFromDvh( ...
                    doseGrid,volumePoints);
                expectedQi(i).D_95 = planWorkflow.analysis.ExpectedQi.dvhDoseAtVolume( ...
                    doseGrid,volumePoints,95);
                expectedQi(i).D_98 = planWorkflow.analysis.ExpectedQi.dvhDoseAtVolume( ...
                    doseGrid,volumePoints,98);
                expectedQi(i).D_2 = planWorkflow.analysis.ExpectedQi.dvhDoseAtVolume( ...
                    doseGrid,volumePoints,2);
                expectedQi(i).D_50 = planWorkflow.analysis.ExpectedQi.dvhDoseAtVolume( ...
                    doseGrid,volumePoints,50);
                expectedQi(i).V_17_1Gy = planWorkflow.analysis.ExpectedQi.dvhVolumeAtDose( ...
                    doseGrid,volumePoints,17.1);
                expectedQi(i).V_34_3Gy = planWorkflow.analysis.ExpectedQi.dvhVolumeAtDose( ...
                    doseGrid,volumePoints,34.3);

                if i <= size(cst,1) && strcmp(cst{i,3},'TARGET')
                    referenceDose = planWorkflow.analysis.ExpectedQi.targetReferenceDose( ...
                        cst,i,pln);
                    if isfinite(referenceDose)
                        expectedQi(i).referenceDose = referenceDose;
                        expectedQi(i).doseMode = 'perFraction';
                        expectedQi(i).COV1 = ...
                            planWorkflow.analysis.ExpectedQi.dvhVolumeAtDose( ...
                            doseGrid,volumePoints,referenceDose);
                        expectedQi(i).COV_95 = ...
                            planWorkflow.analysis.ExpectedQi.dvhVolumeAtDose( ...
                            doseGrid,volumePoints,0.95*referenceDose);
                        expectedQi(i).COV_98 = ...
                            planWorkflow.analysis.ExpectedQi.dvhVolumeAtDose( ...
                            doseGrid,volumePoints,0.98*referenceDose);
                        expectedQi(i).COV_99 = ...
                            planWorkflow.analysis.ExpectedQi.dvhVolumeAtDose( ...
                            doseGrid,volumePoints,0.99*referenceDose);
                    end
                end
            end
        end

        function meanDose = meanDoseFromDvh(doseGrid,volumePoints)
            survival = volumePoints(:) / 100;
            meanDose = trapz(doseGrid(:),survival);
        end

        function stdDose = stdDoseFromDvh(doseGrid,volumePoints)
            survival = volumePoints(:) / 100;
            meanDose = planWorkflow.analysis.ExpectedQi.meanDoseFromDvh( ...
                doseGrid,survival*100);
            secondMoment = 2 * trapz(doseGrid(:),doseGrid(:).*survival);
            stdDose = sqrt(max(secondMoment - meanDose.^2,0));
        end

        function minDose = minDoseFromDvh(doseGrid,volumePoints)
            ix = find(volumePoints < 100,1,'first');
            if isempty(ix)
                minDose = NaN;
            else
                minDose = doseGrid(ix);
            end
        end

        function maxDose = maxDoseFromDvh(doseGrid,volumePoints)
            ix = find(volumePoints > 0,1,'last');
            if isempty(ix)
                maxDose = NaN;
            else
                maxDose = doseGrid(ix);
            end
        end

        function dose = dvhDoseAtVolume(doseGrid,volumePoints,targetVolume)
            dose = NaN;
            valid = isfinite(doseGrid) & isfinite(volumePoints);
            if nnz(valid) < 2
                return;
            end

            volume = flipud(volumePoints(valid));
            doseValues = flipud(doseGrid(valid));
            [volume,uniqueIx] = unique(volume,'stable');
            doseValues = doseValues(uniqueIx);
            if numel(volume) < 2 || targetVolume < min(volume) || ...
                    targetVolume > max(volume)
                return;
            end

            dose = interp1(volume,doseValues,targetVolume,'linear');
        end

        function volume = dvhVolumeAtDose(doseGrid,volumePoints,dose)
            if dose < min(doseGrid) || dose > max(doseGrid)
                volume = NaN;
            else
                volume = interp1(doseGrid,volumePoints,dose,'linear') / 100;
            end
        end

        function referenceDose = targetReferenceDose(cst,voiIx,pln)
            referenceDose = inf;
            objectives = cst{voiIx,6};
            if isempty(objectives)
                referenceDose = NaN;
                return;
            end

            if isstruct(objectives)
                objectives = num2cell(arrayfun( ...
                    @matRad_DoseOptimizationFunction.convertOldOptimizationStruct, ...
                    objectives));
            end

            for objectiveIx = 1:numel(objectives)
                objective = objectives{objectiveIx};
                if ~isa(objective,'matRad_DoseOptimizationFunction')
                    try
                        objective = ...
                            matRad_DoseOptimizationFunction.createInstanceFromStruct( ...
                            objective);
                    catch
                        continue;
                    end
                end

                penalizesUnderdose = ...
                    isa(objective,'DoseObjectives.matRad_SquaredDeviation') || ...
                    isa(objective,'DoseObjectives.matRad_SquaredUnderdosing') || ...
                    isa(objective,'DoseObjectives.matRad_SquaredBertoluzzaDeviation2') || ...
                    isa(objective,'DoseObjectives.matRad_MinDVH');
                if ~penalizesUnderdose
                    continue;
                end

                doseParameters = objective.getDoseParameters();
                doseParameters = doseParameters(isfinite(doseParameters));
                if ~isempty(doseParameters)
                    referenceDose = min([referenceDose; doseParameters(:)]);
                end
            end

            if isfinite(referenceDose)
                referenceDose = referenceDose / pln.numOfFractions;
            else
                referenceDose = NaN;
            end
        end

        function value = structTextField(source,fieldNames,fallback)
            value = fallback;
            for i = 1:numel(fieldNames)
                fieldName = fieldNames{i};
                if isfield(source,fieldName) && ~isempty(source.(fieldName))
                    candidate = source.(fieldName);
                    if ischar(candidate) || isstring(candidate)
                        value = char(candidate);
                        return;
                    end
                end
            end
        end
    end
end
