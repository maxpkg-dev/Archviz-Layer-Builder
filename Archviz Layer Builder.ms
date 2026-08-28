/* Archviz Layer Builder | 1.1.0 | Lukianenko Vasyl | https://3dground.net */

try
(
    if (ALB_Floater != undefined) do closeRolloutFloater ALB_Floater
)
catch
(
    format "Archviz Layer Builder cleanup: %\n" (getCurrentException())
)

global ALB_Floater
global ALB_MainRollout
global ALB_TransferRollout
global ALB_AboutRollout
global ALB_State

struct ALB_StateType
(
    versionText = "1.1.0",
    layerNames = #(),
    parentIndexes = #(),
    displayLines = #(),
    displayToNode = #(),
    settingsFilePath = (getDir #userScripts) + "\\ArchvizLayerBuilder.ini",
    windowPosition = [160,120],

    fn restoreDefaultTemplate =
    (
        layerNames = #(
            "01_ARCH", "02_FURNITURE", "03_DECOR", "04_LIGHTS", "05_CAMERAS",
            "06_HELPERS", "EXTRA", "07_VEGETATION", "08_CONTEXT", "09_REFERENCE"
        )
        parentIndexes = #(0,0,0,0,0,0,0,7,7,7)
        return true
    ),

    fn writeHierarchy destinationFilePath includeMetadata:false =
    (
        if (destinationFilePath == undefined or destinationFilePath == "") do return false
        if (layerNames.count != parentIndexes.count) do throw "Template names and parent indexes are inconsistent"

        if (includeMetadata) do
        (
            setINISetting destinationFilePath "Info" "Script" "Archviz Layer Builder"
            setINISetting destinationFilePath "Info" "Version" versionText
        )
        setINISetting destinationFilePath "Hierarchy" "Count" (layerNames.count as string)

        for layerIndex in 1 to layerNames.count do
        (
            local iniSectionName = "Layer_" + (layerIndex as string)
            setINISetting destinationFilePath iniSectionName "Name" layerNames[layerIndex]
            setINISetting destinationFilePath iniSectionName "Parent" (parentIndexes[layerIndex] as string)
        )
        return doesFileExist destinationFilePath
    ),

    fn readHierarchy sourceFilePath =
    (
        if (sourceFilePath == undefined or not (doesFileExist sourceFilePath)) do return undefined

        local importedLayerCount = 0
        try
        (
            importedLayerCount = (getINISetting sourceFilePath "Hierarchy" "Count") as integer
        )
        catch
        (
            return undefined
        )
        if (importedLayerCount < 1) do return undefined

        local importedLayerNames = #()
        local importedParentIndexes = #()
        for layerIndex in 1 to importedLayerCount do
        (
            local iniSectionName = "Layer_" + (layerIndex as string)
            local importedLayerName = getINISetting sourceFilePath iniSectionName "Name"
            local importedParentIndex = -1
            try
            (
                importedParentIndex = (getINISetting sourceFilePath iniSectionName "Parent") as integer
            )
            catch
            (
                return undefined
            )

            if (importedLayerName == "") do return undefined
            if ((findString importedLayerName "|") != undefined) do return undefined
            if (importedParentIndex < 0 or importedParentIndex >= layerIndex) do return undefined
            for existingLayerName in importedLayerNames do
            (
                if ((stricmp existingLayerName importedLayerName) == 0) do return undefined
            )

            append importedLayerNames importedLayerName
            append importedParentIndexes importedParentIndex
        )
        return #(importedLayerNames, importedParentIndexes)
    ),

    fn saveTemplate =
    (
        return writeHierarchy settingsFilePath
    ),

    fn loadTemplate =
    (
        local storedHierarchy = readHierarchy settingsFilePath
        if (storedHierarchy == undefined) then
        (
            restoreDefaultTemplate()
            return saveTemplate()
        )
        else
        (
            layerNames = storedHierarchy[1]
            parentIndexes = storedHierarchy[2]
            return true
        )
    ),

    fn loadWindowPosition =
    (
        local storedX = 160
        local storedY = 120
        local storedXText = getINISetting settingsFilePath "Window" "X"
        local storedYText = getINISetting settingsFilePath "Window" "Y"
        try (if (storedXText != "") do storedX = storedXText as integer) catch()
        try (if (storedYText != "") do storedY = storedYText as integer) catch()
        windowPosition = [amax 0 storedX, amax 0 storedY]
        return windowPosition
    ),

    fn saveWindowPosition =
    (
        if (ALB_Floater == undefined) do return false
        local currentWindowPosition = ALB_Floater.pos
        setINISetting settingsFilePath "Window" "X" (currentWindowPosition.x as string)
        setINISetting settingsFilePath "Window" "Y" (currentWindowPosition.y as string)
        return true
    ),

    fn saveListSelection displayIndex =
    (
        if (displayIndex > 0 and displayIndex <= displayToNode.count) then
        (
            local selectedNodeIndex = displayToNode[displayIndex]
            setINISetting settingsFilePath "UI" "SelectedLayer" layerNames[selectedNodeIndex]
            setINISetting settingsFilePath "UI" "SelectedIndex" (displayIndex as string)
            return true
        )
        else
        (
            setINISetting settingsFilePath "UI" "SelectedLayer" ""
            setINISetting settingsFilePath "UI" "SelectedIndex" "0"
            return false
        )
    ),

    fn getChildIndexes parentIndex =
    (
        local childIndexes = #()
        for layerIndex in 1 to parentIndexes.count do
        (
            if (parentIndexes[layerIndex] == parentIndex) do append childIndexes layerIndex
        )
        return childIndexes
    ),

    fn appendDisplayBranch nodeIndex branchPrefix isRootNode isLastNode =
    (
        local characterClass = dotNetClass "System.Char"
        local branchCharacter = characterClass.ConvertFromUtf32 9500
        local cornerCharacter = characterClass.ConvertFromUtf32 9492
        local dashCharacter = characterClass.ConvertFromUtf32 9472
        local connectorText = ""
        if (not isRootNode) do
        (
            connectorText = (if isLastNode then cornerCharacter else branchCharacter) + dashCharacter + dashCharacter + " "
        )

        append displayLines (branchPrefix + connectorText + layerNames[nodeIndex])
        append displayToNode nodeIndex

        local childIndexes = getChildIndexes nodeIndex
        local childPrefix = branchPrefix
        if (not isRootNode) do childPrefix += (if isLastNode then "    " else "|   ")
        for childNumber in 1 to childIndexes.count do
        (
            appendDisplayBranch childIndexes[childNumber] childPrefix false (childNumber == childIndexes.count)
        )
        return true
    ),

    fn rebuildDisplay selectedNodeIndex:0 fallbackDisplayIndex:0 =
    (
        displayLines = #()
        displayToNode = #()
        local rootIndexes = getChildIndexes 0
        for rootNumber in 1 to rootIndexes.count do
        (
            appendDisplayBranch rootIndexes[rootNumber] "" true (rootNumber == rootIndexes.count)
        )
        if (ALB_MainRollout == undefined) do return false

        ALB_MainRollout.layerList.items = displayLines
        local selectedDisplayIndex = 0
        if (selectedNodeIndex > 0) do selectedDisplayIndex = findItem displayToNode selectedNodeIndex
        if (selectedDisplayIndex == 0 and fallbackDisplayIndex > 0 and displayLines.count > 0) do
        (
            selectedDisplayIndex = amin fallbackDisplayIndex displayLines.count
        )
        if (selectedDisplayIndex == 0) do
        (
            local storedLayerName = getINISetting settingsFilePath "UI" "SelectedLayer"
            if (storedLayerName != "") do
            (
                for layerIndex in 1 to layerNames.count do
                (
                    if ((stricmp layerNames[layerIndex] storedLayerName) == 0) do
                    (
                        selectedDisplayIndex = findItem displayToNode layerIndex
                    )
                )
            )
        )
        if (selectedDisplayIndex == 0 and displayLines.count > 0) do
        (
            local storedDisplayIndex = 0
            try (storedDisplayIndex = (getINISetting settingsFilePath "UI" "SelectedIndex") as integer) catch()
            selectedDisplayIndex = if storedDisplayIndex > 0 then amin storedDisplayIndex displayLines.count else 1
        )
        ALB_MainRollout.layerList.selection = selectedDisplayIndex
        saveListSelection selectedDisplayIndex
        return true
    ),

    fn layerNameExists proposedLayerName =
    (
        for existingLayerName in layerNames do
        (
            if ((stricmp existingLayerName proposedLayerName) == 0) do return true
        )
        return false
    ),

    fn validateLayerName proposedLayerName =
    (
        if (proposedLayerName == undefined or proposedLayerName == "") do return "Enter a layer name."
        if ((findString proposedLayerName "|") != undefined) do return "Layer names cannot contain the | character."
        if (layerNameExists proposedLayerName) do return "That layer name is already in the template."
        return ""
    ),

    fn addTemplateLayer proposedLayerName parentIndex =
    (
        if ((validateLayerName proposedLayerName) != "") do return 0
        if (parentIndex < 0 or parentIndex > layerNames.count) do parentIndex = 0
        append layerNames proposedLayerName
        append parentIndexes parentIndex
        if (not saveTemplate()) do throw "Could not save the updated template"
        return layerNames.count
    ),

    fn nodeIsInBranch nodeIndex rootIndex =
    (
        local currentNodeIndex = nodeIndex
        while (currentNodeIndex > 0) do
        (
            if (currentNodeIndex == rootIndex) do return true
            currentNodeIndex = parentIndexes[currentNodeIndex]
        )
        return false
    ),

    fn removeTemplateBranch rootIndex =
    (
        if (rootIndex < 1 or rootIndex > layerNames.count) do return false
        local oldLayerCount = layerNames.count
        local oldToNewIndexes = for layerIndex in 1 to oldLayerCount collect 0
        local remainingNames = #()
        local remainingParents = #()

        for layerIndex in 1 to oldLayerCount do
        (
            if (not (nodeIsInBranch layerIndex rootIndex)) do
            (
                append remainingNames layerNames[layerIndex]
                oldToNewIndexes[layerIndex] = remainingNames.count
            )
        )
        for layerIndex in 1 to oldLayerCount do
        (
            if (oldToNewIndexes[layerIndex] > 0) do
            (
                local oldParentIndex = parentIndexes[layerIndex]
                append remainingParents (if oldParentIndex == 0 then 0 else oldToNewIndexes[oldParentIndex])
            )
        )
        layerNames = remainingNames
        parentIndexes = remainingParents
        return saveTemplate()
    ),

    fn createSceneLayers =
    (
        if (layerNames.count != parentIndexes.count) do throw "Template hierarchy is inconsistent"
        local createdLayerCount = 0
        local existingLayerCount = 0
        undo "Create Archviz Layers" on
        (
            for layerIndex in 1 to layerNames.count do
            (
                local sceneLayer = LayerManager.getLayerFromName layerNames[layerIndex]
                if (sceneLayer == undefined) then
                (
                    sceneLayer = LayerManager.newLayerFromName layerNames[layerIndex]
                    createdLayerCount += 1
                )
                else existingLayerCount += 1

                if (parentIndexes[layerIndex] > 0) do
                (
                    local parentLayer = LayerManager.getLayerFromName layerNames[parentIndexes[layerIndex]]
                    if (parentLayer == undefined) do throw "A parent layer could not be created"
                    sceneLayer.setParent parentLayer
                )
            )
        )
        return #(createdLayerCount, existingLayerCount)
    )
)

ALB_State = ALB_StateType()

rollout ALB_MainRollout "Main" width:300 height:435
(
    group "Layer Template" (
		listBox layerList "" width:268 height:20
		editText layerNameInput "Name:" height:20
		button addButton "Add" width:84 height:26 across: 3
		button sublayerButton "Sublayer" width:84 height:26
		button removeButton "Remove" width:84 height:26
	)
    button createButton "Create Layers"  width:268 height:30 offset: [0, 10]
    label statusLabel "Ready" width:268 height:16 align: #left

    on ALB_MainRollout open do
    (
        ALB_State.rebuildDisplay()
        statusLabel.text = (ALB_State.layerNames.count as string) + " template layers"
    )
    on layerList selected displayIndex do
    (
        ALB_State.saveListSelection displayIndex
        if (displayIndex > 0 and displayIndex <= ALB_State.displayToNode.count) do
        (
            statusLabel.text = ALB_State.layerNames[ALB_State.displayToNode[displayIndex]]
        )
    )
    on addButton pressed do
    (
        local validationMessage = ALB_State.validateLayerName layerNameInput.text
        if (validationMessage != "") then messageBox validationMessage title:"Archviz Layer Builder"
        else
        (
            local newNodeIndex = ALB_State.addTemplateLayer layerNameInput.text 0
            ALB_State.rebuildDisplay selectedNodeIndex:newNodeIndex
            layerNameInput.text = ""
            statusLabel.text = "Root layer added"
        )
    )
    on sublayerButton pressed do
    (
        if (layerList.selection < 1) then messageBox "Select a parent layer first." title:"Archviz Layer Builder"
        else
        (
            local validationMessage = ALB_State.validateLayerName layerNameInput.text
            if (validationMessage != "") then messageBox validationMessage title:"Archviz Layer Builder"
            else
            (
                local parentIndex = ALB_State.displayToNode[layerList.selection]
                local newNodeIndex = ALB_State.addTemplateLayer layerNameInput.text parentIndex
                ALB_State.rebuildDisplay selectedNodeIndex:newNodeIndex
                layerNameInput.text = ""
                statusLabel.text = "Sublayer added"
            )
        )
    )
    on removeButton pressed do
    (
        if (layerList.selection < 1) then messageBox "Select a layer to remove." title:"Archviz Layer Builder"
        else
        (
            local previousDisplayIndex = layerList.selection
            local selectedNodeIndex = ALB_State.displayToNode[previousDisplayIndex]
            local confirmationText = "Remove '" + ALB_State.layerNames[selectedNodeIndex] + "' and its sublayers from the template?"
            if (queryBox confirmationText title:"Archviz Layer Builder") do
            (
                ALB_State.removeTemplateBranch selectedNodeIndex
                ALB_State.rebuildDisplay fallbackDisplayIndex:previousDisplayIndex
                statusLabel.text = "Template item removed"
            )
        )
    )
    on createButton pressed do
    (
        try
        (
            local creationCounts = ALB_State.createSceneLayers()
            statusLabel.text = (creationCounts[1] as string) + " created, " + (creationCounts[2] as string) + " existing"
            completeRedraw()
        )
        catch
        (
            messageBox ("Could not create the layers.\n\n" + getCurrentException()) title:"Archviz Layer Builder"
            statusLabel.text = "Layer creation failed"
        )
    )
    on ALB_MainRollout close do
    (
        ALB_State.saveListSelection layerList.selection
        ALB_State.saveWindowPosition()
        ALB_State.saveTemplate()
    )
)

rollout ALB_TransferRollout "Import / Export" width:300 height:72
(
    group "Layer Hierarchy" (
		button importButton "Import..."  width:84 across: 3		
		button exportButton "Export..."  width:84 
		button defaultsButton "Defaults"  width:84 
	)

    on defaultsButton pressed do
    (
        if (queryBox "Restore the default layer template?" title:"Archviz Layer Builder") do
        (
            ALB_State.restoreDefaultTemplate()
            ALB_State.saveTemplate()
            ALB_State.rebuildDisplay fallbackDisplayIndex:1
            ALB_MainRollout.statusLabel.text = "Default template restored"
        )
    )
    on exportButton pressed do
    (
        local destinationFilePath = getSaveFileName caption:"Export Layer Hierarchy" filename:"Archviz_Layer_Hierarchy.ini" types:"INI Files (*.ini)|*.ini|"
        if (destinationFilePath != undefined) do
        (
            local mayWriteFile = true
            if (doesFileExist destinationFilePath) do mayWriteFile = queryBox "Replace the existing hierarchy file?" title:"Archviz Layer Builder"
            if (mayWriteFile) do
            (
                try
                (
                    if (not (ALB_State.writeHierarchy destinationFilePath includeMetadata:true)) do throw "The hierarchy file was not created"
                )
                catch
                (
                    messageBox ("Could not export the hierarchy.\n\n" + getCurrentException()) title:"Archviz Layer Builder"
                )
            )
        )
    )
    on importButton pressed do
    (
        local sourceFilePath = getOpenFileName caption:"Import Layer Hierarchy" types:"INI Files (*.ini)|*.ini|"
        if (sourceFilePath != undefined) do
        (
            local importedHierarchy = ALB_State.readHierarchy sourceFilePath
            if (importedHierarchy == undefined) then messageBox "The selected file does not contain a valid layer hierarchy." title:"Archviz Layer Builder"
            else if (queryBox "Replace the current layer template with the imported hierarchy?" title:"Archviz Layer Builder") do
            (
                ALB_State.layerNames = importedHierarchy[1]
                ALB_State.parentIndexes = importedHierarchy[2]
                ALB_State.saveTemplate()
                ALB_State.rebuildDisplay()
                ALB_MainRollout.statusLabel.text = (ALB_State.layerNames.count as string) + " imported layers"
            )
        )
    )
)

rollout ALB_AboutRollout "About" width:300 height:120
(
    label scriptNameLabel "Archviz Layer Builder" align:#center
    label versionLabel "1.1.0" align:#center
    label authorLabel "Lukianenko Vasyl" align:#center
    hyperlink websiteLink "3dground.net" address:"https://3dground.net" align:#center color: orange hoverColor: orange visitedColor: orange
)

if (not (ALB_State.loadTemplate())) do throw "Archviz Layer Builder could not initialize its settings"
ALB_State.loadWindowPosition()
ALB_Floater = newRolloutFloater "Archviz Layer Builder" 316 620 pos:ALB_State.windowPosition
addRollout ALB_MainRollout ALB_Floater rolledUp:false
addRollout ALB_TransferRollout ALB_Floater rolledUp:true
addRollout ALB_AboutRollout ALB_Floater rolledUp:true

