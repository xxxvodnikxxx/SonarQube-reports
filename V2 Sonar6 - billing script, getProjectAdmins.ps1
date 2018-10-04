<#
    Powershell script for obtain projects admins from sonarqube
#>

####### CONFIG ####### 
$debug = "0";

#Authentication
    #prod sonar
    $baseUrl = "SONARBASEURL"
    $Username = "AUTHTOKEN"
    
#URLS
$Headers = @{ Authorization = "Basic {0}" -f [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $Username,$Password))) }
    
$urlProjectSearch="/api/projects/search?ps=499&qualifiers=TRK"
$urlPRojectsPermissions="/api/permissions/users?projectKey="

 
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
            
            $project = New-Object System.Object
            $project | Add-Member -type NoteProperty -name name -value $_.name
            $project | Add-Member -type NoteProperty -name key -value $_.key
            $project | Add-Member -type NoteProperty -name id -value $_.id
            $project | Add-Member -type NoteProperty -name lastAnalysis -value $analysisDate

            $adminUsers = New-Object System.Collections.ArrayList
            $adminUsers  = getProjectPermissions($project)

            $project | Add-Member -type NoteProperty -name adminUsers -value $adminUsers


            $allProjList.Add($project) > $null    
           }
           
           $loadedCount = $loadedCount +1  
           $currPage=$currPage+1
        }while($loadedCount -lt $expectedCount ) 
    return $allProjList
}

<#
    Load project permissions and filter per admins
#> 
function getProjectPermissions($project){
    $returnList = New-Object System.Collections.ArrayList
    
    $projPermUrl = "$baseUrl$urlPRojectsPermissions" + $project.key

    if($debug -eq "1"){
        Write-Host $projPermUrl
    }

     $obj = Invoke-WebRequest -Uri $projPermUrl -Headers $Headers
     $json = $obj.Content | ConvertFrom-Json
     $json = $json.users

      foreach ($jsonItem in $json) {
          #Write-Host $jsonItem.name
          $permissions = $jsonItem.permissions

          foreach ($permissionItem in $permissions){
            #Write-Host $permissionItem
            if($permissionItem -eq "admin"){
                $returnList.Add($jsonItem.name + "-" + $jsonItem.email) >$null
            }

          }
      }

    return $returnList
}


[System.Collections.ArrayList] $projList = getProjects

foreach ($project in $projList){
    $admins = ""
    foreach ($admin in $project.adminUsers){
        $admins = $admin + ";" + $admins
    }

    $record = $project.name + ";" +$admins
    Write-Host $record

    
    Add-Content -Path "adminSonarUsers.txt" -Value $record
}
