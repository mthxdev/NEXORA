$bytes = [System.IO.File]::ReadAllBytes("C:\Dev\_Mathieu\02_Projets\Perso\Nexora\Nexora\Resources\Assets.xcassets\AppIcon.appiconset\AppIcon-60@3x.png")
$offset = 8
while ($offset + 8 -le $bytes.Length) {
    $chunkLen = [System.BitConverter]::ToUInt32([byte[]]$bytes[$offset..($offset+3)], 0)
    $chunkType = [System.Text.Encoding]::ASCII.GetString([byte[]]$bytes[($offset+4)..($offset+7)])
    if ($chunkType -eq "IHDR") {
        $ihdr = [byte[]]$bytes[($offset+8)..($offset+8+$chunkLen-1)]
        $width = [System.BitConverter]::ToUInt32($ihdr[0..3], 0)
        $height = [System.BitConverter]::ToUInt32($ihdr[4..7], 0)
        $colorType = $ihdr[9]
        $hasAlpha = ($colorType -eq 4 -or $colorType -eq 6)
        Write-Host "AppIcon-60@3x.png: ${width}x${height}, color_type=$colorType, has_alpha=$hasAlpha"
        break
    }
    $offset += 12 + $chunkLen
}