Add-Type -AssemblyName System.Drawing

$counterDir = Join-Path $PSScriptRoot "output\gfx\palette"
$inputDir   = Join-Path $PSScriptRoot "input"
$airDir     = Join-Path $PSScriptRoot "airforce"

function New-24BitBitmap {
    param(
        [int]$Width,
        [int]$Height
    )

    New-Object System.Drawing.Bitmap(
        $Width,
        $Height,
        [System.Drawing.Imaging.PixelFormat]::Format24bppRgb
    )
}

function Draw-BicubicImage {
    param(
        [System.Drawing.Graphics]$Graphics,
        [System.Drawing.Image]$Image,
        [System.Drawing.Rectangle]$Destination
    )

    $Graphics.InterpolationMode =
        [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic

    $Graphics.PixelOffsetMode =
        [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality

    $Graphics.SmoothingMode =
        [System.Drawing.Drawing2D.SmoothingMode]::HighQuality

    $Graphics.DrawImage(
        $Image,
        $Destination,
        0,
        0,
        $Image.Width,
        $Image.Height,
        [System.Drawing.GraphicsUnit]::Pixel
    )
}

# Create the 14x9 flag, then put a 1px black border OUTSIDE it.
function New-FlagWithBorder {
    param(
        [System.Drawing.Image]$FlagImage
    )

    # First resize the actual flag to exactly 14x9.
    $flag14x9 = New-24BitBitmap -Width 14 -Height 9

    try {
        $g = [System.Drawing.Graphics]::FromImage($flag14x9)

        try {
            # Transparent areas become #edbeed.
            $g.Clear([System.Drawing.Color]::FromArgb(237, 190, 237))

            Draw-BicubicImage `
                -Graphics $g `
                -Image $FlagImage `
                -Destination (New-Object System.Drawing.Rectangle(0, 0, 14, 9))
        }
        finally {
            $g.Dispose()
        }

        # Finished object is 16x11:
        #
        # BBBBBBBBBBBBBBBB
        # BFFFFFFFFFFFFFFB
        # BFFFFFFFFFFFFFFB
        # BFFFFFFFFFFFFFFB
        # BFFFFFFFFFFFFFFB
        # BFFFFFFFFFFFFFFB
        # BFFFFFFFFFFFFFFB
        # BFFFFFFFFFFFFFFB
        # BFFFFFFFFFFFFFFB
        # BFFFFFFFFFFFFFFB
        # BBBBBBBBBBBBBBBB
        #
        # B = black border
        # F = 14x9 flag

        $result = New-24BitBitmap -Width 16 -Height 11

        $g = [System.Drawing.Graphics]::FromImage($result)

        try {
            # Entire area starts black, giving us the 1px border.
            $g.Clear([System.Drawing.Color]::Black)

            # Put the 14x9 flag inside the border.
            $g.InterpolationMode =
                [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor

            $g.PixelOffsetMode =
                [System.Drawing.Drawing2D.PixelOffsetMode]::Default

            $g.DrawImage(
                $flag14x9,
                1,
                1,
                14,
                9
            )
        }
        finally {
            $g.Dispose()
            $flag14x9.Dispose()
        }

        return $result
    }
    catch {
        if ($flag14x9) {
            $flag14x9.Dispose()
        }

        throw
    }
}

Get-ChildItem -LiteralPath $counterDir -Filter "counter_*.bmp" -File | ForEach-Object {

    $counterPath = $_.FullName
    $something = $_.BaseName.Substring("counter_".Length)

    $flagPath    = Join-Path $inputDir "$something.bmp"
    $emblemsPath = Join-Path $inputDir "${something}_emblems.bmp"
    $airPath     = Join-Path $airDir "$something.bmp"

    if (-not (Test-Path -LiteralPath $flagPath)) {
        return
    }

    $flag = $null
    $flagComposite = $null
    $flagWithBorder = $null
    $originalCounter = $null
    $counter = $null

    try {
        # ------------------------------------------------------------
        # Load and compose the flag + optional emblems
        # ------------------------------------------------------------

        $flag = [System.Drawing.Image]::FromFile($flagPath)

        # Use the flag's dimensions for the composition canvas.
        $flagComposite = New-24BitBitmap `
            -Width $flag.Width `
            -Height $flag.Height

        $g = [System.Drawing.Graphics]::FromImage($flagComposite)

        try {
            # Transparent areas become #edbeed.
            $g.Clear([System.Drawing.Color]::FromArgb(237, 190, 237))

            Draw-BicubicImage `
                -Graphics $g `
                -Image $flag `
                -Destination (New-Object System.Drawing.Rectangle(
                    0,
                    0,
                    $flag.Width,
                    $flag.Height
                ))

            if (Test-Path -LiteralPath $emblemsPath) {
                $emblems = [System.Drawing.Image]::FromFile($emblemsPath)

                try {
                    Draw-BicubicImage `
                        -Graphics $g `
                        -Image $emblems `
                        -Destination (New-Object System.Drawing.Rectangle(
                            0,
                            0,
                            $flag.Width,
                            $flag.Height
                        ))
                }
                finally {
                    $emblems.Dispose()
                }
            }
        }
        finally {
            $g.Dispose()
            $flag.Dispose()
            $flag = $null
        }

        # ------------------------------------------------------------
        # Make 16x11 object:
        # 14x9 flag + 1px black border on all sides
        # ------------------------------------------------------------

        $flagWithBorder = New-FlagWithBorder -FlagImage $flagComposite

        $flagComposite.Dispose()
        $flagComposite = $null

        # ------------------------------------------------------------
        # Load counter as a 24-bit bitmap
        # ------------------------------------------------------------

        $originalCounter = [System.Drawing.Image]::FromFile($counterPath)

        $counter = New-24BitBitmap `
            -Width $originalCounter.Width `
            -Height $originalCounter.Height

        $g = [System.Drawing.Graphics]::FromImage($counter)

        try {
            # Copy original counter.
            $g.InterpolationMode =
                [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor

            $g.PixelOffsetMode =
                [System.Drawing.Drawing2D.PixelOffsetMode]::Default

            $g.DrawImage(
                $originalCounter,
                0,
                0,
                $originalCounter.Width,
                $originalCounter.Height
            )

            # --------------------------------------------------------
            # First flag:
            #
            # Border starts at (2,19)
            # 14x9 flag itself starts at (3,20)
            # --------------------------------------------------------

            $g.DrawImage(
                $flagWithBorder,
                3,
                20,
                16,
                11
            )

            # --------------------------------------------------------
            # Second item
            # --------------------------------------------------------

            if (-not (Test-Path -LiteralPath $airPath)) {

                # No air emblem:
                # border starts at (34,19)
                # flag itself starts at (35,20)

                $g.DrawImage(
                    $flagWithBorder,
                    35,
                    20,
                    16,
                    11
                )
            }
            else {

                # ----------------------------------------------------
                # Load air emblem
                # ----------------------------------------------------

                $airEmblem = [System.Drawing.Image]::FromFile($airPath)

                try {
                    $newHeight = 10

                    $newWidth = [int][Math]::Round(
                        $airEmblem.Width *
                        ($newHeight / [double]$airEmblem.Height)
                    )

                    if ($newWidth -lt 1) {
                        $newWidth = 1
                    }

                    $airResized = New-Object System.Drawing.Bitmap(
						$newWidth,
						$newHeight,
						[System.Drawing.Imaging.PixelFormat]::Format32bppArgb
					)

                    try {
                        $airG = [System.Drawing.Graphics]::FromImage($airResized)

                        try {
                            # Transparent areas become #edbeed.
							$airG.Clear([System.Drawing.Color]::Transparent)

                            Draw-BicubicImage `
                                -Graphics $airG `
                                -Image $airEmblem `
                                -Destination (New-Object System.Drawing.Rectangle(
                                    0,
                                    0,
                                    $newWidth,
                                    $newHeight
                                ))
                        }
                        finally {
                            $airG.Dispose()
                        }

                        # Air emblem starts at (35,21).
                        $g.DrawImage(
                            $airResized,
                            35,
                            21,
                            $newWidth,
                            10
                        )
                    }
                    finally {
                        $airResized.Dispose()
                    }
                }
                finally {
                    $airEmblem.Dispose()
                }
            }
        }
        finally {
            $g.Dispose()
            $originalCounter.Dispose()
            $originalCounter = $null
        }
        # ------------------------------------------------------------
        # Save the completed result as a 24-bit BMP and replace
        # the original. No palette conversion is performed here.
        # ------------------------------------------------------------

        $tempPath = "$counterPath.tmp.bmp"

                try {
            $counter.Save(
                $tempPath,
                [System.Drawing.Imaging.ImageFormat]::Bmp
            )

            $counter.Dispose()
            $counter = $null

            # Convert the 24-bit BMP to an 8-bit indexed-colour BMP
            magick $tempPath -alpha off -colors 256 -dither None -compress None BMP3:$tempPath

            Move-Item `
                -LiteralPath $tempPath `
                -Destination $counterPath `
                -Force
        }
        finally {
            if (Test-Path -LiteralPath $tempPath) {
                Remove-Item -LiteralPath $tempPath -Force
            }

            if ($counter) {
                $counter.Dispose()
                $counter = $null
            }

            if ($flagComposite) {
                $flagComposite.Dispose()
                $flagComposite = $null
            }

            if ($flagWithBorder) {
                $flagWithBorder.Dispose()
                $flagWithBorder = $null
            }

            if ($originalCounter) {
                $originalCounter.Dispose()
                $originalCounter = $null
            }
        }
    }
    finally {
        
    }
}