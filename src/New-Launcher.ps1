Set-StrictMode -Version 3.0
#Requires -Version 5.1

# For each PowerShell script in the scripts directory, create a shortcut to run the script with a double click.
# Script will create a directory titled "Scripts". Please place desired scripts there.
# The scripts folder is where the shortcuts will link back to, so please take caution when removing files.

if ( -not ( Test-Path "$PSScriptRoot\Scripts\*.ps1" )) {
	Write-Verbose -Message "Creating scripts folder."
	New-Item -ItemType Directory -Force -Path "$PSScriptRoot\Scripts" | Out-Null
	Read-Host -Prompt "No PowerShell script files detected. Please place at least one PowerShell
	script (ps1) file in the scripts folder, then press enter to continue"
}

Get-ChildItem $PSScriptRoot\Scripts\* -Filter *.ps1 | ForEach-Object {
	$WScriptShell = New-Object -comObject WScript.Shell
	$Shortcut = $WScriptShell.CreateShortcut(("$PSScriptRoot\") + ($_.BaseName) + ('.lnk'))
	# Use PowerShell 7 if available, otherwise fall back to PowerShell 5.1.
	if (Get-Command "pwsh" -ErrorAction SilentlyContinue) {
		$Shortcut.TargetPath = "pwsh.exe"
	}
	else {$Shortcut.TargetPath = "powershell.exe"}
	$Shortcut.TargetPath = "pwsh.exe"
	$Shortcut.Arguments = "-ExecutionPolicy Bypass -file ""$_""  -Noexit"
	$Shortcut.Save()
	Write-Verbose -Message "Shortcut created for $_."
}