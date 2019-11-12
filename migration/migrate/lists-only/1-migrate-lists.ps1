. ".\environment.ps1"

if ($null -eq $endIndex) {
    Write-Host "check environment.ps1, missing endIndex" -ForegroundColor Yellow
    break
}

$input = [Array](Import-Csv -Path $listsFile)
$sites = [Array](Import-Csv -Path $sitesFile)

$i = 1
foreach ($line in $input) {
    if ($i -lt $startIndex) {
        $i++
        continue
    }
    
    $url = $line.Url
    $dstSiteUrl = $sites | Where-Object { $_.SourceUrl -eq $url }

    if ($null -eq $dstSiteUrl) {
        Write-Host "Destination URL not found"
        break
    }
    $dstSiteUrl = $dstSiteUrl.DestURL
    Write-Host "$i-$endIndex["$url/$($line.ListName)"] -> ["$dstSiteUrl"]" -ForegroundColor DarkGray -NoNewline

    $srcSite = Connect-Site -Url $url
    $dstSite = Connect-Site -Url $dstSiteUrl
    $srcList = Get-List -Site $srcSite -name $line.ListName
    if ($null -eq $srcList) {
        Write-Host "Source list not found"
        break
    }

    $mappings = New-MappingSettings	
    Import-UserAndGroupMapping -MappingSettings $mappings -Path "$(Get-Location)\UserAndGroupMappings.sgum" | Out-Null

    $copysettings = New-CopySettings -OnContentItemExists Skip
    $result = Copy-List -List $srcList -DestinationSite $dstSite -CopySettings $copysettings -MappingSettings $mappings
    Write-Host " Errors:" $result.Errors "Warnings:" $result.Warnings "Copied:" $result.ItemsCopied

    $statusMessage = "OK"
    if ($result.Warnings -gt 0) {
        $statusMessage = "Warning"
        Write-Host "Warning during copy" -ForegroundColor Yellow
    }
    if ($result.Errors -gt 0) {
        $statusMessage = "ERROR"
        Write-Host "Error during copy" -ForegroundColor Red
    }

    $filename = "$i-$($statusMessage).csv"
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

    if ($i++ -ge $endIndex) {
        Write-Host "break because of endIndex limit" -ForegroundColor DarkYellow
        break
    }
}
