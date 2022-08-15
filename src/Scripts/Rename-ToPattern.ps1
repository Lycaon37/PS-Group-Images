Set-StrictMode -Version 3.0
#Requires -Version 5.1

# Rename files to match the pattern of a name, followed by a four digit number in parentheses.
# Example: "Test (0001)", "Test (0002)".

[string]$Name = Read-Host -Prompt "What name would you like the files to follow?"
[string]$Destination = Read-Host -Prompt "Where are the files you would like to rename?"

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