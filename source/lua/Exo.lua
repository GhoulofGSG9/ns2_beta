-- ======= Copyright (c) 2012, Unknown Worlds Entertainment, Inc. All rights reserved. ============
--
-- lua\Exo.lua
--
--    Created by:   Brian Cronin (brianc@unknownworlds.com)
--
-- ========= For more information, visit us at http://www.unknownworlds.com =====================

Script.Load("lua/Player.lua")
Script.Load("lua/Mixins/BaseMoveMixin.lua")
Script.Load("lua/Mixins/GroundMoveMixin.lua")
Script.Load("lua/Mixins/CameraHolderMixin.lua")
Script.Load("lua/Weapons/Marine/ExoWeaponHolder.lua")
Script.Load("lua/MapBlipMixin.lua")
Script.Load("lua/ScoringMixin.lua")
Script.Load("lua/LOSMixin.lua")
Script.Load("lua/WeldableMixin.lua")
Script.Load("lua/CombatMixin.lua")
Script.Load("lua/SelectableMixin.lua")
Script.Load("lua/OrdersMixin.lua")
Script.Load("lua/CorrodeMixin.lua")
Script.Load("lua/TunnelUserMixin.lua")
Script.Load("lua/NanoShieldMixin.lua")
Script.Load("lua/CatPackMixin.lua")
Script.Load("lua/ParasiteMixin.lua")
Script.Load("lua/MarineActionFinderMixin.lua")
Script.Load("lua/WebableMixin.lua")
Script.Load("lua/ExoVariantMixin.lua")
Script.Load("lua/MarineVariantMixin.lua")

local kExoFirstPersonHitEffectName = PrecacheAsset("cinematics/marine/exo/hit_view.cinematic")

class 'Exo' (Player)

kExoThrusterMode = enum({'Vertical', 'Horizontal', 'StrafeLeft', 'StrafeRight', 'DodgeBack'})

local networkVars =
{
    flashlightOn = "boolean",
    flashlightLastFrame = "private boolean",
    idleSound2DId = "private entityid",
    thrustersActive = "compensated boolean",
    lastThrusterDesired = "compensated boolean",
    timeThrustersEnded = "private compensated time",
    timeThrustersStarted = "private compensated time",
    weaponUpgradeLevel = "integer (0 to 3)",
    inventoryWeight = "float",
    thrusterMode = "enum kExoThrusterMode",
    hasDualGuns = "private boolean",
    creationTime = "private time",
    ejecting = "compensated boolean",
    timeFuelChanged = "private time",
    fuelAtChange = "private float (0 to 1 by 0.01)",
}

Exo.kMapName = "exo"

Exo.kHealthWarningsTimer = 0.5
Exo.kHealthWarningsStatDelay = 4

local kModelName = PrecacheAsset("models/marine/exosuit/exosuit_cm.model")
local kAnimationGraph = PrecacheAsset("models/marine/exosuit/exosuit_cm.animation_graph")

local kDualModelName = PrecacheAsset("models/marine/exosuit/exosuit_mm.model")
local kDualAnimationGraph = PrecacheAsset("models/marine/exosuit/exosuit_mm.animation_graph")

local kClawRailgunModelName = PrecacheAsset("models/marine/exosuit/exosuit_cr.model")
local kClawRailgunAnimationGraph = PrecacheAsset("models/marine/exosuit/exosuit_cr.animation_graph")

local kDualRailgunModelName = PrecacheAsset("models/marine/exosuit/exosuit_rr.model")
local kDualRailgunAnimationGraph = PrecacheAsset("models/marine/exosuit/exosuit_rr.animation_graph")

PrecacheAsset("shaders/ExoScreen.surface_shader")

local kIdle2D = PrecacheAsset("sound/NS2.fev/marine/heavy/idle_2D")

if Client then
    PrecacheAsset("cinematics/vfx_materials/heal_exo_view.surface_shader")
end

local kExoHealViewMaterialName = PrecacheAsset("cinematics/vfx_materials/heal_exo_view.material")

local kHealthWarning = PrecacheAsset("sound/NS2.fev/marine/heavy/warning")
local kHealthWarningTrigger = 0.55

local kHealthCritical = PrecacheAsset("sound/NS2.fev/marine/heavy/critical")
local kHealthCriticalTrigger = 0.35

local kWalkMaxSpeed = 3.7
local kMaxSpeed = 5.75
local kViewOffsetHeight = 2.3
local kAcceleration = 20

local kSmashEggRange = 1.5

local kCrouchShrinkAmount = 0
local kExtentsCrouchShrinkAmount = 0

local kThrustersCooldownTime = 2.5
local kThrusterDuration = 1.5

local kThrusterMinimumFuel = 0.99

local kDeploy2DSound = PrecacheAsset("sound/NS2.fev/marine/heavy/deploy_2D")

local kThrusterCinematic = PrecacheAsset("cinematics/marine/exo/thruster.cinematic")
local kThrusterLeftAttachpoint = "Exosuit_LFoot"
local kThrusterRightAttachpoint = "Exosuit_RFoot"

local kExoViewDamaged = PrecacheAsset("cinematics/marine/exo/hurt_view.cinematic")
local kExoViewHeavilyDamaged = PrecacheAsset("cinematics/marine/exo/hurt_severe_view.cinematic")

local kFlaresAttachpoint = "Exosuit_UpprTorso"
local kFlareCinematic = PrecacheAsset("cinematics/marine/exo/lens_flare.cinematic")

local kThrusterUpwardsAcceleration = 2
local kThrusterHorizontalAcceleration = 23
-- added to max speed when using thrusters
local kHorizontalThrusterAddSpeed = 2.5

local kExoEjectDuration = 0
local kExoDeployDuration = 1.4

local gHurtCinematic

Exo.kMass = 980

Exo.kXZExtents = 0.55
Exo.kYExtents = 1.2

AddMixinNetworkVars(BaseMoveMixin, networkVars)
AddMixinNetworkVars(GroundMoveMixin, networkVars)
AddMixinNetworkVars(CameraHolderMixin, networkVars)
AddMixinNetworkVars(LOSMixin, networkVars)
AddMixinNetworkVars(CombatMixin, networkVars)
AddMixinNetworkVars(SelectableMixin, networkVars)
AddMixinNetworkVars(OrdersMixin, networkVars)
AddMixinNetworkVars(CorrodeMixin, networkVars)
AddMixinNetworkVars(TunnelUserMixin, networkVars)
AddMixinNetworkVars(NanoShieldMixin, networkVars)
AddMixinNetworkVars(CatPackMixin, networkVars)
AddMixinNetworkVars(ParasiteMixin, networkVars)
AddMixinNetworkVars(ScoringMixin, networkVars)
AddMixinNetworkVars(WebableMixin, networkVars)
AddMixinNetworkVars(MarineVariantMixin, networkVars)
AddMixinNetworkVars(ExoVariantMixin, networkVars)

local function SmashNearbyEggs(self)

    assert(Server)


    local nearbyEggs = GetEntitiesWithinRange("Egg", self:GetOrigin(), kSmashEggRange)
    for e = 1, #nearbyEggs do
        nearbyEggs[e]:Kill(self, self, self:GetOrigin(), Vector(0, -1, 0))
    end
    
    local nearbyEmbryos = GetEntitiesWithinRange("Embryo", self:GetOrigin(), kSmashEggRange)
    for e = 1, #nearbyEmbryos do
        nearbyEmbryos[e]:Kill(self, self, self:GetOrigin(), Vector(0, -1, 0))
    end
    
    
    -- Keep on killing those nasty eggs forever.
    return true
    
end

function Exo:OnCreate()

    Player.OnCreate(self)
    
    InitMixin(self, BaseMoveMixin, { kGravity = Player.kGravity })
    InitMixin(self, GroundMoveMixin)
    InitMixin(self, LOSMixin)
    InitMixin(self, CameraHolderMixin, { kFov = kExoFov })
    InitMixin(self, ScoringMixin, { kMaxScore = kMaxScore })
    InitMixin(self, WeldableMixin)
    InitMixin(self, CombatMixin)
    InitMixin(self, SelectableMixin)
    InitMixin(self, CorrodeMixin)
    InitMixin(self, TunnelUserMixin)
    InitMixin(self, ParasiteMixin)
    InitMixin(self, MarineActionFinderMixin)
    InitMixin(self, WebableMixin)
    InitMixin(self, MarineVariantMixin)
    InitMixin(self, ExoVariantMixin)
    
    self:SetIgnoreHealth(true)
    
    if Server then
        self:AddTimedCallback(SmashNearbyEggs, 0.1)

        self.lasthealthWarningsTime = 0
        self.healthWarningSound = nil
        self.healthCriticalSound = nil
        self:AddTimedCallback(Exo.UpdateHealthSoundWarnings, Exo.kHealthWarningsTimer)
    end
    
    self.deployed = false
    
    self.flashlightOn = false
    self.flashlightLastFrame = false
    self.idleSound2DId = Entity.invalidId
    self.timeThrustersEnded = 0
    self.timeThrustersStarted = 0
    self.inventoryWeight = 0
    self.thrusterMode = kExoThrusterMode.Vertical
    self.ejecting = false
    
    self.creationTime = Shared.GetTime()
    
    if Server then
    
        self.idleSound2D = Server.CreateEntity(SoundEffect.kMapName)
        self.idleSound2D:SetAsset(kIdle2D)
        self.idleSound2D:SetParent(self)
        self.idleSound2D:Start()
        
        -- Only sync 2D sound with this Exo player.
        self.idleSound2D:SetPropagate(Entity.Propagate_PlayerOwner)

        
        self.idleSound2DId = self.idleSound2D:GetId()
        
    elseif Client then
    
        self.flashlight = Client.CreateRenderLight()
        
        self.flashlight:SetType(RenderLight.Type_Spot)
        self.flashlight:SetColor(Color(.8, .8, 1))
        self.flashlight:SetInnerCone(math.rad(30))
        self.flashlight:SetOuterCone(math.rad(45))
        self.flashlight:SetIntensity(10)
        self.flashlight:SetRadius(25)
        --TODO Apply atmospherics settings to Exo flashlight
        --self.flashlight:SetGoboTexture("models/marine/male/flashlight.dds")
        
        self.flashlight:SetIsVisible(false)
        
        self.idleSound2DId = Entity.invalidId

    end
    
end

function Exo:InitExoModel()

    local modelName = kModelName
    local graphName = kAnimationGraph
    if self.layout == "MinigunMinigun" then
    
        modelName = kDualModelName
        graphName = kDualAnimationGraph
        self.hasDualGuns = true
        
    elseif self.layout == "ClawRailgun" then
    
        modelName = kClawRailgunModelName
        graphName = kClawRailgunAnimationGraph
        
    elseif self.layout == "RailgunRailgun" then
    
        modelName = kDualRailgunModelName
        graphName = kDualRailgunAnimationGraph
        self.hasDualGuns = true
        
    end
    
    -- SetModel must be called before Player.OnInitialized is called so the attach points in
    -- the Exo are valid to attach weapons to. This is far too subtle...
    self:SetModel(modelName, graphName)

end

function Exo:OnInitialized()

    -- Only set the model on the Server, the Client
    -- will already have the correct model at this point.
    if Server then    
        self:InitExoModel()
    end
    
    InitMixin(self, OrdersMixin, { kMoveOrderCompleteDistance = kPlayerMoveOrderCompleteDistance })
    InitMixin(self, NanoShieldMixin)
    InitMixin(self, CatPackMixin)

    Player.OnInitialized(self)
    
    if Server then
    
        -- This Mixin must be inited inside this OnInitialized() function.
        if not HasMixin(self, "MapBlip") then
            InitMixin(self, MapBlipMixin)
        end
        
        self.armor = self:GetArmorAmount()
        self.maxArmor = self.armor
        
        self.thrustersActive = false
        self.healthCriticalPlaying = false
        self.healthWarningTriggered = false

    elseif Client then
    
        InitMixin(self, HiveVisionMixin)
        InitMixin(self, MarineOutlineMixin)
        
        self.clientThrustersActive = self.thrustersActive

        self.thrusterLeftCinematic = Client.CreateCinematic(RenderScene.Zone_Default)
        self.thrusterLeftCinematic:SetCinematic(kThrusterCinematic)
        self.thrusterLeftCinematic:SetRepeatStyle(Cinematic.Repeat_Endless)
        self.thrusterLeftCinematic:SetParent(self)
        self.thrusterLeftCinematic:SetCoords(Coords.GetIdentity())
        self.thrusterLeftCinematic:SetAttachPoint(self:GetAttachPointIndex(kThrusterLeftAttachpoint))
        self.thrusterLeftCinematic:SetIsVisible(false)
        
        self.thrusterRightCinematic = Client.CreateCinematic(RenderScene.Zone_Default)
        self.thrusterRightCinematic:SetCinematic(kThrusterCinematic)
        self.thrusterRightCinematic:SetRepeatStyle(Cinematic.Repeat_Endless)
        self.thrusterRightCinematic:SetParent(self)
        self.thrusterRightCinematic:SetCoords(Coords.GetIdentity())
        self.thrusterRightCinematic:SetAttachPoint(self:GetAttachPointIndex(kThrusterRightAttachpoint))
        self.thrusterRightCinematic:SetIsVisible(false)
        
        self.flares = Client.CreateCinematic(RenderScene.Zone_Default)
        self.flares:SetCinematic(kFlareCinematic)
        self.flares:SetRepeatStyle(Cinematic.Repeat_Endless)
        self.flares:SetParent(self)
        self.flares:SetCoords(Coords.GetIdentity())
        self.flares:SetAttachPoint(self:GetAttachPointIndex(kFlaresAttachpoint))
        self.flares:SetIsVisible(false)
        
        self:AddHelpWidget("GUITunnelEntranceHelp", 1)
        
    end
    
end

local function ShowHUD(self, show)

    assert(Client)
    
    if self.marineHudVisible ~= show then
        self.marineHudVisible = show
        ClientUI.SetScriptVisibility("Hud/Marine/GUIMarineHUD", "Alive", show)
    end
    
    if self.exoHudVisible ~= show then
        self.exoHudVisible = show
        ClientUI.SetScriptVisibility("Hud/Marine/GUIExoHUD", "Alive", show)
    end
    
end

-- The Exo doesn't want the model to change. Only cares about the sex of the Marine inside.
function Exo:GetIgnoreVariantModels()
    return true
end

function Exo:GetHasDualGuns()
    return self.hasDualGuns
end

function Exo:GetControllerPhysicsGroup()
    return PhysicsGroup.BigPlayerControllersGroup
end

function Exo:GetShowParasiteView()
    return false
end

function Exo:OnInitLocalClient()

    Player.OnInitLocalClient(self)
    
    ShowHUD(self, false)
    
end

function Exo:ComputeDamageAttackerOverride(attacker, damage, damageType)

    if self.hasDualGuns then

        if self:GetHasMinigun() then
            damage = damage * kExoDualMinigunModifier
        elseif self:GetHasRailgun() then
            damage = damage * kExoDualRailgunModifier
        end        

    end

    return damage
    
end

-- Returns player mass in kg
function Exo:GetMass()
    return Exo.kMass
end

function Exo:GetCrouchShrinkAmount()
    return kCrouchShrinkAmount
end

function Exo:GetExtentsCrouchShrinkAmount()
    return kExtentsCrouchShrinkAmount
end

-- exo has no crouch animations
function Exo:GetCanCrouch()
    return false
end

function Exo:InitWeapons()

    Player.InitWeapons(self)
    
    local weaponHolder = self:GetWeapon(ExoWeaponHolder.kMapName)
    
    if not weaponHolder then
        weaponHolder = self:GiveItem(ExoWeaponHolder.kMapName, false)   
    end    
    
    if self.layout == "ClawMinigun" then
        weaponHolder:SetWeapons(Claw.kMapName, Minigun.kMapName)
    elseif self.layout == "MinigunMinigun" then
        weaponHolder:SetWeapons(Minigun.kMapName, Minigun.kMapName)
    elseif self.layout == "ClawRailgun" then
        weaponHolder:SetWeapons(Claw.kMapName, Railgun.kMapName)
    elseif self.layout == "RailgunRailgun" then
        weaponHolder:SetWeapons(Railgun.kMapName, Railgun.kMapName)
    else
    
        Print("Warning: incorrect layout set for exosuit")
        weaponHolder:SetWeapons(Minigun.kMapName, Minigun.kMapName)
        
    end
    
    weaponHolder:TriggerEffects("exo_login")
    self.inventoryWeight = weaponHolder:GetInventoryWeight(self)
    self:SetActiveWeapon(ExoWeaponHolder.kMapName)
    StartSoundEffectForPlayer(kDeploy2DSound, self)
    
end

function Exo:GetMaxBackwardSpeedScalar()
    return 0.8
end   

function Exo:OnDestroy()
   
    if self.flashlight ~= nil then
        Client.DestroyRenderLight(self.flashlight)
    end
    
    if self.thrusterLeftCinematic then
    
        Client.DestroyCinematic(self.thrusterLeftCinematic)
        self.thrusterLeftCinematic = nil
    
    end
    
    if self.thrusterRightCinematic then
    
        Client.DestroyCinematic(self.thrusterRightCinematic)
        self.thrusterRightCinematic = nil
    
    end
    
    if self.flares then
    
        Client.DestroyCinematic(self.flares)
        self.flares = nil
        
    end
    
    if self.armorDisplay then
        
        Client.DestroyGUIView(self.armorDisplay)
        self.armorDisplay = nil
        
    end

    if self.healthWarningSound ~= nil then
        self.healthWarningSound = nil
    end

    if self.healthCriticalSound ~= nil then
        self.healthCriticalSound = nil
    end

    if Client then
        if gHurtCinematic then
        
            Client.DestroyCinematic(gHurtCinematic)   
            gHurtCinematic = nil
            
        end
    end 
end

function Exo:GetMaxViewOffsetHeight()
    return kViewOffsetHeight
end

function Exo:GetMaxSpeed(possible)

    if possible then
        return kWalkMaxSpeed
    end
    
    local maxSpeed = kMaxSpeed * self:GetInventorySpeedScalar()
    
    if self:GetHasCatPackBoost() then
        maxSpeed = maxSpeed + kCatPackMoveAddSpeed
    end
    
    return maxSpeed
    
end

--McG: All of these type functions should be rolled into a overall lookup. Mixin with rules table?
function Exo:GetIsDualWeapon()
    
    local weaponHolder = self:GetWeapon(ExoWeaponHolder.kMapName)
    return weaponHolder ~= nil and not weaponHolder:GetLeftSlotWeapon():isa("Claw")
    
end

function Exo:GetHasRailgun()

    local weaponHolder = self:GetWeapon(ExoWeaponHolder.kMapName)
    return weaponHolder ~= nil and (weaponHolder:GetLeftSlotWeapon():isa("Railgun") or weaponHolder:GetRightSlotWeapon():isa("Railgun"))
    
end

function Exo:GetHasMinigun()

    local weaponHolder = self:GetWeapon(ExoWeaponHolder.kMapName)
    return weaponHolder ~= nil and (weaponHolder:GetLeftSlotWeapon():isa("Minigun") or weaponHolder:GetRightSlotWeapon():isa("Minigun"))

end

function Exo:GetHeadAttachpointName()
    return "Exosuit_HoodHinge"
end

function Exo:GetArmorAmount(armorLevels)

    if not armorLevels then
    
        armorLevels = 0
    
        if GetHasTech(self, kTechId.Armor3, true) then
            armorLevels = 3
        elseif GetHasTech(self, kTechId.Armor2, true) then
            armorLevels = 2
        elseif GetHasTech(self, kTechId.Armor1, true) then
            armorLevels = 1
        end
    
    end
    
    return kExosuitArmor + armorLevels * kExosuitArmorPerUpgradeLevel
    
end

function Exo:GetFirstPersonHitEffectName()
    return kExoFirstPersonHitEffectName
end 

function Exo:GetCanRepairOverride(target)
    return false
end

function Exo:GetReceivesBiologicalDamage()
    return false
end

function Exo:GetReceivesVaporousDamage()
    return false
end

function Exo:GetCanBeWeldedOverride()
    return self:GetArmor() < self:GetMaxArmor(), false
end

function Exo:GetWeldPercentageOverride()
    return self:GetArmor() / self:GetMaxArmor()
end

function Exo:UpdateHealthSoundWarnings( deltaTime )

    self.lasthealthWarningsTime = self.lasthealthWarningsTime + deltaTime

    --Give time for Login sound to finish playing
    if self.lasthealthWarningsTime < Exo.kHealthWarningsStatDelay then
        return true
    end

    local healthPercent = self:GetArmorScalar()

    if healthPercent > kHealthCriticalTrigger and self.healthCriticalPlaying then
        if self.healthCriticalSound ~= nil then --FIXME Prevent sound from being cut-off, let it finish before stopping
            self.healthCriticalSound:Stop()
        end
        self.healthCriticalPlaying = false
    end

    if healthPercent > kHealthWarningTrigger and self.healthWarningTriggered then
        self.healthWarningTriggered = false
    end
    
    local playWarning =
        healthPercent <= kHealthWarningTrigger and
        healthPercent > kHealthCriticalTrigger and
        not self.healthWarningTriggered and
        not self.healthCriticalPlaying

    local playCritical =
        healthPercent <= kHealthCriticalTrigger and
        not self.healthCriticalPlaying

    if playWarning and not playCritical then
        self.healthWarningSound = StartSoundEffectForPlayer(kHealthWarning, self)
        self.healthWarningTriggered = true
    end

    if playCritical then
        --if self.healthWarningSound ~= nil then --FIXME this keeps being nil and SoundEffect destroys itself when not looped
        --    self.healthWarningSound:Stop()
        --end
        
        self.healthCriticalSound = StartSoundEffectForPlayer(kHealthCritical, self)
        self.healthCriticalPlaying = true
    end
    
    return true
end

local kEngageOffset = Vector(0, 1.5, 0)
function Exo:GetEngagementPointOverride()
    return self:GetOrigin() + kEngageOffset
end

function Exo:GetHealthbarOffset()
    return 1.8
end

--[[
$McG: This isn't required now since update warnings was changed
function Exo:OnWeldOverride(doer, elapsedTime)

    Player.OnWeldOverride(self, doer, elapsedTime)
    
    if Server then
        UpdateHealthSoundWarnings(self)
    end
    
end
--]]

function Exo:GetPlayerStatusDesc()
    return self:GetIsAlive() and kPlayerStatus.Exo or kPlayerStatus.Dead
end

function Exo:GetInventorySpeedScalar(player)
    return 1 - self.inventoryWeight
end

--[[
Removed with Sweets sound update
local function UpdateIdle2DSound(self, yaw, pitch, dt)

    if self.idleSound2DId ~= Entity.invalidId then
    
        local idleSound2D = Shared.GetEntity(self.idleSound2DId)
        
        self.lastExoYaw = self.lastExoYaw or yaw
        self.lastExoPitch = self.lastExoPitch or pitch
        
        local yawDiff = math.abs(GetAnglesDifference(yaw, self.lastExoYaw))
        local pitchDiff = math.abs(GetAnglesDifference(pitch, self.lastExoPitch))
        
        self.lastExoYaw = yaw
        self.lastExoPitch = pitch
        
        local rotateSpeed = math.min(1, ((yawDiff ^ 2) + (pitchDiff ^ 2)) / 0.05)
        idleSound2D:SetParameter("rotate", rotateSpeed, 1)
        
    end
    
end
--]]

local function UpdateThrusterEffects(self)

    if self.clientThrustersActive ~= self.thrustersActive then
    
        self.clientThrustersActive = self.thrustersActive

        if self.thrustersActive then            
        
            local effectParams = {}
            effectParams[kEffectParamVolume] = 0.1
        
            self:TriggerEffects("exo_thruster_start", effectParams)         
        else
            self:TriggerEffects("exo_thruster_end")            
        end
    
    end
    
    local showEffect = ( not self:GetIsLocalPlayer() or self:GetIsThirdPerson() ) and self.thrustersActive
    self.thrusterLeftCinematic:SetIsVisible(showEffect)
    self.thrusterRightCinematic:SetIsVisible(showEffect)

end

function Exo:OnProcessMove(input)

    Player.OnProcessMove(self, input)

    if Client and not Shared.GetIsRunningPrediction() then
        --UpdateIdle2DSound(self, input.yaw, input.pitch, input.time)
        UpdateThrusterEffects(self)
    end
    
    local flashlightPressed = bit.band(input.commands, Move.ToggleFlashlight) ~= 0
    if not self.flashlightLastFrame and flashlightPressed then
    
        self:SetFlashlightOn(not self:GetFlashlightOn())
        StartSoundEffectOnEntity(Marine.kFlashlightSoundName, self, 1, self)
        
    end
    self.flashlightLastFrame = flashlightPressed
    
end

function Exo:SetFlashlightOn(state)
    self.flashlightOn = state
end

function Exo:GetFlashlightOn()
    return self.flashlightOn
end

function Exo:GetCanEject()
    return self:GetIsPlaying() and not self.ejecting and self:GetIsOnGround() and not self:GetIsOnEntity() 
        and self.creationTime + kExoDeployDuration < Shared.GetTime()
        and #GetEntitiesForTeamWithinRange("CommandStation", self:GetTeamNumber(), self:GetOrigin(), 4) == 0
end

function Exo:GetIsEjecting()
    return self.ejecting
end

function Exo:EjectExo()

    if self:GetCanEject() then
    
        self.ejecting = true
        self:TriggerEffects("eject_exo_begin")
        
        if Server then
            self:AddTimedCallback(Exo.PerformEject, kExoEjectDuration)
        end
    
    end

end


if Server then

    function Exo:PerformEject()
    
        if self:GetIsAlive() then
        
            -- pickupable version
            local exosuit = CreateEntity(Exosuit.kMapName, self:GetOrigin(), self:GetTeamNumber())
            exosuit:SetLayout(self.layout)
            exosuit:SetCoords(self:GetCoords())
            exosuit:SetMaxArmor(self:GetMaxArmor())
            exosuit:SetArmor(self:GetArmor())
            exosuit:SetExoVariant(self:GetExoVariant())
            exosuit:SetFlashlightOn(self:GetFlashlightOn())
            exosuit:TransferParasite(self)
            
            local reuseWeapons = self.storedWeaponsIds ~= nil
        
            local marine = self:Replace(self.prevPlayerMapName or Marine.kMapName, self:GetTeamNumber(), false, self:GetOrigin() + Vector(0, 0.2, 0), { preventWeapons = reuseWeapons })
            marine:SetHealth(self.prevPlayerHealth or kMarineHealth)
            marine:SetMaxArmor(self.prevPlayerMaxArmor or kMarineArmor)
            marine:SetArmor(self.prevPlayerArmor or kMarineArmor)
            
            exosuit:SetOwner(marine)
            
            marine.onGround = false
            local initialVelocity = self:GetViewCoords().zAxis
            initialVelocity:Scale(4)
            initialVelocity.y = math.max(0,initialVelocity.y) + 9
            marine:SetVelocity(initialVelocity)
            
            if reuseWeapons then
         
                for _, weaponId in ipairs(self.storedWeaponsIds) do
                
                    local weapon = Shared.GetEntity(weaponId)
                    if weapon then
                        marine:AddWeapon(weapon)
                    end
                    
                end
            
            end
            
            marine:SetHUDSlotActive(1)
            
            if marine:isa("JetpackMarine") then
                marine:SetFuel(0.25)
            end
        
        end
    
        return false
    
    end

    function Exo:StoreWeapon(weapon)

        if not self.storedWeaponsIds then
            self.storedWeaponsIds = {}
        end
        weapon:SetWeaponWorldState(false)
        table.insert(self.storedWeaponsIds, weapon:GetId())
        
    end

    function Exo:OnEntityChange(oldId, newId)
    
        Player.OnEntityChange(self, oldId, newId)

        if oldId == self.idleSound2DId then
            self.idleSound2DId = Entity.invalidId
        end
        
        if oldId and self.storedWeaponsIds and table.removevalue(self.storedWeaponsIds, oldId) and newId then
            table.insert(self.storedWeaponsIds, newId)
        end

    end

    function Exo:OnHealed()
        if self:GetArmorScalar() > kHealthWarningTrigger then
            self.healthWarningTriggered = false
            Print("Exo:OnHealed() - self.healthWarningTriggered = false")
        end
    end
    
    --function Exo:OnTakeDamage(damage, attacker, doer, point, direction, damageType)
    --    UpdateHealthSoundWarnings(self)
    --end
    
    function Exo:OnKill(attacker, doer, point, direction)
        
        self.lastExoLayout = { layout = self.layout }

        Player.OnKill(self, attacker, doer, point, direction)
        
        local activeWeapon = self:GetActiveWeapon()
        if activeWeapon and activeWeapon.OnParentKilled then
            activeWeapon:OnParentKilled(attacker, doer, point, direction)
        end
    
        self:TriggerEffects("death", { classname = self:GetClassName(), effecthostcoords = Coords.GetTranslation(self:GetOrigin()) })
        
        if self.storedWeaponsIds then
            
            -- MUST iterate backwards, as "DestroyEntity()" causes the ids to be removed as they're hit.
            for i=#self.storedWeaponsIds, 1, -1 do
                local weaponId = self.storedWeaponsIds[i]
                local weapon = Shared.GetEntity(weaponId)
                if weapon then
                    -- save unused grenades
                    if weapon:isa("GrenadeThrower") and weapon.grenadesLeft > 0 then
                        self.grenadesLeft = weapon.grenadesLeft
                        self.grenadeType = weapon.kMapName
                    end
                    
                    DestroyEntity(weapon)
                end
                
            end
        
        end
        
    end
    
end

if Client then
    
    -- The Exo overrides the default trigger for footsteps.
    -- They are triggered by the view model for the local player but
    -- still uses the default behavior for other players viewing the Exo.
    function Exo:TriggerFootstep()
    
        if self ~= Client.GetLocalPlayer() then
            Player.TriggerFootstep(self)
        end
        
    end
    
    function Exo:UpdateClientEffects(deltaTime, isLocal)
    
        Player.UpdateClientEffects(self, deltaTime, isLocal)
        
        if isLocal then
        
            local visible = self.deployed and self:GetIsAlive() and not self:GetIsThirdPerson()
            ShowHUD(self, visible)
            
        end
        
        if self.buyMenu then
        
            if not self:GetIsAlive() or not GetIsCloseToMenuStructure(self) then
                self:CloseMenu()
            end
            
        end 
        
    end
    
    function Exo:OnUpdateRender()
    
        PROFILE("Exo:OnUpdateRender")
        
        Player.OnUpdateRender(self)
        
        local localPlayer = Client.GetLocalPlayer()
        local showHighlight = localPlayer ~= nil and localPlayer:isa("Alien") and self:GetIsAlive()
        
        --[[ disabled for now
        local model = self:GetRenderModel()
        
        if model then
        
            if showHighlight and not self.marineHighlightMaterial then
                
                self.marineHighlightMaterial = AddMaterial(model, "cinematics/vfx_materials/marine_highlight.material")
                
            elseif not showHighlight and self.marineHighlightMaterial then
            
                RemoveMaterial(model, self.marineHighlightMaterial)
                self.marineHighlightMaterial = nil
            
            end
            
            if self.marineHighlightMaterial then
                self.marineHighlightMaterial:SetParameter("distance", (localPlayer:GetEyePos() - self:GetOrigin()):GetLength())
            end
        
        end
        --]]
        
        local isLocal = self:GetIsLocalPlayer()
        local flashLightVisible = self.flashlightOn and (isLocal or self:GetIsVisible()) and self:GetIsAlive()
        local flaresVisible = flashLightVisible and (not isLocal or self:GetIsThirdPerson())
        
        -- Synchronize the state of the light representing the flash light.
        self.flashlight:SetIsVisible(flashLightVisible)
        self.flares:SetIsVisible(flaresVisible)
        
        if self.flashlightOn then
        
            local coords = Coords(self:GetViewCoords())
            coords.origin = coords.origin + coords.zAxis * 0.75
            
            self.flashlight:SetCoords(coords)
            
            -- Only display atmospherics for third person players.
            local density = 0.025
            if isLocal and not self:GetIsThirdPerson() then
                density = 0
            end
            self.flashlight:SetAtmosphericDensity(density)
            
        end
        
        if self:GetIsLocalPlayer() then
        
            local armorDisplay = self.armorDisplay
            if not armorDisplay then

                armorDisplay = Client.CreateGUIView(256, 256, true)
                armorDisplay:Load("lua/GUIExoArmorDisplay.lua")
                armorDisplay:SetTargetTexture("*exo_armor")
                self.armorDisplay = armorDisplay

            end
            
            local armorAmount = self:GetIsAlive() and math.ceil(math.max(1, self:GetArmor())) or 0
            armorDisplay:SetGlobal("armorAmount", armorAmount)
            armorDisplay:SetGlobal("isParasited", self:GetIsParasited() and 1 or 0)
            
            if not self.timeLastDamagedEffect or self.timeLastDamagedEffect + 2 < Shared.GetTime() then
            
                local healthScalar = self:GetHealthScalar()
                
                if healthScalar < kHealthWarningTrigger then
                
                    gHurtCinematic = Client.CreateCinematic(RenderScene.Zone_ViewModel)
                    local cinematicName = kExoViewDamaged
                    
                    if healthScalar < kHealthCriticalTrigger then
                        cinematicName = kExoViewHeavilyDamaged
                    end
                    
                    gHurtCinematic:SetCinematic(cinematicName)
                
                end
                
                self.timeLastDamagedEffect = Shared.GetTime()
                
            end
            
        elseif self.armorDisplay then
        
            Client.DestroyGUIView(self.armorDisplay)
            self.armorDisplay = nil
            
        end
        
    end
    
end

function Exo:GetCanClimb()
    return false
end

function Exo:GetDeathMapName()
    return MarineSpectator.kMapName
end

function Exo:GetDeathIconIndex()
    return kDeathMessageIcon.Crush    
end

function Exo:OnTag(tagName)

    PROFILE("Exo:OnTag")

    Player.OnTag(self, tagName)
    
    if tagName == "deploy_end" then
        self.deployed = true
    end
    
end

-- jumping is handled in a different way for exos
function Exo:GetCanJump()
    return false
end

function Exo:HandleButtons(input)

    if self.ejecting or self.creationTime + kExoDeployDuration > Shared.GetTime() then

        input.commands = bit.band(input.commands, bit.bnot(bit.bor(Move.Use, Move.Buy, Move.Jump,
                                                                   Move.PrimaryAttack, Move.SecondaryAttack,
                                                                   Move.SelectNextWeapon, Move.SelectPrevWeapon, Move.Reload,
                                                                   Move.Taunt, Move.Weapon1, Move.Weapon2,
                                                                   Move.Weapon3, Move.Weapon4, Move.Weapon5, Move.Crouch, Move.MovementModifier)))
                                                                   
        input.move:Scale(0)
    
    end

    Player.HandleButtons(self, input)
    
    self:UpdateThrusters(input)

    if bit.band(input.commands, Move.Drop) ~= 0 then
       self:EjectExo()
    end
    
end

Exo.thurstStartTime = 0.5
function Exo:HandleThrusterStart(thrusterMode)

    if thrusterMode == kExoThrusterMode.Vertical
            and self:GetIsOnGround() then --deny bunny hopping
        self:DisableGroundMove(self.thurstStartTime)
    end
    
    self:SetFuel( self:GetFuel() )
    
    self.thrustersActive = true 
    self.timeThrustersStarted = Shared.GetTime()
    self.thrusterMode = thrusterMode
    

end

function Exo:HandleThrusterEnd()

    self:SetFuel( self:GetFuel() )
    
    self.thrustersActive = false
    self.timeThrustersEnded = Shared.GetTime()
    
end

function Exo:GetIsThrusterAllowed()

    local allowed = true
    
    for i = 0, self:GetNumChildren() - 1 do
    
        local child = self:GetChildAtIndex(i)
        if child.GetIsThrusterAllowed and not child:GetIsThrusterAllowed() then
            allowed = false
            break
        end
    
    end
    
    return allowed

end

function Exo:UpdateThrusters(input)

    local lastThrustersActive = self.thrustersActive
    local jumpPressed = bit.band(input.commands, Move.Jump) ~= 0
    local movementSpecialPressed = bit.band(input.commands, Move.MovementModifier) ~= 0
    local thrusterDesired = (jumpPressed or movementSpecialPressed) and self:GetIsThrusterAllowed()
    
    if thrusterDesired ~= lastThrustersActive then
    
        if thrusterDesired and not self.lastThrusterDesired then
                
            local desiredMode = 
                jumpPressed and kExoThrusterMode.Vertical 
                or input.move.x < 0 and kExoThrusterMode.StrafeLeft 
                or input.move.x > 0 and kExoThrusterMode.StrafeRight
                or input.move.z < 0 and kExoThrusterMode.DodgeBack 
                or input.move.z > 0 and kExoThrusterMode.Horizontal
                or nil
                
            if desiredMode and self:GetFuel() >= kThrusterMinimumFuel then
                self:HandleThrusterStart(desiredMode)
                self.lastThrusterDesired = true
            end

        else
            self:HandleThrusterEnd()
        end
        
    end
    
    if not thrusterDesired then
        self.lastThrusterDesired = false
    end
    
    if self.thrustersActive and self:GetFuel() == 0 then
        self:HandleThrusterEnd()
    end

end

function Exo:GetGroundFriction()
    return self.thrustersActive and 2 or 8
end

local kUpVector = Vector(0, 1, 0)
function Exo:ModifyVelocity(input, velocity, deltaTime)

    if self.thrustersActive then
    
        if self.thrusterMode == kExoThrusterMode.Vertical then   
        
            velocity:Add(kUpVector * kThrusterUpwardsAcceleration * deltaTime)
            velocity.y = math.min(1.5, velocity.y)
            
        else
        
            input.move.y = 0
        
            local maxSpeed,wishDir
            
            maxSpeed = self:GetMaxSpeed() + kHorizontalThrusterAddSpeed
            
            if self.thrusterMode == kExoThrusterMode.StrafeLeft then
                input.move.x = -1
            elseif self.thrusterMode == kExoThrusterMode.StrafeRight then
                input.move.x = 1
            elseif self.thrusterMode == kExoThrusterMode.DodgeBack then
                -- strafe buttons should have less effect when going forwards/backwards, should be more based on your look direction
                input.move.z = -2
            else
                -- strafe buttons should have less effect when going forwards/backwards, should be more based on your look direction
                input.move.z = 2 
            end
            
            wishDir = self:GetViewCoords():TransformVector( input.move )
            wishDir.y = 0
            wishDir:Normalize()
            
            wishDir = wishDir * maxSpeed
            
            -- force should help correct velocity towards wishDir, this makes turning more responsive
            local forceDir = wishDir - velocity
            local forceLength = forceDir:GetLengthXZ()
            forceDir:Normalize()
            
            local accelSpeed = kThrusterHorizontalAcceleration * deltaTime               
            accelSpeed = math.min(forceLength, accelSpeed)
            velocity:Add(forceDir * accelSpeed)
            
        
        end
        
    end
    
end

function Exo:ModifyGravityForce(gravityTable)

    if self:GetIsOnGround() or ( self.thrustersActive and self.thrusterMode == kExoThrusterMode.Vertical ) then
        gravityTable.gravity = 0
    end

end

function Exo:GetArmorUseFractionOverride()
    return 1.0
end

if Client then

    function Exo:OnUpdate(deltaTime)

        Player.OnUpdate(self, deltaTime)
        UpdateThrusterEffects(self)

    end

end

local kMinigunDisruptTimeout = 5

function Exo:Disrupt()

    if not self.timeLastExoDisrupt then
        self.timeLastExoDisrupt = Shared.GetTime() - kMinigunDisruptTimeout
    end
    
    if self.timeLastExoDisrupt + kMinigunDisruptTimeout <= Shared.GetTime() then

        local weaponHolder = self:GetActiveWeapon()    
        local leftWeapon = weaponHolder:GetLeftSlotWeapon()
        local rightWeapon = weaponHolder:GetRightSlotWeapon()
        
        if leftWeapon:isa("Minigun") then
        
            leftWeapon.overheated = true
            self:TriggerEffects("minigun_overheated_left")
            leftWeapon:OnPrimaryAttackEnd(self)
            
        end
        
        if rightWeapon:isa("Minigun") then
        
            rightWeapon.overheated = true
            self:TriggerEffects("minigun_overheated_left")
            rightWeapon:OnPrimaryAttackEnd(self)
        
        end
        
        StartSoundEffectForPlayer("sound/NS2.fev/marine/heavy/overheated", self)
        
        self.timeLastExoDisrupt = Shared.GetTime()
    
    end
    
end

if Server then

    local function GetCanTriggerAlert(self, techId, timeOut)

        if not self.alertTimes then
            self.alertTimes = {}
        end
        
        return not self.alertTimes[techId] or self.alertTimes[techId] + timeOut < Shared.GetTime()

    end
    
    function Exo:OnOverrideOrder(order)
        
        local orderTarget

        if order:GetParam() ~= nil then
            orderTarget = Shared.GetEntity(order:GetParam())
        end
        
        -- exos can only attack or move
        if orderTarget ~= nil and HasMixin(orderTarget, "Live") and GetEnemyTeamNumber(self:GetTeamNumber()) == orderTarget:GetTeamNumber() and orderTarget:GetIsAlive() and (not HasMixin(orderTarget, "LOS") or orderTarget:GetIsSighted()) then
            order:SetType(kTechId.Attack)
        else
            order:SetType(kTechId.Move)
        end
        
    end

end

function Exo:GetAirControl()
    return 5
end

function Exo:GetAnimateDeathCamera()
    return false
end

function Exo:OverrideHealViewMateral()
    return kExoHealViewMaterialName
end

function  Exo:GetShowDamageArrows()
    return true
end    

function Exo:SetFuel(fuel)
   self.timeFuelChanged = Shared.GetTime()
   self.fuelAtChange = fuel
end

-- for jetpack fuel display
function Exo:GetFuel()
    if self.thrustersActive then
        return Clamp(self.fuelAtChange - (Shared.GetTime() - self.timeFuelChanged) / kThrusterDuration, 0, 1)
    else
        return Clamp(self.fuelAtChange + (Shared.GetTime() - self.timeFuelChanged) / kThrustersCooldownTime, 0, 1)
    end
end

function Exo:OnUpdateAnimationInput(modelMixin)

    PROFILE("Exo:OnUpdateAnimationInput")
    
    Player.OnUpdateAnimationInput(self, modelMixin)
    
    if self.thrustersActive then    
        modelMixin:SetAnimationInput("move", "jump")
    end
    
end

if Server then

    local function OnCommandDisruptExo(client)

        local player = client:GetControllingPlayer()
        if player and player:isa("Exo") and Shared.GetCheatsEnabled() then
            player:Disrupt()
        end

    end

    Event.Hook("Console_disruptexo", OnCommandDisruptExo)
    
    function Exo:CopyPlayerDataFrom(player)
    
        Player.CopyPlayerDataFrom(self, player)
    
        if player:isa("Marine") then
            
            self.prevPlayerMapName = player:GetMapName()
            self.prevPlayerHealth = player:GetHealth()
            self.prevPlayerMaxArmor = player:GetMaxArmor()
            self.prevPlayerArmor = player:GetArmor()
            self.prevParasited = player.parasited
            self.prevParasitedTime = player.timeParasited
            
            self.grenadesLeft = player.grenadesLeft
            self.grenadeType = player.grenadeType
        
        elseif player:isa("Exo") then
            
            self.prevPlayerMapName =  player.prevPlayerMapName
            self.prevPlayerHealth = player.prevPlayerHealth
            self.prevPlayerMaxArmor = player.prevPlayerMaxArmor
            self.prevPlayerArmor = player.prevPlayerArmor
            self.prevParasited = player.prevParasited
            self.prevParasitedTime = player.prevParasitedTime
            
            if player.storedWeaponsIds then
                self.storedWeaponsIds = player.storedWeaponsIds
            end
            
        end
    end
    
    function Exo:AttemptToBuy(techIds)

        local techId = techIds[1]
        local success = false
        
        if not self:GetHasDualGuns() then
            
            local newExo

            if techId == kTechId.UpgradeToDualMinigun and self:GetHasMinigun() then

                newExo = self:Replace(Exo.kMapName, self:GetTeamNumber(), false, self:GetOrigin(), { layout = "MinigunMinigun" })
                success = true
            
            elseif techId == kTechId.UpgradeToDualRailgun and self:GetHasRailgun() then
            
                newExo = self:Replace(Exo.kMapName, self:GetTeamNumber(), false, self:GetOrigin(), { layout = "RailgunRailgun" })
                success = true
            
            end
            
            if success and newExo then
            
                newExo:SetMaxArmor(self:GetMaxArmor())
                newExo:SetArmor(self:GetArmor())
                newExo:AddResources(-GetCostForTech(techId))
                
                newExo:TriggerEffects("spawn_exo")
            
            end
        
        end
        
        return success
        
    end 
     
elseif Client then

    function Exo:UpdateMisc(input)

        Player.UpdateMisc(self, input)
        
        if not Shared.GetIsRunningPrediction() then

            if input.move.x ~= 0 or input.move.z ~= 0 then

                self:CloseMenu()
                
            end
            
        end
        
    end

    -- Bring up buy menu
    function Exo:BuyMenu(structure)
        
        -- Don't allow display in the ready room
        if self:GetTeamNumber() ~= 0 and Client.GetLocalPlayer() == self then
        
            if not self.buyMenu and not HelpScreen_GetHelpScreen():GetIsBeingDisplayed() then
            
                self.buyMenu = GetGUIManager():CreateGUIScript("GUIMarineBuyMenu")
                
                MarineUI_SetHostStructure(structure)
                
                if structure then
                    self.buyMenu:SetHostStructure(structure)
                end
                
                self:TriggerEffects("marine_buy_menu_open")

            end
            
        end
        
    end

end

function Exo:GetWebSlowdownScalar()
    return 0.6
end

-- move camera down while ejecting
local kExoEjectionMove = 1
function Exo:PlayerCameraCoordsAdjustment(cameraCoords)

    if self:GetIsAlive() then

        if self.ejecting and self.clientExoEjecting ~= self.ejecting then
            self.timeEjectStarted = Shared.GetTime()
            self.clientExoEjecting = self.ejecting
        end
        
        if Shared.GetTime() - self.creationTime < kExoDeployDuration then
        
            self.animStartTime = self.creationTime
            self.animDirection = 1
            self.animDuration = kExoDeployDuration
            
        end    

        if self.timeEjectStarted then
        
            self.animStartTime = self.timeEjectStarted
            self.animDirection = -1
        
        end
        
        if self.animStartTime then

            local animTime = Clamp(Shared.GetTime() - self.animStartTime, 0, self.animDuration)
            local animFraction = Easing.inOutBounce(animTime, 0.0, 1.0, self.animDuration)
            
            if self.animDirection == -1 then        
                cameraCoords.origin.y = cameraCoords.origin.y - kExoEjectionMove * animFraction
            elseif self.animDirection == 1 then
                cameraCoords.origin.y = cameraCoords.origin.y - kExoEjectionMove + kExoEjectionMove * animFraction
            end    
        
        end
    
    end
    
    return cameraCoords

end

Shared.LinkClassToMap("Exo", Exo.kMapName, networkVars, true)
