# Nexora

Application utilitaire personnelle évolutive pour iOS.

## Modules

- **MuscuLog** — Suivi musculation complet (programmes, séances, progression)
- **LogBook** — Films, séries, animés, jeux, projets, apprentissages *(à venir)*

## Stack

- Swift + SwiftUI
- SwiftData (stockage local)
- iOS 17+
- Aucune dépendance externe
- XcodeGen pour la génération de projet

## Build

L'application est compilée automatiquement via GitHub Actions à chaque push sur `main`.

Le fichier `.ipa` est disponible dans l'onglet **Actions** → dernier workflow → **Artifacts** → `Nexora-ipa`.

## Installation

1. Télécharger le `.ipa` depuis GitHub Actions
2. L'installer via SideStore sur l'iPhone

## Développement local

```bash
# Générer le projet Xcode
xcodegen generate

# Ouvrir dans Xcode
open Nexora.xcodeproj
```