<#
	.SYNOPSIS
		Consolidate images from a database of folders.

	.DESCRIPTION
		Consolidate images from a database of folders
		It will name according to a specified name followed by a four digit pattern.
		The images will be converted to JPGs and sorted into appropriately named folders.
		With a bit of work using the task scheduler in Windows,
		this could be set up to run automatically at preset times, such as every day at 8:00 AM, for example.

		If this script was installed correctly. The proper database folder should be included. It is titled 'Database.csv'.
		Please fill this in the with the required data before use.

	.PARAMETER Backup
		Backup directory. This directory is where the original images will be placed.
		By default, a subdirectory of the script root is used.

	.PARAMETER Output
		Output directory. This directory is where the consolidated images will be placed
		By default, a subdirectory of the script root is used.

	.EXAMPLE
		PS C:\>Group-Images
		Consolidate images using default settings.

	.EXAMPLE
		PS C:\>Group-Images -Backup ~\Backup -Output ~\Pictures\Photography
		Consolidate images using customized folder locations.
#>

Param(
	[string]$Backup = "$PSScriptRoot\Backup",
	[string]$Output = "$PSScriptRoot\Output"
)

Set-StrictMode -Version 3.0
#Requires -Version 5.1

Function Export-JPG {
	<#
		.SYNOPSIS
			Convert images to the JPEG format.

		.DESCRIPTION
			Given compatible images, convert them to the JPEG format. (.jpg).
			Compatible formats include: BMP, EMF, EXIF, GIF, JPEG, PNG, TIFF, and WMF.

		.PARAMETER Path
			File or list of files to be converted to JPEG. Files must be in one of the supported formats above.
			Converting JPEG to JPEG is not recommended, as this will reduce the quality of the output image.

		.EXAMPLE
			PS C:\>Export-JPG -Path $PWD\Input\Test.jpg

			Convert one image.

		.EXAMPLE
			PS C:\>Export-JPG -Path $PWD\Input\Test1.jpg,$PWD\Input\Test2.png

			Convert multiple images.

		.EXAMPLE
			PS C:\>Get-ChildItem $PWD\Input\* | Export-JPG

			Batch convert images.
	#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory,ValueFromPipeline)]
		[System.IO.FileInfo]$Path
	)

	process {
		$Path | ForEach-Object {
			# Use the built-in System.Drawing .NET method to convert images.
			try {
				$File = [System.Drawing.Image]::FromFile($_.FullName)
				$FilePath = [IO.Path]::ChangeExtension($_.FullName, '.jpg')
				$File.Save($FilePath, [System.Drawing.Imaging.ImageFormat]::Jpeg)

				# Dispose of file to free it up from memory.
				$File.Dispose()
			}
			catch {
				Write-Error -Message 'Path does not exist. Please check if your path exists, and that the image format is suppported.'
			}
		}
	}
}
Function Group-Item {
	<#
		.SYNOPSIS
			Rename and organize files.

		.DESCRIPTION
			Rename files to a given name, followed by a four digit number.

		.PARAMETER Path
			Source directory or directories files will be taken from.
			Must be a valid path that exists on the computer.

		.PARAMETER Name
			Name for files.

		.PARAMETER Destination
			Destination directory renamed files will be placed in.

		.PARAMETER Filter
			Regex filter to search by for files to organize.
			Use to only organize only certain files, instead of the full contents of the source folders.

		.EXAMPLE
			PS C:\>Group-Item -Path $PWD\Input\*.jpg -Destination $PSScriptRoot\Output -Name 'July'

			Output: July (0001).jpg, July (0002).jpg, July (0003).jpg

			Organize single folder.

		.EXAMPLE
			PS C:\>Group-Item -Path $PWD\Input\*.jpg,$PWD\Input2\*.png -Destination $PSScriptRoot\Output -Name 'Canyon Trip'

			Output: Canyon Trip (0001).jpg, Canyon Trip (0002).jpg, Canyon Trip (0003).jpg Canyon Trip (0004).png, Canyon Trip (0005).png, Canyon Trip (0006).png

			Organize multiple folders.

		.EXAMPLE
			PS C:\>Get-Content Folders.txt | Group-Item -Destination $PSScriptRoot\Output -Name 'Mom'

			Output: Mom (0001).jpg, Mom (0002).jpg, Mom (0003).jpg, Mom (0004).png, Mom (0005).png, Mom (0006).png

			Organize multiple folders via pipeline.

		.EXAMPLE
			PS C:\>Group-Item -Path $PWD\Input\*.docx -Destination $PSScriptRoot\Output -Name Journal -Filter 'Page*'

			Output: Journal (0001).docx, Journal (0002).docx, Journal (0003).docx

			Organize items with a filter.
	#>
	[CmdletBinding(SupportsShouldProcess=$True)]
	param(
		[Parameter(Mandatory,ValueFromPipeline)]
		[String]$Path,

		[Parameter(Mandatory)]
		[string]$Name,

		[Parameter(Mandatory)]
		[string]$Destination,

		[string]$Filter = '.'
	)
	begin {
		Write-Verbose -Message 'Beginning sorting...'
	}
	process {
		# foreach allows script to run with multiple directory input.
		foreach($Directory in $Path) {
			# Create essential folders & move files.
			Write-Verbose -Message 'Searching for and grouping files.'
			Get-ChildItem $Directory\* -File -Filter "$Filter" | Move-Item -Destination $Destination

			# Check for missing numbers in the list of files. If found, fix the gap in numbers.
			if ([System.Int32[]]$IterationGap = Get-ChildItem "$Destination\*" | Where-Object{$_.Name -match '\d{4}'} | ForEach-Object{$Matches[0]}) {
				$GapNumber = 1..$IterationGap[-1] | Where-Object{$_ -notin $IterationGap} | Select-Object -First 1
				if ($GapNumber) {
					Get-ChildItem $Destination\* -File | Sort-Object -Property CreationTime,BaseName | Select-Object -Skip ($GapNumber - 1) | ForEach-Object {
						Write-Debug -Message "Working on file $_."
						Rename-Item $_ -NewName ("$Name ({0:D4}){1}" -f $GapNumber++, $_.extension) -Verbose:($VerbosePreference -eq 'Continue')
						Write-Debug -Message "Iteration is now $GapNumber."
					}
				}
			}

			# Check for existing iteration, if it exists.
			Write-Verbose -Message 'Searching for iteration...'
			# Regex: \(\d{4}\) Finds all file names with the pattern of (0001), or another number along those lines. 4 Digits in parentheses.
			$IterationString = Get-ChildItem "$Destination\*" | Where-Object{$_.Name -match "$Name \(\d{4}\)"} | Where-Object{$_.Name -match '\d{4}'} | ForEach-Object{$Matches[0]} | Select-Object -Last 1
			if ($IterationString) {
				$Iteration = [int]$IterationString
				$Iteration++
			}
			else {$Iteration = 1}

			# Rename files according to the pattern.
			Write-Debug -Message "Starting file count with $Iteration."
			Get-ChildItem $Destination\* -File | Where-Object {$_.Name -notmatch "$Name` \(\d{4}\)"} | Sort-Object -Property CreationTime,BaseName | ForEach-Object {
				Write-Debug -Message "Working on file $_."
				Rename-Item $_ -NewName ("$Name ({0:D4}){1}" -f $Iteration++, $_.extension) -Verbose:($VerbosePreference -eq 'Continue')
				Write-Debug -Message "Iteration is now $Iteration."
			}
		}
	}

	end {
		Write-Verbose -Message 'Organization complete.'
		Write-Output -InputObject (Get-ChildItem $Destination\* -File)
	}
}

$GameData = Import-Csv -Path "$PSScriptRoot\Database.csv"
$GameData | ForEach-Object {
	$RenameImageArguments = @{
		Path = $_.Path
		Destination = "$Output" + '\' + $_.Name
		Name = $_.Name
		Filter = $_.Filter + '.jpg'
	}
	# Standardize names of jpg files.
	Write-Verbose -Message 'Renaming .jfif & .jpeg files to .jpg.'
	Get-ChildItem ( $_.Path + '\*' ) -Include ('*.jfif', '*.jpeg') | Rename-Item -NewName { $_.Name -Replace '\.(jfif|jpeg)$', '.jpg' }

	# Create output and backup folders, then back up the original images.
	Write-Verbose -Message 'Creating output directory.'
	New-Item -ItemType Directory -Force -Path ( "$Output" + '\' + $_.Name ) | Out-Null
	Write-Verbose -Message 'Creating backup directory.'
	New-Item -ItemType Directory -Force -Path ( "$Backup" + '\' + $_.Name ) | Out-Null
	Get-ChildItem ( $_.Path + '\*' ) | Copy-Item -Destination ( "$Backup" + '\' + $_.Name )

	# Convert images to jpg, remove the originals, then move the output to the proper folder.
	Get-ChildItem ( $_.Path + '\*' ) -Exclude '*.jpg','*.mkv','*.mp4' | Export-JPG
	Get-ChildItem ( $_.Path + '\*' ) -Exclude '*.jpg','*.mkv','*.mp4' | Remove-Item
	Get-ChildItem ( $_.Path + '\*' ) -Include '*.jpg','*.mkv','*.mp4' | Move-Item -Destination ("$Output" + '\' + $_.Name)

	# Rename images to match the pattern 'Name (0001).jpg', 'Name (0002).jpg', and so on.
	Group-Item @RenameImageArguments
}