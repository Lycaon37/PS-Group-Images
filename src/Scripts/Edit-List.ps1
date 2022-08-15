#Requires -Version 5.1
#Requires -Modules PSMenu
Set-StrictMode -Version 3.0

do { 
	Write-Information -MessageData ("This interactive menu is controllable by hotkeys:
	- Arrow up/down: Navigate menu items.
	- Enter: Select menu item..
	- Page up/down: Go one page up or down - if the menu is larger then the screen.
	- Home/end: Go to the top or bottom of the menu.
	- Escape: Quit the menu." ) -InformationAction Continue
	$Choice = Show-Menu -MenuItems @(
		"Add Folder"
		"Remove Folder"
		"View Database"
	)

	switch ($Choice) {
		"Add Folder" {
			# Get name.
			do {
				$Name = Read-Host "Please enter the name you want the images to follow"

				if(-not($Name)){
					Write-Error -Message "Name field is blank. Please enter a name."
				}
			}
			until($Name)

			# Get folder path.
			Add-Type -AssemblyName System.Windows.Forms
			Push-Location
			$FileBrowser = New-Object System.Windows.Forms.FolderBrowserDialog -Property @{
			ShowNewFolderButton = $true
			RootFolder = 'Desktop'
			Description = 'Please select a folder for sorting.'
			UseDescriptionForTitle = $true
			}
			Pop-Location
			if($FileBrowser.ShowDialog() -ne "OK") {
			Write-Information -Message "Selection canceled." -InformationAction Continue
			Read-Host "Press any key to return to the main menu"
			}
			else {
			$NewPath = $FileBrowser.SelectedPath
			$DatabaseContents = Get-Content $PSScriptRoot\Database.csv
			if($DatabaseContents -contains $NewPath) {
			  Write-Error -Message "Folder is already in the list."
			  Read-Host "Press any key to return to the main menu"
			}
			  else { $Path = $FileBrowser.SelectedPath }
			}

			# Get filter.
			$Filter = Read-Host "Please enter the filter for the files to follow. If nothing is entered, all files will be included"
			if(-not($Filter)){
			  $Filter = '.'
			}

			Add-Content $PSScriptRoot\Database.csv "$Name,$Path,$Filter"
		}

		"Remove Folder" {
			if (-not(Get-Content -Path $PSScriptRoot\Database.csv)) {
				Write-Error "Folder list is already empty."
				Read-Host "Press any key to return to the main menu"
			}
			else {
				# Select the entry to remove from a menu.
				$BadEntry = Show-Menu $(Import-CSV $PSScriptRoot\Database.csv) -MenuItemFormatter {
					($Args | Select-Object -ExpandProperty Name) + ' | ' + ($Args | Select-Object -ExpandProperty Path)
				}

				# Get the full contents of the database excluding the removed data.
				# Done separately to prevent errors from editing a file being used by another process.
				$NewData = Get-Content $PSScriptRoot\Database.csv |
				Where-Object { $_ -notlike ("$($BadEntry.Name)" + ',' + "$($BadEntry.Path)" + ',' + "$($BadEntry.Filter)") }
				if (-not($NewData)) {
					Clear-Content $PSScriptRoot\Database.csv
				}
				else {
					# Set database to be equal to corrected contents.
					$NewData | Set-Content $PSScriptRoot\Database.csv
				}
			}
		}

		"View Database" {
			$Database = Import-Csv $PSScriptRoot\Database.csv
			if (-not($Database)) { Write-Information -MessageData "Folder list is empty." -InformationAction Continue}
			else { $Database | Format-Table }
			Read-Host "Press any key to return to the main menu"
		}
	}
	Clear-Host
} until ($null -eq $Choice)