#plasticB0x
#Extra Creds: potatoqualitee@github for Runspace powershell template
#
#Descrip: Quickly rummages through Windows file system, returns all file paths.
#Implements a new runspace for each directory at the starting path defined below.
#
#Future plans: Expand runspace creation to something like "if subdir > 20 dir"
#
#Side notes/reminders: net view
# Get-WmiObject -Query 'Select * from win32_share where not name like "%$%" and not name like "%users%" and not name like "%driver%"' -ComputerName <compName> | select name
# pushd \\UNCPath\Here
# cmd /r 'pushd \\<host>\<shareFolder> & dir /b /a-d /s'

$startingPath = "C:\"
$maxThreads = 4

#Setup pool and various vars
$pool = [RunspaceFactory]::CreateRunspacePool(1, $maxThreads) #Params define the minimum,maximum runspaces that can be running for the pool
$pool.ApartmentState = "MTA"
$pool.Open()
$runspaces = @()
$results = @()

$rootDir = cmd /r dir "$startingPath" /b /ad
$pathList = New-Object System.Collections.ArrayList

#Workhorse Scriptblock
$scriptBlock = {
    Param (
    [parameter(Mandatory=$true)]
	[string]
    $hostName
	)

    $internalList = New-Object System.Collections.ArrayList

    $shareNames = Get-WmiObject -Query 'Select * from win32_share where not name like "%$%" and not name like "%users%" and not name like "%driver%"' -ComputerName $hostName | select name

    function GetAllFilePaths{
        Param(
        [parameter(Mandatory=$true)]
        [String]
        $tmpDir 
        )

        foreach ($share in $shareNames){
            $tmpFiles = cmd /r dir "$startingPath\$dir" /b /s /a-d
            foreach ($tmpFile in $tmpFiles){
                $scriptList.Add($tmpFile) | out-null
            }
        }
    }

    RecursiveDirectoryRetrieve $filePath
	return $scriptList
}

foreach ($dir in $rootDir){
    #Create/Queue runspaces for each top level folder
    $runspace = [PowerShell]::Create()
    $runspace.AddScript($scriptBlock) | Out-Null #microsoftWhy
    $runspace.AddArgument($dir) | Out-Null #microsoftWhy
    $runspace.RunspacePool = $pool #So funky... This is how you assign the runspace to a pool
    $runspaces += [PSCustomObject]@{Pipe = $runspace; Status = $runspace.BeginInvoke() }
}

while ($runspaces.Status.IsCompleted -contains $false){
    $trueCount = ($runspaces.Status | where -Property IsCompleted -eq $true).count
    $percentComplete = [math]::Round(100*$trueCount/$runspaces.Status.count, 2)
    Write-Progress -Activity "Iterating through directories... $percentComplete%" -Status "Runspaces: $trueCount of $($runspaces.Status.count) left..." -PercentComplete $percentComplete
}

$x = 0
foreach ($runspace in $runspaces ) {

    $percentComplete = [math]::Round(100*$x/$runspaces.Status.count, 2)
    Write-Progress -Activity "Getting results... $percentComplete%" -Status "Getting all the results: $x of $($runspaces.Status.count) results left..." -PercentComplete $percentComplete

	$result = @($runspace.Pipe.EndInvoke($runspace.Status))
    
    foreach ($intResult in $result){
        $pathList.Add($intResult) | Out-null
    }

	$runspace.Pipe.Dispose()
    $x++
}

$pool.Close() 
$pool.Dispose()

Write-Host "Done getting results..."
Write-Host "PS-FSBang completed... Found $($pathList.Count) files."
Write-Host 'File paths are in $pathList variable'