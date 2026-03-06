-- Universal Hub - LinoriaLib + Unnamed ESP Core (No duplicate UI)
print("Loading Universal Hub...")

-- Load LinoriaLib
local success, Library = pcall(function()
    return loadstring(game:HttpGet("https://raw.githubusercontent.com/violin-suzutsuki/LinoriaLib/main/Library.lua"))()
end)

if not success then
    warn("Failed to load Library - trying alternative...")
    Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/violin-suzutsuki/LinoriaLib/main/Library.lua"))()
end

local ThemeManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/violin-suzutsuki/LinoriaLib/main/addons/ThemeManager.lua"))()
local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/violin-suzutsuki/LinoriaLib/main/addons/SaveManager.lua"))()

-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

-- Create window
local Window = Library:CreateWindow({
    Title = "Universal Hub",
    Center = true,
    AutoShow = true
})

-- Create tabs
local Tabs = {
    ESP = Window:AddTab("ESP"),
    Player = Window:AddTab("Player"),
    Movement = Window:AddTab("Movement"),
    Misc = Window:AddTab("Misc"),
    Settings = Window:AddTab("Settings")
}

-- ============================================
-- ESP CORE (adapted from Unnamed ESP)
-- ============================================

assert(Drawing, 'exploit not supported')

if not cloneref then cloneref = function(o) return o end end

local HttpService = cloneref(game:GetService'HttpService')
local TweenService = cloneref(game:GetService'TweenService')
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local V2New = Vector2.new
local V3New = Vector3.new
local WTVP = Camera.WorldToViewportPoint
local WorldToViewport = function(...) return WTVP(Camera, ...) end
local Menu = {}
local LastRefresh = 0
local OptionsFile = 'IC3_ESP_SETTINGS.dat'
local OIndex = 0
local LineBox = {}
local IgnoreList = {}
local EnemyColor = Color3.new(1, 0, 0)
local TeamColor = Color3.new(0, 1, 0)
local TracerPosition = V2New(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y - 135)
local IsSynapse = syn and not PROTOSMASHER_LOADED
local Connections = { Active = {} }
local Signal = {} Signal.__index = Signal
local GetCharacter, Spectating

local Mouse = pcall(function() return LocalPlayer:GetMouse() end) and LocalPlayer:GetMouse() or nil
local Terrain = workspace:FindFirstChild'Terrain'
local QUAD_SUPPORTED_EXPLOIT = pcall(function() Drawing.new('Quad'):Remove() end)

-- Clean up stale Drawing objects from previous script execution
if shared.InstanceData then
    for i, v in pairs(shared.InstanceData) do
        if v.Instances then
            for _, obj in pairs(v.Instances) do
                pcall(function()
                    if typeof(obj) == 'table' and obj.SetVisible then
                        obj:SetVisible(false)
                        obj:Remove()
                    elseif typeof(obj) == 'userdata' or (typeof(obj) == 'table' and obj.Remove) then
                        pcall(function() obj.Visible = false end)
                        pcall(function() obj:Remove() end)
                    end
                end)
            end
        end
    end
end
if shared.MenuDrawingData and shared.MenuDrawingData.Instances then
    for _, inst in pairs(shared.MenuDrawingData.Instances) do
        pcall(function() inst.Visible = false; inst:Remove() end)
    end
end

shared.MenuDrawingData = { Instances = {} }
shared.InstanceData = {}
shared.RSName = shared.RSName or ('UnnamedESP_by_ic3-' .. HttpService:GenerateGUID(false))

local GetDataName = shared.RSName .. '-GetData'
local UpdateName = shared.RSName .. '-Update'

local Debounce = setmetatable({}, {
    __index = function(t, i)
        return rawget(t, i) or false
    end
})

local function IsStringEmpty(String)
    if type(String) == 'string' then
        return String:match'^%s+$' ~= nil or #String == 0 or String == '' or false;
    end
    return false;
end

local function Set(t, i, v) t[i] = v end

local Teams = {};
local CustomTeams = { -- Games that don't use roblox's team system
    [2563455047] = {
        Initialize = function()
            Teams.Sheriffs = {};
            Teams.Bandits = {};
            local Func = game:GetService'ReplicatedStorage':WaitForChild('RogueFunc', 1);
            local Event = game:GetService'ReplicatedStorage':WaitForChild('RogueEvent', 1);
            local S, B = Func:InvokeServer'AllTeamData';

            Teams.Sheriffs = S;
            Teams.Bandits = B;

            Event.OnClientEvent:Connect(function(id, PlayerName, Team, Remove)
                if id == 'UpdateTeam' then
                    local TeamTable, NotTeamTable
                    if Team == 'Bandits' then
                        TeamTable = TDM.Bandits
                        NotTeamTable = TDM.Sheriffs
                    else
                        TeamTable = TDM.Sheriffs
                        NotTeamTable = TDM.Bandits
                    end
                    if Remove then
                        TeamTable[PlayerName] = nil
                    else
                        TeamTable[PlayerName] = true
                        NotTeamTable[PlayerName] = nil
                    end
                    if PlayerName == LocalPlayer.Name then
                        TDM.Friendlys = TeamTable
                        TDM.Enemies = NotTeamTable
                    end
                end
            end)
        end;
        CheckTeam = function(Player)
            local LocalTeam = Teams.Sheriffs[LocalPlayer.Name] and Teams.Sheriffs or Teams.Bandits;
            return LocalTeam[Player.Name] and true or false;
        end;
    };
    [5208655184] = {
        CheckTeam = function(Player)
            local LocalLastName = LocalPlayer:GetAttribute'LastName' if not LocalLastName or IsStringEmpty(LocalLastName) then return true end
            local PlayerLastName = Player:GetAttribute'LastName' if not PlayerLastName then return false end
            return PlayerLastName == LocalLastName
        end
    };
    [3541987450] = {
        CheckTeam = function(Player)
            local LocalStats = LocalPlayer:FindFirstChild'leaderstats';
            local LocalLastName = LocalStats and LocalStats:FindFirstChild'LastName'; if not LocalLastName or IsStringEmpty(LocalLastName.Value) then return true; end
            local PlayerStats = Player:FindFirstChild'leaderstats';
            local PlayerLastName = PlayerStats and PlayerStats:FindFirstChild'LastName'; if not PlayerLastName then return false; end
            return PlayerLastName.Value == LocalLastName.Value;
        end;
    };
    [6032399813] = {
        CheckTeam = function(Player)
            local LocalStats = LocalPlayer:FindFirstChild'leaderstats';
            local LocalGuildName = LocalStats and LocalStats:FindFirstChild'Guild'; if not LocalGuildName or IsStringEmpty(LocalGuildName.Value) then return true; end
            local PlayerStats = Player:FindFirstChild'leaderstats';
            local PlayerGuildName = PlayerStats and PlayerStats:FindFirstChild'Guild'; if not PlayerGuildName then return false; end
            return PlayerGuildName.Value == LocalGuildName.Value;
        end;
    };
    [5735553160] = {
        CheckTeam = function(Player)
            local LocalStats = LocalPlayer:FindFirstChild'leaderstats';
            local LocalGuildName = LocalStats and LocalStats:FindFirstChild'Guild'; if not LocalGuildName or IsStringEmpty(LocalGuildName.Value) then return true; end
            local PlayerStats = Player:FindFirstChild'leaderstats';
            local PlayerGuildName = PlayerStats and PlayerStats:FindFirstChild'Guild'; if not PlayerGuildName then return false; end
            return PlayerGuildName.Value == LocalGuildName.Value;
        end;
    };
};

local RenderList = {Instances = {}};

function RenderList:AddOrUpdateInstance(Instance, Obj2Draw, Text, Color)
    RenderList.Instances[Instance] = { ParentInstance = Instance; Instance = Obj2Draw; Text = Text; Color = Color };
    return RenderList.Instances[Instance];
end

local CustomPlayerTag;
local CustomESP;
local CustomCharacter;
local GetHealth;
local GetAliveState;
local CustomRootPartName;

local Modules = {
    [292439477] = {
        Initialize = function()
            if not create_comm_channel or not get_comm_channel then return end
            local run_on_actor = runonactor or run_on_actor
            local EventID, Event = create_comm_channel()
            Event.Event:Connect(function(List)
                PF_CharList = List
            end)
            for Index, Actor in pairs(getactors()) do
                run_on_actor(Actor, [[
                    local Event = get_comm_channel(...)
                    if not getrenv().shared.require then return end
                    local RunService = game:GetService'RunService'
                    local Cache = debug.getupvalues(getrenv().shared.require)[1]._cache if not Cache then return end
                    local ReplicationInterface = rawget(rawget(Cache, 'ReplicationInterface'), 'module') if not ReplicationInterface then return end
                    local getEntry = rawget(ReplicationInterface, 'getEntry')
                    if shared.UNPFHB then shared.UNPFHB:Disconnect() end
                    shared.UNPFHB = RunService.Heartbeat:Connect(function()
                        local CharacterList = {}
                        for Player, Entry in pairs(debug.getupvalues(getEntry)[1]) do
                            local TPO = rawget(Entry, '_thirdPersonObject') if not TPO then continue end
                            local Character = rawget(TPO, '_characterHash') if not Character then continue end
                            local Torso = rawget(Character, 'Torso') if not Torso then continue end
                            local HealthState = rawget(Entry, '_healthstate')
                            CharacterList[Player.Name] = {
                                Head = Character.Head,
                                Torso = Character.Torso,
                                Health = HealthState and rawget(HealthState, 'health0') or 100,
                                Alive = rawget(Entry, '_alive')
                            }
                        end
                        Event:Fire(CharacterList)
                    end)
                ]], EventID)
            end
        end,
        CustomCharacter = function(Player)
            if not shared.PF_CharMT then
                shared.PF_CharMT = {}
                shared.PF_CharMT.__index = shared.PF_CharMT
                function shared.PF_CharMT:FindFirstChild(Name)
                    return rawget(self, Name)
                end
                function shared.PF_CharMT:FindFirstChildOfClass() end
            end
            if PF_CharList and PF_CharList[Player.Name] then
                local Character = PF_CharList[Player.Name]
                setmetatable(Character, shared.PF_CharMT)
                return Character
            end
        end,
        GetHealth = function(Player)
            if PF_CharList and PF_CharList[Player.Name] then
                return PF_CharList[Player.Name].Health
            end
        end,
        GetAliveState = function(Player)
            if PF_CharList and PF_CharList[Player.Name] then
                return PF_CharList[Player.Name].Alive
            end
        end,
        CustomRootPartName = 'Torso',
    };
    [2950983942] = {
        CustomCharacter = function(Player)
            if workspace:FindFirstChild'Players' then
                return workspace.Players:FindFirstChild(Player.Name);
            end
        end
    };
    [2262441883] = {
        CustomPlayerTag = function(Player)
            return Player:FindFirstChild'Job' and (' [' .. Player.Job.Value .. ']') or '';
        end;
        CustomESP = function()
            if workspace:FindFirstChild'MoneyPrinters' then
                for i, v in pairs(workspace.MoneyPrinters:GetChildren()) do
                    local Main    = v:FindFirstChild'Main';
                    local Owner    = v:FindFirstChild'TrueOwner';
                    local Money    = v:FindFirstChild'Int' and v.Int:FindFirstChild'Money' or nil;
                    if Main and Owner and Money then
                        local O = tostring(Owner.Value);
                        local M = tostring(Money.Value);
                        pcall(RenderList.AddOrUpdateInstance, RenderList, v, Main, string.format('Money Printer\nOwned by %s\n[%s]', O, M), Color3.fromRGB(13, 255, 227));
                    end
                end
            end
        end;
    };
    [4801598506] = {
        CustomESP = function()
            if workspace:FindFirstChild'Mobs' and workspace.Mobs:FindFirstChild'Forest1' then
                for i, v in pairs(workspace.Mobs.Forest1:GetChildren()) do
                    local Main    = v:FindFirstChild'Head';
                    local Hum    = v:FindFirstChild'Mob';
                    if Main and Hum then
                        pcall(RenderList.AddOrUpdateInstance, RenderList, v, Main, string.format('[%s] [%s/%s]', v.Name, Hum.Health, Hum.MaxHealth), Color3.fromRGB(13, 255, 227));
                    end
                end
            end
        end;
    };
    [2555873122] = {
        CustomESP = function()
            if workspace:FindFirstChild'WoodPlanks' then
                for i, v in pairs(workspace:GetChildren()) do
                    if v.Name == 'WoodPlanks' then
                        local Main = v:FindFirstChild'Wood';
                        if Main then
                            pcall(RenderList.AddOrUpdateInstance, RenderList, v, Main, 'Wood Planks', Color3.fromRGB(13, 255, 227));
                        end
                    end
                end
            end
        end;
    };
    [5208655184] = {
        CustomPlayerTag = function(Player)
            if game.PlaceVersion < 457 then return '' end
            local Name = '';
            local FirstName = Player:GetAttribute'FirstName'
            if typeof(FirstName) == 'string' and #FirstName > 0 then
                local Prefix = '';
                local Extra = {};
                Name = Name .. '\n[';
                if Player:GetAttribute'Prestige' > 0 then
                    Name = Name .. '#' .. tostring(Player:GetAttribute'Prestige') .. ' ';
                end
                if not IsStringEmpty(Player:GetAttribute'HouseRank') then
                    Prefix = Player:GetAttribute'HouseRank' == 'Owner' and (Player:GetAttribute'Gender' == 'Female' and 'Lady ' or 'Lord ') or '';
                end
                if not IsStringEmpty(FirstName) then
                    Name = Name .. '' .. Prefix .. FirstName;
                end
                if not IsStringEmpty(Player:GetAttribute'LastName') then
                    Name = Name .. ' ' .. Player:GetAttribute'LastName';
                end
                if not IsStringEmpty(Name) then Name = Name .. ']'; end
                local Character = GetCharacter(Player);
                if Character then
                    if Character and Character:FindFirstChild'Danger' then table.insert(Extra, 'D'); end
                    if Character:FindFirstChild'ManaAbilities' and Character.ManaAbilities:FindFirstChild'ManaSprint' then table.insert(Extra, 'D1'); end
                    if Character:FindFirstChild'Mana'         then table.insert(Extra, 'M' .. math.floor(Character.Mana.Value)); end
                    if Character:FindFirstChild'Vampirism'     then table.insert(Extra, 'V'); end
                    if Character:FindFirstChild'Observe'        then table.insert(Extra, 'ILL'); end
                    if Character:FindFirstChild'Inferi'            then table.insert(Extra, 'NEC'); end
                    if Character:FindFirstChild'World\'s Pulse' then table.insert(Extra, 'DZIN'); end
                    if Character:FindFirstChild'Shift'         then table.insert(Extra, 'MAD'); end
                    if Character:FindFirstChild'Head' and Character.Head:FindFirstChild'FacialMarking' then
                        local FM = Character.Head:FindFirstChild'FacialMarking';
                        if FM.Texture == 'http://www.roblox.com/asset/?id=4072968006' then
                            table.insert(Extra, 'HEALER');
                        elseif FM.Texture == 'http://www.roblox.com/asset/?id=4072914434' then
                            table.insert(Extra, 'SEER');
                        elseif FM.Texture == 'http://www.roblox.com/asset/?id=4094417635' then
                            table.insert(Extra, 'JESTER');
                        elseif FM.Texture == 'http://www.roblox.com/asset/?id=4072968656' then
                            table.insert(Extra, 'BLADE');
                        end
                    end
                end
                if Player:FindFirstChild'Backpack' then
                    if Player.Backpack:FindFirstChild'Observe'             then table.insert(Extra, 'ILL');  end
                    if Player.Backpack:FindFirstChild'Inferi'            then table.insert(Extra, 'NEC');  end
                    if Player.Backpack:FindFirstChild'World\'s Pulse'     then table.insert(Extra, 'DZIN'); end
                    if Player.Backpack:FindFirstChild'Shift'             then table.insert(Extra, 'MAD'); end
                end
                if #Extra > 0 then Name = Name .. ' [' .. table.concat(Extra, '-') .. ']'; end
            end
            return Name;
        end;
    };
    [3541987450] = {
        CustomPlayerTag = function(Player)
            local Name = '';
            if Player:FindFirstChild'leaderstats' then
                Name = Name .. '\n[';
                local Prefix = '';
                local Extra = {};
                if Player.leaderstats:FindFirstChild'Prestige' and Player.leaderstats.Prestige.ClassName == 'IntValue' and Player.leaderstats.Prestige.Value > 0 then
                    Name = Name .. '#' .. tostring(Player.leaderstats.Prestige.Value) .. ' ';
                end
                if Player.leaderstats:FindFirstChild'HouseRank' and Player.leaderstats:FindFirstChild'Gender' and Player.leaderstats.HouseRank.ClassName == 'StringValue' and not IsStringEmpty(Player.leaderstats.HouseRank.Value) then
                    Prefix = Player.leaderstats.HouseRank.Value == 'Owner' and (Player.leaderstats.Gender.Value == 'Female' and 'Lady ' or 'Lord ') or '';
                end
                if Player.leaderstats:FindFirstChild'FirstName' and Player.leaderstats.FirstName.ClassName == 'StringValue' and not IsStringEmpty(Player.leaderstats.FirstName.Value) then
                    Name = Name .. '' .. Prefix .. Player.leaderstats.FirstName.Value;
                end
                if Player.leaderstats:FindFirstChild'LastName' and Player.leaderstats.LastName.ClassName == 'StringValue' and not IsStringEmpty(Player.leaderstats.LastName.Value) then
                    Name = Name .. ' ' .. Player.leaderstats.LastName.Value;
                end
                if Player.leaderstats:FindFirstChild'UberTitle' and Player.leaderstats.UberTitle.ClassName == 'StringValue' and not IsStringEmpty(Player.leaderstats.UberTitle.Value) then
                    Name = Name .. ', ' .. Player.leaderstats.UberTitle.Value;
                end
                if not IsStringEmpty(Name) then Name = Name .. ']'; end
                local Character = GetCharacter(Player);
                if Character then
                    if Character and Character:FindFirstChild'Danger' then table.insert(Extra, 'D'); end
                    if Character:FindFirstChild'ManaAbilities' and Character.ManaAbilities:FindFirstChild'ManaSprint' then table.insert(Extra, 'D1'); end
                    if Character:FindFirstChild'Mana'         then table.insert(Extra, 'M' .. math.floor(Character.Mana.Value)); end
                    if Character:FindFirstChild'Vampirism'     then table.insert(Extra, 'V');    end
                    if Character:FindFirstChild'Observe'        then table.insert(Extra, 'ILL');  end
                    if Character:FindFirstChild'Inferi'            then table.insert(Extra, 'NEC');  end
                    if Character:FindFirstChild'World\'s Pulse'     then table.insert(Extra, 'DZIN'); end
                    if Character:FindFirstChild'Head' and Character.Head:FindFirstChild'FacialMarking' then
                        local FM = Character.Head:FindFirstChild'FacialMarking';
                        if FM.Texture == 'http://www.roblox.com/asset/?id=4072968006' then
                            table.insert(Extra, 'HEALER');
                        elseif FM.Texture == 'http://www.roblox.com/asset/?id=4072914434' then
                            table.insert(Extra, 'SEER');
                        elseif FM.Texture == 'http://www.roblox.com/asset/?id=4094417635' then
                            table.insert(Extra, 'JESTER');
                        end
                    end
                end
                if Player:FindFirstChild'Backpack' then
                    if Player.Backpack:FindFirstChild'Observe'             then table.insert(Extra, 'ILL');  end
                    if Player.Backpack:FindFirstChild'Inferi'            then table.insert(Extra, 'NEC');  end
                    if Player.Backpack:FindFirstChild'World\'s Pulse'     then table.insert(Extra, 'DZIN'); end
                end
                if #Extra > 0 then Name = Name .. ' [' .. table.concat(Extra, '-') .. ']'; end
            end
            return Name;
        end;
    };
    [4691401390] = { -- Vast Realm
        CustomCharacter = function(Player)
            if workspace:FindFirstChild'Players' then
                return workspace.Players:FindFirstChild(Player.Name);
            end
        end
    };
    [6032399813] = { -- Deepwoken [Etrean]
        CustomPlayerTag = function(Player)
            local Name = '';
            CharacterName = Player:GetAttribute'CharacterName';
            if not IsStringEmpty(CharacterName) then
                Name = ('\n[%s]'):format(CharacterName);
                local Character = GetCharacter(Player);
                local Extra = {};
                if Character then
                    local Blood, Armor = Character:FindFirstChild('Blood'), Character:FindFirstChild('Armor');
                    if Blood and Blood.ClassName == 'DoubleConstrainedValue' then
                        table.insert(Extra, ('B%d'):format(Blood.Value));
                    end
                    if Armor and Armor.ClassName == 'DoubleConstrainedValue' then
                        table.insert(Extra, ('A%d'):format(math.floor(Armor.Value / 10)));
                    end
                end
                local BackpackChildren = Player.Backpack:GetChildren()
                for index = 1, #BackpackChildren do
                    local Oath = BackpackChildren[index]
                    if Oath.ClassName == 'Folder' and Oath.Name:find('Talent:Oath') then
                        local OathName = Oath.Name:gsub('Talent:Oath: ', '')
                        table.insert(Extra, OathName);
                    end
                end
                if #Extra > 0 then Name = Name .. ' [' .. table.concat(Extra, '-') .. ']'; end
            end
            return Name;
        end;
    };
    [5735553160] = { -- Deepwoken [Depths]
        CustomPlayerTag = function(Player)
            local Name = '';
            CharacterName = Player:GetAttribute'CharacterName';
            if not IsStringEmpty(CharacterName) then
                Name = ('\n[%s]'):format(CharacterName);
                local Character = GetCharacter(Player);
                local Extra = {};
                if Character then
                    local Blood, Armor = Character:FindFirstChild('Blood'), Character:FindFirstChild('Armor');
                    if Blood and Blood.ClassName == 'DoubleConstrainedValue' then
                        table.insert(Extra, ('B%d'):format(Blood.Value));
                    end
                    if Armor and Armor.ClassName == 'DoubleConstrainedValue' then
                        table.insert(Extra, ('A%d'):format(math.floor(Armor.Value / 10)));
                    end
                end
                local BackpackChildren = Player.Backpack:GetChildren()
                for index = 1, #BackpackChildren do
                    local Oath = BackpackChildren[index]
                    if Oath.ClassName == 'Folder' and Oath.Name:find('Talent:Oath') then
                        local OathName = Oath.Name:gsub('Talent:Oath: ', '')
                        table.insert(Extra, OathName);
                    end
                end
                if #Extra > 0 then Name = Name .. ' [' .. table.concat(Extra, '-') .. ']'; end
            end
            return Name;
        end;
    };
    [3127094264] = {
        CustomCharacter = function(Player)
            if not _FIRST then
                _FIRST = true
                pcall(function()
                    local GPM = rawget(require(LocalPlayer.PlayerScripts:WaitForChild('Client', 5):WaitForChild('Player', 5)), 'GetPlayerModel')
                    PList = debug.getupvalue(GPM, 1)
                end)
            end
            if PList then
                local Player = rawget(PList, Player.UserId)
                if Player and Player.model then
                    return Player.model
                end
            end
        end
    }
};

if Modules[game.PlaceId] ~= nil or Modules[game.GameId] ~= nil then
    local Module = Modules[game.PlaceId] or Modules[game.GameId]
    if Module.Initialize then
        Module.Initialize()
    end
    CustomPlayerTag = Module.CustomPlayerTag or nil
    CustomESP = Module.CustomESP or nil
    CustomCharacter = Module.CustomCharacter or nil
    GetHealth = Module.GetHealth or nil
    GetAliveState = Module.GetAliveState or nil
    CustomRootPartName = Module.CustomRootPartName or nil
end

function GetCharacter(Player)
    return CustomCharacter and CustomCharacter(Player) or Player.Character
end

function GetMouseLocation()
    return UserInputService:GetMouseLocation();
end

function GetTableData(t)
    if typeof(t) ~= 'table' then return end
    return setmetatable(t, {
        __call = function(t, func)
            if typeof(func) ~= 'function' then return end;
            for i, v in pairs(t) do
                pcall(func, i, v);
            end
        end;
    });
end
local function Format(format, ...)
    return string.format(format, ...)
end
function CalculateValue(Min, Max, Percent)
    return Min + math.floor(((Max - Min) * Percent) + .5);
end

function NewDrawing(InstanceName)
    local Instance = Drawing.new(InstanceName)
    return (function(Properties)
        for i, v in pairs(Properties) do
            pcall(Set, Instance, i, v)
        end
        return Instance
    end)
end

function Menu:AddMenuInstance(Name, DrawingType, Properties)
    local Instance;
    if shared.MenuDrawingData.Instances[Name] ~= nil then
        Instance = shared.MenuDrawingData.Instances[Name];
        for i, v in pairs(Properties) do
            pcall(Set, Instance, i, v);
        end
    else
        Instance = NewDrawing(DrawingType)(Properties);
    end
    shared.MenuDrawingData.Instances[Name] = Instance;
    return Instance;
end
function Menu:UpdateMenuInstance(Name)
    local Instance = shared.MenuDrawingData.Instances[Name];
    if Instance ~= nil then
        return (function(Properties)
            for i, v in pairs(Properties) do
                pcall(Set, Instance, i, v);
            end
            return Instance;
        end)
    end
end
function Menu:GetInstance(Name)
    return shared.MenuDrawingData.Instances[Name];
end

local Options = setmetatable({}, {
    __call = function(t, ...)
        local Arguments = {...};
        local Name = Arguments[1];
        OIndex = OIndex + 1;
        rawset(t, Name, setmetatable({
            Name            = Arguments[1];
            Text            = Arguments[2];
            Value            = Arguments[3];
            DefaultValue    = Arguments[3];
            AllArgs            = Arguments;
            Index            = OIndex;
        }, {
            __call = function(t, v, force)
                local self = t;
                if typeof(t.Value) == 'function' then
                    t.Value();
                elseif typeof(t.Value) == 'EnumItem' then
                    -- keybind handling removed
                else
                    local NewValue = v;
                    if NewValue == nil then NewValue = not t.Value; end
                    rawset(t, 'Value', NewValue);
                end
            end;
        }));
    end;
})

function Load(IgnoreFile)
    if IgnoreFile or not readfile then return end
    local _, Result = pcall(readfile, OptionsFile);
    if _ then
        local _, Table = pcall(HttpService.JSONDecode, HttpService, Result);
        if _ and typeof(Table) == 'table' then
            for i, v in pairs(Table) do
                if typeof(Options[i]) == 'table' and Options[i].Value ~= nil and (typeof(Options[i].Value) == 'boolean' or typeof(Options[i].Value) == 'number') then
                    Options[i].Value = v.Value;
                    pcall(Options[i], v.Value);
                end
            end
            if Table.TeamColor then TeamColor = Color3.new(Table.TeamColor.R, Table.TeamColor.G, Table.TeamColor.B) end
            if Table.EnemyColor then EnemyColor = Color3.new(Table.EnemyColor.R, Table.EnemyColor.G, Table.EnemyColor.B) end
        end
    end
end

-- ==================== CUSTOM HEALTHBAR ADDON ====================
local HealthbarObjects = {}

local function CreateHealthbar(player)
    if player == LocalPlayer then return end
    if HealthbarObjects[player] then
        pcall(function()
            if HealthbarObjects[player].Background then HealthbarObjects[player].Background:Remove() end
            if HealthbarObjects[player].Fill then HealthbarObjects[player].Fill:Remove() end
            if HealthbarObjects[player].Text then HealthbarObjects[player].Text:Remove() end
        end)
    end
    local healthbar = {
        Background = Drawing.new("Square"),
        Fill = Drawing.new("Square"),
        Text = Drawing.new("Text")
    }
    healthbar.Background.Filled = true
    healthbar.Background.Color = Color3.fromRGB(30, 30, 30)
    healthbar.Background.Transparency = 0.5
    healthbar.Background.Visible = false
    healthbar.Fill.Filled = true
    healthbar.Fill.Visible = false
    healthbar.Text.Center = true
    healthbar.Text.Outline = true
    healthbar.Text.Color = Color3.new(1, 1, 1)
    healthbar.Text.Size = 13
    healthbar.Text.Visible = false
    HealthbarObjects[player] = healthbar
    return healthbar
end
-- ==================== END CUSTOM HEALTHBAR ADDON ====================

-- Options
Options('Enabled', 'ESP Enabled', true);
Options('ShowTeam', 'Show Team', true);
Options('ShowTeamColor', 'Show Team Color', false);
Options('ShowName', 'Show Names', false);
Options('ShowDistance', 'Show Distance', false);
Options('ShowHealth', 'Show Health', false);
Options('ShowBoxes', 'Show Boxes', false);
Options('ShowTracers', 'Show Tracers', false);
Options('ShowDot', 'Show Head Dot', false);
Options('VisCheck', 'Visibility Check', false);
Options('Crosshair', 'Crosshair', false);
Options('TextOutline', 'Text Outline', true);
Options('TextSize', 'Text Size', syn and 18 or 14, 10, 24);
Options('MaxDistance', 'Max Distance', 2500, 100, 25000);
Options('RefreshRate', 'Refresh Rate (ms)', 5, 1, 200);
Options('YOffset', 'Y Offset', 0, -200, 200);
-- Custom healthbar options
Options('ShowCustomHealthbar', 'Show Healthbars', true);
Options('HealthbarWidth', 'Healthbar Width', 50, 30, 100);
Options('HealthbarHeight', 'Healthbar Height', 4, 2, 10);
Options('HealthbarOffset', 'Healthbar Offset', 70, 30, 100);

Load(1);

Options('MenuOpen', nil, false); -- We don't need a menu open state for drawing menu

local function Combine(...)
    local Output = {};
    for i, v in pairs{...} do
        if typeof(v) == 'table' then
            table.foreach(v, function(i, v)
                Output[i] = v;
            end)
        end
    end
    return Output
end

function LineBox:Create(Properties)
    local Box = { Visible = true };
    local Properties = Combine({
        Transparency    = 1;
        Thickness        = 3;
        Visible            = true;
    }, Properties);
    if shared.am_ic3 then
        Box['OutlineSquare']= NewDrawing'Square'(Properties);
        Box['Square']         = NewDrawing'Square'(Properties);
    elseif QUAD_SUPPORTED_EXPLOIT then
        Box['Quad']            = NewDrawing'Quad'(Properties);
    else
        Box['TopLeft']        = NewDrawing'Line'(Properties);
        Box['TopRight']        = NewDrawing'Line'(Properties);
        Box['BottomLeft']    = NewDrawing'Line'(Properties);
        Box['BottomRight']    = NewDrawing'Line'(Properties);
    end
    function Box:Update(CF, Size, Color, Properties, Parts)
        if not CF or not Size then return end
        if shared.am_ic3 and typeof(Parts) == 'table' then
            local AllCorners = {};
            for i, v in pairs(Parts) do
                local CF, Size = v.CFrame, v.Size;
                local Corners = {
                    Vector3.new(CF.X + Size.X / 2, CF.Y + Size.Y / 2, CF.Z + Size.Z / 2);
                    Vector3.new(CF.X - Size.X / 2, CF.Y + Size.Y / 2, CF.Z + Size.Z / 2);
                    Vector3.new(CF.X - Size.X / 2, CF.Y - Size.Y / 2, CF.Z - Size.Z / 2);
                    Vector3.new(CF.X + Size.X / 2, CF.Y - Size.Y / 2, CF.Z - Size.Z / 2);
                    Vector3.new(CF.X - Size.X / 2, CF.Y + Size.Y / 2, CF.Z - Size.Z / 2);
                    Vector3.new(CF.X + Size.X / 2, CF.Y + Size.Y / 2, CF.Z - Size.Z / 2);
                    Vector3.new(CF.X - Size.X / 2, CF.Y - Size.Y / 2, CF.Z + Size.Z / 2);
                    Vector3.new(CF.X + Size.X / 2, CF.Y - Size.Y / 2, CF.Z + Size.Z / 2);
                };
                for i, v in pairs(Corners) do
                    table.insert(AllCorners, v);
                end
            end
            local xMin, yMin = Camera.ViewportSize.X, Camera.ViewportSize.Y;
            local xMax, yMax = 0, 0;
            local Vs = true;
            for i, v in pairs(AllCorners) do                
                local Position, V = WorldToViewport(v);
                if VS and not V then Vs = false break end
                if Position.X > xMax then xMax = Position.X; end
                if Position.X < xMin then xMin = Position.X; end
                if Position.Y > yMax then yMax = Position.Y; end
                if Position.Y < yMin then yMin = Position.Y; end
            end
            local xSize, ySize = xMax - xMin, yMax - yMin;
            local Outline = Box['OutlineSquare'];
            local Square = Box['Square'];
            Outline.Visible = Vs;
            Square.Visible = Vs;
            Square.Position = V2New(xMin, yMin);
            Square.Color    = Color;
            Square.Thickness = math.floor(Outline.Thickness * 0.3);
            Square.Size = V2New(xSize, ySize);
            Outline.Position = Square.Position;
            Outline.Size = Square.Size;
            Outline.Color = Color3.new(0.12, 0.12, 0.12);
            Outline.Transparency = 0.75;
            return
        end
        local TLPos, Visible1    = WorldToViewport((CF * CFrame.new( Size.X,  Size.Y, 0)).Position);
        local TRPos, Visible2    = WorldToViewport((CF * CFrame.new(-Size.X,  Size.Y, 0)).Position);
        local BLPos, Visible3    = WorldToViewport((CF * CFrame.new( Size.X, -Size.Y, 0)).Position);
        local BRPos, Visible4    = WorldToViewport((CF * CFrame.new(-Size.X, -Size.Y, 0)).Position);
        local Quad = Box['Quad'];
        if QUAD_SUPPORTED_EXPLOIT then
            if Visible1 and Visible2 and Visible3 and Visible4 then
                Quad.Visible = true;
                Quad.Color    = Color;
                Quad.PointA = V2New(TLPos.X, TLPos.Y);
                Quad.PointB = V2New(TRPos.X, TRPos.Y);
                Quad.PointC = V2New(BRPos.X, BRPos.Y);
                Quad.PointD = V2New(BLPos.X, BLPos.Y);
            else
                Box['Quad'].Visible = false;
            end
        else
            Visible1 = TLPos.Z > 0;
            Visible2 = TRPos.Z > 0;
            Visible3 = BLPos.Z > 0;
            Visible4 = BRPos.Z > 0;
            if Visible1 then
                Box['TopLeft'].Visible        = true;
                Box['TopLeft'].Color        = Color;
                Box['TopLeft'].From            = V2New(TLPos.X, TLPos.Y);
                Box['TopLeft'].To            = V2New(TRPos.X, TRPos.Y);
            else
                Box['TopLeft'].Visible        = false;
            end
            if Visible2 then
                Box['TopRight'].Visible        = true;
                Box['TopRight'].Color        = Color;
                Box['TopRight'].From        = V2New(TRPos.X, TRPos.Y);
                Box['TopRight'].To            = V2New(BRPos.X, BRPos.Y);
            else
                Box['TopRight'].Visible        = false;
            end
            if Visible3 then
                Box['BottomLeft'].Visible    = true;
                Box['BottomLeft'].Color        = Color;
                Box['BottomLeft'].From        = V2New(BLPos.X, BLPos.Y);
                Box['BottomLeft'].To        = V2New(TLPos.X, TLPos.Y);
            else
                Box['BottomLeft'].Visible    = false;
            end
            if Visible4 then
                Box['BottomRight'].Visible    = true;
                Box['BottomRight'].Color    = Color;
                Box['BottomRight'].From        = V2New(BRPos.X, BRPos.Y);
                Box['BottomRight'].To        = V2New(BLPos.X, BLPos.Y);
            else
                Box['BottomRight'].Visible    = false;
            end
            if Properties and typeof(Properties) == 'table' then
                GetTableData(Properties)(function(i, v)
                    pcall(Set, Box['TopLeft'],        i, v);
                    pcall(Set, Box['TopRight'],        i, v);
                    pcall(Set, Box['BottomLeft'],    i, v);
                    pcall(Set, Box['BottomRight'],    i, v);
                end)
            end
        end
    end
    function Box:SetVisible(bool)
        if shared.am_ic3 then
            Box['Square'].Visible = bool;
            Box['OutlineSquare'].Visible = bool;
        elseif self.Quad then
            self.Quad.Visible = false
        elseif self.TopLeft and self.TopRight and self.BottomLeft and self.BottomRight then
            self.TopLeft.Visible = bool
            self.TopRight.Visible = bool
            self.BottomLeft.Visible = bool
            self.BottomRight.Visible = bool
        end
    end
    function Box:Remove()
        self:SetVisible(false)
        if shared.am_ic3 then
            Box['Square']:Remove()
            Box['OutlineSquare']:Remove()
        elseif self.Quad then
            Box['Quad']:Remove()
        elseif self.TopLeft and self.TopRight and self.BottomLeft and self.BottomRight then
            self.TopLeft:Remove()
            self.TopRight:Remove()
            self.BottomLeft:Remove()
            self.BottomRight:Remove()
        end
    end
    return Box;
end

local Colors = {
    White = Color3.fromHex'ffffff',
    Primary = {
        Main    = Color3.fromHex'424242',
        Light    = Color3.fromHex'6d6d6d',
        Dark    = Color3.fromHex'1b1b1b'
    },
    Secondary = {
        Main    = Color3.fromHex'e0e0e0',
        Light    = Color3.fromHex'ffffff',
        Dark    = Color3.fromHex'aeaeae'
    }
}

function Connections:Listen(Connection, Function)
    local NewConnection = Connection:Connect(Function);
    table.insert(self.Active, NewConnection);
    return NewConnection;
end

function Connections:DisconnectAll()
    for Index, Connection in pairs(self.Active) do
        if Connection.Connected then
            Connection:Disconnect();
        end
    end
    self.Active = {};
end

function Signal.new()
    local self = setmetatable({ _BindableEvent = Instance.new'BindableEvent' }, Signal);
    return self;
end

function Signal:Connect(Callback)
    assert(typeof(Callback) == 'function', 'function expected; got ' .. typeof(Callback));
    return self._BindableEvent.Event:Connect(function(...) Callback(...) end);
end

function Signal:Fire(...)
    self._BindableEvent:Fire(...);
end

function Signal:Wait()
    local Arguments = self._BindableEvent:Wait();
    return Arguments;
end

function Signal:Disconnect()
    if self._BindableEvent then
        self._BindableEvent:Destroy();
    end
end

local function GetMouseLocation()
    return UserInputService:GetMouseLocation();
end

local function CameraCon()
    workspace.CurrentCamera:GetPropertyChangedSignal'ViewportSize':Connect(function()
        TracerPosition = V2New(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y - 135);
    end);
end
CameraCon();

local LastRayIgnoreUpdate, RayIgnoreList = 0, {}

local function CheckRay(Instance, Distance, Position, Unit)
    local Pass = true;
    local Model = Instance;
    if Distance > 999 then return false; end
    if Instance.ClassName == 'Player' then
        Model = GetCharacter(Instance);
    end
    if not Model then
        Model = Instance.Parent;
        if Model.Parent == workspace then
            Model = Instance;
        end
    end
    if not Model then return false end
    local _Ray = Ray.new(Position, Unit * Distance)
    if tick() - LastRayIgnoreUpdate > 3 then
        LastRayIgnoreUpdate = tick()
        table.clear(RayIgnoreList)
        table.insert(RayIgnoreList, LocalPlayer.Character)
        table.insert(RayIgnoreList, Camera)
        if Mouse and Mouse.TargetFilter then table.insert(RayIgnoreList, Mouse.TargetFilter) end
        if #IgnoreList > 64 then
            while #IgnoreList > 64 do
                table.remove(IgnoreList, 1)
            end
        end
        for i, v in pairs(IgnoreList) do table.insert(RayIgnoreList, v) end
    end
    local Hit = workspace:FindPartOnRayWithIgnoreList(_Ray, RayIgnoreList)
    if Hit and not Hit:IsDescendantOf(Model) then
        Pass = false;
        if Hit.Transparency >= .3 or not Hit.CanCollide and Hit.ClassName ~= Terrain then
            table.insert(IgnoreList, Hit)
        end
    end
    return Pass;
end

local function CheckTeam(Player)
    if Player.Neutral and LocalPlayer.Neutral then return true; end
    return Player.TeamColor == LocalPlayer.TeamColor;
end

local CustomTeam = CustomTeams[game.PlaceId];
if CustomTeam ~= nil then
    if CustomTeam.Initialize then ypcall(CustomTeam.Initialize) end
    CheckTeam = CustomTeam.CheckTeam;
end

local function CheckPlayer(Player, Character)
    if not Options.Enabled.Value then return false end
    local Pass = true;
    local Distance = 0;
    if Player ~= LocalPlayer and Character then
        if not Options.ShowTeam.Value and CheckTeam(Player) then
            Pass = false;
        end
        local Head = Character:FindFirstChild'Head';
        if Pass and Character and Head then
            Distance = (Camera.CFrame.Position - Head.Position).Magnitude;
            if Options.VisCheck.Value then
                Pass = CheckRay(Player, Distance, Camera.CFrame.Position, (Head.Position - Camera.CFrame.Position).unit);
            end
            if Distance > Options.MaxDistance.Value then
                Pass = false;
            end
        end
    else
        Pass = false;
    end
    return Pass, Distance;
end

local function CheckDistance(Instance)
    if not Options.Enabled.Value then return false end
    local Pass = true;
    local Distance = 0;
    if Instance ~= nil then
        Distance = (Camera.CFrame.Position - Instance.Position).Magnitude;
        if Options.VisCheck.Value then
            Pass = CheckRay(Instance, Distance, Camera.CFrame.Position, (Instance.Position - Camera.CFrame.Position).unit);
        end
        if Distance > Options.MaxDistance.Value then
            Pass = false;
        end
    else
        Pass = false;
    end
    return Pass, Distance;
end

local function UpdatePlayerData()
    if (tick() - LastRefresh) > (Options.RefreshRate.Value / 1000) then
        LastRefresh = tick();
        if CustomESP and Options.Enabled.Value then
            local a, b = pcall(CustomESP);
        end
        for i, v in pairs(RenderList.Instances) do
            pcall(function()
            if v.Instance ~= nil and v.Instance.Parent ~= nil and v.Instance:IsA'BasePart' then
                local Data = shared.InstanceData[v.Instance:GetDebugId()] or { Instances = {}; DontDelete = true };
                Data.Instance = v.Instance;
                Data.Instances['OutlineTracer'] = Data.Instances['OutlineTracer'] or NewDrawing'Line'{
                    Transparency    = 0.75;
                    Thickness        = 5;
                    Color             = Color3.new(0.1, 0.1, 0.1);
                }
                Data.Instances['Tracer'] = Data.Instances['Tracer'] or NewDrawing'Line'{
                    Transparency    = 1;
                    Thickness        = 2;
                }
                Data.Instances['NameTag'] = Data.Instances['NameTag'] or NewDrawing'Text'{
                    Size            = Options.TextSize.Value;
                    Center            = true;
                    Outline            = Options.TextOutline.Value;
                    Visible            = true;
                };
                Data.Instances['DistanceTag'] = Data.Instances['DistanceTag'] or NewDrawing'Text'{
                    Size            = Options.TextSize.Value - 1;
                    Center            = true;
                    Outline            = Options.TextOutline.Value;
                    Visible            = true;
                };
                local NameTag        = Data.Instances['NameTag'];
                local DistanceTag    = Data.Instances['DistanceTag'];
                local Tracer        = Data.Instances['Tracer'];
                local OutlineTracer    = Data.Instances['OutlineTracer'];
                local Pass, Distance = CheckDistance(v.Instance);
                if Pass then
                    local ScreenPosition, Vis = WorldToViewport(v.Instance.Position);
                    local Color = v.Color;
                    local OPos = Camera.CFrame:pointToObjectSpace(v.Instance.Position);
                    if ScreenPosition.Z < 0 then
                        local AT = math.atan2(OPos.Y, OPos.X) + math.pi;
                        OPos = CFrame.Angles(0, 0, AT):vectorToWorldSpace((CFrame.Angles(0, math.rad(89.9), 0):vectorToWorldSpace(V3New(0, 0, -1))));
                    end
                    local Position = WorldToViewport(Camera.CFrame:pointToWorldSpace(OPos));
                    if Options.ShowTracers.Value then
                        Tracer.Transparency = math.clamp(Distance / 200, 0.45, 0.8);
                        Tracer.Visible    = true;
                        Tracer.From        = TracerPosition;
                        Tracer.To        = V2New(Position.X, Position.Y);
                        Tracer.Color    = Color;
                        OutlineTracer.Visible = true;
                        OutlineTracer.Transparency = Tracer.Transparency - 0.1;
                        OutlineTracer.From = Tracer.From;
                        OutlineTracer.To = Tracer.To;
                        OutlineTracer.Color    = Color3.new(0.1, 0.1, 0.1);
                    else
                        Tracer.Visible = false;
                        OutlineTracer.Visible = false;
                    end
                    if ScreenPosition.Z > 0 then
                        local ScreenPositionUpper = ScreenPosition;
                        if Options.ShowName.Value then
                            LocalPlayer.NameDisplayDistance = 0;
                            NameTag.Visible        = true;
                            NameTag.Text        = v.Text;
                            NameTag.Size        = Options.TextSize.Value;
                            NameTag.Outline        = Options.TextOutline.Value;
                            NameTag.Position    = V2New(ScreenPositionUpper.X, ScreenPositionUpper.Y);
                            NameTag.Color        = Color;
                            if Drawing.Fonts and shared.am_ic3 then
                                NameTag.Font    = Drawing.Fonts.Monospace;
                            end
                        else
                            LocalPlayer.NameDisplayDistance = 100;
                            NameTag.Visible = false;
                        end
                        if Options.ShowDistance.Value or Options.ShowHealth.Value then
                            DistanceTag.Visible        = true;
                            DistanceTag.Size        = Options.TextSize.Value - 1;
                            DistanceTag.Outline        = Options.TextOutline.Value;
                            DistanceTag.Color        = Color3.new(1, 1, 1);
                            if Drawing.Fonts and shared.am_ic3 then
                                NameTag.Font    = Drawing.Fonts.Monospace;
                            end
                            local Str = '';
                            if Options.ShowDistance.Value then
                                Str = Str .. Format('[%d] ', Distance);
                            end
                            DistanceTag.Text = Str;
                            DistanceTag.Position = V2New(ScreenPositionUpper.X, ScreenPositionUpper.Y) + V2New(0, NameTag.TextBounds.Y);
                        else
                            DistanceTag.Visible = false;
                        end
                    else
                        NameTag.Visible            = false;
                        DistanceTag.Visible        = false;
                    end
                else
                    NameTag.Visible            = false;
                    DistanceTag.Visible        = false;
                    Tracer.Visible            = false;
                    OutlineTracer.Visible    = false;
                end
                Data.Instances['NameTag']         = NameTag;
                Data.Instances['DistanceTag']    = DistanceTag;
                Data.Instances['Tracer']        = Tracer;
                Data.Instances['OutlineTracer']    = OutlineTracer;
                shared.InstanceData[v.Instance:GetDebugId()] = Data;
            end
            end) -- pcall per-instance
        end
        for i, v in pairs(Players:GetPlayers()) do
            pcall(function()
            local Data = shared.InstanceData[v.Name] or { Instances = {}; };
            Data.Instances['Box'] = Data.Instances['Box'] or LineBox:Create{Thickness = 4};
            Data.Instances['OutlineTracer'] = Data.Instances['OutlineTracer'] or NewDrawing'Line'{
                Transparency    = 1;
                Thickness        = 3;
                Color            = Color3.new(0.1, 0.1, 0.1);
            }
            Data.Instances['Tracer'] = Data.Instances['Tracer'] or NewDrawing'Line'{
                Transparency    = 1;
                Thickness        = 1;
            }
            Data.Instances['HeadDot'] = Data.Instances['HeadDot'] or NewDrawing'Circle'{
                Filled            = true;
                NumSides        = 30;
            }
            Data.Instances['NameTag'] = Data.Instances['NameTag'] or NewDrawing'Text'{
                Size            = Options.TextSize.Value;
                Center            = true;
                Outline            = Options.TextOutline.Value;
                OutlineOpacity    = 1;
                Visible            = true;
            };
            Data.Instances['DistanceHealthTag'] = Data.Instances['DistanceHealthTag'] or NewDrawing'Text'{
                Size            = Options.TextSize.Value - 1;
                Center            = true;
                Outline            = Options.TextOutline.Value;
                OutlineOpacity    = 1;
                Visible            = true;
            };
            local NameTag        = Data.Instances['NameTag'];
            local DistanceTag    = Data.Instances['DistanceHealthTag'];
            local Tracer        = Data.Instances['Tracer'];
            local OutlineTracer    = Data.Instances['OutlineTracer'];
            local HeadDot        = Data.Instances['HeadDot'];
            local Box            = Data.Instances['Box'];
            local Character = GetCharacter(v);
            local Pass, Distance = CheckPlayer(v, Character);
            if Pass and Character then
                local Humanoid = Character:FindFirstChildOfClass'Humanoid';
                local Head = Character:FindFirstChild'Head';
                local HumanoidRootPart = Character:FindFirstChild(CustomRootPartName or 'HumanoidRootPart')
                local Dead = (Humanoid and Humanoid:GetState().Name == 'Dead')
                if type(GetAliveState) == 'function' then
                    Dead = (not GetAliveState(v, Character))
                end
                if Character ~= nil and Head and HumanoidRootPart and not Dead then
                    local ScreenPosition, Vis = WorldToViewport(Head.Position);
                    local Color = (CheckTeam(v) and TeamColor or EnemyColor); Color = Options.ShowTeamColor.Value and v.TeamColor.Color or Color;
                    local OPos = Camera.CFrame:pointToObjectSpace(Head.Position);
                    if ScreenPosition.Z < 0 then
                        local AT = math.atan2(OPos.Y, OPos.X) + math.pi;
                        OPos = CFrame.Angles(0, 0, AT):vectorToWorldSpace((CFrame.Angles(0, math.rad(89.9), 0):vectorToWorldSpace(V3New(0, 0, -1))));
                    end
                    local Position = WorldToViewport(Camera.CFrame:pointToWorldSpace(OPos));
                    if Options.ShowTracers.Value then
                        if TracerPosition.X >= Camera.ViewportSize.X or TracerPosition.Y >= Camera.ViewportSize.Y or TracerPosition.X < 0 or TracerPosition.Y < 0 then
                            TracerPosition = V2New(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y - 135);
                        end
                        Tracer.Visible    = true;
                        Tracer.Transparency = math.clamp(1 - (Distance / 200), 0.25, 0.75);
                        Tracer.From        = TracerPosition;
                        Tracer.To        = V2New(Position.X, Position.Y);
                        Tracer.Color    = Color;
                        OutlineTracer.From = Tracer.From;
                        OutlineTracer.To = Tracer.To;
                        OutlineTracer.Transparency = Tracer.Transparency - 0.15;
                        OutlineTracer.Visible = true;
                    else
                        Tracer.Visible = false;
                        OutlineTracer.Visible = false;
                    end
                    if ScreenPosition.Z > 0 then
                        local ScreenPositionUpper    = WorldToViewport((HumanoidRootPart:GetRenderCFrame() * CFrame.new(0, Head.Size.Y + HumanoidRootPart.Size.Y + (Options.YOffset.Value / 25), 0)).Position);
                        local Scale                    = Head.Size.Y / 2;
                        if Options.ShowName.Value then
                            NameTag.Visible        = true;
                            NameTag.Text        = v.Name .. (CustomPlayerTag and CustomPlayerTag(v) or '');
                            NameTag.Size        = Options.TextSize.Value;
                            NameTag.Outline        = Options.TextOutline.Value;
                            NameTag.Position    = V2New(ScreenPositionUpper.X, ScreenPositionUpper.Y) - V2New(0, NameTag.TextBounds.Y);
                            NameTag.Color        = Color;
                            NameTag.OutlineColor= Color3.new(0.05, 0.05, 0.05);
                            NameTag.Transparency= 0.85;
                            if Drawing.Fonts and shared.am_ic3 then
                                NameTag.Font    = Drawing.Fonts.Monospace;
                            end
                        else
                            NameTag.Visible = false;
                        end
                        if Options.ShowDistance.Value or Options.ShowHealth.Value then
                            DistanceTag.Visible        = true;
                            DistanceTag.Size        = Options.TextSize.Value - 1;
                            DistanceTag.Outline        = Options.TextOutline.Value;
                            DistanceTag.Color        = Color3.new(1, 1, 1);
                            DistanceTag.Transparency= 0.85;
                            if Drawing.Fonts and shared.am_ic3 then
                                NameTag.Font    = Drawing.Fonts.Monospace;
                            end
                            local Str = '';
                            if Options.ShowDistance.Value then
                                Str = Str .. Format('[%d] ', Distance);
                            end
                            if Options.ShowHealth.Value then                                
                                if typeof(Humanoid) == 'Instance' then
                                    Str = Str .. Format('[%d/%d] [%s%%]', Humanoid.Health, Humanoid.MaxHealth, math.floor(Humanoid.Health / Humanoid.MaxHealth * 100));
                                elseif type(GetHealth) == 'function' then
                                    local health, maxHealth = GetHealth(v)
                                    if type(health) == 'number' and type(maxHealth) == 'number' then
                                        Str = Str .. Format('[%d/%d] [%s%%]', health, maxHealth, math.floor(health / maxHealth * 100))
                                    end
                                end
                            end
                            DistanceTag.Text = Str;
                            DistanceTag.OutlineColor = Color3.new(0.05, 0.05, 0.05);
                            DistanceTag.Position = (NameTag.Visible and NameTag.Position + V2New(0, NameTag.TextBounds.Y) or V2New(ScreenPositionUpper.X, ScreenPositionUpper.Y));
                        else
                            DistanceTag.Visible = false;
                        end
                        if Options.ShowDot.Value and Vis then
                            local Top            = WorldToViewport((Head.CFrame * CFrame.new(0, Scale, 0)).Position);
                            local Bottom        = WorldToViewport((Head.CFrame * CFrame.new(0, -Scale, 0)).Position);
                            local Radius        = math.abs((Top - Bottom).Y);
                            HeadDot.Visible        = true;
                            HeadDot.Color        = Color;
                            HeadDot.Position    = V2New(ScreenPosition.X, ScreenPosition.Y);
                            HeadDot.Radius        = Radius;
                        else
                            HeadDot.Visible = false;
                        end
                        if Options.ShowBoxes.Value and Vis and HumanoidRootPart then
                            local Body = {
                                Head;
                                Character:FindFirstChild'Left Leg' or Character:FindFirstChild'LeftLowerLeg';
                                Character:FindFirstChild'Right Leg' or Character:FindFirstChild'RightLowerLeg';
                                Character:FindFirstChild'Left Arm' or Character:FindFirstChild'LeftLowerArm';
                                Character:FindFirstChild'Right Arm' or Character:FindFirstChild'RightLowerArm';
                            }
                            Box:Update(HumanoidRootPart.CFrame, V3New(2, 3, 1) * (Scale * 2), Color, nil, shared.am_ic3 and Body);
                        else
                            Box:SetVisible(false);
                        end
                    else
                        NameTag.Visible            = false;
                        DistanceTag.Visible        = false;
                        HeadDot.Visible            = false;
                        Box:SetVisible(false);
                    end
                else
                    NameTag.Visible            = false;
                    DistanceTag.Visible        = false;
                    HeadDot.Visible            = false;
                    Tracer.Visible            = false;
                    OutlineTracer.Visible     = false;
                    Box:SetVisible(false);
                end
            else
                NameTag.Visible            = false;
                DistanceTag.Visible        = false;
                HeadDot.Visible            = false;
                Tracer.Visible            = false;
                OutlineTracer.Visible     = false;
                Box:SetVisible(false);
            end
            shared.InstanceData[v.Name] = Data;
            end) -- pcall per-player
        end
    end
end

local LastInvalidCheck = 0;

-- Custom healthbar update function
local function UpdateHealthbars()
    if not Options.Enabled.Value or not Options.ShowCustomHealthbar.Value then
        for _, hb in pairs(HealthbarObjects) do
            if hb.Background then hb.Background.Visible = false end
            if hb.Fill then hb.Fill.Visible = false end
            if hb.Text then hb.Text.Visible = false end
        end
        return
    end
    for player, hb in pairs(HealthbarObjects) do
        if not player or not player.Character then
            if hb.Background then hb.Background.Visible = false end
            if hb.Fill then hb.Fill.Visible = false end
            if hb.Text then hb.Text.Visible = false end
            continue
        end
        local character = player.Character
        local humanoid = character:FindFirstChild("Humanoid")
        local head = character:FindFirstChild("Head")
        local targetRootPart = character:FindFirstChild("HumanoidRootPart") or head
        local localCharacter = LocalPlayer.Character
        local localRootPart = localCharacter and localCharacter:FindFirstChild("HumanoidRootPart")
        if not (humanoid and head and humanoid.Health > 0) then
            if hb.Background then hb.Background.Visible = false end
            if hb.Fill then hb.Fill.Visible = false end
            if hb.Text then hb.Text.Visible = false end
            continue
        end
        local headPos, onScreen = Camera:WorldToViewportPoint(head.Position)
        if onScreen then
            local currentHealth = humanoid.Health
            local maxHealth = humanoid.MaxHealth
            local healthPercent = math.clamp(currentHealth / maxHealth, 0, 1)
            local barWidth = Options.HealthbarWidth.Value
            local barHeight = Options.HealthbarHeight.Value
            local barX = headPos.X - barWidth / 2
            local barY = headPos.Y - Options.HealthbarOffset.Value
            -- Background
            if hb.Background then
                hb.Background.Visible = true
                hb.Background.Size = Vector2.new(barWidth, barHeight)
                hb.Background.Position = Vector2.new(barX, barY)
            end
            -- Fill
            if hb.Fill then
                hb.Fill.Visible = true
                hb.Fill.Size = Vector2.new(barWidth * healthPercent, barHeight)
                hb.Fill.Position = Vector2.new(barX, barY)
                if healthPercent > 0.6 then
                    hb.Fill.Color = Color3.fromRGB(0, 255, 0)
                elseif healthPercent > 0.3 then
                    hb.Fill.Color = Color3.fromRGB(255, 255, 0)
                else
                    hb.Fill.Color = Color3.fromRGB(255, 0, 0)
                end
            end
            -- Text
            if hb.Text then
                hb.Text.Visible = true
                local distanceText = "?"
                if localRootPart and targetRootPart then
                    local distance = (targetRootPart.Position - localRootPart.Position).Magnitude
                    distanceText = tostring(math.floor(distance))
                end
                hb.Text.Text = string.format("%s | %s studs | %d/%d", player.Name, distanceText, math.floor(currentHealth), math.floor(maxHealth))
                hb.Text.Position = Vector2.new(headPos.X, barY - 22)
            end
        else
            if hb.Background then hb.Background.Visible = false end
            if hb.Fill then hb.Fill.Visible = false end
            if hb.Text then hb.Text.Visible = false end
        end
    end
end

local function Update()
    if tick() - LastInvalidCheck > 0.3 then
        LastInvalidCheck = tick();
        if Camera.Parent ~= workspace then
            Camera = workspace.CurrentCamera;
            CameraCon();
            WTVP = Camera.WorldToViewportPoint;
        end
        for i, v in pairs(shared.InstanceData) do
            if not Players:FindFirstChild(tostring(i)) then
                if not shared.InstanceData[i].DontDelete then
                    GetTableData(v.Instances)(function(i, obj)
                        obj.Visible = false;
                        obj:Remove();
                        v.Instances[i] = nil;
                    end)
                    shared.InstanceData[i] = nil;
                else
                    if shared.InstanceData[i].Instance == nil or shared.InstanceData[i].Instance.Parent == nil then
                        GetTableData(v.Instances)(function(i, obj)
                            obj.Visible = false;
                            obj:Remove();
                            v.Instances[i] = nil;
                        end)
                        shared.InstanceData[i] = nil;
                    end
                end
            end
        end
    end
    local CX = Menu:GetInstance'CrosshairX';
    local CY = Menu:GetInstance'CrosshairY';
    if Options.Crosshair.Value then
        if not CX then
            Menu:AddMenuInstance('CrosshairX', 'Line', { Visible = false });
            Menu:AddMenuInstance('CrosshairY', 'Line', { Visible = false });
            CX = Menu:GetInstance'CrosshairX';
            CY = Menu:GetInstance'CrosshairY';
        end
        CX.Visible = true;
        CY.Visible = true;
        CX.To = V2New((Camera.ViewportSize.X / 2) - 8, (Camera.ViewportSize.Y / 2));
        CX.From = V2New((Camera.ViewportSize.X / 2) + 8, (Camera.ViewportSize.Y / 2));
        CY.To = V2New((Camera.ViewportSize.X / 2), (Camera.ViewportSize.Y / 2) - 8);
        CY.From = V2New((Camera.ViewportSize.X / 2), (Camera.ViewportSize.Y / 2) + 8);
    else
        if CX then CX.Visible = false end
        if CY then CY.Visible = false end
    end
    UpdateHealthbars()
end

-- Initialize custom healthbars for existing players
for _, player in ipairs(Players:GetPlayers()) do
    if player ~= LocalPlayer then
        CreateHealthbar(player)
    end
end

Players.PlayerAdded:Connect(function(player)
    if player ~= LocalPlayer then
        task.wait(0.5)
        CreateHealthbar(player)
        player.CharacterAdded:Connect(function()
            task.wait(0.5)
            CreateHealthbar(player)
        end)
    end
end)

Players.PlayerRemoving:Connect(function(player)
    local hb = HealthbarObjects[player]
    if hb then
        pcall(function()
            if hb.Background then hb.Background:Remove() end
            if hb.Fill then hb.Fill:Remove() end
            if hb.Text then hb.Text:Remove() end
        end)
        HealthbarObjects[player] = nil
    end
end)

-- Start render loops
RunService:UnbindFromRenderStep(GetDataName);
RunService:UnbindFromRenderStep(UpdateName);
RunService:BindToRenderStep(GetDataName, 300, UpdatePlayerData);
RunService:BindToRenderStep(UpdateName, 199, Update);

-- ==================== LINORIA UI ====================

-- ESP Tab
local ESPGroup = Tabs.ESP:AddLeftGroupbox("ESP Settings")
local ESPVisuals = Tabs.ESP:AddRightGroupbox("Visual Options")
local ESPSizing = Tabs.ESP:AddRightGroupbox("Sizing", 2)

ESPGroup:AddToggle("ESPToggle", {
    Text = "Enable ESP",
    Default = true,
    Callback = function(value)
        Options.Enabled(value)
    end
})

ESPVisuals:AddToggle("ShowNames", {
    Text = "Show Names",
    Default = false,
    Callback = function(value)
        Options.ShowName(value)
    end
})

ESPVisuals:AddToggle("ShowBoxes", {
    Text = "Show Boxes",
    Default = false,
    Callback = function(value)
        Options.ShowBoxes(value)
    end
})

ESPVisuals:AddToggle("ShowTracers", {
    Text = "Show Tracers",
    Default = false,
    Callback = function(value)
        Options.ShowTracers(value)
    end
})

ESPVisuals:AddToggle("ShowDistance", {
    Text = "Show Distance",
    Default = false,
    Callback = function(value)
        Options.ShowDistance(value)
    end
})

ESPVisuals:AddToggle("ShowHealth", {
    Text = "Show Health",
    Default = false,
    Callback = function(value)
        Options.ShowHealth(value)
    end
})

ESPVisuals:AddToggle("ShowHeadDot", {
    Text = "Show Head Dot",
    Default = false,
    Callback = function(value)
        Options.ShowDot(value)
    end
})

ESPVisuals:AddToggle("TeamCheck", {
    Text = "Show Teammates",
    Default = true,
    Callback = function(value)
        Options.ShowTeam(value)
    end
})

ESPVisuals:AddToggle("ShowTeamColor", {
    Text = "Show Team Color",
    Default = false,
    Callback = function(value)
        Options.ShowTeamColor(value)
    end
})

ESPVisuals:AddToggle("VisibilityCheck", {
    Text = "Visibility Check",
    Default = false,
    Callback = function(value)
        Options.VisCheck(value)
    end
})

ESPVisuals:AddToggle("Crosshair", {
    Text = "Crosshair",
    Default = false,
    Callback = function(value)
        Options.Crosshair(value)
    end
})

ESPVisuals:AddToggle("TextOutline", {
    Text = "Text Outline",
    Default = true,
    Callback = function(value)
        Options.TextOutline(value)
    end
})

ESPSizing:AddSlider("RefreshRate", {
    Text = "Refresh Rate",
    Default = 5,
    Min = 1,
    Max = 200,
    Rounding = 0,
    Suffix = " ms",
    Callback = function(value)
        Options.RefreshRate(value)
    end
})

ESPSizing:AddSlider("TextSize", {
    Text = "Text Size",
    Default = 14,
    Min = 8,
    Max = 30,
    Rounding = 0,
    Suffix = "px",
    Callback = function(value)
        Options.TextSize(value)
    end
})

ESPSizing:AddSlider("MaxDistance", {
    Text = "Max Distance",
    Default = 2500,
    Min = 100,
    Max = 10000,
    Rounding = 0,
    Suffix = " studs",
    Callback = function(value)
        Options.MaxDistance(value)
    end
})

ESPSizing:AddSlider("YOffset", {
    Text = "Y Offset",
    Default = 0,
    Min = -200,
    Max = 200,
    Rounding = 0,
    Suffix = "",
    Callback = function(value)
        Options.YOffset(value)
    end
})

-- Custom Healthbar Options
local HealthbarGroup = Tabs.ESP:AddLeftGroupbox("Healthbar ESP")

HealthbarGroup:AddToggle("ShowHealthbars", {
    Text = "Enable Healthbars",
    Default = true,
    Callback = function(value)
        Options.ShowCustomHealthbar(value)
    end
})

HealthbarGroup:AddSlider("HealthbarWidth", {
    Text = "Healthbar Width",
    Default = 50,
    Min = 30,
    Max = 100,
    Rounding = 0,
    Suffix = "px",
    Callback = function(value)
        Options.HealthbarWidth(value)
    end
})

HealthbarGroup:AddSlider("HealthbarHeight", {
    Text = "Healthbar Height",
    Default = 4,
    Min = 2,
    Max = 10,
    Rounding = 0,
    Suffix = "px",
    Callback = function(value)
        Options.HealthbarHeight(value)
    end
})

HealthbarGroup:AddSlider("HealthbarOffset", {
    Text = "Healthbar Offset",
    Default = 70,
    Min = 30,
    Max = 100,
    Rounding = 0,
    Suffix = "px",
    Callback = function(value)
        Options.HealthbarOffset(value)
    end
})

-- Player Tab

-- ==================== NO FALL DAMAGE ====================
local NoFall = {
    Enabled = false,
}

-- Hook DataEvent to block fall damage
local DataEvent = nil
pcall(function()
    local events = game:GetService("ReplicatedStorage"):FindFirstChild("Events")
    if events then
        DataEvent = events:FindFirstChild("DataEvent")
    end
end)

local OldNamecall
OldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
    local method = getnamecallmethod()
    local args = {...}
    
    -- Intercept DataEvent:FireServer calls
    if method == "FireServer" and DataEvent and self == DataEvent and NoFall.Enabled then
        -- Check if this is a TakeDamage call
        if args[1] == "TakeDamage" then
            -- Check if player is falling or just landed (indicating fall damage)
            local success = pcall(function()
                local char = LocalPlayer.Character
                if char then
                    local humanoid = char:FindFirstChild("Humanoid")
                    if humanoid and humanoid:IsA("Humanoid") then
                        local state = humanoid:GetState()
                        -- Block if in freefall or landing state
                        if state == Enum.HumanoidStateType.Freefall or 
                           state == Enum.HumanoidStateType.Landed then
                            -- Block this damage call (fall damage)
                            return true
                        end
                    end
                end
                return false
            end)
            
            if success then
                return
            end
        end
    end
    
    return OldNamecall(self, ...)
end)

-- UI in Player Tab
local NoFallGroup = Tabs.Player:AddLeftGroupbox("No Fall Damage")
NoFallGroup:AddToggle("NoFallToggle", {
    Text = "Enable No Fall Damage",
    Default = false,
    Callback = function(value)
        NoFall.Enabled = value
    end
})

NoFallGroup:AddLabel("Blocks TakeDamage remote when falling.")
NoFallGroup:AddLabel("Works by hooking DataEvent:FireServer.")

-- ==================== RESET BUTTON ====================
local PlayerUtilities = Tabs.Player:AddLeftGroupbox("Utilities")

PlayerUtilities:AddButton({
    Text = "Reset Character",
    Func = function()
        local char = LocalPlayer.Character
        if char and char:FindFirstChild("Humanoid") then
            char.Humanoid.Health = 0
            task.wait(1)
            char:BreakJoints()
        end
    end
})
-- ==================== M1 SPAM ====================
local M1Spam = {
    Enabled = false,
    Holding = false,
    Delay = 0.1,
    Thread = nil
}

local VirtualInput = game:GetService("VirtualInputManager")
local UserInputService = game:GetService("UserInputService")

local function GetMousePos()
    return UserInputService:GetMouseLocation()
end

local function PerformClick()
    local pos = GetMousePos()
    pcall(function()
        VirtualInput:SendMouseButtonEvent(pos.X, pos.Y, 0, true, game, 0)
    end)
end

-- Track physical mouse hold
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        M1Spam.Holding = true
    end
end)

UserInputService.InputEnded:Connect(function(input, gameProcessed)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        M1Spam.Holding = false
    end
end)

local function SpamLoop()
    while M1Spam.Enabled do
        if M1Spam.Holding then
            PerformClick()
        end
        task.wait(M1Spam.Delay)
    end
end

local function StartSpam()
    if M1Spam.Thread then
        pcall(task.cancel, M1Spam.Thread)
    end
    M1Spam.Thread = task.spawn(SpamLoop)
end

local function StopSpam()
    M1Spam.Holding = false
    if M1Spam.Thread then
        pcall(task.cancel, M1Spam.Thread)
        M1Spam.Thread = nil
    end
end

-- UI
local M1Group = Tabs.Player:AddLeftGroupbox("M1 Spam")

M1Group:AddToggle("M1SpamToggle", {
    Text = "Enable M1 Spam",
    Default = false,
    Callback = function(v)
        M1Spam.Enabled = v
        if v then
            StartSpam()
        else
            StopSpam()
        end
    end
}):AddKeyPicker("M1SpamKey", {
    Default = "L",
    SyncToggleState = true,
    Mode = "Toggle",
    Text = "M1 Spam"
})

M1Group:AddSlider("M1SpamDelay", {
    Text = "Click Delay (s)",
    Default = 0.1,
    Min = 0.02,
    Max = 0.5,
    Rounding = 2,
    Suffix = "s",
    Callback = function(v) M1Spam.Delay = v end
})

M1Group:AddLabel("Toggle with L. Hold M1 to spam clicks.")
-- Movement Tab
local MovementGroup = Tabs.Movement:AddLeftGroupbox("Movement")

local flying = false
local bodyVelocity, bodyGyro

MovementGroup:AddToggle("Noclip", {
    Text = "Noclip",
    Default = false,
    Callback = function(value)
        _G.Noclip = value
    end
}):AddKeyPicker("NoclipKey", {
    Default = "N",
    SyncToggleState = true,
    Mode = "Toggle",
    Text = "Noclip",
})

MovementGroup:AddToggle("InfiniteJump", {
    Text = "Infinite Jump",
    Default = false,
    Callback = function(value)
        _G.InfiniteJump = value
    end
})

MovementGroup:AddToggle("Fly", {
    Text = "Fly",
    Default = false,
    Callback = function(value)
        flying = value
        local character = LocalPlayer.Character
        if not character then return end
        local humanoid = character:FindFirstChild("Humanoid")
        local rootPart = character:FindFirstChild("HumanoidRootPart")
        if not (humanoid and rootPart) then return end
        if flying then
            humanoid.PlatformStand = true
            bodyVelocity = Instance.new("BodyVelocity")
            bodyVelocity.Velocity = Vector3.new(0, 0, 0)
            bodyVelocity.MaxForce = Vector3.new(4000, 4000, 4000)
            bodyVelocity.Parent = rootPart
            bodyGyro = Instance.new("BodyGyro")
            bodyGyro.MaxTorque = Vector3.new(4000, 4000, 4000)
            bodyGyro.Parent = rootPart
        else
            if bodyVelocity then bodyVelocity:Destroy() end
            if bodyGyro then bodyGyro:Destroy() end
            humanoid.PlatformStand = false
        end
    end
}):AddKeyPicker("FlyKey", {
    Default = "F",
    SyncToggleState = true,
    Mode = "Toggle",
    Text = "Fly",
})

-- ==================== WALKSPEED MULTIPLIER ====================
local WalkspeedMultiplier = {
    Enabled = false,
    Multiplier = 1.0,
    BaseSpeed = nil,   -- captured once when enabled
    Connection = nil,
}

-- Capture the game's current walkspeed as the base, then apply multiplier each frame
local function EnableWalkspeed()
    local char = LocalPlayer.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end

    -- Snapshot the game's current speed as the base
    WalkspeedMultiplier.BaseSpeed = hum.WalkSpeed
    hum.WalkSpeed = WalkspeedMultiplier.BaseSpeed * WalkspeedMultiplier.Multiplier

    -- Disconnect old connection if any
    if WalkspeedMultiplier.Connection then
        WalkspeedMultiplier.Connection:Disconnect()
    end

    -- Each frame, re-read the game's base (in case the game changes it)
    -- and apply the multiplier on top
    WalkspeedMultiplier.Connection = RunService.RenderStepped:Connect(function()
        if not WalkspeedMultiplier.Enabled then return end
        local c = LocalPlayer.Character
        if not c then return end
        local h = c:FindFirstChildOfClass("Humanoid")
        if not h then return end

        local expected = WalkspeedMultiplier.BaseSpeed * WalkspeedMultiplier.Multiplier
        -- If the game changed the speed externally (not matching our expected),
        -- treat the new value as the updated base
        if math.abs(h.WalkSpeed - expected) > 0.5 then
            WalkspeedMultiplier.BaseSpeed = h.WalkSpeed
            expected = WalkspeedMultiplier.BaseSpeed * WalkspeedMultiplier.Multiplier
        end
        h.WalkSpeed = expected
    end)
end

local function DisableWalkspeed()
    if WalkspeedMultiplier.Connection then
        WalkspeedMultiplier.Connection:Disconnect()
        WalkspeedMultiplier.Connection = nil
    end
    -- Restore original speed
    if WalkspeedMultiplier.BaseSpeed then
        local char = LocalPlayer.Character
        if char then
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum then
                hum.WalkSpeed = WalkspeedMultiplier.BaseSpeed
            end
        end
    end
    WalkspeedMultiplier.BaseSpeed = nil
end

-- Re-apply on respawn
LocalPlayer.CharacterAdded:Connect(function(char)
    if WalkspeedMultiplier.Enabled then
        task.wait(0.3)
        EnableWalkspeed()
    end
end)

MovementGroup:AddToggle("WalkspeedToggle", {
    Text = "Walkspeed Multiplier",
    Default = false,
    Callback = function(value)
        WalkspeedMultiplier.Enabled = value
        if value then
            EnableWalkspeed()
        else
            DisableWalkspeed()
        end
    end
}):AddKeyPicker("WalkspeedKey", {
    Default = "X",
    SyncToggleState = true,
    Mode = "Toggle",
    Text = "Walkspeed",
})

MovementGroup:AddSlider("WalkspeedSlider", {
    Text = "Speed Multiplier",
    Default = 1.0,
    Min = 0.1,
    Max = 25,
    Rounding = 1,
    Suffix = "x",
    Callback = function(value)
        WalkspeedMultiplier.Multiplier = value
        -- If already enabled, re-apply immediately
        if WalkspeedMultiplier.Enabled and WalkspeedMultiplier.BaseSpeed then
            local char = LocalPlayer.Character
            if char then
                local hum = char:FindFirstChildOfClass("Humanoid")
                if hum then
                    hum.WalkSpeed = WalkspeedMultiplier.BaseSpeed * value
                end
            end
        end
    end
})

MovementGroup:AddLabel("Multiplies your current game walkspeed.")

-- Noclip loop
RunService.Stepped:Connect(function()
    if _G.Noclip and LocalPlayer.Character then
        for _, part in ipairs(LocalPlayer.Character:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = false
            end
        end
    end
end)

-- Infinite Jump
UserInputService.JumpRequest:Connect(function()
    if _G.InfiniteJump then
        local character = LocalPlayer.Character
        if character then
            local humanoid = character:FindFirstChild("Humanoid")
            if humanoid then
                humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
            end
        end
    end
end)

-- Misc Tab
local MiscGroup = Tabs.Misc:AddLeftGroupbox("Misc")

-- ==================== BOSS HEALTH BARS (AUTO + MANUAL) ====================
local BossBarTab = Window:AddTab("Boss Bars")

-- Global default max distance (studs) for auto detection
local DEFAULT_MAX_DISTANCE = 500
local BOSS_MIN_HEALTH = 450  -- minimum max health to be considered a boss

-- Edit this table to add your permanent bosses manually (optional)
local BossConfig = {
    -- Example: { path = 'workspace["Wooden Golem"].Humanoid', maxDistance = 300 },
}

-- Test entries (temporary)
local TestEntries = {}  -- { path = string, maxDistance = number? }

-- Auto‑detected bosses: key = humanoid (unique), value = { bar, humanoid, maxDist }
local AutoBosses = {}

-- Active bars for manual/test entries: key = path (or "test_"..path), value = { bg, fill, txt, humanoid, maxDist }
local ManualBars = {}

-- Settings
local AutoDetect = {
    Enabled = true,
    Range = DEFAULT_MAX_DISTANCE,
    ScanInterval = 2,  -- seconds
    LastScan = 0,
    ScanThread = nil,
}

-- Helper to clear groupbox
local function ClearGroupBox(group) 
    if group and group.Container then
        for _, child in ipairs(group.Container:GetChildren()) do
            child:Destroy()
        end
    end 
end

-- Create drawing objects for a bar
local function CreateBarDrawing()
    local bg = Drawing.new("Square")
    bg.Filled = true
    bg.Color = Color3.fromRGB(30, 30, 30)
    bg.Transparency = 0.7
    bg.Visible = false

    local fill = Drawing.new("Square")
    fill.Filled = true
    fill.Color = Color3.fromRGB(128, 0, 128)  -- purple
    fill.Transparency = 0.9
    fill.Visible = false

    local txt = Drawing.new("Text")
    txt.Center = true
    txt.Outline = true
    txt.Color = Color3.new(1, 1, 1)
    txt.Size = 16
    txt.Visible = false

    return { bg = bg, fill = fill, txt = txt }
end

-- Calculate distance from local player to a humanoid's root
local function GetDistanceToHumanoid(humanoid)
    local char = humanoid.Parent
    if not char then return nil end
    local rootPart = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Head")
    if not rootPart then return nil end
    local localChar = LocalPlayer.Character
    if not localChar then return nil end
    local localRoot = localChar:FindFirstChild("HumanoidRootPart") or localChar:FindFirstChild("Head")
    if not localRoot then return nil end
    return (localRoot.Position - rootPart.Position).Magnitude
end

-- Update a bar for a given humanoid with distance check
local function UpdateBar(bar, humanoid, maxDist)
    if not humanoid or not humanoid.Parent then
        bar.bg.Visible = false
        bar.fill.Visible = false
        bar.txt.Visible = false
        return false
    end

    -- Distance check
    local dist = GetDistanceToHumanoid(humanoid)
    if not dist or dist > maxDist then
        bar.bg.Visible = false
        bar.fill.Visible = false
        bar.txt.Visible = false
        return false
    end

    local rootPart = humanoid.Parent:FindFirstChild("HumanoidRootPart") or humanoid.Parent:FindFirstChild("Head")
    if not rootPart then return false end

    local pos, onScreen = Camera:WorldToViewportPoint(rootPart.Position)
    if not onScreen then
        bar.bg.Visible = false
        bar.fill.Visible = false
        bar.txt.Visible = false
        return false
    end

    local health = humanoid.Health
    local maxHealth = humanoid.MaxHealth
    local percent = math.clamp(health / maxHealth, 0, 1)

    local barWidth = 200
    local barHeight = 20
    local x = pos.X - barWidth/2
    local y = pos.Y - 70  -- above the boss

    -- Background
    bar.bg.Position = Vector2.new(x, y)
    bar.bg.Size = Vector2.new(barWidth, barHeight)
    bar.bg.Visible = true

    -- Fill
    bar.fill.Position = Vector2.new(x, y)
    bar.fill.Size = Vector2.new(barWidth * percent, barHeight)
    bar.fill.Visible = true

    -- Text
    bar.txt.Position = Vector2.new(pos.X, y + barHeight/2 - 8)
    bar.txt.Text = string.format("%d / %d", math.floor(health), math.floor(maxHealth))
    bar.txt.Visible = true

    return true
end

-- Remove a manual bar by key
local function RemoveManualBar(key)
    local bar = ManualBars[key]
    if bar then
        pcall(function()
            bar.bg:Remove()
            bar.fill:Remove()
            bar.txt:Remove()
        end)
        ManualBars[key] = nil
    end
end

-- Remove an auto bar by humanoid reference
local function RemoveAutoBar(humanoid)
    local entry = AutoBosses[humanoid]
    if entry and entry.bar then
        pcall(function()
            entry.bar.bg:Remove()
            entry.bar.fill:Remove()
            entry.bar.txt:Remove()
        end)
    end
    AutoBosses[humanoid] = nil
end

-- Scan for new bosses (called periodically)
local function ScanForBosses()
    if not AutoDetect.Enabled then return end

    local localChar = LocalPlayer.Character
    if not localChar then return end
    local localRoot = localChar:FindFirstChild("HumanoidRootPart") or localChar:FindFirstChild("Head")
    if not localRoot then return end

    -- Get all humanoids in workspace (excluding players)
    local allHumanoids = {}
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("Humanoid") and obj.Parent and obj.Parent ~= localChar then
            -- Skip players (they have Player instances)
            local player = Players:GetPlayerFromCharacter(obj.Parent)
            if not player then
                table.insert(allHumanoids, obj)
            end
        end
    end

    -- Mark existing auto bosses as seen
    local seen = {}
    for _, hum in ipairs(allHumanoids) do
        if hum.MaxHealth >= BOSS_MIN_HEALTH then
            local dist = GetDistanceToHumanoid(hum)
            if dist and dist <= AutoDetect.Range then
                seen[hum] = true
                if not AutoBosses[hum] then
                    -- New boss: create bar
                    AutoBosses[hum] = {
                        bar = CreateBarDrawing(),
                        humanoid = hum,
                        maxDist = AutoDetect.Range
                    }
                end
            end
        end
    end

    -- Remove auto bosses that are no longer valid
    for hum, entry in pairs(AutoBosses) do
        if not seen[hum] or not hum.Parent then
            RemoveAutoBar(hum)
        end
    end
end

-- Start the auto‑scan loop
local function StartAutoScan()
    if AutoDetect.ScanThread then
        task.cancel(AutoDetect.ScanThread)
    end
    AutoDetect.ScanThread = task.spawn(function()
        while AutoDetect.Enabled do
            ScanForBosses()
            task.wait(AutoDetect.ScanInterval)
        end
    end)
end

-- Main render loop (runs every frame)
RunService.RenderStepped:Connect(function()
    -- Manual permanent entries
    for _, entry in ipairs(BossConfig) do
        local key = entry.path
        if not ManualBars[key] then
            local success, humanoid = pcall(function()
                return loadstring("return " .. key)()
            end)
            if success and humanoid and humanoid:IsA("Humanoid") then
                local maxDist = entry.maxDistance or DEFAULT_MAX_DISTANCE
                ManualBars[key] = CreateBarDrawing()
                ManualBars[key].humanoid = humanoid
                ManualBars[key].maxDist = maxDist
            end
        end
        local bar = ManualBars[key]
        if bar then
            UpdateBar(bar, bar.humanoid, bar.maxDist)
        end
    end

    -- Test entries
    for _, entry in ipairs(TestEntries) do
        local key = "test_" .. entry.path
        if not ManualBars[key] then
            local success, humanoid = pcall(function()
                return loadstring("return " .. entry.path)()
            end)
            if success and humanoid and humanoid:IsA("Humanoid") then
                local maxDist = entry.maxDistance or DEFAULT_MAX_DISTANCE
                ManualBars[key] = CreateBarDrawing()
                ManualBars[key].humanoid = humanoid
                ManualBars[key].maxDist = maxDist
            end
        end
        local bar = ManualBars[key]
        if bar then
            UpdateBar(bar, bar.humanoid, bar.maxDist)
        end
    end

    -- Auto‑detected bosses
    for hum, entry in pairs(AutoBosses) do
        if hum and hum.Parent then
            UpdateBar(entry.bar, hum, entry.maxDist)
        else
            RemoveAutoBar(hum)
        end
    end
end)

-- ===== UI =====
-- Left group: Auto detection settings
local AutoGroup = BossBarTab:AddLeftGroupbox("Auto Boss Detection")
AutoGroup:AddToggle("AutoDetectToggle", {
    Text = "Enable Auto Detection",
    Default = false,
    Callback = function(v)
        AutoDetect.Enabled = v
        if v then
            StartAutoScan()
        else
            -- Clear all auto bars
            for hum, _ in pairs(AutoBosses) do
                RemoveAutoBar(hum)
            end
            if AutoDetect.ScanThread then
                task.cancel(AutoDetect.ScanThread)
                AutoDetect.ScanThread = nil
            end
        end
    end
})
AutoGroup:AddSlider("AutoDetectRange", {
    Text = "Detection Range",
    Default = DEFAULT_MAX_DISTANCE,
    Min = 100,
    Max = 2000,
    Rounding = 0,
    Suffix = "studs",
    Callback = function(v) AutoDetect.Range = v end
})
AutoGroup:AddLabel(string.format("Auto‑detects NPCs with ≥ %d max health.", BOSS_MIN_HEALTH))

-- Manual permanent bosses (read‑only)
local PermGroup = BossBarTab:AddLeftGroupbox("Manual Permanent Bosses")
local function RefreshPermList()
    ClearGroupBox(PermGroup)
    for i, entry in ipairs(BossConfig) do
        local distText = entry.maxDistance and (" (max " .. entry.maxDistance .. " studs)") or (" (default " .. DEFAULT_MAX_DISTANCE .. " studs)")
        PermGroup:AddLabel(string.format("%d. %s%s", i, entry.path, distText))
    end
    if #BossConfig == 0 then
        PermGroup:AddLabel("No manual bosses.")
    end
end
RefreshPermList()

-- Test section (same as before)
local TestGroup = BossBarTab:AddRightGroupbox("Test a Boss")

TestGroup:AddInput("TestPath", {
    Text = "Path to Humanoid",
    Default = "",
    Placeholder = 'e.g., workspace["Wooden Golem"].Humanoid',
    Numeric = false,
    Finished = false,
    Callback = function(val) _G.TestPath = val end
})

TestGroup:AddSlider("TestMaxDistance", {
    Text = "Max Distance (studs)",
    Default = DEFAULT_MAX_DISTANCE,
    Min = 50,
    Max = 2000,
    Rounding = 0,
    Suffix = "studs",
    Callback = function(val) _G.TestMaxDist = val end
})

TestGroup:AddButton({
    Text = "Add Test",
    Func = function()
        local path = _G.TestPath or ""
        if path == "" then
            Library:Notify("Enter a path", 3)
            return
        end
        local success, humanoid = pcall(function()
            return loadstring("return " .. path)()
        end)
        if not success or not humanoid or not humanoid:IsA("Humanoid") then
            Library:Notify("Invalid path or not a Humanoid", 3)
            return
        end
        local maxDist = _G.TestMaxDist or DEFAULT_MAX_DISTANCE
        table.insert(TestEntries, { path = path, maxDistance = maxDist })
        RefreshTestList()
        Library:Notify("Test boss added (max " .. maxDist .. " studs)", 2)
    end
})

TestGroup:AddButton({
    Text = "Clear Tests",
    Func = function()
        for _, entry in ipairs(TestEntries) do
            RemoveManualBar("test_" .. entry.path)
        end
        TestEntries = {}
        RefreshTestList()
        Library:Notify("Test entries cleared", 2)
    end
})

TestGroup:AddButton({
    Text = "Promote All Tests to Permanent",
    Func = function()
        for _, entry in ipairs(TestEntries) do
            table.insert(BossConfig, { path = entry.path, maxDistance = entry.maxDistance })
        end
        RefreshPermList()
        -- Clear test bars and entries
        for _, entry in ipairs(TestEntries) do
            RemoveManualBar("test_" .. entry.path)
        end
        TestEntries = {}
        RefreshTestList()
        Library:Notify("Tests added to permanent list. Edit the script to keep them permanently.", 3)
    end
})

-- Test list display
local TestListGroup = BossBarTab:AddRightGroupbox("Current Tests", 2)
local function RefreshTestList()
    ClearGroupBox(TestListGroup)
    for i, entry in ipairs(TestEntries) do
        local distText = " (max " .. (entry.maxDistance or DEFAULT_MAX_DISTANCE) .. " studs)"
        TestListGroup:AddLabel(string.format("%d. %s%s", i, entry.path, distText))
        TestListGroup:AddButton({
            Text = "Remove",
            Func = function()
                RemoveManualBar("test_" .. entry.path)
                table.remove(TestEntries, i)
                RefreshTestList()
            end
        })
    end
    if #TestEntries == 0 then
        TestListGroup:AddLabel("No active tests.")
    end
end
RefreshTestList()

-- ==================== BOSS FARM (ANCHOR + M1 SPAM) ====================
local BossFarm = {
    Enabled = false,
    Target = nil,           -- the Humanoid we're farming
    TargetName = "",        -- display name of the boss model
    HeightOffset = 50,      -- studs above the boss root
    AttackDelay = 0.12,     -- seconds between remote fire calls
    ScanRange = 500,        -- max studs to scan for bosses
    MinHealth = 450,        -- minimum MaxHealth to count as a boss
    Thread = nil,
    AnchorConn = nil,
    FoundBosses = {},       -- { humanoid = Humanoid, name = string }
}

local BossFarmGroup = BossBarTab:AddLeftGroupbox("Boss Farm")

-- Scan for nearby bosses and return a list
local function ScanBossFarmTargets()
    local results = {}
    local localChar = LocalPlayer.Character
    if not localChar then return results end
    local localRoot = localChar:FindFirstChild("HumanoidRootPart") or localChar:FindFirstChild("Head")
    if not localRoot then return results end

    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("Humanoid") and obj.Parent and obj.Health > 0 and obj.MaxHealth >= BossFarm.MinHealth then
            local player = Players:GetPlayerFromCharacter(obj.Parent)
            if not player then
                local root = obj.Parent:FindFirstChild("HumanoidRootPart") or obj.Parent:FindFirstChild("Head")
                if root then
                    local dist = (localRoot.Position - root.Position).Magnitude
                    if dist <= BossFarm.ScanRange then
                        table.insert(results, {
                            humanoid = obj,
                            name = obj.Parent.Name,
                            distance = math.floor(dist)
                        })
                    end
                end
            end
        end
    end

    -- Sort by distance
    table.sort(results, function(a, b) return a.distance < b.distance end)
    return results
end

-- Fire the melee hit remote
local BossFarmDataEvent = game:GetService("ReplicatedStorage"):FindFirstChild("Events") and
    game:GetService("ReplicatedStorage").Events:FindFirstChild("DataEvent")

local function BossFarmAttack()
    if not BossFarmDataEvent then return end
    pcall(function()
        BossFarmDataEvent:FireServer("CheckMeleeHit", nil, "NormalAttack", false)
    end)
end

local function BossFarmDash()
    if not BossFarmDataEvent then return end
    local hum = BossFarm.Target
    if not hum or not hum.Parent then return end
    local bossRoot = hum.Parent:FindFirstChild("HumanoidRootPart") or hum.Parent:FindFirstChild("Head")
    if not bossRoot then return end
    pcall(function()
        BossFarmDataEvent:FireServer("Dash", "Sub", bossRoot.Position)
    end)
end

-- Start the farm loop (anchor + click)
local function StartBossFarm()
    -- Stop any previous
    if BossFarm.AnchorConn then
        BossFarm.AnchorConn:Disconnect()
        BossFarm.AnchorConn = nil
    end
    if BossFarm.Thread then
        pcall(task.cancel, BossFarm.Thread)
        BossFarm.Thread = nil
    end

    if not BossFarm.Target or not BossFarm.Target.Parent then
        Library:Notify("No valid boss target!", 3)
        BossFarm.Enabled = false
        return
    end

    Library:Notify("Farming: " .. BossFarm.TargetName, 3)

    -- Anchor: every frame, teleport on top of boss
    BossFarm.AnchorConn = RunService.Heartbeat:Connect(function()
        if not BossFarm.Enabled then return end
        local hum = BossFarm.Target
        if not hum or not hum.Parent or hum.Health <= 0 then
            -- Boss died or despawned
            Library:Notify(BossFarm.TargetName .. " is dead or gone!", 3)
            BossFarm.Enabled = false
            if BossFarm.AnchorConn then BossFarm.AnchorConn:Disconnect(); BossFarm.AnchorConn = nil end
            if BossFarm.Thread then pcall(task.cancel, BossFarm.Thread); BossFarm.Thread = nil end
            return
        end

        local bossRoot = hum.Parent:FindFirstChild("HumanoidRootPart") or hum.Parent:FindFirstChild("Head")
        if not bossRoot then return end

        local char = LocalPlayer.Character
        if not char then return end
        local root = char:FindFirstChild("HumanoidRootPart")
        if not root then return end

        -- Position above the boss, standing upright
        local targetPos = bossRoot.Position + Vector3.new(0, BossFarm.HeightOffset, 0)
        root.CFrame = CFrame.new(targetPos)
    end)

    -- Attack spam loop (fires remote)
    BossFarm.Thread = task.spawn(function()
        while BossFarm.Enabled do
            if BossFarm.Target and BossFarm.Target.Parent and BossFarm.Target.Health > 0 then
                BossFarmDash()
                BossFarmAttack()
            end
            task.wait(BossFarm.AttackDelay)
        end
    end)
end

local function StopBossFarm()
    BossFarm.Enabled = false
    if BossFarm.AnchorConn then
        BossFarm.AnchorConn:Disconnect()
        BossFarm.AnchorConn = nil
    end
    if BossFarm.Thread then
        pcall(task.cancel, BossFarm.Thread)
        BossFarm.Thread = nil
    end
end

-- Status label
local BossFarmStatus = BossFarmGroup:AddLabel("Target: None")

-- Scan button — finds bosses and picks the nearest one
BossFarmGroup:AddButton({
    Text = "Scan & Pick Nearest Boss",
    Func = function()
        local bosses = ScanBossFarmTargets()
        if #bosses == 0 then
            Library:Notify("No bosses found within " .. BossFarm.ScanRange .. " studs", 3)
            BossFarmStatus:SetText("Target: None")
            BossFarm.Target = nil
            BossFarm.TargetName = ""
            return
        end
        -- Pick nearest
        local pick = bosses[1]
        BossFarm.Target = pick.humanoid
        BossFarm.TargetName = pick.name
        BossFarmStatus:SetText(string.format("Target: %s (%d HP, %d studs)", pick.name, math.floor(pick.humanoid.Health), pick.distance))
        Library:Notify(string.format("Selected: %s (%d studs away)", pick.name, pick.distance), 3)

        -- List all found bosses in chat
        for i, b in ipairs(bosses) do
            Library:Notify(string.format("  %d. %s — %d HP, %d studs", i, b.name, math.floor(b.humanoid.Health), b.distance), 4)
        end
    end,
    Tooltip = "Scans for NPCs with high HP nearby and selects the closest one"
})

-- Scan & show list to pick from
BossFarmGroup:AddButton({
    Text = "Scan & Pick by Name",
    Func = function()
        local bosses = ScanBossFarmTargets()
        if #bosses == 0 then
            Library:Notify("No bosses found within " .. BossFarm.ScanRange .. " studs", 3)
            return
        end
        -- Build a simple text list
        local msg = "Found bosses (say number in chat to pick):\n"
        BossFarm.FoundBosses = bosses
        for i, b in ipairs(bosses) do
            msg = msg .. string.format("  %d. %s — %d HP, %d studs\n", i, b.name, math.floor(b.humanoid.Health), b.distance)
        end
        Library:Notify(msg, 8)
        Library:Notify("Use the index input below to select one.", 5)
    end,
    Tooltip = "Shows all detected bosses so you can pick one by index"
})

BossFarmGroup:AddInput("BossFarmIndex", {
    Text = "Boss Index",
    Default = "1",
    Numeric = true,
    Finished = true,
    Placeholder = "e.g. 1",
    Callback = function(val)
        local idx = tonumber(val)
        if not idx or not BossFarm.FoundBosses or not BossFarm.FoundBosses[idx] then
            Library:Notify("Invalid index. Scan first, then enter a number.", 3)
            return
        end
        local pick = BossFarm.FoundBosses[idx]
        BossFarm.Target = pick.humanoid
        BossFarm.TargetName = pick.name
        BossFarmStatus:SetText(string.format("Target: %s (%d HP, %d studs)", pick.name, math.floor(pick.humanoid.Health), pick.distance))
        Library:Notify(string.format("Selected: %s", pick.name), 2)
    end
})

BossFarmGroup:AddToggle("BossFarmToggle", {
    Text = "Start Farm",
    Default = false,
    Callback = function(v)
        BossFarm.Enabled = v
        if v then
            StartBossFarm()
        else
            StopBossFarm()
            Library:Notify("Boss farm stopped", 2)
        end
    end
}):AddKeyPicker("BossFarmKey", {
    Default = "G",
    SyncToggleState = true,
    Mode = "Toggle",
    Text = "Boss Farm",
})

BossFarmGroup:AddSlider("BossFarmHeight", {
    Text = "Height Above Boss",
    Default = 50,
    Min = -100,
    Max = 100,
    Rounding = 1,
    Suffix = " studs",
    Callback = function(v) BossFarm.HeightOffset = v end
})

BossFarmGroup:AddSlider("BossFarmAttackDelay", {
    Text = "Attack Delay",
    Default = 0.12,
    Min = 0.02,
    Max = 0.5,
    Rounding = 2,
    Suffix = "s",
    Callback = function(v) BossFarm.AttackDelay = v end
})

BossFarmGroup:AddSlider("BossFarmScanRange", {
    Text = "Scan Range",
    Default = 500,
    Min = 50,
    Max = 2000,
    Rounding = 0,
    Suffix = " studs",
    Callback = function(v) BossFarm.ScanRange = v end
})

BossFarmGroup:AddSlider("BossFarmMinHP", {
    Text = "Min Boss HP",
    Default = 450,
    Min = 100,
    Max = 5000,
    Rounding = 0,
    Suffix = " HP",
    Callback = function(v) BossFarm.MinHealth = v end
})

BossFarmGroup:AddLabel("Anchors above boss + fires CheckMeleeHit.")
BossFarmGroup:AddLabel("Toggle with G key. Boss dies → auto stops.")

-- ==================== CHAKRA SENSE TRACKER ====================
local ChakraTracker = {
    ActiveUsers = {},
    ScreenAlerts = {},   -- Drawing.new("Text") per player — persistent on-screen indicators we fully control
    Tracks = {},
    Connections = {},
    PendingStops = {},
    SkillID = "9864206537",
    Label = nil
}

-- Persistent on-screen alert management (Drawing objects, not Library:Notify)
local function CreateScreenAlert(playerName)
    if ChakraTracker.ScreenAlerts[playerName] then return end -- already exists
    local alert = Drawing.new("Text")
    alert.Text = playerName .. " is using Chakra Sense"
    alert.Size = 18
    alert.Center = true
    alert.Outline = true
    alert.OutlineColor = Color3.new(0, 0, 0)
    alert.Color = Color3.fromRGB(255, 100, 100)
    alert.Visible = true
    alert.Position = Vector2.new(Camera.ViewportSize.X / 2, 50)
    ChakraTracker.ScreenAlerts[playerName] = alert
    -- Reposition all alerts so they stack vertically
    local idx = 0
    for _, a in pairs(ChakraTracker.ScreenAlerts) do
        a.Position = Vector2.new(Camera.ViewportSize.X / 2, 50 + idx * 22)
        idx = idx + 1
    end
end

local function RemoveScreenAlert(playerName)
    local alert = ChakraTracker.ScreenAlerts[playerName]
    if alert then
        alert.Visible = false
        alert:Remove()
        ChakraTracker.ScreenAlerts[playerName] = nil
    end
    -- Reposition remaining alerts
    local idx = 0
    for _, a in pairs(ChakraTracker.ScreenAlerts) do
        a.Position = Vector2.new(Camera.ViewportSize.X / 2, 50 + idx * 22)
        idx = idx + 1
    end
end

local function UpdateLabel()
    if not ChakraTracker.Label then return end
    local names = {}
    for name, _ in pairs(ChakraTracker.ActiveUsers) do
        table.insert(names, name)
    end
    if #names == 0 then
        ChakraTracker.Label:SetText("No one using Chakra Sense")
    else
        ChakraTracker.Label:SetText("Chakra Sense: " .. table.concat(names, ", "))
    end
end

local function StopTracking(player)
    if ChakraTracker.ActiveUsers[player.Name] then
        ChakraTracker.ActiveUsers[player.Name] = nil
        ChakraTracker.Tracks[player.Name] = nil
        RemoveScreenAlert(player.Name)
        UpdateLabel()
        Library:Notify(player.Name .. " stopped Chakra Sense", 3)
    end
end

local function MonitorPlayer(player)
    if player == LocalPlayer then return end
    local function onCharacterAdded(character)
        task.wait(0.5)
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if not humanoid then return end
        local animator = humanoid:FindFirstChildOfClass("Animator")
        if not animator then return end

        -- Clean up old connections for this player
        if ChakraTracker.Connections[player] then
            for _, conn in ipairs(ChakraTracker.Connections[player]) do
                conn:Disconnect()
            end
        end
        ChakraTracker.Connections[player] = {}

        local function onAnimPlayed(track)
            local assetId = track.Animation.AnimationId:match("rbxassetid://(%d+)")
            if assetId ~= ChakraTracker.SkillID then return end

            -- Cancel any pending stop (animation re-fired before grace period expired)
            if ChakraTracker.PendingStops[player.Name] then
                ChakraTracker.PendingStops[player.Name] = nil
            end

            -- If already active, just update the track reference (animation re-fired) — don't create another notification
            if ChakraTracker.ActiveUsers[player.Name] then
                ChakraTracker.Tracks[player.Name] = track
                return
            end

            -- Activate
            ChakraTracker.ActiveUsers[player.Name] = true
            ChakraTracker.Tracks[player.Name] = track
            UpdateLabel()
            CreateScreenAlert(player.Name)  -- persistent on-screen Drawing text, removed only when they stop

            -- Monitor this track for stopping with grace period
            local trackConnections = {}

            -- Heartbeat check with 1-second grace period
            local heartbeatConn
            heartbeatConn = RunService.Heartbeat:Connect(function()
                if not track or not track.IsPlaying then
                    -- Don't stop immediately — set a pending stop with grace period
                    if ChakraTracker.ActiveUsers[player.Name] and not ChakraTracker.PendingStops[player.Name] then
                        ChakraTracker.PendingStops[player.Name] = tick()
                    end
                    -- If grace period (1 second) expired and still pending, actually stop
                    if ChakraTracker.PendingStops[player.Name] and (tick() - ChakraTracker.PendingStops[player.Name]) > 1 then
                        ChakraTracker.PendingStops[player.Name] = nil
                        StopTracking(player)
                        heartbeatConn:Disconnect()
                    end
                else
                    -- Animation is playing again, cancel any pending stop
                    ChakraTracker.PendingStops[player.Name] = nil
                end
            end)
            table.insert(trackConnections, heartbeatConn)

            -- Store track-specific connections for cleanup
            ChakraTracker.Connections[player] = ChakraTracker.Connections[player] or {}
            for _, conn in ipairs(trackConnections) do
                table.insert(ChakraTracker.Connections[player], conn)
            end
        end

        local playedConn = animator.AnimationPlayed:Connect(onAnimPlayed)
        table.insert(ChakraTracker.Connections[player], playedConn)

        -- Check existing tracks
        for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
            onAnimPlayed(track)
        end
    end

    player.CharacterAdded:Connect(onCharacterAdded)
    if player.Character then
        onCharacterAdded(player.Character)
    end
end

-- Initialize existing players
for _, player in ipairs(Players:GetPlayers()) do
    MonitorPlayer(player)
end

-- New players
Players.PlayerAdded:Connect(MonitorPlayer)

-- Cleanup on player leave
Players.PlayerRemoving:Connect(function(player)
    if ChakraTracker.Connections[player] then
        for _, conn in ipairs(ChakraTracker.Connections[player]) do
            conn:Disconnect()
        end
        ChakraTracker.Connections[player] = nil
    end
    if ChakraTracker.ActiveUsers[player.Name] then
        StopTracking(player)
    end
end)

-- Add UI to Misc tab
local MiscGroup = Tabs.Misc:AddLeftGroupbox("Skill Status")
ChakraTracker.Label = MiscGroup:AddLabel("No one using Chakra Sense")
UpdateLabel()

-- ==================== AUTO PERFECT BLOCK (FIXED) ====================
-- Permanent config (edit this table directly)
local BlockRules = {
   { animID = "6360969229", delay = 0.18, distance = 15 },
   { animID = "11330795390", delay = 0.115, distance = 6 },
   { animID = "7275651023", delay = 0.2, distance = 19 },
   { animID = "86213040968703", delay = 0.0, distance = 25, continuous = true },
   { animID = "116907126244057", delay = 1.1, continuous = true },
   { animID = "120758909308511", delay = 1.0,distance = 101,  continuous = true },
}

-- Test rule (temporary)
local TestRule = nil

-- Runtime data
local AutoBlock = {
    Enabled = false,
    Connections = {},
    Triggered = {},
    ContinuousMonitors = {}, -- key = playerName..animID, value = RBXScriptConnection
    MobConnections = {},     -- key = model, value = {connections}
    MobScanThread = nil,
    MobScanInterval = 2,
}

-- Remote events
local DataFunction = game:GetService("ReplicatedStorage"):FindFirstChild("Events") and 
                    game:GetService("ReplicatedStorage").Events:FindFirstChild("DataFunction")

local function GetDistanceToPlayer(player)
    local localChar = LocalPlayer.Character
    local targetChar = player.Character
    if not localChar or not targetChar then return nil end
    local localRoot = localChar:FindFirstChild("HumanoidRootPart") or localChar:FindFirstChild("Head")
    local targetRoot = targetChar:FindFirstChild("HumanoidRootPart") or targetChar:FindFirstChild("Head")
    if not localRoot or not targetRoot then return nil end
    return (localRoot.Position - targetRoot.Position).Magnitude
end

local function Block()
    if not DataFunction then return end
    DataFunction:InvokeServer("Block")
end

local function Unblock()
    if not DataFunction then return end
    DataFunction:InvokeServer("EndBlock")
end

local function ScheduleBlock(playerName, delay)
    if AutoBlock.Triggered[playerName] then return end
    AutoBlock.Triggered[playerName] = true

    local function doBlock()
        if not AutoBlock.Enabled then
            AutoBlock.Triggered[playerName] = nil
            return
        end
        Block()
        task.delay(0.5, function()
            if AutoBlock.Enabled then Unblock() end
            AutoBlock.Triggered[playerName] = nil
        end)
    end

    if delay <= 0.01 then
        -- Fire immediately — no task.delay overhead (~16ms saved)
        task.spawn(doBlock)
    else
        task.delay(delay, doBlock)
    end
end

-- Continuous block: monitors a long-running animation and blocks whenever the player is within distance
local function StartContinuousBlock(player, track, rule)
    local key = player.Name .. "_" .. rule.animID
    -- Don't duplicate if already monitoring this animation for this player
    if AutoBlock.ContinuousMonitors[key] then return end

    local isBlocking = false
    local conn
    conn = RunService.Heartbeat:Connect(function()
        -- Stop monitoring if disabled, track stopped, or player/character gone
        if not AutoBlock.Enabled or not track or not track.IsPlaying or not player.Character then
            if isBlocking then
                Unblock()
                isBlocking = false
            end
            conn:Disconnect()
            AutoBlock.ContinuousMonitors[key] = nil
            return
        end

        local dist = GetDistanceToPlayer(player)
        if dist and dist <= (rule.distance or 999) then
            if not isBlocking then
                local function doContBlock()
                    if AutoBlock.Enabled and track and track.IsPlaying then
                        local d = GetDistanceToPlayer(player)
                        if d and d <= (rule.distance or 999) then
                            Block()
                            isBlocking = true
                        end
                    end
                end
                if (rule.delay or 0.1) <= 0.01 then
                    task.spawn(doContBlock)
                else
                    task.delay(rule.delay or 0.1, doContBlock)
                end
            end
        else
            if isBlocking then
                Unblock()
                isBlocking = false
            end
        end
    end)

    AutoBlock.ContinuousMonitors[key] = conn
    -- Also store in player connections for cleanup
    if not AutoBlock.Connections[player] then AutoBlock.Connections[player] = {} end
    table.insert(AutoBlock.Connections[player], conn)
end

local function MonitorPlayerBlock(player, character)
    if not character or player == LocalPlayer then return end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end
    local animator = humanoid:FindFirstChildOfClass("Animator")
    if not animator then return end

    local function onAnimPlayed(track)
        if not AutoBlock.Enabled then return end
        local animId = track.Animation.AnimationId
        local assetId = animId:match("rbxassetid://(%d+)") or animId

        -- Check permanent rules
        for _, rule in ipairs(BlockRules) do
            if assetId == rule.animID then
                if rule.continuous then
                    -- Long-running animation: continuously monitor distance while it plays
                    StartContinuousBlock(player, track, rule)
                else
                    if rule.distance then
                        local dist = GetDistanceToPlayer(player)
                        if not dist or dist > rule.distance then return end
                    end
                    ScheduleBlock(player.Name, rule.delay or 0.3)
                end
                return
            end
        end

        -- Check test rule
        if TestRule and assetId == TestRule.animID then
            if TestRule.continuous then
                StartContinuousBlock(player, track, TestRule)
            else
                if TestRule.distance then
                    local dist = GetDistanceToPlayer(player)
                    if not dist or dist > TestRule.distance then return end
                end
                ScheduleBlock(player.Name, TestRule.delay or 0.3)
            end
        end
    end

    local conn = animator.AnimationPlayed:Connect(onAnimPlayed)
    if not AutoBlock.Connections[player] then AutoBlock.Connections[player] = {} end
    table.insert(AutoBlock.Connections[player], conn)

    for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
        onAnimPlayed(track)
    end
end

-- Initialize players (same as before)
for _, player in ipairs(Players:GetPlayers()) do
    if player ~= LocalPlayer then
        player.CharacterAdded:Connect(function(char)
            task.wait(0.5)
            MonitorPlayerBlock(player, char)
        end)
        if player.Character then
            MonitorPlayerBlock(player, player.Character)
        end
    end
end

Players.PlayerAdded:Connect(function(player)
    if player == LocalPlayer then return end
    player.CharacterAdded:Connect(function(char)
        task.wait(0.5)
        MonitorPlayerBlock(player, char)
    end)
    if player.Character then
        MonitorPlayerBlock(player, player.Character)
    end
end)

Players.PlayerRemoving:Connect(function(player)
    if AutoBlock.Connections[player] then
        for _, conn in ipairs(AutoBlock.Connections[player]) do
            conn:Disconnect()
        end
        AutoBlock.Connections[player] = nil
    end
    AutoBlock.Triggered[player.Name] = nil
    -- Clean up continuous monitors for this player
    for key, conn in pairs(AutoBlock.ContinuousMonitors) do
        if key:find("^" .. player.Name .. "_") then
            conn:Disconnect()
            AutoBlock.ContinuousMonitors[key] = nil
        end
    end
end)

-- ==================== MOB AUTO BLOCK ====================
local function GetDistanceToMob(model)
    local localChar = LocalPlayer.Character
    if not localChar or not model then return nil end
    local localRoot = localChar:FindFirstChild("HumanoidRootPart") or localChar:FindFirstChild("Head")
    local targetRoot = model:FindFirstChild("HumanoidRootPart") or model:FindFirstChild("Head")
    if not localRoot or not targetRoot then return nil end
    return (localRoot.Position - targetRoot.Position).Magnitude
end

local function StartContinuousBlockMob(model, track, rule)
    local key = "mob_" .. model.Name .. "_" .. rule.animID
    if AutoBlock.ContinuousMonitors[key] then return end

    local isBlocking = false
    local conn
    conn = RunService.Heartbeat:Connect(function()
        if not AutoBlock.Enabled or not track or not track.IsPlaying or not model.Parent then
            if isBlocking then
                Unblock()
                isBlocking = false
            end
            conn:Disconnect()
            AutoBlock.ContinuousMonitors[key] = nil
            return
        end

        local dist = GetDistanceToMob(model)
        if dist and dist <= (rule.distance or 999) then
            if not isBlocking then
                local function doContBlock()
                    if AutoBlock.Enabled and track and track.IsPlaying then
                        local d = GetDistanceToMob(model)
                        if d and d <= (rule.distance or 999) then
                            Block()
                            isBlocking = true
                        end
                    end
                end
                if (rule.delay or 0.1) <= 0.01 then
                    task.spawn(doContBlock)
                else
                    task.delay(rule.delay or 0.1, doContBlock)
                end
            end
        else
            if isBlocking then
                Unblock()
                isBlocking = false
            end
        end
    end)

    AutoBlock.ContinuousMonitors[key] = conn
end

local function MonitorMobBlock(model)
    if AutoBlock.MobConnections[model] then return end
    local humanoid = model:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end
    local animator = humanoid:FindFirstChildOfClass("Animator")
    if not animator then return end

    local function onAnimPlayed(track)
        if not AutoBlock.Enabled then return end
        local animId = track.Animation.AnimationId
        local assetId = animId:match("rbxassetid://(%d+)") or animId

        for _, rule in ipairs(BlockRules) do
            if assetId == rule.animID then
                if rule.continuous then
                    StartContinuousBlockMob(model, track, rule)
                else
                    if rule.distance then
                        local dist = GetDistanceToMob(model)
                        if not dist or dist > rule.distance then return end
                    end
                    ScheduleBlock("mob_" .. model.Name, rule.delay or 0.3)
                end
                return
            end
        end

        if TestRule and assetId == TestRule.animID then
            if TestRule.continuous then
                StartContinuousBlockMob(model, track, TestRule)
            else
                if TestRule.distance then
                    local dist = GetDistanceToMob(model)
                    if not dist or dist > TestRule.distance then return end
                end
                ScheduleBlock("mob_" .. model.Name, TestRule.delay or 0.3)
            end
        end
    end

    local conn = animator.AnimationPlayed:Connect(onAnimPlayed)
    AutoBlock.MobConnections[model] = {conn}

    for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
        onAnimPlayed(track)
    end
end

local function ScanForBlockMobs()
    local localChar = LocalPlayer.Character
    if not localChar then return end
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("Humanoid") and obj.Parent and obj.Parent ~= localChar then
            local player = Players:GetPlayerFromCharacter(obj.Parent)
            if not player and not AutoBlock.MobConnections[obj.Parent] then
                local dist = GetDistanceToMob(obj.Parent)
                if dist and dist <= 100 then -- scan range for mob block
                    MonitorMobBlock(obj.Parent)
                end
            end
        end
    end
    -- Clean up dead mobs
    for model, conns in pairs(AutoBlock.MobConnections) do
        if not model or not model.Parent then
            for _, c in ipairs(conns) do c:Disconnect() end
            AutoBlock.MobConnections[model] = nil
        end
    end
end

local function StartMobBlockScan()
    if AutoBlock.MobScanThread then pcall(task.cancel, AutoBlock.MobScanThread) end
    AutoBlock.MobScanThread = task.spawn(function()
        while AutoBlock.Enabled do
            ScanForBlockMobs()
            task.wait(AutoBlock.MobScanInterval)
        end
    end)
end

local function StopMobBlockScan()
    if AutoBlock.MobScanThread then
        pcall(task.cancel, AutoBlock.MobScanThread)
        AutoBlock.MobScanThread = nil
    end
    for model, conns in pairs(AutoBlock.MobConnections) do
        for _, c in ipairs(conns) do c:Disconnect() end
    end
    AutoBlock.MobConnections = {}
end

-- ===== UI =====
local BlockGroup = Tabs.Misc:AddLeftGroupbox("Auto Perfect Block")

BlockGroup:AddToggle("AutoBlockToggle", {
    Text = "Enable Auto Block",
    Default = false,
    Callback = function(v)
        AutoBlock.Enabled = v
        if v then
            StartMobBlockScan()
        else
            StopMobBlockScan()
        end
    end
})

-- Test section
local TestGroup = Tabs.Misc:AddLeftGroupbox("Test a Rule")

-- Inputs
TestGroup:AddInput("TestAnimID", {
    Text = "Animation ID",
    Default = "",
    Placeholder = "e.g., 9864206537",
    Numeric = true,
    Finished = false,
    Callback = function(v) _G.TestAnimID = v end
})

TestGroup:AddSlider("TestDelay", {
    Text = "Block Delay (s)",
    Default = 0.3,
    Min = 0, Max = 2, Rounding = 2, Suffix = "s",
    Callback = function(v) _G.TestDelay = v end
})

TestGroup:AddSlider("TestDistance", {
    Text = "Max Distance (0 = no limit)",
    Default = 0, Min = 0, Max = 500, Rounding = 0, Suffix = "studs",
    Callback = function(v) _G.TestDistance = v end
})

TestGroup:AddToggle("TestContinuous", {
    Text = "Continuous (long anim)",
    Default = false,
    Tooltip = "Keep blocking while animation plays and player is in range",
    Callback = function(v) _G.TestContinuous = v end
})

-- Test rule status display
local TestStatus = TestGroup:AddLabel("No test rule active.")

local function UpdateTestStatus()
    if TestRule then
        TestStatus:SetText(string.format("ID: %s | Delay: %.3fs | Dist: %s | %s",
            TestRule.animID,
            TestRule.delay,
            TestRule.distance and (TestRule.distance.." studs") or "No limit",
            TestRule.continuous and "Continuous" or "One-shot"))
    else
        TestStatus:SetText("No test rule active.")
    end
end

TestGroup:AddButton({
    Text = "Apply Test Rule",
    Func = function()
        local id = _G.TestAnimID or ""
        if id == "" then Library:Notify("Enter an ID", 3); return end
        TestRule = {
            animID = id,
            delay = _G.TestDelay or 0.3,
            distance = (_G.TestDistance and _G.TestDistance > 0) and _G.TestDistance or nil,
            continuous = _G.TestContinuous or false
        }
        UpdateTestStatus()
        Library:Notify("Test rule applied", 2)
    end
})

TestGroup:AddButton({
    Text = "Clear Test Rule",
    Func = function()
        TestRule = nil
        UpdateTestStatus()
        Library:Notify("Test rule cleared", 2)
    end
})

TestGroup:AddButton({
    Text = "Copy Rule as Lua",
    Func = function()
        if not TestRule then Library:Notify("No rule to copy", 3); return end
        local dist = TestRule.distance and (", distance = " .. TestRule.distance) or ""
        local cont = TestRule.continuous and ", continuous = true" or ""
        local code = string.format('{ animID = "%s", delay = %.3f%s%s },', TestRule.animID, TestRule.delay, dist, cont)
        setclipboard(code)
        Library:Notify("Lua code copied", 2)
    end
})

-- Permanent rules display
local PermGroup = Tabs.Misc:AddLeftGroupbox("Permanent Rules")
local permText = ""
for i, rule in ipairs(BlockRules) do
    local mode = rule.continuous and "Continuous" or "One-shot"
    permText = permText .. string.format("%d. ID: %s, Delay: %.3fs, Dist: %s, %s\n", i, rule.animID, rule.delay or 0.3, rule.distance and (rule.distance.." studs") or "Any", mode)
end
if permText == "" then permText = "No permanent rules." end
PermGroup:AddLabel(permText)
PermGroup:AddLabel("Edit BlockRules table in script to add/modify.")
-- ==================== ANIMATION FETCHER ====================
local AnimFetcher = {
    Enabled = false,
    MobEnabled = false,
    MaxDistance = 50,
    Connections = {},
    MobConnections = {},    -- key = model instance
    MobScanThread = nil,
    MobScanInterval = 2,
}

local function GetDistanceToPlayer(player)
    local localChar = LocalPlayer.Character
    local targetChar = player.Character
    if not localChar or not targetChar then return nil end
    local localRoot = localChar:FindFirstChild("HumanoidRootPart") or localChar:FindFirstChild("Head")
    local targetRoot = targetChar:FindFirstChild("HumanoidRootPart") or targetChar:FindFirstChild("Head")
    if not localRoot or not targetRoot then return nil end
    return (localRoot.Position - targetRoot.Position).Magnitude
end

local function GetDistanceToModel(model)
    local localChar = LocalPlayer.Character
    if not localChar then return nil end
    local localRoot = localChar:FindFirstChild("HumanoidRootPart") or localChar:FindFirstChild("Head")
    if not localRoot then return nil end
    local targetRoot = model:FindFirstChild("HumanoidRootPart") or model:FindFirstChild("Head")
    if not targetRoot then return nil end
    return (localRoot.Position - targetRoot.Position).Magnitude
end

local function MonitorPlayerAnim(player, character)
    if not character or player == LocalPlayer then return end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end
    local animator = humanoid:FindFirstChildOfClass("Animator")
    if not animator then return end

    local function onAnimPlayed(track)
        if not AnimFetcher.Enabled then return end
        local distance = GetDistanceToPlayer(player)
        if not distance or distance > AnimFetcher.MaxDistance then return end
        local animId = track.Animation.AnimationId
        local assetId = animId:match("rbxassetid://(%d+)") or animId
        Library:Notify(string.format("[%d studs] %s: %s", math.floor(distance), player.Name, assetId), 5)
    end

    local conn = animator.AnimationPlayed:Connect(onAnimPlayed)
    if not AnimFetcher.Connections[player] then AnimFetcher.Connections[player] = {} end
    table.insert(AnimFetcher.Connections[player], conn)

    -- Also log currently playing animations
    for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
        onAnimPlayed(track)
    end
end

-- Monitor a mob/NPC model for animations
local function MonitorMobAnim(model)
    if AnimFetcher.MobConnections[model] then return end -- already monitoring
    local humanoid = model:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end
    local animator = humanoid:FindFirstChildOfClass("Animator")
    if not animator then return end

    local function onAnimPlayed(track)
        if not AnimFetcher.MobEnabled then return end
        local distance = GetDistanceToModel(model)
        if not distance or distance > AnimFetcher.MaxDistance then return end
        local animId = track.Animation.AnimationId
        local assetId = animId:match("rbxassetid://(%d+)") or animId
        Library:Notify(string.format("[MOB %d studs] %s: %s", math.floor(distance), model.Name, assetId), 5)
    end

    local conn = animator.AnimationPlayed:Connect(onAnimPlayed)
    AnimFetcher.MobConnections[model] = {conn}

    -- Log currently playing
    for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
        onAnimPlayed(track)
    end
end

local function ScanForMobs()
    local localChar = LocalPlayer.Character
    if not localChar then return end
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("Humanoid") and obj.Parent and obj.Parent ~= localChar then
            local player = Players:GetPlayerFromCharacter(obj.Parent)
            if not player then
                local model = obj.Parent
                if not AnimFetcher.MobConnections[model] then
                    local dist = GetDistanceToModel(model)
                    if dist and dist <= AnimFetcher.MaxDistance then
                        MonitorMobAnim(model)
                    end
                end
            end
        end
    end
    -- Clean up dead mobs
    for model, conns in pairs(AnimFetcher.MobConnections) do
        if not model or not model.Parent then
            for _, c in ipairs(conns) do c:Disconnect() end
            AnimFetcher.MobConnections[model] = nil
        end
    end
end

local function StartMobScan()
    if AnimFetcher.MobScanThread then pcall(task.cancel, AnimFetcher.MobScanThread) end
    AnimFetcher.MobScanThread = task.spawn(function()
        while AnimFetcher.MobEnabled do
            ScanForMobs()
            task.wait(AnimFetcher.MobScanInterval)
        end
    end)
end

local function StopMobScan()
    if AnimFetcher.MobScanThread then
        pcall(task.cancel, AnimFetcher.MobScanThread)
        AnimFetcher.MobScanThread = nil
    end
    for model, conns in pairs(AnimFetcher.MobConnections) do
        for _, c in ipairs(conns) do c:Disconnect() end
    end
    AnimFetcher.MobConnections = {}
end

-- Initialize existing players (same as before)
for _, player in ipairs(Players:GetPlayers()) do
    if player ~= LocalPlayer then
        player.CharacterAdded:Connect(function(char)
            task.wait(0.5)
            MonitorPlayerAnim(player, char)
        end)
        if player.Character then
            MonitorPlayerAnim(player, player.Character)
        end
    end
end

-- New players
Players.PlayerAdded:Connect(function(player)
    if player == LocalPlayer then return end
    player.CharacterAdded:Connect(function(char)
        task.wait(0.5)
        MonitorPlayerAnim(player, char)
    end)
    if player.Character then
        MonitorPlayerAnim(player, player.Character)
    end
end)

-- Cleanup
Players.PlayerRemoving:Connect(function(player)
    if AnimFetcher.Connections[player] then
        for _, conn in ipairs(AnimFetcher.Connections[player]) do
            conn:Disconnect()
        end
        AnimFetcher.Connections[player] = nil
    end
end)

-- UI Controls
local FetcherGroup = Tabs.Misc:AddLeftGroupbox("Animation Fetcher")
FetcherGroup:AddToggle("AnimFetcherToggle", {
    Text = "Log Animations",
    Default = false,
    Callback = function(value)
        AnimFetcher.Enabled = value
    end
})
FetcherGroup:AddSlider("AnimFetcherDistance", {
    Text = "Max Distance",
    Default = 50,
    Min = 10,
    Max = 500,
    Rounding = 0,
    Suffix = " studs",
    Callback = function(value)
        AnimFetcher.MaxDistance = value
    end
})
FetcherGroup:AddLabel("Only logs animations within this range.")
FetcherGroup:AddToggle("AnimFetcherMobToggle", {
    Text = "Log Mob/NPC Animations",
    Default = false,
    Callback = function(value)
        AnimFetcher.MobEnabled = value
        if value then
            StartMobScan()
        else
            StopMobScan()
        end
    end
})
FetcherGroup:AddLabel("Mob anims shown as [MOB] in notifications.")

-- ==================== ANIMATION PLAYER ====================
local AnimPlayer = {
    CurrentTrack = nil,
    AnimId = "",
    Looping = false,
    Speed = 1
}

local AnimPlayerGroup = Tabs.Misc:AddRightGroupbox("Animation Player")

AnimPlayerGroup:AddInput("AnimPlayerId", {
    Default = "",
    Numeric = false,
    Finished = false,
    Text = "Animation ID",
    Tooltip = "Enter a Roblox animation asset ID (numbers only or rbxassetid://...)",
    Placeholder = "e.g. 12345678",
    Callback = function(value)
        AnimPlayer.AnimId = value
    end
})

AnimPlayerGroup:AddToggle("AnimPlayerLoop", {
    Text = "Loop Animation",
    Default = false,
    Callback = function(value)
        AnimPlayer.Looping = value
        if AnimPlayer.CurrentTrack then
            AnimPlayer.CurrentTrack.Looped = value
        end
    end
})

AnimPlayerGroup:AddSlider("AnimPlayerSpeed", {
    Text = "Playback Speed",
    Default = 1,
    Min = 0.1,
    Max = 3,
    Rounding = 1,
    Suffix = "x",
    Callback = function(value)
        AnimPlayer.Speed = value
        if AnimPlayer.CurrentTrack and AnimPlayer.CurrentTrack.IsPlaying then
            AnimPlayer.CurrentTrack:AdjustSpeed(value)
        end
    end
})

AnimPlayerGroup:AddButton({
    Text = "Play Animation",
    Func = function()
        local id = AnimPlayer.AnimId
        if not id or id == "" then
            Library:Notify("Enter an animation ID first!", 3)
            return
        end

        -- Normalize the ID
        if not id:match("rbxassetid://") then
            id = "rbxassetid://" .. id:match("%d+")
        end

        local char = LocalPlayer.Character
        if not char then
            Library:Notify("No character found!", 3)
            return
        end

        local humanoid = char:FindFirstChildOfClass("Humanoid")
        if not humanoid then
            Library:Notify("No humanoid found!", 3)
            return
        end

        local animator = humanoid:FindFirstChildOfClass("Animator")
        if not animator then
            animator = Instance.new("Animator")
            animator.Parent = humanoid
        end

        -- Stop previous preview
        if AnimPlayer.CurrentTrack then
            pcall(function() AnimPlayer.CurrentTrack:Stop() end)
            pcall(function() AnimPlayer.CurrentTrack:Destroy() end)
            AnimPlayer.CurrentTrack = nil
        end

        local anim = Instance.new("Animation")
        anim.AnimationId = id

        local ok, track = pcall(function()
            return animator:LoadAnimation(anim)
        end)

        if not ok or not track then
            Library:Notify("Failed to load animation: " .. tostring(id), 3)
            anim:Destroy()
            return
        end

        track.Looped = AnimPlayer.Looping
        track:Play()
        track:AdjustSpeed(AnimPlayer.Speed)
        AnimPlayer.CurrentTrack = track

        Library:Notify("Playing animation: " .. id, 3)
    end,
    DoubleClick = false,
    Tooltip = "Play the animation on your character"
})

AnimPlayerGroup:AddButton({
    Text = "Stop Animation",
    Func = function()
        if AnimPlayer.CurrentTrack then
            pcall(function() AnimPlayer.CurrentTrack:Stop() end)
            pcall(function() AnimPlayer.CurrentTrack:Destroy() end)
            AnimPlayer.CurrentTrack = nil
            Library:Notify("Animation stopped", 2)
        else
            Library:Notify("No animation is playing", 2)
        end
    end,
    DoubleClick = false,
    Tooltip = "Stop the currently previewed animation"
})

AnimPlayerGroup:AddLabel("Paste an ID from the fetcher to preview it.")

-- ==================== ANTI-CHEAT BYPASS & SERVER UTILITIES ====================
local MiscGroup = Tabs.Misc:AddLeftGroupbox("Anti-Cheat & Server")

-- Anti-Cheat bypass toggle
local AntiCheat = {
    Enabled = false,
    Connections = {}
}

local DataEvent = game:GetService("ReplicatedStorage"):FindFirstChild("Events") and 
                  game:GetService("ReplicatedStorage").Events:FindFirstChild("DataEvent")

if DataEvent then
    -- Block outgoing "BanMe" calls (if client tries to trigger it)
    local oldFireServer
    oldFireServer = hookfunction(DataEvent.FireServer, function(self, ...)
        if AntiCheat.Enabled then
            local args = {...}
            if args[1] == "BanMe" then
                Library:Notify("Blocked BanMe remote", 2)
                return -- block
            end
        end
        return oldFireServer(self, ...)
    end)
end


MiscGroup:AddToggle("ACToggle", {
    Text = "Enable Anti-Cheat Bypass",
    Default = false,
    Callback = function(v)
        AntiCheat.Enabled = v
    end
})

-- ==================== TELEPORT TAB ====================
local TeleportTab = Window:AddTab("Teleports")

-- Hardcoded teleport locations (edit this table to add your own)
local TeleportLocations = {
    -- Example entries (uncomment and modify as needed)
     { Name = "Wood Boss", Pos = Vector3.new(-4708.4, 336.9, -2986.2)},
     { Name = "Sorythia Village", Pos = Vector3.new(-113.2, 50.9, -283.8)},
     { Name = "Lava Snake Boss", Pos = Vector3.new(-547.6, -541.7, -1281.8)},
     { Name = "Biyo Bay", Pos = Vector3.new(-598.9, -178.6, -464.3)},
}

-- Function to teleport
local function TeleportTo(pos)
    local char = LocalPlayer.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Head")
    if root then
        root.CFrame = CFrame.new(pos)
    end
end

-- Left group: Current position and copy
local CurrentGroup = TeleportTab:AddLeftGroupbox("Current Position")

-- Live coordinate display
local CoordLabel = CurrentGroup:AddLabel("X: 0, Y: 0, Z: 0")
RunService.RenderStepped:Connect(function()
    local char = LocalPlayer.Character
    if char then
        local root = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Head")
        if root then
            local pos = root.Position
            CoordLabel:SetText(string.format("X: %.1f, Y: %.1f, Z: %.1f", pos.X, pos.Y, pos.Z))
        else
            CoordLabel:SetText("No character")
        end
    else
        CoordLabel:SetText("No character")
    end
end)

-- Button to copy current position as Vector3
CurrentGroup:AddButton({
    Text = "Copy Position as Vector3",
    Func = function()
        local char = LocalPlayer.Character
        if char then
            local root = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Head")
            if root then
                local pos = root.Position
                local text = string.format("Vector3.new(%.1f, %.1f, %.1f)", pos.X, pos.Y, pos.Z)
                setclipboard(text)
                Library:Notify("Coordinates copied to clipboard", 2)
            end
        end
    end
})

-- Right group: Hardcoded teleport list
local TeleportListGroup = TeleportTab:AddRightGroupbox("Teleport Locations")

-- Populate list from hardcoded table
for _, loc in ipairs(TeleportLocations) do
    TeleportListGroup:AddButton({
        Text = loc.Name .. " (" .. math.floor(loc.Pos.X) .. ", " .. math.floor(loc.Pos.Y) .. ", " .. math.floor(loc.Pos.Z) .. ")",
        Func = function()
            TeleportTo(loc.Pos)
            Library:Notify("Teleported to " .. loc.Name, 2)
        end
    })
end

if #TeleportLocations == 0 then
    TeleportListGroup:AddLabel("No locations defined. Edit the script to add them.")
end

-- ==================== CHAKRA POINT COLLECTOR ====================
local ChakraCollector = {
    Running = false,
    Thread = nil,
    Delay = 1.5,       -- seconds to wait at each point (for E press to register)
    CurrentIndex = 0,
    Total = 0,
}

local ChakraGroup = TeleportTab:AddLeftGroupbox("Chakra Point Collector")

local ChakraStatusLabel = ChakraGroup:AddLabel("Status: Idle")

local function PressE()
    -- Simulate pressing E via VirtualInputManager
    pcall(function()
        VirtualInput:SendKeyEvent(true, Enum.KeyCode.E, false, game)
        task.wait(0.15)
        VirtualInput:SendKeyEvent(false, Enum.KeyCode.E, false, game)
    end)
end

local function CollectChakraPoints()
    local char = LocalPlayer.Character
    if not char then
        Library:Notify("No character found", 3)
        return
    end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then
        Library:Notify("No HumanoidRootPart", 3)
        return
    end

    local chakraFolder = workspace:FindFirstChild("ChakraPoints")
    if not chakraFolder then
        Library:Notify("ChakraPoints folder not found in workspace", 3)
        return
    end

    local children = chakraFolder:GetChildren()
    ChakraCollector.Total = #children
    ChakraCollector.CurrentIndex = 0

    if ChakraCollector.Total == 0 then
        Library:Notify("No ChakraPoints found", 3)
        return
    end

    ChakraStatusLabel:SetText("Status: Running (0/" .. ChakraCollector.Total .. ")")
    Library:Notify("Starting Chakra Point collection (" .. ChakraCollector.Total .. " points)", 2)

    -- Count how many are already unlocked vs locked
    local lockedCount = 0
    for _, point in ipairs(children) do
        local unlocked = point:FindFirstChild("Unlocked")
        if not unlocked or (tostring(unlocked.Value):lower() ~= "on" and unlocked.Value ~= true) then
            lockedCount = lockedCount + 1
        end
    end
    Library:Notify(lockedCount .. " locked points to collect (" .. (#children - lockedCount) .. " already unlocked)", 3)

    for i, point in ipairs(children) do
        if not ChakraCollector.Running then
            ChakraStatusLabel:SetText("Status: Stopped at " .. i - 1 .. "/" .. ChakraCollector.Total)
            Library:Notify("Chakra collection stopped", 2)
            return
        end

        -- Skip already unlocked points
        local unlocked = point:FindFirstChild("Unlocked")
        if unlocked and (tostring(unlocked.Value):lower() == "on" or unlocked.Value == true) then
            if M1Spam and M1Spam.Debug then
                print(string.format("[Chakra] Skipping point %d (%s) — already unlocked", i, point.Name))
            end
            ChakraStatusLabel:SetText("Status: Skipped " .. i .. "/" .. ChakraCollector.Total .. " (unlocked)")
            continue
        end

        ChakraCollector.CurrentIndex = i
        ChakraStatusLabel:SetText("Status: Point " .. i .. "/" .. ChakraCollector.Total)

        -- Get position from the point's CFrame/Position/WorldPivot
        local targetPos = nil
        pcall(function()
            -- Try WorldPivot first (Model)
            if point:IsA("Model") then
                targetPos = point:GetPivot().Position
            elseif point:IsA("BasePart") then
                targetPos = point.Position
            end
        end)

        -- Fallback: try PrimaryPart or first BasePart child
        if not targetPos then
            pcall(function()
                local primary = point.PrimaryPart or point:FindFirstChildWhichIsA("BasePart")
                if primary then
                    targetPos = primary.Position
                end
            end)
        end

        if targetPos then
            -- Teleport to the point
            root.CFrame = CFrame.new(targetPos)
            if M1Spam and M1Spam.Debug then
                print(string.format("[Chakra] Teleported to point %d at (%.1f, %.1f, %.1f)", i, targetPos.X, targetPos.Y, targetPos.Z))
            end

            -- Wait a moment for the game to register proximity
            task.wait(0.5)

            -- Press E to interact
            PressE()

            -- Wait for interaction to complete
            task.wait(ChakraCollector.Delay)
        else
            if M1Spam and M1Spam.Debug then
                print(string.format("[Chakra] Could not get position for point %d (%s)", i, point.Name))
            end
        end
    end

    ChakraCollector.Running = false
    ChakraStatusLabel:SetText("Status: Done (" .. ChakraCollector.Total .. "/" .. ChakraCollector.Total .. ")")
    Library:Notify("Chakra Point collection complete!", 2)
end

ChakraGroup:AddToggle("ChakraCollectorToggle", {
    Text = "Auto Collect Chakra Points",
    Default = false,
    Callback = function(v)
        ChakraCollector.Running = v
        if v then
            if ChakraCollector.Thread then
                task.cancel(ChakraCollector.Thread)
            end
            ChakraCollector.Thread = task.spawn(CollectChakraPoints)
        else
            if ChakraCollector.Thread then
                task.cancel(ChakraCollector.Thread)
                ChakraCollector.Thread = nil
            end
            ChakraStatusLabel:SetText("Status: Stopped")
        end
    end
})

ChakraGroup:AddSlider("ChakraDelay", {
    Text = "Wait per Point (s)",
    Default = 1.5,
    Min = 0.5,
    Max = 5,
    Rounding = 1,
    Suffix = "s",
    Callback = function(v) ChakraCollector.Delay = v end
})

ChakraGroup:AddLabel("Teleports to each ChakraPoint and presses E.")

-- ==================== TRINKET AUTO COLLECTOR ====================
local TrinketCollector = {
    Running = false,
    Thread = nil,
    RenderThread = nil,
    ClickDelay = 0.5,
    CheckInterval = 2,
    PickupRange = 15,        -- Pickup range (hitbox size)
    MaxDistance = 100,       -- Max scan distance
    CollectedCount = 0,
    ShowHitbox = false,
    HitboxCircle = nil,
    DebugMode = false,       -- Show detailed notifications
}

local TrinketGroup = TeleportTab:AddRightGroupbox("Trinket Auto Collector")
local TrinketStatusLabel = TrinketGroup:AddLabel("Status: Idle")

-- Create hitbox visualization
local function CreateHitboxVisual()
    if TrinketCollector.HitboxCircle then
        TrinketCollector.HitboxCircle:Remove()
    end
    
    local circle = Drawing.new("Circle")
    circle.Thickness = 2
    circle.NumSides = 32
    circle.Radius = 100
    circle.Color = Color3.fromRGB(0, 255, 255)
    circle.Transparency = 0.7
    circle.Visible = false
    circle.Filled = false
    
    TrinketCollector.HitboxCircle = circle
    return circle
end

-- Update hitbox position on screen
local function UpdateHitboxVisual()
    if not TrinketCollector.ShowHitbox or not TrinketCollector.HitboxCircle then return end
    
    local char = LocalPlayer.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return end
    
    local camera = workspace.CurrentCamera
    local screenPos, onScreen = camera:WorldToViewportPoint(root.Position)
    
    if onScreen then
        -- Calculate radius based on distance and range
        local distance = (camera.CFrame.Position - root.Position).Magnitude
        local scale = 1 / distance * 1000
        local radius = TrinketCollector.PickupRange * scale
        
        TrinketCollector.HitboxCircle.Position = Vector2.new(screenPos.X, screenPos.Y)
        TrinketCollector.HitboxCircle.Radius = math.clamp(radius, 20, 300)
        TrinketCollector.HitboxCircle.Visible = true
    else
        TrinketCollector.HitboxCircle.Visible = false
    end
end

-- Function to find all actual trinkets in workspace
local function FindAllTrinkets()
    local trinkets = {}
    local trinketNames = {
        "Gold Bracelet",
        "Gold Ring",
        "Silver Ring",
        "Silver Bracelet",
        "Silver Necklace",
        "Gold Necklace",
        "Gold Enclosed Ring",
        "Silver Enclosed Ring",
        "Ring Schematics",
        "Ring Of The Neoncat",
        "Ring Of Resistance",
        "Ring Of Nourishment",
        "Ring Of Favor",


    }
    
    for _, trinketName in ipairs(trinketNames) do
        local trinket = workspace:FindFirstChild(trinketName)
        if trinket then
            table.insert(trinkets, trinket)
        end
    end
    
    return trinkets
end

-- Function to collect a trinket
local function CollectTrinket(trinket)
    if not trinket or not trinket.Parent then return false end
    
    -- Get trinket position
    local trinketPos = nil
    pcall(function()
        if trinket:IsA("Model") then
            trinketPos = trinket:GetPivot().Position
        elseif trinket:IsA("BasePart") then
            trinketPos = trinket.Position
        else
            local part = trinket:FindFirstChildWhichIsA("BasePart", true)
            if part then
                trinketPos = part.Position
            end
        end
    end)
    
    if not trinketPos then 
        if TrinketCollector.DebugMode then
            Library:Notify("Could not get position for " .. trinket.Name, 2)
        end
        return false 
    end
    
    -- Check distance to player
    local char = LocalPlayer.Character
    if not char then return false end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return false end
    
    local distance = (root.Position - trinketPos).Magnitude
    
    -- If too far, skip
    if distance > TrinketCollector.MaxDistance then
        return false
    end
    
    -- Teleport near the trinket
    root.CFrame = CFrame.new(trinketPos + Vector3.new(0, 3, 0))
    task.wait(0.3)
    
    -- Update distance after teleport
    distance = (root.Position - trinketPos).Magnitude
    
    -- Check if within pickup range using 3D hitbox detection
    if distance > TrinketCollector.PickupRange then
        if TrinketCollector.DebugMode then
            Library:Notify("Not in pickup range (" .. math.floor(distance) .. " studs)", 2)
        end
        return false
    end
    
    local success = false
    
    -- Method 1: Try ProximityPrompt first (most common for pickups)
    local proximityPrompt = trinket:FindFirstChildOfClass("ProximityPrompt", true)
    if proximityPrompt then
        pcall(function()
            fireproximityprompt(proximityPrompt)
            success = true
        end)
        task.wait(0.3)
    end
    
    -- Method 2: Fire the pickup remote
    if not success then
        local DataEvent = game:GetService("ReplicatedStorage"):FindFirstChild("Events")
        if DataEvent then
            DataEvent = DataEvent:FindFirstChild("DataEvent")
        end
        
        if DataEvent then
            pcall(function()
                DataEvent:FireServer("PickUp")
                success = true
            end)
            task.wait(0.3)
        end
    end
    
    -- Method 3: Try click detector
    if not success then
        local clickDetector = trinket:FindFirstChildOfClass("ClickDetector", true)
        if clickDetector then
            pcall(function()
                fireclickdetector(clickDetector)
                success = true
            end)
            task.wait(0.3)
        end
    end
    
    -- Method 4: Try finding and triggering any TouchTransmitter (for Touch-based pickups)
    if not success then
        pcall(function()
            local touchPart = trinket:FindFirstChildWhichIsA("BasePart", true)
            if touchPart then
                firetouchinterest(root, touchPart, 0)
                task.wait(0.1)
                firetouchinterest(root, touchPart, 1)
                success = true
            end
        end)
    end
    
    task.wait(TrinketCollector.ClickDelay)
    
    if success then
        TrinketCollector.CollectedCount = TrinketCollector.CollectedCount + 1
        Library:Notify("Collected " .. trinket.Name .. "!", 2)
    end
    
    return success
end

-- Main collection loop
local function TrinketCollectionLoop()
    TrinketCollector.CollectedCount = 0
    TrinketStatusLabel:SetText("Status: Running (0 collected)")
    
    while TrinketCollector.Running do
        local foundAny = false
        
        -- Find all actual trinket objects in workspace
        local trinkets = FindAllTrinkets()
        
        if #trinkets == 0 then
            TrinketStatusLabel:SetText("Status: No trinkets found!")
        else
            -- Check each trinket
            for _, trinket in ipairs(trinkets) do
                if not TrinketCollector.Running then break end
                
                local collected = CollectTrinket(trinket)
                
                if collected then
                    foundAny = true
                    TrinketStatusLabel:SetText(string.format("Status: Running (%d collected)", TrinketCollector.CollectedCount))
                end
            end
            
            if not foundAny then
                TrinketStatusLabel:SetText(string.format("Status: Waiting... (%d collected)", TrinketCollector.CollectedCount))
            end
        end
        
        -- Wait before next scan
        task.wait(TrinketCollector.CheckInterval)
    end
    
    TrinketStatusLabel:SetText(string.format("Status: Stopped (%d total collected)", TrinketCollector.CollectedCount))
end

-- Hitbox render loop
local function StartHitboxRender()
    if not TrinketCollector.HitboxCircle then
        CreateHitboxVisual()
    end
    
    if TrinketCollector.RenderThread then
        task.cancel(TrinketCollector.RenderThread)
    end
    
    TrinketCollector.RenderThread = task.spawn(function()
        while TrinketCollector.ShowHitbox do
            UpdateHitboxVisual()
            task.wait(0.1) -- Update 10 times per second instead of every frame
        end
        if TrinketCollector.HitboxCircle then
            TrinketCollector.HitboxCircle.Visible = false
        end
    end)
end

local function StopHitboxRender()
    if TrinketCollector.RenderThread then
        task.cancel(TrinketCollector.RenderThread)
        TrinketCollector.RenderThread = nil
    end
    if TrinketCollector.HitboxCircle then
        TrinketCollector.HitboxCircle.Visible = false
    end
end

-- UI Controls
TrinketGroup:AddToggle("TrinketCollectorToggle", {
    Text = "Auto Collect Trinkets",
    Default = false,
    Callback = function(v)
        TrinketCollector.Running = v
        if v then
            if TrinketCollector.Thread then
                task.cancel(TrinketCollector.Thread)
            end
            TrinketCollector.Thread = task.spawn(TrinketCollectionLoop)
        else
            if TrinketCollector.Thread then
                task.cancel(TrinketCollector.Thread)
                TrinketCollector.Thread = nil
            end
            TrinketStatusLabel:SetText(string.format("Status: Stopped (%d total collected)", TrinketCollector.CollectedCount))
        end
    end
}):AddKeyPicker("TrinketCollectorKey", {
    Default = "T",
    SyncToggleState = true,
    Mode = "Toggle",
    Text = "Trinket Collector",
})

TrinketGroup:AddSlider("TrinketCheckInterval", {
    Text = "Scan Interval (s)",
    Default = 2,
    Min = 0.5,
    Max = 10,
    Rounding = 1,
    Suffix = "s",
    Callback = function(v) TrinketCollector.CheckInterval = v end
})

TrinketGroup:AddSlider("TrinketClickDelay", {
    Text = "Click Delay (s)",
    Default = 0.5,
    Min = 0.1,
    Max = 3,
    Rounding = 1,
    Suffix = "s",
    Callback = function(v) TrinketCollector.ClickDelay = v end
})

TrinketGroup:AddSlider("TrinketMaxDistance", {
    Text = "Max Distance",
    Default = 100,
    Min = 50,
    Max = 500,
    Rounding = 0,
    Suffix = " studs",
    Callback = function(v) TrinketCollector.MaxDistance = v end
})

TrinketGroup:AddSlider("TrinketPickupRange", {
    Text = "Pickup Range",
    Default = 15,
    Min = 5,
    Max = 50,
    Rounding = 0,
    Suffix = " studs",
    Callback = function(v) TrinketCollector.PickupRange = v end,
    Tooltip = "Hitbox radius for collection"
})

TrinketGroup:AddToggle("ShowTrinketHitbox", {
    Text = "Show Pickup Hitbox",
    Default = false,
    Callback = function(v)
        TrinketCollector.ShowHitbox = v
        if v then
            StartHitboxRender()
        else
            StopHitboxRender()
        end
    end,
    Tooltip = "Visualize the pickup range around your character"
})

TrinketGroup:AddToggle("TrinketDebugMode", {
    Text = "Debug Notifications",
    Default = false,
    Callback = function(v)
        TrinketCollector.DebugMode = v
    end,
    Tooltip = "Show detailed notifications for debugging"
})

TrinketGroup:AddLabel("Uses 3D proximity detection (no clicking needed).")
TrinketGroup:AddLabel("Tries: ProximityPrompt → Remote → ClickDetector → Touch.")

-- ==================== RIFT COLLECTOR ====================
local RiftCollector = {
    Running = false,
    Thread = nil,
    Delay = 1.5,       -- seconds to wait at each rift
    CurrentIndex = 0,
    Total = 0,
}

local RiftGroup = TeleportTab:AddLeftGroupbox("Rift Collector")

local RiftStatusLabel = RiftGroup:AddLabel("Status: Idle")

local function CollectRifts()
    local char = LocalPlayer.Character
    if not char then
        Library:Notify("No character found", 3)
        return
    end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then
        Library:Notify("No HumanoidRootPart", 3)
        return
    end

    local riftsFolder = workspace:FindFirstChild("Rifts")
    if not riftsFolder then
        Library:Notify("Rifts folder not found in workspace", 3)
        return
    end

    local children = riftsFolder:GetChildren()
    RiftCollector.Total = #children
    RiftCollector.CurrentIndex = 0

    if RiftCollector.Total == 0 then
        Library:Notify("No Rifts found", 3)
        return
    end

    RiftStatusLabel:SetText("Status: Running (0/" .. RiftCollector.Total .. ")")
    Library:Notify("Starting Rift collection (" .. RiftCollector.Total .. " rifts)", 2)

    for i, rift in ipairs(children) do
        if not RiftCollector.Running then
            RiftStatusLabel:SetText("Status: Stopped at " .. i - 1 .. "/" .. RiftCollector.Total)
            Library:Notify("Rift collection stopped", 2)
            return
        end

        RiftCollector.CurrentIndex = i
        RiftStatusLabel:SetText("Status: Rift " .. i .. "/" .. RiftCollector.Total .. " (" .. rift.Name .. ")")

        -- Get position from the rift's CFrame/Position/WorldPivot
        local targetPos = nil
        pcall(function()
            if rift:IsA("Model") then
                targetPos = rift:GetPivot().Position
            elseif rift:IsA("BasePart") then
                targetPos = rift.Position
            end
        end)

        -- Fallback: try PrimaryPart or first BasePart child
        if not targetPos then
            pcall(function()
                local primary = rift.PrimaryPart or rift:FindFirstChildWhichIsA("BasePart")
                if primary then
                    targetPos = primary.Position
                end
            end)
        end

        if targetPos then
            -- Teleport to the rift
            root.CFrame = CFrame.new(targetPos)
            Library:Notify("Teleported to " .. rift.Name .. " (" .. i .. "/" .. RiftCollector.Total .. ")", 2)

            -- Wait for the game to register proximity
            task.wait(0.5)

            -- Press E to interact (if needed)
            PressE()

            -- Wait for interaction to complete
            task.wait(RiftCollector.Delay)
        else
            Library:Notify("Could not get position for rift " .. i, 2)
        end
    end

    RiftCollector.Running = false
    RiftStatusLabel:SetText("Status: Done (" .. RiftCollector.Total .. "/" .. RiftCollector.Total .. ")")
    Library:Notify("Rift collection complete!", 2)
end

RiftGroup:AddToggle("RiftCollectorToggle", {
    Text = "Auto Collect Rifts",
    Default = false,
    Callback = function(v)
        RiftCollector.Running = v
        if v then
            if RiftCollector.Thread then
                task.cancel(RiftCollector.Thread)
            end
            RiftCollector.Thread = task.spawn(CollectRifts)
        else
            if RiftCollector.Thread then
                task.cancel(RiftCollector.Thread)
                RiftCollector.Thread = nil
            end
            RiftStatusLabel:SetText("Status: Stopped")
        end
    end
})

RiftGroup:AddSlider("RiftDelay", {
    Text = "Wait per Rift (s)",
    Default = 1.5,
    Min = 0.5,
    Max = 5,
    Rounding = 1,
    Suffix = "s",
    Callback = function(v) RiftCollector.Delay = v end
})

RiftGroup:AddLabel("Teleports to each Unstable Rift in workspace.Rifts.")
RiftGroup:AddLabel("Presses E at each location.")

-- Theme
local ThemeTab = Window:AddTab("Theme")
ThemeManager:SetLibrary(Library)
ThemeManager:ApplyToTab(ThemeTab)

-- SaveManager
SaveManager:SetLibrary(Library)
SaveManager:SetFolder("UniversalHub")
SaveManager:BuildConfigSection(Tabs.Settings)

-- Initialize
Library:SetWatermark("Universal Hub")
Library:SetWatermarkVisibility(true)
SaveManager:LoadAutoloadConfig()

print("=== Universal Hub Loaded ===")
print("Press RightControl to toggle menu")
print("Healthbar ESP is active (name + distance + health)")
