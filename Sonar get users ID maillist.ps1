<#
    Powershell script for obtain user mailing list from SonarQube
#>

####### CONFIG ####### 

#Authentication
    $baseUrl = "https://sonarqubehostFooo.com"
    $Username = "AUTH_TOKEN_FROM_PROFILE"

#URLS
$Headers = @{ Authorization = "Basic {0}" -f [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $Username,$Password))) }

$urlUsers = "/api/users/search?format=json&includeDeactivated=false"

$resUrl = "$baseUrl$urlUsers"

#Write-Host $usrList

$page = 1
$count = 0
$jsonCount = 0
$usrList = ""

Do{
 $callURL = $resUrl +"&p="+$page
 #Write-Host "call url:" +$callURL

 $obj = Invoke-WebRequest -Uri $callURL -Headers $Headers
 $objJson = ConvertFrom-Json -InputObject $obj
 $users = $objJson.users
 $jsonCount = $objJson.paging.total

  ForEach($usr in $users){
   if( ($usr.email -ne $null) -and ($usr.email.Contains("@"))) {
        $newItem= $usr.login.Trim()+';'+$usr.email.Trim()+';'+$usr.name.Trim()+"`n"
        Write-Host $newItem
        $usrList = $usrList +$newItem
    }
    
 }

 
 #debug
 #Write-Host $users
  
  $count = $count + $users.Count
  $page = $page + 1

} While ($count -lt $jsonCount)

#Write-Host 'usr list: ' $usrList
#Out-File -filepath exportusrs.txt -InputObject $usrList 