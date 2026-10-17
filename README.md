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
| Patrouille (Wegpunkte; `Shift` = weitere, letzter Klick ohne `Shift`) | `P`, dann Linksklick |
| Deckung nehmen (zur nächsten Mauer zwischen Einheit und Gegner) / Verschanzen (eingraben) | `K` / `Z` |
| Haus stürmen (Aurelia-Infanterie; auch Rechtsklick auf ein aktives Haus) | `Y`, dann Haus anklicken |
| Stopp / Feuer halten | `X` / `H` |
| Person kontrollieren (Aurelia) | `C`, dann auf die Person klicken |
| Feuerbefehl Artillerie / Raketenrampe | `F`, dann Bodenziel |
| Zivile Tarnung an/aus (Hadar-Front) | `G` |
| Sprengfalle legen (Hadar-Front) | `B` |
| Gebäude räumen | `V` |
| Tunnelreise der Besatzung (Hadar-Front, Tunnelknoten gewählt) | `N`, dann Ziel-Knoten anklicken |
| Tunnel-Sammelpunkt (neue Kämpfer reisen unterirdisch) | Knoten gewählt, Rechtsklick auf anderen Knoten |
| Einsatzregeln streng/frei (Aurelia) | `R` |
| Unterstützung / Fähigkeiten | `F1`–`F10` oder Buttons rechts |
| Letzter Alarm | `Leertaste` |
| Kontrollgruppen | `Strg+1…9` speichern, `1…9` abrufen (2× = Kamera hinschicken) |
| Spielgeschwindigkeit | `+` / `−` |
| Pause / Menü | `Esc` · Vollbild `F11` · **Hilfe** `F12` (Grundlagen, Fähigkeiten & Einheiten beider Seiten, Steuerung) |

Wird eine eigene Einheit beschossen, zeigt ein **roter Pfeil am Bildrand** (bzw. ein roter Ring auf dem Bildschirm) die Richtung und Entfernung des Feuergefechts; `Leertaste` springt dorthin.

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

### Häuserkampf

Besetzte Häuser sind **zäh**: Handfeuerwaffen richten kaum etwas an Gebäuden an, Panzer brauchen lange – wer schnell fertig werden
will, greift zum Luftschlag (und zahlt in Empörung). Die Alternative ist das **Stürmen** (`Y`): Infanterie dringt ein, kämpft Mann gegen Mann
(langsam, mit Verlusten, Zivilisten im Haus geraten ins Feuer – aber ohne Einsturz). Gesicherte Tunnelknoten fallen ohne Trümmer aus dem Netz.
Die Aurelia-KI stürmt, sobald Zivilisten gefährdet sind oder die Empörung steigt.
**Deckung** (`K`) und **Verschanzen** (`Z`) halbieren den erlittenen Schaden fast; **Patrouille** (`P`) funktioniert für alle Einheiten –
auch Drohnen überwachen so ein Gebiet. Die Argus-Drohne fliegt jetzt hoch über den Dächern und ist nur noch durch RPGs verwundbar (dafür teurer).

### Radikalisierung („Wut“ der Viertel)

Die Karte ist in Viertel (Planquadrate A1–H8) unterteilt. **Jeder zivile Tote, jedes zerstörte Wohnhaus, jede getroffene Klinik
macht das Viertel wütend.** Wütende Viertel

* schicken der Hadar-Front **Freiwillige** (Zivilisten werden zu getarnten Kämpfern, kostenlos),
* bringen ihr **Spenden** (Einkommen steigt mit der Gesamtwut),
* **decken** ihre getarnten Kämpfer (der Verdacht der Armee wächst dort langsamer).

Wut klingt langsam ab – schneller mit Hilfsmaßnahmen. Die Minikarte tönt unruhige Viertel rot, im Bild stehen „WUT n %“-Marken.

### Das Tunnelnetz

Die sieben Tunnelknoten sind **unterirdisch verbunden**. Die Hadar-Front schickt Besatzungen mit `N` unsichtbar von Knoten zu Knoten
(auch über mehrere Stationen), setzt Tunnel-Sammelpunkte für neue Kämpfer und zieht Verteidiger vor einem Angriff ab
(die KI tut das von selbst). Aurelia kann das Netz aufspüren: Ein **Aufklärungsflug** über einer Verbindung findet sie – und damit
**beide** Knoten. Wird ein Knoten zerstört, kappt das alle seine Verbindungen; wer gerade dorthin unterwegs ist, wird verschüttet.

### Aurelia – Werkzeuge

Infanterie, Aufklärer, Wolf-Schützenpanzer, Titan-Kampfpanzer, Hammer-Haubitze, Argus-Drohne, Viper-Kampfhubschrauber.
Unterstützung: **Präzisionsschlag** (teuer, chirurgisch), **Artillerie-Salve** (billig, ungenau), **Luftschlag**
(gewaltig), **Evakuierungswarnung**, **Aufklärungsflug**, **Beweise veröffentlichen**.
Hilfsmaßnahmen: **Hilfskonvoi** (F7), **Feldlazarett** (F8), **Evakuierungskorridor** (F9), **Presse-Briefing** (F10) –
sie senken die Wut in den Vierteln bzw. die Empörung (siehe unten).
Sieg: alle sieben Tunnelknoten zerstören oder sichern. Niederlage: Kommandozentrale zerstört oder Empörung 100 %.

### Wie Aurelia Tunnelknoten findet

Knoten sind Wohnhäuser, bis die Armee sie entlarvt – blind ganze Straßenzüge zu zerstören kostet Empörung und Beweise. Hinweise liefert die **Beobachtung**:
Häuser mit Rebellen-Besatzung sammeln **Verdacht**, solange Aurelia-Einheiten sie sehen (Aufklärer und Drohnen doppelt so gut); jedes Hinein- und Hinausgehen von
Kämpfern erhöht ihn sprunghaft. Ab 15 % erscheint ein gelbes **„?“**, ab 50 % kommt eine Meldung, bei 100 % wird ein Knoten entdeckt (ein gewöhnliches Haus mit
Bewaffneten gilt dann als „heiß“). **Durchsuchen / Stürmen** (`Y`) klärt es sicher: ein leeres Haus dauert 5 s und setzt den Verdacht zurück (leichte Schikane für
Anwohner); sitzen Kämpfer darin, kommt es zum Häuserkampf. Rauch und Störsender (Hadar-Front) verhindern Beobachtung.

### Hadar-Front – Werkzeuge

Kämpfer (tarnbar), RPG-Schütze (tarnbar), **Scharfschütze** (50 m Reichweite, tarnbar), Technical, Raketenrampe (tarnbar, provoziert),
Medien-Team, Sprengfallen-Leger. Produktion in den **Tunnelknoten**; Einkommen steigt mit der Empörung (Spenden!).

Fähigkeiten (F1–F6) – die „fiesen Tricks“:

| Taste | Fähigkeit | Wirkung |
|---|---|---|
| F1 | **Upload** | veröffentlicht das gesammelte Videomaterial |
| F2 | **Spendenaufruf** | verwandelt Sympathie in Geld |
| F3 | **Menschliche Schutzschilde** | zwingt bis zu 8 Zivilisten im Zielgebiet 40 s lang, sich um Kämpfer/besetzte Häuser zu stellen. Die Armee stellt dort das Feuer ein (Feuerdisziplin) – tötet sie doch Zivilisten, zählt das als eigene, besonders schwere Empörungsursache. Preis: Aurelia sammelt Beweise, die Wut im Viertel sinkt |
| F4 | **Inszenierung (Klinik/Schule)** | sofort Videomaterial, das Gebäude gilt als „heiß“ (Köder) und ein Treffer löst ×2,5 Empörung aus. Aurelia bekommt Beweise für „militärische Nutzung“ |
| F5 | **Störsender** | 25 s lang fallen Drohnen, Präzisionsschlag, Aufklärungsflug und Gegenbatterie-Radar aus |
| F6 | **Rauchschleier** | 25 s lang sieht niemand weiter als 6 m in oder durch den Rauch |

**Besatzungen:** Befindet sich eigene Besatzung in einem Haus, erscheint sie als Symbole in der Infoleiste (Klick wählt, Rechtsklick auf den Boden bei gewähltem
Haus führt alle heraus, `V` räumt). Aus Häusern wird durch die „Fenster“ geschossen (Reichweitenbonus ab Fassade) – wer aus einem Tunnelknoten feuert, verrät ihn.
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

## Grafik

Im Pausenmenü lässt sich die **Grafikstufe** (Niedrig / Mittel / Hoch) umschalten: Kantenglättung (MSAA 0/2×/4×) sowie Schattenauflösung und -reichweite.
Fassaden und Boden haben Relief (Fensterlaibungen, Fugen, Gehsteigkanten, Dünenrippel), der Himmel ist ein eigener Shader mit wandernden Wolken.

## Auswertung

Nach jeder Partie zeigt der Endbildschirm den **Verlauf der Empörung** mit Ereignismarken (Opfer, Uploads, Stufen, Tunnelknoten …),
eine Aufschlüsselung **„Woher kam die Empörung?“** (Luftschläge, Einstürze, Journalisten, Kliniken …) und die **Wendepunkte** der Partie.

## Ausblick

Dies ist ein **spielbarer Prototyp** (erste „Mission“ auf einer 320×320 m großen Karte mit Altstadt, Marktplatz, Park, Sportfeld, Rathausplatz und Zeltlager). Ideen für die nächsten Schritte:
weitere Karten und Kampagne (Hafen, Grenzstadt), Verbündete/Allianztreue als eigene Mechanik, mehr Einheiten (Pioniere, Scharfschützen,
Panzerabwehr-Teams), Checkpoints und Ausgangssperren, Cyber-/Funkstörung, Mehrspieler, Nebel des Krieges mit Sichtfeld-Overlay.
