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

                dvhStat = cstStat(i).dvhStat;
                dvh = dvhStat.mean;
                if ~isfield(dvh,'doseGrid') || ~isfield(dvh,'volumePoints')
                    continue;
                end

                doseGrid = dvh.doseGrid(:);
                volumePoints = dvh.volumePoints(:);
                [lowerDvh,upperDvh,hasTrustband] = ...
                    planWorkflow.analysis.ExpectedQi.trustbandLimitDvhs( ...
                    dvhStat);
                expectedQi(i).mean = planWorkflow.analysis.ExpectedQi.meanDoseFromDvh( ...
                    doseGrid,volumePoints);
                expectedQi(i).spatialStdDose = ...
                    planWorkflow.analysis.ExpectedQi.stdDoseFromDvh( ...
                    doseGrid,volumePoints);
                expectedQi(i).uncertaintyHalfWidth = NaN;
                expectedQi(i).trustbandHalfWidth = NaN;
                if hasTrustband
                    lowerMean = ...
                        planWorkflow.analysis.ExpectedQi.meanDoseFromDvh( ...
                        lowerDvh.doseGrid(:),lowerDvh.volumePoints(:));
                    upperMean = ...
                        planWorkflow.analysis.ExpectedQi.meanDoseFromDvh( ...
                        upperDvh.doseGrid(:),upperDvh.volumePoints(:));
                    [lowerMean,upperMean] = ...
                        planWorkflow.analysis.ExpectedQi.orderedBounds( ...
                        lowerMean,upperMean);
                    expectedQi(i).uncertaintyHalfWidth = ...
                        planWorkflow.analysis.ExpectedQi.trustbandHalfWidth( ...
                        lowerMean,upperMean);
                    expectedQi(i).trustbandHalfWidth = ...
                        expectedQi(i).uncertaintyHalfWidth;
                    expectedQi(i).min = ...
                        planWorkflow.analysis.ExpectedQi.minDoseFromDvh( ...
                        lowerDvh.doseGrid(:),lowerDvh.volumePoints(:));
                    expectedQi(i).max = ...
                        planWorkflow.analysis.ExpectedQi.maxDoseFromDvh( ...
                        upperDvh.doseGrid(:),upperDvh.volumePoints(:));
                else
                    expectedQi(i).min = planWorkflow.analysis.ExpectedQi.minDoseFromDvh( ...
                        doseGrid,volumePoints);
                    expectedQi(i).max = planWorkflow.analysis.ExpectedQi.maxDoseFromDvh( ...
                        doseGrid,volumePoints);
                end
                expectedQi(i).D_95 = planWorkflow.analysis.ExpectedQi.dvhDoseAtVolume( ...
                    doseGrid,volumePoints,95);
                expectedQi(i).D_98 = planWorkflow.analysis.ExpectedQi.dvhDoseAtVolume( ...
                    doseGrid,volumePoints,98);
                expectedQi(i).D_2 = planWorkflow.analysis.ExpectedQi.dvhDoseAtVolume( ...
                    doseGrid,volumePoints,2);
                expectedQi(i).D_50 = planWorkflow.analysis.ExpectedQi.dvhDoseAtVolume( ...
                    doseGrid,volumePoints,50);

                if i <= size(cst,1) && strcmp(cst{i,3},'TARGET')
                    referenceDose = planWorkflow.analysis.ExpectedQi.targetReferenceDose( ...
                        cst,i,pln);
                    if isfinite(referenceDose)
                        expectedQi(i).referenceDose = referenceDose;
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

        function [lowerDvh,upperDvh,hasTrustband] = trustbandLimitDvhs(dvhStat)
            lowerDvh = struct();
            upperDvh = struct();
            hasTrustband = false;
            if ~isstruct(dvhStat) || ~isfield(dvhStat,'mean') || ...
                    ~isfield(dvhStat.mean,'doseGrid') || ...
                    ~isfield(dvhStat.mean,'volumePoints')
                return;
            end

            meanDvh = dvhStat.mean;
            if ~isfield(dvhStat,'std') || ...
                    ~isfield(dvhStat.std,'doseGrid') || ...
                    ~isfield(dvhStat.std,'volumePoints')
                return;
            end

            meanDoseGrid = meanDvh.doseGrid(:);
            meanVolume = meanDvh.volumePoints(:);
            stdVolume = planWorkflow.analysis.ExpectedQi.dvhStdOnDoseGrid( ...
                meanDoseGrid,dvhStat.std);
            if isempty(stdVolume)
                return;
            end

            lowerDvh = meanDvh;
            upperDvh = meanDvh;
            lowerDvh.doseGrid = meanDoseGrid;
            upperDvh.doseGrid = meanDoseGrid;
            lowerDvh.volumePoints = max(meanVolume - stdVolume,0);
            upperDvh.volumePoints = min(meanVolume + stdVolume,100);
            hasTrustband = true;
        end

        function stdVolume = dvhStdOnDoseGrid(doseGrid,stdDvh)
            stdVolume = [];
            stdDoseGrid = stdDvh.doseGrid(:);
            stdValues = stdDvh.volumePoints(:);
            valid = isfinite(stdDoseGrid) & isfinite(stdValues);
            if nnz(valid) < 1
                return;
            end

            if numel(stdValues) == numel(doseGrid) && ...
                    isequal(stdDoseGrid,doseGrid)
                stdVolume = stdValues;
                return;
            end

            stdVolume = interp1(stdDoseGrid(valid),stdValues(valid), ...
                doseGrid,'linear',NaN);
            if any(~isfinite(stdVolume))
                stdVolume = [];
                return;
            end
        end

        function [lowerValue,upperValue] = orderedBounds(lowerValue,upperValue)
            if isfinite(lowerValue) && isfinite(upperValue) && ...
                    lowerValue > upperValue
                tmp = lowerValue;
                lowerValue = upperValue;
                upperValue = tmp;
            end
        end

        function stdValue = trustbandHalfWidth(lowerValue,upperValue)
            if isfinite(lowerValue) && isfinite(upperValue)
                stdValue = abs(upperValue - lowerValue) / 2;
            else
                stdValue = NaN;
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
            volume = NaN;
            if ~isnumeric(dose) || ~isscalar(dose) || ~isfinite(dose)
                return;
            end

            doseGrid = doseGrid(:);
            volumePoints = volumePoints(:);
            valid = isfinite(doseGrid) & isfinite(volumePoints);
            if nnz(valid) < 2
                return;
            end

            doseGrid = doseGrid(valid);
            volumePoints = volumePoints(valid);
            [doseGrid,sortIx] = sort(doseGrid);
            volumePoints = volumePoints(sortIx);
            [doseGrid,uniqueIx] = unique(doseGrid,'stable');
            volumePoints = volumePoints(uniqueIx);
            if numel(doseGrid) < 2
                return;
            end

            if dose < doseGrid(1)
                volume = 1;
            elseif dose > doseGrid(end)
                volume = 0;
            else
                volume = interp1(doseGrid,volumePoints,dose,'linear') / 100;
                volume = min(max(volume,0),1);
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
