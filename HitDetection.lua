local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Debris = game:GetService("Debris")

local Packager = require(ReplicatedStorage.Packager)

local Limbs = {}

local LocalPlayer = Players.LocalPlayer
local TrackingData = {}

local Batch

local VALID_HIT_PARTS = {
	Head = true,
	["Left Arm"] = true,
	["Right Arm"] = true,
	Torso = true,
}

local function drawDebugSegment(oldPosition: Vector3, newPosition: Vector3)
	local part = Instance.new("Part")
	part.Color = Color3.new(1, 0, 0)
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Transparency = 0.3

	local difference = newPosition - oldPosition
	part.CFrame = CFrame.new(oldPosition + difference / 2, newPosition)
	part.Size = Vector3.new(0.05, 0.05, difference.Magnitude)

	part.Parent = Workspace
	Debris:AddItem(part, 0.5)
end

local function getAttachments(model: Model)
	local rayAttachments = {}

	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("Attachment") and descendant.Name == "RayAttachment" then
			table.insert(rayAttachments, descendant)
		end
	end

	return rayAttachments
end

function Limbs.GetAttachmentsPositions(attachments)
	local positions = {}

	for _, attachment: Attachment in ipairs(attachments) do
		positions[attachment] = attachment.WorldPosition
	end

	return positions
end

function Limbs.Init()
	Batch = Packager.Get("Batch")
end

function Limbs.Start()
	RunService.RenderStepped:Connect(function()
		for model: Model, data in pairs(TrackingData) do
			if os.clock() > data.EndTime then
				Limbs.Stop(model)
				continue
			end

			if not model or not model.Parent then
				Limbs.Stop(model)
				continue
			end

			local raycastParams = data.RaycastParams
			local hits = data.Hits
			local oldPositions = data.RayPositions
			local newPositions = Limbs.GetAttachmentsPositions(data.RayAttachments)

			local shouldStop = false

			for attachment, newPosition in pairs(newPositions) do
				local oldPosition = oldPositions[attachment]

				if oldPosition then
					local direction = newPosition - oldPosition

					drawDebugSegment(oldPosition, newPosition)

					raycastParams.FilterDescendantsInstances = hits
					local result = Workspace:Raycast(oldPosition, direction, raycastParams)

					if result then
						table.insert(hits, result.Instance)

						if VALID_HIT_PARTS[result.Instance.Name] then
							Batch.AddToBatch("ClientHitZombie", {
								Player = LocalPlayer,
								Limb = result.Instance.Name,
								ZombieId = result.Instance.Parent.Name,
							})

							Limbs.Stop(model)
							shouldStop = true
							break
						end
					end
				end
			end

			if not shouldStop and TrackingData[model] then
				data.RayPositions = newPositions
			end
		end
	end)
end

function Limbs.Track(swordModel: Model, duration: number)
	local existingData = TrackingData[swordModel]
	local newEndTime = os.clock() + duration

	if existingData then
		if existingData.EndTime < newEndTime then
			existingData.EndTime = newEndTime
		end
		return
	end

	local attachments = getAttachments(swordModel)

	local raycastParams = RaycastParams.new()
	raycastParams.CollisionGroup = "Zombie"
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude

	TrackingData[swordModel] = {
		EndTime = newEndTime,
		RayAttachments = attachments,
		RayPositions = Limbs.GetAttachmentsPositions(attachments),
		RaycastParams = raycastParams,
		Hits = {},
	}
end

function Limbs.Stop(model: Model)
	TrackingData[model] = nil
end

return Limbs
