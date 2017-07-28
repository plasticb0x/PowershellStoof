#A basic template for Powershell jobs

#Variables
#----------------------------------------------------------
$inputData = Get-Content "C:\Your\Path\Here\ServerList.txt"

$csvExportPath = "C:\Export\Path\For\Your\Data.csv"

$jobPrefix = "JobPrfixHere"

Get-Job "$jobPrefix*" | Stop-Job 
Get-Job "$jobPrefix*" | Remove-Job 

$maxJobs = "20" #Add more as needed/can handle

$i = 0

#Functions
#----------------------------------------------------------
function JobScriptToRun ($tmpDataPoint){

    Start-Job -Name "$jobPrefix.$tmpDataPoint" -ScriptBlock {
        
        #Your code to iterate over here
        #Should 'return' some data at the end
        return $returnSomeDataForWhenJobIsRetrieved

    } -ArgumentList $tmpDataPoint | Out-Null 


    $runningJobsCount = (Get-Job "$jobPrefix*" | ? {$_.State -eq "Running"}).count 
    while ($runningJobsCount -gt $maxJobs) 
    { 
        Write-Progress -Activity "Reached maximum number of threads: $($maxJobs)..." -Status "Waiting until a job completes to start a new one..." -PercentComplete (100*$i/($inputData.count)) 
        Start-Sleep 10 
        $runningJobsCount = (Get-Job "jobPrefix*" | ? {$_.State -eq "Running"}).count 
    }
}

#Main Code
#----------------------------------------------------------
foreach ($dataPoint in $inputData) 
{ 
    $i++ 
    Write-Progress -Activity "Creating job..." -Status $dataPoint -PercentComplete (100*$i/($inputData.count)) 

    JobScriptToRun $dataPoint    
}

$runningJobsCount = (Get-Job "$jobPrefix*" | ? {$_.State -eq "Running"}).count
While (Get-Job "$jobPrefix*" | ? {$_.State -eq "Running"}) { 
    Write-Progress -Activity "Final jobs wrapping up, please wait..." -Status "$($runningJobsCount) jobs running" -PercentComplete (100*($i-$runningJobsCount)/$i)  
    Start-Sleep 10 
    $runningJobsCount = (Get-Job "jobPrefix*" | ? {$_.State -eq "Running"}).count 
} 

$results=@() 

Write-Host "Retrieving data from jobs..."
foreach ($job in (Get-Job | ? { $_.Name -like "$jobPrefix.*"})) { 
    $tmpResult = $null 
    $tmpResult = Receive-Job $job 
    $results += @($tmpResult)
    Remove-Job $job 
} 

$results | select * | Export-Csv -Path $csvExportPath -NoTypeInformation