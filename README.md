# Spooky Skeleton

Spooky Skeleton is a tiny PowerShell-only terminal animation helper inspired by the incredibly serious spooky skeleton copypasta.

The main script is `Invoke-SpookySkeleton.ps1`, and the main function is `Invoke-SpookySkeleton`. It can run as a short demo spinner, or it can animate while another PowerShell script block runs. While it dances, the skeleton flashes through terminal colors for maximum haunted status energy, and each message stays on screen for at least two seconds.

## Project Structure

```text
.
├── assets/
│   ├── spooky-skeleton.txt
│   └── messages.txt
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

## Assets

The source art and source messages live in `assets/`.

- `assets/spooky-skeleton.txt` contains the base skeleton art.
- `assets/messages.txt` contains one spinner message per line.

When `Invoke-SpookySkeleton.ps1` is generated or updated, the asset contents are embedded directly into the script. At runtime, `Invoke-SpookySkeleton.ps1` is self-contained. You can copy only that file into another folder, dot-source it, and run `Invoke-SpookySkeleton`.

To update the spinner messages, edit `assets/messages.txt`, then update the embedded message list in `Invoke-SpookySkeleton.ps1`.

## Script Analyzer

The script is intended to pass basic PSScriptAnalyzer checks:

```powershell
Invoke-ScriptAnalyzer -Path ./Invoke-SpookySkeleton.ps1
```

No external dependencies are required for the animation itself.
