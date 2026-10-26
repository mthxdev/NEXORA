<# 
.SYNOPSIS
    Attend la fin d'un build GitHub Actions et rapporte le statut + URL artefact.

.DESCRIPTION
    Utilise gh CLI pour surveiller le workflow 'Build Nexora' sur le repo mthxdev/NEXORA.
    Retourne un objet JSON avec le statut, l'URL de l'IPA, et la validation icônes.

.PARAMETER Repo
    Repository GitHub (défaut: mthxdev/NEXORA)

.PARAMETER Branch
    Branche à surveiller (défaut: branche courante)

.PARAMETER MaxWaitMinutes
    Timeout maximal (défaut: 30)

.PARAMETER PollIntervalSeconds
    Intervalle de polling (défaut: 30)

.OUTPUTS
    Objet JSON avec: triggered, workflow_run_id, status, ipa_url, icon_verification
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$Repo = "mthxdev/NEXORA",

    [Parameter(Mandatory=$false)]
    [string]$Branch = "",

    [Parameter(Mandatory=$false)]
    [int]$MaxWaitMinutes = 30,

    [Parameter(Mandatory=$false)]
    [int]$PollIntervalSeconds = 30
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $ts = Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ"
    Write-Host "[$ts] [$Level] $Message"
}

$repoRoot = "C:\Dev\_Mathieu\02_Projets\Perso\Nexora"
if (-not $Branch) {
    $Branch = (git -C $repoRoot branch --show-current).Trim()
}

if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    Write-Log "gh CLI non installé" -Level "ERROR"
    @{ triggered = $false; status = "error"; message = "gh CLI not installed" } | ConvertTo-Json -Compress
    exit 1
}

Write-Log "Surveillance build pour $Repo @ $Branch (max ${MaxWaitMinutes}min)"

$startTime = Get-Date
$runId = $null

while ((Get-Date) - $startTime -lt (New-TimeSpan -Minutes $MaxWaitMinutes)) {
    $runs = gh run list --repo $Repo --limit 10 --json databaseId,status,conclusion,headBranch,createdAt,workflowName 2>$null | ConvertFrom-Json
    
    if ($runs) {
        $matching = $runs | Where-Object { 
            $_.headBranch -eq $Branch -and $_.workflowName -eq "Build Nexora" 
        } | Select-Object -First 1
        
        if ($matching) {
            $runId = $matching.databaseId
            Write-Log "Run trouvé: #$runId — Status: $($matching.status) — Conclusion: $($matching.conclusion)"
            
            if ($matching.status -eq "completed") {
                # Récupérer artefacts
                $artifacts = gh run view $runId --repo $Repo --json artifacts 2>$null | ConvertFrom-Json
                $ipaUrl = ""
                if ($artifacts) {
                    $ipa = $artifacts.artifacts | Where-Object { $_.name -eq "Nexora-ipa" } | Select-Object -First 1
                    if ($ipa) { $ipaUrl = $ipa.url }
                }
                
                $result = @{
                    triggered = $true
                    workflow_run_id = $runId
                    status = $matching.conclusion
                    ipa_url = $ipaUrl
                    icon_verification = if ($matching.conclusion -eq "success") { "passed" } else { "failed" }
                    completed_at = (Get-Date).ToString("o")
                }
                $result | ConvertTo-Json -Compress
                exit 0
            }
        }
    }
    
    Start-Sleep -Seconds $PollIntervalSeconds
}

Write-Log "Timeout après ${MaxWaitMinutes}min" -Level "WARN"
@{ triggered = $true; workflow_run_id = $runId; status = "timeout"; ipa_url = ""; icon_verification = "unknown" } | ConvertTo-Json -Compress
exit 1