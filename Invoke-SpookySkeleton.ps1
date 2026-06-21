<#
.SYNOPSIS
Animates a spooky skeleton in the terminal.

.DESCRIPTION
Runs a terminal animation using embedded spooky skeleton art and rotating status messages.
The function can run for a fixed number of seconds, or animate while a caller-provided
script block runs in a background job. The skeleton flashes through a small set of
terminal colors while it dances. Messages rotate independently and stay on screen
for at least two seconds. By default, it plays a short three-note spooky song before
the animation starts.

.PARAMETER Seconds
Specifies how many seconds the animation should run in demo mode. The default is 6.
Aliases: s, DurationInSecods.

.PARAMETER ScriptBlock
Specifies work to run while the spooky skeleton animation is displayed.
Aliases: sb, Command.

.PARAMETER FrameDelayMilliseconds
Specifies the delay between animation frames.
Alias: fdm.

.PARAMETER NoClear
Writes each frame without clearing the host first.
Alias: nc.

.PARAMETER NoMusic
Runs the animation without playing the spooky song.
Alias: nm.

.PARAMETER PassThru
Returns output produced by ScriptBlock after the animation finishes.

.EXAMPLE
. ./Invoke-SpookySkeleton.ps1
Invoke-SpookySkeleton

.EXAMPLE
. ./Invoke-SpookySkeleton.ps1
Invoke-SpookySkeleton -ScriptBlock {
    Start-Sleep -Seconds 5
}

.EXAMPLE
Invoke-SpookySkeleton -ScriptBlock {
    Get-Date
} -PassThru

.EXAMPLE
Invoke-SpookySkeleton -s 10 -fdm 200 -nm
#>
function Invoke-SpookySkeleton {
    [CmdletBinding(DefaultParameterSetName = 'Seconds')]
    [Alias('spooky-skeleton', 'spookyskeleton')]
    param(
        [Parameter(ParameterSetName = 'Seconds')]
        [ValidateRange(1, 3600)]
        [Alias('s', 'DurationInSecods')]
        [int] $Seconds = 6,

        [Parameter(Mandatory, ParameterSetName = 'ScriptBlock')]
        [Alias('sb', 'Command')]
        [scriptblock] $ScriptBlock,

        [ValidateRange(50, 2000)]
        [Alias('fdm')]
        [int] $FrameDelayMilliseconds = 92,

        [Alias('nc')]
        [switch] $NoClear,

        [Alias('nm')]
        [switch] $NoMusic,

        [Parameter(ParameterSetName = 'ScriptBlock')]
        [switch] $PassThru
    )

    begin {
        $CanManageCursor = -not [Console]::IsOutputRedirected
        $PreviousCursorVisible = $true
        if ($CanManageCursor) {
            try {
                $PreviousCursorVisible = [Console]::CursorVisible
            }
            catch {
                $CanManageCursor = $false
            }
        }
        $CanManageColor = $true
        $PreviousForegroundColor = [ConsoleColor]::Gray
        try {
            $PreviousForegroundColor = $Host.UI.RawUI.ForegroundColor
        }
        catch {
            $CanManageColor = $false
        }

        function Invoke-SpookySong {
            [CmdletBinding()]
            param()

            begin {
                $Notes = @(
                    [pscustomobject] @{
                        Frequency = 392
                        DurationMilliseconds = 300
                    }
                    [pscustomobject] @{
                        Frequency = 277
                        DurationMilliseconds = 450
                    }
                    [pscustomobject] @{
                        Frequency = 185
                        DurationMilliseconds = 700
                    }
                )

                function Out-SpookySongWaveFile {
                    [CmdletBinding()]
                    param(
                        [Parameter(Mandatory)]
                        [pscustomobject[]] $WaveNotes,

                        [Parameter(Mandatory)]
                        [string] $Path
                    )

                    $SampleRate = 44100
                    $Amplitude = 16000
                    $BytesPerSample = 2
                    $SampleCount = 0

                    foreach ($Note in $WaveNotes) {
                        $SampleCount += [int] [Math]::Ceiling($SampleRate * ($Note.DurationMilliseconds / 1000))
                    }

                    $DataSize = $SampleCount * $BytesPerSample
                    $FileSizeMinusRiffHeader = 36 + $DataSize
                    $ByteRate = $SampleRate * $BytesPerSample

                    $FileStream = [System.IO.File]::Create($Path)
                    $Writer = [System.IO.BinaryWriter]::new($FileStream)

                    try {
                        $Writer.Write([Text.Encoding]::ASCII.GetBytes('RIFF'))
                        $Writer.Write([int] $FileSizeMinusRiffHeader)
                        $Writer.Write([Text.Encoding]::ASCII.GetBytes('WAVE'))
                        $Writer.Write([Text.Encoding]::ASCII.GetBytes('fmt '))
                        $Writer.Write([int] 16)
                        $Writer.Write([short] 1)
                        $Writer.Write([short] 1)
                        $Writer.Write([int] $SampleRate)
                        $Writer.Write([int] $ByteRate)
                        $Writer.Write([short] $BytesPerSample)
                        $Writer.Write([short] 16)
                        $Writer.Write([Text.Encoding]::ASCII.GetBytes('data'))
                        $Writer.Write([int] $DataSize)

                        foreach ($Note in $WaveNotes) {
                            $NoteSampleCount = [int] [Math]::Ceiling($SampleRate * ($Note.DurationMilliseconds / 1000))

                            for ($SampleIndex = 0; $SampleIndex -lt $NoteSampleCount; $SampleIndex++) {
                                $ElapsedSeconds = $SampleIndex / $SampleRate
                                $Envelope = [Math]::Min(1, $SampleIndex / 400)
                                $SamplesRemaining = $NoteSampleCount - $SampleIndex

                                if ($SamplesRemaining -lt 1200) {
                                    $Envelope *= $SamplesRemaining / 1200
                                }

                                $Value = [Math]::Sin(2 * [Math]::PI * $Note.Frequency * $ElapsedSeconds)
                                $Writer.Write([short] ($Value * $Amplitude * $Envelope))
                            }
                        }
                    }
                    finally {
                        $Writer.Dispose()
                        $FileStream.Dispose()
                    }
                }

                function Invoke-SpookyWavePlayer {
                    [CmdletBinding()]
                    [OutputType([bool])]
                    param(
                        [Parameter(Mandatory)]
                        [pscustomobject[]] $WaveNotes,

                        [Parameter(Mandatory)]
                        [string[]] $PlayerNames
                    )

                    $FoundPlayer = $false
                    foreach ($PlayerName in $PlayerNames) {
                        $Player = Get-Command -Name $PlayerName -ErrorAction SilentlyContinue

                        if ($null -eq $Player) {
                            continue
                        }

                        $FoundPlayer = $true
                        $WavePath = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath "spooky-song-$([guid]::NewGuid()).wav"

                        try {
                            Out-SpookySongWaveFile -WaveNotes $WaveNotes -Path $WavePath
                            $Process = $null
                            $ProcessStartInfo = [System.Diagnostics.ProcessStartInfo]::new()
                            $ProcessStartInfo.FileName = $Player.Source
                            [void] $ProcessStartInfo.ArgumentList.Add($WavePath)
                            $ProcessStartInfo.CreateNoWindow = $true
                            $ProcessStartInfo.RedirectStandardError = $true
                            $ProcessStartInfo.RedirectStandardOutput = $true
                            $ProcessStartInfo.UseShellExecute = $false

                            $Process = [System.Diagnostics.Process]::new()
                            $Process.StartInfo = $ProcessStartInfo
                            [void] $Process.Start()
                            $StandardOutputTask = $Process.StandardOutput.ReadToEndAsync()
                            $StandardErrorTask = $Process.StandardError.ReadToEndAsync()
                            $ProcessExited = $Process.WaitForExit(5000)

                            if (-not $ProcessExited) {
                                $Process.Kill()
                                $Process.WaitForExit()
                            }

                            [void] $StandardOutputTask.GetAwaiter().GetResult()
                            [void] $StandardErrorTask.GetAwaiter().GetResult()

                            if ($ProcessExited -and $Process.ExitCode -eq 0) {
                                return $true
                            }
                        }
                        finally {
                            if ($null -ne $Process) {
                                $Process.Dispose()
                            }

                            if (Test-Path -LiteralPath $WavePath) {
                                Remove-Item -LiteralPath $WavePath -Force
                            }
                        }
                    }

                    if ($FoundPlayer) {
                        throw 'A supported audio player was found, but it could not play the generated spooky song.'
                    }

                    return $false
                }

                function Invoke-SpookyTerminalBell {
                    [CmdletBinding()]
                    param(
                        [Parameter(Mandatory)]
                        [pscustomobject[]] $BellNotes
                    )

                    foreach ($Note in $BellNotes) {
                        [Console]::Out.Write([char] 7)
                        [Console]::Out.Flush()
                        Start-Sleep -Milliseconds $Note.DurationMilliseconds
                    }
                }
            }

            process {
                if ($IsLinux) {
                    if (Invoke-SpookyWavePlayer -WaveNotes $Notes -PlayerNames @('paplay', 'aplay', 'ffplay')) {
                        return
                    }

                    Write-Verbose 'No supported Linux audio player was found. No sound was played.'
                    return
                }

                if ($IsMacOS) {
                    if (Invoke-SpookyWavePlayer -WaveNotes $Notes -PlayerNames @('afplay')) {
                        return
                    }

                    Write-Verbose 'afplay was not found. Using terminal bell fallback.'
                    Invoke-SpookyTerminalBell -BellNotes $Notes
                    return
                }

                try {
                    foreach ($Note in $Notes) {
                        [Console]::Beep($Note.Frequency, $Note.DurationMilliseconds)
                    }
                }
                catch [System.PlatformNotSupportedException] {
                    Write-Verbose 'Console.Beep is not supported here. Using terminal bell fallback.'
                    Invoke-SpookyTerminalBell -BellNotes $Notes
                }
            }
        }

        function Invoke-SpookySongAsync {
            [CmdletBinding()]
            [OutputType([System.Management.Automation.Job])]
            param()

            $ThreadJobCommand = Get-Command -Name Start-ThreadJob -ErrorAction SilentlyContinue

            if ($null -eq $ThreadJobCommand) {
                Invoke-SpookySong
                return $null
            }

            $SongFunctionText = ${function:Invoke-SpookySong}.ToString()

            Start-ThreadJob -ScriptBlock {
                $FunctionDefinition = "function Invoke-SpookySong { $using:SongFunctionText }"
                . ([scriptblock]::Create($FunctionDefinition))
                Invoke-SpookySong
            }
        }

        $ScriptJob = $null
        $SongJob = $null
        $FrameIndex = 0
        $MessageIndex = -1
        $MessageSequenceIndex = 0
        $HasPlayedMusic = $false
        $MessageDisplayMilliseconds = 2000
        $NextMessageAt = [DateTimeOffset]::Now.AddMilliseconds($MessageDisplayMilliseconds)

        $SkeletonArt = @'
░░░░░░░░░░░░░▄▐░░░░
░░░░░░░▄▄▄░░▄██▄░░░
░░░░░░▐▀█▀▌░░░░▀█▄░
░░░░░░▐█▄█▌░░░░░░▀█▄
░░░░░░░▀▄▀░░░▄▄▄▄▄▀▀
░░░░░▄▄▄██▀▀▀▀░░░░░
░░░░█▀▄▄▄█░▀▀░░░░░░
░░░░▌░▄▄▄▐▌▀▀▀░░░░░
░▄░▐░░░▄▄░█░▀▀░░░░░
░▀█▌░░░▄░▀█▀░▀░░░░░
░░░░░░░░▄▄▐▌▄▄░░░░░
░░░░░░░░▀███▀█░▄░░░
░░░░░░░▐▌▀▄▀▄▀▐▄░░░
░░░░░░░▐▀░░░░░░▐▌░░
░░░░░░░█░░░░░░░░█░░
░░░░░░▐▌░░░░░░░░░█░
'@

        $Messages = @(
            'DOOT DOOT'
            'THE BONES HAVE ENTERED THE PIPELINE'
            'RATTLE ME BONES WHILE THIS RUNS'
            'YOUR TERMINAL HAS BEEN CURSED, RESPECTFULLY'
            'SKELETONS ARE COMPILING YOUR DESTINY'
            'WARNING: BONE-BASED COMPUTING DETECTED'
            'THE SKILENTON DEMANDS A SUCCESSFUL EXIT CODE'
            'SEND THIS TO 7 FUNCTIONS OR YOUR SCRIPT WILL BE HAUNTED'
            'CONGRATULATION, U ARE NOW SPOOKED'
            'PLEASE WAIT WHILE THE SKELETON DOES DEVOPS'
            'THE RIBCAGE IS RESOLVING DEPENDENCIES'
            'A VERY NORMAL AMOUNT OF BONES IS HAPPENING'
            'SKELETON IS ASKING THE TERMINAL POLITELY'
            'THE SKULL IS THINKING ABOUT YAML'
            'THIS PROCESS IS NOW LEGALLY HAUNTED'
            'THE TERMINAL RATTLES WITH ANCIENT KNOWLEDGE'
            'PLEASE HOLD WHILE BONES ALIGN'
            'THE SKELETON IS DOING ABSOLUTELY CRITICAL WORK'
            'NO BUGS ONLY BONES'
            'A TINY GHOST IS LINTING YOUR SCRIPT'
            'THE SKELETON HAS ENTERED SPINNER MODE'
            'THIS MESSAGE HAS BEEN PEER REVIEWED BY BONES'
            'THE DOOT DOOT CONTINUES'
            'BONE CACHE WARMING IN PROGRESS'
            'PLEASE STAND BY FOR ADDITIONAL RATTLE'
            'THE SKELETON IS PRACTICING LEAST PRIVILEGE'
            'YOUR SHELL HAS BEEN VISITED BY BONES'
            'THE BONES ARE AUDITING THIS FUNCTION'
            'PLEASE DO NOT INTERRUPT THE DANCE OF COMPLIANCE'
            'THE RIBCAGE HAS ACHIEVED FEATURE PARITY'
            'SKELETON STATUS: EXTREMELY SPOOKY'
            'THE SKELETON IS VALIDATING YOUR LIFE CHOICES'
            'THE SKELETON IS SUMMONING A CLEAN WORKING TREE'
            'THE BONES DEMAND A MEANINGFUL STATUS MESSAGE'
            'DOOT DOOT BUT MAKE IT ENTERPRISE'
            'THE RIBCAGE IS ALIGNING WITH BEST PRACTICES'
            'THE SKELETON HAS FILED A TICKET WITH THE UNDERWORLD'
            'THE SKELETON IS PRACTICING SAFE SCRIPTING'
            'YOUR PROCESS HAS BEEN SPOOKED PROFESSIONALLY'
            'THE BONES HAVE BEEN APPROVED BY SECURITY'
            'THE SKELETON IS DOING A RESPONSIBLE AMOUNT OF YAML'
            'THE SKELETON HAS REACHED EVENTUAL CONSISTENCY'
            'THE BONES ARE WAITING FOR NETWORK I/O'
            'THE SKULL IS PARSING JSON WITH GREAT CONCERN'
            'THE SKELETON IS NOT MAD, JUST DISAPPOINTED'
            'THE FEMUR HAS JOINED THE INCIDENT BRIDGE'
            'THE BONES HAVE DECLARED THIS A LEARNING OPPORTUNITY'
            'SPOOKY AUTOMATION HAS ENTERED THE CHAT'
            'THE SKELETON IS MAKING THIS REUSABLE'
            'THE BONES ARE GENERATING TERMINAL AMBIENCE'
            'THE SKELETON IS WAITING WITH MAXIMUM DRAMA'
        )

        $OpeningMessages = @(
            'U HAVE BEEN SPOOKED BY THE SPOOKY SKILENTON'
            'SEND THIS TO 4 PPL OR SKELINTONS WILL EAT YOU'
        )
        $CurrentMessage = $OpeningMessages[$MessageSequenceIndex]

        function Get-SpookyRandomMessageIndex {
            param(
                [int] $CurrentIndex,
                [int] $MessageCount
            )

            if ($MessageCount -le 1) {
                return 0
            }

            do {
                $NextIndex = Get-Random -Minimum 0 -Maximum $MessageCount
            } while ($NextIndex -eq $CurrentIndex)

            $NextIndex
        }
        $FrameOffsets = @(0, 1, 2, 1)
        $FrameColors = @(
            [ConsoleColor]::Gray
            [ConsoleColor]::White
            [ConsoleColor]::Cyan
            [ConsoleColor]::Magenta
            [ConsoleColor]::Yellow
            [ConsoleColor]::Green
        )
        $SkeletonLines = $SkeletonArt -split "`r?`n"
        $WaveLeftLines = [string[]] $SkeletonLines.Clone()
        $WaveLeftLines[8] = '░▀░▐░░░▄▄░█░▀▀░░░░░'
        $WaveLeftLines[9] = '░▄█▌░░░▄░▀█▀░▀░░░░░'
        $WaveLeftLines[14] = '░░░░░░▐▌░░░░░░░░█░░'
        $WaveLeftLines[15] = '░░░░░░░█░░░░░░░░▐▌░'

        $WaveRightLines = [string[]] $SkeletonLines.Clone()
        $WaveRightLines[13] = '░░░░░░░▐▌░░░░░░▐▌░░'
        $WaveRightLines[15] = '░░░░░░▐▌░░░░░░░░█░░'

        $SkeletonDanceFrames = [System.Collections.Generic.List[string[]]]::new()
        $SkeletonDanceFrames.Add($SkeletonLines)
        $SkeletonDanceFrames.Add($WaveLeftLines)
        $SkeletonDanceFrames.Add($SkeletonLines)
        $SkeletonDanceFrames.Add($WaveRightLines)

        function Write-SpookySkeletonFrame {
            param(
                [string[]] $ArtLines,
                [string] $Message,
                [int] $Offset,
                [ConsoleColor] $Color,
                [bool] $UseColor,
                [switch] $NoClearFrame
            )

            if (-not $NoClearFrame) {
                Clear-Host
            }

            $Padding = ' ' * $Offset
            if ($UseColor) {
                $Host.UI.RawUI.ForegroundColor = $Color
            }

            $FrameWidth = ($ArtLines | Measure-Object -Property Length -Maximum).Maximum
            $FrameBuilder = [System.Text.StringBuilder]::new()
            foreach ($Line in $ArtLines) {
                [void] $FrameBuilder.AppendLine("$Padding$($Line.PadRight($FrameWidth, '░'))")
            }

            [void] $FrameBuilder.AppendLine()
            [void] $FrameBuilder.AppendLine("$Padding$Message")
            $Host.UI.Write($FrameBuilder.ToString())
        }
    }

    process {
        try {
            if ($CanManageCursor) {
                [Console]::CursorVisible = $false
            }

            if ($PSCmdlet.ParameterSetName -eq 'ScriptBlock') {
                $ScriptJob = Start-Job -ScriptBlock $ScriptBlock
            }

            if ($PSCmdlet.ParameterSetName -eq 'Seconds') {
                $StopAt = [DateTimeOffset]::Now.AddSeconds($Seconds)

                while ([DateTimeOffset]::Now -lt $StopAt) {
                    $CurrentTime = [DateTimeOffset]::Now
                    if ($CurrentTime -ge $NextMessageAt) {
                        $MessageSequenceIndex++
                        if ($MessageSequenceIndex -lt $OpeningMessages.Count) {
                            $CurrentMessage = $OpeningMessages[$MessageSequenceIndex]
                        }
                        else {
                            $MessageIndex = Get-SpookyRandomMessageIndex -CurrentIndex $MessageIndex -MessageCount $Messages.Count
                            $CurrentMessage = $Messages[$MessageIndex]
                        }
                        $NextMessageAt = $CurrentTime.AddMilliseconds($MessageDisplayMilliseconds)
                    }

                    $CurrentOffset = $FrameOffsets[$FrameIndex % $FrameOffsets.Count]
                    $CurrentColor = $FrameColors[$FrameIndex % $FrameColors.Count]
                    $SkeletonFrameLines = $SkeletonDanceFrames[$FrameIndex % $SkeletonDanceFrames.Count]

                    Write-SpookySkeletonFrame -ArtLines $SkeletonFrameLines -Message $CurrentMessage -Offset $CurrentOffset -Color $CurrentColor -UseColor $CanManageColor -NoClearFrame:$NoClear

                    if (-not $NoMusic -and -not $HasPlayedMusic) {
                        $HasPlayedMusic = $true
                        $SongJob = Invoke-SpookySongAsync
                    }

                    $FrameIndex++
                    Start-Sleep -Milliseconds $FrameDelayMilliseconds
                }
            }
            else {
                while ($ScriptJob.State -eq 'NotStarted' -or $ScriptJob.State -eq 'Running') {
                    $CurrentTime = [DateTimeOffset]::Now
                    if ($CurrentTime -ge $NextMessageAt) {
                        $MessageSequenceIndex++
                        if ($MessageSequenceIndex -lt $OpeningMessages.Count) {
                            $CurrentMessage = $OpeningMessages[$MessageSequenceIndex]
                        }
                        else {
                            $MessageIndex = Get-SpookyRandomMessageIndex -CurrentIndex $MessageIndex -MessageCount $Messages.Count
                            $CurrentMessage = $Messages[$MessageIndex]
                        }
                        $NextMessageAt = $CurrentTime.AddMilliseconds($MessageDisplayMilliseconds)
                    }

                    $CurrentOffset = $FrameOffsets[$FrameIndex % $FrameOffsets.Count]
                    $CurrentColor = $FrameColors[$FrameIndex % $FrameColors.Count]
                    $SkeletonFrameLines = $SkeletonDanceFrames[$FrameIndex % $SkeletonDanceFrames.Count]

                    Write-SpookySkeletonFrame -ArtLines $SkeletonFrameLines -Message $CurrentMessage -Offset $CurrentOffset -Color $CurrentColor -UseColor $CanManageColor -NoClearFrame:$NoClear

                    if (-not $NoMusic -and -not $HasPlayedMusic) {
                        $HasPlayedMusic = $true
                        $SongJob = Invoke-SpookySongAsync
                    }

                    $FrameIndex++
                    Start-Sleep -Milliseconds $FrameDelayMilliseconds
                }

                $ScriptOutput = Receive-Job -Job $ScriptJob -ErrorAction Stop

                if ($ScriptJob.State -eq 'Failed') {
                    $JobReason = $ScriptJob.ChildJobs[0].JobStateInfo.Reason

                    if ($null -ne $JobReason) {
                        throw $JobReason
                    }

                    throw 'The spooky skeleton script block failed.'
                }

                if ($PassThru) {
                    $ScriptOutput
                }
            }
        }
        catch {
            throw
        }
        finally {
            if ($CanManageCursor) {
                [Console]::CursorVisible = $PreviousCursorVisible
            }
            if ($CanManageColor) {
                $Host.UI.RawUI.ForegroundColor = $PreviousForegroundColor
            }

            if (-not $NoClear) {
                Clear-Host
            }

            if ($null -ne $ScriptJob) {
                if ($ScriptJob.State -eq 'Running') {
                    Stop-Job -Job $ScriptJob
                }

                Remove-Job -Job $ScriptJob -Force
            }

            if ($null -ne $SongJob) {
                Receive-Job -Job $SongJob -ErrorAction SilentlyContinue | Out-Null
                Remove-Job -Job $SongJob -Force
            }
        }
    }

    end {
        if ($CanManageCursor) {
            [Console]::CursorVisible = $PreviousCursorVisible
        }
        if ($CanManageColor) {
            $Host.UI.RawUI.ForegroundColor = $PreviousForegroundColor
        }
    }
}
