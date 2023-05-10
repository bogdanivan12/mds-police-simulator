local API_NAME = script.Name;

local Client = _G;
local APIs = Client.API;
local CurrentAPI = APIs[API_NAME];
local Storage = {
    UI_ELEMENTS = {};
};

function SetupAPIs()    -- CORE
    local function GetUIElements()
        for i,v in pairs(Client.UI:GetDescendants()) do
            if v.Name == 'UI_MARKER' and v.ClassName == 'StringValue' then
                if Storage.UI_ELEMENTS[v.Value] ~= nil then
                    warn("DUPLICATE UI MARKER ID=(".. v.Value .."). OVERWRITING");
                    warn("OLD PARENT: ".. Storage.UI_ELEMENTS[v.Value]:GetFullName());
                    warn("NEW PARENT: ".. v.Parent:GetFullName()); warn();
                end
                Storage.UI_ELEMENTS[v.Value] = v.Parent;
                v:Destroy();
            end
        end
    end
    CurrentAPI.GetUI = function(UI_TAG)
        return Storage.UI_ELEMENTS[UI_TAG];
    end

    GetUIElements();
end

return function ()
    SetupAPIs();
end