
local Client = _G;                                      -- Global table https://create.roblox.com/docs/reference/engine/globals/LuaGlobals#_G
Client.Player = game.Players.LocalPlayer;               -- Player Object
Client.Camera = game.Workspace.CurrentCamera;           -- Camera
Client.Mouse = Client.Player:GetMouse();                -- Mouse
Client.UI = game.StarterGui:WaitForChild('UI');         -- Interface
Client.UI.Parent = Client.Player.PlayerGui;                 -- Reparenting, Players.CharacterAutoloads = false, UI won't load by itself
Client.API = {};                                        -- Container of function overloads

local loadOrder = { -- Loading each module one by one
    'UIAPI',        -- Must be first    UI Controller
    'CameraAPI',    -- Unknown          Camera Controller
    'GameplayAPI'   -- Should be last   Gameplay Controller (Starts the game)
}

function StartUp()  -- int main()
    local moduleList = script.Parent:WaitForChild('Modules'):GetChildren();
    for i,v in pairs(loadOrder) do  -- Loading Module X and letting it overload functions in API[X]. Helpful for code scaling
        local module = script.Parent.Modules:FindFirstChild(v);
        if module then
            Client.API[v] = {};
            print("LOADING MODULE ("..v..")");
            require(module)();
            print("MODULE ("..v..") LOADED");
        else
            warn("NO SUCH MODULE AS: ".. v.." (typo?)");
        end
        for i, elem in pairs(moduleList) do
            if elem.Name == v then
                table.remove(moduleList, i);
            end
        end
    end
    for i,v in pairs(moduleList) do
        warn("MODULE ("..v:GetFullName()..") WAS NOT IN THE LOAD LIST");
    end
end

StartUp();  -- Call of int main()