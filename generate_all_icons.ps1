Add-Type -AssemblyName System.Drawing

function Get-ContentBounds {
    param([System.Drawing.Bitmap]$bitmap)
    
    $width = $bitmap.Width
    $height = $bitmap.Height
    $left = $width
    $top = $height
    $right = 0
    $bottom = 0
    $foundPixel = $false
    
    for ($y = 0; $y -lt $height; $y++) {
        for ($x = 0; $x -lt $width; $x++) {
            $pixel = $bitmap.GetPixel($x, $y)
            # Check if pixel is not fully transparent (alpha > 0)
            if ($pixel.A -gt 0) {
                $foundPixel = $true
                if ($x -lt $left) { $left = $x }
                if ($x -gt $right) { $right = $x }
                if ($y -lt $top) { $top = $y }
                if ($y -gt $bottom) { $bottom = $y }
            }
        }
    }
    
    if (-not $foundPixel) {
        return @{ Left = 0; Top = 0; Width = $width; Height = $height }
    }
    
    return @{ Left = $left; Top = $top; Width = $right - $left + 1; Height = $bottom - $top + 1 }
}

$logoVariants = @(
    @{ Name = "Classic"; SourceDir = "NexoraLogo.imageset"; BaseName = "NexoraLogo"; AppIconSetName = "AppIcon"; Prefix = "" },
    @{ Name = "Classic"; SourceDir = "NexoraLogo.imageset"; BaseName = "NexoraLogo"; AppIconSetName = "AppIcon-Classic"; Prefix = "Classic-" },
    @{ Name = "Gradient"; SourceDir = "NexoraLogoGradient.imageset"; BaseName = "NexoraLogoGradient"; AppIconSetName = "AppIcon-Gradient"; Prefix = "Gradient-" },
    @{ Name = "Minimal"; SourceDir = "NexoraLogoMinimal.imageset"; BaseName = "NexoraLogoMinimal"; AppIconSetName = "AppIcon-Minimal"; Prefix = "Minimal-" },
    @{ Name = "Bold"; SourceDir = "NexoraLogoBold.imageset"; BaseName = "NexoraLogoBold"; AppIconSetName = "AppIcon-Bold"; Prefix = "Bold-" },
    @{ Name = "Mono"; SourceDir = "NexoraLogoMono.imageset"; BaseName = "NexoraLogoMono"; AppIconSetName = "AppIcon-Mono"; Prefix = "Mono-" }
)

$iconSizes = @(
    @{ Size = 20;  Scale = 2; Idiom = "iphone"; FilenameSuffix = "20@2x" },
    @{ Size = 20;  Scale = 3; Idiom = "iphone"; FilenameSuffix = "20@3x" },
    @{ Size = 29;  Scale = 2; Idiom = "iphone"; FilenameSuffix = "29@2x" },
    @{ Size = 29;  Scale = 3; Idiom = "iphone"; FilenameSuffix = "29@3x" },
    @{ Size = 40;  Scale = 2; Idiom = "iphone"; FilenameSuffix = "40@2x" },
    @{ Size = 40;  Scale = 3; Idiom = "iphone"; FilenameSuffix = "40@3x" },
    @{ Size = 60;  Scale = 2; Idiom = "iphone"; FilenameSuffix = "60@2x" },
    @{ Size = 60;  Scale = 3; Idiom = "iphone"; FilenameSuffix = "60@3x" },
    @{ Size = 20;  Scale = 1; Idiom = "ipad"; FilenameSuffix = "20~ipad" },
    @{ Size = 20;  Scale = 2; Idiom = "ipad"; FilenameSuffix = "20~ipad@2x" },
    @{ Size = 29;  Scale = 1; Idiom = "ipad"; FilenameSuffix = "29@1x" },
    @{ Size = 29;  Scale = 2; Idiom = "ipad"; FilenameSuffix = "29@2x" },
    @{ Size = 40;  Scale = 1; Idiom = "ipad"; FilenameSuffix = "40@1x" },
    @{ Size = 40;  Scale = 2; Idiom = "ipad"; FilenameSuffix = "40@2x" },
    @{ Size = 76;  Scale = 1; Idiom = "ipad"; FilenameSuffix = "76@1x" },
    @{ Size = 76;  Scale = 2; Idiom = "ipad"; FilenameSuffix = "76@2x" },
    @{ Size = 83.5; Scale = 2; Idiom = "ipad"; FilenameSuffix = "83.5@2x" },
    @{ Size = 1024; Scale = 1; Idiom = "ios-marketing"; FilenameSuffix = "1024" }
)

$basePath = "C:\Dev\_Mathieu\02_Projets\Perso\Nexora\Nexora\Resources\Assets.xcassets"

foreach ($variant in $logoVariants) {
    $sourceFile = "$basePath\$($variant.SourceDir)\$($variant.BaseName)@3x.png"
    if (-not (Test-Path $sourceFile)) {
        Write-Host "Source not found: $sourceFile"
        continue
    }

    $sourceImg = [System.Drawing.Image]::FromFile($sourceFile)
    
    # Crop to content bounds (remove transparent padding)
    $bounds = Get-ContentBounds -bitmap $sourceImg
    Write-Host "Source $($variant.Name): Content bounds = $($bounds.Width)x$($bounds.Height) at ($($bounds.Left), $($bounds.Top))"
    
    $croppedSource = New-Object System.Drawing.Bitmap($bounds.Width, $bounds.Height)
    $cropGraphics = [System.Drawing.Graphics]::FromImage($croppedSource)
    $cropGraphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $cropGraphics.DrawImage($sourceImg, 
        [System.Drawing.Rectangle]::FromLTRB(0, 0, $bounds.Width, $bounds.Height),
        [System.Drawing.Rectangle]::FromLTRB($bounds.Left, $bounds.Top, $bounds.Left + $bounds.Width, $bounds.Top + $bounds.Height),
        [System.Drawing.GraphicsUnit]::Pixel)
    $cropGraphics.Dispose()

    $targetDir = "$basePath\$($variant.AppIconSetName).appiconset"
    if (-not (Test-Path $targetDir)) {
        New-Item -ItemType Directory -Path $targetDir | Out-Null
    }

    # Generate all icon sizes - OPAQUE (no alpha channel)
    foreach ($iconSize in $iconSizes) {
        $pixelSize = [int]($iconSize.Size * $iconSize.Scale)
        
        # Create bitmap WITHOUT alpha channel (Format24bppRgb = opaque)
        $bitmap = New-Object System.Drawing.Bitmap($pixelSize, $pixelSize, [System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
        $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
        $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
        
        # Fill with white background first (opaque)
        $graphics.Clear([System.Drawing.Color]::White)
        
        # Draw cropped source image centered
        $srcWidth = $croppedSource.Width
        $srcHeight = $croppedSource.Height
        $scale = [Math]::Min($pixelSize / $srcWidth, $pixelSize / $srcHeight)
        $drawWidth = [int]($srcWidth * $scale)
        $drawHeight = [int]($srcHeight * $scale)
        $x = [int](($pixelSize - $drawWidth) / 2)
        $y = [int](($pixelSize - $drawHeight) / 2)
        
        $graphics.DrawImage($croppedSource, $x, $y, $drawWidth, $drawHeight)
        $graphics.Dispose()

        $filename = "AppIcon-$($variant.Prefix)$($iconSize.FilenameSuffix).png"
        $bitmap.Save("$targetDir\$filename", [System.Drawing.Imaging.ImageFormat]::Png)
        $bitmap.Dispose()
        Write-Host "Generated: $targetDir\$filename ($pixelSize x $pixelSize) - OPAQUE"
    }

    $sourceImg.Dispose()
    $croppedSource.Dispose()

    # Generate Contents.json for this appiconset
    $images = @()
    foreach ($iconSize in $iconSizes) {
        $pixelSize = [int]($iconSize.Size * $iconSize.Scale)
        $idiom = $iconSize.Idiom
        $scale = $iconSize.Scale
        $size = "$($iconSize.Size)x$($iconSize.Size)"
        $scaleStr = "${scale}x"
        if ($scale -eq 1) { $scaleStr = "1x" }

        $filename = "AppIcon-$($variant.Prefix)$($iconSize.FilenameSuffix).png"

        $images += @{
            idiom = $idiom
            size = $size
            scale = $scaleStr
            filename = $filename
        }
    }

    $json = @{
        images = $images
        info = @{
            author = "xcode"
            version = 1
        }
    } | ConvertTo-Json -Depth 5

    $json | Set-Content -Path "$targetDir\Contents.json" -Encoding UTF8
    Write-Host "Created Contents.json for $($variant.AppIconSetName)"
}

Write-Host "Done generating all icons (OPAQUE, cropped to content)!"