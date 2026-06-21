# Repository Instructions

- Before every completion after editing PowerShell code, run and report:

  ```powershell
  Invoke-ScriptAnalyzer -Path ./Invoke-SpookySkeleton.ps1
  ```

- Update help every time `Invoke-SpookySkeleton` changes.
- Run the script analyzer for every PowerShell change.
- Before every completion after editing Markdown, run and report:

  ```shell
  npx markdownlint-cli2 "*.md"
  ```
