local API_NAME = script.Name;

local Client = _G;
local APIs = Client.API;
local CurrentAPI = APIs[API_NAME];
local Storage = {
    CurrentDestructor = nil;
};

function SetupAPIs()
    CurrentAPI.DestroyCurrentGameplay = function()
        if Storage.CurrentDestructor then
            Storage.CurrentDestructor();
            Storage.CurrentDestructor = nil;
        end
    end
    CurrentAPI.GoToIntro = function()
        CurrentAPI.DestroyCurrentGameplay();
        APIs.UIAPI.GetUI('IntroFrame').Visible = true;

        local rotSpeed = 10; -- Degrees/Second
        local zDist = 40;
        local scene = APIs.CameraAPI.CreateScene(function(t)
            return game.Workspace.IntroScene.CameraOffset.CFrame
                        * CFrame.Angles(0, math.rad(rotSpeed) * t, 0)
                        * CFrame.Angles(math.rad(-15), 0, 0)
                        * CFrame.new(0, 5, zDist);
        end)
        APIs.CameraAPI.SetDepthOfField(zDist);

        local buttonConnection = APIs.UIAPI.GetUI('IntroButtons').Play.Activated:Connect(function()
            CurrentAPI.GoToGameplay();
        end)

        Storage.CurrentDestructor = function()
            APIs.UIAPI.GetUI('IntroFrame').Visible = false;
            buttonConnection:Disconnect();
            scene:Destroy();
        end
    end

    CurrentAPI.GoToGameplay = function()
        CurrentAPI.DestroyCurrentGameplay();
        APIs.UIAPI.GetUI('GameplayFrame').Visible = true;

        local uis = game:GetService('UserInputService');
        local anglesLimit = Vector2.new(10, 15);
        local mouseSensitivity = 0.1;
        local currentAngles = Vector2.new(0, 0);

        local zoomLimit = 5;
        local zoomValue = 1;
        local zoomSensitivity = 0.3;
        local scene = APIs.CameraAPI.CreateScene(function(t)
            local cf = game.Workspace.Gameplay.CameraOffset.CFrame
                        * CFrame.Angles(0, math.rad(currentAngles.Y), 0)
                        * CFrame.Angles(math.rad(currentAngles.X), 0, 0)
            
            local raycastParams = RaycastParams.new();
            raycastParams.FilterDescendantsInstances = {game.Workspace.Gameplay.CameraOffset};
            raycastParams.FilterType = Enum.RaycastFilterType.Exclude;
            raycastParams.IgnoreWater = true;
            local raycastDistance = 10000;
            local raycastResult = workspace:Raycast(cf.Position, cf.LookVector*raycastDistance);  -- https://create.roblox.com/docs/mechanics/raycasting
            if raycastResult then
                raycastDistance = (cf.Position - raycastResult.Position).Magnitude;
            end
            APIs.CameraAPI.SetDepthOfField(raycastDistance, 1);
            return cf;
        end)

        uis.MouseBehavior = Enum.MouseBehavior.LockCenter;
        uis.MouseIconEnabled = false;
        local connection1 = uis.InputChanged:Connect(function(input, gameProcessedEvent) -- Checking for user input
            if gameProcessedEvent then return; end
            if input.UserInputType == Enum.UserInputType.MouseMovement then -- https://create.roblox.com/docs/reference/engine/enums/UserInputType
                local delta = input.Delta * mouseSensitivity / 3 / zoomValue;
                delta = Vector2.new(delta.Y, delta.X);
                currentAngles -= delta;
                currentAngles = Vector2.new(math.clamp(currentAngles.X, -anglesLimit.X, anglesLimit.X), math.clamp(currentAngles.Y, -anglesLimit.Y, anglesLimit.Y))

                uis.MouseBehavior = Enum.MouseBehavior.LockCenter;
            elseif input.UserInputType == Enum.UserInputType.MouseWheel then
                local delta = input.Position.Z * zoomSensitivity;
                zoomValue = math.clamp(zoomValue + delta, 1, zoomLimit);
                APIs.CameraAPI.SetFOV(70 * (1/zoomValue), 0.5);
                print(delta);
            end
        end)
        local connection2 = uis.InputBegan:Connect(function(input, gameProcessedEvent) -- Checking for user input
            if gameProcessedEvent then return; end
            if input.UserInputType == Enum.UserInputType.Keyboard then
                if input.KeyCode == Enum.KeyCode.Q then
                    CurrentAPI.GoToIntro();
                end
            end
        end)

        Storage.CurrentDestructor = function()
            APIs.CameraAPI.SetFOV(70, 0);
            APIs.UIAPI.GetUI('GameplayFrame').Visible = false;
            connection1:Disconnect();
            connection2:Disconnect();
            scene:Destroy();
            uis.MouseBehavior = Enum.MouseBehavior.Default;
            uis.MouseIconEnabled = true;
        end
    end
end

function StartGame()
    Client.Camera.CameraType = Enum.CameraType.Scriptable;  -- Disables Roblox camera controller
    CurrentAPI.GoToIntro();
end

return function ()
    SetupAPIs();
    StartGame();
end