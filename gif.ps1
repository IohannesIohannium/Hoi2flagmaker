# Requires ImageMagick:
#   https://imagemagick.org/
#
# Input:
#   /output/flags/flag_abc.bmp
#
# Output:
#   /output/abc.gif
#
# Each sprite is 28 pixels wide.
# #00ff00 becomes actual transparency.
# Each frame lasts 100 ms.

$InputDir = "./output/flags"
$OutputDir = "./output"

$SpriteWidth = 28
$Delay = 10                  # 10/100 sec = 100 ms
$TransparentColor = "#00ff00"

# ------------------------------------------------------------
# Find ImageMagick
# ------------------------------------------------------------

$Magick = Get-Command magick -ErrorAction SilentlyContinue

if (-not $Magick) {
    $PossiblePaths = @(
        "C:\Program Files\ImageMagick-*\magick.exe",
        "C:\Program Files\ImageMagick*\magick.exe",
        "C:\Program Files (x86)\ImageMagick-*\magick.exe",
        "C:\Program Files (x86)\ImageMagick*\magick.exe"
    )

    foreach ($Pattern in $PossiblePaths) {
        $Found = Get-ChildItem -Path $Pattern -File -ErrorAction SilentlyContinue |
                 Select-Object -First 1

        if ($Found) {
            $Magick = $Found
            break
        }
    }
}

if (-not $Magick) {
    Write-Error "ImageMagick could not be found."
    exit 1
}

# ------------------------------------------------------------
# Make sure output directory exists
# ------------------------------------------------------------

if (-not (Test-Path -LiteralPath $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}

$Files = Get-ChildItem -LiteralPath $InputDir -Filter "flag_*.bmp" -File

if ($Files.Count -eq 0) {
    Write-Warning "No flag_*.bmp files found in $InputDir"
    exit 0
}

# ------------------------------------------------------------
# Process every flag
# ------------------------------------------------------------

foreach ($File in $Files) {


    # Read image dimensions
    $Geometry = & $Magick.Source identify -format "%w %h" -- $File.FullName

    if ($LASTEXITCODE -ne 0) {
        continue
    }

    $Parts = $Geometry -split "\s+"
    $Width = [int]$Parts[0]
    $Height = [int]$Parts[1]

    if ($Width -lt $SpriteWidth) {
        continue
    }

    if (($Width % $SpriteWidth) -ne 0) {
    }

    $FrameCount = [math]::Floor($Width / $SpriteWidth)

    # flag_abc.bmp -> abc.gif
    $OutputName = $File.BaseName -replace '^flag_', ''
    $OutputFile = Join-Path $OutputDir ($OutputName + ".gif")

    # Temporary directory
    $TempDir = Join-Path $env:TEMP ("flag_gif_" + [guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Path $TempDir | Out-Null

    try {

        $FrameFiles = @()

        # --------------------------------------------------------
        # Create individual frames
        # --------------------------------------------------------

        for ($i = 0; $i -lt $FrameCount; $i++) {

            $X = $i * $SpriteWidth
            $FrameFile = Join-Path $TempDir ("frame_{0:D5}.png" -f $i)

            # IMPORTANT:
            # The input image comes FIRST.
            #
            # -crop extracts the 28px sprite.
            # +repage removes the original canvas offset.
            # -transparent #00ff00 converts the green pixels
            # into actual transparency.
            & $Magick.Source `
                $File.FullName `
                -crop "${SpriteWidth}x${Height}+${X}+0" `
                +repage `
                -transparent $TransparentColor `
                $FrameFile

            if ($LASTEXITCODE -ne 0) {
                throw "Failed to create frame $($i + 1)."
            }

            $FrameFiles += $FrameFile
        }

        # --------------------------------------------------------
        # Assemble frames into GIF
        # --------------------------------------------------------

        & $Magick.Source `
            -delay $Delay `
            -loop 0 `
            -dispose Background `
            $FrameFiles `
            $OutputFile

        if ($LASTEXITCODE -ne 0) {
            throw "Failed to create GIF."
        }
    }
    catch {
        Write-Warning $_
    }
    finally {
        if (Test-Path -LiteralPath $TempDir) {
            Remove-Item -LiteralPath $TempDir -Recurse -Force
        }
    }
}