# Workflow d'automatisation Nexora — Guide utilisateur

## Vue d'ensemble

Ce système permet d'enchaîner : **ChatGPT → Fichier tâche → KiloCode CLI → Rapport → ChatGPT**  
sans copier-coller manuel, en gardant le contrôle total sur chaque étape.

## Prérequis

- Windows 11 + PowerShell 5.1+
- KiloCode CLI v7.8+ (`kilo --version`)
- Git + GitHub CLI (`gh auth login`)
- Dépôt Nexora cloné localement
- Clé API Anthropic/OpenAI configurée dans KiloCode (`kilo auth`)

## Structure des dossiers

```
Nexora/
├── .kilo/
│   ├── config.yaml           # Configuration (modèles, agents, permissions)
│   ├── tasks/                # Fichiers JSON de tâches à exécuter
│   └── reports/              # Rapports JSON générés
├── scripts/
│   ├── kilo-orchestrator.ps1 # Orchestrateur principal
│   └── wait-build.ps1        # Attente build GitHub Actions
└── docs/
    └── AUTOMATION_WORKFLOW.md
```

## Créer une tâche

1. Copier un modèle depuis `.kilo/tasks/` ou créer un JSON :
```json
{
  "id": "task-2026-10-26-002",
  "title": "Description courte",
  "prompt": "Prompt détaillé pour KiloCode...",
  "scope": {
    "files": ["fichier1.swift", "fichier2.swift"],
    "branch": "fix/ma-correction"
  },
  "constraints": {
    "no_data_destruction": true,
    "no_uninstall": true,
    "no_schema_migration": true
  },
  "validation": {
    "build_required": true,
    "tests": ["BackupManagerTests"],
    "manual_verification": ["Étapes de test sur iPhone"]
  },
  "metadata": { "created_by": "chatgpt", "priority": "high", "tags": ["tag1"] }
}
```

2. Placer dans `.kilo/tasks/`

## Lancer l'orchestrateur

```powershell
# Exécuter la tâche la plus récente
.\scripts\kilo-orchestrator.ps1

# Ou spécifier un fichier
.\scripts\kilo-orchestrator.ps1 -TaskFile .\.kilo\tasks\ma-tache.json

# Attendre le build GitHub Actions
.\scripts\kilo-orchestrator.ps1 -WaitForBuild
```

## Lire le rapport

Le rapport JSON dans `.kilo/reports/` contient :
- `status` : completed / failed / partial
- `git` : branche, commits, diff stat
- `build` : workflow_run_id, status, ipa_url, icon_verification
- `tests` : exécutés, passés, échoués
- `errors` / `warnings` : détails
- `artifacts` : session export, diff
- `next_steps` : actions manuelles requises

## Workflow complet ChatGPT → KiloCode → ChatGPT

### 1. ChatGPT prépare la tâche
- Analyse le contexte (code, logs, rapports précédents)
- Génère le JSON de tâche avec prompt précis
- Sauvegarde dans `.kilo/tasks/task-YYYY-MM-DD-XXX.json`

### 2. Utilisateur lance l'orchestrateur (une commande)
```powershell
.\scripts\kilo-orchestrator.ps1 -WaitForBuild
```

### 3. KiloCode exécute
- Crée/switch branche dédiée
- Analyse le code, fait les modifications
- Commit + push vers GitHub
- Déclenche le build GitHub Actions

### 4. Orchestrateur attend le build (optionnel)
- Poll GitHub Actions via `gh CLI`
- Récupère URL IPA + validation icônes

### 5. Rapport généré
- JSON structuré dans `.kilo/reports/`
- Résumé affiché en console (copiable pour ChatGPT)

### 6. ChatGPT lit le rapport
- Décide : valider (ouvrir PR), itérer (nouvelle tâche), ou abandonner
- Si PR : utilisateur fait `gh pr create` manuellement

## Sécurité — Règles impératives

| Interdiction | Pourquoi |
|--------------|----------|
| `--auto` global | Approuve tout sans confirmation |
| Push force sur main | Perte historique |
| Suppression données | Irréversible |
| Migration schéma sans backup | Perte données |
| Serveur `kilo serve` exposé | Accès non autorisé |

## Commandes utiles

```powershell
# Voir les tâches en attente
ls .kilo/tasks/*.json

# Voir les derniers rapports
ls .kilo/reports/*.json | Sort-Object LastWriteTime -Descending | Select-Object -First 5

# Lire un rapport
Get-Content .kilo/reports/task-xxx-report.json | ConvertFrom-Json

# Attendre un build manuellement
.\scripts\wait-build.ps1 -MaxWaitMinutes 20

# Ouvrir PR manuellement après validation
gh pr create --base main --head fix/ma-branche --title "Fix: ..." --body "..."
```

## Évolution future

| Étape | Description | Commande |
|-------|-------------|----------|
| 1. Local (actuel) | PowerShell + kilo run | ✅ Implémenté |
| 2. GitHub Agent | `kilo github install` + webhook | `kilo github install` |
| 3. ACP Server | `kilo acp --port 4096` + client externe | `kilo acp` |
| 4. Cloud Agent | `kilo cloud start` (facturé) | `kilo cloud start` |

## Dépannage

| Problème | Solution |
|----------|----------|
| `kilo: command not found` | Recharger PATH ou redémarrer terminal |
| `gh: not found` | `winget install GitHub.cli` puis `gh auth login` |
| Build GitHub échoue | Vérifier logs : `gh run view <run-id> --log` |
| Branche existe déjà | L'orchestrateur fait `checkout`, pas `create` |
| Permission refusée | Vérifier `.kilo/config.yaml` permissions, pas `--auto` |

## Exemple de session complète

```powershell
# 1. ChatGPT a créé task-2026-10-26-001-backup-external-trigger.json
# 2. Lancer
.\scripts\kilo-orchestrator.ps1 -WaitForBuild

# 3. Attendre ~2-5 min (kilo + build)
# 4. Rapport affiché + sauvé dans .kilo/reports/
# 5. Copier le JSON résumé → ChatGPT
# 6. ChatGPT : "Build OK, icône validée. Ouvrir PR ?"
# 7. Utilisateur : gh pr create...
```

## Limitations actuelles

- Tests SwiftTesting non exécutables sur Windows (nécessite macOS)
- Build iOS uniquement sur GitHub Actions (macOS runner)
- Installation IPA via SideStore manuelle
- Pas de boucle autonome (validation humaine requise à chaque étape)
- Pas de serveur persistant (chaque `kilo run` = nouvelle session sauf `--continue`)

## Support

- Logs KiloCode : `%LOCALAPPDATA%\kilo\logs\`
- GitHub Actions : https://github.com/mthxdev/NEXORA/actions
- KiloCode docs : https://kilo.ai/docs