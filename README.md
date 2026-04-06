# 🎮 Rogue Launcher

**Rogue Launcher** ist ein macOS-Gaming-Frontend für [Moonlight Game Streaming](https://moonlight-stream.org/). Es verbindet dich nahtlos mit deinem Windows-Gaming-PC und bietet eine vollwertige Spielebibliothek, Genre-Verwaltung, Launcher-Integration und vieles mehr — alles in einer eleganten macOS-App.

> ⚠️ **Wichtig:** Rogue Launcher benötigt den **Rogue Companion**, der auf deinem Windows- oder Linux-PC installiert sein muss. Ohne den Companion sind viele Funktionen nicht verfügbar.

---

## 📸 Screenshots

*Bilder folgen*

---

## ✨ Features

- **Spielebibliothek** — Verwalte all deine Spiele an einem Ort, mit Covern, Beschreibungen, Genres und Bewertungen
- **Moonlight-Integration** — Starte Spiele direkt per Klick über Moonlight Game Streaming
- **Multi-Launcher-Support** — Steam, Epic Games, GOG, EA App, Ubisoft Connect und mehr
- **Genre-Verwaltung** — Organisiere deine Bibliothek nach Genres mit eigenen Cover-Bildern
- **Konsolen-Bibliothek** — Verwalte auch deine PS5- und Nintendo Switch-Spiele
- **Emulatoren** — RetroArch-Integration für klassische Plattformen
- **Chat-Integration** — Element, Steam, Discord, Signal und WhatsApp direkt in der App
- **Kostenlose Spiele** — Übersicht über aktuelle Gratis-Angebote bei Epic Games und Amazon Prime Gaming
- **Scripte** — Führe benutzerdefinierte Skripte auf dem Gaming-PC aus
- **In-App Updates** — Automatische Update-Erkennung und -Installation

---

## 🖥️ Systemvoraussetzungen

### Mac (Rogue Launcher)
- macOS 14.0 oder neuer
- [Moonlight für macOS](https://moonlight-stream.org/) installiert
- Netzwerkverbindung zum Gaming-PC

### Gaming-PC (Rogue Companion)
- Windows 10/11 **oder** Linux (x86_64)
- [Sunshine](https://github.com/LizardByte/Sunshine) als Streaming-Server
- Rogue Companion installiert (siehe unten)

---

## 🔧 Installation

### 1. Rogue Launcher (Mac)

1. Lade die neueste Version von [Releases](https://github.com/DarrenShure/rogue-launcher/releases/latest) herunter
2. Entpacke die ZIP-Datei
3. Ziehe `Rogue Launcher.app` nach `/Applications`
4. Beim ersten Start: **Rechtsklick → Öffnen** (wegen Ad-hoc-Signierung)

### 2. Rogue Companion (Gaming-PC) — **Pflicht**

Der Rogue Companion ist eine Helfer-App, die auf deinem Gaming-PC läuft und dem Rogue Launcher erweiterte Funktionen bereitstellt:

- PC starten und herunterfahren
- Steam-Bibliothek auslesen
- Skripte ausführen
- Sunshine-Integration
- Crafty-Server-Verwaltung

➡️ **[Rogue Companion herunterladen](https://github.com/DarrenShure/rogue_companion/releases/latest)**

#### Windows
1. `RogueCompanion_Setup.exe` herunterladen und ausführen
2. Companion startet automatisch beim Windows-Start

#### Linux
1. `RogueCompanion-x86_64.AppImage` und `RogueHelper-x86_64.AppImage` herunterladen
2. Ausführbar machen: `chmod +x RogueCompanion-x86_64.AppImage`
3. AppImage starten

---

## ⚙️ Konfiguration

Nach der Installation:

1. Öffne **Rogue Launcher → Einstellungen → Rogue Helper**
2. Trage die IP-Adresse deines Gaming-PCs ein
3. Trage Benutzername und Passwort des Companions ein
4. Klicke **Verbindung testen**

---

## 🔄 Updates

Rogue Launcher prüft beim Start automatisch auf neue Versionen. Updates können direkt in der App unter **Einstellungen → Updates** installiert werden.

Der Rogue Companion prüft ebenfalls auf Updates über seinen eingebauten Update-Tab.

---

## 🏗️ Projektstruktur

| Komponente | Beschreibung | Repository |
|---|---|---|
| **Rogue Launcher** | macOS-App (SwiftUI) | Dieses Repo |
| **Rogue Companion** | Helper-App für Windows & Linux (Python) | [rogue_companion](https://github.com/DarrenShure/rogue_companion) |

---

## 🛠️ Entwicklung

Rogue Launcher ist in **Swift/SwiftUI** geschrieben und wird mit Xcode gebaut.

```bash
# Projekt öffnen
open RogueLauncher.xcodeproj

# Bauen und signieren
xcodebuild -project RogueLauncher.xcodeproj -scheme RogueLauncher -configuration Release archive
codesign --deep --force --sign - "/Applications/Rogue Launcher.app"
```

---

## 📄 Lizenz

MIT License — siehe [LICENSE](LICENSE)

Copyright © 2026 Christian Sielaff. Gebaut mit der Hilfe von [Claude](https://claude.ai) (Anthropic).
