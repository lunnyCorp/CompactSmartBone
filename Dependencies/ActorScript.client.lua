-- // Types \\ --

type dictionary = { [string]: any }
type array = { [number]: any }
local ActorModule = {}
ActorModule.__index = ActorModule

-- // Services \\ --

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- // Dependencies \\ --

local Paths = {
	ReplicatedStorage,
	Players.LocalPlayer:WaitForChild("PlayerScripts"),
}
local Require = getgenv().sharedRequire
local mrp = 'https://raw.githubusercontent.com/LARTAJE/CompactSmartBone/refs/heads/main/'

local Config = Require(mrp..'Dependencies/Config.lua')

local SmartBone = Require(mrp..'init.lua')
local CameraUtil = Require(mrp..'Dependencies/CameraUtil.lua')

local DEBUG = Config.Debug

local timeFunc = os.clock
local oldTime = timeFunc()
local frameRate = 60
local frameRateTable = {}

--[[ Local Functions ]] --

local round = 1000

local function roundNumber(num)
	return  math.floor((num * round) + 0.5) / round
end

local function smoothDelta()
	local currentTime = timeFunc()

	for index = #frameRateTable,1,-1 do
		frameRateTable[index + 1] = (frameRateTable[index] >= currentTime - 1) and frameRateTable[index] or nil
	end

	frameRateTable[1] = currentTime
	frameRate =  math.floor((timeFunc() - oldTime >= 1 and #frameRateTable) or (#frameRateTable / (timeFunc() - oldTime)))

	return roundNumber(frameRate * ((1/frameRate)^2) + .001)
end

local Connection = nil
function ActorModule.Initialize(Object: BasePart, RootList: array)
	local SBone = SmartBone.new(Object, RootList)

	local frameTime = 0
	Connection = RunService.PostSimulation:Connect(function(Delta: number)
		Delta = smoothDelta()
		frameTime += Delta

		local camPosition = workspace.CurrentCamera.CFrame.Position
		local rootPosition = SBone.RootPart.Position
		local distance = (camPosition - rootPosition).Magnitude
		local activationDistance = SBone.Settings.ActivationDistance
		
		local UpdateRate = distance > 30 and 15 and distance > 15 and 30 or frameTime --Hardfix

		local WithinViewport = CameraUtil.WithinViewport(SBone.RootPart)
		if frameTime >= (1/UpdateRate) then
			if distance < activationDistance and WithinViewport then
				Delta = frameTime
				frameTime = 0

				debug.profilebegin("SoftBone")

				if SBone.InRange == false then
					SBone.InRange = true
				end

				SBone:UpdateBones(Delta, UpdateRate)

				debug.profileend()

				debug.profilebegin("SoftBoneTransform")

				for _, _ParticleTree in SBone.ParticleTrees do
					SBone:TransformBones(_ParticleTree, Delta)
					if DEBUG then
						SBone:DEBUG(_ParticleTree, Delta)
					end
				end

				debug.profileend()
			else
				if SBone.InRange == true then
					SBone.InRange = false

					for _, _ParticleTree in SBone.ParticleTrees do
						SBone:ResetParticles(_ParticleTree)
					end

					for _, _ParticleTree in SBone.ParticleTrees do
						SBone:ResetTransforms(_ParticleTree, Delta)
					end
				end
			end
		end
	end)
	SBone.SimulationConnection = Connection
	return SBone
end
function ActorModule.Stop()
	Connection:Disconnect()
end
return ActorModule
