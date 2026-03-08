-- Universal Hub - LinoriaLib + Unnamed ESP Core (No duplicate UI)

-- Load LinoriaLib
local success, Library = pcall(function()
    return loadstring(game:HttpGet("https://raw.githubusercontent.com/violin-suzutsuki/LinoriaLib/main/Library.lua"))()
end)

if not success then
    Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/violin-suzutsuki/LinoriaLib/main/Library.lua"))()
end

local ThemeManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/violin-suzutsuki/LinoriaLib/main/addons/ThemeManager.lua"))()
local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/violin-suzutsuki/LinoriaLib/main/addons/SaveManager.lua"))()

-- Load Chakra Sense
loadstring(game:HttpGet("https://raw.githubusercontent.com/MosIsOG/playground/refs/heads/main/chakra_sense.lua"))()

-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

-- Create window
local Window = Library:CreateWindow({
    Title = "Universal Hub v1.1.2c",
    Center = false,
    AutoShow = true,
    Position = UDim2.new(0.65, 0, 0.5, 0)
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

-- Remote attack spam (no targeting, just fires remote)
local RemoteAttackSpam = {
    Enabled = false,
    Delay = 0.12,
    Thread = nil
}

-- Get DataEvent for remote attack spam
local RemoteAttackDataEvent = game:GetService("ReplicatedStorage"):FindFirstChild("Events") and
    game:GetService("ReplicatedStorage").Events:FindFirstChild("DataEvent")

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

-- Remote attack spam functions
local function RemoteAttackLoop()
    while RemoteAttackSpam.Enabled do
        if RemoteAttackDataEvent then
            pcall(function()
                RemoteAttackDataEvent:FireServer("CheckMeleeHit", nil, "NormalAttack", false)
            end)
        end
        task.wait(RemoteAttackSpam.Delay)
    end
end

local function StartRemoteAttackSpam()
    if RemoteAttackSpam.Thread then
        pcall(task.cancel, RemoteAttackSpam.Thread)
    end
    RemoteAttackSpam.Thread = task.spawn(RemoteAttackLoop)
end

local function StopRemoteAttackSpam()
    RemoteAttackSpam.Enabled = false
    if RemoteAttackSpam.Thread then
        pcall(task.cancel, RemoteAttackSpam.Thread)
        RemoteAttackSpam.Thread = nil
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

-- Remote Attack Spam (independent)
local RemoteAttackGroup = Tabs.Player:AddLeftGroupbox("Remote Attack Spam")

RemoteAttackGroup:AddToggle("RemoteAttackSpamToggle", {
    Text = "Enable Remote Attack",
    Default = false,
    Callback = function(v)
        RemoteAttackSpam.Enabled = v
        if v then
            StartRemoteAttackSpam()
        else
            StopRemoteAttackSpam()
        end
    end
}):AddKeyPicker("RemoteAttackSpamKey", {
    Default = "K",
    SyncToggleState = true,
    Mode = "Toggle",
    Text = "Remote Attack Spam"
})

RemoteAttackGroup:AddSlider("RemoteAttackDelay", {
    Text = "Attack Delay",
    Default = 0.12,
    Min = 0.05,
    Max = 0.5,
    Rounding = 2,
    Suffix = "s",
    Callback = function(v) RemoteAttackSpam.Delay = v end
})

RemoteAttackGroup:AddLabel("Spams melee attack remote (CheckMeleeHit).")
RemoteAttackGroup:AddLabel("Toggle with K. No targeting required.")

-- ==================== VOID & LAVA PROTECTION ====================
local KillPartProtection = {
    Enabled = false,
    KillParts = {},
    HealthConnection = nil,
    CharacterAddedConnection = nil,
    LastHealth = 100,
    SafePosition = nil,
}

local function FindKillParts()
    local killParts = {}
    
    -- Search workspace for parts named "Void", "FakeVoid", "Lava", "FakeLava" (optimized)
    pcall(function()
        for _, obj in ipairs(workspace:GetChildren()) do
            if obj:IsA("Model") or obj:IsA("Folder") then
                for _, child in ipairs(obj:GetDescendants()) do
                    if child:IsA("BasePart") then
                        local name = child.Name
                        if name == "Void" or name == "FakeVoid" or name == "Lava" or name == "FakeLava" then
                            if not table.find(killParts, child) then
                                table.insert(killParts, child)
                            end
                        end
                    end
                end
            elseif obj:IsA("BasePart") then
                local name = obj.Name
                if name == "Void" or name == "FakeVoid" or name == "Lava" or name == "FakeLava" then
                    if not table.find(killParts, obj) then
                        table.insert(killParts, obj)
                    end
                end
            end
        end
    end)
    
    return killParts
end

local function SetupHealthProtection()
    local char = LocalPlayer.Character
    if not char then return end
    
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end
    
    KillPartProtection.LastHealth = humanoid.Health
    
    if KillPartProtection.HealthConnection then
        KillPartProtection.HealthConnection:Disconnect()
    end
    
    KillPartProtection.HealthConnection = humanoid.HealthChanged:Connect(function(newHealth)
        if not KillPartProtection.Enabled then return end
        
        local healthDrop = KillPartProtection.LastHealth - newHealth
        if healthDrop > 20 or newHealth <= 0 then
            humanoid.Health = KillPartProtection.LastHealth
            -- No teleporting - just restore health
            Library:Notify("Kill part damage prevented!", 1)
        else
            KillPartProtection.LastHealth = newHealth
        end
    end)
end

local function EnableKillPartProtection()
    KillPartProtection.KillParts = FindKillParts()
    
    local voidCount = 0
    local lavaCount = 0
    
    for _, part in ipairs(KillPartProtection.KillParts) do
        pcall(function()
            -- Rename appropriately
            if part.Name == "Void" then
                part.Name = "FakeVoid"
                voidCount = voidCount + 1
            elseif part.Name == "Lava" then
                part.Name = "FakeLava"
                lavaCount = lavaCount + 1
            end
            
            -- Make walkable but disable kill script
            part.CanCollide = true
            part.CanTouch = false
            part.CanQuery = false
        end)
    end
    
    local msg = ""
    if voidCount > 0 then msg = msg .. voidCount .. " Void" end
    if lavaCount > 0 then
        if msg ~= "" then msg = msg .. ", " end
        msg = msg .. lavaCount .. " Lava"
    end
    
    if msg ~= "" then
        Library:Notify("Protected: " .. msg .. " (now safe & walkable)", 2)
    else
        Library:Notify("No Void/Lava parts found", 2)
    end
    
    SetupHealthProtection()
    
    local char = LocalPlayer.Character
    if char then
        local root = char:FindFirstChild("HumanoidRootPart")
        if root then
            KillPartProtection.SafePosition = root.Position
        end
    end
    
    if KillPartProtection.CharacterAddedConnection then
        KillPartProtection.CharacterAddedConnection:Disconnect()
    end
    KillPartProtection.CharacterAddedConnection = LocalPlayer.CharacterAdded:Connect(function(newChar)
        if KillPartProtection.Enabled then
            task.wait(1)
            SetupHealthProtection()
        end
    end)
end

local function DisableKillPartProtection()
    if KillPartProtection.HealthConnection then
        KillPartProtection.HealthConnection:Disconnect()
        KillPartProtection.HealthConnection = nil
    end
    
    if KillPartProtection.CharacterAddedConnection then
        KillPartProtection.CharacterAddedConnection:Disconnect()
        KillPartProtection.CharacterAddedConnection = nil
    end
    
    for _, part in ipairs(KillPartProtection.KillParts) do
        pcall(function()
            if part.Name == "FakeVoid" then
                part.Name = "Void"
            elseif part.Name == "FakeLava" then
                part.Name = "Lava"
            end
            
            part.CanCollide = true
            part.CanTouch = true
            part.CanQuery = true
        end)
    end
    
    KillPartProtection.KillParts = {}
    KillPartProtection.SafePosition = nil
    Library:Notify("Protection OFF - Void & Lava are deadly again", 2)
end

local KillPartGroup = Tabs.Player:AddRightGroupbox("Void & Lava Protection")

KillPartGroup:AddToggle("KillPartProtectionToggle", {
    Text = "Enable Void & Lava Protection",
    Default = false,
    Callback = function(v)
        KillPartProtection.Enabled = v
        if v then
            EnableKillPartProtection()
        else
            DisableKillPartProtection()
        end
    end
}):AddKeyPicker("KillPartProtectionKey", {
    Default = "V",
    SyncToggleState = true,
    Mode = "Toggle",
    Text = "Void/Lava Protection",
})

KillPartGroup:AddButton({
    Text = "Set Safe Position",
    Func = function()
        local char = LocalPlayer.Character
        if char then
            local root = char:FindFirstChild("HumanoidRootPart")
            if root then
                KillPartProtection.SafePosition = root.Position
                Library:Notify("Safe position set at current location", 2)
            end
        end
    end,
    Tooltip = "Sets current position as safe zone for teleport"
})

KillPartGroup:AddLabel("Makes Void & Lava safe walkable surfaces.")
KillPartGroup:AddLabel("Renames: Void→FakeVoid, Lava→FakeLava")
KillPartGroup:AddLabel("Health backup: restores HP on damage.")

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
:AddKeyPicker("InfiniteJumpKey", {
    Default = ".",
    SyncToggleState = true,
    Mode = "Toggle",
    Text = "Infinite Jump",
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

-- ==================== FLY SCRIPT (FIXED) ====================
local FlySystem = {
    Enabled = false,
    Speed = 50,
    Connection = nil,
    Keys = {W = false, A = false, S = false, D = false, Space = false, Shift = false}
}

-- Track key presses
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.W then FlySystem.Keys.W = true end
    if input.KeyCode == Enum.KeyCode.A then FlySystem.Keys.A = true end
    if input.KeyCode == Enum.KeyCode.S then FlySystem.Keys.S = true end
    if input.KeyCode == Enum.KeyCode.D then FlySystem.Keys.D = true end
    if input.KeyCode == Enum.KeyCode.Space then FlySystem.Keys.Space = true end
    if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
        FlySystem.Keys.Shift = true
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.KeyCode == Enum.KeyCode.W then FlySystem.Keys.W = false end
    if input.KeyCode == Enum.KeyCode.A then FlySystem.Keys.A = false end
    if input.KeyCode == Enum.KeyCode.S then FlySystem.Keys.S = false end
    if input.KeyCode == Enum.KeyCode.D then FlySystem.Keys.D = false end
    if input.KeyCode == Enum.KeyCode.Space then FlySystem.Keys.Space = false end
    if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
        FlySystem.Keys.Shift = false
    end
end)

local function StartFlying()
    local char = LocalPlayer.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return end
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end
    
    -- Set humanoid to Physics state for smooth flying
    humanoid:SetStateEnabled(Enum.HumanoidStateType.Climbing, false)
    humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
    humanoid:SetStateEnabled(Enum.HumanoidStateType.Flying, false)
    humanoid:SetStateEnabled(Enum.HumanoidStateType.Freefall, false)
    humanoid:SetStateEnabled(Enum.HumanoidStateType.GettingUp, false)
    humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
    humanoid:SetStateEnabled(Enum.HumanoidStateType.Landed, false)
    humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
    humanoid:SetStateEnabled(Enum.HumanoidStateType.Running, false)
    humanoid:SetStateEnabled(Enum.HumanoidStateType.Seated, false)
    humanoid:SetStateEnabled(Enum.HumanoidStateType.Swimming, false)
    humanoid:ChangeState(Enum.HumanoidStateType.Physics)
    
    -- Update loop using CFrame manipulation
    if FlySystem.Connection then
        FlySystem.Connection:Disconnect()
    end
    
    FlySystem.Connection = RunService.Heartbeat:Connect(function(deltaTime)
        if not FlySystem.Enabled then return end
        
        local char = LocalPlayer.Character
        if not char or not char:FindFirstChild("HumanoidRootPart") then return end
        local root = char.HumanoidRootPart
        local humanoid = char:FindFirstChildOfClass("Humanoid")
        if not humanoid then return end
        
        -- Keep humanoid in Physics state
        if humanoid:GetState() ~= Enum.HumanoidStateType.Physics then
            humanoid:ChangeState(Enum.HumanoidStateType.Physics)
        end
        
        local camera = workspace.CurrentCamera
        local speed = FlySystem.Speed * deltaTime
        local moveVector = Vector3.new(0, 0, 0)
        
        -- Calculate movement direction based on camera
        if FlySystem.Keys.W then
            moveVector = moveVector + (camera.CFrame.LookVector * speed)
        end
        if FlySystem.Keys.S then
            moveVector = moveVector - (camera.CFrame.LookVector * speed)
        end
        if FlySystem.Keys.A then
            moveVector = moveVector - (camera.CFrame.RightVector * speed)
        end
        if FlySystem.Keys.D then
            moveVector = moveVector + (camera.CFrame.RightVector * speed)
        end
        if FlySystem.Keys.Space then
            moveVector = moveVector + Vector3.new(0, speed, 0)
        end
        if FlySystem.Keys.Shift then
            moveVector = moveVector - Vector3.new(0, speed, 0)
        end
        
        -- Apply movement
        root.CFrame = root.CFrame + moveVector
        root.Velocity = Vector3.new(0, 0, 0)
        root.RotVelocity = Vector3.new(0, 0, 0)
    end)
    
    Library:Notify("Flying enabled! Use WASD + Space/Shift", 2)
end

local function StopFlying()
    if FlySystem.Connection then
        FlySystem.Connection:Disconnect()
        FlySystem.Connection = nil
    end
    
    local char = LocalPlayer.Character
    if char then
        local humanoid = char:FindFirstChildOfClass("Humanoid")
        if humanoid then
            -- Re-enable normal states
            humanoid:SetStateEnabled(Enum.HumanoidStateType.Climbing, true)
            humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true)
            humanoid:SetStateEnabled(Enum.HumanoidStateType.Flying, true)
            humanoid:SetStateEnabled(Enum.HumanoidStateType.Freefall, true)
            humanoid:SetStateEnabled(Enum.HumanoidStateType.GettingUp, true)
            humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
            humanoid:SetStateEnabled(Enum.HumanoidStateType.Landed, true)
            humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, true)
            humanoid:SetStateEnabled(Enum.HumanoidStateType.Running, true)
            humanoid:SetStateEnabled(Enum.HumanoidStateType.Seated, true)
            humanoid:SetStateEnabled(Enum.HumanoidStateType.Swimming, true)
            humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
        end
    end
    
    Library:Notify("Flying disabled", 2)
end

-- Handle character respawn
LocalPlayer.CharacterAdded:Connect(function()
    if FlySystem.Enabled then
        task.wait(0.5)
        StartFlying()
    end
end)

MovementGroup:AddToggle("FlyToggle", {
    Text = "Fly",
    Default = false,
    Callback = function(value)
        FlySystem.Enabled = value
        if value then
            StartFlying()
        else
            StopFlying()
        end
    end
}):AddKeyPicker("FlyKey", {
    Default = "Y",
    SyncToggleState = true,
    Mode = "Toggle",
    Text = "Fly",
})

MovementGroup:AddSlider("FlySpeed", {
    Text = "Fly Speed",
    Default = 50,
    Min = 10,
    Max = 300,
    Rounding = 0,
    Suffix = " speed",
    Callback = function(v) FlySystem.Speed = v end
})

MovementGroup:AddLabel("WASD to move, Space/Shift for up/down.")

-- Misc Tab
local MiscGroup = Tabs.Misc:AddLeftGroupbox("Misc")

-- ==================== AUTOFARM ====================
local AutoFarmTab = Window:AddTab("AutoFarm")

-- Global default max distance (studs) for auto detection
local DEFAULT_MAX_DISTANCE = 500

-- Predefined boss list - scans folders and workspace by name
local PredefinedBosses = {
    { name = "Wooden Golem", maxDistance = 500 },
    { name = "Manda", maxDistance = 500, allowDuplicates = true },
    { name = "Chakra Knight", maxDistance = 500 },
    { name = "The Barbarian", maxDistance = 500, allowDuplicates = true },
    { name = "Barbarit The Rose", maxDistance = 500 },
    { name = "Lava Snake", maxDistance = 500 },
    { name = "Hyuga Boss", maxDistance = 500},
    { name = "Haku Boss", maxDistance = 500},
}

-- Tracked bosses: key = boss instance (Model or Humanoid), value = { bar, humanoid, maxDist, name }
local TrackedBosses = {}

-- Active bars for manual/test entries: key = path (or "test_"..path), value = { bg, fill, txt, humanoid, maxDist }
local ManualBars = {}

-- Settings
local BossDetect = {
    Enabled = true,
    ScanInterval = 30,  -- seconds (only checks every 30 seconds)
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
    local rootPart = char:FindFirstChild("HumanoidRootPart") 
                  or char:FindFirstChild("Head")
                  or char:FindFirstChild("Torso")
                  or char:FindFirstChild("UpperTorso")
                  or char:FindFirstChildWhichIsA("BasePart")
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

    local rootPart = humanoid.Parent:FindFirstChild("HumanoidRootPart") 
                  or humanoid.Parent:FindFirstChild("Head")
                  or humanoid.Parent:FindFirstChild("Torso")
                  or humanoid.Parent:FindFirstChild("UpperTorso")
                  or humanoid.Parent:FindFirstChildWhichIsA("BasePart")
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

-- Remove a tracked boss bar
local function RemoveTrackedBoss(bossInstance)
    local entry = TrackedBosses[bossInstance]
    if entry and entry.bar then
        pcall(function()
            entry.bar.bg:Remove()
            entry.bar.fill:Remove()
            entry.bar.txt:Remove()
        end)
    end
    TrackedBosses[bossInstance] = nil
end

-- Scan for predefined bosses only (called every 30 seconds)
-- Uses robust scanning like boss farm - checks folders AND workspace directly
local function ScanForPredefinedBosses()
    if not BossDetect.Enabled then return end

    local localChar = LocalPlayer.Character
    if not localChar then return end
    local localRoot = localChar:FindFirstChild("HumanoidRootPart") or localChar:FindFirstChild("Head")
    if not localRoot then return end
    local playerPos = localRoot.Position

    -- Scan specific folders AND workspace directly (like boss farm scanner)
    local foldersToCheck = {"NPCs", "Mobs", "Enemies"}
    local checkedModels = {} -- Prevent duplicates
    
    -- Check folders first
    for _, folderName in ipairs(foldersToCheck) do
        local folder = workspace:FindFirstChild(folderName)
        if folder then
            for _, model in ipairs(folder:GetChildren()) do
                if model:IsA("Model") and not checkedModels[model] then
                    checkedModels[model] = true
                    
                    -- Check if this model matches any predefined boss
                    for _, bossConfig in ipairs(PredefinedBosses) do
                        if model.Name == bossConfig.name then
                            -- Found a boss match
                            if not TrackedBosses[model] then
                                local humanoid = model:FindFirstChildOfClass("Humanoid")
                                if humanoid and humanoid.Health > 0 then
                                    local rootPart = model:FindFirstChild("HumanoidRootPart") 
                                                  or model:FindFirstChild("Head")
                                                  or model:FindFirstChild("Torso")
                                                  or model:FindFirstChild("UpperTorso")
                                                  or model:FindFirstChildWhichIsA("BasePart")
                                    if rootPart then
                                        local distance = (playerPos - rootPart.Position).Magnitude
                                        if distance <= (bossConfig.maxDistance or DEFAULT_MAX_DISTANCE) then
                                            -- New boss detected - create bar
                                            TrackedBosses[model] = {
                                                bar = CreateBarDrawing(),
                                                humanoid = humanoid,
                                                maxDist = bossConfig.maxDistance or DEFAULT_MAX_DISTANCE,
                                                name = bossConfig.name
                                            }
                                            Library:Notify("Detected: " .. bossConfig.name .. " (" .. math.floor(distance) .. " studs)", 3)
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    
    -- ALSO check workspace directly (for bosses not in folders)
    for _, model in ipairs(workspace:GetChildren()) do
        if model:IsA("Model") and not checkedModels[model] then
            checkedModels[model] = true
            
            -- Check if this model matches any predefined boss
            for _, bossConfig in ipairs(PredefinedBosses) do
                if model.Name == bossConfig.name then
                    -- Check if duplicates are allowed OR if we haven't tracked this boss yet
                    local canTrack = bossConfig.allowDuplicates or not TrackedBosses[model]
                    
                    if canTrack and not TrackedBosses[model] then
                        local humanoid = model:FindFirstChildOfClass("Humanoid")
                        if humanoid and humanoid.Health > 0 then
                            local rootPart = model:FindFirstChild("HumanoidRootPart") 
                                          or model:FindFirstChild("Head")
                                          or model:FindFirstChild("Torso")
                                          or model:FindFirstChild("UpperTorso")
                                          or model:FindFirstChildWhichIsA("BasePart")
                            if rootPart then
                                local distance = (playerPos - rootPart.Position).Magnitude
                                if distance <= (bossConfig.maxDistance or DEFAULT_MAX_DISTANCE) then
                                    -- New boss detected - create bar
                                    TrackedBosses[model] = {
                                        bar = CreateBarDrawing(),
                                        humanoid = humanoid,
                                        maxDist = bossConfig.maxDistance or DEFAULT_MAX_DISTANCE,
                                        name = bossConfig.name
                                    }
                                    Library:Notify("Detected: " .. bossConfig.name .. " (" .. math.floor(distance) .. " studs)", 3)
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    -- Remove tracked bosses that are no longer valid or dead
    for bossInstance, entry in pairs(TrackedBosses) do
        if not bossInstance.Parent or not entry.humanoid or not entry.humanoid.Parent or entry.humanoid.Health <= 0 then
            RemoveTrackedBoss(bossInstance)
        end
    end
end

-- Start the predefined boss scan loop (every 30 seconds)
local function StartBossScan()
    if BossDetect.ScanThread then
        task.cancel(BossDetect.ScanThread)
    end
    BossDetect.ScanThread = task.spawn(function()
        while BossDetect.Enabled do
            ScanForPredefinedBosses()
            task.wait(BossDetect.ScanInterval)
        end
    end)
end

-- Main render loop (throttled to reduce lag)
local BossBarUpdateThread = task.spawn(function()
    while true do
        -- Tracked predefined bosses
        for bossInstance, entry in pairs(TrackedBosses) do
            if bossInstance and bossInstance.Parent and entry.humanoid and entry.humanoid.Parent then
                UpdateBar(entry.bar, entry.humanoid, entry.maxDist)
            else
                RemoveTrackedBoss(bossInstance)
            end
        end
        
        task.wait(0.067) -- Update ~15 times per second instead of 60
    end
end)

-- ===== UI =====
-- Boss detection settings
local BossGroup = AutoFarmTab:AddLeftGroupbox("Predefined Boss Detection")
BossGroup:AddToggle("BossDetectToggle", {
    Text = "Enable Boss Detection",
    Default = true,
    Callback = function(v)
        BossDetect.Enabled = v
        if v then
            StartBossScan()
        else
            -- Clear all tracked bosses
            for bossInstance, _ in pairs(TrackedBosses) do
                RemoveTrackedBoss(bossInstance)
            end
            if BossDetect.ScanThread then
                task.cancel(BossDetect.ScanThread)
                BossDetect.ScanThread = nil
            end
        end
    end
})
BossGroup:AddSlider("BossScanInterval", {
    Text = "Scan Interval",
    Default = 30,
    Min = 10,
    Max = 120,
    Rounding = 0,
    Suffix = "s",
    Callback = function(v) BossDetect.ScanInterval = v end,
    Tooltip = "How often to check for predefined bosses."
})
BossGroup:AddLabel("Scans for predefined bosses every 30s.")
BossGroup:AddLabel("Checks NPCs/Mobs/Enemies folders + workspace.")
BossGroup:AddLabel("Bosses: Wooden Golem, Manda, Chakra Knight,")
BossGroup:AddLabel("The Barbarian, Barbarit The Rose, Lava Snake")
BossGroup:AddLabel("Boss bars update at 15 FPS (optimized).")
BossGroup:AddLabel("Auto-detects bosses by name anywhere in game.")

-- Start scanning on load
if BossDetect.Enabled then
    StartBossScan()
end

-- ==================== BOSS FARM (ANCHOR + M1 SPAM) ====================
local BossFarm = {
    Enabled = false,
    Target = nil,           -- the Humanoid we're farming
    TargetName = "",        -- display name of the boss model
    SelectedBoss = "Wooden Golem", -- currently selected boss name
    HeightOffset = 50,      -- studs above the boss root
    AttackDelay = 0.12,     -- seconds between remote fire calls
    Thread = nil,
    AnchorConn = nil,
    HyugaHeightBoost = 0,   -- additional height for Hyuga Boss special animations
    HyugaAnimConnection = nil, -- connection to monitor Hyuga Boss animations
    LavaSnakeHeightBoost = 0,   -- additional height for Lava Snake special animation
    LavaSnakeAnimConnection = nil, -- connection to monitor Lava Snake animations
    HakuAnimConnection = nil, -- connection to monitor Haku Boss IceDragonHead/Beam
    HakuSafeSpot = false,   -- whether to teleport to safe spot
    HakuSafeSpotEndTime = 0, -- when to end safe spot (tick())
}

local BossFarmGroup = AutoFarmTab:AddLeftGroupbox("Boss Farm")

-- Scan for nearby bosses and return a list (OPTIMIZED)
local function ScanBossFarmTargets()
    local results = {}
    local localChar = LocalPlayer.Character
    if not localChar then return results end
    local localRoot = localChar:FindFirstChild("HumanoidRootPart") or localChar:FindFirstChild("Head")
    if not localRoot then return results end
    local playerPos = localRoot.Position

    -- Check specific folders AND workspace itself
    local foldersToCheck = {"NPCs", "Mobs", "Enemies"}
    
    for _, folderName in ipairs(foldersToCheck) do
        local folder = workspace:FindFirstChild(folderName)
        if folder then
            for _, model in ipairs(folder:GetChildren()) do
                if model:IsA("Model") then
                    local hum = model:FindFirstChildWhichIsA("Humanoid")
                    if hum and hum.Health > 0 and hum.MaxHealth >= BossFarm.MinHealth then
                        local root = model:FindFirstChild("HumanoidRootPart") 
                                  or model:FindFirstChild("Head")
                                  or model:FindFirstChild("Torso")
                                  or model:FindFirstChild("UpperTorso")
                                  or model:FindFirstChildWhichIsA("BasePart")
                        if root then
                            local dist = (playerPos - root.Position).Magnitude
                            if dist <= BossFarm.ScanRange then
                                table.insert(results, {
                                    humanoid = hum,
                                    name = model.Name,
                                    distance = math.floor(dist)
                                })
                            end
                        end
                    end
                end
            end
        end
    end
    
    -- ALSO check workspace directly (for bosses not in folders)
    for _, model in ipairs(workspace:GetChildren()) do
        if model:IsA("Model") then
            local hum = model:FindFirstChildWhichIsA("Humanoid")
            if hum and hum.Health > 0 and hum.MaxHealth >= BossFarm.MinHealth then
                local root = model:FindFirstChild("HumanoidRootPart") 
                          or model:FindFirstChild("Head")
                          or model:FindFirstChild("Torso")
                          or model:FindFirstChild("UpperTorso")
                          or model:FindFirstChildWhichIsA("BasePart")
                if root then
                    local dist = (playerPos - root.Position).Magnitude
                    if dist <= BossFarm.ScanRange then
                        table.insert(results, {
                            humanoid = hum,
                            name = model.Name,
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
    local bossRoot = hum.Parent:FindFirstChild("HumanoidRootPart") 
                  or hum.Parent:FindFirstChild("Head")
                  or hum.Parent:FindFirstChild("Torso")
                  or hum.Parent:FindFirstChild("UpperTorso")
                  or hum.Parent:FindFirstChildWhichIsA("BasePart")
    if not bossRoot then return end
    pcall(function()
        BossFarmDataEvent:FireServer("Dash", "Sub", bossRoot.Position)
    end)
end

-- Check if Haku Boss is near any mirror (within 2 studs average distance)
local function CheckHakuMirrorProximity(bossPosition)
    local mirrorRealm = workspace:FindFirstChild("Mirror Realm")
    if not mirrorRealm then return false end
    
    local mirrorsFolder = mirrorRealm:FindFirstChild("Mirrors")
    if not mirrorsFolder then return false end
    
    local mirrors = mirrorsFolder:GetChildren()
    
    for _, mirror in ipairs(mirrors) do
        -- Get mirror position (handle Models or BaseParts)
        local mirrorPos
        if mirror:IsA("BasePart") then
            mirrorPos = mirror.Position
        elseif mirror:IsA("Model") then
            local primaryPart = mirror.PrimaryPart or mirror:FindFirstChildWhichIsA("BasePart")
            if primaryPart then
                mirrorPos = primaryPart.Position
            end
        end
        
        if mirrorPos then
            -- Calculate average absolute difference
            local avgDiff = (math.abs(bossPosition.X - mirrorPos.X) + 
                             math.abs(bossPosition.Y - mirrorPos.Y) + 
                             math.abs(bossPosition.Z - mirrorPos.Z)) / 3
            
            -- If within 2 studs, boss is in/near this mirror
            if avgDiff <= 2 then
                return true
            end
        end
    end
    
    return false
end

-- Monitor Haku Boss for special animations that require height adjustment
-- Monitor Haku Boss for IceDragonHead object spawning
local function MonitorHakuBossIceDragon()
    if BossFarm.HakuAnimConnection then
        BossFarm.HakuAnimConnection:Disconnect()
        BossFarm.HakuAnimConnection = nil
    end
    
    -- Get or create Debris folder reference
    local debris = workspace:FindFirstChild("Debris")
    if not debris then
        -- Wait for Debris folder to be created
        local debrisCreatedConn
        debrisCreatedConn = workspace.ChildAdded:Connect(function(child)
            if child.Name == "Debris" then
                debris = child
                debrisCreatedConn:Disconnect()
                -- Start monitoring after Debris is found
                MonitorHakuBossIceDragon()
            end
        end)
        return
    end
    
    -- Monitor for IceDragonHead and Beam121 spawning
    BossFarm.HakuAnimConnection = debris.ChildAdded:Connect(function(child)
        if not BossFarm.Enabled then return end
        
        local shouldTeleport = false
        local detectionMsg = ""
        local safeSpotDuration = 1  -- default 1 second
        
        -- Check for IceDragonHead (could be Model or Part)
        if child.Name == "IceDragonHead" or (child:IsA("Model") and child.Name == "IceDragonHead") then
            shouldTeleport = true
            safeSpotDuration = 4  -- 4 seconds for IceDragonHead
            detectionMsg = "Haku IceDragonHead detected! Teleported to safe spot (4s)"
            print("[DEBUG] IceDragonHead detected! Type:", child.ClassName)
        -- Check for Beam121
        elseif child:IsA("Beam") and child.Name == "Beam121" then
            shouldTeleport = true
            safeSpotDuration = 1  -- 1 second for Beam
            detectionMsg = "Haku Beam121 detected! Teleported to safe spot (1s)"
            print("[DEBUG] Beam121 detected!")
        end
        
        if shouldTeleport then
            -- Teleport to safe position
            local char = LocalPlayer.Character
            if char and char:FindFirstChild("HumanoidRootPart") then
                char.HumanoidRootPart.CFrame = CFrame.new(-2969.2, 1832.9, -9610.4)
                BossFarm.HakuSafeSpot = true
                BossFarm.HakuSafeSpotEndTime = tick() + safeSpotDuration
                Library:Notify(detectionMsg, 1)
                print("[DEBUG] Teleported to safe spot, timer set to:", BossFarm.HakuSafeSpotEndTime, "Duration:", safeSpotDuration)
            end
        else
            -- Debug: print what objects are spawning in Debris
            print("[DEBUG] Debris child added:", child.Name, "Type:", child.ClassName)
        end
    end)
end

-- Monitor Hyuga Boss for special animations that require height adjustment
local function MonitorHyugaBossAnimations(bossModel)
    if BossFarm.HyugaAnimConnection then
        BossFarm.HyugaAnimConnection:Disconnect()
        BossFarm.HyugaAnimConnection = nil
    end
    
    if not bossModel then return end
    
    local humanoid = bossModel:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end
    local animator = humanoid:FindFirstChildOfClass("Animator")
    if not animator then return end
    
    BossFarm.HyugaAnimConnection = animator.AnimationPlayed:Connect(function(track)
        if not BossFarm.Enabled then return end
        
        local animId = track.Animation.AnimationId
        local assetId = animId:match("rbxassetid://(%d+)") or animId
        
        -- Hyuga Boss special animations: 64 Palms and Rotation
        local hyugaDangerousAnims = {
            "8699113073", -- 64 palms
            "8580099842"  -- Rotation
        }
        
        for _, dangerAnimID in ipairs(hyugaDangerousAnims) do
            if assetId == dangerAnimID then
                -- Increase height by 20 studs
                BossFarm.HyugaHeightBoost = 20
                Library:Notify("Hyuga Attack! Height +20", 1)
                
                -- Monitor the track to reset height when animation stops
                local resetThread
                resetThread = task.spawn(function()
                    while track and track.IsPlaying and BossFarm.Enabled do
                        task.wait(0.1)
                    end
                    -- Animation ended, reset boost
                    task.wait(0.5) -- Small grace period
                    BossFarm.HyugaHeightBoost = 0
                end)
                
                return
            end
        end
    end)
end

-- Monitor Lava Snake animations
local function MonitorLavaSnakeAnimations(bossModel)
    -- Disconnect previous connection if any
    if BossFarm.LavaSnakeAnimConnection then
        BossFarm.LavaSnakeAnimConnection:Disconnect()
        BossFarm.LavaSnakeAnimConnection = nil
    end
    
    if not bossModel then return end
    
    local humanoid = bossModel:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end
    local animator = humanoid:FindFirstChildOfClass("Animator")
    if not animator then return end
    
    BossFarm.LavaSnakeAnimConnection = animator.AnimationPlayed:Connect(function(track)
        if not BossFarm.Enabled then return end
        
        local animId = track.Animation.AnimationId
        local assetId = animId:match("rbxassetid://(%d+)") or animId
        
        -- Lava Snake special animation: makes player go 10 studs up
        if assetId == "9954909571" then
            -- Increase height by 10 studs
            BossFarm.LavaSnakeHeightBoost = 10
            Library:Notify("Lava Snake Attack! Height +10", 1)
            
            -- Monitor the track to reset height when animation stops
            local resetThread
            resetThread = task.spawn(function()
                while track and track.IsPlaying and BossFarm.Enabled do
                    task.wait(0.1)
                end
                -- Animation ended, reset boost
                task.wait(0.5) -- Small grace period
                BossFarm.LavaSnakeHeightBoost = 0
            end)
            
            return
        end
    end)
end

-- Boss configurations
local BossConfigs = {
    ["Wooden Golem"] = { height = 16 },
    ["Hyuga Boss"] = { height = 8 },
    ["Lava Snake"] = { height = 38 },
    ["Haku Boss"] = { height = 8 },
    ["Barbarit The Rose"] = { height = 12 },
    ["Manda"] = { height = 38 },
}

-- Find boss in workspace
local function FindBoss(bossName)
    local foldersToCheck = {"NPCs", "Mobs", "Enemies", workspace}
    
    for _, folder in ipairs(foldersToCheck) do
        local searchFolder = folder == workspace and folder or workspace:FindFirstChild(folder)
        if searchFolder then
            for _, model in ipairs(searchFolder:GetChildren()) do
                if model:IsA("Model") and model.Name == bossName then
                    local hum = model:FindFirstChildOfClass("Humanoid")
                    if hum and hum.Health > 0 then
                        return hum, model
                    end
                end
            end
        end
    end
    return nil, nil
end

-- Monitor Haku Boss for IceDragonHead and Beam
-- Start boss farm
local function StartBossFarm()
    if BossFarm.AnchorConn then
        BossFarm.AnchorConn:Disconnect()
    end
    if BossFarm.Thread then
        pcall(task.cancel, BossFarm.Thread)
    end
    
    local bossName = BossFarm.SelectedBoss
    local config = BossConfigs[bossName]
    
    -- Find selected boss
    local humanoid, model = FindBoss(bossName)
    
    if not humanoid or not model then
        Library:Notify("⚠️ " .. bossName .. " is not spawned yet!", 3)
        BossFarm.Enabled = false
        return
    end
    
    BossFarm.Target = humanoid
    BossFarm.TargetName = model.Name
    
    -- Set boss config
    if config then
        BossFarm.HeightOffset = config.height
    end
    
    -- If farming Hyuga Boss, monitor for special animations
    if BossFarm.TargetName == "Hyuga Boss" then
        MonitorHyugaBossAnimations(BossFarm.Target.Parent)
    end
    
    -- If farming Lava Snake, monitor for special animation
    if BossFarm.TargetName == "Lava Snake" then
        MonitorLavaSnakeAnimations(BossFarm.Target.Parent)
    end
    
    -- If farming Haku Boss, monitor for IceDragonHead spawning
    if BossFarm.TargetName == "Haku Boss" then
        MonitorHakuBossIceDragon()
    end

    Library:Notify("Farming: " .. BossFarm.TargetName, 3)

    -- Anchor: every frame, teleport on top of boss
    BossFarm.AnchorConn = RunService.Heartbeat:Connect(function()
        local success, err = pcall(function()
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

            local bossRoot = hum.Parent:FindFirstChild("HumanoidRootPart") 
                          or hum.Parent:FindFirstChild("Head")
                          or hum.Parent:FindFirstChild("Torso")
                          or hum.Parent:FindFirstChild("UpperTorso")
                          or hum.Parent:FindFirstChildWhichIsA("BasePart")
            
            if not bossRoot then 
                print("[BOSS FARM] No root part found for", BossFarm.TargetName)
                return 
            end

            local char = LocalPlayer.Character
            if not char then return end
            local root = char:FindFirstChild("HumanoidRootPart")
            if not root then return end

            -- Check if safe spot timer expired
            if BossFarm.HakuSafeSpot and tick() >= BossFarm.HakuSafeSpotEndTime then
                BossFarm.HakuSafeSpot = false
            end

            -- Position based on safe spot status
            if BossFarm.HakuSafeSpot then
                -- Anchor at safe spot position
                root.CFrame = CFrame.new(-2969.2, 1832.9, -9610.4)
            else
                -- Position above the boss, facing down at it
                -- Add extra height boost during special animations (Hyuga Boss, Lava Snake)
                local effectiveHeight = BossFarm.HeightOffset + BossFarm.HyugaHeightBoost + BossFarm.LavaSnakeHeightBoost
                local targetPos = bossRoot.Position + Vector3.new(0, effectiveHeight, 0)
                root.CFrame = CFrame.lookAt(targetPos, bossRoot.Position)
            end
        end)
        
        if not success then
            warn("[BOSS FARM] Heartbeat error:", err)
        end
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
    BossFarm.HyugaHeightBoost = 0
    BossFarm.HakuSafeSpot = false
    BossFarm.HakuSafeSpotEndTime = 0
    
    -- Disconnect Hyuga animation monitoring
    if BossFarm.HyugaAnimConnection then
        BossFarm.HyugaAnimConnection:Disconnect()
        BossFarm.HyugaAnimConnection = nil
    end
    
    -- Disconnect Haku object monitoring
    if BossFarm.HakuAnimConnection then
        BossFarm.HakuAnimConnection:Disconnect()
        BossFarm.HakuAnimConnection = nil
    end
    
    if BossFarm.AnchorConn then
        BossFarm.AnchorConn:Disconnect()
        BossFarm.AnchorConn = nil
    end
    if BossFarm.Thread then
        pcall(task.cancel, BossFarm.Thread)
        BossFarm.Thread = nil
    end
end

BossFarmGroup:AddDropdown("BossSelector", {
    Text = "Select Boss",
    Default = 1,
    Values = {"Wooden Golem", "Hyuga Boss", "Lava Snake", "Haku Boss", "Barbarit The Rose", "Manda"},
    Callback = function(value)
        BossFarm.SelectedBoss = value
        Library:Notify("Selected: " .. value, 1)
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

BossFarmGroup:AddSlider("BossFarmAttackDelay", {
    Text = "Attack Delay",
    Default = 0.12,
    Min = 0.02,
    Max = 0.5,
    Rounding = 2,
    Suffix = "s",
    Callback = function(v) BossFarm.AttackDelay = v end
})

BossFarmGroup:AddLabel("Select boss → Toggle ON (or press G)")
BossFarmGroup:AddLabel("Each boss has custom height & behaviors")
BossFarmGroup:AddLabel("Auto-stops when boss dies")

-- ==================== AUTO EYE FARM (Sharingan/Byakugan) ====================
local AutoEye = {
    Enabled = false,
    Thread = nil,
    TargetPos = Vector3.new(-2883.2, 652.6, -5448.9),  -- teleport coordinates
    SelectedItem = "Sharingan [Stage 1]",  -- Default selection
}

-- Remote references
local DataEvent = game:GetService("ReplicatedStorage"):FindFirstChild("Events") and 
                  game:GetService("ReplicatedStorage").Events:FindFirstChild("DataEvent")
local DataFunction = game:GetService("ReplicatedStorage"):FindFirstChild("Events") and 
                     game:GetService("ReplicatedStorage").Events:FindFirstChild("DataFunction")

-- Helper to check if character has forcefield
local function isOutOfForcefield(character)
    return character and not character:FindFirstChild("ForceField")
end

local function autoEyeLoop()
    while AutoEye.Enabled do
        -- Wait for character to exist
        local char = LocalPlayer.Character
        if not char then
            char = LocalPlayer.CharacterAdded:Wait()
        end

        -- Wait for root part to exist (HumanoidRootPart or Head)
        local root = char:WaitForChild("HumanoidRootPart", 5) or char:WaitForChild("Head", 5)
        if not root then
            task.wait(0.3)
            continue
        end
        
        -- If forcefield exists, spam teleport until it's gone
        if not isOutOfForcefield(char) then
            while char and not isOutOfForcefield(char) and AutoEye.Enabled do
                if root and root.Parent then
                    root.CFrame = CFrame.new(AutoEye.TargetPos)
                end
                task.wait(0.05) -- Spam teleport every 0.05 seconds
            end
        end
        
        -- Once forcefield is gone (or if there was none), proceed with normal flow
        if root and root.Parent and isOutOfForcefield(char) then
            -- 1. Teleport
            root.CFrame = CFrame.new(AutoEye.TargetPos)
            task.wait(0.2)

            -- 2. Fire Item/Selected remote
            if DataEvent then
                pcall(function()
                    DataEvent:FireServer("Item", "Selected", AutoEye.SelectedItem)
                end)
            end
            
            task.wait(0.3)

            -- 3. Fire Awaken remote and wait for it to complete
            if DataFunction then
                local success, result = pcall(function()
                    return DataFunction:InvokeServer("Awaken", AutoEye.SelectedItem)
                end)
                if success then
                    task.wait(0.5)
                end
            end

            -- 4. Reset character
            if char and char:FindFirstChild("Humanoid") then
                char.Humanoid.Health = 0
                task.wait(0.1)
                char:BreakJoints()
            end
        else
            -- If root disappeared, just wait a bit and let the loop restart
            task.wait(0.3)
        end

        -- Small pause before next iteration to prevent flooding
        task.wait(0.2)
    end
end

local function startAutoEye()
    if AutoEye.Thread then
        task.cancel(AutoEye.Thread)
    end
    AutoEye.Thread = task.spawn(autoEyeLoop)
end

local function stopAutoEye()
    AutoEye.Enabled = false
    if AutoEye.Thread then
        task.cancel(AutoEye.Thread)
        AutoEye.Thread = nil
    end
end

-- UI in AutoFarm tab
local AutoEyeGroup = AutoFarmTab:AddRightGroupbox("AutoEye")

AutoEyeGroup:AddDropdown("EyeItemSelect", {
    Text = "Select Eye Item",
    Default = 1,
    Values = {
        "Sharingan [Stage 1]",
        "Sharingan [Stage 2]",
        "Sharingan [Stage 3]",
        "Byakugan [Stage 1]",
        "Byakugan [Stage 2]",
        "Byakugan [Stage 3]",
        "Byakugan [Stage 4]"
    },
    Callback = function(value)
        AutoEye.SelectedItem = value
    end
})

AutoEyeGroup:AddToggle("AutoEyeToggle", {
    Text = "Enable AutoEye Farm",
    Default = false,
    Callback = function(value)
        if value then
            AutoEye.Enabled = true
            startAutoEye()
        else
            AutoEye.Enabled = false
            stopAutoEye()
        end
    end
})

AutoEyeGroup:AddLabel("Select your eye item from dropdown above.")
AutoEyeGroup:AddLabel("If forcefield: spams teleport until gone,")
AutoEyeGroup:AddLabel("then teleports, fires events, and resets.")

-- ==================== AUTO GRIP FARM ====================
local AutoGripFarm = {
    AltEnabled = false,
    MainEnabled = false,
    AltThread = nil,
    MainThread = nil,
    TargetPos = Vector3.new(-4458.5, 660.7, -4895.2),
    LocationCheckRadius = 50,  -- studs
    PlayerDetectRadius = 20,   -- studs for Main mode
    GripWaitTime = 4,          -- seconds to wait after gripping
}

-- Get DataEvent for grip/damage remotes
local GripDataEvent = game:GetService("ReplicatedStorage"):FindFirstChild("Events") and 
                      game:GetService("ReplicatedStorage").Events:FindFirstChild("DataEvent")

-- Helper: check if character is out of forcefield
local function isGripOutOfForcefield(character)
    return character and not character:FindFirstChild("ForceField")
end

-- Helper: get distance from character to target position
local function getDistanceToTargetPos(character, targetPos)
    if not character then return nil end
    local root = character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("Head")
    if not root then return nil end
    return (root.Position - targetPos).Magnitude
end

-- Helper: check if humanoid is knocked (health <= 0 or specific state)
local function isKnocked(humanoid)
    if not humanoid then return false end
    return humanoid.Health <= 0 or humanoid:GetState() == Enum.HumanoidStateType.Dead
end

-- ALT MODE: Teleport, check location, take damage to get knocked, wait to be gripped
local function autoGripAltLoop()
    while AutoGripFarm.AltEnabled do
        local char = LocalPlayer.Character
        if not char then
            char = LocalPlayer.CharacterAdded:Wait()
        end

        local root = char:WaitForChild("HumanoidRootPart", 5) or char:WaitForChild("Head", 5)
        if not root then
            task.wait(0.3)
            continue
        end
        
        -- If forcefield exists, spam teleport until it's gone
        if not isGripOutOfForcefield(char) then
            while char and not isGripOutOfForcefield(char) and AutoGripFarm.AltEnabled do
                if root and root.Parent then
                    root.CFrame = CFrame.new(AutoGripFarm.TargetPos)
                end
                task.wait(0.05)
            end
        end
        
        -- Teleport to location
        if root and root.Parent and isGripOutOfForcefield(char) then
            root.CFrame = CFrame.new(AutoGripFarm.TargetPos)
            task.wait(0.2)
            
            -- Check if within 50 studs of target location
            local distance = getDistanceToTargetPos(char, AutoGripFarm.TargetPos)
            if distance and distance <= AutoGripFarm.LocationCheckRadius then
                -- Fire TakeDamage remote to get knocked
                if GripDataEvent then
                    pcall(function()
                        GripDataEvent:FireServer("TakeDamage", 999)
                    end)
                end
                
                -- Wait to be knocked and gripped
                task.wait(2)
                
                -- Check if knocked
                local humanoid = char:FindFirstChild("Humanoid")
                if humanoid and isKnocked(humanoid) then
                    -- Wait to be gripped (wait longer for grip to happen)
                    task.wait(5)
                    
                    -- Reset to repeat
                    if char and char:FindFirstChild("Humanoid") then
                        char.Humanoid.Health = 0
                        task.wait(0.1)
                        char:BreakJoints()
                    end
                end
            else
                -- Not in range, retry teleport
                task.wait(0.3)
            end
        else
            task.wait(0.3)
        end

        task.wait(0.2)
    end
end

-- MAIN MODE: Teleport to location, find nearby player, teleport to them, grip them
local function autoGripMainLoop()
    while AutoGripFarm.MainEnabled do
        local char = LocalPlayer.Character
        if not char then
            char = LocalPlayer.CharacterAdded:Wait()
        end

        local root = char:WaitForChild("HumanoidRootPart", 5) or char:WaitForChild("Head", 5)
        if not root then
            task.wait(0.3)
            continue
        end
        
        -- Teleport to target location
        if root and root.Parent then
            root.CFrame = CFrame.new(AutoGripFarm.TargetPos)
            task.wait(0.3)
            
            -- Find a player within 20 studs
            local targetPlayer = nil
            local shortestDist = AutoGripFarm.PlayerDetectRadius
            
            for _, player in ipairs(Players:GetPlayers()) do
                if player ~= LocalPlayer then
                    local targetChar = player.Character
                    if targetChar then
                        local targetRoot = targetChar:FindFirstChild("HumanoidRootPart") or targetChar:FindFirstChild("Head")
                        if targetRoot then
                            local dist = (root.Position - targetRoot.Position).Magnitude
                            if dist <= shortestDist then
                                shortestDist = dist
                                targetPlayer = player
                            end
                        end
                    end
                end
            end
            
            -- If found a target, teleport to them and grip
            if targetPlayer then
                local targetChar = targetPlayer.Character
                if targetChar then
                    local targetRoot = targetChar:FindFirstChild("HumanoidRootPart") or targetChar:FindFirstChild("Head")
                    if targetRoot then
                        -- Teleport to target player
                        root.CFrame = CFrame.new(targetRoot.Position)
                        task.wait(0.1)
                        
                        -- Fire grip remote
                        if GripDataEvent then
                            pcall(function()
                                GripDataEvent:FireServer("Grip")
                            end)
                        end
                        
                        -- Wait 4 seconds for grip to complete
                        task.wait(AutoGripFarm.GripWaitTime)
                    end
                end
            else
                -- No player found, wait a bit
                task.wait(1)
            end
        else
            task.wait(0.3)
        end

        task.wait(0.2)
    end
end

local function startGripAlt()
    if AutoGripFarm.AltThread then
        task.cancel(AutoGripFarm.AltThread)
    end
    AutoGripFarm.AltThread = task.spawn(autoGripAltLoop)
end

local function stopGripAlt()
    AutoGripFarm.AltEnabled = false
    if AutoGripFarm.AltThread then
        task.cancel(AutoGripFarm.AltThread)
        AutoGripFarm.AltThread = nil
    end
end

local function startGripMain()
    if AutoGripFarm.MainThread then
        task.cancel(AutoGripFarm.MainThread)
    end
    AutoGripFarm.MainThread = task.spawn(autoGripMainLoop)
end

local function stopGripMain()
    AutoGripFarm.MainEnabled = false
    if AutoGripFarm.MainThread then
        task.cancel(AutoGripFarm.MainThread)
        AutoGripFarm.MainThread = nil
    end
end

-- UI in AutoFarm tab (right side)
local AutoGripGroup = AutoFarmTab:AddRightGroupbox("Auto Grip Farm")

AutoGripGroup:AddToggle("GripAltToggle", {
    Text = "Enable Alt Mode",
    Default = false,
    Callback = function(value)
        if value then
            AutoGripFarm.AltEnabled = true
            startGripAlt()
        else
            AutoGripFarm.AltEnabled = false
            stopGripAlt()
        end
    end
})

AutoGripGroup:AddToggle("GripMainToggle", {
    Text = "Enable Main Mode",
    Default = false,
    Callback = function(value)
        if value then
            AutoGripFarm.MainEnabled = true
            startGripMain()
        else
            AutoGripFarm.MainEnabled = false
            stopGripMain()
        end
    end
})

AutoGripGroup:AddLabel("Alt: Teleport, check location (50 studs),")
AutoGripGroup:AddLabel("take 999 damage to get knocked & gripped.")
AutoGripGroup:AddLabel("Forcefield check: spams teleport until gone.")
AutoGripGroup:AddLabel("")
AutoGripGroup:AddLabel("Main: Teleport to location, find player")
AutoGripGroup:AddLabel("within 20 studs, teleport to them, grip.")
AutoGripGroup:AddLabel("Location: (-4458.5, 660.7, -4895.2)")


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
   { animID = "120758909308511", delay = 1.0, distance = 101, continuous = true },
}

-- Test rule (temporary)
local TestRule = nil

-- Runtime data
local AutoBlock = {
    Enabled = false,
    MonitoredEntities = {},  -- key = model, value = {connections}
    Triggered = {},
    ContinuousMonitors = {},
    ScanThread = nil,
}

-- Remote events
local DataFunction = game:GetService("ReplicatedStorage"):FindFirstChild("Events") and 
                    game:GetService("ReplicatedStorage").Events:FindFirstChild("DataFunction")

local function GetDistanceToEntity(model)
    local localChar = LocalPlayer.Character
    if not localChar or not model then return nil end
    local localRoot = localChar:FindFirstChild("HumanoidRootPart") or localChar:FindFirstChild("Head")
    local targetRoot = model:FindFirstChild("HumanoidRootPart") or model:FindFirstChild("Head")
    if not localRoot or not targetRoot then return nil end
    return (localRoot.Position - targetRoot.Position).Magnitude
end

local function Block()
    if not DataFunction then return end
    pcall(function()
        DataFunction:InvokeServer("Block")
    end)
end

local function Unblock()
    if not DataFunction then return end
    pcall(function()
        DataFunction:InvokeServer("EndBlock")
    end)
end

local function ScheduleBlock(entityName, delay)
    if AutoBlock.Triggered[entityName] then return end
    AutoBlock.Triggered[entityName] = true

    local function doBlock()
        if not AutoBlock.Enabled then
            AutoBlock.Triggered[entityName] = nil
            return
        end
        Block()
        task.delay(0.5, function()
            AutoBlock.Triggered[entityName] = nil
        end)
    end

    if delay <= 0.01 then
        task.spawn(doBlock)
    else
        task.delay(delay, doBlock)
    end
end

-- Continuous block: monitors a long-running animation
local function StartContinuousBlock(model, track, rule)
    local key = tostring(model) .. "_" .. rule.animID
    if AutoBlock.ContinuousMonitors[key] then return end

    local isBlocking = false
    local delayApplied = false
    local thread = task.spawn(function()
        while AutoBlock.Enabled and track and track.IsPlaying and model.Parent do
            local dist = GetDistanceToEntity(model)
            if dist and dist <= (rule.distance or 999) then
                if not isBlocking and not delayApplied then
                    delayApplied = true
                    task.wait(rule.delay or 0.1)
                    if AutoBlock.Enabled and track and track.IsPlaying then
                        local d = GetDistanceToEntity(model)
                        if d and d <= (rule.distance or 999) then
                            Block()
                            isBlocking = true
                        end
                    end
                end
            else
                if isBlocking then
                    Unblock()
                    isBlocking = false
                    delayApplied = false
                end
            end
            task.wait(0.01)
        end
        
        if isBlocking then
            Unblock()
        end
        AutoBlock.ContinuousMonitors[key] = nil
    end)

    AutoBlock.ContinuousMonitors[key] = thread
end

-- Monitor ANY entity (player or mob) for block animations
local function MonitorEntity(model)
    if AutoBlock.MonitoredEntities[model] then return end
    if model == LocalPlayer.Character then return end
    
    local humanoid = model:FindFirstChildOfClass("Humanoid")
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
                    StartContinuousBlock(model, track, rule)
                else
                    if rule.distance then
                        local dist = GetDistanceToEntity(model)
                        if not dist or dist > rule.distance then return end
                    end
                    ScheduleBlock(model.Name or "entity", rule.delay or 0.3)
                end
                return
            end
        end

        -- Check test rule
        if TestRule and assetId == TestRule.animID then
            if TestRule.continuous then
                StartContinuousBlock(model, track, TestRule)
            else
                if TestRule.distance then
                    local dist = GetDistanceToEntity(model)
                    if not dist or dist > TestRule.distance then return end
                end
                ScheduleBlock(model.Name or "entity", TestRule.delay or 0.3)
            end
        end
    end

    local conn = animator.AnimationPlayed:Connect(onAnimPlayed)
    AutoBlock.MonitoredEntities[model] = {conn}

    -- Check already playing animations
    for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
        onAnimPlayed(track)
    end
end

-- Scan for all entities to monitor (optimized distance-based filtering)
local function ScanForEntities()
    local localChar = LocalPlayer.Character
    if not localChar then return end
    local localRoot = localChar:FindFirstChild("HumanoidRootPart")
    if not localRoot then return end
    
    local playerPos = localRoot.Position
    local scanRadius = 250 -- Only scan within 250 studs
    
    -- Optimized: Check specific folders first, then workspace if needed
    local scanTargets = {
        workspace:FindFirstChild("NPCs"),
        workspace:FindFirstChild("Mobs"),
        workspace:FindFirstChild("Enemies")
    }
    
    local checkedModels = {}
    local foundDedicatedFolder = false
    
    -- Check dedicated folders first
    for _, folder in ipairs(scanTargets) do
        if folder then
            foundDedicatedFolder = true
            for _, obj in ipairs(folder:GetChildren()) do
                if obj:IsA("Model") and obj ~= localChar and not checkedModels[obj] then
                    checkedModels[obj] = true
                    
                    -- FIRST check distance BEFORE checking for Humanoid (optimization)
                    local objRoot = obj:FindFirstChild("HumanoidRootPart") or obj:FindFirstChild("Head")
                    if objRoot then
                        local distance = (playerPos - objRoot.Position).Magnitude
                        if distance <= scanRadius then
                            -- Now check if it has humanoid and isn't already monitored
                            local humanoid = obj:FindFirstChildOfClass("Humanoid")
                            if humanoid and not AutoBlock.MonitoredEntities[obj] then
                                MonitorEntity(obj)
                            end
                        end
                    end
                end
            end
        end
    end
    
    -- If no dedicated folders found, scan workspace children
    if not foundDedicatedFolder then
        for _, obj in ipairs(workspace:GetChildren()) do
            if obj:IsA("Model") and obj ~= localChar and not checkedModels[obj] then
                checkedModels[obj] = true
                
                local objRoot = obj:FindFirstChild("HumanoidRootPart") or obj:FindFirstChild("Head")
                if objRoot then
                    local distance = (playerPos - objRoot.Position).Magnitude
                    if distance <= scanRadius then
                        local humanoid = obj:FindFirstChildOfClass("Humanoid")
                        if humanoid and not AutoBlock.MonitoredEntities[obj] then
                            MonitorEntity(obj)
                        end
                    end
                end
            end
        end
    end
    
    -- Also check for player characters nearby
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local char = player.Character
            if not checkedModels[char] then
                local charRoot = char:FindFirstChild("HumanoidRootPart")
                if charRoot then
                    local distance = (playerPos - charRoot.Position).Magnitude
                    if distance <= scanRadius then
                        local humanoid = char:FindFirstChildOfClass("Humanoid")
                        if humanoid and not AutoBlock.MonitoredEntities[char] then
                            MonitorEntity(char)
                        end
                    end
                end
            end
        end
    end
    
    -- Clean up entities that are now out of range or removed
    for model, conns in pairs(AutoBlock.MonitoredEntities) do
        if not model or not model.Parent then
            -- Entity removed/destroyed
            for _, c in ipairs(conns) do 
                if typeof(c) == "RBXScriptConnection" then
                    c:Disconnect() 
                end
            end
            AutoBlock.MonitoredEntities[model] = nil
        else
            -- Check if still in range
            local dist = GetDistanceToEntity(model)
            if not dist or dist > scanRadius + 50 then -- Add 50 stud buffer to prevent flickering
                for _, c in ipairs(conns) do 
                    if typeof(c) == "RBXScriptConnection" then
                        c:Disconnect() 
                    end
                end
                AutoBlock.MonitoredEntities[model] = nil
            end
        end
    end
end

local function StartAutoBlock()
    if AutoBlock.ScanThread then pcall(task.cancel, AutoBlock.ScanThread) end
    AutoBlock.ScanThread = task.spawn(function()
        while AutoBlock.Enabled do
            ScanForEntities()
            task.wait(1) -- Scan every second
        end
    end)
end

local function StopAutoBlock()
    if AutoBlock.ScanThread then
        pcall(task.cancel, AutoBlock.ScanThread)
        AutoBlock.ScanThread = nil
    end
    for model, conns in pairs(AutoBlock.MonitoredEntities) do
        for _, c in ipairs(conns) do
            if typeof(c) == "RBXScriptConnection" then
                c:Disconnect()
            end
        end
    end
    AutoBlock.MonitoredEntities = {}
    AutoBlock.ContinuousMonitors = {}
    Unblock()
end

-- ===== UI =====
local BlockGroup = Tabs.Misc:AddLeftGroupbox("Auto Perfect Block")

BlockGroup:AddToggle("AutoBlockToggle", {
    Text = "Enable Auto Block",
    Default = false,
    Callback = function(v)
        AutoBlock.Enabled = v
        if v then
            StartAutoBlock()
        else
            StopAutoBlock()
        end
    end
})

BlockGroup:AddLabel("Blocks ANY entity (player or mob) that plays")
BlockGroup:AddLabel("a registered animation ID within distance.")
BlockGroup:AddLabel("Scans NPCs/Mobs/Players within 250 studs.")
BlockGroup:AddLabel("Optimal Distance-filtered entity scanning.")

-- ==================== TELEPORT TAB ====================
local TeleportTab = Window:AddTab("Teleports")

-- Hardcoded teleport locations (edit this table to add your own)
local TeleportLocations = {
    -- Example entries (uncomment and modify as needed)
     { Name = "Wood Boss", Pos = Vector3.new(-4708.4, 336.9, -2986.2)},
     { Name = "Sorythia Village", Pos = Vector3.new(-113.2, 50.9, -283.8)},
     { Name = "Lava Snake", Pos = Vector3.new(-547.6, -541.7, -1281.8)},
     { Name = "Biyo Bay", Pos = Vector3.new(-598.9, -178.6, -464.3)},
     { Name = "Snow Village", Pos = Vector3.new(-2916.3, -46.0, -4907.3)},
     { Name = "Snap Trainer", Pos = Vector3.new(337.2, 131.4, -1967.2)},
     { Name = "Durana", Pos = Vector3.new(1851.0, -125.5, 1065.2)},
     { Name = "Secret Spot", Pos = Vector3.new(-4458.5, 660.7, -4895.2)},
     { Name = "Hyuga Boss", Pos = Vector3.new(-693.7, -359.9, -765.7)},
     { Name = "Haku Boss", Pos = Vector3.new(-3838.2, -231.4, -9657.0)},
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

-- ==================== MISSION MARKER TELEPORTER ====================
local MissionMarkerGroup = TeleportTab:AddLeftGroupbox("Mission Markers")

local MissionMarkers = {
    FoundMarkers = {},
    StatusLabel = nil,
}

local function ScanMissionMarkers()
    MissionMarkers.FoundMarkers = {}
    
    local debris = workspace:FindFirstChild("Debris")
    if not debris then
        Library:Notify("Debris folder not found", 3)
        return
    end
    
    local missionLocations = debris:FindFirstChild("Mission Locations")
    if not missionLocations then
        Library:Notify("Mission Locations folder not found", 3)
        return
    end
    
    -- Scan all location folders (Snow, etc.) - NO DISTANCE LIMIT
    for _, locationFolder in ipairs(missionLocations:GetChildren()) do
        local spawners = locationFolder:FindFirstChild("Spawners")
        if spawners then
            -- Get all spawner children
            for i, spawner in ipairs(spawners:GetChildren()) do
                -- MUST have a "MissionMarker" child
                local missionMarker = spawner:FindFirstChild("MissionMarker")
                if missionMarker then
                    local pos = nil
                    
                    -- Try multiple methods to get position (no distance limit, find ALL markers)
                    pcall(function()
                        if missionMarker:IsA("BasePart") then
                            pos = missionMarker.Position
                        elseif missionMarker:IsA("Model") then
                            pos = missionMarker:GetPivot().Position
                        elseif missionMarker:IsA("Attachment") then
                            pos = missionMarker.WorldPosition
                        end
                    end)
                    
                    -- Fallback 1: Try any BasePart child
                    if not pos then
                        pcall(function()
                            local part = missionMarker:FindFirstChildWhichIsA("BasePart", true)
                            if part then
                                pos = part.Position
                            end
                        end)
                    end
                    
                    -- Fallback 2: Try the spawner's position
                    if not pos then
                        pcall(function()
                            if spawner:IsA("BasePart") then
                                pos = spawner.Position
                            elseif spawner:IsA("Model") then
                                pos = spawner:GetPivot().Position
                            end
                        end)
                    end
                    
                    -- Fallback 3: Try any part in the spawner
                    if not pos then
                        pcall(function()
                            local part = spawner:FindFirstChildWhichIsA("BasePart", true)
                            if part then
                                pos = part.Position
                            end
                        end)
                    end
                    
                    -- Add marker if ANY method found a position
                    if pos then
                        table.insert(MissionMarkers.FoundMarkers, {
                            name = string.format("%s #%d (%s)", locationFolder.Name, i, spawner.Name),
                            location = locationFolder.Name,
                            index = i,
                            spawner = spawner,
                            missionMarker = missionMarker,
                            pos = pos
                        })
                    end
                end
            end
        end
    end
    
    -- ALSO scan workspace directly for Models with MissionMarker child (like "The Frosty Facilitator")
    for _, model in ipairs(workspace:GetChildren()) do
        if model:IsA("Model") then
            local missionMarker = model:FindFirstChild("MissionMarker")
            if missionMarker then
                local pos = nil
                
                -- Try to get position from the model (check Torso, HumanoidRootPart, or any part)
                pcall(function()
                    local torso = model:FindFirstChild("Torso")
                    if torso and torso:IsA("BasePart") then
                        pos = torso.Position
                    end
                end)
                
                -- Fallback 1: Try HumanoidRootPart
                if not pos then
                    pcall(function()
                        local hrp = model:FindFirstChild("HumanoidRootPart")
                        if hrp and hrp:IsA("BasePart") then
                            pos = hrp.Position
                        end
                    end)
                end
                
                -- Fallback 2: Try model pivot
                if not pos then
                    pcall(function()
                        pos = model:GetPivot().Position
                    end)
                end
                
                -- Fallback 3: Try MissionMarker itself
                if not pos then
                    pcall(function()
                        if missionMarker:IsA("BasePart") then
                            pos = missionMarker.Position
                        elseif missionMarker:IsA("Model") then
                            pos = missionMarker:GetPivot().Position
                        end
                    end)
                end
                
                -- Fallback 4: Any BasePart in the model
                if not pos then
                    pcall(function()
                        local part = model:FindFirstChildWhichIsA("BasePart", true)
                        if part then
                            pos = part.Position
                        end
                    end)
                end
                
                -- Add if found
                if pos then
                    table.insert(MissionMarkers.FoundMarkers, {
                        name = string.format("Workspace: %s", model.Name),
                        location = "Workspace",
                        index = 0,
                        spawner = model,
                        missionMarker = missionMarker,
                        pos = pos
                    })
                end
            end
        end
    end
    
    if #MissionMarkers.FoundMarkers > 0 then
        MissionMarkers.StatusLabel:SetText("Found " .. #MissionMarkers.FoundMarkers .. " markers")
        Library:Notify("Found " .. #MissionMarkers.FoundMarkers .. " mission markers", 2)
        
        -- Print list to console for selection
        local msg = "Mission Markers:\n"
        for i, marker in ipairs(MissionMarkers.FoundMarkers) do
            msg = msg .. string.format("%d. %s\n", i, marker.name)
        end
        print(msg)
    else
        MissionMarkers.StatusLabel:SetText("No markers found")
        Library:Notify("No mission markers found", 3)
    end
end

MissionMarkers.StatusLabel = MissionMarkerGroup:AddLabel("Status: Not scanned")

MissionMarkerGroup:AddButton({
    Text = "Teleport to Nearest Mission",
    Func = function()
        -- Scan first
        ScanMissionMarkers()
        
        if #MissionMarkers.FoundMarkers == 0 then
            Library:Notify("No mission markers found", 3)
            return
        end
        
        local char = LocalPlayer.Character
        if not char then return end
        local root = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Head")
        if not root then return end
        
        local playerPos = root.Position
        local nearest = nil
        local minDist = math.huge
        
        -- Find nearest marker
        for _, marker in ipairs(MissionMarkers.FoundMarkers) do
            local dist = (playerPos - marker.pos).Magnitude
            if dist < minDist then
                minDist = dist
                nearest = marker
            end
        end
        
        if nearest then
            TeleportTo(nearest.pos)
            Library:Notify("Teleported to " .. nearest.name .. " (" .. math.floor(minDist) .. " studs)", 2)
        end
    end,
    Tooltip = "Auto-scan and teleport to closest mission marker"
})

MissionMarkerGroup:AddButton({
    Text = "Scan for Mission Markers",
    Func = ScanMissionMarkers,
    Tooltip = "Scans workspace.Debris['Mission Locations'] for all spawners"
})

MissionMarkerGroup:AddInput("MissionMarkerIndex", {
    Text = "Marker Index",
    Default = "1",
    Numeric = true,
    Finished = true,
    Placeholder = "e.g. 1",
    Callback = function(val)
        local idx = tonumber(val)
        if not idx or not MissionMarkers.FoundMarkers or not MissionMarkers.FoundMarkers[idx] then
            Library:Notify("Invalid index", 3)
            return
        end
        
        local marker = MissionMarkers.FoundMarkers[idx]
        TeleportTo(marker.pos)
        Library:Notify("Teleported to " .. marker.name, 2)
    end
})

MissionMarkerGroup:AddLabel("Auto-scans and TPs to nearest mission.")
MissionMarkerGroup:AddLabel("Only spawners with MissionMarker child.")

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
            -- Teleport to the point (-4 studs on Y axis)
            root.CFrame = CFrame.new(targetPos + Vector3.new(0, -4, 0))
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

-- ==================== TRINKET COLLECTOR ====================
TrinketCollector = {
    Enabled = false,
    ScanInterval = 1.5,  -- Slower to reduce lag
    PickupRadius = 100,
    Thread = nil,
    CollectedCount = 0,
}

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
    "Ring Of Remedy",
    "Ring Of Vitality",
    "Ring Of Infusion",
    "Bloodbite Ring",
    "Ring Of Beauty",
    "Ring Of Dexterity",
    "Ring Of A Helping Hand",
    "Ring Schematics",
    "Aqua Gem",
    "Flame Gem",
    "Spark Gem",
    "Black Flame Gem",
    "Ground Gem",
    "Ice Gem",
    "Wind Gem",
    "Poison Gem",
    "Extraction Spoon",
    "Scalpel",
    "Chakra Heart",
    "Scalpel",
    "Fruit Of Forgetfulness",
    "Progression Soul",
    "Memory Soul",
    "Summoning Scroll",
    "Life Up Fruit",
    "Mastery Scroll",
}

local TrinketGroup = TeleportTab:AddRightGroupbox("Trinket Collector")

local TrinketStatusLabel = TrinketGroup:AddLabel("Status: Idle (0 collected)")

local function IsTrinket(obj)
    if not obj then return false end
    for _, name in ipairs(trinketNames) do
        if obj.Name == name then
            return true
        end
    end
    return false
end

local DataEvent = game:GetService("ReplicatedStorage"):FindFirstChild("Events") and 
                  game:GetService("ReplicatedStorage").Events:FindFirstChild("DataEvent")

local function CollectTrinket(trinket)
    local char = LocalPlayer.Character
    if not char then return false end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return false end
    
    -- Check distance first - only collect if already close
    local distance = (root.Position - trinket.Position).Magnitude
    if distance > TrinketCollector.PickupRadius then
        return false
    end
    
    -- METHOD 1: Fire the remote with the trinket's ID
    if DataEvent then
        local idValue = trinket:FindFirstChild("ID")
        if idValue and idValue:IsA("NumberValue") then
            local success = pcall(function()
                DataEvent:FireServer("PickUp", idValue.Value)
            end)
            if success then
                task.wait(0.1)
                if not trinket.Parent then
                    return true
                end
            end
        end
    end
    
    -- METHOD 2: Mouse click at trinket's screen position
    local part = trinket:IsA("BasePart") and trinket or trinket:FindFirstChildWhichIsA("BasePart")
    if part then
        local screenPos, onScreen = Camera:WorldToViewportPoint(part.Position)
        if onScreen then
            pcall(function()
                VirtualInput:SendMouseButtonEvent(screenPos.X, screenPos.Y, 0, true, game, 0)
                task.wait(0.05)
                VirtualInput:SendMouseButtonEvent(screenPos.X, screenPos.Y, 0, false, game, 0)
            end)
            task.wait(0.1)
            if not trinket.Parent then
                return true
            end
        end
    end
    
    return false
end

-- Event-based trinket detection (optimized, no lag)
local TrinketSpawnConnection = nil
local TrackedTrinkets = {} -- Cache of known trinkets

local function OnTrinketSpawned(obj)
    if not TrinketCollector.Enabled then return end
    if not obj:IsA("BasePart") then return end -- Accepts Part, MeshPart, etc.
    if not IsTrinket(obj) then return end
    if TrackedTrinkets[obj] then return end
    
    TrackedTrinkets[obj] = true
    
    -- Try to collect it immediately if in range
    task.spawn(function()
        task.wait(0.1) -- Let it fully load
        if obj.Parent and TrinketCollector.Enabled then
            if CollectTrinket(obj) then
                TrinketCollector.CollectedCount = TrinketCollector.CollectedCount + 1
                TrinketStatusLabel:SetText("Status: Active (" .. TrinketCollector.CollectedCount .. " collected)")
            end
        end
        TrackedTrinkets[obj] = nil
    end)
end

local function ScanAndCollectTrinkets()
    local char = LocalPlayer.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return end
    
    local playerPos = root.Position
    local collected = 0
    
    -- Only scan nearby region, not entire workspace
    local region = Region3.new(
        playerPos - Vector3.new(TrinketCollector.PickupRadius, TrinketCollector.PickupRadius, TrinketCollector.PickupRadius),
        playerPos + Vector3.new(TrinketCollector.PickupRadius, TrinketCollector.PickupRadius, TrinketCollector.PickupRadius)
    )
    region = region:ExpandToGrid(4)
    
    -- Scan only BaseParts (Part, MeshPart, etc.) in workspace children (faster than GetDescendants)
    for _, obj in ipairs(workspace:GetChildren()) do
        if TrinketCollector.Enabled and obj:IsA("BasePart") and IsTrinket(obj) and not TrackedTrinkets[obj] then
            local distance = (playerPos - obj.Position).Magnitude
            
            if distance <= TrinketCollector.PickupRadius then
                TrackedTrinkets[obj] = true
                if CollectTrinket(obj) then
                    collected = collected + 1
                    TrinketCollector.CollectedCount = TrinketCollector.CollectedCount + 1
                end
                TrackedTrinkets[obj] = nil
            end
        end
    end
    
    if collected > 0 then
        TrinketStatusLabel:SetText("Status: Active (" .. TrinketCollector.CollectedCount .. " collected)")
    end
end

StartTrinketCollector = function()
    if TrinketCollector.Thread then
        pcall(task.cancel, TrinketCollector.Thread)
    end
    
    -- Setup event-based detection for instant pickup (optimized)
    if TrinketSpawnConnection then
        TrinketSpawnConnection:Disconnect()
    end
    TrinketSpawnConnection = workspace.DescendantAdded:Connect(OnTrinketSpawned)
    
    -- Periodic scan as backup (slower interval to reduce lag)
    TrinketCollector.Thread = task.spawn(function()
        while TrinketCollector.Enabled do
            ScanAndCollectTrinkets()
            task.wait(TrinketCollector.ScanInterval)
        end
    end)
end

StopTrinketCollector = function()
    TrinketCollector.Enabled = false
    
    if TrinketCollector.Thread then
        pcall(task.cancel, TrinketCollector.Thread)
        TrinketCollector.Thread = nil
    end
    
    if TrinketSpawnConnection then
        TrinketSpawnConnection:Disconnect()
        TrinketSpawnConnection = nil
    end
    
    TrackedTrinkets = {}
    TrinketStatusLabel:SetText("Status: Stopped (" .. TrinketCollector.CollectedCount .. " total)")
end

-- Collect boss loot after kill (defined here after trinket collector functions)
CollectBossLoot = function(bossName)
    local config = BossConfigs[bossName]
    if not config or not config.lootPath or not config.trinketCount then
        return
    end
    
    local char = LocalPlayer.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return end
    local root = char.HumanoidRootPart
    
    Library:Notify("✓ Collecting loot from " .. bossName .. "...", 2)
    
    -- Special handling for Wooden Golem (split across two folders)
    if bossName == "Wooden Golem" then
        local rewardsBase = workspace:FindFirstChild("WoodenGolemRewards")
        if not rewardsBase then
            Library:Notify("⚠️ WoodenGolemRewards not found", 2)
            return
        end
        
        local folder1 = rewardsBase:FindFirstChild("Model")
        local folder2 = rewardsBase:GetChildren()[2]
        
        -- First pass: Quick teleport to all trinket spawns (no delay)
        -- TrinketSpawn1-7 in Model
        if folder1 then
            for i = 1, 7 do
                local trinketSpawn = folder1:FindFirstChild("TrinketSpawn" .. i)
                if trinketSpawn then
                    pcall(function()
                        root.CFrame = trinketSpawn.CFrame
                    end)
                end
            end
        end
        
        -- TrinketSpawn8-14 in second folder
        if folder2 then
            for i = 8, 14 do
                local trinketSpawn = folder2:FindFirstChild("TrinketSpawn" .. i)
                if trinketSpawn then
                    pcall(function()
                        root.CFrame = trinketSpawn.CFrame
                    end)
                end
            end
        end
        
        -- Enable trinket autopickup if not already enabled
        local wasEnabled = TrinketCollector.Enabled
        if not wasEnabled then
            TrinketCollector.Enabled = true
            StartTrinketCollector()
        end
        
        -- Wait 8 seconds for loot pile to appear
        Library:Notify("⏳ Waiting 8 seconds for loot pile...", 2)
        task.wait(8)
        
        -- Second pass: Teleport with small delays for pickup
        -- TrinketSpawn1-7 in Model
        if folder1 then
            for i = 1, 7 do
                local trinketSpawn = folder1:FindFirstChild("TrinketSpawn" .. i)
                if trinketSpawn then
                    pcall(function()
                        root.CFrame = trinketSpawn.CFrame
                    end)
                    task.wait(0.2)
                end
            end
        end
        
        -- TrinketSpawn8-14 in second folder
        if folder2 then
            for i = 8, 14 do
                local trinketSpawn = folder2:FindFirstChild("TrinketSpawn" .. i)
                if trinketSpawn then
                    pcall(function()
                        root.CFrame = trinketSpawn.CFrame
                    end)
                    task.wait(0.2)
                end
            end
        end
        
        -- Restore original autopickup state
        if not wasEnabled then
            task.wait(0.5)
            StopTrinketCollector()
            TrinketCollector.Enabled = false
        end
        
        Library:Notify("✓ Loot collection complete!", 2)
        return
    end
    
    -- Standard handling for other bosses
    local pathParts = {}
    for part in config.lootPath:gmatch("[^%.]+") do
        table.insert(pathParts, part)
    end
    
    local rewardsFolder = workspace
    for _, part in ipairs(pathParts) do
        rewardsFolder = rewardsFolder:FindFirstChild(part)
        if not rewardsFolder then
            Library:Notify("⚠️ Loot folder not found: " .. part, 2)
            return
        end
    end
    
    -- First pass: Quick teleport to all trinket spawns (no delay)
    for i = 1, config.trinketCount do
        local trinketSpawn = rewardsFolder:FindFirstChild("TrinketSpawn" .. i)
        if trinketSpawn then
            pcall(function()
                root.CFrame = trinketSpawn.CFrame
            end)
        end
    end
    
    -- Enable trinket autopickup if not already enabled
    local wasEnabled = TrinketCollector.Enabled
    if not wasEnabled then
        TrinketCollector.Enabled = true
        StartTrinketCollector()
    end
    
    -- Wait 8 seconds for loot pile to appear
    Library:Notify("⏳ Waiting 8 seconds for loot pile...", 2)
    task.wait(8)
    
    -- Second pass: Teleport with small delays for pickup
    for i = 1, config.trinketCount do
        local trinketSpawn = rewardsFolder:FindFirstChild("TrinketSpawn" .. i)
        if trinketSpawn then
            pcall(function()
                root.CFrame = trinketSpawn.CFrame
            end)
            task.wait(0.2) -- Give time for autopickup to work
        end
    end
    
    -- Restore original autopickup state
    if not wasEnabled then
        task.wait(0.5)
        StopTrinketCollector()
        TrinketCollector.Enabled = false
    end
    
    Library:Notify("✓ Loot collection complete!", 2)
end

TrinketGroup:AddToggle("TrinketCollectorToggle", {
    Text = "Auto Collect Trinkets",
    Default = false,
    Callback = function(v)
        TrinketCollector.Enabled = v
        if v then
            StartTrinketCollector()
        else
            StopTrinketCollector()
        end
    end
})

TrinketGroup:AddSlider("TrinketScanInterval", {
    Text = "Scan Interval",
    Default = 1.5,
    Min = 0.5,
    Max = 5,
    Rounding = 1,
    Suffix = "s",
    Callback = function(v) TrinketCollector.ScanInterval = v end,
    Tooltip = "How often to scan (slower = less lag)"
})

TrinketGroup:AddSlider("TrinketPickupRadius", {
    Text = "Pickup Radius",
    Default = 100,
    Min = 10,
    Max = 500,
    Rounding = 0,
    Suffix = "studs",
    Callback = function(v) TrinketCollector.PickupRadius = v end,
    Tooltip = "Maximum distance to collect trinkets"
})

TrinketGroup:AddLabel("Proximity-based auto-pickup (no teleporting).")
TrinketGroup:AddLabel("Event-based detection for instant collection.")

-- Theme
local ThemeTab = Window:AddTab("Theme")
ThemeManager:SetLibrary(Library)
ThemeManager:ApplyToTab(ThemeTab)

-- SaveManager
SaveManager:SetLibrary(Library)
SaveManager:SetFolder("UniversalHub")
SaveManager:BuildConfigSection(Tabs.Settings)

-- Initialize
SaveManager:LoadAutoloadConfig()

print("=== Universal Hub Loaded ===")