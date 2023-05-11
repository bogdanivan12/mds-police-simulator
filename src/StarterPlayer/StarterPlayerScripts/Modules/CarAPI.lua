local API_NAME = script.Name;

local Client = _G;
local APIs = Client.API;
local CurrentAPI = APIs[API_NAME];
local Storage = {
};

function SetupAPIs()
    CurrentAPI.CreateCar = function()   -- Creates a random car from the asset pack and recolors it
        local assets = Client.Assets.Cars:GetChildren();
        local car = assets[math.random(1, #assets)]:Clone();
        local color = BrickColor.random();
        for i,v in pairs(car:GetDescendants()) do
            if v.Name == '_PAINT_' and v.ClassName == 'BoolValue' and v.Value == true then
                v.Parent.BrickColor = color;
            end
        end
        return car;
    end
end

return function ()
    SetupAPIs();
end