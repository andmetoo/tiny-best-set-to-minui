<#
.SYNOPSIS
Converts Tiny Best Set GO (Onion layout) to the folder layout used by NextUI/MinUI.

.DESCRIPTION
Run without parameters for a friendly guided setup, or pass SourceRoot and
TargetRoot for an unattended-friendly command. Source files are never deleted.

.EXAMPLE
.\Convert-TinyBestSetToNextUI.ps1

.EXAMPLE
.\Convert-TinyBestSetToNextUI.ps1 -SourceRoot 'D:\Tiny best sets' -TargetRoot 'G:\'

.EXAMPLE
.\Convert-TinyBestSetToNextUI.ps1 -SourceRoot 'D:\Tiny best sets' -TargetRoot G -DryRun
#>

#requires -Version 5.1

[CmdletBinding()]
param(
    [Parameter()]
    [string]$SourceRoot,

    [Parameter()]
    [string]$TargetRoot,

    [Parameter()]
    [switch]$NonInteractive,

    [Parameter()]
    [switch]$Yes,

    [Parameter()]
    [switch]$SkipArcade,

    [Parameter()]
    [switch]$SkipArtwork,

    [Parameter()]
    [switch]$OverwriteExisting,

    [Parameter()]
    [switch]$AllowLowSpace,

    [Parameter()]
    [switch]$DryRun,

    [Parameter()]
    [Int64]$ReserveBytes = 2GB,

    [Parameter()]
    [string]$LogPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:SevenZip = $null
$script:TempRoot = $null
$script:TranscriptStarted = $false
$script:PromptedForInput = $false

function Write-Stage {
    param([Parameter(Mandatory)][string]$Message)
    $stamp = Get-Date -Format 'HH:mm:ss'
    Write-Host "[$stamp] $Message"
}

function Format-Bytes {
    param([Parameter(Mandatory)][Int64]$Bytes)

    if ($Bytes -ge 1TB) { return ('{0:N2} TB' -f ($Bytes / 1TB)) }
    if ($Bytes -ge 1GB) { return ('{0:N2} GB' -f ($Bytes / 1GB)) }
    if ($Bytes -ge 1MB) { return ('{0:N2} MB' -f ($Bytes / 1MB)) }
    return ('{0:N0} B' -f $Bytes)
}

function Clear-PathInput {
    param([string]$Path)

    if ([string]::IsNullOrWhiteSpace($Path)) { return $null }
    return $Path.Trim().Trim('"').Trim("'")
}

function Convert-ToTargetPath {
    param([string]$Path)

    $cleanPath = Clear-PathInput -Path $Path
    if (-not $cleanPath) { return $null }
    if ($cleanPath -match '^[A-Za-z]:?$') {
        return ($cleanPath.Substring(0, 1).ToUpperInvariant() + ':\')
    }
    return $cleanPath
}

function Resolve-TinyBestSetSourceRoot {
    param([string]$Path)

    $cleanPath = Clear-PathInput -Path $Path
    if (-not $cleanPath) { return $null }

    try { $fullPath = [System.IO.Path]::GetFullPath($cleanPath) }
    catch { return $null }

    $baseArchiveBelow = Join-Path $fullPath 'tiny-best-set-go\tiny-best-set-go-games.zip'
    if (Test-Path -LiteralPath $baseArchiveBelow -PathType Leaf) { return $fullPath }

    $baseArchiveHere = Join-Path $fullPath 'tiny-best-set-go-games.zip'
    if (Test-Path -LiteralPath $baseArchiveHere -PathType Leaf) {
        return (Split-Path -Parent $fullPath)
    }

    return $null
}

function Show-AvailableFileSystemDrives {
    Write-Host ''
    Write-Host 'Доступные диски / Available drives:' -ForegroundColor Cyan
    $rows = [System.Collections.Generic.List[object]]::new()
    foreach ($drive in [System.IO.DriveInfo]::GetDrives()) {
        try {
            if (-not $drive.IsReady) { continue }
            $rows.Add([pscustomobject]@{
                Drive = $drive.Name
                Label = $drive.VolumeLabel
                Type = [string]$drive.DriveType
                FreeGB = [math]::Round($drive.AvailableFreeSpace / 1GB, 1)
            })
        }
        catch { continue }
    }
    $rows | Format-Table -AutoSize | Out-Host
}

function Find-SevenZip {
    $command = Get-Command 7z.exe -ErrorAction SilentlyContinue
    if (-not $command) { $command = Get-Command 7z -ErrorAction SilentlyContinue }
    if ($command) { return $command.Source }

    $candidates = [System.Collections.Generic.List[string]]::new()
    $candidates.Add((Join-Path $PSScriptRoot '7z.exe'))
    if ($env:ProgramFiles) {
        $candidates.Add((Join-Path $env:ProgramFiles '7-Zip\7z.exe'))
    }
    if (${env:ProgramFiles(x86)}) {
        $candidates.Add((Join-Path ${env:ProgramFiles(x86)} '7-Zip\7z.exe'))
    }
    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate -PathType Leaf) { return $candidate }
    }
    return $null
}

function Read-SourceRootInteractively {
    Write-Host ''
    Write-Host 'Укажите папку, внутри которой лежит каталог tiny-best-set-go.' -ForegroundColor Cyan
    Write-Host 'You may also paste the tiny-best-set-go folder itself.'
    Write-Host 'Пример / Example: D:\Downloads\Tiny best sets'
    while ($true) {
        $answer = Read-Host 'Путь к Tiny Best Set / Tiny Best Set path'
        $resolved = Resolve-TinyBestSetSourceRoot -Path $answer
        if ($resolved) { return $resolved }
        Write-Warning 'Не найден tiny-best-set-go-games.zip. Проверьте путь и попробуйте ещё раз.'
    }
}

function Read-TargetRootInteractively {
    Show-AvailableFileSystemDrives
    Write-Host 'Введите букву microSD. Можно написать G, G: или G:\.' -ForegroundColor Cyan
    while ($true) {
        $answer = Convert-ToTargetPath -Path (Read-Host 'Флешка NextUI / NextUI SD card')
        if ($answer -and
            (Test-Path -LiteralPath (Join-Path $answer '.system') -PathType Container) -and
            (Test-Path -LiteralPath (Join-Path $answer 'Roms') -PathType Container) -and
            (Test-Path -LiteralPath (Join-Path $answer 'Bios') -PathType Container)) {
            return $answer
        }
        Write-Warning 'На этом диске не найдены папки .system, Roms и Bios. Это точно карта с установленным NextUI?'
    }
}

function Ensure-Directory {
    param([Parameter(Mandatory)][string]$Path)

    if (Test-Path -LiteralPath $Path -PathType Container) { return }
    if ($DryRun) {
        Write-Stage "[DRY RUN] Создать папку: $Path"
        return
    }
    $null = New-Item -ItemType Directory -Path $Path -Force
}

function Invoke-7ZipExtract {
    param(
        [Parameter(Mandatory)][ValidateSet('e', 'x')][string]$Mode,
        [Parameter(Mandatory)][string]$Archive,
        [Parameter(Mandatory)][string]$Destination,
        [string]$Pattern,
        [switch]$ForceOverwrite,
        [Parameter(Mandatory)][string]$Description
    )

    Write-Stage $Description
    if ($DryRun) { return }

    Ensure-Directory -Path $Destination

    $overwriteMode = '-aos'
    if ($OverwriteExisting -or $ForceOverwrite) { $overwriteMode = '-aoa' }

    $arguments = @(
        $Mode,
        $Archive,
        '-y',
        $overwriteMode,
        '-bso0',
        '-bsp0',
        '-bse1',
        "-o$Destination"
    )
    if ($Pattern) { $arguments += "-ir!$Pattern" }

    & $script:SevenZip @arguments
    $exitCode = $LASTEXITCODE
    if ($exitCode -gt 1) {
        throw "7-Zip завершился с кодом ${exitCode}: $Description"
    }
    if ($exitCode -eq 1) {
        Write-Warning "7-Zip сообщил предупреждение: $Description"
    }
}

function Get-ArchiveUnpackedSize {
    param([Parameter(Mandatory)][string]$Archive)

    [Int64]$total = 0
    $lines = & $script:SevenZip l -slt -ba -- $Archive
    if ($LASTEXITCODE -ne 0) {
        throw "Не удалось прочитать каталог архива: $Archive"
    }
    foreach ($line in $lines) {
        if ($line -like 'Size = *') {
            $value = $line.Substring(7)
            [Int64]$size = 0
            if ([Int64]::TryParse($value, [ref]$size)) { $total += $size }
        }
    }
    return $total
}

function Copy-BiosFromArchive {
    param(
        [Parameter(Mandatory)][string]$Archive,
        [Parameter(Mandatory)][string]$Entry,
        [Parameter(Mandatory)][string]$Destination,
        [Parameter(Mandatory)][string]$Description
    )

    Write-Stage $Description
    if ($DryRun) { return }

    $destinationDirectory = Split-Path -Parent $Destination
    Ensure-Directory -Path $destinationDirectory

    if ((Test-Path -LiteralPath $Destination -PathType Leaf) -and -not $OverwriteExisting) {
        Write-Stage "Уже существует, пропуск: $Destination"
        return
    }

    $extractDirectory = Join-Path $script:TempRoot ([Guid]::NewGuid().ToString('N'))
    Ensure-Directory -Path $extractDirectory
    Invoke-7ZipExtract -Mode e -Archive $Archive -Destination $extractDirectory -Pattern $Entry -ForceOverwrite -Description "  извлечение $Entry"

    $leafName = Split-Path -Leaf $Entry
    $extracted = Join-Path $extractDirectory $leafName
    if (-not (Test-Path -LiteralPath $extracted -PathType Leaf)) {
        throw "BIOS не найден после извлечения: $Entry"
    }
    Copy-Item -LiteralPath $extracted -Destination $Destination -Force
}

function Copy-StandaloneFile {
    param(
        [Parameter(Mandatory)][string]$Source,
        [Parameter(Mandatory)][string]$Destination,
        [Parameter(Mandatory)][string]$Description
    )

    Write-Stage $Description
    if ($DryRun) { return }

    Ensure-Directory -Path (Split-Path -Parent $Destination)
    if ((Test-Path -LiteralPath $Destination -PathType Leaf) -and -not $OverwriteExisting) {
        Write-Stage "Уже существует, пропуск: $Destination"
        return
    }
    Copy-Item -LiteralPath $Source -Destination $Destination -Force
}

function Write-NextUiMapFromMiyooXml {
    param(
        [Parameter(Mandatory)][string]$XmlPath,
        [Parameter(Mandatory)][string]$Destination,
        [switch]$HideNeoGeoBios
    )

    Write-Stage "Создание NextUI map.txt: $Destination"
    if ($DryRun) { return }

    if ((Test-Path -LiteralPath $Destination -PathType Leaf) -and -not $OverwriteExisting) {
        Write-Stage "Уже существует, пропуск: $Destination"
        return
    }

    [xml]$document = Get-Content -LiteralPath $XmlPath -Raw
    $lines = [System.Collections.Generic.List[string]]::new()
    foreach ($game in @($document.gameList.game)) {
        $fileName = [string]$game.path
        $displayName = [string]$game.name
        $fileName = $fileName -replace '^[.][\\/]', ''
        $fileName = Split-Path -Leaf $fileName
        $displayName = $displayName -replace '[\r\n\t]+', ' '
        if ($fileName -and $displayName) {
            $lines.Add("$fileName`t$displayName")
        }
    }
    if ($HideNeoGeoBios -and -not ($lines -match '^neogeo[.]zip\t')) {
        $lines.Add("neogeo.zip`t.Neo Geo BIOS")
    }

    Ensure-Directory -Path (Split-Path -Parent $Destination)
    $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
    [System.IO.File]::WriteAllLines($Destination, $lines, $utf8NoBom)
}

try {
    $missingSource = [string]::IsNullOrWhiteSpace($SourceRoot)
    $missingTarget = [string]::IsNullOrWhiteSpace($TargetRoot)
    if ($NonInteractive -and ($missingSource -or $missingTarget)) {
        throw 'В режиме -NonInteractive нужно указать -SourceRoot и -TargetRoot.'
    }

    if ($missingSource -or $missingTarget) {
        $script:PromptedForInput = $true
        Write-Host ''
        Write-Host 'Tiny Best Set GO -> NextUI / MinUI' -ForegroundColor Green
        Write-Host 'Скрипт не удаляет исходные файлы и не форматирует карту.'
        Write-Host 'The script does not delete source files or format the SD card.'
    }
    if ($missingSource) { $SourceRoot = Read-SourceRootInteractively }
    if ($missingTarget) { $TargetRoot = Read-TargetRootInteractively }

    $resolvedSourceRoot = Resolve-TinyBestSetSourceRoot -Path $SourceRoot
    if ($resolvedSourceRoot) { $SourceRoot = $resolvedSourceRoot }
    $TargetRoot = Convert-ToTargetPath -Path $TargetRoot

    $SourceRoot = [System.IO.Path]::GetFullPath($SourceRoot)
    $TargetRoot = [System.IO.Path]::GetFullPath($TargetRoot)

    if (-not $LogPath) {
        $LogPath = Join-Path $PSScriptRoot ("tiny-best-set-nextui-{0}.log" -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
    }
    $LogPath = [System.IO.Path]::GetFullPath($LogPath)
    $null = Start-Transcript -Path $LogPath -Force
    $script:TranscriptStarted = $true

    Write-Stage 'Проверка исходной сборки и флешки'
    if (-not (Test-Path -LiteralPath $SourceRoot -PathType Container)) {
        throw "Исходная папка не найдена: $SourceRoot"
    }
    if (-not (Test-Path -LiteralPath $TargetRoot -PathType Container)) {
        throw "Целевая папка не найдена: $TargetRoot"
    }
    if ($SourceRoot.TrimEnd('\') -eq $TargetRoot.TrimEnd('\')) {
        throw 'Исходная и целевая папки не могут совпадать.'
    }

    $targetDriveRoot = [System.IO.Path]::GetPathRoot($TargetRoot)
    $systemDriveRoot = ([string]$env:SystemDrive).TrimEnd('\') + '\'
    if ($targetDriveRoot -eq $systemDriveRoot) {
        throw "Для безопасности системный диск нельзя использовать как TargetRoot: $TargetRoot"
    }

    $nextUiMarkers = @(
        (Join-Path $TargetRoot '.system'),
        (Join-Path $TargetRoot 'Roms'),
        (Join-Path $TargetRoot 'Bios')
    )
    foreach ($marker in $nextUiMarkers) {
        if (-not (Test-Path -LiteralPath $marker -PathType Container)) {
            throw "На целевом диске не найдена ожидаемая папка NextUI: $marker"
        }
    }

    $script:SevenZip = Find-SevenZip
    if (-not $script:SevenZip) {
        throw '7-Zip не найден. Установите 7-Zip или добавьте 7z.exe в PATH.'
    }

    $setRoot = Join-Path $SourceRoot 'tiny-best-set-go'
    $arcadeRoot = Join-Path $SourceRoot 'tiny-best-set-go-arcade-update_202305'

    $archives = [ordered]@{
        BaseGames       = Join-Path $setRoot 'tiny-best-set-go-games.zip'
        Games64         = Join-Path $setRoot 'tiny-best-set-go-expansion-64-games.zip'
        Games128        = Join-Path $setRoot 'tiny-best-set-go-expansion-128-games.zip'
        BaseArtwork     = Join-Path $setRoot 'tiny-best-set-go-imgs-onion.zip'
        Artwork64       = Join-Path $setRoot 'tiny-best-set-go-expansion-64-imgs-onion.zip'
        Artwork128      = Join-Path $setRoot 'tiny-best-set-go-expansion-128-imgs-onion.zip'
        ArcadeNames     = Join-Path $setRoot 'tiny-best-set-go-arcade-names-onion.zip'
        ArcadeUpdate    = Join-Path $arcadeRoot 'tiny-best-set-go-arcade-update-onion.zip'
        ArcadeArtwork   = Join-Path $arcadeRoot 'tiny-best-set-go-arcade-update-onion-imgs.zip'
    }

    $requiredArchiveKeys = @('BaseGames', 'Games64', 'Games128')
    if (-not $SkipArtwork) { $requiredArchiveKeys += @('BaseArtwork', 'Artwork64', 'Artwork128') }
    if (-not $SkipArcade) { $requiredArchiveKeys += @('ArcadeNames', 'ArcadeUpdate') }
    if (-not $SkipArcade -and -not $SkipArtwork) { $requiredArchiveKeys += 'ArcadeArtwork' }
    foreach ($key in $requiredArchiveKeys) {
        $archivePath = $archives[$key]
        if (-not (Test-Path -LiteralPath $archivePath -PathType Leaf)) {
            throw "Не найден обязательный архив: $archivePath"
        }
    }

    [Int64]$requiredBytes = 0
    foreach ($key in $requiredArchiveKeys) {
        Write-Stage "Подсчёт размера: $([System.IO.Path]::GetFileName($archives[$key]))"
        $requiredBytes += Get-ArchiveUnpackedSize -Archive $archives[$key]
    }

    $tombRaiderRom = Join-Path $setRoot 'Tomb Raider\Tomb Raider (USA) (Rev 6).chd'
    $tombRaiderArtwork = Join-Path $setRoot 'Tomb Raider\tomb-raider-img-onion\Tomb Raider (USA) (Rev 6).png'
    if (Test-Path -LiteralPath $tombRaiderRom -PathType Leaf) {
        $requiredBytes += (Get-Item -LiteralPath $tombRaiderRom).Length
    }
    if (-not $SkipArtwork -and (Test-Path -LiteralPath $tombRaiderArtwork -PathType Leaf)) {
        $requiredBytes += (Get-Item -LiteralPath $tombRaiderArtwork).Length
    }

    $targetDrive = [System.IO.DriveInfo]::new($targetDriveRoot)
    $freeBytes = $targetDrive.AvailableFreeSpace
    Write-Stage "Нужно не более: $(Format-Bytes $requiredBytes); свободно: $(Format-Bytes $freeBytes); резерв: $(Format-Bytes $ReserveBytes)"
    if (($requiredBytes + $ReserveBytes) -gt $freeBytes -and -not $AllowLowSpace) {
        throw "Недостаточно места с учётом резерва. Освободите место или явно используйте -AllowLowSpace."
    }

    if ($script:PromptedForInput -and -not $DryRun -and -not $Yes) {
        Write-Host ''
        Write-Host 'Всё готово к переносу / Ready to copy' -ForegroundColor Green
        Write-Host "  Tiny Best Set: $SourceRoot"
        Write-Host "  NextUI / MinUI SD: $TargetRoot"
        Write-Host "  Максимальный объём / Maximum size: $(Format-Bytes $requiredBytes)"
        $confirmation = (Read-Host 'Начать? / Start? [Y/n]').Trim().ToLowerInvariant()
        if ($confirmation -and $confirmation -notin @('y', 'yes', 'д', 'да')) {
            throw 'Операция отменена пользователем / Cancelled by user.'
        }
    }

    if ($DryRun) {
        Write-Stage 'Режим DRY RUN: файлы изменяться не будут'
    }

    if (-not $DryRun) {
        $script:TempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("tiny-best-set-nextui-{0}" -f [Guid]::NewGuid().ToString('N'))
        $null = New-Item -ItemType Directory -Path $script:TempRoot -Force
    }

    $romMappings = @(
        [pscustomobject]@{ Source = 'ARCADE'; Target = 'Arcade (FBN)'; Arcade = $true },
        [pscustomobject]@{ Source = 'ATARI'; Target = 'Atari 2600 (A2600)'; Arcade = $false },
        [pscustomobject]@{ Source = 'FC'; Target = 'Nintendo Entertainment System (FC)'; Arcade = $false },
        [pscustomobject]@{ Source = 'GB'; Target = 'Game Boy (GB)'; Arcade = $false },
        [pscustomobject]@{ Source = 'GBA'; Target = 'Game Boy Advance (GBA)'; Arcade = $false },
        [pscustomobject]@{ Source = 'GBC'; Target = 'Game Boy Color (GBC)'; Arcade = $false },
        [pscustomobject]@{ Source = 'GG'; Target = 'Sega Game Gear (GG)'; Arcade = $false },
        [pscustomobject]@{ Source = 'MD'; Target = 'Sega Genesis (MD)'; Arcade = $false },
        [pscustomobject]@{ Source = 'MS'; Target = 'Sega Master System (SMS)'; Arcade = $false },
        [pscustomobject]@{ Source = 'NEOGEO'; Target = 'Neo Geo (FBN)'; Arcade = $true },
        [pscustomobject]@{ Source = 'PCE'; Target = 'TurboGrafx-16 (PCE)'; Arcade = $false },
        [pscustomobject]@{ Source = 'SFC'; Target = 'Super Nintendo Entertainment System (SFC)'; Arcade = $false }
    )
    $expansionMappings = @(
        [pscustomobject]@{ Source = 'PCECD'; Target = 'TurboGrafx-16 (PCE)' },
        [pscustomobject]@{ Source = 'PS'; Target = 'Sony PlayStation (PS)' },
        [pscustomobject]@{ Source = 'SEGACD'; Target = 'Sega CD (SEGACD)' }
    )

    foreach ($mapping in $romMappings) {
        if ($mapping.Arcade -and $SkipArcade) { continue }
        $destination = Join-Path (Join-Path $TargetRoot 'Roms') $mapping.Target
        Invoke-7ZipExtract -Mode e -Archive $archives.BaseGames -Destination $destination -Pattern "Roms\$($mapping.Source)\*" -Description "ROM: $($mapping.Source) -> $($mapping.Target)"
    }
    foreach ($archiveKey in @('Games64', 'Games128')) {
        foreach ($mapping in $expansionMappings) {
            $destination = Join-Path (Join-Path $TargetRoot 'Roms') $mapping.Target
            Invoke-7ZipExtract -Mode e -Archive $archives[$archiveKey] -Destination $destination -Pattern "Roms\$($mapping.Source)\*" -Description "ROM ${archiveKey}: $($mapping.Source) -> $($mapping.Target)"
        }
    }

    if (-not $SkipArcade) {
        $arcadeDestination = Join-Path (Join-Path $TargetRoot 'Roms') 'Arcade (FBN)'
        Invoke-7ZipExtract -Mode e -Archive $archives.ArcadeUpdate -Destination $arcadeDestination -Pattern 'Roms\ARCADE\*' -ForceOverwrite -Description 'Применение аркадного обновления Tiny Best Set (MAME2003+ ROM set)'
    }

    if (Test-Path -LiteralPath $tombRaiderRom -PathType Leaf) {
        Copy-StandaloneFile -Source $tombRaiderRom -Destination (Join-Path (Join-Path (Join-Path $TargetRoot 'Roms') 'Sony PlayStation (PS)') (Split-Path -Leaf $tombRaiderRom)) -Description 'ROM: отдельный Tomb Raider -> Sony PlayStation (PS)'
    }

    if (-not $SkipArtwork) {
        foreach ($mapping in $romMappings) {
            if ($mapping.Arcade -and $SkipArcade) { continue }
            $destination = Join-Path (Join-Path (Join-Path $TargetRoot 'Roms') $mapping.Target) '.media'
            Invoke-7ZipExtract -Mode e -Archive $archives.BaseArtwork -Destination $destination -Pattern "Roms\$($mapping.Source)\Imgs\*" -Description "Обложки: $($mapping.Source) -> $($mapping.Target)\.media"
        }
        foreach ($archiveKey in @('Artwork64', 'Artwork128')) {
            foreach ($mapping in $expansionMappings) {
                $destination = Join-Path (Join-Path (Join-Path $TargetRoot 'Roms') $mapping.Target) '.media'
                Invoke-7ZipExtract -Mode e -Archive $archives[$archiveKey] -Destination $destination -Pattern "Roms\$($mapping.Source)\Imgs\*" -Description "Обложки ${archiveKey}: $($mapping.Source) -> $($mapping.Target)\.media"
            }
        }
        if (-not $SkipArcade) {
            $arcadeMedia = Join-Path (Join-Path (Join-Path $TargetRoot 'Roms') 'Arcade (FBN)') '.media'
            Invoke-7ZipExtract -Mode e -Archive $archives.ArcadeArtwork -Destination $arcadeMedia -Pattern 'Roms\ARCADE\Imgs\*' -ForceOverwrite -Description 'Применение обновлённых аркадных обложек'
        }
        if (Test-Path -LiteralPath $tombRaiderArtwork -PathType Leaf) {
            Copy-StandaloneFile -Source $tombRaiderArtwork -Destination (Join-Path (Join-Path (Join-Path (Join-Path $TargetRoot 'Roms') 'Sony PlayStation (PS)') '.media') (Split-Path -Leaf $tombRaiderArtwork)) -Description 'Обложка: отдельный Tomb Raider -> Sony PlayStation (PS)\.media'
        }
    }

    $baseBiosMappings = @(
        [pscustomobject]@{ Entry = 'BIOS\disksys.rom'; Target = 'FC\disksys.rom' },
        [pscustomobject]@{ Entry = 'BIOS\gb_bios.bin'; Target = 'GB\gb_bios.bin' },
        [pscustomobject]@{ Entry = 'BIOS\gbc_bios.bin'; Target = 'GBC\gbc_bios.bin' },
        [pscustomobject]@{ Entry = 'BIOS\gba_bios.bin'; Target = 'GBA\gba_bios.bin' },
        [pscustomobject]@{ Entry = 'BIOS\bios.gg'; Target = 'GG\bios.gg' },
        [pscustomobject]@{ Entry = 'BIOS\bios_E.sms'; Target = 'SMS\bios_E.sms' },
        [pscustomobject]@{ Entry = 'BIOS\bios_J.sms'; Target = 'SMS\bios_J.sms' },
        [pscustomobject]@{ Entry = 'BIOS\bios_U.sms'; Target = 'SMS\bios_U.sms' },
        [pscustomobject]@{ Entry = 'BIOS\bios_MD.bin'; Target = 'MD\bios_MD.bin' }
    )
    foreach ($mapping in $baseBiosMappings) {
        $destination = Join-Path (Join-Path $TargetRoot 'Bios') $mapping.Target
        Copy-BiosFromArchive -Archive $archives.BaseGames -Entry $mapping.Entry -Destination $destination -Description "BIOS: $($mapping.Target)"
    }

    $expansionBiosMappings = @(
        [pscustomobject]@{ Entry = 'BIOS\bios_CD_E.bin'; Target = 'SEGACD\bios_CD_E.bin' },
        [pscustomobject]@{ Entry = 'BIOS\bios_CD_J.bin'; Target = 'SEGACD\bios_CD_J.bin' },
        [pscustomobject]@{ Entry = 'BIOS\bios_CD_U.bin'; Target = 'SEGACD\bios_CD_U.bin' },
        [pscustomobject]@{ Entry = 'BIOS\syscard3.pce'; Target = 'PCE\syscard3.pce' },
        [pscustomobject]@{ Entry = 'BIOS\PSXONPSP660.bin'; Target = 'PS\psxonpsp660.bin' }
    )
    foreach ($mapping in $expansionBiosMappings) {
        $destination = Join-Path (Join-Path $TargetRoot 'Bios') $mapping.Target
        Copy-BiosFromArchive -Archive $archives.Games64 -Entry $mapping.Entry -Destination $destination -Description "BIOS: $($mapping.Target)"
    }

    if (-not $SkipArcade) {
        $arcadeSamples = Join-Path (Join-Path $TargetRoot 'Bios') 'FBN\fbneo\samples'
        Invoke-7ZipExtract -Mode e -Archive $archives.ArcadeUpdate -Destination $arcadeSamples -Pattern 'BIOS\mame2003-plus\samples\*' -ForceOverwrite -Description 'Аркадные звуковые samples -> Bios\FBN\fbneo\samples'

        $neoGeoTempDestination = Join-Path $TargetRoot '.dry-run-temp-neogeo'
        if (-not $DryRun) { $neoGeoTempDestination = Join-Path $script:TempRoot 'neogeo-bios' }
        Invoke-7ZipExtract -Mode e -Archive $archives.BaseGames -Destination $neoGeoTempDestination -Pattern 'BIOS\neogeo.zip' -ForceOverwrite -Description 'Извлечение Neo Geo BIOS'
        if (-not $DryRun) {
            $neoGeoSource = Join-Path $neoGeoTempDestination 'neogeo.zip'
            foreach ($folder in @('Arcade (FBN)', 'Neo Geo (FBN)')) {
                $destination = Join-Path (Join-Path (Join-Path $TargetRoot 'Roms') $folder) 'neogeo.zip'
                if ($OverwriteExisting -or -not (Test-Path -LiteralPath $destination -PathType Leaf)) {
                    Copy-Item -LiteralPath $neoGeoSource -Destination $destination -Force
                }
            }
        }

        $namesTemp = Join-Path $TargetRoot '.dry-run-temp-arcade-names'
        if (-not $DryRun) { $namesTemp = Join-Path $script:TempRoot 'arcade-names' }
        Invoke-7ZipExtract -Mode x -Archive $archives.ArcadeNames -Destination $namesTemp -ForceOverwrite -Description 'Извлечение таблиц названий аркад'
        if (-not $DryRun) {
            Write-NextUiMapFromMiyooXml -XmlPath (Join-Path $namesTemp 'Roms\ARCADE\miyoogamelist.xml') -Destination (Join-Path (Join-Path (Join-Path $TargetRoot 'Roms') 'Arcade (FBN)') 'map.txt') -HideNeoGeoBios
            Write-NextUiMapFromMiyooXml -XmlPath (Join-Path $namesTemp 'Roms\NEOGEO\miyoogamelist.xml') -Destination (Join-Path (Join-Path (Join-Path $TargetRoot 'Roms') 'Neo Geo (FBN)') 'map.txt') -HideNeoGeoBios
        }
    }

    if (-not $DryRun) {
        Write-Stage 'Итоговая проверка файлов'
        $summaryTargets = @($romMappings | Where-Object { -not ($_.Arcade -and $SkipArcade) }) + $expansionMappings
        $summary = foreach ($mapping in $summaryTargets) {
            $romDirectory = Join-Path (Join-Path $TargetRoot 'Roms') $mapping.Target
            $mediaDirectory = Join-Path $romDirectory '.media'
            [pscustomobject]@{
                System = $mapping.Target
                Roms = @(Get-ChildItem -LiteralPath $romDirectory -File -Force -ErrorAction SilentlyContinue | Where-Object { $_.Name -ne 'map.txt' }).Count
                Artwork = @(Get-ChildItem -LiteralPath $mediaDirectory -File -Force -ErrorAction SilentlyContinue).Count
            }
        }
        $summary = $summary | Group-Object System | ForEach-Object { $_.Group | Select-Object -First 1 }
        $summary | Sort-Object System | Format-Table -AutoSize

        $totalRoms = ($summary | Measure-Object Roms -Sum).Sum
        $totalArtwork = ($summary | Measure-Object Artwork -Sum).Sum
        $biosFiles = @(Get-ChildItem -LiteralPath (Join-Path $TargetRoot 'Bios') -File -Force -Recurse).Count
        $remaining = [System.IO.DriveInfo]::new($targetDriveRoot).AvailableFreeSpace
        Write-Stage "Готово / Done: ROM-файлов $totalRoms; обложек $totalArtwork; BIOS-файлов $biosFiles; осталось $(Format-Bytes $remaining)"
    }
    else {
        Write-Stage 'DRY RUN завершён успешно'
    }

    Write-Stage "Журнал: $LogPath"
}
finally {
    if ($script:TempRoot -and (Test-Path -LiteralPath $script:TempRoot -PathType Container)) {
        Remove-Item -LiteralPath $script:TempRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
    if ($script:TranscriptStarted) {
        $null = Stop-Transcript
    }
}
