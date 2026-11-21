-- Unicorn Hub MM2 | Fixed & Optimized Release (v2.1)
-- WindUI + Custom HUD Buttons (Mobile-First, Safe Load, Persistent Positions)

repeat task.wait() until game:IsLoaded()

-- ════════════════════════════════════
-- SERVICES
-- ════════════════════════════════════
local CoreGui           = game:GetService("CoreGui")
local Players           = game:GetService("Players")
local Workspace         = game:GetService("Workspace")
local RunService        = game:GetService("RunService")
local TeleportService   = game:GetService("TeleportService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService       = game:GetService("HttpService")
local UserInputService  = game:GetService("UserInputService")
local TweenService      = game:GetService("TweenService")

local Player = Players.LocalPlayer
local Mouse  = Player:GetMouse()
local Camera = Workspace.CurrentCamera

local firetouchinterest = firetouchinterest or nil
local queue_on_teleport = queue_on_teleport
    or (syn and syn.queue_on_teleport)
    or (fluxus and fluxus.queue_on_teleport)
    or function() end

-- ════════════════════════════════════
-- CLEANUP
-- ════════════════════════════════════
local env = (getgenv and getgenv()) or _G
if env.UnicornHub_Connections then
    for i, c in pairs(env.UnicornHub_Connections) do
        pcall(function() c:Disconnect() end)
        env.UnicornHub_Connections[i] = nil
    end
end
env.UnicornHub_Connections = {}

local function SafeParent()
    local ok, cg = pcall(function() return gethui and gethui() or CoreGui end)
    if ok and cg then return cg end
    return Player:WaitForChild("PlayerGui")
end
local GuiParent = SafeParent()

for _, g in ipairs(GuiParent:GetChildren()) do
    if g.Name == "UnicornHub" or g.Name == "UnicornESP"
    or g.Name == "UnicornCrosshair" or g.Name == "UnicornLogo"
    or g.Name:match("^UnicornBtn_") then
        g:Destroy()
    end
end

for _, p in ipairs(Players:GetPlayers()) do
    if p.Character then
        local h = p.Character:FindFirstChild("UnicornHL")
        local hd = p.Character:FindFirstChild("Head")
        if h then h:Destroy() end
        if hd then
            local n = hd:FindFirstChild("UnicornName")
            if n then n:Destroy() end
        end
    end
end

for _, o in ipairs(Workspace:GetDescendants()) do
    if o.Name == "UnicornGunHL" then o:Destroy() end
end

-- ════════════════════════════════════
-- SAFE WIND UI LOADER (WITH FALLBACKS)
-- ════════════════════════════════════
local WindUI = nil
local urls = {
    "https://github.com/Footagesus/WindUI/releases/latest/download/main.lua",
    "https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua",
    "https://raw.githubusercontent.com/KevinScripts2024/Gkfkfkdlwsk/refs/heads/main/wind%20(1).txt"
}

for _, url in ipairs(urls) do
    local ok, res = pcall(function()
        return loadstring(game:HttpGet(url))()
    end)
    if ok and res then
        WindUI = res
        break
    end
end

if not WindUI then
    warn("[Unicorn Hub] Failed to load WindUI from all sources! Check your executor HttpGet.")
    return
end

-- ════════════════════════════════════
-- STATE
-- ════════════════════════════════════
local M = {}
M.Player       = Player
M.Mouse        = Mouse
M.PlayerData   = {}
M.HudButtons   = {}

M.Cfg = {
    WalkSpeed = 16, EnableWalkSpeed = false,
    JumpPower = 50, EnableJumpPower = false,
    Noclip = false, InfiniteJump = false,
    Fly = false,
    GodMode = false, AntiFling = false, AntiAfk = false,
    AutoGrabGun = false, AutoKill = false,
    KnifeAura = false, AuraRadius = 10,
    AutoShootMurderer = false, SilentThrow = false,
    WallCheck = true,
    EspPlayers = false, ShowNames = false,
    GunEsp = false,
    CrosshairEnabled = false,
    CrosshairShape = "Cross",
    CrosshairColor = Color3.fromHex("#CF9FFF"),
    CrosshairSize = 20,
    CrosshairThick = 2,
    AimbotEnabled = false, AimbotSmooth = 0.2, AimbotFov = 120,
    AimbotMurdererOnly = true, WallCheckAimbot = true,
    NotifyMurderer = false, NotifySheriff = false, NotifyGunDropped = false,
    AutoQueue = true, ButtonsLocked = false,
    QueueUrl = "",
}

local IS_MOBILE = UserInputService.TouchEnabled
local TILE      = IS_MOBILE and 72 or 84
local HUD_SCALE = IS_MOBILE and 0.85 or 1
local HUD_COL   = {
    Shoot   = Color3.fromHex("#257AF7"),
    Throw   = Color3.fromHex("#EF4444"),
    Grab    = Color3.fromHex("#10C550"),
    KillAll = Color3.fromHex("#DC2626"),
    Aimbot  = Color3.fromHex("#2DD4BF"),
    Fly     = Color3.fromHex("#38BDF8"),
    Noclip  = Color3.fromHex("#94A3B8"),
}

local function AddConn(c)
    local t = env.UnicornHub_Connections
    for i = #t, 1, -1 do
        if not t[i] or not t[i].Connected then table.remove(t, i) end
    end
    table.insert(t, c)
    return c
end

local function RefreshChar(char)
    M.Character = char
    if char then
        M.Humanoid = char:FindFirstChildOfClass("Humanoid") or char:WaitForChild("Humanoid", 5)
        M.RootPart = char:FindFirstChild("HumanoidRootPart") or char.PrimaryPart
        M.Backpack = Player:FindFirstChild("Backpack")
        Camera = Workspace.CurrentCamera
    else
        M.Humanoid = nil; M.RootPart = nil
    end
end
if Player.Character then RefreshChar(Player.Character) end
AddConn(Player.CharacterAdded:Connect(RefreshChar))
AddConn(Player.CharacterRemoving:Connect(function() RefreshChar(nil) end))
AddConn(Players.PlayerRemoving:Connect(function(p) M.PlayerData[p.Name] = nil end))

-- Player Data Sync
do
    local ok, rem = pcall(function() return ReplicatedStorage:WaitForChild("Remotes", 5) end)
    if ok and rem then
        local gp = rem:FindFirstChild("Gameplay") or rem:FindFirstChild("Gameplay", true)
        if gp then
            local ev = gp:FindFirstChild("PlayerDataChanged")
            if ev and ev:IsA("RemoteEvent") then
                AddConn(ev.OnClientEvent:Connect(function(d) if type(d) == "table" then M.PlayerData = d end end))
            end
        end
    end
    local gpd = ReplicatedStorage:FindFirstChild("GetPlayerData", true)
    if gpd and typeof(gpd.InvokeServer) == "function" then
        pcall(function()
            local ok2, r = pcall(function() return gpd:InvokeServer() end)
            if ok2 and type(r) == "table" then M.PlayerData = r end
        end)
    end
end

-- ════════════════════════════════════
-- HELPERS
-- ════════════════════════════════════
local function Notify(title, body, icon, col)
    pcall(function()
        WindUI:Notify({
            Title = title, Content = body,
            Icon = icon or "bell", Duration = 4,
        })
    end)
end

local function GetMap()
    for _, o in ipairs(Workspace:GetChildren()) do
        if o:FindFirstChild("CoinContainer") and o:FindFirstChild("Spawns") then return o end
    end
end

local function GetLobby()
    for _, o in ipairs(Workspace:GetChildren()) do
        if o:FindFirstChild("Lobby") then return o.Lobby end
        if o.Name:lower() == "lobby" then return o end
    end
end

function M.FindMurderer()
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Backpack and p.Backpack:FindFirstChild("Knife") then return p end
    end
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Character and p.Character:FindFirstChild("Knife") then return p end
    end
    for name, d in pairs(M.PlayerData) do
        if d and (d.Role == "Murderer" or d.role == "Murderer") then return Players:FindFirstChild(name) end
    end
end

function M.FindSheriff()
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Backpack and p.Backpack:FindFirstChild("Gun") then return p end
    end
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Character and p.Character:FindFirstChild("Gun") then return p end
    end
    for name, d in pairs(M.PlayerData) do
        if d and (d.Role == "Sheriff" or d.role == "Sheriff") then return Players:FindFirstChild(name) end
    end
end

local function CanSee(charA, rootB)
    if not charA or not rootB then return false end
    local rp = RaycastParams.new()
    rp.FilterType = Enum.RaycastFilterType.Exclude
    rp.FilterDescendantsInstances = {Player.Character}
    rp.RespectCanCollide = true
    for _, part in ipairs({"HumanoidRootPart","Head","UpperTorso","Torso"}) do
        local p = charA:FindFirstChild(part)
        if p then
            local hit = Workspace:Raycast(rootB.Position, p.Position - rootB.Position, rp)
            if not hit or (hit.Instance and hit.Instance:IsDescendantOf(charA)) or (hit.Instance and hit.Instance.Transparency > 0.5) then
                return true
            end
        end
    end
    return false
end

local function PredictPos(target)
    if not target or not target.Character then return Vector3.new() end
    local hrp = target.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return Vector3.new() end
    local vel = hrp.AssemblyLinearVelocity or Vector3.new()
    local ping = 0
    pcall(function()
        if typeof(Player.GetNetworkPing) == "function" then
            ping = Player:GetNetworkPing() or 0
        end
    end)
    if type(ping) ~= "number" then ping = 0 end
    if ping > 1 then ping = ping / 1000 end
    return hrp.Position + vel * (0.028 + ping)
end

local function NearestPlayer()
    local best, bestDist = nil, math.huge
    local myRoot = M.RootPart
    if not myRoot then return nil end
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= Player and p.Character then
            local r = p.Character:FindFirstChild("HumanoidRootPart")
            local hum = p.Character:FindFirstChildOfClass("Humanoid")
            if r and hum and hum.Health > 0 then
                local d = (r.Position - myRoot.Position).Magnitude
                if d < bestDist then bestDist = d; best = p end
            end
        end
    end
    return best
end

-- ════════════════════════════════════
-- MOVEMENT
-- ════════════════════════════════════
do
    local _wsConn, _jpConn
    function M.SetWalkspeedEnabled(v)
        M.Cfg.EnableWalkSpeed = v
        if _wsConn then _wsConn:Disconnect() _wsConn = nil end
        if v then
            _wsConn = AddConn(RunService.Heartbeat:Connect(function()
                if M.Humanoid and M.Humanoid.WalkSpeed ~= M.Cfg.WalkSpeed then
                    M.Humanoid.WalkSpeed = M.Cfg.WalkSpeed
                end
            end))
        else
            if M.Humanoid then M.Humanoid.WalkSpeed = 16 end
        end
    end
    function M.SetWalkspeedVal(v)
        M.Cfg.WalkSpeed = math.clamp(v, 16, 300)
        if M.Cfg.EnableWalkSpeed and M.Humanoid then M.Humanoid.WalkSpeed = M.Cfg.WalkSpeed end
    end
    function M.SetJumppowerEnabled(v)
        M.Cfg.EnableJumpPower = v
        if _jpConn then _jpConn:Disconnect() _jpConn = nil end
        if v then
            _jpConn = AddConn(RunService.Heartbeat:Connect(function()
                if M.Humanoid and M.Humanoid.JumpPower ~= M.Cfg.JumpPower then
                    M.Humanoid.JumpPower = M.Cfg.JumpPower
                end
            end))
        else
            if M.Humanoid then M.Humanoid.JumpPower = 50 end
        end
    end
    function M.SetJumppowerVal(v)
        M.Cfg.JumpPower = math.clamp(v, 50, 500)
        if M.Cfg.EnableJumpPower and M.Humanoid then M.Humanoid.JumpPower = M.Cfg.JumpPower end
    end
end

do
    local _ncConn, _savedCC = nil, {}
    function M.SetNoclip(v)
        M.Cfg.Noclip = v
        if v then
            if M.Character then
                for _, p in ipairs(M.Character:GetDescendants()) do
                    if p:IsA("BasePart") then _savedCC[p] = p.CanCollide; p.CanCollide = false end
                end
            end
            if _ncConn then _ncConn:Disconnect() end
            _ncConn = AddConn(RunService.Stepped:Connect(function()
                if not M.Character then return end
                for _, p in ipairs(M.Character:GetDescendants()) do
                    if p:IsA("BasePart") then p.CanCollide = false end
                end
            end))
        else
            if _ncConn then _ncConn:Disconnect() _ncConn = nil end
            for p, s in pairs(_savedCC) do if p and p.Parent then p.CanCollide = s end end
            _savedCC = {}
        end
    end
end

do
    local _ijConn
    function M.SetInfJump(v)
        M.Cfg.InfiniteJump = v
        if _ijConn then _ijConn:Disconnect() _ijConn = nil end
        if v then
            _ijConn = AddConn(UserInputService.JumpRequest:Connect(function()
                if M.Humanoid then M.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping) end
            end))
        end
    end
end

do
    local _flyConn, _flyBV, _flyBG
    local function CleanFly()
        if _flyBV and _flyBV.Parent then _flyBV:Destroy() end
        if _flyBG and _flyBG.Parent then _flyBG:Destroy() end
        _flyBV = nil; _flyBG = nil
        if _flyConn then _flyConn:Disconnect() _flyConn = nil end
    end
    function M.SetFly(v)
        M.Cfg.Fly = v
        CleanFly()
        if not v then return end
        local root = M.RootPart
        if not root then return end
        _flyBV = Instance.new("BodyVelocity")
        _flyBV.MaxForce = Vector3.new(1e5,1e5,1e5)
        _flyBV.Velocity = Vector3.new(0,0,0)
        _flyBV.Parent = root
        _flyBG = Instance.new("BodyGyro")
        _flyBG.MaxTorque = Vector3.new(1e5,1e5,1e5)
        _flyBG.D = 50
        _flyBG.Parent = root
        _flyConn = AddConn(RunService.Heartbeat:Connect(function()
            if not M.Cfg.Fly or not root.Parent then CleanFly() return end
            local cam = Camera.CFrame
            local speed = M.Cfg.WalkSpeed > 16 and M.Cfg.WalkSpeed or 50
            local dir = Vector3.new()
            local uis = UserInputService
            if uis:IsKeyDown(Enum.KeyCode.W) then dir = dir + cam.LookVector end
            if uis:IsKeyDown(Enum.KeyCode.S) then dir = dir - cam.LookVector end
            if uis:IsKeyDown(Enum.KeyCode.A) then dir = dir - cam.RightVector end
            if uis:IsKeyDown(Enum.KeyCode.D) then dir = dir + cam.RightVector end
            if uis:IsKeyDown(Enum.KeyCode.Space) then dir = dir + Vector3.new(0,1,0) end
            if uis:IsKeyDown(Enum.KeyCode.LeftShift) then dir = dir - Vector3.new(0,1,0) end
            if IS_MOBILE and M.Humanoid and M.Humanoid.MoveDirection.Magnitude > 0 then
                dir = cam.LookVector * M.Humanoid.MoveDirection.Magnitude
            end
            _flyBV.Velocity = dir.Magnitude > 0 and dir.Unit * speed or Vector3.new(0,0,0)
            _flyBG.CFrame = cam
        end))
    end
    AddConn(Player.CharacterAdded:Connect(function() if M.Cfg.Fly then task.wait(0.3); M.SetFly(true) end end))
end

-- ════════════════════════════════════
-- GODMODE / ANTIFLING / ANTIAFK
-- ════════════════════════════════════
do
    local _godConn
    function M.SetGodMode(v)
        M.Cfg.GodMode = v
        if _godConn then _godConn:Disconnect() _godConn = nil end
        if not v then return end
        local function Protect(h)
            if not h then return end
            h.HealthChanged:Connect(function(hp) if M.Cfg.GodMode and hp < h.MaxHealth then h.Health = h.MaxHealth end end)
            task.spawn(function()
                while M.Cfg.GodMode and h and h.Parent do
                    if h.Health < h.MaxHealth then h.Health = h.MaxHealth end
                    if h:GetState() == Enum.HumanoidStateType.Dead then
                        h:ChangeState(Enum.HumanoidStateType.GettingUp); h.Health = h.MaxHealth
                    end
                    task.wait(0.2)
                end
            end)
        end
        if M.Humanoid then Protect(M.Humanoid) end
        _godConn = AddConn(Player.CharacterAdded:Connect(function(c)
            local hum = c:WaitForChild("Humanoid", 5)
            if hum then task.wait(0.5); Protect(hum) end
        end))
    end
end

do
    local _afConn
    function M.SetAntiFling(v)
        M.Cfg.AntiFling = v
        if _afConn then _afConn:Disconnect() _afConn = nil end
        if not v then return end
        _afConn = AddConn(RunService.Stepped:Connect(function()
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= Player and p.Character then
                    for _, part in ipairs(p.Character:GetChildren()) do
                        if part:IsA("BasePart") and part.CanCollide then
                            part.CanCollide = false
                            if part.Name == "HumanoidRootPart" then
                                part.Velocity = Vector3.new(0,0,0)
                                part.RotVelocity = Vector3.new(0,0,0)
                            end
                        end
                    end
                end
            end
        end))
    end
end

do
    local _afkConn
    local vru = game:GetService("VirtualUser")
    function M.SetAntiAfk(v)
        M.Cfg.AntiAfk = v
        if _afkConn then _afkConn:Disconnect() _afkConn = nil end
        if not v then return end
        _afkConn = AddConn(Player.Idled:Connect(function()
            pcall(function()
                vru:Button2Down(Vector2.new(0,0), Camera.CFrame)
                task.wait(0.1)
                vru:Button2Up(Vector2.new(0,0), Camera.CFrame)
            end)
        end))
    end
end

-- ════════════════════════════════════
-- FLING
-- ════════════════════════════════════
local function Fling(target)
    if not target or not target.Character then return end
    local root = M.RootPart
    if not root then return end
    local tHRP = target.Character:FindFirstChild("HumanoidRootPart") or target.Character.PrimaryPart
    if not tHRP then return end
    local orig = root.CFrame
    root.CFrame = tHRP.CFrame
    local bg = Instance.new("BodyGyro")
    bg.MaxTorque = Vector3.new(1e9,1e9,1e9); bg.P = 1e9; bg.D = 0
    bg.CFrame = tHRP.CFrame * CFrame.Angles(math.pi/2,0,0); bg.Parent = tHRP
    local bv = Instance.new("BodyVelocity")
    bv.MaxForce = Vector3.new(1e9,1e9,1e9)
    bv.Velocity = CFrame.new(root.Position, tHRP.Position).LookVector * 999; bv.Parent = tHRP
    task.delay(0.3, function()
        if bg and bg.Parent then bg:Destroy() end
        if bv and bv.Parent then bv:Destroy() end
    end)
    root.CFrame = orig
end
function M.FlingMurderer() pcall(Fling, M.FindMurderer()) end
function M.FlingSheriff()  pcall(Fling, M.FindSheriff()) end
function M.FlingAll() for _, p in ipairs(Players:GetPlayers()) do if p ~= Player then pcall(Fling, p) end end end

-- ════════════════════════════════════
-- SHOOT MURDERER
-- ════════════════════════════════════
local shootCooldown = false
function M.ShootMurderer()
    if shootCooldown then return end
    shootCooldown = true
    task.delay(0.4, function() shootCooldown = false end)

    local target = M.FindMurderer()
    if not target or not target.Character then
        Notify("No Murderer", "No murderer found this round.", "x")
        return
    end
    local myRoot = M.RootPart
    if not myRoot then return end
    local tHRP = target.Character:FindFirstChild("HumanoidRootPart")
    if not tHRP then return end
    if M.Cfg.WallCheck and not CanSee(target.Character, myRoot) then
        Notify("Wall Detected", "Murderer is behind a wall.", "shield")
        return
    end
    if (myRoot.Position - tHRP.Position).Magnitude > 300 then
        Notify("Too Far", "Gun only reaches 300 studs.", "x")
        return
    end
    local gun = M.Character and M.Character:FindFirstChild("Gun")
    if not gun then
        local bp = Player.Backpack and Player.Backpack:FindFirstChild("Gun")
        if bp and M.Humanoid then
            pcall(function() M.Humanoid:EquipTool(bp) end)
            task.wait(0.1)
            gun = M.Character and M.Character:FindFirstChild("Gun")
        end
    end
    if not gun then return end
    local shoot = gun:FindFirstChild("Shoot")
    if shoot and shoot:IsA("RemoteEvent") then
        local attach = myRoot:FindFirstChild("GunRaycastAttachment")
        local fromCF = attach and attach.WorldCFrame or CFrame.new(myRoot.Position)
        shoot:FireServer(fromCF, CFrame.new(PredictPos(target)))
        return
    end
    local kl = gun:FindFirstChild("KnifeLocal")
    local cb = kl and kl:FindFirstChild("CreateBeam")
    local rf = cb and cb:FindFirstChild("RemoteFunction")
    if rf and typeof(rf.InvokeServer) == "function" then
        pcall(function() rf:InvokeServer(1, PredictPos(target), "AH2") end)
    end
end

do
    local _asConn
    function M.SetAutoShoot(v)
        M.Cfg.AutoShootMurderer = v
        if _asConn then _asConn:Disconnect() _asConn = nil end
        if not v then return end
        _asConn = AddConn(RunService.Heartbeat:Connect(function()
            if M.Cfg.AutoShootMurderer and M.FindSheriff() == Player then
                pcall(M.ShootMurderer)
            end
        end))
    end
end

-- ════════════════════════════════════
-- THROW KNIFE
-- ════════════════════════════════════
local throwCooldown = false
function M.ThrowKnife(target)
    if throwCooldown then return end
    throwCooldown = true
    task.delay(0.6, function() throwCooldown = false end)

    target = target or NearestPlayer()
    if not target or not target.Character then
        Notify("No Target", "No player nearby to throw at.", "x")
        return
    end
    local knife = M.Character and M.Character:FindFirstChild("Knife")
    if not knife then
        local bp = Player.Backpack and Player.Backpack:FindFirstChild("Knife")
        if bp and M.Humanoid then
            pcall(function() M.Humanoid:EquipTool(bp) end)
            task.wait(0.1)
            knife = M.Character and M.Character:FindFirstChild("Knife")
        end
    end
    if not knife then return end
    local rightHand = M.Character:FindFirstChild("RightHand") or M.RootPart
    if not rightHand then return end
    local tHRP = target.Character:FindFirstChild("HumanoidRootPart")
    if not tHRP then return end
    if M.Cfg.WallCheck and not CanSee(target.Character, rightHand) then
        Notify("Wall Detected", target.Name .. " is behind a wall.", "shield")
        return
    end
    local aimPos = PredictPos(target)
    local throw = knife:FindFirstChild("Throw")
        or (knife:FindFirstChild("Events") and knife.Events:FindFirstChild("KnifeThrown"))
    if throw and throw:IsA("RemoteEvent") then
        throw:FireServer(CFrame.new(rightHand.Position), CFrame.new(aimPos))
        pcall(function()
            local animator = M.Humanoid and M.Humanoid:FindFirstChildOfClass("Animator")
            local anim = knife:FindFirstChild("ThrowKnife", true)
            if animator and anim then animator:LoadAnimation(anim):Play(0.1, 6, 1) end
        end)
        return
    end
    local kl = knife:FindFirstChild("KnifeLocal")
    local cb = kl and kl:FindFirstChild("CreateBeam")
    local rf = cb and cb:FindFirstChild("RemoteFunction")
    if rf and typeof(rf.InvokeServer) == "function" then
        pcall(function() rf:InvokeServer(1, aimPos, "AH2") end)
    end
end

do
    local _stConn
    function M.SetSilentThrow(v)
        M.Cfg.SilentThrow = v
        if _stConn then _stConn:Disconnect() _stConn = nil end
        if not v then return end
        _stConn = AddConn(RunService.Heartbeat:Connect(function()
            if M.Cfg.SilentThrow then
                pcall(M.ThrowKnife)
                task.wait(0.5)
            end
        end))
    end
end

-- ════════════════════════════════════
-- GRAB GUN
-- ════════════════════════════════════
function M.GrabGun()
    local root = M.RootPart
    if not root then return end
    for _, o in ipairs(Workspace:GetDescendants()) do
        if o.Name == "GunDrop" and o.Parent then
            local function tryGrab(part)
                if part:IsA("BasePart") then
                    if firetouchinterest and part:FindFirstChild("TouchInterest") then
                        firetouchinterest(part, root, 1)
                        firetouchinterest(part, root, 0)
                        return true
                    else
                        local old = root.CFrame
                        root.CFrame = part.CFrame
                        task.wait(0.1)
                        root.CFrame = old
                        return true
                    end
                end
            end
            if tryGrab(o) then return end
            for _, d in ipairs(o:GetDescendants()) do if tryGrab(d) then return end end
        end
    end
end

do
    local _ggConn
    function M.SetAutoGrabGun(v)
        M.Cfg.AutoGrabGun = v
        if _ggConn then _ggConn:Disconnect() _ggConn = nil end
        if v then _ggConn = AddConn(RunService.Heartbeat:Connect(M.GrabGun)) end
    end
end

-- ════════════════════════════════════
-- KILL ALL / KNIFE AURA
-- ════════════════════════════════════
function M.KillAll()
    if not M.Backpack or not M.Character or not M.Humanoid then return end
    local knife = M.Backpack:FindFirstChild("Knife") or M.Character:FindFirstChild("Knife")
    if not knife then return end
    if knife.Parent == M.Backpack then
        M.Humanoid:EquipTool(knife); task.wait(0.1)
        knife = M.Character:FindFirstChild("Knife")
    end
    if not knife then return end
    local ev = knife:FindFirstChild("Events")
    local stabbed = ev and ev:FindFirstChild("KnifeStabbed")
    local touched = ev and ev:FindFirstChild("HandleTouched")
    if stabbed and touched then
        pcall(function() stabbed:FireServer() end)
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= Player and p.Character then
                local r = p.Character:FindFirstChild("HumanoidRootPart")
                if r then pcall(function() touched:FireServer(r) end) end
                task.wait(0.08)
            end
        end
        return
    end
    local handle = knife:FindFirstChild("Handle")
    local stab = knife:FindFirstChild("Stab")
    if knife:IsA("Tool") then
        knife.Parent = M.Character
        for _, p in ipairs(Players:GetPlayers()) do
            local er = p.Character and (p.Character:FindFirstChild("HumanoidRootPart") or p.Character.PrimaryPart)
            if p ~= Player and er and handle and firetouchinterest then
                firetouchinterest(handle, er, 1)
                firetouchinterest(handle, er, 0)
                if stab and typeof(stab.FireServer) == "function" then stab:FireServer(er.Position) end
                task.wait(0.08)
            end
        end
    end
end

do
    local _akConn
    function M.SetAutoKill(v)
        M.Cfg.AutoKill = v
        if _akConn then _akConn:Disconnect() _akConn = nil end
        if v then
            _akConn = AddConn(RunService.Heartbeat:Connect(function()
                if M.Cfg.AutoKill and M.Backpack and M.Character then
                    local k = M.Backpack:FindFirstChild("Knife") or M.Character:FindFirstChild("Knife")
                    if k then pcall(M.KillAll) end
                end
            end))
        end
    end
end

do
    local _kaConn
    function M.SetKnifeAura(v)
        M.Cfg.KnifeAura = v
        if _kaConn then _kaConn:Disconnect() _kaConn = nil end
        if not v then return end
        _kaConn = AddConn(RunService.Heartbeat:Connect(function()
            local knife = M.Character and M.Character:FindFirstChild("Knife")
            if not knife or not knife:IsA("Tool") or knife.Parent ~= M.Character then return end
            local ev = knife:FindFirstChild("Events")
            local stabbed = ev and ev:FindFirstChild("KnifeStabbed")
            local touched = ev and ev:FindFirstChild("HandleTouched")
            local handle = knife:FindFirstChild("Handle")
            local stab = knife:FindFirstChild("Stab")
            if not M.RootPart then return end
            local range = math.max(1, tonumber(M.Cfg.AuraRadius) or 10)
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= Player and p.Character then
                    local hum = p.Character:FindFirstChildOfClass("Humanoid")
                    if hum and hum.Health > 0 then
                        local r = p.Character:FindFirstChild("HumanoidRootPart")
                        if r and (r.Position - M.RootPart.Position).Magnitude <= range then
                            if stabbed and touched then
                                pcall(function() stabbed:FireServer() end)
                                pcall(function() touched:FireServer(r) end)
                            elseif handle and firetouchinterest then
                                firetouchinterest(handle, r, 1)
                                firetouchinterest(handle, r, 0)
                                if stab and typeof(stab.FireServer) == "function" then stab:FireServer(r.Position) end
                            end
                            break
                        end
                    end
                end
            end
        end))
    end
end

-- ════════════════════════════════════
-- AIMBOT
-- ════════════════════════════════════
do
    local _abConn
    function M.SetAimbot(v)
        M.Cfg.AimbotEnabled = v
        if _abConn then _abConn:Disconnect() _abConn = nil end
        if not v then return end
        _abConn = AddConn(RunService.RenderStepped:Connect(function()
            if not M.Cfg.AimbotEnabled or not M.Character then return end
            local best, bestDist = nil, math.huge
            local center = Camera.ViewportSize / 2
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= Player and p.Character then
                    local hum = p.Character:FindFirstChildOfClass("Humanoid")
                    if hum and hum.Health > 0 then
                        local head = p.Character:FindFirstChild("Head") or p.Character:FindFirstChild("HumanoidRootPart")
                        if head then
                            local vp, inScreen = Camera:WorldToViewportPoint(head.Position)
                            if inScreen then
                                local dist = (Vector2.new(vp.X, vp.Y) - center).Magnitude
                                if dist <= M.Cfg.AimbotFov and dist < bestDist then
                                    if M.Cfg.AimbotMurdererOnly then
                                        if M.FindMurderer() == p then bestDist = dist; best = p end
                                    else
                                        bestDist = dist; best = p
                                    end
                                end
                            end
                        end
                    end
                end
            end
            if not best then return end
            if M.Cfg.WallCheckAimbot then
                local myRoot = M.RootPart
                if myRoot and not CanSee(best.Character, myRoot) then return end
            end
            local aimPos = PredictPos(best)
            pcall(function()
                Camera.CFrame = Camera.CFrame:Lerp(
                    CFrame.new(Camera.CFrame.Position, aimPos),
                    math.clamp(M.Cfg.AimbotSmooth, 0.01, 1)
                )
            end)
        end))
    end
end

-- ════════════════════════════════════
-- ESP
-- ════════════════════════════════════
do
    local function GetRole(p)
        if M.FindMurderer() == p then return "Murderer", Color3.fromRGB(255,60,60) end
        if M.FindSheriff() == p then return "Sheriff", Color3.fromHex("#4FC3F7") end
        local d = M.PlayerData[p.Name]
        if d and (d.Role == "Hero" or d.role == "Hero") then return "Hero", Color3.fromHex("#FFD700") end
        return "Innocent", Color3.fromRGB(100,255,100)
    end

    local espConn
    function M.SetEsp(v)
        M.Cfg.EspPlayers = v
        if espConn then espConn:Disconnect() espConn = nil end
        if not v and not M.Cfg.ShowNames then
            for _, p in ipairs(Players:GetPlayers()) do
                if p.Character then
                    local h = p.Character:FindFirstChild("UnicornHL")
                    if h then h:Destroy() end
                    local hd = p.Character:FindFirstChild("Head")
                    if hd then local n = hd:FindFirstChild("UnicornName"); if n then n:Destroy() end end
                end
            end
            return
        end
        espConn = AddConn(RunService.Heartbeat:Connect(function()
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= Player and p.Character then
                    local role, color = GetRole(p)
                    if M.Cfg.EspPlayers then
                        local h = p.Character:FindFirstChild("UnicornHL") or Instance.new("Highlight")
                        h.Name = "UnicornHL"
                        h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                        h.FillTransparency = 0.5; h.OutlineTransparency = 0
                        h.FillColor = color; h.OutlineColor = color
                        h.Parent = p.Character
                    else
                        local h = p.Character:FindFirstChild("UnicornHL"); if h then h:Destroy() end
                    end
                    local head = p.Character:FindFirstChild("Head")
                    if head then
                        if M.Cfg.ShowNames then
                            local bg = head:FindFirstChild("UnicornName") or Instance.new("BillboardGui")
                            bg.Name = "UnicornName"; bg.Adornee = head
                            bg.Size = UDim2.new(0,220,0,55); bg.StudsOffset = Vector3.new(0,3.2,0)
                            bg.AlwaysOnTop = true; bg.Parent = head
                            local lbl = bg:FindFirstChildOfClass("TextLabel") or Instance.new("TextLabel")
                            lbl.BackgroundTransparency = 1; lbl.Size = UDim2.new(1,0,1,0)
                            lbl.TextSize = 15; lbl.Font = Enum.Font.GothamBold
                            lbl.TextColor3 = color; lbl.TextStrokeTransparency = 0
                            lbl.TextStrokeColor3 = Color3.new(0,0,0)
                            lbl.Text = p.Name .. "\n[" .. role .. "]"; lbl.Parent = bg
                        else
                            local n = head:FindFirstChild("UnicornName"); if n then n:Destroy() end
                        end
                    end
                end
            end
        end))
    end
    function M.SetNames(v) M.Cfg.ShowNames = v; M.SetEsp(M.Cfg.EspPlayers) end

    local gunEspConn
    function M.SetGunEsp(v)
        M.Cfg.GunEsp = v
        if gunEspConn then gunEspConn:Disconnect() gunEspConn = nil end
        for _, o in ipairs(Workspace:GetDescendants()) do if o.Name == "UnicornGunHL" then o:Destroy() end end
        if not v then return end
        gunEspConn = AddConn(RunService.Heartbeat:Connect(function()
            for _, o in ipairs(Workspace:GetDescendants()) do
                if o.Name == "GunDrop" and o:IsA("BasePart") and not o:FindFirstChild("UnicornGunHL") then
                    local sb = Instance.new("SelectionBox")
                    sb.Name = "UnicornGunHL"; sb.Adornee = o
                    sb.Color3 = Color3.fromHex("#CF9FFF"); sb.LineThickness = 0.07
                    sb.SurfaceTransparency = 0.7; sb.SurfaceColor3 = Color3.fromHex("#CF9FFF")
                    sb.Parent = o
                end
            end
        end))
    end
end

-- ════════════════════════════════════
-- CUSTOM CROSSHAIR
-- ════════════════════════════════════
local CrosshairGui = nil

local function DestroyCrosshair()
    if CrosshairGui then CrosshairGui:Destroy() CrosshairGui = nil end
end

local function BuildCrosshair()
    DestroyCrosshair()
    if not M.Cfg.CrosshairEnabled then return end

    CrosshairGui = Instance.new("ScreenGui")
    CrosshairGui.Name = "UnicornCrosshair"
    CrosshairGui.ResetOnSpawn = false
    CrosshairGui.IgnoreGuiInset = true
    CrosshairGui.DisplayOrder = 999
    CrosshairGui.Parent = GuiParent

    local shape  = M.Cfg.CrosshairShape
    local color  = M.Cfg.CrosshairColor
    local sz     = M.Cfg.CrosshairSize
    local thick  = M.Cfg.CrosshairThick

    local function MakePart(x, y, w, h)
        local f = Instance.new("Frame")
        f.AnchorPoint = Vector2.new(0.5, 0.5)
        f.Position = UDim2.new(0.5, x, 0.5, y)
        f.Size = UDim2.fromOffset(w, h)
        f.BackgroundColor3 = color
        f.BorderSizePixel = 0
        f.Parent = CrosshairGui
        return f
    end

    if shape == "Cross" then
        MakePart(0, 0, sz, thick)
        MakePart(0, 0, thick, sz)
    elseif shape == "Dot" then
        local dot = MakePart(0, 0, thick*2, thick*2)
        Instance.new("UICorner", dot).CornerRadius = UDim.new(1,0)
    elseif shape == "Circle" then
        local circle = Instance.new("Frame")
        circle.AnchorPoint = Vector2.new(0.5,0.5)
        circle.Position = UDim2.new(0.5,0,0.5,0)
        circle.Size = UDim2.fromOffset(sz, sz)
        circle.BackgroundTransparency = 1
        circle.Parent = CrosshairGui
        Instance.new("UICorner", circle).CornerRadius = UDim.new(1,0)
        local stroke = Instance.new("UIStroke", circle)
        stroke.Color = color; stroke.Thickness = thick
    elseif shape == "Square" then
        local half = sz / 2
        local len = sz / 3
        MakePart(-half + len/2, -half, len, thick)
        MakePart(-half, -half + len/2, thick, len)
        MakePart(half - len/2, -half, len, thick)
        MakePart(half, -half + len/2, thick, len)
        MakePart(-half + len/2, half, len, thick)
        MakePart(-half, half - len/2, thick, len)
        MakePart(half - len/2, half, len, thick)
        MakePart(half, half - len/2, thick, len)
    elseif shape == "X" then
        local function XBar(rot)
            local f = Instance.new("Frame")
            f.AnchorPoint = Vector2.new(0.5,0.5)
            f.Position = UDim2.new(0.5,0,0.5,0)
            f.Size = UDim2.fromOffset(sz, thick)
            f.BackgroundColor3 = color
            f.BorderSizePixel = 0
            f.Rotation = rot
            f.Parent = CrosshairGui
        end
        XBar(45); XBar(-45)
    end
end

-- ════════════════════════════════════
-- NOTIFICATIONS
-- ════════════════════════════════════
do
    local notTask
    local notM, notS = false, false

    local function RoleLoop()
        while true do
            local ok, secs = pcall(function()
                return ReplicatedStorage.Remotes.Extras.GetTimer:InvokeServer()
            end)
            if not ok or (type(secs) == "number" and secs <= 1) then
                notM = false; notS = false
            elseif ok and type(secs) == "number" and secs > 1 then
                if M.Cfg.NotifyMurderer and not notM then
                    local p = M.FindMurderer()
                    if p then notM = true; Notify("Murderer Detected!", p.Name, "skull") end
                end
                if M.Cfg.NotifySheriff and not notS then
                    local p = M.FindSheriff()
                    if p then notS = true; Notify("Sheriff Detected!", p.Name, "shield") end
                end
            end
            task.wait(1)
        end
    end

    function M.UpdateRoleNotify()
        if notTask then pcall(task.cancel, notTask) notTask = nil end
        if M.Cfg.NotifyMurderer or M.Cfg.NotifySheriff then notTask = task.spawn(RoleLoop) end
    end
end

do
    local _ngConn, _lastGun
    function M.SetNotifyGun(v)
        M.Cfg.NotifyGunDropped = v
        if _ngConn then _ngConn:Disconnect() _ngConn = nil end
        _lastGun = nil
        if not v then return end
        _ngConn = AddConn(RunService.Heartbeat:Connect(function()
            for _, o in ipairs(Workspace:GetDescendants()) do
                if o.Name == "GunDrop" and o:IsA("BasePart") and o ~= _lastGun then
                    _lastGun = o
                    Notify("Gun Dropped!", "A gun appeared on the map.", "crosshair")
                    return
                end
            end
        end))
    end
end

-- ════════════════════════════════════
-- CHAT ROLES & SERVER UTILS
-- ════════════════════════════════════
function M.ChatRoles()
    local murderer = M.FindMurderer()
    local sheriff  = M.FindSheriff()
    local msg = ""
    if murderer then msg = msg .. "Murderer: " .. murderer.Name .. " " end
    if sheriff  then msg = msg .. "Sheriff: " .. sheriff.Name end
    if msg == "" then msg = "No roles detected yet!" end
    pcall(function()
        local ts = game:GetService("TextChatService")
        local ch = ts.TextChannels:FindFirstChild("RBXGeneral")
        if ch then ch:SendAsync(msg) end
    end)
end

function M.Rejoin()
    if M.Cfg.AutoQueue and M.Cfg.QueueUrl ~= "" then queue_on_teleport(M.Cfg.QueueUrl) end
    pcall(function() TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, Player) end)
end

function M.ServerHop()
    if M.Cfg.AutoQueue and M.Cfg.QueueUrl ~= "" then queue_on_teleport(M.Cfg.QueueUrl) end
    local ok, r = pcall(function()
        return HttpService:JSONDecode(game:HttpGet(
            "https://games.roblox.com/v1/games/"..game.PlaceId.."/servers/Public?sortOrder=Asc&limit=100"
        ))
    end)
    if ok and r and r.data then
        for _, sv in ipairs(r.data) do
            if sv.id ~= game.JobId and sv.playing < sv.maxPlayers then
                TeleportService:TeleportToPlaceInstance(game.PlaceId, sv.id, Player); return
            end
        end
    end
    TeleportService:Teleport(game.PlaceId, Player)
end

-- ════════════════════════════════════
-- TELEPORTS
-- ════════════════════════════════════
function M.TpToPlayer(target)
    if not M.RootPart or not target or not target.Character then return end
    pcall(function() M.Character:PivotTo(target.Character:GetPivot() * CFrame.new(0,3,0)) end)
end
function M.TpToMurderer() M.TpToPlayer(M.FindMurderer()) end
function M.TpToSheriff()  M.TpToPlayer(M.FindSheriff()) end

function M.TpToMap()
    local map = GetMap(); if not map then return end
    local spawns = map:FindFirstChild("Spawns"); if not spawns then return end
    local list = {}
    for _, v in ipairs(spawns:GetChildren()) do if v:IsA("BasePart") then table.insert(list,v) end end
    local sp = #list > 0 and list[math.random(1,#list)] or spawns:FindFirstChild("Spawn")
    if sp and sp:IsA("BasePart") and M.Character then M.Character:PivotTo(sp.CFrame * CFrame.new(0,5,0)) end
end

function M.TpToLobby()
    local lobby = GetLobby(); if not lobby then return end
    local spawns = lobby:FindFirstChild("Spawns"); if not spawns then return end
    local list = {}
    for _, v in ipairs(spawns:GetChildren()) do if v:IsA("BasePart") then table.insert(list,v) end end
    local sp = #list > 0 and list[math.random(1,#list)] or spawns:FindFirstChild("SpawnLocation")
    if sp and sp:IsA("BasePart") and M.Character then M.Character:PivotTo(sp.CFrame * CFrame.new(0,5,0)) end
end

-- ════════════════════════════════════
-- HUD BUTTONS (INDEPENDENT POSITIONS)
-- ════════════════════════════════════
local HUD = {}
HUD.buttons = {}
HUD.savedPositions = {} -- Saves each button's last dragged position
HUD.locked  = false

local HUD_ICONS = {
    Shoot   = "rbxassetid://134242818164054",
    Throw   = "rbxassetid://124448418211665",
    Grab    = "rbxassetid://130703864968637",
    KillAll = "rbxassetid://137726256442333",
    Aimbot  = "rbxassetid://87563802520297",
    Fly     = "rbxassetid://126985561580989",
    Noclip  = "rbxassetid://113822048130017",
}

local function HudTween(obj, props)
    TweenService:Create(obj, TweenInfo.new(0.12, Enum.EasingStyle.Quad), props):Play()
end

function HUD.Create(name, label, accent, iconId, defaultPos, callback)
    if HUD.buttons[name] then return end

    local sg = Instance.new("ScreenGui")
    sg.Name = "UnicornBtn_" .. name
    sg.ResetOnSpawn = false; sg.IgnoreGuiInset = true; sg.Parent = GuiParent

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.fromOffset(TILE * HUD_SCALE, TILE * HUD_SCALE)
    -- Use saved position if previously dragged, otherwise use its dedicated defaultPos
    btn.Position = HUD.savedPositions[name] or defaultPos
    btn.AnchorPoint = Vector2.new(0.5, 0.5)
    btn.Text = ""; btn.AutoButtonColor = false
    btn.BackgroundColor3 = Color3.fromRGB(10,10,13)
    btn.BackgroundTransparency = 0.18
    btn.BorderSizePixel = 0; btn.ZIndex = 2
    btn.Parent = sg
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 14)

    local stroke = Instance.new("UIStroke", btn)
    stroke.Thickness = 1.5; stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    stroke.Color = accent; stroke.Transparency = 0.15

    local plate = Instance.new("Frame", btn)
    plate.Size = UDim2.fromOffset(32, 32)
    plate.Position = UDim2.new(0.5, 0, 0, math.floor(TILE * HUD_SCALE * 0.26))
    plate.AnchorPoint = Vector2.new(0.5, 0.5)
    plate.BackgroundColor3 = accent; plate.BackgroundTransparency = 0.65
    plate.BorderSizePixel = 0; plate.ZIndex = 3
    Instance.new("UICorner", plate).CornerRadius = UDim.new(0, 9)

    local icon = Instance.new("ImageLabel", plate)
    icon.Size = UDim2.fromOffset(20, 20)
    icon.Position = UDim2.fromScale(0.5, 0.5); icon.AnchorPoint = Vector2.new(0.5, 0.5)
    icon.BackgroundTransparency = 1
    icon.Image = iconId or ""; icon.ImageColor3 = Color3.fromRGB(220, 220, 240)
    icon.ZIndex = 5

    local lbl = Instance.new("TextLabel", btn)
    lbl.Size = UDim2.new(1, -6, 0, 22)
    lbl.Position = UDim2.new(0.5, 0, 1, -4); lbl.AnchorPoint = Vector2.new(0.5, 1)
    lbl.BackgroundTransparency = 1
    lbl.Text = label; lbl.TextSize = IS_MOBILE and 8 or 9
    lbl.Font = Enum.Font.GothamBold; lbl.TextColor3 = Color3.fromRGB(146, 146, 158)
    lbl.TextWrapped = true; lbl.LineHeight = 1.1; lbl.ZIndex = 6

    local uiScale = Instance.new("UIScale", btn); uiScale.Scale = 1
    local dragging, dragStart, startPos, hasMoved = false, nil, nil, false

    btn.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.Touch or inp.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true; hasMoved = false
            dragStart = inp.Position; startPos = btn.Position
        end
    end)

    AddConn(UserInputService.InputChanged:Connect(function(inp)
        if not dragging or HUD.locked then return end
        if inp.UserInputType ~= Enum.UserInputType.Touch and inp.UserInputType ~= Enum.UserInputType.MouseMovement then return end
        if not btn.Parent then return end
        local delta = inp.Position - dragStart
        if not hasMoved then
            if math.abs(delta.X) + math.abs(delta.Y) < 6 then return end
            hasMoved = true
        end
        local newPos = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        btn.Position = newPos
        HUD.savedPositions[name] = newPos
    end))

    local function OnTap()
        if hasMoved then return end
        HudTween(uiScale, {Scale = 0.9})
        task.delay(0.1, function() if uiScale.Parent then HudTween(uiScale, {Scale = 1}) end end)
        task.spawn(callback)
    end

    btn.InputEnded:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.Touch or inp.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
            if not hasMoved then OnTap() end
        end
    end)

    btn.MouseButton1Click:Connect(function()
        if not IS_MOBILE then OnTap() end
    end)

    HUD.buttons[name] = { gui = sg, btn = btn, label = lbl, plate = plate, stroke = stroke, active = false }
end

function HUD.SetActive(name, active)
    local b = HUD.buttons[name]; if not b then return end
    b.active = active
    HudTween(b.stroke, {Transparency = active and 0 or 0.15})
    HudTween(b.label, {TextColor3 = active and Color3.fromRGB(240,240,246) or Color3.fromRGB(146,146,158)})
    HudTween(b.plate, {BackgroundTransparency = active and 0.3 or 0.65})
end

function HUD.SetLabel(name, text)
    local b = HUD.buttons[name]; if not b then return end
    b.label.Text = text
end

function HUD.Destroy(name)
    local b = HUD.buttons[name]; if not b then return end
    if b.btn and b.btn.Parent then
        HUD.savedPositions[name] = b.btn.Position
    end
    b.gui:Destroy(); HUD.buttons[name] = nil
end

-- ════════════════════════════════════
-- LOGO
-- ════════════════════════════════════
local function MakeLogo()
    local sg = Instance.new("ScreenGui")
    sg.Name = "UnicornLogo"; sg.ResetOnSpawn = false
    sg.IgnoreGuiInset = true; sg.DisplayOrder = 10
    sg.Parent = GuiParent

    local frame = Instance.new("Frame", sg)
    frame.Size = UDim2.fromOffset(120, 36)
    frame.Position = UDim2.fromOffset(10, 10)
    frame.BackgroundColor3 = Color3.fromHex("#0A0314")
    frame.BackgroundTransparency = 0.3
    frame.BorderSizePixel = 0
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 10)
    local stroke = Instance.new("UIStroke", frame)
    stroke.Color = Color3.fromHex("#CF9FFF"); stroke.Thickness = 1.2; stroke.Transparency = 0.3

    local lbl = Instance.new("TextLabel", frame)
    lbl.Size = UDim2.new(1,0,1,0)
    lbl.BackgroundTransparency = 1
    lbl.Text = "Unicorn Hub"
    lbl.TextColor3 = Color3.fromHex("#CF9FFF")
    lbl.Font = Enum.Font.GothamBold; lbl.TextSize = 14
    lbl.TextXAlignment = Enum.TextXAlignment.Center

    local ver = Instance.new("TextLabel", sg)
    ver.Size = UDim2.fromOffset(120, 14)
    ver.Position = UDim2.fromOffset(10, 48)
    ver.BackgroundTransparency = 1
    ver.Text = "MM2 | v2.1"
    ver.TextColor3 = Color3.fromHex("#7B6895")
    ver.Font = Enum.Font.Gotham; ver.TextSize = 11
    ver.TextXAlignment = Enum.TextXAlignment.Left
end
MakeLogo()

-- ════════════════════════════════════
-- WIND UI THEME & WINDOW
-- ════════════════════════════════════
pcall(function()
    WindUI:AddTheme({
        Name        = "Unicorn",
        Accent      = Color3.fromHex("#CF9FFF"),
        Dialog      = Color3.fromHex("#0E0518"),
        Outline     = Color3.fromHex("#E8D5FF"),
        Text        = Color3.fromHex("#F0E6FF"),
        Placeholder = Color3.fromHex("#7B6895"),
        Background  = Color3.fromHex("#0A0314"),
        Button      = Color3.fromHex("#1A0A2E"),
        Icon        = Color3.fromHex("#CF9FFF"),
    })
end)

local Window = WindUI:CreateWindow({
    Title    = "Unicorn Hub",
    Author   = "MM2",
    Folder   = "UnicornHub",
    Theme    = "Unicorn",
    Size     = UDim2.fromOffset(520, 340),
    Transparent = true,
    Resizable = true,
    OpenButton = {
        Title = "Unicorn Hub",
        CornerRadius = UDim.new(0, 14),
        StrokeThickness = 2,
        Enabled = true,
        Draggable = true,
        OnlyMobile = true,
        Color = ColorSequence.new(Color3.fromHex("#CF9FFF"), Color3.fromHex("#89F7FF"))
    }
})

-- TABS
local TabHome     = Window:Tab({Title="Home",     Icon="house"})
local TabMovement = Window:Tab({Title="Movement",  Icon="footprints"})
local TabCombat   = Window:Tab({Title="Combat",    Icon="swords"})
local TabVisuals  = Window:Tab({Title="Visuals",   Icon="eye"})
local TabTeleport = Window:Tab({Title="Teleport",  Icon="map-pin"})
local TabButtons  = Window:Tab({Title="HUD",       Icon="layout-grid"})
local TabMisc     = Window:Tab({Title="Misc",      Icon="box"})
local TabSettings = Window:Tab({Title="Settings",  Icon="settings"})

-- ══════════ HOME ══════════
do
    TabHome:Paragraph({
        Title = "Unicorn Hub — MM2",
        Desc  = "All features loaded. Tap the Unicorn Hub button to open/close.\nHUD tiles on screen keep their dragged positions.",
    })
    TabHome:Section({Title="Player Info", Icon="user", Opened=true})
    TabHome:Button({Title="Expose Roles in Chat", Desc="Posts murderer & sheriff names", Icon="message-circle", Callback=M.ChatRoles})
end

-- ══════════ MOVEMENT ══════════
do
    TabMovement:Section({Title="Movement", Icon="footprints", Opened=true})
    TabMovement:Toggle({Title="Enable WalkSpeed", Callback=M.SetWalkspeedEnabled})
    TabMovement:Slider({Title="Walk Speed", Value={Min=16,Max=300,Default=16}, Callback=M.SetWalkspeedVal})
    TabMovement:Toggle({Title="Enable Jump Power", Callback=M.SetJumppowerEnabled})
    TabMovement:Slider({Title="Jump Power", Value={Min=50,Max=500,Default=50}, Callback=M.SetJumppowerVal})
    TabMovement:Toggle({Title="Noclip", Desc="Walk through walls", Callback=M.SetNoclip})
    TabMovement:Toggle({Title="Infinite Jump", Callback=M.SetInfJump})
    TabMovement:Toggle({Title="Anti-Fling", Desc="Block fling attacks", Callback=M.SetAntiFling})
    TabMovement:Toggle({Title="Anti-AFK", Desc="Prevent idle kick", Callback=M.SetAntiAfk})
    TabMovement:Toggle({Title="Fly", Desc="Fly around the map", Callback=M.SetFly})
    TabMovement:Button({Title="Reset Character", Icon="refresh-cw", Callback=function()
        if M.Character then M.Character:BreakJoints() end
    end})
end

-- ══════════ COMBAT ══════════
do
    TabCombat:Section({Title="General Combat", Icon="backpack", Opened=true})
    TabCombat:Toggle({Title="God Mode", Desc="Prevent death", Callback=M.SetGodMode})
    TabCombat:Button({Title="Grab Gun", Desc="Pick up dropped gun", Icon="hand", Callback=M.GrabGun})
    TabCombat:Toggle({Title="Auto Grab Gun", Callback=M.SetAutoGrabGun})
    TabCombat:Toggle({Title="Wall Check", Desc="Block through-wall shots", Value=true,
        Callback=function(v) M.Cfg.WallCheck = v end})

    TabCombat:Section({Title="Murderer", Icon="skull", Opened=true})
    TabCombat:Button({Title="Kill All", Desc="Stab all players", Icon="skull", Callback=M.KillAll})
    TabCombat:Toggle({Title="Auto Kill All", Callback=M.SetAutoKill})
    TabCombat:Toggle({Title="Knife Aura", Desc="Kill nearby players automatically", Callback=M.SetKnifeAura})
    TabCombat:Slider({Title="Aura Radius", Value={Min=5,Max=150,Default=10},
        Callback=function(v) M.Cfg.AuraRadius = v end})
    TabCombat:Toggle({Title="Auto Throw Knife", Callback=M.SetSilentThrow})
    TabCombat:Button({Title="Throw Knife", Icon="crosshair", Callback=function() M.ThrowKnife() end})

    TabCombat:Section({Title="Sheriff & Aimbot", Icon="shield", Opened=true})
    TabCombat:Toggle({Title="Auto Shoot Murderer", Callback=M.SetAutoShoot})
    TabCombat:Button({Title="Shoot Murderer", Icon="crosshair", Callback=M.ShootMurderer})
    TabCombat:Toggle({Title="Aimbot (Camera Lock)", Callback=M.SetAimbot})
    TabCombat:Toggle({Title="Murderer Only Aim", Value=true,
        Callback=function(v) M.Cfg.AimbotMurdererOnly = v end})
    TabCombat:Toggle({Title="Aimbot Wall Check", Value=true,
        Callback=function(v) M.Cfg.WallCheckAimbot = v end})
    TabCombat:Slider({Title="Aimbot Smooth", Value={Min=1,Max=100,Default=20},
        Callback=function(v) M.Cfg.AimbotSmooth = v / 100 end})
    TabCombat:Slider({Title="Aimbot FOV", Value={Min=20,Max=400,Default=120},
        Callback=function(v) M.Cfg.AimbotFov = v end})
end

-- ══════════ VISUALS ══════════
do
    TabVisuals:Section({Title="ESP & Notifications", Icon="eye", Opened=true})
    TabVisuals:Toggle({Title="Player ESP", Desc="See players through walls", Callback=M.SetEsp})
    TabVisuals:Toggle({Title="Player Names", Desc="Show name + role above heads", Callback=M.SetNames})
    TabVisuals:Toggle({Title="Dropped Gun ESP", Callback=M.SetGunEsp})
    TabVisuals:Toggle({Title="Notify: Murderer Appears",
        Callback=function(v) M.Cfg.NotifyMurderer = v; M.UpdateRoleNotify() end})
    TabVisuals:Toggle({Title="Notify: Sheriff Appears",
        Callback=function(v) M.Cfg.NotifySheriff = v; M.UpdateRoleNotify() end})
    TabVisuals:Toggle({Title="Notify: Gun Dropped", Callback=M.SetNotifyGun})

    TabVisuals:Section({Title="Custom Crosshair", Icon="crosshair", Opened=true})
    TabVisuals:Toggle({Title="Enable Crosshair",
        Callback=function(v) M.Cfg.CrosshairEnabled = v; BuildCrosshair() end})
    TabVisuals:Dropdown({Title="Shape",
        Values={"Cross","Dot","Circle","Square","X"}, Value="Cross",
        Callback=function(v) M.Cfg.CrosshairShape = v; BuildCrosshair() end})
    TabVisuals:Slider({Title="Size", Value={Min=10,Max=60,Default=20},
        Callback=function(v) M.Cfg.CrosshairSize = v; BuildCrosshair() end})
    TabVisuals:Slider({Title="Thickness", Value={Min=1,Max=8,Default=2},
        Callback=function(v) M.Cfg.CrosshairThick = v; BuildCrosshair() end})
    TabVisuals:Colorpicker({Title="Color", Default=Color3.fromHex("#CF9FFF"),
        Callback=function(v) M.Cfg.CrosshairColor = v; BuildCrosshair() end})
end

-- ══════════ TELEPORT ══════════
do
    TabTeleport:Section({Title="Quick Teleport", Icon="map-pin", Opened=true})
    TabTeleport:Button({Title="Teleport to Map",    Icon="map",    Callback=M.TpToMap})
    TabTeleport:Button({Title="Teleport to Lobby",  Icon="home",   Callback=M.TpToLobby})
    TabTeleport:Button({Title="Teleport to Murderer", Icon="skull", Callback=M.TpToMurderer})
    TabTeleport:Button({Title="Teleport to Sheriff",  Icon="shield", Callback=M.TpToSheriff})

    local selP = nil
    local pVals = {}
    local function RefreshPDrop()
        pVals = {}
        for _, p in ipairs(Players:GetPlayers()) do if p ~= Player then table.insert(pVals, p.Name) end end
    end
    RefreshPDrop()
    local pDrop = TabTeleport:Dropdown({Title="Select Player", Values=pVals,
        Callback=function(v) selP = Players:FindFirstChild(v) end})
    TabTeleport:Button({Title="Teleport to Selected Player", Icon="user", Callback=function()
        if selP then M.TpToPlayer(selP) end
    end})
    AddConn(Players.PlayerAdded:Connect(function() RefreshPDrop(); pcall(function() pDrop:Refresh(pVals) end) end))
    AddConn(Players.PlayerRemoving:Connect(function() RefreshPDrop(); pcall(function() pDrop:Refresh(pVals) end) end))
end

-- ══════════ HUD BUTTONS TAB ══════════
do
    TabButtons:Section({Title="HUD Tiles", Icon="layout-grid", Opened=true})

    local function HudToggle(title, name, accent, iconId, defaultPos, activateCallback)
        TabButtons:Toggle({Title="Show " .. title .. " Button",
            Callback=function(v)
                if v then
                    HUD.Create(name, title:upper():gsub(" ", "\n"), accent, iconId, defaultPos, activateCallback)
                else
                    HUD.Destroy(name)
                end
            end})
    end

    HudToggle("Shoot Murder", "Shoot", HUD_COL.Shoot,   HUD_ICONS.Shoot,
        UDim2.new(0.20, 0, 0.72, 0), M.ShootMurderer)
    HudToggle("Throw Knife",  "Throw", HUD_COL.Throw,   HUD_ICONS.Throw,
        UDim2.new(0.32, 0, 0.72, 0), function() M.ThrowKnife() end)
    HudToggle("Grab Gun",     "Grab",  HUD_COL.Grab,    HUD_ICONS.Grab,
        UDim2.new(0.44, 0, 0.72, 0), M.GrabGun)
    HudToggle("Kill All",     "KillAll",HUD_COL.KillAll,HUD_ICONS.KillAll,
        UDim2.new(0.56, 0, 0.72, 0), M.KillAll)
    HudToggle("Aimbot",       "Aimbot",HUD_COL.Aimbot,  HUD_ICONS.Aimbot,
        UDim2.new(0.68, 0, 0.72, 0), function()
            M.Cfg.AimbotEnabled = not M.Cfg.AimbotEnabled
            M.SetAimbot(M.Cfg.AimbotEnabled)
            HUD.SetActive("Aimbot", M.Cfg.AimbotEnabled)
            HUD.SetLabel("Aimbot", M.Cfg.AimbotEnabled and "AIMBOT\nON" or "AIMBOT\nOFF")
        end)
    HudToggle("Fly",          "Fly",   HUD_COL.Fly,     HUD_ICONS.Fly,
        UDim2.new(0.80, 0, 0.72, 0), function()
            M.Cfg.Fly = not M.Cfg.Fly; M.SetFly(M.Cfg.Fly)
            HUD.SetActive("Fly", M.Cfg.Fly)
        end)
    HudToggle("Noclip",       "Noclip",HUD_COL.Noclip,  HUD_ICONS.Noclip,
        UDim2.new(0.20, 0, 0.85, 0), function()
            M.Cfg.Noclip = not M.Cfg.Noclip; M.SetNoclip(M.Cfg.Noclip)
            HUD.SetActive("Noclip", M.Cfg.Noclip)
        end)

    TabButtons:Toggle({Title="Lock Buttons in Place", Desc="Prevents dragging tiles",
        Callback=function(v) HUD.locked = v end})
end

-- ══════════ MISC ══════════
do
    TabMisc:Section({Title="Fling", Icon="wind", Opened=true})
    TabMisc:Button({Title="Fling Murderer", Icon="skull",   Callback=M.FlingMurderer})
    TabMisc:Button({Title="Fling Sheriff",  Icon="shield",  Callback=M.FlingSheriff})
    TabMisc:Button({Title="Fling All",      Icon="wind",    Callback=M.FlingAll})

    local selF = nil
    local fVals = {}
    local function RefreshFVals()
        fVals = {}
        for _, p in ipairs(Players:GetPlayers()) do if p ~= Player then table.insert(fVals, p.Name) end end
    end
    RefreshFVals()
    local fDrop = TabMisc:Dropdown({Title="Select Player", Values=fVals,
        Callback=function(v) selF = Players:FindFirstChild(v) end})
    TabMisc:Button({Title="Fling Selected Player", Icon="wind", Callback=function()
        if selF then pcall(Fling, selF) end
    end})
    AddConn(Players.PlayerAdded:Connect(function() RefreshFVals(); pcall(function() fDrop:Refresh(fVals) end) end))
    AddConn(Players.PlayerRemoving:Connect(function() RefreshFVals(); pcall(function() fDrop:Refresh(fVals) end) end))

    TabMisc:Section({Title="Emotes", Icon="star", Opened=true})
    local emotes = {"sit","zombie","ninja","zen","floss","dab","wave","cheer"}
    local selE = nil
    TabMisc:Dropdown({Title="Select Emote", Values=emotes,
        Callback=function(v) selE = v end})
    TabMisc:Button({Title="Play Emote", Icon="play", Callback=function()
        if selE then
            pcall(function()
                local ts = game:GetService("TextChatService")
                local ch = ts.TextChannels:FindFirstChild("RBXGeneral")
                if ch then ch:SendAsync("/e " .. selE) end
            end)
        end
    end})
end

-- ══════════ SETTINGS ══════════
do
    TabSettings:Section({Title="Server & UI", Icon="settings", Opened=true})
    TabSettings:Button({Title="Rejoin Server", Icon="refresh-cw", Callback=M.Rejoin})
    TabSettings:Button({Title="Server Hop", Icon="shuffle", Callback=M.ServerHop})
    TabSettings:Toggle({Title="UI Transparency",
        Callback=function(v) pcall(function() Window:ToggleTransparency(v) end) end})
end

-- ════════════════════════════════════
-- DONE
-- ════════════════════════════════════
pcall(function() Window:SelectTab(1) end)
Notify("Unicorn Hub", "Loaded successfully", "sparkles")
