Add-Type -AssemblyName System.Drawing

$logoVariants = @(
    @{ Name = "Classic"; SourceDir = "NexoraLogo.imageset"; BaseName = "NexoraLogo" },
    @{ Name = "Gradient"; SourceDir = "NexoraLogoGradient.imageset"; BaseName = "NexoraLogoGradient" },
    @{ Name = "Minimal"; SourceDir = "NexoraLogoMinimal.imageset"; BaseName = "NexoraLogoMinimal" },
    @{ Name = "Bold"; SourceDir = "NexoraLogoBold.imageset"; BaseName = "NexoraLogoBold" },
    @{ Name = "Mono"; SourceDir = "NexoraLogoMono.imageset"; BaseName = "NexoraLogoMono" }
)

$iconSizes = @(
    @{ Size = 20;  Scale = 1; Idiom = "ipad";   FilenameSuffix = "20~ipad" },
    @{ Size = 20;  Scale = 2; Idiom = "ipad";   FilenameSuffix = "20~ipad@2x" },
    @{ Size = 20;  Scale = 2; Idiom = "iphone"; FilenameSuffix = "20@2x" },
    @{ Size = 20;  Scale = 3; Idiom = "iphone"; FilenameSuffix = "20@3x" },
    @{ Size = 29;  Scale = 1; Idiom = "ipad";   FilenameSuffix = "29@1x" },
    @{ Size = 29;  Scale = 2; Idiom = "ipad";   FilenameSuffix = "29@2x" },
    @{ Size = 29;  Scale = 3; Idiom = "iphone"; FilenameSuffix = "29@3x" },
    @{ Size = 40;  Scale = 1; Idiom = "ipad";   FilenameSuffix = "40@1x" },
    @{ Size = 40;  Scale = 2; Idiom = "ipad";   FilenameSuffix = "40@2x" },
    @{ Size = 40;  Scale = 2; Idiom = "iphone"; FilenameSuffix = "40@2x" },
    @{ Size = 40;  Scale = 3; Idiom = "iphone"; FilenameSuffix = "40@3x" },
    @{ Size = 60;  Scale = 2; Idiom = "iphone"; FilenameSuffix = "60@2x" },
    @{ Size = 60;  Scale = 3; Idiom = "iphone"; FilenameSuffix = "60@3x" },
    @{ Size = 76;  Scale = 1; Idiom = "ipad";   FilenameSuffix = "76@1x" },
    @{ Size = 76;  Scale = 2; Idiom = "ipad";   FilenameSuffix = "76@2x" },
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
    
    $targetDir = "$basePath\AppIcon-$($variant.Name).appiconset"
    if (-not (Test-Path $targetDir)) {
        New-Item -ItemType Directory -Path $targetDir | Out-Null
    }
    
    foreach ($iconSize in $iconSizes) {
        $pixelSize = [int]($iconSize.Size * $iconSize.Scale)
        $bitmap = New-Object System.Drawing.Bitmap($pixelSize, $pixelSize)
        $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
        $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $graphics.DrawImage($sourceImg, 0, 0, $pixelSize, $pixelSize)
        $graphics.Dispose()
        
        $filename = "AppIcon-$($iconSize.FilenameSuffix).png"
        $bitmap.Save("$targetDir\$filename", [System.Drawing.Imaging.ImageFormat]::Png)
        $bitmap.Dispose()
        Write-Host "Generated: $targetDir\$filename ($pixelSize x $pixelSize)"
    }
    
    $sourceImg.Dispose()
}

Write-Host "Done generating icons!"