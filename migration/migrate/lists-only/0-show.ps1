. ".\environment.ps1"

if ($null -eq $endIndex) {
    Write-Host "check environment.ps1, missing endIndex" -ForegroundColor Yellow
    break
}

if ($null -eq $dstSiteUrl) {
    Write-Host "check environment.ps1, missing dstSiteUrl" -ForegroundColor Yellow
    break
}

$input = [Array](Import-Csv -Path $listsFile)

$i = 1
foreach ($line in $input) {
    if ($i -lt $startIndex) {
        $i++
        continue
    }

    $url = $line.Url
    $url2 = $line.ListName
    Write-Host "$i-$endIndex [$url] -> [$url2]" -ForegroundColor DarkGray

    if ($i++ -ge $endIndex) {
        Write-Host "break because of endIndex limit" -ForegroundColor DarkYellow
        break
    }
}
