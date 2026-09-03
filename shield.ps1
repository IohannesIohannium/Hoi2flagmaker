# Ensure input and output directories exist
$inputDir = ".\input"
$outputDir = ".\output\shields"
$shadowPath = ".\shield_shadow.bmp"

if (-not (Test-Path $outputDir)) {
    New-Item -ItemType Directory -Force -Path $outputDir | Out-Null
}

# Load required .NET drawing assemblies
Add-Type -AssemblyName System.Drawing

# Check if shadow mask exists
if (-not (Test-Path $shadowPath)) {
    Write-Error "Shadow mask 'shield_shadow.bmp' not found in the root directory."
    exit
}

$shadowImg = [System.Drawing.Bitmap]::FromFile($shadowPath)

#---------------------------------------------------------------------------
# Helper: resize an image to the specified dimensions
#---------------------------------------------------------------------------
function Resize-Bitmap {
    param (
        [System.Drawing.Bitmap]$Source,
        [int]$Width,
        [int]$Height
    )

    $result = New-Object System.Drawing.Bitmap(
        $Width,
        $Height,
        [System.Drawing.Imaging.PixelFormat]::Format32bppArgb
    )

    $graphics =
        [System.Drawing.Graphics]::FromImage($result)

    $graphics.CompositingMode =
        [System.Drawing.Drawing2D.CompositingMode]::SourceCopy

    $graphics.InterpolationMode =
        [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic

    $graphics.SmoothingMode =
        [System.Drawing.Drawing2D.SmoothingMode]::HighQuality

    $graphics.PixelOffsetMode =
        [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality

    $graphics.CompositingQuality =
        [System.Drawing.Drawing2D.CompositingQuality]::HighQuality

    $graphics.DrawImage(
        $Source,
        0,
        0,
        $Width,
        $Height
    )

    $graphics.Dispose()

    return $result
}

#---------------------------------------------------------------------------
# Helper: find connected non-transparent blobs in an image.
#
# Returns an array of objects, each containing:
# Pixels  - the pixels belonging to the blob
# CenterX - center of the blob
# CenterY - center of the blob
#
# 8-way connectivity is used, so diagonally touching pixels belong together.
#---------------------------------------------------------------------------
function Find-EmblemBlobs {
    param (
        [System.Drawing.Bitmap]$Image
    )

    $width = $Image.Width
    $height = $Image.Height

    $visited = New-Object 'bool[]' ($width * $height)

    $blobs = New-Object System.Collections.ArrayList

    for ($startY = 0; $startY -lt $height; $startY++) {
        for ($startX = 0; $startX -lt $width; $startX++) {

            $startIndex = $startY * $width + $startX

            if ($visited[$startIndex]) {
                continue
            }

            $startPixel = $Image.GetPixel($startX, $startY)

            if ($startPixel.A -eq 0) {
                $visited[$startIndex] = $true
                continue
            }

            $queue = New-Object System.Collections.Queue
            $pixels = New-Object System.Collections.ArrayList

            $queue.Enqueue(@($startX, $startY))
            $visited[$startIndex] = $true

            $sumX = 0.0
            $sumY = 0.0

            while ($queue.Count -gt 0) {

                $point = $queue.Dequeue()

                $x = $point[0]
                $y = $point[1]

                [void]$pixels.Add(@($x, $y))

                $sumX += $x
                $sumY += $y

                for ($dy = -1; $dy -le 1; $dy++) {
                    for ($dx = -1; $dx -le 1; $dx++) {

                        if ($dx -eq 0 -and $dy -eq 0) {
                            continue
                        }

                        $nx = $x + $dx
                        $ny = $y + $dy

                        if ($nx -lt 0 -or $nx -ge $width -or
                            $ny -lt 0 -or $ny -ge $height) {
                            continue
                        }

                        $index = $ny * $width + $nx

                        if ($visited[$index]) {
                            continue
                        }

                        $pixel = $Image.GetPixel($nx, $ny)

                        if ($pixel.A -gt 0) {
                            $visited[$index] = $true
                            $queue.Enqueue(@($nx, $ny))
                        }
                        else {
                            $visited[$index] = $true
                        }
                    }
                }
            }

            if ($pixels.Count -gt 0) {

                $blob = [PSCustomObject]@{
                    Pixels  = $pixels
                    CenterX = $sumX / $pixels.Count
                    CenterY = $sumY / $pixels.Count
                }

                [void]$blobs.Add($blob)
            }
        }
    }

    return @($blobs.ToArray())
}

#---------------------------------------------------------------------------
# Helper: create the upright emblem layer.
#
# Source:
#   70 x 44
#
# Working layer:
#   70 x 70
#
# Process:
#   1. Find all blobs in the 70x44 source.
#   2. For every blob, change its centre from (x,y) to (y,x).
#   3. Keep the actual pixels of each blob upright.
#   4. Only AFTER all blobs have been moved, crop the result to 44x70.
#
# Transparent pixels use the alpha channel.
#---------------------------------------------------------------------------
function Create-UprightEmblemLayer {
    param (
        [System.Drawing.Bitmap]$EmblemSource
    )

    $sourceWidth = $EmblemSource.Width
    $sourceHeight = $EmblemSource.Height

    # Full working canvas.
    $workingWidth = 70
    $workingHeight = 70

    # Final cropped dimensions.
    $finalWidth = 44
    $finalHeight = 70

    # -----------------------------------------------------------------------
    # Create the full 70x70 working layer with an alpha channel.
    # -----------------------------------------------------------------------

    $workingLayer = New-Object System.Drawing.Bitmap(
        $workingWidth,
        $workingHeight,
        [System.Drawing.Imaging.PixelFormat]::Format32bppArgb
    )

    $transparentColor =
        [System.Drawing.Color]::FromArgb(0, 0, 0, 0)

    for ($y = 0; $y -lt $workingHeight; $y++) {
        for ($x = 0; $x -lt $workingWidth; $x++) {

            $workingLayer.SetPixel(
                $x,
                $y,
                $transparentColor
            )
        }
    }

    # -----------------------------------------------------------------------
    # Find all emblem blobs.
    # -----------------------------------------------------------------------

    $blobs = Find-EmblemBlobs -Image $EmblemSource

    # -----------------------------------------------------------------------
    # Move EVERY blob on the full 70x70 working layer.
    #
    # Blob centre:
    #     (CenterX, CenterY)
    #
    # New centre:
    #     (CenterY, CenterX)
    #
    # The blob itself is not rotated.
    #
    # The new centre is kept as a FLOAT. No rounding is performed.
    # -----------------------------------------------------------------------

    foreach ($blob in $blobs) {

        # Find the bounding box of this blob.
        $minX = $blob.Pixels[0][0]
        $maxX = $blob.Pixels[0][0]
        $minY = $blob.Pixels[0][1]
        $maxY = $blob.Pixels[0][1]

        foreach ($point in $blob.Pixels) {

            $sourceX = $point[0]
            $sourceY = $point[1]

            if ($sourceX -lt $minX) {
                $minX = $sourceX
            }

            if ($sourceX -gt $maxX) {
                $maxX = $sourceX
            }

            if ($sourceY -lt $minY) {
                $minY = $sourceY
            }

            if ($sourceY -gt $maxY) {
                $maxY = $sourceY
            }
        }

        $blobWidth = $maxX - $minX + 1
        $blobHeight = $maxY - $minY + 1
		
		if ($blobWidth -eq 71) { # Can't get the thing to work...
			$scale = 40.0 / $blobWidth

			$scaledWidth = 40
			$scaledHeight = [int][Math]::Round(
				$blobHeight * $scale
			)
		}
		else {
			$scale = 1.0

			$scaledWidth = $blobWidth
			$scaledHeight = $blobHeight
		}

        # ---------------------------------------------------------------
		# Create a bitmap containing the original blob.
		# ---------------------------------------------------------------

		$originalBlobBitmap = New-Object System.Drawing.Bitmap(
			$blobWidth,
			$blobHeight,
			[System.Drawing.Imaging.PixelFormat]::Format32bppArgb
		)

		for ($y = 0; $y -lt $blobHeight; $y++) {
			for ($x = 0; $x -lt $blobWidth; $x++) {

				$originalBlobBitmap.SetPixel(
					$x,
					$y,
					$transparentColor
				)
			}
		}

		# Copy the blob's original pixels into the bitmap.
		foreach ($point in $blob.Pixels) {

			$sourceX = $point[0]
			$sourceY = $point[1]

			$pixel =
				$EmblemSource.GetPixel(
					$sourceX,
					$sourceY
				)

			$targetX = $sourceX - $minX
			$targetY = $sourceY - $minY

			$originalBlobBitmap.SetPixel(
				$targetX,
				$targetY,
				[System.Drawing.Color]::FromArgb(
					$pixel.A,
					$pixel.R,
					$pixel.G,
					$pixel.B
				)
			)
		}

		# ---------------------------------------------------------------
		# Bicubic resize the blob if required.
		# ---------------------------------------------------------------

		if ($blobWidth -eq 71) {

			$scaledWidth = 40
			$scaledHeight = [int][Math]::Round(
				$blobHeight * (40.0 / $blobWidth)
			)

			$blobBitmap = New-Object System.Drawing.Bitmap(
				$scaledWidth,
				$scaledHeight,
				[System.Drawing.Imaging.PixelFormat]::Format32bppArgb
			)

			$resizeGraphics =
				[System.Drawing.Graphics]::FromImage($blobBitmap)

			$resizeGraphics.CompositingMode =
				[System.Drawing.Drawing2D.CompositingMode]::SourceCopy

			$resizeGraphics.InterpolationMode =
				[System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic

			$resizeGraphics.SmoothingMode =
				[System.Drawing.Drawing2D.SmoothingMode]::HighQuality

			$resizeGraphics.PixelOffsetMode =
				[System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality

			$resizeGraphics.CompositingQuality =
				[System.Drawing.Drawing2D.CompositingQuality]::HighQuality

			$resizeGraphics.DrawImage(
				$originalBlobBitmap,
				0,
				0,
				$scaledWidth,
				$scaledHeight
			)

			$resizeGraphics.Dispose()
			$originalBlobBitmap.Dispose()
		}
		else {

			$blobBitmap = $originalBlobBitmap
		}

        # ---------------------------------------------------------------
        # Calculate the destination position using FLOAT coordinates.
        #
        # Original blob centre:
        #     (CenterX, CenterY)
        #
        # New blob centre:
        #     (CenterY, CenterX)
        #
        # No Round() and no [int].
        # ---------------------------------------------------------------

        [float]$destinationX =
            [float]$blob.CenterY -
            ([float]$blob.CenterX - [float]$minX)

        [float]$destinationY =
            [float]$blob.CenterX -
            ([float]$blob.CenterY - [float]$minY)

        # ---------------------------------------------------------------
        # Draw the blob using its fractional destination position.
        # ---------------------------------------------------------------

        $blobGraphics =
            [System.Drawing.Graphics]::FromImage($workingLayer)

        $blobGraphics.CompositingMode =
            [System.Drawing.Drawing2D.CompositingMode]::SourceOver

        $blobGraphics.InterpolationMode =
            [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic

        $blobGraphics.PixelOffsetMode =
            [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality

        $blobGraphics.DrawImage(
            $blobBitmap,
            $destinationX,
            $destinationY
        )

        $blobGraphics.Dispose()
        $blobBitmap.Dispose()
    }

    # -----------------------------------------------------------------------
    # NOW crop the completed 70x70 layer to 44x70.
    # -----------------------------------------------------------------------

    $cropRectangle =
        New-Object System.Drawing.Rectangle(
            0,
            0,
            $finalWidth,
            $finalHeight
        )

    $result =
        $workingLayer.Clone(
            $cropRectangle,
            [System.Drawing.Imaging.PixelFormat]::Format32bppArgb
        )

    $workingLayer.Dispose()

    return $result
}

#---------------------------------------------------------------------------
# Process each BMP file in the input directory.
# Files containing "_emblems" in their name are deliberately skipped.
#---------------------------------------------------------------------------
Get-ChildItem -Path $inputDir -Filter "*.bmp" |
Where-Object { $_.BaseName -notlike "*_emblems" -and
    $_.BaseName -notlike "*_vertical" } |
ForEach-Object {

    $filePath = $_.FullName
    $fileName = $_.Name
    $baseName = $_.BaseName

    $outputFilePath =
        Join-Path $outputDir "shield_$fileName"

    # Temporary upright emblem bitmap.
    $tempEmblemPath =
        Join-Path $outputDir "temp_$fileName"

    try {

        # -------------------------------------------------------------------
        # 1. Load and resize the normal flag.
        # -------------------------------------------------------------------

        $originalImg =
            [System.Drawing.Bitmap]::FromFile($filePath)

        $resizedImg =
            Resize-Bitmap `
                -Source $originalImg `
                -Width 70 `
                -Height 44

        $originalImg.Dispose()

        # -------------------------------------------------------------------
		# 2. Find corresponding emblem/vertical bitmap.
		#
		# Priority:
		#   1. xxx_emblems.bmp
		#      -> transform with Create-UprightEmblemLayer
		#
		#   2. xxx_vertical.bmp
		#      -> use directly as the complete 44x70 vertical layer
		#
		# _vertical.bmp is NOT composited with the flag.
		# Its transparent pixels will clear the corresponding flag pixels.
		# -------------------------------------------------------------------

		$emblemPath =
			Join-Path $_.DirectoryName ($baseName + "_emblems.bmp")

		$verticalPath =
			Join-Path $_.DirectoryName ($baseName + "_vertical.bmp")

		$emblemLayer = $null
		$verticalEmblem = $false

		if (Test-Path $emblemPath) {

			# ---------------------------------------------------------------
			# Horizontal emblem source.
			# ---------------------------------------------------------------

			$emblemSourceOriginal =
				[System.Drawing.Bitmap]::FromFile($emblemPath)

			$emblemSource =
				Resize-Bitmap `
					-Source $emblemSourceOriginal `
					-Width 70 `
					-Height 44

			$emblemSourceOriginal.Dispose()

			$emblemLayer =
				Create-UprightEmblemLayer `
					-EmblemSource $emblemSource

			$emblemSource.Dispose()
		}
		elseif (Test-Path $verticalPath) {

			# ---------------------------------------------------------------
			# Already-vertical source.
			#
			# This is the COMPLETE 44x70 emblem layer.
			# Transparent pixels remain transparent.
			# ---------------------------------------------------------------

			$verticalSource =
				[System.Drawing.Bitmap]::FromFile($verticalPath)

			$emblemLayer =
				Resize-Bitmap `
					-Source $verticalSource `
					-Width 44 `
					-Height 70

			$verticalSource.Dispose()

			$verticalEmblem = $true
		}

        # -------------------------------------------------------------------
        # 3. Rotate the flag 90 degrees clockwise and mirror it.
        # -------------------------------------------------------------------

        $resizedImg.RotateFlip(
            [System.Drawing.RotateFlipType]::Rotate90FlipX
        )

        # -------------------------------------------------------------------
		# 4. Paste the emblem onto the vertical flag.
		#
		# Normal _emblems.bmp:
		#   Transparent pixels leave the flag untouched.
		#
		# _vertical.bmp:
		#   Transparent pixels CLEAR the flag underneath.
		# -------------------------------------------------------------------

		if ($null -ne $emblemLayer) {

			for ($y = 0; $y -lt $emblemLayer.Height; $y++) {
				for ($x = 0; $x -lt $emblemLayer.Width; $x++) {

					$pixel =
						$emblemLayer.GetPixel($x, $y)

					# Paste one pixel to the left.
					$destinationX = $x
					$destinationY = $y

					if ($destinationX -ge 0 -and
						$destinationX -lt $resizedImg.Width -and
						$destinationY -ge 0 -and
						$destinationY -lt $resizedImg.Height) {

						# ---------------------------------------------------
						# Transparent pixel.
						# ---------------------------------------------------

						if ($pixel.A -eq 0) {

							if ($verticalEmblem) {

								# For _vertical.bmp, transparency means
								# the flag underneath must also be cleared.
								$resizedImg.SetPixel(
									$destinationX,
									$destinationY,
									[System.Drawing.Color]::FromArgb(
										0,
										0,
										0,
										0
									)
								)
							}

							# For normal _emblems.bmp, simply leave the
							# existing flag pixel untouched.
							continue
						}

						$destination =
							$resizedImg.GetPixel(
								$destinationX,
								$destinationY
							)

						# ---------------------------------------------------
						# Fully opaque emblem pixel.
						# ---------------------------------------------------

						if ($pixel.A -eq 255) {

							$resizedImg.SetPixel(
								$destinationX,
								$destinationY,
								[System.Drawing.Color]::FromArgb(
									255,
									$pixel.R,
									$pixel.G,
									$pixel.B
								)
							)
						}
						else {

							# ------------------------------------------------
							# Proper straight-alpha compositing.
							# ------------------------------------------------

							$srcA = $pixel.A / 255.0
							$dstA = $destination.A / 255.0

							$outA =
								$srcA + ($dstA * (1.0 - $srcA))

							if ($outA -gt 0) {

								$outR = (
									($pixel.R * $srcA) +
									($destination.R * $dstA * (1.0 - $srcA))
								) / $outA

								$outG = (
									($pixel.G * $srcA) +
									($destination.G * $dstA * (1.0 - $srcA))
								) / $outA

								$outB = (
									($pixel.B * $srcA) +
									($destination.B * $dstA * (1.0 - $srcA))
								) / $outA

								$resizedImg.SetPixel(
									$destinationX,
									$destinationY,
									[System.Drawing.Color]::FromArgb(
										[int][Math]::Round($outA * 255),
										[int][Math]::Round($outR),
										[int][Math]::Round($outG),
										[int][Math]::Round($outB)
									)
								)
							}
						}
					}
				}
			}

			$emblemLayer.Dispose()
			$emblemLayer = $null
		}

        # -------------------------------------------------------------------
        # 5. Paste four times side-by-side to create a 176x70 image.
        # -------------------------------------------------------------------

        $canvas =
            New-Object System.Drawing.Bitmap 176, 70

        $canvasGraphics =
            [System.Drawing.Graphics]::FromImage($canvas)

        for ($i = 0; $i -lt 4; $i++) {

            $canvasGraphics.DrawImage(
                $resizedImg,
                ($i * 44),
                0,
                44,
                70
            )
        }

        $canvasGraphics.Dispose()
        $resizedImg.Dispose()

        # -------------------------------------------------------------------
        # 6. Overlay shadow mask.
        # -------------------------------------------------------------------

        if ($shadowImg.Width -eq 176 -and
            $shadowImg.Height -eq 70) {

            for ($y = 0; $y -lt 70; $y++) {
                for ($x = 0; $x -lt 176; $x++) {

                    $p = $canvas.GetPixel($x, $y)

                    if ($p.A -gt 0) {

                        $s = $shadowImg.GetPixel($x, $y)

                        if ($s.A -gt 0 -and
                            -not ($s.R -eq 0 -and
                                  $s.G -eq 0 -and
                                  $s.B -eq 0)) {

                            $blended =
                                [System.Drawing.Color]::FromArgb(
                                    255,
                                    [Math]::Min(
                                        255,
                                        [int]$p.R * $s.R / 255
                                    ),
                                    [Math]::Min(
                                        255,
                                        [int]$p.G * $s.G / 255
                                    ),
                                    [Math]::Min(
                                        255,
                                        [int]$p.B * $s.B / 255
                                    )
                                )

                            $canvas.SetPixel(
                                $x,
                                $y,
                                $blended
                            )
                        }
                    }
                }
            }
        }

        # -------------------------------------------------------------------
        # 7. Apply border/contour multiplier tint.
        # -------------------------------------------------------------------

        $borderColors = @(
            [System.Drawing.Color]::FromArgb(127, 127, 127),
            [System.Drawing.Color]::FromArgb(127, 127, 127),
            [System.Drawing.Color]::FromArgb(90, 90, 90),
            [System.Drawing.Color]::FromArgb(49, 49, 49)
        )

        for ($section = 0; $section -lt 4; $section++) {

            $startX = $section * 44
            $endX = $startX + 43
            $tintColor = $borderColors[$section]

            for ($y = 0; $y -lt 70; $y++) {
                for ($x = $startX; $x -le $endX; $x++) {

                    $p = $canvas.GetPixel($x, $y)

                    if ($p.A -gt 0) {

                        $isEdge = $false

                        if ($x -eq $startX -or
                            $x -eq $endX -or
                            $y -eq 0 -or
                            $y -eq 69) {

                            $isEdge = $true
                        }
                        else {

                            if (
                                ($canvas.GetPixel($x - 1, $y).A -eq 0) -or
                                ($canvas.GetPixel($x + 1, $y).A -eq 0) -or
                                ($canvas.GetPixel($x, $y - 1).A -eq 0) -or
                                ($canvas.GetPixel($x, $y + 1).A -eq 0)
                            ) {
                                $isEdge = $true
                            }
                        }

                        if ($isEdge) {

                            $overlayed =
                                [System.Drawing.Color]::FromArgb(
                                    255,
                                    [Math]::Min(
                                        255,
                                        [int]$p.R * $tintColor.R / 255
                                    ),
                                    [Math]::Min(
                                        255,
                                        [int]$p.G * $tintColor.G / 255
                                    ),
                                    [Math]::Min(
                                        255,
                                        [int]$p.B * $tintColor.B / 255
                                    )
                                )

                            $canvas.SetPixel(
                                $x,
                                $y,
                                $overlayed
                            )
                        }
                    }
                }
            }
        }

        # -------------------------------------------------------------------
        # 8. Fill transparent pixels with green.
        # -------------------------------------------------------------------

        $fillColor =
            [System.Drawing.Color]::FromArgb(0, 255, 0)

        for ($y = 0; $y -lt 70; $y++) {
            for ($x = 0; $x -lt 176; $x++) {

                $p = $canvas.GetPixel($x, $y)

                if ($p.A -eq 0) {

                    $canvas.SetPixel(
                        $x,
                        $y,
                        $fillColor
                    )
                }
            }
        }

        # -------------------------------------------------------------------
        # 9. Convert to 24-bit RGB and save.
        # -------------------------------------------------------------------

        $rect =
            New-Object System.Drawing.Rectangle(
                0,
                0,
                $canvas.Width,
                $canvas.Height
            )

        $final24bit =
            $canvas.Clone(
                $rect,
                [System.Drawing.Imaging.PixelFormat]::Format24bppRgb
            )

        $final24bit.Save(
            $outputFilePath,
            [System.Drawing.Imaging.ImageFormat]::Bmp
        )

        $final24bit.Dispose()
        $canvas.Dispose()
    }
    catch {

        if ($null -ne $emblemLayer) {
            $emblemLayer.Dispose()
            $emblemLayer = $null
        }

        if ($null -ne $resizedImg) {
            $resizedImg.Dispose()
            $resizedImg = $null
        }

        if (Test-Path $tempEmblemPath) {
            try {
                Remove-Item `
                    -Force `
                    $tempEmblemPath `
                    -ErrorAction SilentlyContinue
            }
            catch {
                # Ignore cleanup failure.
            }
        }
    }
}

$shadowImg.Dispose()