-- ======= Copyright (c) 2003-2011, Unknown Worlds Entertainment, Inc. All rights reserved. =======
--
-- lua\Client.lua
--
--    Created by:   Charlie Cleveland (charlie@unknownworlds.com)
--
-- ========= For more information, visit us at http://www.unknownworlds.com =====================

-- Set the name of the VM for debugging
decoda_name = "Client"

Script.Load("lua/PreLoadMod.lua")

Script.Load("lua/ClientResources.lua")
Script.Load("lua/Shared.lua")
Script.Load("lua/GUIAssets.lua")
Script.Load("lua/Effect.lua")
Script.Load("lua/AmbientSound.lua")
Script.Load("lua/GhostModelUI.lua")
Script.Load("lua/Render.lua")
Script.Load("lua/MapEntityLoader.lua")
Script.Load("lua/Chat.lua")
Script.Load("lua/DeathMessage_Client.lua")
Script.Load("lua/DSPEffects.lua")
Script.Load("lua/Scoreboard.lua")
Script.Load("lua/ScoreDisplay.lua")
Script.Load("lua/AlienBuy_Client.lua")
Script.Load("lua/MarineBuy_Client.lua")
Script.Load("lua/Tracer_Client.lua")
Script.Load("lua/GUIManager.lua")
Script.Load("lua/GUIDebugText.lua")
Script.Load("lua/TrailCinematic.lua")
Script.Load("lua/MenuManager.lua")
Script.Load("lua/BindingsDialog.lua")
Script.Load("lua/MainMenu.lua")
Script.Load("lua/ConsoleBindings.lua")
Script.Load("lua/ServerAdmin.lua")
Script.Load("lua/ClientUI.lua")
Script.Load("lua/Voting.lua")
Script.Load("lua/Badges_Client.lua")

Script.Load("lua/Hud/HelpScreen/HelpScreen.lua")

Script.Load("lua/ConsoleCommands_Client.lua")
Script.Load("lua/NetworkMessages_Client.lua")

Script.Load("lua/HiveVision.lua")
Script.Load("lua/Matchmaking.lua")

Script.Load("lua/JitConfig.lua")

Script.Load("lua/Analytics.lua")

-- Precache the common surface shaders.
PrecacheAsset("shaders/Model.surface_shader")
PrecacheAsset("shaders/Emissive.surface_shader")
PrecacheAsset("shaders/Model_emissive.surface_shader")
PrecacheAsset("shaders/Model_alpha.surface_shader")
PrecacheAsset("shaders/ViewModel.surface_shader")
PrecacheAsset("shaders/ViewModel_emissive.surface_shader")
PrecacheAsset("shaders/Decal.surface_shader")
PrecacheAsset("shaders/Decal_emissive.surface_shader")

Client.locationList = { }
Client.propList = { }
Client.lightList = { }
Client.glowingProps = { }
Client.skyBoxList = { }
Client.ambientSoundList = { }
Client.tracersList = { }
Client.fogAreaModifierList = { }
Client.rules = { }
Client.cinematics = { }
Client.trailCinematics = { }
-- cinematics which are queued for destruction next frame
Client.destroyTrailCinematics = { }
Client.worldMessages = { }
Client.timeLimitedDecals = { }

Client.timeOfLastPowerPoints = nil

local startLoadingTime = Shared.GetSystemTimeReal()
local currentLoadingTime = Shared.GetSystemTimeReal()

Client.serverHidden = false
function Client.GetServerIsHidden()
    return Client.serverHidden
end

Client.localClientIndex = nil
function Client.GetLocalClientIndex()
    return Client.localClientIndex
end

local gOutlinePlayers = true
function Client.GetOutlinePlayers()
    return gOutlinePlayers
end

function Client.ToggleOutlinePlayers()
     gOutlinePlayers = not gOutlinePlayers
end

local toggleOutlineLastFrame = false
function Client.OnProcessGameInput(input)

    if Client.GetLocalClientTeamNumber() == kSpectatorIndex then

        local toggleOutlinePressed = bit.band(input.commands, Move.ToggleFlashlight) ~= 0
        if not toggleOutlineLastFrame and toggleOutlinePressed then
            Client.ToggleOutlinePlayers()          
        end
        toggleOutlineLastFrame = toggleOutlinePressed
    
    end
    
end

--
--This function will return the team number the local client is on
--regardless of any spectating the local client may be doing.
--
Client.localClientTeamNumber = kTeamInvalid
function Client.GetLocalClientTeamNumber()
    return Client.localClientTeamNumber
end

local function InitializeRenderCamera()
    gRenderCamera = Client.CreateRenderCamera()
    gRenderCamera:SetRenderSetup("renderer/Deferred.render_setup")
end

function GetRenderCameraCoords()

    if gRenderCamera then
        return gRenderCamera:GetCoords()
    end

    return Coords.GetIdentity()    
    
end

-- Client tech tree
local gTechTree = TechTree()
gTechTree:Initialize() 

function GetTechTree()
    return gTechTree
end

function ClearTechTree()
    gTechTree:Initialize()    
end

function SetLocalPlayerIsOverhead(isOverhead)

    Client.SetGroupIsVisible(kCommanderInvisibleGroupName, not isOverhead)
    Client.SetGroupIsVisible(kCommanderInvisibleVentsGroupName, not isOverhead)
    Client.SetGroupIsVisible(kCommanderInvisibleNonCollisionGroupName, not isOverhead)
    if gSeasonalCommanderInvisibleGroupName then
        Client.SetGroupIsVisible(gSeasonalCommanderInvisibleGroupName, not isOverhead)
    end
    for c = 1, #Client.cinematics do
    
        local cinematic = Client.cinematics[c]
        if cinematic.commanderInvisible then
            cinematic:SetIsVisible(not isOverhead)
        end
        
    end
    
end

--
--Destroys all of the objects created during the level load by the
--OnMapLoadEntity function.
--
function DestroyLevelObjects()

    -- Remove all of the props.
    if Client.propList ~= nil then
        for index, models in ipairs(Client.propList) do
            Client.DestroyRenderModel(models[1])
            Shared.DestroyCollisionObject(models[2])
        end
        Client.propList = { }
    end
    
    -- Remove the lights.
    if Client.lightList ~= nil then
        for index, light in ipairs(Client.lightList) do
            Client.DestroyRenderLight(light)
        end
        Client.lightList = { }
    end
    
    -- Remove the billboards.
    if Client.billboardList ~= nil then  
        for index, billboard in ipairs(Client.billboardList) do
            Client.DestroyRenderBillboard(billboard)
        end
        Client.billboardList = { }
    end
    
    -- Remove the decals.
    if Client.decalList ~= nil then  
        for index, decal in ipairs(Client.decalList) do
            Client.DestroyRenderDecal(decal)
        end
        Client.decalList = { }
    end

    -- Remove the reflection probes.
    if Client.reflectionProbeList ~= nil then
    
        for index, reflectionProbe in ipairs(Client.reflectionProbeList) do
            Client.DestroyRenderReflectionProbe(reflectionProbe)
        end
        Client.reflectionProbeList = { }
        
    end
    
    -- Remove the cinematics.
    if Client.cinematics ~= nil then
    
        for index, cinematic in ipairs(Client.cinematics) do
            Client.DestroyCinematic(cinematic)
        end
        Client.cinematics = { }
        
    end
    
    -- Remove the skyboxes.
    Client.skyBoxList = { }
    
    Client.tracersList = { }
    for a = 1, #Client.ambientSoundList do
        Client.ambientSoundList[a]:OnDestroy()
    end
    Client.ambientSoundList = { }
    Client.rules = { }
    
end

function ExitPressed()

    if not Shared.GetIsRunningPrediction() then
    
        -- Close buy menu if open, otherwise show in-game menu
        if MainMenu_GetIsOpened() then
            MainMenu_ReturnToGame()
        else
        
            if not Client.GetLocalPlayer():CloseMenu() then
                MainMenu_Open()
            end
            
        end
        
    end
    
end

--
--Called as the map is being loaded to create the entities. If no group, groupName will be "".
--
function OnMapLoadEntity(className, groupName, values)

    local season = GetSeason()
    -- set custom round start music if defined
    if className == "ns2_gamerules" then
    
        if values.roundStartMusic ~= nil and string.len(values.roundStartMusic) > 0 then
            gRoundStartMusic = values.roundStartMusic
        end
    
    -- Create render objects.
    elseif className == "color_grading" then
    
        -- Disabled temporarily because it's crashing
        Print("color_grading map entity ignored (temporarily disabled)")
        --[[
        local renderColorGrading = Client.CreateRenderColorGrading()
        
        renderColorGrading:SetOrigin( values.origin )
        renderColorGrading:SetBalance( values.balance )
        renderColorGrading:SetBrightness( values.brightness )
        renderColorGrading:SetContrast( values.contrast )
        renderColorGrading:SetRadius( values.distance )
        renderColorGrading:SetGroup(groupName)
        --]]
        
    elseif className == "fog_controls" then
    
        Client.globalFogControls = values
        Client.SetZoneFogDepthScale(RenderScene.Zone_ViewModel, 1.0 / values.view_zone_scale)
        Client.SetZoneFogColor(RenderScene.Zone_ViewModel, values.view_zone_color)
        
        Client.SetZoneFogDepthScale(RenderScene.Zone_SkyBox, 1.0 / values.skybox_zone_scale)
        Client.SetZoneFogColor(RenderScene.Zone_SkyBox, values.skybox_zone_color)
        
        Client.SetZoneFogDepthScale(RenderScene.Zone_Default, 1.0 / values.default_zone_scale)
        Client.SetZoneFogColor(RenderScene.Zone_Default, values.default_zone_color)
        
    elseif className == "fog_area_modifier" then
    
        assert(values.start_blend_radius > values.end_blend_radius, "Error: fog_area_modifier must have a larger start blend radius than end blend radius")
        table.insert(Client.fogAreaModifierList, values)
        
    elseif className == "minimap_extents" then
    
        if not Client.rules.numberMiniMapExtents then
            Client.rules.numberMiniMapExtents = 0
        end
        
        if values.useLegacyOverview ~= false then
            -- This map's overview was generated with the pre-build-320 overview.exe, meaning we have to use
            -- old code for blips to continue to map correctly to the overview image.  If nil, it simply
            -- indicates it's an old version of the level that has not been saved with a >=320 editor setup.
            -- The author can also set this value to true if they wish to keep the old overview.
            -- When opening an old map, the value "useLegacyOverview" will default to false if it is not found.
            Client.legacyMinimap = true
        end
        
        Client.rules.numberMiniMapExtents = Client.rules.numberMiniMapExtents + 1
        Client.minimapExtentScale = values.scale
        Client.minimapExtentOrigin = values.origin
        
    -- Only create the client side cinematic if it isn't waiting for a signal to start.
    -- Otherwise the server will create the cinematic.
    elseif className == "skybox" or (className == "cinematic" and (values.startsOnMessage == "" or values.startsOnMessage == nil)) then
    
        if IsGroupActiveInSeason(groupName, season) then
        
            local coords = values.angles:GetCoords(values.origin)
            
            local zone = RenderScene.Zone_Default
            
            if className == "skybox" then
                zone = RenderScene.Zone_SkyBox
            end
            
            local cinematic = Client.CreateCinematic(zone)
            
            cinematic:SetCinematic(values.cinematicName)
            cinematic:SetCoords(coords)
            
            local repeatStyle = Cinematic.Repeat_None
            
            -- 0 is Repeat_None but Repeat_None is not supported here because it would
            -- cause the cinematic to kill itself but the cinematic would not be
            -- removed from the Client.cinematics list which would cause errors.
            if values.repeatStyle == 0 then
                repeatStyle = Cinematic.Repeat_Loop
            elseif values.repeatStyle == 1 then
                repeatStyle = Cinematic.Repeat_Loop
            elseif values.repeatStyle == 2 then
                repeatStyle = Cinematic.Repeat_Endless
            end
            
            if className == "skybox" then
            
                table.insert(Client.skyBoxList, cinematic)
                
                -- Becuase we're going to hold onto the skybox, make sure it
                -- uses the endless repeat style so that it doesn't delete itself
                repeatStyle = Cinematic.Repeat_Endless
                
            end
            
            cinematic:SetRepeatStyle(repeatStyle)
            
            cinematic.commanderInvisible = values.commanderInvisible
            cinematic.className = className
            cinematic.coords = coords
            
            table.insert(Client.cinematics, cinematic)
            
        end
    
    elseif className == "ambient_sound" then
    
        if IsGroupActiveInSeason(groupName, season) then
            local entity = AmbientSound()
            LoadEntityFromValues(entity, values)
            Client.PrecacheLocalSound(entity.eventName)
            table.insert(Client.ambientSoundList, entity)
            table.insert(Client.cachedAmbientSoundList, {className = className, groupName = groupName, values = values})
        end
        
    elseif className == Reverb.kMapName then
    
        local entity = Reverb()
        LoadEntityFromValues(entity, values)
        entity:OnLoad()
        
    elseif className == "pathing_settings" then
        ParsePathingSettings(values)
    
    elseif className == "location" then
    
        local coords = values.angles:GetCoords(values.origin)
        coords.xAxis = coords.xAxis * values.scale.x * 0.2395
        coords.yAxis = coords.yAxis * values.scale.y * 0.2395
        coords.zAxis = coords.zAxis * values.scale.z * 0.2395
        coords = coords:GetInverse()
        
        if not Client.locationList[values.name] then
            Client.locationList[values.name] = {}
        end
        
        table.insert(Client.locationList[values.name], coords)
    
    else
    
        -- $AS FIXME: We are special caasing techPoints for pathing right now :/
        if (className == "tech_point") then
            local coords = values.angles:GetCoords(values.origin)
            if not Pathing.GetLevelHasPathingMesh() then
                Pathing.CreatePathingObject(TechPoint.kModelName, coords, true)
                Pathing.AddFillPoint(values.origin)
            end
            
            -- Store a list of techpoint locations
            ConcedeSequence.AddTPLocation(coords.origin)
        end
        
        -- Allow the MapEntityLoader to load it if all else fails.
        LoadMapEntity(className, groupName, values)
        
    end
    
end

-- TODO: Change this to setting the alpha instead of visibility when supported
function SetCommanderPropState(isComm)

    for index, propPair in ipairs(Client.propList) do
        local prop = propPair[1]
        if prop.commAlpha < 1 then
            prop:SetIsVisible(not isComm)
        end
    end

end

local function UpdateAmbientSounds(deltaTime)
    
    PROFILE("Client:UpdateAmbientSounds")

    local ambientSoundList = Client.ambientSoundList
    for index = 1,#ambientSoundList do
        local ambientSound = ambientSoundList[index]
        ambientSound:OnUpdate(deltaTime)
    end
    
end

local function UpdateTrailCinematics(deltaTime)

    PROFILE("Client:UpdateTrailCinematics")

    for i = 1, #Client.destroyTrailCinematics do
        local destroyCinematic = Client.destroyTrailCinematics[i]
        Client.DestroyTrailCinematic(destroyCinematic)
    end

    for i = 1, #Client.trailCinematics do
        local trailCinematic = Client.trailCinematics[i]
        trailCinematic:Update(deltaTime)
    end

end

local function UpdateWorldMessages()

    PROFILE("Client:UpdateWorldMessages")

    local removeEntries = { }
    
    for _, message in ipairs(Client.worldMessages) do
    
        if (Client.GetTime() - message.creationTime) >= message.lifeTime then
            table.insert(removeEntries, message)
        else
            message.animationFraction = (Client.GetTime() - message.creationTime) / message.lifeTime
        end
        
    end
    
    for _, removeMessage in ipairs(removeEntries) do
        table.removevalue(Client.worldMessages, removeMessage)
    end
    
end

local function UpdateDecals(deltaTime)
    PROFILE("Client:UpdateDecals")

    local reUseDecals = { }

    for i = 1, #Client.timeLimitedDecals do
    
        local decalEntry = Client.timeLimitedDecals[i]
        if decalEntry[2] > Shared.GetTime() then
            table.insert(reUseDecals, decalEntry)
        else
            Client.DestroyRenderDecal(decalEntry[1])
        end
    
    end
    
    Client.timeLimitedDecals = reUseDecals


end

Client._playingDangerMusic = false
Client.IsPlayingDangerMusic = function()
    return Client._playingDangerMusic
end


local optionsSent = false

local oldGameState = 0
local function CheckGameState()

  local entityList = Shared.GetEntitiesWithClassname("GameInfo")

  if entityList:GetSize() > 0 then

    local state = entityList:GetEntityAtIndex(0):GetState()
    
    if state ~= oldGameState then
      if state == kGameState.Started then
        ProfileLib.AddMarker("RoundStart")
      end
    
      oldGameState = state
    end
  end
end

function OnUpdateClient(deltaTime)
  
    Client.SetDebugText("Client.OnUpdateClient entry")

    PROFILE("Client:OnUpdateClient")
    
    UpdateTrailCinematics(deltaTime)
    UpdateDecals(deltaTime)
    UpdateWorldMessages()
    
    local player = Client.GetLocalPlayer()
    if player then

        --OnUpdateClientSeason() -- Can activate this to hide seasonal stuff after the game has started
        
        UpdateAmbientSounds(deltaTime)
        
        UpdateDSPEffects()
        
        UpdateTracers(deltaTime)
        
        --UpdateDangerEffects(player)
    end
    
    UpdatePowerPointLights()
    
    if not optionsSent then

        Client.UpdateInventory()
        optionsSent = true
        
    end

    CheckGameState()

    Client.SetDebugText("Client.OnUpdateClient exit")

end

function OnNotifyGUIItemDestroyed(destroyedItem)
    GetGUIManager():NotifyGUIItemDestroyed(destroyedItem)
end

function CreateTracer(startPoint, endPoint, velocity, doer, effectName, residueEffectName)

    if not Shared.GetIsRunningPrediction() then

        if not effectName then
        
            if doer.GetTracerEffectName then
                effectName = doer:GetTracerEffectName()
            else
                effectName = kDefaultTracerEffectName
            end
        
        end
        
        if not residueEffectName then
            
            if doer.GetTracerResidueEffectName then
                residueEffectName = doer:GetTracerResidueEffectName()
            end
            
        end

        local tracer = BuildTracer(startPoint, endPoint, velocity, effectName, residueEffectName)
        table.insert(Client.tracersList, tracer)
        
    end
    
end

function UpdateTracers(deltaTime)

    PROFILE("Client:UpdateTracers")

    local tracers = {}
    for i = #Client.tracersList, 1, -1 do
        local tracer = Client.tracersList[i]

        if tracer:GetTimeToDie() then
            tracer:OnDestroy()
        else
            tracer:OnUpdate(deltaTime)
            tracers[#tracers+1] = tracer
        end

    end

    Client.tracersList = tracers

end

--
--Shows or hides the skybox(es) based on the specified state.
--
function SetSkyboxDrawState(skyBoxVisible)

    for index, skyBox in ipairs(Client.skyBoxList) do
        skyBox:SetIsVisible( skyBoxVisible )
    end

end


local function OnMapPreLoad()
    
    -- Clear our list of render objects, lights, props
    Client.propList = { }

    Client.lightList = { }

    Client.skyBoxList = { }

    Client.ambientSoundList = { }
    Client.cachedAmbientSoundList = { }

    Client.tracersList = { }
    
    Client.rules = { }
    Client.DestroyReverbs()
    Client.ResetSoundSystem()
    
end

local function CheckRules()

    --Client side check for game requirements (listen server)
    --Required to prevent scripting errors on the client that can lead to false positives
    if Client.rules.numberMiniMapExtents == nil then
        Shared.Message('ERROR: minimap_extent entity is missing from the level.')
        Client.minimapExtentScale = Vector(100,100,100)
        Client.minimapExtentOrigin = Vector(0,0,0)
    elseif Client.rules.numberMiniMapExtents > 1 then
        Shared.Message('WARNING: There are too many minimap_extents, There should only be one placed in the level.')
    end

end

local function CheckMaxFPS()
    local maxfps = Clamp(Client.GetOptionInteger("graphics/maxfps", 200), 30, 1000)
    Client.SetOptionInteger("graphics/maxfps", maxfps)

    Shared.ConsoleCommand(string.format("maxfps %s", maxfps))
end

--
--Callback handler for when the map is finished loading.
--
local function OnMapPostLoad()

    -- Set sound falloff defaults
    Client.SetMinMaxSoundDistance(7, 100)

    InitializePathing()
    CreateDSPs()
    Scoreboard_Clear()
    CheckRules()
    PrecacheLightsAndProps()
    
    ConcedeSequence.CalculateAllTechpointCameraMoves()

end

--
--Returns the horizontal field of view adjusted so that regardless of the resolution,
--the vertical fov is a constant. standardAspect specifies the aspect ratio the game
--is designed to be played at.
--
function GetScreenAdjustedFov(horizontalFov, standardAspect)
        
    local actualAspect   = Client.GetScreenWidth() / Client.GetScreenHeight()
    
    local verticalFov    = 2.0 * math.atan(math.tan(horizontalFov * 0.5) / standardAspect)
    horizontalFov = 2.0 * math.atan(math.tan(verticalFov * 0.5) * actualAspect)

    return horizontalFov    

end

local function UpdateFogAreaModifiers(fromOrigin)

    local globalFogControls = Client.globalFogControls
    if globalFogControls then
    
        local viewZoneScale = globalFogControls.view_zone_scale
        local viewZoneColor = globalFogControls.view_zone_color
        
        local skyboxZoneScale = globalFogControls.skybox_zone_scale
        local skyboxZoneColor = globalFogControls.skybox_zone_color
        
        local defaultZoneScale = globalFogControls.default_zone_scale
        local defaultZoneColor = globalFogControls.default_zone_color
        
        for f = 1, #Client.fogAreaModifierList do
        
            local fogAreaModifier = Client.fogAreaModifierList[f]
            
            -- Check if the passed in origin is within the range of this fog area modifier.
            local distSq = (fogAreaModifier.origin - fromOrigin):GetLengthSquared()
            local startBlendRadiusSq = fogAreaModifier.start_blend_radius
            startBlendRadiusSq = startBlendRadiusSq * startBlendRadiusSq
            if distSq <= startBlendRadiusSq then
            
                local endBlendRadiusSq = fogAreaModifier.end_blend_radius
                endBlendRadiusSq = endBlendRadiusSq * endBlendRadiusSq
                local blendDistanceSq = startBlendRadiusSq - endBlendRadiusSq
                local distPercent = 1 - (math.max(distSq - endBlendRadiusSq, 0) / blendDistanceSq)
                 
                viewZoneScale = LerpNumber(viewZoneScale, fogAreaModifier.view_zone_scale, distPercent)
                viewZoneColor = LerpColor(viewZoneColor, fogAreaModifier.view_zone_color, distPercent)
                
                skyboxZoneScale = LerpNumber(skyboxZoneScale, fogAreaModifier.skybox_zone_scale, distPercent)
                skyboxZoneColor = LerpColor(skyboxZoneColor, fogAreaModifier.skybox_zone_color, distPercent)
                
                defaultZoneScale = LerpNumber(defaultZoneScale, fogAreaModifier.default_zone_scale, distPercent)
                defaultZoneColor = LerpColor(defaultZoneColor, fogAreaModifier.default_zone_color, distPercent)
                
                -- This only works with 1 fog area modifier currently.
                break
                
            end
            
        end
        
        Client.SetZoneFogDepthScale(RenderScene.Zone_ViewModel, 1.0 / viewZoneScale)
        Client.SetZoneFogColor(RenderScene.Zone_ViewModel, viewZoneColor)
        
        Client.SetZoneFogDepthScale(RenderScene.Zone_SkyBox, 1.0 / skyboxZoneScale)
        Client.SetZoneFogColor(RenderScene.Zone_SkyBox, skyboxZoneColor)
        
        Client.SetZoneFogDepthScale(RenderScene.Zone_Default, 1.0 / defaultZoneScale)
        Client.SetZoneFogColor(RenderScene.Zone_Default, defaultZoneColor)
        
    end
    
end

local gShowDebugTrace = false
function SetShowDebugTrace(value)
    gShowDebugTrace = value
end

local kDebugTraceGUISize = Vector(40, 40, 0)
local function UpdateDebugTrace()

    if not debugTraceGUI then
    
        debugTraceGUI = GUI.CreateItem()
        debugTraceGUI:SetSize(kDebugTraceGUISize)
        debugTraceGUI:SetAnchor(GUIItem.Middle, GUIItem.Center)
        debugTraceGUI:SetPosition(-kDebugTraceGUISize * 0.5)
        
    end

    debugTraceGUI:SetIsVisible(gShowDebugTrace)
    if gShowDebugTrace then
    
        local player = Client.GetLocalPlayer()
        if player then
            
            local viewCoords = player:GetViewCoords()
            local normalTrace = Shared.TraceRay(viewCoords.origin, viewCoords.origin + viewCoords.zAxis * 100, CollisionRep.Default, PhysicsMask.CystBuild, EntityFilterAll())
            
            local color = normalTrace.fraction == 1 and Color(1, 0, 0, 0.5) or Color(1,1,1,0.5)
            debugTraceGUI:SetColor(color)
        
        end
    
    end

end

-- Return effective fov for the player, including options adjustment and scaling for screen resolution
function Client.GetEffectiveFov(player)
    
    local adjustValue   = Clamp( Client.GetOptionFloat("graphics/display/fov-adjustment",0), 0, 1 )
    local adjustRadians = math.rad(
        (1-adjustValue)*kMinFOVAdjustmentDegrees + adjustValue*kMaxFOVAdjustmentDegrees)
    
    -- Don't adjust the FOV for the commander.
    if player:isa("Commander") then
        adjustRadians = 0
    end
        
    return player:GetRenderFov()+adjustRadians
end

--
--Called once per frame to setup the camera for rendering the scene.
--
local function OnUpdateRender()
    
    Infestation_UpdateForPlayer()
    
    if OnUpdateRenderOverride then
        local success = OnUpdateRenderOverride()
        if success then
            return
        end
    end
    
    if ConcedeSequence and ConcedeSequence.UpdateRenderOverride then
        local success = ConcedeSequence.UpdateRenderOverride()
        if success then
            return
        end
    end
    
    local camera = Camera()
    local cullingMode = RenderCamera.CullingMode_Occlusion
    
    local player = Client.GetLocalPlayer()
    -- If we have a player, use them to setup the camera.
    if player ~= nil then
    
        local coords = player:GetCameraViewCoords()
        
        --UpdateFogAreaModifiers(coords.origin)
        
        camera:SetCoords(coords)
        
        local adjustValue   = Clamp( Client.GetOptionFloat("graphics/display/fov-adjustment",0), 0, 1 )
        local adjustRadians = math.rad(
            (1-adjustValue)*kMinFOVAdjustmentDegrees + adjustValue*kMaxFOVAdjustmentDegrees)
        
        -- Don't adjust the FOV for the commander or spectator
        if player:isa("Commander") or player:isa("Spectator") then
            adjustRadians = 0
        end
            
        camera:SetFov(player:GetRenderFov()+adjustRadians)
        
        -- In commander mode use frustum culling since the occlusion geometry
        -- isn't generally setup for viewing the level from the outside (and
        -- there is very little occlusion anyway)
        if player:GetIsOverhead() then
            cullingMode = RenderCamera.CullingMode_Frustum
        end
        
        local horizontalFov = GetScreenAdjustedFov( camera:GetFov(), 4 / 3 )
        
        local farPlane = player:GetCameraFarPlane()
        
        -- Occlusion culling doesn't use the far plane, so switch to frustum culling
        -- with close far planes
        if farPlane then
            cullingMode = RenderCamera.CullingMode_Frustum
        else
            farPlane = 1000.0
        end
        
        gRenderCamera:SetCoords(camera:GetCoords())
        gRenderCamera:SetFov(horizontalFov)
        gRenderCamera:SetNearPlane(0.03)
        gRenderCamera:SetFarPlane(farPlane)
        gRenderCamera:SetCullingMode(cullingMode)
        Client.SetRenderCamera(gRenderCamera)
        
        local outlinePlayers = Client.GetOutlinePlayers() and Client.GetLocalClientTeamNumber() == kSpectatorIndex

        HiveVision_SetEnabled( GetIsAlienUnit(player) or outlinePlayers )
        HiveVision_SyncCamera( gRenderCamera, player:isa("Commander") or outlinePlayers )
        
        EquipmentOutline_SetEnabled( GetIsMarineUnit(player) or outlinePlayers )
        EquipmentOutline_SyncCamera( gRenderCamera, player:isa("Commander") or outlinePlayers )
        
        if OptionsDialogUI_GetAtmospherics() then
            if player:GetShowAtmosphericLight() then
                EnableAtmosphericDensity()
            else
                DisableAtmosphericDensity()
            end
        end

    else
    
        Client.SetRenderCamera(nil)
        HiveVision_SetEnabled( false )
        EquipmentOutline_SetEnabled( false )
        
    end
    
    UpdateDebugTrace()
    
end

function Client.AddWorldMessage(messageType, message, position, entityId)

    -- Only add damage messages if we have it enabled
    if messageType ~= kWorldTextMessageType.Damage or Client.GetOptionBoolean( "drawDamage", false ) then

        -- If we already have a message for this entity id, update existing message instead of adding new one
        local time = Client.GetTime()
            
        local updatedExisting = false
        
        if messageType == kWorldTextMessageType.Damage then
        
            for _, currentWorldMessage in ipairs(Client.worldMessages) do
            
                if currentWorldMessage.messageType == messageType and currentWorldMessage.entityId == entityId and entityId ~= nil and entityId ~= Entity.invalidId then
                
                    currentWorldMessage.creationTime = time
                    currentWorldMessage.position = position
                    currentWorldMessage.previousNumber = tonumber(currentWorldMessage.message)
                    currentWorldMessage.message = currentWorldMessage.message + message
                    currentWorldMessage.minimumAnimationFraction = kWorldDamageRepeatAnimationScalar
                    
                    updatedExisting = true
                    break
                    
                end
                
            end
            
        end
        
        if not updatedExisting then
        
            local worldMessage = {}
            
            worldMessage.messageType = messageType
            worldMessage.message = message
            worldMessage.position = position        
            worldMessage.creationTime = time
            worldMessage.entityId = entityId
            worldMessage.animationFraction = 0
            worldMessage.lifeTime = ConditionalValue(kWorldTextMessageType.CommanderError == messageType, kCommanderErrorMessageLifeTime, kWorldMessageLifeTime)
            
            if messageType == kWorldTextMessageType.CommanderError then
            
                local commander = Client.GetLocalPlayer()
                if commander then
                    commander:TriggerInvalidSound()
                end
                
            end
            
            table.insert(Client.worldMessages, worldMessage)
            
        end
        
    end
    
end

function Client.GetWorldMessages()
    return Client.worldMessages
end

function Client.CreateTrailCinematic(renderZone)

    local trailCinematic = TrailCinematic()
    trailCinematic:Initialize(renderZone)
    table.insert(Client.trailCinematics, trailCinematic)
    return trailCinematic
    
end

function Client.ResetTrailCinematic(trailCinematic)
    return trailCinematic:Destroy()    
end

function Client.DestroyTrailCinematic(trailCinematic, nextFrame)

    if nextFrame then
    
        table.insert(Client.destroyTrailCinematics, trailCinematic)
        return true
        
    end
    
    local success = trailCinematic:Destroy()
    return success and table.removevalue(Client.trailCinematics, trailCinematic)
    
end

local function OnClientConnected()
end

--
--Called when the client is disconnected from the server.
--
local function OnClientDisconnected(reason)

    -- Clean up the render objects we created during the level load.
    DestroyLevelObjects()
    
    ClientUI.DestroyUIScripts()
    
    -- Hack to avoid script error if load hasn't completed yet.
    if Client.SetOptionString then
        Client.SetOptionString("lastServerMapName", "")
    end
    
end

local function SendAddBotCommands()

    ------------------------------------------
    --  If bots were requested via the main menu, add them now
    ------------------------------------------
    if Client.GetOptionBoolean("botsSettings_enableBots", false) then
        Client.SetOptionBoolean("botsSettings_enableBots", false)

        Shared.ConsoleCommand( "sv_maxbots 12 true" )
    end

    if Client.GetOptionBoolean("sendBotsCommands", false) then
        Client.SetOptionBoolean("sendBotsCommands", false)

        local numMarineBots = Client.GetOptionInteger("botsSettings_numMarineBots", 0)
        local numAlienBots = Client.GetOptionInteger("botsSettings_numAlienBots", 0)
        local addMarineCom = Client.GetOptionBoolean("botsSettings_marineCom", false)
        local addAlienCom = Client.GetOptionBoolean("botsSettings_alienCom", false)
        local marineSkill = Client.GetOptionString("botsSettings_marineSkillLevel", "Intermediate")

        if numMarineBots > 0 then
            Shared.ConsoleCommand( string.format("addbot %d 1", numMarineBots) )
        end

        if numAlienBots > 0 then
            Shared.ConsoleCommand( string.format("addbot %d 2", numAlienBots) )
        end

        if addMarineCom then
            Shared.ConsoleCommand("addbot 1 1 com")
        end

        if addAlienCom then
            Shared.ConsoleCommand("addbot 1 2 com")
        end

        local skill2jitter =
        {
            Beginner = 1.2,
            Intermediate = 0.8,
            Expert = 0.4
        }
        Shared.ConsoleCommand(string.format("marinejitter %f", skill2jitter[marineSkill]))

        Shared.ConsoleCommand("bottraining")
    end

end


local function OnLoadComplete()
    
    Client.fullyLoaded = true
    
    Render_SyncRenderOptions()
    Input_SyncInputOptions()
    HitSounds_SyncOptions()
    OptionsDialogUI_SyncSoundVolumes()
    MainMenu_Preload()

    HiveVision_Initialize()
    EquipmentOutline_Initialize()
    
    
    -- In case name changed during load
    SetNameWithSteamPersona()
    local playerName = GetNickName()
    
    Client.SendNetworkMessage("SetName", { name = playerName }, true)
    
    Lights_UpdateLightMode()
    
    SendAddBotCommands()
    
    ------------------------------------------
    --  Stuff for first-time optimization dialog
    ------------------------------------------

    -- Remember the build number of when we last loaded a map
    Client.SetOptionInteger("lastLoadedBuild", Shared.GetBuildNumber())

    if Client.GetOptionBoolean("immediateDisconnect", false) then
        Client.SetOptionBoolean("immediateDisconnect", false)
        Shared.ConsoleCommand("disconnect")
    end

    ------------------------------------------
    --  Stuff for sandbox mode
    ------------------------------------------
    if Client.GetOptionBoolean("sandboxMode", false) then
        Client.SetOptionBoolean("sandboxMode", false)
        Shared.ConsoleCommand("cheats 1")
        Shared.ConsoleCommand("autobuild")
        Shared.ConsoleCommand("alltech")
        Shared.ConsoleCommand("fastevolve")
        Shared.ConsoleCommand("allfree")
        Shared.ConsoleCommand("sandbox")
    end
    
    PreLoadGUIScripts()
    
    currentLoadingTime = Shared.GetSystemTimeReal() - startLoadingTime
    Print("Loading took " .. ToString(currentLoadingTime) .. " seconds")

    if Client.lowLightList and #Client.lowLightList == 0 and Client.GetOptionInteger("graphics/lightQuality", 2) == 1 then
        Shared.Message("Map doesn't support low lights option, defaulting to regular lights.")
        Shared.ConsoleCommand("output " .. "Map doesn't support low lights option, defaulting to regular lights.")
    end

    --tell the server if we played the tutorial or not
    if Client.GetAchievement("First_0_1") then
        Client.SendNetworkMessage( "PlayedTutorial", {}, true)
    end

    CheckMaxFPS()
end

local function TimeoutDecals(materialName, origin, distance)

    local squaredDistance = distance * distance
    for i = 1, #Client.timeLimitedDecals do
    
        local decalEntry = Client.timeLimitedDecals[i]
        
        if (decalEntry[1]:GetCoords().origin - origin):GetLengthSquared() < squaredDistance then
            decalEntry[2] = Shared.GetTime() + 1
            decalEntry[3]:SetParameter("endTime", Shared.GetTime() + 1)
        end
    
    end

end

function Client.CreateTimeLimitedDecal(materialName, coords, scale, lifeTime)

    if not lifeTime then
        lifeTime = Client.GetOptionFloat("graphics/decallifetime", 0.2) * kDecalMaxLifetime
    end
        
    if lifeTime ~= 0 then

        -- Create new decal
        local decal = Client.CreateRenderDecal()
        local material = Client.CreateRenderMaterial()
        material:SetMaterial(materialName)            
        decal:SetMaterial(material)
        decal:SetCoords(coords)
        
        -- Set uniform scale from parameter
        decal:SetExtents( Vector(scale, scale, scale) )
        material:SetParameter("scale", scale)
        
        local endTime = Shared.GetTime() + lifeTime
        material:SetParameter("endTime", endTime)
        
        -- timeout nearby decals using the same material, ignore too small decal
        if scale > 0.3 then
            TimeoutDecals(materialName, coords.origin, scale * 0.5)
        end
        
        table.insert(Client.timeLimitedDecals, {decal, endTime, material, materialName})

    end

end

local firstPersonSpectateUI
local function OnLocalPlayerChanged()

    local player = Client.GetLocalPlayer()
    -- Show and hide UI elements based on the type of player passed in.
    ClientUI.EvaluateUIVisibility(player)
    ClientResources.EvaluateResourceVisibility(player)
    
    HelpScreen_GetHelpScreen():OnLocalPlayerChanged()
    
    if player then
    
        player:OnInitLocalClient()
        
        if not Client.GetIsControllingPlayer() and not firstPersonSpectateUI then
            firstPersonSpectateUI = GetGUIManager():CreateGUIScript("GUIFirstPersonSpectate")
        elseif Client.GetIsControllingPlayer() and firstPersonSpectateUI then
        
            GetGUIManager():DestroyGUIScript(firstPersonSpectateUI)
            firstPersonSpectateUI = nil
            
        end
        
    end
    
end
Event.Hook("LocalPlayerChanged", OnLocalPlayerChanged)

Event.Hook("ClientDisconnected", OnClientDisconnected)
Event.Hook("ClientConnected", OnClientConnected)
Event.Hook("UpdateRender", OnUpdateRender)
Event.Hook("MapLoadEntity", OnMapLoadEntity)
Event.Hook("MapPreLoad", OnMapPreLoad)
Event.Hook("MapPostLoad", OnMapPostLoad)
Event.Hook("UpdateClient", OnUpdateClient, "Client")
Event.Hook("NotifyGUIItemDestroyed", OnNotifyGUIItemDestroyed)
Event.Hook("LoadComplete", OnLoadComplete)

-- Debug command to test resolution scaling
-- Not super elegant, but provides easy test cases
local function swapres()
    if Shared.GetTestsEnabled() or Shared.GetCheatsEnabled() then
        local xres = Client.GetScreenWidth()
        local yres = Client.GetScreenHeight()
        
        if xres == 640 then
            xres = 3840
        elseif xres == 3840 then
            xres = 1920
        else
            xres = 640
        end
        
        if yres == 480 then
            yres = 2160
        elseif yres == 2160 then
            yres = 1080
        else
            yres = 480
        end
        
        Client.SetOptionInteger( kGraphicsXResolutionOptionsKey, xres)
        Client.SetOptionInteger( kGraphicsYResolutionOptionsKey, yres)
        Client.SetOptionString( kWindowModeOptionsKey, "fullscreen-windowed")
        Client.ReloadGraphicsOptions()
        Print(xres .. " " .. yres)
    else
        Shared.Message("This command requires cheats or tests enabled.")
    end
end
Event.Hook("Console_swapres", swapres)

Event.Hook("DebugState",
function()
    -- Leaving this here for future debugging convenience.
    local player = Client.GetLocalPlayer()
    if player then
        DebugPrint("active weapon id = %d", player.activeWeaponId )
    end
end)

Script.Load("lua/PostLoadMod.lua")

-- Initialize the camera at load time, so that the render setup will be
-- properly precached during the loading screen.
InitializeRenderCamera()

-- setup the time buffer for the killcam - 8 seconds long
--Client.SetTimeBuffer(8)