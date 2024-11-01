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

local dialog = Dialog("CharSet Animation Helper")

local _dialogResetBounds
local _hideCurrentLayer = true
local _overwriteCurrentLayer = false
local _frameLayoutType = 0
local _selectionOK = false
local _frameCount = 3

local _tileW = 24
local _tileH = 32

local _layoutATileNumberImages = {}
local _layoutBTileNumberImages = {}
local _layoutTileNumH = 44
local _layoutTileNumW = 33


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
	dialog:modify{ id="fl_radio2", selected=false }
	RepaintDialog()
end

function SelectRad_LayoutTypeB()
	_frameLayoutType = 1
	dialog:modify{ id="fl_radio1", selected=false }
	RepaintDialog()
end

function ToggleHideCurrentLayer()
	_hideCurrentLayer = not _hideCurrentLayer
end

function ToggleOverwriteCurrentLayer()
	_overwriteCurrentLayer = not _overwriteCurrentLayer
	if _overwriteCurrentLayer then
		dialog:modify{ id="btnhidelayer", enabled=false }
	else
		dialog:modify{ id="btnhidelayer", enabled=true }
	end
end

function RepaintDialog()
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
	end
end

function UpdateFrameCount()
	_frameCount = dialog.data["numframes"]
	RepaintDialog()
end

function CharSetToTimeline_Transaction()
	app.transaction(CharSetToTimeline)
	app.refresh()
end

function GetXYIndexForFrame(frameIndex)
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

function CharSetToTimeline()
	local sprite = app.sprite
	local selectionOrigin = GetSelectionOrigin(sprite)
	
	-- Create a new Image with the same dimensions as the Sprite
	-- We then want to copy the target Cel onto this image, using the Cel position as an offset
	-- This should help to simplify a lot of the positioning calculations going forward
	local charSetImage = Image(sprite.width, sprite.height, sprite.colorMode)
	charSetImage:drawImage(app.cel.image, app.cel.position)
	
	local frameImages = {}
	for i=1,_frameCount do
		local frameIndex = i - 1
		local xIndex, yIndex = GetXYIndexForFrame(frameIndex)
		local tileRect = GetTileRect(_tileW, _tileH, xIndex, yIndex, selectionOrigin)
		frameImages[i] = CopyImage(charSetImage, tileRect)
	end
	
	if (not _overwriteCurrentLayer and _hideCurrentLayer) then app.layer.isVisible = false end
	
	local outputLayer
	if _overwriteCurrentLayer then
		outputLayer = app.layer
	else
		local layerName = app.layer.name
		outputLayer = sprite:newLayer()
		outputLayer.name = layerName .. "_Compiled"
	end

	for i=1,_frameCount do
		if frameImages[i] ~= nil then
			local outputCel = nil
			if _overwriteCurrentLayer and outputLayer:cel(i) then sprite:deleteCel(outputLayer, i) end
			outputCel = sprite:newCel(outputLayer, i)
			outputCel.position = selectionOrigin
			outputCel.image = CopyImage(frameImages[i], Rectangle(0, 0, _tileW, _tileH))
		end 
	end
	
end

function TimelineToCharSet_Transaction()
	app.transaction(TimelineToCharSet)
	app.refresh()
end

function TimelineToCharSet()
	local sprite = app.sprite
	local selectionOrigin = GetSelectionOrigin(sprite)
	
	local layerCels = app.layer.cels
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
		outputLayer = app.layer
		if outputLayer:cel(1) then sprite:deleteCel(outputLayer, 1) end
	else
		local layerName = app.layer.name
		outputLayer = sprite:newLayer()
		outputLayer.name = layerName .. "_Compiled"
	end
	local outputCel = sprite:newCel(outputLayer, 1)

	local finalImage = Image(sprite.width, sprite.height, sprite.colorMode)
	for i=1,_frameCount do
		if frameImages[i] ~= nil then
			local frameIndex = i - 1
			local xIndex, yIndex = GetXYIndexForFrame(frameIndex)
			local tileRect = GetTileRect(_tileW, _tileH, xIndex, yIndex, selectionOrigin)
			finalImage:drawImage(frameImages[i], Point(tileRect.x, tileRect.y))
		end
	end
	outputCel.image = finalImage
end

LoadTileNumImageSets()

dialog:label{id="label1", text="Frame Layout:"}
dialog:radio{ id="fl_radio1", text="Horizontal (Step)", selected=true, onclick=SelectRad_LayoutTypeA }
dialog:radio{ id="fl_radio2", text="Vertical (Spin)", selected=false, onclick=SelectRad_LayoutTypeB }
dialog:newrow()
dialog:canvas{autoscaling=false, onpaint=UpdateCanvas}
--dialog.bounds = Rectangle(dialog.bounds.x, dialog.bounds.y, 175, dialog.bounds.height + 65)
--dialog:separator()
--dialog:label{id="label2", text="Selection area should be 24x32"}
--dialog:newrow()
--dialog:label{id="label3", text="[Selection Not Checked]"}
--dialog:button{id="btncheck", text="Check", onclick=CheckSelectionArea}
dialog:separator()
dialog:label{id="label4", text="Number of Frames:"}
dialog:slider{id="numframes", min=2, max=12, value=3, onchange=UpdateFrameCount}
dialog:label{id="label4", text="Tile Size:"}
dialog:number{id="tilewinput", text="".._tileW, decimals=0, onchange=function() _tileW=dialog.data["tilewinput"] end }
dialog:number{id="tilehinput", text="".._tileH, decimals=0, onchange=function() _tileH=dialog.data["tilehinput"] end } 
dialog:separator()
dialog:check{id="btnhidelayer", text="Hide Current Layer", onclick=ToggleHideCurrentLayer}
dialog:newrow()
dialog:check{id="btnoverwritelayer", text="Overwrite Current Layer [!!]", onclick=ToggleOverwriteCurrentLayer}
dialog:separator()
dialog:button{id="btndothing", text="Timeline -> CharSet", onclick=TimelineToCharSet_Transaction}
dialog:newrow()
dialog:button{id="btndothing2", text="CharSet -> Timeline", onclick=CharSetToTimeline_Transaction}
dialog:show{wait=false}
_dialogResetBounds = Rectangle(dialog.bounds.x, dialog.bounds.y, dialog.bounds.width, dialog.bounds.height)
RepaintDialog()