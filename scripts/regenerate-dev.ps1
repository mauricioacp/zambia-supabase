#Requires -Version 5.1
<#
.SYNOPSIS
Manages a development environment involving Supabase, a CMS/App, and ngrok.
Can reset the environment, start services, seed data, and stop started services.

.DESCRIPTION
This script automates the process of resetting a local Supabase development environment,
starting necessary background services (Supabase functions, Node.js app, ngrok),
triggering initial data migration/seeding, and optionally stopping these background services later.
It now streams the output of synchronous commands like 'supabase start' to the console.

.PARAMETER StartServices
(Default) Use this parameter set to perform the full environment reset and start services.

.PARAMETER StopServices
Use this parameter set to stop the background services previously started by this script.

.EXAMPLE
.\YourScriptName.ps1 -Verbose
# Runs the default 'StartServices' action with detailed script and command output.

.EXAMPLE
.\YourScriptName.ps1 -StopServices
# Stops the background services (supabase functions, npm develop, ngrok) tracked by the script.

.NOTES
- Ensure Supabase CLI, Node.js/npm, ngrok, Deno, and pg_dump are installed and in your PATH.
- Configure the variables in the 'Configuration' section below.
- The script stores the PIDs of started background processes in a temporary file (%TEMP%\dev_env_pids.txt).
- The -StopServices switch relies on this file to identify which processes to terminate.
- Run with '-Verbose' to see detailed script steps and command output.
#>

[CmdletBinding(DefaultParameterSetName = 'Start')]
param(
    [Parameter(Mandatory=$false, ParameterSetName='Start')]
    [switch]$StartServices,

    [Parameter(Mandatory=$true, ParameterSetName='Stop')]
    [switch]$StopServices
)

# --- Configuration ---
$supabaseDir = "C:\Developer\supabase" # Base directory for Supabase project
$cmsDir = "C:\Developer\wuwei-cms"     # Base directory for CMS/App project

# --- File & Process Tracking ---
$pidFileName = "dev_env_pids.txt"
$pidFilePath = Join-Path $env:TEMP $pidFileName # Stores PIDs of background processes
$script:RunningProcesses = [System.Collections.Generic.List[int]]::new() # Script-level list to hold PIDs

# --- File Paths (Relative to Supabase Dir unless specified) ---
$functionsDir = Join-Path $supabaseDir "functions"
$functionsEnvFile = Join-Path $functionsDir ".env"
$supabaseEnvFile = Join-Path $supabaseDir "scripts\.env" # Often the same as functions .env, adjust if needed
$backupFileName = "data_seed.sql" # Name for the data backup file
$denoScriptName = "create-test-users.ts" # Name of the Deno seeding script
$denoScriptDir = Join-Path $supabaseDir "scripts" # Directory containing the Deno script

# --- Service Configuration ---
$initialMigrationName = "initial_migration" # Name for the initial auto-generated migration
$appPort = 1337 # Port your CMS/App runs on (used by npm run develop and ngrok)
$ngrokPort = $appPort # Port ngrok should expose
$supabaseFunctionUrl = "http://127.0.0.1:54321/functions/v1/strapi-migration" # URL of the Supabase function to trigger

# --- Database Configuration (Defaults for local Supabase) ---
$dbPort = 54322 # Default Supabase local DB port, verify with 'supabase status'
$dbUser = "postgres"
$dbPassword = "postgres" # WARNING: Avoid hardcoding sensitive data in production scripts. Consider secure alternatives.
$dbName = "postgres"
$dbHost = "localhost"

# --- Timing ---
$serviceStartupDelaySeconds = 15 # Increase if services need more time to start before proceeding
$supabaseStartDelaySeconds = 7   # Wait time after 'supabase start' (less critical now with live output, but kept for safety)

# --- Helper Functions ---

# Updated function to stream command output
function Invoke-CommandWithErrorCheck {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Command,
        [Parameter(Mandatory=$false)]
        [string[]]$Arguments,
        [Parameter(Mandatory=$true)]
        [string]$ErrorMessage,
        [Parameter(Mandatory=$false)]
        [string]$WorkingDirectory = $PWD,
        [switch]$IgnoreExitCode
    )

    $commandStringForLog = "$Command $($Arguments -join ' ')" # Use full path if available
    $commandNameOnly = Split-Path $Command -Leaf # Get just the command name for prefixing logs
    Write-Verbose "Executing in '$WorkingDirectory': $commandStringForLog"

    $processInfo = New-Object System.Diagnostics.ProcessStartInfo
    $processInfo.FileName = $Command
    $processInfo.Arguments = $Arguments -join ' '
    $processInfo.WorkingDirectory = $WorkingDirectory
    $processInfo.UseShellExecute = $false       # Required for redirection
    $processInfo.RedirectStandardOutput = $true # Redirect stdout
    $processInfo.RedirectStandardError = $true  # Redirect stderr
    $processInfo.CreateNoWindow = $true       # Don't create a separate window for the command

    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $processInfo

    # Script block for handling received output data
    $outputHandler = {
        if (-not [string]::IsNullOrEmpty($EventArgs.Data)) {
            # Prefix output with command name for clarity
            Write-Host "[$commandNameOnly] $($EventArgs.Data)"
        }
    }

    # Register event handlers for stdout and stderr
    $stdOutEvent = Register-ObjectEvent -InputObject $process -EventName 'OutputDataReceived' -Action $outputHandler -ErrorAction SilentlyContinue
    $stdErrEvent = Register-ObjectEvent -InputObject $process -EventName 'ErrorDataReceived' -Action $outputHandler -ErrorAction SilentlyContinue # Use same handler

    if (-not ($stdOutEvent -and $stdErrEvent)) {
         Write-Warning "Failed to register one or both output event handlers for $commandNameOnly."
         # Fallback to non-streaming execution might be needed here if critical
    }

    # Start the process and begin asynchronous reading of output streams
    try {
        $process.Start() | Out-Null
        $process.BeginOutputReadLine()
        $process.BeginErrorReadLine()

        Write-Verbose "Waiting for command '$commandStringForLog' to complete..."
        $process.WaitForExit() # Wait synchronously for the process to finish
        Write-Verbose "Command '$commandStringForLog' finished."

    } catch {
        Write-Warning "An error occurred while starting or waiting for '$commandStringForLog': $($_.Exception.Message)"
        # Consider how to handle this - maybe attempt to kill process?
        # For now, we'll proceed to the finally block and exit code check.
    } finally {
        # Ensure event handlers are unregistered
        if ($stdOutEvent) { Unregister-Event -SourceIdentifier $stdOutEvent.Name -ErrorAction SilentlyContinue }
        if ($stdErrEvent) { Unregister-Event -SourceIdentifier $stdErrEvent.Name -ErrorAction SilentlyContinue }
    }

    # Check the exit code after the process has finished
    $exitCode = $process.ExitCode
    Write-Verbose "Command '$commandStringForLog' exited with code $exitCode."
    if ($exitCode -ne 0 -and -not $IgnoreExitCode) {
        throw "$ErrorMessage (Command: '$commandStringForLog', Exit Code: $exitCode)"
    }
    # No need for "Command executed successfully" here as it's implied if no exception was thrown
}

function Get-SupabaseServiceKey {
    param(
        [Parameter(Mandatory=$true)]
        [string]$EnvFilePath
    )
    Write-Verbose "Attempting to read SUPABASE_SERVICE_ROLE_KEY from $EnvFilePath"
    if (-not (Test-Path $EnvFilePath -PathType Leaf)) {
        throw ".env file not found at $EnvFilePath"
    }

    # Read .env file, find the key, ignore comments, extract value
    $serviceKeyLine = Get-Content $EnvFilePath | Where-Object { $_ -match '^\s*SUPABASE_SERVICE_ROLE_KEY\s*=' -and $_ -notmatch '^\s*#' } | Select-Object -First 1

    if ($serviceKeyLine) {
        $serviceKey = ($serviceKeyLine -split '=', 2)[1].Trim().Trim("'""").Trim() # Handle potential quotes
        if (-not [string]::IsNullOrWhiteSpace($serviceKey)) {
            Write-Host "Supabase Service Role Key loaded successfully from .env file."
            # DO NOT Write-Host the key itself for security. Use Write-Verbose if needed for debugging.
            Write-Verbose "Service Key loaded (length: $($serviceKey.Length))."
            return $serviceKey
        }
    }

    throw "SUPABASE_SERVICE_ROLE_KEY not found, empty, or could not be parsed in $EnvFilePath"
}

function Start-TrackedProcess {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Command,
        [Parameter(Mandatory=$true)]
        [string[]]$Arguments,
        [Parameter(Mandatory=$true)]
        [string]$ProcessName, # For logging purposes
        [Parameter(Mandatory=$false)]
        [string]$WorkingDirectory = $PWD
    )
    # This function starts processes in the background, so we don't stream output here.
    # We just start it and track the PID.
    Write-Host "Starting $ProcessName ($Command $($Arguments -join ' ')) (background)..."
    try {
        # Use -WindowStyle Hidden if you don't want brief console flashes
        $process = Start-Process $Command -ArgumentList $Arguments -WorkingDirectory $WorkingDirectory -NoNewWindow -PassThru -ErrorAction Stop
        if ($process) {
            $script:RunningProcesses.Add($process.Id)
            Write-Verbose "$ProcessName started successfully with PID: $($process.Id)"
            return $process # Return the process object if needed elsewhere
        } else {
            # This case might happen if the command exits immediately or fails very early
            Write-Warning "$ProcessName ($Command) did not return a running process object or exited too quickly."
            return $null
        }
    } catch {
        throw "Failed to start $ProcessName. Error: $($_.Exception.Message)"
    }
}

function Stop-TrackedProcesses {
    param(
        [Parameter(Mandatory=$true)]
        [string]$PidStoragePath
    )
    Write-Host "Attempting to stop background services..."
    if (-not (Test-Path $PidStoragePath -PathType Leaf)) {
        Write-Warning "PID file not found at $PidStoragePath. No tracked services to stop."
        return
    }

    # Read PIDs, ensuring they are valid integers
    $pidsToStop = Get-Content $PidStoragePath -ErrorAction SilentlyContinue | ForEach-Object {
        try {
            [int]$_
        } catch {
            Write-Warning "Invalid PID found in ${PidStoragePath}: '$($_)'. Skipping."
            $null # Output $null for invalid lines
        }
    } | Where-Object { $_ -ne $null } # Filter out nulls from invalid lines

    if ($pidsToStop.Count -eq 0) {
        Write-Warning "PID file at $PidStoragePath is empty or contains no valid PIDs. No PIDs to stop."
        Remove-Item $PidStoragePath -Force -ErrorAction SilentlyContinue
        return
    }

    Write-Verbose "Found PIDs to stop: $($pidsToStop -join ', ')"
    $stoppedCount = 0
    $notFoundCount = 0

    foreach ($pid in $pidsToStop) {
        $process = Get-Process -Id $pid -ErrorAction SilentlyContinue
        if ($process) {
            Write-Host "Stopping process '$($process.ProcessName)' (PID: $pid)..."
            try {
                # Attempt to stop gracefully first, then force if needed? For simplicity, just force.
                Write-Verbose "Attempting to stop PID: $processIdToStop" # Add this line
                Stop-Process -Id $pid -Force -ErrorAction Stop
                Write-Verbose "Successfully sent stop signal to PID $pid."
                $stoppedCount++
            } catch {
                Write-Warning "Failed to stop process with PID $pid. It might have already exited or requires higher privileges. Error: $($_.Exception.Message)"
            }
        } else {
            Write-Verbose "Process with PID $pid not found. It may have already terminated."
            $notFoundCount++
        }
    }

    Write-Host "Finished stopping services. Stopped: $stoppedCount, Not Found/Already Exited: $notFoundCount."

    # Clean up the PID file
    Write-Verbose "Removing PID file: $PidStoragePath"
    Remove-Item $PidStoragePath -Force -ErrorAction SilentlyContinue
}


# --- Main Script Logic ---

# --- Stop Services Parameter Set ---
if ($StopServices) {
    Stop-TrackedProcesses -PidStoragePath $pidFilePath
    exit 0 # Exit after stopping services
}

# --- Start Services Parameter Set (Default) ---
# Wrap the main logic in a try/finally to ensure cleanup
$originalLocation = $PWD
$envPasswordSet = $false
try {
    # --- Pre-flight Checks ---
    Write-Host "Starting Development Environment Reset..." -ForegroundColor Cyan

    if (Test-Path $pidFilePath -PathType Leaf) {
         Write-Warning "PID file found at '$pidFilePath'. Previous services might still be running."
         Write-Warning "Consider running the script with '-StopServices' first if you encounter issues."
         # Optionally, uncomment the next line to force stopping before starting
         # Stop-TrackedProcesses -PidStoragePath $pidFilePath
         # Or uncomment the next line to exit if the file exists
         # throw "PID file '$pidFilePath' exists. Run with -StopServices first or manually delete the file."
    }

    Write-Host "Checking prerequisites..."
    if (-not (Test-Path $supabaseDir -PathType Container)) { throw "Supabase directory not found: $supabaseDir" }
    if (-not (Test-Path $cmsDir -PathType Container)) { throw "CMS directory not found: $cmsDir" }
    # Add checks for commands if needed (e.g., Get-Command supabase, npm, ngrok, deno, pg_dump)

    # --- Step 1: Navigate to Supabase Directory ---
    Write-Host "(1/11) Navigating to Supabase directory: $supabaseDir"
    Push-Location $supabaseDir

    # --- Step 2: Stop Supabase ---
    Write-Host "(2/11) Stopping Supabase instance (if running)..."
    # Use IgnoreExitCode as 'supabase stop' might return non-zero if already stopped
    # Output from 'supabase stop' will now be streamed
    Invoke-CommandWithErrorCheck -Command "supabase" -Arguments "stop" -ErrorMessage "Failed to execute Supabase stop command" -IgnoreExitCode

    # --- Step 3: Reset Migrations ---
    Write-Host "(3/11) Resetting migrations directory..."
    $migrationsDir = Join-Path $PWD "migrations"
    if (Test-Path $migrationsDir -PathType Container) {
        Write-Verbose "Deleting existing migrations directory: $migrationsDir"
        Remove-Item -Recurse -Force $migrationsDir
        if ($LASTEXITCODE -ne 0) { throw "Failed to delete migrations directory" }
        Write-Verbose "Migrations directory deleted."
    } else {
        Write-Verbose "Migrations directory does not exist, skipping deletion."
    }
    Write-Verbose "Creating empty migrations directory."
    New-Item -ItemType Directory -Path $migrationsDir -ErrorAction SilentlyContinue | Out-Null

    # --- Step 4: Generate Initial Migration ---
    Write-Host "(4/11) Generating initial migration file..."
    # Output from 'supabase db diff' will now be streamed
    try {
         Invoke-CommandWithErrorCheck -Command "supabase" -Arguments "db", "diff", "-f", $initialMigrationName -ErrorMessage "Failed to generate initial migration file"
    } catch {
        Write-Warning "Could not generate initial migration diff. This might be expected if the DB was fully stopped. Error: $($_.Exception.Message)"
        Write-Warning "Ensure your migrations folder is correctly set up for 'supabase db reset'."
    }

    # --- Step 5: Start Supabase ---
    Write-Host "(5/11) Starting Supabase instance..."
    # Output from 'supabase start' will now be streamed
    Invoke-CommandWithErrorCheck -Command "supabase" -Arguments "start", "--debug" -ErrorMessage "Failed to start Supabase"
    Write-Verbose "Supabase start command finished. Waiting $supabaseStartDelaySeconds seconds for internal services..."
    Start-Sleep -Seconds $supabaseStartDelaySeconds # Keep a short delay just in case internal services need a moment after the command exits

    # --- Step 6: Apply Migrations ---
    Write-Host "(6/11) Applying database migrations..."
    # Output from 'supabase db reset' will now be streamed
    Invoke-CommandWithErrorCheck -Command "supabase" -Arguments "db", "reset" -ErrorMessage "Failed to apply migrations"

    # --- Step 7: Start Supabase Functions (Background) ---
    # Start-TrackedProcess is used here, so output is NOT streamed (it runs in background)
    $funcArgs = @("functions", "serve", "--no-verify-jwt") # Add --no-verify-jwt if needed for local dev
    if (Test-Path $functionsEnvFile -PathType Leaf) {
        Write-Verbose "Using functions env file: $functionsEnvFile"
        $funcArgs += "--env-file", $functionsEnvFile
    } else {
        Write-Verbose "Optional functions .env file not found at $functionsEnvFile, starting without it."
    }
    Start-TrackedProcess -Command "supabase" -Arguments $funcArgs -ProcessName "Supabase Functions" -WorkingDirectory $supabaseDir

    # --- Step 8: Navigate to CMS Directory ---
    Write-Host "(7/11) Navigating to CMS/App directory: $cmsDir"
    Push-Location $cmsDir

    # --- Step 9.1: Ensure port is free before starting the CMS/App ---
    Write-Host "(7.1/11) Checking for processes on port $appPort..."
    $existingPids = @(Get-NetTCPConnection -LocalPort $appPort -ErrorAction SilentlyContinue | Select-Object -ExpandProperty OwningProcess | Select-Object -Unique)
    foreach ($p in $existingPids) {
        try {
            Write-Host "Killing process on port $appPort (PID: $p)..."
            Stop-Process -Id $p -Force -ErrorAction Stop
        } catch {
            Write-Warning "Could not kill process $p: $($_.Exception.Message)"
        }
    }
    # --- End port cleanup ---

    # --- Step 9: Start App Server (Background) ---
    # Start-TrackedProcess is used here, so output is NOT streamed
    Start-TrackedProcess -Command "npm" -Arguments "run", "develop" -ProcessName "App Dev Server (npm)" -WorkingDirectory $cmsDir


    # --- Step 11: Trigger Supabase Function & Run Deno Script ---
    Pop-Location # Back to Supabase Dir ($supabaseDir)

    Write-Host "(8/11) Triggering Supabase function: $supabaseFunctionUrl"
        try {
            $serviceKey = Get-SupabaseServiceKey -EnvFilePath $supabaseEnvFile
        Write-Verbose "Attempting to invoke function..."
            $headers = @{
                "Authorization" = "Bearer $serviceKey"
                "Content-Type"  = "application/json"
                "Accept"        = "application/json"
            }
            $response = Invoke-RestMethod -Uri $supabaseFunctionUrl -Method Get -Headers $headers -TimeoutSec 60 -UseBasicParsing -ErrorAction Stop
            Write-Host "Supabase function triggered successfully."
            Write-Verbose "Function Response: $($response | ConvertTo-Json -Depth 3)"
        } catch {
        throw "Critical failure: Could not trigger Supabase function at $supabaseFunctionUrl. Error: $($_.Exception.Message)"
    }

    Write-Host "(9/11) Running Deno seeding script..."
    $denoScriptPath = Join-Path $denoScriptDir $denoScriptName
    if (Test-Path $denoScriptPath -PathType Leaf) {
        # Output from 'deno run' will now be streamed
        Invoke-CommandWithErrorCheck -Command "deno" -Arguments "run", "--allow-net", "--allow-env", "--allow-read", "--allow-write", $denoScriptPath -ErrorMessage "Failed to run Deno script" -WorkingDirectory $supabaseDir
    } else {
        throw "Deno script not found at $denoScriptPath"
    }

    # --- Step 12: Generate Data Backup ---
    Write-Host "(10/11) Generating data-only backup..."
    $backupFilePath = Join-Path $supabaseDir $backupFileName
    $env:PGPASSWORD = $dbPassword
    $envPasswordSet = $true
    try {
        $pgDumpArgs = @(
            "--data-only", "--no-owner", "--no-privileges", "--inserts",
            "--username=$dbUser", "--host=$dbHost", "--port=$dbPort", "--dbname=$dbName",
            "--file=$backupFilePath"
        )
        # Output from 'pg_dump' will now be streamed
        Invoke-CommandWithErrorCheck -Command "pg_dump" -Arguments $pgDumpArgs -ErrorMessage "Failed to generate data backup using pg_dump" -WorkingDirectory $supabaseDir
        Write-Host "Data backup created successfully: $backupFilePath"
    } finally {
        if ($envPasswordSet) {
            Write-Verbose "Clearing PGPASSWORD environment variable."
            Remove-Variable -Name PGPASSWORD -Scope Env -Force -ErrorAction SilentlyContinue
            $envPasswordSet = $false
        }
    }

    # --- Step 13: Save PIDs ---
    Write-Host "(11/11) Saving background process PIDs to $pidFilePath"
    if ($script:RunningProcesses.Count -gt 0) {
        try {
            $script:RunningProcesses | Out-File -FilePath $pidFilePath -Encoding utf8 -Force -ErrorAction Stop
            Write-Verbose "PIDs ($($script:RunningProcesses -join ', ')) saved."
        } catch {
            Write-Warning "Failed to save PIDs to $pidFilePath. You may need to stop processes manually. Error: $($_.Exception.Message)"
            $script:RunningProcesses.Clear()
        }
    } else {
        Write-Warning "No background processes were successfully started or tracked. PID file not created."
    }

    # --- Completion ---
    Write-Host "`n✅✅✅ Development Environment Reset and Startup Completed Successfully ✅✅✅" -ForegroundColor Green
    if ($script:RunningProcesses.Count -gt 0) {
         Write-Host "➡️ Background services are running. Use '$($MyInvocation.MyCommand.Name) -StopServices' to terminate them." -ForegroundColor Yellow
    }
    Write-Host "➡️ Data seed backup saved to: $backupFilePath"

} catch {
    Write-Error "❌❌❌ Script execution failed: $($_.Exception.Message)"
    Write-Error "Error occurred at: $($_.InvocationInfo.PositionMessage)"
    # Attempt to stop any processes that might have been started before the error
    if ($script:RunningProcesses.Count -gt 0) {
        Write-Warning "Attempting to stop already started background processes due to script failure..."
        $tempPidPath = "$pidFilePath.error"
        $script:RunningProcesses | Out-File -FilePath $tempPidPath -Encoding utf8 -Force -ErrorAction SilentlyContinue
        if (Test-Path $tempPidPath) {
            Write-Verbose "Entering cleanup catch block. Attempting call to Stop-TrackedProcesses." # Add this line
             Stop-TrackedProcesses -PidStoragePath $tempPidPath # Use the stop function
             Remove-Item $tempPidPath -Force -ErrorAction SilentlyContinue # Clean up temp file
        }
    }
    # Also remove the main PID file if it exists, as the startup was incomplete
    if (Test-Path $pidFilePath) {
        Write-Verbose "Removing potentially incomplete PID file due to error: $pidFilePath"
        Remove-Item $pidFilePath -Force -ErrorAction SilentlyContinue
    }
    exit 1
} finally {
    # Ensure PGPASSWORD is clear, regardless of success or failure
    if ($envPasswordSet) {
        Write-Verbose "Ensuring PGPASSWORD environment variable is cleared in finally block."
        Remove-Variable -Name PGPASSWORD -Scope Env -Force -ErrorAction SilentlyContinue
    }
    # Restore original location robustly
    while ($Host.UI.RawUI.WindowTitle -match 'Push-Location') {
        try { Pop-Location -ErrorAction Stop } catch { break }
    }
    Write-Verbose "Restored original location: $originalLocation"
    Write-Verbose "Script execution finished."
}