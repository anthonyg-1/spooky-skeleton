# Spooky Skeleton

Spooky Skeleton is a tiny PowerShell-only terminal animation helper inspired by the incredibly serious spooky skeleton copypasta.

The main script is `Invoke-SpookySkeleton.ps1`, and the main function is `Invoke-SpookySkeleton`. It can run as a short demo spinner, or it can animate while another PowerShell script block runs. While it dances, the skeleton flashes through terminal colors for maximum haunted status energy, each message stays on screen for at least two seconds, and a short three-note spooky song plays by default.

## Project Structure

```text
.
├── Invoke-SpookySkeleton.ps1
├── SYSTEM_PROMPT.md
└── README.md
```

## Usage

Dot-source the script first:

```powershell
. ./Invoke-SpookySkeleton.ps1
```

Run demo mode with the default 10-second duration:

```powershell
Invoke-SpookySkeleton
```

Run demo mode for a specific duration:

```powershell
Invoke-SpookySkeleton -Seconds 10
```

Adjust the animation speed:

```powershell
Invoke-SpookySkeleton -Seconds 10 -FrameDelayMilliseconds 200
```

Run work mode while a script block executes:

```powershell
Invoke-SpookySkeleton -ScriptBlock {
    Start-Sleep -Seconds 5
}
```

Return output from the script block:

```powershell
Invoke-SpookySkeleton -ScriptBlock {
    Get-Date
} -PassThru
```

Run silently without the spooky song:

```powershell
Invoke-SpookySkeleton -NoMusic
```

## Audio Behavior

`Invoke-SpookySkeleton` embeds a private `Invoke-SpookySong` helper. The song uses the same three notes on every supported operating system:

```text
392 Hz for 300 ms
277 Hz for 450 ms
185 Hz for 700 ms
```

The first skeleton frame is written before the song starts, so the animation appears immediately. When `Start-ThreadJob` is available, the song runs in the background while the animation continues. If thread jobs are unavailable, the first frame is still shown before the song plays.

Audio support by platform:

- Windows: plays the notes with `[Console]::Beep`.
- macOS: generates a temporary WAV file and plays it with `afplay`.
- Linux: generates a temporary WAV file and tries `paplay`, then `aplay`, then `ffplay`.

On Linux, if none of those players are installed, no sound is played. If a supported player is present but cannot play the generated WAV, the function throws instead of falling back to terminal bell beeps.

## Script Analyzer

The script is intended to pass basic PSScriptAnalyzer checks:

```powershell
Invoke-ScriptAnalyzer -Path ./Invoke-SpookySkeleton.ps1
```

No external dependencies are required for the animation itself.
