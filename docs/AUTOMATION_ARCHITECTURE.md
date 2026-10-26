# Nexora — Architecture d'automatisation KiloCode / ChatGPT / GitHub Actions

## Phase 1 — Audit de l'environnement (réalisé)

### KiloCode CLI v7.8.18
Commandes clés disponibles :
- `kilo run [message]` — exécution non-interactive avec message, supporte `--format json`, `--continue`, `--fork`, `--agent`, `--model`
- `kilo serve` — serveur headless (port aléatoire par défaut, auth basique optionnelle)
- `kilo acp` — serveur ACP (Agent Client Protocol) pour clients externes
- `kilo remote` — relais de session temps réel
- `kilo github install|run` — agent GitHub (installation + exécution sur PR/issues)
- `kilo cloud start|send|status|result` — tâches Cloud Agent (exécution distante)
- `kilo worktree create|list|remove` — gestion worktrees Git
- `kilo daemon` — démon local pour connexions persistantes

### Projet Nexora
- iOS/SwiftUI, XcodeGen (project.yml), build macOS-14 via GitHub Actions
- Branche `main` protégée, workflow `build.yml` déclenché sur push + `workflow_dispatch`
- Artefact IPA uploadé (retention 90 jours), validation icônes via `Tools/verify_ipa_icon.py`
- Tests SwiftTesting dans `Tests/` (non exécutés sur CI — Xcode 15.4)
- Pas de `.kilo/` local, pas d'agents configurés

### Sécurité
- Aucune clé API dans le dépôt
- GitHub Actions utilise runners GitHub hébergés (macOS)
- SideStore pour installation IPA sur iPhone

---

## Phase 2 — Comparaison des solutions

| Critère | A. Orchestrateur PowerShell local | B. GitHub Agent (`kilo github`) | C. Serveur ACP/Remote + Client externe |
|---------|-----------------------------------|----------------------------------|----------------------------------------|
| **Faisabilité** | ✅ Immédiate (CLI installé) | ✅ Supportée nativement | ✅ Supportée (`kilo serve` + `kilo acp`) |
| **Configuration** | Script PS1 + dossier tâches | `kilo github install` (webhook GitHub) | `kilo serve --port N` + tunnel/VPN |
| **Coût modèles** | Local (clé utilisateur) | Cloud Kilo (facturé à l'usage) | Local ou Cloud selon config |
| **Autonomie** | Tâche unique, synchrone | PR/Issue → build → commit/PR | Session persistante, multi-tours |
| **Risques sécurité** | Faible (local, pas d'exposition) | Webhook GitHub (permissions repo) | Serveur exposé si mal configuré |
| **Récupération résultats** | Fichiers JSON/MD locaux | Commits/PR + logs Actions | ACP/Remote streaming + export |
| **Boucle ChatGPT→Kilo** | Manuelle (copier-coller) | Automatisée via webhook | Automatisée via ACP/Remote |
| **Limite principale** | Nécessite intervention manuelle | Déclencheur = événement GitHub | Infrastructure serveur à maintenir |

### Recommandation : **Solution hybride A + B (prototype → évolution)**

**Pourquoi :**
1. **Démarrage immédiat** : PowerShell local ne demande aucune infra, pas de secrets exposés
2. **Évolution naturelle** : `kilo github` s'ajoute plus tard pour automatiser PR/Issues
3. **Sécurité** : Aucune exposition réseau au début, contrôle total sur les permissions
4. **Coût** : Zéro infrastructure, utilise la clé API locale de l'utilisateur

**Architecture cible :**
```
ChatGPT → (génère fichier tâche) → Dossier local tasks/ → PowerShell orchestrateur
    → kilo run --format json → Rapport JSON + Git diff + Build status
    → ChatGPT lit rapport → décide suite → nouvelle tâche
    
Évolution future : GitHub Actions workflow_dispatch + kilo github agent
```

---

## Phase 3 — Prototype implémenté

### Structure créée

```
Nexora/
├── .kilo/
│   ├── tasks/              # Fichiers de tâches à exécuter (JSON)
│   ├── reports/            # Rapports d'exécution (JSON)
│   └── config.yaml         # Configuration locale (modèles, agents, permissions)
├── scripts/
│   ├── kilo-orchestrator.ps1    # Orchestrateur principal
│   ├── kilo-run-task.ps1        # Exécution d'une tâche unique
│   ├── wait-build.ps1           # Attente + récupération build GitHub Actions
│   └── verify-build.ps1         # Validation locale (si macOS dispo)
├── docs/
│   └── AUTOMATION_WORKFLOW.md   # Documentation complète
└── .github/workflows/
    └── kilo-task.yml            # Workflow optionnel pour exécution CI
```

### Format de tâche (`.kilo/tasks/*.json`)

```json
{
  "id": "task-2026-10-26-001",
  "title": "Fix backup external iCloud trigger",
  "prompt": "Audit BackupManager.swift: backupAfterImportantOperation n'est appelé qu'à la fin d'une séance MuscuLog. Ajouter l'appel après chaque modification LogBook (SeriesEntry, MovieEntry, etc.) et après insert dans AddEntryView. Vérifier la persistance du security-scoped bookmark.",
  "scope": {
    "files": ["Nexora/Core/Data/BackupManager.swift", "Nexora/Features/LogBook/Views/AddEntryView.swift"],
    "branch": "fix/backup-external-trigger"
  },
  "constraints": {
    "no_data_destruction": true,
    "no_uninstall": true,
    "no_schema_migration": true,
    "max_duration_minutes": 30
  },
  "validation": {
    "build_required": true,
    "tests": ["BackupManagerTests"],
    "manual_verification": "Créer une série LogBook → vérifier fichier dans iCloud Drive"
  },
  "metadata": {
    "created_by": "chatgpt",
    "priority": "high",
    "tags": ["backup", "icloud", "logbook"]
  }
}
```

### Format de rapport (`.kilo/reports/*.json`)

```json
{
  "task_id": "task-2026-10-26-001",
  "status": "completed|failed|partial",
  "started_at": "2026-10-26T14:30:00Z",
  "completed_at": "2026-10-26T14:45:00Z",
  "kilo_session_id": "abc-123",
  "git": {
    "branch": "fix/backup-external-trigger",
    "base_commit": "5bf6ab1",
    "head_commit": "a1b2c3d",
    "files_changed": 3,
    "lines_added": 45,
    "lines_removed": 12
  },
  "build": {
    "triggered": true,
    "workflow_run_id": 40331847421,
    "status": "success",
    "ipa_url": "https://github.com/.../artifacts/...",
    "icon_verification": "passed"
  },
  "tests": {
    "executed": ["BackupManagerTests"],
    "passed": 18,
    "failed": 0,
    "skipped": 2
  },
  "errors": [],
  "warnings": ["Tests SwiftTesting non exécutés sur CI (Xcode 15.4)"],
  "artifacts": {
    "session_export": ".kilo/reports/task-2026-10-26-001-session.json",
    "diff": ".kilo/reports/task-2026-10-26-001.diff"
  },
  "next_steps": [
    "Tester sur iPhone : créer série LogBook → vérifier iCloud Drive",
    "Si OK → merge vers main via PR"
  ]
}
```

---

## Phase 4 — Fichiers créés

Je vais maintenant créer les fichiers du prototype.