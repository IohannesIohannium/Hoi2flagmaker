param(
[string]$InputFolder = (Join-Path $PSScriptRoot "input"),
[string]$ShadowMaskPath = (Join-Path $PSScriptRoot "shadow.bmp"),
[string]$OutputFolder = (Join-Path $PSScriptRoot "output/flags")
)

# Create output folder if it doesn't exist
if (-not (Test-Path $OutputFolder)) {
New-Item -ItemType Directory -Path $OutputFolder | Out-Null
}

# Load System.Drawing assembly once globally
Add-Type -AssemblyName "System.Drawing"

# Load the shadow mask once (must be 700x18) to reuse across all images
$shadowImg = [System.Drawing.Bitmap]::FromFile($ShadowMaskPath)

# Define column transformation rules for Sprite Phase 1 (0-indexed columns 0 to 24)
$allPhases = @(
@(
@{ Start = 0; End = 5; Height = 15; Shift = 1; Erase = $null },
@{ Start = 6; End = 10; Height = 16; Shift = 1; Erase = $null },
@{ Start = 11; End = 13; Height = 15; Shift = 2; Erase = $null },
@{ Start = 14; End = 16; Height = 16; Shift = 1; Erase = $null },
@{ Start = 17; End = 19; Height = 15; Shift = 1; Erase = $null },
@{ Start = 20; End = 22; Height = 16; Shift = 0; Erase = $null },
@{ Start = 23; End = 23; Height = 15; Shift = 1; Erase = $null },
@{ Start = 24; End = 24; Height = 15; Shift = 1; Erase = 6..11 }
),
@(
@{ Start = 0; End = 6; Height = 15; Shift = 1; Erase = $null },
@{ Start = 7; End = 10; Height = 16; Shift = 1; Erase = $null },
@{ Start = 11; End = 14; Height = 15; Shift = 2; Erase = $null },
@{ Start = 15; End = 17; Height = 16; Shift = 1; Erase = $null },
@{ Start = 18; End = 20; Height = 15; Shift = 1; Erase = $null },
@{ Start = 21; End = 21; Height = 16; Shift = 0; Erase = $null },
@{ Start = 22; End = 23; Height = 15; Shift = 1; Erase = $null },
@{ Start = 24; End = 24; Height = 15; Shift = 1; Erase = 6..11 }
),
@(
@{ Start = 0; End = 6; Height = 15; Shift = 1; Erase = $null },
@{ Start = 7; End = 10; Height = 16; Shift = 1; Erase = $null },
@{ Start = 11; End = 16; Height = 15; Shift = 2; Erase = $null },
@{ Start = 17; End = 19; Height = 16; Shift = 1; Erase = $null },
@{ Start = 20; End = 23; Height = 15; Shift = 1; Erase = $null },
@{ Start = 24; End = 24; Height = 15; Shift = 1; Erase = 6..11 }
),
@(
@{ Start = 0; End = 7; Height = 15; Shift = 1; Erase = $null },
@{ Start = 8; End = 11; Height = 16; Shift = 1; Erase = $null },
@{ Start = 12; End = 17; Height = 15; Shift = 2; Erase = $null },
@{ Start = 18; End = 20; Height = 16; Shift = 1; Erase = $null },
@{ Start = 21; End = 23; Height = 15; Shift = 1; Erase = $null },
@{ Start = 24; End = 24; Height = 15; Shift = 1; Erase = 6..11 }
),
@(
@{ Start = 0; End = 8; Height = 15; Shift = 1; Erase = $null },
@{ Start = 9; End = 11; Height = 16; Shift = 1; Erase = $null },
@{ Start = 12; End = 13; Height = 15; Shift = 2; Erase = $null },
@{ Start = 14; End = 16; Height = 16; Shift = 2; Erase = $null },
@{ Start = 17; End = 18; Height = 15; Shift = 2; Erase = $null },
@{ Start = 19; End = 21; Height = 16; Shift = 1; Erase = $null },
@{ Start = 22; End = 23; Height = 15; Shift = 1; Erase = $null },
@{ Start = 24; End = 24; Height = 15; Shift = 1; Erase = 6..11 }
),
@(
@{ Start = 0; End = 9; Height = 15; Shift = 1; Erase = $null },
@{ Start = 10; End = 12; Height = 16; Shift = 1; Erase = $null },
@{ Start = 13; End = 14; Height = 15; Shift = 2; Erase = $null },
@{ Start = 15; End = 17; Height = 16; Shift = 2; Erase = $null },
@{ Start = 18; End = 18; Height = 15; Shift = 2; Erase = $null },
@{ Start = 19; End = 23; Height = 15; Shift = 1; Erase = $null },
@{ Start = 24; End = 24; Height = 15; Shift = 1; Erase = 6..11 }
),
@(
@{ Start = 0; End = 10; Height = 15; Shift = 1; Erase = $null },
@{ Start = 11; End = 12; Height = 16; Shift = 1; Erase = $null },
@{ Start = 13; End = 14; Height = 15; Shift = 2; Erase = $null },
@{ Start = 15; End = 17; Height = 16; Shift = 2; Erase = $null },
@{ Start = 18; End = 19; Height = 15; Shift = 2; Erase = $null },
@{ Start = 20; End = 23; Height = 16; Shift = 1; Erase = $null },
@{ Start = 24; End = 24; Height = 15; Shift = 1; Erase = 6..12 }
),
@(
@{ Start = 0; End = 11; Height = 15; Shift = 1; Erase = $null },
@{ Start = 12; End = 13; Height = 16; Shift = 1; Erase = $null },
@{ Start = 14; End = 15; Height = 15; Shift = 2; Erase = $null },
@{ Start = 16; End = 18; Height = 16; Shift = 2; Erase = $null },
@{ Start = 19; End = 20; Height = 15; Shift = 2; Erase = $null },
@{ Start = 21; End = 23; Height = 16; Shift = 1; Erase = $null },
@{ Start = 24; End = 24; Height = 15; Shift = 1; Erase = 6..13 }
),
@(
@{ Start = 0; End = 12; Height = 15; Shift = 1; Erase = $null },
@{ Start = 13; End = 14; Height = 16; Shift = 1; Erase = $null },
@{ Start = 15; End = 16; Height = 15; Shift = 2; Erase = $null },
@{ Start = 17; End = 19; Height = 16; Shift = 2; Erase = $null },
@{ Start = 20; End = 21; Height = 15; Shift = 2; Erase = $null },
@{ Start = 22; End = 23; Height = 16; Shift = 1; Erase = $null },
@{ Start = 24; End = 24; Height = 15; Shift = 1; Erase = 6..13 }
),
@(
@{ Start = 0; End = 8; Height = 15; Shift = 1; Erase = $null },
@{ Start = 9; End = 10; Height = 16; Shift = 0; Erase = $null },
@{ Start = 11; End = 13; Height = 15; Shift = 1; Erase = $null },
@{ Start = 14; End = 15; Height = 16; Shift = 1; Erase = $null },
@{ Start = 16; End = 17; Height = 15; Shift = 2; Erase = $null },
@{ Start = 18; End = 19; Height = 16; Shift = 2; Erase = $null },
@{ Start = 20; End = 23; Height = 15; Shift = 2; Erase = $null },
@{ Start = 24; End = 24; Height = 15; Shift = 2; Erase = 5..13 }
),
@(
@{ Start = 0; End = 8; Height = 15; Shift = 1; Erase = $null },
@{ Start = 9; End = 12; Height = 16; Shift = 0; Erase = $null },
@{ Start = 13; End = 14; Height = 15; Shift = 1; Erase = $null },
@{ Start = 15; End = 16; Height = 16; Shift = 1; Erase = $null },
@{ Start = 17; End = 23; Height = 15; Shift = 2; Erase = $null },
@{ Start = 24; End = 24; Height = 15; Shift = 2; Erase = 5..13 }
),
@(
@{ Start = 0; End = 8; Height = 15; Shift = 1; Erase = $null },
@{ Start = 9; End = 13; Height = 16; Shift = 0; Erase = $null },
@{ Start = 14; End = 15; Height = 15; Shift = 1; Erase = $null },
@{ Start = 16; End = 17; Height = 16; Shift = 1; Erase = $null },
@{ Start = 18; End = 23; Height = 15; Shift = 2; Erase = $null },
@{ Start = 24; End = 24; Height = 15; Shift = 2; Erase = 5..13 }
),
@(
@{ Start = 0; End = 8; Height = 15; Shift = 1; Erase = $null },
@{ Start = 9; End = 14; Height = 16; Shift = 0; Erase = $null },
@{ Start = 15; End = 16; Height = 15; Shift = 1; Erase = $null },
@{ Start = 17; End = 18; Height = 16; Shift = 1; Erase = $null },
@{ Start = 19; End = 23; Height = 15; Shift = 2; Erase = $null },
@{ Start = 24; End = 24; Height = 15; Shift = 2; Erase = 5..13 }
),
@(
@{ Start = 0; End = 9; Height = 15; Shift = 1; Erase = $null },
@{ Start = 10; End = 15; Height = 16; Shift = 0; Erase = $null },
@{ Start = 16; End = 17; Height = 15; Shift = 1; Erase = $null },
@{ Start = 18; End = 19; Height = 16; Shift = 1; Erase = $null },
@{ Start = 20; End = 23; Height = 15; Shift = 2; Erase = $null },
@{ Start = 24; End = 24; Height = 15; Shift = 2; Erase = 5..13 }
),
@(
@{ Start = 0; End = 10; Height = 15; Shift = 1; Erase = $null },
@{ Start = 11; End = 16; Height = 16; Shift = 0; Erase = $null },
@{ Start = 17; End = 18; Height = 15; Shift = 1; Erase = $null },
@{ Start = 19; End = 20; Height = 16; Shift = 1; Erase = $null },
@{ Start = 21; End = 23; Height = 15; Shift = 2; Erase = $null },
@{ Start = 24; End = 24; Height = 15; Shift = 2; Erase = 5..13 }
),
@(
@{ Start = 0; End = 3; Height = 15; Shift = 1; Erase = $null },
@{ Start = 4; End = 7; Height = 16; Shift = 1; Erase = $null },
@{ Start = 8; End = 10; Height = 15; Shift = 1; Erase = $null },
@{ Start = 11; End = 17; Height = 16; Shift = 0; Erase = $null },
@{ Start = 18; End = 18; Height = 15; Shift = 1; Erase = $null },
@{ Start = 19; End = 21; Height = 16; Shift = 1; Erase = $null },
@{ Start = 22; End = 23; Height = 15; Shift = 2; Erase = $null },
@{ Start = 24; End = 24; Height = 15; Shift = 2; Erase = 5..13 }
),
@(
@{ Start = 0; End = 2; Height = 15; Shift = 1; Erase = $null },
@{ Start = 3; End = 8; Height = 16; Shift = 1; Erase = $null },
@{ Start = 9; End = 11; Height = 15; Shift = 1; Erase = $null },
@{ Start = 12; End = 18; Height = 16; Shift = 0; Erase = $null },
@{ Start = 19; End = 19; Height = 15; Shift = 1; Erase = $null },
@{ Start = 20; End = 22; Height = 16; Shift = 1; Erase = $null },
@{ Start = 23; End = 23; Height = 15; Shift = 2; Erase = $null },
@{ Start = 24; End = 24; Height = 15; Shift = 2; Erase = 5..13 }
),
@(
@{ Start = 0; End = 1; Height = 15; Shift = 1; Erase = $null },
@{ Start = 2; End = 9; Height = 16; Shift = 1; Erase = $null },
@{ Start = 10; End = 12; Height = 15; Shift = 1; Erase = $null },
@{ Start = 13; End = 18; Height = 16; Shift = 0; Erase = $null },
@{ Start = 19; End = 20; Height = 15; Shift = 1; Erase = $null },
@{ Start = 21; End = 23; Height = 16; Shift = 1; Erase = $null },
@{ Start = 24; End = 24; Height = 15; Shift = 2; Erase = 5..13 }
),
@(
@{ Start = 0; End = 1; Height = 15; Shift = 1; Erase = $null },
@{ Start = 2; End = 10; Height = 16; Shift = 1; Erase = $null },
@{ Start = 11; End = 12; Height = 15; Shift = 1; Erase = $null },
@{ Start = 13; End = 19; Height = 16; Shift = 0; Erase = $null },
@{ Start = 20; End = 21; Height = 15; Shift = 1; Erase = $null },
@{ Start = 22; End = 23; Height = 16; Shift = 1; Erase = $null },
@{ Start = 24; End = 24; Height = 15; Shift = 2; Erase = 5..13 }
),
@(
@{ Start = 0; End = 1; Height = 15; Shift = 1; Erase = $null },
@{ Start = 2; End = 11; Height = 16; Shift = 1; Erase = $null },
@{ Start = 12; End = 13; Height = 15; Shift = 1; Erase = $null },
@{ Start = 14; End = 20; Height = 16; Shift = 0; Erase = $null },
@{ Start = 21; End = 21; Height = 15; Shift = 1; Erase = $null },
@{ Start = 22; End = 23; Height = 16; Shift = 1; Erase = $null },
@{ Start = 24; End = 24; Height = 15; Shift = 2; Erase = 5..13 }
),
@(
@{ Start = 0; End = 2; Height = 15; Shift = 1; Erase = $null },
@{ Start = 3; End = 12; Height = 16; Shift = 1; Erase = $null },
@{ Start = 13; End = 14; Height = 15; Shift = 1; Erase = $null },
@{ Start = 15; End = 20; Height = 16; Shift = 0; Erase = $null },
@{ Start = 21; End = 22; Height = 15; Shift = 1; Erase = $null },
@{ Start = 23; End = 23; Height = 16; Shift = 1; Erase = $null },
@{ Start = 24; End = 24; Height = 16; Shift = 1; Erase = 6..13 }
),
@(
@{ Start = 0; End = 4; Height = 15; Shift = 1; Erase = $null },
@{ Start = 4; End = 13; Height = 16; Shift = 1; Erase = $null },
@{ Start = 14; End = 15; Height = 15; Shift = 1; Erase = $null },
@{ Start = 16; End = 21; Height = 16; Shift = 0; Erase = $null },
@{ Start = 22; End = 22; Height = 15; Shift = 1; Erase = $null },
@{ Start = 23; End = 23; Height = 16; Shift = 1; Erase = $null },
@{ Start = 24; End = 24; Height = 16; Shift = 1; Erase = 6..13 }
),
@(
@{ Start = 0; End = 4; Height = 15; Shift = 1; Erase = $null },
@{ Start = 5; End = 14; Height = 16; Shift = 1; Erase = $null },
@{ Start = 15; End = 16; Height = 15; Shift = 1; Erase = $null },
@{ Start = 17; End = 21; Height = 16; Shift = 0; Erase = $null },
@{ Start = 22; End = 23; Height = 15; Shift = 1; Erase = $null },
@{ Start = 24; End = 24; Height = 16; Shift = 1; Erase = 6..13 }
),
@(
@{ Start = 0; End = 4; Height = 15; Shift = 1; Erase = $null },
@{ Start = 5; End = 15; Height = 16; Shift = 1; Erase = $null },
@{ Start = 16; End = 17; Height = 15; Shift = 1; Erase = $null },
@{ Start = 18; End = 21; Height = 16; Shift = 0; Erase = $null },
@{ Start = 22; End = 23; Height = 15; Shift = 1; Erase = $null },
@{ Start = 24; End = 24; Height = 16; Shift = 1; Erase = 6..13 }
),
@(
@{ Start = 0; End = 5; Height = 15; Shift = 1; Erase = $null },
@{ Start = 6; End = 10; Height = 16; Shift = 1; Erase = $null },
@{ Start = 11; End = 13; Height = 15; Shift = 2; Erase = $null },
@{ Start = 14; End = 16; Height = 16; Shift = 1; Erase = $null },
@{ Start = 17; End = 19; Height = 15; Shift = 1; Erase = $null },
@{ Start = 20; End = 22; Height = 16; Shift = 0; Erase = $null },
@{ Start = 23; End = 23; Height = 15; Shift = 1; Erase = $null },
@{ Start = 24; End = 24; Height = 15; Shift = 1; Erase = 6..13 }
)
)

# Function to render a sprite given a set of column rules at a specific sprite index slot
function Render-Sprite {
param(
[System.Drawing.Bitmap]$SourceBmp,
[System.Drawing.Graphics]$TargetGraphics,
[array]$Rules,
[int]$SpriteIndex,
[System.Drawing.Color]$TransparentColor
)

$boxOffsetX = $SpriteIndex * 28

foreach ($rule in $Rules) {
    $colCount = $rule.End - $rule.Start
    for ($i = 0; $i -le $colCount; $i++) {
        $currentDestCol = $rule.Start + $i
        
        $baseSourceStart = if ($rule.PSobject.Properties.Name -contains "Source" -and $rule.Source -ne $null) { $rule.Source } else { $rule.Start }
        $currentSrcCol = $baseSourceStart + $i

        if ($currentSrcCol -gt 24) { $currentSrcCol = 24 }

        $srcRect = New-Object System.Drawing.Rectangle($currentSrcCol, 0, 1, 15)
        $colBmp = $SourceBmp.Clone($srcRect, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)

        $destHeight = 15
        if ($rule.Height -ne 15) {
            $scaledCol = New-Object System.Drawing.Bitmap(1, $rule.Height, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
            $g = [System.Drawing.Graphics]::FromImage($scaledCol)
            $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
            $g.DrawImage($colBmp, 0, 0, 1, $rule.Height)
            $g.Dispose()
            $colBmp.Dispose()
            $colBmp = $scaledCol
            $destHeight = $rule.Height
        }

        if ($rule.Erase -ne $null) {
            for ($row = 0; $row -le $colBmp.Height; $row++) {
                if ($rule.Erase -contains $row) {
                    if ($row -lt $colBmp.Height) {
                        $colBmp.SetPixel(0, $row, $TransparentColor)
                    }
                }
            }
        }

        $destX = $boxOffsetX + $currentDestCol
        $destY = $rule.Shift

        $TargetGraphics.DrawImage($colBmp, $destX, $destY, 1, $destHeight)
        $colBmp.Dispose()
    }
}

}

# Iterate through every BMP file in the input directory.
# _emblems.bmp files are deliberately skipped because they are overlays
# for their corresponding base flag rather than flags to process themselves.
Get-ChildItem -Path $InputFolder -Filter "*.bmp" -File |
Where-Object { $_.BaseName -notlike "*_emblems" -and
    $_.BaseName -notlike "*_vertical" } |
ForEach-Object {

$InputImagePath = $_.FullName
$OutputPath = Join-Path $OutputFolder "flag_$($_.Name)"

# -----------------------------------------------------------------------

# 1. Load the base flag and scale it to 25x15.

# -----------------------------------------------------------------------

$originalImg = [System.Drawing.Bitmap]::FromFile($InputImagePath)

$base25x15 = New-Object System.Drawing.Bitmap(
    25,
    15,
    [System.Drawing.Imaging.PixelFormat]::Format32bppArgb
)

$graphicsBase = [System.Drawing.Graphics]::FromImage($base25x15)
$graphicsBase.InterpolationMode =
    [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$graphicsBase.SmoothingMode =
    [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
$graphicsBase.PixelOffsetMode =
    [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
$graphicsBase.CompositingQuality =
    [System.Drawing.Drawing2D.CompositingQuality]::HighQuality

$graphicsBase.DrawImage($originalImg, 0, 0, 25, 15)

$graphicsBase.Dispose()
$originalImg.Dispose()

# -----------------------------------------------------------------------
# 2. Look for a matching _emblems.bmp file.
#
# Example:
#     abc.bmp
#     abc_emblems.bmp
#
# If the emblem file exists, resize it to 25x15 and paste it directly
# over the base flag. No coordinate transformation is performed.
# -----------------------------------------------------------------------

$emblemPath = Join-Path $_.DirectoryName ($_.BaseName + "_emblems.bmp")

if (Test-Path $emblemPath) {

    $emblemOriginal =
        [System.Drawing.Bitmap]::FromFile($emblemPath)

    $emblem25x15 = New-Object System.Drawing.Bitmap(
        25,
        15,
        [System.Drawing.Imaging.PixelFormat]::Format32bppArgb
    )

    $emblemGraphics =
        [System.Drawing.Graphics]::FromImage($emblem25x15)

    $emblemGraphics.InterpolationMode =
        [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $emblemGraphics.SmoothingMode =
        [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $emblemGraphics.PixelOffsetMode =
        [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $emblemGraphics.CompositingQuality =
        [System.Drawing.Drawing2D.CompositingQuality]::HighQuality

    # Draw the emblem over the flag at exactly the same coordinates.

    # Its alpha channel determines what is actually overlaid.

    $emblemGraphics.DrawImage(
        $emblemOriginal,
        0,
        0,
        25,
        15
    )

    $emblemGraphics.Dispose()
    $emblemOriginal.Dispose()

    # Composite the emblem layer onto the already-resized flag.
    $baseGraphics =
        [System.Drawing.Graphics]::FromImage($base25x15)

    $baseGraphics.CompositingMode =
        [System.Drawing.Drawing2D.CompositingMode]::SourceOver

    $baseGraphics.DrawImage(
        $emblem25x15,
        0,
        0,
        25,
        15
    )

    $baseGraphics.Dispose()
    $emblem25x15.Dispose()
}
else {
	
}

# -----------------------------------------------------------------------
# 3. Create final canvas: 700 width by 18 height.
# -----------------------------------------------------------------------

$spriteSheetWidth = 700
$spriteSheetHeight = 18

$canvas = New-Object System.Drawing.Bitmap(
    $spriteSheetWidth,
    $spriteSheetHeight,
    [System.Drawing.Imaging.PixelFormat]::Format32bppArgb
)

$canvasGraphics = [System.Drawing.Graphics]::FromImage($canvas)

# Fill entire canvas with transparency color (#00ff00)

$transparentColor =
    [System.Drawing.Color]::FromArgb(0, 255, 0)

$canvasGraphics.Clear($transparentColor)

# -----------------------------------------------------------------------
# 4. Render all phases into the sprite index slots.
# -----------------------------------------------------------------------

for ($i = 0; $i -lt $allPhases.Count; $i++) {
    Render-Sprite `
        -SourceBmp $base25x15 `
        -TargetGraphics $canvasGraphics `
        -Rules $allPhases[$i] `
        -SpriteIndex $i `
        -TransparentColor $transparentColor
}

# -----------------------------------------------------------------------
# 5. Multiply the shadow mask onto the canvas.
# -----------------------------------------------------------------------

for ($x = 0; $x -lt $canvas.Width; $x++) {
    for ($y = 0; $y -lt $canvas.Height; $y++) {

        $canvasPixel = $canvas.GetPixel($x, $y)
        
        # Skip transparent pixels
        if ($canvasPixel.R -eq 0 -and
            $canvasPixel.G -eq 255 -and
            $canvasPixel.B -eq 0) {

            continue
        }

        $shadowPixel = $shadowImg.GetPixel($x, $y)

        $factor =
            (($shadowPixel.R +
              $shadowPixel.G +
              $shadowPixel.B) / 3.0) / 255.0

        $newR = [Math]::Min(
            255,
            [Math]::Max(
                0,
                [int]($canvasPixel.R * $factor)
            )
        )

        $newG = [Math]::Min(
            255,
            [Math]::Max(
                0,
                [int]($canvasPixel.G * $factor)
            )
        )

        $newB = [Math]::Min(
            255,
            [Math]::Max(
                0,
                [int]($canvasPixel.B * $factor)
            )
        )

        $canvas.SetPixel(
            $x,
            $y,
            [System.Drawing.Color]::FromArgb(
                $canvasPixel.A,
                $newR,
                $newG,
                $newB
            )
        )
    }
}

# -----------------------------------------------------------------------
# 6. Create a clean 24bppRgb bitmap matching your canvas size.
# -----------------------------------------------------------------------

$final24bit = New-Object System.Drawing.Bitmap(
    $canvas.Width,
    $canvas.Height,
    [System.Drawing.Imaging.PixelFormat]::Format24bppRgb
)

$finalGraphics =
    [System.Drawing.Graphics]::FromImage($final24bit)

$finalGraphics.DrawImage(
    $canvas,
    0,
    0,
    $canvas.Width,
    $canvas.Height
)

$finalGraphics.Dispose()

# -----------------------------------------------------------------------
# 7. Save the 24-bit version and clean up.
# -----------------------------------------------------------------------

$final24bit.Save(
    $OutputPath,
    [System.Drawing.Imaging.ImageFormat]::Bmp
)

$final24bit.Dispose()
$canvasGraphics.Dispose()
$canvas.Dispose()
$base25x15.Dispose()

}

# Cleanup global resources
$shadowImg.Dispose()