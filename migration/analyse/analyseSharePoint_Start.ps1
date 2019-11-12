$input = [Array](Import-Csv -Path "sites.csv")

# setup output directory
$outputFolderName = ".\output"

if(Test-Path $outputFolderName) {
    Remove-Item $outputFolderName -Verbose -Recurse
}
New-Item -ItemType Directory -Force -Path $outputFolderName
Write-Host "Creating directory $outputFolderName"

foreach($line in $input) 
{
   .\analyseSharePoint.ps1 -url $line.SiteUrl $outputFolderName
}
