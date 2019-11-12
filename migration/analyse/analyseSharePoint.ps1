Param(
    [Parameter(Mandatory = $True, Position = 0)] [string]$url,
    [Parameter(Mandatory = $True, Position = 1)] [string]$outputFolderName
)

$ScriptDir = Split-Path $script:MyInvocation.MyCommand.Path
Add-Type -Path "$ScriptDir\Microsoft.SharePoint.Client.dll" 
Add-Type -Path "$ScriptDir\Microsoft.SharePoint.Client.Runtime.dll"

$clientContext = New-Object Microsoft.SharePoint.Client.ClientContext($url);

enum Options {
    lists = 1
    items = 2
    workflows = 3
    itemCount = 4
    largeFiles = 5
    versions = 6
}

function getQuery() {
    Param (
        [Parameter(Mandatory = $true, Position = 0)] [Options]$function,
        [Parameter(Mandatory = $false, Position = 1)] [string]$searchPattern
    )
    if ($searchPattern -ne "") {
        # query filenames containing $searchPattern
        $query = "<View Scope='Recursive'>
                    <Query>
                        <Where>
                            <Contains>
                                <FieldRef Name='FileLeafRef' /><Value Type='Text'>$searchPattern</Value>
                            </Contains>
                        </Where>
                    </Query>
                  </View>"
    }
    else {
        # query all list items
        $query = "<View Scope='Recursive'>
                     <Query>
                     </Query>
                  </View>"
    }

    # find large files that exceed the 'configured' max size of the destination SharePoint farm.
    if ($function -eq [Options]::largeFiles) {
        $sizeInMB = 1024 * 1024 * 250  
        $query = "<View Scope='Recursive'>
                    <Query>
                        <Where>
                            <Gt>
                                <FieldRef Name='File_x0020_Size' /><Value Type='Text'>$sizeInMB</Value>
                            </Gt>
                        </Where>
                    </Query>
                   </View>"
    }
    return $query
}

# export listnames, itemcount and basetemplates. Also shows lastmodified date.
function lists() {

    $output = @();
    $lists = $currentWeb.Lists
    $clientContext.Load($lists)
    $clientContext.ExecuteQuery()

    foreach ($list in $lists) {
        
        Write-Host "[" $list.ItemCount "] " -NoNewline
        Write-Host $list.Title -ForegroundColor Yellow -BackgroundColor DarkGray -NoNewline
        Write-Host " " $url$($currentWeb.ServerRelativeUrl) -ForegroundColor Green -BackgroundColor DarkRed

        $o = new-object psobject
        $o | Add-Member -MemberType noteproperty -Name "Url" -value $url;
        $o | Add-Member -MemberType noteproperty -Name "Web_Title" -value $currentWeb.Title;
        $o | Add-Member -MemberType noteproperty -Name "Web_Url" -value $currentWeb.ServerRelativeUrl;
        $o | Add-Member -MemberType noteproperty -Name "Web_Creation_Date" -value $currentWeb.Created;
        $o | Add-Member -MemberType noteproperty -Name "Web_Last_Item_Modified" -value $currentWeb.LastItemModifiedDate;
        $o | Add-Member -MemberType noteproperty -Name "ListName" -value $list.Title;
        $o | Add-Member -MemberType noteproperty -Name "List_BaseType" -value $list.BaseType;
        $o | Add-Member -MemberType noteproperty -Name "List_BaseTemplate" -value $list.BaseTemplate;
        $o | Add-Member -MemberType noteproperty -Name "List_ItemCount" -value $list.ItemCount;
        $o | Add-Member -MemberType noteproperty -Name "List_LastItemModifiedDate" -value $list.LastItemModifiedDate;
        $output += $o;
    }
    
    if ($null -ne $output) {
        saveToFile $output
    }
}

# track down workflows, workflows are a strong indication of user customizations
function workflows() {

    $output = @();
    $lists = $currentWeb.Lists
    $clientContext.Load($lists)
    $clientContext.ExecuteQuery()

    foreach ($list in $lists) {
        $wfa = $list.WorkflowAssociations
        $clientContext.Load($wfa)
        $clientContext.ExecuteQuery()

        foreach ($wf in $wfa) {
            Write-Host "[" $wf.Name "]" -NoNewline
            Write-Host $list.Title -ForegroundColor Yellow -BackgroundColor DarkGray -NoNewline
            Write-Host $wf.Created -ForegroundColor Green -BackgroundColor DarkGray -NoNewline
            Write-Host $wf.Modified -ForegroundColor Green -BackgroundColor DarkRed

            $o = new-object psobject
            $o | Add-Member -MemberType noteproperty -Name WorkflowName -value $wf.Name;
            $o | Add-Member -MemberType noteproperty -Name Created -value $wf.Created;
            $o | Add-Member -MemberType noteproperty -Name Modified -value $wf.Modified;
            $o | Add-Member -MemberType noteproperty -Name ListTitle -value $list['Title'];
            $o | Add-Member -MemberType noteproperty -Name ListURL -value $list.DefaultDisplayFormUrl;
            $output += $o;
        }
    }
    
    if ($null -ne $output) {
        saveToFile $output
    }
}

# general purpose function to find files with a matching $pattern in their filenames. Example: '.js', 'xsn'
function listItems() {
    Param (
        [Parameter(Mandatory = $true, Position = 0)] [Options]$function,
        [Parameter(Mandatory = $false, Position = 1)] [string]$searchPattern,
        [Parameter(Mandatory = $false, Position = 2)] [string]$listBaseType
    )

    $output = @();
    $lists = $currentWeb.Lists
    $clientContext.Load($lists)
    $clientContext.ExecuteQuery()

    # optional filtering on base list type
    if ($listBaseType -ne "") {
        $lists = $lists | Where-Object { $_.BaseType -eq $listBaseType }
    }

    $query = New-Object Microsoft.SharePoint.Client.CamlQuery;
    $query.ViewXml = getQuery $function $searchPattern

    foreach ($list in $lists) {
        $listItems = $list.GetItems($query);
        $clientContext.Load($listItems);
        $clientContext.ExecuteQuery();
        $nrOfItemsFound = "{0:0000}" -f $listItems.Count
        
        if ($listItems.Count -gt 0) {
            Write-Host "[" $nrOfItemsFound "] " -NoNewline -ForegroundColor Green
        }
        else {
            Write-Host "[" $nrOfItemsFound "] " -NoNewline
        }
        
        Write-Host $currentWeb.Title -ForegroundColor Yellow -BackgroundColor DarkGray -NoNewline
        Write-Host " " -NoNewline
        Write-Host $list.Title -ForegroundColor Yellow -BackgroundColor DarkGreen -NoNewline
        Write-Host " " -NoNewline
        Write-Host $list.DefaultDisplayFormUrl -ForegroundColor Green -BackgroundColor DarkRed
        
        foreach ($listItem in $listItems) {
            $o = new-object psobject
            $o | Add-Member -MemberType noteproperty -Name url -value $url;
            $o | Add-Member -MemberType noteproperty -Name FileRef -value $listItem['FileRef'];
            $o | Add-Member -MemberType noteproperty -Name FileDirRef -value $listItem['FileDirRef'];
            $o | Add-Member -MemberType noteproperty -Name FileLeafRef -value $listItem['FileLeafRef'];
            $o | Add-Member -MemberType noteproperty -Name Modified_x0020_By -value $listItem.FieldValues.Modified_x0020_By
            $o | Add-Member -MemberType noteproperty -Name Last_x0020_Modified -value $listItem.FieldValues.Last_x0020_Modified
            $o | Add-Member -MemberType noteproperty -Name "SizeMegaBytes" -value $([convert]::ToInt32($listItem['File_x0020_Size'], 10) / (1024 * 1024))

            # only execute if versions are to be analysed, because this is a timeconsuming operation
            if ($function -eq [Options]::versions) {
                $file = $listItem.File
                $clientContext.Load($file)
                $clientContext.ExecuteQuery();

                $versions = $file.Versions
                $clientContext.Load($versions)
                $clientContext.ExecuteQuery();

                $o | Add-Member -MemberType noteproperty -Name "Versions" -value $versions.Count;
                #only output to file if there are multiple versions
                if ($versions.Count -gt 0) {
                    $output += $o;
                }
            }
            else {
                $output += $o;
            }
        }
    }
    if ($null -ne $output) {
        saveToFile $output
    }
}

function saveToFile([object]$lines) {
    $a = Get-Date
    $lines | export-csv "$outputFolderName\Export_$($a.Ticks).csv" -noTypeInformation;
}

function export() {
    Param (
        [Parameter(Mandatory = $true, Position = 0)] [Options]$function,
        [Parameter(Mandatory = $false, Position = 1)] [string]$searchPattern,
        [Parameter(Mandatory = $false, Position = 2)] [switch]$recursive
    )

    Write-Host "[$($childWebs.Count) sub websites] [$($currentWeb.ServerRelativeUrl)]" -ForegroundColor Red -BackgroundColor Yellow

    try {
        switch ($function) {
            ([Options]::items) { listItems -function $function -searchPattern $searchPattern; break }
            ([Options]::largeFiles) { listItems -function $function -listBaseType "DocumentLibrary"; break }
            ([Options]::versions) { listItems -function $function -listBaseType "DocumentLibrary"; break }
            ([Options]::workflows) { workflows; break }
            ([Options]::lists) { lists; break }
            
            default {
                Write-Host "Invalid function" -ForegroundColor Red
            }
        }
    }
    catch { Write-Host $_.Exception.Message -ForegroundColor Red }

    if ($recursive) {
        foreach ($web in $childWebs) {
            $currentWeb = $web;
            $childWebs = $currentWeb.Webs
            $clientContext.Load($childWebs)
            $clientContext.ExecuteQuery()
            export $function $searchPattern $recursive;
        }
    }
}

$currentWeb = $clientContext.Web;
$childWebs = $clientContext.Web.Webs
$clientContext.Load($currentWeb)
$clientContext.Load($childWebs)
$clientContext.ExecuteQuery()

## use -recursive to incude all subsites

#### infopath is a big indication of customization
#export -function ([Options]::items) -searchPattern ".xsn" #-recursive

#### javascript: javascipt is a big indication of customization
#export -function ([Options]::items) -searchPattern ".js" #-recursive

#### workflows: workflows are a big indication of customizations
#export -function ([Options]::workflows) #-recursive

#### lists information gives insight into
# - itemcount
# - list base types (for example kpi lists)
export -function ([Options]::lists) -recursive

# large files: find files larger than destination limit : 250 is default for onprem
#export -function ([Options]::largeFiles) #-recursive

# versions: document versions can take up a lot of space, especially for non-office documents. track down these files and limit the number of versions if possible.
#export -function ([Options]::versions) #-recursive
