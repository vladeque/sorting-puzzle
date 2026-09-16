<#
.SYNOPSIS
Builds the short per-impact reward-chest cue from star_hud_arrival.wav.

.DESCRIPTION
Keeps the authored attack intact, then applies a raised-cosine fade so repeated chest impacts end
on sample-accurate silence instead of being hard-cut by the SFX polyphony cap.
#>
param(
    [string]$Source = 'assets/audio/star_hud_arrival/star_hud_arrival.wav',
    [string]$Output = 'assets/audio/reward_chest_star_arrival/reward_chest_star_arrival_short.wav',
    [int]$DurationMs = 200,
    [int]$FadeStartMs = 160
)

$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$sourcePath = if ([System.IO.Path]::IsPathRooted($Source)) { $Source } else { Join-Path $projectRoot $Source }
$outputPath = if ([System.IO.Path]::IsPathRooted($Output)) { $Output } else { Join-Path $projectRoot $Output }

if ($DurationMs -le 0 -or $FadeStartMs -lt 0 -or $FadeStartMs -ge $DurationMs) {
    throw 'DurationMs must be positive and FadeStartMs must fall inside the output duration.'
}
if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
    throw "Source WAV was not found: $sourcePath"
}

$bytes = [System.IO.File]::ReadAllBytes($sourcePath)
if ($bytes.Length -lt 44 -or [Text.Encoding]::ASCII.GetString($bytes, 0, 4) -ne 'RIFF' -or
    [Text.Encoding]::ASCII.GetString($bytes, 8, 4) -ne 'WAVE') {
    throw 'Source must be a RIFF/WAVE file.'
}

$formatCode = 0
$channels = 0
$sampleRate = 0
$bitsPerSample = 0
$blockAlign = 0
$dataOffset = -1
$dataLength = 0
$offset = 12
while ($offset + 8 -le $bytes.Length) {
    $chunkId = [Text.Encoding]::ASCII.GetString($bytes, $offset, 4)
    $chunkLength = [BitConverter]::ToUInt32($bytes, $offset + 4)
    $chunkDataOffset = $offset + 8
    if ($chunkDataOffset + $chunkLength -gt $bytes.Length) {
        throw "Malformed WAV chunk: $chunkId"
    }

    if ($chunkId -eq 'fmt ') {
        $formatCode = [BitConverter]::ToUInt16($bytes, $chunkDataOffset)
        $channels = [BitConverter]::ToUInt16($bytes, $chunkDataOffset + 2)
        $sampleRate = [BitConverter]::ToUInt32($bytes, $chunkDataOffset + 4)
        $blockAlign = [BitConverter]::ToUInt16($bytes, $chunkDataOffset + 12)
        $bitsPerSample = [BitConverter]::ToUInt16($bytes, $chunkDataOffset + 14)
    } elseif ($chunkId -eq 'data') {
        $dataOffset = $chunkDataOffset
        $dataLength = [int]$chunkLength
    }

    $offset = $chunkDataOffset + [int]$chunkLength + ([int]$chunkLength % 2)
}

if ($formatCode -ne 1 -or $bitsPerSample -ne 16 -or $channels -lt 1 -or $dataOffset -lt 0) {
    throw 'Source must be uncompressed 16-bit PCM with a data chunk.'
}

$sourceFrameCount = [int]($dataLength / $blockAlign)
$outputFrameCount = [Math]::Min([int][Math]::Round($sampleRate * $DurationMs / 1000.0), $sourceFrameCount)
$fadeStartFrame = [Math]::Min([int][Math]::Round($sampleRate * $FadeStartMs / 1000.0), $outputFrameCount - 1)
$outputData = [byte[]]::new($outputFrameCount * $blockAlign)
[Array]::Copy($bytes, $dataOffset, $outputData, 0, $outputData.Length)

for ($frame = $fadeStartFrame; $frame -lt $outputFrameCount; $frame++) {
    $fadePosition = ($frame - $fadeStartFrame) / [double][Math]::Max($outputFrameCount - 1 - $fadeStartFrame, 1)
    $gain = 0.5 * (1.0 + [Math]::Cos([Math]::PI * $fadePosition))
    for ($channel = 0; $channel -lt $channels; $channel++) {
        $sampleOffset = ($frame * $blockAlign) + ($channel * 2)
        $sample = [BitConverter]::ToInt16($outputData, $sampleOffset)
        $scaled = [int16][Math]::Round($sample * $gain)
        $scaledBytes = [BitConverter]::GetBytes($scaled)
        $outputData[$sampleOffset] = $scaledBytes[0]
        $outputData[$sampleOffset + 1] = $scaledBytes[1]
    }
}

$outputDirectory = Split-Path -Parent $outputPath
if (-not (Test-Path -LiteralPath $outputDirectory -PathType Container)) {
    New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
}

$stream = [System.IO.File]::Open($outputPath, [System.IO.FileMode]::Create, [System.IO.FileAccess]::Write)
$writer = [System.IO.BinaryWriter]::new($stream)
try {
    $writer.Write([Text.Encoding]::ASCII.GetBytes('RIFF'))
    $writer.Write([uint32](36 + $outputData.Length))
    $writer.Write([Text.Encoding]::ASCII.GetBytes('WAVE'))
    $writer.Write([Text.Encoding]::ASCII.GetBytes('fmt '))
    $writer.Write([uint32]16)
    $writer.Write([uint16]1)
    $writer.Write([uint16]$channels)
    $writer.Write([uint32]$sampleRate)
    $writer.Write([uint32]($sampleRate * $blockAlign))
    $writer.Write([uint16]$blockAlign)
    $writer.Write([uint16]$bitsPerSample)
    $writer.Write([Text.Encoding]::ASCII.GetBytes('data'))
    $writer.Write([uint32]$outputData.Length)
    $writer.Write($outputData)
} finally {
    $writer.Dispose()
    $stream.Dispose()
}

Write-Output ("Built {0} ({1} ms, fade {2}-{1} ms, {3} Hz, {4} channel(s))" -f `
    $outputPath, $DurationMs, $FadeStartMs, $sampleRate, $channels)
