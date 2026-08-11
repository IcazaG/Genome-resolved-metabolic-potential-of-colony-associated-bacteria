# Bakta API Batch Annotation Script

PowerShell script to annotate genomes (FASTA files) in batches using the Bakta web API. Automates upload, tracking, and download of results, organizing each genome in its own folder.
Pl

## Responsible use

The Bakta web API is a free, shared resource maintained for the research community. Please use this script conscientiously to avoid overloading the servers:

-  Keep $BatchSize at a reasonable level (avoid launching very large batches at once).
-  Do not set $PollIntervalSeconds too low. frequent polling adds unnecessary load; 30–60 seconds is generally sufficient.
-  Avoid running multiple instances of the script in parallel against the same API.
-  Only (re)submit genomes that actually need annotation, and use the cleanup function (Invoke-BaktaDelete) to -remove finished jobs you no longer need.
-  If you plan to annotate very large numbers of genomes, consider running Bakta locally instead of via the web API.

## Requirements

-   PowerShell 5.1+ (Windows) or PowerShell Core (Linux/macOS)
-   Internet access to communicate with the Bakta API
-   Input files with extension `.fa` (nucleotide FASTA)
-   No credentials required for basic API usage

## Configuration

Before running, edit the following variables in the `# -------------------- Configuration --------------------` section of the script:

| Variable               | Description                                                                                       |
|-------------------------|-----------------------------------------------------------------------------------------------------|
| `$MAGsDir`              | Path to the directory containing your `.fa` files.                                                 |
| `$OutputRoot`           | Root directory where results folders will be created. Default: `$MAGsDir\bakta_results`.           |
| `$BatchSize`            | Number of genomes processed simultaneously (default 10).                                           |
| `$PollIntervalSeconds`  | Seconds between status checks (default 60).                                                         |
| `$ApiBaseUrl`           | URL of the Bakta API (do not modify unless the endpoint changes).                                  |

```powershell
$MAGsDir = "C:\MyGenomes"
$BatchSize = 5
$PollIntervalSeconds = 30
```

## Usage

1. Place all your genomes (`.fa`) in `$MAGsDir`.
2. Open a PowerShell console in the script's folder.
3. Run:

```powershell
.\bakta_batch_annotation.ps1
```

If you have execution restrictions:

```powershell
powershell -ExecutionPolicy Bypass -File .\bakta_batch_annotation.ps1
```

The script will show progress in the console, and when finished, each genome will have its own subfolder with the downloaded results.

## Workflow

1. **Initialization** – For each FASTA, calls `/job/init` and gets `jobID`, `secret`, and upload URL.
2. **Upload** – Sends the file via `PUT` to the provided URL.
3. **Start** – Sends annotation configuration to `/job/start`.
4. **Monitoring** – Periodically queries `/job/list` until all jobs in the batch finish.
5. **Download** – When a job finishes successfully (`SUCCESSFUL`), downloads all result files via `/job/result`.
6. **Next batch** – Repeats the process with the next group of files.

## Annotation configuration

The script uses these parameters (you can modify them in the `Invoke-BaktaStart` function):

| Parameter            | Value    | Description                             |
|------------------------|----------|-------------------------------------------|
| `completeGenome`       | `$false` | Does not assume a complete genome.        |
| `compliant`            | `$false` | Does not force standard compliance.       |
| `keepContigHeaders`    | `$true`  | Keeps original contig headers.            |
| `minContigLength`      | `200`    | Minimum contig length to consider.        |
| `translationTable`     | `11`     | Bacterial genetic code.                   |
| Others                 | empty or `$null` | Genus, species, strain, etc. left unspecified. |

## Output structure

For each genome, a folder is created with the FASTA base name. Inside, the files returned by the API are downloaded (examples):

- `{jobID}.embl` – EMBL flat file
- `{jobID}.faa` – Predicted proteins
- `{jobID}.hypotheticals.faa` – Hypothetical proteins
- `{jobID}.ffn` – Nucleotide gene sequences
- `{jobID}.fna` – Annotated contigs
- `{jobID}.gbff` – GenBank flat file
- `{jobID}.gff3` – GFF3 file
- `{jobID}.json` – Complete data in JSON
- `{jobID}.png` / `{jobID}.svg` – Circular plot
- `{jobID}.tsv` – Annotation table
- `{jobID}.hypothetical.tsv` – Hypotheticals table
- `{jobID}.inference.tsv` – Inferences
- `{jobID}.txt` – Process logs

All files include the `jobID` in their name to avoid collisions.

## Job cleanup

The script has the `Invoke-BaktaDelete` function commented out. If you want to delete jobs from the server after download (to free resources), uncomment this line in the download section:

```powershell
# Invoke-BaktaDelete -JobId $jobId -Secret $job.secret
```

## Error handling

- Jobs with a status other than `SUCCESSFUL` are logged as a warning and are not downloaded.
- If the API does not respond, the script waits 30 seconds and retries.
- Upload or download errors are displayed in the console but do not stop batch processing.

## Additional notes

- The script works on Windows, Linux, and macOS with PowerShell Core.
- Adjust `$BatchSize` and `$PollIntervalSeconds` according to API limits and your connection.
- Input files must have a `.fa` extension. If you use another, change the `-Filter "*.fa"` filter.

## Support

If you encounter problems:

1. Check your Internet connection.
2. Make sure the API URL is accessible.
3. Verify that the FASTA files are not corrupt.
4. Review error messages in the console.

## License

This script is provided "as is" without warranty. You may modify and distribute it freely.
