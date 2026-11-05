# Île Dynamique

Dynamic Island autour de l'encoche du MacBook (ou pilule noire centrée sur les Mac sans encoche).
Swift 5.9+, SwiftUI + AppKit, macOS 14+, aucune dépendance externe.

## Installation (sans compiler)

1. Téléchargez `IleDynamique-x.y.dmg` depuis la page [Releases](https://github.com/capitainepoof8/IleDynamique/releases/latest).
2. Ouvrez le DMG et glissez **IleDynamique** sur le raccourci **Applications**.
3. Premier lancement : l'app n'est pas signée par un développeur Apple identifié, macOS la bloque.
   - Ouvrez-la une fois (message d'avertissement), puis allez dans
     *Réglages Système → Confidentialité et sécurité* et cliquez **Ouvrir quand même** ;
   - ou, dans le Terminal : `xattr -dr com.apple.quarantine /Applications/IleDynamique.app`

Binaire universel (Apple Silicon + Intel), macOS 14 ou plus récent.

Pour produire le DMG soi-même : `./scripts/creer-dmg.sh` (résultat dans `build/`).

## Arborescence

```
dinamique/
├── Package.swift                 # paquet Swift (s'ouvre dans Xcode)
├── project.yml                   # optionnel : génère un .xcodeproj avec XcodeGen
├── Resources/
│   ├── Info.plist                # LSUIElement, descriptions d'autorisations
│   └── IleDynamique.entitlements # Apple Events + calendrier (runtime renforcé)
├── scripts/construire-app.sh     # compile (universel) + emballe build/IleDynamique.app
├── scripts/creer-dmg.sh          # crée le DMG et le zip à distribuer
├── scripts/construire-aide-lecture.sh # compile l'aide de lecture (.dylib universelle)
├── Sources/AideLecture/aide-lecture.m # « À l'écoute » du système, chargée dans /usr/bin/perl
└── Sources/IleDynamique/
    ├── App/            Principal.swift (point d'entrée), AppDelegate.swift (barre des menus)
    ├── Fenetre/        PanneauIle.swift, ControleurFenetre.swift, GeometrieEncoche.swift
    ├── ViewModel/      IleViewModel.swift (état unique : étendu, activité, survol)
    ├── Modules/        ModuleMusique, AideLecture, ModuleBatterie, ModuleCalendrier,
    │                   ModuleVolumeLuminosite, ModuleEtagere
    ├── Preferences/    Preferences.swift, VuePreferences.swift, LancementAuDemarrage.swift
    └── Vues/           VueIle, FormeIle, VueCompacte, Egaliseur, VueEtendue,
                        VueEnTete, VueLecteur, VueCalendrier, VueEtagere
```

## Info.plist et entitlements

| Clé | Rôle |
|---|---|
| `LSUIElement = true` | app agent, pas d'icône dans le Dock |
| `NSAppleEventsUsageDescription` | piloter Musique / Spotify (repli si la lecture système ne répond pas) |
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
2. **Automatisation** : macOS peut demander l'accès à Musique / Spotify (uniquement pour le repli AppleScript).
3. **Accessibilité** (facultatif) : *Réglages Système → Confidentialité et sécurité → Accessibilité*,
   ajoutez Île Dynamique. Nécessaire uniquement pour détecter les touches de luminosité.
4. **Lancer au démarrage** : dans les Préférences (icône capsule dans la barre des menus).

Avec une signature ad hoc, chaque recompilation change l'empreinte de l'app : macOS peut
redemander les autorisations. Si une autorisation reste bloquée : `tccutil reset All fr.iledynamique.app`.

## Choix techniques

- **Aucun minuteur en arrière-plan** : survol = moniteurs `NSEvent` (souris), lecture = notifications
  MediaRemote (repli : notifications distribuées de Musique/Spotify), batterie = `IOPSNotificationCreateRunLoopSource`, volume = écouteurs
  CoreAudio, calendrier = `EKEventStoreChanged`. Les `TimelineView` (heure, progression) ne tournent
  que lorsque l'île est ouverte.
- **Clics** : le panneau est grand et transparent, mais `ignoresMouseEvents` reste à `true` tant que
  la souris n'est pas sur l'île, donc la barre des menus en dessous reste cliquable.
- **Lecture de toutes les apps** : le lecteur suit l'« À l'écoute » de macOS (navigateurs, VLC, IINA,
  Musique, Spotify…), via le framework privé MediaRemote. Depuis macOS 15.4, celui-ci ne répond qu'aux
  processus Apple : une petite bibliothèque est donc chargée dans `/usr/bin/perl`, et communique avec
  l'app en JSON sur stdin/stdout. Si Apple ferme cette voie, le lecteur retombe sur AppleScript
  (Musique et Spotify uniquement). Une app qui ne publie rien dans « À l'écoute » reste invisible.
- **Luminosité** : il n'existe pas d'API publique pour lire la luminosité de l'écran intégré sur
  Apple Silicon. Le module charge `DisplayServicesGetBrightness` dynamiquement (framework privé,
  via `dlsym`) et se désactive sans planter s'il est absent. Seules les touches de luminosité sont
  détectées (pas le curseur du Centre de contrôle). Avec MediaRemote, ce sont les seuls points non publics de l'app.

## Améliorations possibles

- Météo (WeatherKit ou Open-Meteo) dans l'en-tête
- Minuteur / Pomodoro en activité compacte (anneau de progression)
- AirDrop depuis l'étagère (`NSSharingService(named: .sendViaAirDrop)`)
- Aperçu des notifications (nécessite des API privées, ou les notifications de vos propres apps)
- Couleur de l'égaliseur tirée de la pochette, curseur de position cliquable
- Retour haptique sur le trackpad (`NSHapticFeedbackManager`) à l'ouverture
