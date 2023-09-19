#first time - install
Install-Module -Name MicrosoftPowerBIMgmt

<#
# Verifying if the PowerShell Power BI management module is installed
Write-Host 'Verifying if the PowerShell Power BI management module is installed...'
if (Get-Module -ListAvailable -Name MicrosoftPowerBIMgmt) {
    Write-Host "MicrosoftPowerBIMgmt already installed."
} 
else {
    try {
        Install-Module -Name MicrosoftPowerBIMgmt -AllowClobber -Confirm:$False -Force  
        Write-Host "MicrosoftPowerBIMgmt installed."
    }
    catch [Exception] {
        $_.message 
        exit
    }
}
#>

## Choose your authencication type (1) or (2) and run only that.
# 1.1 fill in client id and secret value or your credentials
$TenantId = Read-Host -Prompt 'Enter the Tenant Id' #where $TenantId is Power BI tenant ID
Connect-PowerBIServiceAccount -ServicePrincipal -Credential (Get-Credential) -Tenant $TenantId 

# 1.2 connect with admin account
Connect-PowerBIServiceAccount | Out-Null #remove | Out-Null if you want to see the output (example below)

<# Usual response would be:
Environment : Public
TenantId    : xxxxxxxx-xxxx-xxxx-xxx-xxxxxxxxxxxx
UserName    : email@domain.onmicrosoft.com
#>






##################################### Create Workspaces #####################################

# 1. create a new workspace (WS)

# https://learn.microsoft.com/en-us/rest/api/power-bi/groups/create-group#code-try-0
#POST https://api.powerbi.com/v1.0/myorg/groups?workspaceV2=True 

$URLCreate =  "https://api.powerbi.com/v1.0/myorg/groups?workspaceV2=True"

$WSName = "The Sickness"

$bodyWS = @"
            {
            "name": "$WSName" 
            }
"@

Invoke-PowerBIRestMethod -Method POST -URL $URLCreate -Body $bodyWS



#### What if a workspace with this name already exists? need to check ####

# 1. Get all WS
# 2. Check if one already exists
# 3. If not, create it


# Get all WS
#https://learn.microsoft.com/en-us/rest/api/power-bi/admin/groups-get-groups-as-admin
#GET https://api.powerbi.com/v1.0/myorg/admin/groups?$top={$top}

$URLGetWS =  "https://api.powerbi.com/v1.0/myorg/admin/groups?%24filter=(name eq '$WSName')&%24top=5000"

$GetWS = Invoke-PowerBIRestMethod -Method GET -URL $URLGetWS

$GetWS | ConvertFrom-JSON

($GetWS | ConvertFrom-JSON).Value #if you want to see result in more convenient way


#### Make it a little bit more sofisticated :) ####

if ( !($GetWS) ) { 
    Invoke-PowerBIRestMethod -Method POST -URL $URLCreate -Body $bodyWS 
    }
else { Write-Host "Workspace already exists" }


#### What if you want to create multiple workspaces?

# Store WS names (can be even a file)
$WSNames = "Believe", "Ten Thousand Fists", "Indestructible", "Asylum"

# Go throufh all names one by one and create a new workspace

$WSNames | ForEach-Object {
    $body = @"
                {
                    "name": "$_"
                }
"@

    Invoke-PowerBIRestMethod -Method POST -URL $URLCreate -Body $body 

    Write-Host "WS '$_' was created"
}


#### Again, what if such workspace already exists? ####

## 1. Delete WS, because we'll run creation loop again

# DELETE https://api.powerbi.com/v1.0/myorg/groups/{groupId}

$WSNames | ForEach-Object {
    # Needs state eq 'Active' because you can see deleted workspaces too
    $URLGetWS2 =  "https://api.powerbi.com/v1.0/myorg/admin/groups?%24filter=(name eq '$_' and state eq 'Active')&%24top=5000"

    $GetWS = (Invoke-PowerBIRestMethod -Method GET -URL $URLGetWS2 | ConvertFrom-JSON).Value

    $WSid = $GetWS.id

    $DeleteUrl = "https://api.powerbi.com/v1.0/myorg/groups/$WSid"
    
    Invoke-PowerBIRestMethod -Method DELETE -URL $DeleteUrl
    
    Write-Verbose "WS '$_' was deleted" -Verbose
}


## 2. Create multiple WS, but if only they don't exist

$WSNames | ForEach-Object {
    
    $URLGetWS =  "https://api.powerbi.com/v1.0/myorg/admin/groups?%24filter=(name eq '$_' and state eq 'Active')&%24top=5000"
    $GetWS = (Invoke-PowerBIRestMethod -Method GET -URL $URLGetWS | ConvertFrom-JSON).Value

    #-ine means not equal and case-insensitive
    if( $_ -ine $GetWS.name) 
        { 
        
            $body = @"
                        {
                            "name": "$_"
                        }
"@

            Invoke-PowerBIRestMethod -Method POST -URL $URLCreate -Body $body | ConvertFrom-JSON

            Write-Verbose "WS '$_' was created" -Verbose
        }
    else { Write-Host "Workspace "$GetWS.name" already exists, so it won't be created." } 
}



###### Maybe you accidently deleted a workspace that is still used - How to RESTORE it? ######

# https://learn.microsoft.com/en-us/rest/api/power-bi/admin/groups-restore-deleted-group-as-admin

# POST https://api.powerbi.com/v1.0/myorg/admin/groups/{groupId}/restore 
<#
{
  "name": "Restored Workspace", #The name of the group to be restored
  "emailAddress": "john@contoso.com" #The email address of the owner of the group to be restored
}
#>

# 0. Delete a workspace
$WSNameToDelete = "TrialPremWS"
$URLGetWS3 =  "https://api.powerbi.com/v1.0/myorg/admin/groups?%24filter=(name eq '$WSNameToDelete')&%24top=5000"
$GetWS3 = (Invoke-PowerBIRestMethod -Method GET -URL $URLGetWS3 | ConvertFrom-JSON).Value
$WSid3 = $GetWS3.id
$DeleteUrl3 = "https://api.powerbi.com/v1.0/myorg/groups/$WSid3"
    
Invoke-PowerBIRestMethod -Method DELETE -URL $DeleteUrl3
    
Write-Verbose "WS '$WSNameToDelete' was deleted" -Verbose

# 1. I'll need a WS Id

$WSNameToRestore = "TrialPremWS"

$URLGetWSForRestoring =  "https://api.powerbi.com/v1.0/myorg/admin/groups?%24filter=(name eq '$WSNameToRestore')&%24top=5000"
$WSIdToRestore = (Invoke-PowerBIRestMethod -Method GET -URL $URLGetWSForRestoring | ConvertFrom-JSON).Value.id

# 2. Restore the WS

$UrlRestore = "https://api.powerbi.com/v1.0/myorg/admin/groups/$WSIdToRestore/restore"

$bodyRestoreWs = @"
                        {
                            "name": "$WSNameToRestore",
                            "emailAddress": "adminOdeta@DragonsData.onmicrosoft.com"
                        }
"@

$restore = Invoke-PowerBIRestMethod -Method POST -URL $UrlRestore -Body $bodyRestoreWs -Verbose




##################################### WS users ##################################### 

#### Check WS users ####

## 1. Get WS ids
# GET https://api.powerbi.com/v1.0/myorg/admin/groups/{groupId}/users

# Eliminating "My Workspace": type eq 'Workspace'
$URLGetAllWS =  "https://api.powerbi.com/v1.0/myorg/admin/groups?%24filter=(state eq 'Active' and type eq 'Workspace')&%24top=5000"
$GetAllWS = (Invoke-PowerBIRestMethod -Method GET -URL $URLGetAllWS | ConvertFrom-JSON).Value

$AllWSIds = $GetAllWS.id

## 2. Get WS users
$users = @()

$AllWSIds | ForEach-Object { 
	    
    $uri = "https://api.powerbi.com/v1.0/myorg/admin/groups/$_/users"

	$a = (Invoke-PowerBIRestMethod -Method GET -URL $uri | ConvertFrom-JSON).Value `
                | Select-Object groupUserAccessRight, emailAddress, displayName

	$a | Add-Member -MemberType NoteProperty -Name "WorkspaceId" -Value $_
	
    $users += $a
    
    Write-Host "Users for WS $_ found" -ForegroundColor DarkRed
}
$users


#### Add Disturbed as a member to all WS that they aren't a part of ####

<#
POST https://api.powerbi.com/v1.0/myorg/admin/groups/{groupId}/users
{
  "emailAddress": "john@contoso.com",
  "groupUserAccessRight": "Admin"
}
#>

# Since WS where Disturbed is a user could have multiple users (multiple rows - dublicated WS ids), 
# we need to get WS Id first and then filter out rows from $users

## 1. Get WS id where Disturbed is a user

$WSIdDisturbed = ($users | Where-Object displayName -eq 'Disturbed').WorkspaceId

##. 2. Get WS ids where Disturbed isn't a user

$WSIds_noDisturbed = ($users | Where-Object WorkspaceId -ne $WSIdDisturbed).WorkspaceId

## 3. Add Disturbed as a Member

$bodyUsers = @"
    {
        "emailAddress": "Disturbed@DragonsData.onmicrosoft.com",
        "groupUserAccessRight": "Member"
    }
"@

$WSIds_noDisturbed | ForEach-Object { 
	    
    $uri = "https://api.powerbi.com/v1.0/myorg/admin/groups/$_/users"
	Invoke-PowerBIRestMethod -Method POST -URL $uri -Body $bodyUsers
	
    Write-Host "Disturbed added as a Member in WS $_"
}

## 4. Check if it worked

$users_noDisturbed = @()

$WSIds_noDisturbed | ForEach-Object { 
	    
    $url = "https://api.powerbi.com/v1.0/myorg/admin/groups/$_/users"
	
    $a = (Invoke-PowerBIRestMethod -Method GET -URL $url | ConvertFrom-JSON).Value `
                | Select-Object groupUserAccessRight, emailAddress, displayName
	
    $a | Add-Member -MemberType NoteProperty -Name "WorkspaceId" -Value $_
	
    $users_noDisturbed += $a
        
    Write-Host "Users for WS $_ found"
}
$users_noDisturbed






##################################### Get User Activities #####################################

#GET https://api.powerbi.com/v1.0/myorg/admin/activityevents?startDateTime={startDateTime}&endDateTime={endDateTime}&continuationToken={continuationToken}&$filter={$filter}

#### Last 30 days Users Activities ####

#Input values before running the script:
$NbrDaysDaysToExtract = 15
#$ExportFileLocation = 'C:\Users\Odeta\Downloads'
#$ExportFileName = 'PBIActivityEventsNonPrem'

#Start with yesterday for counting back to ensure full day results are obtained:
[datetime]$DayUTC = ([datetime]::Today.ToUniversalTime()).Date 

#Loop through each of the days to be extracted (<Initilize> ; <Condition> ; <Repeat>)

$EventsWS = @()
For( $LoopNo=0; $LoopNo -lt $NbrDaysDaysToExtract; $LoopNo++)
    {
        [datetime]$DateToExtractUTC = $DayUTC.AddDays(-$LoopNo).ToString("yyyy-MM-dd")
        [string]$DateToExtractLabel = $DateToExtractUTC.ToString("yyyy-MM-dd")

        #Obtain activity events and store intermediary results:
        #filter for every WS id using "Where WorkspaceId -in $AllWSIds"
        
        $Events = (Get-PowerBIActivityEvent `
                        -StartDateTime ($DateToExtractLabel+'T00:00:00.000') -EndDateTime ($DateToExtractLabel+'T23:59:59.999') `
                        -ActivityType ViewReport -ResultType JsonString | ConvertFrom-Json) `
                        | Where-Object WorkspaceId -in $AllWSIds `
                        | Select-Object id, CreationTime, UserId, Workload, Activity, ItemName, WorkSpaceName, DatasetName, ReportName, CapacityId,`
                                 WorkspaceId, AppName, ObjectId, DatasetId, ReportId, ArtifactId, ArtifactName, ReportType, ArtifactKind
                                 
        $EventsWS += $Events

        Write-Verbose "Events written for: $DateToExtractLabel" -Verbose 
    }
Write-Verbose "Extract of Power BI activity events is complete." -Verbose

$EventsWS #| Export-Csv -Path "$ExportFileLocation\$ExportFileName.csv" -Delimiter "`t" -NoTypeInformation -Force

# to calculate #Viewers and #Views for reports

$Viewers = $EventsWS | Select-Object ReportId, UserId -Unique 
$Views = $EventsWS | Select-Object ReportId, Activity

# w/o -NoElement you'll also get a property/column "Group" with "{@{ReportId=7498919e-4e54-4e6b-ba3a-63e2f6ed5b08; Activity=ViewReport}}"
# and | Select-Object is needed to see entire report id, otherwise it looks like "7498919e-4e54-4e6b-ba3..."

$ViewersCount = $Viewers | Group-Object -Property ReportId -NoElement | Sort-Object Count -Descending | Select-Object Name, Count
$ViewsCount = $Views | Group-Object -Property ReportId -NoElement | Sort-Object Count -Descending | Select-Object Name, Count

# Change property/column names

$Viewers | Group-Object -Property ReportId -NoElement | Sort-Object Count -Descending `
            | Select-Object @{N='ReportId'; E={$_.Name}}, @{N="ViewersCount"; E={$_.Count}}


<# Export to CSV:

$ViewersCount = $Viewers | Group-Object -Property ReportId -NoElement | Sort-Object Count -Descending | Select-Object Name, Count
$ViewsCount = $Views | Group-Object -Property ReportId -NoElement | Sort-Object Count -Descending | Select-Object Name, Count

$ViewersCount | Export-Csv -Path "$ExportFileLocation\ViewersCount.csv" -Delimiter "`t" -NoTypeInformation -Force
$ViewsCount | Export-Csv -Path "$ExportFileLocation\ViewsCount.csv" -Delimiter "`t" -NoTypeInformation -Force
#>






##################################### Get Scan Results - everything about PBI artefacts #####################################

## 1. Get Scan ID
<#
POST https://api.powerbi.com/v1.0/myorg/admin/workspaces/getInfo?lineage=True&datasourceDetails=True&datasetSchema=True&datasetExpressions=True
{
  "workspaces": [
    "97d03602-4873-4760-b37e-1563ef5358e3",
    "67b7e93a-3fb3-493c-9e41-2c5051008f24"
  ]
}
#>

$ScanUrl = "https://api.powerbi.com/v1.0/myorg/admin/workspaces/getInfo?lineage=True&datasourceDetails=True&datasetSchema=True&datasetExpressions=True"

$AllWSIds # I need this in the form as in the example above

$WSIdsScan = $AllWSIds | ConvertTo-Json

$ScanBody = @"
            {
                "workspaces": $WSIdsScan
            }
"@

$ScanId = (Invoke-PowerBIRestMethod -Method POST -URL $ScanUrl -Body $ScanBody | ConvertFrom-JSON).id

## 2. Get the scan status for the specified scan
# GET https://api.powerbi.com/v1.0/myorg/admin/workspaces/scanStatus/{scanId}

$ScanStatusUrl = "https://api.powerbi.com/v1.0/myorg/admin/workspaces/scanStatus/$ScanId"

Invoke-PowerBIRestMethod -Method GET -URL $ScanStatusUrl | ConvertFrom-JSON

## 3. Get the scan result for the specified scan
# GET https://api.powerbi.com/v1.0/myorg/admin/workspaces/scanResult/{scanId}

$GetScanUrl = "https://api.powerbi.com/v1.0/myorg/admin/workspaces/scanResult/$ScanId"

$ScanResult = Invoke-PowerBIRestMethod -Method GET -URL $GetScanUrl 

$b = $ScanResult | ConvertFrom-JSON

$b | Get-Member

#$b | Select-Object -Property datasourceInstances, workspaces

#$b | Select-Object workspaces | Foreach { $_.workspaces }
#$b | Select-Object -ExpandProperty workspaces
$b.workspaces

($b.workspaces).reports



## How to see everything? Notice reports/datasets values - $b is a nested object

$expandedReports = $b.workspaces | Select-Object -Property @{name="WSId"; expr={$_.id}}, @{n="WSName"; e={$_.name}}, type, state, `
                                            dataRetrievalState, isOnDedicatedCapacity `
                                           -ExpandProperty reports

$expandedreports | Select-Object -Property WSId, WSName, id, name

($b.workspaces).datasets

$expandedDatasets = $b.workspaces | Select-Object -Property @{name="WSId"; expr={$_.id}}, @{n="WSName"; e={$_.name}}, type, state, `
                                            dataRetrievalState, isOnDedicatedCapacity `
                                           -ExpandProperty datasets

# Expands everything
$band = $b.workspaces | Format-Custom -Property *


























































































<#

$Sites = @($m)

$Flat = foreach($Site in $m){
    foreach($Vcenter in $Site.vCenters){
        Foreach($vHost in $Vcenter.ESXHosts){
            foreach($Property in ($vHost.psobject.Properties.Name | where-object {$_ -notlike 'Name'})){
                [pscustomobject]@{
                    Site = $Site.Site
                    vCenter = $Vcenter.Name
                    Host = $vHost.Name
                    Property = $Property
                    Value = $vHost.$Property
                }
            }
        }
    }
}

$Flat | ft -AutoSize


#>


