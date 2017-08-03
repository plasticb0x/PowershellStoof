#plasticB0x
#Extra Creds: potatoqualitee@github for Runspace powershell template
#
#Descrip: Quickly rummages through Windows file system, returns all file paths.
#Implements a new runspace for each directory at the starting path defined below.
#
#Future plans: Expand runspace creation to something like "if subdir > 20 dir"

#Path to start scanning from, can be UNC
$startingPath = "C:\"

#Setup pool and various vars
$pool = [RunspaceFactory]::CreateRunspacePool(1, 20) #Params define the minimum,maximum runspaces that can be running for the pool
$pool.ApartmentState = "MTA"
$pool.Open()
$runspaces = @()
$results = @()

$rootDir = ([System.IO.DirectoryInfo]($startingPath)).GetDirectories().FullName
$pathList = New-Object System.Collections.ArrayList

#Workhorse Scriptblock
$scriptBlock = {
    Param (
    [parameter(Mandatory=$true)]
	[string]
    $filePath
	)

    $scriptList = New-Object System.Collections.ArrayList

    function RecursiveDirectoryRetrieve{
        Param(
        [parameter(Mandatory=$true)]
        [String]
        $tmpDir 
        )

        $success = $true
    
        try{
            $internalDirectory = ([System.IO.DirectoryInfo]($tmpDir)).GetDirectories().FullName
        }
        catch{
            #Trying to break on the function seems to break the script block? Doing dumb bool thing here
            $success = $false
        }

        if ($success){
            foreach ($dir in $internalDirectory){
                $tmpFiles = ([System.IO.DirectoryInfo]($dir)).GetFiles().FullName
                foreach ($tmpFile in $tmpFiles){
                    $scriptList.Add($tmpFile) | out-null
                }
                RecursiveDirectoryRetrieve $dir
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