-----------------------------------------------------------------------------------------------
-- Client Lua Script for DrScoreBadger
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------

require "Window"

-----------------------------------------------------------------------------------------------
-- DrScoreBadger Module Definition
-----------------------------------------------------------------------------------------------
local DrScoreBadger = {} 

local tRaceHeadHeight = {
    [0] = 3,
    [GameLib.CodeEnumRace.Human] = 2.1,
    [GameLib.CodeEnumRace.Granok] = 3,
    [GameLib.CodeEnumRace.Aurin] = 1.8,
    [GameLib.CodeEnumRace.Draken] = 2.3,
    [GameLib.CodeEnumRace.Mechari] = 2.85,
    [GameLib.CodeEnumRace.Mordesh] = 2.75,
    [GameLib.CodeEnumRace.Chua] = 1.35,
}

local healSprites = {"plus", "plus1", "plus2", "plus3", "plus4"}
local killsSprites = {"king", "king1", "king2", "king3", "king4"}
local deathsSprites = {"turd", "turd1", "turd2", "turd3", "turd4"}

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

    self.options.opacity = 60
    self.options.size = 60
    self.options.height = 100

    self.options.healSprite = 3
    self.options.killsSprite = 3
    self.options.deathsSprite = 4

    self.bTesting = false

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
    Apollo.RegisterEventHandler("TargetUnitChanged", "OnTargetUnitChanged", self)
end

-----------------------------------------------------------------------------------------------
-- DrScoreBadger Functions
-----------------------------------------------------------------------------------------------
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
        self:DrawPixies(self.healers, self:GetHealSprite())
    end

    if self.options.bShowScorers then
        self:DrawPixies(self.topKillers, self:GetKillsSprite())
        self:DrawPixies(self.topDamagers, self:GetKillsSprite())
    end

    if self.options.bShowTurds then
        self:DrawPixies(self.topDeaths, self:GetDeathsSprite())
    end

    if self.bTesting then
        if self.targetUnit == nil then
            self.targetUnit = GameLib.GetTargetUnit()
        end

        if self.targetUnit ~= nil then
            self:DrawPixies({{unitParticipant=self.targetUnit, strName=self.targetUnit:GetName()}}, self.testSprite)
        end
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
                head_height = tRaceHeadHeight[unit:GetRaceId() or 0]
                if unit:IsMounted() then
                    head_height = head_height * 1.5
                end
                -- [0, 100] => [-0.2*h, 2*h]
                badge_height = (self.options.height / 100 * 2.2 - 0.2) * head_height

                height3 = Vector3.New(0, badge_height, 0)
                pos3 = unit:GetPosition()
                if pos3 ~= nil then
                    screen3 = GameLib.WorldLocToScreenPoint(Vector3.New(pos3.x, pos3.y, pos3.z) + height3)
                    offset = self.options.size / 2
                    if not isOccluded(unit) then
                        self.wndMain:AddPixie({strSprite = spriteName, cr = opacityColor(self.options.opacity), 
                                loc = {fPoints = {0, 0, 0, 0}, nOffsets = {screen3["x"] - offset, screen3["y"] - offset, screen3["x"] + offset, screen3["y"] + offset}}})
                    end
                end
            end
        end
    end
end

function DrScoreBadger:UpdateOptionsPixies()
    size = 50
    self.wndOpts:DestroyAllPixies()
    self.wndOpts:AddPixie({strSprite = self:GetHealSprite(),
            loc = {fPoints = {0, 0, 0, 0}, nOffsets = {56, 106, 56 + size, 106 + size}}})
    self.wndOpts:AddPixie({strSprite = self:GetKillsSprite(),
            loc = {fPoints = {0, 0, 0, 0}, nOffsets = {56, 199, 56 + size, 199 + size}}})
    self.wndOpts:AddPixie({strSprite = self:GetDeathsSprite(),
            loc = {fPoints = {0, 0, 0, 0}, nOffsets = {56, 298, 56 + size, 298 + size}}})
end

function DrScoreBadger:OnTargetUnitChanged(unit)
    self.targetUnit = unit
end

function DrScoreBadger:GetHealSprite()
    return "drScoreBadgerSprites:" .. healSprites[self.options.healSprite]
end

function DrScoreBadger:GetKillsSprite()
    return "drScoreBadgerSprites:" .. killsSprites[self.options.killsSprite]
end

function DrScoreBadger:GetDeathsSprite()
    return "drScoreBadgerSprites:" .. deathsSprites[self.options.deathsSprite]
end

-----------------------------------------------------------------------------------------------
-- Helper Functions
-----------------------------------------------------------------------------------------------

function isOccluded(unit)
    pos = GameLib.GetUnitScreenPosition(unit)
    return unit:IsDead() or pos == nil or not pos.bOnScreen or 
            (not unit:IsMounted() and unit:IsOccluded()) or (unit:IsMounted() and unit:GetUnitMount():IsOccluded())
end

function opacityColor(opacity)
    o = opacity/100 * 255
    return string.format("%02x", o) .. "FFFFFF"
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
function DrScoreBadger:OnConfigure()
    self.wndOpts:FindChild("drawHealers"):SetCheck(self.options.bShowHealers)
    self.wndOpts:FindChild("drawScorers"):SetCheck(self.options.bShowScorers)
    self.wndOpts:FindChild("drawDeaths"):SetCheck(self.options.bShowTurds)
    self.wndOpts:FindChild("damagePlayers"):SetText(tostring(self.options.nNumDamage))
    self.wndOpts:FindChild("killsPlayers"):SetText(tostring(self.options.nNumKills))
    self.wndOpts:FindChild("deathsPlayers"):SetText(tostring(self.options.nNumDeaths))

    self.wndOpts:FindChild("opacitySliderBar"):SetValue(self.options.opacity)
    self.wndOpts:FindChild("sizeSliderBar"):SetValue(self.options.size)
    self.wndOpts:FindChild("heightSliderBar"):SetValue(self.options.height)

    self.prevOpacity = self.options.opacity
    self.prevSize = self.options.size
    self.prevHeight = self.options.height
    self.prevHealSprite = self.options.healSprite
    self.prevKillsSprite = self.options.killsSprite
    self.prevDeathsSprite = self.options.deathsSprite

    self.bTesting = false
    self.wndOpts:FindChild("testSettings"):SetText("Test Settings on current target")

    self.testSprite = self:GetHealSprite()
    self:UpdateOptionsPixies()

    self.wndOpts:Invoke()
end

function DrScoreBadger:OnOK()
    self.options.bShowHealers = self.wndOpts:FindChild("drawHealers"):IsChecked()
    self.options.bShowScorers = self.wndOpts:FindChild("drawScorers"):IsChecked()
    self.options.bShowTurds = self.wndOpts:FindChild("drawDeaths"):IsChecked()
    self.options.nNumDamage = tonumber(self.wndOpts:FindChild("damagePlayers"):GetText()) or 3
    self.options.nNumKills = tonumber(self.wndOpts:FindChild("killsPlayers"):GetText()) or 3
    self.options.nNumDeaths = tonumber(self.wndOpts:FindChild("deathsPlayers"):GetText()) or 3
    self.options.opacity = self.wndOpts:FindChild("opacitySliderBar"):GetValue()
    self.options.size = self.wndOpts:FindChild("sizeSliderBar"):GetValue()
    self.options.height = self.wndOpts:FindChild("heightSliderBar"):GetValue()

    self.bTesting = false
    self.wndOpts:Close()
end

function DrScoreBadger:OnCancel()
    self.options.opacity = self.prevOpacity
    self.options.size = self.prevSize
    self.options.height = self.prevHeight
    self.options.healSprite = self.prevHealSprite
    self.options.killsSprite = self.prevKillsSprite
    self.options.deathsSprite = self.prevDeathsSprite

    self.bTesting = false
    self.wndOpts:Close()
end

function DrScoreBadger:OnTestSettings()
    self.bTesting = not self.bTesting
    text = self.bTesting and "Stop Testing" or "Test Settings on current target"
    self.wndOpts:FindChild("testSettings"):SetText(text)
end

function DrScoreBadger:OnOpacityChanged()
    self.options.opacity = self.wndOpts:FindChild("opacitySliderBar"):GetValue()
end

function DrScoreBadger:OnSizeChanged()
    self.options.size = self.wndOpts:FindChild("sizeSliderBar"):GetValue()
end

function DrScoreBadger:OnHeightChanged()
    self.options.height = self.wndOpts:FindChild("heightSliderBar"):GetValue()
end

function DrScoreBadger:OnHealNext()
    self.options.healSprite = (self.options.healSprite % #healSprites) + 1
    self:UpdateOptionsPixies()
    self.testSprite = self:GetHealSprite()
end

function DrScoreBadger:OnHealPrev()
    self.options.healSprite = ((self.options.healSprite - 2) % #healSprites) + 1
    self:UpdateOptionsPixies()
    self.testSprite = self:GetHealSprite()
end

function DrScoreBadger:OnKillsNext()
    self.options.killsSprite = (self.options.killsSprite % #killsSprites) + 1
    self:UpdateOptionsPixies()
    self.testSprite = self:GetKillsSprite()
end

function DrScoreBadger:OnKillsPrev()
    self.options.killsSprite = ((self.options.killsSprite - 2) % #killsSprites) + 1
    self:UpdateOptionsPixies()
    self.testSprite = self:GetKillsSprite()
end

function DrScoreBadger:OnDeathsNext()
    self.options.deathsSprite = (self.options.deathsSprite % #deathsSprites) + 1
    self:UpdateOptionsPixies()
    self.testSprite = self:GetDeathsSprite()
end

function DrScoreBadger:OnDeathsPrev()
    self.options.deathsSprite = ((self.options.deathsSprite - 2) % #deathsSprites) + 1
    self:UpdateOptionsPixies()
    self.testSprite = self:GetDeathsSprite()
end

-----------------------------------------------------------------------------------------------
-- DrScoreBadger Instance
-----------------------------------------------------------------------------------------------
local DrScoreBadgerInst = DrScoreBadger:new()
DrScoreBadgerInst:Init()
