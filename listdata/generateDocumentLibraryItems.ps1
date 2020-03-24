# This powerhell script will fill a SharePoint document library with random documents and random properties
# You need to install https://github.com/pnp/PnP-PowerShell first to make it work.
#
# Author: Jurjan Brust

# Change these variables to your own needs
$itemsToCreate = 10
$credentials = "Name of your credential in the windows credentialstore" # credentials are stored in the windows credentialstore
$words = "Airplay","Cyanide","Cyborgs","Cycloon","Dynamos","Gameboy","Hyacint","Hydraat","Hydrant","Moyenne","Penalty","Symbool","Typeren","Yoghurt","Cylinder","Cytosine","Monotype","Mysterie","Royement","Typenaam","Typering","Baxters","Complex","Excerpt","Exogeen","Exogene","Experts","Laxeren","Lexicon","Mailbox","Mentrix","Mixture","Sextant","Textiel","Xylitol","Xanthoom","Xenofiel","Xenofobe","Xenofoob","Xenomani","Cabaret","Centers","Cesuren","Chianti","Chinees","Clement","Collage","Collega","Curator","Decente","Lactose","Lichter","Locatie","Narcose","Scanner","Sociale","Calvados","Cassette","Ceintuur","Checkbox","Cynische","Delicaat","Scenario","Antiqua","Aquarel","Aquaria","Aquavit","Attaque","Cliques","Croquet","Enquete","Equator","Exquise","Jacquet","Kumquat","Liquide","Quanten","Queeste","Queueen","Quotums","Requiem","Tequila","Adequaat","Aquaduct","Aquanaut","Aquarium","Aquastop","Aquavion","Attaques","Calqueer","Choquant","Claqueur","Craquele","Frequent","Quartole","Quotejes","Quoteert","Quoteren"
$user = "set your user user@domain.nl"
$url = "url of the web"
$listName = "name of the list"
$contentTypeName = "name of the contenttype"
$debug = $false

function GetAllTermsRecursive($terms)
{
    $termIdList = @()
    ForEach($item in $terms)
    {
        if($item.TermsCount -gt 0) {
            GetAllTermsRecursive $item.Terms
        } else {
            $termIdList += $item.Id
            if($debug) { Write-Host "$($item.Id)-$($item.Name)" }
        }
    }
    return $termIdList
}

Connect-PnPOnline $url -Credentials $credentials -UseAdfs -NoTelemetry -ErrorAction Stop

$list = Get-PnPList -Identity $listName
if($null -ne $list) {
    Write-Host "Opened list" $list.Title -ForegroundColor Red -BackgroundColor Yellow
} else {
    Write-Host "No list found"
    break
}

$contenttype = Get-PnPContentType -List $listName | Where-Object {$_.Name -eq $contentTypeName}
if($null -eq $contenttype) {
    Write-Host "No $contenttype ContentType available on the list" -ForegroundColor Red
    Get-PnPContentType -List $listName | ForEach-Object { Write-Host "Available contenttype: " $_.Name -ForegroundColor Green }
    break;
}

Get-PnPproperty -clientobject $contenttype -property "Fields" | Out-Null

Write-Host "Using ContentType: $($contenttype.Name)" -ForegroundColor Green
if($debug) {
    $contenttype.Fields | ForEach-Object {
        Write-Host $_.Title -ForegroundColor Green -NoNewline
        Write-Host " " $_.InternalName -ForegroundColor Yellow -NoNewline
        Write-Host " " $_.TypeAsString -ForegroundColor Red
    }
    break
}

for($index = 1; $index -lt $itemsToCreate+1; $index++) {
    $randomText = $words | Get-Random -count 1
    $randomNr = Get-Random -Minimum 10000 -Maximum 99999
    $titleText = "$randomNr-$randomText"
    $fileName = "$($titleText).$($fileExtension)"

    $spprops = @{}
    $taxFields = @{}

    $contenttype.Fields | Where-Object { -Not $_.InternalName.StartsWith("_") } | ForEach-Object {
        if($_.InternalName -eq "Title") {
            
            $spprops[$_.InternalName] = $titleText
        }
        if($_.InternalName -ne "Title" -and $_.TypeAsString -eq "Text" -or ($_.TypeAsString -eq "Note" -and $_.Hidden -eq $false)) {
            # hidden - false -> make sure we do not set hidden taxfields
            $spprops[$_.InternalName] = $randomText
        }
        if($_.TypeAsString -eq "User") {
            $spprops[$_.InternalName] = $user
        }
        if($_.TypeAsString -eq "Choice") {
            $spprops[$_.InternalName] = $_.Choices | Get-Random -Count 1
        }
        if($_.TypeAsString -eq "DateTime") {
            $days = Get-Random -Minimum -100 -Maximum 100
            $spprops[$_.InternalName] = [System.DateTime]::Now.AddDays($days)
        }
        if($_.TypeAsString -eq "TaxonomyFieldType") {
            $terms = Get-PnPTerm -TermSet $_.TermSetId -TermGroup $_.Group -IncludeChildTerms -Recursive 
            $results = GetAllTermsRecursive $terms
            $randomTerm =  $results | Get-Random -Count 1
            $taxFields[$_.InternalName] = $randomTerm
        }
        if($_.TypeAsString -eq "TaxonomyFieldTypeMulti" -and $_.InternalName -ne "TaxKeyword") {
            $terms = Get-PnPTerm -TermSet $_.TermSetId -TermGroup $_.Group -IncludeChildTerms -Recursive -ErrorAction Continue
            $results = GetAllTermsRecursive $terms
            $randomTerm =  $results | Get-Random -Count 1
            if($randomTerm -ne $null) {
                $taxFields[$_.InternalName] = $randomTerm
            }
        }

        if($($spprops[$_.InternalName]) -ne $null) {
            Write-Host "$($_.InternalName):" -NoNewline -ForegroundColor Red
            Write-Host "$($spprops[$_.InternalName])" -ForegroundColor Yellow
        }
    }
    $file = Add-PnPFile -Path $filePath -Folder $list.EntityTypeName -NewFileName $fileName -Values $spprops 
    if($null -ne $file) {
        Write-Host "Added List item: $($file.ListItemAllFields.Id) - $($file.Title)" -ForegroundColor Green

        # I was unable to set the taxonomy fields directly, so I do it here by using Set-PnpTaxonomyFieldValue
        foreach ($h in $taxFields.GetEnumerator()) {
            Write-Host "Setting Taxfield: "  -ForegroundColor Green -NoNewline
            Write-Host "$($h.Name) - $($h.Value)" -ForegroundColor Yellow
            Set-PnPTaxonomyFieldValue -ListItem $file.ListItemAllFields -InternalFieldName $h.Name -TermId  $h.Value
        }
    }
}

Write-Host "Done!" -ForegroundColor Green
