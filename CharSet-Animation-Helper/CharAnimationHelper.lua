-- Tool to help with pulling together CharSet animations (by dex plushy)
-- Features: 
-- * Convert a timeline animation into a CharSet animation. Animation frames can be arranged on the spritesheet in a vertical or horizontal layout. 
-- * Convert from CharSet animation to a timeline animation. 

-- Shoutout to the Collective Unconscious YNFG community, hopefully this will help out with development! (https://ynoproject.net/unconscious/)

-----------------------------------------------------------------
-- Try editing these filepaths if you're having issues with the 
-- 		script not being able to find the 'data' folder
-----------------------------------------------------------------

local _pathScriptFolder = app.fs.userConfigPath .. 'scripts/'
local _pathTileNumberSheet = _pathScriptFolder .. 'CharSet-Animation-Helper/data/AnimHelperTileNumbers.png'

-----------------------------------------------------------------
-----------------------------------------------------------------

local _dlgList = {}

local _hideCurrentLayer = false
local _overwriteCurrentLayer = false
local _steppyMode = false
local _frameLayoutType = 0
local _frameCount = 3

local _tileW = 24
local _tileH = 32

local _layoutATileNumberImages = {}
local _layoutBTileNumberImages = {}
local _layoutTileNumH = 44
local _layoutTileNumW = 33

local _enableMultiLayer = false
local _multiLayerConfig = {}


function ToStr_Rect(rect)
	return ("[x" .. rect.x .. ":y" .. rect.y .. ":w" .. rect.width .. ":h" .. rect.height .. "]")
end

function GetTileRect(tileW, tileH, xIndex, yIndex, origin)
	origin = origin or Point()
	local xPos = (xIndex * tileW) + origin.x
	local yPos = (yIndex * tileH) + origin.y
	return Rectangle(xPos, yPos, tileW, tileH)
end

function CopyImage(srcImage, srcRect, dstRect)
	dstRect = dstRect or Rectangle(0, 0, srcRect.width, srcRect.height)
	local pixelsInRect = srcImage:pixels(srcRect)
	local newImage = Image(dstRect.width, dstRect.height, srcImage.colorMode)
	for it in pixelsInRect do
		local pixelValue = it()
		local px = (it.x - srcRect.x) + dstRect.x
		local py = (it.y - srcRect.y) + dstRect.y
		newImage:putPixel(px, py, pixelValue)
	end
	return newImage
end

function GetRowFromTileset(srcImage, rowIndex, tileW, tileH, nTiles, origin)
	origin = origin or Point(0,0)
	local tileImages = {}
	for i=0,nTiles do
		tileImages[i+1] = CopyImage(srcImage, GetTileRect(tileW, tileH, i, rowIndex, origin))
	end
	return tileImages
end 

function LoadTileNumImageSets()
	local srcImage = Image{ fromFile=_pathTileNumberSheet }
	local tileW, tileH, nTiles = 33, 44, 11
	_layoutATileNumberImages = GetRowFromTileset(srcImage, 0, tileW, tileH, nTiles)
	_layoutBTileNumberImages = GetRowFromTileset(srcImage, 1, tileW, tileH, nTiles)
end

function GetSelectionOrigin(sprite)
	if sprite and sprite.selection then
		return sprite.selection.origin
	end
	return Point()
end

function SelectRad_LayoutTypeA()
	_frameLayoutType = 0
	_dlgList[1].dlg:modify{ id="fl_radio2", selected=false }
	CheckSteppyModeConditions()
	RepaintDialog(1)
end

function SelectRad_LayoutTypeB()
	_frameLayoutType = 1
	_dlgList[1].dlg:modify{ id="fl_radio1", selected=false }
	CheckSteppyModeConditions()
	RepaintDialog(1)
end

function ToggleHideCurrentLayer()
	_hideCurrentLayer = not _hideCurrentLayer
end

function ToggleOverwriteCurrentLayer()
	_overwriteCurrentLayer = not _overwriteCurrentLayer
	if _overwriteCurrentLayer then
		_dlgList[1].dlg:modify{ id="btnhidelayer", enabled=false }
	else
		_dlgList[1].dlg:modify{ id="btnhidelayer", enabled=true }
	end
end

function RepaintDialog(index)
	if _dlgList[index] and _dlgList[index].dlg then
		local dialog = _dlgList[index].dlg
		if _dlgList[index].reset then
			local reset = _dlgList[index].reset
			dialog.bounds = Rectangle(dialog.bounds.x, dialog.bounds.y, reset.x, reset.y)
		end
		dialog:repaint()
	end
	app.refresh()
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
	end
end

function CheckSteppyModeConditions()
	local enabled = false
	if _frameCount == 3 and _frameLayoutType == 0 then
		if _steppyMode then enabled = true end
		_dlgList[1].dlg:modify{ id="btnsteppymode", enabled=true }
	else
		_dlgList[1].dlg:modify{ id="btnsteppymode", enabled=false }
	end
	return enabled
end

function UpdateFrameCount()
	_frameCount = _dlgList[1].dlg.data["numframes"]
	CheckSteppyModeConditions()
	RepaintDialog(1)
end

function GetXYIndexForFrame(frameIndex)
	local xIndex, yIndex
	if _frameLayoutType == 0 then
		xIndex = frameIndex % 3
		yIndex = math.floor(frameIndex / 3)
	else
		yIndex = frameIndex % 4
		xIndex = math.floor(frameIndex / 4)
	end
	return xIndex, yIndex
end

function TileWH()
	return Point(_tileW, _tileH)
end

function CreateFrames(frameCount)
	local sprite = app.sprite
	if frameCount <= 1 or #sprite.frames >= frameCount then return end
	-- create empty frames
	for i=2,frameCount do
		if i > #sprite.frames then 
			sprite:newEmptyFrame(i)
			-- copy cels for non-selected layers into the new frames
			for k,layer in ipairs(sprite.layers) do
				local prevCel = layer:cel(i-1)
				if prevCel then
					local newCel = sprite:newCel(layer, i)
					newCel.image = Image(prevCel.image)
					newCel.position = prevCel.position
				end
			end
			-- end of copy frames section
		end
	end
end

function CharSetToTimeline_Transaction()
	app.transaction(function()
		if not _enableMultiLayer then
			CharSetToTimeline(app.layer)
		else
			local layers = app.sprite.layers
			for i=1, #layers do
				local revI = #layers + 1 - i
				local layer = layers[revI]
				if _multiLayerConfig[revI] then
					CharSetToTimeline(layer)
				end
			end
		end
	end)
	app.refresh()
end

function CharSetToTimeline(targetLayer)
	if not targetLayer then return end
	local targetCel = targetLayer:cel(app.frame.frameNumber)
	if not targetCel then
		app.alert("No image on selected layer/frame")
		return
	end

	local sprite = app.sprite
	local selectionOrigin = GetSelectionOrigin(sprite)
	local localFrameCount = _frameCount

	-- Create a new Image with the same dimensions as the Sprite
	-- We then want to copy the target Cel onto this image, using the Cel position as an offset
	-- This should help to simplify a lot of the positioning calculations going forward
	local charSetImage = Image(sprite.width, sprite.height, sprite.colorMode)
	charSetImage:drawImage(targetCel.image, targetCel.position)
	
	local frameImages = {}
	for i=1,localFrameCount do
		local frameIndex = i - 1
		local xIndex, yIndex = GetXYIndexForFrame(frameIndex)
		local tileRect = GetTileRect(_tileW, _tileH, xIndex, yIndex, selectionOrigin)
		frameImages[i] = CopyImage(charSetImage, tileRect)
		charSetImage:clear(tileRect)
	end
	
	if CheckSteppyModeConditions() then
		localFrameCount = localFrameCount + 1
		frameImages[localFrameCount] = Image(frameImages[2])
	end

	if (not _overwriteCurrentLayer and _hideCurrentLayer) then app.layer.isVisible = false end

	local outputLayer
	if _overwriteCurrentLayer then
		outputLayer = targetLayer
	else
		local layerName = targetLayer.name
		outputLayer = sprite:newLayer()
		outputLayer.name = layerName .. "_Compiled"
	end

	CreateFrames(localFrameCount)
	for i=1,localFrameCount do
		local outputCel = outputLayer:cel(i)
		if not outputCel then outputCel = sprite:newCel(outputLayer, i) end

		local finalImage = Image(sprite.width, sprite.height, sprite.colorMode)
		finalImage:drawImage(outputCel.image, outputCel.position)
		local tileRect = Rectangle(selectionOrigin.x, selectionOrigin.y, _tileW, _tileH)
		finalImage:clear(tileRect)
		if frameImages[i] ~= nil then
			finalImage:drawImage(frameImages[i], selectionOrigin)
		end
		outputCel.position = Point()
		outputCel.image = finalImage
	end
	
end

function TimelineToCharSet_Transaction()
	app.transaction(function()
		if not _enableMultiLayer then
			TimelineToCharSet(app.layer)
		else
			local layers = app.sprite.layers
			for i=1, #layers do
				local revI = #layers + 1 - i
				local layer = layers[revI]
				if _multiLayerConfig[revI] then
					TimelineToCharSet(layer)
				end
			end
		end
	end)
	app.refresh()
end

function TimelineToCharSet(targetLayer)
	if not targetLayer then return end
	local sprite = app.sprite
	local selectionOrigin = GetSelectionOrigin(sprite)
	
	local layerCels = targetLayer.cels
	local frameImages = {}
	for i=1,_frameCount do
		if layerCels[i] ~= nil and layerCels[i].image ~= nil then
			local sourceImage = Image(sprite.width, sprite.height, sprite.colorMode)
			sourceImage:drawImage(layerCels[i].image, layerCels[i].position)
			frameImages[i] = CopyImage(sourceImage, Rectangle(selectionOrigin.x, selectionOrigin.y, _tileW, _tileH))
		end
	end
	
	if (not _overwriteCurrentLayer and _hideCurrentLayer) then app.layer.isVisible = false end
	
	local outputLayer
	if _overwriteCurrentLayer then
		outputLayer = targetLayer
	else
		local layerName = targetLayer.name
		outputLayer = sprite:newLayer()
		outputLayer.name = layerName .. "_Compiled"
	end
	local outputCel = outputLayer:cel(1)
	if not outputCel then outputCel = sprite:newCel(outputLayer, 1) end

	local finalImage = Image(sprite.width, sprite.height, sprite.colorMode)
	finalImage:drawImage(outputCel.image, outputCel.position)
	for i=1,_frameCount do
		if frameImages[i] ~= nil then
			local frameIndex = i - 1
			local xIndex, yIndex = GetXYIndexForFrame(frameIndex)
			local tileRect = GetTileRect(_tileW, _tileH, xIndex, yIndex, selectionOrigin)
			finalImage:clear(tileRect)
			finalImage:drawImage(frameImages[i], Point(tileRect.x, tileRect.y))
		end
	end
	outputCel.position = Point()
	outputCel.image = finalImage
	--outputCel.image:shrinkBounds()
end

function CreateMultiLayerDialog(parentDlg)
	if not parentDlg then
		app.alert("aaaaa")
	end

	layerDlg = Dialog{ title="Multi-Layer Options", parent=parentDlg}
		:check{id="btnenablem", text="Enable Multi-Layer Mode", selected=_enableMultiLayer, onclick=function()
			_enableMultiLayer = not _enableMultiLayer
			local layers = app.sprite.layers
			for i=1, #layers do
				local revI = #layers + 1 - i
				layerDlg:modify{id="btnmlayer" .. revI, enabled=_enableMultiLayer}
			end
			end }
		:separator()

	local layers = app.sprite.layers
	for i=1, #layers do
		local revI = #layers + 1 - i
		local layer = layers[revI]
		
		_multiLayerConfig[revI] = _multiLayerConfig[revI] or false
		local text = revI .. " - " .. layer.name

		if layer == app.layer then
			text = revI .. " - " .. layer.name .. " (selected)"
		else

		end
		layerDlg:check{id="btnmlayer" .. revI, text=text, enabled=_enableMultiLayer, selected=_multiLayerConfig[revI], onclick=function() _multiLayerConfig[revI] = not _multiLayerConfig[revI] end }
		layerDlg:newrow()
	end

	layerDlg:separator()
		:button{id="btnmconfirm", text="Confirm", onclick=function() layerDlg:close() end}
		--:button{id="btnmcancel", text="Cancel", onclick=function() layerDlg:close() end}
		
	layerDlg:show{wait=true, autoscrollbars=true}
	return layerDlg
end


function CreateAnimConvertDialog(index)
	dialog = Dialog("CharSet Animation Helper")
		--:tab{ id="tab1", text="char/timeline", selected=true }		
		:label{id="label1", text="Frame Layout:"}
		:radio{ id="fl_radio1", text="Horizontal (Step)", selected=true, onclick=SelectRad_LayoutTypeA }
		:radio{ id="fl_radio2", text="Vertical (Spin)", selected=false, onclick=SelectRad_LayoutTypeB }
		:newrow()
		:canvas{autoscaling=true, onpaint=UpdateCanvas}
		:separator()
		:label{id="label4", text="Number of Frames:"}
		:slider{id="numframes", min=2, max=12, value=3, onchange=UpdateFrameCount}
		:label{id="label4", text="Tile Size:"}
		:number{id="tilewinput", text="".._tileW, decimals=0, onchange=function() _tileW=dialog.data["tilewinput"] end }
		:number{id="tilehinput", text="".._tileH, decimals=0, onchange=function() _tileH=dialog.data["tilehinput"] end }
		:separator()
		:check{id="btnhidelayer", text="Hide Current Layer", selected=_hideCurrentLayer, onclick=ToggleHideCurrentLayer}
		:newrow()
		:check{id="btnoverwritelayer", text="Overwrite Current Layer [!!]", selected=_overwriteCurrentLayer, onclick=ToggleOverwriteCurrentLayer}
		:newrow()
		:check{id="btnsteppymode", text="Steppy Mode", onclick=function() _steppyMode = not _steppyMode end}
		:separator()
		:button{id="btnmultilayer", text="Multi-Layer Mode", onclick=function() CreateMultiLayerDialog(dialog) end}
		:separator()
		:button{id="btndothing", text="Timeline -> CharSet", onclick=TimelineToCharSet_Transaction}
		:newrow()
		:button{id="btndothing2", text="CharSet -> Timeline", onclick=CharSetToTimeline_Transaction}
		--:endtabs{ id="tab1" } 
		--:tab{ id="tab2", text="anim preview" }
		--:endtabs{ id="tab2", selected=false } 
		:show{wait=false}
	_dlgList[index] = { dlg=dialog, reset=Point(dialog.bounds.width, dialog.bounds.height + (50 * app.uiScale)) }
	return dialog
end

LoadTileNumImageSets()
CreateAnimConvertDialog(1)
RepaintDialog(1)





