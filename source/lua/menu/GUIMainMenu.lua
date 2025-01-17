-- ======= Copyright (c) 2003-2014, Unknown Worlds Entertainment, Inc. All rights reserved. =====
--
-- lua\menu\GUIMainMenu.lua
--
--    Created by:   Andreas Urwalek (andi@unknownworld.com) and
--                  Brian Cronin (brianc@unknownworlds.com)
--
-- ========= For more information, visit us at http://www.unknownworlds.com =====================
 
Script.Load("lua/menu/WindowManager.lua")
Script.Load("lua/GUIAnimatedScript.lua")
Script.Load("lua/menu/MenuMixin.lua")
Script.Load("lua/menu/BigLink.lua")
Script.Load("lua/menu/Link.lua")
Script.Load("lua/menu/SlideBar.lua")
Script.Load("lua/menu/ProgressBar.lua")
Script.Load("lua/menu/ContentBox.lua")
Script.Load("lua/menu/Image.lua")
Script.Load("lua/menu/Table.lua")
Script.Load("lua/ServerBrowser.lua")
Script.Load("lua/menu/Form.lua")
Script.Load("lua/menu/ServerList.lua")
Script.Load("lua/menu/ServerTabs.lua")
Script.Load("lua/menu/PlayerEntry.lua")
Script.Load("lua/dkjson.lua")
Script.Load("lua/menu/MenuPoses.lua")
Script.Load("lua/HitSounds.lua")
Script.Load("lua/menu/GUIMainMenu_WelcomeProgress.lua")
Script.Load("lua/menu/GUIMainMenuNews.lua")
Script.Load("lua/menu/GUIMainMenu_NewItemInfo.lua")
Script.Load("lua/menu/GUIMainMenu_Alert.lua")
Script.Load("lua/menu/GUIMainMenu_NewGameModeInfo.lua")
Script.Load("lua/menu/GUIMainMenu_Changelog.lua")
Script.Load("lua/PlayerRanking.lua")

local kMainMenuLinkColor = Color(137 / 255, 137 / 255, 137 / 255, 1)
local kMainMenuLinkTextGlowColor = Color(147/255, 229/255, 255/255, 1.0)
local kMainMenuLinkAlertTextColor = Color(255/255, 212/255, 143/255, 1.0)
local kLinkGlowTexture = PrecacheAsset("ui/menu/link_background_glow.dds")

class 'GUIMainMenu' (GUIAnimatedScript)

Script.Load("lua/menu/GUIMainMenu_PlayNow.lua")
Script.Load("lua/menu/GUIMainMenu_Mods.lua")
Script.Load("lua/menu/GUIMainMenu_Training.lua")
Script.Load("lua/menu/GUIMainMenu_Web.lua")
Script.Load("lua/Badges_Client.lua")
Script.Load("lua/menu/GUIMainMenu_Customize.lua")

-- Min and maximum values for the mouse sensitivity slider
local kMinSensitivity = 0.01
local kMaxSensitivity = 20

local kMinAcceleration = 1
local kMaxAcceleration = 1.4

local kWindowModeIds         = { "windowed", "fullscreen", "fullscreen-windowed" }
local kWindowModeNames       = { "WINDOWED", "FULLSCREEN", "FULLSCREEN WINDOWED" }

local kAmbientOcclusionModes = { "off", "medium", "high" }
local kInfestationModes      = { "minimal", "rich" }
local kParticleQualityModes  = { "low", "high" }
local kRefractionQualityModes = { "high", "low" }
local kRenderDevices         = Client.GetRenderDeviceNames()
local kRenderDeviceDisplayNames = {}

local menuBackgroundList = {}
local menuMusicList = {}

for i = 1, #kRenderDevices do
    local name = kRenderDevices[i]
    if name == "D3D11" or name == "OpenGL" then
        name = name .. " (Beta)"
    end
    kRenderDeviceDisplayNames[i] = name
end
    
local kLocales =
    {
        { name = "enUS", label = "English" },
        { name = "bgBG", label = "Bulgarian" },
        { name = "hrHR", label = "Croatian"},
        { name = "zhCN", label = "Chinese (Simplified)" },
        { name = "zhTW", label = "Chinese (Traditional)" },
        { name = "csCS", label = "Czech" },
        { name = "daDK", label = "Danish"},
        { name = "nlNL", label = "Dutch"},
        { name = "fiFI", label = "Finnish"},
        { name = "frFR", label = "French" },       
        { name = "deDE", label = "German" },
        { name = "itIT", label = "Italian" },
        { name = "jaJA", label = "Japanese" },
        { name = "koKR", label = "Korean" },
        { name = "noNO", label = "Norwegian" },
        { name = "plPL", label = "Polish" },
        { name = "ptBR", label = "Portuguese" },
        { name = "roRO", label = "Romanian" },
        { name = "ruRU", label = "Russian" },
        { name = "rsRS", label = "Serbian" },
        { name = "esES", label = "Spanish" },
        { name = "swSW", label = "Swedish" },
    }

local gMainMenu
function GetGUIMainMenu()

    return gMainMenu
    
end

function GUIMainMenu:TriggerOpenAnimation(window)
    
    if not window:GetIsVisible() then
        
        self.windowToOpen = window
        self:SetShowWindowName(window:GetWindowName())
        
    end
    
    MainMenu_OnPlayButtonClicked()
    
end

function GUIMainMenu:Initialize()
    
    GUIAnimatedScript.Initialize(self, 0)

    Shared.Message("Main Menu Initialized at Version: " .. Shared.GetBuildNumber())
    Shared.Message("Steam Id: " .. Client.GetSteamId())
    
    gDebugTrainingHighlight = Client.GetOptionBoolean("debug_training_glow", false)
    
    -- ensure this is initialized...
    self.numServers = 0
    
    --provides a set of functions required for window handling
    AddMenuMixin(self)
    self:SetCursor("ui/Cursor_MenuDefault.dds")
    self:SetWindowLayer(kWindowLayerMainMenu)
    
    LoadCSSFile("lua/menu/main_menu.css")
    
    self.mainWindow = self:CreateWindow()
    self.mainWindow:SetCSSClass("main_frame")
    
    self.tvGlareImage = CreateMenuElement(self.mainWindow, "Image")

    if MainMenu_IsInGame() then
        self.tvGlareImage:SetCSSClass("tvglare_dark")
        self.tvGlareImage:SetIsVisible(false)
    else
        self.tvGlareImage:SetCSSClass("tvglare")
    end    
    
    self.mainWindow:DisableTitleBar()
    self.mainWindow:DisableResizeTile()
    self.mainWindow:DisableCanSetActive()
    self.mainWindow:DisableContentBox()
    self.mainWindow:DisableSlideBar()
    
    self.showWindowAnimation = CreateMenuElement(self.mainWindow, "Font", false)
    self.showWindowAnimation:SetCSSClass("showwindow_hidden")
    
    if not MainMenu_IsInGame() then
        self.newsScript =  CreateMenuElement(self.mainWindow, "GUIMainMenuNews")
    end
    
    self.optionTooltip = GetGUIManager():CreateGUIScriptSingle("menu/GUIHoverTooltip")
    
    self.openedWindows = 0
    self.numMods = 0
    
    menuBackgroundList = MainMenu_GetMenuBackgrounds()
    menuMusicList = MainMenu_GetMusicList()
    
    local eventCallbacks =
    {
        OnEscape = function (self)
        
            if MainMenu_IsInGame() then
                self.scriptHandle:SetIsVisible(false)
            end

            return true
            
        end,
        
        OnShow = function (self)
            MainMenu_Open()
        end,
        
        OnHide = function (self)
            
            if MainMenu_IsInGame() then
            
                MainMenu_ReturnToGame()
                ClientUI.EvaluateUIVisibility(Client.GetLocalPlayer())
                
                --Clear active element which caused mouse wheel to not register events
                GetWindowManager():SetElementInactive()
                
                return true
                
            else
                return false
            end
            
        end
    }
    
    self.mainWindow:AddEventCallbacks(eventCallbacks)

    -- To prevent load delays, we create most windows lazily.
    -- But these are fast enough to just do immediately.
    self:CreatePasswordPromptWindow()
    self:CreateAutoJoinWindow()
    self:CreateServerNetworkModdedAlertWindow()
    self:CreateRookieOnlyAlertWindow()
    self:CreateServerBrowserWindow()    
    self.serverBrowserWindow:SetIsVisible(false)

    if not MainMenu_IsInGame() then
        self.playScreen = GetGUIManager():CreateGUIScriptSingle("menu/PlayScreen")
        self:CreateOptionWindow()
        self.optionWindow:SetIsVisible(false)
    end
    
    --self.scanLine = CreateMenuElement(self.mainWindow, "Image")
    --self.scanLine:SetCSSClass("scanline")
    
    --self.logo = CreateMenuElement(self.mainWindow, "Image")
    --self.logo:SetCSSClass("logo")
    
    self:CreateMenuBackground()
    self:CreateProfile()

    gMainMenu = self
    
    self:MaybeCreateModWarningWindow()
    
    self.Links = {}
    self:CreateMainLinks()
    
    self:MaybeOpenPopup()
    
    local VoiceChat = Client.GetOptionString("input/VoiceChat", "LeftAlt")
    local ShowMap = Client.GetOptionString("input/ShowMap", "C")
    local TextChat = Client.GetOptionString("input/TextChat", "Y")
    local TeamChat = Client.GetOptionString("input/TeamChat", "Return")
    local SelectNextWeapon = Client.GetOptionString("input/SelectNextWeapon", "MouseWheelUp")
    local SelectPrevWeapon = Client.GetOptionString("input/SelectPrevWeapon", "MouseWheelDown")
    local Drop = Client.GetOptionString("input/Drop", "G")
    local MovementModifier = Client.GetOptionString("input/MovementModifier", "LeftShift")

    local VoiceChatCom = Client.GetOptionString("input/VoiceChatCom", VoiceChat)
    local ShowMapCom = Client.GetOptionString("input/ShowMapCom", ShowMap)
    local TextChatCom = Client.GetOptionString("input/TextChatCom", TextChat)
    local TeamChatCom = Client.GetOptionString("input/TeamChatCom", TeamChat)
    local OverHeadZoomIncrease = Client.GetOptionString("input/OverHeadZoomIncrease", SelectNextWeapon)
    local OverHeadZoomDecrease = Client.GetOptionString("input/OverHeadZoomDecrease", SelectPrevWeapon)
    local OverHeadZoomReset = Client.GetOptionString("input/OverHeadZoomReset", Drop)
    local MovementOverride = Client.GetOptionString("input/MovementOverrideCom", MovementModifier)
    
    Client.SetOptionString("input/VoiceChatCom", VoiceChatCom)
    Client.SetOptionString("input/ShowMapCom", ShowMapCom)
    Client.SetOptionString("input/TextChatCom", TextChatCom)
    Client.SetOptionString("input/TeamChatCom", TeamChatCom)
    Client.SetOptionString("input/OverHeadZoomIncrease", OverHeadZoomIncrease)
    Client.SetOptionString("input/OverHeadZoomDecrease", OverHeadZoomDecrease)
    Client.SetOptionString("input/OverHeadZoomReset", OverHeadZoomReset)
    Client.SetOptionString("input/MovementOverrideCom", MovementOverride)

    local gPlayerData = {}
    local kPlayerRankingRequestUrl = "http://hive2.ns2cdt.com/api/get/playerData/"
    local kHiveWhitelistRequestUrl = "http://hive2.ns2cdt.com/api/get/whitelistedServers/"

    local function PlayerDataResponse(steamId)
        return function (playerData)

            PROFILE("PlayerRanking:PlayerDataResponse")

            local obj, pos, err = json.decode(playerData, 1, nil)

            if obj then

                gPlayerData[steamId..""] = obj

                -- its possible that the server does not send all data we want, need to check for nil here to not cause any script errors later:
                obj.skill = obj.skill or 0
                obj.level = obj.level or 0
                obj.xp    = obj.xp or 0
                obj.score = obj.score or 0
				
                Analytics.RecordLaunch( steamId, obj.level, obj.score, obj.time_played )

                Badges_FetchBadges(nil , obj.badges)

                if gMainMenu then
                    gMainMenu.playerSkill = obj.skill
                    gMainMenu.playerScore = obj.score

                    local rookie = obj.level < kRookieLevel
                    gMainMenu.playerIsRookie = rookie

                    gMainMenu:UpdateSkillTierIcon(obj.skill, rookie, obj.adagrad_sum)
                    gMainMenu:UpdateLevelBar( obj.level, obj.xp )

                    if gMainMenu.newsScript and not Client.GetAchievement("First_1_0") then
                        gMainMenu.progress = CreateMenuElement(gMainMenu.mainWindow, "GUIWelcomeProgress")

                        if rookie then
                            gMainMenu.newsScript:HideNews()
                        else
                            gMainMenu.progress:Hide()
                        end
                    end
                    
                end

            end
            
            if g_introVideoWatchTime then
                Analytics.RecordEvent( "intro_video", { extra = g_introVideoWatchTime } )
                g_introVideoWatchTime = nil
            end
        end
   end

    local requestUrl = string.format("%s%s", kPlayerRankingRequestUrl, Client.GetSteamId())
    Shared.SendHTTPRequest(requestUrl, "GET", { }, PlayerDataResponse(Client.GetSteamId()))

    local function WhitelistDataResponse(data)
        local obj, pos, err = json.decode(data)

        if obj then
            local whitelist = {}
            for _, entry in ipairs(obj) do
                if entry.ip then
                local address = string.format("%s:%s", entry.ip, entry.port)
                whitelist[address] = true
            end

                if entry.dns then
                    local address = string.format("%s:%s", entry.dns, entry.port)
                    whitelist[address] = true
                end
            end

            UpdateRankedServers(whitelist)
        end
    end
    Shared.SendHTTPRequest(kHiveWhitelistRequestUrl, "GET", { }, WhitelistDataResponse)

end

function GUIMainMenu:UpdateLevelBar( level, xp )

    if self.playerLevel ~= level or self.playerXP ~= xp then

        self.playerLevel = level
        self.playerXP = xp

        self.rankLevel:SetText(string.format( Locale.ResolveString("MENU_LEVEL"), level ))

        local xpEarned = xp - PlayerRanking_GetTotalXpNeededForLevel( level )
        local xpNeeded =  PlayerRanking_GetXPNeededForLevel(level + 1)
        self.rankLevelBar:SetText(string.format( "%d / %d", xpEarned, xpNeeded ) )
        self.rankLevelBar.levelBar:SetValue( Clamp( xpEarned / xpNeeded, 0, 1 ) )

    end
end

function GUIMainMenu:UpdateSkillTierIcon( skill, isRookie, adagrad )
    if skill then
        local skillTier, tierName = GetPlayerSkillTier(skill, isRookie, adagrad)
        self.skillTier = skillTier
        self.skillTierName = tierName
        self.skillTierIcon.tooltipText = string.format(Locale.ResolveString("SKILLTIER_TOOLTIP"), Locale.ResolveString(tierName), skillTier)
        self.skillTierIcon.background:SetTexturePixelCoordinates(0, (skillTier + 2) * 32, 100, (skillTier + 3) * 32 - 1)

        self.skillTierLink:SetText(self.skillTierIcon.tooltipText)
    end
end

function GUIMainMenu:SetShowWindowName(name)

    self.showWindowAnimation:SetText(ToString(name))
    self.showWindowAnimation:GetBackground():DestroyAnimations()
    self.showWindowAnimation:SetIsVisible(true)
    self.showWindowAnimation:SetCSSClass("showwindow_hidden")
    self.showWindowAnimation:SetCSSClass("showwindow_animation1")
    
end

function GUIMainMenu:CreateMainLink(text, linkNum, OnClick)
    
    local playRoomOffset = MainMenu_IsInGame() and 0 or 0.5
    local cssClass = MainMenu_IsInGame() and "ingame" or "mainmenu"
    local elementName = "Link"
    
    -- play button takes up one and a half slots.
    if text == "MENU_PLAY" then
        playRoomOffset = 0
        elementName = "BigLink"
        cssClass = "play_button"
    end
    
    local mainLink = CreateMenuElement(self.menuBackground, elementName)
    mainLink:SetText(Locale.ResolveString(text))
    mainLink.originalText = text
    mainLink:SetCSSClass(cssClass)
    mainLink:SetTopOffset(50 + 70 * (linkNum + playRoomOffset))
    mainLink:SetBackgroundColor(Color(1,1,1,0))
    mainLink:EnableHighlighting()
    
    mainLink.linkIcon = CreateMenuElement(mainLink, "Font")
    local linkNumText = string.format("%s%s", linkNum < 10 and "0" or "", linkNum)
    mainLink.linkIcon:SetText(linkNumText)
    mainLink.linkIcon:SetCSSClass(cssClass)
    mainLink.linkIcon:SetTextColor(Color(1,1,1,0))
    mainLink.linkIcon:EnableHighlighting()
    mainLink.linkIcon:SetBackgroundColor(Color(1,1,1,0))
    
    -- do some special highlighting effects on the "Training" option if they haven't completed the tutorials yet.
    if text == "MENU_TRAINING" then
        
        -- only display if they haven't done both of the new tutorials.
        if not Client.GetAchievement('First_0_9') or gDebugTrainingHighlight then
            mainLink:SetTextColor(kMainMenuLinkTextGlowColor)
            mainLink:SetTopOffset(50 + 70 * (linkNum + playRoomOffset))
            mainLink:SetBackgroundColor(Color(1,1,1,0))
            
            local mainLinkGlow = CreateMenuElement(self.menuBackground, "Image")
            mainLinkGlow:SetCSSClass('link_glow')
            mainLinkGlow:SetBackgroundTexture(kLinkGlowTexture)
            mainLinkGlow:SetIgnoreEvents(true)
            mainLinkGlow:SetLayer(mainLink:GetLayer() - 1)
            mainLinkGlow.topOffsetOriginal = 40 + 70 * (linkNum + playRoomOffset)
            mainLinkGlow:SetTopOffset(mainLinkGlow.topOffsetOriginal)
            mainLink.mainLinkGlow = mainLinkGlow
            
            local mainLinkAlertTextGlow = CreateMenuElement(self.menuBackground, "Image")
            mainLinkAlertTextGlow:SetCSSClass('link_alert_glow')
            mainLinkAlertTextGlow:SetBackgroundTexture(kLinkGlowTexture)
            mainLinkAlertTextGlow:SetIgnoreEvents(true)
            mainLinkAlertTextGlow.topOffsetOriginal = 40 + 70 * (linkNum + playRoomOffset)
            mainLinkAlertTextGlow:SetTopOffset(mainLinkAlertTextGlow.topOffsetOriginal)
            mainLink.mainLinkAlertTextGlow = mainLinkAlertTextGlow
            
            local mainLinkAlertText = CreateMenuElement(mainLinkAlertTextGlow, "Font")
            mainLinkAlertText:SetCSSClass('link_alert')
            mainLinkAlertText:SetTextColor(kMainMenuLinkAlertTextColor)
            mainLinkAlertText:SetText(Locale.ResolveString("MENU_UPDATED"))
            mainLink.mainLinkAlertText = mainLinkAlertText
            
        end
        
    end
    
	local parent = self
	local isPlayNow = ( text == "MENU_PLAY_NOW" )
    local eventCallbacks =
    {
        OnMouseIn = function (self, buttonPressed)
            MainMenu_OnMouseIn()
        end,
        
        OnMouseOver = function (self, buttonPressed)        
            self.linkIcon:OnMouseOver(buttonPressed)
			if parent.lastStandOption then
				--parent.lastStandOption:SetIsVisible( isPlayNow )
			end
        end,
        
        OnMouseOut = function (self, buttonPressed)
            self.linkIcon:OnMouseOut(buttonPressed) 
            MainMenu_OnMouseOut()
        end
    }
    
    mainLink:AddEventCallbacks(eventCallbacks)
    local callbackTable =
    {
        OnClick = OnClick
    }
    mainLink:AddEventCallbacks(callbackTable)
    
    return mainLink
    
end

function GUIMainMenu:Uninitialize()

    gMainMenu = nil
    self:DestroyAllWindows()
    
    if self.newsScript then
    
        GetGUIManager():DestroyGUIScript(self.newsScript)
        self.newsScript = nil
        
    end
    
    if self.optionTooltip then
    
        GetGUIManager():DestroyGUIScript(self.optionTooltip)
        self.optionTooltip = nil
        
    end
    
    GUIAnimatedScript.Uninitialize(self)
    
end

function GUIMainMenu:Restart()
    self:Uninitialize()
    self:Initialize()
end

function GUIMainMenu:CreateMenuBackground()

    self.menuBackground = CreateMenuElement(self.mainWindow, "Image")
    self.menuBackground:SetCSSClass("menu_bg_show")
    
end

function GUIMainMenu:CreateProfile()

    self.profileBackground = CreateMenuElement(self.menuBackground, "Image")
    self.profileBackground:SetCSSClass("profile")


    local eventCallbacks =
    {
        -- Trigger initial animation
        OnShow = function(self)
        
            -- Passing updateChildren == false to prevent updating of children
            self:SetCSSClass("profile", false)
            
        end,
        
        -- Destroy all animation and reset state
        OnHide = function(self) end
    }
    
    self.profileBackground:AddEventCallbacks(eventCallbacks)
    
    -- Create avatar icon.
    self.avatar = CreateMenuElement(self.profileBackground, "Image")
    self.avatar:SetCSSClass("avatar")
    self.avatar:SetBackgroundTexture("*avatar")
    
    self.playerName = CreateMenuElement(self.profileBackground, "Link")
    self.playerName:SetText(OptionsDialogUI_GetNickname())
    self.playerName:SetCSSClass("profile")

    self.skillTierIcon = CreateMenuElement(self.profileBackground, "Image")
    self.skillTierIcon:SetCSSClass("skill_icon")
    self.skillTierIcon:SetLeftOffset(self.playerName:GetTextWidth() + 150)
    self.skillTierIcon.background:SetTexturePixelCoordinates(0, 0, 100, 31)

    self.rankLevel = CreateMenuElement(self.profileBackground, "Link")
    self.rankLevel:SetText(string.format( Locale.ResolveString("MENU_LEVEL"),
    self.playerLevel or Locale.ResolveString("HIVE_OFFLINE")))
    self.rankLevel:SetCSSClass("rank_level")
    
    self.skillTierLink = CreateMenuElement(self.profileBackground, "Link")
    if self.skillTier then
        self.skillTierLink:SetText(string.format(Locale.ResolveString("SKILLTIER_TOOLTIP"), Locale.ResolveString(self.skillTierName), self.skillTier))
    else
        self.skillTierLink:SetText(string.format(Locale.ResolveString("SKILLTIER_TOOLTIP"), Locale.ResolveString("HIVE_OFFLINE"), -1))
    end
    self.skillTierLink:SetCSSClass("skill_level")
    
    self.rankLevelBar = CreateMenuElement(self.profileBackground, "Font")
    self.rankLevelBar:SetText("Until Level ###")    --TODO localize
    self.rankLevelBar:SetCSSClass("rank_level_progress")
    
    self.rankLevelBarBorder = CreateMenuElement(self.rankLevelBar, "Image")
    self.rankLevelBarBorder:SetCSSClass("rank_level_bar_container")
    
    self.rankLevelBar.levelBar = CreateMenuElement(self.rankLevelBarBorder, "ProgressBar")
    self.rankLevelBar.levelBar:SetHorizontal()
    self.rankLevelBar.levelBar:SetValue(0)
    self.rankLevelBar.levelBar:SetCSSClass("rank_level_bar", true)
    
    self.rankLevelBarBorder.hiveLink = CreateMenuElement(self.rankLevelBar.levelBar, "Image")
    self.rankLevelBarBorder.hiveLink:SetCSSClass("rank_level_bar_link")
    --TODO Add Tooltip for progressbar. Explain scoring
    
end  

local function FinishWindowAnimations(self)
    self:GetBackground():EndAnimations()
end

local function AddFavoritesToServerList(serverList)

    local favoriteServers = GetStoredServers()
    for f = 1, #favoriteServers do
    
        local currentFavorite = favoriteServers[f]
        if type(currentFavorite) == "string" then
            currentFavorite = { address = currentFavorite }
        end
        
        local serverEntry = { }
        serverEntry.name = currentFavorite.name or "No name"
        serverEntry.mode = "?"
        serverEntry.map = "?"
        serverEntry.numPlayers = 0
        serverEntry.maxPlayers = currentFavorite.maxPlayers or 24
        serverEntry.numSpectators = currentFavorite.numSpectators or 0
        serverEntry.maxSpectators = currentFavorite.maxSpectators or 0
        serverEntry.ping = 999
        serverEntry.address = currentFavorite.address or "127.0.0.1:27015"
        serverEntry.requiresPassword = currentFavorite.requiresPassword or false
        serverEntry.playerSkill = currentFavorite.playerSkill or 0
        serverEntry.rookieOnly = currentFavorite.rookieOnly or false
        serverEntry.friendsOnServer = false
        serverEntry.lanServer = false
        serverEntry.tickrate = 30
        serverEntry.currentScore = 0
        serverEntry.performanceScore = 0
        serverEntry.performanceQuality = 0
        serverEntry.serverId = -f
        serverEntry.numRS = currentFavorite.numRS or 0
        serverEntry.modded = currentFavorite.modded or false
        serverEntry.favorite = currentFavorite.favorite
        serverEntry.blocked = currentFavorite.blocked
        serverEntry.history = currentFavorite.history
        serverEntry.lastConnect = currentFavorite.lastConnect or 0

        serverEntry.name = FormatServerName(serverEntry.name, serverEntry.rookieOnly)
        
        local function OnServerRefreshed(serverData)
            serverList:UpdateEntry(serverData)
        end
        Client.RefreshServer(serverEntry.address, OnServerRefreshed)
        
        serverList:AddEntry(serverEntry)
        
    end
    
end

function GUIMainMenu:UpdateServerList()
    if Client.GetServerListRefreshed() then
        self.serverTabs:Reset()
        self.numServers = 0
        self.totalServers = 0

        Client.RebuildServerList()
        self.serverBrowserWindow:ResetSlideBar()
        self.selectServer:SetIsVisible(false)
        self.serverList:ClearChildren()
        -- Needs to be done here because the server IDs will change.
        self:ResetServerSelection()
    
        AddFavoritesToServerList(self.serverList)
    end
end

function GUIMainMenu:JoinServer()

    local selectedServer = MainMenu_GetSelectedServer()
    if selectedServer then

        if selectedServer < 0 then

            MainMenu_JoinSelected()
            
        elseif MainMenu_GetSelectedIsFull() and not MainMenu_ForceJoin() then
            
            self.autoJoinWindow:SetIsVisible(true)
            self.autoJoinText:SetText(ToString(MainMenu_GetSelectedServerName()))

            if MainMenu_GetSelectedHasSpectatorSlots() then
                if MainMenu_GetSelectedIsFullWithNoRS() then
                    self.autoJoinTooltip:SetText(Locale.ResolveString("AUTOJOIN_JOIN_TOOLTIP_SPEC"))
                    self.autoJoinWindow.forceJoin:SetText(Locale.ResolveString("AUTOJOIN_SPEC"))
                else
                    self.autoJoinTooltip:SetText(Locale.ResolveString("AUTOJOIN_JOIN_TOOLTIP_SPEC_AND_RS"))
                    self.autoJoinWindow.forceJoin:SetText(Locale.ResolveString("AUTOJOIN_SPEC_AND_RS"))
                end

                self.autoJoinWindow.forceJoin:SetIsVisible(true)
            elseif not MainMenu_GetSelectedIsFullWithNoRS() then
                self.autoJoinWindow.forceJoin:SetText(Locale.ResolveString("AUTOJOIN"))
                self.autoJoinWindow.forceJoin:SetIsVisible(true)
                self.autoJoinTooltip:SetText(Locale.ResolveString("AUTOJOIN_JOIN_TOOLTIP"))
            else
                self.autoJoinTooltip:SetText("")
                self.autoJoinWindow.forceJoin:SetIsVisible(false)
            end
            
        else
           
            MainMenu_JoinSelected()
            
        end
    end
    
end

function GUIMainMenu:ProcessJoinServer(pastWarning)
    if MainMenu_GetSelectedServer() then
        
        if not pastWarning and not MainMenu_GetSelectedIsFavorited() and not Client.GetOptionBoolean("never_show_snma", false)
            and ( MainMenu_GetSelectedIsHighPlayerCount() or MainMenu_GetSelectedIsNetworkModded() ) 
        then
            
            local showNeverShow = self.playerLevel and self.playerLevel >= kRookieLevel
            
            self.serverNetworkModedAlertWindow:SetIsVisible(true)
            self.serverNetworkModedAlertWindow.neverShow:SetIsVisible(showNeverShow)
            self.serverNetworkModedAlertWindow.neverShowText:SetIsVisible(showNeverShow)
            
        elseif (not pastWarning or pastWarning == 1) and not Client.GetOptionBoolean("never_show_roa", false) 
            and MainMenu_GetSelectedIsRookieOnly() and Client.GetLevel() >= kRookieLevel
        then
            
            self.rookieOnlyAlertWindow:SetIsVisible(true)
            
        elseif MainMenu_GetSelectedRequiresPassword() then
            
            -- JoinServer is called directly from the password prompt window, so no need to check "pastWarning" here
            self.passwordPromptWindow:SetIsVisible(true)
            
        else

            self:JoinServer()
            
        end
    end
    
end

function GUIMainMenu:CreateAlertWindow()
    self.alertWindow = CreateMenuElement(self.mainWindow, "GUIAlertWindow")
    self.alertText = self.alertWindow.title
end 

function GUIMainMenu:CreateRookieOnlyAlertWindow()

    local window = self:CreateWindow()
    
    self.rookieOnlyAlertWindow = window
    
    window:SetWindowName(Locale.ResolveString("ALERT"))
    window:SetInitialVisible(false)
    window:SetIsVisible(false)
    window:DisableResizeTile()
    window:DisableSlideBar()
    window:DisableContentBox()
    window:SetCSSClass("warning_alert_window")
    window:DisableCloseButton()
    window:SetLayer(kGUILayerMainMenuDialogs)

    window:AddEventCallbacks( { OnBlur = function(self) self:SetIsVisible(false) end } )

    window.alertText = CreateMenuElement(window, "Font")
    window.alertText:SetCSSClass("warning_alerttext")
    window.alertText:SetText(WordWrap(window.alertText.text, Locale.ResolveString("ROOKIEONLYNAG_MSG"), 0, 460) )

    local okButton = CreateMenuElement(window, "MenuButton")
    okButton:SetCSSClass("warning_alert_join")
    okButton:SetText(string.UTF8Upper(Locale.ResolveString("OK")))

    local cancel = CreateMenuElement(window, "MenuButton")
    cancel:SetCSSClass("warning_alert_cancle")
    cancel:SetText(string.UTF8Upper(Locale.ResolveString("CANCEL")))

    local neverShow = CreateMenuElement(window, "Checkbox")    
    neverShow:SetCSSClass("never_show_again")
    neverShow:SetChecked(Client.GetOptionBoolean("never_show_roa", false))
    
    local neverShowText = CreateMenuElement(window, "Font")
    neverShowText:SetCSSClass("never_show_again_text")
    neverShowText:SetText(Locale.ResolveString("NEVER_SHOW_AGAIN"))
    
    window.neverShow = neverShow
    
    okButton:AddEventCallbacks({
        OnClick = function (self)
            if self.scriptHandle.rookieOnlyAlertWindow.neverShow:GetValue() then                
                Client.SetOptionBoolean("never_show_roa", true)
            end
            self.scriptHandle.rookieOnlyAlertWindow:SetIsVisible(false)
            self.scriptHandle:ProcessJoinServer( 2 )
        end
    })

    cancel:AddEventCallbacks({
        OnClick = function (self)
            self.scriptHandle.rookieOnlyAlertWindow:SetIsVisible(false)
        end
    })

end

function GUIMainMenu:CreateServerNetworkModdedAlertWindow()

    local window = self:CreateWindow()
    
    self.serverNetworkModedAlertWindow = window
    
    window:SetWindowName(Locale.ResolveString("ALERT"))
    window:SetInitialVisible(false)
    window:SetIsVisible(false)
    window:DisableResizeTile()
    window:DisableSlideBar()
    window:DisableContentBox()
    window:SetCSSClass("warning_alert_window")
    window:DisableCloseButton()
    window:SetLayer(kGUILayerMainMenuDialogs)
    
   window:AddEventCallbacks( { OnBlur = function(self) self:SetIsVisible(false) end } )
   
   window.alertText = CreateMenuElement(window, "Font")
   window.alertText:SetCSSClass("warning_alerttext")
   window.alertText:SetText(WordWrap(window.alertText.text, Locale.ResolveString("SERVER_MODDED_WARNING"), 0, 460))
    
    local okButton = CreateMenuElement(window, "MenuButton")
    okButton:SetCSSClass("warning_alert_join")
    okButton:SetText(string.UTF8Upper(Locale.ResolveString("JOIN")))
    
    local cancel = CreateMenuElement(window, "MenuButton")
    cancel:SetCSSClass("warning_alert_cancle")
    cancel:SetText(string.UTF8Upper(Locale.ResolveString("CANCEL")))
        
    local neverShow = CreateMenuElement(window, "Checkbox")
    neverShow:SetCSSClass("never_show_again")
    neverShow:SetChecked(Client.GetOptionBoolean("never_show_snma", false))
    neverShow:SetIsVisible(false)
    
    window.neverShow = neverShow
    
    local neverShowText = CreateMenuElement(window, "Font")
    neverShowText:SetCSSClass("never_show_again_text")
    neverShowText:SetText(Locale.ResolveString("NEVER_SHOW_AGAIN"))
    neverShowText:SetIsVisible(false)
    
    window.neverShowText = neverShowText

    okButton:AddEventCallbacks({ 
        OnClick = function (self)
            local neverShow = self.scriptHandle.serverNetworkModedAlertWindow.neverShow 
            if neverShow:GetIsVisible() and neverShow:GetValue() then
                Client.SetOptionBoolean("never_show_snma", true)
            end
            
            self.scriptHandle.serverNetworkModedAlertWindow:SetIsVisible(false)
            self.scriptHandle:ProcessJoinServer( 1 )
        end 
    })
    
    cancel:AddEventCallbacks({ 
        OnClick = function (self)    
            self.scriptHandle.serverNetworkModedAlertWindow:SetIsVisible(false)
        end 
    })

    
end

function GUIMainMenu:CreateAutoJoinWindow()

    self.autoJoinWindow = self:CreateWindow()    
    self.autoJoinWindow:SetWindowName("WAITING FOR SLOT ...")
    self.autoJoinWindow:SetInitialVisible(false)
    self.autoJoinWindow:SetIsVisible(false)
    self.autoJoinWindow:DisableTitleBar()
    self.autoJoinWindow:DisableResizeTile()
    self.autoJoinWindow:DisableSlideBar()
    self.autoJoinWindow:DisableContentBox()
    self.autoJoinWindow:SetCSSClass("autojoin_window")
    self.autoJoinWindow:DisableCloseButton()
    self.autoJoinWindow:SetLayer(kGUILayerMainMenuDialogs)
    
    self.autoJoinWindow.forceJoin = CreateMenuElement(self.autoJoinWindow, "MenuButton")
    self.autoJoinWindow.forceJoin:SetCSSClass("forcejoin")
    self.autoJoinWindow.forceJoin:SetText(Locale.ResolveString("AUTOJOIN"))
    
    local cancel = CreateMenuElement(self.autoJoinWindow, "MenuButton")
    cancel:SetCSSClass("autojoin_cancel")
    cancel:SetText(Locale.ResolveString("AUTOJOIN_CANCEL"))
    
    local text = CreateMenuElement(self.autoJoinWindow, "Font")
    text:SetCSSClass("auto_join_text")
    text:SetText(Locale.ResolveString("AUTOJOIN_JOIN"))
    
    self.autoJoinTooltip = CreateMenuElement(self.autoJoinWindow, "Font")
    self.autoJoinTooltip:SetCSSClass("auto_join_text_tooltip")
    self.autoJoinTooltip:SetText(Locale.ResolveString("AUTOJOIN_JOIN_TOOLTIP"))
    
    self.autoJoinText = CreateMenuElement(self.autoJoinWindow, "Font")
    self.autoJoinText:SetCSSClass("auto_join_text_servername")
    self.autoJoinText:SetText("")
    
    self.blinkingArrowTwo = CreateMenuElement(self.autoJoinWindow, "Image")
    self.blinkingArrowTwo:SetCSSClass("blinking_arrow_two")

    self.autoJoinWindow.forceJoin:AddEventCallbacks( {OnClick = 
    function(self) 
        MainMenu_ForceJoin(true)
        self.scriptHandle:ProcessJoinServer(3) 
    end } )
    
    cancel:AddEventCallbacks({ OnClick =
    function (self)    
        self:GetParent():SetIsVisible(false)        
    end })
    
    local eventCallbacks =
    {
        OnShow = function(self)
            self.scriptHandle.updateAutoJoin = true
        end,
        OnHide = function(self)
            self.scriptHandle.updateAutoJoin = false
        end,
        OnBlur = function(self)
            self:SetIsVisible(false)
        end
    }
    
    self.autoJoinWindow:AddEventCallbacks(eventCallbacks)

end

function GUIMainMenu:CreatePasswordPromptWindow()

    self.passwordPromptWindow = self:CreateWindow()
    local passwordPromptWindow = self.passwordPromptWindow
    passwordPromptWindow:SetWindowName("ENTER PASSWORD")
    passwordPromptWindow:SetInitialVisible(false)
    passwordPromptWindow:SetIsVisible(false)
    passwordPromptWindow:DisableResizeTile()
    passwordPromptWindow:DisableSlideBar()
    passwordPromptWindow:DisableContentBox()
    passwordPromptWindow:SetCSSClass("passwordprompt_window")
    passwordPromptWindow:SetLayer(kGUILayerMainMenuDialogs)
        
    local passwordForm = CreateMenuElement(passwordPromptWindow, "Form", false)
    passwordForm:SetCSSClass("passwordprompt")
    
    local textinput = passwordForm:CreateFormElement(Form.kElementType.TextInput, "PASSWORD", "")
    textinput:SetCSSClass("serverpassword")    
    textinput:SetIsSecret(true)
    
    local descriptionText = CreateMenuElement(passwordPromptWindow.titleBar, "Font", false)
    descriptionText:SetCSSClass("passwordprompt_title")
    descriptionText:SetText(Locale.ResolveString("PASSWORD"))
    
    local togglePasswordVisible = CreateMenuElement(passwordForm, "MenuButton")
    togglePasswordVisible:SetCSSClass("displaypassword_toggle")
    
    local function TogglePassword()
        textinput:SetIsSecret(not textinput:GetIsSecret())
        GetWindowManager():HandleFocusBlur(passwordPromptWindow, textinput)
    end
    
    togglePasswordVisible:AddEventCallbacks({ OnClick = TogglePassword })
    
    local joinServer = CreateMenuElement(passwordPromptWindow, "MenuButton")
    joinServer:SetCSSClass("bottomcenter")
    joinServer:SetText(Locale.ResolveString("JOIN"))
    
    local function SubmitPassword()
        local formData = passwordForm:GetFormData()
        MainMenu_SetSelectedServerPassword(formData.PASSWORD)
        passwordPromptWindow:SetIsVisible(false)
        self:JoinServer()
    end
    
    joinServer:AddEventCallbacks({ OnClick = SubmitPassword })
    passwordPromptWindow:AddEventCallbacks({ 
    
        OnBlur = function(self) self:SetIsVisible(false) end,        
        OnEnter = SubmitPassword,
        OnShow = function(self) GetWindowManager():HandleFocusBlur(self, textinput) end,
        OnHide = function(self)
            textinput:SetValue("")
            textinput:SetIsSecret(true)
        end,
        OnEscape = function(self)
            passwordPromptWindow:SetIsVisible(false)
        end
    })
    
end

local kTickrateDescription = "PERFORMANCE: %s%%"

function GUIMainMenu:CreateFilterForm()

    self.filterForm = CreateMenuElement(self.serverBrowserWindow, "Form", false)
    self.filterForm:SetCSSClass("filter_form")
    
    self.filterServerName = self.filterForm:CreateFormElement(Form.kElementType.TextInput, Locale.ResolveString("SERVERBROWSER_SERVERNAME"))
    self.filterServerName:SetCSSClass("filter_servername")
    self.filterServerName:SetValue(Locale.ResolveString("SERVERBROWSER_SEARCH"))
    self.filterServerName:AddSetValueCallback(function(self)
        if not self.firstClick then return end
    
        local value = StringTrim(self:GetValue())
        self.scriptHandle.serverList:SetFilter(10, FilterSearchServer(value))
        
        Client.SetOptionString("filter_servername", value)
        
    end)

    self.filterServerName:AddEventCallbacks{
        OnClick = function(self)
            if not self.firstClick then
                self:SetValue("")
                self.firstClick = true
            end
        end,
        OnBlur = function(self)
            if self:GetValue() == "" then
                self.firstClick = false
                self:SetValue(Locale.ResolveString("SERVERBROWSER_SEARCH"))
            end
        end
    }

    self.filterMaxPing = self.filterForm:CreateFormElement(Form.kElementType.SlideBar, "MAX PING")
    self.filterMaxPing:SetCSSClass("filter_maxping")
    self.filterMaxPing:AddSetValueCallback( function(self)

        local value = self.scriptHandle.filterMaxPing:GetValue()
        local filterRange = kFilterMaxPing - kFilterMinPing
        local filterValue = math.round(kFilterMinPing + value * filterRange)
        self.scriptHandle.serverList:SetFilter(4, FilterMaxPing(filterValue))
        Client.SetOptionString("filter_maxping", ToString(value))

        local textValue = ""
        if value == 1.0 then
            textValue = Locale.ResolveString("FILTER_UNLIMTED")
        else
            textValue = ToString(filterValue)
        end

        self.scriptHandle.pingDescription:SetText(string.format("%s %s", Locale.ResolveString("SERVERBROWSER_MAXPING"), textValue))

    end )

    self.pingDescription = CreateMenuElement(self.filterMaxPing, "Font")
    self.pingDescription:SetCSSClass("filter_description")

    self.filterHasPlayers = self.filterForm:CreateFormElement(Form.kElementType.Checkbox, Locale.ResolveString("SERVERBROWSER_SHOW_EMPTY"))
    self.filterHasPlayers:SetCSSClass("filter_hasplayers")
    self.filterHasPlayers:AddSetValueCallback(function(self)
    
        self.scriptHandle.serverList:SetFilter(5, FilterEmpty(not self:GetValue()))
        Client.SetOptionString("filter_show_empty", ToString(self.scriptHandle.filterHasPlayers:GetValue()))
        
    end)



    local description = CreateMenuElement(self.filterHasPlayers, "Font")
    description:SetText(Locale.ResolveString("SERVERBROWSER_SHOW_EMPTY"))
    description:SetCSSClass("filter_description")

    self.filterFull = self.filterForm:CreateFormElement(Form.kElementType.Checkbox, Locale.ResolveString("SERVERBROWSER_SHOW_FULL"))
    self.filterFull:SetCSSClass("filter_full")
    self.filterFull:AddSetValueCallback(function(self)
    
        self.scriptHandle.serverList:SetFilter(6, FilterFull(not self:GetValue()))
        Client.SetOptionString("filter_show_full", ToString(self.scriptHandle.filterFull:GetValue()))
        
    end)
    
    description = CreateMenuElement(self.filterFull, "Font")
    description:SetText(Locale.ResolveString("SERVERBROWSER_SHOW_FULL"))
    description:SetCSSClass("filter_description")
    
    self.filterPassworded = self.filterForm:CreateFormElement(Form.kElementType.Checkbox, Locale.ResolveString("SERVERBROWSER_PASSWORDED"))
    self.filterPassworded:SetCSSClass("filter_passworded")
    self.filterPassworded:AddSetValueCallback(function(self)
    
        self.scriptHandle.serverList:SetFilter(7, FilterPassworded(self:GetValue()))
        Client.SetOptionString("filter_passworded", ToString(self.scriptHandle.filterPassworded:GetValue()))
        
    end)
    
    description = CreateMenuElement(self.filterPassworded, "Font")
    description:SetText(Locale.ResolveString("SERVERBROWSER_PASSWORDED"))
    description:SetCSSClass("filter_description")
    
    self.filterRookieOnly = self.filterForm:CreateFormElement(Form.kElementType.Checkbox, Locale.ResolveString("SERVERBROWSER_ROOKIEONLY"))
    self.filterRookieOnly:SetCSSClass("filter_rookieonly")
    self.filterRookieOnly:AddSetValueCallback(function(self)
    
        self.scriptHandle.serverList:SetFilter(12, FilterRookieOnly(self:GetValue()))
        Client.SetOptionString("show_rookie_only", ToString(self.scriptHandle.filterRookieOnly:GetValue()))
        
    end)
    
    description = CreateMenuElement(self.filterRookieOnly, "Font")
    description:SetText(Locale.ResolveString("SERVERBROWSER_ROOKIEONLY"))
    description:SetCSSClass("filter_description")
    
    self.filterRankedOnly = self.filterForm:CreateFormElement(Form.kElementType.Checkbox, Locale.ResolveString("SERVERBROWSER_SHOW_UNRANKED"))
    self.filterRankedOnly:SetCSSClass("filter_rankedonly")
    self.filterRankedOnly:AddSetValueCallback(function(self)
    
        self.scriptHandle.serverList:SetFilter(9, FilterRankedOnly(not self:GetValue()))
        Client.SetOptionString("filter_show_unranked", ToString(self.scriptHandle.filterRankedOnly:GetValue()))
        
    end)

    --At resolutions with a with lower 1280 the max ping bar just doesn't fit in
    self.filterMaxPing:SetIsVisible( self.filterRankedOnly.background:GetPosition().x + self.filterRankedOnly.background:GetSize().x <
            self.filterMaxPing.background:GetPosition().x )
    
    description = CreateMenuElement(self.filterRankedOnly, "Font")
    description:SetText(Locale.ResolveString("SERVERBROWSER_SHOW_UNRANKED"))
    description:SetCSSClass("filter_description")

    local oldHasPlayer = string.ToBoolean(Client.GetOptionString("filter_hasplayers", "false"))
    local oldFull = string.ToBoolean(Client.GetOptionString("filter_full", "false"))

    self.filterHasPlayers:SetValue(Client.GetOptionString("filter_show_empty", tostring(not oldHasPlayer)))
    self.filterFull:SetValue(Client.GetOptionString("filter_show_full", tostring(not oldFull)))

    if self.filterMaxPing:GetIsVisible() then
        self.filterMaxPing:SetValue(tonumber(Client.GetOptionString("filter_maxping", "1")) or 1)
    else
        self.filterMaxPing:SetValue(1)
    end

    self.filterPassworded:SetValue(Client.GetOptionString("filter_passworded", "true"))
    self.filterRookieOnly:SetValue(Client.GetOptionString("show_rookie_only", "true"))

    self.filterRankedOnly:SetValue(Client.GetOptionString("filter_show_unranked", "true"))

end

function GUIMainMenu:CreatePlayFooter()

    self.playFooter = CreateMenuElement(self.serverBrowserWindow, "Form")
    self.playFooter:SetCSSClass("serverbrowser_footer_bg")

    self.playFooter.playNow = CreateMenuElement(self.playFooter, "MenuButton")
    self.playFooter.playNow:SetCSSClass("serverbrowser_footer_playnow")
    self.playFooter.playNow:SetText(Locale.ResolveString("JOIN"))
    self.playFooter.playNow:AddEventCallbacks{
        OnClick = function (playNow)
            if self.serverDetailsWindow:GetIsVisible() then
                self:ProcessJoinServer()
            else
                self:DoQuickJoin()
            end
        end,
    }

    local divider = CreateMenuElement(self.playFooter, "Image")
    divider:SetCSSClass("serverbrowser_footer_divider_1")

    divider = CreateMenuElement(self.playFooter, "Image")
    divider:SetCSSClass("serverbrowser_footer_divider_2")

    self.playFooter.createServer = CreateMenuElement(self.playFooter, "MenuButton")
    self.playFooter.createServer:SetCSSClass("serverbrowser_footer_createserver")
    self.playFooter.createServer:SetText(Locale.ResolveString("START_SERVER"))
    self.playFooter.createServer:AddEventCallbacks{
        OnClick = function ()
            if not self.createGame:GetIsVisible() then
                self.createGame:SetIsVisible(true)
            else
                self.hostGameButton:OnClick()
            end
        end
    }

    self.playFooter.back = CreateMenuElement(self.playFooter, "MenuButton")
    self.playFooter.back:SetCSSClass("serverbrowser_footer_back")
    self.playFooter.back:SetText(Locale.ResolveString("BACK"))
    self.playFooter.back:AddEventCallbacks{
        OnClick = function ()
            self.playNowWindow:SetIsVisible(false)
            self.serverBrowserWindow:SetIsVisible(false)
            
            Matchmaking_LeaveGlobalLobby()
            
            if self.playScreen then
                self:HideMenu()
                self.playScreen:Show()
            end
        end
    }
end

local function TestGetServerPlayerDetails(index, table)

    table[1] = { name = "Test 1", score = 1, timePlayed = 200 }
    table[2] = { name = "Test 2", score = 10, timePlayed = 300 }
    table[3] = { name = "Test 3", score = 12, timePlayed = 450 }
    table[4] = { name = "Test 4", score = 100, timePlayed = 332 }
    table[5] = { name = "Test 5", score = 24, timePlayed = 800.6 }
    table[6] = { name = "Test 6", score = 22, timePlayed = 212.7 }
    table[7] = { name = "Test 7", score = 15, timePlayed = 80 }
    table[8] = { name = "Test 8", score = 90, timePlayed = 60 }
    table[9] = { name = "Test 9", score = 45, timePlayed = 1231 }
    table[10] = { name = "Test 10", score = 340, timePlayed = 564 }
    table[11] = { name = "Test 11", score = 400, timePlayed = 55 }
    table[12] = { name = "Test 1", score = 1, timePlayed = 645 }
    table[13] = { name = "Test 2", score = 10, timePlayed = 987 }
    table[14] = { name = "Test 3", score = 12, timePlayed = 456 }
    table[15] = { name = "Test 4", score = 100, timePlayed = 321 }
    table[16] = { name = "Test 5", score = 24, timePlayed = 458 }
    table[17] = { name = "Test 6", score = 22, timePlayed = 159 }
    table[18] = { name = "Test 7", score = 15, timePlayed = 852 }
    table[19] = { name = "Test 8", score = 90, timePlayed = 753 }
    table[20] = { name = "Test 9", score = 45, timePlayed = 50 }
    table[21] = { name = "Test 10", score = 340, timePlayed = 220 }
    table[22] = { name = "Test 11", score = 400, timePlayed = 443 }
    table[23] = { name = "Test 11", score = 400, timePlayed = 20 }
    table[24] = { name = "Test 11", score = 400, timePlayed = 30 }
    table[25] = { name = "Test 11", score = 400, timePlayed = 23 }
    table[26] = { name = "Test 11", score = 400, timePlayed = 5 }
    table[27] = { name = "Test 11", score = 400, timePlayed = 12 }
    table[28] = { name = "Test 11", score = 400, timePlayed = 800 }
    table[29] = { name = "Test 11", score = 400, timePlayed = 865 }
    table[30] = { name = "Test 11", score = 400, timePlayed = 744 }
    table[31] = { name = "Test 11", score = 400, timePlayed = 45.786 }
    table[32] = { name = "Test 11", score = 400, timePlayed = 558.987 }

end

local downloadedModDetails = { }
local currentlyDownloadingModDetails = {}

local function ModDetailsCallback(modId, title, description)

    downloadedModDetails[modId] = title
    currentlyDownloadingModDetails[modId] = nil
    
end

local function GetPerformanceTextFromIndex(serverIndex)
    local performanceQuality = Client.GetServerPerformanceQuality(serverIndex)
    local performanceScore = Client.GetServerPerformanceScore(serverIndex)
    local str = ServerPerformanceData.GetPerformanceText(performanceQuality, performanceScore)
    return string.format("%s %s", Locale.ResolveString("SERVERBROWSER_SERVER_DETAILS_PERF"), str)
end
  
local function GetPerformanceText(serverData)
    local performanceQuality = serverData.performanceQuality
    local performanceScore = serverData.performanceScore
    local str = ServerPerformanceData.GetPerformanceText(serverData.performanceQuality, serverData.performanceScore)
    return string.format("%s %s", Locale.ResolveString("SERVERBROWSER_SERVER_DETAILS_PERF"), str)
end

function GUIMainMenu:CreateServerDetailsWindow()

    self.serverDetailsWindow = self:CreateWindow()
    
    self.serverDetailsWindow:SetWindowName(Locale.ResolveString("SERVERBROWSER_SERVER_DETAILS"))
    self.serverDetailsWindow:SetInitialVisible(false)
    self.serverDetailsWindow:SetIsVisible(false)
    self.serverDetailsWindow:DisableResizeTile()
    self.serverDetailsWindow:SetCSSClass("serverdetails_window")
    --self.serverDetailsWindow:DisableCloseButton()
    
    self.serverDetailsWindow:AddEventCallbacks({
        OnBlur = function(self)
            self:SetIsVisible(false)
        end,
        OnEscape = function(self)
            self:SetIsVisible(false)
            return true
        end
    })
    
    self.serverDetailsWindow.serverName = CreateMenuElement(self.serverDetailsWindow, "Font")
    
    self.serverDetailsWindow.serverAddress = CreateMenuElement(self.serverDetailsWindow, "Font")
    self.serverDetailsWindow.serverAddress:SetTopOffset(32)    
    
    self.serverDetailsWindow.playerCount = CreateMenuElement(self.serverDetailsWindow, "Font")
    self.serverDetailsWindow.playerCount:SetTopOffset(64)

    self.serverDetailsWindow.spectatorCount = CreateMenuElement(self.serverDetailsWindow, "Font")
    self.serverDetailsWindow.spectatorCount:SetTopOffset(96)
    
    self.serverDetailsWindow.ping = CreateMenuElement(self.serverDetailsWindow, "Font")
    self.serverDetailsWindow.ping:SetTopOffset(128)
    
    self.serverDetailsWindow.gameMode = CreateMenuElement(self.serverDetailsWindow, "Font")
    self.serverDetailsWindow.gameMode:SetTopOffset(160)
    
    self.serverDetailsWindow.map = CreateMenuElement(self.serverDetailsWindow, "Font")
    self.serverDetailsWindow.map:SetTopOffset(192)
    
    self.serverDetailsWindow.performance = CreateMenuElement(self.serverDetailsWindow, "Font")
    self.serverDetailsWindow.performance:SetTopOffset(224)
    
    self.serverDetailsWindow.modsDesc = CreateMenuElement(self.serverDetailsWindow, "Font")
    self.serverDetailsWindow.modsDesc:SetTopOffset(256)
    self.serverDetailsWindow.modsDesc:SetText("Installed Mods:")
    
    local windowWidth = self.serverDetailsWindow.background.guiItem:GetSize().x - 16
    
    self.serverDetailsWindow.modList = CreateMenuElement(self.serverDetailsWindow, "Font")
    self.serverDetailsWindow.modList:SetTopOffset(288)
    self.serverDetailsWindow.modList:SetCSSClass("serverdetails_modlist")
    self.serverDetailsWindow.modList.text:SetTextClipped(true, windowWidth, 70)

    self.serverDetailsWindow.joinServerButton = CreateMenuElement(self.serverDetailsWindow, "MenuButton")
    self.serverDetailsWindow.joinServerButton:SetCSSClass("joinserver")
    self.serverDetailsWindow.joinServerButton:SetText(Locale.ResolveString("JOIN"))
    self.serverDetailsWindow.joinServerButton:AddEventCallbacks( {OnClick = function(self) self.scriptHandle:ProcessJoinServer() end } )

    self.serverDetailsWindow.favoriteIcon = CreateMenuElement(self.serverDetailsWindow, "Image")
    self.serverDetailsWindow.favoriteIcon:SetBackgroundSize(Vector(26, 26, 0))
    self.serverDetailsWindow.favoriteIcon:SetTopOffset(64)
    self.serverDetailsWindow.favoriteIcon:SetRightOffset(24)
    self.serverDetailsWindow.favoriteIcon:SetBackgroundTexture("ui/menu/favorite.dds")

    self.serverDetailsWindow.blockedIcon = CreateMenuElement(self.serverDetailsWindow, "Image")
    self.serverDetailsWindow.blockedIcon:SetBackgroundSize(Vector(26, 26, 0))
    self.serverDetailsWindow.blockedIcon:SetTopOffset(64)
    self.serverDetailsWindow.blockedIcon:SetRightOffset(24)
    self.serverDetailsWindow.blockedIcon:SetBackgroundTexture("ui/menu/blocked.dds")
    
    self.serverDetailsWindow.passwordedIcon = CreateMenuElement(self.serverDetailsWindow, "Image")
    self.serverDetailsWindow.passwordedIcon:SetBackgroundSize(Vector(26, 26, 0))
    self.serverDetailsWindow.passwordedIcon:SetTopOffset(96)
    self.serverDetailsWindow.passwordedIcon:SetRightOffset(24)
    self.serverDetailsWindow.passwordedIcon:SetBackgroundTexture("ui/lock.dds")
    
    self.serverDetailsWindow.playerEntries = {}

    self.serverDetailsWindow.UpdatePlayers = function(self)
        if self.serverIndex < 0 then return end

        local playersInfo = { }
        Client.GetServerPlayerDetails(self.serverIndex, playersInfo)

        -- update entry count:
        local numEntries = #self.playerEntries
        local numCurrentEntries = #playersInfo

        if numEntries > numCurrentEntries then

            for i = 1,  numEntries - numCurrentEntries do

                self.playerEntries[#self.playerEntries]:Uninitialize()
                self.playerEntries[#self.playerEntries] = nil

            end

        elseif numCurrentEntries > numEntries then

            for i = 1, numCurrentEntries - numEntries do

                local entry = CreateMenuElement(self:GetContentBox(), "PlayerEntry")
                table.insert(self.playerEntries, entry)

            end

        end

        -- update data and positions
        for i = 1, numCurrentEntries do

            local data = playersInfo[i]
            local entry = self.playerEntries[i]

            entry:SetTopOffset( (i-1) * kPlayerEntryHeight )
            entry:SetPlayerData(data)

        end
    end

    self.serverDetailsWindow.UpdateMods = function(self)
        if self.serverIndex < 0 then return end

        local modString = Client.GetServerKeyValue(self.serverIndex, "mods") -- "7c59c34 7b986f5 5f9ccf1 5fd7a38 5fdc381 6ec6bcd 676c71a 7619dc7"
        local modTitles = {}

        local mods = StringSplit(StringTrim(modString), " ")
        local modCount = string.len(modString) == 0 and 0 or #mods
        for m = 1, #mods do

            local modId = tonumber(string.format("0x%s", mods[m]))
            if modId and not downloadedModDetails[modId] and (not currentlyDownloadingModDetails[modId]
                    or currentlyDownloadingModDetails[modId] < Shared.GetTime()) then

                Client.GetModDetails(modId, ModDetailsCallback)
                currentlyDownloadingModDetails[modId] = Shared.GetTime() + 5

            end

            modTitles[#modTitles + 1] = downloadedModDetails[modId]

        end

        self.modsDesc:SetText(string.format("%s %d", Locale.ResolveString("SERVERBROWSER_SERVER_DETAILS_MODS"), modCount))
        self.modList:SetText(table.concat(modTitles, ", "))

    end
    
    self.serverDetailsWindow.SetServerData = function(self, serverData, serverIndex)

        if serverIndex >= 0 then
            Client.RequestServerDetails(serverIndex)
        end

        self.serverIndex = serverIndex
        
        for i = 1,  #self.playerEntries do
        
            self.playerEntries[#self.playerEntries]:Uninitialize()
            self.playerEntries[#self.playerEntries] = nil
        
        end
        
        self.serverName:SetText("")
        self.serverAddress:SetText(Locale.ResolveString("SERVERBROWSER_SERVER_DETAILS_ADDRESS"))
        self.playerCount:SetText(Locale.ResolveString("SERVERBROWSER_SERVER_DETAILS_PLAYERS"))
        self.spectatorCount:SetText(Locale.ResolveString("SERVERBROWSER_SERVER_DETAILS_SPECTATORS"))
        self.ping:SetText(Locale.ResolveString("SERVERBROWSER_SERVER_DETAILS_PING"))
        self.gameMode:SetText(Locale.ResolveString("SERVERBROWSER_SERVER_DETAILS_GAME"))
        self.map:SetText(Locale.ResolveString("SERVERBROWSER_SERVER_DETAILS_MAP"))
        self.modsDesc:SetText(Locale.ResolveString("SERVERBROWSER_SERVER_DETAILS_MODS"))
        self.modList:SetText("...")
        self.performance:SetText(Locale.ResolveString("SERVERBROWSER_SERVER_DETAILS_PERF"))
        
        if serverData then
    
            self.serverName:SetText(serverData.name)
            self.serverAddress:SetText(string.format("%s %s", Locale.ResolveString("SERVERBROWSER_SERVER_DETAILS_ADDRESS"), ToString(serverData.address)))
            local numReservedSlots = serverData.numRS or 0
            self.playerCount:SetText(string.format("%s %d / %d", Locale.ResolveString("SERVERBROWSER_SERVER_DETAILS_PLAYERS"), math.max(0, serverData.numPlayers), math.max(0, (serverData.maxPlayers - numReservedSlots))))
            self.spectatorCount:SetText(string.format("%s %d / %d", Locale.ResolveString("SERVERBROWSER_SERVER_DETAILS_SPECTATORS"), serverData.numSpectators, serverData.maxSpectators))
            self.ping:SetText(string.format("%s %d", Locale.ResolveString("SERVERBROWSER_SERVER_DETAILS_PING"), serverData.ping))
            self.gameMode:SetText(string.format("%s %s", Locale.ResolveString("SERVERBROWSER_SERVER_DETAILS_GAME"), serverData.mode))
            self.map:SetText(string.format("%s %s", Locale.ResolveString("SERVERBROWSER_SERVER_DETAILS_MAP"), serverData.map))
            
            self.favoriteIcon:SetIsVisible(serverData.favorite)
            self.blockedIcon:SetIsVisible(serverData.blocked)
            self.passwordedIcon:SetIsVisible(serverData.requiresPassword)
            self.performance:SetText( GetPerformanceText( serverData ) )

        end

        self:UpdateMods()
        self:UpdatePlayers()
    
    end  
    
    self.serverDetailsWindow.SetRefreshed = function(self)

        if self.serverIndex >= 0 then

            local serverName = FormatServerName(Client.GetServerName(self.serverIndex), Client.GetServerHasTag(self.serverIndex, "rookie_only"))

            self.serverName:SetText(serverName)
            self.serverAddress:SetText(string.format("%s %s", Locale.ResolveString("SERVERBROWSER_SERVER_DETAILS_ADDRESS"), ToString(GetServerAddress(self.serverIndex))))

            local numReservedSlots = GetNumServerReservedSlots(self.serverIndex)
            self.playerCount:SetText(string.format("%s %d / %d", Locale.ResolveString("SERVERBROWSER_SERVER_DETAILS_PLAYERS"), math.max(0, Client.GetServerNumPlayers(self.serverIndex)), math.max(0,Client.GetServerMaxPlayers(self.serverIndex) - numReservedSlots)))
            self.spectatorCount:SetText(string.format("%s %d / %d", Locale.ResolveString("SERVERBROWSER_SERVER_DETAILS_SPECTATORS"), Client.GetServerNumSpectators(self.serverIndex), Client.GetServerMaxSpectators(self.serverIndex)))
            self.ping:SetText(string.format("%s %d", Locale.ResolveString("SERVERBROWSER_SERVER_DETAILS_PING"), Client.GetServerPing(self.serverIndex)))
            self.gameMode:SetText(string.format("%s %s", Locale.ResolveString("SERVERBROWSER_SERVER_DETAILS_GAME"), FormatGameMode(Client.GetServerGameMode(self.serverIndex), Client.GetServerMaxPlayers(self.serverIndex))))
            self.map:SetText(string.format("%s %s",Locale.ResolveString("SERVERBROWSER_SERVER_DETAILS_MAP"), GetTrimmedMapName(Client.GetServerMapName(self.serverIndex))))

            self.performance:SetText( GetPerformanceTextFromIndex(self.serverIndex) )

            self.passwordedIcon:SetIsVisible(Client.GetServerRequiresPassword(self.serverIndex))

            self:UpdatePlayers()
            self:UpdateMods()

    
        end
    
    end
    
    self.serverDetailsWindow.slideBar:AddCSSClass("window_scroller_playernames")
    self.serverDetailsWindow:ResetSlideBar()

    self.serverDetailsWindow:SetLayer(kGUILayerMainMenuServerDetails)
end

function GUIMainMenu:CreateServerListWindow()

    self.highlightServer = CreateMenuElement(self.serverBrowserWindow:GetContentBox(), "Image")
    self.highlightServer:SetCSSClass("highlight_server")
    self.highlightServer:SetIgnoreEvents(true)
    self.highlightServer:SetIsVisible(false)
    
    self.blinkingArrow = CreateMenuElement(self.highlightServer, "Image")
    self.blinkingArrow:SetCSSClass("blinking_arrow")
    self.blinkingArrow:GetBackground():SetInheritsParentStencilSettings(false)
    self.blinkingArrow:GetBackground():SetStencilFunc(GUIItem.Always)
    
    self.selectServer = CreateMenuElement(self.serverBrowserWindow:GetContentBox(), "Image")
    self.selectServer:SetCSSClass("select_server")
    self.selectServer:SetIsVisible(false)
    self.selectServer:SetIgnoreEvents(true)
    
    self.serverRowNames = CreateMenuElement(self.serverBrowserWindow, "Table")
    self.serverList = CreateMenuElement(self.serverBrowserWindow:GetContentBox(), "ServerList")
    
    local columnClassNames =
    {
        "rank",
        "favorite",
        "blocked",
        "private",
        "skill",
        "servername",
        "game",
        "map",
        "players",
        "spectators",
        "rate",
        "ping"
    }
    
    local rowNames = { { Locale.ResolveString("SERVERBROWSER_RANK"), Locale.ResolveString("SERVERBROWSER_FAVORITE"), Locale.ResolveString("SERVERBROWSER_BLOCKED"), Locale.ResolveString("SERVERBROWSER_PRIVATE"), Locale.ResolveString("SERVERBROWSER_SKILL"), Locale.ResolveString("SERVERBROWSER_NAME"), Locale.ResolveString("SERVERBROWSER_GAME"), Locale.ResolveString("SERVERBROWSER_MAP"), Locale.ResolveString("SERVERBROWSER_PLAYERS"), Locale.ResolveString("SERVERBROWSER_SPECTATORS"), Locale.ResolveString("SERVERBROWSER_PERF"), Locale.ResolveString("SERVERBROWSER_PING") } }
    
    local serverList = self.serverList

    -- sorttype and the index inside the table need to match otherwise setting the default sorting won't work anymore
    local entryCallbacks = {
        { OnClick = function() serverList:SetComparator(SortByRating, true, 1) end },
        { OnClick = function() serverList:SetComparator(SortByFavorite, nil, 2) end },
        { OnClick = function() serverList:SetComparator(SortByBlocked, nil, 14) end },
        { OnClick = function() serverList:SetComparator(SortByPrivate, nil, 3) end },
        { OnClick = function() serverList:SetComparator(SortByPlayerSkill, nil, 11) end },
        { OnClick = function() serverList:SetComparator(SortByName, nil, 4) end },
        { OnClick = function() serverList:SetComparator(SortByMode, nil, 5) end },
        { OnClick = function() serverList:SetComparator(SortByMap, nil, 6) end },
        { OnClick = function() serverList:SetComparator(SortByPlayers, nil, 7) end },
        { OnClick = function() serverList:SetComparator(SortBySpectators, nil, 8) end },
        { OnClick = function() serverList:SetComparator(SortByPerformance, nil, 9) end },
        { OnClick = function() serverList:SetComparator(SortByPing, nil, 10) end }
    }

    --Default sorting
    local selected =  Client.GetOptionInteger("currentServerBrowerComparator", 1)
    if selected < 1 or selected > #entryCallbacks then
        selected = 1
    end
    entryCallbacks[selected].OnClick()
    
    self.serverRowNames:SetCSSClass("server_list_row_names")
    self.serverRowNames:AddCSSClass("server_list_names")
    self.serverRowNames:SetColumnClassNames(columnClassNames)
    self.serverRowNames:SetEntryCallbacks(entryCallbacks)
    self.serverRowNames:SetRowPattern( { SERVERBROWSER_RANK, RenderServerNameEntry, RenderServerNameEntry, RenderServerNameEntry, RenderServerNameEntry, RenderServerNameEntry, RenderServerNameEntry, RenderServerNameEntry, RenderServerNameEntry, RenderServerNameEntry, } )
    self.serverRowNames:SetTableData(rowNames)
    
    self.serverBrowserWindow:AddEventCallbacks({
        OnShow = function()
            self.serverBrowserWindow:ResetSlideBar()
            self:UpdateServerList()
        end
    })
    
    self:CreateFilterForm()
    self:CreatePlayFooter()
    
    self.serverTabs = CreateMenuElement(self.serverBrowserWindow, "ServerTabs", true)
    self.serverTabs:SetCSSClass("main_server_tabs")
    self.serverTabs:SetServerList(self.serverList)

end

function GUIMainMenu:ResetServerSelection()
    
    self.selectServer:SetIsVisible(false)
    MainMenu_SelectServer(nil, nil)
    
end

local function SaveServerSettings(formData)

    Client.SetOptionString("serverName", formData.ServerName)
    Client.SetOptionString("mapName", formData.Map)
    Client.SetOptionString("lastServerMapName", formData.Map)
    Client.SetOptionString("gameMod", formData.GameMode)
    Client.SetOptionInteger("playerLimit", formData.PlayerLimit)
    Client.SetOptionString("serverPassword", formData.Password)
    
end

local function CreateServer(self)

    local formData = self.createServerForm:GetFormData()
    SaveServerSettings(formData)
    
    local modIndex      = self.createServerForm.modIds[formData.Map_index]
    local password      = formData.Password
    local port          = tonumber(formData.Port)
    local maxPlayers    = formData.PlayerLimit
    local serverName    = formData.ServerName

    if formData.Bots == Locale.ResolveString("YES") then
        Client.SetOptionBoolean("botsSettings_enableBots", true)
    end
    
    if modIndex == 0 then
        local mapName = formData.GameMode .. "_" .. string.lower(formData.Map)
        if Client.StartServer(mapName, serverName, password, port, maxPlayers) then
            LeaveMenu()
        end
    else
        if Client.StartServer(modIndex, serverName, password, port, maxPlayers) then
            LeaveMenu()
        end
    end
    
end
 
local function GetMaps()

    Client.RefreshModList()
    
    local mapNames = { }
    local modIds   = { }
    
    -- First add all of the maps that ship with the game into the list.
    -- These maps don't have corresponding mod ids since they are loaded
    -- directly from the main game.
    local shippedMaps = MainMenu_GetMapNameList()
    for i = 1, #shippedMaps do
        mapNames[i] = shippedMaps[i]
        modIds[i]   = 0
    end
    
    -- TODO: Add levels from mods we have installed
    
    return mapNames, modIds

end

function GUIMainMenu:RepositionOptionsForm(options,offset)
	
    local optionElements = self.optionElements
    local rowHeight = 50
	
    for i = 1, #options do
    
        local option = options[i]
        local y = rowHeight * (i + offset - 1)
		 
        optionElements[option.name]:SetTopOffset(y)
		optionElements[option.name].label:SetTopOffset(y)
		if optionElements[option.name].input_display then
			optionElements[option.name].input_display:SetTopOffset(y)
		end

    end
end
	
	
	
GUIMainMenu.CreateOptionsForm = function(mainMenu, content, options, optionElements)

    local form = CreateMenuElement(content, "Form", false)
    
    local rowHeight = 50
    
    for i = 1, #options do
    
        local option = options[i]
        local input
        local input_display
        local defaultInputClass = "option_input"
        
        local y = rowHeight * (i - 1)
        
        if option.type == "select" then
            input = form:CreateFormElement(Form.kElementType.DropDown, option.name, option.value)
            if option.values then
                input:SetOptions(option.values)
            end                
        elseif option.type == "slider" then
            --Todo: This should be replaced with a proper SlideBar class ...

            input = form:CreateFormElement(Form.kElementType.SlideBar, option.name, option.value)			
            input_display = form:CreateFormElement(Form.kElementType.TextInput, option.name, option.value)
            input_display:SetNumbersOnly(true)    
            input_display:SetXAlignment(GUIItem.Align_Min)
            input_display:SetMarginLeft(5)
            if option.formName and option.formName == "sound" then
                input_display:SetCSSClass("display_sound_input")
            else
                input_display:SetCSSClass("display_input")
            end
            input_display:SetTopOffset(y)
            input_display:SetValue(ToString( input:GetValue() ))
            input_display:AddEventCallbacks({ 
                
            OnEnter = function(self)
                if input_display:GetValue() ~= "" and input_display:GetValue() ~= "." then
                    if option.name == "Sensitivity" then
                        input:SetValue((input_display:GetValue() - kMinSensitivity) / (kMaxSensitivity - kMinSensitivity))
                    elseif option.name == "AccelerationAmount" then
                        input:SetValue(input_display:GetValue())
                    elseif option.name == "FOVAdjustment" then
                        input:SetValue(input_display:GetValue() / 20)
                    elseif option.name == "Gamma" then
                        input:SetValue((input_display:GetValue() - Client.MinRenderGamma) /
                                (Client.MaxRenderGamma - Client.MinRenderGamma))
                    else
                        input:SetValue(input_display:GetValue())
                    end
                end
                if input_display:GetValue() == "" or input_display:GetValue() == "." then
                    if option.name == "Sensitivity" then
                        input_display:SetValue(string.sub(OptionsDialogUI_GetMouseSensitivity(), 0, 4))
                    elseif option.name == "AccelerationAmount" then
                        input_display:SetValue(string.sub(input:GetValue(), 0, 4))
                    elseif option.name == "FOVAdjustment" then
                        input_display:SetValue(string.format("%.0f", input:GetValue() * 20))
                    elseif option.name == "Gamma" then
                        input_display:SetValue(string.format("%.1f", Client.MinRenderGamma + input:GetValue() *
                            (Client.MaxRenderGamma - Client.MinRenderGamma)))
                    else
                        input_display:SetValue(string.sub(input:GetValue(),0, 4))
                    end
                end
            
            end,
            OnBlur = function(self)
                if input_display:GetValue() ~= "" and input_display:GetValue() ~= "." then
                    if option.name == "Sensitivity" then
                        input:SetValue((input_display:GetValue() - kMinSensitivity) / (kMaxSensitivity - kMinSensitivity))
                    elseif option.name == "AccelerationAmount" then
                        input:SetValue(input_display:GetValue())
                    elseif option.name == "FOVAdjustment" then
                        input:SetValue(input_display:GetValue() / 20)
                    elseif option.name == "Gamma" then
                        input:SetValue((input_display:GetValue() - Client.MinRenderGamma) /
                                (Client.MaxRenderGamma - Client.MinRenderGamma))
                    else
                        input:SetValue(input_display:GetValue())
                    end
                end
                
                if input_display:GetValue() == "" or input_display:GetValue() == "." then
                    if option.name == "Sensitivity" then
                        input_display:SetValue(string.sub(OptionsDialogUI_GetMouseSensitivity(), 0, 4))
                    elseif option.name == "AccelerationAmount" then
                        input_display:SetValue(string.sub(input:GetValue(), 0, 4))
                    elseif option.name == "FOVAdjustment" then
                        input_display:SetValue(string.format("%.0f", input:GetValue() * 20))
                    elseif option.name == "Gamma" then
                        input_display:SetValue(string.format("%.1f", Client.MinRenderGamma + input:GetValue() *
                                (Client.MaxRenderGamma - Client.MinRenderGamma)))
                    else
                        input_display:SetValue(ToString(string.sub(input:GetValue(), 0, 4)))
                    end
                end
            end,
            })
            -- HACK: Really should use input:AddSetValueCallback, but the slider bar bypasses that.
            if option.sliderCallback then
                input:Register(
                    {OnSlide =
                        function(value, interest)
                            option.sliderCallback(mainMenu)
                            if option.name == "Sensitivity" then
                                input_display:SetValue(string.sub(OptionsDialogUI_GetMouseSensitivity(), 0, 4))
                            elseif option.name == "AccelerationAmount" then
                                input_display:SetValue(string.sub(input:GetValue(), 0, 4))
                            elseif option.name == "FOVAdjustment" then
                                input_display:SetValue(string.format("%.0f", input:GetValue() * 20))
                            elseif option.name == "Gamma" then
                                input_display:SetValue(string.format("%.1f", Client.MinRenderGamma + input:GetValue() *
                                        (Client.MaxRenderGamma - Client.MinRenderGamma)))
                            else
                                input_display:SetValue(string.sub(input:GetValue(),0, 4))
                            end
                        end
                    }, SLIDE_HORIZONTAL)
            end
        elseif option.type == "progress" then
            input = form:CreateFormElement(Form.kElementType.ProgressBar, option.name, option.value)       
        elseif option.type == "checkbox" then
            input = form:CreateFormElement(Form.kElementType.Checkbox, option.name, option.value)
            defaultInputClass = "option_checkbox"
        elseif option.type == "numberBox" then
            input = form:CreateFormElement(Form.kElementType.TextInput, option.name, option.value)
            input:SetNumbersOnly(true)
            if option.length then
                input:SetMaxLength(option.length)
            end
        else
            input = form:CreateFormElement(Form.kElementType.TextInput, option.name, option.value)
        end
        
        if option.callback then
            input:AddSetValueCallback(option.callback)
        end
        local inputClass = defaultInputClass
        if option.inputClass then
            inputClass = option.inputClass
        end
        
        input:SetCSSClass(inputClass)
        input:SetTopOffset(y)

        for index, child in ipairs(input:GetChildren()) do
            -- Hitsounds preview, remove menu sound click callback and add the hitsound
            if option.name == "HitSoundVolume" then
                child.clickCallbacks = {}
                table.insert(child.clickCallbacks, function(self) HitSounds_PlayHitsound(1) end)
            end
            
            child:AddEventCallbacks({ 
                OnMouseOver = function(self)
                    if gMainMenu ~= nil then
                        local text = option.tooltip
                        if text ~= nil then
                            gMainMenu.optionTooltip:SetText(text)
                            gMainMenu.optionTooltip:Show()
                        else
                            gMainMenu.optionTooltip:Hide()
                        end
                    end    
                end,
              
                OnMouseOut = function(self)
                    if gMainMenu ~= nil then
                        gMainMenu.optionTooltip:Hide()
                    end
                end,
                })
        end

        local label = CreateMenuElement(form, "Font", false)
        label:SetCSSClass("option_label")
        label:SetText(option.label .. ":")
        label:SetTopOffset(y)
        label:SetIgnoreEvents(false)
        
        optionElements[option.name] = input
		optionElements[option.name].label = label
		optionElements[option.name].input_display = input_display
    end
    
    form:SetCSSClass("options")

    return form

end

function GUIMainMenu:CreateHostGameWindow()

    self.createGame:AddEventCallbacks({ OnHide = function()
            SaveServerSettings(self.createServerForm:GetFormData())
            end })

    local minPlayers            = 2
    local maxPlayers            = 24
    local playerLimitOptions    = { }
    
    for i = minPlayers, maxPlayers do
        table.insert(playerLimitOptions, i)
    end

    local gameModes = CreateServerUI_GetGameModes()

    local hostOptions = 
        {
            {   
                name   = "ServerName",            
                label  = Locale.ResolveString("SERVERBROWSER_SERVERNAME"),
                value  = Client.GetOptionString("serverName", "NS2 Listen Server")
            },
            {   
                name   = "Password",            
                label  = Locale.ResolveString("SERVERBROWSER_CREATE_PASSWORD"),
                value  = Client.GetOptionString("serverPassword", "")
            },
            {
                name    = "Port",
                label   = Locale.ResolveString("SERVERBROWSER_CREATE_PORT"),
                type      = "numberBox",
                length     = 5,
                value   = Client.GetOptionString("listenPort", "27015")
            },
            {
                name    = "Map",
                label   = Locale.ResolveString("SERVERBROWSER_MAP"),
                type    = "select",
                value  = Client.GetOptionString("mapName", "Summit")
            },
            {
                name    = "GameMode",
                label   = Locale.ResolveString("SERVERBROWSER_CREATE_GAME_MODE"),
                type    = "select",
                values  = gameModes,
                value   = gameModes[CreateServerUI_GetGameModesIndex()]
            },
            {
                name    = "PlayerLimit",
                label   = Locale.ResolveString("SERVERBROWSER_CREATE_PLAYER_LIMIT"),
                type    = "select",
                values  = playerLimitOptions,
                value   = Client.GetOptionInteger("playerLimit", 16)
            },
            {
                name    = "Bots",
                label   = Locale.ResolveString("SERVERBROWSER_CREATE_ADD_BOTS"),
                type    = "select",
                values  = { Locale.ResolveString("NO"), Locale.ResolveString("YES") },
                value = Client.GetOptionBoolean("botsSettings_enableBots", false) and Locale.ResolveString("YES") or Locale.ResolveString("NO")
            },
        }
        
    local createdElements = {}
    
    local content = self.createGame
    local createServerForm = GUIMainMenu.CreateOptionsForm(self, content, hostOptions, createdElements)
    
    self.createServerForm = createServerForm
    self.createServerForm:SetCSSClass("createserver")
    
    local mapList = createdElements.Map
    
    self.hostGameButton = CreateMenuElement(self.createGame, "MenuButton")
    self.hostGameButton:SetCSSClass("apply")
    self.hostGameButton:SetText(Locale.ResolveString("MENU_CREATE"))

    self.hostGameButton:AddEventCallbacks({
             OnClick = function (self) CreateServer(self.scriptHandle) end
        })

    self.createGame:AddEventCallbacks({
             OnShow = function (self)
                local mapNames
                mapNames, createServerForm.modIds = GetMaps()
                mapList:SetOptions( mapNames )
            end
        })
    
end

local function InitKeyBindings(keyInputs)

    local bindingsTable = BindingsUI_GetBindingsTable()
    for b = 1, #bindingsTable do
    
        if bindingsTable[b].current == "None" then
            keyInputs[b]:SetValue("")
        else
            keyInputs[b]:SetValue(bindingsTable[b].current)
        end
        
    end
    
end

local function InitKeyBindingsCom(keyInputsCom)

    local bindingsTableCom = BindingsUI_GetComBindingsTable()
    for c = 1, #bindingsTableCom do
        if bindingsTableCom[c].current == "None" then
            keyInputsCom[c]:SetValue("")
        else
            keyInputsCom[c]:SetValue(bindingsTableCom[c].current)
        end
    end  
    
end

local function CheckForConflictedKeys(keyInputs)

    -- Reset back to non-conflicted state.
    for k = 1, #keyInputs do
        keyInputs[k]:SetCSSClass("option_input")
    end
    
    -- Check for conflicts.
    for k1 = 1, #keyInputs do
    
        for k2 = 1, #keyInputs do
        
            if k1 ~= k2 then
            
                local boundKey1 = Client.GetOptionString("input/" .. keyInputs[k1].inputName, "")
                local boundKey2 = Client.GetOptionString("input/" .. keyInputs[k2].inputName, "")
                if (boundKey1 ~= "None" and boundKey2 ~= "None") and boundKey1 == boundKey2 then
                
                    keyInputs[k1]:SetCSSClass("option_input_conflict")
                    keyInputs[k2]:SetCSSClass("option_input_conflict")
                    
                end
                
            end
            
        end
        
    end
    
end

local function CreateKeyBindingsForm(mainMenu, content)

    local keyBindingsForm = CreateMenuElement(content, "Form", false)
    
    local bindingsTable = BindingsUI_GetBindingsTable()
    
    mainMenu.keyInputs = { }
    
    local rowHeight = 50
    
    for b = 1, #bindingsTable do
    
        local binding = bindingsTable[b]
        
        local keyInput = keyBindingsForm:CreateFormElement(Form.kElementType.FormButton, "INPUT" .. b, binding.current)
        keyInput:SetCSSClass("option_input")
        keyInput:AddEventCallbacks( { OnBlur = function(self) keyInput.ignoreFirstKey = nil end } )
        
        function keyInput:OnSendKey(key, down)
        
           if not down and key ~= InputKey.Escape then
            
                -- We want to ignore the click that gave this input focus.
                if keyInput.ignoreFirstKey == true then
                
                    local keyString = Client.ConvertKeyCodeToString(key)
                    keyInput:SetValue(keyString)
                    
                    Client.SetOptionString("input/" .. keyInput.inputName, keyString)
                    
                    CheckForConflictedKeys(mainMenu.keyInputs)
                    
                    GetWindowManager():ClearActiveElement(self)
                    
                    keyInput.ignoreFirstKey = false
                    
                else
                    keyInput.ignoreFirstKey = true
                end
                
            end
            
        end
        
        function keyInput:OnMouseWheel(up)
            if up then
                self:OnSendKey(InputKey.MouseWheelUp, false)
            else
                self:OnSendKey(InputKey.MouseWheelDown, false)
            end
        end
        
        local clearKeyInput = CreateMenuElement(keyBindingsForm, "MenuButton", false)
        clearKeyInput:SetCSSClass("clear_keybind")
        clearKeyInput:SetText("x")
        
        function clearKeyInput:OnClick()
            Client.SetOptionString("input/" .. keyInput.inputName, "None")
            keyInput:SetValue("")
            CheckForConflictedKeys(mainMenu.keyInputs)
        end

        local keyInputText = CreateMenuElement(keyBindingsForm, "Font", false)
        keyInputText:SetText(string.UTF8Upper(binding.detail) ..  ":")
        keyInputText:SetCSSClass("option_label")
        
        local y = rowHeight * (b  - 1)
        
        keyInput:SetTopOffset(y)
        keyInputText:SetTopOffset(y)
        clearKeyInput:SetTopOffset(y)
        
        keyInput.inputName = binding.name
        table.insert(mainMenu.keyInputs, keyInput)
        
    end
    
    InitKeyBindings(mainMenu.keyInputs)
    
    CheckForConflictedKeys(mainMenu.keyInputs)
    
    keyBindingsForm:SetCSSClass("keybindings")
    
    return keyBindingsForm
    
end

local function CreateKeyBindingsFormCom(mainMenu, content)

    local keyBindingsFormCom = CreateMenuElement(content, "Form", false)
    
    local bindingsTableCom = BindingsUI_GetComBindingsTable()
    mainMenu.keyInputsCom = { }
    local rowHeight = 50
    
    for b = 1, #bindingsTableCom do
    
        local bindingCom = bindingsTableCom[b]
        
        local keyInputCom = keyBindingsFormCom:CreateFormElement(Form.kElementType.FormButton, "INPUT" .. b, bindingCom.current)
        keyInputCom:SetCSSClass("option_input")
        keyInputCom:AddEventCallbacks( { OnBlur = function(self) keyInputCom.ignoreFirstKey = nil end } )
        
        function keyInputCom:OnSendKey(key, down)
        
            if not down and key ~= InputKey.Escape then
            
                -- We want to ignore the click that gave this input focus.
                if keyInputCom.ignoreFirstKey == true then
                
                    local keyStringCom = Client.ConvertKeyCodeToString(key)
                    keyInputCom:SetValue(keyStringCom)
                    
                    Client.SetOptionString("input/" .. keyInputCom.inputName, keyStringCom)
                    
                    CheckForConflictedKeys(mainMenu.keyInputsCom)
                    
                end
                keyInputCom.ignoreFirstKey = true
                
            end
            
        end
        
        function keyInputCom:OnMouseWheel(up)
            if up then
                self:OnSendKey(InputKey.MouseWheelUp, false)
            else
                self:OnSendKey(InputKey.MouseWheelDown, false)
            end
        end
        
        local keyInputTextCom = CreateMenuElement(keyBindingsFormCom, "Font", false)
        keyInputTextCom:SetText(string.UTF8Upper(bindingCom.detail) ..  ":")
        keyInputTextCom:SetCSSClass("option_label")
        
        local clearKeyInput = CreateMenuElement(keyBindingsFormCom, "MenuButton", false)
        clearKeyInput:SetCSSClass("clear_keybind")
        clearKeyInput:SetText("x")
        
        function clearKeyInput:OnClick()
            Client.SetOptionString("input/" .. keyInputCom.inputName, "None")
            keyInputCom:SetValue("")
            CheckForConflictedKeys(mainMenu.keyInputsCom)
        end
        
        local y = rowHeight * (b  - 1)
        
        keyInputCom:SetTopOffset(y)
        keyInputTextCom:SetTopOffset(y)
        clearKeyInput:SetTopOffset(y)
        
        keyInputCom.inputName = bindingCom.name
        table.insert(mainMenu.keyInputsCom, keyInputCom)
        
    end

    InitKeyBindingsCom(mainMenu.keyInputsCom)
    CheckForConflictedKeys(mainMenu.keyInputsCom)
    
    keyBindingsFormCom:SetCSSClass("keybindings")
    
    return keyBindingsFormCom
    
end

local function InitOptions(self)
       
	local optionElements = self.optionElements
	
    local function BoolToIndex(value)
        if value then
            return 2
        end
        return 1
    end

    local nickName              = OptionsDialogUI_GetNickname()
    local useSteamName      = Client.GetOptionBoolean(kNicknameOverrideKey, false)
    local mouseSens             = (OptionsDialogUI_GetMouseSensitivity() - kMinSensitivity) / (kMaxSensitivity - kMinSensitivity)
    local mouseAcceleration     = Client.GetOptionBoolean("input/mouse/acceleration", false)
    local accelerationAmount    = (Client.GetOptionFloat("input/mouse/acceleration-amount", 1) - kMinAcceleration) / (kMaxAcceleration -kMinAcceleration)
    local invMouse              = OptionsDialogUI_GetMouseInverted()
    local rawInput              = Client.GetOptionBoolean("input/mouse/rawinput", true)
    local locale                = Client.GetOptionString( "locale", "enUS" )
    local showHints             = Client.GetOptionBoolean( "showHints", true )
    local enemyHealth            = Client.GetOptionBoolean( "enemyHealth", true )
    local drawDamage            = Client.GetOptionBoolean( "drawDamage", false )    
    local physicsMultithreading = Client.GetOptionBoolean( "physicsMultithreading", false)
    local resourceLoading       = Client.GetOptionInteger("system/resourceLoading", 1)
    local menuBackground        = Client.GetOptionInteger("menu/menuBackground", 1)
    local menuMusic             = Client.GetOptionInteger("menu/menuMusic", 1)
    
    local screenResIdx          = OptionsDialogUI_GetScreenResolutionsIndex()
    local visualDetailIdx       = OptionsDialogUI_GetVisualDetailSettingsIndex()
    local display               = OptionsDialogUI_GetDisplay()

    local windowMode            = table.find(kWindowModeIds, OptionsDialogUI_GetWindowModeId()) or 1
    local windowModes           = OptionsDialogUI_GetWindowModes()
    local windowModeOptionIndex = table.find(windowModes, windowMode) or 1
    
    local displayBuffering      = Client.GetOptionInteger("graphics/display/display-buffering", 0)
    local ambientOcclusion      = Client.GetOptionString("graphics/display/ambient-occlusion", kAmbientOcclusionModes[1])
    local reflections           = Client.GetOptionBoolean("graphics/reflections", false)
    local refractionQuality     = Client.GetOptionString("graphics/refractionQuality", "high")
    local particleQuality       = Client.GetOptionString("graphics/display/particles", "low")
    local infestation           = Client.GetOptionString("graphics/infestation", "minimal")
    local fovAdjustment         = Client.GetOptionFloat("graphics/display/fov-adjustment", 10)
    local cameraAnimation       = Client.GetOptionBoolean("CameraAnimation", false)
    local physicsGpuAcceleration = Client.GetOptionBoolean(kPhysicsGpuAccelerationKey, false)
    local decalLifeTime         = Client.GetOptionFloat("graphics/decallifetime", 0.2)
    local textureManagement     = Client.GetOptionInteger("graphics/textureManagement", 3)
    local atmoDensity           = Client.GetOptionFloat("graphics/atmospheric-density", 1.0)

    local minimapZoom           = Client.GetOptionFloat("minimap-zoom", 0.75)
    local hitsoundVolume        = Client.GetOptionFloat("hitsound-vol", 0.0)
    
    local hudmode               = Client.GetOptionInteger("hudmode", kHUDMode.Full)
        
    local lightQuality = Client.GetOptionInteger("graphics/lightQuality", 2)

    local gamma = Clamp(Client.GetOptionFloat("graphics/display/gamma", Client.DefaultRenderGammaAdjustment),
        Client.MinRenderGamma , Client.MaxRenderGamma)
    gamma = (gamma - Client.MinRenderGamma) / (Client.MaxRenderGamma - Client.MinRenderGamma)
    
    -- support legacy values    
    if ambientOcclusion == "false" then
        ambientOcclusion = "off"
    elseif ambientOcclusion == "true" then
        ambientOcclusion = "high"
    end
    
    local shadows = OptionsDialogUI_GetShadows()
    local bloom = OptionsDialogUI_GetBloom()
    local atmospherics = OptionsDialogUI_GetAtmospherics()
    local anisotropicFiltering = OptionsDialogUI_GetAnisotropicFiltering()
    local antiAliasing = OptionsDialogUI_GetAntiAliasing()
    
    local renderDevice = Client.GetOptionString("graphics/device", kRenderDevices[1])
    
    local soundInputDeviceGuid = Client.GetOptionString(kSoundInputDeviceOptionsKey, "Default")
    local soundOutputDeviceGuid = Client.GetOptionString(kSoundOutputDeviceOptionsKey, "Default")

    local soundInputDevice = 1
    if soundInputDeviceGuid ~= 'Default' then
        soundInputDevice = math.max(Client.FindSoundDeviceByGuid(Client.SoundDeviceType_Input, soundInputDeviceGuid), 0) + 2
    end
    
    local soundOutputDevice = 1
    if soundOutputDeviceGuid ~= 'Default' then
        soundOutputDevice = math.max(Client.FindSoundDeviceByGuid(Client.SoundDeviceType_Output, soundOutputDeviceGuid), 0) + 2
    end
    
    local soundVol = Client.GetOptionInteger("soundVolume", 90) / 100
    local musicVol = Client.GetOptionInteger("musicVolume", 90) / 100
    local voiceVol = Client.GetOptionInteger("voiceVolume", 90) / 100
    local recordingGain = Client.GetOptionFloat("recordingGain", 0.5)
    local recordingReleaseDelay = Client.GetOptionFloat("recordingReleaseDelay", 0.15)
    
    local muteWhenMinized = Client.GetOptionBoolean(kSoundMuteWhenMinized, true)
    
    for i = 1, #kLocales do
    
        if kLocales[i].name == locale then
            optionElements.Language:SetOptionActive(i)
        end
        
    end
	
    optionElements.NickName:SetValue( nickName )
	
    optionElements.NickNameOverride:SetOptionActive( BoolToIndex(useSteamName) )
		
	optionElements.NickName:SetIsVisible( useSteamName )
	optionElements.NickName.label:SetIsVisible( useSteamName )
	self:RepositionOptionsForm( self.generalOptionsDef, useSteamName and 0 or -1 )
	
    optionElements.Sensitivity:SetValue( mouseSens )
    optionElements.AccelerationAmount:SetValue( accelerationAmount )
    optionElements.MouseAcceleration:SetOptionActive( BoolToIndex(mouseAcceleration) )
    optionElements.InvertedMouse:SetOptionActive( BoolToIndex(invMouse) )
    optionElements.RawInput:SetOptionActive( BoolToIndex(rawInput) )
    optionElements.ShowHints:SetOptionActive( BoolToIndex(showHints) )
    optionElements.EnemyHealth:SetOptionActive( BoolToIndex(enemyHealth) )
    optionElements.DrawDamage:SetOptionActive( BoolToIndex(drawDamage) )
    optionElements.PhysicsMultithreading:SetOptionActive( BoolToIndex(physicsMultithreading) )
    optionElements.ResourceLoading:SetOptionActive( resourceLoading )

    optionElements.RenderDevice:SetOptionActive( table.find(kRenderDevices, renderDevice) )
    optionElements.Display:SetOptionActive( display + 1 )
    optionElements.WindowMode:SetOptionActive( windowModeOptionIndex )
    optionElements.DisplayBuffering:SetOptionActive( displayBuffering + 1 )
    optionElements.Resolution:SetOptionActive( screenResIdx )
    optionElements.Shadows:SetOptionActive( BoolToIndex(shadows) )
    optionElements.Infestation:SetOptionActive( table.find(kInfestationModes, infestation) )
    optionElements.Bloom:SetOptionActive( BoolToIndex(bloom) )
    optionElements.Atmospherics:SetOptionActive( BoolToIndex(atmospherics) )
    optionElements.AtmosphericDensity:SetValue(atmoDensity)
    optionElements.AnisotropicFiltering:SetOptionActive( BoolToIndex(anisotropicFiltering) )
    optionElements.AntiAliasing:SetOptionActive( BoolToIndex(antiAliasing) )
    optionElements.Detail:SetOptionActive(visualDetailIdx)
    optionElements.AmbientOcclusion:SetOptionActive( table.find(kAmbientOcclusionModes, ambientOcclusion) )
    optionElements.Reflections:SetOptionActive( BoolToIndex(reflections) )
    optionElements.RefractionQuality:SetOptionActive( table.find(kRefractionQualityModes, refractionQuality))
    optionElements.FOVAdjustment:SetValue(fovAdjustment)
    optionElements.MinimapZoom:SetValue(minimapZoom)
    optionElements.DecalLifeTime:SetValue(decalLifeTime)
    optionElements.CameraAnimation:SetOptionActive( BoolToIndex(cameraAnimation) )
    optionElements.PhysicsGpuAcceleration:SetOptionActive( BoolToIndex(physicsGpuAcceleration) )
    optionElements.ParticleQuality:SetOptionActive( table.find(kParticleQualityModes, particleQuality) ) 
    optionElements.TextureManagement:SetOptionActive( textureManagement )
    optionElements.LightQuality:SetOptionActive( lightQuality )
    optionElements.Gamma:SetValue(gamma)
    optionElements.MenuBackground:SetOptionActive(menuBackground)
    optionElements.MenuMusic:SetOptionActive(menuMusic)
    
    optionElements.SoundInputDevice:SetOptionActive(soundInputDevice)
    optionElements.SoundOutputDevice:SetOptionActive(soundOutputDevice)
    optionElements.SoundVolume:SetValue(soundVol)
    optionElements.MusicVolume:SetValue(musicVol)
    optionElements.VoiceVolume:SetValue(voiceVol)
    optionElements.HitSoundVolume:SetValue(hitsoundVolume)
    optionElements.RecordingGain:SetValue(recordingGain)
    optionElements.RecordingReleaseDelay:SetValue( recordingReleaseDelay )
    optionElements.MuteWhenMinized:SetOptionActive( BoolToIndex(muteWhenMinized) )
    
    optionElements.hudmode:SetValue(hudmode == 1 and Locale.ResolveString("HIGH") or Locale.ResolveString("LOW"))
    
end

local function SaveSecondaryGraphicsOptions(mainMenu)
    -- These are options that are pretty quick to change, unlike screen resolution etc.
    -- Have this separate, since graphics options are auto-applied

    local ambientOcclusionIdx   = mainMenu.optionElements.AmbientOcclusion:GetActiveOptionIndex()
    local visualDetailIdx       = mainMenu.optionElements.Detail:GetActiveOptionIndex()
    local infestationIdx        = mainMenu.optionElements.Infestation:GetActiveOptionIndex()
    local shadows               = mainMenu.optionElements.Shadows:GetActiveOptionIndex() > 1
    local bloom                 = mainMenu.optionElements.Bloom:GetActiveOptionIndex() > 1
    local atmospherics          = mainMenu.optionElements.Atmospherics:GetActiveOptionIndex() > 1
    local anisotropicFiltering  = mainMenu.optionElements.AnisotropicFiltering:GetActiveOptionIndex() > 1
    local antiAliasing          = mainMenu.optionElements.AntiAliasing:GetActiveOptionIndex() > 1
    local particleQualityIdx    = mainMenu.optionElements.ParticleQuality:GetActiveOptionIndex()
    local reflections           = mainMenu.optionElements.Reflections:GetActiveOptionIndex() > 1
    local refractionQuality     = mainMenu.optionElements.RefractionQuality:GetActiveOptionIndex()
    local renderDeviceIdx       = mainMenu.optionElements.RenderDevice:GetActiveOptionIndex()
    local lightQuality          = mainMenu.optionElements.LightQuality:GetActiveOptionIndex()
    local textureManagement     = mainMenu.optionElements.TextureManagement:GetActiveOptionIndex()
    local resourceLoading       = mainMenu.optionElements.ResourceLoading:GetActiveOptionIndex()

    Client.SetOptionBoolean("graphics/reflections", reflections)
    Client.SetOptionString("graphics/refractionQuality", kRefractionQualityModes[refractionQuality])
    Client.SetOptionString("graphics/display/ambient-occlusion", kAmbientOcclusionModes[ambientOcclusionIdx] )
    Client.SetOptionString("graphics/display/particles", kParticleQualityModes[particleQualityIdx] )
    Client.SetOptionString("graphics/infestation", kInfestationModes[infestationIdx] )
    Client.SetOptionInteger( kDisplayQualityOptionsKey, visualDetailIdx - 1 )
    Client.SetOptionBoolean ( kShadowsOptionsKey, shadows )
    Client.SetOptionBoolean ( kBloomOptionsKey, bloom )
    Client.SetOptionBoolean ( kAtmosphericsOptionsKey, atmospherics )
    Client.SetOptionBoolean ( kAnisotropicFilteringOptionsKey, anisotropicFiltering )
    Client.SetOptionBoolean ( kAntiAliasingOptionsKey, antiAliasing )
    Client.SetOptionString("graphics/device", kRenderDevices[renderDeviceIdx] )
    Client.SetOptionInteger("graphics/lightQuality", lightQuality)
    Client.SetOptionInteger("graphics/textureManagement", textureManagement)
    
end

local function SyncSecondaryGraphicsOptions()
    Render_SyncRenderOptions() 
    if Infestation_SyncOptions then
        Infestation_SyncOptions()
    end
    Input_SyncInputOptions()
end

local function OnGraphicsOptionsChanged(mainMenu)
    SaveSecondaryGraphicsOptions(mainMenu)
    Client.ReloadGraphicsOptions()
    SyncSecondaryGraphicsOptions()
end

local function OnSoundVolumeChanged(mainMenu)
    local soundVol = mainMenu.optionElements.SoundVolume:GetValue() * 100
    OptionsDialogUI_SetSoundVolume( soundVol )
end

local function OnMusicVolumeChanged(mainMenu)
    local musicVol = mainMenu.optionElements.MusicVolume:GetValue() * 100
    OptionsDialogUI_SetMusicVolume( musicVol )
end

local function OnVoiceVolumeChanged(mainMenu)
    local voiceVol = mainMenu.optionElements.VoiceVolume:GetValue() * 100
    OptionsDialogUI_SetVoiceVolume( voiceVol )
end

local function OnRecordingReleaseDelayChanged(mainMenu)
    local value = mainMenu.optionElements.RecordingReleaseDelay:GetValue()
    Client.SetOptionFloat("recordingReleaseDelay", value)
end

local function OnRecordingGainChanged(mainMenu)
    local recordingGain = mainMenu.optionElements.RecordingGain:GetValue()
    Client.SetRecordingGain(recordingGain)
    Client.SetOptionFloat("recordingGain", recordingGain)
end

local function OnSensitivityChanged(mainMenu)
    local value = mainMenu.optionElements.Sensitivity:GetValue()
    if value >= 0 then
        OptionsDialogUI_SetMouseSensitivity(value * (kMaxSensitivity - kMinSensitivity) + kMinSensitivity)
    end
end

local function OnAccelerationAmountChanged(mainMenu)
    local value = mainMenu.optionElements.AccelerationAmount:GetValue()
    Client.SetOptionFloat("input/mouse/acceleration-amount", value * (kMaxAcceleration - kMinAcceleration) + kMinAcceleration )
end

local function OnFOVAdjustChanged(mainMenu)
    local value = mainMenu.optionElements.FOVAdjustment:GetValue()
    Client.SetOptionFloat("graphics/display/fov-adjustment", value)
end

local function OnMinimapZoomChanged(mainMenu)

    local value = mainMenu.optionElements.MinimapZoom:GetValue()
    Client.SetOptionFloat("minimap-zoom", value)

    if SafeRefreshMinimapZoom then
        SafeRefreshMinimapZoom()
    end

end

local function OnHitSoundVolumeChanged(mainMenu)
   
    local value = mainMenu.optionElements.HitSoundVolume:GetValue()
    Client.SetOptionFloat("hitsound-vol", value)

    if HitSounds_SyncOptions then
        HitSounds_SyncOptions()
    end
    
end
    
function OnDisplayChanged(oldDisplay, newDisplay)

    if gMainMenu ~= nil and gMainMenu.optionElements ~= nil then
        gMainMenu.optionElements.Display:SetOptionActive( newDisplay + 1 )
    end
    
end

local function SaveOptions(mainMenu)

    local nickName              = mainMenu.optionElements.NickName:GetValue()
    local mouseSens             = mainMenu.optionElements.Sensitivity:GetValue() * (kMaxSensitivity - kMinSensitivity) + kMinSensitivity
    local mouseAcceleration     = mainMenu.optionElements.MouseAcceleration:GetActiveOptionIndex() > 1
    local accelerationAmount    = mainMenu.optionElements.AccelerationAmount:GetValue() * (kMaxAcceleration - kMinAcceleration) + kMinAcceleration
    local invMouse              = mainMenu.optionElements.InvertedMouse:GetActiveOptionIndex() > 1
    local rawInput              = mainMenu.optionElements.RawInput:GetActiveOptionIndex() > 1
    local locale                = kLocales[mainMenu.optionElements.Language:GetActiveOptionIndex()].name
    local showHints             = mainMenu.optionElements.ShowHints:GetActiveOptionIndex() > 1
    local enemyHealth           = mainMenu.optionElements.EnemyHealth:GetActiveOptionIndex() > 1
    local drawDamage            = mainMenu.optionElements.DrawDamage:GetActiveOptionIndex() > 1
    local physicsMultithreading = mainMenu.optionElements.PhysicsMultithreading:GetActiveOptionIndex() > 1
    local resourceLoading       = mainMenu.optionElements.ResourceLoading:GetActiveOptionIndex()
    
    local display               = mainMenu.optionElements.Display:GetActiveOptionIndex() - 1
    local screenResIdx          = mainMenu.optionElements.Resolution:GetActiveOptionIndex()
    local visualDetailIdx       = mainMenu.optionElements.Detail:GetActiveOptionIndex()
    local displayBuffering      = mainMenu.optionElements.DisplayBuffering:GetActiveOptionIndex() - 1
    
    local windowModeOptionIndex = mainMenu.optionElements.WindowMode:GetActiveOptionIndex()
    local windowMode            = OptionsDialogUI_GetWindowModes()[windowModeOptionIndex]

    local shadows               = mainMenu.optionElements.Shadows:GetActiveOptionIndex() > 1
    local bloom                 = mainMenu.optionElements.Bloom:GetActiveOptionIndex() > 1
    local atmospherics          = mainMenu.optionElements.Atmospherics:GetActiveOptionIndex() > 1
    local anisotropicFiltering  = mainMenu.optionElements.AnisotropicFiltering:GetActiveOptionIndex() > 1
    local antiAliasing          = mainMenu.optionElements.AntiAliasing:GetActiveOptionIndex() > 1
    local textureManagement     = mainMenu.optionElements.TextureManagement:GetActiveOptionIndex()
    local lightQuality          = mainMenu.optionElements.LightQuality:GetActiveOptionIndex()
    local particleQuality       = mainMenu.optionElements.ParticleQuality:GetActiveOptionIndex()
    
    local soundVol              = mainMenu.optionElements.SoundVolume:GetValue() * 100
    local musicVol              = mainMenu.optionElements.MusicVolume:GetValue() * 100
    local voiceVol              = mainMenu.optionElements.VoiceVolume:GetValue() * 100
    local muteWhenMinimized     = mainMenu.optionElements.MuteWhenMinized:GetActiveOptionIndex() > 1
    
    local hudmode               = mainMenu.optionElements.hudmode:GetValue()
    
    local cameraAnimation       = mainMenu.optionElements.CameraAnimation:GetActiveOptionIndex() > 1
    local physicsGpuAcceleration = mainMenu.optionElements.PhysicsGpuAcceleration:GetActiveOptionIndex() > 1
    
    local menuBackground        = mainMenu.optionElements.MenuBackground:GetActiveOptionIndex()
    local menuMusic             = mainMenu.optionElements.MenuMusic:GetActiveOptionIndex()
    
    Client.SetOptionBoolean("input/mouse/rawinput", rawInput)
    Client.SetOptionBoolean("input/mouse/acceleration", mouseAcceleration)
    Client.SetOptionBoolean("showHints", showHints)
    Client.SetOptionBoolean("enemyHealth", enemyHealth)
    Client.SetOptionBoolean("drawDamage", drawDamage)
    Client.SetOptionBoolean("physicsMultithreading", physicsMultithreading)
    Client.SetOptionInteger("system/resourceLoading", resourceLoading);
    
    Client.SetOptionBoolean("CameraAnimation", cameraAnimation)
    Client.SetOptionBoolean(kPhysicsGpuAccelerationKey, physicsGpuAcceleration)
    Client.SetOptionInteger("hudmode", hudmode == Locale.ResolveString("HIGH") and kHUDMode.Full or kHUDMode.Minimal)
    Client.SetOptionInteger("graphics/lightQuality", lightQuality)
    Client.SetOptionFloat("input/mouse/acceleration-amount", accelerationAmount)
    Client.SetOptionInteger("graphics/textureManagement", textureManagement)
    
    Client.SetOptionBoolean(kSoundMuteWhenMinized, muteWhenMinimized)
    
    if string.len(TrimName(nickName)) < 1 or not string.IsValidNickname(nickName) then
       
        nickName = GetNickName()
        mainMenu.optionElements.NickName:SetValue(nickName)

        MainMenu_SetAlertMessage("Invalid Nickname")
        
    end
    
    -- Some redundancy with ApplySecondaryGraphicsOptions here, no harm.
    OptionsDialogUI_SetValues(
        nickName,
        mouseSens,
        display,
        screenResIdx,
        visualDetailIdx,
        soundVol,
        musicVol,
        kWindowModeIds[windowMode],
        shadows,
        bloom,
        atmospherics,
        anisotropicFiltering,
        antiAliasing,
        invMouse,
        voiceVol)
        
    SaveSecondaryGraphicsOptions(mainMenu)
    Client.SetOptionInteger("graphics/display/display-buffering", displayBuffering)
    


    SyncSecondaryGraphicsOptions()
    
    for k = 1, #mainMenu.keyInputs do
    
        local keyInput = mainMenu.keyInputs[k]
        local value = keyInput:GetValue()
        if value == "" then
            value = "None"
        end
        Client.SetOptionString("input/" .. keyInput.inputName, value)
        
    end
    Client.ReloadKeyOptions()
    
    -- if the keybind manager exists, we'll need to update any displayed keybinds
    if GetKeybindDisplayManager then
        GetKeybindDisplayManager():UpdateAllBindings()
    end
    
    for l = 1, #mainMenu.keyInputsCom do
    
        local keyInputCom = mainMenu.keyInputsCom[l]
        local value = keyInputCom:GetValue()
        if value == "" then
            value = "None"
        end
        Client.SetOptionString("input/" .. keyInputCom.inputName, value)
        
    end
    Client.ReloadKeyOptions()

    -- This will reload the first three graphics settings
    OptionsDialogUI_ExitDialog()
    
    if locale ~= Client.GetOptionString("locale", "enUS") then
        Client.SetOptionString("locale", locale) 
        Client.RestartMain()
    end
    
    if menuBackground ~= Client.GetOptionInteger("menu/menuBackground", 1) then
        Client.SetOptionInteger("menu/menuBackground", menuBackground)
        Client.RestartMain()
    end
    
    if menuMusic ~= Client.GetOptionInteger("menu/menuMusic", 1) then
        Client.SetOptionInteger("menu/menuMusic", menuMusic)
        Client.RestartMain()
    end
    
end

local function UpdateUsingSteamName(formElement)
	local useSteamName = formElement:GetActiveOptionIndex() > 1
    Client.SetOptionBoolean( kNicknameOverrideKey, useSteamName )
	if gMainMenu then
		gMainMenu.optionElements.NickName:SetIsVisible( useSteamName )
		gMainMenu.optionElements.NickName.label:SetIsVisible( useSteamName )
		gMainMenu:RepositionOptionsForm( gMainMenu.generalOptionsDef, useSteamName and 0 or -1 )
	end
    OnSteamPersonaChanged() -- force an update
end
    
local function StoreCameraAnimationOption(formElement)
    Client.SetOptionBoolean("CameraAnimation", formElement:GetActiveOptionIndex() > 1)
end

local function StorePhysicsGpuAccelerationOption(formElement)
    Client.SetOptionBoolean(kPhysicsGpuAccelerationKey, formElement:GetActiveOptionIndex() > 1)
end

local function OnLightQualityChanged(formElement)

    Client.SetOptionInteger("graphics/lightQuality", formElement:GetActiveOptionIndex())
    
    if Lights_UpdateLightMode then
        Lights_UpdateLightMode()
    end
    
    if Client.GetIsConnected() then
    
        for _, onos in ientitylist(Shared.GetEntitiesWithClassname("Onos")) do            
            onos:RecalculateShakeLightList()        
        end
    
    end
    
    Render_SyncRenderOptions()
    
end

local function OnDecalLifeTimeChanged(mainMenu)

    local value = mainMenu.optionElements.DecalLifeTime:GetValue()
    Client.SetOptionFloat("graphics/decallifetime", value)
    
end

local function OnAtmosphericDensityChanged(mainMenu)

    local value = mainMenu.optionElements.AtmosphericDensity:GetValue()
    Client.SetOptionFloat("graphics/atmospheric-density", value)
    if Client and Client.lightList then
        ApplyAtmosphericDensity()
    end
    
end

local function OnGammaChanged(mainMenu)

    local value = mainMenu.optionElements.Gamma:GetValue()
    value = Client.MinRenderGamma + value * ( Client.MaxRenderGamma  - Client.MinRenderGamma )

    Client.SetOptionFloat("graphics/display/gamma", value)
    Client.SetRenderGammaAdjustment(value)
    Render_SyncRenderOptions()
    
end

local function OnSoundDeviceChanged(window, formElement, deviceType)

    if formElement.inSoundCallback then
        return
    end

    local activeOptionIndex = formElement:GetActiveOptionIndex()
    
    if activeOptionIndex == 1 then
        if Client.GetSoundDeviceCount(deviceType) > 0 then
            Client.SetSoundDevice(deviceType, 0)
        end
        
        if deviceType == Client.SoundDeviceType_Input then
            Client.SetOptionString(kSoundInputDeviceOptionsKey, 'Default')
        elseif deviceType == Client.SoundDeviceType_Output then
            Client.SetOptionString(kSoundOutputDeviceOptionsKey, 'Default')
        end        
        return
    end
    
    local deviceId = activeOptionIndex - 2

    -- Get GUIDs of all audio devices
    local numDevices = Client.GetSoundDeviceCount(deviceType)
    local guids = {}
    for id = 1, numDevices do
        guids[id] = Client.GetSoundDeviceGuid(deviceType, id - 1)
    end

    local desiredGuid = guids[deviceId + 1]
    Client.SetSoundDevice(deviceType, deviceId)

    -- Check if GUIDs are still the same, update the list in process
    local newNumDevices = Client.GetSoundDeviceCount(deviceType)
    local listChanged = numDevices ~= newNumDevices
    numDevices = newNumDevices
    
    for id = 1, numDevices do
        local guid = Client.GetSoundDeviceGuid(deviceType, id - 1)
        if guids[id] ~= guid then
            listChanged = true
            guids[id] = guid
        end
    end
    
    if listChanged then
        -- Device list order changed        
        -- Avoid re-entering this callback
        formElement.inSoundCallback = true
        
        local soundOutputDevices = OptionsDialogUI_GetSoundDeviceNames(deviceType)
        formElement:SetOptions(soundOutputDevices)
        
        -- Find the GUID we were trying to select again
        deviceId = Client.FindSoundDeviceByGuid(deviceType, desiredGuid)
        
        if deviceId == -1 then
            deviceId = 0
        end
        
        formElement:SetOptionActive(deviceId + 1)
        Client.SetSoundDevice(deviceType, deviceId)
        
        formElement.inSoundCallback = false
    end
    
    window:UpdateRestartMessage()

    guid = guids[deviceId + 1]
    if guid == nil then
        Print('Warning: device %d (type %d) has invalid GUID', deviceId, deviceType)
        guid = ''
    end
    if deviceType == Client.SoundDeviceType_Input then
        Client.SetOptionString(kSoundInputDeviceOptionsKey, guid)
    elseif deviceType == Client.SoundDeviceType_Output then
        Client.SetOptionString(kSoundOutputDeviceOptionsKey, guid)
    end
    
end

function GUIMainMenu:CreateOptionWindow()

    self.optionWindow = self:CreateWindow()
    self.optionWindow:DisableCloseButton()
    self.optionWindow:SetCSSClass("option_window")
    
    self:SetupWindow(self.optionWindow, "OPTIONS")
    local function InitOptionWindow()
    
        InitOptions(self)
        InitKeyBindings(self.keyInputs)
        InitKeyBindingsCom(self.keyInputsCom)
        
    end
    self.optionWindow:AddEventCallbacks( {
        OnHide = function(self)
            InitOptionWindow()
        end
    } )
    
    local content = self.optionWindow:GetContentBox()
    
    local back = CreateMenuElement(self.optionWindow, "MenuButton")
    back:SetCSSClass("back")
    back:SetText(Locale.ResolveString("BACK"))
    back:AddEventCallbacks( { OnClick = function() self.optionWindow:SetIsVisible(false) end } )
    
    local apply = CreateMenuElement(self.optionWindow, "MenuButton")
    apply:SetCSSClass("apply")
    apply:SetText(Locale.ResolveString("MENU_APPLY"))
    apply:AddEventCallbacks( { OnClick = function() SaveOptions(self) end } )

    self.fpsDisplay = CreateMenuElement( self.optionWindow, "MenuButton" )
    self.fpsDisplay:SetCSSClass("fps") 
    
    self.warningLabel = CreateMenuElement(self.optionWindow, "MenuButton", false)
    self.warningLabel:SetCSSClass("warning_label")
    self.warningLabel:SetText(Locale.ResolveString("GAME_RESTART_REQUIRED"))
    self.warningLabel:SetIgnoreEvents(true)
    self.warningLabel:SetIsVisible(false)

    local displays = OptionsDialogUI_GetDisplays()    
    local windowModes = OptionsDialogUI_GetWindowModes()
    local windowModeNames = {}
    for i = 1, #windowModes do
        table.insert(windowModeNames, kWindowModeNames[windowModes[i]])
    end 

    local screenResolutions = OptionsDialogUI_GetScreenResolutions()
    local soundOutputDevices = OptionsDialogUI_GetSoundDeviceNames(Client.SoundDeviceType_Output)
    local soundInputDevices = OptionsDialogUI_GetSoundDeviceNames(Client.SoundDeviceType_Input)
    
    local languages = { }
    for i = 1,#kLocales do
        languages[i] = kLocales[i].label
    end
    
    local generalOptions =
        {
            { 
                name    = "NickName",
                label   = Locale.ResolveString("NICKNAME"),
            },
            { 
                name    = "NickNameOverride",
                label   = Locale.ResolveString("NS2NICKNAME"),
                type    = "select",
                values  = { Locale.ResolveString("YES"), Locale.ResolveString("NO") },
                callback = UpdateUsingSteamName
            },
            {
                name    = "Language",
                label   = Locale.ResolveString("LANGUAGE"),
                type    = "select",
                values  = languages,
            },
            { 
                name    = "Sensitivity",
                label   = Locale.ResolveString("MOUSE_SENSITIVITY"),
                type    = "slider",
                sliderCallback = OnSensitivityChanged,
            },
            {
                name    = "InvertedMouse",
                label   = Locale.ResolveString("REVERSE_MOUSE"),
                type    = "select",
                values  = { Locale.ResolveString("NO"), Locale.ResolveString("YES") }
            },
            {
                name    = "MouseAcceleration",
                label   = Locale.ResolveString("MOUSE_ACCELERATION"),
                type    = "select",
                values  = { Locale.ResolveString("OFF"), Locale.ResolveString("ON") }
            },
            {
                name    = "AccelerationAmount",
                label   = Locale.ResolveString("ACCELERATION_AMOUNT"),
                type    = "slider",
                sliderCallback = OnAccelerationAmountChanged,
            },
            {
                name    = "RawInput",
                label   = Locale.ResolveString("RAW_INPUT"),
                type    = "select",
                values  = { Locale.ResolveString("OFF"), Locale.ResolveString("ON") }
            },
            {
                name    = "ShowHints",
                label   = Locale.ResolveString("SHOW_HINTS"),
                tooltip = Locale.ResolveString("OPTION_SHOW_HINTS"),
                type    = "select",
                values  = { Locale.ResolveString("NO"), Locale.ResolveString("YES") }
            },
            {
                name    = "EnemyHealth",
                label   = Locale.ResolveString("ENEMY_HEALTH_BARS"),
                tooltip = Locale.ResolveString("OPTION_ENEMY_HEALTH"),
                type    = "select",
                values  = { Locale.ResolveString("NO"), Locale.ResolveString("YES") }
            },
            {
                name    = "DrawDamage",
                label   = Locale.ResolveString("DRAW_DAMAGE"),
                tooltip = Locale.ResolveString("OPTION_DRAW_DAMAGE"),
                type    = "select",
                values  = { Locale.ResolveString("NO"), Locale.ResolveString("YES") }
            },
            { 
                name    = "FOVAdjustment",
                label   = Locale.ResolveString("FOV_ADJUSTMENT"),
                type    = "slider",
                sliderCallback = OnFOVAdjustChanged,
            },
            { 
                name    = "MinimapZoom",
                label   = Locale.ResolveString("MINIMAP_ZOOM"),
                type    = "slider",
                sliderCallback = OnMinimapZoomChanged,
            },
            {
                name    = "CameraAnimation",
                label   = Locale.ResolveString("CAMERA_ANIMATION"),
                tooltip = Locale.ResolveString("OPTION_CAMERA_ANIMATION"),
                type    = "select",
                values  = { Locale.ResolveString("OFF"), Locale.ResolveString("ON") },
                callback = StoreCameraAnimationOption
            }, 
            {
                name    = "hudmode",
                label   = Locale.ResolveString("HUD_DETAIL"),
                tooltip = Locale.ResolveString("OPTION_HUDQUALITY"),
                type    = "select",
                values  = { Locale.ResolveString("HIGH"), Locale.ResolveString("LOW") },
                callback = autoApplyCallback
            },   
            {
                name    = "PhysicsGpuAcceleration",
                label   = Locale.ResolveString("PHYSX_GPU_ACCELERATION"),
                type    = "select",
                values  = { Locale.ResolveString("OFF"), Locale.ResolveString("ON") },
                callback = StorePhysicsGpuAccelerationOption
            },
            {
                name    = "PhysicsMultithreading",
                label   = Locale.ResolveString("OPTION_PHYSICS_MULTITHREADING"),
                tooltip = Locale.ResolveString("OPTION_PHYSICS_MULTITHREADING_TOOLTIP"),
                type    = "select",
                values  = { Locale.ResolveString("OFF"), Locale.ResolveString("ON") },
            },
            {
                name    = "ResourceLoading",
                label   = Locale.ResolveString("OPTION_RESOURCE_LOADING"),
                tooltip = Locale.ResolveString("OPTION_RESOURCE_LOADING_TOOLTIP"),
                type    = "select",
                values  = {  Locale.ResolveString("LOW"), Locale.ResolveString("MEDIUM"), Locale.ResolveString("HIGH")  },
            },
            {
                name    = "MenuBackground",
                label   = Locale.ResolveString("MENU_BACKGROUND"),
                tooltip = Locale.ResolveString("OPTION_MENU_BACKGROUND"),
                type    = "select",
                values  = menuBackgroundList, 
            },
            {
                name    = "MenuMusic",
                label   = Locale.ResolveString("MENU_MUSIC"),
                tooltip = Locale.ResolveString("OPTION_MENU_MUSIC"),
                type    = "select",
                values  = menuMusicList, 
            },
            
        }
	self.generalOptionsDef = generalOptions
	
    local soundOptions =
        {
            {   
                name   = "SoundOutputDevice",
                label  = Locale.ResolveString("OUTPUT_DEVICE"),
                type   = "select",
                values = soundOutputDevices,
                callback = function(formElement) OnSoundDeviceChanged(self, formElement, Client.SoundDeviceType_Output) end,
            },
            {   
                name   = "SoundInputDevice",
                label  = Locale.ResolveString("INPUT_DEVICE"),
                type   = "select",
                values = soundInputDevices,
                callback = function(formElement) OnSoundDeviceChanged(self, formElement, Client.SoundDeviceType_Input) end,
            },            
            { 
                name    = "SoundVolume",
                label   = Locale.ResolveString("SOUND_VOLUME"),
                type    = "slider",
                sliderCallback = OnSoundVolumeChanged,
                formName = "sound",
            },
            { 
                name    = "MusicVolume",
                label   = Locale.ResolveString("MUSIC_VOLUME"),
                type    = "slider",
                sliderCallback = OnMusicVolumeChanged,
                formName = "sound",
            },
            { 
                name    = "HitSoundVolume",
                label   = Locale.ResolveString("HIT_SOUND_VOLUME"),
                tooltip = Locale.ResolveString("OPTION_HIT_SOUNDS"),
                type    = "slider",
                sliderCallback = OnHitSoundVolumeChanged,
                formName = "sound",
            },
            {
                name    = "MuteWhenMinized",
                label   = Locale.ResolveString("SOUND_MUTE_MINIZED"),
                tooltip = Locale.ResolveString("SOUND_MUTE_MINIZED_TTIP"),
                type    = "select",
                values  = { Locale.ResolveString("NO"), Locale.ResolveString("YES") },
                callback = function(fe) Client.SetOptionBoolean(kSoundMuteWhenMinized, fe:GetActiveOptionIndex() > 1) end;
            },
            { 
                name    = "VoiceVolume",
                label   = Locale.ResolveString("VOICE_VOLUME"),
                type    = "slider",
                sliderCallback = OnVoiceVolumeChanged,
                formName = "sound",
            },
            {
                name    = "RecordingGain",
                label   = Locale.ResolveString("MICROPHONE_GAIN"),
                type    = "slider",
                sliderCallback = OnRecordingGainChanged,
                formName = "sound",
            },
            {
                name    = "RecordingReleaseDelay",
                label   = Locale.ResolveString("MICROPHONE_RELEASE_DELAY"),
                tooltip = Locale.ResolveString("MICROPHONE_RELEASE_DELAY_TTIP"),
                type    = "slider",
                sliderCallback = OnRecordingReleaseDelayChanged,
                formName = "sound",
            },
            {
                name    = "RecordingVolume",
                label   = Locale.ResolveString("MICROPHONE_LEVEL"),
                type    = "progress",
                formName = "sound",
            }
        }        
        
    local autoApplyCallback = function(formElement) OnGraphicsOptionsChanged(self) end
    
    local graphicsOptions = 
        {
            {   
                name   = "RenderDevice",
                label  = Locale.ResolveString("DEVICE"),
                type   = "select",
                tooltip = Locale.ResolveString("OPTION_DEVICE"),
                values = kRenderDeviceDisplayNames,
                callback = function(formElement) SaveSecondaryGraphicsOptions(self) self:UpdateRestartMessage() end,
            },  
            {
                name   = "Display",
                label  = Locale.ResolveString("DISPLAY"),
                tooltip = Locale.ResolveString("OPTION_DISPLAY"),
                type   = "select",
                values = displays,
            },      
            {   
                name   = "Resolution",
                label  = Locale.ResolveString("RESOLUTION"),
                type   = "select",
                values = screenResolutions,
            },
            {   
                name   = "WindowMode",            
                label  = Locale.ResolveString("WINDOW_MODE"),
                type   = "select",
                values = windowModeNames,
            },
            {   
                name   = "DisplayBuffering",            
                label  = Locale.ResolveString("VYSNC"),
                tooltip = Locale.ResolveString("OPTION_VYSNC"),
                type   = "select",
                values = { Locale.ResolveString("DISABLED"), Locale.ResolveString("DOUBLE_BUFFERED"), Locale.ResolveString("TRIPLE_BUFFERED") }
            },                       
            {
                name    = "Detail",
                label   = Locale.ResolveString("TEXTURE_QUALITY"),
                tooltip = Locale.ResolveString("OPTION_TEXTUREQUALITY"),
                type    = "select",
                values  = { Locale.ResolveString("LOW"), Locale.ResolveString("MEDIUM"), Locale.ResolveString("HIGH") },
                callback = autoApplyCallback
            },
            {
                name    = "TextureManagement",
                label   = Locale.ResolveString("OPTION_TEXTURE_MANAGEMENT"),
                tooltip = Locale.ResolveString("OPTION_TEXTURE_MANAGEMENT_TOOLTIP"),
                type    = "select",
                values  = { Locale.ResolveString("OFF"),  Locale.ResolveString("GB_HALF"), Locale.ResolveString("GB_ONE"), Locale.ResolveString("GB_ONE_POINT_FIVE"), Locale.ResolveString("GB_TWO_PLUS")  },
                callback = autoApplyCallback
            },
            {
                name    = "ParticleQuality",
                label   = Locale.ResolveString("PARTICLE_QUALITY"),
                type    = "select",
                values  = { Locale.ResolveString("LOW"), Locale.ResolveString("HIGH") },
                callback = autoApplyCallback
            },   
            {
                name    = "Shadows",
                label   = Locale.ResolveString("SHADOWS"),
                type    = "select",
                values  = { Locale.ResolveString("OFF"), Locale.ResolveString("ON") },
                callback = autoApplyCallback
            },
            {
                name    = "LightQuality",
                label   = Locale.ResolveString("LIGHT_QUALITY"),
                tooltip = Locale.ResolveString("OPTION_LIGHT_QUALITY"),
                type    = "select",
                values  = { Locale.ResolveString("LOW"), Locale.ResolveString("HIGH") },
                callback = OnLightQualityChanged
            },
            {
                name    = "AntiAliasing",
                label   = Locale.ResolveString("ANTI_ALIASING"),
                tooltip = Locale.ResolveString("OPTION_ANTI_ALIASING"),
                type    = "select",
                values  = { Locale.ResolveString("OFF"), Locale.ResolveString("ON") },
                callback = autoApplyCallback
            },
            {
                name    = "Bloom",
                label   = Locale.ResolveString("BLOOM"),
                type    = "select",
                values  = { Locale.ResolveString("OFF"), Locale.ResolveString("ON") },
                callback = autoApplyCallback
            },
            {
                name    = "Atmospherics",
                label   = Locale.ResolveString("ATMOSPHERICS"),
                type    = "select",
                values  = { Locale.ResolveString("OFF"), Locale.ResolveString("ON") },
                callback = autoApplyCallback
            },
            {
                name    = "AtmosphericDensity",
                label   = Locale.ResolveString("ATMO_DENSITY"),
                type    = "slider",
                sliderCallback = OnAtmosphericDensityChanged,
            },
            {   
                name    = "AnisotropicFiltering",
                label   = Locale.ResolveString("AF"),
                tooltip = Locale.ResolveString("OPTION_AF"),
                type    = "select",
                values  = { Locale.ResolveString("OFF"), Locale.ResolveString("ON") },
                callback = autoApplyCallback
            },
            {
                name    = "AmbientOcclusion",
                label   = Locale.ResolveString("AMBIENT_OCCLUSION"),
                type    = "select",
                values  = { Locale.ResolveString("OFF"), Locale.ResolveString("MEDIUM"), Locale.ResolveString("HIGH") },
                callback = autoApplyCallback
            },
            {
                name    = "Reflections",
                label   = Locale.ResolveString("REFLECTIONS"),
                type    = "select",
                values  = { Locale.ResolveString("OFF"), Locale.ResolveString("ON") },
                callback = autoApplyCallback
            },
            {
                name    = "RefractionQuality",
                label   = Locale.ResolveString("REFRACTION_QUALITY"),
                type    = "select",
                values  = { Locale.ResolveString("HIGH"), Locale.ResolveString("LOW") },
                callback = autoApplyCallback
            },
            {
                name    = "DecalLifeTime",
                label   = Locale.ResolveString("DECAL"),
                type    = "slider",
                sliderCallback = OnDecalLifeTimeChanged,
            },  
            {
                name    = "Infestation",
                label   = Locale.ResolveString("OPTION_INFESTATION"),
                type    = "select",
                values  = { Locale.ResolveString("MINIMAL"), Locale.ResolveString("RICH") },
                callback = autoApplyCallback
            },
            {
                name    = "Gamma",
                label   = Locale.ResolveString("OPTION_GAMMA"),
                type    = "slider",
                sliderCallback = OnGammaChanged,
            },
        }
        
    -- save our option elements for future reference
    self.optionElements = { }
	
    local generalForm     = GUIMainMenu.CreateOptionsForm(self, content, generalOptions, self.optionElements)
    local keyBindingsForm = CreateKeyBindingsForm(self, content)
    local keyBindingsFormCom = CreateKeyBindingsFormCom(self, content)
    local graphicsForm    = GUIMainMenu.CreateOptionsForm(self, content, graphicsOptions, self.optionElements)
    local soundForm       = GUIMainMenu.CreateOptionsForm(self, content, soundOptions, self.optionElements)
    
    soundForm:SetCSSClass("sound_options")    
    self.soundForm = soundForm
        
    local tabs = 
        {
            { label = Locale.ResolveString("GENERAL"),  form = generalForm, scroll=true  },
            { label = Locale.ResolveString("BINDINGS"), form = keyBindingsForm, scroll=true },
            { label = Locale.ResolveString("OPTION_COMMANDER"), form = keyBindingsFormCom, scroll=true },
            { label = Locale.ResolveString("GRAPHICS"), form = graphicsForm, scroll=true },
            { label = Locale.ResolveString("SOUND"),    form = soundForm },
        }
        
    local xTabWidth = 256

    local tabBackground = CreateMenuElement(self.optionWindow, "Image")
    tabBackground:SetCSSClass("tab_background")
    tabBackground:SetIgnoreEvents(true)
    
    local tabAnimateTime = 0.1
        
    for i = 1,#tabs do
    
        local tab = tabs[i]
        local tabButton = CreateMenuElement(self.optionWindow, "MenuButton")
        
        local function ShowTab()
            for j =1,#tabs do
                tabs[j].form:SetIsVisible(i == j)
                self.optionWindow:ResetSlideBar()
                self.optionWindow:SetSlideBarVisible(tab.scroll == true)
                local tabPosition = tabButton.background:GetPosition()
                tabBackground:SetBackgroundPosition( tabPosition, false, tabAnimateTime ) 
            end
        end
    
        tabButton:SetCSSClass("tab")
        tabButton:SetText(tab.label)
        tabButton:AddEventCallbacks({ OnClick = ShowTab })
        
        local tabWidth = tabButton:GetWidth()
        tabButton:SetBackgroundPosition( Vector(tabWidth * (i - 1), 0, 0) )
        
        -- Make the first tab visible.
        if i==1 then
            tabBackground:SetBackgroundPosition( Vector(tabWidth * (i - 1), 0, 0) )
            ShowTab()
        end
        
    end        
    
    InitOptionWindow()
  
end

local kReplaceAlertMessage = { }
kReplaceAlertMessage["Connection disallowed"] = Locale.ResolveString("CONNECTION_DISALLOWED")
function GUIMainMenu:Update(deltaTime)

    PROFILE("GUIMainMenu:Update")
    
    if self:GetIsVisible() then

        local currentTime = Client.GetTime()
        
        -- Refresh the mod list once every 5 seconds.
        --self.timeOfLastRefresh = self.timeOfLastRefresh or currentTime
        self.modsListRefreshed = self.modsListRefreshed or false --No sane reason to spam RefreshModsList every 5 seconds...
        if self.modsWindow and self.modsWindow:GetIsVisible() and not self.modsListRefreshed then --currentTime - self.timeOfLastRefresh >= 5 
            self:RefreshModsList()
            --self.timeOfLastRefresh = currentTime
            self.modsListRefreshed = true
        end
        
        local alertText = MainMenu_GetAlertMessage()
        if self.currentAlertText ~= alertText then
        
            alertText = kReplaceAlertMessage[alertText] or alertText
            self.currentAlertText = alertText
            
            if self.currentAlertText then

                if not self.alertWindow then
                    self:CreateAlertWindow()
                end

                local wrap = WordWrap( self.alertText.text, self.currentAlertText, 0, 450 )
                self.alertText:SetText( wrap )
                self.alertWindow:SetIsVisible(true)
                
                MainMenu_OnTooltip()
                
            end
            
        end
        
        -- Update only when visible.
        GUIAnimatedScript.Update(self, deltaTime)
    
        if self.soundForm and self.soundForm:GetIsVisible() then
            if self.optionElements.RecordingVolume then
                self.optionElements.RecordingVolume:SetValue(Client.GetRecordingVolume())
                if Client.GetRecordingVolume() >= 1 then
                    self.optionElements.RecordingVolume:SetColor(Color(0.6, 0, 0, 1))
                elseif Client.GetRecordingVolume() > 0.5 and Client.GetRecordingVolume() < 1 then
                    self.optionElements.RecordingVolume:SetColor(Color(0.7, 0.7, 0, 1))
                else
                    self.optionElements.RecordingVolume:SetColor(Color(0.47, 0.67, 0.67, 1))
                end
                
            end
        end

        --Update name
        local playerName = OptionsDialogUI_GetNickname()
        if self.playerName.text:GetText() ~= playerName then
            self.playerName:SetText(playerName)
            self.skillTierIcon:SetLeftOffset(self.playerName:GetTextWidth() + 150)
        end
        
        if self.modsWindow and self.modsWindow:GetIsVisible() then
            self:UpdateModsWindow()
        end

        if self.serverBrowserWindow and self.serverBrowserWindow:GetIsVisible() then

            if not Client.GetServerListRefreshed() then
                local angle = -currentTime * 2

                if not self.serverTabs.serverRefresh.rotating then
                    self.serverTabs.serverRefresh.rotating = true
                    self.serverTabs.serverRefresh:SetBackgroundTexture( self.serverTabs.serverRefresh.backgroundTextureActive )
                end

                self.serverTabs.serverRefresh:GetBackground():SetRotation( Vector(0, 0, angle) )
            elseif self.serverTabs.serverRefresh.rotating then

                self.serverTabs.serverRefresh.rotating = false
                self.serverTabs.serverRefresh:SetBackgroundTexture( self.serverTabs.serverRefresh.backgroundTexture )
                self.serverTabs.serverRefresh:GetBackground():SetRotation( Vector(0, 0, 0) )

            end

            if not self.totalServers or self.totalServers < Client.GetNumServers() then

                local listChanged = false

                for s = 0, Client.GetNumServers() - 1 do

                    self.numServers = self.numServers or 0

                    if s + 1 > self.numServers then

                        local serverEntry = BuildServerEntry(s)
                        if self.serverList:GetEntryExists(serverEntry) then

                            self.serverList:UpdateEntry(serverEntry, true)

                                UpdateFavoriteServerData(serverEntry)
                            UpdateBlockedServerData(serverEntry)
                                UpdateHistoryServerData(serverEntry)

                        else

                            self.serverList:AddEntry(serverEntry, true)

                        end

                        self.numServers = self.numServers + 1
                        listChanged = true

                    end
                end

                self.totalServers = Client.GetNumServers()

                if listChanged then
                    self.serverList:RenderNow()
                end
            end

            local countTxt = string.format("%s / %s", self.serverList:GetNumVisibleEntries(),
                self.serverList:GetNumEntries())
            self.serverTabs.serverCountDisplay:SetText(countTxt)
            
            self.serverTabs:SetGameTypes(self.serverList:GetGameTypes())
        end

        if self.newsScript then
            self.newsScript:Update(deltaTime)
        end

        if self.playNowWindow then
            self.playNowWindow:UpdateLogic(self)
        end

        if self.progress then
            self.progress:Update(deltaTime)
        end
        
        if self.fpsDisplay then
            self.fpsDisplay:SetText(string.format( Locale.ResolveString("MENU_FPS"), Client.GetFrameRate()))
        end
        
        if self.updateAutoJoin then
        
            if not self.timeLastAutoJoinUpdate or self.timeLastAutoJoinUpdate + 0.5 < Shared.GetTime() then
            
                Client.RefreshServer(MainMenu_GetSelectedServer())
                
                if MainMenu_GetSelectedIsFull() then
                    self.timeLastAutoJoinUpdate = Shared.GetTime()
                else
                
                    MainMenu_JoinSelected()
                    self.autoJoinWindow:SetIsVisible(false)
                    
                end
                
            end
            
        elseif self.serverDetailsWindow and self.serverDetailsWindow:GetIsVisible() then

            if not self.timeDetailsRefreshed or self.timeDetailsRefreshed + 1 < Shared.GetTime() then
            
                local index = self.serverDetailsWindow.serverIndex    
                
                if index >= 0 then
                
                    local function RefreshCallback(index)
                        MainMenu_OnServerRefreshed(index)
                    end
                    Client.RefreshServer(index, RefreshCallback)
                    
                    self.timeDetailsRefreshed = Shared.GetTime()   
                
                end
            
            end
        
        end

        if gSelectedServerEntry and gSelectedServerEntry.lastOneClick and gSelectedServerEntry.lastOneClick + 0.3 < Shared.GetTime() then
            if gSelectedServerEntry.lastOneClick then
                gSelectedServerEntry.lastOneClick = nil
                self.serverDetailsWindow:SetIsVisible(true)
            end
        end

        local lastModel = Client.GetOptionString("currentModel", "")
        if self.customizeFrame and self.customizeFrame:GetIsVisible() then
            MenuPoses_Update(deltaTime)
            MenuPoses_SetViewModel(false)
            
            --FIXME The Draw order of this makes fixed position models "blink" from previous model's position, relative to new model's orientation of old model's orientation (yeah, confusing...)
            if lastModel == "MarineStructureVariantName" or lastModel == "AlienStructureVariantName" then
                MenuPoses_SetModelAngle( -0.525 )
            elseif lastModel == "AlienTunnelVariantName" then
                MenuPoses_SetModelAngle( -0.5 )
            elseif lastModel == "ShoulderPad" then
                MenuPoses_SetModelAngle( -1.485 )
            else
                MenuPoses_SetModelAngle( self.sliderAngleBar:GetValue() or 0 )
            end
        end
        
    end
    
end

function GUIMainMenu:OnServerRefreshed(serverIndex)

    local serverEntry = BuildServerEntry(serverIndex)
    self.serverList:UpdateEntry(serverEntry)
    
    if self.serverDetailsWindow and self.serverDetailsWindow:GetIsVisible() then
        self.serverDetailsWindow:SetRefreshed()
    end
    
end

function GUIMainMenu:ShowMenu()

    self.menuBackground:SetIsVisible(true)
    self.menuBackground:SetCSSClass("menu_bg_show", false)
    
    --self.logo:SetIsVisible(true)

    if self.progress then
        self.progress:SetIsVisible(true)
    end

    if self.newsScript and self.newsScript.isVisible == false then
        self.newsScript:SetPlayAnimation("show")  
    end
    
end

function GUIMainMenu:HideMenu()

    self.menuBackground:SetCSSClass("menu_bg_hide", false)

    for i = 1, #self.Links do
        self.Links[i]:SetIsVisible(false)
    end

    --self.logo:SetIsVisible(false)

    if self.progress then
        self.progress:SetIsVisible(false)
    end

    if self.newsScript then
        self.newsScript:SetPlayAnimation("hide")    
    end

    if self.modWarningWindow then
        self.modWarningWindow:SetIsVisible(false)
    end

    if self.tutorialNagWindow then
        self.tutorialNagWindow:SetIsVisible(false)
    end

    if self.changelog then
        self.changelog:SetIsVisible(false)
    end

    if self.endOfLifeWarn then
        self.endOfLifeWarn:SetIsVisible(false)
    end

end

function GUIMainMenu:OnAnimationsEnd(item)
    
end

function GUIMainMenu:OnAnimationCompleted(animatedItem, animationName, itemHandle)

    if animationName == "ANIMATE_LINK_BG" then
        
        for i = 1, #self.Links do
            self.Links[i]:SetFrameCount(15, 1.6, AnimateLinear, "ANIMATE_LINK_BG")       
        end
        
    elseif animationName == "ANIMATE_BLINKING_ARROW" and self.blinkingArrow then
    
        self.blinkingArrow:SetCSSClass("blinking_arrow")
        
    elseif animationName == "ANIMATE_BLINKING_ARROW_TWO" then
    
        self.blinkingArrowTwo:SetCSSClass("blinking_arrow_two")
        
    elseif animationName == "MAIN_MENU_OPACITY" then
    
        if self.menuBackground:HasCSSClass("menu_bg_hide") then
            self.menuBackground:SetIsVisible(false)
        end    

    elseif animationName == "MAIN_MENU_MOVE" then
    
        if self.menuBackground:HasCSSClass("menu_bg_show") then

            for i = 1, #self.Links do
                self.Links[i]:SetIsVisible(true)
            end

        end
        
    elseif animationName == "SHOWWINDOW_UP" then
    
        self.showWindowAnimation:SetCSSClass("showwindow_animation2")
    
    elseif animationName == "SHOWWINDOW_RIGHT" and self.windowToOpen then

        self.windowToOpen:SetIsVisible(true)
        self.showWindowAnimation:SetIsVisible(false)
        
    elseif animationName == "SHOWWINDOW_LEFT" then

        self.showWindowAnimation:SetCSSClass("showwindow_animation2_close")
        
    elseif animationName == "SHOWWINDOW_DOWN" then

        self.showWindowAnimation:SetCSSClass("showwindow_hidden")
        self.showWindowAnimation:SetIsVisible(false)
        
    end

end

function GUIMainMenu:OnWindowOpened(window)

    self.openedWindows = self.openedWindows + 1
    
    self.showWindowAnimation:SetCSSClass("showwindow_animation1")
    
end

function GUIMainMenu:OnWindowClosed(window)
    
    self.openedWindows = self.openedWindows - 1
    
    if self.openedWindows <= 0 then
    
        self:ShowMenu()
        self.showWindowAnimation:SetCSSClass("showwindow_animation1_close")
        self.showWindowAnimation:SetIsVisible(true)
        
    end
    
end

function GUIMainMenu:SetupWindow(window, title)

    window:SetCanBeDragged(false)
    window:SetWindowName(title)
    window:AddClass("main_menu_window")
    window:SetInitialVisible(false)
    window:SetIsVisible(false)
    window:DisableResizeTile()
    
    local eventCallbacks =
    {
        OnShow = function(self)
            self.scriptHandle:OnWindowOpened(self)
            MainMenu_OnWindowOpen()
        end,
        
        OnHide = function(self)
            self.scriptHandle:OnWindowClosed(self)
        end
    }
    
    window:AddEventCallbacks(eventCallbacks)
    
end

function GUIMainMenu:OnResolutionChanged(oldX, oldY, newX, newY)

    GUIAnimatedScript.OnResolutionChanged(self, oldX, oldY, newX, newY)

    for _,window in ipairs(self.windows) do
        window:ReloadCSSClass(true)
    end

    -- handle some specific reloading behavior not covered by CSS reload alone.
    for i = 1, #self.Links do

        -- reload glows on training menu button
        if self.Links[i].originalText == 'MENU_TRAINING' then
            local mainLinkGlow = self.Links[i].mainLinkGlow
            if mainLinkGlow then
                mainLinkGlow:SetTopOffset(mainLinkGlow.topOffsetOriginal)
            end
            local mainLinkAlertTextGlow = self.Links[i].mainLinkAlertTextGlow
            if mainLinkAlertTextGlow then
                mainLinkAlertTextGlow:SetTopOffset(mainLinkAlertTextGlow.topOffsetOriginal)
            end
        end

    end

    self.filterMaxPing:SetIsVisible(newX >= 1280)
    if self.filterMaxPing:GetIsVisible() then
        self.filterMaxPing:SetValue(tonumber(Client.GetOptionString("filter_maxping", "1")) or 1)
    else
        self.filterMaxPing:SetValue(1)
    end


    self.skillTierIcon:SetLeftOffset(self.playerName:GetTextWidth() + 150)
    if self.skillTierIcon:GetIsVisible() then
        self:UpdateSkillTierIcon(self.playerSkill, self.playerIsRookie)
    end

end

function GUIMainMenu:UpdateRestartMessage()

    local needsRestart = not Client.GetIsSoundDeviceValid(Client.SoundDeviceType_Input) or
                         not Client.GetIsSoundDeviceValid(Client.SoundDeviceType_Output) or
                         Client.GetRenderDeviceName() ~= Client.GetOptionString("graphics/device", "")
    if needsRestart then
        self.warningLabel:SetText(Locale.ResolveString("GAME_RESTART_REQUIRED"))
        self.warningLabel:SetIsVisible(true)    
    else
        self.warningLabel:SetIsVisible(false)        
    end

end

function OnSoundDeviceListChanged()

    -- The options page may not be initialized yet
    if gMainMenu ~= nil and gMainMenu.optionElements ~= nil then 

        local soundInputDeviceGuid = Client.GetOptionString(kSoundInputDeviceOptionsKey, "Default")
        local soundOutputDeviceGuid = Client.GetOptionString(kSoundOutputDeviceOptionsKey, "Default")

        local soundInputDevice = 1
        if soundInputDeviceGuid ~= 'Default' then
            soundInputDevice = math.max(Client.FindSoundDeviceByGuid(Client.SoundDeviceType_Input, soundInputDeviceGuid), 0) + 2
        end
        
        local soundOutputDevice = 1
        if soundOutputDeviceGuid ~= 'Default' then
            soundOutputDevice = math.max(Client.FindSoundDeviceByGuid(Client.SoundDeviceType_Output, soundOutputDeviceGuid), 0) + 2
        end

        local soundOutputDevices = OptionsDialogUI_GetSoundDeviceNames(Client.SoundDeviceType_Output)
        local soundInputDevices = OptionsDialogUI_GetSoundDeviceNames(Client.SoundDeviceType_Input)

        gMainMenu.optionElements.SoundInputDevice:SetOptions(soundInputDevices)
        gMainMenu.optionElements.SoundInputDevice:SetOptionActive(soundInputDevice)
        
        gMainMenu.optionElements.SoundOutputDevice:SetOptions(soundOutputDevices)
        gMainMenu.optionElements.SoundOutputDevice:SetOptionActive(soundOutputDevice)

    end

end

-- Called when the options file is changed externally
local function OnOptionsChanged()

    if gMainMenu ~= nil and gMainMenu.optionElements then
        InitOptions(gMainMenu)
    end
    
end

function GUIMainMenu:CreateLastStandMenu()
	local info = CreateMenuElement(self.mainWindow, "GUINewGameModeInfo")
	info:Setup{
		title = "Infested Marines",
		icon = "ui/logo_infested.dds",
		description = "You have been dispatched to deal with a dangerous pathogen detected within a remote TSF outpost. Race to repair the air purifiers before the pathogen corrodes them too severely and the air is overwhelmed with spores. But watch out, one of your teammates has already been infested!",
		gamemode = "Infested",
		event = "laststand",
	}
end

function GUIMainMenu:PopupIsVisible()
    return 
        ( self.modWarningWindow and self.modWarningWindow:GetIsVisible() ) or 
        ( self.newItemPopup and self.newItemPopup:GetIsVisible() ) or
        ( self.changelog and self.changelog:GetIsVisible() ) or
        ( self.endOfLifeWarn and self.endOfLifeWarn:GetIsVisible() )
end

function GUIMainMenu:MaybeOpenPopup()
    if not MainMenu_IsInGame() then
        self:MaybeAddChangelogPopup()
        self:MaybeAddNewItemPopup()
        self:MaybeAddLastStandMenu()
    end
end

function GUIMainMenu:MaybeAddChangelogPopup()
    if self:PopupIsVisible() then return end
    local show = kRemoteShowChangelog or Client.GetClientUpdated()
    if not self.changelog and show then
        self.changelog = CreateMenuElement(self.mainWindow, "GUIChangelog")
    end
end

function GUIMainMenu:MaybeAddNewItemPopup()
    if self:PopupIsVisible() then return end
    
    local new = InventoryNewItemNotifyPop()
    if new and GetOwnsItem(new) then
        
        local info = CreateMenuElement(self.mainWindow, "GUINewItemInfo")
        info:SetupWithId( new )
        self.newItemPopup = info
        
    end
end

function GUIMainMenu:MaybeAddLastStandMenu()
	local isRookie = self.playerLevel and self.playerLevel < kRookieOnlyLevel
	if not kRemoteConfig or not kRemoteConfig.infested or isRookie or not self:PlayNowUnlocked() or MainMenu_IsInGame() then
        return
    end
    
    if self.Links and self.Links[1] and not self.lastStandOption then
        local mainLink = self.Links[1]
        local parent = self
        local lastStandOption = CreateMenuElement( mainLink, 'Image', false )
        lastStandOption:SetBackgroundTexture("ui/logo_infested.dds")
        lastStandOption:SetCSSClass("playnow_laststand")
        lastStandOption:SetIsVisible( true )
        lastStandOption:AddEventCallbacks(
            {
                OnClick = function( self, buttonPressed )
                    Analytics.RecordEvent( "playnow_laststand" )
                    parent:CreateLastStandMenu()
                end
            })
        parent.lastStandOption = lastStandOption
        
    end
    
    local showInfestedInfo = Client.GetOptionInteger("shownInfestedInfo", 0)
    if self:PlayNowUnlocked() and showInfestedInfo < 3
        and not self:PopupIsVisible()
    then
        Client.SetOptionInteger("shownInfestedInfo", showInfestedInfo + 1 )
        self:CreateLastStandMenu()
        return
    end

end

function GUIMainMenu:MaybeCreateModWarningWindow()

    if Client.GetOptionBoolean("playedTutorial", false) or Client.GetOptionBoolean("system/playedTutorial", false) then
        Client.SetAchievement("First_0_1")
    end

    local modsWasDisabled = Client.GetAndResetClientSideModsDisabled()
    if not modsWasDisabled then
        return
    end
    
    if self.modWarningWindow ~= nil then
        self:DestroyWindow( self.modWarningWindow )
        self.modWarningWindow = nil
    end
    
    self.modWarningWindow = self:CreateWindow()  
    self.modWarningWindow:SetWindowName("HINT")
    self.modWarningWindow:SetInitialVisible(true)
    self.modWarningWindow:SetIsVisible(true)
    self.modWarningWindow:DisableResizeTile()
    self.modWarningWindow:DisableTitleBar()
    self.modWarningWindow:DisableSlideBar()
    self.modWarningWindow:DisableContentBox()
    self.modWarningWindow:SetCSSClass("first_run_window")
    self.modWarningWindow:DisableCloseButton()
    self.modWarningWindow:SetLayer(kGUILayerMainMenuDialogs)
    
    local title = CreateMenuElement(self.modWarningWindow, "Font")
    local hint = CreateMenuElement(self.modWarningWindow, "Font")
    local okButton = CreateMenuElement(self.modWarningWindow, "MenuButton")

    title:SetCSSClass("nag_title")
    hint:SetCSSClass("nag_msg")
    hint:SetTextClipped( true, GUIScaleWidth(550), GUIScaleHeight(220) )
    okButton:SetCSSClass("first_run_ok")

    title:SetText(Locale.ResolveString("MODS_WARNING_TITLE"))
    hint:SetText(Locale.ResolveString("MODS_WARNING_WINDOW"))
    
    okButton:SetText(Locale.ResolveString("OPTIMIZE_CONFIRM"))
    okButton:AddEventCallbacks({ OnClick = function()
            self:DestroyWindow( self.modWarningWindow )
            self.modWarningWindow = nil
            self:MaybeOpenPopup()
        end})

    MainMenu_OnTooltip()

end

function GUIMainMenu:ActivateCustomizeWindow()

    self:OpenCustomizeWindow( Client.UpdateInventory )
    self:TriggerOpenAnimation(self.customizeLoadingWindow)
    self:HideMenu()

end

function GUIMainMenu:CreateRookieOnlyNagWindow()
    self.rookieOnlyNagWindow = self:CreateWindow()
    self.rookieOnlyNagWindow:SetWindowName("HINT")
    self.rookieOnlyNagWindow:SetInitialVisible(true)
    self.rookieOnlyNagWindow:SetIsVisible(true)
    self.rookieOnlyNagWindow:DisableResizeTile()
    self.rookieOnlyNagWindow:DisableSlideBar()
    self.rookieOnlyNagWindow:DisableContentBox()
    self.rookieOnlyNagWindow:SetCSSClass("nag_window")
    self.rookieOnlyNagWindow:DisableCloseButton()
    self.rookieOnlyNagWindow:DisableTitleBar()
    self.rookieOnlyNagWindow:SetLayer(kGUILayerMainMenuDialogs)

    local title = CreateMenuElement(self.rookieOnlyNagWindow, "Font")
    title:SetCSSClass("nag_title")

    local hint = CreateMenuElement(self.rookieOnlyNagWindow, "Font")
    hint:SetCSSClass("nag_msg")
    hint:SetText(Locale.ResolveString("ROOKIEONLYNAG_MSG"))
    hint:SetTextClipped( true, GUIScaleWidth(580), GUIScaleHeight(200) )

    local okButton = CreateMenuElement(self.rookieOnlyNagWindow, "MenuButton")
    okButton:SetCSSClass("tutnag_play")
    okButton:SetText(Locale.ResolveString("PLAY_NOW"))
    okButton:AddEventCallbacks({ OnClick = function()
        if self.rookieOnlyNagWindow then
            self:DestroyWindow( self.rookieOnlyNagWindow )
            self.rookieOnlyNagWindow = nil
            self:DoQuickJoin()
        end
    end})

    local skipButton = CreateMenuElement(self.rookieOnlyNagWindow, "MenuButton")
    skipButton:SetCSSClass("tutnag_playnow")
    skipButton:SetText(Locale.ResolveString("CANCEL"))
    skipButton:AddEventCallbacks({OnClick = function()
        if self.rookieOnlyNagWindow then
            self:DestroyWindow( self.rookieOnlyNagWindow )
            self.rookieOnlyNagWindow = nil
        end
    end})
end

function GUIMainMenu:CreateTutorialNagWindow(closeFunc)

    --Only show the warning once
    if self.tutorialNagWindow then
        closeFunc()
        return
    end

    self.tutorialNagWindow = self:CreateWindow()
    self.tutorialNagWindow:SetWindowName("HINT")
    self.tutorialNagWindow:SetInitialVisible(false)
    self.tutorialNagWindow:SetIsVisible(true)
    self.tutorialNagWindow:DisableResizeTile()
    self.tutorialNagWindow:DisableSlideBar()
    self.tutorialNagWindow:DisableContentBox()
    self.tutorialNagWindow:SetCSSClass("nag_window")
    self.tutorialNagWindow:DisableCloseButton()
    self.tutorialNagWindow:DisableTitleBar()
    self.tutorialNagWindow:SetLayer(kGUILayerMainMenuDialogs)

    local title = CreateMenuElement(self.tutorialNagWindow, "Font")
    title:SetCSSClass("nag_title")
    title:SetText(Locale.ResolveString("TUTNAG_TITLE"))

    local hint = CreateMenuElement(self.tutorialNagWindow, "Font")
    hint:SetCSSClass("nag_msg")
    hint:SetText(Locale.ResolveString("TUTNAG_MSG"))
    hint:SetTextClipped( true, GUIScaleWidth(580), GUIScaleHeight(200))
    
    -- DO TRAINING BUTTON
    local okButton = CreateMenuElement(self.tutorialNagWindow, "MenuButton")
    okButton:SetCSSClass("tutnag_play")
    okButton:SetText(Locale.ResolveString("TUTNAG_PLAY"))
    okButton:AddEventCallbacks({ OnClick = function()
        if self.tutorialNagWindow then
            Analytics.RecordEvent( "playnow_tutorial" )
            self.tutorialNagWindow:SetIsVisible(false)
            self:StartTutorial()
        end
    end})
    
    -- DO BOOTCAMP BUTTON
    self.tutorialNagWindow.OnClose = function()
        Analytics.RecordEvent( "playnow_bootcamp" )
        if closeFunc then
            closeFunc()
        end
    end

    local playButton = CreateMenuElement(self.tutorialNagWindow, "MenuButton")
    playButton:SetCSSClass("tutnag_playnow")
    playButton:SetText(Locale.ResolveString("TUTNAG_CLOSE"))
    playButton:AddEventCallbacks({ OnClick = function()
        self.tutorialNagWindow:SetIsVisible(false)
        self.tutorialNagWindow.OnClose()
    end})

    self.tutorialNagWindow:AddEventCallbacks({
        OnEscape = function(self)
            self.OnClose()
        end
    })

    return true
end

function GUIMainMenu:StartTutorial()
    if self.serverBrowserWindow then
        self.playNowWindow:SetIsVisible(false)
        self.serverBrowserWindow:SetIsVisible(false)
    end

    if self.playScreen then
        self.playScreen:Hide()
    end

    if not self.trainingWindow then
        self:CreateTrainingWindow()
    end

    self:TriggerOpenAnimation(self.trainingWindow)

    --the open animation of the newsScript is still playing so we have to set this false manually
    if self.newsScript then
        self.newsScript.isVisible = true
    end

    self:HideMenu()
end

function GUIMainMenu:PlayNowUnlocked()
    if gDebugPlayNowLock then return false end

    local isRookie = self.playerLevel and self.playerLevel < kRookieOnlyLevel
    local doneTutorial = Client.GetAchievement("First_0_1")
	return not isRookie or doneTutorial	
end

function GUIMainMenu:AttemptToOpenServerBrowser()
    
    if self:PlayNowUnlocked() then
        self:OpenServerBrowser()
    else
        local function openServerBrowser()
            self:OpenServerBrowser()
        end
        self:CreateTutorialNagWindow(openServerBrowser)
    end
    
end

function GUIMainMenu:OpenServerBrowser()
    
    Matchmaking_JoinGlobalLobby()
    
    if not self.serverBrowserWindow then
        self:CreateServerBrowserWindow()
    end
    
    self:TriggerOpenAnimation(self.serverBrowserWindow)
    self:HideMenu()
    
end

function GUIMainMenu:OpenTraining()

    if not self.trainingWindow then
        self:CreateTrainingWindow()
    end
    self:TriggerOpenAnimation(self.trainingWindow)
    self:HideMenu()

end

function GUIMainMenu:DoQuickJoin(gamemode)
    
    Matchmaking_JoinGlobalLobby()
        
    if not self.serverBrowserWindow then
        self:CreateServerBrowserWindow()
    end
    
    self.playNowWindow.gamemode = gamemode
    self.playNowWindow:SetIsVisible(true)
    self.playNowWindow:UpdateLogic(self)
    
end

function GUIMainMenu:AttemptToQuickJoin(gamemode)
    
    if self:PlayNowUnlocked() then
        self:DoQuickJoin(gamemode)
    else
        local function quickJoin()
            self:DoQuickJoin(gamemode)
        end
        self:CreateTutorialNagWindow(quickJoin)
    end
    
end

local LinkItems =
{
    [1] = { "MENU_RESUME_GAME", function(self)

            self.scriptHandle:SetIsVisible(not self.scriptHandle:GetIsVisible())

        end
    },
    [2] = { "MENU_GO_TO_READY_ROOM", function(self)
            
            self.scriptHandle:SetIsVisible(not self.scriptHandle:GetIsVisible())
            Shared.ConsoleCommand("rr")

        end, "readyroom"
    },
    [3] = { "MENU_VOTE", function(self)

            OpenVoteMenu()
            self.scriptHandle:SetIsVisible(false)

        end, "vote"
    },
    [4] = { "MENU_SERVER_BROWSER", function(self)
            
            self.scriptHandle:AttemptToOpenServerBrowser()

        end, "browser"
    },
    [5] = { "MENU_ORGANIZED_PLAY", function(self)
        --NYI
    end
    },
    [6] = { "MENU_OPTIONS", function(self)

            if not self.scriptHandle.optionWindow then
                self.scriptHandle:CreateOptionWindow()
            end
            self.scriptHandle:TriggerOpenAnimation(self.scriptHandle.optionWindow)
            self.scriptHandle:HideMenu()

        end, "options"
    },
    [7] = { "MENU_CUSTOMIZE_PLAYER", function(self)

            self.scriptHandle:ActivateCustomizeWindow()
            self.scriptHandle.screenFade = GetGUIManager():CreateGUIScript("GUIScreenFade")
            self.scriptHandle.screenFade:Reset()

        end, "customize"
    },
    [8] = { "MENU_DISCONNECT", function(self)

            self.scriptHandle:HideMenu()

            Shared.ConsoleCommand("disconnect")

            self.scriptHandle:ShowMenu()

        end, "disconnect"
    },
    [9] = { "MENU_TRAINING", function(self)

            self.scriptHandle:OpenTraining()

        end, "training"
    },
    [10] = { "MENU_MODS", function(self)
            
            if not self.scriptHandle.modsWindow then
                self.scriptHandle:CreateModsWindow()
            end            
            self.scriptHandle.modsWindow.sorted = false
            self.scriptHandle:TriggerOpenAnimation(self.scriptHandle.modsWindow)
            self.scriptHandle:HideMenu()

        end, "mods"
    },
    [11] = { "MENU_CREDITS", function(self)

            self.scriptHandle:HideMenu()
            self.creditsScript = GetGUIManager():CreateGUIScript("menu/GUICredits")
            MainMenu_OnPlayButtonClicked()
            self.creditsScript:SetPlayAnimation("show")


        end, "credits"
    },
    [12] = { "MENU_EXIT", function()

            Client.Exit()

        end, "exit"
    },
    [13] = { "MENU_PLAY", function(self)

            MainMenu_OnPlayButtonClicked() --Play click sound

            self.scriptHandle:HideMenu()
            self.scriptHandle.playScreen:Show()
            
        end,
    },
}
--Id of Links table is used to order links
local LinkOrder =
{
    { 13,9,6,7,10,11,12 },
    { 1,2,3,4,9,6,7,8 }
}

function RecordEventWrap( func, event )
	return function(...) 
		Analytics.RecordEvent( event )
		return func(...)
	end
end
	
function GUIMainMenu:CreateMainLinks()
    
    local index = MainMenu_IsInGame() and 2 or 1
    local linkOrder = LinkOrder[index]
    for i=1, #linkOrder do
        local linkId = linkOrder[i]
        local text = LinkItems[linkId][1]
        local callbackTable = LinkItems[linkId][2]
		local event = LinkItems[linkId][3]
		if event then
			event = ( MainMenu_IsInGame() and "igmenu_" or "menu_" ) .. event
			callbackTable = RecordEventWrap( callbackTable, event )			
		end
        local link = self:CreateMainLink(text, i, callbackTable)
        table.insert(self.Links, link)
    end
    
end

--mode 1: Not Ingame 2: Ingame 3: Both
function GUIMainMenu:AddMainLink(name, position, OnClick, mode)
    if not ( name or position or OnClick or mode) then 
        return 
    end
    
    table.insert(LinkItems, {name, OnClick})
    if mode == 1 or mode == 3 then 
        table.insert(LinkOrder[1], position, #LinkItems)
    end
    if mode == 2 or mode == 3 then
        table.insert(LinkOrder[2], position, #LinkItems)
    end
    return true
end

function GUIMainMenu:RemoveMainLink(position, inGame)
    local orderTable = inGame and 2 or 1
    table.remove(LinkOrder[inGame], position)
end

Event.Hook("SoundDeviceListChanged", OnSoundDeviceListChanged)
Event.Hook("OptionsChanged", OnOptionsChanged)
Event.Hook("DisplayChanged", OnDisplayChanged)

-- DEBUG

local function OnCommandDebugPlayNowLock()
    gDebugPlayNowLock = not gDebugPlayNowLock

    Print(string.format("Play Now lock is %s", gDebugPlayNowLock and "enabled" or "disabled"))
end
Event.Hook("Console_debugplaynowlock", OnCommandDebugPlayNowLock)

local function OnCommandDebugTrainingGlow()
    gDebugTrainingHighlight = not Client.GetOptionBoolean("debug_training_glow", false)
    Client.SetOptionBoolean("debug_training_glow", gDebugTrainingHighlight)

    Print(string.format("Debug highlight is %s", gDebugTrainingHighlight and "enabled" or "disabled"))
end
Event.Hook("Console_debugtrainingglow", OnCommandDebugTrainingGlow)

--[[
-- DEBUG cloud nag
Script.Load("lua/challenge/GUIChallengePromptAlien.lua")
local nag
local function OnCommandDebugNag(iconName)
    
    nag = GetGUIManager():CreateGUIScript("GUIChallengePromptAlien")
    nag:SetLayer(999)
    nag:SetPromptText("STEAM_CLOUD_NAG_PROMPT")
    nag:SetDescriptionText("STEAM_CLOUD_NAG_DESC")
    nag:AddButton("YES", function() Log("Yes clicked") end)
    nag:AddButton("JUST_THIS_TIME", function() Log("Just this time clicked") end)
    nag:AddButton("NO", function() Log("No clicked") end)
    nag:SetIcon(iconName or "choice")
    
end
Event.Hook("Console_debugnag", OnCommandDebugNag) -- icon name

local function OnCommandDebugNagShow()
    nag:Show(function() Log("hidden now!") end)
end
Event.Hook("Console_debugnagshow", OnCommandDebugNagShow)

local function OnCommandDebugNagHide()
    nag:Hide(function() Log("hidden now!") end)
end
Event.Hook("Console_debugnaghide", OnCommandDebugNagHide)
--]]


Event.Hook("Console_restartmain", function() Client.RestartMain() end)