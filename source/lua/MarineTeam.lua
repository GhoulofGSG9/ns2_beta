-- ======= Copyright (c) 2003-2011, Unknown Worlds Entertainment, Inc. All rights reserved. =======
--
-- lua\MarineTeam.lua
--
--    Created by:   Charlie Cleveland (charlie@unknownworlds.com) and
--                  Max McGuire (max@unknownworlds.com)
--
-- This class is used for teams that are actually playing the game, e.g. Marines or Aliens.
--
-- ========= For more information, visit us at http://www.unknownworlds.com =====================

Script.Load("lua/Marine.lua")
Script.Load("lua/PlayingTeam.lua")

class 'MarineTeam' (PlayingTeam)

MarineTeam.gSandboxMode = false

-- How often to send the "No IPs" message to the Marine team in seconds.
local kSendNoIPsMessageRate = 20

local kCannotSpawnSound = PrecacheAsset("sound/NS2.fev/marine/voiceovers/commander/need_ip")

--Cache for spawned ip positions
local takenInfantryPortalPoints = {}


function MarineTeam:OnInitialized()

    PlayingTeam.OnInitialized(self)

    self.activeStructureSkin = kDefaultMarineStructureVariant

end

function MarineTeam:ResetTeam()
	takenInfantryPortalPoints = {}
	
    local commandStructure = PlayingTeam.ResetTeam(self)
    
    self.updateMarineArmor = false
    
    if self.brain ~= nil then
        self.brain:Reset()
    end
    
    return commandStructure
    
end

function MarineTeam:OnResetComplete()

    --adjust first power node
    local initialTechPoint = self:GetInitialTechPoint()
    for _, powerPoint in ientitylist(Shared.GetEntitiesWithClassname("PowerPoint")) do
    
        if powerPoint:GetLocationName() == initialTechPoint:GetLocationName() then
            powerPoint:SetConstructionComplete()
        end
        
    end

    local commander = self:GetCommander()
    local gameInfo = GetGameInfoEntity()
    
    if commander then

        local commStructSkin = commander:GetCommanderStructureSkin()
        
        if commStructSkin then
            gameInfo:SetTeamSkin( self:GetTeamNumber(), commStructSkin )
        end

    else
        gameInfo:SetTeamSkin( self:GetTeamNumber(), kDefaultMarineStructureVariant )
    end
    
end

function MarineTeam:GetActiveTeamSkin()
    return self.activeStructureSkin
end

function MarineTeam:SetStructureSkinIndex( skinIndex )
    self.activeStructureSkin = skinIndex  --TODO Better enum/range/value checking
end

function MarineTeam:GetTeamType()
    return kMarineTeamType
end

function MarineTeam:GetIsMarineTeam()
    return true 
end

function MarineTeam:Initialize(teamName, teamNumber)

    PlayingTeam.Initialize(self, teamName, teamNumber)
    
    self.respawnEntity = Marine.kMapName
    
    self.updateMarineArmor = false
    
    self.lastTimeNoIPsMessageSent = Shared.GetTime()
    
end

function MarineTeam:GetHasAbilityToRespawn()

    -- Any active IPs on team? There could be a case where everyone has died and no active
    -- IPs but builder bots are mid-construction so a marine team could theoretically keep
    -- playing but ignoring that case for now
    local spawningStructures = GetEntitiesForTeam("InfantryPortal", self:GetTeamNumber())
    
    for _, current in ipairs(spawningStructures) do
    
        if current:GetIsBuilt() and current:GetIsPowered() then
            return true
        end
        
    end        
    
    return false
    
end

function MarineTeam:OnRespawnQueueChanged()

    local spawningStructures = GetEntitiesForTeam("InfantryPortal", self:GetTeamNumber())
    
    for _, current in ipairs(spawningStructures) do
    
        if current:GetIsBuilt() and current:GetIsPowered() then
            current:FillQueueIfFree()
        end
        
    end        
    
end


function MarineTeam:GetTotalInRespawnQueue()

    local numPlayers = 0
    
    for i = 1, self.respawnQueue:GetCount() do
        local player = Shared.GetEntity(self.respawnQueue:GetValueAtIndex(i))
        if player then
            numPlayers = numPlayers + 1
        end
    
    end
    
    local allIPs = GetEntitiesForTeam( "InfantryPortal", self:GetTeamNumber() )
    if #allIPs > 0 then
        
        for _, ip in ipairs( allIPs ) do
        
            if GetIsUnitActive( ip ) then
                
                if ip.queuedPlayerId ~= nil and ip.queuedPlayerId ~= Entity.invalidId then
                    numPlayers = numPlayers + 1
                end
                
            end
        
        end
        
    end
    
    return numPlayers
    
end


-- Clear distress flag for all players on team, unless affected by distress beaconing Observatory.
-- This function is here to make sure case with multiple observatories and distress beacons is
-- handled properly.
function MarineTeam:UpdateGameMasks()

    PROFILE("MarineTeam:UpdateGameMasks")

    local beaconState = false
    
    for _, obs in ipairs(GetEntitiesForTeam("Observatory", self:GetTeamNumber())) do
    
        if obs:GetIsBeaconing() then
        
            beaconState = true
            break
            
        end
        
    end
    
    for _, player in ipairs(self:GetPlayers()) do
    
        if player:GetGameEffectMask(kGameEffect.Beacon) ~= beaconState then
            player:SetGameEffectMask(kGameEffect.Beacon, beaconState)
        end
        
    end
    
end

function MarineTeam:CheckForNoIPs()

    PROFILE("MarineTeam:CheckForNoIPs")

    if Shared.GetTime() - self.lastTimeNoIPsMessageSent >= kSendNoIPsMessageRate then
    
        self.lastTimeNoIPsMessageSent = Shared.GetTime()
        if Shared.GetEntitiesWithClassname("InfantryPortal"):GetSize() == 0 then

            local func = Closure [=[
                self kCannotSpawnSound
                args player
                StartSoundEffectForPlayer(kCannotSpawnSound, player)
            ]=]{kCannotSpawnSound}
            self:ForEachPlayer(func)
            SendTeamMessage(self, kTeamMessageTypes.CannotSpawn)
            
        end
        
    end
    
end

function MarineTeam:SpawnInfantryPortal(techPoint)
    local techPointOrigin = techPoint:GetOrigin() + Vector(0, 2, 0)

    local spawnPoint

    local attachRange = kInfantryPortalAttachRange
    local attachRangeSquared = attachRange * attachRange
    -- First check the predefined spawn points. Look for a close one.
    for p = 1, #Server.infantryPortalSpawnPoints do

        if not takenInfantryPortalPoints[p] then
            local predefinedSpawnPoint = Server.infantryPortalSpawnPoints[p]
            if (predefinedSpawnPoint - techPointOrigin):GetLengthSquared() <= attachRangeSquared then
                spawnPoint = predefinedSpawnPoint
                takenInfantryPortalPoints[p] = true
                break
            end
        end

    end

    if not spawnPoint then

        spawnPoint = GetRandomBuildPosition( kTechId.InfantryPortal, techPointOrigin, attachRange )
        spawnPoint = spawnPoint and spawnPoint - Vector( 0, 0.6, 0 )

    end

    if spawnPoint then

        local ip = CreateEntity(InfantryPortal.kMapName, spawnPoint, self:GetTeamNumber())

        SetRandomOrientation(ip)
        ip:SetConstructionComplete()

        self.spawnedInfantryPortal = self.spawnedInfantryPortal + 1

    end

end

function MarineTeam:AddPlayer(player)
    PlayingTeam.AddPlayer(self, player)

    if self.startTechPoint and self.spawnedInfantryPortal == 1 and #self.playerIds >= kSecondInitialInfantryPortalMinPlayerCount then

        -- check that the initial tech point is still controlled by the marines
        local techPoint = self.startTechPoint
        local techPointOrigin = techPoint:GetOrigin()

        local commandStations = GetEntitiesForTeam("CommandStation", self:GetTeamNumber())
        local numCommandStations = #commandStations

        -- abort if marines don't have any command stations at the moment
        if numCommandStations == 0 then return end

        local inRange = false
        local rangeSquared = kInfantryPortalAttachRange * kInfantryPortalAttachRange

        for i = 1, numCommandStations do
            local commandStation = commandStations[i]
            if (commandStation:GetOrigin() - techPointOrigin):GetLengthSquaredXZ() <= rangeSquared then
                inRange = true
                break
            end
        end

        if not inRange then
            techPoint = commandStations[1]
        end

        self:SpawnInfantryPortal(techPoint)
    end
end

local function GetArmorLevel(self)

    local armorLevels = 0
    
    local techTree = self:GetTechTree()
    if techTree then
    
        if techTree:GetHasTech(kTechId.Armor3) then
            armorLevels = 3
        elseif techTree:GetHasTech(kTechId.Armor2) then
            armorLevels = 2
        elseif techTree:GetHasTech(kTechId.Armor1) then
            armorLevels = 1
        end
    
    end
    
    return armorLevels

end

function MarineTeam:Update(timePassed)

    PROFILE("MarineTeam:Update")

    PlayingTeam.Update(self, timePassed)
    
    -- Update distress beacon mask
    self:UpdateGameMasks(timePassed)    

    if GetGamerules():GetGameStarted() then
        self:CheckForNoIPs()
    end
    
    local armorLevel = GetArmorLevel(self)
    for _, player in ipairs(GetEntitiesForTeam("Player", self:GetTeamNumber())) do
        player:UpdateArmorAmount(armorLevel)
    end
    
end

function MarineTeam:GetHasPoweredPhaseGate()
    return self.hasPoweredPG == true    
end

function MarineTeam:InitTechTree()

    PlayingTeam.InitTechTree(self)

    -- Marine tier 1
    self.techTree:AddBuildNode(kTechId.CommandStation,            kTechId.None,                kTechId.None)
    self.techTree:AddBuildNode(kTechId.Extractor,                 kTechId.None,                kTechId.None)

    self.techTree:AddUpgradeNode(kTechId.ExtractorArmor)

    -- Count recycle like an upgrade so we can have multiples
    self.techTree:AddUpgradeNode(kTechId.Recycle, kTechId.None, kTechId.None)

    self.techTree:AddPassive(kTechId.Welding)
    self.techTree:AddPassive(kTechId.SpawnMarine)
    self.techTree:AddPassive(kTechId.CollectResources, kTechId.Extractor)
    self.techTree:AddPassive(kTechId.Detector)

    self.techTree:AddSpecial(kTechId.TwoCommandStations)
    self.techTree:AddSpecial(kTechId.ThreeCommandStations)

    -- When adding marine upgrades that morph structures, make sure to add to GetRecycleCost() also
    self.techTree:AddBuildNode(kTechId.InfantryPortal,            kTechId.CommandStation,                kTechId.None)
    self.techTree:AddBuildNode(kTechId.Sentry,                    kTechId.RoboticsFactory,     kTechId.None, true)
    self.techTree:AddBuildNode(kTechId.Armory,                    kTechId.CommandStation,      kTechId.None)
    self.techTree:AddBuildNode(kTechId.ArmsLab,                   kTechId.CommandStation,                kTechId.None)
    self.techTree:AddManufactureNode(kTechId.MAC,                 kTechId.RoboticsFactory,                kTechId.None,  true)

    self.techTree:AddBuyNode(kTechId.Axe,                         kTechId.None,              kTechId.None)
    self.techTree:AddBuyNode(kTechId.Pistol,                      kTechId.None,                kTechId.None)
    self.techTree:AddBuyNode(kTechId.Rifle,                       kTechId.None,                kTechId.None)

    self.techTree:AddBuildNode(kTechId.SentryBattery,             kTechId.RoboticsFactory,      kTechId.None)

    self.techTree:AddOrder(kTechId.Defend)
    self.techTree:AddOrder(kTechId.FollowAndWeld)

    -- Commander abilities
    self.techTree:AddResearchNode(kTechId.AdvancedMarineSupport)

    self.techTree:AddTargetedActivation(kTechId.NanoShield,       kTechId.AdvancedMarineSupport)
    self.techTree:AddTargetedActivation(kTechId.Scan,             kTechId.Observatory)
    self.techTree:AddTargetedActivation(kTechId.PowerSurge,       kTechId.AdvancedMarineSupport)
    self.techTree:AddTargetedActivation(kTechId.MedPack,          kTechId.None)
    self.techTree:AddTargetedActivation(kTechId.AmmoPack,         kTechId.None)
    self.techTree:AddTargetedActivation(kTechId.CatPack,          kTechId.AdvancedMarineSupport)

    self.techTree:AddAction(kTechId.SelectObservatory)

    -- Armory upgrades
    self.techTree:AddUpgradeNode(kTechId.AdvancedArmoryUpgrade,  kTechId.Armory)

    -- arms lab upgrades

    self.techTree:AddResearchNode(kTechId.Armor1,                 kTechId.ArmsLab)
    self.techTree:AddResearchNode(kTechId.Armor2,                 kTechId.Armor1, kTechId.None)
    self.techTree:AddResearchNode(kTechId.Armor3,                 kTechId.Armor2, kTechId.None)
    self.techTree:AddResearchNode(kTechId.NanoArmor,              kTechId.None)

    self.techTree:AddResearchNode(kTechId.Weapons1,               kTechId.ArmsLab)
    self.techTree:AddResearchNode(kTechId.Weapons2,               kTechId.Weapons1, kTechId.None)
    self.techTree:AddResearchNode(kTechId.Weapons3,               kTechId.Weapons2, kTechId.None)

    -- Marine tier 2
    self.techTree:AddBuildNode(kTechId.AdvancedArmory,               kTechId.Armory,        kTechId.None)
    self.techTree:AddResearchNode(kTechId.PhaseTech,                    kTechId.Observatory,        kTechId.None)
    self.techTree:AddBuildNode(kTechId.PhaseGate,                    kTechId.PhaseTech,        kTechId.None, true)


    self.techTree:AddBuildNode(kTechId.Observatory,               kTechId.InfantryPortal,       kTechId.Armory)      
    self.techTree:AddActivation(kTechId.DistressBeacon,           kTechId.Observatory)
    self.techTree:AddActivation(kTechId.ReversePhaseGate,         kTechId.None)

    -- Door actions
    self.techTree:AddBuildNode(kTechId.Door, kTechId.None, kTechId.None)
    self.techTree:AddActivation(kTechId.DoorOpen)
    self.techTree:AddActivation(kTechId.DoorClose)
    self.techTree:AddActivation(kTechId.DoorLock)
    self.techTree:AddActivation(kTechId.DoorUnlock)

    -- Weapon-specific
    self.techTree:AddResearchNode(kTechId.ShotgunTech,           kTechId.Armory,              kTechId.None)
    self.techTree:AddTargetedBuyNode(kTechId.Shotgun,            kTechId.ShotgunTech,         kTechId.None)
    self.techTree:AddTargetedActivation(kTechId.DropShotgun,     kTechId.ShotgunTech,         kTechId.None)

    --self.techTree:AddResearchNode(kTechId.HeavyMachineGunTech,           kTechId.AdvancedWeaponry,              kTechId.None)
    self.techTree:AddTargetedBuyNode(kTechId.HeavyMachineGun,            kTechId.AdvancedWeaponry)
    self.techTree:AddTargetedActivation(kTechId.DropHeavyMachineGun,     kTechId.AdvancedWeaponry)

    self.techTree:AddResearchNode(kTechId.AdvancedWeaponry,      kTechId.AdvancedArmory,      kTechId.None)

    self.techTree:AddTargetedBuyNode(kTechId.GrenadeLauncher,  kTechId.AdvancedWeaponry)
    self.techTree:AddTargetedActivation(kTechId.DropGrenadeLauncher,  kTechId.AdvancedWeaponry)

    self.techTree:AddResearchNode(kTechId.GrenadeTech,           kTechId.Armory,                   kTechId.None)
    self.techTree:AddTargetedBuyNode(kTechId.ClusterGrenade,     kTechId.GrenadeTech)
    self.techTree:AddTargetedBuyNode(kTechId.GasGrenade,         kTechId.GrenadeTech)
    self.techTree:AddTargetedBuyNode(kTechId.PulseGrenade,       kTechId.GrenadeTech)

    self.techTree:AddTargetedBuyNode(kTechId.Flamethrower,     kTechId.AdvancedWeaponry)
    self.techTree:AddTargetedActivation(kTechId.DropFlamethrower,    kTechId.AdvancedWeaponry)

    self.techTree:AddResearchNode(kTechId.MinesTech,            kTechId.Armory,           kTechId.None)
    self.techTree:AddTargetedBuyNode(kTechId.LayMines,          kTechId.MinesTech,        kTechId.None)
    self.techTree:AddTargetedActivation(kTechId.DropMines,      kTechId.MinesTech,        kTechId.None)

    self.techTree:AddTargetedBuyNode(kTechId.Welder,          kTechId.Armory,        kTechId.None)
    self.techTree:AddTargetedActivation(kTechId.DropWelder,   kTechId.Armory,        kTechId.None)

    -- ARCs
    self.techTree:AddBuildNode(kTechId.RoboticsFactory,                    kTechId.InfantryPortal,                 kTechId.None)
    self.techTree:AddUpgradeNode(kTechId.UpgradeRoboticsFactory,           kTechId.Armory,              kTechId.RoboticsFactory)
    self.techTree:AddBuildNode(kTechId.ARCRoboticsFactory,                 kTechId.Armory,              kTechId.RoboticsFactory)

    self.techTree:AddTechInheritance(kTechId.RoboticsFactory, kTechId.ARCRoboticsFactory)

    self.techTree:AddManufactureNode(kTechId.ARC,    kTechId.ARCRoboticsFactory,     kTechId.None, true)
    self.techTree:AddActivation(kTechId.ARCDeploy)
    self.techTree:AddActivation(kTechId.ARCUndeploy)

    -- Robotics factory menus
    self.techTree:AddMenu(kTechId.RoboticsFactoryARCUpgradesMenu)
    self.techTree:AddMenu(kTechId.RoboticsFactoryMACUpgradesMenu)

    self.techTree:AddMenu(kTechId.WeaponsMenu)

    -- Marine tier 3
    self.techTree:AddBuildNode(kTechId.PrototypeLab,          kTechId.AdvancedArmory,              kTechId.None)

    -- Jetpack
    self.techTree:AddResearchNode(kTechId.JetpackTech,           kTechId.PrototypeLab, kTechId.None)
    self.techTree:AddBuyNode(kTechId.Jetpack,                    kTechId.JetpackTech, kTechId.None)
    self.techTree:AddTargetedActivation(kTechId.DropJetpack,    kTechId.JetpackTech, kTechId.None)

    -- Exosuit
    self.techTree:AddResearchNode(kTechId.ExosuitTech,           kTechId.PrototypeLab, kTechId.None)
    self.techTree:AddBuyNode(kTechId.DualMinigunExosuit, kTechId.ExosuitTech, kTechId.None)
    self.techTree:AddBuyNode(kTechId.DualRailgunExosuit, kTechId.ExosuitTech, kTechId.None)

    --  self.techTree:AddTargetedActivation(kTechId.DropExosuit,     kTechId.ExosuitTech, kTechId.None)

    --self.techTree:AddResearchNode(kTechId.DualMinigunTech,       kTechId.ExosuitTech, kTechId.TwoCommandStations)
    --self.techTree:AddResearchNode(kTechId.DualMinigunExosuit,    kTechId.DualMinigunTech, kTechId.TwoCommandStations)
    --self.techTree:AddResearchNode(kTechId.ClawRailgunExosuit,    kTechId.ExosuitTech, kTechId.None)
    --self.techTree:AddResearchNode(kTechId.DualRailgunTech,       kTechId.ExosuitTech, kTechId.TwoCommandStations)
    --self.techTree:AddResearchNode(kTechId.DualRailgunExosuit,    kTechId.DualMinigunTech, kTechId.TwoCommandStations)


    self.techTree:AddActivation(kTechId.SocketPowerNode,    kTechId.None,   kTechId.None)

    self.techTree:SetComplete()

end

function MakeTechEnt( techPoint, mapName, rightOffset, forwardOffset, teamType )
    local origin = techPoint:GetOrigin()
    local right = techPoint:GetCoords().xAxis
    local forward = techPoint:GetCoords().zAxis
    local position = origin + right * rightOffset + forward * forwardOffset

    local newEnt = CreateEntity( mapName, position, teamType)
    if HasMixin( newEnt, "Construct" ) then
        SetRandomOrientation( newEnt )
        newEnt:SetConstructionComplete()
    end

    if HasMixin( newEnt, "Live" ) then
        newEnt:SetIsAlive(true)
    end

    return newEnt
end

function MarineTeam:SpawnWarmUpStructures()
    local techPoint = self.startTechPoint
    if not (Shared.GetCheatsEnabled() and MarineTeam.gSandboxMode) and #self.warmupStructures == 0 then
        self.warmupStructures[#self.warmupStructures+1] = MakeTechEnt(techPoint, AdvancedArmory.kMapName, 3.5, -2, kMarineTeamType)
        self.warmupStructures[#self.warmupStructures+1] = MakeTechEnt(techPoint, PrototypeLab.kMapName, -3.5, 2, kMarineTeamType)
    end
end

function MarineTeam:SpawnInitialStructures(techPoint)

    self.warmupStructures = {}
    self.startTechPoint = techPoint
    self.spawnedInfantryPortal = 0
    takenInfantryPortalPoints = {}

    local tower, commandStation = PlayingTeam.SpawnInitialStructures(self, techPoint)

    self:SpawnInfantryPortal(techPoint)
    -- Spawn a second IP when marines have 9 or more players
    if self:GetNumPlayers() >= kSecondInitialInfantryPortalMinPlayerCount then
        self:SpawnInfantryPortal(techPoint)
    end

    if Shared.GetCheatsEnabled() and MarineTeam.gSandboxMode then
        MakeTechEnt(techPoint, AdvancedArmory.kMapName, 3.5, -2, kMarineTeamType)
        MakeTechEnt(techPoint, PrototypeLab.kMapName, -3.5, 2, kMarineTeamType)
    end

    return tower, commandStation

end

function MarineTeam:GetSpectatorMapName()
    return MarineSpectator.kMapName
end

function MarineTeam:OnBought(techId)

    local listeners = self.eventListeners['OnBought']

    if listeners then

        for _, listener in ipairs(listeners) do
            listener(techId)
        end

    end

end
