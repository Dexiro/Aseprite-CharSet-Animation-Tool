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

local _hideCurrentLayer = true
local _overwriteCurrentLayer = false
local _frameLayoutType = 0
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
	_dlgList[1].dlg:modify{ id="fl_radio2", selected=false }
	RepaintDialog(1)
end

function SelectRad_LayoutTypeB()
	_frameLayoutType = 1
	_dlgList[1].dlg:modify{ id="fl_radio1", selected=false }
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

function UpdateFrameCount()
	_frameCount = _dlgList[1].dlg.data["numframes"]
	RepaintDialog(1)
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

function CreateFrames(frameCount)
	local sprite = app.sprite
	if frameCount <= 1 or #sprite.frames >= frameCount then return end
	-- create empty frames
	for i=2,frameCount do
		if i > #sprite.frames then 
			sprite:newEmptyFrame(i)
			-- copy cels for non-selected layers into the new frames
			for k,layer in ipairs(sprite.layers) do
				if layer ~= app.layer then
					local prevCel = layer:cel(i-1)
					if prevCel then
						local newCel = sprite:newCel(layer, i)
						newCel.image = Image(prevCel.image)
						newCel.position = prevCel.position
					end
				end
			end
			-- end of copy frames section
		end
	end
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

	CreateFrames(_frameCount)
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
		:check{id="btnhidelayer", text="Hide Current Layer", onclick=ToggleHideCurrentLayer}
		:newrow()
		:check{id="btnoverwritelayer", text="Overwrite Current Layer [!!]", onclick=ToggleOverwriteCurrentLayer}
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





