param(
    [Parameter(Mandatory = $true)]
    [string]$SourceIcon,

    [Parameter(Mandatory = $true)]
    [string]$OutputDirectory
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing

function New-RoundedRectanglePath {
    param(
        [System.Drawing.RectangleF]$Bounds,
        [float]$Radius
    )

    $diameter = $Radius * 2
    $path = [System.Drawing.Drawing2D.GraphicsPath]::new()
    $path.AddArc($Bounds.Left, $Bounds.Top, $diameter, $diameter, 180, 90)
    $path.AddArc($Bounds.Right - $diameter, $Bounds.Top, $diameter, $diameter, 270, 90)
    $path.AddArc($Bounds.Right - $diameter, $Bounds.Bottom - $diameter, $diameter, $diameter, 0, 90)
    $path.AddArc($Bounds.Left, $Bounds.Bottom - $diameter, $diameter, $diameter, 90, 90)
    $path.CloseFigure()
    return $path
}

function Get-LogoLayer {
    param([System.Drawing.Bitmap]$Source)

    $layer = [System.Drawing.Bitmap]::new($Source.Width, $Source.Height, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $minX = $Source.Width
    $minY = $Source.Height
    $maxX = -1
    $maxY = -1

    for ($y = 0; $y -lt $Source.Height; $y++) {
        for ($x = 0; $x -lt $Source.Width; $x++) {
            $pixel = $Source.GetPixel($x, $y)
            $brightness = [Math]::Max($pixel.R, [Math]::Max($pixel.G, $pixel.B))
            if ($pixel.A -gt 0 -and $brightness -gt 8) {
                $alpha = [Math]::Min(255, [int](($brightness / 255.0) * $pixel.A))
                $layer.SetPixel($x, $y, [System.Drawing.Color]::FromArgb($alpha, 255, 255, 255))
                $minX = [Math]::Min($minX, $x)
                $minY = [Math]::Min($minY, $y)
                $maxX = [Math]::Max($maxX, $x)
                $maxY = [Math]::Max($maxY, $y)
            }
        }
    }

    if ($maxX -lt $minX -or $maxY -lt $minY) {
        $layer.Dispose()
        throw "No light logo pixels were found in $SourceIcon"
    }

    return @{
        Image = $layer
        Bounds = [System.Drawing.Rectangle]::FromLTRB($minX, $minY, $maxX + 1, $maxY + 1)
    }
}

function Save-DownscaledIcon {
    param(
        [System.Drawing.Bitmap]$Master,
        [int]$Size,
        [string]$Path
    )

    $result = [System.Drawing.Bitmap]::new($Size, $Size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $graphics = [System.Drawing.Graphics]::FromImage($result)
    try {
        $graphics.Clear([System.Drawing.Color]::Transparent)
        $graphics.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceCopy
        $graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
        $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
        $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
        $graphics.DrawImage($Master, [System.Drawing.Rectangle]::new(0, 0, $Size, $Size))
        $result.Save($Path, [System.Drawing.Imaging.ImageFormat]::Png)
    } finally {
        $graphics.Dispose()
        $result.Dispose()
    }
}

$sourcePath = (Resolve-Path -LiteralPath $SourceIcon).Path
[System.IO.Directory]::CreateDirectory($OutputDirectory) | Out-Null
$outputPath = (Resolve-Path -LiteralPath $OutputDirectory).Path

$source = [System.Drawing.Bitmap]::FromFile($sourcePath)
$logoData = $null
$master = $null
$graphics = $null
$backgroundPath = $null
$backgroundBrush = $null
try {
    $logoData = Get-LogoLayer -Source $source

    # Render at 4x and downsample. The visible tile occupies 87.5% of the
    # canvas and uses a 23% corner radius so all four corners remain obvious
    # when fnOS displays the 64px asset.
    $scale = 4
    $masterSize = 256 * $scale
    $tileMargin = 16 * $scale
    $tileSize = $masterSize - (2 * $tileMargin)
    $cornerRadius = 52 * $scale
    $logoWidth = 160 * $scale

    $master = [System.Drawing.Bitmap]::new($masterSize, $masterSize, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $graphics = [System.Drawing.Graphics]::FromImage($master)
    $graphics.Clear([System.Drawing.Color]::Transparent)
    $graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
    $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias

    $tileBounds = [System.Drawing.RectangleF]::new($tileMargin, $tileMargin, $tileSize, $tileSize)
    $backgroundPath = New-RoundedRectanglePath -Bounds $tileBounds -Radius $cornerRadius
    $backgroundBrush = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(255, 3, 3, 4))
    $graphics.FillPath($backgroundBrush, $backgroundPath)

    $logoBounds = $logoData.Bounds
    $logoHeight = [int][Math]::Round($logoWidth * ($logoBounds.Height / [double]$logoBounds.Width))
    $logoX = [int](($masterSize - $logoWidth) / 2)
    $logoY = [int](($masterSize - $logoHeight) / 2)
    $graphics.DrawImage(
        $logoData.Image,
        [System.Drawing.Rectangle]::new($logoX, $logoY, $logoWidth, $logoHeight),
        $logoBounds.X,
        $logoBounds.Y,
        $logoBounds.Width,
        $logoBounds.Height,
        [System.Drawing.GraphicsUnit]::Pixel
    )

    Save-DownscaledIcon -Master $master -Size 256 -Path (Join-Path $outputPath "icon_256.png")
    Save-DownscaledIcon -Master $master -Size 64 -Path (Join-Path $outputPath "icon_64.png")
} finally {
    if ($backgroundBrush) { $backgroundBrush.Dispose() }
    if ($backgroundPath) { $backgroundPath.Dispose() }
    if ($graphics) { $graphics.Dispose() }
    if ($master) { $master.Dispose() }
    if ($logoData -and $logoData.Image) { $logoData.Image.Dispose() }
    $source.Dispose()
}

Write-Output "Generated $outputPath\icon_256.png"
Write-Output "Generated $outputPath\icon_64.png"
