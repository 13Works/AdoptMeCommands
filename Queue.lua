export type Status = {["CurrentTask"]: string; ["IsTrading"]: boolean; ["TaskAmount"]: number}

local Queue = {}
Queue.Testing = false

local function IsPlayer(a: any)
	if typeof(a) ~= "Instance" or a.ClassName ~= "Player" then
		return false
	end
	return true
end

function Queue:FindFirstTarget(Target: Player)
	if not IsPlayer(Target) then warn("Target must be a 'Player' object. Got:", typeof(Target)) return end
	for i, Info in Queue do
		if typeof(Info) ~= "table" then continue end
		if Info.Target ~= Target then 
			continue 
		elseif Queue.Testing then 
			print("Found", Target.Name, "in queue. Position:", i)
			return i 
		end
	end
	return
end

function Queue:Add(Target: Player, Status: Status)
	if not IsPlayer(Target) then warn("Target must be a 'Player' object. Got:", typeof(Target)) return end
	if Queue:FindFirstTarget(Target) then warn(Target.Name, "is already in the queue.") return end
	if next(Status) == nil then warn("Status must be a 'Status' object. Got: Empty array.") return end
	table.insert(Queue, {["Target"] = Target; ["Status"] = Status})
	if Queue.Testing then
		print("Added", Target.Name, "to the queue. Position:", #Queue)
	end
end

function Queue:Remove(Target: Player)
	if not IsPlayer(Target) then warn("Target must be a 'Player' object. Got:", typeof(Target)) return end
	local TargetPosition = Queue:FindFirstTarget(Target)
	if not TargetPosition then warn(Target.Name, "is not in the queue.") end
	if Queue.Testing then
		print("Removed", Target.Name, "from the queue.")
		if Queue[2] and TargetPosition == 1 then
			print(Queue[2].Target.Name, "is now first in queue.")
		elseif not Queue[2] then
			print("The queue is now empty.")
		end
	end
	table.remove(Queue, TargetPosition)
end

function Queue:Next()
	if Queue.Testing then
		print("Skipped", Queue[1].Target.Name ..".")
		if Queue[2] then
			print(Queue[2].Target.Name, "is now first in queue.")
		else
			print("The queue is now empty.")
		end
	end
	table.remove(Queue, 1)
end

function Queue:Get()
	local CurrentQueue = {}
	for i, Info in Queue do
		if typeof(Info) ~= "table" then continue end
		CurrentQueue[i] = Info
	end
	return CurrentQueue
end

return Queue