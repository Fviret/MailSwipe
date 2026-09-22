# MailSwipe

Une app iOS pour gérer ses mails Gmail d'un geste : swipe droite pour répondre, gauche pour supprimer, haut pour archiver, bas pour snoozer.

## Gestes

| Swipe | Action |
|---|---|
| → Droite | Répondre (feuille de réponse rapide) |
| ← Gauche | Supprimer |
| ↑ Haut | Archiver |
| ↓ Bas | Snoozer (revient plus tard, avec notification) |

## Setup

Prérequis : Xcode 16+, [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`).

```bash
xcodegen generate
open MailSwipe.xcodeproj
```

Le projet Xcode (`.xcodeproj`) est généré depuis `project.yml` et n'est pas versionné.

Sans configuration Gmail, l'app tourne en **mode démo** avec des mails fictifs.

## Connecter un vrai compte Gmail

Voir les instructions détaillées dans [`Sources/Config.swift`](Sources/Config.swift) :
créer un projet Google Cloud, activer l'API Gmail, créer un Client ID OAuth de type iOS,
le coller dans `Config.swift`, puis mettre à jour `GOOGLE_REVERSED_CLIENT_ID_SCHEME`
dans `project.yml` avant de relancer `xcodegen generate`.

## Architecture

- `Sources/Models` — `EmailCard`, `SnoozeItem`
- `Sources/Services` — `AuthManager` (OAuth 2.0 + PKCE via `ASWebAuthenticationSession`), `GmailAPI` (REST Gmail), `EmailStore`, `SnoozeScheduler`
- `Sources/Views` — UI SwiftUI, dont `SwipeCardView` pour le geste de swipe
