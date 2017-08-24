#plasticB0x
#Extra Creds: 
#potatoqualitee@github for initial Runspace powershell template
#PowerShellMafia@github for some tips out of PowerSploit
#
#Descrip: Quickly rummages through Windows network share file system, returns all file paths.
#
#Usage [1]: PS-FSBang C:\ServerList.txt    #Defaults to 4 runspace threads
#Usage [2]: Ps-FSBang C:\ServerList.txt 8  #Uses 8 threads instead of default 4
#
#To Do: Add export option/bool
#-------------------------------------------------------------------------------------------

function PS-FSBang{
    Param (
        [parameter(Mandatory=$true)]
	    [String[]]
        $importedServers,

        [Int]
        $maxThreads = 4
    )

    $returnedValues = @{}

    #Core pull block
    $scriptBlock = {
        Param (
        [parameter(Mandatory=$true)]
	    [string]
        $tmpHostName
	    )
        
        $returnArray = @("$tmpHostName")
        
        $shareNames = Get-WmiObject -Query 'Select * from win32_share where not name like "%$%" and not name like "%users%" and not name like "%driver%"' -ComputerName $tmpHostName | select name

        foreach ($share in $shareNames){
            $shareString = "\\$tmpHostName\$($share.name)"
            $dirFind = @(cmd /r "pushd `"$shareString`" & dir /b /s /a-d & popd `"$shareString`"")

            foreach ($file in $dirFind){
                $tmpFile = "$shareString\$($file.Substring(3))"
                $returnArray += @($tmpFile)
            }
        }
        
        return $returnArray
        
    }

    $serverNames = [System.IO.File]::ReadAllLines($importedServers)

    #Setup pool and various vars
    $pool = [RunspaceFactory]::CreateRunspacePool(1, $maxThreads) #Params define the minimum,maximum runspaces that can be running for the pool
    $pool.ApartmentState = "MTA"
    $pool.Open()
    $runspaces = @()
    $results = @()

    foreach ($server in $serverNames){
        $returnedValues["$server"] = @()

        #Create/Queue runspaces for each top level folder
        $runspace = [PowerShell]::Create()
        $runspace.AddScript($scriptBlock) | Out-Null #microsoftWhy
        $runspace.AddArgument($server) | Out-Null #microsoftWhy
        $runspace.RunspacePool = $pool #So funky... This is how you assign the runspace to a pool
        $runspaces += [PSCustomObject]@{Pipe = $runspace; Status = $runspace.BeginInvoke() }
    }

    while ($runspaces.Status.IsCompleted -contains $false){
        $trueCount = ($runspaces.Status | where -Property IsCompleted -eq $true).count
        $percentComplete = [math]::Round(100*$trueCount/$runspaces.Status.count, 2)
        Write-Progress -Activity "Iterating through directories... $percentComplete%" -Status "Runspaces: $trueCount of $($runspaces.Status.count) left..." -PercentComplete $percentComplete

        Start-Sleep -MilliSeconds 500
    }

    $x = 0
    foreach ($runspace in $runspaces ) {

        $percentComplete = [math]::Round(100*$x/$runspaces.Status.count, 2)
        Write-Progress -Activity "Getting results... $percentComplete%" -Status "Getting all the results: $x of $($runspaces.Status.count) results left..." -PercentComplete $percentComplete

	    $tmpReturn = $runspace.Pipe.EndInvoke($runspace.Status)
        
        $returnedValues[$tmpReturn[0]] += @($tmpReturn[1..$tmpReturn.Count])
	    $runspace.Pipe.Dispose() | Out-Null
        $x++
    }

    $pool.Close() 
    $pool.Dispose | out-null

    $returnedValues

    Write-Host ""
    Write-Host "Done getting results..."

}