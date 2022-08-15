Param(
    [string]$Backup = "$PSScriptRoot\Backup",
	[string]$Output = "$PSScriptRoot\Output"
)

Set-StrictMode -Version 3.0
#Requires -Version 5.1

Function Invoke-Mogrify {
	<#
		.SYNOPSIS
			Convert images to other formats using ImageMagick.

		.DESCRIPTION
			This function will convert given images into the specified format.
			The converted images will be saved to the same location as the original images by default.
			While PowerShell 5.1 is supported, use ofPowerShell 7 is strongly recommended due to a
			large speed increase in image processing times.

		.PARAMETER Path
			Source directory or directories files will be taken from.
			Must be a valid path that exists on the computer.

		.PARAMETER Format
			Target format for images.

		.PARAMETER Destination
			Destination directory converted images will be placed in.

		.PARAMETER Filter
			Regex Filter to search by for files to convert.
			Use to only convert only certain files, instead of the full contents of the source folders.

		.EXAMPLE
			Invoke-Mogrify -Path $PSScriptRoot\Input -Destination $PSScriptRoot\Output -Format PNG

			Convert all pictures from one folder into PNG images.

		.EXAMPLE
			Invoke-Mogrify -Path $PSScriptRoot\Input,~\Gallery,~\user\pictures -Destination $PSScriptRoot\Output -Format jpg

			Convert all pictures from multiple folders into jpg images.
	#>
	[CmdletBinding()]
	param(
		[Parameter(Mandatory,ValueFromPipeline)]
		[string]$Path,

		[Parameter(Mandatory)]
		[string]$Format,

		[string]$Destination = $Path,

		[string]$Filter = '.'
	)
	begin {
		Write-Verbose -Message "Checking for ImageMagick."
		if ($null -eq (Get-Command "magick" -ErrorAction SilentlyContinue)) {
			Throw "ImageMagick not installed. Please install ImageMagick."
		}
		else {
			Write-Verbose -Message "ImageMagick is installed."
		}
	}
	process {
		foreach ($Directory in $Path) {
			Write-Verbose -Message "Renaming .jfif & .jpeg files to .jpg."
			Get-ChildItem $Directory\* -Include ('*.jfif', '*.jpeg') | Rename-Item -NewName { $_.Name -Replace "\.(jfif|jpeg)$", ".jpg" }
			Write-Verbose -Message "Searching for files..."
			Get-ChildItem $Directory\* -Filter "$Filter" -Recurse -Include "*.$Format" | Move-Item -Destination $Destination
		}

		<# ImageMagick normally converts ALL images, even if they are already in the target format.
			This will reduce quality if converting to lossy formats such as jpg.
			ImageMagick does not have a parameter to filter out images, so Where-Object is used.
			This does run about 25% more slowly than sending all images to ImageMagick, unfortunately.
			This can be fixed on systems running at least PowerShell 7,
			as the command can then be run in parallel. #>

		# Still want to support 5.1, so the script will fall back to a slower sequential method when needed.
		Write-Verbose -Message "Converting images to $Format"
		if ($PSVersionTable.PSVersion -ge 7) {
			Get-ChildItem $Path\* | Where-Object {
				$_.Extension -match 'jpg' -or 'png' -or 'heic' -or 'webp' -or 'tiff' -and
				$_.Extension -notmatch "$Format"
			} | Foreach-Object -ThrottleLimit 5 -Parallel {
				magick mogrify -path $USING:Destination -format $USING:Format $_ -define preserve-timestamp=true
			}
		}
		else {
			Get-ChildItem $Path\* | Where-Object {
				$_.Extension -match 'jpg' -or 'png' -or 'heic' -or 'webp' -or 'tiff' -and
				$_.Extension -notmatch "$Format"
			} | ForEach-Object {
				magick mogrify -path $Destination -format $Format $_ -define preserve-timestamp=true
			}
		}
	}
	end {
		Write-Verbose -Message "Images Converted."
		Write-Output -InputObject (Get-ChildItem $Destination\*.$Format -File)
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
			PS C:\>Format-Item -Path $PWD\Input\*.jpg -Destination $PSScriptRoot\Output -Name "July"

			Output: July (0001).jpg, July (0002).jpg, July (0003).jpg

			Organize single folder.

		.EXAMPLE
			PS C:\>Format-Item -Path $PWD\Input\*.jpg,$PWD\Input2\*.png -Destination $PSScriptRoot\Output -Name "Canyon Trip"

			Output: Canyon Trip (0001).jpg, Canyon Trip (0002).jpg, Canyon Trip (0003).jpg Canyon Trip (0004).png, Canyon Trip (0005).png, Canyon Trip (0006).png

			Organize multiple folders.

		.EXAMPLE
			PS C:\>Get-Content Folders.txt | Format-Item -Destination $PSScriptRoot\Output -Name "Mom"

			Output: Mom (0001).jpg, Mom (0002).jpg, Mom (0003).jpg, Mom (0004).png, Mom (0005).png, Mom (0006).png

			Organize multiple folders via pipeline.

		.EXAMPLE
			PS C:\>Format-Item -Path $PWD\Input\*.docx -Destination $PSScriptRoot\Output -Name Journal -Filter "Page*"

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
		Write-Verbose -Message "Beginning sorting..."
	}
	process {
		# foreach allows script to run with multiple directory input.
		foreach($Directory in $Path) {
			# Create essential folders & move files.
			Write-Verbose -Message "Searching for and grouping files."
			Get-ChildItem $Directory\* -File -Filter "$Filter" | Move-Item -Destination $Destination

			# Check for missing numbers in the list of files. If found, fix the gap in numbers.
			if ([System.Int32[]]$IterationGap = Get-ChildItem "$Destination\*" | Where-Object{$_.Name -match "\d{4}"} | ForEach-Object{$Matches[0]}) {
				$GapNumber = 1..$IterationGap[-1] | Where-Object{$_ -notin $IterationGap} | Select-Object -First 1
				if ($GapNumber) {
					Get-ChildItem $Destination\* -File | Sort-Object -Property CreationTime,BaseName | Select-Object -Skip ($GapNumber - 1) | ForEach-Object {
						Write-Debug -Message "Working on file $_."
						Rename-Item $_ -NewName ("$Name ({0:D4}){1}" -f $GapNumber++, $_.extension) -Verbose:($VerbosePreference -eq "Continue")
						Write-Debug -Message "Iteration is now $GapNumber."
					}
				}
			}

			# Check for existing iteration, if it exists.
			Write-Verbose -Message "Searching for iteration..."
			# Regex: \(\d{4}\) Finds all file names with the pattern of (0001), or another number along those lines. 4 Digits in parentheses.
			$IterationString = Get-ChildItem "$Destination\*" | Where-Object{$_.Name -match "$Name \(\d{4}\)"} | Where-Object{$_.Name -match "\d{4}"} | ForEach-Object{$Matches[0]} | Select-Object -Last 1
			if ($IterationString) {
				$Iteration = [int]$IterationString
				$Iteration++
			}
			else {$Iteration = 1}

			# Rename files according to the pattern.
			Write-Debug -Message "Starting file count with $Iteration."
			Get-ChildItem $Destination\* -File | Where-Object {$_.Name -notmatch "$Name` \(\d{4}\)"} | Sort-Object -Property CreationTime,BaseName | ForEach-Object {
				Write-Debug -Message "Working on file $_."
				Rename-Item $_ -NewName ("$Name ({0:D4}){1}" -f $Iteration++, $_.extension) -Verbose:($VerbosePreference -eq "Continue")
				Write-Debug -Message "Iteration is now $Iteration."
			}
		}
	}

	end {
		Write-Verbose -Message "Organization complete."
		Write-Output -InputObject (Get-ChildItem $Destination\* -File)
	}
}

$GameData = Import-Csv -Path "$PSScriptRoot\Database.csv"
$GameData | ForEach-Object {
	$ConvertImageArguments = @{
		Path = $_.Path
		Destination = "$Output" + '\' + $_.Name
		Format = "jpg"
		Filter = $_.Filter
	}
	$RenameImageArguments = @{
		Path = $_.Path
		Destination = "$Output" + '\' + $_.Name
		Name = $_.Name
		Filter = $_.Filter + '.jpg'
	}

	# Create output and backup folders.
	Write-Verbose -Message "Creating output directory."
	New-Item -ItemType Directory -Force -Path ( "$Output" + '\' + $_.Name ) | Out-Null
	Write-Verbose -Message "Creating backup directory."
	New-Item -ItemType Directory -Force -Path ( "$Backup" + '\' + $_.Name ) | Out-Null
	Get-ChildItem ( $_.Path + '\*' ) | Copy-Item -Destination ( "$Backup" + '\' + $_.Name )

	# Convert images to jpg.
	Invoke-Mogrify @ConvertImageArguments

	# Move original images to a backup folder.
	Get-ChildItem ( $_.Path + '\*' ) -Exclude "*.jpg","*.mkv","*.mp4" | Remove-Item

	# Rename images to match the pattern "Game Name (0001).jpg", "Game Name (002).jpg", and so on.
	Group-Item @RenameImageArguments
}