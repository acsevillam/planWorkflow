classdef PrepareEditorController < handle
    % PrepareEditorController owns prepare/template panel state and widgets.

    properties (Access = private)
        Handles
        ObjectiveSetTabs = struct()
        ObjectiveTables = struct()
        SelectedObjectiveRows = struct()
        SelectedStructureRow = []
        ObjectiveEditedCallback = []
    end

    methods (Static)
        function obj = create(parent,template,state,callbacks)
            obj = planWorkflow.gui.panels.PrepareEditorController( ...
                parent,template,state,callbacks);
        end
    end

    methods
        function obj = PrepareEditorController(parent,template,state,callbacks)
            obj.Handles = ...
                planWorkflow.gui.panels.PrepareEditorPanel.create( ...
                parent,template,state,callbacks);
        end

        function loadPlanParameters(obj,runConfig,optionSets,selectedOptions)
            planWorkflow.gui.panels.PrepareEditorPanel.loadPlanParameters( ...
                obj.Handles,runConfig,optionSets,selectedOptions);
        end

        function runConfig = syncPlanParameters(obj,runConfig)
            runConfig = ...
                planWorkflow.gui.panels.PrepareEditorPanel.syncPlanParameters( ...
                obj.Handles,runConfig);
        end

        function tableHandle = activeParameterPanel(obj)
            tableHandle = ...
                planWorkflow.gui.panels.PrepareEditorPanel.activeParameterPanel( ...
                obj.Handles);
        end

        function controls = parameterControls(obj)
            controls = ...
                planWorkflow.gui.panels.PrepareEditorPanel.parameterControls( ...
                obj.Handles);
        end

        function index = descriptionIndex(obj)
            index = get(obj.control( ...
                obj.Handles.preparePatientImagesConfigTable,'description'), ...
                'Value');
        end

        function setDescriptionIndex(obj,index)
            set(obj.control(obj.Handles.preparePatientImagesConfigTable, ...
                'description'),'Value',index);
        end

        function index = acquisitionTypeIndex(obj)
            index = get(obj.control( ...
                obj.Handles.preparePatientImagesConfigTable, ...
                'AcquisitionType'),'Value');
        end

        function index = templateIndex(obj)
            index = get(obj.Handles.templatePopup,'Value');
        end

        function patch = applyDescriptionSelection(obj,runConfig, ...
                descriptionIds,includeOtherRadiationModes)
            selectedDescriptionIx = obj.descriptionIndex();
            patch = ...
                planWorkflow.gui.panels.PrepareTemplateSelection.selectDescription( ...
                runConfig,descriptionIds{selectedDescriptionIx}, ...
                includeOtherRadiationModes);
            patch.selectedDescriptionIx = selectedDescriptionIx;
            obj.applyTemplateSelectionPatch(patch);
        end

        function patch = applyTemplateSelection(obj,runConfig, ...
                templateIds,includeOtherRadiationModes)
            selectedTemplateIx = obj.templateIndex();
            patch = ...
                planWorkflow.gui.panels.PrepareTemplateSelection.selectTemplate( ...
                runConfig,templateIds,selectedTemplateIx, ...
                includeOtherRadiationModes);
            obj.applyTemplateSelectionPatch(patch);
        end

        function applyTemplateSelectionPatch(obj,patch)
            if isfield(patch,'templateIds') && ...
                    isfield(patch,'selectedTemplateIx')
                obj.setTemplateOptions(patch.templateIds, ...
                    patch.selectedTemplateIx);
            end
            if isfield(patch,'beamIds') && isfield(patch,'selectedBeamIx')
                obj.setBeamOptions(patch.beamIds,patch.selectedBeamIx);
            end
            if isfield(patch,'template') && isfield(patch.template, ...
                    'prescriptionDose')
                obj.setPrescriptionDose(patch.template.prescriptionDose);
            end
        end

        function setTemplateOptions(obj,templateIds,index)
            set(obj.Handles.templatePopup,'String',templateIds,'Value',index);
        end

        function templateId = selectedTemplateId(obj,templateIds)
            templateId = templateIds{obj.templateIndex()};
        end

        function currentCaseId = currentCaseId(obj,fallbackCaseId)
            currentCaseId = fallbackCaseId;
            if ~ishandle(obj.Handles.caseIdPopup)
                return;
            end
            popupCases = get(obj.Handles.caseIdPopup,'String');
            if ischar(popupCases)
                popupCases = cellstr(popupCases);
            end
            popupValue = get(obj.Handles.caseIdPopup,'Value');
            if ~isempty(popupCases) && popupValue <= numel(popupCases)
                currentCaseId = popupCases{popupValue};
            end
        end

        function setCaseOptions(obj,caseIds,index)
            set(obj.Handles.caseIdPopup,'String',caseIds,'Value',index);
        end

        function index = beamIndex(obj)
            index = get(obj.Handles.beamPopup,'Value');
        end

        function setBeamOptions(obj,beamIds,index)
            set(obj.Handles.beamPopup,'String',beamIds,'Value',index);
        end

        function setBeamIndex(obj,index)
            set(obj.Handles.beamPopup,'Value',index);
        end

        function beamId = selectedBeamId(obj,beamIds)
            beamId = beamIds{obj.beamIndex()};
        end

        function loadBeam(obj,beamConfig,optionSets,selectedOptions)
            planWorkflow.gui.ParameterPanelRenderer.load( ...
                obj.Handles.beamConfigTable,beamConfig, ...
                optionSets,selectedOptions);
        end

        function beamConfig = syncBeam(obj,beamConfig)
            beamConfig = planWorkflow.gui.ParameterPanelRenderer.toConfig( ...
                beamConfig,obj.Handles.beamConfigTable);
        end

        function value = beamFieldValue(obj,fieldName)
            value = planWorkflow.gui.ParameterPanelRenderer.fieldValue( ...
                obj.Handles.beamConfigTable,fieldName);
        end

        function setFractions(obj,value)
            set(obj.Handles.fractionsEdit,'String',num2str(value));
        end

        function value = fractionsValue(obj)
            value = str2double(get(obj.Handles.fractionsEdit,'String'));
        end

        function setPrescriptionDose(obj,value)
            set(obj.Handles.prescriptionEdit,'String',num2str(value));
        end

        function value = prescriptionDose(obj)
            value = ...
                planWorkflow.config.WorkflowParameterSchema.parseValue( ...
                get(obj.Handles.prescriptionEdit,'String'), ...
                'numericScalar','prescriptionDose');
        end

        function loadStructures(obj,template)
            obj.setTablePropertyIfChanged(obj.Handles.structuresTable, ...
                'Data', ...
                planWorkflow.gui.TemplateStructureTableAdapter.toTable( ...
                template));
        end

        function template = syncStructures(obj,template)
            template = ...
                planWorkflow.gui.TemplateStructureTableAdapter.applyTable( ...
                template,get(obj.Handles.structuresTable,'Data'));
        end

        function recordStructureSelection(obj,event)
            if ~isempty(event.Indices)
                obj.SelectedStructureRow = event.Indices(1);
            end
        end

        function changed = selectStructureColor(obj)
            changed = false;
            data = get(obj.Handles.structuresTable,'Data');
            rowIx = obj.SelectedStructureRow;
            if isempty(data) || isempty(rowIx) || ...
                    rowIx < 1 || rowIx > size(data,1)
                return;
            end
            currentColor = ...
                planWorkflow.gui.TemplateStructureTableAdapter.parseColorText( ...
                data{rowIx,4});
            selectedColor = uisetcolor(currentColor, ...
                sprintf('Select color for %s',char(data{rowIx,2})));
            if isequal(selectedColor,0)
                return;
            end
            data{rowIx,4} = ...
                planWorkflow.gui.TemplateStructureTableAdapter.colorText( ...
                selectedColor);
            set(obj.Handles.structuresTable,'Data',data);
            changed = true;
        end

        function addStructureRow(obj)
            data = get(obj.Handles.structuresTable,'Data');
            data(end + 1,:) = ...
                planWorkflow.gui.TemplateStructureTableAdapter.defaultRow( ...
                data);
            obj.SelectedStructureRow = size(data,1);
            set(obj.Handles.structuresTable,'Data',data);
        end

        function removeSelectedStructureRow(obj)
            data = get(obj.Handles.structuresTable,'Data');
            if isempty(data)
                return;
            end
            if isempty(obj.SelectedStructureRow)
                obj.SelectedStructureRow = size(data,1);
            end
            data(obj.SelectedStructureRow,:) = [];
            obj.SelectedStructureRow = [];
            set(obj.Handles.structuresTable,'Data',data);
        end

        function rebuildObjectiveTabs(obj,template,runConfig,editCallback)
            obj.ObjectiveEditedCallback = editCallback;
            existingTabs = get(obj.Handles.objectiveTabGroup,'Children');
            for tabIx = 1:numel(existingTabs)
                delete(existingTabs(tabIx));
            end
            obj.ObjectiveSetTabs = struct();
            obj.ObjectiveTables = struct();
            objectiveSetNames = ...
                planWorkflow.templates.PlanTemplate.objectiveSetNames( ...
                template);
            objectiveSetLabels = ...
                planWorkflow.gui.PlanEditorContract.objectiveSetLabelsForRunConfig( ...
                template,runConfig);
            for setIx = 1:numel(objectiveSetNames)
                setName = objectiveSetNames{setIx};
                obj.SelectedObjectiveRows.(setName) = [];
                obj.ObjectiveSetTabs.(setName) = uitab( ...
                    obj.Handles.objectiveTabGroup, ...
                    'Title',objectiveSetLabels{setIx});
                obj.ObjectiveTables.(setName) = uitable( ...
                    'Parent',obj.ObjectiveSetTabs.(setName), ...
                    'Units','normalized', ...
                    'Position',[0.00 0.00 1.00 1.00], ...
                    'ColumnName',{'Enabled','Structure','Type', ...
                    'Parameters JSON','Robustness','DosePulling JSON'}, ...
                    'ColumnEditable',[true true true true true true], ...
                    'ColumnFormat', ...
                    planWorkflow.gui.ObjectiveTableAdapter.columnFormat( ...
                    template), ...
                    'CellSelectionCallback',@(src,event) ...
                    obj.objectiveSelected(setName,event), ...
                    'CellEditCallback',@(src,event) ...
                    obj.objectiveEdited(setName,src,event));
            end
        end

        function loadObjectiveTables(obj,template,runConfig)
            setNames = planWorkflow.templates.PlanTemplate.objectiveSetNames( ...
                template);
            if obj.objectiveTabsNeedRebuild(setNames)
                obj.rebuildObjectiveTabs(template,runConfig, ...
                    obj.ObjectiveEditedCallback);
            end
            columnFormat = ...
                planWorkflow.gui.ObjectiveTableAdapter.columnFormat(template);
            for setIx = 1:numel(setNames)
                setName = setNames{setIx};
                obj.setTablePropertyIfChanged( ...
                    obj.ObjectiveTables.(setName),'ColumnFormat', ...
                    columnFormat);
                obj.setTablePropertyIfChanged( ...
                    obj.ObjectiveTables.(setName),'Data', ...
                    planWorkflow.gui.ObjectiveTableAdapter.toTable( ...
                    template,setName));
            end
        end

        function template = syncObjectiveTables(obj,template)
            setNames = fieldnames(obj.ObjectiveTables);
            for setIx = 1:numel(setNames)
                setName = setNames{setIx};
                if ishandle(obj.ObjectiveTables.(setName))
                    template = ...
                        planWorkflow.gui.ObjectiveTableAdapter.applyTable( ...
                        template,get(obj.ObjectiveTables.(setName), ...
                        'Data'),setName);
                end
            end
        end

        function template = syncObjectiveTable( ...
                obj,template,objectiveSetName,source)
            template = planWorkflow.gui.ObjectiveTableAdapter.applyTable( ...
                template,get(source,'Data'),objectiveSetName);
        end

        function addObjectiveRow(obj,template)
            objectiveSetName = obj.activeObjectiveSetName();
            objectivesTable = obj.activeObjectivesTable();
            selectedObjectiveRow = obj.SelectedObjectiveRows.( ...
                objectiveSetName);
            data = get(objectivesTable,'Data');
            if ~isempty(data) && ~isempty(selectedObjectiveRow)
                structureName = char(data{selectedObjectiveRow,2});
            else
                structureName = char(template.primaryTarget);
            end
            data(end + 1,:) = ...
                planWorkflow.gui.ObjectiveTableAdapter.defaultRow( ...
                structureName);
            set(objectivesTable,'Data',data);
        end

        function deleteObjectiveRow(obj)
            objectiveSetName = obj.activeObjectiveSetName();
            objectivesTable = obj.activeObjectivesTable();
            selectedObjectiveRow = obj.SelectedObjectiveRows.( ...
                objectiveSetName);
            data = get(objectivesTable,'Data');
            if isempty(data)
                return;
            end
            if isempty(selectedObjectiveRow)
                selectedObjectiveRow = size(data,1);
            end
            data(selectedObjectiveRow,:) = [];
            obj.SelectedObjectiveRows.(objectiveSetName) = [];
            set(objectivesTable,'Data',data);
        end

        function objectiveSetName = activeObjectiveSetName(obj)
            selectedTab = get(obj.Handles.objectiveTabGroup,'SelectedTab');
            objectiveSetName = 'reference';
            setNames = fieldnames(obj.ObjectiveSetTabs);
            for setIx = 1:numel(setNames)
                if isequal(selectedTab,obj.ObjectiveSetTabs.(setNames{setIx}))
                    objectiveSetName = setNames{setIx};
                    return;
                end
            end
        end

        function selectObjectiveSetTab(obj,objectiveSetName)
            objectiveSetName = char(objectiveSetName);
            if isfield(obj.ObjectiveSetTabs,objectiveSetName) && ...
                    ishandle(obj.ObjectiveSetTabs.(objectiveSetName))
                set(obj.Handles.objectiveTabGroup,'SelectedTab', ...
                    obj.ObjectiveSetTabs.(objectiveSetName));
            end
        end

        function setObjectiveTabTitle(obj,objectiveSetName,title)
            objectiveSetName = char(objectiveSetName);
            if isfield(obj.ObjectiveSetTabs,objectiveSetName) && ...
                    ishandle(obj.ObjectiveSetTabs.(objectiveSetName))
                set(obj.ObjectiveSetTabs.(objectiveSetName), ...
                    'Title',title);
            end
        end

        function planIx = activeRobustPlanIndex(obj,template)
            planIx = [];
            objectiveSetName = obj.activeObjectiveSetName();
            if strcmp(objectiveSetName,'reference')
                return;
            end
            robustObjectiveSets = ...
                planWorkflow.templates.PlanTemplate.robustObjectiveSets( ...
                template);
            planIx = find(strcmp({robustObjectiveSets.id}, ...
                objectiveSetName),1);
        end

        function controls = controlsForLock(obj)
            controls = [ ...
                obj.parameterControls(); ...
                obj.Handles.beamConfigTable.controls(:); ...
                obj.Handles.prescriptionEdit; ...
                obj.Handles.fractionsEdit; ...
                obj.Handles.addStructureButton; ...
                obj.Handles.removeStructureButton; ...
                obj.Handles.addRobustPlanButton; ...
                obj.Handles.deleteRobustPlanButton; ...
                obj.Handles.addObjectiveButton; ...
                obj.Handles.deleteObjectiveButton];
        end

        function tableHandles = tableHandlesForLock(obj)
            tableHandles = obj.Handles.structuresTable;
            setNames = fieldnames(obj.ObjectiveTables);
            for setIx = 1:numel(setNames)
                tableHandles = [tableHandles; ...
                    obj.ObjectiveTables.(setNames{setIx})]; %#ok<AGROW>
            end
        end
    end

    methods (Access = private)
        function controlHandle = control(~,tableHandle,fieldName)
            controlHandle = ...
                planWorkflow.gui.panels.PrepareEditorPanel.control( ...
                tableHandle,fieldName);
        end

        function tableHandle = activeObjectivesTable(obj)
            objectiveSetName = obj.activeObjectiveSetName();
            tableHandle = obj.ObjectiveTables.(objectiveSetName);
        end

        function objectiveSelected(obj,objectiveSetName,event)
            if ~isempty(event.Indices)
                obj.SelectedObjectiveRows.(objectiveSetName) = ...
                    event.Indices(1);
            end
        end

        function objectiveEdited(obj,objectiveSetName,source,event)
            if ~isempty(obj.ObjectiveEditedCallback)
                obj.ObjectiveEditedCallback(objectiveSetName,source,event);
            end
        end

        function needsRebuild = objectiveTabsNeedRebuild(obj,setNames)
            needsRebuild = ...
                planWorkflow.gui.PlanEditorContract.objectiveSetTabsNeedRebuild( ...
                fieldnames(obj.ObjectiveTables),setNames);
            if needsRebuild
                return;
            end
            for setIx = 1:numel(setNames)
                setName = setNames{setIx};
                if ~isfield(obj.ObjectiveSetTabs,setName) || ...
                        ~ishandle(obj.ObjectiveSetTabs.(setName)) || ...
                        ~isfield(obj.ObjectiveTables,setName) || ...
                        ~ishandle(obj.ObjectiveTables.(setName))
                    needsRebuild = true;
                    return;
                end
            end
        end

        function setTablePropertyIfChanged(~,tableHandle,propertyName,value)
            if ~ishandle(tableHandle)
                return;
            end
            try
                currentValue = get(tableHandle,propertyName);
                if isequaln(currentValue,value)
                    return;
                end
            catch
            end
            set(tableHandle,propertyName,value);
        end
    end
end
