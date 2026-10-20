$basePath = "C:\Dev\_Mathieu\02_Projets\Perso\Nexora\Nexora\Resources\Assets.xcassets"

$variants = @(
    @{ Name = "Classic"; Key = "classic" },
    @{ Name = "Gradient"; Key = "gradient" },
    @{ Name = "Minimal"; Key = "minimal" },
    @{ Name = "Bold"; Key = "bold" },
    @{ Name = "Mono"; Key = "mono" }
)

$images = @(
    @{ Filename = "AppIcon-20@2x.png"; Idiom = "iphone"; Size = "20x20"; Scale = "2x" },
    @{ Filename = "AppIcon-20@3x.png"; Idiom = "iphone"; Size = "20x20"; Scale = "3x" },
    @{ Filename = "AppIcon-29@2x.png"; Idiom = "iphone"; Size = "29x29"; Scale = "2x" },
    @{ Filename = "AppIcon-29@3x.png"; Idiom = "iphone"; Size = "29x29"; Scale = "3x" },
    @{ Filename = "AppIcon-40@2x.png"; Idiom = "iphone"; Size = "40x40"; Scale = "2x" },
    @{ Filename = "AppIcon-40@3x.png"; Idiom = "iphone"; Size = "40x40"; Scale = "3x" },
    @{ Filename = "AppIcon-60@2x.png"; Idiom = "iphone"; Size = "60x60"; Scale = "2x" },
    @{ Filename = "AppIcon-60@3x.png"; Idiom = "iphone"; Size = "60x60"; Scale = "3x" },
    @{ Filename = "AppIcon-20~ipad.png"; Idiom = "ipad"; Size = "20x20"; Scale = "1x" },
    @{ Filename = "AppIcon-20~ipad@2x.png"; Idiom = "ipad"; Size = "20x20"; Scale = "2x" },
    @{ Filename = "AppIcon-29@1x.png"; Idiom = "ipad"; Size = "29x29"; Scale = "1x" },
    @{ Filename = "AppIcon-29@2x.png"; Idiom = "ipad"; Size = "29x29"; Scale = "2x" },
    @{ Filename = "AppIcon-40@1x.png"; Idiom = "ipad"; Size = "40x40"; Scale = "1x" },
    @{ Filename = "AppIcon-40@2x.png"; Idiom = "ipad"; Size = "40x40"; Scale = "2x" },
    @{ Filename = "AppIcon-76@1x.png"; Idiom = "ipad"; Size = "76x76"; Scale = "1x" },
    @{ Filename = "AppIcon-76@2x.png"; Idiom = "ipad"; Size = "76x76"; Scale = "2x" },
    @{ Filename = "AppIcon-83.5@2x.png"; Idiom = "ipad"; Size = "83.5x83.5"; Scale = "2x" },
    @{ Filename = "AppIcon-1024.png"; Idiom = "ios-marketing"; Size = "1024x1024"; Scale = "1x" }
)

foreach ($variant in $variants) {
    $targetDir = "$basePath\AppIcon-$($variant.Name).appiconset"
    
    $json = @{
        images = $images
        info = @{
            author = "xcode"
            version = 1
        }
    } | ConvertTo-Json -Depth 5
    
    $json | Set-Content -Path "$targetDir\Contents.json" -Encoding UTF8
    Write-Host "Created Contents.json for $($variant.Name)"
}

# Also update the main AppIcon.appiconset Contents.json to match
$mainDir = "$basePath\AppIcon.appiconset"
$json | Set-Content -Path "$mainDir\Contents.json" -Encoding UTF8
Write-Host "Updated Contents.json for main AppIcon"