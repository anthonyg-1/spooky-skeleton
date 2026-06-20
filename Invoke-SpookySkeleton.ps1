<#
.SYNOPSIS
Animates a spooky skeleton in the terminal.

.DESCRIPTION
Runs a terminal animation using embedded spooky skeleton art and rotating status messages.
The function can run for a fixed number of seconds, or animate while a caller-provided
script block runs in a background job. The skeleton flashes through a small set of
terminal colors while it dances. Messages rotate independently and stay on screen
for at least two seconds.

.PARAMETER Seconds
Specifies how many seconds the animation should run in demo mode. The default is 10.

.PARAMETER ScriptBlock
Specifies work to run while the spooky skeleton animation is displayed.

.PARAMETER FrameDelayMilliseconds
Specifies the delay between animation frames.

.PARAMETER NoClear
Writes each frame without clearing the host first.

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
#>
function Invoke-SpookySkeleton {
    [CmdletBinding(DefaultParameterSetName = 'Seconds')]
    param(
        [Parameter(ParameterSetName = 'Seconds')]
        [ValidateRange(1, 3600)]
        [int] $Seconds = 10,

        [Parameter(Mandatory, ParameterSetName = 'ScriptBlock')]
        [scriptblock] $ScriptBlock,

        [ValidateRange(50, 2000)]
        [int] $FrameDelayMilliseconds = 92,

        [switch] $NoClear,

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

        $ScriptJob = $null
        $FrameIndex = 0
        $MessageIndex = 0
        $MessageDisplayMilliseconds = 2000
        $NextMessageAt = [DateTimeOffset]::Now.AddMilliseconds($MessageDisplayMilliseconds)

        $SkeletonArt = @'
▒▒▒░░░░░░░░░░▄▐░░░░
▒░░░░░░▄▄▄░░▄██▄░░░
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
            'U HAVE BEEN SPOOKED BY THE SPOOKY SKELETON'
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

            foreach ($Line in $ArtLines) {
                $Host.UI.WriteLine("$Padding$Line")
            }

            $Host.UI.WriteLine('')
            $Host.UI.WriteLine("$Padding$Message")
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
                        $MessageIndex++
                        $NextMessageAt = $CurrentTime.AddMilliseconds($MessageDisplayMilliseconds)
                    }

                    $CurrentOffset = $FrameOffsets[$FrameIndex % $FrameOffsets.Count]
                    $CurrentColor = $FrameColors[$FrameIndex % $FrameColors.Count]
                    $CurrentMessage = $Messages[$MessageIndex % $Messages.Count]
                    $SkeletonFrameLines = $SkeletonDanceFrames[$FrameIndex % $SkeletonDanceFrames.Count]

                    Write-SpookySkeletonFrame -ArtLines $SkeletonFrameLines -Message $CurrentMessage -Offset $CurrentOffset -Color $CurrentColor -UseColor $CanManageColor -NoClearFrame:$NoClear

                    $FrameIndex++
                    Start-Sleep -Milliseconds $FrameDelayMilliseconds
                }
            }
            else {
                while ($ScriptJob.State -eq 'NotStarted' -or $ScriptJob.State -eq 'Running') {
                    $CurrentTime = [DateTimeOffset]::Now
                    if ($CurrentTime -ge $NextMessageAt) {
                        $MessageIndex++
                        $NextMessageAt = $CurrentTime.AddMilliseconds($MessageDisplayMilliseconds)
                    }

                    $CurrentOffset = $FrameOffsets[$FrameIndex % $FrameOffsets.Count]
                    $CurrentColor = $FrameColors[$FrameIndex % $FrameColors.Count]
                    $CurrentMessage = $Messages[$MessageIndex % $Messages.Count]
                    $SkeletonFrameLines = $SkeletonDanceFrames[$FrameIndex % $SkeletonDanceFrames.Count]

                    Write-SpookySkeletonFrame -ArtLines $SkeletonFrameLines -Message $CurrentMessage -Offset $CurrentOffset -Color $CurrentColor -UseColor $CanManageColor -NoClearFrame:$NoClear

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
