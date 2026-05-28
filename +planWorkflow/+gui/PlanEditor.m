classdef PlanEditor
    % PlanEditor Interactive editor for effective workflow stage settings.

    methods (Static)
        function [template,runConfig,accepted,progressReporter, ...
                resumeStateFile] = edit(template,runConfig,options)
            originalTemplate = template;
            originalRunConfig = runConfig;
            accepted = false;
            progressReporter = [];
            resumeStateFile = '';
            if nargin < 3
                options = struct();
            end
            options = planWorkflow.gui.PlanEditor.normalizeEditorOptions( ...
                options);

            if ~usejava('desktop')
                error('planWorkflow:gui:PlanEditor:Unavailable', ...
                    'The interactive plan editor requires MATLAB GUI support.');
            end

            editorState = planWorkflow.gui.PlanEditorSession.initialize( ...
                template,runConfig);
            template = editorState.template;
            runConfig = editorState.runConfig;
            descriptionIds = editorState.descriptionIds;
            selectedDescriptionIx = editorState.selectedDescriptionIx;
            templateIds = editorState.templateIds;
            selectedTemplateIx = editorState.selectedTemplateIx;
            includeOtherRadiationModes = ...
                editorState.includeOtherRadiationModes;
            radiationModes = editorState.radiationModes;
            selectedRadiationModeIx = ...
                editorState.selectedRadiationModeIx;
            machineOptions = editorState.machineOptions;
            selectedMachineIx = editorState.selectedMachineIx;
            bioModelOptions = editorState.bioModelOptions;
            selectedBioModelIx = editorState.selectedBioModelIx;
            quantityOptions = editorState.quantityOptions;
            selectedQuantityIx = editorState.selectedQuantityIx;
            acquisitionTypes = editorState.acquisitionTypes;
            selectedAcquisitionTypeIx = ...
                editorState.selectedAcquisitionTypeIx;
            hlutFileNames = editorState.hlutFileNames;
            selectedHlutFileIx = editorState.selectedHlutFileIx;
            caseIds = editorState.caseIds;
            selectedCaseIx = editorState.selectedCaseIx;
            planParameterOptions = editorState.planParameterOptions;
            planParameterSelection = editorState.planParameterSelection;
            planParameterCallbacks = ...
                planWorkflow.gui.panels.PrepareEditorPanel.callbacks( ...
                struct('descriptionChanged',@descriptionChanged, ...
                'templateChanged',@templateChanged, ...
                'acquisitionTypeChanged',@acquisitionTypeChanged), ...
                @prepareConfigChanged);
            precomputeCallbacks = ...
                planWorkflow.gui.panels.PrecomputeEditorPanel.callbacks( ...
                struct('referencePlanLabelChanged', ...
                @referencePlanLabelChanged, ...
                'selectionChanged',@precomputeSelectionChanged, ...
                'planLabelChanged',@precomputePlanLabelChanged), ...
                @precomputeConfigChanged);
            beamIds = editorState.beamIds;
            selectedBeamIx = editorState.selectedBeamIx;
            objectiveSetNames = editorState.objectiveSetNames;
            frame = planWorkflow.gui.PlanEditorFrame.create(options, ...
                struct('cancel',@cancelCallback, ...
                'resume',@resumeActionCallback, ...
                'settings',@settingsActionCallback, ...
                'export',@exportPresetCallback, ...
                'calculate',@calculateCallback, ...
                'stop',@stopCallback));
            fig = frame.fig;
            tabGroup = frame.tabGroup;
            prepareTab = frame.prepareTab;
            precomputeTab = frame.precomputeTab;
            pullingTab = frame.pullingTab;
            optimizeTab = frame.optimizeTab;
            samplingTab = frame.samplingTab;
            analysisTab = frame.analysisTab;
            resumeActionButton = frame.resumeActionButton;
            settingsActionButton = frame.settingsActionButton;
            exportPresetButton = frame.exportPresetButton;
            calculateButton = frame.calculateButton;
            stopButton = frame.stopButton;
            cancelButton = frame.cancelButton;
            progressReporter = frame.progressReporter;
            configureProgressReporterForReanalysis();

            beamCallbacks = struct( ...
                'radiationMode',@beamRadiationModeChanged, ...
                'bioModel',@beamBioModelChanged, ...
                'plan_beams',@beamChanged, ...
                'includeOtherRadiationModes', ...
                @includeOtherRadiationModesChanged, ...
                'defaultCallback',@beamConfigChanged);
            preparePanelState = struct( ...
                'planParameterOptions',planParameterOptions, ...
                'planParameterSelection',planParameterSelection, ...
                'beamIds',{beamIds}, ...
                'radiationModes',{radiationModes}, ...
                'machineOptions',{machineOptions}, ...
                'bioModelOptions',{bioModelOptions}, ...
                'quantityOptions',{quantityOptions}, ...
                'selectedBeamIx',selectedBeamIx, ...
                'selectedRadiationModeIx',selectedRadiationModeIx, ...
                'selectedMachineIx',selectedMachineIx, ...
                'selectedBioModelIx',selectedBioModelIx, ...
                'selectedQuantityIx',selectedQuantityIx, ...
                'includeOtherRadiationModes',includeOtherRadiationModes);
            preparePanelCallbacks = struct( ...
                'planParameter',planParameterCallbacks, ...
                'beam',beamCallbacks, ...
                'addStructure',@addStructure, ...
                'removeStructure',@removeStructure, ...
                'structureSelected',@structureSelected, ...
                'structureEdited',@structureEdited, ...
                'prescriptionChanged',@prescriptionConfigChanged, ...
                'fractionsChanged',@fractionsConfigChanged, ...
                'addObjective',@addObjective, ...
                'deleteObjective',@deleteObjective, ...
                'addRobustPlan',@addRobustPlan, ...
                'deleteRobustPlan',@deleteRobustPlan);
            preparePanel = ...
                planWorkflow.gui.panels.PrepareEditorController.create( ...
                prepareTab,template,preparePanelState, ...
                preparePanelCallbacks);
            createObjectiveSetTabs();

            precomputePanel = ...
                planWorkflow.gui.panels.PrecomputeEditorPanel.create( ...
                precomputeTab,runConfig, ...
                struct('addRobustPlan',@addRobustPlanFromPrecompute, ...
                'deleteRobustPlan',@deleteRobustPlanFromPrecompute, ...
                'reference',precomputeCallbacks));
            rebuildPrecomputeRobustTabs();

            stageController = ...
                planWorkflow.gui.StageParameterPanelController.create( ...
                struct('dosePulling',pullingTab,'optimize',optimizeTab, ...
                'sampling',samplingTab,'analysis',analysisTab), ...
                runConfig,template,@setStageRunConfig, ...
                @showInvalidWorkflowSettings);
            set(fig,'WindowScrollWheelFcn', ...
                @parameterPanelScrollWheel);
            loadPrepareConfigTable();
            loadBeamControls();
            loadStructuresTable();
            loadObjectiveTable();
            loadPrecomputeConfigTable();
            stageController.loadAll();
            if options.readOnly
                lockEditorControls(false);
            end
            showInitialResults();
            uiwait(fig);

            if ~accepted
                if ishandle(fig)
                    delete(fig);
                end
                template = originalTemplate;
                runConfig = originalRunConfig;
                progressReporter = [];
            end

            function descriptionChanged(~,~)
                operationCleanup = beginInteractiveOperation( ...
                    'Updating plan description...');
                previousState = prepareSelectionSnapshot();

                try
                    selectionPatch = preparePanel.applyDescriptionSelection( ...
                        runConfig,descriptionIds, ...
                        includeOtherRadiationModes);
                    applyPrepareSelectionPatch(selectionPatch);
                    refreshAfterPrepareTemplateChange();
                catch ME
                    restorePrepareSelectionSnapshot(previousState);
                    errordlg(ME.message,'Invalid plan description');
                end
            end

            function acquisitionTypeChanged(~,~)
                operationCleanup = beginInteractiveOperation( ...
                    'Updating acquisition options...');
                selectedAcquisitionTypeIx = ...
                    preparePanel.acquisitionTypeIndex();
                runConfig.AcquisitionType = ...
                    acquisitionTypes{selectedAcquisitionTypeIx};
                planParameterSelection.AcquisitionType = ...
                    selectedAcquisitionTypeIx;
                refreshCaseIdOptions();
                refreshSamplingPanel();
            end

            function templateChanged(~,~)
                operationCleanup = beginInteractiveOperation( ...
                    'Loading plan template...');
                previousState = prepareSelectionSnapshot();

                try
                    selectionPatch = preparePanel.applyTemplateSelection( ...
                        runConfig,templateIds, ...
                        includeOtherRadiationModes);
                    applyPrepareSelectionPatch(selectionPatch);
                    refreshAfterPrepareTemplateChange();
                catch ME
                    restorePrepareSelectionSnapshot(previousState);
                    errordlg(ME.message,'Invalid plan template');
                end
            end

            function snapshot = prepareSelectionSnapshot()
                snapshot = struct( ...
                    'template',template, ...
                    'runConfig',runConfig, ...
                    'templateIds',{templateIds}, ...
                    'planParameterOptions',planParameterOptions, ...
                    'planParameterSelection',planParameterSelection, ...
                    'beamIds',{beamIds}, ...
                    'selectedBeamIx',selectedBeamIx, ...
                    'radiationModes',{radiationModes}, ...
                    'selectedDescriptionIx',selectedDescriptionIx, ...
                    'selectedTemplateIx',selectedTemplateIx);
            end

            function restorePrepareSelectionSnapshot(snapshot)
                template = snapshot.template;
                runConfig = snapshot.runConfig;
                templateIds = snapshot.templateIds;
                planParameterOptions = snapshot.planParameterOptions;
                planParameterSelection = snapshot.planParameterSelection;
                beamIds = snapshot.beamIds;
                selectedBeamIx = snapshot.selectedBeamIx;
                radiationModes = snapshot.radiationModes;
                selectedDescriptionIx = snapshot.selectedDescriptionIx;
                selectedTemplateIx = snapshot.selectedTemplateIx;
                preparePanel.setDescriptionIndex(selectedDescriptionIx);
                preparePanel.setTemplateOptions(templateIds,selectedTemplateIx);
                preparePanel.setBeamOptions(beamIds,selectedBeamIx);
                loadStructuresTable();
                loadAnalysisPanel();
            end

            function applyPrepareSelectionPatch(selectionPatch)
                runConfig = selectionPatch.runConfig;
                template = selectionPatch.template;
                templateIds = selectionPatch.templateIds;
                selectedTemplateIx = selectionPatch.selectedTemplateIx;
                radiationModes = selectionPatch.radiationModes;
                beamIds = selectionPatch.beamIds;
                selectedBeamIx = selectionPatch.selectedBeamIx;
                planParameterOptions.plan_template = templateIds;
                if isfield(selectionPatch,'selectedDescriptionIx')
                    selectedDescriptionIx = selectionPatch.selectedDescriptionIx;
                    planParameterSelection.description = selectedDescriptionIx;
                end
                planParameterSelection.plan_template = selectedTemplateIx;
            end

            function refreshAfterPrepareTemplateChange()
                refreshCaseIdOptions();
                loadBeamControls();
                loadPrecomputeConfigTable();
                loadStructuresTable();
                loadObjectiveTable();
                refreshSamplingPanel();
                loadAnalysisPanel();
            end

            function beamChanged(~,~)
                operationCleanup = beginInteractiveOperation( ...
                    'Updating beam set...');
                previousBeamIx = selectedBeamIx;
                try
                    saveBeamControls();
                    selectedBeamIx = preparePanel.beamIndex();
                    loadBeamControls();
                    loadPrecomputeConfigTable();
                catch ME
                    selectedBeamIx = previousBeamIx;
                    preparePanel.setBeamIndex(selectedBeamIx);
                    errordlg(ME.message,'Invalid beam set');
                end
            end

            function loadPrepareConfigTable()
                preparePanel.loadPlanParameters( ...
                    runConfig,planParameterOptions, ...
                    planParameterSelection);
            end

            function savePrepareConfigTable()
                runConfig = preparePanel.syncPlanParameters(runConfig);
            end

            function prepareConfigChanged(~,~)
                syncEditedConfig(@savePrepareConfigTable);
            end

            function precomputeSelectionChanged(~,~)
                operationCleanup = beginInteractiveOperation( ...
                    'Updating visible precompute fields...');
                refreshPrecomputeConfigRows();
            end

            function parameterPanelScrollWheel(~,event)
                tableHandle = activeParameterPanelHandle();
                if ~isempty(tableHandle)
                    planWorkflow.gui.ParameterPanelRenderer.scrollByWheel( ...
                        tableHandle,event.VerticalScrollCount);
                    return;
                end

                selectedTab = get(tabGroup,'SelectedTab');
                scrollSlider = ...
                    planWorkflow.gui.PanelScroller.selectedScrollableSlider( ...
                    selectedTab);
                planWorkflow.gui.PanelScroller.scrollByWheel( ...
                    scrollSlider,event.VerticalScrollCount);
            end

            function tableHandle = activeParameterPanelHandle()
                tableHandle = [];
                selectedTopTab = get(tabGroup,'SelectedTab');
                if isequal(selectedTopTab,prepareTab)
                    tableHandle = preparePanel.activeParameterPanel();
                elseif isequal(selectedTopTab,precomputeTab)
                    tableHandle = ...
                        planWorkflow.gui.panels.PrecomputeEditorPanel.activeParameterPanel( ...
                        precomputePanel);
                else
                    tableHandle = ...
                        stageController.activeParameterPanel(selectedTopTab);
                end
            end

            function refreshCaseIdOptions()
                currentCaseId = preparePanel.currentCaseId(runConfig.caseID);

                caseIds = ...
                    planWorkflow.gui.WorkflowParameterOptions.availableCaseIds( ...
                    runConfig.patientDataPath,runConfig.description, ...
                    runConfig.AcquisitionType);
                [caseIds,selectedCaseIx] = ...
                    planWorkflow.gui.WorkflowParameterOptions.caseIdOptionSet( ...
                    caseIds,currentCaseId);
                planParameterOptions.caseID = caseIds;
                planParameterSelection.caseID = selectedCaseIx;
                runConfig.caseID = caseIds{selectedCaseIx};
                preparePanel.setCaseOptions(caseIds,selectedCaseIx);
            end

            function loadPrecomputeConfigTable()
                [precomputePanel,runConfig,template] = ...
                    planWorkflow.gui.panels.PrecomputeEditorPanel.load( ...
                    precomputePanel,runConfig,template, ...
                    precomputeTransversalConfig());
                refreshReferencePlanTabTitle();
                refreshRobustPlanTabTitles();
            end

            function savePrecomputeConfigTable()
                [precomputePanel,runConfig,template,transversalConfig] = ...
                    planWorkflow.gui.panels.PrecomputeEditorPanel.sync( ...
                    precomputePanel,runConfig,template, ...
                    precomputeTransversalConfig());
                setCurrentBeamBixelWidth(transversalConfig.bixelWidth);
                refreshReferencePlanTabTitle();
                refreshRobustPlanTabTitles();
            end

            function precomputeConfigChanged(~,~)
                operationCleanup = beginInteractiveOperation( ...
                    'Updating precompute settings...');
                if syncEditedConfig(@savePrecomputeConfigTable)
                    loadObjectiveTable();
                    loadAnalysisPanel();
                end
            end

            function refreshPrecomputeConfigRows()
                precomputePanel = ...
                    planWorkflow.gui.panels.PrecomputeEditorPanel.refreshVisibility( ...
                    precomputePanel);
            end

            function rebuildPrecomputeRobustTabs()
                [runConfig,template] = ...
                    planWorkflow.gui.panels.PrecomputeEditorPanel.align( ...
                    runConfig,template);
                precomputePanel = ...
                    planWorkflow.gui.panels.PrecomputeEditorPanel.rebuildRobustTabs( ...
                    precomputePanel,runConfig);
            end

            function refreshPrecomputeConfigTableList()
                precomputePanel = ...
                    planWorkflow.gui.panels.PrecomputeEditorPanel.refreshConfigTables( ...
                    precomputePanel);
            end

            function ok = syncEditedConfig(saveFn)
                ok = false;
                if options.readOnly
                    return;
                end
                try
                    saveFn();
                    ok = true;
                catch ME
                    errordlg(ME.message,'Invalid workflow settings');
                end
            end

            function cleanupObj = beginInteractiveOperation(message)
                cleanupObj = onCleanup(@() []);
                if isempty(progressReporter) || ...
                        ~ismethod(progressReporter, ...
                        'beginInteractiveOperation')
                    return;
                end
                cleanupObj = ...
                    progressReporter.beginInteractiveOperation(message);
            end

            function setStageRunConfig(newRunConfig)
                runConfig = newRunConfig;
            end

            function showInvalidWorkflowSettings(message,title)
                errordlg(message,title);
            end

            function refreshSamplingPanel()
                stageController.setRunConfig(runConfig);
                stageController.refreshSampling();
                runConfig = stageController.runConfig();
            end

            function loadAnalysisPanel()
                stageController.setRunConfig(runConfig);
                stageController.setTemplate(template);
                stageController.loadAnalysis();
            end

            function loadBeamControls()
                beamConfig = currentBeamConfig();
                beamConfig.includeOtherRadiationModes = ...
                    includeOtherRadiationModes;
                selectedRadiationModeIx = ...
                    planWorkflow.gui.OptionValues.selectedOptionIndex( ...
                    radiationModes,runConfig.radiationMode);
                machineOptions = ...
                    planWorkflow.matRadCapabilitiesReader.supportedMachines( ...
                    runConfig.radiationMode);
                [machineOptions,selectedMachineIx] = ...
                    planWorkflow.gui.OptionValues.optionSetWithCurrent( ...
                    machineOptions,runConfig.machine);
                bioModelOptions = ...
                    planWorkflow.matRadCapabilitiesReader.supportedBioModels( ...
                    runConfig.radiationMode);
                [bioModelOptions,selectedBioModelIx] = ...
                    planWorkflow.gui.OptionValues.optionSetWithCurrent( ...
                    bioModelOptions,runConfig.bioModel);
                quantityOptions = ...
                    planWorkflow.matRadCapabilitiesReader.supportedDoseQuantities( ...
                    runConfig.radiationMode,runConfig.bioModel);
                [quantityOptions,selectedQuantityIx] = ...
                    planWorkflow.gui.OptionValues.optionSetWithCurrent( ...
                    quantityOptions,runConfig.quantityOpt);
                preparePanel.setFractions(beamConfig.numOfFractions);
                preparePanel.loadBeam(beamConfig, ...
                    planWorkflow.gui.WorkflowParameterOptions.prepareBeamOptionSets( ...
                    beamIds,radiationModes,machineOptions, ...
                    bioModelOptions,quantityOptions), ...
                    struct('plan_beams',selectedBeamIx, ...
                    'radiationMode',selectedRadiationModeIx, ...
                    'machine',selectedMachineIx, ...
                    'bioModel',selectedBioModelIx, ...
                    'quantityOpt',selectedQuantityIx, ...
                    'includeOtherRadiationModes', ...
                    includeOtherRadiationModes));
            end

            function saveBeamControls()
                beamSet = preparePanel.syncBeam(currentBeamConfig());
                includeOtherRadiationModes = ...
                    logical(beamSet.includeOtherRadiationModes);
                beamSet = rmfield(beamSet,'includeOtherRadiationModes');
                radiationModes = ...
                    planWorkflow.templates.BeamSelection.radiationModeOptions( ...
                    template,includeOtherRadiationModes);
                runConfig.radiationMode = char(beamSet.radiationMode);
                runConfig.machine = char(beamSet.machine);
                runConfig.bioModel = char(beamSet.bioModel);
                runConfig.quantityOpt = char(beamSet.quantityOpt);
                runConfig.plan_beams = char(beamSet.plan_beams);
                beamSet = rmfield(beamSet, ...
                    {'radiationMode','machine','bioModel','quantityOpt'});
                selectedRadiationModeIx = ...
                    planWorkflow.gui.OptionValues.selectedOptionIndex( ...
                    radiationModes,runConfig.radiationMode);
                beamSet.numOfFractions = preparePanel.fractionsValue();
                if ~isfinite(beamSet.bixelWidth)
                    error('planWorkflow:gui:PlanEditor:InvalidBeamSet', ...
                        'bixelWidth must be finite.');
                end
                if isempty(beamSet.couchAngles)
                    beamSet.couchAngles = zeros(1,numel(beamSet.gantryAngles));
                end
                if numel(beamSet.couchAngles) ~= numel(beamSet.gantryAngles)
                    error('planWorkflow:gui:PlanEditor:InvalidBeamSet', ...
                        'couchAngles must match gantryAngles length.');
                end
                beamSet = rmfield(beamSet,'plan_beams');
                template.beamSets(selectedBeamIx) = beamSet;
                template.radiationModes = ...
                    planWorkflow.templates.BeamSelection.upsertRadiationModeSpec( ...
                    template.radiationModes,runConfig.radiationMode, ...
                    runConfig.plan_beams,runConfig.machine, ...
                    runConfig.bioModel);
            end

            function beamConfigChanged(~,~)
                operationCleanup = beginInteractiveOperation( ...
                    'Updating beam settings...');
                syncEditedConfig(@saveBeamControls);
                loadBeamControls();
                loadAnalysisPanel();
            end

            function beamRadiationModeChanged(~,~)
                operationCleanup = beginInteractiveOperation( ...
                    'Updating radiation mode...');
                runConfig.radiationMode = ...
                    preparePanel.beamFieldValue('radiationMode');
                runConfig = ...
                    planWorkflow.templates.BeamSelection.applyTemplateDefaults( ...
                    runConfig,template,true);
                selectedBeamIx = find(strcmp(beamIds, ...
                    runConfig.plan_beams),1);
                if isempty(selectedBeamIx)
                    selectedBeamIx = 1;
                    runConfig.plan_beams = beamIds{selectedBeamIx};
                end
                preparePanel.setBeamIndex(selectedBeamIx);
                loadBeamControls();
            end

            function beamBioModelChanged(~,~)
                operationCleanup = beginInteractiveOperation( ...
                    'Updating biological model...');
                runConfig.bioModel = ...
                    preparePanel.beamFieldValue('bioModel');
                runConfig = ...
                    planWorkflow.plan.DoseQuantityResolver.applyDefaultToRunConfig( ...
                    runConfig,true);
                loadBeamControls();
            end

            function includeOtherRadiationModesChanged(~,~)
                operationCleanup = beginInteractiveOperation( ...
                    'Updating radiation-mode options...');
                includeOtherRadiationModes = ...
                    preparePanel.beamFieldValue('includeOtherRadiationModes');
                radiationModes = ...
                    planWorkflow.templates.BeamSelection.radiationModeOptions( ...
                    template,includeOtherRadiationModes);
                if ~any(strcmp(runConfig.radiationMode,radiationModes))
                    runConfig.radiationMode = radiationModes{1};
                    runConfig = ...
                        planWorkflow.templates.BeamSelection.applyTemplateDefaults( ...
                        runConfig,template,true);
                    selectedBeamIx = find(strcmp(beamIds, ...
                        runConfig.plan_beams),1);
                    if isempty(selectedBeamIx)
                        selectedBeamIx = 1;
                        runConfig.plan_beams = beamIds{selectedBeamIx};
                    end
                    preparePanel.setBeamIndex(selectedBeamIx);
                end
                loadBeamControls();
            end

            function beamConfig = currentBeamConfig()
                beamConfig = template.beamSets(selectedBeamIx);
                beamConfig.plan_beams = beamIds{selectedBeamIx};
                if ~isfield(beamConfig,'couchAngles') || ...
                        isempty(beamConfig.couchAngles)
                    beamConfig.couchAngles = [];
                end
                beamConfig.radiationMode = runConfig.radiationMode;
                beamConfig.machine = runConfig.machine;
                beamConfig.bioModel = runConfig.bioModel;
                beamConfig.quantityOpt = runConfig.quantityOpt;
                bioModelInfo = ...
                    planWorkflow.plan.DoseQuantityResolver.bioModelInfoFromRunConfig( ...
                    runConfig);
                beamConfig.bioOpt = bioModelInfo.bioOpt;
                beamConfig.quantityVis = bioModelInfo.quantityVis;
            end

            function config = precomputeTransversalConfig()
                config = runConfig;
                beamConfig = currentBeamConfig();
                config.bixelWidth = beamConfig.bixelWidth;
            end

            function setCurrentBeamBixelWidth(bixelWidth)
                if ~isfinite(bixelWidth)
                    error('planWorkflow:gui:PlanEditor:InvalidBeamSet', ...
                        'bixelWidth must be finite.');
                end
                template.beamSets(selectedBeamIx).bixelWidth = bixelWidth;
            end

            function loadStructuresTable()
                preparePanel.loadStructures(template);
            end

            function saveStructuresTable()
                template = preparePanel.syncStructures(template);
            end

            function structureSelected(~,event)
                preparePanel.recordStructureSelection(event);
                if ~isempty(event.Indices) && size(event.Indices,2) >= 2 && ...
                        event.Indices(2) == 4 && ...
                        preparePanel.selectStructureColor()
                    structureEdited();
                end
            end

            function structureEdited(varargin)
                operationCleanup = beginInteractiveOperation( ...
                    'Updating structures...');
                try
                    saveStructuresTable();
                    loadObjectiveTable();
                    loadAnalysisPanel();
                catch ME
                    loadStructuresTable();
                    loadObjectiveTable();
                    loadAnalysisPanel();
                    errordlg(ME.message,'Invalid structure');
                end
            end

            function addStructure(~,~)
                operationCleanup = beginInteractiveOperation( ...
                    'Adding structure...');
                preparePanel.addStructureRow();
                saveStructuresTable();
                loadObjectiveTable();
                loadAnalysisPanel();
            end

            function removeStructure(~,~)
                operationCleanup = beginInteractiveOperation( ...
                    'Removing structure...');
                preparePanel.removeSelectedStructureRow();
                saveStructuresTable();
                loadObjectiveTable();
                loadAnalysisPanel();
            end

            function createObjectiveSetTabs()
                preparePanel.rebuildObjectiveTabs( ...
                    template,runConfig,@objectiveEdited);
            end

            function loadObjectiveTable()
                preparePanel.loadObjectiveTables(template,runConfig);
            end

            function saveObjectiveTable()
                template = preparePanel.syncObjectiveTables(template);
            end

            function objectiveEdited(objectiveSetName,source,event)
                operationCleanup = beginInteractiveOperation( ...
                    'Updating objectives...');
                robustnessEdited = ...
                    planWorkflow.gui.ObjectiveTableAdapter.isRobustnessEdit( ...
                    event);
                robustObjectiveEdited = ~strcmp(char(objectiveSetName), ...
                    'reference');
                precomputeNeedsRefresh = robustnessEdited || ...
                    robustObjectiveEdited;
                try
                    if robustnessEdited
                        data = get(source,'Data');
                        robustness = ...
                            planWorkflow.gui.ObjectiveTableAdapter.editedRobustness( ...
                            data,event);
                        data = ...
                            planWorkflow.gui.ObjectiveTableAdapter.harmonizeNonNoneRobustness( ...
                            data,robustness);
                        set(source,'Data',data);
                    end
                    template = preparePanel.syncObjectiveTable( ...
                        template,objectiveSetName,source);
                    if robustnessEdited
                        runConfig = ...
                            planWorkflow.gui.PlanEditorContract.retargetPrecomputeRobustnessFromObjectives( ...
                            runConfig,template);
                    end
                    if precomputeNeedsRefresh
                        loadPrecomputeConfigTable();
                    end
                    if robustnessEdited
                        loadObjectiveTable();
                    end
                    loadAnalysisPanel();
                catch ME
                    loadObjectiveTable();
                    if precomputeNeedsRefresh
                        loadPrecomputeConfigTable();
                    end
                    loadAnalysisPanel();
                    errordlg(ME.message,'Invalid objective');
                end
            end

            function prescriptionConfigChanged(~,~)
                syncEditedConfig(@savePrescriptionDose);
            end

            function fractionsConfigChanged(~,~)
                syncEditedConfig(@saveBeamControls);
            end

            function savePrescriptionDose()
                template.prescriptionDose = preparePanel.prescriptionDose();
            end

            function addObjective(~,~)
                operationCleanup = beginInteractiveOperation( ...
                    'Adding objective...');
                preparePanel.addObjectiveRow(template);
            end

            function deleteObjective(~,~)
                operationCleanup = beginInteractiveOperation( ...
                    'Deleting objective...');
                preparePanel.deleteObjectiveRow();
            end

            function addRobustPlan(~,~)
                operationCleanup = beginInteractiveOperation( ...
                    'Adding robust plan...');
                saveObjectiveTable();
                newObjectiveSetName = appendRobustPlan( ...
                    activeObjectiveRobustPlanIx());
                createObjectiveSetTabs();
                loadObjectiveTable();
                loadPrecomputeConfigTable();
                selectObjectiveSetTab(newObjectiveSetName);
            end

            function addRobustPlanFromPrecompute(~,~)
                operationCleanup = beginInteractiveOperation( ...
                    'Adding robust plan...');
                saveObjectiveTable();
                savePrecomputeConfigTable();
                newObjectiveSetName = appendRobustPlan( ...
                    activePrecomputeRobustPlanIx());
                createObjectiveSetTabs();
                loadObjectiveTable();
                loadPrecomputeConfigTable();
                selectObjectiveSetTab(newObjectiveSetName);
                selectPrecomputeRobustPlanTab(newObjectiveSetName);
            end

            function newObjectiveSetName = appendRobustPlan(sourcePlanIx)
                robustObjectiveSets = ...
                    planWorkflow.templates.PlanTemplate.robustObjectiveSets( ...
                    template);
                newIx = numel(robustObjectiveSets) + 1;
                existingNames = ...
                    planWorkflow.templates.PlanTemplate.objectiveSetNames( ...
                    template);
                newId = sprintf('robust_%d',newIx);
                while any(strcmp(existingNames,newId))
                    newIx = newIx + 1;
                    newId = sprintf('robust_%d',newIx);
                end
                newLabel = sprintf('Robust %d',newIx);
                if ~isempty(sourcePlanIx) && ...
                        sourcePlanIx >= 1 && ...
                        sourcePlanIx <= numel(robustObjectiveSets)
                    newSet = robustObjectiveSets(sourcePlanIx);
                elseif isempty(robustObjectiveSets)
                    newSet = planWorkflow.templates.PlanTemplate.objectiveSet( ...
                        template,'reference');
                else
                    newSet = robustObjectiveSets(end);
                end
                newSet.id = newId;
                newSet.label = newLabel;
                template.objectiveSets.robustPlans(end + 1) = newSet;

                runConfig = ...
                    planWorkflow.gui.PlanEditorContract.alignRobustPlansWithTemplate( ...
                    runConfig,template);
                newObjectiveSetName = newId;
            end

            function deleteRobustPlan(~,~)
                operationCleanup = beginInteractiveOperation( ...
                    'Deleting robust plan...');
                deleteRobustPlanByIx(activeObjectiveRobustPlanIx());
            end

            function deleteRobustPlanFromPrecompute(~,~)
                operationCleanup = beginInteractiveOperation( ...
                    'Deleting robust plan...');
                saveObjectiveTable();
                savePrecomputeConfigTable();
                deleteRobustPlanByIx(activePrecomputeRobustPlanIx());
            end

            function deleteRobustPlanByIx(planIx)
                if isempty(planIx)
                    return;
                end
                robustObjectiveSets = ...
                    planWorkflow.templates.PlanTemplate.robustObjectiveSets( ...
                    template);
                if numel(robustObjectiveSets) <= 1
                    return;
                end
                if planIx < 1 || planIx > numel(robustObjectiveSets)
                    return;
                end
                robustObjectiveSets(planIx) = [];
                template.objectiveSets.robustPlans = robustObjectiveSets;
                robustPlans = ...
                    planWorkflow.config.RobustPlanConfig.plansFromRunConfig( ...
                    runConfig);
                if numel(robustPlans) >= planIx
                    robustPlans(planIx) = [];
                    runConfig.precompute.robustPlans = ...
                        planWorkflow.config.RobustPlanConfig.normalizePlans( ...
                        robustPlans);
                end
                createObjectiveSetTabs();
                loadObjectiveTable();
                loadPrecomputeConfigTable();
            end

            function referencePlanLabelChanged(source,~)
                if options.readOnly
                    return;
                end
                label = ...
                    planWorkflow.gui.PlanEditorContract.normalizeReferencePlanLabel( ...
                    get(source,'String'));
                runConfig.precompute.reference.label = label;
                set(source,'String',label);
                refreshReferencePlanTabTitle();
            end

            function refreshReferencePlanTabTitle()
                reference = ...
                    planWorkflow.config.RobustPlanConfig.referenceFromRunConfig( ...
                    runConfig);
                title = planWorkflow.gui.panels.PrecomputePanel.referencePlanTabTitle( ...
                    reference.label);
                if ishandle(precomputePanel.referenceTab)
                    set(precomputePanel.referenceTab,'Title',title);
                end
                preparePanel.setObjectiveTabTitle('reference',title);
            end

            function planIx = activeObjectiveRobustPlanIx()
                planIx = preparePanel.activeRobustPlanIndex(template);
            end

            function planIx = activePrecomputeRobustPlanIx()
                planIx = [];
                if ~ishandle(precomputePanel.tabGroup)
                    return;
                end
                planIx = ...
                    planWorkflow.gui.panels.PrecomputeEditorPanel.robustTabIndex( ...
                    precomputePanel,get(precomputePanel.tabGroup,'SelectedTab'));
            end

            function selectObjectiveSetTab(objectiveSetName)
                preparePanel.selectObjectiveSetTab(objectiveSetName);
            end

            function selectPrecomputeRobustPlanTab(objectiveSetName)
                objectiveSetName = char(objectiveSetName);
                robustPlans = ...
                    planWorkflow.config.RobustPlanConfig.plansFromRunConfig( ...
                    runConfig);
                planIx = ...
                    planWorkflow.gui.PlanEditorContract.findRobustPlanByObjectiveSet( ...
                    robustPlans,objectiveSetName);
                if planIx ~= 0 && ...
                        planIx <= numel(precomputePanel.robustTabs) && ...
                        ishandle(precomputePanel.robustTabs(planIx))
                    set(precomputePanel.tabGroup,'SelectedTab', ...
                        precomputePanel.robustTabs(planIx));
                end
            end

            function precomputePlanLabelChanged(source,~)
                if options.readOnly
                    return;
                end
                robustPlanIx = precomputeRobustPlanIxFromControl(source);
                if isempty(robustPlanIx)
                    return;
                end
                try
                    label = ...
                        planWorkflow.gui.PlanEditorContract.normalizeRobustPlanLabel( ...
                        get(source,'String'));
                    runConfig.precompute.robustPlans(robustPlanIx).label = label;
                    set(source,'String',label);
                    template = ...
                        planWorkflow.gui.PlanEditorContract.syncRobustObjectiveSetLabels( ...
                        template,runConfig);
                    refreshRobustPlanTabTitles();
                catch ME
                    set(source,'String', ...
                        char(runConfig.precompute.robustPlans( ...
                        robustPlanIx).label));
                    errordlg(ME.message,'Invalid plan label');
                end
            end

            function robustPlanIx = precomputeRobustPlanIxFromControl( ...
                    control)
                robustPlanIx = [];
                for candidateIx = 1:numel( ...
                        precomputePanel.robustConfigTables)
                    if any(precomputePanel.robustConfigTables( ...
                            candidateIx).controls ...
                            == control)
                        robustPlanIx = candidateIx;
                        return;
                    end
                end
            end

            function refreshRobustPlanTabTitles()
                robustPlans = ...
                    planWorkflow.config.RobustPlanConfig.plansFromRunConfig( ...
                    runConfig);
                for robustPlanIx = 1:min(numel(precomputePanel.robustTabs), ...
                        numel(robustPlans))
                    label = char(robustPlans(robustPlanIx).label);
                    if ishandle(precomputePanel.robustTabs(robustPlanIx))
                        set(precomputePanel.robustTabs(robustPlanIx), ...
                            'Title',label);
                    end
                    objectiveSetName = ...
                        char(robustPlans(robustPlanIx).objectiveSetName);
                    preparePanel.setObjectiveTabTitle( ...
                        objectiveSetName,label);
                end
            end

            function saveCurrentEditorState()
                savePrepareConfigTable();
                saveBeamControls();
                saveStructuresTable();
                saveObjectiveTable();
                savePrecomputeConfigTable();
                stageController.setRunConfig(runConfig);
                runConfig = stageController.syncAll(runConfig);
                template.prescriptionDose = preparePanel.prescriptionDose();
                runConfig.plan_template = ...
                    preparePanel.selectedTemplateId(templateIds);
                runConfig.plan_beams = preparePanel.selectedBeamId(beamIds);
                runConfig = ...
                    planWorkflow.config.DosePullingConfig.validateActiveStartConfigs( ...
                    template,runConfig);
                [template,runConfig] = ...
                    planWorkflow.config.WorkflowContractValidator.validateAction( ...
                    template,runConfig);
                runConfig = options.validateRunConfig(runConfig,template);
                [template,runConfig] = ...
                    planWorkflow.config.WorkflowContractValidator.validateAction( ...
                    template,runConfig);
            end

            function exportPresetCallback(~,~)
                operationCleanup = beginInteractiveOperation( ...
                    'Preparing export...');
                try
                    saveCurrentEditorState();
                    presetNames = ...
                        planWorkflow.gui.PlanPresetWriter.defaultPresetNames( ...
                        runConfig);
                    clear operationCleanup;
                    answer = ...
                        planWorkflow.gui.PlanEditor.promptExportPresetNames( ...
                        runConfig,template,presetNames);
                    if isempty(answer)
                        return;
                    end

                    operationCleanup = beginInteractiveOperation( ...
                        'Exporting preset...');
                    switch answer.action
                        case 'template'
                            saveResult = ...
                                planWorkflow.gui.PlanPresetWriter.saveTemplate( ...
                                template,runConfig,answer.templateId);
                            template = saveResult.template;
                            runConfig.plan_template = saveResult.templateId;
                            selectTemplateOption(saveResult.templateId);
                            msgbox(sprintf('Exported template:\n%s', ...
                                saveResult.templateFolder),'Exported');
                        case 'macro'
                            saveResult = ...
                                planWorkflow.gui.PlanPresetWriter.saveMacro( ...
                                runConfig,answer.templateId,answer.macroName);
                            msgbox(sprintf('Exported macro:\n%s', ...
                                saveResult.macroFile),'Exported');
                        case 'both'
                            saveResult = ...
                                planWorkflow.gui.PlanPresetWriter.save( ...
                                template,runConfig,answer.templateId, ...
                                answer.macroName);
                            template = saveResult.template;
                            runConfig.plan_template = saveResult.templateId;
                            selectTemplateOption(saveResult.templateId);
                            msgbox(sprintf(['Exported template:\n%s\n\n' ...
                                'Exported macro:\n%s'], ...
                                saveResult.templateFolder, ...
                                saveResult.macroFile),'Exported');
                    end
                catch ME
                    errordlg(ME.message,'Export failed');
                end
            end

            function selectTemplateOption(templateId)
                templateId = char(templateId);
                if ~any(strcmp(templateIds,templateId))
                    templateIds{end + 1} = templateId;
                    templateIds = sort(templateIds);
                end
                selectedTemplateIx = find(strcmp(templateIds,templateId),1);
                planParameterOptions.plan_template = templateIds;
                planParameterSelection.plan_template = selectedTemplateIx;
                preparePanel.setTemplateOptions( ...
                    templateIds,selectedTemplateIx);
            end

            function calculateCallback(~,~)
                operationCleanup = beginInteractiveOperation( ...
                    'Validating workflow settings...');
                try
                    if ~options.readOnly
                        saveCurrentEditorState();
                    end
                    resumeStateFile = '';
                    accepted = true;
                    lockEditorControls(true);
                    set(cancelButton,'String','Close');
                    clear operationCleanup;
                    progressReporter.calculationAccepted();
                    uiresume(fig);
                catch ME
                    if ishandle(calculateButton)
                        set(calculateButton,'Enable','on');
                    end
                    errordlg(ME.message,'Invalid workflow settings');
                end
            end

            function configureProgressReporterForReanalysis()
                if ~isempty(options.progressReporterReadyCallback)
                    options.progressReporterReadyCallback(progressReporter);
                end
                if ismethod(progressReporter, ...
                        'setRecalculateAnalysisConfigProvider')
                    progressReporter.setRecalculateAnalysisConfigProvider( ...
                        @currentAnalysisConfigFromEditor);
                end
                if ~isempty(options.recalculateAnalysisCallback) && ...
                        ismethod(progressReporter, ...
                        'setRecalculateAnalysisCallback')
                    progressReporter.setRecalculateAnalysisCallback( ...
                        options.recalculateAnalysisCallback);
                end
            end

            function analysis = currentAnalysisConfigFromEditor()
                previousRunConfig = runConfig;
                try
                    stageController.setRunConfig(runConfig);
                    updatedRunConfig = ...
                        stageController.syncAnalysisStrict(runConfig);
                    updatedRunConfig = ...
                        options.validateRunConfig(updatedRunConfig,template);
                    runConfig = updatedRunConfig;
                    stageController.setRunConfig(runConfig);
                    analysis = runConfig.analysis;
                catch ME
                    runConfig = previousRunConfig;
                    stageController.setRunConfig(runConfig);
                    rethrow(ME);
                end
            end

            function showInitialResults()
                if isstruct(options.initialResults) && ...
                        ~isempty(fieldnames(options.initialResults))
                    progressReporter.showResults(options.initialResults);
                end
            end

            function settingsActionCallback(~,~)
                operationCleanup = beginInteractiveOperation( ...
                    'Preparing workflow settings...');
                try
                    if ~options.readOnly
                        savePrepareConfigTable();
                    end
                    clear operationCleanup;
                    [updatedRunConfig,settingsAccepted] = ...
                        planWorkflow.gui.PlanEditor.promptWorkflowSettings( ...
                        runConfig);
                    if settingsAccepted
                        operationCleanup = beginInteractiveOperation( ...
                            'Applying workflow settings...');
                        runConfig = updatedRunConfig;
                        refreshCaseIdOptions();
                        refreshSamplingPanel();
                    end
                catch ME
                    errordlg(ME.message,'Invalid workflow settings');
                end
            end

            function resumeActionCallback(~,~)
                candidateStateFile = ...
                    planWorkflow.gui.PlanEditor.promptResumeStateFile( ...
                    options);
                if isempty(candidateStateFile)
                    return;
                end
                try
                    operationCleanup = beginInteractiveOperation( ...
                        'Loading workflow state...');
                    resumedEditorState = ...
                        planWorkflow.gui.PlanEditor.resumeEditorState( ...
                        candidateStateFile);
                    applyResumeEditorState(resumedEditorState);
                    clear operationCleanup;
                catch ME
                    errordlg(ME.message,'Invalid workflow state');
                    return;
                end
                resumeStateFile = candidateStateFile;
                accepted = true;
                lockEditorControls(true);
                set(cancelButton,'String','Close');
                progressReporter.calculationAccepted();
                progressReporter.log(sprintf( ...
                    'Resuming workflow from %s.',candidateStateFile));
                showResumeInitialResults(resumedEditorState.initialResults);
                uiresume(fig);
            end

            function applyResumeEditorState(resumedEditorState)
                editorState = ...
                    planWorkflow.gui.PlanEditorSession.initialize( ...
                    resumedEditorState.template, ...
                    resumedEditorState.runConfig);
                template = editorState.template;
                runConfig = editorState.runConfig;
                descriptionIds = editorState.descriptionIds;
                selectedDescriptionIx = editorState.selectedDescriptionIx;
                templateIds = editorState.templateIds;
                selectedTemplateIx = editorState.selectedTemplateIx;
                includeOtherRadiationModes = ...
                    editorState.includeOtherRadiationModes;
                radiationModes = editorState.radiationModes;
                selectedRadiationModeIx = ...
                    editorState.selectedRadiationModeIx;
                machineOptions = editorState.machineOptions;
                selectedMachineIx = editorState.selectedMachineIx;
                bioModelOptions = editorState.bioModelOptions;
                selectedBioModelIx = editorState.selectedBioModelIx;
                quantityOptions = editorState.quantityOptions;
                selectedQuantityIx = editorState.selectedQuantityIx;
                acquisitionTypes = editorState.acquisitionTypes;
                selectedAcquisitionTypeIx = ...
                    editorState.selectedAcquisitionTypeIx;
                hlutFileNames = editorState.hlutFileNames;
                selectedHlutFileIx = editorState.selectedHlutFileIx;
                caseIds = editorState.caseIds;
                selectedCaseIx = editorState.selectedCaseIx;
                planParameterOptions = editorState.planParameterOptions;
                planParameterSelection = ...
                    editorState.planParameterSelection;
                beamIds = editorState.beamIds;
                selectedBeamIx = editorState.selectedBeamIx;
                objectiveSetNames = editorState.objectiveSetNames;

                preparePanel.setDescriptionIndex(selectedDescriptionIx);
                preparePanel.setTemplateOptions(templateIds, ...
                    selectedTemplateIx);
                preparePanel.setCaseOptions(caseIds,selectedCaseIx);
                preparePanel.setBeamOptions(beamIds,selectedBeamIx);
                loadPrepareConfigTable();
                loadBeamControls();
                loadStructuresTable();
                createObjectiveSetTabs();
                loadObjectiveTable();
                rebuildPrecomputeRobustTabs();
                loadPrecomputeConfigTable();
                stageController.setRunConfig(runConfig);
                stageController.setTemplate(template);
                stageController.loadAll();

                options.stateFile = resumedEditorState.stateFile;
                if isfield(resumedEditorState,'paths') && ...
                        isfield(resumedEditorState.paths,'rootPath')
                    options.rootPath = resumedEditorState.paths.rootPath;
                end
                if isfield(resumedEditorState,'state')
                    if isfield(resumedEditorState.state,'currentStage')
                        options.currentStage = ...
                            resumedEditorState.state.currentStage;
                    end
                    if isfield(resumedEditorState.state,'completedStages')
                        options.completedStages = ...
                            resumedEditorState.state.completedStages;
                    end
                end
            end

            function showResumeInitialResults(initialResults)
                if isstruct(initialResults) && ...
                        ~isempty(fieldnames(initialResults))
                    progressReporter.showResults(initialResults);
                end
            end

            function stopCallback(~,~)
                progressReporter.requestStop();
            end

            function lockEditorControls(lockActions)
                if nargin < 1
                    lockActions = true;
                end
                controlHandles = [ ...
                    preparePanel.controlsForLock(); ...
                    planWorkflow.gui.panels.PrecomputeEditorPanel.controls( ...
                    precomputePanel); ...
                    stageController.controls(); ...
                    settingsActionButton; ...
                    exportPresetButton];
                if lockActions
                    controlHandles = [ ...
                        controlHandles; ...
                        calculateButton; ...
                        resumeActionButton];
                end
                planWorkflow.gui.PlanEditor.setControlsEnabled( ...
                    controlHandles,'inactive');
                if options.readOnly || accepted
                    planWorkflow.gui.PlanEditor.setControlsEnabled( ...
                        stageController.analysisControls(),'on');
                end

                tableHandles = preparePanel.tableHandlesForLock();
                planWorkflow.gui.PlanEditor.setTablesEditable( ...
                    tableHandles,false);
            end

            function cancelCallback(~,~)
                if ~planWorkflow.gui.PlanEditor.confirmCloseRequest( ...
                        accepted)
                    return;
                end

                if accepted
                    if ishandle(fig)
                        delete(fig);
                    end
                else
                    accepted = false;
                    uiresume(fig);
                end
            end
        end

        function tf = confirmCloseRequest(workflowRunning,confirmFcn)
            if nargin < 2 || isempty(confirmFcn)
                confirmFcn = @questdlg;
            end

            [message,title,confirmLabel,cancelLabel] = ...
                planWorkflow.gui.PlanEditor.closeConfirmationDialog( ...
                workflowRunning);
            answer = confirmFcn(message,title,confirmLabel, ...
                cancelLabel,cancelLabel);
            tf = strcmp(char(answer),confirmLabel);
        end

        function [message,title,confirmLabel,cancelLabel] = ...
                closeConfirmationDialog(workflowRunning)
            title = 'Close plan workflow editor';
            if workflowRunning
                message = ['Close the progress window? The workflow will ' ...
                    'continue in MATLAB. Use Stop if you want to stop the ' ...
                    'running workflow.'];
                confirmLabel = 'Close window';
                cancelLabel = 'Keep open';
            else
                message = ['Close the editor and discard unapplied changes? ' ...
                    'The workflow will not be started.'];
                confirmLabel = 'Close editor';
                cancelLabel = 'Continue editing';
            end
        end

        function options = normalizeEditorOptions(options)
            defaults = struct();
            defaults.readOnly = false;
            defaults.stateFile = '';
            defaults.rootPath = '';
            defaults.currentStage = 'new';
            defaults.completedStages = {};
            defaults.nextStage = 'prepare';
            defaults.validateRunConfig = @(runConfig,template) runConfig;
            defaults.recalculateAnalysisCallback = [];
            defaults.progressReporterReadyCallback = [];
            defaults.initialResults = struct();

            fields = fieldnames(defaults);
            for i = 1:numel(fields)
                fieldName = fields{i};
                if ~isfield(options,fieldName) || isempty(options.(fieldName))
                    options.(fieldName) = defaults.(fieldName);
                end
            end

            options.readOnly = logical(options.readOnly);
            options.stateFile = char(options.stateFile);
            options.rootPath = char(options.rootPath);
            options.currentStage = char(options.currentStage);
            options.nextStage = char(options.nextStage);
            options.completedStages = cellstr(options.completedStages);
            if ~isa(options.validateRunConfig,'function_handle')
                error('planWorkflow:gui:PlanEditor:InvalidEditorOptions', ...
                    'options.validateRunConfig must be a function handle.');
            end
            validatorInputCount = nargin(options.validateRunConfig);
            if validatorInputCount >= 0 && validatorInputCount < 2
                error('planWorkflow:gui:PlanEditor:InvalidEditorOptions', ...
                    ['options.validateRunConfig must accept runConfig ' ...
                    'and template inputs.']);
            end
            if ~isempty(options.recalculateAnalysisCallback) && ...
                    ~isa(options.recalculateAnalysisCallback,'function_handle')
                error('planWorkflow:gui:PlanEditor:InvalidEditorOptions', ...
                    'options.recalculateAnalysisCallback must be a function handle.');
            end
            if ~isempty(options.progressReporterReadyCallback) && ...
                    ~isa(options.progressReporterReadyCallback,'function_handle')
                error('planWorkflow:gui:PlanEditor:InvalidEditorOptions', ...
                    ['options.progressReporterReadyCallback must be a ' ...
                     'function handle.']);
            end
            if isempty(options.initialResults)
                options.initialResults = struct();
            end
        end

        function rows = resumeInfoRows(options)
            options = planWorkflow.gui.PlanEditor.normalizeEditorOptions( ...
                options);
            completedStages = strjoin(options.completedStages,', ');
            if isempty(completedStages)
                completedStages = 'none';
            end
            rows = { ...
                'Mode',planWorkflow.gui.PlanEditor.readOnlyModeLabel( ...
                options.readOnly); ...
                'Current stage',options.currentStage; ...
                'Completed stages',completedStages; ...
                'Next stage',options.nextStage; ...
                'Output folder',options.rootPath; ...
                'State file',options.stateFile};
        end

        function label = readOnlyModeLabel(readOnly)
            if readOnly
                label = 'Read-only';
            else
                label = 'Editable';
            end
        end

        function validateResumeStateFile(stateFile)
            if isempty(stateFile) || ~isfile(stateFile)
                error('planWorkflow:gui:PlanEditor:MissingResumeState', ...
                    'Select an existing workflow_state.mat file.');
            end

            snapshot = load(stateFile,'runConfig','className');
            if ~isfield(snapshot,'runConfig') || ...
                    ~isfield(snapshot,'className') || ...
                    isempty(snapshot.className)
                error('planWorkflow:gui:PlanEditor:InvalidResumeState', ...
                    ['The selected file is not a valid planWorkflow ' ...
                     'state file.']);
            end
        end

        function editorState = resumeEditorState(stateFile)
            planWorkflow.gui.PlanEditor.validateResumeStateFile(stateFile);

            snapshot = load(stateFile,'runConfig','state','paths', ...
                'className','artifactFiles');
            editorState = struct();
            editorState.stateFile = char(stateFile);
            editorState.runConfig = snapshot.runConfig;
            editorState.state = struct();
            if isfield(snapshot,'state') && isstruct(snapshot.state)
                editorState.state = snapshot.state;
            end
            editorState.paths = struct();
            if isfield(snapshot,'paths') && isstruct(snapshot.paths)
                editorState.paths = snapshot.paths;
            end
            editorState.artifactFiles = struct();
            if isfield(snapshot,'artifactFiles') && ...
                    isstruct(snapshot.artifactFiles)
                editorState.artifactFiles = snapshot.artifactFiles;
            end
            editorState.template = ...
                planWorkflow.gui.PlanEditor.resumePlanTemplate( ...
                snapshot,stateFile);
            editorState.initialResults = ...
                planWorkflow.gui.PlanEditor.resumeInitialResults( ...
                snapshot,stateFile);
        end

    end

    methods (Static, Access = private)
        function template = resumePlanTemplate(snapshot,stateFile)
            template = [];
            dataFile = planWorkflow.gui.PlanEditor.resumeArtifactFile( ...
                snapshot,stateFile,'data','workflow_data.mat');
            if ~isempty(dataFile) && isfile(dataFile)
                dataSnapshot = load(dataFile,'data');
                if isfield(dataSnapshot,'data') && ...
                        isstruct(dataSnapshot.data) && ...
                        isfield(dataSnapshot.data,'planTemplate') && ...
                        ~isempty(dataSnapshot.data.planTemplate)
                    template = dataSnapshot.data.planTemplate;
                end
            end
            if isempty(template)
                template = planWorkflow.templates.PlanTemplate.resolve( ...
                    snapshot.runConfig);
            end
        end

        function initialResults = resumeInitialResults(snapshot,stateFile)
            initialResults = struct();
            resultsFile = planWorkflow.gui.PlanEditor.resumeArtifactFile( ...
                snapshot,stateFile,'results','workflow_results.mat');
            if isempty(resultsFile) || ~isfile(resultsFile)
                return;
            end

            resultsSnapshot = load(resultsFile,'results');
            if ~isfield(resultsSnapshot,'results') || ...
                    ~isstruct(resultsSnapshot.results)
                return;
            end
            initialResults = resultsSnapshot.results;
            if isempty(fieldnames(initialResults))
                return;
            end

            performanceFile = ...
                planWorkflow.gui.PlanEditor.resumeArtifactFile( ...
                snapshot,stateFile,'performance', ...
                'workflow_performance.mat');
            if isempty(performanceFile) || ~isfile(performanceFile)
                return;
            end
            performanceSnapshot = load(performanceFile,'performance');
            if isfield(performanceSnapshot,'performance') && ...
                    isstruct(performanceSnapshot.performance) && ...
                    ~isfield(initialResults,'performance')
                initialResults.performance = ...
                    performanceSnapshot.performance;
            end
        end

        function filePath = resumeArtifactFile(snapshot,stateFile,kind, ...
                fallbackName)
            filePath = '';
            if isfield(snapshot,'artifactFiles') && ...
                    isstruct(snapshot.artifactFiles) && ...
                    isfield(snapshot.artifactFiles,kind) && ...
                    ~isempty(snapshot.artifactFiles.(kind))
                filePath = char(snapshot.artifactFiles.(kind));
                return;
            end

            rootPath = '';
            if isfield(snapshot,'paths') && isstruct(snapshot.paths) && ...
                    isfield(snapshot.paths,'rootPath') && ...
                    ~isempty(snapshot.paths.rootPath)
                rootPath = char(snapshot.paths.rootPath);
            end
            if isempty(rootPath)
                rootPath = fileparts(stateFile);
            end
            if ~isempty(rootPath)
                filePath = fullfile(rootPath,fallbackName);
            end
        end

        function setControlsEnabled(handles,enabled)
            for i = 1:numel(handles)
                if ishandle(handles(i))
                    set(handles(i),'Enable',enabled);
                end
            end
        end

        function setTablesEditable(handles,editable)
            for i = 1:numel(handles)
                if ~ishandle(handles(i))
                    continue;
                end

                columnName = get(handles(i),'ColumnName');
                if ischar(columnName)
                    columnCount = 1;
                else
                    columnCount = numel(columnName);
                end
                set(handles(i),'ColumnEditable', ...
                    repmat(logical(editable),1,columnCount));
            end
        end

        function [runConfig,accepted] = promptWorkflowSettings(runConfig)
            accepted = false;
            originalRunConfig = runConfig;

            dialogWidth = 720;
            dialogHeight = 360;
            dialog = figure( ...
                'Name','Workflow settings', ...
                'NumberTitle','off', ...
                'MenuBar','none', ...
                'ToolBar','none', ...
                'WindowStyle','modal', ...
                'Units','pixels', ...
                'Position', ...
                planWorkflow.gui.PlanEditor.centeredDialogPosition( ...
                dialogWidth,dialogHeight), ...
                'Resize','off', ...
                'Color',[0.94 0.94 0.94], ...
                'CloseRequestFcn',@cancelSettings);

            settingsTable = ...
                planWorkflow.gui.ParameterPanelRenderer.create( ...
                dialog,[0.05 0.22 0.90 0.70], ...
                planWorkflow.gui.ParameterPanelSpecAdapter.fromSchema( ...
                planWorkflow.config.WorkflowParameterSchema.prepareConfigSpecs()), ...
                struct(),struct(),struct());
            planWorkflow.gui.ParameterPanelRenderer.load( ...
                settingsTable,runConfig,struct(),struct());
            set(dialog,'WindowScrollWheelFcn',@scrollSettings);

            uicontrol('Parent',dialog,'Style','pushbutton', ...
                'String','Apply', ...
                'Units','normalized', ...
                'Position',[0.70 0.07 0.11 0.08], ...
                'Callback',@acceptSettings);
            uicontrol('Parent',dialog,'Style','pushbutton', ...
                'String','Cancel', ...
                'Units','normalized', ...
                'Position',[0.83 0.07 0.11 0.08], ...
                'Callback',@cancelSettings);

            uiwait(dialog);

            if ishandle(dialog)
                delete(dialog);
            end
            if ~accepted
                runConfig = originalRunConfig;
            end

            function scrollSettings(~,event)
                planWorkflow.gui.ParameterPanelRenderer.scrollByWheel( ...
                    settingsTable,event.VerticalScrollCount);
            end

            function acceptSettings(~,~)
                try
                    runConfig = ...
                        planWorkflow.gui.ParameterPanelRenderer.toConfig( ...
                        runConfig,settingsTable);
                    accepted = true;
                    uiresume(dialog);
                catch ME
                    errordlg(ME.message,'Invalid workflow settings');
                end
            end

            function cancelSettings(~,~)
                accepted = false;
                if ishandle(dialog)
                    uiresume(dialog);
                end
            end
        end

        function stateFile = promptResumeStateFile(options)
            stateFile = '';

            dialogWidth = 820;
            dialogHeight = 360;
            dialog = figure( ...
                'Name','Resume workflow', ...
                'NumberTitle','off', ...
                'MenuBar','none', ...
                'ToolBar','none', ...
                'WindowStyle','modal', ...
                'Units','pixels', ...
                'Position', ...
                planWorkflow.gui.PlanEditor.centeredDialogPosition( ...
                dialogWidth,dialogHeight), ...
                'Resize','off', ...
                'Color',[0.94 0.94 0.94], ...
                'CloseRequestFcn',@cancelResume);

            resumeRows = planWorkflow.gui.PlanEditor.resumeInfoRows( ...
                options);
            uitable('Parent',dialog,'Units','normalized', ...
                'Position',[0.05 0.48 0.90 0.40], ...
                'Data',resumeRows, ...
                'ColumnName',{'Workflow state','Value'}, ...
                'ColumnEditable',[false false], ...
                'ColumnWidth',{170 580});
            uicontrol('Parent',dialog,'Style','text', ...
                'String','State file', ...
                'HorizontalAlignment','left','Units','normalized', ...
                'Position',[0.05 0.36 0.14 0.06], ...
                'FontWeight','bold', ...
                'BackgroundColor',[0.94 0.94 0.94]);
            stateFileEdit = uicontrol('Parent',dialog, ...
                'Style','edit','String',options.stateFile, ...
                'HorizontalAlignment','left','Units','normalized', ...
                'Position',[0.18 0.36 0.55 0.07]);
            uicontrol('Parent',dialog, ...
                'Style','pushbutton','String','Browse...', ...
                'Units','normalized','Position',[0.74 0.36 0.10 0.07], ...
                'Callback',@browseResumeStateFile);
            uicontrol('Parent',dialog, ...
                'Style','pushbutton','String','Resume from file', ...
                'Units','normalized','Position',[0.85 0.36 0.10 0.07], ...
                'Callback',@acceptResume);
            uicontrol('Parent',dialog,'Style','text', ...
                'String',['Select a workflow_state.mat file to load an ' ...
                'existing workflow. The editor remains read-only for ' ...
                'completed workflows; stage methods continue from the ' ...
                'first incomplete stage.'], ...
                'HorizontalAlignment','left','Units','normalized', ...
                'Position',[0.05 0.20 0.90 0.09], ...
                'FontSize',planWorkflow.gui.TextLayout.helpTextFontSize(), ...
                'ForegroundColor',[0.35 0.35 0.35], ...
                'BackgroundColor',[0.94 0.94 0.94]);
            uicontrol('Parent',dialog,'Style','pushbutton', ...
                'String','Cancel', ...
                'Units','normalized', ...
                'Position',[0.85 0.08 0.10 0.08], ...
                'Callback',@cancelResume);

            uiwait(dialog);

            if ishandle(dialog)
                delete(dialog);
            end

            function browseResumeStateFile(~,~)
                [fileName,pathName] = uigetfile( ...
                    {'workflow_state.mat','Workflow state file'; ...
                     '*.mat','MAT-files'}, ...
                    'Select workflow state file', ...
                    get(stateFileEdit,'String'));
                if isequal(fileName,0)
                    return;
                end
                set(stateFileEdit,'String',fullfile(pathName,fileName));
            end

            function acceptResume(~,~)
                try
                    candidateStateFile = strtrim( ...
                        get(stateFileEdit,'String'));
                    planWorkflow.gui.PlanEditor.validateResumeStateFile( ...
                        candidateStateFile);
                    stateFile = candidateStateFile;
                    uiresume(dialog);
                catch ME
                    errordlg(ME.message,'Invalid workflow state');
                end
            end

            function cancelResume(~,~)
                stateFile = '';
                if ishandle(dialog)
                    uiresume(dialog);
                end
            end
        end

        function position = centeredDialogPosition(width,height)
            screenSize = get(0,'ScreenSize');
            dialogLeft = screenSize(1) + ...
                max(0,(screenSize(3) - width) / 2);
            dialogBottom = screenSize(2) + ...
                max(0,(screenSize(4) - height) / 2);
            position = [dialogLeft dialogBottom width height];
        end

        function answer = promptExportPresetNames(runConfig,template, ...
                presetNames)
            answer = [];
            accepted = false;

            dialogWidth = 680;
            dialogHeight = 285;
            dialog = figure( ...
                'Name','Export template and macro', ...
                'NumberTitle','off', ...
                'MenuBar','none', ...
                'ToolBar','none', ...
                'WindowStyle','modal', ...
                'Units','pixels', ...
                'Position', ...
                planWorkflow.gui.PlanEditor.centeredDialogPosition( ...
                dialogWidth,dialogHeight), ...
                'Resize','off', ...
                'CloseRequestFcn',@cancelExport);

            uicontrol('Parent',dialog,'Style','text', ...
                'String','Template name', ...
                'HorizontalAlignment','left', ...
                'Units','normalized', ...
                'Position',[0.06 0.78 0.25 0.08], ...
                'FontWeight','bold');
            templateEdit = uicontrol('Parent',dialog,'Style','edit', ...
                'String',presetNames.templateId, ...
                'HorizontalAlignment','left', ...
                'Units','normalized', ...
                'Position',[0.32 0.78 0.60 0.09], ...
                'Callback',@updateValidation, ...
                'KeyReleaseFcn',@updateValidation);
            templateMessage = uicontrol('Parent',dialog,'Style','text', ...
                'String','', ...
                'HorizontalAlignment','left', ...
                'Units','normalized', ...
                'Position',[0.32 0.66 0.60 0.09], ...
                'FontSize', ...
                planWorkflow.gui.TextLayout.helpTextFontSize(), ...
                'ForegroundColor',[0.75 0 0]);

            uicontrol('Parent',dialog,'Style','text', ...
                'String','Macro name', ...
                'HorizontalAlignment','left', ...
                'Units','normalized', ...
                'Position',[0.06 0.49 0.25 0.08], ...
                'FontWeight','bold');
            macroEdit = uicontrol('Parent',dialog,'Style','edit', ...
                'String',presetNames.macroName, ...
                'HorizontalAlignment','left', ...
                'Units','normalized', ...
                'Position',[0.32 0.49 0.60 0.09], ...
                'Callback',@updateValidation, ...
                'KeyReleaseFcn',@updateValidation);
            macroMessage = uicontrol('Parent',dialog,'Style','text', ...
                'String','', ...
                'HorizontalAlignment','left', ...
                'Units','normalized', ...
                'Position',[0.32 0.37 0.60 0.09], ...
                'FontSize', ...
                planWorkflow.gui.TextLayout.helpTextFontSize(), ...
                'ForegroundColor',[0.75 0 0]);

            exportTemplateButton = uicontrol('Parent',dialog,'Style','pushbutton', ...
                'String','Export template', ...
                'Units','normalized', ...
                'Position',[0.33 0.11 0.18 0.11], ...
                'Callback',@acceptTemplateExport);
            exportMacroButton = uicontrol('Parent',dialog,'Style','pushbutton', ...
                'String','Export macro', ...
                'Units','normalized', ...
                'Position',[0.52 0.11 0.17 0.11], ...
                'Callback',@acceptMacroExport);
            exportBothButton = uicontrol('Parent',dialog,'Style','pushbutton', ...
                'String','Export both', ...
                'Units','normalized', ...
                'Position',[0.70 0.11 0.14 0.11], ...
                'Callback',@acceptBothExport);
            uicontrol('Parent',dialog,'Style','pushbutton', ...
                'String','Cancel', ...
                'Units','normalized', ...
                'Position',[0.85 0.11 0.10 0.11], ...
                'Callback',@cancelExport);

            updateValidation();
            uiwait(dialog);

            if ishandle(dialog)
                delete(dialog);
            end
            if ~accepted
                answer = [];
            end

            function status = updateValidation(~,~)
                status = ...
                    planWorkflow.gui.PlanPresetWriter.exportNameStatus( ...
                    template,runConfig,get(templateEdit,'String'), ...
                    get(macroEdit,'String'));
                set(templateMessage,'String',status.templateMessage);
                set(templateMessage,'ForegroundColor', ...
                    planWorkflow.gui.EditorChrome.exportStatusColor( ...
                    status.templateSeverity));
                set(macroMessage,'String',status.macroMessage);
                set(macroMessage,'ForegroundColor', ...
                    planWorkflow.gui.EditorChrome.exportStatusColor( ...
                    status.macroSeverity));
                set(exportTemplateButton,'Enable', ...
                    planWorkflow.gui.EditorChrome.enableText( ...
                    status.canExportTemplate));
                set(exportMacroButton,'Enable', ...
                    planWorkflow.gui.EditorChrome.enableText( ...
                    status.canExportMacro));
                set(exportBothButton,'Enable', ...
                    planWorkflow.gui.EditorChrome.enableText( ...
                    status.canExportBoth));
            end

            function acceptTemplateExport(~,~)
                status = updateValidation();
                if ~status.canExportTemplate
                    return;
                end
                answer = struct('action','template', ...
                    'templateId',status.templateId, ...
                    'macroName',status.macroName);
                accepted = true;
                uiresume(dialog);
            end

            function acceptMacroExport(~,~)
                status = updateValidation();
                if ~status.canExportMacro
                    return;
                end
                answer = struct('action','macro', ...
                    'templateId',status.templateId, ...
                    'macroName',status.macroName);
                accepted = true;
                uiresume(dialog);
            end

            function acceptBothExport(~,~)
                status = updateValidation();
                if ~status.canExportBoth
                    return;
                end
                answer = struct('action','both', ...
                    'templateId',status.templateId, ...
                    'macroName',status.macroName);
                accepted = true;
                uiresume(dialog);
            end

            function cancelExport(~,~)
                accepted = false;
                if ishandle(dialog)
                    uiresume(dialog);
                end
            end
        end

    end
end
