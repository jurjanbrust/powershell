param(
    [Parameter(Mandatory = $False, Position = 1)] [string]$siteUrlOnPrem,
    [Parameter(Mandatory = $False, Position = 2)] [string]$siteUrlOnline,
    [Parameter(Mandatory = $False, Position = 3)] [string]$listTitle
)

Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass

Add-Type -Path "$PSScriptRoot\Microsoft.SharePoint.Client.dll" 
Add-Type -Path "$PSScriptRoot\Microsoft.SharePoint.Client.Runtime.dll"

function getAllListItems($_ctx, $_listName, $_rowLimit) {
    $list = $_ctx.Web.Lists.GetByTitle($_listName)
    $_ctx.Load($list)

    $query = New-Object Microsoft.SharePoint.Client.CamlQuery
    $query.ViewXml = "<View Scope='RecursiveAll'>
        <RowLimit>$_rowLimit</RowLimit>
    </View>"

    $items = @()
    do {
        $listItems = $list.getItems($query)
        $_ctx.Load($listItems)
        $_ctx.ExecuteQuery()
        $query.ListItemCollectionPosition = $listItems.ListItemCollectionPosition

        foreach ($item in $listItems) {
            $items += $item
        }
        Write-Host "Getting next batch of $_rowLimit"
    }
    While ($null -ne $query.ListItemCollectionPosition)

    return $items
}

# SharePoint Online (destination)
$clientContext = New-Object Microsoft.SharePoint.Client.ClientContext($siteUrlOnline)
$userCredentials = Get-Credential
$userName = $userCredentials.UserName
$securePassword =  $userCredentials.Password
$credentials = New-Object Microsoft.SharePoint.Client.SharePointOnlineCredentials($userName, $securePassword)  
$clientContext.Credentials = $credentials  

if (!$clientContext.ServerObjectIsNull.Value) {  
    Write-Host "Connected to SharePoint Online site: '$siteUrlOnline'" -ForegroundColor Green  
}

$theitemsonline = getAllListItems $clientContext $listTitle 2000  # get listitems in batches of 2000 (needed for large lists). Adjust 2000 to your own needs.
Write-Host $theitemsonline.Count "items found"
$onlineFiles = @()
foreach ($onlineitem in $theitemsonline) {
    $onlineFiles += $onlineitem["FileLeafRef"]
}

Write-Host "Connected to on-prem site: $siteUrlOnPrem" -ForegroundColor Green

$clientContext = New-Object Microsoft.SharePoint.Client.ClientContext($siteUrlOnPrem)
#$clientContext.Credentials = Get-Credential # optional use other credentials than current user
$currentWeb = $clientContext.Web

$lists = $currentWeb.Lists
$list = $lists.GetByTitle($listTitle) 
$theitemsonprem = getAllListItems $clientContext $listTitle 2000  # get listitems in batches of 2000 (needed for large lists). Adjust 2000 to your own needs.
Write-Host $theitemsonprem.Count "items found"

$onPremFiles = @()
foreach ($onpremitem in $theitemsonprem) {
    $onPremFiles += $onpremitem["FileLeafRef"] 
}

$a = Get-Date
$fileName = $a.Ticks 
$tasks = @()
$i = 0

$differences = Compare-Object $onPremFiles $onlineFiles
Write-Host $differences.Count files are missing, starting export to csv file "'ListCompare_Export_$fileName.csv'" -ForegroundColor Red

$differences | ForEach-Object { 
	$completed = ($i*100)/$differences.Count
    Write-Progress -Activity "Export " -percentComplete $completed; 
    Write-Host $_.SideIndicator $_.InputObject -ForegroundColor DarkYellow

    $inputObjectAsString = $_.InputObject

    if ($_.SideIndicator -eq "<=") {
        Write-Host " missing online: " -ForegroundColor DarkYellow -NoNewLine
        Write-Host $_.SideIndicator $_.InputObject -ForegroundColor DarkYellow
        $theitem = $theitemsonprem | Where-Object {$_["FileLeafRef"] -eq $inputObjectAsString} 
    }

    if ($_.SideIndicator -eq "=>") {
        Write-Host " missing on-prem: " -ForegroundColor DarkYellow -NoNewLine
        Write-Host $_.SideIndicator $_.InputObject -ForegroundColor DarkYellow
        $theitem = $theitemsonline | Where-Object {$_["FileLeafRef"] -eq $inputObjectAsString} 
    }

    if ($theitem -ne $null) {
        $o = new-object psobject
        $o | Add-Member -MemberType noteproperty -Name SideIndicator -value $_.SideIndicator;
        $o | Add-Member -MemberType noteproperty -Name inputObjectAsString -value $inputObjectAsString;
        $o | Add-Member -MemberType noteproperty -Name FileRef -value $theitem["FileRef"];
        $tasks += $o;
    }
    $i++
}

$tasks | export-csv ".\ListCompare_Export_$fileName.csv" -noTypeInformation;