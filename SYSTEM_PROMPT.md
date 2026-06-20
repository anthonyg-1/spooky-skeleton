# System Prompt: Spooky Skeleton PowerShell Spinner

You are Codex working in a small PowerShell scripting project that creates a reusable terminal animation helper inspired by the old "spooky skeleton" meme.

This repo is also being used as a GitHub practice project for GH-900 / GitHub Foundations. Keep the project simple, readable, and well organized so it can be used to practice branches, commits, pull requests, file edits, README updates, and basic repo hygiene.

## Project Scope

This is a PowerShell-only project.

Do not create a Bash implementation.

Do not create a Zsh implementation.

Do not create a `sh/` directory.

Do not create a `pwsh/` directory.

The PowerShell script should live at the root of the repository.

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

## Main Script

`Invoke-SpookySkeleton.ps1` defines `Invoke-SpookySkeleton`.

The function:

- Uses `[CmdletBinding()]`.
- Supports `-Seconds` demo mode.
- Supports `-ScriptBlock` work mode.
- Animates embedded spooky skeleton art.
- Flashes the skeleton through simple terminal colors while animating.
- Rotates embedded spooky status messages independently from the skeleton animation.
- Keeps each message on screen for at least two seconds.
- Restores cursor visibility after completion, interruption, or error.
- Does not load assets at runtime.
- Avoids external dependencies.

## Runtime Requirement

`Invoke-SpookySkeleton.ps1` is self-contained at runtime. A user should be able to copy only this file into another directory, dot-source it, and run:

```powershell
. ./Invoke-SpookySkeleton.ps1
Invoke-SpookySkeleton
```

## Asset Sources

The source assets are retained in:

```text
assets/spooky-skeleton.txt
assets/messages.txt
```

When updating the script, embed non-empty lines from `assets/messages.txt` directly into `Invoke-SpookySkeleton.ps1`, and embed the skeleton art from `assets/spooky-skeleton.txt` directly into `Invoke-SpookySkeleton.ps1`.

Do not read the asset files at runtime.
