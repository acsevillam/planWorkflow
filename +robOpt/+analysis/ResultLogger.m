classdef ResultLogger
    % ResultLogger Console formatting for workflow analysis summaries.

    methods (Static)
        function log(logFn,results)
            robOpt.analysis.ResultLogger.emit(logFn,'Analysis results summary:');
            runConfig = struct();
            if isfield(results,'runConfig')
                runConfig = results.runConfig;
            end

            loggedExpectedSamplingQi = false;
            if isfield(results,'sampling')
                loggedExpectedSamplingQi = ...
                    robOpt.analysis.ResultLogger.logSamplingExpectedQiResults( ...
                    logFn,results.sampling,runConfig);
                robOpt.analysis.ResultLogger.logSamplingResults( ...
                    logFn,results.sampling);
            end

            if loggedExpectedSamplingQi
                return;
            end

            if isfield(results,'nominal') && isfield(results.nominal,'qi')
                robOpt.analysis.ResultLogger.logQiResults( ...
                    logFn,'nominal',results.nominal.qi);
            end

            if isfield(results,'robust')
                for planIx = 1:numel(results.robust)
                    if isfield(results.robust{planIx},'qi')
                        robOpt.analysis.ResultLogger.logQiResults( ...
                            logFn,sprintf('robust plan %d',planIx), ...
                            results.robust{planIx}.qi);
                    end
                end
            end
        end

        function logQiResults(logFn,label,qi)
            if isempty(qi)
                robOpt.analysis.ResultLogger.emit(logFn, ...
                    sprintf('Analysis results %s QI: empty.',label));
                return;
            end

            robOpt.analysis.ResultLogger.emit(logFn, ...
                sprintf('Analysis results %s QI:',label));
            robOpt.analysis.ResultLogger.logQiTable(logFn,qi);
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
            if isfield(samplingResults,'nominal') && ...
                    robOpt.analysis.ResultLogger.hasExpectedQi( ...
                    samplingResults.nominal)
                numPlans = numPlans + 1;
                labels{numPlans} = 'nominal plan';
                plans{numPlans} = samplingResults.nominal;
            end

            if isfield(samplingResults,'robust')
                for planIx = 1:numel(samplingResults.robust)
                    if robOpt.analysis.ResultLogger.hasExpectedQi( ...
                            samplingResults.robust{planIx})
                        numPlans = numPlans + 1;
                        labels{numPlans} = sprintf('robust plan %d',planIx);
                        plans{numPlans} = samplingResults.robust{planIx};
                    end
                end
            end

            if numPlans == 0
                return;
            end

            robOpt.analysis.ResultLogger.emit(logFn, ...
                ['Analysis QI from sampling expected DVH ' ...
                 '(same curve as trustband dotted line):']);
            if isfield(samplingResults,'scenarioMode')
                robOpt.analysis.ResultLogger.emit(logFn, ...
                    sprintf('  scenarioMode: %s', ...
                    char(samplingResults.scenarioMode)));
            end

            for planIx = 1:numPlans
                loggedAny = robOpt.analysis.ResultLogger.logExpectedQiResults( ...
                    logFn,labels{planIx},plans{planIx}) || loggedAny;
                robOpt.analysis.ResultLogger.logClinicalEndpointResults( ...
                    logFn,labels{planIx},plans{planIx},runConfig);
            end
        end

        function tf = hasExpectedQi(planResults)
            tf = isstruct(planResults) && isfield(planResults,'expectedQi') && ...
                ~isempty(planResults.expectedQi);
        end

        function logged = logExpectedQiResults(logFn,label,planResults)
            logged = false;
            if ~isfield(planResults,'expectedQi') || isempty(planResults.expectedQi)
                return;
            end

            robOpt.analysis.ResultLogger.emit(logFn, ...
                sprintf('Analysis results %s QI from expected DVH:',label));
            robOpt.analysis.ResultLogger.logQiTable(logFn,planResults.expectedQi);
            logged = true;
        end

        function logClinicalEndpointResults(logFn,label,planResults,runConfig)
            if ~isstruct(planResults) || ~isfield(planResults,'cstStat') || ...
                    isempty(planResults.cstStat)
                return;
            end

            endpoints = robOpt.analysis.ResultLogger.clinicalEndpoints(runConfig);
            if isempty(endpoints)
                return;
            end

            rows = robOpt.analysis.ResultLogger.clinicalEndpointRows( ...
                planResults.cstStat,endpoints);
            if isempty(rows)
                return;
            end

            robOpt.analysis.ResultLogger.emit(logFn, ...
                sprintf('Analysis clinical endpoints %s from expected DVH:',label));
            headers = {'Structure','Metric','Mean','Min','Max','Unit'};
            widths = [24 10 10 10 10 8];
            robOpt.analysis.ResultLogger.emit(logFn, ...
                ['  ' robOpt.analysis.ResultLogger.formatFixedWidthRow( ...
                headers,widths)]);
            robOpt.analysis.ResultLogger.emit(logFn, ...
                ['  ' robOpt.analysis.ResultLogger.formatFixedWidthRow( ...
                {'------------------------','----------','----------', ...
                 '----------','----------','--------'},widths)]);
            for i = 1:numel(rows)
                robOpt.analysis.ResultLogger.emit(logFn, ...
                    ['  ' robOpt.analysis.ResultLogger.formatFixedWidthRow( ...
                    {rows(i).structure,rows(i).metric, ...
                     robOpt.analysis.ResultLogger.formatNumber(rows(i).mean), ...
                     robOpt.analysis.ResultLogger.formatNumber(rows(i).min), ...
                     robOpt.analysis.ResultLogger.formatNumber(rows(i).max), ...
                     rows(i).unit},widths)]);
            end
        end

        function logQiTable(logFn,qi)
            [fields,headers] = robOpt.analysis.ResultLogger.qiSummaryColumns();
            widths = [24 repmat(8,1,numel(headers))];
            robOpt.analysis.ResultLogger.emit(logFn, ...
                ['  ' robOpt.analysis.ResultLogger.formatFixedWidthRow( ...
                [{'Structure'} headers],widths)]);
            robOpt.analysis.ResultLogger.emit(logFn, ...
                ['  ' robOpt.analysis.ResultLogger.formatFixedWidthRow( ...
                [{'------------------------'} ...
                repmat({'--------'},1,numel(headers))],widths)]);
            for i = 1:numel(qi)
                structureName = ...
                    robOpt.analysis.ExpectedQi.structTextField(qi(i), ...
                    {'name','VOIname'},sprintf('structure_%d',i));
                robOpt.analysis.ResultLogger.emit(logFn, ...
                    ['  ' robOpt.analysis.ResultLogger.formatFixedWidthRow( ...
                    [{structureName} ...
                    robOpt.analysis.ResultLogger.formatMetricList( ...
                    qi(i),fields)],widths)]);
            end
        end

        function [fields,headers] = qiSummaryColumns()
            fields = {'COV1','COV_95','COV_98','COV_99','mean','std','min','max', ...
                'D_95','D_98','D_2','D_50','V_17_1Gy','V_34_3Gy'};
            headers = {'COV1','COV95','COV98','COV99','Mean','Std','Min','Max', ...
                'D95','D98','D2','D50','V17.1','V34.3'};
        end

        function endpoints = clinicalEndpoints(runConfig)
            endpoints = struct([]);
            if ~isstruct(runConfig) || ~isfield(runConfig,'description')
                return;
            end

            switch char(runConfig.description)
                case 'prostate'
                    endpoints = [ ...
                        robOpt.analysis.ResultLogger.endpoint( ...
                        {'BLADDER'},'V60','V',60,'%'), ...
                        robOpt.analysis.ResultLogger.endpoint( ...
                        {'RECTUM'},'V40','V',40,'%'), ...
                        robOpt.analysis.ResultLogger.endpoint( ...
                        {'RECTUM'},'V50','V',50,'%')];
                case 'breast'
                    endpoints = [ ...
                        robOpt.analysis.ResultLogger.endpoint( ...
                        {'CONTRALATERAL LUNG','RIGHT LUNG','RIGTH LUNG'}, ...
                        'V50','V',50,'%'), ...
                        robOpt.analysis.ResultLogger.endpoint( ...
                        {'CONTRALATERAL LUNG','RIGHT LUNG','RIGTH LUNG'}, ...
                        'D5','D',5,'Gy'), ...
                        robOpt.analysis.ResultLogger.endpoint( ...
                        {'LEFT LUNG'},'V20','V',20,'%'), ...
                        robOpt.analysis.ResultLogger.endpoint( ...
                        {'LEFT LUNG'},'D20','D',20,'Gy'), ...
                        robOpt.analysis.ResultLogger.endpoint( ...
                        {'HEART'},'Dmean','mean',NaN,'Gy'), ...
                        robOpt.analysis.ResultLogger.endpoint( ...
                        {'CONTRALATERAL BREAST'},'Dmax','max',NaN,'Gy')];
            end
        end

        function endpoint = endpoint(structureNames,metric,kind,threshold,unit)
            endpoint = struct();
            endpoint.structureNames = structureNames;
            endpoint.metric = metric;
            endpoint.kind = kind;
            endpoint.threshold = threshold;
            endpoint.unit = unit;
        end

        function rows = clinicalEndpointRows(cstStat,endpoints)
            rows = struct([]);
            for endpointIx = 1:numel(endpoints)
                cstIx = robOpt.analysis.ResultLogger.findCstStat( ...
                    cstStat,endpoints(endpointIx).structureNames);
                if isempty(cstIx)
                    continue;
                end

                row = robOpt.analysis.ResultLogger.evaluateClinicalEndpoint( ...
                    cstStat(cstIx),endpoints(endpointIx));
                if isempty(row)
                    continue;
                end

                if isempty(rows)
                    rows = row;
                else
                    rows(end + 1) = row; %#ok<AGROW>
                end
            end
        end

        function ix = findCstStat(cstStat,structureNames)
            ix = [];
            for i = 1:numel(cstStat)
                structureName = robOpt.analysis.ExpectedQi.structTextField( ...
                    cstStat(i),{'name','VOIname'},'');
                for nameIx = 1:numel(structureNames)
                    if strcmpi(structureName,structureNames{nameIx})
                        ix = i;
                        return;
                    end
                end
            end
        end

        function row = evaluateClinicalEndpoint(cstStat,endpoint)
            row = struct([]);
            if ~isfield(cstStat,'dvhStat')
                return;
            end

            statNames = {'mean','min','max'};
            values = NaN(1,numel(statNames));
            for statIx = 1:numel(statNames)
                statName = statNames{statIx};
                if ~isfield(cstStat.dvhStat,statName)
                    continue;
                end

                values(statIx) = robOpt.analysis.ResultLogger.evaluateDvhEndpoint( ...
                    cstStat.dvhStat.(statName),endpoint);
            end

            row = struct();
            row.structure = robOpt.analysis.ExpectedQi.structTextField( ...
                cstStat,{'name','VOIname'},endpoint.structureNames{1});
            row.metric = endpoint.metric;
            row.mean = values(1);
            row.min = values(2);
            row.max = values(3);
            row.unit = endpoint.unit;
        end

        function value = evaluateDvhEndpoint(dvh,endpoint)
            value = NaN;
            if ~isfield(dvh,'doseGrid') || ~isfield(dvh,'volumePoints')
                return;
            end

            doseGrid = dvh.doseGrid(:);
            volumePoints = dvh.volumePoints(:);
            switch endpoint.kind
                case 'V'
                    value = 100 * robOpt.analysis.ExpectedQi.dvhVolumeAtDose( ...
                        doseGrid,volumePoints,endpoint.threshold);
                case 'D'
                    value = robOpt.analysis.ExpectedQi.dvhDoseAtVolume( ...
                        doseGrid,volumePoints,endpoint.threshold);
                case 'mean'
                    value = robOpt.analysis.ExpectedQi.meanDoseFromDvh( ...
                        doseGrid,volumePoints);
                case 'max'
                    value = robOpt.analysis.ExpectedQi.maxDoseFromDvh( ...
                        doseGrid,volumePoints);
            end
        end

        function values = formatMetricList(source,fields)
            values = cell(1,numel(fields));
            for i = 1:numel(fields)
                values{i} = robOpt.analysis.ResultLogger.formatMetricValue( ...
                    source,fields{i});
            end
        end

        function text = formatMetricValue(source,fieldName)
            if isfield(source,fieldName) && ...
                    robOpt.analysis.ResultLogger.isNumericScalar(source.(fieldName))
                text = robOpt.analysis.ResultLogger.formatNumber( ...
                    source.(fieldName));
            else
                text = '-';
            end
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

        function logSamplingResults(logFn,samplingResults)
            robOpt.analysis.ResultLogger.emit(logFn,'Analysis results sampling:');
            if isfield(samplingResults,'scenarioMode')
                robOpt.analysis.ResultLogger.emit(logFn, ...
                    sprintf('  scenarioMode: %s', ...
                    char(samplingResults.scenarioMode)));
            end

            headers = {'Plan','Gamma','Rob1','Rob2','MeanMax','StdMax','Figures'};
            widths = [24 repmat(9,1,numel(headers) - 1)];
            robOpt.analysis.ResultLogger.emit(logFn, ...
                ['  ' robOpt.analysis.ResultLogger.formatFixedWidthRow( ...
                headers,widths)]);
            robOpt.analysis.ResultLogger.emit(logFn, ...
                ['  ' robOpt.analysis.ResultLogger.formatFixedWidthRow( ...
                [{'------------------------'} ...
                repmat({'---------'},1,numel(headers) - 1)],widths)]);
            if isfield(samplingResults,'nominal')
                robOpt.analysis.ResultLogger.emit(logFn, ...
                    ['  ' robOpt.analysis.ResultLogger.formatSamplingPlanRow( ...
                    'nominal',samplingResults.nominal,widths)]);
            end

            if isfield(samplingResults,'robust')
                for planIx = 1:numel(samplingResults.robust)
                    robOpt.analysis.ResultLogger.emit(logFn, ...
                        ['  ' robOpt.analysis.ResultLogger.formatSamplingPlanRow( ...
                        sprintf('robust plan %d',planIx), ...
                        samplingResults.robust{planIx},widths)]);
                end
            end
        end

        function row = formatSamplingPlanRow(label,planResults,widths)
            values = {'-','-','-','-','-','-'};
            if isfield(planResults,'doseStat')
                doseStat = planResults.doseStat;
                if isfield(doseStat,'gammaAnalysis') && ...
                        isfield(doseStat.gammaAnalysis,'gammaPassRate') && ...
                        robOpt.analysis.ResultLogger.isNumericScalar( ...
                        doseStat.gammaAnalysis.gammaPassRate)
                    values{1} = robOpt.analysis.ResultLogger.formatNumber( ...
                        doseStat.gammaAnalysis.gammaPassRate);
                end
                if isfield(doseStat,'robustnessAnalysis')
                    robustness = doseStat.robustnessAnalysis;
                    if isfield(robustness,'robPassRate1') && ...
                            robOpt.analysis.ResultLogger.isNumericScalar( ...
                            robustness.robPassRate1)
                        values{2} = robOpt.analysis.ResultLogger.formatNumber( ...
                            robustness.robPassRate1);
                    end
                    if isfield(robustness,'robPassRate2') && ...
                            robOpt.analysis.ResultLogger.isNumericScalar( ...
                            robustness.robPassRate2)
                        values{3} = robOpt.analysis.ResultLogger.formatNumber( ...
                            robustness.robPassRate2);
                    end
                end
                if isfield(doseStat,'meanCubeW')
                    values{4} = robOpt.analysis.ResultLogger.formatNumber( ...
                        robOpt.analysis.ResultLogger.finiteMax(doseStat.meanCubeW));
                end
                if isfield(doseStat,'stdCubeW')
                    values{5} = robOpt.analysis.ResultLogger.formatNumber( ...
                        robOpt.analysis.ResultLogger.finiteMax(doseStat.stdCubeW));
                end
            end

            if isfield(planResults,'figureFiles')
                values{6} = sprintf('%d', ...
                    robOpt.analysis.ResultLogger.countSavedFigures( ...
                    planResults.figureFiles));
            end

            row = robOpt.analysis.ResultLogger.formatFixedWidthRow( ...
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
