$srcSite = Connect-Site -Url "https://sourcesite" -Browser
$dstSite = Connect-Site -Url "https://destinationsite" -UseCredentialsFrom $srcSite

$result = Copy-Site -Site $srcSite -DestinationSite $dstSite -Merge -WaitForImportCompletion #-Subsites  #-WhatIf #-NoCustomPermissions -NoWorkflows -NoSiteFeatures #-NoContent #-NoCustomizedFormsAndViews -NoNavigation -MappingSettings $mappings
Write-Host " Errors:" $result.Errors "Warnings:" $result.Warnings "Copied:" $result.ItemsCopied

$statusMessage = "OK"
if($result.Warnings -gt 0) 
{
    $statusMessage = "Warning"
    Write-Host "Warning during copy" -ForegroundColor Yellow
}
if($result.Errors -gt 0) 
{
    $statusMessage = "ERROR"
    Write-Host "Error during copy" -ForegroundColor Red
}

$filename = "$($i)-$($statusMessage).csv"
Export-Report $result -Path "./log/$filename" -Overwrite | Out-Null

Write-Host "Showing logfile errors and warnings ./log/$filename" -ForegroundColor Green
$input = Import-Csv "./log/$filename"

$input | ForEach-Object {
    if($_.Status -eq "Error") 
    {
        Write-Host "Error [$($_.Title)]" -NoNewline -ForegroundColor Magenta
        Write-Host $_.Details -ForegroundColor Red

    }
    if($_.Status -eq "Warning") 
    {
        Write-Host "Warning [$($_.Title)]" -NoNewline -ForegroundColor Magenta
        Write-Host $_.Details -ForegroundColor Yellow
    }
}
