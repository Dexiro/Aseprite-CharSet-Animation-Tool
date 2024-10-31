-- Tool to help with pulling together CharSet animations (by dex plushy)
-- Features: 
-- * Convert a timeline animation into a CharSet animation. Animation frames can be arranged on the spritesheet in a vertical or horizontal layout. 

-- Shoutout to the Collective Unconscious YNFG community, hopefully this will help out with development! (https://ynoproject.net/unconscious/)

-----------------------------------------------------------------
-- Try editing these filepaths if you're having issues with the 
-- 		script not being able to find the 'data' folder
-----------------------------------------------------------------

local _pathScriptFolder = app.fs.userConfigPath .. 'scripts/'
local _pathTileNumberSheet = _pathScriptFolder .. 'CharSet-Animation-Helper/data/AnimHelperTileNumbers.png'

-----------------------------------------------------------------
-----------------------------------------------------------------

local dialog = Dialog("CharSet Animation Helper")

local _dialogResetBounds
local _frameLayoutType = 0
local _selectionOK = false
local _frameCount = 3

local _layoutATileNumberImages = {}
local _layoutBTileNumberImages = {}
local _layoutTileNumH = 44
local _layoutTileNumW = 33

function CopyImage(fromImage, rect, colorMode)
	local pixelsInRect = fromImage:pixels(rect)
	local newImage = Image(rect.width, rect.height, colorMode)
	for it in pixelsInRect do
		local pixelValue = it()
		local px = it.x - rect.x
		local py = it.y - rect.y
		newImage:putPixel(px, py, pixelValue)
	end
	return newImage
end

function LoadTileNumImages(srcImage, yOffset)
	local layoutTileImages = {}
	for i=0,11 do
		local rect = Rectangle(i*33, yOffset, 33, 44)
		layoutTileImages[i+1] = CopyImage(srcImage, rect, colorMode)
	end
	return layoutTileImages
end 

function LoadTileNumImageSets()
	local srcImage = Image{ fromFile=_pathTileNumberSheet }
	
	_layoutATileNumberImages = LoadTileNumImages(srcImage, 0)
	_layoutBTileNumberImages = LoadTileNumImages(srcImage, 44)
end

function SelectRad_LayoutTypeA()
	_frameLayoutType = 0
	dialog:modify{ id="fl_radio2", selected=false }
	RepaintDialog()
end

function SelectRad_LayoutTypeB()
	_frameLayoutType = 1
	dialog:modify{ id="fl_radio1", selected=false }
	RepaintDialog()
end

function CheckSelectionArea()
	local selection = app.sprite.selection
	if selection.bounds.width == 24 and selection.bounds.height == 32 then
		_selectionOK = true
		--dialog:modify{ id="label3", text="[Selection OK]" }
	else
		_selectionOK = false
		--dialog:modify{ id="label3", text="[Selection Not OK]" }
	end
	RepaintDialog()
	return _selectionOK
end

function RepaintDialog()
	--dialog.bounds = Rectangle(dialog.bounds.x, dialog.bounds.y, 175, _dialogResetBounds.height + 45)
	dialog.bounds = Rectangle(dialog.bounds.x, dialog.bounds.y, 175, _dialogResetBounds.height + 50)
	dialog:repaint()
end

function UpdateCanvas(ev)
	local gc = ev.context
	gc:beginPath()
	gc:rect(Rectangle(0, 0, 175, 80))
	gc:clip()
	-- gc is a GraphicsContext
	if _frameLayoutType == 0 then
		gc:drawImage(_layoutATileNumberImages[_frameCount], 60, 0)
		
	else
		gc:drawImage(_layoutBTileNumberImages[_frameCount], 60, 0)
		--gc:drawImage(_layoutInfoImageB, 0, 0)
	end
end

function UpdateFrameCount()
	_frameCount = dialog.data["numframes"]
	RepaintDialog()
end

function RefreshCanvas()
  --should be a nicer solution
  app.command.Undo()
  app.command.Redo()
end

function DoTheTransaction()
	app.transaction(DoTheThing)
	RefreshCanvas()
end

function DoTheThing()
	local sprite = app.sprite
	if CheckSelectionArea() == false then
		app.alert("Invalid Selection Area")
		return
	end
	local layerCels = app.layer.cels
	local frameImages = {}
	for i=1,_frameCount do
		if layerCels[i] ~= nil and layerCels[i].image ~= nil then
			local sourceImage = Image(sprite.selection.bounds.width, sprite.selection.bounds.height, sprite.colorMode)
			sourceImage:drawImage(layerCels[i].image, Point(layerCels[i].position.x, layerCels[i].position.y))
			local frameImage = CopyImage(sourceImage, sprite.selection.bounds, sprite.colorMode)
			frameImages[i] = frameImage
		end
	end
	
	local layerName = app.layer.name
	local outputLayer = sprite:newLayer()
	outputLayer.name = layerName .. "_Compiled"
	local newCel = sprite:newCel(outputLayer, 1)
	local finalImage = Image(24 * 3, 32*4, colorMode)
	
	for i=1,_frameCount do
		if frameImages[i] ~= nil then
			frameImage = frameImages[i]
			local xIndex = 0
			local yIndex = 0
			local frameIndex = i - 1
			if _frameLayoutType == 0 then
				xIndex = frameIndex % 3
				yIndex = math.floor(frameIndex / 3)
			else
				yIndex = frameIndex % 4
				xIndex = math.floor(frameIndex / 4)
			end
			finalImage:drawImage(frameImage, Point(xIndex * 24, yIndex * 32))
		end
	end
	newCel.image = finalImage
	
end

LoadTileNumImageSets()

dialog:label{id="label1", text="Frame Layout:"}
dialog:radio{ id="fl_radio1", text="Horizontal (Step)", selected=true, onclick=SelectRad_LayoutTypeA }
dialog:radio{ id="fl_radio2", text="Vertical (Spin)", selected=false, onclick=SelectRad_LayoutTypeB }
dialog:newrow()
dialog:canvas{autoscaling=false, onpaint=UpdateCanvas}
--dialog.bounds = Rectangle(dialog.bounds.x, dialog.bounds.y, 175, dialog.bounds.height + 65)
dialog:separator()
dialog:label{id="label2", text="Selection area should be 24x32"}
--dialog:newrow()
--dialog:label{id="label3", text="[Selection Not Checked]"}
--dialog:button{id="btncheck", text="Check", onclick=CheckSelectionArea}
dialog:separator()
dialog:label{id="label4", text="Number of Frames:"}
dialog:slider{id="numframes", min=2, max=12, value=3, onchange=UpdateFrameCount}
dialog:separator()
dialog:button{id="btndothing", text="Do The Thing", onclick=DoTheTransaction}
dialog:show{wait=false}
_dialogResetBounds = Rectangle(dialog.bounds.x, dialog.bounds.y, dialog.bounds.width, dialog.bounds.height)
CheckSelectionArea()
RepaintDialog()