param(
[string]$InputFolder = (Join-Path $PSScriptRoot "input"),
[string]$OutputFolder = (Join-Path $PSScriptRoot "output/flags")
)

# Create output folder if it doesn't exist
if (-not (Test-Path $OutputFolder)) {
New-Item -ItemType Directory -Path $OutputFolder | Out-Null
}

# Load System.Drawing assembly once globally
Add-Type -AssemblyName "System.Drawing"

# Iterate through every BMP file in the input directory.
# _emblems.bmp files are overlays and should not be processed on their own.
Get-ChildItem -Path $InputFolder -Filter "*.bmp" -File |
Where-Object { $_.BaseName -notlike "*_emblems" -and
    $_.BaseName -notlike "*_vertical" } |
ForEach-Object {

$InputImagePath = $_.FullName
$OutputPath = Join-Path $OutputFolder "icon_$($_.BaseName).bmp"

# -----------------------------------------------------------------------
# 1. Load the base flag.
# -----------------------------------------------------------------------

$originalImg = [System.Drawing.Bitmap]::FromFile($InputImagePath)

# -----------------------------------------------------------------------
# 2. Look for a matching _emblems.bmp.
#
# For:
#     abc.bmp
#
# look for:
#     abc_emblems.bmp
#
# The emblem is composited directly onto the original image BEFORE
# resizing, so it follows exactly the same resizing as the flag.
# -----------------------------------------------------------------------

$emblemPath = Join-Path $_.DirectoryName ($_.BaseName + "_emblems.bmp")

$sourceImg = $originalImg

if (Test-Path $emblemPath) {

    $emblemImg =
        [System.Drawing.Bitmap]::FromFile($emblemPath)

    # Create a working image based on the original flag.
    #
    # Using the original dimensions means the emblem can simply be
    # placed at its original coordinates without any coordinate
    # manipulation.
    $compositedImg = New-Object System.Drawing.Bitmap(
        $originalImg.Width,
        $originalImg.Height,
        [System.Drawing.Imaging.PixelFormat]::Format32bppArgb
    )

    $compositeGraphics =
        [System.Drawing.Graphics]::FromImage($compositedImg)

    $compositeGraphics.CompositingMode =
        [System.Drawing.Drawing2D.CompositingMode]::SourceOver

    # Draw the base flag first.
    $compositeGraphics.DrawImage(
        $originalImg,
        0,
        0,
        $originalImg.Width,
        $originalImg.Height
    )

    # Then paste the emblem directly on top at the same coordinates.
    $compositeGraphics.DrawImage(
        $emblemImg,
        0,
        0,
        $emblemImg.Width,
        $emblemImg.Height
    )

    $compositeGraphics.Dispose()
    $emblemImg.Dispose()
    $originalImg.Dispose()

    $sourceImg = $compositedImg
}


# -----------------------------------------------------------------------
# 3. Load input image and resize to 14x9 using high-quality bicubic
# interpolation.
# -----------------------------------------------------------------------

$resizedImg = New-Object System.Drawing.Bitmap(
    14,
    9,
    [System.Drawing.Imaging.PixelFormat]::Format32bppArgb
)

$graphicsResize =
    [System.Drawing.Graphics]::FromImage($resizedImg)

$graphicsResize.InterpolationMode =
    [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic

$graphicsResize.SmoothingMode =
    [System.Drawing.Drawing2D.SmoothingMode]::HighQuality

$graphicsResize.PixelOffsetMode =
    [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality

$graphicsResize.CompositingQuality =
    [System.Drawing.Drawing2D.CompositingQuality]::HighQuality

$graphicsResize.DrawImage(
    $sourceImg,
    0,
    0,
    14,
    9
)

$graphicsResize.Dispose()
$sourceImg.Dispose()


# -----------------------------------------------------------------------
# 4. Create a temporary canvas (16x14) to apply the border and padding.
#
# Target dimensions:
#   14 width + 2 (left/right borders) = 16
#
# Height:
#   9 content + 2 (top/bottom borders)
#   + 1 row above + 2 rows below = 14
# -----------------------------------------------------------------------

$paddedCanvas = New-Object System.Drawing.Bitmap(
    16,
    14,
    [System.Drawing.Imaging.PixelFormat]::Format32bppArgb
)

$canvasGraphics =
    [System.Drawing.Graphics]::FromImage($paddedCanvas)

$greenColor =
    [System.Drawing.Color]::FromArgb(0, 255, 0)

$canvasGraphics.Clear($greenColor)

# Offset inside the 16x14 canvas
$contentOffsetX = 1
$contentOffsetY = 2

# Draw the resized image onto the canvas center area first
$canvasGraphics.DrawImage(
    $resizedImg,
    $contentOffsetX,
    $contentOffsetY,
    14,
    9
)


# -----------------------------------------------------------------------
# 5. Apply a 1-pixel wide black border targeting filled parts and
# semi-transparent edges.
# -----------------------------------------------------------------------

for ($y = 0; $y -lt 9; $y++) {
    for ($x = 0; $x -lt 14; $x++) {

        $pixel = $resizedImg.GetPixel($x, $y)

        # Consider a pixel part of the shape if it has visible opacity
        if ($pixel.A -gt 0) {

            # Check all 8 directions
            # (Orthogonal + Diagonals to capture corners)
            $neighbors = @(
                @{X = $x;     Y = $y - 1}, # Up
                @{X = $x;     Y = $y + 1}, # Down
                @{X = $x - 1; Y = $y},     # Left
                @{X = $x + 1; Y = $y},     # Right
                @{X = $x - 1; Y = $y - 1}, # Top-Left Corner
                @{X = $x + 1; Y = $y - 1}, # Top-Right Corner
                @{X = $x - 1; Y = $y + 1}, # Bottom-Left Corner
                @{X = $x + 1; Y = $y + 1}  # Bottom-Right Corner
            )

            foreach ($n in $neighbors) {

                $isOutside =
                    ($n.X -lt 0 -or
                     $n.X -ge 14 -or
                     $n.Y -lt 0 -or
                     $n.Y -ge 9)

                $isCandidateBackground = $false

                if (-not $isOutside) {

                    $neighborPixel =
                        $resizedImg.GetPixel($n.X, $n.Y)

                    # Target semi-transparent or transparent pixels
                    # created by bicubic scaling
                    if ($neighborPixel.A -lt 128) {
                        $isCandidateBackground = $true
                    }
                }

                if ($isOutside -or $isCandidateBackground) {

                    $targetCanvasX =
                        $contentOffsetX + $n.X

                    $targetCanvasY =
                        $contentOffsetY + $n.Y

                    # Ensure we don't overwrite areas outside
                    # the canvas bounds
                    if ($targetCanvasX -ge 0 -and
                        $targetCanvasX -lt 16 -and
                        $targetCanvasY -ge 0 -and
                        $targetCanvasY -lt 14) {

                        $currentCanvasPixel =
                            $paddedCanvas.GetPixel(
                                $targetCanvasX,
                                $targetCanvasY
                            )

                        # Blend black border onto existing
                        # semi-transparent or green background pixels
                        if (-not (
                            $currentCanvasPixel.R -eq 0 -and
                            $currentCanvasPixel.G -eq 255 -and
                            $currentCanvasPixel.B -eq 0
                        )) {

                            # Blend with existing anti-aliased fringe
                            # alpha channel
                            $blendAlpha =
                                [Math]::Max(
                                    $currentCanvasPixel.A,
                                    180
                                )

                            $paddedCanvas.SetPixel(
                                $targetCanvasX,
                                $targetCanvasY,
                                [System.Drawing.Color]::FromArgb(
                                    $blendAlpha,
                                    0,
                                    0,
                                    0
                                )
                            )
                        }
                        else {

                            # Fully transparent spot beside content
                            # becomes a clean crisp black border pixel
                            $paddedCanvas.SetPixel(
                                $targetCanvasX,
                                $targetCanvasY,
                                [System.Drawing.Color]::FromArgb(
                                    255,
                                    0,
                                    0,
                                    0
                                )
                            )
                        }
                    }
                }
            }
        }
    }
}


# -----------------------------------------------------------------------
# 6. Save final 16x14 image as 24bppRgb BMP.
# -----------------------------------------------------------------------

$rect = New-Object System.Drawing.Rectangle(
    0,
    0,
    $paddedCanvas.Width,
    $paddedCanvas.Height
)

$final24bit = $paddedCanvas.Clone(
    $rect,
    [System.Drawing.Imaging.PixelFormat]::Format24bppRgb
)

$final24bit.Save(
    $OutputPath,
    [System.Drawing.Imaging.ImageFormat]::Bmp
)

$final24bit.Dispose()
$paddedCanvas.Dispose()

# Cleanup iteration resources
$canvasGraphics.Dispose()
$resizedImg.Dispose()

}