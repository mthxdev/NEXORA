<# 
.SYNOPSIS
    Orchestrateur KiloCode pour Nexora — exécute une tâche définie en JSON, génère un rapport standardisé.

.DESCRIPTION
    Lit un fichier de tâche dans .kilo/tasks/, lance `kilo run` avec le prompt,
    collecte les résultats (session, git diff, build status, tests), produit un rapport JSON.

.PARAMETER TaskFile
    Chemin vers le fichier JSON de tâche (défaut: le plus récent dans .kilo/tasks/)

.PARAMETER WaitForBuild
    Attendre la fin du build GitHub Actions et inclure le statut dans le rapport.

.PARAMETER OutputDir
    Dossier de sortie pour le rapport (défaut: .kilo/reports/)

.EXAMPLE
    .\scripts\kilo-orchestrator.ps1 -TaskFile .\kilo\tasks\ma-tache.json -WaitForBuild

.NOTES
    Nécessite: kilo CLI installé, git, gh CLI (pour wait-build), jq (optionnel)
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$TaskFile = "",

    [Parameter(Mandatory=$false)]
    [switch]$WaitForBuild,

    [Parameter(Mandatory=$false)]
    [string]$OutputDir = "C:\Dev\_Mathieu\02_Projets\Perso\Nexora\.kilo\reports",

    [Parameter(Mandatory=$false)]
    [string]$KiloCmd = "kilo",

    [Parameter(Mandatory=$false)]
    [int]$TimeoutMinutes = 60
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $ts = Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ"
    Write-Host "[$ts] [$Level] $Message"
}

function Read-TaskFile {
    param([string]$Path)
    if (-not (Test-Path $Path)) {
        throw "Fichier de tâche introuvable : $Path"
    }
    $content = Get-Content $Path -Raw -Encoding UTF8
    return $content | ConvertFrom-Json
}

function New-Report {
    param(
        [string]$TaskId,
        [string]$Status,
        [datetime]$StartedAt,
        [datetime]$CompletedAt,
        [string]$KiloSessionId,
        [hashtable]$GitInfo,
        [hashtable]$BuildInfo,
        [hashtable]$TestInfo,
        [string[]]$Errors,
        [string[]]$Warnings,
        [hashtable]$Artifacts,
        [string[]]$NextSteps
    )
    return @{
        task_id = $TaskId
        status = $Status
        started_at = $StartedAt.ToString("o")
        completed_at = $CompletedAt.ToString("o")
        kilo_session_id = $KiloSessionId
        git = $GitInfo
        build = $BuildInfo
        tests = $TestInfo
        errors = $Errors
        warnings = $Warnings
        artifacts = $Artifacts
        next_steps = $NextSteps
    }
}

function Get-GitInfo {
    param([string]$BaseCommit, [string]$BranchName)
    $repoRoot = "C:\Dev\_Mathieu\02_Projets\Perso\Nexora"
    
    $headCommit = git -C $repoRoot rev-parse HEAD
    $diffStat = git -C $repoRoot diff --shortstat $BaseCommit 2>$null
    $filesChanged = git -C $repoRoot diff --name-only $BaseCommit 2>$null | Measure-Object | Select-Object -ExpandProperty Count
    
    $added = 0; $removed = 0
    if ($diffStat -match "(\d+) insertion") { $added = [int]$matches[1] }
    if ($diffStat -match "(\d+) deletion") { $removed = [int]$matches[1] }
    
    $diffContent = git -C $repoRoot diff $BaseCommit 2>$null
    
    return @{
        branch = $BranchName
        base_commit = $BaseCommit
        head_commit = $headCommit.Trim()
        files_changed = $filesChanged
        lines_added = $added
        lines_removed = $removed
        diff_available = $diffContent.Length -gt 0
    }
}

function Invoke-KiloTask {
    param(
        [string]$Prompt,
        [string]$BranchName,
        [string]$SessionId,
        [bool]$AutoApprove = $false
    )
    
    $repoRoot = "C:\Dev\_Mathieu\02_Projets\Perso\Nexora"
    
    # Créer/switcher vers la branche de travail
    $currentBranch = git -C $repoRoot branch --show-current
    if ($currentBranch -ne $BranchName) {
        if (git -C $repoRoot show-ref --verify --quiet "refs/heads/$BranchName") {
            Write-Log "Branche $BranchName existe, checkout..."
            git -C $repoRoot checkout $BranchName
        } else {
            Write-Log "Création branche $BranchName..."
            git -C $repoRoot checkout -b $BranchName
        }
    }
    
    # Construire la commande kilo
    $args = @("run")
    if ($SessionId) { $args += "--session", $SessionId, "--fork" }
    $args += "--format", "json"
    $args += "--dir", $repoRoot
    if ($AutoApprove) { $args += "--auto" }
    $args += "--title", "Nexora Task: $BranchName"
    $args += $Prompt
    
    Write-Log "Lancement: $KiloCmd $($args -join ' ')"
    
    $startTime = Get-Date
    $result = & $KiloCmd @args 2>&1
    $exitCode = $LASTEXITCODE
    $duration = (Get-Date) - $startTime
    
    Write-Log "Kilo terminé en $($duration.TotalSeconds)sec, exit code: $exitCode"
    
    # Essayer d'extraire le session ID depuis la sortie
    $sessionId = $null
    if ($result -match '"session_id"\s*:\s*"([^"]+)"') { $sessionId = $matches[1] }
    elseif ($result -match 'session[:\s]+([a-f0-9-]+)') { $sessionId = $matches[1] }
    
    return @{
        exit_code = $exitCode
        output = $result
        session_id = $sessionId
        duration_seconds = $duration.TotalSeconds
    }
}

function Wait-GitHubBuild {
    param([string]$Repo = "mthxdev/NEXORA", [int]$MaxWaitMinutes = 30)
    
    if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
        Write-Log "gh CLI non trouvé, impossible d'attendre le build" -Level "WARN"
        return @{ triggered = $false; status = "unknown"; message = "gh CLI not installed" }
    }
    
    Write-Log "Attente du build GitHub Actions (max ${MaxWaitMinutes}min)..."
    $startTime = Get-Date
    $runId = $null
    
    while ((Get-Date) - $startTime -lt (New-TimeSpan -Minutes $MaxWaitMinutes)) {
        # Trouver le dernier run pour cette branche
        $runs = gh run list --repo $Repo --limit 5 --json databaseId,status,conclusion,headBranch,createdAt 2>$null | ConvertFrom-Json
        if ($runs) {
            $latest = $runs | Where-Object { $_.headBranch -eq (git -C $repoRoot branch --show-current) } | Select-Object -First 1
            if ($latest) {
                $runId = $latest.databaseId
                if ($latest.status -eq "completed") {
                    Write-Log "Build terminé: $($latest.conclusion)"
                    # Récupérer l'URL de l'artefact
                    $artifacts = gh run view $runId --repo $Repo --json artifacts 2>$null | ConvertFrom-Json
                    $ipaUrl = ""
                    if ($artifacts) {
                        $ipa = $artifacts.artifacts | Where-Object { $_.name -eq "Nexora-ipa" } | Select-Object -First 1
                        if ($ipa) { $ipaUrl = $ipa.url }
                    }
                    return @{
                        triggered = $true
                        workflow_run_id = $runId
                        status = $latest.conclusion
                        ipa_url = $ipaUrl
                        icon_verification = if ($latest.conclusion -eq "success") { "passed" } else { "failed" }
                    }
                }
            }
        }
        Start-Sleep -Seconds 30
    }
    
    Write-Log "Timeout attente build" -Level "WARN"
    return @{ triggered = $true; workflow_run_id = $runId; status = "timeout"; ipa_url = ""; icon_verification = "unknown" }
}

# ============================================================
# MAIN
# ============================================================

$repoRoot = "C:\Dev\_Mathieu\02_Projets\Perso\Nexora"
Set-Location $repoRoot

# Déterminer le fichier de tâche
if (-not $TaskFile) {
    $files = Get-ChildItem "$repoRoot\.kilo\tasks" -Filter "*.json" | Sort-Object LastWriteTime -Descending
    if ($files.Count -eq 0) { throw "Aucun fichier de tâche dans .kilo\tasks\" }
    $TaskFile = $files[0].FullName
    Write-Log "Aucun fichier spécifié, utilisation du plus récent : $TaskFile"
}

$task = Read-TaskFile $TaskFile
$taskId = $task.id
$branchName = $task.scope.branch
$baseCommit = (git -C $repoRoot rev-parse HEAD).Trim()

Write-Log "=== DÉBUT TÂCHE: $taskId ==="
Write-Log "Titre: $($task.title)"
Write-Log "Branche: $branchName"
Write-Log "Commit de base: $baseCommit"

$startedAt = Get-Date
$errors = @()
$warnings = @()

try {
    # Exécuter la tâche Kilo
    $kiloResult = Invoke-KiloTask -Prompt $task.prompt -BranchName $branchName -SessionId $task.metadata.session_id
    
    if ($kiloResult.exit_code -ne 0) {
        $errors += "Kilo exit code: $($kiloResult.exit_code)"
        $errors += "Output: $($kiloResult.output.Substring(0, [Math]::Min(500, $kiloResult.output.Length)))"
    }
    
    # Infos Git
    $gitInfo = Get-GitInfo -BaseCommit $baseCommit -BranchName $branchName
    
    # Build GitHub Actions (optionnel)
    $buildInfo = @{ triggered = $false; status = "skipped" }
    if ($task.validation.build_required -or $WaitForBuild) {
        $buildInfo = Wait-GitHubBuild -MaxWaitMinutes 30
    }
    
    # Tests (info seulement — pas d'exécution locale sur Windows)
    $testInfo = @{
        executed = @()
        passed = 0
        failed = 0
        skipped = 0
        note = "Tests SwiftTesting requièrent macOS + Xcode. Non exécutés localement."
    }
    
    $status = if ($errors.Count -gt 0) { "failed" } elseif ($buildInfo.status -eq "failure") { "failed" } else { "completed" }
    
} catch {
    $errors += "Exception: $($_.Exception.Message)"
    $status = "failed"
    $gitInfo = @{ branch = $branchName; base_commit = $baseCommit; error = $_.Exception.Message }
    $buildInfo = @{ triggered = $false; status = "error" }
    $testInfo = @{ executed = @(); passed = 0; failed = 0; skipped = 0 }
    $kiloResult = @{ session_id = $null }
} finally {
    $completedAt = Get-Date
    
    # Sauvegarder le diff
    $diffPath = ""
    if ($gitInfo.diff_available) {
        $diffPath = "$OutputDir\$taskId.diff"
        git -C $repoRoot diff $baseCommit > $diffPath 2>$null
    }
    
    # Exporter la session Kilo si possible
    $sessionExportPath = ""
    if ($kiloResult.session_id) {
        $sessionExportPath = "$OutputDir\$taskId-session.json"
        & $KiloCmd export $kiloResult.session_id --format json > $sessionExportPath 2>$null
    }
    
    # Construire le rapport
    $report = New-Report `
        -TaskId $taskId `
        -Status $status `
        -StartedAt $startedAt `
        -CompletedAt $completedAt `
        -KiloSessionId $kiloResult.session_id `
        -GitInfo $gitInfo `
        -BuildInfo $buildInfo `
        -TestInfo $testInfo `
        -Errors $errors `
        -Warnings $warnings `
        -Artifacts @{
            session_export = if ($sessionExportPath) { $sessionExportPath } else { "" }
            diff = if ($diffPath) { $diffPath } else { "" }
        } `
        -NextSteps $task.validation.manual_verification
    
    $reportPath = "$OutputDir\$taskId-report.json"
    $report | ConvertTo-Json -Depth 10 | Set-Content $reportPath -Encoding UTF8
    
    Write-Log "=== RAPPORT GÉNÉRÉ: $reportPath ==="
    Write-Log "Status: $status"
    Write-Log "Git: $($gitInfo.files_changed) fichiers, +$($gitInfo.lines_added)/-$($gitInfo.lines_removed)"
    Write-Log "Build: $($buildInfo.status)"
    
    if ($errors.Count -gt 0) {
        Write-Log "ERREURS:" -Level "ERROR"
        $errors | ForEach-Object { Write-Log "  - $_" -Level "ERROR" }
    }
    
    # Afficher le résumé pour ChatGPT
    Write-Log "--- SUMMARY FOR CHATGPT ---"
    $report | ConvertTo-Json -Depth 5 -Compress
}