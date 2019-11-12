. ".\environment.ps1"

if ($null -eq $endIndex) {
    Write-Host "check environment.ps1, missing endIndex" -ForegroundColor Yellow
    break
}

if ($null -eq $dstSiteUrl) {
    Write-Host "check environment.ps1, missing dstSiteUrl" -ForegroundColor Yellow
    break
}

$input = [Array](Import-Csv -Path $inputFile)
$dstSite = Connect-Site -Url $dstSiteUrl -Browser

$i = 1
foreach ($line in $input) {
    if ($i -lt $startIndex) {
        $i++
        continue
    }
    
    $url = $line.SiteUrl
    $projectNr = $url.split("/")[-1]
    Write-Host "$i-$endIndex [$url] -> [$dstSiteUrl/$projectNr]" -ForegroundColor DarkGray
    
    $srcSite = Connect-Site -Url $url

    $mappings = New-MappingSettings	
    Import-UserAndGroupMapping -MappingSettings $mappings -Path "$(Get-Location)\UserAndGroupMappings.sgum" | Out-Null
    Import-SiteTemplateMapping -MappingSettings $mappings -Path "$(Get-Location)\SiteTemplateMappings.sgwtm" | Out-Null
    Import-PermissionLevelMapping -MappingSettings $mappings -Path "$(Get-Location)\PermissionLevelMappings.sgrm" | Out-Null

    Write-Host $(Get-Date -Format "dddd MM/dd/yyyy HH:mm") -ForegroundColor White

    $copysettings = New-CopySettings -OnContentItemExists Skip -OnSiteObjectExists Skip

    $result = Copy-Site -MappingSettings $mappings -CopySettings $copysettings -Site $srcSite -DestinationSite $dstSite -NoCustomPermissions -NoWorkflows -NoSiteFeatures #-NoContent #-NoCustomizedFormsAndViews -NoNavigation
    Write-Host " Errors:" $result.Errors "Warnings:" $result.Warnings "Copied:" $result.ItemsCopied

    Write-Host $(Get-Date -Format "dddd MM/dd/yyyy HH:mm") -ForegroundColor White

    $statusMessage = "OK"
    if ($result.Warnings -gt 0) {
        $statusMessage = "Warning"
        Write-Host "Warning during copy" -ForegroundColor Yellow
    }
    if ($result.Errors -gt 0) {
        $statusMessage = "ERROR"
        Write-Host "Error during copy" -ForegroundColor Red
    }

    $filename = "$($i)-$($statusMessage).csv"
    Export-Report $result -Path "./log/$filename" -Overwrite | Out-Null

    Write-Host "Showing logfile errors and warnings ./log/$filename" -ForegroundColor Green
    $input = Import-Csv "./log/$filename"

    $input | ForEach-Object {
        if ($_.Status -eq "Error") {
            Write-Host "Error [$($_.Title)]" -NoNewline -ForegroundColor Magenta
            Write-Host $_.Details -ForegroundColor Red

        }
        if ($_.Status -eq "Warning") {
            Write-Host "Warning [$($_.Title)]" -NoNewline -ForegroundColor Magenta
            Write-Host $_.Details -ForegroundColor Yellow
        }

    }

    Write-Host
    if ($i++ -ge $endIndex) {
        Write-Host "break because of endIndex limit" -ForegroundColor DarkYellow
        break
    }
}
