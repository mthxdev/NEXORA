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

.PARAMETER KiloCmd
    Commande KiloCode à utiliser (défaut: kilo)

.PARAMETER TimeoutMinutes
    Timeout maximal pour l'exécution KiloCode (défaut: 60)

.EXAMPLE
    .\scripts\kilo-orchestrator.ps1 -TaskFile .\kilo\tasks\ma-tache.json -WaitForBuild

.NOTES
    Nécessite: kilo CLI installé, git, gh CLI (pour wait-build)
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
    
    $headCommit = git -C $repoRoot rev-parse HEAD 2>$null
    $diffStat = git -C $repoRoot diff --shortstat $BaseCommit 2>$null
    $filesChanged = git -C $repoRoot diff --name-only $BaseCommit 2>$null | Measure-Object | Select-Object -ExpandProperty Count
    
    $added = 0; $removed = 0
    if ($diffStat -match "(\d+) insertion") { $added = [int]$matches[1] }
    if ($diffStat -match "(\d+) deletion") { $removed = [int]$matches[1] }
    
    $diffContent = git -C $repoRoot diff $BaseCommit 2>$null
    
    return @{
        branch = $BranchName
        base_commit = $BaseCommit
        head_commit = if ($headCommit) { $headCommit.Trim() } else { "" }
        files_changed = $filesChanged
        lines_added = $added
        lines_removed = $removed
        diff_available = ($null -ne $diffContent) -and ($diffContent.Length -gt 0)
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
    
    Write-Log "Invoke-KiloTask: starting for branch $BranchName" -Level "DEBUG"
    
    # Créer/switcher vers la branche de travail
    $currentBranch = git -C $repoRoot branch --show-current
    Write-Log "Invoke-KiloTask: current branch = $currentBranch, target = $BranchName" -Level "DEBUG"
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
    if ($SessionId -and $SessionId.Length -gt 0) { 
        $args += "--session", $SessionId, "--fork" 
    }
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
    
    # Essayer d'extraire le session ID depuis la sortie (streaming JSON)
    $sessionId = $null
    # Format observé: "sessionID":"ses_..." dans les événements step_start/step_finish
    $patterns = @(
        '"sessionID"\s*:\s*"([^"]+)"',
        '"session_id"\s*:\s*"([^"]+)"',
        'session[:\s]+([a-f0-9-]{36})'
    )
    
    foreach ($pattern in $patterns) {
        $match = [regex]::Match($result, $pattern)
        if ($match.Success -and $match.Groups.Count -gt 1) {
            $sessionId = $match.Groups[1].Value
            break
        }
    }
    
    if (-not $sessionId) {
        Write-Log "Impossible d'extraire session_id depuis la sortie Kilo" -Level "WARN"
    }
    
    Write-Log "Invoke-KiloTask: returning exit_code=$exitCode, session_id=$sessionId" -Level "DEBUG"
    
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

# Variables initialisées AVANT try pour être accessibles dans catch/finally
$kiloResult = @{ exit_code = -1; output = ""; session_id = $null; duration_seconds = 0 }
$gitInfo = @{ branch = $branchName; base_commit = $baseCommit; head_commit = ""; files_changed = 0; lines_added = 0; lines_removed = 0; diff_available = $false }
$buildInfo = @{ triggered = $false; status = "skipped" }
$testInfo = @{ executed = @(); passed = 0; failed = 0; skipped = 0; note = "Tests SwiftTesting requièrent macOS + Xcode. Non exécutés localement." }
$status = "failed"

try {
    # Exécuter la tâche Kilo
    $sessionId = ""
    # Accès sécurisé à metadata.session_id
    $meta = $null
    if ($task.PSObject.Properties['metadata']) { $meta = $task.metadata }
    if ($meta -and $meta.PSObject.Properties['session_id']) { 
        $sessionId = $meta.session_id 
    }
    
    $kiloResult = Invoke-KiloTask -Prompt $task.prompt -BranchName $branchName -SessionId $sessionId
    Write-Log "Invoke-KiloTask returned: exit_code=$($kiloResult.exit_code), session_id=$($kiloResult.session_id)"
    
    if ($kiloResult.exit_code -ne 0) {
        $errors += "Kilo exit code: $($kiloResult.exit_code)"
        $outputPreview = $kiloResult.output
        if ($outputPreview.Length -gt 500) { $outputPreview = $outputPreview.Substring(0, 500) }
        $errors += "Output: $outputPreview"
    }
    
    # Infos Git
    $gitInfo = Get-GitInfo -BaseCommit $baseCommit -BranchName $branchName
    
    # Build GitHub Actions (optionnel)
    $buildInfo = @{ triggered = $false; status = "skipped" }
    if ($task.validation.build_required -or $WaitForBuild) {
        $buildInfo = Wait-GitHubBuild -MaxWaitMinutes 30
    }
    
    $status = if ($errors.Count -gt 0) { "failed" } elseif ($buildInfo.status -eq "failure") { "failed" } else { "completed" }
    
} catch {
    $errors += "Exception: $($_.Exception.Message)"
    $status = "failed"
    # gitInfo, buildInfo, testInfo déjà initialisés avec valeurs par défaut
    $kiloResult = @{ exit_code = -1; output = $_.Exception.Message; session_id = $null; duration_seconds = 0 }
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
    $kiloSessionId = ""
    if ($null -ne $kiloResult -and $kiloResult.session_id) {
        $kiloSessionId = $kiloResult.session_id
        $sessionExportPath = "$OutputDir\$taskId-session.json"
        try {
            & $KiloCmd export $kiloResult.session_id --format json > $sessionExportPath 2>$null
        } catch {
            Write-Log "Export session Kilo échoué (ignoré): $($_.Exception.Message)" -Level "WARN"
            $sessionExportPath = ""
        }
    }
    
    # Construire le rapport
    $report = New-Report `
        -TaskId $taskId `
        -Status $status `
        -StartedAt $startedAt `
        -CompletedAt $completedAt `
        -KiloSessionId $kiloSessionId `
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