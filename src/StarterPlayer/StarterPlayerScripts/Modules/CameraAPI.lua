local API_NAME = script.Name;

local Client = _G;
local APIs = Client.API;
local CurrentAPI = APIs[API_NAME];
local Storage = {
    CurrentScene = nil;
    Blur = nil;
    DepthOfField = nil;
};

function SetupAPIs()
    CurrentAPI.CreateScene = function(callback) -- Creates a single controller for the camera, and positions it by the output of "callback"
        if Storage.CurrentScene ~= nil then return warn("SCENE ALREADY EXISTS. DESTROY OLD ONE TO CREATE NEW ONE") end;

        local start = os.clock()    -- Will be used to know how much time has passed since scene was created
                                    -- https://create.roblox.com/docs/reference/engine/libraries/os#clock
        
        local connection = game:GetService('RunService').RenderStepped:Connect(function(t)
            local deltaTime = os.clock() - start;
            Client.Camera.CFrame = callback(deltaTime);
        end)
        local scene = {
            Connection = connection;
            Start = start;
        }
        function scene:Destroy()
            scene.Connection:Disconnect();
            scene = nil;
            Storage.CurrentScene = nil;
        end

        Storage.CurrentScene = scene;
        return scene;
    end

    Storage.ColorCorrection = Instance.new('ColorCorrectionEffect')
    Storage.ColorCorrection.Parent = Client.Camera;
    CurrentAPI.SetSaturation = function(value, t)
        t = t or 0; -- Default value in case t is nil
        game:GetService('TweenService'):Create(
            Storage.ColorCorrection,
            TweenInfo.new(t, Enum.EasingStyle.Quint, Enum.EasingDirection.Out, 0, false, 0),
            {Saturation = value}
        ):Play();
    end
    CurrentAPI.SetBrightness = function(value, t)
        t = t or 0; -- Default value in case t is nil
        game:GetService('TweenService'):Create(
            Storage.ColorCorrection,
            TweenInfo.new(t, Enum.EasingStyle.Quint, Enum.EasingDirection.Out, 0, false, 0),
            {Brightness = value}
        ):Play();
    end

    Storage.Blur = Instance.new('BlurEffect');
    Storage.Blur.Parent = Client.Camera;
    Storage.Blur.Size = 0;
    CurrentAPI.SetBlur = function(value, t)
        t = t or 0; -- Default value in case t is nil
        game:GetService('TweenService'):Create(
            Storage.Blur, 
            TweenInfo.new(t, Enum.EasingStyle.Quint, Enum.EasingDirection.Out, 0, false, 0),
            {Size = value * 56}
        ):Play();
    end

    Storage.DepthOfField = Instance.new('DepthOfFieldEffect');
    Storage.DepthOfField.Parent = Client.Camera;
    Storage.DepthOfField.FarIntensity = 0.5;
    Storage.DepthOfField.FocusDistance = 0;
    Storage.DepthOfField.InFocusRadius = 50;
    Storage.DepthOfField.NearIntensity = 0.5;
    CurrentAPI.SetDepthOfField = function(value, t)
        t = t or 0; -- Default value in case t is nil
        game:GetService('TweenService'):Create(
            Storage.DepthOfField, 
            TweenInfo.new(t, Enum.EasingStyle.Quint, Enum.EasingDirection.Out, 0, false, 0),
            {FocusDistance = value}
        ):Play();
    end

    CurrentAPI.SetFOV = function(value, t)
        t = t or 0; -- Default value in case t is nil
        game:GetService('TweenService'):Create(
            Client.Camera, 
            TweenInfo.new(t, Enum.EasingStyle.Quint, Enum.EasingDirection.Out, 0, false, 0),
            {FieldOfView = value}
        ):Play();
    end
end

return function ()
    SetupAPIs();
end