[CmdletBinding()]
param(
    [string]$GodotPath = 'D:\Godot\godot.exe',
    [string]$FfmpegPath = 'ffmpeg',
    [string]$FfprobePath = 'ffprobe',
    [switch]$UpdateSnapshot,
    [switch]$SkipOverlap
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$snapshotPath = Join-Path $projectRoot 'assets\audio\sfx_loudness_measurements.json'
$invariant = [System.Globalization.CultureInfo]::InvariantCulture
$failures = [System.Collections.Generic.List[string]]::new()
$warnings = [System.Collections.Generic.List[string]]::new()

function Resolve-Executable {
    param([Parameter(Mandatory = $true)][string]$RequestedPath)

    if (Test-Path -LiteralPath $RequestedPath -PathType Leaf) {
        return (Resolve-Path -LiteralPath $RequestedPath).Path
    }

    $command = Get-Command $RequestedPath -ErrorAction SilentlyContinue
    if ($null -eq $command) {
        throw "Executable not found: $RequestedPath"
    }
    return $command.Source
}

function Convert-ToDouble {
    param([Parameter(Mandatory = $true)][string]$Text)
    return [double]::Parse($Text, [System.Globalization.NumberStyles]::Float, $invariant)
}

function Get-ObjectPropertyValue {
    param(
        [Parameter(Mandatory = $true)]$Object,
        [Parameter(Mandatory = $true)][string]$Name,
        $Default = 0.0
    )

    if ($null -eq $Object) {
        return $Default
    }
    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property) {
        return $Default
    }
    return $property.Value
}

function Convert-ResourcePath {
    param([Parameter(Mandatory = $true)][string]$ResourcePath)

    if (-not $ResourcePath.StartsWith('res://', [System.StringComparison]::Ordinal)) {
        throw "Expected res:// audio path, got: $ResourcePath"
    }
    return Join-Path $projectRoot $ResourcePath.Substring(6).Replace('/', '\')
}

function Measure-AudioFile {
    param([Parameter(Mandatory = $true)][string]$Path)

    $probeText = (& $script:ffprobeExe -v error -show_entries 'format=duration' -of json $Path 2>&1) -join "`n"
    if ($LASTEXITCODE -ne 0) {
        throw "ffprobe failed for $Path`n$probeText"
    }
    $probe = $probeText | ConvertFrom-Json

    $filter = '[0:a]asplit=3[a][b][c];' +
        '[a]apad=whole_dur=0.4,loudnorm=I=-24:LRA=7:TP=-1:print_format=json[ao];' +
        '[b]volumedetect[bo];' +
        '[c]apad=whole_dur=0.4,ebur128=peak=true:framelog=verbose[co]'
    $output = (& $script:ffmpegExe -hide_banner -nostats -loglevel verbose -i $Path `
        -filter_complex $filter -map '[ao]' -map '[bo]' -map '[co]' -f null NUL 2>&1) -join "`n"
    if ($LASTEXITCODE -ne 0) {
        throw "ffmpeg loudness measurement failed for $Path`n$output"
    }

    $inputI = [regex]::Match($output, '"input_i"\s*:\s*"([^\"]+)"')
    $inputTp = [regex]::Match($output, '"input_tp"\s*:\s*"([^\"]+)"')
    $mean = [regex]::Match($output, 'mean_volume:\s*([-\d\.]+) dB')
    $samplePeak = [regex]::Match($output, 'max_volume:\s*([-\d\.]+) dB')
    $momentary = @([regex]::Matches($output, '\bM:\s*(-?\d+(?:\.\d+)?)') |
        ForEach-Object { Convert-ToDouble $_.Groups[1].Value } |
        Where-Object { $_ -gt -100.0 })
    if (-not $inputI.Success -or -not $inputTp.Success -or -not $mean.Success -or
        -not $samplePeak.Success -or $momentary.Count -eq 0) {
        throw "Could not parse loudness output for $Path"
    }

    return [pscustomobject]@{
        duration_seconds = [math]::Round([double]$probe.format.duration, 3)
        max_m_lufs = [math]::Round(($momentary | Measure-Object -Maximum).Maximum, 2)
        integrated_lufs = [math]::Round((Convert-ToDouble $inputI.Groups[1].Value), 2)
        true_peak_dbtp = [math]::Round((Convert-ToDouble $inputTp.Groups[1].Value), 2)
        rms_dbfs = [math]::Round((Convert-ToDouble $mean.Groups[1].Value), 2)
        sample_peak_dbfs = [math]::Round((Convert-ToDouble $samplePeak.Groups[1].Value), 2)
    }
}

function Get-Event {
    param([Parameter(Mandatory = $true)][string]$EventId)

    $event = $script:manifest.events | Where-Object { $_.event_id -eq $EventId } | Select-Object -First 1
    if ($null -eq $event) {
        throw "Catalog manifest is missing event: $EventId"
    }
    return $event
}

function New-ScenarioInput {
    param(
        [Parameter(Mandatory = $true)][string]$EventId,
        [int]$StreamIndex = 0,
        [double]$ExtraGainDb = 0.0,
        [int]$DelayMs = 0
    )

    $event = Get-Event $EventId
    $streamPath = [string]$event.streams[$StreamIndex]
    $streamOffset = [double](Get-ObjectPropertyValue $event.stream_volume_offsets_db $streamPath 0.0)
    return [pscustomobject]@{
        path = Convert-ResourcePath $streamPath
        gain_db = [double]$event.volume_db + $streamOffset + $ExtraGainDb
        delay_ms = $DelayMs
    }
}

function Measure-OverlapScenario {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][array]$Inputs
    )

    $arguments = [System.Collections.Generic.List[string]]::new()
    $arguments.Add('-hide_banner')
    $arguments.Add('-nostats')
    $arguments.Add('-loglevel')
    $arguments.Add('verbose')
    foreach ($input in $Inputs) {
        $arguments.Add('-i')
        $arguments.Add([string]$input.path)
    }

    $parts = [System.Collections.Generic.List[string]]::new()
    $labels = [System.Collections.Generic.List[string]]::new()
    for ($index = 0; $index -lt $Inputs.Count; $index++) {
        $input = $Inputs[$index]
        $label = "a$index"
        $delay = if ([int]$input.delay_ms -gt 0) { ",adelay=$([int]$input.delay_ms):all=1" } else { '' }
        $gain = ([double]$input.gain_db).ToString('0.###', $invariant)
        $parts.Add("[$index`:a]volume=${gain}dB$delay[$label]")
        $labels.Add("[$label]")
    }
    $parts.Add(($labels -join '') + "amix=inputs=$($Inputs.Count):duration=longest:normalize=0," +
        'asplit=2[m][n]')
    $parts.Add('[m]apad=whole_dur=0.4,loudnorm=I=-24:LRA=7:TP=-1:print_format=json[mo]')
    $parts.Add('[n]apad=whole_dur=0.4,ebur128=peak=true:framelog=verbose[no]')
    $arguments.Add('-filter_complex')
    $arguments.Add($parts -join ';')
    $arguments.Add('-map')
    $arguments.Add('[mo]')
    $arguments.Add('-map')
    $arguments.Add('[no]')
    $arguments.Add('-f')
    $arguments.Add('null')
    $arguments.Add('NUL')

    $output = (& $script:ffmpegExe @arguments 2>&1) -join "`n"
    if ($LASTEXITCODE -ne 0) {
        throw "ffmpeg overlap measurement failed for $Name`n$output"
    }
    $inputTp = [regex]::Match($output, '"input_tp"\s*:\s*"([^\"]+)"')
    $momentary = @([regex]::Matches($output, '\bM:\s*(-?\d+(?:\.\d+)?)') |
        ForEach-Object { Convert-ToDouble $_.Groups[1].Value } |
        Where-Object { $_ -gt -100.0 })
    if (-not $inputTp.Success -or $momentary.Count -eq 0) {
        throw "Could not parse overlap measurement for $Name"
    }

    return [pscustomobject]@{
        scenario = $Name
        max_m_lufs = [math]::Round(($momentary | Measure-Object -Maximum).Maximum, 2)
        pre_limiter_true_peak_dbtp = [math]::Round((Convert-ToDouble $inputTp.Groups[1].Value), 2)
    }
}

$godotExe = Resolve-Executable $GodotPath
$script:ffmpegExe = Resolve-Executable $FfmpegPath
$script:ffprobeExe = Resolve-Executable $FfprobePath
$tempParent = Join-Path $projectRoot 'tmp'
$tempLeaf = 'sorting-puzzle-sfx-audit-' + [guid]::NewGuid().ToString('N')
$tempRoot = Join-Path $tempParent $tempLeaf
$manifestPath = Join-Path $tempRoot 'catalog.json'

try {
    New-Item -ItemType Directory -Path $tempRoot | Out-Null
    $godotProcess = Start-Process -FilePath $godotExe -ArgumentList @(
        '--headless', '--path', $projectRoot,
        '--script', 'res://scripts/tools/export_sfx_loudness_manifest.gd',
        '--', "--output=$manifestPath"
    ) -NoNewWindow -Wait -PassThru
    if ($godotProcess.ExitCode -ne 0 -or -not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
        throw 'Godot could not export the SFX loudness manifest.'
    }
    $script:manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json

    $measurements = [System.Collections.Generic.List[object]]::new()
    $audioFiles = Get-ChildItem (Join-Path $projectRoot 'assets\audio') -Recurse -File |
        Where-Object { $_.Extension.ToLowerInvariant() -in @('.wav', '.mp3', '.ogg', '.flac', '.m4a', '.aac', '.opus') } |
        Sort-Object FullName
    foreach ($file in $audioFiles) {
        $relative = $file.FullName.Substring($projectRoot.Length + 1).Replace('\', '/')
        $measurement = Measure-AudioFile $file.FullName
        $measurements.Add([pscustomobject]@{
            path = "res://$relative"
            sha256 = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
            duration_seconds = $measurement.duration_seconds
            max_m_lufs = $measurement.max_m_lufs
            integrated_lufs = $measurement.integrated_lufs
            true_peak_dbtp = $measurement.true_peak_dbtp
            rms_dbfs = $measurement.rms_dbfs
            sample_peak_dbfs = $measurement.sample_peak_dbfs
        })
        if ($measurement.true_peak_dbtp -gt [double]$script:manifest.standard.asset_hard_true_peak_dbtp + 0.05) {
            $failures.Add("$relative exceeds the -1 dBTP source ceiling ($($measurement.true_peak_dbtp) dBTP).")
        }
    }

    $runtimeRows = [System.Collections.Generic.List[object]]::new()
    foreach ($event in $script:manifest.events) {
        $class = Get-ObjectPropertyValue $script:manifest.standard.classes ([string]$event.loudness_class) $null
        if ($null -eq $class) {
            $failures.Add("$($event.event_id) has unknown loudness class $($event.loudness_class).")
            continue
        }
        $variantLevels = [System.Collections.Generic.List[double]]::new()
        foreach ($streamPath in $event.streams) {
            $raw = $measurements | Where-Object { $_.path -eq [string]$streamPath } | Select-Object -First 1
            if ($null -eq $raw) {
                $failures.Add("$($event.event_id) has no measurement for $streamPath.")
                continue
            }
            $streamOffset = [double](Get-ObjectPropertyValue $event.stream_volume_offsets_db ([string]$streamPath) 0.0)
            $gain = [double]$event.volume_db + $streamOffset
            $nominalM = [math]::Round([double]$raw.max_m_lufs + $gain, 2)
            $burstM = [math]::Round($nominalM + [double]$event.volume_variation_db + [double]$event.max_count_gain_db, 2)
            $runtimeTp = [math]::Round([double]$raw.true_peak_dbtp + $gain, 2)
            $variantLevels.Add($nominalM)
            $runtimeRows.Add([pscustomobject]@{
                event = $event.event_id
                file = Split-Path ([string]$streamPath) -Leaf
                class = $event.loudness_class
                max_m_lufs = $nominalM
                burst_max_m_lufs = $burstM
                true_peak_dbtp = $runtimeTp
            })

            if ($nominalM -lt [double]$class.nominal_min_lufs - 0.25 -or
                $nominalM -gt [double]$class.nominal_max_lufs + 0.25) {
                $failures.Add("$($event.event_id)/$(Split-Path ([string]$streamPath) -Leaf) is $nominalM LUFS-M; class $($event.loudness_class) requires $($class.nominal_min_lufs) to $($class.nominal_max_lufs).")
            }
            if ($burstM -gt [double]$class.burst_ceiling_lufs + 0.25) {
                $failures.Add("$($event.event_id) can reach $burstM LUFS-M; its burst ceiling is $($class.burst_ceiling_lufs).")
            }

            $major = [string]$event.loudness_class -in @('ability_warning', 'terminal_stinger')
            $runtimePeakGuide = if ($major) {
                [double]$script:manifest.standard.major_event_true_peak_dbtp
            } else {
                [double]$script:manifest.standard.routine_event_true_peak_dbtp
            }
            if ($runtimeTp -gt $runtimePeakGuide + 0.05) {
                $warnings.Add("$($event.event_id) reaches $runtimeTp dBTP; the class guide is $runtimePeakGuide dBTP.")
            }
        }

        if ($variantLevels.Count -gt 1) {
            $spread = ($variantLevels | Measure-Object -Maximum).Maximum - ($variantLevels | Measure-Object -Minimum).Minimum
            if ($spread -gt [double]$script:manifest.standard.max_variant_spread_lu + 0.05) {
                $failures.Add("$($event.event_id) variants span $([math]::Round($spread, 2)) LU; maximum is $($script:manifest.standard.max_variant_spread_lu) LU.")
            }
        }
    }

    Write-Output 'Runtime event loudness (nominal catalog gain):'
    $runtimeRows | Sort-Object event, file | Format-Table -AutoSize

    if ($UpdateSnapshot) {
        $snapshot = [ordered]@{
            schema_version = 1
            meter = 'ITU-R BS.1770 / FFmpeg ebur128+loudnorm; clips shorter than 400 ms are silence-padded'
            measurements = @($measurements | Sort-Object path)
        }
        $json = $snapshot | ConvertTo-Json -Depth 6
        [System.IO.File]::WriteAllText($snapshotPath, $json + "`n", [System.Text.UTF8Encoding]::new($false))
        Write-Output "Updated snapshot: $snapshotPath"
    } else {
        if (-not (Test-Path -LiteralPath $snapshotPath -PathType Leaf)) {
            $failures.Add("Missing measurement snapshot: $snapshotPath (run with -UpdateSnapshot after review).")
        } else {
            $snapshot = Get-Content -LiteralPath $snapshotPath -Raw | ConvertFrom-Json
            foreach ($measurement in $measurements) {
                $saved = $snapshot.measurements | Where-Object { $_.path -eq $measurement.path } | Select-Object -First 1
                if ($null -eq $saved) {
                    $failures.Add("Measurement snapshot is missing $($measurement.path).")
                } elseif ($saved.sha256 -ne $measurement.sha256) {
                    $failures.Add("Audio changed without refreshing loudness measurements: $($measurement.path).")
                }
            }
        }
    }

    if (-not $SkipOverlap) {
        $scenarios = [ordered]@{
            placement_match_star = @(
                (New-ScenarioInput 'item_place_valid' 0 ([double](Get-Event 'item_place_valid').volume_variation_db)),
                (New-ScenarioInput 'match_clear' 0 ([double](Get-Event 'match_clear').volume_variation_db)),
                (New-ScenarioInput 'star_hud_arrival' 0 ([double](Get-Event 'star_hud_arrival').max_count_gain_db))
            )
            timer_hammer = @((New-ScenarioInput 'timer_critical_tick'), (New-ScenarioInput 'ability_hammer'))
            timer_shuffle = @((New-ScenarioInput 'timer_critical_tick'), (New-ScenarioInput 'ability_shuffle'))
            timer_lantern = @((New-ScenarioInput 'timer_critical_tick'), (New-ScenarioInput 'ability_lantern'))
            timer_freezer = @((New-ScenarioInput 'timer_critical_tick'), (New-ScenarioInput 'ability_freezer'))
            purchase_coin_gain = @((New-ScenarioInput 'shop_purchase_success'), (New-ScenarioInput 'coin_gain'))
            time_up_failure = @((New-ScenarioInput 'time_up'), (New-ScenarioInput 'level_failed'))
            item_place_polyphony = @(0..3 | ForEach-Object {
                New-ScenarioInput 'item_place_valid' 0 ([double](Get-Event 'item_place_valid').volume_variation_db) ($_ * 20)
            })
            match_polyphony = @(0..2 | ForEach-Object {
                New-ScenarioInput 'match_clear' 0 ([double](Get-Event 'match_clear').volume_variation_db) ($_ * 20)
            })
            reward_arrival_polyphony = @(0..2 | ForEach-Object {
                New-ScenarioInput 'reward_chest_star_arrival' 0 ([double](Get-Event 'reward_chest_star_arrival').volume_variation_db) ($_ * 50)
            })
            ui_click_polyphony = @(
                (New-ScenarioInput 'ui_click' 0 ([double](Get-Event 'ui_click').volume_variation_db) 0),
                (New-ScenarioInput 'ui_click' 1 ([double](Get-Event 'ui_click').volume_variation_db) 40),
                (New-ScenarioInput 'ui_click' 2 ([double](Get-Event 'ui_click').volume_variation_db) 80)
            )
        }

        $overlapRows = [System.Collections.Generic.List[object]]::new()
        foreach ($scenario in $scenarios.GetEnumerator()) {
            $result = Measure-OverlapScenario $scenario.Key $scenario.Value
            $overlapRows.Add($result)
            if ($result.pre_limiter_true_peak_dbtp -gt 0.0) {
                $failures.Add("Overlap $($result.scenario) clips before Master ($($result.pre_limiter_true_peak_dbtp) dBTP).")
            }
            if ($result.max_m_lufs -gt -14.0) {
                $failures.Add("Overlap $($result.scenario) reaches $($result.max_m_lufs) LUFS-M; project mix ceiling is -14 LUFS-M.")
            }
        }
        Write-Output 'Required overlap scenarios (pre-limiter):'
        $overlapRows | Format-Table -AutoSize
    }

    foreach ($warning in $warnings) {
        Write-Warning $warning
    }
    if ($failures.Count -gt 0) {
        foreach ($failure in $failures) {
            Write-Error $failure -ErrorAction Continue
        }
        exit 1
    }

    Write-Output "SFX loudness audit passed for $($measurements.Count) audio files and $($runtimeRows.Count) runtime streams."
}
finally {
    if (Test-Path -LiteralPath $tempRoot -PathType Container) {
        $resolvedTemp = [System.IO.Path]::GetFullPath($tempRoot)
        $resolvedParent = [System.IO.Path]::GetFullPath($tempParent).TrimEnd('\') + '\'
        if (-not $resolvedTemp.StartsWith($resolvedParent, [System.StringComparison]::OrdinalIgnoreCase) -or
            (Split-Path -Leaf $resolvedTemp) -notlike 'sorting-puzzle-sfx-audit-*') {
            throw "Refusing to clean unexpected audit directory: $resolvedTemp"
        }
        Remove-Item -LiteralPath $resolvedTemp -Recurse -Force
    }
}
