--!strict
-- Arte de interfaz generado con ForgeGUI (ver forgegui-project.json). Las imágenes se publicaron sin recortar:
-- cada pieza se recorta con ImageRectOffset/ImageRectSize en píxeles de la imagen guardada por Roblox (lado mayor ≤ 1024).
local UiArt = {}

export type Piece = { image: string, offset: Vector2, size: Vector2, slice: Rect? }

local PANEL = "rbxassetid://99587350783353"
local BUTTON = "rbxassetid://120477640903266"
local ICONS = "rbxassetid://113404836852402"

-- Placa de acero con 4 tornillos (9-slice: las esquinas con tornillo no se estiran).
UiArt.Panel = { image = PANEL, offset = Vector2.new(95, 38), size = Vector2.new(834, 500), slice = Rect.new(80, 80, 754, 420) } :: Piece
-- Botón de consola con filo cian.
UiArt.Button = { image = BUTTON, offset = Vector2.new(83, 154), size = Vector2.new(858, 267), slice = Rect.new(70, 70, 788, 197) } :: Piece

local function icon(x: number, y: number, w: number, h: number): Piece
	return { image = ICONS, offset = Vector2.new(x, y), size = Vector2.new(w, h) }
end
UiArt.Icons = {
	Hull = icon(141, 55, 178, 202),
	Oxygen = icon(402, 55, 202, 202),
	Depth = icon(674, 55, 200, 202),
	Repair = icon(126, 301, 199, 202),
	Money = icon(418, 318, 184, 177),
	Exit = icon(674, 306, 223, 191),
}

-- Aplica una pieza a un ImageLabel/ImageButton: fondo transparente, sin borde, recorte y 9-slice si lo tiene.
function UiArt.Apply(target: ImageLabel | ImageButton, piece: Piece, sliceScale: number?)
	target.BackgroundTransparency = 1
	target.BorderSizePixel = 0
	target.Image = piece.image
	target.ImageRectOffset = piece.offset
	target.ImageRectSize = piece.size
	if piece.slice then
		target.ScaleType = Enum.ScaleType.Slice
		target.SliceCenter = piece.slice
		target.SliceScale = sliceScale or 0.3
	else
		target.ScaleType = Enum.ScaleType.Fit
	end
end

-- Icono cuadrado de `px` píxeles.
function UiArt.Icon(piece: Piece, px: number, parent: Instance?): ImageLabel
	local img = Instance.new("ImageLabel")
	img.Size = UDim2.fromOffset(px, px)
	UiArt.Apply(img, piece)
	img.ImageColor3 = Color3.new(1, 1, 1)
	img.Parent = parent
	return img
end

return UiArt
