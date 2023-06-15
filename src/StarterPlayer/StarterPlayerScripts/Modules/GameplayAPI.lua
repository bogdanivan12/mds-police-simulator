local UserInputService = game:GetService('UserInputService')
local API_NAME = script.Name;

local Client = _G;
local APIs = Client.API;
local CurrentAPI = APIs[API_NAME];
local Storage = {
    CurrentDestructor = nil;
    CurrentPoints = 0;
    ChaseChance = 0.2;

    SpeedLimit = 100;
    ChaseOrigin = Client.Assets.Scenes.Chase.Road.PrimaryPart.CFrame;
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

        Storage.CurrentPoints = 0;
        APIs.CameraAPI.SetSaturation(0, 0);
        APIs.CameraAPI.SetBrightness(0, 3);
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

        local buttonConnection;
        buttonConnection = APIs.UIAPI.GetUI('IntroButtons').Play.Activated:Connect(function()
            buttonConnection:Disconnect(); buttonConnection = nil;

            APIs.CameraAPI.SetSaturation(-1, 3);
            APIs.CameraAPI.SetBrightness(-1, 3);
            task.wait(3);
            CurrentAPI.GoToGameplay();
        end)

        Storage.CurrentDestructor = function()
            APIs.UIAPI.GetUI('IntroFrame').Visible = false;
            if buttonConnection then
                buttonConnection:Disconnect();
            end

            scene:Destroy();
        end
    end

    CurrentAPI.GoToGameplay = function()
        CurrentAPI.DestroyCurrentGameplay();
        APIs.UIAPI.GetUI('GameplayFrame').Visible = true;
        local speedUI = APIs.UIAPI.GetUI('SpeedFrame');
        local pointsUI = APIs.UIAPI.GetUI('PointsFrame')
        pointsUI.Text = 'Points: '.. tostring(Storage.CurrentPoints);

        APIs.CameraAPI.SetSaturation(0, 3);
        APIs.CameraAPI.SetBrightness(0, 3);

        -- CAR PHYSICS
        local speedLimits = Vector2.new(50,150);

        local physicsDestructor, carsDestructor;
        local connection1, connection2;

        local spawnerConnections = {};
        local laneModels = Client.Assets.Scenes.Gameplay.Spawner:GetChildren();
        local carsDataset = {};
        local destroyCar = function(carIndex)
            local data = carsDataset[carIndex];                                                     -- Get data at index carIndex
            if data._simulation then data._simulation:Disconnect(); data._simulation = nil end      -- Disconnect event
            data.Model:Destroy();                                                                   -- :Destroy() is necessary, memory leaks can occur without it
            carsDataset[carIndex] = nil;                                                            -- Remove value at index carIndex. Because of #carsDataset, the next spawnCar call will fill the spot 
        end
        local spawnCar = function(rootModel, speed, interact)       -- Spawns car given a Model (Model has StartPosition and EndPosition), Speed, and Interact
            interact = interact or false;                           -- Ternary to defaul to false (Value means if user can interact with this car)
            local carModel = APIs.CarAPI.CreateCar();
            carModel.Parent = rootModel;
            carModel:PivotTo(rootModel.StartSpawn.CFrame);          -- Sets position and orientation of Car to StartSpawns CFrame
            local moveVec = (rootModel.EndSpawn.Position - rootModel.StartSpawn.Position).Unit; -- Creates a Unit vector representing the direction
            local distance = (rootModel.EndSpawn.Position - rootModel.StartSpawn.Position).Magnitude;
            local timeTillFinish = os.clock() + (distance / speed);

            local index = #carsDataset + 1; -- Used to store at index
            local connection = game:GetService('RunService').Heartbeat:Connect(function(deltaTime)
                carModel:PivotTo(carModel.PrimaryPart.CFrame*CFrame.new(carModel.PrimaryPart.CFrame:VectorToObjectSpace(moveVec) * deltaTime * speed));
                if timeTillFinish <= os.clock() then
                    destroyCar(index);
                end
            end)

            carsDataset[index] = {
                Model = carModel;               -- Car Model
                Lane = rootModel;
                MoveVector = moveVec;           -- Unit Direction vector (where it moves to)
                Speed = speed;                  -- Speed (studs/second)
                Distance = distance;            -- Distance (studs)
                FinishTime = timeTillFinish;    -- Future time when simulation will finish (seconds, high-precision)
                Clicked = false;

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
                for i,v in pairs(carsDataset) do    -- Iterate through carsDataset and check if we can insert car with speed newSpeed without collissions
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
            for i,v in pairs(carsDataset) do
                v._simulation:Disconnect();
                v._simulation = nil;
            end
            physicsDestructor = nil;
        end
        carsDestructor = function()
            for i,v in pairs(carsDataset) do
                destroyCar(i);
            end
            carsDestructor = nil;
        end
        -- CAR PHYSICS

        -- CAMERA CONTROLS AND LIMITS
        local uis = game:GetService('UserInputService');
        local anglesLimit = Vector2.new(10, 15);
        local mouseSensitivity = 0.1;
        local currentAngles = Vector2.new(0, 0);

        local zoomLimit = 5;
        local zoomValue = 1;
        local clickcallback = function() end
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
            speedUI.TextColor3 = Color3.fromRGB(255, 255, 255);
            clickcallback = function() end  -- Overwrite the clickcallback function to static act
            if raycastResult then
                raycastDistance = (cf.Position - raycastResult.Position).Magnitude;
                for i,v in pairs(carsDataset) do
                    if raycastResult.Instance:IsDescendantOf(v.Model) then
                        local speed = v.Speed;
                        speedUI.Text = tostring(math.floor(speed)) ..' km/h'; -- Adapt UI to the current speed
                        if v.Clicked == true then
                            speedUI.TextColor3 = Color3.fromRGB(255, 170, 0);
                        elseif speed>= Storage.SpeedLimit then
                            speedUI.TextColor3 = Color3.fromRGB(255, 0, 0);
                        end
                        

                        clickcallback = function()  -- Overwrite the clickcallback function to act
                            if v.Clicked == true then return; end
                            v.Clicked = true;

                            local x = math.random();
                            if x < Storage.ChaseChance then
                                print('Chase Mechanic')
                                connection1:Disconnect(); connection1 = nil;
                                connection2:Disconnect(); connection2 = nil;
                                physicsDestructor();
                                APIs.CameraAPI.SetSaturation(-1);
                                APIs.CameraAPI.SetBrightness(-1, 3)
                                task.wait(3);
                                CurrentAPI.GoToChase(v.Model:Clone());
                            else
                                if speed >= Storage.SpeedLimit then
                                    Storage.CurrentPoints += 50;        -- Award 50 points and update the UI
                                else
                                    Storage.CurrentPoints -= 50;        -- Penalty of 50 points and update the UI
                                end
                                pointsUI.Text = 'Points: '.. tostring(Storage.CurrentPoints);    -- Points UI update
                                print('Interrogation Mechanic')
                            end
                        end
                        break;
                    end
                end
            end
            APIs.CameraAPI.SetDepthOfField(raycastDistance, 1);
            return cf;
        end)

        uis.MouseBehavior = Enum.MouseBehavior.LockCenter;
        uis.MouseIconEnabled = false;
        connection1 = uis.InputChanged:Connect(function(input, gameProcessedEvent) -- Checking for user input
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
        connection2 = uis.InputBegan:Connect(function(input, gameProcessedEvent) -- Checking for user input
            if gameProcessedEvent then return; end
            if input.UserInputType == Enum.UserInputType.Keyboard then
                if input.KeyCode == Enum.KeyCode.Q then
                    CurrentAPI.GoToIntro();
                end
            elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
                clickcallback()
            end
        end)
        -- CAMERA CONTROLS AND LIMITS

        Storage.CurrentDestructor = function()
            APIs.CameraAPI.SetFOV(70, 0);
            APIs.UIAPI.GetUI('GameplayFrame').Visible = false;
            speedUI.Text = '0 km/h';
            speedUI.TextColor3 = Color3.fromRGB(255, 255, 255);
            pointsUI.Text = 'Points: 0'

            if physicsDestructor then physicsDestructor(); end
            if carsDestructor then carsDestructor(); end
            if connection1 then connection1:Disconnect(); end
            if connection2 then connection2:Disconnect(); end
            scene:Destroy();
            uis.MouseBehavior = Enum.MouseBehavior.Default;
            uis.MouseIconEnabled = true;
        end
    end

    CurrentAPI.GoToInterrogation = function()
        CurrentAPI.DestroyCurrentGameplay();

    end
    CurrentAPI.GoToChase = function(chasingCar)
        CurrentAPI.DestroyCurrentGameplay();

        local chasingPath = {};
        local carsDataset = {};
        local checkCollision = function(car1, car2)
            local origin1, size1 = car1:GetBoundingBox(); origin1 = origin1.Position; size1 = size1 * 0.9
            local origin2, size2 = car2:GetBoundingBox(); origin2 = origin2.Position; size2 = size2 * 0.9

            local rect1_left = origin1.X - size1.X/2;
            local rect1_right = origin1.X + size1.X/2;
            local rect2_left = origin2.X - size2.X/2;
            local rect2_right = origin2.X + size2.X/2;
            
            if rect1_right < rect2_left or rect1_left > rect2_right then
                return false -- No horizontal overlap
            end
            
            -- Check for vertical overlap
            local rect1_top = origin1.Z - size1.Z/2;
            local rect1_bottom = origin1.Z + size1.Z/2;
            local rect2_top = origin2.Z - size2.Z/2;
            local rect2_bottom = origin2.Z + size2.Z/2;
            
            if rect1_bottom < rect2_top or rect1_top > rect2_bottom then
                return false -- No vertical overlap
            end
            
            return true -- Collision detected
        end
        local destroyCar = function(carIndex)
            local data = carsDataset[carIndex];     -- Get data at index carIndex
            if data._simulation then
                data._simulation:Disconnect();          -- Disconnect event
            end
            data.Model:Destroy();                   -- :Destroy() is necessary, memory leaks can occur without it
            carsDataset[carIndex] = nil;            -- Remove value at index carIndex. Because of #carsDataset, the next spawnCar call will fill the spot 
        end
        local spawnCar = function(rootModel, speed, alpha, collision)
            collision = collision or false;
            speed = speed or 0;
            alpha = alpha or 0;

            local carModel = APIs.CarAPI.CreateCar();
            carModel.Parent = rootModel;
            local moveVec = (rootModel.EndSpawn.Position - rootModel.StartSpawn.Position).Unit; -- Creates a Unit vector representing the direction
            local distance = (rootModel.EndSpawn.Position - rootModel.StartSpawn.Position).Magnitude;
            carModel:PivotTo(rootModel.StartSpawn.CFrame*CFrame.new(0, 0, -distance * alpha));   -- Sets position and orientation of Car to StartSpawns CFrame

            local index = #carsDataset + 1; -- Used to store at index
            local connection;
            if speed > 0 then
                connection = game:GetService('RunService').Heartbeat:Connect(function(deltaTime)
                    carModel:PivotTo(carModel.PrimaryPart.CFrame*CFrame.new(carModel.PrimaryPart.CFrame:VectorToObjectSpace(moveVec) * deltaTime * speed));
                end)
            end

            carsDataset[index] = {
                Model = carModel;               -- Car Model
                Lane = rootModel;
                MoveVector = moveVec;           -- Unit Direction vector (where it moves to)
                Speed = speed;                  -- Speed (studs/second)
                Distance = distance;            -- Distance (studs)
                CanCollide = collision;

                _simulation = connection;       -- RBXScriptConnection to Heartbeat event. Used to simulate car moving forward
            }
            return index;
        end

        do  -- Spawning cars into current lane
            local leftLane = Client.Assets.Scenes.Chase.Spawner['1'];   -- Left lane asset
            local rightLane = Client.Assets.Scenes.Chase.Spawner['2'];  -- Right lane asset
            local cellSize = 35;
            local cellCount = math.ceil((leftLane.EndSpawn.Position - leftLane.StartSpawn.Position).Magnitude/cellSize);

            local lastAction = 'Pass';  -- Generating cars on the current lane
            local weightedMax = 3;
            local leftCount = weightedMax;
            local rightCount = weightedMax;
            local passCount = weightedMax;
            for i = 1,cellCount do
                local p = {Left = 2*leftCount, Right = 2*rightCount, Pass = 0.5*passCount};              -- Weights of Probability for generating a Left or Right car, also for passing the current cell
                local pSum = 0;
                if lastAction == 'Left' then p.Right = nil; end
                if lastAction == 'Right' then p.Left = nil; end
                if lastAction == 'Pass' then p.Pass = nil; end
                for i,v in pairs(p) do pSum += v; end

                local chance = math.random()*pSum;
                local action;
                for i,v in pairs(p) do
                    if v > chance then
                        action = i;
                        break;
                    else
                        chance -= v;
                    end
                end

                lastAction = action;
                if action == 'Left' then
                    local distance = (rightLane.EndSpawn.Position - rightLane.StartSpawn.Position).Magnitude;
                    local newPoint = rightLane.StartSpawn.CFrame*CFrame.new(0, 0, -distance * i/cellCount)
                    chasingPath[#chasingPath + 1] = newPoint;

                    spawnCar(leftLane, 0, i/cellCount);
                    leftCount = math.max(leftCount - 1.5, 0);
                    rightCount = math.min(rightCount + 1, weightedMax);
                    passCount = math.min(passCount + 1, weightedMax);
                elseif action == 'Right' then
                    local distance = (leftLane.EndSpawn.Position - leftLane.StartSpawn.Position).Magnitude;
                    local newPoint = leftLane.StartSpawn.CFrame*CFrame.new(0, 0, -distance * i/cellCount)
                    chasingPath[#chasingPath + 1] = newPoint;

                    spawnCar(rightLane, 0, i/cellCount);
                    leftCount = math.min(leftCount + 1, weightedMax);
                    rightCount = math.max(rightCount - 1.5, 0);
                    passCount = math.min(passCount + 1, weightedMax);
                elseif action == 'Pass' then
                    local distance = (leftLane.EndSpawn.Position - leftLane.StartSpawn.Position).Magnitude;
                    local newPoint = leftLane.StartSpawn.CFrame*CFrame.new(0, 0, -distance * i/cellCount)
                    chasingPath[#chasingPath + 1] = newPoint;

                    leftCount = math.min(leftCount + 1, weightedMax);
                    rightCount = math.min(rightCount + 1, weightedMax);
                    passCount = 0;
                    continue;
                else
                    warn('UNKNOWN BEHAVIOR. UNKNOWN ACTION CHOSEN TO SPAWN VEHICLE')
                end
            end

            local newPoint = chasingPath[#chasingPath] * CFrame.new(0, 0, -10000)
            chasingPath[#chasingPath + 1] = newPoint;
        end
        do  -- Spawn cars into the oncoming lane TODO
            
        end

        local speed = 100;
        local turnSpeed = 50;
        local policeCar = Client.Assets.Scenes.Chase.PoliceCar; policeCar:PivotTo(Client.Assets.Scenes.Chase.Spawn.CFrame)
        local ground = Client.Assets.Scenes.Chase.Road;
        local limiter = {Min = Client.Assets.Scenes.Chase.XLimits.Min.Position.X, Max = Client.Assets.Scenes.Chase.XLimits.Max.Position.X}
        chasingCar.Parent = Client.Assets.Scenes.Chase;
        chasingCar:PivotTo(chasingPath[1])

        APIs.CameraAPI.SetDepthOfField((policeCar.CameraOffset.Position - policeCar.PrimaryPart.Position).Magnitude);
        local scene = APIs.CameraAPI.CreateScene(function(t)
            return policeCar.CameraOffset.CFrame;
        end)

        
        APIs.CameraAPI.SetSaturation(0, 3);
        APIs.CameraAPI.SetBrightness(0, 3);
        task.wait(3);

        local finishTime = 2048/speed;
        local currentTime = 0;
        local timeScale = 0;
        local physicsEmulator;
        physicsEmulator = game:GetService('RunService').Heartbeat:Connect(function(deltaTime)
            timeScale = math.min(timeScale + deltaTime * 1/3, 1)
            deltaTime = deltaTime * timeScale;
            currentTime += deltaTime;

            local right = UserInputService:IsKeyDown(Enum.KeyCode.D);
            local left = UserInputService:IsKeyDown(Enum.KeyCode.A);
            local turnDirection = ((right and 1 or 0) + (left and -1 or 0));
            local newCF = policeCar.PrimaryPart.CFrame*CFrame.new(turnDirection * turnSpeed * deltaTime, 0, -speed * deltaTime);
            local delta = Vector3.new(math.clamp(newCF.Position.X, limiter.Min, limiter.Max) - newCF.Position.X, 0, 0);
            newCF = newCF + delta;
            policeCar:PivotTo(newCF);

            local sign = math.floor(currentTime / 0.25) % 2;
            policeCar.Lights.Left.Material = (sign == 0) and Enum.Material.Neon or Enum.Material.SmoothPlastic;
            policeCar.Lights.Right.Material = (sign == 0) and Enum.Material.SmoothPlastic or Enum.Material.Neon;

            local totalDist = speed * currentTime;
            local deltaDist = 0;
            local pointA, pointB, alpha;
            for i = 1, #chasingPath - 1 do
                local a = chasingPath[i];
                local b = chasingPath[i + 1]
                local currentDist = math.abs(a.Position.Z - b.Position.Z);
                deltaDist += currentDist;
                if deltaDist >= totalDist then
                    alpha = 1 - (deltaDist - totalDist)/currentDist;
                    pointA = a; pointB = b;
                    break;
                end
            end
            chasingCar:PivotTo(pointA:Lerp(pointB, alpha));

            ground:PivotTo(ground.PrimaryPart.CFrame*CFrame.new(0, 0, speed*deltaTime))
            if currentTime > finishTime then
                physicsEmulator:Disconnect();
                physicsEmulator = nil;
                
                APIs.CameraAPI.SetSaturation(-1);
                APIs.CameraAPI.SetBrightness(-1, 3);
                task.wait(3);
                Storage.CurrentPoints += 200;
                CurrentAPI.GoToGameplay();
            end

            local collision = false;
            for i,v in pairs(carsDataset) do
                if checkCollision(v.Model, policeCar.Model) then
                    collision = true;
                    physicsEmulator:Disconnect();
                    physicsEmulator = nil;
                    break;
                end
            end
            if collision then
                APIs.CameraAPI.SetSaturation(-1);
                APIs.CameraAPI.SetBrightness(-1, 3);
                task.wait(3);
                CurrentAPI.GoToIntro();
            end
        end)
        local physicsDestructor = function()
            if physicsEmulator then physicsEmulator:Disconnect(); physicsEmulator = nil; end
            for i,v in pairs(carsDataset) do
                destroyCar(i);
            end
        end

        Storage.CurrentDestructor = function()
            chasingCar:Destroy();
            APIs.CameraAPI.SetFOV(70, 0);

            ground:PivotTo(Storage.ChaseOrigin)
            ground = Storage.ChaseOrigin;
            physicsDestructor();
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