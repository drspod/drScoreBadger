-----------------------------------------------------------------------------------------------
-- Client Lua Script for DrScoreBadger
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------

require "Window"

-----------------------------------------------------------------------------------------------
-- DrScoreBadger Module Definition
-----------------------------------------------------------------------------------------------
local DrScoreBadger = {} 

-----------------------------------------------------------------------------------------------
-- Initialization
-----------------------------------------------------------------------------------------------
function DrScoreBadger:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self

    self.options = {}
    self.options.bShowHealers = true
    self.options.bShowScorers = true
    self.options.bShowTurds = true
    self.options.nNumDamage = 3
    self.options.nNumKills = 3
    self.options.nNumDeaths = 3

    return o
end

function DrScoreBadger:Init()
    local bHasConfigureFunction = true
    local strConfigureButtonText = "drScoreBadger"
    local tDependencies = {}
    Apollo.RegisterAddon(self, bHasConfigureFunction, strConfigureButtonText, tDependencies)
end

-----------------------------------------------------------------------------------------------
-- DrScoreBadger OnLoad
-----------------------------------------------------------------------------------------------
function DrScoreBadger:OnLoad()
    Apollo.LoadSprites("drScoreBadgerSprites.xml", "drScoreBadgerSprites")
    self.xmlDoc = XmlDoc.CreateFromFile("drScoreBadger.xml")
    self.xmlDoc:RegisterCallback("OnDocLoaded", self)
end

-----------------------------------------------------------------------------------------------
-- DrScoreBadger OnDocLoaded
-----------------------------------------------------------------------------------------------
function DrScoreBadger:OnDocLoaded()
    if self.xmlDoc ~= nil and self.xmlDoc:IsLoaded() then
        self.wndMain = Apollo.LoadForm(self.xmlDoc, "DrScoreBadgerHUD", "InWorldHudStratum", self)
        if self.wndMain == nil then
            Apollo.AddAddonErrorText(self, "Could not load the HUD window for some reason.")
            return
        end        
        self.wndMain:Show(true, true)

        self.wndOpts = Apollo.LoadForm(self.xmlDoc, "DrScoreBadgerOptions", nil, self)
        if self.wndOpts == nil then
            Apollo.AddAddonErrorText(self, "Could not load the settings window for some reason.")
            return
        end        
        self.wndOpts:Show(false, true)
        Apollo.RegisterSlashCommand("drsb", "OnConfigure", self)
    end

    Apollo.RegisterEventHandler("PublicEventStart", "OnPublicEventStart", self)
    Apollo.RegisterEventHandler("PublicEventLiveStatsUpdate", "OnPublicEventStart", self)
    Apollo.RegisterEventHandler("MatchEntered", "OnMatchEntered", self)    
    Apollo.RegisterEventHandler("MatchExited", "OnMatchExited", self)
    Apollo.RegisterEventHandler("NextFrame", "OnNextFrame", self)
end

-----------------------------------------------------------------------------------------------
-- DrScoreBadger Functions
-----------------------------------------------------------------------------------------------
function DrScoreBadger:OnConfigure()
    self.wndOpts:FindChild("drawHealers"):SetCheck(self.options.bShowHealers)
    self.wndOpts:FindChild("drawScorers"):SetCheck(self.options.bShowScorers)
    self.wndOpts:FindChild("drawDeaths"):SetCheck(self.options.bShowTurds)
    self.wndOpts:FindChild("damagePlayers"):SetText(tostring(self.options.nNumDamage))
    self.wndOpts:FindChild("killsPlayers"):SetText(tostring(self.options.nNumKills))
    self.wndOpts:FindChild("deathsPlayers"):SetText(tostring(self.options.nNumDeaths))

    self.wndOpts:Invoke()
end

function DrScoreBadger:OnSave(eLevel)
    if eLevel ~= GameLib.CodeEnumAddonSaveLevel.Character then
        return nil
    end

    ret = {}
    for k,v in pairs(self.options) do
        ret[k] = v
    end
    return ret
end

function DrScoreBadger:OnRestore(eLevel, tData)
    for k,v in pairs(tData) do
        self.options[k] = v
    end
end

function DrScoreBadger:OnPublicEventStart(peEvent)
    tStats = peEvent:GetLiveStats()
    if tStats == nil or tStats.arTeamStats == nil or #tStats.arTeamStats < 2 then
        return
    end

    myTeam = tStats.arTeamStats[1].bIsMyTeam and tStats.arTeamStats[1].strTeamName or tStats.arTeamStats[2].strTeamName

    enemies = filter_a(tStats.arParticipantStats, function(player) return player.strTeamName ~= myTeam end)

    self.healers = filter_a(enemies, 
            function(player)
                return player.nHealed > player.nDamage and 
                (player.eClass == GameLib.CodeEnumClass.Esper or player.eClass == GameLib.CodeEnumClass.Medic or player.eClass == GameLib.CodeEnumClass.Spellslinger)
            end)

    self.topKillers = filter_a(topK(enemies, self.options.nNumKills, function(p1, p2) return p2.nKills < p1.nKills end),
            function(player) return player.nKills > 0 end)

    self.topDamagers = filter_a(topK(enemies, self.options.nNumDamage, function(p1, p2) return p2.nDamage < p1.nDamage end),
            function(player) return player.nDamage > 0 end)

    self.topDeaths = filter_a(topK(enemies, self.options.nNumDeaths, function(p1, p2) return p2.nDeaths < p1.nDeaths end),
            function(player) return player.nDeaths > 0 end)
end

function DrScoreBadger:OnMatchEntered()
    self.healers = nil
    self.topKillers = nil
    self.topDamagers = nil
    self.topDeaths = nil
end

function DrScoreBadger:OnMatchExited()
    self.healers = nil
    self.topKillers = nil
    self.topDamagers = nil
    self.topDeaths = nil
end

function DrScoreBadger:OnNextFrame()
    self.wndMain:DestroyAllPixies()

    if self.options.bShowHealers then
        self:DrawPixies(self.healers, "drScoreBadgerSprites:plus")
    end

    if self.options.bShowScorers then
        self:DrawPixies(self.topKillers, "drScoreBadgerSprites:king")
        self:DrawPixies(self.topDamagers, "drScoreBadgerSprites:king")
    end

    if self.options.bShowTurds then
        self:DrawPixies(self.topDeaths, "drScoreBadgerSprites:turd")
    end
end

function DrScoreBadger:DrawPixies(players, spriteName)
    if players ~= nil then
        for _, player in pairs(players) do
            unit = player.unitParticipant
            if unit == nil then
                unit = GameLib.GetPlayerUnitByName(player.strName)
            end
            if unit ~= nil then
                pos = GameLib.GetUnitScreenPosition(unit)
                if pos ~= nil and pos.bOnScreen and not unit:IsOccluded() then
                    self.wndMain:AddPixie({strSprite = spriteName, cr = "88FFFFFF", loc = {fPoints = {0, 0, 0, 0}, nOffsets = {pos.nX - 15, pos.nY - 15, pos.nX + 15, pos.nY + 15}}})
                end
            end
        end
    end
end

function topK(t, n, cmp)
    table.sort(t, cmp)
    ret = {}
    for i = 1,n do
        if i > #t then return ret end
        ret[#ret+1] = t[i]
    end
    return ret
end

function filter_a(t, pred)
    ret = {}
    for _, v in pairs(t) do
        if pred(v) then
            ret[#ret + 1] = v
        end
    end
    return ret
end

-----------------------------------------------------------------------------------------------
-- DrScoreBadgerOptionsForm Functions
-----------------------------------------------------------------------------------------------
function DrScoreBadger:OnOK()
    self.options.bShowHealers = self.wndOpts:FindChild("drawHealers"):IsChecked()
    self.options.bShowScorers = self.wndOpts:FindChild("drawScorers"):IsChecked()
    self.options.bShowTurds = self.wndOpts:FindChild("drawDeaths"):IsChecked()
    self.options.nNumDamage = tonumber(self.wndOpts:FindChild("damagePlayers"):GetText()) or 3
    self.options.nNumKills = tonumber(self.wndOpts:FindChild("killsPlayers"):GetText()) or 3
    self.options.nNumDeaths = tonumber(self.wndOpts:FindChild("deathsPlayers"):GetText()) or 3
    self.wndOpts:Close()
end

function DrScoreBadger:OnCancel()
    self.wndOpts:Close()
end

-----------------------------------------------------------------------------------------------
-- DrScoreBadger Instance
-----------------------------------------------------------------------------------------------
local DrScoreBadgerInst = DrScoreBadger:new()
DrScoreBadgerInst:Init()
