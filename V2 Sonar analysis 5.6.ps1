<#
    Powershell script for obtain project analysis statistics from SonarQube
    configuration:
        - refDaysAgo- frame scope to the referencial date (days past, please notice it have to with minus sign)
        - refMonthsAgo- frame scope to the referencial date (months past, please notice it have to with minus sign)
#>

####### CONFIG ####### 
$debug = "0";

#time scope
    #projects scope
        $refDaysAgoProjects = -7;
        $refMonthsProjects = -1;
        
    #scans scope
        $refDaysAgoScans = -7;
        $refDaysMonthsScans = -0;

    #scope until
    $refDateUntilDaysAgo = -9;
    $refDateUntilMonthsAgo = -0;

#Authentication
    $baseUrl = "https://sonarqubehostFooo.com"
    $Username = "AUTH_TOKEN_FROM_PROFILE"

#URLS
$Headers = @{ Authorization = "Basic {0}" -f [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $Username,$Password))) }

    #https://docs.sonarqube.org/pages/viewpage.action?pageId=2392180
$urlResources = "/api/resources?metrics=ncloc&format=xml&scopes=PRJ&qualifiers=TRK"

    #https://docs.sonarqube.org/pages/viewpage.action?pageId=2392163 
$urlTimeMachinePref = "/api/timemachine?resource="
$urlTimeMachinePost = "&metrics=ncloc"



<# help to set ref. date value according to the config params #>
function SetRefDate($param,$daysPast,$monthsPast){
    $param = $param.AddDays($daysPast)
    $param = $param.AddMonths($monthsPast)
    
    $param = $param.AddHours(-$param.Hour)
    $param = $param.AddMinutes(-$param.Minute)
    $param = $param.AddSeconds(-$param.Second)
    $param = $param.AddMilliseconds(-$param.Millisecond) 

    return $param
}


<# loads projects from Sonar, using resources api #>
function GetResources(){
    $resUrl = "$baseUrl$urlResources"

    if($debug -eq 1){
        Write-Host "resources URL: $resUrl"
    }

    [xml]$obj = Invoke-WebRequest -Uri $resUrl -Headers $Headers
    $allResList = New-Object System.Collections.ArrayList

     $obj.resources.resource | foreach {
        $resource = New-Object System.Object
        
            #project properties
            $resource | Add-Member -type NoteProperty -name name -value $_.name
            $resource | Add-Member -type NoteProperty -name key -value $_.key
            $resource | Add-Member -type NoteProperty -name date -value $_.date
            #loc from metrics
            $resource | Add-Member -type NoteProperty -name loc -value $_.msr.val

            #null or empty check
            if($resource.key -and $resource.name){
                $allResList.Add($resource) > $null
            }
     }

     
    return $allResList
}

<# filter projects by date in scope of dates #>
function FilterProjects($dateFrom,$dateUntil,$projectsList){
    $filteredList = New-Object System.Collections.ArrayList
    foreach($proj in $projectsList){
         if($proj.date -and ([datetime]$proj.date -gt $dateFrom) -and ([datetime]$proj.date -lt $dateUntil)){
            $filteredList.Add($proj) > $null
        }
    }
    return $filteredList
}

<# count element loc on items #>
function GetLOCInList($dataList){
    $count = 0

    foreach($itm in $dataList){
        if($itm.loc){
            $count += $itm.loc
        }
    }

    return $count
}

#will load scans per project and compare to dates
function GetScansInPeriod($resList,$dateFrom,$dateUntil){
    $count = 0

    foreach($proj in $resList){
        $prKey = $proj.key

        $url = "$baseUrl$urlTimeMachinePref$prKey$urlTimeMachinePost"
        $obj = Invoke-WebRequest -Uri $url -Headers $Headers
   
        $json =  $obj.Content | ConvertFrom-Json
        $json = $json.cells

        if($dateFrom -and $dateUntil){
            foreach($scanDate in $json.d){
                if($scanDate -and   ([datetime]$scanDate -gt $dateFrom) -and ([datetime]$scanDate -lt $dateUntil)){
                    $count += 1;
                }
            }
            
        }else{
            $count += $json.count    
        }
    
    }
    return $count

    }


# prepare scope section start #
    $refDateScopeProjectsBegging = Get-Date  
    $refDateScopeScansBegging = Get-Date 
    $refDateScopeUntil = Get-Date  

    $refDateScopeProjectsBegging = SetRefDate $refDateScopeProjectsBegging $refDaysAgoProjects $refMonthsProjects
    $refDateScopeScansBegging = SetRefDate $refDateScopeScansBegging $refDaysAgoScans $refDaysMonthsScans
    $refDateScopeUntil = SetRefDate $refDateScopeUntil $refDateUntilDaysAgo $refDateUntilMonthsAgo

    Write-Host "Scope, projects start: $refDateScopeProjectsBegging"
    Write-Host "Scope, scans start: $refDateScopeScansBegging"
    Write-Host "Scope, until: $refDateScopeUntil"

# prepare scope section end #

#load projects
[System.Collections.ArrayList] $resourceList = GetResources

    #project
        #.name
        #.key
        #.date
        #.loc

#filter projects by scope
$filteredProjects = FilterProjects $refDateScopeProjectsBegging  $refDateScopeUntil $resourceList

Write-Host "- projects -"
Write-Host "Number of projects: " $resourceList.Count
Write-Host "Active of projects: " $filteredProjects.Count

#sumarize lines of code
$locTotal = GetLOCInList $resourceList
$locActive = GetLOCInList $filteredProjects

Write-Host "- LOC -"
Write-Host "Total: " $locTotal
Write-Host "Active: " $locActive

$scansTotal = GetScansInPeriod $resourceList
$scansActiveTotal = GetScansInPeriod $resourceList $refDateScopeProjectsBegging $refDateScopeUntil

Write-Host "- scans -"
Write-Host "Total: " $scansTotal
Write-Host "Active: " $scansActiveTotal

