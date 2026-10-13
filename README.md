# ASYMMETRIC

> *Den Krieg gewinnt nicht, wer die meisten Panzer hat.*

Ein Echtzeitstrategiespiel im Stil von **Command & Conquer: Generals** – mit einer Besonderheit:
Eine Seite hat die Feuerkraft, die andere hat die Bilder.

Du spielst wahlweise

* **die Aurelischen Streitkräfte** – eine Hightech-Supermacht mit Panzern, Drohnen, Kampfhubschraubern,
  Artillerie, Luft- und Präzisionsschlägen. Jedes Gefecht kannst du gewinnen. Aber der Feind versteckt
  sich unter Zivilisten, und jeder Fehlschlag wandert als Video um die Welt. Wird die **Weltöffentlichkeit**
  zu laut, kürzen Verbündete dein Budget, verhängen eine Flugverbotszone – und am Ende greift eine
  internationale Koalition ein.
* **die Hadar-Front** – eine Guerilla mit billigen Kämpfern, RPGs, Technicals, versteckten Raketenrampen,
  Sprengfallen und **Medien-Teams**. Du kannst keine Schlacht gewinnen, aber du kannst den Krieg der Bilder
  gewinnen: Tarne dich unter Zivilisten, lege Hinterhalte, provoziere den Giganten – und lass die Kameras laufen.

Das Szenario („Qadira“ in „Hadar“, Fraktionen „Aurelia“ und „Hadar-Front“) ist **fiktiv**. Optik und Setting
(nahöstliche Stadt) lehnen sich bewusst an die Konflikte unserer Zeit an, benennen aber keinen konkreten Konflikt.

---

## Schnellstart

1. **Godot 4.3 oder neuer** installieren (Standard-Build, kein .NET nötig): <https://godotengine.org/download>
2. Dieses Repository klonen/herunterladen und in Godot über **Importieren → `project.godot`** öffnen.
   Beim ersten Öffnen importiert der Editor die Audiodateien automatisch (dauert ein paar Sekunden).
3. **F5** drücken. Im Hauptmenü Seite und Schwierigkeit wählen.

Das Projekt nutzt den **Compatibility-Renderer** (OpenGL) – läuft damit auf praktisch jeder Hardware
und lässt sich später auch für Web exportieren. Es werden **keine externen Assets** benötigt:
alle Modelle, Texturen, Effekte, Sounds und Musik werden prozedural erzeugt (Kosten: 0).

---

## Steuerung

| Aktion | Taste |
|---|---|
| Kamera bewegen | `W A S D` / Pfeiltasten / Mauszeiger an den Rand · `Shift` = schneller |
| Kamera drehen | `Q` / `E` oder Mitteltaste gedrückt halten + ziehen |
| Zoomen | Mausrad |
| Einheiten wählen | Linksklick · Rahmen ziehen · `Shift` = hinzufügen · Doppelklick = alle gleichen Typs |
| Befehl (Bewegen / Angreifen / Gebäude besetzen) | Rechtsklick (`Strg` + Rechtsklick = Feuer erzwingen) |
| Angriffsbewegung | `T`, dann Linksklick |
| Stopp / Feuer halten | `X` / `H` |
| Person kontrollieren (Aurelia) | `C`, dann auf die Person klicken |
| Feuerbefehl Artillerie / Raketenrampe | `F`, dann Bodenziel |
| Zivile Tarnung an/aus (Hadar-Front) | `G` |
| Sprengfalle legen (Hadar-Front) | `B` |
| Gebäude räumen | `V` |
| Einsatzregeln streng/frei (Aurelia) | `R` |
| Unterstützung / Fähigkeiten | `F1`–`F6` oder Buttons rechts |
| Letzter Alarm | `Leertaste` |
| Kontrollgruppen | `Strg+1…9` speichern, `1…9` abrufen (2× = Kamera hinschicken) |
| Spielgeschwindigkeit | `+` / `−` |
| Pause / Menü | `Esc` · Vollbild `F11` |

Gebäude (Fabrik, Kaserne, Tunnelknoten …) anklicken, um Einheiten zu bauen; Rechtsklick setzt den Sammelpunkt.

---

## Das Spielprinzip in Kurzform

### Die Empörungsleiste („Weltöffentlichkeit“)

Das Herzstück. Jeder zivile Tote, jedes getroffene Krankenhaus, jeder getötete Journalist füttert die Leiste –
aber **wie stark**, hängt davon ab, ob es *dokumentiert* wurde:

* **Medien-Team in der Nähe** (Kamera-Symbol über dem Kopf): Wirkung ×2. Kameras sind für beide Seiten sichtbar –
  Aurelia kann also sehen, wo Vorsicht geboten ist.
* **Handy-Videos** der Anwohner liefern immer eine Grundwirkung.
* Videomaterial sammelt sich an und muss von der Hadar-Front per **Upload** (`F1`) veröffentlicht werden – dann
  mit Bonus. Fällt das letzte Medien-Team, sickert Material nur noch langsam durch.

| Stufe | Schwelle | Folge |
|---|---|---|
| 1 | 35 % | **Sanktionen**: Budget −40 % |
| 2 | 65 % | **Flugverbotszone**: keine Luftschläge, Hubschrauber und Drohnen werden abgezogen |
| 3 | 100 % | **Intervention** einer Koalition – Aurelia verliert |

Gegenmittel für Aurelia: **Beweise veröffentlichen** (`F6`), gesammelt durch geortete Raketenabschüsse und
Opfer der Gegenseite, sowie präzises Vorgehen, Vorwarnungen und Aufklärung.

### Nebel der Ungewissheit

* **Die Hadar-Front tarnt sich**: Kämpfer, RPG-Schützen und Raketenwerfer sehen für Aurelia wie Zivilisten (bzw.
  zivile Lkw) aus – bis sie schießen. Beobachtung baut *Verdacht* auf (gelbes „?“ über dem Kopf); Aufklärer,
  Drohnen, der **Aufklärungsflug** oder eine aktive **Kontrolle** (`C`) entlarven sie.
* **Tunnelknoten** sind ganz normale Wohnhäuser, bis sie entdeckt werden (Einheiten, die herauskommen,
  Aufklärungsflug, Gefechte). Sie zu zerstören bedeutet meist: Das Haus stürzt ein, mit allen Bewohnern.
* **Hinterhalte**: Rebellen besetzen Häuser (Rechtsklick). Wer aus einem Haus schießt, macht es zum Ziel –
  mit den Zivilisten darin. Aurelia kann das Gebäude zuvor per **Evakuierungswarnung** (`F4`) räumen lassen.
* Zielvorschau für Schläge zeigt die geschätzte Zahl **Zivilisten im Radius**, Kameras und sensible Orte (Klinik, Schule).

### Aurelia – Werkzeuge

Infanterie, Aufklärer, Wolf-Schützenpanzer, Titan-Kampfpanzer, Hammer-Haubitze, Argus-Drohne, Viper-Kampfhubschrauber.
Unterstützung: **Präzisionsschlag** (teuer, chirurgisch), **Artillerie-Salve** (billig, ungenau), **Luftschlag**
(gewaltig), **Evakuierungswarnung**, **Aufklärungsflug**, **Beweise veröffentlichen**.
Sieg: alle sechs Tunnelknoten zerstören. Niederlage: Kommandozentrale zerstört oder Empörung 100 %.

### Hadar-Front – Werkzeuge

Kämpfer (tarnbar), RPG-Schütze (tarnbar), Technical, Raketenrampe (tarnbar, provoziert), Medien-Team,
Sprengfallen-Leger. Produktion in den **Tunnelknoten**; Einkommen steigt mit der Empörung (Spenden!).
Fähigkeiten: **Upload** und **Spendenaufruf**.
Sieg: Empörung 100 % oder Kommandozentrale zerstört. Niederlage: alle Tunnelknoten verloren.

---

## Projektstruktur

```
project.godot            Godot-Projekt (Compatibility-Renderer)
scenes/main.tscn         einzige Szene – alles Weitere wird per Code aufgebaut
scripts/
  main.gd                Titelbild, Briefing, Spielschleife, Pause/Ende
  autoload/game.gd       globale Regeln: Budget, Empörung, Fähigkeiten, Siegbedingungen
  autoload/sfx.gd        Audio (SFX-Pool, dynamische Musik)
  core/                  Daten (data.gd), Navigation (A*), Spatial-Hash, Hilfsfunktionen
  world/                 Stadtgenerator, Welt/Sichtbarkeit/Schaden, Unterstützung, Atmosphäre
  entities/              Entity, Unit, Civilian, Structure, Projectile, Mine
  ai/                    KI der beiden Seiten
  control/               RTS-Kamera, Spielersteuerung
  gfx/                   MeshBuilder, prozedurale Modelle/Props, Effekte, Shader
  ui/                    HUD, Minikarte, Overlay, Menüs
assets/audio/            erzeugte Sounds und Musik (siehe tools/gen_audio.py)
tools/                   Audio-Generator, Headless-Simulation, Screenshot-/Test-Szenarien
docs/GAME_DESIGN.md      Designdokument und Balancing-Notizen
```

### Entwickler-Tools

```bash
python3 tools/gen_audio.py                       # Sounds/Musik neu erzeugen (numpy, ffmpeg optional)
godot --headless --fixed-fps 30 tools/sim.tscn -- seconds=300 speed=8 demo=0   # KI gegen KI, ohne Grafik
godot --path . -- autostart=0 scenario=closeup shot=/tmp/s                      # Szenario + Screenshots
```

Startparameter für das Spiel (nach `--`): `autostart=0|1` (Seite), `diff=0|1|2`, `speed=`, `ai_both=1`,
`tod=0..0.85` (Tageszeit), `cam=x,z,dist[,yaw]`.

---

## Ausblick

Dies ist ein **spielbarer Prototyp** (erste „Mission“ auf einer Karte). Ideen für die nächsten Schritte:
weitere Karten und Kampagne, Verbündete/Allianztreue als eigene Mechanik, mehr Einheiten (Pioniere, Scharfschützen,
Panzerabwehr-Teams), Checkpoints und Ausgangssperren, Cyber-/Funkstörung, Mehrspieler, Nebel des Krieges mit Sichtfeld-Overlay.
