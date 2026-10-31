# Île Dynamique

Dynamic Island autour de l'encoche du MacBook (ou pilule noire centrée sur les Mac sans encoche).
Swift 5.9+, SwiftUI + AppKit, macOS 14+, aucune dépendance externe.

## Arborescence

```
dinamique/
├── Package.swift                 # paquet Swift (s'ouvre dans Xcode)
├── project.yml                   # optionnel : génère un .xcodeproj avec XcodeGen
├── Resources/
│   ├── Info.plist                # LSUIElement, descriptions d'autorisations
│   └── IleDynamique.entitlements # Apple Events + calendrier (runtime renforcé)
├── scripts/construire-app.sh     # compile + emballe build/IleDynamique.app
└── Sources/IleDynamique/
    ├── App/            Principal.swift (point d'entrée), AppDelegate.swift (barre des menus)
    ├── Fenetre/        PanneauIle.swift, ControleurFenetre.swift, GeometrieEncoche.swift
    ├── ViewModel/      IleViewModel.swift (état unique : étendu, activité, survol)
    ├── Modules/        ModuleMusique, ModuleBatterie, ModuleCalendrier,
    │                   ModuleVolumeLuminosite, ModuleEtagere
    ├── Preferences/    Preferences.swift, VuePreferences.swift, LancementAuDemarrage.swift
    └── Vues/           VueIle, FormeIle, VueCompacte, Egaliseur, VueEtendue,
                        VueEnTete, VueLecteur, VueCalendrier, VueEtagere
```

## Info.plist et entitlements

| Clé | Rôle |
|---|---|
| `LSUIElement = true` | app agent, pas d'icône dans le Dock |
| `NSAppleEventsUsageDescription` | piloter Musique / Spotify |
| `NSCalendarsFullAccessUsageDescription` | EventKit, macOS 14+ |
| `NSCalendarsUsageDescription` | compatibilité |

Entitlements (runtime renforcé, **sans** App Sandbox) :
`com.apple.security.automation.apple-events`, `com.apple.security.personal-information.calendars`.

Pourquoi pas de sandbox : les moniteurs d'événements globaux et l'envoi d'Apple Events à d'autres
apps demanderaient des exceptions temporaires (`com.apple.security.temporary-exception.apple-events`),
refusées sur le Mac App Store de toute façon. Pour une distribution hors App Store, le runtime renforcé suffit.

## Compiler et lancer

**Option A, Terminal (les Command Line Tools ne suffisent pas, voir la note) :**
```sh
./scripts/construire-app.sh          # produit build/IleDynamique.app
open build/IleDynamique.app
```

**Option B, Xcode :**
```sh
brew install xcodegen && xcodegen generate && open IleDynamique.xcodeproj
```
Puis choisissez votre équipe dans *Signing & Capabilities* et faites ⌘R.

> ⚠️ Il faut **Xcode** installé et sélectionné (`sudo xcode-select -s /Applications/Xcode.app`).
> Avec les seules Command Line Tools, `@State` (devenu une macro SwiftUI) ne compile pas :
> le plugin `SwiftUIMacros` n'est fourni qu'avec Xcode.

## Autorisations

1. **Calendrier** : demandé au premier lancement (si le module est activé).
2. **Automatisation** : macOS demande l'accès à Musique / Spotify à la première commande.
3. **Accessibilité** (facultatif) : *Réglages Système → Confidentialité et sécurité → Accessibilité*,
   ajoutez Île Dynamique. Nécessaire uniquement pour détecter les touches de luminosité.
4. **Lancer au démarrage** : dans les Préférences (icône capsule dans la barre des menus).

Avec une signature ad hoc, chaque recompilation change l'empreinte de l'app : macOS peut
redemander les autorisations. Si une autorisation reste bloquée : `tccutil reset All fr.iledynamique.app`.

## Choix techniques

- **Aucun minuteur en arrière-plan** : survol = moniteurs `NSEvent` (souris), musique = notifications
  distribuées de Musique/Spotify, batterie = `IOPSNotificationCreateRunLoopSource`, volume = écouteurs
  CoreAudio, calendrier = `EKEventStoreChanged`. Les `TimelineView` (heure, progression) ne tournent
  que lorsque l'île est ouverte.
- **Clics** : le panneau est grand et transparent, mais `ignoresMouseEvents` reste à `true` tant que
  la souris n'est pas sur l'île, donc la barre des menus en dessous reste cliquable.
- **Luminosité** : il n'existe pas d'API publique pour lire la luminosité de l'écran intégré sur
  Apple Silicon. Le module charge `DisplayServicesGetBrightness` dynamiquement (framework privé,
  via `dlsym`) et se désactive sans planter s'il est absent. Seules les touches de luminosité sont
  détectées (pas le curseur du Centre de contrôle). C'est le seul point non public de l'app.

## Améliorations possibles

- Météo (WeatherKit ou Open-Meteo) dans l'en-tête
- Minuteur / Pomodoro en activité compacte (anneau de progression)
- AirDrop depuis l'étagère (`NSSharingService(named: .sendViaAirDrop)`)
- Aperçu des notifications (nécessite des API privées, ou les notifications de vos propres apps)
- Couleur de l'égaliseur tirée de la pochette, curseur de position cliquable
- Retour haptique sur le trackpad (`NSHapticFeedbackManager`) à l'ouverture
