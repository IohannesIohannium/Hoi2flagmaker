# ============================================================
# Palette BMP Generator
# ============================================================

$InputDir   = Join-Path $PSScriptRoot "input"
$OutputDir  = Join-Path $PSScriptRoot "output\gfx\palette"
$CsvPath    = Join-Path $InputDir "colours.csv"
$CounterBmp = Join-Path $PSScriptRoot "counter.bmp"

# ------------------------------------------------------------
# Helper: RGB -> HSV
# H = 0..360
# S = 0..100
# V = 0..100
# ------------------------------------------------------------
function Convert-RgbToHsv {
    param(
        [int]$R,
        [int]$G,
        [int]$B
    )

    $r = $R / 255.0
    $g = $G / 255.0
    $b = $B / 255.0

    $max = [Math]::Max($r, [Math]::Max($g, $b))
    $min = [Math]::Min($r, [Math]::Min($g, $b))
    $delta = $max - $min

    # Value
    $v = $max

    # Saturation
    if ($max -eq 0) {
        $s = 0
    }
    else {
        $s = $delta / $max
    }

    # Hue
    if ($delta -eq 0) {
        $h = 0
    }
    elseif ($max -eq $r) {
        $h = 60 * ((($g - $b) / $delta) % 6)

        if ($h -lt 0) {
            $h += 360
        }
    }
    elseif ($max -eq $g) {
        $h = 60 * ((($b - $r) / $delta) + 2)
    }
    else {
        $h = 60 * ((($r - $g) / $delta) + 4)
    }

    return @{
        H = $h
        S = $s * 100
        V = $v * 100
    }
}

# ------------------------------------------------------------
# Helper: HSV -> RGB
# H = 0..360
# S = 0..100
# V = 0..100
# ------------------------------------------------------------
function Convert-HsvToRgb {
    param(
        [double]$H,
        [double]$S,
        [double]$V
    )

    $S = [Math]::Max(0, [Math]::Min(100, $S))
    $V = [Math]::Max(0, [Math]::Min(100, $V))

    $s = $S / 100.0
    $v = $V / 100.0

    $c = $v * $s
    $x = $c * (1 - [Math]::Abs((($H / 60.0) % 2) - 1))
    $m = $v - $c

    if ($H -lt 60) {
        $r1 = $c
        $g1 = $x
        $b1 = 0
    }
    elseif ($H -lt 120) {
        $r1 = $x
        $g1 = $c
        $b1 = 0
    }
    elseif ($H -lt 180) {
        $r1 = 0
        $g1 = $c
        $b1 = $x
    }
    elseif ($H -lt 240) {
        $r1 = 0
        $g1 = $x
        $b1 = $c
    }
    elseif ($H -lt 300) {
        $r1 = $x
        $g1 = 0
        $b1 = $c
    }
    else {
        $r1 = $c
        $g1 = 0
        $b1 = $x
    }

    return @{
        R = [int][Math]::Round(($r1 + $m) * 255)
        G = [int][Math]::Round(($g1 + $m) * 255)
        B = [int][Math]::Round(($b1 + $m) * 255)
    }
}

# ------------------------------------------------------------
# Check required files/directories
# ------------------------------------------------------------
if (-not (Test-Path $InputDir)) {
    throw "Input directory not found: $InputDir"
}

if (-not (Test-Path $CsvPath)) {
    throw "Colours CSV not found: $CsvPath"
}

if (-not (Test-Path $CounterBmp)) {
    throw "Counter BMP not found: $CounterBmp"
}

if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}

# ------------------------------------------------------------
# Load colours.csv
#
# Expected format:
# abc;195;176;145
# def;100;120;140
# ------------------------------------------------------------
$Colours = @{}

foreach ($line in Get-Content -LiteralPath $CsvPath) {

    if ([string]::IsNullOrWhiteSpace($line)) {
        continue
    }

    $parts = $line -split ';'

    if ($parts.Count -lt 4) {
        continue
    }

    $name = $parts[0].Trim()

    $r = 0
    $g = 0
    $b = 0

    if (
        -not [int]::TryParse($parts[1].Trim(), [ref]$r) -or
        -not [int]::TryParse($parts[2].Trim(), [ref]$g) -or
        -not [int]::TryParse($parts[3].Trim(), [ref]$b)
    ) {
        continue
    }

    $Colours[$name] = @{
        R = [Math]::Max(0, [Math]::Min(255, $r))
        G = [Math]::Max(0, [Math]::Min(255, $g))
        B = [Math]::Max(0, [Math]::Min(255, $b))
    }
}

# ------------------------------------------------------------
# Load System.Drawing
# ------------------------------------------------------------
Add-Type -AssemblyName System.Drawing

# Load counter.bmp once; every output is based on this image.
$counter = [System.Drawing.Bitmap]::new($CounterBmp)

try {

    # --------------------------------------------------------
    # Find all candidate BMPs
    # --------------------------------------------------------
    $bmpFiles = Get-ChildItem -LiteralPath $InputDir -Filter "*.bmp" -File -Recurse |
        Where-Object {
            $_.Name -notmatch '(?i)_emblems\.bmp$' -and
            $_.Name -notmatch '(?i)_vertical\.bmp$' -and
            $_.FullName -ne $CounterBmp
        }

    foreach ($file in $bmpFiles) {

        $name = $file.BaseName

        # ----------------------------------------------------
        # Find colour for this name
        # ----------------------------------------------------
        if (-not $Colours.ContainsKey($name)) {

			$main = @{
				R = 0x4D
				G = 0x5D
				B = 0x53
			}
		}
		else {
			$main = $Colours[$name]
		}

        $main = $Colours[$name]

        # ----------------------------------------------------
        # Calculate main HSV
        # ----------------------------------------------------
        $hsv = Convert-RgbToHsv `
            -R $main.R `
            -G $main.G `
            -B $main.B

        $H = $hsv.H
        $S = $hsv.S
        $V = $hsv.V

        # ----------------------------------------------------
        # Highlight:
        #
        # S = S / 4
        # V = average(V, 100)
        # ----------------------------------------------------
        $highlightS = $S / 4
        $highlightV = ($V + 100) / 2

        $highlight = Convert-HsvToRgb `
            -H $H `
            -S $highlightS `
            -V $highlightV

        # ----------------------------------------------------
        # Shade:
        #
        # S = S * 1/4
        #
        # "subtract half of what would be needed to get V
        # to 100"
        #
        # Difference to 100 = 100 - V
        # Half of that = (100 - V) / 2
        # Therefore:
        # V = V - ((100 - V) / 2)
        # ----------------------------------------------------
        $shadeS = $S * 2/4
        $shadeV = $V - 30 - ((100 - $V) / 3)
		
		if ($shadeV -le 0) {
			$shade = @{
				R = 255
				G = 255
				B = 255
			}
		}
		else {
			$shade = Convert-HsvToRgb `
				-H $H `
				-S ($S * 5 / 4) `
				-V $shadeV
		}

        # ----------------------------------------------------
        # Create a 24-bit output bitmap
        # ----------------------------------------------------
        $output = [System.Drawing.Bitmap]::new(
            $counter.Width,
            $counter.Height,
            [System.Drawing.Imaging.PixelFormat]::Format24bppRgb
        )

        try {

            # Copy counter.bmp into the 24-bit output bitmap.
            $graphics = [System.Drawing.Graphics]::FromImage($output)

            try {
                $graphics.DrawImageUnscaled($counter, 0, 0)
            }
            finally {
                $graphics.Dispose()
            }

            # ------------------------------------------------
            # Lock the bitmap data for fast pixel processing.
            # ------------------------------------------------
            $rect = [System.Drawing.Rectangle]::new(
                0,
                0,
                $output.Width,
                $output.Height
            )

            $data = $output.LockBits(
                $rect,
                [System.Drawing.Imaging.ImageLockMode]::ReadWrite,
                [System.Drawing.Imaging.PixelFormat]::Format24bppRgb
            )

            try {

                $stride = $data.Stride
                $height = $output.Height
                $width = $output.Width

                # BMP rows can have padding at the end.
                $bufferSize = [Math]::Abs($stride) * $height
                $buffer = New-Object byte[] $bufferSize

                [System.Runtime.InteropServices.Marshal]::Copy(
                    $data.Scan0,
                    $buffer,
                    0,
                    $bufferSize
                )

                for ($y = 0; $y -lt $height; $y++) {

                    # Handle both positive and negative stride.
                    if ($stride -gt 0) {
                        $rowOffset = $y * $stride
                    }
                    else {
                        $rowOffset = ($height - 1 - $y) * (-$stride)
                    }

                    for ($x = 0; $x -lt $width; $x++) {

                        # 24-bit BMP is BGR, not RGB.
                        $offset = $rowOffset + ($x * 3)

                        $b = $buffer[$offset]
                        $g = $buffer[$offset + 1]
                        $r = $buffer[$offset + 2]

                        # ------------------------------------
                        # #FF0000 -> main colour
                        # ------------------------------------
                        if ($r -eq 255 -and $g -eq 0 -and $b -eq 0) {

                            $buffer[$offset]     = [byte]$main.B
                            $buffer[$offset + 1] = [byte]$main.G
                            $buffer[$offset + 2] = [byte]$main.R
                        }

                        # ------------------------------------
                        # #00FF00 -> highlight
                        # ------------------------------------
                        elseif ($r -eq 0 -and $g -eq 255 -and $b -eq 0) {

                            $buffer[$offset]     = [byte]$highlight.B
                            $buffer[$offset + 1] = [byte]$highlight.G
                            $buffer[$offset + 2] = [byte]$highlight.R
                        }

                        # ------------------------------------
                        # #0000FF -> shade
                        # ------------------------------------
                        elseif ($r -eq 0 -and $g -eq 0 -and $b -eq 255) {

                            $buffer[$offset]     = [byte]$shade.B
                            $buffer[$offset + 1] = [byte]$shade.G
                            $buffer[$offset + 2] = [byte]$shade.R
                        }
                    }
                }

                [System.Runtime.InteropServices.Marshal]::Copy(
                    $buffer,
                    0,
                    $data.Scan0,
                    $bufferSize
                )
            }
            finally {
                $output.UnlockBits($data)
            }

            # ------------------------------------------------
            # Save as a genuine 24-bit BMP.
            # ------------------------------------------------
            $outputPath = Join-Path $OutputDir "counter_$name.bmp"

            $output.Save(
                $outputPath,
                [System.Drawing.Imaging.ImageFormat]::Bmp
            )
        }
        finally {
            $output.Dispose()
        }
    }
}

finally {
    $counter.Dispose()
}

