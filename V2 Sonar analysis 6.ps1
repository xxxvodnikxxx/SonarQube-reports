<#
    Powershell script for obtain project analysis statistics from SonarQube
    configuration:
        - refDaysAgo- frame scope to the referencial date (days past, please notice it have to with minus sign)
        - refMonthsAgo- frame scope to the referencial date (months past, please notice it have to with minus sign)
#>

####### CONFIG ####### 
$debug = "0";

#time scope
    #scope from
        $refDaysAgo = -12;
        $refMonths= -6;
    
    #scope until
    $refDateUntilDaysAgo = -12;
    $refDateUntilMonthsAgo = -0;

#Authentication
    $baseUrl = "https://sonarqubehostFooo.com"
    $Username = "AUTH_TOKEN_FROM_PROFILE"
    
#URLS
$Headers = @{ Authorization = "Basic {0}" -f [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $Username,$Password))) }
    
$urlProjectSearch="/api/projects/search?ps=499&qualifiers=TRK"
$urlProjectLoC = "/api/measures/component?metricKeys=ncloc&component="
$urlMeasuresHistory="/api/measures/search_history?metrics=ncloc&component="


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



<# filter projects by date in scope of dates #>
function FilterProjectsAnalysisDate($dateFrom,$dateUntil,$projectsList){
    $filteredList = New-Object System.Collections.ArrayList
    foreach($proj in $projectsList){
         if($proj.lastAnalysis -and ([datetime]$proj.lastAnalysis -gt $dateFrom) -and ([datetime]$proj.lastAnalysis -lt $dateUntil)){
            $filteredList.Add($proj) > $null
        }
    }
    return $filteredList
} 

<# count element loc on items #>
function GetLOCInList($dataList){
    $count = 0
    
  foreach($itm in $dataList){
    $count += [int]$itm.loc
  }

  return $count
}

#will load scans per project and compare to dates
function GetScansInPeriod($resList,$dateFrom,$dateUntil){
    $count = 0
    
    if($dateFrom -and $dateUntil){
         foreach($itm in $resList){
                 if(($itm.date -lt $dateUntil) -and ($itm.date -gt $dateFrom)){
                  $count += 1
                }
         }

    }else{
        return $resList.count
    }
    return $count
}

<#
    LOAD Projects with last analysis date, key, name
#>
function getProjects(){
 $projUrl = "$baseUrl$urlProjectSearch"

    if($debug -eq "1"){
        Write-Host "projects URL: $projURL"
    }

     $allProjList = New-Object System.Collections.ArrayList
     
    
         #pagination
             $loadedCount = 0
             $expectedCount = 0
             $currPage =1

        do{
        $urlPaging=$projUrl+"&p="+$currPage

        if($debug -eq "1"){
            Write-Host $urlPaging
        }
        
         $obj = Invoke-WebRequest -Uri $urlPaging -Headers $Headers
         $json = $obj.Content | ConvertFrom-Json
         
         $expectedCount=$json.paging.total
            $json.components | foreach {
            
              $analysisDate= $null
              if($_.lastAnalysisDate -ne $null -and $_.lastAnalysisDate -ne " "){
                $analysisDate = [DateTime] $_.lastAnalysisDate
              }

              $project = New-Object System.Object
              $project | Add-Member -type NoteProperty -name name -value $_.name
              $project | Add-Member -type NoteProperty -name key -value $_.key
              $project | Add-Member -type NoteProperty -name id -value $_.id
              $project | Add-Member -type NoteProperty -name lastAnalysis -value $analysisDate

              #null or empty check
                if($project.key -and $project.name){
                    $loc = getLoCPerProject $_.key
                    $project | Add-Member -type NoteProperty -name loc -value $loc

                    $measureHistory = getTimeMachine $_.key
                    $project | Add-Member -type NoteProperty -name history -value $measureHistory

                    $allProjList.Add($project) > $null
                }
              
          
                
           }
           
           $loadedCount = $loadedCount +1  
           $currPage=$currPage+1
        }while($loadedCount -lt $expectedCount ) 
    return $allProjList
}

<#
    LOAD project LoC by key
#>
function getLoCPerProject($projKey){
      $url = "$baseUrl$urlProjectLoC$projKey"

      if($debug -eq "1"){
        Write-Host "loc url: $url"
      }


    $obj = Invoke-WebRequest -Uri $url -Headers $Headers
    $json = $obj.Content | ConvertFrom-Json
    if ($json.component.measures.Length -eq 0) { 
        return  0
    } else {
        return  $json.component.measures[0].value 
    }
}

<#
    LOAD measurements history by ID
#>
function getTimeMachine($projKey){
      $url = "$baseUrl$urlMeasuresHistory$projKey"

      if($debug -eq "1"){
        Write-Host "loc url: $url"
      }

        #pagination
             $loadedCount = 0
             $expectedCount = 0
             $currPage =1

       $measuresList = New-Object System.Collections.ArrayList

    
        do{
           $urlPaging="$url&p=$currPage"
           $obj = Invoke-WebRequest -Uri $urlPaging -Headers $Headers
           $json = $obj.Content | ConvertFrom-Json
           $expectedCount = $json.paging.total

           
           if($expectedCount -eq 0){
            return $null
           }

           $jsonMeasures = $json.measures.history
           
           $jsonMeasures | foreach {
             $dateAnalysis =  [DateTime] $_.date
             
             $measure = New-Object System.Object
             $measure | Add-Member -type NoteProperty -name date -value $dateAnalysis
             $measure | Add-Member -type NoteProperty -name value -value $_.value

             $measuresList.Add($measure) > $null
             $loadedCount = $loadedCount +1
           }

     
        }while($loadedCount -lt $expectedCount)
       
       return $measuresList

}

# prepare scope section start #
    $refDateScopeStart = Get-Date  
    $refDateScopeEnd = Get-Date 
   
    $refDateScopeStart = SetRefDate $refDateScopeStart $refDaysAgo $refMonths
    $refDateScopeEnd = SetRefDate $refDateScopeEnd $refDateUntilDaysAgo $refDateUntilMonthsAgo

    Write-Host "Scope start: $refDateScopeStart"
    Write-Host "Scope, until: $refDateScopeEnd"

# prepare scope section end #

[System.Collections.ArrayList] $projList = getProjects
[System.Collections.ArrayList] $projListFiltered = FilterProjectsAnalysisDate $refDateScopeStart $refDateScopeEnd $projList

$locProject = GetLOCInList $projList
$locActive = GetLOCInList $projListFiltered  

$scansTotal = 0
$projList | forEach {
    if($_.history){
        $scansProject = GetScansInPeriod $_.history
        $scansTotal = $scansTotal + $scansProject
    }   
}

$scansInPeriod= 0
$projListFiltered | forEach {
    if($_.history){
        $scansProject = GetScansInPeriod $_.history $refDateScopeStart $refDateScopeEnd
        $scansInPeriod = $scansInPeriod + $scansProject
    }   
}


Write-Host "Total Projects: " $projList.Count
Write-Host "Active projects: " $projListFiltered.Count

Write-Host "LOC total: " $locTotal
Write-Host "LOC active: " $locActive

Write-Host "scans total: " $scansTotal
Write-Host "scans in period: " $scansInPeriod