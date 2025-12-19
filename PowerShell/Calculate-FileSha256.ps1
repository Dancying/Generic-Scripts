#
# PowerShell Script to calculate the SHA256 values of files in a directory
# Author: Gemini, Dancying
# Version: 1.0
#

$OutputFileName = "SHA256_Checksums.txt"
$SourceDirectory = Read-Host "Please enter the full directory path (e.g., D:\Markdown)"
$SourceFiles = Get-ChildItem -Path $SourceDirectory -File | Where-Object { $_.Name -ne $OutputFileName }
$TotalFiles = $SourceFiles.Count

if ($TotalFiles -eq 0) {
    Write-Host "Warning: No eligible files found. Exiting script." -ForegroundColor Yellow
    exit 1
}

Write-Host "Processing $($TotalFiles) files..." -ForegroundColor Cyan

# Initialize progress bar counter
$Counter = 0

# Calculation and Collection Assignment
$OutputLines = foreach ($File in $SourceFiles) {
    $Counter++
    
    # Update progress bar
    Write-Progress -Activity "Calculating SHA256 Hashes" `
                   -Status "Processing file $Counter of $TotalFiles..." `
                   -PercentComplete (($Counter / $TotalFiles) * 100) `
                   -CurrentOperation "$($File.Name)"

    # Calculate Hash (ErrorAction Stop ensures immediate failure if file is locked/inaccessible)
    $Hash = (Get-FileHash -LiteralPath $File.FullName -Algorithm SHA256 -ErrorAction Stop).Hash
    
    # Output formatted string for collection
    "$Hash    $($File.Name)"
}

# Clear progress bar
Write-Progress -Activity "Calculating SHA256 Hashes" -Completed

# Final Output (Write array to file)
$OutputFile = Join-Path -Path $SourceDirectory -ChildPath $OutputFileName
$OutputLines | Out-File -FilePath $OutputFile -Encoding UTF8 -Force

Write-Host "Success! SHA256 values have been calculated and saved to: $OutputFile" -ForegroundColor Green

Read-Host "Press Enter to exit."
