for _, connection in getgenv().libraryConnections or {} do
	connection:Disconnect()
end

if getgenv().libraryRoot then
	getgenv().libraryRoot:Destroy()
end

if getgenv().libraryCleanup then getgenv().libraryCleanup() end

getgenv().libraryConnections = {}

local function track(connection)
	table.insert(getgenv().libraryConnections, connection)
	return connection
end

local services = setmetatable({}, {
	__index = function(self, name)
		local service = cloneref(game:GetService(name))
		rawset(self, name, service)
		return service
	end,
})

local UserInputService, HttpService, TweenService = services.UserInputService, services.HttpService, services.TweenService
local CoreGui, players = services.CoreGui, services.Players
local tweenInfo = TweenInfo.new(0.1)

local library = {
	directory = "prism",
	services = services,
	flags = {},
	themeBindings = {},
	richTextBindings = {},
	keybindRefreshers = {},
	keybindListMode = "all",
}

local storageFolder, configFolder = `{library.directory}/storage`, `{library.directory}/configs`
library.configFolder = configFolder

for _, folder in {library.directory, storageFolder, configFolder} do
	if not isfolder(folder) then makefolder(folder) end
end

library.theme = {
	accent = Color3.fromRGB(138, 201, 222),
	outline1 = Color3.fromRGB(0, 0, 0),
	outline2 = Color3.fromRGB(46, 46, 46),
	background = Color3.fromRGB(9, 9, 9),
	gradient = Color3.fromRGB(18, 18, 18),
	textColor = Color3.fromRGB(151, 151, 151),
	inactiveTextColor = Color3.fromRGB(63, 63, 63),
}

library.keyNames = {
	[Enum.KeyCode.LeftShift] = "LS",
	[Enum.KeyCode.RightShift] = "RS",
	[Enum.KeyCode.LeftControl] = "LC",
	[Enum.KeyCode.RightControl] = "RC",
	[Enum.KeyCode.LeftAlt] = "LA",
	[Enum.KeyCode.RightAlt] = "RA",
	[Enum.KeyCode.Insert] = "INS",
	[Enum.KeyCode.Backspace] = "BS",
	[Enum.KeyCode.Return] = "Ent",
	[Enum.KeyCode.CapsLock] = "CAPS",
	[Enum.KeyCode.Escape] = "ESC",
	[Enum.KeyCode.Space] = "SPC",
	[Enum.KeyCode.Minus] = "-",
	[Enum.KeyCode.Equals] = "=",
	[Enum.KeyCode.Tilde] = "~",
	[Enum.KeyCode.LeftBracket] = "[",
	[Enum.KeyCode.RightBracket] = "]",
	[Enum.KeyCode.LeftParenthesis] = "(",
	[Enum.KeyCode.RightParenthesis] = ")",
	[Enum.KeyCode.Semicolon] = ";",
	[Enum.KeyCode.Quote] = "'",
	[Enum.KeyCode.BackSlash] = "\\",
	[Enum.KeyCode.Comma] = ",",
	[Enum.KeyCode.Period] = ".",
	[Enum.KeyCode.Slash] = "/",
	[Enum.KeyCode.Asterisk] = "*",
	[Enum.KeyCode.Plus] = "+",
	[Enum.KeyCode.Backquote] = "`",
	[Enum.UserInputType.MouseButton1] = "MB1",
	[Enum.UserInputType.MouseButton2] = "MB2",
	[Enum.UserInputType.MouseButton3] = "MB3",
}

for digit, name in {"Zero", "One", "Two", "Three", "Four", "Five", "Six", "Seven", "Eight", "Nine"} do
	library.keyNames[Enum.KeyCode[name]] = tostring(digit - 1)
	library.keyNames[Enum.KeyCode[`Keypad{name}`]] = `Num{digit - 1}`
end

local flagMeta = {
	__index = function(self, key)
		if key == "value" then return self.get() end
	end,
	__newindex = function(self, key, value)
		if key == "value" then self.set(value) return end
		rawset(self, key, value)
	end,
}

local function registerFlag(flag, get, set)
	if not flag then return end
	library.flags[flag] = setmetatable({get = get, set = set}, flagMeta)
end

local themeNames = {}

local function colorKey(color)
	return `{math.round(color.R * 255)},{math.round(color.G * 255)},{math.round(color.B * 255)}`
end

local function indexTheme()
	table.clear(themeNames)
	for name, color in library.theme do themeNames[colorKey(color)] = name end
end

indexTheme()

local function sanitizeNumber(text)
	local result, hasDot = "", false

	for i = 1, #text do
		local char = text:sub(i, i)

		if char:match("%d") or (char == "-" and i == 1) then
			result ..= char
		elseif char == "." and not hasDot then
			result ..= char
			hasDot = true
		end
	end

	return result
end

local function formatDate()
	local day = tonumber(os.date("%d"))
	local suffix = (day % 100 >= 11 and day % 100 <= 13) and "th" or ({"st", "nd", "rd"})[day % 10] or "th"
	return os.date(`%A, {day}{suffix} of %B %Y`):lower()
end

local function download(name, url)
	local file = `{storageFolder}/{name}`
	if not isfile(file) then writefile(file, game:HttpGet(url)) end
	return getcustomasset(file)
end

local fontAsset, familyFile = download("tohama-8px.ttf", "https://github.com/swageph/roblox/raw/refs/heads/main/storage/tohama-8px.ttf"), `{storageFolder}/tohama-8px.font`

if not isfile(familyFile) then
	writefile(familyFile, HttpService:JSONEncode({name = "tohama-8px", faces = {{name = "Normal", weight = 400, style = "normal", assetId = fontAsset}}}))
end

library.font = Font.new(getcustomasset(familyFile), Enum.FontWeight.Regular, Enum.FontStyle.Normal)

library.images = {
	alphaChecker = download("alpha-checker.png", "https://raw.githubusercontent.com/swageph/roblox/refs/heads/main/storage/alpha-checker.png"),
	dropdownState = download("dropdown-state.png", "https://raw.githubusercontent.com/swageph/roblox/refs/heads/main/storage/dropdown-state.png"),
}

local function registerThemeBinding(instance, property, value)
	local color = typeof(value) == "Color3" and value

	if typeof(value) == "ColorSequence" then
		color = value.Keypoints[1].Value
		for _, keypoint in value.Keypoints do
			if keypoint.Value ~= color then return end
		end
	end

	local name = color and themeNames[colorKey(color)]
	if not name then return end

	library.themeBindings[instance] = library.themeBindings[instance] or {}
	library.themeBindings[instance][property] = name
end

function library:create(className, properties)
	local instance = Instance.new(className)
	properties = properties or {}

	instance.Name = "\000"
	if instance:IsA("GuiObject") then instance.BorderSizePixel = 0 end
	if className == "UIStroke" then instance.LineJoinMode = Enum.LineJoinMode.Miter end

	for property, value in properties do
		if property == "Parent" then continue end
		instance[property] = value
		registerThemeBinding(instance, property, value)
	end

	instance.Parent = properties.Parent
	return instance
end

function library:tween(instance, info, properties)
	TweenService:Create(instance, info, properties):Play()

	for property, value in properties do
		registerThemeBinding(instance, property, value)
	end
end

local function bindAccent(instance, template)
	library.richTextBindings[instance] = template
	instance.Text = template:gsub("{accent}", library.theme.accent:ToHex())
end

function library:createRichText(className, properties)
	properties = properties or {}
	properties.RichText = true

	local instance = library:create(className, properties)
	bindAccent(instance, properties.Text)
	return instance
end

function library:setTheme(name, color)
	library.theme[name] = color
	indexTheme()

	for instance, bindings in library.themeBindings do
		if not instance.Parent then
			library.themeBindings[instance] = nil
			continue
		end

		for property, boundName in bindings do
			if boundName ~= name then continue end
			instance[property] = typeof(instance[property]) == "ColorSequence" and ColorSequence.new(color) or color
		end
	end

	if name ~= "accent" then return end

	for instance, template in library.richTextBindings do
		if instance.Parent then bindAccent(instance, template) else library.richTextBindings[instance] = nil end
	end
end

local function createText(properties)
	local merged = {AutomaticSize = Enum.AutomaticSize.XY, BackgroundTransparency = 1, FontFace = library.font, RichText = true, TextColor3 = library.theme.textColor, TextSize = 12}
	for property, value in properties do merged[property] = value end

	local label = library:create("TextLabel", merged)

	merged.Text, merged.TextColor3, merged.ZIndex = label.Text:gsub("<[^>]->", ""), library.theme.outline1, 0
	merged.Position = label.Position + UDim2.fromOffset(1, 1)

	local shadow = library:create("TextLabel", merged)

	label:GetPropertyChangedSignal("Text"):Connect(function()
		shadow.Text = label.Text:gsub("<[^>]->", "")
	end)

	return label, shadow
end

local function createHitbox(parent, zIndex)
	return library:create("TextButton", {AutoButtonColor = false, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Text = "", ZIndex = zIndex or 1, Parent = parent})
end

local function createField(properties)
	properties.BackgroundColor3 = library.theme.gradient

	local field = library:create("Frame", properties)
	library:create("UIGradient", {Rotation = 90, Transparency = NumberSequence.new(0, 1), Parent = field})
	library:create("UIStroke", {BorderStrokePosition = Enum.BorderStrokePosition.Inner, Color = library.theme.outline2, Parent = field})
	return field
end

local function hoverText(button, label, locked)
	button.MouseEnter:Connect(function()
		if not locked() then library:tween(label, tweenInfo, {TextColor3 = library.theme.textColor}) end
	end)

	button.MouseLeave:Connect(function()
		if not locked() then library:tween(label, tweenInfo, {TextColor3 = library.theme.inactiveTextColor}) end
	end)
end

function library:notif(properties)
	properties = properties or {}
	local text, duration = properties.text or "notification!", properties.duration or 3

	if not library.notifHolder then
		library.notifHolder = library:create("CanvasGroup", {BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 999, Parent = library.addons})
		library:create("UIListLayout", {Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder, Parent = library.notifHolder})

		library:create("UIPadding", {
			PaddingBottom = UDim.new(0, 6),
			PaddingLeft = UDim.new(0, 6),
			PaddingRight = UDim.new(0, 6),
			PaddingTop = UDim.new(0, 6),
			Parent = library.notifHolder,
		})
	end

	local notifDisplay = library:create("CanvasGroup", {BackgroundTransparency = 1, Size = UDim2.fromOffset(0, 23), Parent = library.notifHolder})

	local notif = library:create("CanvasGroup", {
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = library.theme.background,
		Position = UDim2.fromOffset(2, 2),
		Size = UDim2.fromOffset(0, 19),
		Parent = notifDisplay,
	})

	library:create("UIStroke", {Color = library.theme.outline2, Parent = notif})
	library:create("UIStroke", {Color = library.theme.outline1, Thickness = 2, ZIndex = 0, Parent = notif})
	library:create("UIPadding", {PaddingRight = UDim.new(0, 6), Parent = notif})
	library:create("Frame", {BackgroundColor3 = library.theme.accent, Size = UDim2.new(0, 1, 1, 0), Parent = notif})
	createText({Text = text, Position = UDim2.fromOffset(6, 2), Parent = notif})

	task.spawn(function()
		task.wait()
		local width, info = notif.AbsoluteSize.X + 10, TweenInfo.new(0.25, Enum.EasingStyle.Quad)

		library:tween(notifDisplay, info, {Size = UDim2.fromOffset(width, notifDisplay.AbsoluteSize.Y)})

		task.delay(duration, function()
			library:tween(notifDisplay, info, {Size = UDim2.fromOffset(0, notifDisplay.AbsoluteSize.Y)})
			task.wait(0.25)
			notifDisplay:Destroy()
		end)
	end)

	return notifDisplay
end

local function isInside(instance, position)
	local topLeft, size = instance.AbsolutePosition, instance.AbsoluteSize
	return position.X >= topLeft.X and position.X <= topLeft.X + size.X and position.Y >= topLeft.Y and position.Y <= topLeft.Y + size.Y
end

local function relative(instance, position)
	local offset = (Vector2.new(position.X, position.Y) - instance.AbsolutePosition) / instance.AbsoluteSize
	return math.clamp(offset.X, 0, 1), math.clamp(offset.Y, 0, 1)
end

local function onDrag(handle, callback)
	handle.InputBegan:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
		callback(input.Position, true)

		local moved, released
		moved = UserInputService.InputChanged:Connect(function(change)
			if change.UserInputType == Enum.UserInputType.MouseMovement then callback(change.Position, false) end
		end)

		released = UserInputService.InputEnded:Connect(function(ended)
			if ended.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
			moved:Disconnect()
			released:Disconnect()
		end)
	end)
end

local function draggable(handle, target)
	local inputStart, startPosition

	onDrag(handle, function(position, began)
		if began then inputStart, startPosition = position, target.Position return end

		local delta = position - inputStart
		target.Position = UDim2.fromOffset(startPosition.X.Offset + delta.X, startPosition.Y.Offset + delta.Y)
	end)
end

local function openPopup(popup, position, storage, onClose)
	local connection

	local function close(input)
		connection:Disconnect()
		popup.Visible, popup.Parent = false, storage
		if onClose then onClose(input) end
	end

	popup.Position, popup.Parent, popup.Visible = position, library.screenGui, true

	connection = UserInputService.InputBegan:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.MouseButton2 then return end
		if not isInside(popup, input.Position) then close(input) end
	end)

	return close
end

local function createKeybindEntry(name)
	local keyInfo = library:create("Frame", {AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 1, Size = UDim2.fromOffset(0, 19), Visible = false, Parent = library.keybinds})
	library:create("UIPadding", {PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6), Parent = keyInfo})

	library:create("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Parent = keyInfo,
	})

	local key = createField({AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(13, 13), Parent = keyInfo})
	library:create("UIPadding", {PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 3), Parent = key})

	local keyValue = createText({AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromScale(1, 1), Parent = key})
	local keyState = library:create("Frame", {AutomaticSize = Enum.AutomaticSize.XY, BackgroundTransparency = 1, LayoutOrder = 1, Parent = keyInfo})
	local keyName = createText({Parent = keyState})

	return function(kb)
		local mode = library.keybindListMode
		local shown = kb.key ~= nil and (mode == "all" or (mode == "enabled" and kb.active) or (mode == "toggled" and kb.owner ~= nil and kb.owner.value == true))

		keyInfo.Visible = shown
		if not shown then return end

		local color = kb.active and library.theme.accent or library.theme.textColor

		keyValue.Text = library.keyNames[kb.key] or kb.key.Name
		keyName.Text = `{name} <font color="#{library.theme.inactiveTextColor:ToHex()}">({kb.mode:lower()})</font>`

		library:tween(keyValue, tweenInfo, {TextColor3 = color})
		library:tween(keyName, tweenInfo, {TextColor3 = color})
	end
end

function library:refreshKeybindList()
	for _, refresh in self.keybindRefreshers do refresh() end
end

local function createKeybind(parent, properties, storage, elementName, owner)
	properties = properties or {}

	local keybind = createField({AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = 999, Size = UDim2.fromOffset(13, 13), Parent = parent})
	library:create("UIPadding", {PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 3), Parent = keybind})

	local keybindValue = createText({AutomaticSize = Enum.AutomaticSize.X, Text = ". . .", Size = UDim2.fromScale(1, 1), Parent = keybind})
	local keybindButton = createHitbox(keybind, 5)

	local keybindModes = library:create("Frame", {
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = library.theme.background,
		Size = UDim2.fromOffset(60, 0),
		Visible = false,
		ZIndex = 20,
		Parent = storage,
	})

	library:create("UIStroke", {Color = library.theme.outline2, Parent = keybindModes})
	library:create("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder, Parent = keybindModes})

	local kb = {instance = keybind, key = properties.default, mode = "Toggle", owner = owner, active = false}
	local modeButtons, listening, closeModes = {}, false, nil
	local updateEntry = function() end

	if properties.showInList ~= false then
		local update = createKeybindEntry(properties.listText or elementName or "keybind")
		updateEntry = function() update(kb) end
		table.insert(library.keybindRefreshers, updateEntry)
	end

	local function refresh()
		keybindValue.Text = kb.key and (library.keyNames[kb.key] or kb.key.Name) or ". . ."
		updateEntry()
	end

	local function activate()
		if kb.active then return end
		kb.active = true
		updateEntry()
		if properties.onPress then properties.onPress() end
	end

	local function deactivate()
		if not kb.active then return end
		kb.active = false
		updateEntry()
		if properties.onRelease then properties.onRelease() end
	end

	local function syncAlways()
		if kb.mode ~= "Always" then return end
		if kb.key then activate() else deactivate() end
	end

	local function setMode(newMode)
		if newMode ~= kb.mode then
			kb.mode = newMode
			deactivate()
		end

		syncAlways()
		updateEntry()

		for name, modeButton in modeButtons do
			library:tween(modeButton, tweenInfo, {TextColor3 = name == newMode and library.theme.accent or library.theme.inactiveTextColor})
		end

		if closeModes then closeModes() end
	end

	local function matches(input)
		return input.UserInputType == kb.key or (input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == kb.key)
	end

	refresh()

	for order, name in {"Toggle", "Always", "Hold"} do
		local modeButton = library:create("TextButton", {
			AutoButtonColor = false,
			BackgroundTransparency = 1,
			FontFace = library.font,
			LayoutOrder = order,
			Size = UDim2.new(1, 0, 0, 19),
			Text = name:lower(),
			TextColor3 = name == kb.mode and library.theme.accent or library.theme.inactiveTextColor,
			TextSize = 12,
			Parent = keybindModes,
		})

		modeButtons[name] = modeButton
		hoverText(modeButton, modeButton, function() return kb.mode == name end)

		modeButton.MouseButton1Click:Connect(function()
			setMode(name)
		end)
	end

	keybindButton.MouseButton2Click:Connect(function()
		local position = keybind.AbsolutePosition
		closeModes = openPopup(keybindModes, UDim2.fromOffset(position.X + keybind.AbsoluteSize.X + 2, position.Y + 1), storage)
	end)

	keybindButton.MouseButton1Click:Connect(function()
		if listening then return end
		listening = true
		keybindValue.Text = ". . ."
		library:tween(keybindValue, tweenInfo, {TextColor3 = library.theme.accent})

		local connection
		connection = UserInputService.InputBegan:Connect(function(input)
			if input.UserInputType ~= Enum.UserInputType.Keyboard and not library.keyNames[input.UserInputType] then return end

			connection:Disconnect()
			listening = false
			library:tween(keybindValue, tweenInfo, {TextColor3 = library.theme.textColor})

			local newKey = input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode or input.UserInputType
			kb.key = newKey ~= Enum.KeyCode.Escape and newKey or nil

			refresh()
			syncAlways()
			if properties.callback then properties.callback(kb.key) end
		end)
	end)

	track(UserInputService.InputBegan:Connect(function(input)
		if listening or not kb.key or not matches(input) then return end

		if kb.mode == "Toggle" then
			if kb.active then deactivate() else activate() end
		elseif kb.mode == "Hold" then
			activate()
		end
	end))

	track(UserInputService.InputEnded:Connect(function(input)
		if kb.key and kb.mode == "Hold" and matches(input) then deactivate() end
	end))

	function kb:set(newKey, newMode)
		self.key = newKey
		refresh()
		setMode(newMode or self.mode)
		if properties.callback then properties.callback(self.key) end
	end

	registerFlag(properties.flag, function()
		return {mode = kb.mode, key = kb.key and {tostring(kb.key.EnumType), kb.key.Name}}
	end, function(value)
		kb:set(value.key and Enum[value.key[1]][value.key[2]], value.mode)
	end)

	if modeButtons[properties.mode] then setMode(properties.mode) end
	if properties.active then activate() end

	return kb
end

local function createColorPicker(parent, properties, storage)
	properties = properties or {}
	local color, alpha = properties.default or Color3.fromRGB(255, 255, 255), properties.alpha or 1
	local enableAlpha = properties.enableAlpha ~= false

	local colorPickerChecker = library:create("ImageLabel", {
		BackgroundTransparency = 1,
		Image = library.images.alphaChecker,
		ImageTransparency = 0.8,
		LayoutOrder = 998,
		ScaleType = Enum.ScaleType.Tile,
		Size = UDim2.fromOffset(13, 13),
		TileSize = UDim2.fromOffset(7, 7),
		Parent = parent,
	})

	local colorPicker = library:create("Frame", {Size = UDim2.fromScale(1, 1), Parent = colorPickerChecker})
	local colorPickerStroke = library:create("UIStroke", {BorderStrokePosition = Enum.BorderStrokePosition.Inner, Parent = colorPicker})
	library:create("UIGradient", {Rotation = 90, Transparency = NumberSequence.new(0, 0.5), Parent = colorPickerStroke})
	library:create("UIGradient", {Rotation = 270, Transparency = NumberSequence.new(0, 0.5), Parent = colorPicker})
	local colorPickerButton = createHitbox(colorPicker, 5)

	local colorPickerWindow = library:create("Frame", {
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = library.theme.background,
		Size = UDim2.fromOffset(160, 180),
		Visible = false,
		ZIndex = 20,
		Parent = storage,
	})

	library:create("UIStroke", {Color = library.theme.outline2, Parent = colorPickerWindow})
	library:create("UIListLayout", {Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = colorPickerWindow})

	library:create("UIPadding", {
		PaddingBottom = UDim.new(0, 7),
		PaddingLeft = UDim.new(0, 7),
		PaddingRight = UDim.new(0, 7),
		PaddingTop = UDim.new(0, 7),
		Parent = colorPickerWindow,
	})

	local function createKnob(bar, transparency)
		local holder = library:create("Frame", {BackgroundTransparency = 1, Position = UDim2.fromOffset(3, 3), Size = UDim2.new(1, -6, 1, -6), ZIndex = 2, Parent = bar})
		local knob = library:create("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = transparency, Size = UDim2.fromOffset(6, 6), ZIndex = 100, Parent = holder})

		library:create("UIStroke", {Color = library.theme.outline1, Transparency = 0.9, Parent = knob})
		library:create("Frame", {BackgroundTransparency = 0.5, Size = UDim2.fromScale(1, 1), ZIndex = 101, Parent = knob}).BackgroundColor3 = Color3.new()
		return knob, holder
	end

	local satValueHolder = library:create("Frame", {Size = UDim2.new(1, 0, 0, 130), Parent = colorPickerWindow})
	library:create("UIStroke", {Color = library.theme.outline2, Parent = satValueHolder})

	local saturation = library:create("Frame", {Size = UDim2.fromScale(1, 1), ZIndex = 2, Parent = satValueHolder})
	local saturationGradient = library:create("UIGradient", {Rotation = 270, Transparency = NumberSequence.new(0, 1), Parent = saturation})

	local valueOverlay = library:create("Frame", {Size = UDim2.fromScale(1, 1), Parent = satValueHolder})
	library:create("UIGradient", {Transparency = NumberSequence.new(0, 1), Parent = valueOverlay})

	local satValuePicker, satValuePickerHolder = createKnob(satValueHolder, 0.5)
	local satValueButton = createHitbox(satValuePickerHolder, 5)

	local hueBar = library:create("Frame", {LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 6), Parent = colorPickerWindow})
	library:create("UIStroke", {Color = library.theme.outline2, Parent = hueBar})

	saturation.BackgroundColor3, valueOverlay.BackgroundColor3, hueBar.BackgroundColor3 = Color3.new(1, 1, 1), Color3.new(1, 1, 1), Color3.new(1, 1, 1)
	saturationGradient.Color = ColorSequence.new(Color3.new())

	library:create("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 0, 0)),
			ColorSequenceKeypoint.new(0.17, Color3.fromRGB(255, 255, 0)),
			ColorSequenceKeypoint.new(0.33, Color3.fromRGB(0, 255, 0)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(0, 255, 255)),
			ColorSequenceKeypoint.new(0.67, Color3.fromRGB(0, 0, 255)),
			ColorSequenceKeypoint.new(0.83, Color3.fromRGB(255, 0, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 0, 0)),
		}),
		Parent = hueBar,
	})

	local hueButton = createHitbox(hueBar, 5)
	local huePicker = createKnob(hueBar, 0)

	local rgbInput = library:create("Frame", {BackgroundTransparency = 1, LayoutOrder = 3, Size = UDim2.new(1, 0, 0, 19), Parent = colorPickerWindow})
	library:create("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = rgbInput})

	local rgb = library:create("Frame", {BackgroundColor3 = library.theme.gradient, Size = UDim2.fromOffset(enableAlpha and 97 or 146, 19), Parent = rgbInput})
	library:create("UIGradient", {Rotation = 90, Transparency = NumberSequence.new(0, 1), Parent = rgb})
	library:create("UIStroke", {Color = library.theme.outline2, Parent = rgb})

	local rgbValues = library:create("TextBox", {
		BackgroundTransparency = 1,
		ClearTextOnFocus = false,
		FontFace = library.font,
		RichText = true,
		Size = UDim2.fromScale(1, 1),
		TextColor3 = library.theme.textColor,
		TextSize = 12,
		Parent = rgb,
	})

	local alphaBar, alphaButton, alphaPicker, alphaValues

	if enableAlpha then
		local alphaChecker = library:create("ImageLabel", {
			BackgroundTransparency = 1,
			Image = library.images.alphaChecker,
			ImageTransparency = 0.8,
			LayoutOrder = 2,
			ScaleType = Enum.ScaleType.Tile,
			Size = UDim2.new(1, 0, 0, 6),
			TileSize = UDim2.fromOffset(7, 7),
			Parent = colorPickerWindow,
		})

		alphaBar = library:create("Frame", {Size = UDim2.fromScale(1, 1), Parent = alphaChecker})
		library:create("UIStroke", {Color = library.theme.outline2, Parent = alphaBar})
		library:create("UIGradient", {Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(30, 30, 30)), Rotation = 180, Transparency = NumberSequence.new(0, 1), Parent = alphaBar})
		alphaButton = createHitbox(alphaBar, 5)
		alphaPicker = createKnob(alphaBar, 0)

		local alphaInput = library:create("Frame", {BackgroundColor3 = library.theme.gradient, LayoutOrder = 1, Size = UDim2.fromOffset(40, 19), Parent = rgbInput})
		library:create("UIGradient", {Rotation = 90, Transparency = NumberSequence.new(0, 1), Parent = alphaInput})
		library:create("UIStroke", {Color = library.theme.outline2, Parent = alphaInput})

		alphaValues = library:create("TextBox", {
			BackgroundTransparency = 1,
			ClearTextOnFocus = false,
			FontFace = library.font,
			RichText = true,
			Size = UDim2.fromScale(1, 1),
			TextColor3 = library.theme.textColor,
			TextSize = 12,
			Parent = alphaInput,
		})
	end

	local h, s, v = color:ToHSV()
	local colorObject = {instance = colorPicker, color = color, alpha = alpha}

	local function update()
		local hueColor, final = Color3.fromHSV(h, 1, 1), Color3.fromHSV(h, s, v)
		colorObject.color, colorObject.alpha = final, alpha

		satValueHolder.BackgroundColor3, huePicker.BackgroundColor3, satValuePicker.BackgroundColor3 = hueColor, hueColor, final
		satValuePicker.Position, huePicker.Position = UDim2.fromScale(s, 1 - v), UDim2.fromScale(h, 0.5)

		colorPicker.BackgroundColor3, colorPicker.BackgroundTransparency, colorPickerStroke.Color = final, 1 - alpha, final
		rgbValues.Text = `{math.round(final.R * 255)}, {math.round(final.G * 255)}, {math.round(final.B * 255)}`

		if enableAlpha then
			alphaBar.BackgroundColor3, alphaPicker.BackgroundColor3 = hueColor, hueColor
			alphaPicker.Position = UDim2.fromScale(alpha, 0.5)
			alphaValues.Text = `{math.round(alpha * 100) / 100}`
		end

		if properties.callback then properties.callback(final, alpha) end
	end

	update()

	onDrag(satValueButton, function(position)
		local x, y = relative(saturation, position)
		s, v = x, 1 - y
		update()
	end)

	onDrag(hueButton, function(position)
		h = relative(hueBar, position)
		update()
	end)

	if enableAlpha then
		onDrag(alphaButton, function(position)
			alpha = relative(alphaBar, position)
			update()
		end)

		alphaValues.FocusLost:Connect(function()
			local newAlpha = tonumber(alphaValues.Text)
			if newAlpha then alpha = math.clamp(newAlpha, 0, 1) end
			update()
		end)
	end

	rgbValues.FocusLost:Connect(function()
		local r, g, b = rgbValues.Text:match("^([^,]+),([^,]+),([^,]+)$")
		r, g, b = tonumber(r), tonumber(g), tonumber(b)

		if r and g and b then h, s, v = Color3.fromRGB(r, g, b):ToHSV() end
		update()
	end)

	colorPickerButton.MouseButton1Click:Connect(function()
		local position = colorPicker.AbsolutePosition
		openPopup(colorPickerWindow, UDim2.fromOffset(position.X + colorPicker.AbsoluteSize.X + 2, position.Y + 1), storage)
	end)

	function colorObject:set(newColor, newAlpha)
		h, s, v = newColor:ToHSV()
		alpha = newAlpha or alpha
		update()
	end

	registerFlag(properties.flag, function()
		return {colorObject.color:ToHex(), colorObject.alpha}
	end, function(value)
		colorObject:set(Color3.fromHex(value[1]), value[2])
	end)

	return colorObject
end

local function addAddons(object, parent, storage, name, owner)
	local addons = library:create("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.fromOffset(0, 19),
		ZIndex = 10,
		Parent = parent,
	})

	library:create("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Parent = addons,
	})

	object.addons = addons

	function object:keybind(properties)
		return createKeybind(addons, properties, storage, name, owner)
	end

	function object:colorPicker(properties)
		return createColorPicker(addons, properties, storage)
	end
end

local function addOptions(object, container, properties, onChange)
	local options, selected, buttons = properties.options or {}, {}, {}
	local multiSelect = properties.multiSelect ~= false

	for _, option in properties.default or {} do selected[option] = true end
	if properties.required and not next(selected) then selected[options[1]] = true end

	local function refresh(option)
		library:tween(buttons[option], tweenInfo, {TextColor3 = selected[option] and library.theme.accent or library.theme.inactiveTextColor})
	end

	local function commit(clicked)
		object.value = {}
		for _, option in options do
			if selected[option] then table.insert(object.value, option) end
		end

		if onChange then onChange(clicked) end
	end

	for _, option in options do
		local button = library:create("TextButton", {
			AutoButtonColor = false,
			BackgroundTransparency = 1,
			FontFace = library.font,
			RichText = true,
			Size = UDim2.new(1, 0, 0, 19),
			Text = option,
			TextColor3 = selected[option] and library.theme.accent or library.theme.inactiveTextColor,
			TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = container,
		})

		library:create("UIPadding", {PaddingLeft = UDim.new(0, 6), Parent = button})
		buttons[option] = button
		hoverText(button, button, function() return selected[option] end)

		button.MouseButton1Click:Connect(function()
			if multiSelect then
				selected[option] = not selected[option] or nil
				if properties.required and not next(selected) then selected[option] = true return end
				refresh(option)
			else
				selected = {[option] = true}
				for other in buttons do refresh(other) end
			end

			commit(true)
			if properties.callback then properties.callback(object.value) end
		end)
	end

	function object:set(newSelected)
		selected = {}
		for _, option in newSelected or {} do selected[option] = true end
		if properties.required and not next(selected) then selected[options[1]] = true end
		for option in buttons do refresh(option) end

		commit(false)
		if properties.callback then properties.callback(object.value) end
	end

	commit(false)

	registerFlag(properties.flag, function()
		return object.value
	end, function(value)
		object:set(value)
	end)
end

local function pageButtonFactory(parent, properties)
	local pageButton = library:create("Frame", {BackgroundColor3 = library.theme.gradient, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 19), Parent = parent})
	local pageState = library:create("Frame", {BackgroundColor3 = library.theme.accent, BackgroundTransparency = 0.6, Size = UDim2.new(0, 1, 1, 0), Parent = pageButton})
	library:create("UIGradient", {Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.5, 1), NumberSequenceKeypoint.new(1, 1)}), Parent = pageButton})

	local pageName = createText({Text = properties.title or "Page", TextColor3 = library.theme.inactiveTextColor, Position = UDim2.fromOffset(6, 2), Parent = pageButton})
	local pageSwitch, isSelected = createHitbox(pageButton), false

	local function setSelected(selected)
		isSelected = selected
		library:tween(pageButton, tweenInfo, {BackgroundTransparency = selected and 0 or 1})
		library:tween(pageState, tweenInfo, {BackgroundTransparency = selected and 0 or 0.6})
		library:tween(pageName, tweenInfo, {TextColor3 = selected and library.theme.textColor or library.theme.inactiveTextColor})
	end

	hoverText(pageSwitch, pageName, function() return isSelected end)
	return pageSwitch, setSelected
end

local function tabButtonFactory(parent, properties)
	local tabButton = library:create("Frame", {BackgroundTransparency = 1, Size = UDim2.fromOffset(100, 100), Parent = parent})
	local tabState = library:create("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		BackgroundColor3 = library.theme.accent,
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 1),
		Parent = tabButton,
	})

	local tabName = createText({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, -1),
		Text = properties.title or "Tab",
		TextColor3 = library.theme.inactiveTextColor,
		Parent = tabButton,
	})

	local tabSwitch, isSelected = createHitbox(tabButton), false

	local function setSelected(selected)
		isSelected = selected
		library:tween(tabState, tweenInfo, {BackgroundTransparency = selected and 0 or 1})
		library:tween(tabName, tweenInfo, {TextColor3 = selected and library.theme.textColor or library.theme.inactiveTextColor})
	end

	hoverText(tabSwitch, tabName, function() return isSelected end)
	return tabSwitch, setSelected
end

local function createColumn(parent, storage)
	local scrollingFrame = library:create("ScrollingFrame", {
		Active = true,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		CanvasSize = UDim2.fromScale(0, 0),
		ScrollBarThickness = 0,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Size = UDim2.fromOffset(100, 100),
		Parent = parent,
	})

	library:create("UIListLayout", {Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = scrollingFrame})
	library:create("UIPadding", {PaddingBottom = UDim.new(0, 6), PaddingTop = UDim.new(0, 6), Parent = scrollingFrame})

	local column = {instance = scrollingFrame}

	function column:groupBox(properties)
		properties = properties or {}

		local groupBox = library:create("Frame", {AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 10), Parent = scrollingFrame})
		library:create("UIStroke", {BorderStrokePosition = Enum.BorderStrokePosition.Inner, Color = library.theme.outline2, Parent = groupBox})
		library:create("UIStroke", {BorderStrokePosition = Enum.BorderStrokePosition.Inner, Color = library.theme.outline1, Thickness = 2, ZIndex = 0, Parent = groupBox})

		local groupBoxInfo = library:create("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundColor3 = library.theme.background,
			Position = UDim2.fromScale(0.5, 0),
			Size = UDim2.fromOffset(0, 12),
			Parent = groupBox,
		})

		library:create("UIPadding", {PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 9), Parent = groupBoxInfo})
		createText({Text = properties.title or "groupbox", Parent = groupBoxInfo})

		local elements = library:create("Frame", {
			AnchorPoint = Vector2.new(0.5, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			Position = UDim2.new(0.5, 0, 0, 6),
			Size = UDim2.new(1, -16, 0, 0),
			Parent = groupBox,
		})

		library:create("UIListLayout", {Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = elements})
		library:create("UIPadding", {PaddingBottom = UDim.new(0, 6), Parent = elements})

		local box = {instance = groupBox, elements = elements}

		local function labeledField(title)
			local holder = library:create("Frame", {BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 32), Parent = elements})
			createText({Text = title, Position = UDim2.fromOffset(0, 2), Parent = holder})
			return holder, createField({AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 13), Parent = holder})
		end

		function box:checkBox(toggleProperties)
			toggleProperties = toggleProperties or {}
			local title = toggleProperties.text or "checkbox"

			local checkBox = library:create("Frame", {BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 19), Parent = elements})
			local checkBoxName = createText({Text = title, TextColor3 = library.theme.inactiveTextColor, Position = UDim2.fromOffset(19, 2), Parent = checkBox})

			local checkBoxValue = library:create("Frame", {BackgroundColor3 = library.theme.gradient, Position = UDim2.fromOffset(0, 3), Size = UDim2.fromOffset(13, 13), Parent = checkBox})
			local checkBoxStroke = library:create("UIStroke", {BorderStrokePosition = Enum.BorderStrokePosition.Inner, Color = library.theme.outline2, Parent = checkBoxValue})
			local checkBoxStrokeGradient = library:create("UIGradient", {Enabled = false, Rotation = 90, Transparency = NumberSequence.new(0, 0.5), Parent = checkBoxStroke})
			library:create("UIGradient", {Rotation = 270, Transparency = NumberSequence.new(0, 0.5), Parent = checkBoxValue})

			local checkBoxButton = createHitbox(checkBox, 5)
			local toggle = {instance = checkBox, value = toggleProperties.default or false}

			addAddons(toggle, checkBox, storage, title, toggle)

			local function updateVisual()
				local on = toggle.value
				library:tween(checkBoxName, tweenInfo, {TextColor3 = on and library.theme.textColor or library.theme.inactiveTextColor})
				library:tween(checkBoxValue, tweenInfo, {BackgroundColor3 = on and library.theme.accent or library.theme.gradient})
				library:tween(checkBoxStroke, tweenInfo, {Color = on and library.theme.accent or library.theme.outline2})
				checkBoxStrokeGradient.Enabled = on
			end

			function toggle:set(newValue)
				self.value = newValue
				library:refreshKeybindList()
				updateVisual()
				if toggleProperties.callback then toggleProperties.callback(newValue) end
			end

			checkBoxButton.MouseButton1Click:Connect(function()
				toggle:set(not toggle.value)
			end)

			checkBoxButton.MouseEnter:Connect(function()
				library:tween(checkBoxName, tweenInfo, {TextColor3 = library.theme.textColor})
			end)

			checkBoxButton.MouseLeave:Connect(updateVisual)
			updateVisual()

			registerFlag(toggleProperties.flag, function()
				return toggle.value
			end, function(value)
				toggle:set(value)
			end)

			return toggle
		end

		function box:button(buttonProperties)
			local holder = library:create("Frame", {BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 19), Parent = elements})

			library:create("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalFlex = Enum.UIFlexAlignment.Fill,
				Padding = UDim.new(0, 6),
				SortOrder = Enum.SortOrder.LayoutOrder,
				VerticalFlex = Enum.UIFlexAlignment.Fill,
				Parent = holder,
			})

			local row = {instance = holder}

			function row:button(rowButtonProperties)
				rowButtonProperties = rowButtonProperties or {}
				local title, callback = rowButtonProperties.text or "button", rowButtonProperties.callback
				local confirm, confirmTime = rowButtonProperties.confirm or false, rowButtonProperties.confirmTime or 3

				local button = library:create("TextButton", {AutoButtonColor = false, BackgroundColor3 = library.theme.gradient, Size = UDim2.fromScale(1, 1), Text = "", ZIndex = 5, Parent = holder})
				library:create("UIStroke", {ApplyStrokeMode = Enum.ApplyStrokeMode.Border, BorderStrokePosition = Enum.BorderStrokePosition.Inner, Color = library.theme.outline2, Parent = button})
				library:create("UIGradient", {Rotation = 90, Transparency = NumberSequence.new(0, 1), Parent = button})

				local buttonName = createText({AnchorPoint = Vector2.new(0.5, 0.5), Text = title, TextColor3 = library.theme.inactiveTextColor, Position = UDim2.fromScale(0.5, 0.5), Parent = button})
				local armed, deadline = false, 0

				local function setColor(color)
					library:tween(buttonName, tweenInfo, {TextColor3 = color})
				end

				hoverText(button, buttonName, function() return armed end)

				button.MouseButton1Down:Connect(function()
					if not armed then setColor(library.theme.accent) end
				end)

				button.MouseButton1Up:Connect(function()
					if not armed then setColor(library.theme.textColor) end
				end)

				button.MouseButton1Click:Connect(function()
					if armed or not confirm then
						armed, buttonName.Text = false, title
						if callback then callback() end
						return
					end

					armed, deadline = true, os.clock() + confirmTime
					setColor(library.theme.accent)

					task.spawn(function()
						while armed and os.clock() < deadline do
							buttonName.Text = `confirm? ({string.format("%.1f", deadline - os.clock())}s)`
							task.wait(0.1)
						end

						if not armed then return end
						armed, buttonName.Text = false, title
						setColor(library.theme.inactiveTextColor)
					end)
				end)

				return row
			end

			return row:button(buttonProperties)
		end

		function box:label(labelProperties)
			labelProperties = labelProperties or {}
			local text = labelProperties.text or "hi i am a textlabel"

			local label = library:create("Frame", {AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 19), Parent = elements})
			local labelText = createText({Text = text, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(0, 2), Parent = label})
			local labelObject = {instance = label}

			addAddons(labelObject, label, storage, text)

			function labelObject:set(newText)
				labelText.Text = newText
			end

			return labelObject
		end

		function box:inputBox(inputProperties)
			inputProperties = inputProperties or {}

			local inputBox, inputDisplay = labeledField(inputProperties.text or "input")

			local inputValue = library:create("TextBox", {
				BackgroundTransparency = 1,
				FontFace = library.font,
				PlaceholderColor3 = library.theme.inactiveTextColor,
				PlaceholderText = inputProperties.placeholder or "Input here...",
				RichText = true,
				Size = UDim2.fromScale(1, 1),
				Text = inputProperties.default or "",
				TextColor3 = library.theme.inactiveTextColor,
				TextSize = 12,
				Parent = inputDisplay,
			})

			local input, focused = {instance = inputBox, value = inputValue.Text}, false

			local function setTextColor(color)
				library:tween(inputValue, tweenInfo, {TextColor3 = color, PlaceholderColor3 = color})
			end

			function input:set(newText)
				inputValue.Text, input.value = newText, newText
			end

			if inputProperties.numeric then
				inputValue:GetPropertyChangedSignal("Text"):Connect(function()
					local sanitized = sanitizeNumber(inputValue.Text)
					if sanitized ~= inputValue.Text then inputValue.Text = sanitized end
				end)
			end

			inputValue.MouseEnter:Connect(function()
				setTextColor(library.theme.textColor)
			end)

			inputValue.MouseLeave:Connect(function()
				if not focused then setTextColor(library.theme.inactiveTextColor) end
			end)

			inputValue.Focused:Connect(function()
				focused = true
				setTextColor(library.theme.textColor)
			end)

			inputValue.FocusLost:Connect(function()
				focused = false
				setTextColor(library.theme.inactiveTextColor)

				input.value = inputValue.Text
				if inputProperties.callback then inputProperties.callback(input.value) end
			end)

			registerFlag(inputProperties.flag, function()
				return input.value
			end, function(value)
				input:set(value)
			end)

			return input
		end

		function box:slider(sliderProperties)
			sliderProperties = sliderProperties or {}
			local min, max, decimals = sliderProperties.min or 0, sliderProperties.max or 100, sliderProperties.float or 0

			local slider, sliderDisplay = labeledField(sliderProperties.text or "slider")

			local sliderState = library:create("Frame", {BackgroundColor3 = library.theme.accent, Size = UDim2.fromScale(0, 1), Parent = sliderDisplay})
			local sliderStroke = library:create("UIStroke", {BorderStrokePosition = Enum.BorderStrokePosition.Inner, Color = library.theme.accent, Parent = sliderState})
			library:create("UIGradient", {Rotation = 90, Transparency = NumberSequence.new(0, 0.5), Parent = sliderStroke})
			library:create("UIGradient", {Rotation = 270, Transparency = NumberSequence.new(0, 0.5), Parent = sliderState})

			local sliderDrag = createHitbox(sliderDisplay)

			local sliderValue = createField({AnchorPoint = Vector2.new(1, 0), AutomaticSize = Enum.AutomaticSize.X, Position = UDim2.new(1, 0, 0, 3), Size = UDim2.fromOffset(13, 13), Parent = slider})
			library:create("UIPadding", {PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 3), Parent = sliderValue})

			local sliderInput = library:create("TextBox", {
				AutomaticSize = Enum.AutomaticSize.X,
				BackgroundTransparency = 1,
				ClearTextOnFocus = false,
				FontFace = library.font,
				RichText = true,
				Size = UDim2.fromScale(1, 1),
				TextColor3 = library.theme.textColor,
				TextSize = 12,
				Parent = sliderValue,
			})

			local sliderObject = {instance = slider, value = math.clamp(sliderProperties.default or min, min, max)}

			function sliderObject:set(newValue)
				local multiplier = 10 ^ decimals
				newValue = math.round(math.clamp(newValue, min, max) * multiplier) / multiplier
				sliderObject.value = newValue

				library:tween(sliderState, tweenInfo, {Size = UDim2.fromScale(max > min and (newValue - min) / (max - min) or 0, 1)})
				sliderInput.Text = string.format(`%.{decimals}f`, newValue)

				if sliderProperties.callback then sliderProperties.callback(newValue) end
			end

			onDrag(sliderDrag, function(position)
				sliderObject:set(min + relative(sliderDisplay, position) * (max - min))
			end)

			sliderInput:GetPropertyChangedSignal("Text"):Connect(function()
				local sanitized = sanitizeNumber(sliderInput.Text)
				if decimals == 0 then sanitized = sanitized:gsub("%.", "") end
				if sanitized ~= sliderInput.Text then sliderInput.Text = sanitized end
			end)

			sliderInput.FocusLost:Connect(function()
				sliderObject:set(tonumber(sliderInput.Text) or sliderObject.value)
			end)

			sliderObject:set(sliderObject.value)

			registerFlag(sliderProperties.flag, function()
				return sliderObject.value
			end, function(value)
				sliderObject:set(value)
			end)

			return sliderObject
		end

		function box:dropdown(dropdownProperties)
			dropdownProperties = dropdownProperties or {}
			local windowHeight = math.min(#(dropdownProperties.options or {}), 4) * 19 + 4

			local dropdown, dropdownDisplay = labeledField(dropdownProperties.text or "dropdown")

			local dropdownValue, dropdownValueShadow = createText({
				AutomaticSize = Enum.AutomaticSize.None,
				Position = UDim2.fromOffset(6, 0),
				Size = UDim2.new(1, -21, 1, 0),
				Text = "",
				TextTruncate = Enum.TextTruncate.AtEnd,
				TextXAlignment = Enum.TextXAlignment.Left,
				Parent = dropdownDisplay,
			})

			dropdownValueShadow.Size = UDim2.new(1, -22, 1, 0)

			local dropdownState = library:create("ImageLabel", {
				AnchorPoint = Vector2.new(1, 0),
				BackgroundTransparency = 1,
				Image = library.images.dropdownState,
				ImageColor3 = Color3.fromRGB(61, 61, 61),
				Position = UDim2.new(1, -2, 0, 0),
				Size = UDim2.fromOffset(13, 13),
				Parent = dropdownDisplay,
			})

			local dropdownButton = createHitbox(dropdownDisplay)

			local dropdownWindow = library:create("Frame", {
				BackgroundColor3 = library.theme.background,
				Size = UDim2.fromOffset(193, windowHeight),
				Visible = false,
				ZIndex = 20,
				Parent = storage,
			})

			library:create("UIStroke", {BorderStrokePosition = Enum.BorderStrokePosition.Inner, Color = library.theme.outline2, Parent = dropdownWindow})
			library:create("UIStroke", {BorderStrokePosition = Enum.BorderStrokePosition.Inner, Color = library.theme.outline1, Thickness = 2, ZIndex = 0, Parent = dropdownWindow})
			library:create("UIPadding", {PaddingBottom = UDim.new(0, 2), PaddingTop = UDim.new(0, 2), Parent = dropdownWindow})

			local dropdownElements = library:create("ScrollingFrame", {
				Active = true,
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				BottomImage = "rbxassetid://118384633897629",
				CanvasSize = UDim2.fromScale(0, 0),
				MidImage = "rbxassetid://118384633897629",
				ScrollBarImageColor3 = library.theme.accent,
				ScrollBarThickness = 1,
				ScrollingDirection = Enum.ScrollingDirection.Y,
				Size = UDim2.new(1, -2, 1, 0),
				TopImage = "rbxassetid://118384633897629",
				Parent = dropdownWindow,
			})

			library:create("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder, Parent = dropdownElements})

			local dropdownObject, closeDropdown, suppressReopen = {instance = dropdown}, nil, false

			addOptions(dropdownObject, dropdownElements, dropdownProperties, function(clicked)
				dropdownValue.Text = table.concat(dropdownObject.value, ", ")
				if clicked and dropdownProperties.multiSelect == false and closeDropdown then closeDropdown() end
			end)

			dropdownButton.MouseButton1Click:Connect(function()
				if suppressReopen then
					suppressReopen = false
					return
				end

				if closeDropdown then
					closeDropdown()
					return
				end

				local position = dropdown.AbsolutePosition
				dropdownWindow.Size = UDim2.fromOffset(dropdownDisplay.AbsoluteSize.X, windowHeight)
				library:tween(dropdownState, tweenInfo, {Rotation = 180})

				closeDropdown = openPopup(dropdownWindow, UDim2.fromOffset(position.X, position.Y + dropdown.AbsoluteSize.Y + 1), storage, function(input)
					closeDropdown = nil
					suppressReopen = input ~= nil and isInside(dropdownButton, input.Position)
					library:tween(dropdownState, tweenInfo, {Rotation = 0})
				end)
			end)

			return dropdownObject
		end

		function box:listBox(listProperties)
			listProperties = listProperties or {}

			local listBox = library:create("Frame", {AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 19), Parent = elements})
			createText({Text = listProperties.text or "listbox", TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(0, 2), Parent = listBox})

			local listBoxDisplay = createField({AutomaticSize = Enum.AutomaticSize.Y, Position = UDim2.fromOffset(0, 19), Size = UDim2.new(1, 0, 0, 6), Parent = listBox})
			library:create("UIStroke", {BorderStrokePosition = Enum.BorderStrokePosition.Inner, Color = library.theme.outline1, Thickness = 2, ZIndex = 0, Parent = listBoxDisplay})
			library:create("UIPadding", {PaddingBottom = UDim.new(0, 2), PaddingTop = UDim.new(0, 2), Parent = listBoxDisplay})

			local listBoxElements = library:create("ScrollingFrame", {
				Active = true,
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				BottomImage = "rbxassetid://118384633897629",
				CanvasSize = UDim2.fromScale(0, 0),
				MidImage = "rbxassetid://118384633897629",
				ScrollBarImageColor3 = library.theme.accent,
				ScrollBarThickness = 1,
				ScrollingDirection = Enum.ScrollingDirection.Y,
				Size = UDim2.new(1, -2, 0, math.min(#(listProperties.options or {}), 6) * 19),
				TopImage = "rbxassetid://118384633897629",
				Parent = listBoxDisplay,
			})

			library:create("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder, Parent = listBoxElements})

			local listObject = {instance = listBox}
			addOptions(listObject, listBoxElements, listProperties)
			return listObject
		end

		return box
	end

	return column
end

local function pageBodyFactory(parent)
	local page = library:create("Frame", {
		AnchorPoint = Vector2.new(1, 1),
		BackgroundTransparency = 1,
		Position = UDim2.new(1, -7, 1, -7),
		Size = UDim2.new(1, -139, 1, -36),
		Parent = parent,
	})

	library:create("UIStroke", {Color = library.theme.outline2, Parent = page})

	local pageTabs = library:create("Frame", {BackgroundColor3 = library.theme.gradient, Size = UDim2.new(1, 0, 0, 22), Parent = page})
	library:create("UIGradient", {Rotation = 90, Transparency = NumberSequence.new(0, 1), Parent = pageTabs})

	library:create("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalFlex = Enum.UIFlexAlignment.Fill,
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalFlex = Enum.UIFlexAlignment.Fill,
		Parent = pageTabs,
	})

	return page, pageTabs
end

local function tabBodyFactory(parent, properties, storage)
	local display = library:create("Frame", {BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 22), Size = UDim2.new(1, 0, 1, -22), Parent = parent})
	library:create("UIPadding", {PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6), Parent = display})

	library:create("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalFlex = Enum.UIFlexAlignment.Fill,
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalFlex = Enum.UIFlexAlignment.Fill,
		Parent = display,
	})

	local columns = {}
	for i = 1, properties.columns or 1 do
		columns[i] = createColumn(display, storage)
	end

	return display, columns
end

local function createSwitcher(barParent, bodyParent, buttonFactory, bodyFactory, storage)
	local entries = {}

	local function select(entry)
		for _, other in entries do
			other.body.Parent = other == entry and bodyParent or storage
			other.setSelected(other == entry)
		end
	end

	return function(properties)
		properties = properties or {}

		local button, setSelected = buttonFactory(barParent, properties)
		local body, extra = bodyFactory(bodyParent, properties, storage)
		local entry = {body = body, setSelected = setSelected}

		table.insert(entries, entry)

		button.MouseButton1Click:Connect(function()
			select(entry)
		end)

		if #entries == 1 then
			select(entry)
		else
			body.Parent = storage
			setSelected(false)
		end

		return body, extra
	end
end

function library:createWindow(properties)
	properties = properties or {}
	local size = properties.size or UDim2.fromOffset(500, 350)
	local nameText, gameName = properties.name or "prism", properties.game or ""
	local viewportSize = workspace.CurrentCamera.ViewportSize

	local root = library:create("Folder", {Parent = CoreGui})
	local storage = library:create("Folder", {Parent = root})
	getgenv().libraryRoot = root

	local libraryGui = library:create("ScreenGui", {
		DisplayOrder = 999999,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = root,
	})

	library.screenGui = libraryGui

	local window = library:create("Frame", {
		BackgroundColor3 = library.theme.background,
		Position = UDim2.fromOffset((viewportSize.X - size.X.Offset) / 2, (viewportSize.Y - size.Y.Offset) / 2),
		Size = size,
		Parent = libraryGui,
	})

	library:create("UIStroke", {Color = library.theme.outline2, Parent = window})
	library:create("UIStroke", {Color = library.theme.outline1, Thickness = 2, ZIndex = 0, Parent = window})

	local top = library:create("Frame", {BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 22), Parent = window})
	library:create("Frame", {AnchorPoint = Vector2.new(0, 1), BackgroundColor3 = library.theme.accent, Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 1), Parent = top})
	library:create("Frame", {AnchorPoint = Vector2.new(0, 1), BackgroundColor3 = library.theme.outline2, Position = UDim2.new(0, 0, 1, -2), Size = UDim2.new(1, 0, 0, 1), Parent = top})

	local title = createText({TextColor3 = library.theme.inactiveTextColor, Position = UDim2.fromOffset(6, 2), Parent = top})
	bindAccent(title, properties.title or nameText)

	local time = createText({AnchorPoint = Vector2.new(1, 0), Text = formatDate(), TextColor3 = library.theme.inactiveTextColor, Position = UDim2.new(1, -6, 0, 2), Parent = top})

	task.spawn(function()
		while time.Parent do
			time.Text = formatDate()
			task.wait(30)
		end
	end)

	local left = library:create("Frame", {BackgroundTransparency = 1, Position = UDim2.fromOffset(7, 29), Size = UDim2.new(0, 117, 1, -36), Parent = window})
	library:create("UIStroke", {Color = library.theme.outline2, Parent = left})

	local pageSelect = library:create("ScrollingFrame", {
		Active = true,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		CanvasSize = UDim2.fromScale(0, 0),
		ScrollBarThickness = 0,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Size = UDim2.fromScale(1, 1),
		Parent = left,
	})

	library:create("UIListLayout", {Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = pageSelect})

	library:create("UIPadding", {
		PaddingBottom = UDim.new(0, 6),
		PaddingLeft = UDim.new(0, 6),
		PaddingRight = UDim.new(0, 6),
		PaddingTop = UDim.new(0, 6),
		Parent = pageSelect,
	})

	local resizeHandle = createHitbox(window)
	resizeHandle.AnchorPoint, resizeHandle.Position, resizeHandle.Size = Vector2.new(1, 1), UDim2.fromScale(1, 1), UDim2.fromOffset(10, 10)

	local minSize, resizeStart, startSize = properties.minSize or Vector2.new(size.X.Offset, size.Y.Offset), nil, nil

	draggable(top, window)

	onDrag(resizeHandle, function(position, began)
		if began then resizeStart, startSize = position, window.Size return end

		local delta = position - resizeStart
		window.Size = UDim2.fromOffset(math.max(startSize.X.Offset + delta.X, minSize.X), math.max(startSize.Y.Offset + delta.Y, minSize.Y))
	end)

	local addons = library:create("Folder", {Name = "addons", Parent = libraryGui})
	library.addons = addons

	local watermark = library:create("Frame", {
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = library.theme.background,
		Position = UDim2.fromOffset(8, 8),
		Size = UDim2.fromOffset(0, 19),
		Parent = addons,
	})

	library:create("UIStroke", {Color = library.theme.outline2, Parent = watermark})
	library:create("UIStroke", {Color = library.theme.outline1, Thickness = 2, ZIndex = 0, Parent = watermark})
	library:create("UIPadding", {PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6), Parent = watermark})

	local watermarkLabel = createText({Position = UDim2.fromOffset(0, 2), Parent = watermark})
	local watermarkOrder = {"info", "game", "ping", "fps", "name", "playercount"}
	local watermarkSelected = {info = true, game = true, ping = true, fps = true}
	local currentFps, currentPing = 0, 0

	local watermarkValue = {
		info = function() return nameText end,
		game = function() return `// {gameName}` end,
		ping = function() return `// {currentPing} ms` end,
		fps = function() return `// {currentFps} fps` end,
		name = function() return `// {players.LocalPlayer.Name}` end,
		playercount = function() return `// {#players:GetPlayers()} of {players.MaxPlayers}` end,
	}

	local function refreshWatermark()
		local segments = {}

		for _, key in watermarkOrder do
			if not watermarkSelected[key] then continue end
			local color = key == "info" and "{accent}" or library.theme.inactiveTextColor:ToHex()
			table.insert(segments, `<font color="#{color}">{watermarkValue[key]()}</font>`)
		end

		bindAccent(watermarkLabel, table.concat(segments, " "))
	end

	refreshWatermark()
	draggable(watermark, watermark)

	local fpsSamples, lastFpsUpdate = 0, os.clock()

	track(services.RunService.Heartbeat:Connect(function()
		fpsSamples += 1
		if os.clock() - lastFpsUpdate < 0.5 then return end

		currentFps = math.round(fpsSamples / (os.clock() - lastFpsUpdate))
		fpsSamples, lastFpsUpdate = 0, os.clock()

		local ok, ping = pcall(players.LocalPlayer.GetNetworkPing, players.LocalPlayer)
		currentPing = ok and math.floor(ping * 1000) or 0

		refreshWatermark()
	end))

	local keybindList = library:create("Frame", {
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = library.theme.background,
		Position = UDim2.fromOffset(8, viewportSize.Y * 0.4),
		Size = UDim2.fromOffset(140, 22),
		Parent = addons,
	})

	library:create("UIStroke", {Color = library.theme.outline2, Parent = keybindList})
	library:create("UIStroke", {Color = library.theme.outline1, Thickness = 2, ZIndex = 0, Parent = keybindList})

	local keybindTop = library:create("Frame", {BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 22), Parent = keybindList})
	library:create("Frame", {AnchorPoint = Vector2.new(0, 1), BackgroundColor3 = library.theme.accent, Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 1), Parent = keybindTop})
	library:create("Frame", {AnchorPoint = Vector2.new(0, 1), BackgroundColor3 = library.theme.outline2, Position = UDim2.new(0, 0, 1, -2), Size = UDim2.new(1, 0, 0, 1), Parent = keybindTop})
	createText({Text = "keybinds", TextColor3 = library.theme.inactiveTextColor, Position = UDim2.fromOffset(6, 2), Parent = keybindTop})

	library.keybinds = library:create("Frame", {
		AutomaticSize = Enum.AutomaticSize.XY,
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 22),
		Size = UDim2.fromOffset(0, 0),
		Parent = keybindList,
	})

	library:create("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder, Parent = library.keybinds})

	library.keybinds:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		keybindList.Size = UDim2.fromOffset(math.max(140, library.keybinds.AbsoluteSize.X), 22)
	end)

	draggable(keybindList, keybindList)

	local windowObject = {instance = window, pageSelect = pageSelect}
	local addPage = createSwitcher(pageSelect, window, pageButtonFactory, pageBodyFactory, storage)

	function windowObject:createPage(pageProperties)
		local pageBody, pageTabs = addPage(pageProperties)
		local addTab = createSwitcher(pageTabs, pageBody, tabButtonFactory, tabBodyFactory, storage)
		local page = {instance = pageBody}

		function page:createTab(tabProperties)
			local display, columns = addTab(tabProperties)
			return {instance = display, columns = columns}
		end

		return page
	end

	function windowObject:settingsPage(settingsProperties)
		settingsProperties = settingsProperties or {}
		local title = settingsProperties.title or "settings"

		local tab = self:createPage({title = title}):createTab({title = title, columns = 2})
		local configBox = tab.columns[1]:groupBox({title = "configs"})
		local autoloadFile, themePickers = `{library.directory}/autoload.txt`, {}
		local configNameInput, savedConfigsList, autoloadLabel

		local function configPath(name)
			return `{configFolder}/{name}.json`
		end

		local function loadConfig(name)
			local path = configPath(name)
			if not isfile(path) then return end

			local ok, err = pcall(function()
				local data = HttpService:JSONDecode(readfile(path))

				for colorName, hex in data.theme or data do
					if not library.theme[colorName] then continue end
					local color = Color3.fromHex(hex)
					library:setTheme(colorName, color)
					if themePickers[colorName] then themePickers[colorName]:set(color) end
				end

				for flag, value in data.flags or {} do
					if library.flags[flag] then library.flags[flag].set(value) end
				end
			end)

			if ok then
				library:notif({text = `successfully loaded "{name}.json"`})
			else
				library:notif({text = `error loading "{name}.json"`})
				library:notif({text = err})
			end
		end

		local function refreshConfigsList()
			local names = {}

			for _, path in listfiles(configFolder) do
				local name = path:match("([^/\\]+)%.json$")
				if name then table.insert(names, name) end
			end

			table.sort(names)
			for i, name in names do names[i] = `{name}.json` end

			if savedConfigsList then savedConfigsList.instance:Destroy() end

			savedConfigsList = configBox:listBox({text = "saved configs", flag = "savedConfig", options = names, multiSelect = false, callback = function(value)
				if value[1] then configNameInput:set((value[1]:gsub("%.json$", ""))) end
			end})

			savedConfigsList.instance.LayoutOrder = 0
		end

		refreshConfigsList()

		configNameInput = configBox:inputBox({text = "config name", flag = "configName", placeholder = "config name...", default = ""})
		configNameInput.instance.LayoutOrder = 1

		local saveLoadRow = configBox:button({text = "save config", confirm = true, callback = function()
			local name = configNameInput.value
			if name == "" then return end

			local data = {theme = {}, flags = {}}
			for colorName, color in library.theme do data.theme[colorName] = color:ToHex() end
			for flag, entry in library.flags do data.flags[flag] = entry.get() end

			writefile(configPath(name), HttpService:JSONEncode(data))
			refreshConfigsList()
			library:notif({text = `successfully saved "{name}.json"`})
		end}):button({text = "load config", confirm = true, callback = function()
			loadConfig(configNameInput.value)
		end})

		local autoLoadRow = configBox:button({text = "set auto load", callback = function()
			local name = configNameInput.value
			if name == "" then return end

			writefile(autoloadFile, name)
			autoloadLabel:set(`auto load "{name}.json"`)
			library:notif({text = `set auto load "{name}.json"`})
		end})

		local deleteAutoLoadRow = configBox:button({text = "delete auto load", callback = function()
			local previous = isfile(autoloadFile) and readfile(autoloadFile)
			autoloadLabel:set("auto load none")
			if not previous then return end

			delfile(autoloadFile)
			library:notif({text = `deleted auto load "{previous}.json"`})
		end})

		local initialAutoload = isfile(autoloadFile) and readfile(autoloadFile) or nil
		autoloadLabel = configBox:label({text = initialAutoload and `auto load {initialAutoload}.json` or "auto load none"})

		saveLoadRow.instance.LayoutOrder, autoLoadRow.instance.LayoutOrder = 2, 3
		deleteAutoLoadRow.instance.LayoutOrder, autoloadLabel.instance.LayoutOrder = 4, 5

		local themeBox = tab.columns[2]:groupBox({title = "themes"})

		for _, name in {"accent", "outline1", "outline2", "background", "gradient", "textColor", "inactiveTextColor"} do
			themePickers[name] = themeBox:label({text = name}):colorPicker({default = library.theme[name], enableAlpha = false, callback = function(color)
				library:setTheme(name, color)
			end})
		end

		local serverBox = tab.columns[2]:groupBox({title = "server"})
		serverBox:label({text = `game: {game.GameId}\nplaceid: {game.PlaceId}`})

		serverBox:button({text = "rejoin", confirm = true, callback = function()
			library:notif({text = "rejoining"})
			services.TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, players.LocalPlayer)
		end}):button({text = "server hop", confirm = true, callback = function()
			library:notif({text = "finding a new server"})

			local ok, response = pcall(function()
				return HttpService:JSONDecode(game:HttpGet(`https://games.roblox.com/v1/games/{game.PlaceId}/servers/Public?sortOrder=Asc&limit=100`))
			end)

			if not ok or not response.data then
				library:notif({text = "server hop: failed to fetch servers"})
				return
			end

			local candidates = {}
			for _, server in response.data do
				if server.id ~= game.JobId and server.playing < server.maxPlayers then table.insert(candidates, server.id) end
			end

			if #candidates == 0 then
				library:notif({text = "server hop: no other servers found"})
				return
			end

			services.TeleportService:TeleportToPlaceInstance(game.PlaceId, candidates[math.random(1, #candidates)], players.LocalPlayer)
		end})

		serverBox:button({text = "copy jobid", callback = function()
			setclipboard(game.JobId)
			library:notif({text = `copied "jobid" to clipboard`})
		end}):button({text = "copy join script", callback = function()
			setclipboard(`game:GetService("TeleportService"):TeleportToPlaceInstance({game.PlaceId}, "{game.JobId}", game:GetService("Players").LocalPlayer)`)
			library:notif({text = `copied "join script" to clipboard`})
		end})

		local hudBox = tab.columns[1]:groupBox({title = "hud"})

		local menuKeybind = hudBox:label({text = "menu keybind"}):keybind({flag = "menuKeybind", default = Enum.KeyCode.RightShift, active = true, showInList = false, onPress = function() window.Visible = true end, onRelease = function() window.Visible = false end})

		local keybindListOn = hudBox:checkBox({text = "keybind list", flag = "keybindList", default = true})
		local keybindListMode = hudBox:dropdown({text = "keybind list mode", flag = "keybindListMode", options = {"enabled", "all", "toggled"}, default = {"all"}, multiSelect = false})

		local watermarkOn = hudBox:checkBox({text = "watermark", flag = "watermark", default = true})
		local watermarkElements = hudBox:dropdown({text = "watermark elements", flag = "watermarkElements", options = {"fps", "name", "game", "info", "playercount", "ping"}, default = {"fps", "game", "info", "ping"}})

		local lastElements
		track(services.RunService.Heartbeat:Connect(function()
			keybindList.Visible, watermark.Visible = keybindListOn.value, watermarkOn.value

			local mode = keybindListMode.value[1] or "all"
			if mode ~= library.keybindListMode then
				library.keybindListMode = mode
				library:refreshKeybindList()
			end

			local elements = watermarkElements.value
			if elements == lastElements then return end -- the dropdown builds a new value table on every change, so identity works as a change check

			lastElements, watermarkSelected = elements, {}
			for _, element in elements do watermarkSelected[element] = true end
			refreshWatermark()
		end))

		if initialAutoload then
			task.spawn(function()
				repeat task.wait() until game:IsLoaded()
				task.wait(5)

				local currentAutoload = isfile(autoloadFile) and readfile(autoloadFile) or nil
				if currentAutoload then loadConfig(currentAutoload) end
			end)
		end

		return {instance = tab.instance}
	end

	function windowObject:visualsPage(visualsProperties)
		local RunService, localPlayer, camera = services.RunService, players.LocalPlayer, workspace.CurrentCamera
		local page = self:createPage({title = "visuals"})
		local espTab, worldTab = page:createTab({title = "esp", columns = 2}), page:createTab({title = "world", columns = 2})
		local renderTab = (visualsProperties or {}).render ~= false and page:createTab({title = "render", columns = 2}) or nil
		local main = espTab.columns[1]:groupBox({title = "players"})

		local enabled = main:checkBox({text = "enabled", flag = "espEnabled"})

		local names = main:checkBox({text = "nametags", flag = "espNames"})
		local nameColor = names:colorPicker({flag = "espNameColor", enableAlpha = false})
		local nameMode = main:dropdown({text = "name", flag = "espNameMode", options = {"username", "display name"}, default = {"username", "display name"}, required = true})

		local boxes = main:checkBox({text = "boxes", flag = "espBoxes"})
		local boxColor = boxes:colorPicker({flag = "espBoxColor", enableAlpha = false})
		local boxMode = main:dropdown({text = "box mode", flag = "espBoxMode", options = {"normal", "corner"}, default = {"normal"}, multiSelect = false, required = true})

		local health = main:checkBox({text = "health bar", flag = "espHealth"})
		local healthLow = health:colorPicker({flag = "espHealthLow", default = Color3.fromRGB(255, 0, 0), enableAlpha = false})
		local healthHigh = health:colorPicker({flag = "espHealthHigh", default = Color3.fromRGB(0, 255, 0), enableAlpha = false})

		local distance = main:checkBox({text = "distance", flag = "espDistance"})
		local distanceColor = distance:colorPicker({flag = "espDistanceColor", enableAlpha = false})

		local weapon = main:checkBox({text = "weapon", flag = "espWeapon"})
		local weaponColor = weapon:colorPicker({flag = "espWeaponColor", enableAlpha = false})

		local skeletons = main:checkBox({text = "skeletons", flag = "espSkeletons"})
		local skeletonColor = skeletons:colorPicker({flag = "espSkeletonColor", enableAlpha = false})

		local highlightBox = espTab.columns[1]:groupBox({title = "highlight"})
		local highlightEnabled = highlightBox:checkBox({text = "enabled", flag = "highlightEnabled"})
		local highlightFill = highlightEnabled:colorPicker({flag = "highlightFill", default = Color3.fromRGB(255, 60, 100), alpha = 0.5})
		local highlightOutline = highlightEnabled:colorPicker({flag = "highlightOutline"})
		local highlightWalls = highlightBox:checkBox({text = "through walls", flag = "highlightWalls", default = true})

		local optionsBox = espTab.columns[2]:groupBox({title = "options"})
		local selfEsp = optionsBox:checkBox({text = "self", flag = "espSelf"})
		local teamCheck = optionsBox:checkBox({text = "team check", flag = "espTeamCheck"})
		local teamColors = optionsBox:checkBox({text = "team colors", flag = "espTeamColors"})

		local outlines = optionsBox:checkBox({text = "outline", flag = "espOutline", default = true})
		local outlineColor = outlines:colorPicker({flag = "espOutlineColor", default = Color3.new(), enableAlpha = false})

		local visibleCheck = optionsBox:checkBox({text = "visible check", flag = "espVisibleCheck"})
		local visibleColor = visibleCheck:colorPicker({flag = "espVisibleColor", default = Color3.fromRGB(0, 255, 0), enableAlpha = false})
		local hiddenColor = visibleCheck:colorPicker({flag = "espHiddenColor", default = Color3.fromRGB(255, 0, 0), enableAlpha = false})
		local visibleOptions = optionsBox:dropdown({text = "visible options", flag = "espVisibleOptions", options = {"only visible", "override colors"}, default = {"only visible"}})

		local maxDistance = optionsBox:slider({text = "max distance", flag = "espMaxDistance", min = 0, max = 10000, default = 10000})

		local characterBox = espTab.columns[2]:groupBox({title = "character"})
		local material = characterBox:checkBox({text = "material", flag = "charMaterial"})
		local materialColor = material:colorPicker({flag = "charMaterialColor", default = Color3.fromRGB(95, 180, 255)})
		local materialOptions = {"forcefield", "neon", "glass", "ice", "metal", "foil"}
		local materialType = characterBox:dropdown({text = "material type", flag = "charMaterialType", options = materialOptions, default = {"forcefield"}, multiSelect = false, required = true})

		local lighting = services.Lighting
		local skyProperties = {"SkyboxBk", "SkyboxDn", "SkyboxFt", "SkyboxLf", "SkyboxRt", "SkyboxUp", "CelestialBodiesShown", "MoonTextureId", "MoonAngularSize", "SunAngularSize"}

		local function skybox(faces, properties)
			local preset = properties or {}

			for i = 1, 6 do
				local face = faces[i]
				preset[skyProperties[i]] = type(face) == "number" and `rbxassetid://{face}` or face
			end

			return preset
		end

		local skyboxes = {
			classic = skybox({
				"rbxasset://sky/null_plainsky512_bk.jpg",
				"rbxasset://sky/null_plainsky512_dn.jpg",
				"rbxasset://sky/null_plainsky512_ft.jpg",
				"rbxasset://sky/null_plainsky512_lf.jpg",
				"rbxasset://sky/null_plainsky512_rt.jpg",
				"rbxasset://sky/null_plainsky512_up.jpg",
			}),
			black = skybox({156311666, 156311666, 156311666, 156311666, 156311666, 156311666}, {CelestialBodiesShown = false}),
			spongebob = skybox({15962101128, 15970246218, 15962101128, 15962101128, 15962101128, 15962901054}, {CelestialBodiesShown = false, MoonTextureId = "rbxassetid://15912530252"}),
			["clear blue"] = skybox({18586524369, 18586494459, 18586524369, 18586524369, 18586524369, 18586494073}),
			["cloudy grey"] = skybox({15063412549, 15063341496, 15063442046, 15063367382, 15063435355, 15063353447}, {MoonAngularSize = 6, SunAngularSize = 9}),
			space = skybox({15593304635, 15593307656, 15593319759, 15593316960, 15593329329, 15593324381}, {CelestialBodiesShown = false, SunAngularSize = 5}),
			sunset = skybox({600830446, 600831635, 600832720, 600886090, 600833862, 600835177}),
			snow = skybox({155657655, 155674246, 155657609, 155657671, 155657619, 155674931}, {CelestialBodiesShown = false}),
		}

		local lightingBox = worldTab.columns[1]:groupBox({title = "lighting"})

		local timeOn = lightingBox:checkBox({text = "time", flag = "worldTime"})
		local clockTime = lightingBox:slider({text = "clock time", flag = "worldClockTime", min = 0, max = 24, default = lighting.ClockTime, float = 1})

		local ambientOn = lightingBox:checkBox({text = "ambient", flag = "worldAmbient"})
		local ambientColor = ambientOn:colorPicker({flag = "worldAmbientColor", default = lighting.Ambient, enableAlpha = false})
		local outdoorColor = ambientOn:colorPicker({flag = "worldOutdoorColor", default = lighting.OutdoorAmbient, enableAlpha = false})

		local brightnessOn = lightingBox:checkBox({text = "brightness", flag = "worldBrightness"})
		local brightness = lightingBox:slider({text = "brightness level", flag = "worldBrightnessLevel", min = 0, max = 10, default = lighting.Brightness, float = 1})

		local exposureOn = lightingBox:checkBox({text = "exposure", flag = "worldExposure"})
		local exposure = lightingBox:slider({text = "exposure level", flag = "worldExposureLevel", min = -3, max = 3, default = lighting.ExposureCompensation, float = 1})

		local shiftOn = lightingBox:checkBox({text = "color shift", flag = "worldShift"})
		local shiftTop = shiftOn:colorPicker({flag = "worldShiftTop", default = lighting.ColorShift_Top, enableAlpha = false})
		local shiftBottom = shiftOn:colorPicker({flag = "worldShiftBottom", default = lighting.ColorShift_Bottom, enableAlpha = false})

		local globalShadows = lightingBox:checkBox({text = "global shadows", flag = "worldGlobalShadows", default = true})

		local skyboxOptions = {"default", "classic", "black", "spongebob", "clear blue", "cloudy grey", "space", "sunset", "snow"}
		local skyboxBox = worldTab.columns[1]:groupBox({title = "skybox"})
		local skyboxSelect = skyboxBox:dropdown({text = "skybox", flag = "worldSkybox", options = skyboxOptions, default = {"default"}, multiSelect = false, required = true})

		local fogBox = worldTab.columns[2]:groupBox({title = "fog"})
		local fogOn = fogBox:checkBox({text = "enabled", flag = "worldFog"})
		local fogColor = fogOn:colorPicker({flag = "worldFogColor", default = lighting.FogColor, enableAlpha = false})
		local fogStart = fogBox:slider({text = "start", flag = "worldFogStart", min = 0, max = 2000, default = 0})
		local fogEnd = fogBox:slider({text = "end", flag = "worldFogEnd", min = 0, max = 5000, default = 500})

		local atmosphereBox = worldTab.columns[2]:groupBox({title = "atmosphere"})
		local atmosphereOn = atmosphereBox:checkBox({text = "enabled", flag = "worldAtmosphere"})
		local atmosphereColor = atmosphereOn:colorPicker({flag = "worldAtmosphereColor", default = Color3.fromRGB(199, 170, 107), enableAlpha = false})
		local atmosphereDecay = atmosphereOn:colorPicker({flag = "worldAtmosphereDecay", default = Color3.fromRGB(92, 60, 13), enableAlpha = false})
		local atmosphereDensity = atmosphereBox:slider({text = "density", flag = "worldAtmosphereDensity", min = 0, max = 1, default = 0.3, float = 2})
		local atmosphereHaze = atmosphereBox:slider({text = "haze", flag = "worldAtmosphereHaze", min = 0, max = 10, default = 1, float = 1})
		local atmosphereGlare = atmosphereBox:slider({text = "glare", flag = "worldAtmosphereGlare", min = 0, max = 10, default = 0, float = 1})

		local correctionBox = worldTab.columns[2]:groupBox({title = "color correction"})
		local correctionOn = correctionBox:checkBox({text = "enabled", flag = "worldCorrection"})
		local correctionTint = correctionOn:colorPicker({flag = "worldCorrectionTint", enableAlpha = false})
		local correctionBrightness = correctionBox:slider({text = "brightness", flag = "worldCorrectionBrightness", min = -1, max = 1, default = 0, float = 2})
		local correctionContrast = correctionBox:slider({text = "contrast", flag = "worldCorrectionContrast", min = -1, max = 1, default = 0, float = 2})
		local correctionSaturation = correctionBox:slider({text = "saturation", flag = "worldCorrectionSaturation", min = -1, max = 1, default = 0, float = 2})

		local bones15 = {
			{"Head", "UpperTorso"}, {"UpperTorso", "LowerTorso"},
			{"UpperTorso", "LeftUpperArm"}, {"LeftUpperArm", "LeftLowerArm"},
			{"UpperTorso", "RightUpperArm"}, {"RightUpperArm", "RightLowerArm"},
			{"LowerTorso", "LeftUpperLeg"}, {"LeftUpperLeg", "LeftLowerLeg"},
			{"LowerTorso", "RightUpperLeg"}, {"RightUpperLeg", "RightLowerLeg"},
		}

		local bones6 = {{"Head", "Torso"}, {"Torso", "Left Arm"}, {"Torso", "Right Arm"}, {"Torso", "Left Leg"}, {"Torso", "Right Leg"}}

		local objects, wasEnabled = {}, false
		local espGui = library:create("ScreenGui", {IgnoreGuiInset = true, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = root})

		local rayParams = RaycastParams.new()
		rayParams.FilterType, rayParams.RespectCanCollide, rayParams.FilterDescendantsInstances = Enum.RaycastFilterType.Exclude, true, {localPlayer.Character}
		track(localPlayer.CharacterAdded:Connect(function(character) rayParams.FilterDescendantsInstances = {character} end))

		local alwaysOnTop, occluded = Enum.HighlightDepthMode.AlwaysOnTop, Enum.HighlightDepthMode.Occluded

		local function createObject(full)
			local object = {outline = {}, box = {}, bones = {}, boneOutlines = {}, hidden = true}
			local holder = library:create("Frame", {BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false, Parent = espGui})
			object.holder = holder

			if full then
				local center = Vector2.new(0.5, 0.5)

				for i = 1, 8 do
					object.outline[i] = library:create("Frame", {ZIndex = 1, Parent = holder})
					object.box[i] = library:create("Frame", {ZIndex = 2, Parent = holder})
				end

				for i = 1, #bones15 do
					object.boneOutlines[i] = library:create("Frame", {AnchorPoint = center, ZIndex = 1, Parent = holder})
					object.bones[i] = library:create("Frame", {AnchorPoint = center, ZIndex = 2, Parent = holder})
				end

				object.barBack, object.bar = library:create("Frame", {ZIndex = 1, Parent = holder}), library:create("Frame", {ZIndex = 2, Parent = holder})
			end

			for _, key in full and {"name", "distance", "weapon"} or {"name", "distance"} do
				object[key] = library:create("TextLabel", {
					AnchorPoint = Vector2.new(0.5, key == "name" and 1 or 0),
					AutomaticSize = Enum.AutomaticSize.XY,
					BackgroundTransparency = 1,
					FontFace = library.font,
					TextSize = 12,
					TextStrokeTransparency = 0,
					ZIndex = 3,
					Parent = holder,
				})
			end

			return object
		end

		local function hide(object)
			if object.hidden then return end
			object.hidden, object.holder.Visible = true, false
		end

		local function setLine(frame, from, to, thickness)
			local delta = to - from
			frame.Position, frame.Size = UDim2.fromOffset((from.X + to.X) / 2, (from.Y + to.Y) / 2), UDim2.fromOffset(delta.Magnitude, thickness)
			frame.Rotation = math.deg(math.atan2(delta.Y, delta.X))
		end

		local evaluations, frameStamp = {}, 0
		track(RunService.RenderStepped:Connect(function() frameStamp += 1 end))

		local function resolve(player, character, rootPart)
			if teamCheck.value and player ~= localPlayer and localPlayer.Team and player.Team == localPlayer.Team then return false end
			if (rootPart.Position - camera.CFrame.Position).Magnitude > maxDistance.value then return false end

			local override
			if visibleCheck.value then
				local origin, visibleModes = camera.CFrame.Position, visibleOptions.value
				local target = character:FindFirstChild("Head") or rootPart
				local hit = workspace:Raycast(origin, target.Position - origin, rayParams)
				local seen = not hit or hit.Instance:IsDescendantOf(character)

				if not seen and table.find(visibleModes, "only visible") then return false end
				if table.find(visibleModes, "override colors") then override = seen and visibleColor.color or hiddenColor.color end
			end

			if not override and teamColors.value and player.Team then override = player.Team.TeamColor.Color end
			return true, override
		end

		local function evaluate(player, character, rootPart)
			local cached = evaluations[player]

			if not cached then
				cached = {stamp = -1}
				evaluations[player] = cached
			end

			if cached.stamp ~= frameStamp then
				cached.stamp = frameStamp
				cached.show, cached.override = resolve(player, character, rootPart)
			end

			return cached.show, cached.override
		end

		local function render(player, object)
			local character = player.Character
			local humanoid, root = character and character:FindFirstChildOfClass("Humanoid"), character and character:FindFirstChild("HumanoidRootPart")
			if not humanoid or not root or humanoid.Health <= 0 then hide(object) return end

			local rootPosition = root.Position
			local up, cameraUp = root.CFrame.UpVector, camera.CFrame.UpVector
			local top, onScreen = camera:WorldToViewportPoint(rootPosition + up * 1.8 + cameraUp)
			local bottom = camera:WorldToViewportPoint(rootPosition - up * 2.5 - cameraUp)
			if not onScreen or bottom.Z < 0 then hide(object) return end

			local show, override = evaluate(player, character, root)
			if not show then hide(object) return end

			object.hidden, object.holder.Visible = false, true

			local baseWidth = math.max(math.floor(math.abs(top.X - bottom.X)), 3)
			local height = math.max(math.floor(math.max(math.abs(bottom.Y - top.Y), baseWidth / 2)), 3)
			local width = math.floor(math.max(height / 1.5, baseWidth))
			local x, y = math.floor((top.X + bottom.X) / 2 - width / 2), math.floor(math.min(top.Y, bottom.Y))
			local centerX = x + width / 2

			local showBoxes, corner, color = boxes.value, boxMode.value[1] == "corner", override or boxColor.color
			local lineWidth, lineHeight = corner and math.floor(width * 0.4) or width - 1, corner and math.floor(height * 0.25) or height - 1
			local outlineOn, outlineTint = outlines.value, outlineColor.color
			local strokeTransparency = outlineOn and 0 or 1

			for i = 1, 8 do
				local index, outline, line = (i - 1) // 2, object.outline[i], object.box[i]
				local cx, cy = x + index % 2 * (width - 1), y + index // 2 * (height - 1)
				local sx, sy = 1 - index % 2 * 2, 1 - index // 2 * 2
				local dx, dy = i % 2 == 0 and 0 or sx * lineWidth, i % 2 == 0 and sy * lineHeight or 0
				local rx, ry, rw, rh = math.min(cx, cx + dx), math.min(cy, cy + dy), math.abs(dx) + 1, math.abs(dy) + 1

				outline.Position, outline.Size = UDim2.fromOffset(rx - 1, ry - 1), UDim2.fromOffset(rw + 2, rh + 2)
				outline.BackgroundColor3, outline.Visible = outlineTint, showBoxes and outlineOn
				line.Position, line.Size = UDim2.fromOffset(rx, ry), UDim2.fromOffset(rw, rh)
				line.BackgroundColor3, line.Visible = color, showBoxes
			end

			local showHealth, bar, barBack = health.value, object.bar, object.barBack
			barBack.Visible, bar.Visible = showHealth and outlineOn, showHealth

			if showHealth then
				local ratio = math.clamp(humanoid.Health / math.max(humanoid.MaxHealth, 1), 0, 1)
				local barHeight = math.round(height * ratio)

				barBack.Position, barBack.Size = UDim2.fromOffset(x - 6, y - 1), UDim2.fromOffset(4, height + 2)
				barBack.BackgroundColor3 = outlineTint

				bar.Position, bar.Size = UDim2.fromOffset(x - 5, y + height - barHeight), UDim2.fromOffset(2, barHeight)
				bar.BackgroundColor3 = healthLow.color:Lerp(healthHigh.color, ratio)
			end

			local nameText, showNames = object.name, names.value
			nameText.Visible = showNames

			if showNames then
				local modes = nameMode.value
				local username, display = table.find(modes, "username"), table.find(modes, "display name")

				nameText.Text = display and (username and `{player.DisplayName} (@{player.Name})` or player.DisplayName) or player.Name
				nameText.Position, nameText.TextColor3 = UDim2.fromOffset(centerX, y - 4), override or nameColor.color
				nameText.TextStrokeTransparency, nameText.TextStrokeColor3 = strokeTransparency, outlineTint
			end

			local textY, distanceText, showDistance = y + height + 2, object.distance, distance.value
			distanceText.Visible = showDistance

			if showDistance then
				distanceText.Text = `{math.floor((rootPosition - camera.CFrame.Position).Magnitude)}m`
				distanceText.Position, distanceText.TextColor3 = UDim2.fromOffset(centerX, textY), override or distanceColor.color
				distanceText.TextStrokeTransparency, distanceText.TextStrokeColor3 = strokeTransparency, outlineTint
				textY += 13
			end

			local weaponText, tool = object.weapon, weapon.value and character:FindFirstChildOfClass("Tool")
			weaponText.Visible = tool and true or false

			if tool then
				weaponText.Text = tool.Name
				weaponText.Position, weaponText.TextColor3 = UDim2.fromOffset(centerX, textY), override or weaponColor.color
				weaponText.TextStrokeTransparency, weaponText.TextStrokeColor3 = strokeTransparency, outlineTint
			end

			local showSkeletons, skeletonLineColor = skeletons.value, override or skeletonColor.color
			local bones = character:FindFirstChild("UpperTorso") and bones15 or bones6

			for i, line in object.bones do
				local back, bone = object.boneOutlines[i], showSkeletons and bones[i]
				local from, to = bone and character:FindFirstChild(bone[1]), bone and character:FindFirstChild(bone[2])
				if not (from and to) then line.Visible, back.Visible = false, false continue end

				local a, b = camera:WorldToViewportPoint(from.Position), camera:WorldToViewportPoint(to.Position)
				local seen = a.Z > 0 and b.Z > 0

				line.Visible, back.Visible = seen, seen and outlineOn
				if not seen then continue end

				local start, finish = Vector2.new(a.X, a.Y), Vector2.new(b.X, b.Y)
				setLine(back, start, finish, 1)
				setLine(line, start, finish, 1)
				back.BackgroundColor3, line.BackgroundColor3 = outlineTint, skeletonLineColor
			end
		end

		track(RunService.RenderStepped:Connect(function()
			if not enabled.value then
				if not wasEnabled then return end
				wasEnabled = false

				for _, object in objects do hide(object) end
				return
			end

			wasEnabled = true

			for _, player in players:GetPlayers() do
				local object = objects[player]

				if player == localPlayer and not selfEsp.value then
					if object then hide(object) end
					continue
				end

				object = object or createObject(true)
				objects[player] = object
				render(player, object)
			end
		end))

		track(players.PlayerRemoving:Connect(function(player)
			evaluations[player] = nil

			local object = objects[player]
			if not object then return end

			object.holder:Destroy()
			objects[player] = nil
		end))

		local espObjects, objectFlags = {}, {}

		function library:espObject(target, properties)
			assert(target:IsA("Model") or target:IsA("BasePart"), "espObject expects a Model or BasePart")

			local settings = {
				name = target.Name,
				enabled = true,
				nametags = true,
				nameColor = Color3.new(1, 1, 1),
				highlight = false,
				highlightFill = Color3.fromRGB(255, 60, 100),
				highlightFillAlpha = 0.5,
				highlightOutline = Color3.new(1, 1, 1),
				highlightOutlineAlpha = 1,
				highlightWalls = true,
				distance = true,
				distanceColor = Color3.new(1, 1, 1),
			}

			for key, value in properties or {} do settings[key] = value end

			local highlight = library:create("Highlight", {Adornee = target, Enabled = false, Parent = root})
			local entry = {target = target, settings = settings, visual = createObject(false), highlight = highlight}
			table.insert(espObjects, entry)

			if renderTab and settings.ui ~= false then
				local prefix = `object{settings.name}`
				objectFlags[prefix] = (objectFlags[prefix] or 0) + 1
				if objectFlags[prefix] > 1 then prefix ..= objectFlags[prefix] end

				local groupBox = renderTab.columns[(#espObjects - 1) % 2 + 1]:groupBox({title = settings.name})
				entry.groupBox = groupBox

				local function toggle(text, key)
					return groupBox:checkBox({text = text, flag = `{prefix}_{key}`, default = settings[key], callback = function(value) settings[key] = value end})
				end

				local function picker(checkBox, key, alphaKey)
					return checkBox:colorPicker({
						flag = `{prefix}_{key}`,
						default = settings[key],
						alpha = alphaKey and settings[alphaKey],
						enableAlpha = alphaKey ~= nil,
						callback = function(color, alpha)
							settings[key] = color
							if alphaKey then settings[alphaKey] = alpha end
						end,
					})
				end

				toggle("enabled", "enabled")
				picker(toggle("nametags", "nametags"), "nameColor")

				local highlightToggle = toggle("highlight", "highlight")
				picker(highlightToggle, "highlightFill", "highlightFillAlpha")
				picker(highlightToggle, "highlightOutline", "highlightOutlineAlpha")
				toggle("through walls", "highlightWalls")

				picker(toggle("distance", "distance"), "distanceColor")
			end

			function entry:remove()
				local index = table.find(espObjects, self)
				if not index then return end

				table.remove(espObjects, index)
				self.destroying:Disconnect()
				self.visual.holder:Destroy()
				self.highlight:Destroy()
				if self.groupBox then self.groupBox.instance:Destroy() end
			end

			entry.destroying = target.Destroying:Connect(function() entry:remove() end)
			return entry
		end

		local function renderObject(entry)
			local target, settings, visual, highlight = entry.target, entry.settings, entry.visual, entry.highlight
			local alive = settings.enabled and target:IsDescendantOf(workspace)
			local cframe, size, objectDistance

			if alive then
				if target:IsA("Model") then cframe, size = target:GetBoundingBox() else cframe, size = target.CFrame, target.Size end
				objectDistance = (cframe.Position - camera.CFrame.Position).Magnitude
				alive = objectDistance <= maxDistance.value
			end

			local highlightOn = alive and settings.highlight
			highlight.Enabled = highlightOn

			if highlightOn then
				highlight.FillColor, highlight.FillTransparency = settings.highlightFill, 1 - settings.highlightFillAlpha
				highlight.OutlineColor, highlight.OutlineTransparency = settings.highlightOutline, 1 - settings.highlightOutlineAlpha
				highlight.DepthMode = settings.highlightWalls and alwaysOnTop or occluded
			end

			if not alive then hide(visual) return end

			local half = size / 2
			local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge

			for i = 0, 7 do
				local corner = cframe * Vector3.new(i % 2 == 0 and -half.X or half.X, i // 2 % 2 == 0 and -half.Y or half.Y, i < 4 and -half.Z or half.Z)
				local point = camera:WorldToViewportPoint(corner)
				if point.Z <= 0 then hide(visual) return end

				minX, maxX = math.min(minX, point.X), math.max(maxX, point.X)
				minY, maxY = math.min(minY, point.Y), math.max(maxY, point.Y)
			end

			local viewport = camera.ViewportSize
			if maxX < 0 or maxY < 0 or minX > viewport.X or minY > viewport.Y then hide(visual) return end

			visual.hidden, visual.holder.Visible = false, true

			local width, height = math.max(math.floor(maxX - minX), 3), math.max(math.floor(maxY - minY), 3)
			local x, y = math.floor(minX), math.floor(minY)
			local centerX = x + width / 2

			local nameText, distanceText = visual.name, visual.distance
			local strokeTransparency, strokeColor = outlines.value and 0 or 1, outlineColor.color
			nameText.Visible, distanceText.Visible = settings.nametags, settings.distance

			if settings.nametags then
				nameText.Text, nameText.Position, nameText.TextColor3 = settings.name, UDim2.fromOffset(centerX, y - 4), settings.nameColor
				nameText.TextStrokeTransparency, nameText.TextStrokeColor3 = strokeTransparency, strokeColor
			end

			if settings.distance then
				distanceText.Text = `{math.floor(objectDistance)}m`
				distanceText.Position, distanceText.TextColor3 = UDim2.fromOffset(centerX, y + height + 2), settings.distanceColor
				distanceText.TextStrokeTransparency, distanceText.TextStrokeColor3 = strokeTransparency, strokeColor
			end
		end

		track(RunService.RenderStepped:Connect(function()
			for _, entry in espObjects do renderObject(entry) end
		end))

		local materials = {
			forcefield = Enum.Material.ForceField,
			neon = Enum.Material.Neon,
			glass = Enum.Material.Glass,
			ice = Enum.Material.Ice,
			metal = Enum.Material.Metal,
			foil = Enum.Material.Foil,
		}

		local originals, materialItems = {}, {}
		local materialCharacter, materialAdded, materialDirty

		local function restoreOriginals()
			for item, original in originals do
				if original[1] then item.Material, item.Color = original[1], original[2] end
				item.Transparency = original[3]
			end

			table.clear(originals)
		end

		track(RunService.RenderStepped:Connect(function()
			local character = localPlayer.Character
			if not character then return end

			if material.value then
				local materialEnum, color, transparency = materials[materialType.value[1]], materialColor.color, 1 - materialColor.alpha

				if character ~= materialCharacter then
					if materialAdded then materialAdded:Disconnect() end
					table.clear(originals)
					materialCharacter, materialDirty = character, true
					materialAdded = character.DescendantAdded:Connect(function() materialDirty = true end)
				end

				if materialDirty then
					local rootPart = character:FindFirstChild("HumanoidRootPart")
					table.clear(materialItems)

					for _, item in character:GetDescendants() do
						if item ~= rootPart and (item:IsA("BasePart") or item:IsA("Decal")) then table.insert(materialItems, item) end
					end

					materialDirty = false
				end

				for _, item in materialItems do
					local isPart = item:IsA("BasePart")
					local original = originals[item]

					if not original then
						original = {isPart and item.Material, isPart and item.Color, item.Transparency}
						originals[item] = original
					end

					if isPart then item.Material, item.Color = materialEnum, color end
					item.Transparency = math.max(original[3], transparency)
				end
			elseif next(originals) then
				restoreOriginals()
			end
		end))

		local playerHighlights, highlightsActive = {}, false

		track(RunService.RenderStepped:Connect(function()
			local highlightOn = highlightEnabled.value
			if not highlightOn and not highlightsActive then return end

			highlightsActive = highlightOn

			for _, player in players:GetPlayers() do
				local highlight, character = playerHighlights[player], player.Character
				local humanoid, rootPart = character and character:FindFirstChildOfClass("Humanoid"), character and character:FindFirstChild("HumanoidRootPart")
				local show, override = false

				if highlightOn and humanoid and rootPart and humanoid.Health > 0 and (player ~= localPlayer or selfEsp.value) then
					show, override = evaluate(player, character, rootPart)
				end

				if not show then
					if highlight then highlight.Enabled = false end
					continue
				end

				if not highlight then
					highlight = library:create("Highlight", {Parent = root})
					playerHighlights[player] = highlight
				end

				highlight.Adornee, highlight.Enabled = character, true
				highlight.DepthMode = highlightWalls.value and alwaysOnTop or occluded
				highlight.FillColor, highlight.FillTransparency = override or highlightFill.color, 1 - highlightFill.alpha
				highlight.OutlineColor, highlight.OutlineTransparency = override or highlightOutline.color, 1 - highlightOutline.alpha
			end
		end))

		track(players.PlayerRemoving:Connect(function(player)
			local highlight = playerHighlights[player]
			if not highlight then return end

			highlight:Destroy()
			playerHighlights[player] = nil
		end))

		local lightingStates, ownedInstances = {}, {}

		local function createOwned(className, properties)
			local instance = library:create(className, properties)
			table.insert(ownedInstances, instance)
			return instance
		end

		local correction = createOwned("ColorCorrectionEffect", {Enabled = false, Parent = lighting})
		local ownAtmosphere, ownSky = createOwned("Atmosphere", {}), createOwned("Sky", {})

		local function attach(instance, className)
			if pcall(function() instance.Parent = lighting end) then return instance end
			return createOwned(className, {Parent = lighting})
		end

		local function override(instance, property, on, value)
			local states = lightingStates[instance]

			if not states then
				states = {}
				lightingStates[instance] = states
			end

			local state = states[property]

			if on then
				if not state then
					state = {original = instance[property]}
					states[property] = state

					state.connection = instance:GetPropertyChangedSignal(property):Connect(function()
						if instance[property] ~= state.value then instance[property] = state.value end
					end)
				end

				state.value = value
				if instance[property] ~= value then instance[property] = value end
			elseif state then
				state.connection:Disconnect()
				instance[property] = state.original
				states[property] = nil
			end
		end

		getgenv().libraryCleanup = function()
			RunService:UnbindFromRenderStep("libraryWorld")
			restoreOriginals()
			if materialAdded then materialAdded:Disconnect() end

			for instance, states in lightingStates do
				for property, state in states do
					state.connection:Disconnect()
					instance[property] = state.original
				end
			end

			for _, instance in ownedInstances do instance:Destroy() end
		end

		RunService:BindToRenderStep("libraryWorld", Enum.RenderPriority.Last.Value, function()
			override(lighting, "ClockTime", timeOn.value, clockTime.value)

			local ambientEnabled, shiftEnabled, fogEnabled = ambientOn.value, shiftOn.value, fogOn.value
			override(lighting, "Ambient", ambientEnabled, ambientColor.color)
			override(lighting, "OutdoorAmbient", ambientEnabled, outdoorColor.color)
			override(lighting, "Brightness", brightnessOn.value, brightness.value)
			override(lighting, "ExposureCompensation", exposureOn.value, exposure.value)
			override(lighting, "ColorShift_Top", shiftEnabled, shiftTop.color)
			override(lighting, "ColorShift_Bottom", shiftEnabled, shiftBottom.color)
			override(lighting, "GlobalShadows", not globalShadows.value, false)
			override(lighting, "FogColor", fogEnabled, fogColor.color)
			override(lighting, "FogStart", fogEnabled, fogStart.value)
			override(lighting, "FogEnd", fogEnabled, fogEnd.value)

			local atmosphereEnabled, atmosphere = atmosphereOn.value, lighting:FindFirstChildOfClass("Atmosphere")

			if atmosphereEnabled and not atmosphere then
				ownAtmosphere = attach(ownAtmosphere, "Atmosphere")
				atmosphere = ownAtmosphere
			elseif not atmosphereEnabled and ownAtmosphere.Parent then
				ownAtmosphere.Parent = nil
			end

			if atmosphere then
				override(atmosphere, "Color", atmosphereEnabled, atmosphereColor.color)
				override(atmosphere, "Decay", atmosphereEnabled, atmosphereDecay.color)
				override(atmosphere, "Density", atmosphereEnabled, atmosphereDensity.value)
				override(atmosphere, "Haze", atmosphereEnabled, atmosphereHaze.value)
				override(atmosphere, "Glare", atmosphereEnabled, atmosphereGlare.value)
			end

			local preset, sky = skyboxes[skyboxSelect.value[1]], lighting:FindFirstChildOfClass("Sky")

			if preset and not sky then
				ownSky = attach(ownSky, "Sky")
				sky = ownSky
			elseif not preset and ownSky.Parent then
				ownSky.Parent = nil
			end

			if sky then
				for _, property in skyProperties do
					local value = preset and preset[property]
					override(sky, property, value ~= nil, value)
				end
			end

			local correctionEnabled = correctionOn.value
			if correctionEnabled and correction.Parent ~= lighting then correction = attach(correction, "ColorCorrectionEffect") end
			correction.Enabled = correctionEnabled

			if correctionEnabled then
				correction.TintColor, correction.Brightness = correctionTint.color, correctionBrightness.value
				correction.Contrast, correction.Saturation = correctionContrast.value, correctionSaturation.value
			end
		end)

		return {instance = page.instance, esp = espTab, world = worldTab, render = renderTab}
	end

	return windowObject
end

return library