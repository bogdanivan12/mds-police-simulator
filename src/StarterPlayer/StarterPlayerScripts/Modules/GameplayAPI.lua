local API_NAME = script.Name;

local Client = _G;
local APIs = Client.API;
local CurrentAPI = APIs[API_NAME];
local Storage = {
    CurrentDestructor = nil;
    CarsDataset = {};
};

-- Storage.CarsDataset[index] = {
--     Model = carModel;               -- Car Model
--     Lane = rootModel;
--     MoveVector = moveVec;           -- Unit Direction vector (where it moves to)
--     Speed = speed;                  -- Speed (studs/second)
--     Distance = distance;            -- Distance (studs)
--     FinishTime = timeTillFinish;    -- Future time when simulation will finish (seconds, high-precision)

--     _simulation = connection;       -- RBXScriptConnection to Heartbeat event. Used to simulate car moving forward
-- }

function SetupAPIs()

    CurrentAPI.GetCarDataByModel = function(model)
        for i, v in pairs(Storage.CarsDataset) do
            if v.Model == model then
                return v;
            end
        end
        warn("No CarData found for " .. model:GetFullName());
    end

    CurrentAPI.DestroyCurrentGameplay = function()
        if Storage.CurrentDestructor then
            Storage.CurrentDestructor();
            Storage.CurrentDestructor = nil;
        end
    end

    CurrentAPI.GoToIntro = function()
        CurrentAPI.DestroyCurrentGameplay();
        APIs.UIAPI.GetUI('IntroFrame').Visible = true;

        local rotSpeed = 10;    -- Degrees/Second
        local zDist = 40;       -- Studs
        local scene = APIs.CameraAPI.CreateScene(function(t)
            return Client.Assets.Scenes.IntroScene.CameraOffset.CFrame
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
        local speedUI = APIs.UIAPI.GetUI('SpeedFrame');

        -- CAR PHYSICS
        local speedLimits = Vector2.new(50,150);

        local physicsDestructor;
        local spawnerConnections = {};
        local laneModels = Client.Assets.Scenes.Gameplay.Spawner:GetChildren();
        local destroyCar = function(carIndex)
            local data = Storage.CarsDataset[carIndex];     -- Get data at index carIndex
            data._simulation:Disconnect();          -- Disconnect event
            data.Model:Destroy();                   -- :Destroy() is necessary, memory leaks can occur without it
            Storage.CarsDataset[carIndex] = nil;            -- Remove value at index carIndex. Because of #carsDataset, the next spawnCar call will fill the spot 
        end
        local spawnCar = function(rootModel, speed, interact)       -- Spawns car given a Model (Model has StartPosition and EndPosition), Speed, and Interact
            interact = interact or false;                           -- Ternary to defaul to false (Value means if user can interact with this car)
            local carModel = APIs.CarAPI.CreateCar();
            carModel.Parent = rootModel;
            carModel:PivotTo(rootModel.StartSpawn.CFrame);          -- Sets position and orientation of Car to StartSpawns CFrame
            local moveVec = (rootModel.EndSpawn.Position - rootModel.StartSpawn.Position).Unit; -- Creates a Unit vector representing the direction
            local distance = (rootModel.EndSpawn.Position - rootModel.StartSpawn.Position).Magnitude;
            local timeTillFinish = os.clock() + (distance / speed);

            local index = #Storage.CarsDataset + 1; -- Used to store at index
            local connection = game:GetService('RunService').Heartbeat:Connect(function(deltaTime)
                carModel:PivotTo(carModel.PrimaryPart.CFrame*CFrame.new(carModel.PrimaryPart.CFrame:VectorToObjectSpace(moveVec) * deltaTime * speed));
                if timeTillFinish <= os.clock() then
                    destroyCar(index);
                end
            end)

            Storage.CarsDataset[index] = {
                Model = carModel;               -- Car Model
                Lane = rootModel;
                MoveVector = moveVec;           -- Unit Direction vector (where it moves to)
                Speed = speed;                  -- Speed (studs/second)
                Distance = distance;            -- Distance (studs)
                FinishTime = timeTillFinish;    -- Future time when simulation will finish (seconds, high-precision)

                _simulation = connection;       -- RBXScriptConnection to Heartbeat event. Used to simulate car moving forward
            }

            return index;
        end
        
        for laneIndex = 1, #laneModels do
            local laneObject = laneModels[laneIndex];
            local distance = (laneObject.EndSpawn.Position - laneObject.StartSpawn.Position).Magnitude;
            local newSpeed = speedLimits.X + (speedLimits.Y - speedLimits.X) * math.random();   -- Lerp Function [ a + (b - a) * alpha ], where alpha = [0, 1]
            spawnerConnections[laneIndex] = game:GetService('RunService').Heartbeat:Connect(function(deltaTime)
                local timeNeeded = distance / newSpeed;
                local availableTime = -1;           -- math.huge = inf (https://create.roblox.com/docs/reference/engine/libraries/math)
                for i,v in pairs(Storage.CarsDataset) do    -- Iterate through carsDataset and check if we can insert car with speed newSpeed without collissions
                    if v.Lane ~= laneObject then continue; end  -- If not on the same lane, continue
                    
                    availableTime = math.max(availableTime, v.FinishTime - os.clock());
                end
                if timeNeeded >= availableTime * 1.5 or availableTime == -1 then
                    spawnCar(laneObject, newSpeed, false);  -- False for testing
                    newSpeed = speedLimits.X + (speedLimits.Y - speedLimits.X) * math.random();   -- Lerp Function [ a + (b - a) * alpha ], where alpha = [0, 1]
                end
            end)
        end

        physicsDestructor = function()
            for i,v in pairs(spawnerConnections) do
                v:Disconnect();
            end
            for i,v in pairs(Storage.CarsDataset) do
                destroyCar(i);
            end
        end
        -- CAR PHYSICS

        -- CAMERA CONTROLS AND LIMITS
        local uis = game:GetService('UserInputService');
        local anglesLimit = Vector2.new(10, 15);
        local mouseSensitivity = 0.1;
        local currentAngles = Vector2.new(0, 0);

        local zoomLimit = 5;
        local zoomValue = 1;
        local zoomSensitivity = 0.3;
        local scene = APIs.CameraAPI.CreateScene(function(t)
            local cf = Client.Assets.Scenes.Gameplay.CameraOffset.CFrame
                        * CFrame.Angles(0, math.rad(currentAngles.Y), 0)
                        * CFrame.Angles(math.rad(currentAngles.X), 0, 0)
            
            local raycastParams = RaycastParams.new();
            raycastParams.FilterDescendantsInstances = {Client.Assets.Scenes.Gameplay.CameraOffset};
            raycastParams.FilterType = Enum.RaycastFilterType.Exclude;
            raycastParams.IgnoreWater = true;
            local raycastDistance = 10000;
            local raycastResult = workspace:Raycast(cf.Position, cf.LookVector*raycastDistance);  -- https://create.roblox.com/docs/mechanics/raycasting

            speedUI.Text = '0 km/h';
            if raycastResult then
                raycastDistance = (cf.Position - raycastResult.Position).Magnitude;
                for i,v in pairs(Storage.CarsDataset) do
                    if raycastResult.Instance:IsDescendantOf(v.Model) then
                        speedUI.Text = tostring(math.floor(v.Speed)) ..' km/h';
                        break;
                    end
                end
            end
            APIs.CameraAPI.SetDepthOfField(raycastDistance, 1);
            return cf;
        end)

        uis.MouseBehavior = Enum.MouseBehavior.LockCenter;
        uis.MouseIconEnabled = false;
        local connection1 = uis.InputChanged:Connect(function(input, gameProcessedEvent) -- Checking for user input
            if gameProcessedEvent then return; end
            if input.UserInputType == Enum.UserInputType.MouseMovement then     -- https://create.roblox.com/docs/reference/engine/enums/UserInputType
                local delta = input.Delta * mouseSensitivity / 3 / zoomValue;   -- Input.Delta (How much the mouse has moved)
                delta = Vector2.new(delta.Y, delta.X);                          -- Vector3 to Vector2 Transform, DeltaY = AngleX, DeltaX = AngleY
                currentAngles -= delta;
                currentAngles = Vector2.new(math.clamp(currentAngles.X, -anglesLimit.X, anglesLimit.X), math.clamp(currentAngles.Y, -anglesLimit.Y, anglesLimit.Y))

                uis.MouseBehavior = Enum.MouseBehavior.LockCenter;              -- Locking mouse to center of screen
            elseif input.UserInputType == Enum.UserInputType.MouseWheel then
                local delta = input.Position.Z * zoomSensitivity;           -- Input.Position.Z (Weird way to say if scroll forward or backward)
                zoomValue = math.clamp(zoomValue + delta, 1, zoomLimit);    -- Clamp values in domain [1, zoomLimit]
                APIs.CameraAPI.SetFOV(70 * (1/zoomValue), 0.5);
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
        -- CAMERA CONTROLS AND LIMITS

        Storage.CurrentDestructor = function()
            APIs.CameraAPI.SetFOV(70, 0);
            APIs.UIAPI.GetUI('GameplayFrame').Visible = false;
            speedUI.Text = '0 km/h';

            physicsDestructor();
            connection1:Disconnect();
            connection2:Disconnect();
            scene:Destroy();
            uis.MouseBehavior = Enum.MouseBehavior.Default;
            uis.MouseIconEnabled = true;
        end
    end

    CurrentAPI.GoToInterogation = function()
        CurrentAPI.DestroyCurrentGameplay();
        APIs.UIAPI.GetUI('Interogation').Visible = true;

        local rotSpeed = 10;    -- Degrees/Second
        local zDist = 40;       -- Studs
        local scene = APIs.CameraAPI.CreateScene(function(t)
            local cameraOffset = Client.Assets.Scenes.IntroScene.CameraOffset.CFrame
            local rotation = CFrame.Angles(0, math.rad(rotSpeed * t), 0) -- Rotate around the Y-axis

            -- Apply rotations and translation to the camera offset
            local newCFrame = cameraOffset * rotation * CFrame.Angles(math.rad(-60), 0, 0) 
                                                      * CFrame.new(0, 5, zDist);

            return newCFrame
        end)
        APIs.CameraAPI.SetDepthOfField(zDist);

        local buttonConnection = APIs.UIAPI.GetUI('InterogationButtons').Play.Activated:Connect(function()
            CurrentAPI.GoToGameplay();
        end)

        Storage.CurrentDestructor = function()
            APIs.UIAPI.GetUI('Interogation').Visible = false;
            buttonConnection:Disconnect();
            scene:Destroy();
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