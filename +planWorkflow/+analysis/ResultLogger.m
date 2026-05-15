classdef ResultLogger
    % ResultLogger Console formatting for workflow analysis summaries.

    methods (Static)
        function log(logFn,results)
            planWorkflow.analysis.ResultLogger.emit(logFn,'Analysis results summary:');
            runConfig = struct();
            if isfield(results,'runConfig')
                runConfig = results.runConfig;
            end
            planWorkflow.analysis.ResultLogger.logStructureNormalizationReports( ...
                logFn,results);

            loggedExpectedSamplingQi = false;
            if isfield(results,'sampling')
                loggedExpectedSamplingQi = ...
                    planWorkflow.analysis.ResultLogger.logSamplingExpectedQiResults( ...
                    logFn,results.sampling,runConfig);
                planWorkflow.analysis.ResultLogger.logSamplingResults( ...
                    logFn,results.sampling);
            end

            if loggedExpectedSamplingQi
                return;
            end

            if isfield(results,'reference') && isfield(results.reference,'qi')
                label = planWorkflow.analysis.ResultLogger.planLabel( ...
                    results.reference,'reference');
                planWorkflow.analysis.ResultLogger.logQiResults( ...
                    logFn,label,results.reference);
                planWorkflow.analysis.ResultLogger.logClinicalEndpointResults( ...
                    logFn,label,results.reference,runConfig, ...
                    results.reference);
            end

            if isfield(results,'robust')
                for planIx = 1:numel(results.robust)
                    if isfield(results.robust{planIx},'qi')
                        label = sprintf('robust plan %d',planIx);
                        if isfield(results.robust{planIx},'label') && ...
                                ~isempty(results.robust{planIx}.label)
                            label = char(results.robust{planIx}.label);
                        end
                        planWorkflow.analysis.ResultLogger.logQiResults( ...
                            logFn,label,results.robust{planIx});
                        referencePlan = [];
                        if isfield(results,'reference')
                            referencePlan = results.reference;
                        end
                        planWorkflow.analysis.ResultLogger.logClinicalEndpointResults( ...
                            logFn,label,results.robust{planIx},runConfig, ...
                            referencePlan);
                    end
                end
            end
        end

        function logStructureNormalizationReports(logFn,results)
            if isfield(results,'structureNormalizationReport')
                planWorkflow.structures.NormalizationReportLogger.log( ...
                    logFn,'Optimization structure normalization', ...
                    results.structureNormalizationReport);
            end
            if isfield(results,'sampling') && isstruct(results.sampling) && ...
                    isfield(results.sampling,'structureNormalizationReport')
                planWorkflow.structures.NormalizationReportLogger.log( ...
                    logFn,'Sampling structure normalization', ...
                    results.sampling.structureNormalizationReport);
            end
        end

        function logQiResults(logFn,label,planResults)
            if isstruct(planResults) && isfield(planResults,'qi')
                qi = planResults.qi;
                context = planWorkflow.analysis.PlanEvaluationContext.fromPlanResults( ...
                    planResults);
            else
                qi = planResults;
                context = planWorkflow.analysis.PlanEvaluationContext.fromPlanResults( ...
                    struct());
                planResults = struct();
            end
            if isempty(qi)
                planWorkflow.analysis.ResultLogger.emit(logFn, ...
                    sprintf('Analysis results %s QI: empty.',label));
                return;
            end

            planWorkflow.analysis.ResultLogger.emit(logFn, ...
                sprintf('Analysis results %s QI:',label));
            planWorkflow.analysis.ResultLogger.logEvaluationContext(logFn,context);
            planWorkflow.analysis.ResultLogger.logQiTable( ...
                logFn,qi,context,planResults);
        end

        function loggedAny = logSamplingExpectedQiResults(logFn,samplingResults,runConfig)
            loggedAny = false;
            maxPlans = 1;
            if isfield(samplingResults,'robust')
                maxPlans = maxPlans + numel(samplingResults.robust);
            end
            labels = cell(1,maxPlans);
            plans = cell(1,maxPlans);
            numPlans = 0;
            referencePlan = [];
            if isfield(samplingResults,'reference') && ...
                    planWorkflow.analysis.ResultLogger.hasExpectedQi( ...
                    samplingResults.reference)
                numPlans = numPlans + 1;
                labels{numPlans} = ...
                    planWorkflow.analysis.ResultLogger.planLabel( ...
                    samplingResults.reference,'reference plan');
                plans{numPlans} = samplingResults.reference;
                referencePlan = samplingResults.reference;
            end

            if isfield(samplingResults,'robust')
                for planIx = 1:numel(samplingResults.robust)
                    if planWorkflow.analysis.ResultLogger.hasExpectedQi( ...
                            samplingResults.robust{planIx})
                        numPlans = numPlans + 1;
                        labels{numPlans} = ...
                            planWorkflow.analysis.ResultLogger.planLabel( ...
                            samplingResults.robust{planIx}, ...
                            sprintf('robust plan %d',planIx));
                        plans{numPlans} = samplingResults.robust{planIx};
                    end
                end
            end

            if numPlans == 0
                return;
            end

            planWorkflow.analysis.ResultLogger.emit(logFn, ...
                ['Analysis QI from sampling expected DVH ' ...
                 '(same curve as trustband dotted line):']);
            if isfield(samplingResults,'scenarioMode')
                planWorkflow.analysis.ResultLogger.emit(logFn, ...
                    sprintf('  scenarioMode: %s', ...
                    char(samplingResults.scenarioMode)));
            end

            for planIx = 1:numPlans
                loggedAny = planWorkflow.analysis.ResultLogger.logExpectedQiResults( ...
                    logFn,labels{planIx},plans{planIx}) || loggedAny;
                planWorkflow.analysis.ResultLogger.logClinicalEndpointResults( ...
                    logFn,labels{planIx},plans{planIx},runConfig, ...
                    referencePlan);
            end
        end

        function tf = hasExpectedQi(planResults)
            tf = isstruct(planResults) && isfield(planResults,'expectedQi') && ...
                ~isempty(planResults.expectedQi);
        end

        function label = planLabel(planResults,defaultLabel)
            label = defaultLabel;
            if isstruct(planResults) && isfield(planResults,'label') && ...
                    ~isempty(planResults.label)
                label = char(planResults.label);
            end
        end

        function logged = logExpectedQiResults(logFn,label,planResults)
            logged = false;
            if ~isfield(planResults,'expectedQi') || isempty(planResults.expectedQi)
                return;
            end
            context = planWorkflow.analysis.PlanEvaluationContext.fromPlanResults(planResults);

            planWorkflow.analysis.ResultLogger.emit(logFn, ...
                sprintf('Analysis results %s QI from expected DVH:',label));
            planWorkflow.analysis.ResultLogger.logEvaluationContext(logFn,context);
            planWorkflow.analysis.ResultLogger.logQiTable( ...
                logFn,planResults.expectedQi,context,planResults);
            logged = true;
        end

        function logClinicalEndpointResults(logFn,label,planResults, ...
                runConfig,referencePlanResults)
            if nargin < 5
                referencePlanResults = [];
            end
            if ~isstruct(planResults) || ~isfield(planResults,'cstStat') || ...
                    isempty(planResults.cstStat)
                return;
            end

            context = ...
                planWorkflow.analysis.PlanEvaluationContext.fromPlanResults( ...
                planResults);
            endpoints = ...
                planWorkflow.analysis.EndpointStructureContract.endpoints( ...
                runConfig,context.endpointQuantity);
            if isempty(endpoints)
                planWorkflow.analysis.ResultLogger.logNoClinicalEndpoints( ...
                    logFn,label,context);
                return;
            end

            [rows,missingEndpoints] = ...
                planWorkflow.analysis.ClinicalEndpointEvaluator.evaluatePlan( ...
                planResults,endpoints,referencePlanResults);
            planWorkflow.analysis.ResultLogger.logMissingClinicalEndpoints( ...
                logFn,label,missingEndpoints);
            if isempty(rows)
                return;
            end

            sourceLabel = 'DVH';
            if isfield(planResults,'expectedQi')
                sourceLabel = 'expected DVH';
            end
            planWorkflow.analysis.ResultLogger.emit(logFn, ...
                sprintf('Analysis clinical endpoints %s from %s:', ...
                label,sourceLabel));
            planWorkflow.analysis.ResultLogger.logEvaluationContext(logFn,context);
            headers = {'Structure','Metric','Mean','UncertHW','Min','Max', ...
                'Delta','Goal','PoR','Unit'};
            widths = [24 10 10 10 10 10 10 14 10 8];
            planWorkflow.analysis.ResultLogger.emit(logFn, ...
                ['  ' planWorkflow.analysis.ResultLogger.formatFixedWidthRow( ...
                headers,widths)]);
            planWorkflow.analysis.ResultLogger.emit(logFn, ...
                ['  ' planWorkflow.analysis.ResultLogger.formatFixedWidthRow( ...
                {'------------------------','----------','----------', ...
                     '----------','----------','----------','----------', ...
                     '--------------','----------', ...
                     '--------'},widths)]);
            for i = 1:numel(rows)
                planWorkflow.analysis.ResultLogger.emit(logFn, ...
                    ['  ' planWorkflow.analysis.ResultLogger.formatFixedWidthRow( ...
                    {rows(i).structure,rows(i).metric, ...
                     planWorkflow.analysis.ResultLogger.formatNumber(rows(i).mean), ...
                     planWorkflow.analysis.ResultLogger.formatNumber( ...
                     rows(i).uncertaintyHalfWidth), ...
                     planWorkflow.analysis.ResultLogger.formatNumber(rows(i).min), ...
                     planWorkflow.analysis.ResultLogger.formatNumber(rows(i).max), ...
                     planWorkflow.analysis.ResultLogger.formatNumber( ...
                     rows(i).deltaFromReference), ...
                     rows(i).goal, ...
                     planWorkflow.analysis.ResultLogger.formatNumber(rows(i).por), ...
                     rows(i).unit},widths)]);
            end
        end

        function logNoClinicalEndpoints(logFn,label,context)
            quantityText = 'unknown';
            if isstruct(context) && isfield(context,'analysisQuantity') && ...
                    ~isempty(context.analysisQuantity)
                quantityText = char(context.analysisQuantity);
            end
            if isstruct(context) && isfield(context,'endpointQuantity') && ...
                    ~isempty(context.endpointQuantity)
                quantityText = char(context.endpointQuantity);
            end
            planWorkflow.analysis.ResultLogger.emit(logFn, ...
                sprintf(['Analysis clinical endpoints %s: no endpoints ' ...
                'configured for endpointQuantity "%s"; skipping.'], ...
                char(label),quantityText));
        end

        function logQiTable(logFn,qi,context,planResults)
            if nargin < 3 || isempty(context)
                context = planWorkflow.analysis.PlanEvaluationContext.fromPlanResults(struct());
            end
            if nargin < 4
                planResults = struct();
            end

            [fields,headers] = planWorkflow.analysis.ResultLogger.qiSummaryColumns();
            widths = [24 repmat(8,1,numel(headers))];
            planWorkflow.analysis.ResultLogger.emit(logFn, ...
                ['  ' planWorkflow.analysis.ResultLogger.formatFixedWidthRow( ...
                [{'Structure'} headers],widths)]);
            planWorkflow.analysis.ResultLogger.emit(logFn, ...
                ['  ' planWorkflow.analysis.ResultLogger.formatFixedWidthRow( ...
                [{'------------------------'} ...
                repmat({'--------'},1,numel(headers))],widths)]);
            for i = 1:numel(qi)
                structureName = ...
                    planWorkflow.analysis.ExpectedQi.structTextField(qi(i), ...
                    {'name','VOIname'},sprintf('structure_%d',i));
                planWorkflow.analysis.ResultLogger.emit(logFn, ...
                    ['  ' planWorkflow.analysis.ResultLogger.formatFixedWidthRow( ...
                    [{structureName} ...
                    planWorkflow.analysis.ResultLogger.formatMetricList( ...
                    qi(i),fields,context,planResults,i)],widths)]);
            end
        end

        function [fields,headers] = qiSummaryColumns()
            fields = {'COV1','COV_95','COV_98','COV_99','mean', ...
                'spatialStdDose','uncertaintyHalfWidth','min','max', ...
                'D_95','D_98','D_2','D_50'};
            headers = {'COV1','COV95','COV98','COV99','Mean', ...
                'SpatialSD','UncertHW','Min','Max', ...
                'D95','D98','D2','D50'};
        end

        function logMissingClinicalEndpoints(logFn,label,missingEndpoints)
            for i = 1:numel(missingEndpoints)
                requiredText = 'required';
                if isfield(missingEndpoints(i),'required') && ...
                        ~missingEndpoints(i).required
                    requiredText = 'optional';
                end
                planWorkflow.analysis.ResultLogger.emit(logFn, ...
                    sprintf(['  missing %s endpoint %s (%s) for %s: ' ...
                    'none of {%s} found in cstStat.'], ...
                    requiredText, ...
                    char(missingEndpoints(i).metric), ...
                    char(missingEndpoints(i).kind),char(label), ...
                    strjoin(missingEndpoints(i).structureNames,', ')));
            end
        end

        function values = formatMetricList(source,fields,context,planResults,structureIx)
            if nargin < 3 || isempty(context)
                context = planWorkflow.analysis.PlanEvaluationContext.fromPlanResults(struct());
            end
            if nargin < 4
                planResults = struct();
            end
            if nargin < 5
                structureIx = [];
            end

            values = cell(1,numel(fields));
            for i = 1:numel(fields)
                values{i} = planWorkflow.analysis.ResultLogger.formatMetricValue( ...
                    source,fields{i},context,planResults,structureIx);
            end
        end

        function text = formatMetricValue(source,fieldName,context,planResults,structureIx)
            if nargin < 3 || isempty(context)
                context = planWorkflow.analysis.PlanEvaluationContext.fromPlanResults(struct());
            end
            if nargin < 4
                planResults = struct();
            end
            if nargin < 5
                structureIx = [];
            end

            value = NaN;
            if isfield(source,fieldName) && ...
                    planWorkflow.analysis.ResultLogger.isNumericScalar(source.(fieldName))
                value = source.(fieldName);
                if planWorkflow.analysis.ResultLogger.isDoseMetric(fieldName)
                    value = value * context.evaluationScale;
                end
            end

            if isfinite(value)
                text = planWorkflow.analysis.ResultLogger.formatNumber(value);
            else
                text = '-';
            end
        end

        function logEvaluationContext(logFn,context)
            planWorkflow.analysis.ResultLogger.emit(logFn, ...
                sprintf('  evaluationMode: %s',context.evaluationMode));
            planWorkflow.analysis.ResultLogger.emit(logFn, ...
                sprintf('  evaluationModeBase: %s',context.evaluationModeBase));
            if ~isempty(context.numOfFractions)
                planWorkflow.analysis.ResultLogger.emit(logFn, ...
                    sprintf('  numOfFractions: %g',context.numOfFractions));
            end
            planWorkflow.analysis.ResultLogger.emit(logFn, ...
                sprintf('  analysisQuantity: %s', ...
                char(context.analysisQuantity)));
            if isfield(context,'endpointQuantity') && ...
                    ~isempty(context.endpointQuantity) && ...
                    ~strcmp(context.endpointQuantity, ...
                    context.analysisQuantity)
                planWorkflow.analysis.ResultLogger.emit(logFn, ...
                    sprintf('  endpointQuantity: %s', ...
                    char(context.endpointQuantity)));
            end
        end

        function tf = isDoseMetric(fieldName)
            tf = any(strcmp(fieldName,{'mean','spatialStdDose', ...
                'uncertaintyHalfWidth','trustbandHalfWidth','min','max', ...
                'referenceDose'})) || ...
                strncmp(fieldName,'D_',2);
        end

        function text = formatFixedWidthRow(values,widths)
            parts = cell(1,numel(values));
            for i = 1:numel(values)
                valueText = char(string(values{i}));
                if i == 1
                    parts{i} = sprintf('%-*s',widths(i),valueText);
                else
                    parts{i} = sprintf('%*s',widths(i),valueText);
                end
            end
            text = strjoin(parts,' ');
        end

        function tf = isNumericScalar(value)
            tf = isnumeric(value) && isscalar(value) && isfinite(value);
        end

        function text = formatNumber(value)
            if ~isfinite(value)
                text = '-';
            elseif abs(value) >= 1
                text = sprintf('%.4g',value);
            else
                text = sprintf('%.4f',value);
            end
        end

        function text = formatSignificantNumber(value,numSig)
            if nargin < 2
                numSig = 3;
            end
            if ~isfinite(value)
                text = '-';
            else
                format = sprintf('%%.%dg',numSig);
                text = sprintf(format,double(value));
            end
        end

        function logSamplingResults(logFn,samplingResults)
            planWorkflow.analysis.ResultLogger.emit(logFn,'Analysis results sampling:');
            if isfield(samplingResults,'scenarioMode')
                planWorkflow.analysis.ResultLogger.emit(logFn, ...
                    sprintf('  scenarioMode: %s', ...
                    char(samplingResults.scenarioMode)));
            end

            headers = {'Plan','Gamma','RI1','RI2','MeanMax','StdMax','Figures'};
            widths = [24 repmat(9,1,numel(headers) - 1)];
            planWorkflow.analysis.ResultLogger.emit(logFn, ...
                ['  ' planWorkflow.analysis.ResultLogger.formatFixedWidthRow( ...
                headers,widths)]);
            planWorkflow.analysis.ResultLogger.emit(logFn, ...
                ['  ' planWorkflow.analysis.ResultLogger.formatFixedWidthRow( ...
                [{'------------------------'} ...
                repmat({'---------'},1,numel(headers) - 1)],widths)]);
            if isfield(samplingResults,'reference')
                label = planWorkflow.analysis.ResultLogger.planLabel( ...
                    samplingResults.reference,'reference');
                planWorkflow.analysis.ResultLogger.emit(logFn, ...
                    ['  ' planWorkflow.analysis.ResultLogger.formatSamplingPlanRow( ...
                    label,samplingResults.reference,widths)]);
            end

            if isfield(samplingResults,'robust')
                for planIx = 1:numel(samplingResults.robust)
                    label = planWorkflow.analysis.ResultLogger.planLabel( ...
                        samplingResults.robust{planIx}, ...
                        sprintf('robust plan %d',planIx));
                    planWorkflow.analysis.ResultLogger.emit(logFn, ...
                        ['  ' planWorkflow.analysis.ResultLogger.formatSamplingPlanRow( ...
                        label,samplingResults.robust{planIx},widths)]);
                end
            end
        end

        function row = formatSamplingPlanRow(label,planResults,widths)
            values = {'-','-','-','-','-','-'};
            if isfield(planResults,'doseStat')
                doseStat = planResults.doseStat;
                if isfield(doseStat,'gammaAnalysis') && ...
                        isfield(doseStat.gammaAnalysis,'gammaPassRate') && ...
                        planWorkflow.analysis.ResultLogger.isNumericScalar( ...
                        doseStat.gammaAnalysis.gammaPassRate)
                    values{1} = planWorkflow.analysis.ResultLogger.formatNumber( ...
                        doseStat.gammaAnalysis.gammaPassRate);
                end
                if isfield(doseStat,'robustnessAnalysis')
                    robustness = doseStat.robustnessAnalysis;
                    if isfield(robustness,'index1') && ...
                            isfield(robustness.index1,'robustnessIndex') && ...
                            planWorkflow.analysis.ResultLogger.isNumericScalar( ...
                            robustness.index1.robustnessIndex)
                        values{2} = planWorkflow.analysis.ResultLogger.formatSignificantNumber( ...
                            robustness.index1.robustnessIndex,3);
                    end
                    if isfield(robustness,'index2') && ...
                            isfield(robustness.index2,'robustnessIndex') && ...
                            planWorkflow.analysis.ResultLogger.isNumericScalar( ...
                            robustness.index2.robustnessIndex)
                        values{3} = planWorkflow.analysis.ResultLogger.formatSignificantNumber( ...
                            robustness.index2.robustnessIndex,3);
                    end
                end
                if isfield(doseStat,'meanCubeW')
                    values{4} = planWorkflow.analysis.ResultLogger.formatNumber( ...
                        planWorkflow.analysis.ResultLogger.finiteMax(doseStat.meanCubeW));
                elseif isfield(doseStat,'summary') && ...
                        isfield(doseStat.summary,'meanCubeWMax')
                    values{4} = planWorkflow.analysis.ResultLogger.formatNumber( ...
                        doseStat.summary.meanCubeWMax);
                end
                if isfield(doseStat,'stdCubeW')
                    values{5} = planWorkflow.analysis.ResultLogger.formatNumber( ...
                        planWorkflow.analysis.ResultLogger.finiteMax(doseStat.stdCubeW));
                elseif isfield(doseStat,'summary') && ...
                        isfield(doseStat.summary,'stdCubeWMax')
                    values{5} = planWorkflow.analysis.ResultLogger.formatNumber( ...
                        doseStat.summary.stdCubeWMax);
                end
            end

            if isfield(planResults,'figureFiles')
                values{6} = sprintf('%d', ...
                    planWorkflow.analysis.ResultLogger.countSavedFigures( ...
                    planResults.figureFiles));
            end

            row = planWorkflow.analysis.ResultLogger.formatFixedWidthRow( ...
                [{label} values],widths);
        end

        function value = finiteMax(array)
            finiteValues = array(isfinite(array));
            if isempty(finiteValues)
                value = NaN;
            else
                value = max(finiteValues(:));
            end
        end

        function count = countSavedFigures(figureFiles)
            count = 0;
            if ~isstruct(figureFiles)
                return;
            end

            fields = fieldnames(figureFiles);
            for i = 1:numel(fields)
                value = figureFiles.(fields{i});
                if (ischar(value) || isstring(value)) && ~isempty(value)
                    count = count + 1;
                end
            end
        end

        function emit(logFn,message)
            logFn(message);
        end
    end
end
