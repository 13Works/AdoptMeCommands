request        = request        or function(...) warn("[no function 'request']") end
getconnections = getconnections or function(...) warn("[no function 'getconnections']") end
isfile         = isfile         or function(...) warn("[no function 'isfile']") end
readfile       = readfile       or function(...) warn("[no function 'readfile']") end
writefile      = writefile      or function(...) warn("[no function 'writefile']") end
getupvalue     = getupvalue     or function(...) warn("[no function 'getupvalue']") end

type DialogObject = {["Text"]: string; ["Dialog"]: GuiObject; ["Buttons"]: {[string]: GuiButton}}
type Filters = {["Categories"]: {string}; ["Properties"]: {string}; ["Names"]: {string}; ["Amount"]: number}
type StandardArgs = {["Sender"]: Player; ["CommandName"]: string; ["Ignored"]: string}
type Status = {["CurrentTask"]: string; ["IsTrading"]: boolean; ["TaskAmount"]: number}
type Trade = {["Targets"]: {Player}; ["Sender"]: Player; ["Giver"]: Player; ["Reciever"]: Player; ["Filters"]: Filters; ["Items"]: {[string]: {}}; ["ListType"]: "[alt list]" | "[pet list]"}
type DiscordEmbed = {["title"]: string; ["description"]: string; ["type"]: "rich" | "standard"; ["color"]: number}

repeat wait() until game:IsLoaded()

local function rename(remotename,hashedremote)
	hashedremote.Name = remotename
end
table.foreach(getupvalue(require(game:GetService("ReplicatedStorage"):WaitForChild("Fsys")).load("RouterClient").init, 4), rename)

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local API = RS:WaitForChild("API")
local Rarities = require(RS.ClientDB.Inventory.InventoryPetsSubDB.InventoryPetsSubDB).entries

local LocalPlayer = Players.LocalPlayer; local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
for _, v in pairs(getconnections(LocalPlayer.Idled)) do v:Disable() end
local TradeFrame = PlayerGui:WaitForChild("TradeApp"):WaitForChild("Frame")

local Accounts = _G.Accounts or {}
local AltControl = _G.AltControl or false
local Webhook = _G.Webhook or ""

testing = true

for AccountName, Info in Accounts do
	Accounts[AccountName] = {
		["IsController"] = Info.IsController,
		["IsTrading"] = false,
		["CurrentTask"] = "",
		["TaskAmount"] = 0
	}
end

local SpecialCharacters = {"!", "@", "#", "$", "%", "^", "&", "*", "(", ")", "_", "+", "-", "=", "{", "}", "[", "]", "|", ";", ":", "'", "\"", ",", ".", "<", ">", "/", "?", "`", "~"}
local OutputSeperator = "______________________________________"
local ArgumentSeperators = {Opening = "{", Closing = "}"}
local Prefix = "!"

-- local Queue = loadstring(game:HttpGet("https://raw.githubusercontent.com/13Works/AdoptMeCommands/main/Queue.lua"))()

function Click(Button: GuiButton)
	assert(
		typeof(Button) == "Instance" and Button:IsA("GuiButton"), 
		"Arg 1 to function 'Click' must be a GuiButton object. Got: ".. (typeof(Button) == "Instance" and Button.ClassName or tostring(typeof(Button)))
	)
	for i, v in pairs(getconnections(Button.MouseButton1Click)) do
		v:Fire()
	end
end

function Concat(tbl: {}, sep: string)
	if typeof(tbl) ~= "table" then
		tbl = {tbl}
	end

	if typeof(tbl[1]) == "Instance" then
		local str = ""

		for i, instance in tbl do
			str = str .. instance.Name or instance

			if #tbl > 1 then
				sep = (i ~= #tbl) and sep or ""
				str = str .. sep
			end
		end

		return str
	end 

	local newstr: string = ""

	for i, str in tbl do
		newstr = newstr .. str or newstr

		if #tbl > 1 then
			sep = (i ~= #tbl) and sep or ""
			newstr = newstr .. sep
		end
	end

	return newstr
end

function rStrip(String: string)
	return (String:gsub("%s+$", ""))
end

function lStrip(String: string)
	return (String:gsub("^%s+", ""))
end

function Strip(String)
	return rStrip(lStrip(String))
end

function Title(str: string)
	return string.gsub(" "..str, "%W%l", string.upper):sub(2)
end

function GetInventory()
	return require(RS.ClientModules.Core.ClientData).get_data()[LocalPlayer.Name].inventory
end

function PrintTable(starting_tbl, index)
	local Indent = "  "
	local Output = "\n" .. "[\"".. (index ~= nil and tostring(index) or "Table") .."\"] = {"

	local function IncreaseDepth(tbl, Depth)
		Depth = Depth or Indent

		for i, v in tbl do
			if typeof(v) == "table" then
				Output = Output .. Depth .."[\"".. i .."\"] = {\n"
				IncreaseDepth(v, Depth .. Indent)
			else
				if typeof(v) == "string" then
					v = "\"".. v .. "\""
				end
				v = tostring(v)
				Output = Output .. Depth .."[\"".. i .."\"] = ".. tostring(v) ..";\n"
			end
		end

		local ReverseDepth = ""
		for i = 1, #Depth:split("") - (Indent:len()), Indent:len() do
			ReverseDepth = ReverseDepth .. Indent
		end
		Output = Output ..ReverseDepth .."};\n"
		task.wait()
	end

	if next(starting_tbl) ~= nil then
		Output = Output .."\n"
		IncreaseDepth(starting_tbl)
	end

	Output = Output .."}"

	return Output
end

local function HasAll(tbl)
	return table.find(tbl, "all") or table.find(tbl, "All")
end

local function GetTargets(Args: {["Targets"]: {string | number}; ["Sender"]: Player; ["IncludeSender"]: boolean; ["CommandName"]: string; ["MaxTargets"]: number})
	Args.Targets = Args.Targets or Args.targets or Args.Target or Args.target or {}

	PrintTable(Args.Targets, "Targets")

	if Args.Sender ~= LocalPlayer and not HasAll(Args.Targets) then
		local IsTarget = false

		for _, Target in Args.Targets or {} do
			print("Player Name:", string.lower(LocalPlayer.Name), "| Target Name:", string.lower(Target))
			print("Player UserId:", LocalPlayer.UserId, "| Target UserId:", tonumber(Target))

			if string.lower(LocalPlayer.Name) == string.lower(Target) or LocalPlayer.UserId == tonumber(Target) then 
				IsTarget = true
				break 
			end
		end

		if not IsTarget then if testing then warn("Attempted to run command on non-target") end return end
	end

	assert(Args, "No arguments were passed to the 'GetTargets' function.")
	assert(Args.Sender, "Missing argument 'Sender'.")
	assert(Args.Targets, "Missing argument 'Targets'; Got: ".. tostring(Args.Targets))
	assert(Args.CommandName, "Missing argument 'CommandName'; Got: ".. tostring(Args.CommandName))
	Args.MaxTargets = Args.MaxTargets or Players.MaxPlayers
	assert(#Args.Targets <= Args.MaxTargets, string.gsub("Too many targets were specified for the '*".. Args.CommandName .."' command. Max targets are: ".. Args.MaxTargets ..". Got: ".. #Args.Targets, "*", Prefix))

	if table.find(Args.Targets, "all") or table.find(Args.Targets, "All") then
		Args.Targets = {}
		for Account_Name, _ in Accounts do
			table.insert(Args.Targets, string.lower(Account_Name))
		end
	end

	local FoundTargets: {Player}, NotFoundTargets: {Player} = {}, {}

	for _, Target in Args.Targets do
		local TargetPlayer = nil

		for _, Player in Players:GetPlayers() do
			if string.lower(Player.Name) ~= string.lower(Target) and Player.UserId ~= tonumber(Target) then continue end
			TargetPlayer = Player
			break
		end

		if not TargetPlayer then 
			local IsAccount = false

			for Account_Name, _ in Accounts do
				if string.lower(Account_Name) == Target then 
					IsAccount = true
					break
				end
			end

			if not IsAccount then 
				warn("Player '".. Target .."' not found.")
			end
			continue
		end
		if not Accounts[TargetPlayer.Name] then warn(string.gsub(TargetPlayer.Name .." must be in your 'Accounts' list. Do *Add_Account to add accounts to your 'Accounts' list.", "*", Prefix)) continue end
		if TargetPlayer == Args.Sender and not Args.IncludeSender then continue end
		if table.find(FoundTargets, TargetPlayer) then continue end
		table.insert(FoundTargets, TargetPlayer)
	end

	if #FoundTargets == 0 then warn("Player".. (Args.MaxTargets > 1 and "s " or " ") .."'" .. Concat(Args.Targets, "&") .. "' not found.") end

	return FoundTargets
end

local function ValidateFilters(Args: StandardArgs)
	local Filters = Args
	local Categories = Filters.categories or Filters.category
	local Properties = Filters.properties or Filters.property
	local Names = Filters.names or Filters.name
	local Amount = Filters.amount and tonumber(Filters.amount[1])

	if not Categories then 
		if Properties then warn("Category/Categories must be provided to use 'Properties' filters.") end
		if Names then warn("Category/Categories must be provided to use 'Names' filters.") end
		if Amount then warn("Category/Categories & Name must be provided to use 'Amount' filter.") end
		if not Properties and not Names and not Amount then warn((string.gsub("Category/Categories must be provided to use the '*".. Args.CommandName .."' command.", "*", Prefix))) end
		return
	end

	return {
		["Categories"] = Categories or {},
		["Properties"] = Properties or {},
		["Names"] = Names or {},
		["Amount"] = Amount or 0
	}
end

local function GetFilters(Args: StandardArgs)
	assert(Args.CommandName, "Missing argument 'CommandName'; Got: ".. tostring(Args.CommandName))
	Args.Filters = ValidateFilters(Args); if not Args.Filters then return end

	local ValidProperties = {}
	ValidProperties.Rarities = {"common", "uncommon", "rare", "ultra-rare", "legendary"}
	ValidProperties.PetProperties = {
		"neon", "mega", "reborn", "twinkle", "sparkle", "flare", "luminous",
		"normal", "newborn", "junior", "pre-teen", "teen", "post-teen", "fullgrown",
		"flyable", "rideable", "listed"
	}

	local ValidCategories = {
		"food", "pet-wear", "pets", "strollers", "vechicles", "toys", "gifts", "transport"
	}

	local TargetCategories = Args.Filters.Categories
	local TargetProperties = Args.Filters.Properties
	local TargetNames = Args.Filters.Names
	local TargetAmount = Args.Filters.Amount

	for _, Category in ipairs(TargetCategories or {}) do
		if not table.find(TargetCategories, string.lower(Category)) then
			warn("Invalid category:", Category)
			return
		end
	end

	for _, Property in TargetProperties do 
		local PetsCategory = table.find(TargetCategories, "pets")
		local IsPetProperty = PetsCategory and table.find(ValidProperties.PetProperties, string.lower(Property))

		if not table.find(ValidProperties.Rarities, string.lower(Property)) and not IsPetProperty then
			warn("Invalid property:", Property)
			return
		end
	end

	local vehicles = table.find(TargetCategories, "vehicles")
	if vehicles then TargetCategories[vehicles] = "transport" end

	return {
		["Categories"] = TargetCategories,
		["Properties"] = TargetProperties,
		["Names"] = TargetNames,
		["Amount"] = TargetAmount
	}
end

local function GetIdentities(Items)
	local Uniques = {}

	for Unique, Info in next, Items do
		if Unique == "ListType" or not Info.kind then continue end
		local Properties = Info.properties
		-- 'k:/a:/n/m/f/r'
		local Identifiers = {
			"k:".. Info.kind,
			(Properties.age) and "a:".. Properties.age or nil,
			(Properties.neon and Properties.neon == true) and "n" or nil,
			(Properties.mega_neon and Properties.mega_neon == true) and "m" or nil,
			(Properties.flyable and Properties.flyable == true) and "f" or nil,
			(Properties.rideable and Properties.rideable == true) and "r" or nil,
			(Rarities[Info.kind] ~= nil) and Rarities[Info.kind].rarity or nil
		}

		local Identity = Concat(Identifiers, "/")
		Uniques[Identity] = Uniques[Identity] or {}
		table.insert(Uniques[Identity], Unique)
	end

	return Uniques
end

local function GetKind(Input: string, Source: {{["name"]: string}})
	if not Input or Input == "" then return end

	Source = Source or Rarities
	-- print("Searching for", Input, "in rarities.")

	local function FindMultipleSegments(InputSegment, PetName)
		local BaseSegments = {unpack(PetName:split(" "))}
		for _, BaseSegment in BaseSegments do
			if (InputSegment:len() == 1 and BaseSegment:sub(1, 1) == InputSegment) or (InputSegment:len() > 1 and InputSegment == BaseSegment) then
				--warn(InputSegment:sub(1, 1), "=", BaseSegment:sub(1, 1), "| true")
				return 1
			end
			-- print(InputSegment:sub(1, 1), "=", BaseSegment:sub(1, 1), "| false")
		end
		return 0
	end

	local function FindSingleSegment(InputSegment, PetName)
		if InputSegment:lower() == PetName:lower() or string.find(PetName, InputSegment) then
			--warn(InputSegment, "=", PetName, "| true")
			return 1
		end

		--print("---------------------")
		--print(PrintTable(PetName:split(" "), "Kind"))
		--print(InputSegment, "=", PetName, "| false")
		return 0
	end

	local InputSegments: {string} = Input:split("-")

	for _, Info in Source do
		local TotalSegmentsMatched = 0
		local PetName = string.lower(Info.name)
		if PetName == string.lower(Input) then return Info.kind, PetName end

		for _, InputSegment in ipairs(InputSegments) do
			InputSegment = Strip(string.lower(InputSegment))
			TotalSegmentsMatched += #InputSegments > 1 and FindMultipleSegments(InputSegment, PetName) or FindSingleSegment(InputSegment, PetName)
		end

		if TotalSegmentsMatched == #InputSegments then
			return Info.kind, PetName
		end
	end

	return
end

function MatchProperties(a: {}, b: {})
	local ValidProperties = {"neon", "mega_neon", "flyable", "rideable"}
	local Matched = true

	a = {
		["neon"] = a.neon or false;
		["mega_neon"] = a.mega_neon or false;
		["flyable"] = a.flyable or false;
		["rideable"] = a.rideable or false;
	}

	b = {
		["neon"] = b.neon or false;
		["mega_neon"] = b.mega_neon or false;
		["flyable"] = b.flyable or false;
		["rideable"] = b.rideable or false;
	}

	for Property, Value in a do
		if b[Property] ~= Value then 
			-- warn("a:", Property, "=", "b:", Property, "|", b[Property] == Value)
			return false 
		end
		-- print("a:", Property, "=", "b:", Property, "|", b[Property] == Value)
	end

	return true
end

local function PhrasePetLines(Lines: {string}, ListType: "[pet list]" | "[alt list]")
	local ValidProperties = {
		["n"] = "neon",
		["m"] = "mega_neon",
		["f"] = "flyable",
		["r"] = "rideable"
	}

	local TargetPets = {}
	local Uniques, TotalUniques = {}, 0
	local Inventory = GetInventory().pets

	for _, Line in Lines do
		Line = Strip(Line)
		if Line == "" or Line:find("%[") then continue end

		local Amount, PetProperties, PetName = 1, "", ""
		local LineInfo = Line:split(" ")

		for i, Field in LineInfo do
			Field = Field:lower()
			local IsPropertyField = true
			if Field == "all" or tonumber(Field) then Amount = Field continue end

			for _, Property in Field:split("") do
				if not ValidProperties[Property] then IsPropertyField = false break end
			end

			if IsPropertyField then 
				if PetProperties ~= "" then continue end
				PetProperties = PetProperties .. Field 
				continue
			end

			PetName = PetName .." ".. Field
		end

		Amount = tonumber(Amount) or (Amount == "all" and math.huge)
		PetName = (PetName ~= "" and PetName ~= nil) and Strip(PetName):gsub("%s+", "-"):lower() or nil
		PetProperties = (PetProperties ~= "" and PetProperties ~= nil) and PetProperties:match("^[mnfrMNFR]*$") or nil

		if not PetName then warn("[no petname]") continue end

		local FoundProperties = {}

		if PetProperties then
			for _, Property in PetProperties:split("") do
				local FoundProperty = ValidProperties[string.lower(Property)]
				if FoundProperty then
					FoundProperties[FoundProperty] = true
				end
			end
		end

		PetProperties = FoundProperties
		local TargetKind, TargetName = GetKind(PetName)
		local FoundUniques, InvalidKinds = {}, {}

		if testing then
			print("Amount:", Amount == math.huge and "All" or Amount)
			print("InputName:", PetName)
			print(TargetName, "(".. (TargetKind or "nil") ..")")
			print("PetProperties:", PetProperties)
		end

		for Unique, Info in Inventory do
			if table.find(InvalidKinds, Info.kind) then continue end
			if TargetKind ~= Info.kind then table.insert(InvalidKinds, Info.kind) continue end 
			if next(PetProperties) ~= nil and not MatchProperties(Info.properties, PetProperties) then continue end
			if table.find(FoundUniques, Unique) then warn("Attempted to insert duplicate pet.") continue end

			warn(TargetKind,"=", Info.kind, "| true") 

			if Amount > 0 then
				Amount -= 1; TotalUniques += 1
				warn("Found pet:", TargetName, "(".. TargetKind ..")")
				table.insert(FoundUniques, Unique)
				TargetPets[Unique] = {
					["pet_name"] = TargetName, 
					["properties"] = Info.properties, 
					["kind"] = TargetKind, 
					["unique"] = Unique
				}
			end

			if Amount == 0 then
				break
			end
		end
		warn("------------------------")
	end

	warn(TargetPets)

	return TargetPets
end

local function GetPetsFromList(List: string)
	local Lines = List:split("\n")
	local FoundPets = {}
	local ListType = Strip((Lines[1] or ""):lower())
	table.remove(Lines, 1)

	if ListType == "[alt list]" then
		for _, Line in Lines do
			if Strip(Line) == "" then continue end
			Line =  Line:split(":") or {}
			local AccountName, Pets = Line[1], Line[2]
			if not AccountName or not Pets then warn("Invalid line: AccountName:", AccountName, "| Pets:", Pets) continue end
			warn(AccountName, Pets)
			FoundPets[Strip(AccountName):lower()] = PhrasePetLines(Pets:gsub(";", ","):gsub(",", "\n"):split("\n"), ListType)
		end
	elseif ListType == "[pet list]" then
		FoundPets = PhrasePetLines(List:gsub(";", ""):gsub(",", ""):split("\n"), ListType)
	else
		warn("Invalid list type:", ListType)
		return {}
	end

	FoundPets.ListType = ListType

	return FoundPets
end

local function ValidateItems(Args: {["Items"]: {}; ["Filters"]: Filters; ["CommandName"]: string})
	local Properties = {
		newborn       = "/a:1"; reborn   = "/a:1",
		junior        = "/a:2"; twinkle  = "/a:2",
		["pre-teen"]  = "/a:3"; sparkle  = "/a:3",
		teen          = "/a:4"; flare    = "/a:4",
		["post-teen"] = "/a:5"; sunshine = "/a:5",
		fullgrown     = "/a:6"; luminous = "/a:6",
		normal   = "/nrl",
		neon     = "/n",
		mega     = "/m",
		flyable  = "/f",
		rideable = "/r",
		legendary = "/legendary", 
		ultra_rare = "/ultra_rare", 
		rare = "/rare", 
		uncommon = "/uncommon", 
		common = "/common"
	}

	if table.find(Args.Filters.Properties, "listed") or table.find(Args.Filters.Properties, "Listed") then
		Args.Filters.Properties = {}
		Args.Filters.Names = {}
		Args.Filters.Amount = 0

		local txt = "Pets To Trade.txt"

		if not isfile(txt) then
			writefile(txt, "")
			warn("There is no", txt, "file.")
			print("Creating", txt, " and ignoring", Prefix .. Args.CommandName .. ".")
			return {}
		end

		local List = readfile(txt) or ""
		local Pets = GetPetsFromList(List)
		Args.Items = Pets
	end

	local TargetNames = Args.Filters.Names
	local TargetProperties = Args.Filters.Properties
	local TargetAmount = Args.Filters.Amount
	local PropertiesString = ""

	if next(TargetProperties) ~= nil then 
		print(TargetProperties)
		for _, TargetProperty in TargetProperties do
			PropertiesString = PropertiesString .. Properties[TargetProperty]
		end
	end

	local function ItemsToUniques(Items)
		local TargetUniques = {}
		local Total = 0

		for Identity, Item_Uniques in GetIdentities(Items) do
			if TargetAmount > 0 and Total == TargetAmount then break end
			local TargetItem = true

			local FoundProperties = PropertiesString:split("/")
			if #FoundProperties == 1 then FoundProperties = {} end
			for _, Property in FoundProperties do
				if not Identity:find("/"..Property) then TargetItem = false break end
			end

			if next(TargetNames) ~= nil then 
				local kind = Identity:split(":")[2]:split("/")[1]
				local FoundName = false

				for _, Name in TargetNames do
					if GetKind(Name) then
						FoundName = true
						break
					end
				end

				if not FoundName then TargetItem = false end
			end

			if TargetItem then
				for _, Unique in Item_Uniques do
					if TargetAmount > 0 and Total == TargetAmount then break end
					if TargetAmount > 0 then Total += 1 end
					table.insert(TargetUniques, Unique)
				end
			end
		end

		return TargetUniques
	end

	print("Getting identities:", Args.Items, "| ListType:", Args.Items.ListType)
	local Uniques = {}
	local ListType = Args.Items.ListType or ""
	if ListType == "[alt list]" then
		for Account_Name, Pets in Args.Items do
			if typeof(Pets) ~= "table" then continue end
			Uniques[Account_Name] = ItemsToUniques(Pets)
		end
	elseif ListType == "[pet list]" then
		Uniques = ItemsToUniques(Args.Items)
	end
	
	Uniques.ListType = Args.Items.ListType
	
	return Uniques
end

local function GetDialogObject(ReturnButtons: boolean)
	local Dialog = PlayerGui.DialogApp.Dialog.NormalDialog
	local Info = Dialog:FindFirstChild("Info")
	local TextLabel = Info and Info:FindFirstChild("TextLabel") or nil
	local DialogObject: DialogObject = {}
	DialogObject.Dialog = Dialog
	DialogObject.Text = TextLabel and TextLabel.Text or ""
	DialogObject.Buttons = {}

	if ReturnButtons and Dialog:FindFirstChild("Buttons") then
		for _, Button in Dialog.Buttons:GetChildren() do
			if not Button:IsA("GuiButton") then continue end
			DialogObject.Buttons[Button.Face.TextLabel.Text] = Button
		end
	end

	return DialogObject
end

local function TradeTarget(Args: {["Giver"]: Player; ["Reciever"]: Player; ["Items"]: {}})
	local TradeFrame = PlayerGui.TradeApp.Frame

	local MaxTradeSize = 18
	local TotalItems = #(Args.Items or {})
	warn("Getting offer...")

	for i = 1, TotalItems, MaxTradeSize do
		local Offer = {}

		for j = i, math.min(i + MaxTradeSize - 1, TotalItems) do
			table.insert(Offer, Args.Items[j])
		end

		if #Offer == 0 then warn("No items to trade") break end

		warn("Trading", #Offer, "items to", Args.Reciever.Name ..".")
		print("Items remaining:", TotalItems - #Offer - i + 1)

		repeat 
			task.wait(1)
			local DialogObject = GetDialogObject()
			print("Waiting for trade request...") 
			print("DialogText:", DialogObject.Text)
		until DialogObject.Dialog.Visible and string.match(DialogObject.Text, Args.Reciever.Name)

		-- API:FindFirstChild("TradeAPI/AcceptOrDeclineTradeRequest"):InvokeServer(Args.Reciever, true)

		local CurrentDialogObject = GetDialogObject(true)
		local Accept = CurrentDialogObject.Buttons.Accept
		if Accept then Click(Accept) end

		repeat 
			print("Checking if it's your first tiem trading."); task.wait(1) 
			local DialogObject = GetDialogObject(true)
			print("DialogText:", DialogObject.Text)
			if string.match(DialogObject.Text, "Be careful") then
				warn("First time trading")
				print("Attempting to find dialog button.")
				local Button = DialogObject.Buttons.Okay
				if Button then 
					Click(Button)
					print("Found dialog button. Proceeding with trade.")
					break
				end
			end
		until TradeFrame.Visible

		task.wait(1)

		for _, Unique in ipairs(Offer) do
			API:FindFirstChild("TradeAPI/AddItemToOffer"):FireServer(Unique)
			print("Added ".. Unique .." to trade.")
			task.wait()
		end

		repeat 
			print("Waiting for target to accept offer...")
			API:WaitForChild("TradeAPI/AcceptNegotiation"):FireServer()
			task.wait(1)
		until (TradeFrame.NegotiationFrame.Visible == false and TradeFrame.ConfirmationFrame.Visible == true) or not GetCurrentTask(Args.Giver, "IsTrading")

		if not GetCurrentTask(Args.Giver, "IsTrading") then break end

		print("Accepted trade.")

		task.wait(1)

		local Unbalanced = false

		repeat 
			print("Checking for unbalance."); task.wait(1) 
			local DialogObject = GetDialogObject(true)
			print("DialogText:", DialogObject.Text)
			if string.match(DialogObject.Text, "This trade seems unbalanced.") then
				warn("Unbalanced trade")
				print("Attempting to find dialog buttons.")
				Unbalanced = true
				local Button = DialogObject.Buttons["Next"]
				if Button then 
					Click(Button)
					break
				end
			else
				Unbalanced = false
			end
		until not DialogObject.Dialog.Visible or not Unbalanced

		task.wait(1)

		repeat 
			task.wait(1) 
			local DialogObject = GetDialogObject(true)
			if string.match(DialogObject.Text, "Remember:") or string.match(DialogObject.Text, "Trust NO ONE!") then
				local Button = DialogObject.Buttons["I understand"]
				if Button then 
					Click(Button)
					print("Ignoring unbalance.")
					break
				end
			else
				Unbalanced = false
			end
		until not DialogObject.Dialog.Visible or not Unbalanced

		task.wait(1)

		repeat 
			print("Waiting for target to confirm offer...")
			API:WaitForChild("TradeAPI/ConfirmTrade"):FireServer()
			task.wait(1)
		until TradeFrame.Visible == false or not GetCurrentTask(Args.Giver, "IsTrading")

		if not GetCurrentTask(Args.Giver, "IsTrading") then break end

		warn("Confirmed trade.")
	end
end

function GetCurrentTask(Target: Player, Task: string)
	assert(typeof(Target) == "Instance" and Target.ClassName == "Player", "Target must be a Player object. Got: ".. typeof(Target))
	return Accounts[Target.Name][Task]
end

local function SetupTrade(Args: Trade)
	if LocalPlayer == Args.Reciever then
		if Args.Filters then print("Getting every", Concat(Args.Filters.Properties or Args.Filters.Names, " & "), "from", Args.Giver.Name) end

		while GetCurrentTask(LocalPlayer, "IsTrading") do
			if not TradeFrame.Visible then
				API:WaitForChild("TradeAPI/SendTradeRequest"):FireServer(Args.Giver)
				warn("Sent trade request to", Args.Giver)

				repeat
					task.wait(1)
					print("Waiting for request to be accepted...")
				until TradeFrame.Visible or not GetCurrentTask(Args.Reciever, "IsTrading")

				warn(Args.Giver, "Accepted")

				repeat 
					task.wait(1)
					print("Waiting for offer...")
					API:WaitForChild("TradeAPI/AcceptNegotiation"):FireServer()
				until (TradeFrame.NegotiationFrame.Visible == false and TradeFrame.ConfirmationFrame.Visible == true) or not GetCurrentTask(Args.Reciever, "IsTrading")

				if not GetCurrentTask(Args.Reciever, "IsTrading") then break end

				task.wait(1)

				local Unbalanced = false

				repeat 
					print("Checking for unbalance."); task.wait(1) 
					local DialogObject = GetDialogObject(true)
					print("DialogText:", DialogObject.Text)
					if string.match(DialogObject.Text, "This trade seems unbalanced.") then
						warn("Unbalanced trade")
						print("Attempting to find dialog buttons.")
						Unbalanced = true
						local Button = DialogObject.Buttons["Next"]
						if Button then 
							Click(Button)
							break
						end
					else
						Unbalanced = false
					end
				until not DialogObject.Dialog.Visible or not Unbalanced

				task.wait(1)

				repeat 
					task.wait(1) 
					local DialogObject = GetDialogObject(true)
					if string.match(DialogObject.Text, "Remember:") or string.match(DialogObject.Text, "Trust NO ONE!") then
						local Button = DialogObject.Buttons["I understand"]
						if Button then 
							Click(Button)
							print("Ignoring unbalance.")
							break
						end
					else
						Unbalanced = false
					end
				until not DialogObject.Dialog.Visible or not Unbalanced

				task.wait(1)

				repeat 
					task.wait(1)
					print("Waiting for offer...")
					API:WaitForChild("TradeAPI/ConfirmTrade"):FireServer()
				until (TradeFrame.Visible == false) or not GetCurrentTask(Args.Reciever, "IsTrading")

				if not GetCurrentTask(Args.Reciever, "IsTrading") then break end

				print("Confirmed trade")
			end

			task.wait(1)
		end

		UpdateStatus(LocalPlayer)
	elseif LocalPlayer == Args.Giver then
		Args.Items = Args.Items and Args.Items[Args.Reciever.Name] or nil

		if Args.Filters and not Args.Items then 
			print("Trading every", Concat(Args.Filters.Properties or Args.Filters.Names, " & "), "to", Args.Reciever.Name)
			local Inventory = GetInventory()
			Args.Items = {}

			for _, Category in Args.Filters.Categories do
				local ValidatedItems = ValidateItems({["Items"] = Inventory[Category], ["Filters"] = Args.Filters, ["CommandName"] = Args.CommandName, ["Target"] = Args.Reciever})
				for _, Unique in ValidatedItems do
					table.insert(Args.Items, Unique)
				end
			end

			print(PrintTable(Args, "New Items"))
		elseif Args.Items and not Args.Filters then
			print(PrintTable(Args, "Set Items"))
		end

		UpdateStatus(LocalPlayer, {["IsTrading"] = true})
		TradeTarget(Args)
		warn("Finished trading")

		Say("I'm finished trading, ".. Args.Reciever.Name ..".")
	else
		error("Error setting up trade\n".. PrintTable(Args, "Args"))
	end
end

local function SetupMultipleTrades(Args: Trade)
	local IsSender = (LocalPlayer == Args.Sender)
	PrintTable(Args.Targets, "Targets")
	for _, Target in Args.Targets do
		if IsSender then Say("Let's trade, ".. Target.Name ..".") end 
		repeat task.wait(1); print("Waiting for turn...") until GetCurrentTask(LocalPlayer, "IsTrading") or GetCurrentTask(Args.Sender, "CurrentTask") == "" or (IsSender and GetCurrentTask(Args.Sender, "IsTrading") == false)

		if GetCurrentTask(Target, "IsTrading") and GetCurrentTask(Args.Sender, "CurrentTask") ~= "" and (LocalPlayer == Target or IsSender) then

			print("Giver:", Args.Giver, "| Reciever:", Target)
			
			Args.Items = Args.ListType == "[alt list]" and Args.Items[Args.Reciever] or Args.Items
			
			SetupTrade({
				["Reciever"] = Args.Reciever or Target, 
				["Giver"] = Args.Giver or Target, 
				["Filters"] = Args.Filters, 
				["Items"] = Args.Items
			})
		end

		UpdateStatus(Target)
	end

	if IsSender then 
		warn("Finished getting items from", #Args.Targets ,"inventories.")
		Say("I finished my current task.") 
	end
end

local function AcceptOrDeclineTrade(Args: StandardArgs, AcceptOrDecline)
	Args.IncludeSender = true
	local Targets: {Player} = GetTargets(Args)

	for _, Target in Targets do
		local CurrentTask = Accounts[Target.Name].CurrentTask
		if CurrentTask ~= "" then warn(LocalPlayer == Target and "You are" or Target.Name .." is", "currently doing a task: '".. CurrentTask .."'. Do '".. Prefix .. Args.CommandName .."' if you wish to cancel this task.") return end
		local IsTrading = UpdateStatus(Target, {IsTrading = AcceptOrDecline}, {"IsTrading"})

		if IsTrading then
			API:WaitForChild(AcceptOrDecline and "TradeAPI/AcceptNegotiation" or "TradeAPI/DeclineNegotiation"):FireServer()
			warn(AcceptOrDecline and "Accepting" or "Declining", "current trade.")
		else
			warn(LocalPlayer == Target and "You have" or Target.Name .." has", "no trade to ".. AcceptOrDecline and "accept" or "decline" ..".", Args.Ignored)
		end
	end
end

function UpdateStatus(Target: Player, Status: Status, ItemsToReturn: {string})
	--if not Target then warn("Target must be a Player object. Got:", typeof(Target)) return end
	local Account = Accounts[Target.Name]
	local Items, ItemsToReturn = {}, ItemsToReturn or {}

	Status = Status or {["CurrentTask"] = "", ["IsTrading"] = false, ["TaskAmount"] = 0}

	for Item, Value in Account do
		if Status[Item] ~= nil then
			Account[Item] = Status[Item]
			if table.find(ItemsToReturn, Item) then
				Items[Item] = Value
			end
		end
	end

	local IsController = (Accounts[Target.Name].IsController) and "," or ""
	print("UpdateStatus(".. Target.Name ..", {")
	print("	IsTrading = ".. tostring(Status.IsTrading or Accounts[Target.Name].IsTrading) ..", ")
	print("	CurrentTask = \"".. tostring(Status.CurrentTask or Accounts[Target.Name].CurrentTask) .."\", ")
	print("	TaskAmount = ".. tostring(Status.TaskAmount or Accounts[Target.Name].TaskAmount) .. IsController)
	if Accounts[Target.Name].IsController then
		print("	IsController = true")
	end
	print("})")

	return Items
end

local function FormatInventoryToString(Inventory)
	local str = ""
	local totals = {
		neons = 0,
		fullgrowns = 0,
		newborns = 0,
		overall = 0
	}

	local function con(...)
		local args = {...}
		for _, arg in ipairs(args) do
			str = str .. arg
		end
	end

	for _, Pet in ipairs(Inventory) do
		totals.overall += Pet.amount
		totals.neons += Pet.neon and Pet.amount or 0
		totals.fullgrowns += Pet.fullgrown and Pet.amount or 0
	end

	con("```js", "\n")
	str = str .. LocalPlayer.Name .. ": "

	local newborns, fullgrowns = {}, {}
	local colors = {
		"red",
		"orange",
		"yellow",
		"green",
		"blue",
		"purple",
		"pink",
		"black",
		"white",
		"brown",
		"grey"
	}

	local function Find_Color(name)
		for _, v in ipairs(name) do 
			if table.find(colors, v) then
				return v
			end
		end
		return false
	end

	for _, pet in ipairs(Inventory) do
		local name = pet.name
		local color = Find_Color(string.split(name, "_"))

		if color then
			pet.name = color:sub(1, 1):upper() .. "-" .. string.split(name, "_")[#string.split(name, "_")]
		elseif string.match(name, "_") and not color then
			name = string.split(name, "_")
			pet.name = name[#name]
		end

		table.insert(pet.fullgrown and fullgrowns or newborns, pet)
	end

	for i, pet in pairs(newborns) do
		local amount = ""
		if pet.amount > 1 then
			amount = "[" .. pet.amount .. "]"
		end

		if pet.neon then
			con(pet.name:sub(1,1):upper()..pet.name:sub(2), amount)
		else
			con(string.lower(pet.name) .. amount)
		end
		if i ~= #newborns then
			con(", ")
		end
	end

	if #newborns > 0 and #fullgrowns > 0 then
		con(", //")
	elseif #newborns == 0 and #fullgrowns > 0 then
		con("//")
	elseif #newborns == 0 and #fullgrowns == 0 then
		con("//empty")
	end

	for i, pet in pairs(fullgrowns) do
		local amount = ""
		if pet.amount > 1 then
			amount = "[" .. pet.amount .. "]"
		end
		if pet.neon then
			con(pet.name:sub(1,1):upper() .. pet.name:sub(2), amount)
		else
			con(string.lower(pet.name) .. amount)
		end
		if i ~= #fullgrowns then
			con(", ")
		end
	end

	con("\n", "```", "\n")
	con("```prolog", "\n")
	con("Total pets: ", totals.overall, "\n")
	con("Total neons: ", totals.neons, "\n")
	con("Total fullgrowns: ", totals.fullgrowns, "\n")
	con("Completion: ", math.floor(totals.fullgrowns / totals.overall * 100), " / 100%", "\n")
	con("```", "\n")
	return str
end

local Commands = {}

Commands["trade"] = function(Args: StandardArgs) -- Trade item(s) to target
	local Targets: {Player} = GetTargets(Args) or {}
	local MultipleTargets = #Targets > 1
	local Filters: Filters = GetFilters(Args)

	local Trade: Trade = {}
	Trade.Filters = Filters
	Trade.Targets = Targets
	Trade.Sender = Args.Sender

	if MultipleTargets then
		Trade.Giver = Args.Sender
		SetupMultipleTrades(Trade)
	else
		UpdateStatus(LocalPlayer, {["IsTrading"] = true, ["CurrentTask"] = Args.CommandName})
		Trade.Reciever = Targets[1]
		Trade.Giver = Args.Sender
		SetupTrade(Trade)
	end
end

Commands["add"] = function(Args: StandardArgs) -- Add item(s) to current trade
	warn("The '".. Prefix .. Args.CommandName .."' command is currently disabled.")
end

Commands["get"] = function(Args: StandardArgs) -- Get item(s) from targets
	local Targets: {Player} = GetTargets(Args) or {}
	local MultipleTargets = #Targets > 1
	local Filters: Filters = GetFilters(Args)

	local Trade: Trade = {}
	Trade.Filters = Filters
	Trade.Targets = Targets
	Trade.Sender = Args.Sender

	if MultipleTargets then
		Trade.Reciever = Args.Sender
		SetupMultipleTrades(Trade)
	else
		Trade.Giver = Targets[1]
		Trade.Reciever = Args.Sender
		UpdateStatus(LocalPlayer, {["IsTrading"] = true, ["CurrentTask"] = Args.CommandName})
		SetupTrade(Trade)
	end
end

Commands["distribute"] = function(Args: StandardArgs) -- Distribute items to targets
	local Targets: {Player} = GetTargets(Args) or {}
	local MultipleTargets = #Targets > 1
	local Filters: Filters = GetFilters(Args)
	local IsSender = (LocalPlayer == Args.Sender)
	local Inventories, TargetItems = {}, {}

	for i = 1, #Targets do
		Inventories[Targets[i].Name:lower()] = {}
	end

	if IsSender then
		local Inventory = GetInventory()

		for _, Category in Filters.Categories do
			if not Inventory[Category] then continue end
			TargetItems = ValidateItems({["Items"] = Inventory[Category], ["Filters"] = Filters})
			print(PrintTable(TargetItems, "TargetItems"))
		end

		if TargetItems.ListType ~= "[alt list]" and next(TargetItems) == nil then return end
		
		local ItemsPerInventory = #TargetItems / #Targets
		local Index = 1

		for i, Item in TargetItems do
			if i == "ListType" then continue end
			if TargetItems.ListType == "[alt list]" then
				Inventories[i] = Item or {}
			elseif TargetItems.ListType == "[pet list]" then
				table.insert(Inventories[Targets[Index].Name], Item)
			end
			
			Index = Index == #Targets and 1 or Index + 1
		end

		print(OutputSeperator)
		if TargetItems.ListType == "[pet list]" then
			warn(#TargetItems, "items total.")
			warn(ItemsPerInventory, "items per inventory.")
		end
		print(PrintTable(Inventories, "Inventories"))
	end

	local Trade: Trade = {}
	Trade.Targets = Targets
	Trade.Giver = Args.Sender
	Trade.Sender = Args.Sender
	Trade.ListType = TargetItems.ListType
	
	if MultipleTargets then
		Trade.Items = Inventories
		SetupMultipleTrades(Trade)
	else
		UpdateStatus(LocalPlayer, {["IsTrading"] = true, ["CurrentTask"] = Args.CommandName})
		Trade.Reciever = Targets[1]
		Trade.Items = Inventories[Trade.Reciever.Name]
		SetupTrade(Trade)
	end
end

Commands["accept"] = function(Args) AcceptOrDeclineTrade(Args, true) end

Commands["decline"] = function(Args) AcceptOrDeclineTrade(Args, false) end

Commands["cancel"] = function(Args: StandardArgs) 
	Args.IncludeSender = true
	local Targets: {Player} = GetTargets(Args)

	for _, Target in Targets do
		local CurrentTask = UpdateStatus(Target, nil, {"CurrentTask"})
		if CurrentTask and CurrentTask[1] == "" then warn(LocalPlayer == Target and "You have" or Target.Name .." has" ,"no current task.", Args.Ignored) return end
		warn("Canceled current task: ".. CurrentTask[1])
		API:WaitForChild("TradeAPI/DeclineNegotiation"):FireServer()
	end
end

Commands["add_alt"] = function(Args: StandardArgs) -- Add alt(s) to alts list
	if Args.Sender ~= LocalPlayer then return end
	local Targets: {Player} = GetTargets(Args)

	for _, Target in Targets do
		if Accounts[Target.Name] then warn("Player '".. Target.Name .."' is already in your 'Accounts' list. Do '".. Prefix .. Args.CommandName .."' to remove accounts.") continue end
		Accounts[Target.Name] = {["CurrentTask"] = "", ["IsTrading"] = false, ["TaskAmount"] = 0}
		print("Added alt:", Target.Name)
	end
end

Commands["remove_alt"] = function(Args: StandardArgs) -- Remove alt(s) from alts list
	if Args.Sender ~= LocalPlayer then return end
	local Targets: {Player} = GetTargets(Args)
	for _, Target in Targets do
		if not Accounts[Target.Name] then continue end
		Accounts[Target.Name] = nil
		print("Removed alt:", Target.Name)
	end
end

Commands["change_seperators"] = function(Args: StandardArgs) -- Change current arguement seperators
	if Args.Sender ~= LocalPlayer then return end
	if not Args.Opening and not Args.Closing then warn("No opening or closing seperator specified.", Args.Ignored) return end
	local Opening = Args.Opening and Args.Opening[1] or ArgumentSeperators.Opening
	local Closing = Args.Closing and Args.Closing[1] or ArgumentSeperators.Closing

	if Opening == Closing then warn("Invalid seperators. You can not have the same opening/closing seperator. |", ArgumentSeperators.Opening) return end
	if not Opening:match("%W") then warn("Opening separator is not a special character.", Args.Ignored) return end
	if not Closing:match("%W") then warn("Closing separator is not a special character.", Args.Ignored) return end
	if #string.split(Opening, "") > 1 then warn("Opening separator must be a single special character.", Args.Ignored) return end
	if #string.split(Closing, "") > 1 then warn("Closing separator must be a single special character.", Args.Ignored) return end

	ArgumentSeperators.Opening = Opening
	ArgumentSeperators.Closing = Closing
end

Commands["change_prefix"] = function(Args: StandardArgs) -- Change current prefix
	if Args.Sender ~= LocalPlayer then return end
	local BlacklistedCharacters = {"/", "?"}
	local NewPrefix = Args.Prefix or Args.prefix

	if not NewPrefix then warn("No prefix specified.", Args.Ignored) return end
	if #NewPrefix > 1 then warn("Only 1 character is required for the '".. Prefix .. Args.CommandName .."' command.") return end

	NewPrefix = NewPrefix[1]

	if table.find(BlacklistedCharacters, NewPrefix) then warn("Cannot set prefix to blacklisted character: '".. NewPrefix .."'.", Args.Ignored) return end
	if not NewPrefix:match("%W") then warn("Given prefix is not a special character.", Args.Ignored) return end

	print("Changed current prefix '".. Prefix .."'' to new prefix:", NewPrefix ..".")
	Prefix = NewPrefix
end

Commands["inventory"] = function(Args: StandardArgs) -- Send inventory through webhook
	if Args.Sender ~= LocalPlayer then return end
	if Webhook == "" then warn("You never entered your webhook url.", Prefix .. Args.CommandName ,"ignored.") return end
	local Filters: Filters = GetFilters(Args)
	local Inventory = GetInventory()
	local TargetItems, Items = {}, {}
	for _, Unique in ValidateItems({["Items"] = Inventory, ["Filters"] = Filters}) do table.insert(TargetItems, Unique) end

	for Unique, Info in Inventory.pets do
		if not table.find(TargetItems, Unique) then
			Inventory[Unique] = nil
		else
			if Items[Info.kind] then Items[Info.kind].amount += 1	continue end
			local Item = {}
			Item.name = Info.kind
			Item.neon = Info.properties.neon or false
			Item.fullgrown = Info.properties.age and Info.properties.age == 6 or 1
			Item.amount = 1
			Items[Info.kind] = Item
		end
		task.wait()
	end

	local InventoryEmbed: DiscordEmbed = {}
	InventoryEmbed.title = "**".. LocalPlayer.Name .."'s Pets**"
	InventoryEmbed.description = FormatInventoryToString(Items)
	InventoryEmbed.type = "rich"
	InventoryEmbed.color = 1974050

	local ProccessEmbeds = game:GetService("HttpService"):JSONEncode({["embeds"] = {InventoryEmbed}})

	request({
		["Url"] = Webhook, 
		["Body"] = ProccessEmbeds, 
		["Method"] = "POST", 
		["Headers"] = {["content-type"] = "application/json"}
	})
end

Commands["money"] = function(Args: StandardArgs)
	warn("The '".. Prefix .. Args.CommandName .."' command is currently disabled.")
end

Commands["help"] = function(Args) -- Standard help command
	if Args.Sender ~= LocalPlayer then return end
	local CommandMessages = {
		["trade"] --[[-----]] = {
			Description = "The '*Trade' command lets you trade your items to a specified target. Use the '*Distribute' command if you have multiple targets",
			Parameters  = "*Trade {Target} {Category} {Properties} {Name} {Amount}"
		},
		["add"] --[[-------]] = {
			Description = "The '*Add' command lets you add items or pets to a target's current trade.  It will accept your current trade if you don't specify any target(s). Will be ignored if the trade is full.",
			Parameters  = "*Add {Targets} {Category} {Properties} {Name} {Amount}"
		},
		["get"] --[[-------]] = {
			Description = "The '*Get' command makes specified targets trade their items to the sender.",
			Parameters  = "*Get {Targets} {Category} {Properties} {Name} {Amount}"
		},
		["distribute"] --[[]] = {
			Description = "The '*Distribute' command allows you to distribute items or pets evenly across specified targets. Use the '*Trade' command if you only have 1 target.",
			Parameters  = "*Distribute {Targets} {Category} {Properties} {Name} {Amount}"
		},
		["accept"] --[[----]] = {
			Description = "The '*Accept' command lets you accept a target's current trade. It will accept your current trade if you don't specify any target(s).",
			Parameters  = "*Accept {Targets} {Category} {Properties} {Name} {Amount}"
		},
		["decline"] --[[---]] = {
			Description = "The '*Decline' command lets you decline a target's current trade. It will decline your current trade if you don't specify any target(s).",
			Parameters  = "*Decline {Targets} {Category} {Properties} {Name} {Amount}"
		},
		["cancel"] --[[----]] = {
			Description = "The '*Cancel' command allows you to cancel any task that requires multiple actions. e.g. distributing, trading more than 18 items, etc.",
			Parameters  = "*Cancel {Targets} {Category} {Properties} {Name} {Amount}"
		},
		["change_seperators"] = {
			Description = "The '*Change_Seperators' command lets you change the opening/closing argument seperators to any special character.",
			Parameters  = "*Change_Seperators {Opening} {Closing}"
		},
		["change_prefix"] = {
			Description = "The '*Change_Prefix' command lets you change the current prefix to any (whitelisted) special character.",
			Parameters  = "*Change_Prefix {Prefix} | Blacklisted characters: '/', '?'"
		},
		["add_alt"] = {
			Description = "The '*Add_Alt' command lets you add an alt account to your 'Accounts' list. The alt(s) you want to add must be ingame otherwise this command will be ignored.",
			Parameters  = "*Add_Alt {Targets}"
		},
		["remove_alt"] = {
			Description = "The '*Remove_Alt' command lets you remove an alt account from your 'Accounts' list. The alt(s) you want to add must be in the list otherwise this command will be ignored.",
			Parameters  = "*Remove_Alt {Targets}"
		}
	}

	if not Args.command or not Args.commands then for CommandName, _ in CommandMessages do print(Prefix .. CommandName) end return end
	local TargetCommands = Args.commands or Args.command or {}
	if next(TargetCommands) == nil then return end

	if table.find(TargetCommands, "all") or table.find(TargetCommands, "All") then
		TargetCommands = {}; for CommandName, _ in CommandMessages do table.insert(TargetCommands, CommandName) end
	end

	for _, TargetCommand in TargetCommands do
		TargetCommand = (string.gsub(string.lower(TargetCommand), Prefix, ""))
		if not CommandMessages[TargetCommand] then warn("Command '".. TargetCommand .."' not found.") continue end
		TargetCommand = CommandMessages[TargetCommand]
		print((string.gsub(TargetCommand.Description, "*", Prefix)))
		warn((string.gsub(TargetCommand.Parameters, "*", Prefix)))
		print(" ")
	end
end

local function ValidateCommand(Message: string, Sender: Player)
	local Opening = table.find(SpecialCharacters, ArgumentSeperators.Opening) and "%".. ArgumentSeperators.Opening or ArgumentSeperators.Opening
	local Closing = table.find(SpecialCharacters, ArgumentSeperators.Closing) and "%".. ArgumentSeperators.Closing or ArgumentSeperators.Closing

	local Command = Message:match("^" .. Prefix .. "(%S+)")
	Command = string.lower(Command or "[no command]")
	if not Commands[Command] then return end

	local Args = {}

	for Arg, Value in Message:gmatch(Opening .. "(.-)%s*:%s*(.-)" .. Closing) do
		local Values = {}
		for v in Value:gmatch("([^,%s]+)") do
			table.insert(Values, v)
		end
		Args[string.lower(Arg)] = Values
	end

	if testing then 
		print(OutputSeperator)
		print("Sender:", Sender.Name)
		print("Command:", Command)
		print(next(Args) ~= nil and "There are arguments" or "There are no arguments", PrintTable(Args)) 
		print(OutputSeperator)
	end

	Args.Sender = Sender
	Args.CommandName = Title(Command)
	Args.Ignored = "'".. Prefix .. Args.CommandName .."' ignored."

	Commands[Command](Args)
end

local TextChatService = game:GetService("TextChatService")

function Say(Message: string, IsSystemMessage: boolean)
	local Channel = IsSystemMessage and "RBXSystem" or "RBXGeneral"
	local TextChannel: TextChannel = TextChatService.TextChannels[Channel]
	TextChannel:SendAsync(Message)
end

local Connection = TextChatService.MessageReceived:Connect(function(Message: TextChatMessage)
	if not Message or not Message.TextSource then error("Error processing message. Got:".. typeof(Message)) end
	local Sender = Players:GetPlayerByUserId(Message.TextSource.UserId)

	if Accounts[Sender.Name] then
		for Account_Name, Info in Accounts do
			if Message.Text == "I'm finished trading, ".. Account_Name .."." then
				print("Reciever:", Account_Name, "| Sender:", Sender.Name)
				UpdateStatus(Players:FindFirstChild(Account_Name), {IsTrading = false, TaskAmount = 0})
				UpdateStatus(Sender, {IsTrading = false, TaskAmount = 0})
				return
			end

			if Message.Text == "Let's trade, ".. Account_Name .."." then
				print("Reciever:", Account_Name, "| Sender:", Sender.Name)
				UpdateStatus(Players:FindFirstChild(Account_Name), {IsTrading = true, CurrentTask = "Distribute"})
				UpdateStatus(Sender, {IsTrading = true, CurrentTask = "Distribute"})
				return
			end

			if Message.Text == "I finished my current task." then
				print("Reciever:", Account_Name, "| Sender:", Sender.Name)
				UpdateStatus(Sender)
				return
			end
		end

		ValidateCommand(Message.Text, Sender)
	end
end)

Players.PlayerRemoving:Connect(function(Player: Player)
	if not Accounts[Player.Name] then return end
	UpdateStatus(Player)
end)

game.StarterGui:SetCore("SendNotification", {
	Title = "Success";
	Text = "Listening for commands.";
	Duration = 5;
})
