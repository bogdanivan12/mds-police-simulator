local API_NAME = script.Name;

local Client = _G;
local APIs = Client.API;
local CurrentAPI = APIs[API_NAME];
local Storage = {
};

function SetupAPIs()
    CurrentAPI.TestMemory = function()
        local x = {}
        for i = 1,1000,1 do
            Client.API.GameplayAPI.GoToGameplay()
            Client.API.GameplayAPI.GoToChase(Client.API.CarApi.CreateCar())
            local mem = game:GetService('Stats').GetTotalMemoryUsageMb()/8 -- Read number of MB consumed by the game after each iteration
            x[#x + 1] = mem
        end

        -- Convertion to Python array as string
        str = '['
        for i,v in pairs(x) do
            str = str .. tostring(v)
            if i ~= #x then
                str = str .. ', '
            else
                str = str .. ']'
            end
        end
        return str -- Returning String to plot in Python
    end
end

return function()
    SetupAPIs()
end