# Bakta API Batch Annotation Script
# Processes all .fa files in a given directory in batches, submits them to Bakta Web API,
# polls for completion, and downloads results.

# -------------------- Configuration --------------------
$MAGsDir = "C:\Users\gonzalo.icaza\OneDrive - Universidad San Sebastian\Investigacion - Programa A. catenella - Documents\General\Manuscrito-ElLoto\result\drep99\dereplicated_genomes"
$OutputRoot = Join-Path $MAGsDir "bakta_results"
$BatchSize = 10
$PollIntervalSeconds = 60          # wait 1 minute between status checks
$ApiBaseUrl = "https://api.bakta.computational.bio/api/v1"

# Create output root if it doesn't exist
if (-not (Test-Path $OutputRoot)) {
    New-Item -ItemType Directory -Path $OutputRoot -Force | Out-Null
}

# -------------------- Helper Functions --------------------
function Invoke-BaktaInit {
    param(
        [string]$JobName
    )
    $body = @{
        name = $JobName
        repliconTableType = "TSV"
    } | ConvertTo-Json
    $url = "$ApiBaseUrl/job/init"
    $response = Invoke-RestMethod -Uri $url -Method Post -Body $body -ContentType "application/json"
    return $response
}

function Upload-File {
    param(
        [string]$UploadUrl,
        [string]$FilePath
    )
    # Use Invoke-RestMethod with -InFile for PUT
    Invoke-RestMethod -Uri $UploadUrl -Method Put -InFile $FilePath -ContentType "application/octet-stream"
}

function Invoke-BaktaStart {
    param(
        [string]$JobId,
        [string]$Secret,
        [hashtable]$Config
    )
    $body = @{
        job = @{
            jobID = $JobId
            secret = $Secret
        }
        config = $Config
    } | ConvertTo-Json -Depth 5
    $url = "$ApiBaseUrl/job/start"
    Invoke-RestMethod -Uri $url -Method Post -Body $body -ContentType "application/json"
}

function Invoke-BaktaList {
    param(
        [array]$Jobs   # array of hashtables with jobID and secret
    )
    $body = @{
        jobs = $Jobs
    } | ConvertTo-Json -Depth 5
    $url = "$ApiBaseUrl/job/list"
    $response = Invoke-RestMethod -Uri $url -Method Post -Body $body -ContentType "application/json"
    return $response
}

function Invoke-BaktaResult {
    param(
        [string]$JobId,
        [string]$Secret
    )
    $body = @{
        jobID = $JobId
        secret = $Secret
    } | ConvertTo-Json
    $url = "$ApiBaseUrl/job/result"
    $response = Invoke-RestMethod -Uri $url -Method Post -Body $body -ContentType "application/json"
    return $response
}

function Invoke-BaktaDelete {
    param(
        [string]$JobId,
        [string]$Secret
    )
    $url = "$ApiBaseUrl/job/delete?jobId=$JobId&secret=$Secret"
    Invoke-RestMethod -Uri $url -Method Delete
}

function Download-Results {
    param(
        [string]$JobId,
        [string]$Secret,
        [string]$OutputDir
    )
    # Get result links
    $result = Invoke-BaktaResult -JobId $JobId -Secret $Secret
    $resultFiles = $result.ResultFiles
    if (-not $resultFiles) {
        Write-Warning "No result files returned for job $JobId"
        return
    }
    # Create job output folder
    if (-not (Test-Path $OutputDir)) {
        New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
    }
    # Download each file
    $resultFiles.PSObject.Properties | ForEach-Object {
        $key = $_.Name
        $url = $_.Value
        if ($url) {
            $ext = switch ($key) {
                "EMBL" { ".embl" }
                "FAA" { ".faa" }
                "FAAHypothetical" { ".hypotheticals.faa" }
                "FFN" { ".ffn" }
                "FNA" { ".fna" }
                "GBFF" { ".gbff" }
                "GFF3" { ".gff3" }
                "JSON" { ".json" }
                "PNGCircularPlot" { ".png" }
                "SVGCircularPlot" { ".svg" }
                "TSV" { ".tsv" }
                "TSVHypothetical" { ".hypothetical.tsv" }
                "TSVInference" { ".inference.tsv" }
                "TXTLogs" { ".txt" }
                default { ".bin" }
            }
            $outFile = Join-Path $OutputDir "$JobId$ext"
            Write-Host "Downloading $key to $outFile"
            Invoke-WebRequest -Uri $url -OutFile $outFile
        }
    }
}

# -------------------- Main Script --------------------
# Get all .fa files
$files = Get-ChildItem -Path $MAGsDir -Filter "*.fa" | ForEach-Object { $_.FullName }
if ($files.Count -eq 0) {
    Write-Host "No .fa files found in $MAGsDir"
    exit
}
Write-Host "Found $($files.Count) MAG files to process."

# Process in batches
for ($i = 0; $i -lt $files.Count; $i += $BatchSize) {
    $batch = $files[$i..([Math]::Min($i + $BatchSize - 1, $files.Count - 1))]
    Write-Host "`n===== Processing batch $($i/$BatchSize + 1) of $([Math]::Ceiling($files.Count / $BatchSize)) ====="

    # 1. Submit jobs in batch
    $jobStatuses = @()   # array of hashtables with jobID, secret, file, status, name
    foreach ($file in $batch) {
        $baseName = [System.IO.Path]::GetFileNameWithoutExtension($file)
        Write-Host "Initializing job for $baseName..."
        try {
            $initResponse = Invoke-BaktaInit -JobName $baseName
            $jobId = $initResponse.job.jobID
            $secret = $initResponse.job.secret
            $uploadUrl = $initResponse.uploadLinkFasta
            Write-Host "  Job ID: $jobId, uploading FASTA..."
            Upload-File -UploadUrl $uploadUrl -FilePath $file
            Write-Host "  Upload complete. Starting job..."
            # Define config: use defaults, set keepContigHeaders to true, minContigLength to 200
            $config = @{
                completeGenome = $false
                compliant = $false
                dermType = $null
                genus = ""
                hasReplicons = $false
                keepContigHeaders = $true
                locus = ""
                locusTag = ""
                minContigLength = 200
                plasmid = ""
                prodigalTrainingFile = $null
                species = ""
                strain = ""
                translationTable = 11
            }
            Invoke-BaktaStart -JobId $jobId -Secret $secret -Config $config
            $jobStatuses += @{
                jobID   = $jobId
                secret  = $secret
                file    = $file
                name    = $baseName
                status  = "INIT"   # will be updated later
            }
        }
        catch {
            Write-Error "Failed to submit job for $baseName : $_"
        }
    }

    if ($jobStatuses.Count -eq 0) {
        Write-Warning "No jobs submitted in this batch. Skipping."
        continue
    }

    # 2. Poll for completion
    $allDone = $false
    while (-not $allDone) {
        Write-Host "Polling job statuses..."
        $listPayload = $jobStatuses | ForEach-Object { @{ jobID = $_.jobID; secret = $_.secret } }
        try {
            $listResponse = Invoke-BaktaList -Jobs $listPayload
            # Update statuses from response
            foreach ($jobInfo in $listResponse.jobs) {
                $jobId = $jobInfo.jobID
                $status = $jobInfo.jobStatus
                # Find the corresponding entry and update
                $entry = $jobStatuses | Where-Object { $_.jobID -eq $jobId }
                if ($entry) {
                    $entry.status = $status
                }
            }
            # Check if any job is still running or queued
            $running = $jobStatuses | Where-Object { $_.status -in @("INIT", "RUNNING") }
            if ($running.Count -eq 0) {
                $allDone = $true
                Write-Host "All jobs in batch are finished."
            } else {
                Write-Host "$($running.Count) job(s) still running. Waiting $PollIntervalSeconds seconds..."
                Start-Sleep -Seconds $PollIntervalSeconds
            }
        }
        catch {
            Write-Error "Error polling job status: $_"
            # Wait before retrying
            Start-Sleep -Seconds 30
        }
    }

    # 3. Download results for successful jobs, log failures
    foreach ($job in $jobStatuses) {
        $jobId = $job.jobID
        $baseName = $job.name
        if ($job.status -eq "SUCCESSFUL") {
            Write-Host "Downloading results for $baseName (Job $jobId)"
            $outDir = Join-Path $OutputRoot $baseName
            try {
                Download-Results -JobId $jobId -Secret $job.secret -OutputDir $outDir
                Write-Host "Results saved to $outDir"
                # Optionally delete job to free server resources
                # Invoke-BaktaDelete -JobId $jobId -Secret $job.secret
            }
            catch {
                Write-Error "Failed to download results for $baseName : $_"
            }
        }
        else {
            Write-Warning "Job $baseName ($jobId) ended with status: $($job.status). Skipping download."
            # You can optionally retrieve logs via /job/logs?jobId=...&secret=... (GET) if needed
        }
    }

    Write-Host "Batch completed. Moving to next batch."
}

Write-Host "`nAll batches processed. Annotation complete."