local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local CameraController = {}
local player = Players.LocalPlayer
local connection

function CameraController.Start()
	local camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Scriptable
	if connection then
		connection:Disconnect()
	end
	connection = RunService:BindToRenderStep("PixelCamera", Enum.RenderPriority.Camera.Value, function()
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not root then
			return
		end
		local focus = root.Position
		local target = CFrame.lookAt(focus + Vector3.new(0, 62, 28), focus, Vector3.new(0, 0, -1))
		camera.CFrame = camera.CFrame:Lerp(target, 0.12)
		camera.FieldOfView = 35
	end)
end

return CameraController
