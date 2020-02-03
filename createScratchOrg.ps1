# MINSAIT 21.05.2019
# Powershell script to create a new scratch org based on the metadata of the actual
# directory, installing the thinkConnect package.
# Uses the environment variable $Env:SELENIUM_HOST for launching executions to the selenium server
<#
.PARAMETER  alias
 Specifies the alias name for the new scratch org
#>
<#
.PARAMETER  duration
 Duration of the scratch org. Defaults to 30 days.
#>
<#
.PARAMETER  step
 Step from which to retake the script, from 1 to 4.
#>
<#
.PARAMETER  defaultOrg
 If true, sets this org as the default one.
#>
<#
.PARAMETER  apiVersion
 If set, will use the api version in the sfdx operations
#>
param (
	[Parameter(Mandatory=$true)][string]$alias,
    [int]$duration = 21,
    [int]$step = 0,
	[switch]$defaultOrg = $false,
    [string]$apiVersion = $null
)

# Define an alias for the get date function, to timestamp the echo messages
filter timestamp {"$(Get-Date -UFormat %H:%M:%S): $_"}

# Method to process the table output of push command in order to print each error
# in a more friendly way.
function ProcessErrorTable {

    param (
        [string[]]$data
    )

    $headerString = $data[0]
    $headerElements = $headerString -split "\s{2,}" | Where-Object{ $_ }
    $headerIndexes = $headerElements | ForEach-Object { $headerString.IndexOf($_) }

    $data | Select-Object -Skip 2 | ForEach-Object {
        $line = $_
        For ($indexStep = 0; $indexStep -le $headerIndexes.Count - 1; $indexStep++) {
            $value = $null            # Assume a null value
            $valueLength = $headerIndexes[$indexStep + 1] - $headerIndexes[$indexStep]
            $valueStart = $headerIndexes[$indexStep]

            If (($valueLength -gt 0) -and (($valueStart + $valueLength) -lt $line.Length)) {
                $value = ($line.Substring($valueStart,$valueLength)).Trim()
            } ElseIf ($valueStart -lt $line.Length){
                $value = ($line.Substring($valueStart)).Trim()
            }

            Write-Host $headerElements[$indexStep] ": " -NoNewline -ForegroundColor Yellow
            Write-Host $value
        }

        Write-Host ""
    }
}
function ProcessJsonResult {

    param (
        [PSCustomObject]$result
    )
    Write-Host ($result.message) -ForegroundColor Yellow
    foreach ($element in $result.data) {
       Write-Host ($element.type,"  ",$element.fullName,"  ",$element.error) -ForegroundColor Yellow
    }
}

function LoadBulkData($file, $SObject, $IdField, $alias, $apiVersionParam, $preprocess=$false, $tempFile=''){
    $ErrorActionPreference = "SilentlyContinue"
    $finalFile = $file
    if($preprocess){
        node .\util-ext\recordTypeLoader\ --origin $file --destination $tempFile --mapping .\build\temp\$alias.rt.json --sobject $SObject
        $finalFile = $tempFile
    }
    
    $pushResult = (sfdx force:data:bulk:upsert -f $finalFile -i $IdField -w 5 -s $SObject -u $alias $apiVersionParam --json) | ConvertFrom-Json     
    $ErrorActionPreference = "Continue"

    if (!$LastExitCode -eq 0) {
        Write-Host $(timestamp) "Following errors have been found uploading $Sobject into the scratch:" -ForegroundColor Red        
        ProcessJsonResult $pushResult
        Exit $pushResult.exitCode
    }

}

# Initialize - Sleep time
$sleepTime = 45
# Initialize - If api version is set, define the additional parameter
$apiVersionParam = '';
if(-not ([string]::IsNullOrEmpty($apiVersion))){
    $apiVersionParam = "--apiversion=$apiVersion";
}
# Check if the selenium variable
if (-not (Test-Path Env:SELENIUM_HOST)) { 
    Write-Host "WARNING: Environment variable SELENIUM_HOST not set; Selenium automation wont work." -ForegroundColor DarkMagenta
 }

# Step 1.
# Run SFDX to create the new scratch org
if ($step -le 1) {
    Write-Host ""
    Write-Host $(timestamp) "Step 1) Creating scratch with following parameters:" -ForegroundColor DarkMagenta
    Write-Host ("   Alias", $alias) -Separator ": "
    Write-Host ("   Duration", $duration) -Separator ": "
    Write-Host ("   New default org", $defaultOrg) -Separator ": "
    if(-not ([string]::IsNullOrEmpty($apiVersion))){
        Write-Host ("   API version", $apiversion) -Separator ": "
    }    
    Write-Host ""

    $createResult = sfdx force:org:create -f config/project-scratch-def.json --setalias $alias --durationdays $duration $apiversionParam --json | ConvertFrom-Json

    # Process result of creation.
    if ($createResult.status -eq 0) {
        Write-Host ("Scratch org", $createResult.result.orgId, "created succesfully.") -Separator " " -ForegroundColor Green

        if ($defaultOrg) {
            sfdx force:config:set defaultusername=$alias 1> $null 2> $null
        }
    }
    else {
        Write-Host $(timestamp) "Error found creating the scratch org: " -ForegroundColor Red
        Exit $createResult.status
    }
    Write-Host $(timestamp) "Wait ${sleepTime} seconds to guarantee scratch initialization."
    Start-Sleep -Seconds ${sleepTime}
}

# Step 3.
# Install packages


# Step 4.
# Everything OK, pushing code into the scratch
if ($step -le 4) {
    Write-Host ""
    Write-Host $(timestamp) "Step 4) Pushing actual code to the new scratch..." -ForegroundColor DarkMagenta
    Write-Host ""

    # Execute push and keep the JSON Output
    $ErrorActionPreference = "SilentlyContinue"
    $pushResult = sfdx force:source:deploy -p force-app -u $alias $apiVersionParam --json | ConvertFrom-Json 
    $ErrorActionPreference = "Continue"

    if ($LastExitCode -eq 0) {
        Write-Host $(timestamp) ("Code push succesfully. You can open the new scratch executing: sfdx force:org:open -u", $alias) -ForegroundColor Green
    } else {
        Write-Host $(timestamp) "Following errors have been found pushing code into the scratch:" -ForegroundColor Red        
        ProcessJsonResult $pushResult
        Exit $pushResult.exitCode
    }
}

# Step 5.
# Upload data to scratch
if ($step -le 5) {
    Write-Host ""
    Write-Host $(timestamp) "Step 5) Uploading seed data to scratch..." -ForegroundColor DarkMagenta
    Write-Host ""    

    # Accounts
    Write-Host $(timestamp) "        Accounts..." -ForegroundColor DarkMagenta
    LoadBulkData "build/data/accounts.csv" "Account" "IdExterno__c" $alias $apiVersionParam

    # Accounts
    Write-Host $(timestamp) "        Contacts..." -ForegroundColor DarkMagenta
    LoadBulkData "build/data/contacts.csv" "Contact" "Email" $alias $apiVersionParam

    Write-Host $(timestamp) ("Data upload succesfull. You can open the new scratch executing: sfdx force:org:open -u", $alias) -ForegroundColor Green    
}