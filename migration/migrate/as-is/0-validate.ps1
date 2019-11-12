. ".\environment.ps1"

Add-Type -Path "$PSScriptRoot\Microsoft.SharePoint.Client.dll" 
Add-Type -Path "$PSScriptRoot\Microsoft.SharePoint.Client.Runtime.dll"

if($null -eq $endIndex) {
    Write-Host "check environment.ps1, missing endIndex" -ForegroundColor Yellow
    break
}

function checkIfWebExists($url) {
    $clientContext = New-Object Microsoft.SharePoint.Client.ClientContext($url);
    $clientContext.RequestTimeout = 5000
    $currentWeb = $clientContext.Web;
    $lists = $currentWeb.Lists
    $clientContext.Load($currentWeb)
    
    try
    {
        $clientContext.ExecuteQuery();
        Write-Host " OK" -ForegroundColor Green 
    } 
    catch
    {
        Write-Host " $url does not exist" -ForegroundColor Red
    }
}

Write-Host "Processing ($startIndex-$endIndex)" -ForegroundColor Green
$input = Import-Csv -Path $inputFile

$i = 1
foreach($line in $input) 
{
   if($i -lt $startIndex)
   {
        $i++
        continue
   }

   $url = $line.SiteURL

   Write-Host "[$i / $endIndex] $url" -NoNewline -ForegroundColor Yellow
   checkIfWebExists $url

   if($i++ -ge $endIndex) 
   {
        Write-Host "break because of endIndex limit" -ForegroundColor Red
        break
   }
}