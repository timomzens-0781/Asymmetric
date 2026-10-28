# CLAUDE.md – Arbeitsnotizen für Asymmetric

RTS in Godot 4.3 (GL Compatibility, GDScript), Asymmetrie-Thema: Hightech-Supermacht („Aurelia“) vs. Guerilla
(„Hadar-Front“), Siegbedingung über die **Empörungsleiste** (Weltöffentlichkeit). Sprache der UI/Texte: Deutsch.
Alle Assets sind prozedural (kein externer Content, keine Kosten) – bitte so beibehalten.

## Wichtige Befehle

```bash
GODOT=godot   # Godot 4.3+ (in der Cloud-Umgebung: /opt/godot_dl/Godot_v4.3-stable_linux.x86_64)
$GODOT --headless --path . --import                         # Klassen-Cache/Import aktualisieren (nach neuen class_name!)
$GODOT --headless --fixed-fps 30 --path . tools/test_mechanics.tscn   # Mechanik-Tests (PASS/FAIL)
$GODOT --headless --fixed-fps 30 --path . tools/sim.tscn -- seconds=300 speed=8 demo=0   # KI vs KI (Balancing)
xvfb-run -a $GODOT --fixed-fps 30 --rendering-driver opengl3 --path . -- autostart=0 scenario=closeup shot=/tmp/s   # Screenshots
python3 tools/gen_audio.py                                   # Audio neu erzeugen (assets/audio)
```

Startparameter (nach `--`): `autostart=0|1`, `diff=0|1|2`, `speed=`, `ai_both=1`, `tod=0..0.85`, `cam=x,z,dist[,yaw]`,
`scenario=<tools/scenarios/NAME.gd>` (z. B. overview, air, report, flow), `shot=<prefix>`, `shots=t1,t2,..`, `quit_after=<s>`.
Mit llvmpipe (Xvfb) rendert alles langsam – `--fixed-fps 30` macht Spielzeit deterministisch.

## Architektur in Kürze

* `scripts/main.gd` – Zustandsmaschine (title → briefing → playing ↔ paused → ended), baut `World`, KI, HUD.
* `autoload/game.gd` – Regeln: Budget, **Empörung/Videomaterial/Beweise**, Stufen, Fähigkeiten, Sieg/Niederlage.
* `world/world.gd` – Entitäten, Spatial-Hashes (`dyn` Einheiten, `stat` Gebäude), **Sichtbarkeit** (`seen_mask` / `ident_mask`),
  Verdacht gegen getarnte Rebellen, Zielwahl (`can_auto_target`), `explode`, Gebäude-Einsturz, Zivilisten-Management.
* `world/city.gd` – prozedurale Stadt 320 × 320 m (`HALF = 160`; Straßen, Maske für den Bodenshader, Blöcke aus Straßenlücken, Sonderzonen
  wie Park/Sportfeld/Lager, Props, Dünen, Skyline). Anker für KI/Basis: `base_assembly`, `base_front`, `far_goal`, `sectors`, `is_far_from_base()`.
  Basis liegt bei `BASE_RECT` (SW-Ecke); Aufstellung = altes Layout + `BASE_OFF`.
* `entities/` – `Entity` (Basis) → `Unit` (Bewegung/Kampf/Tarnung/Garnison/Kontrolle), `Civilian`, `Structure`
  (Zivilhaus/Tunnelknoten/Basisgebäude, Produktion), `Projectile`, `Mine`.
* `core/data.gd` – alle Einheiten-/Gebäude-/Fähigkeitswerte, Schadensmatrix, Schlagzeilen.
* `ai/` – `AiAdf`, `AiRebel` (denken 1×/s, Mikro 0.4–0.6 s). KI nutzt dieselben `cmd_*`-Funktionen wie der Spieler.
* `control/player.gd` – Eingabe, Auswahl (Ray-Picking), Befehle, Zielmodi; `control/rts_camera.gd`.
* Tunnelnetz & Radikalisierung leben in `world/world.gd` (`tunnels`, `tunnel_route`, `anger`/`add_anger`/`_district_tick`, Korridore,
  Feldlazarett); Einheiten-Seite: `Unit.cmd_tunnel`, `tunnel_t`. Hilfsfähigkeiten in `world/support.gd`.
* Auswertung: `Game.log_event`, `attrib`, `outrage_samples` → `ui/end_report.gd`. Empörung immer mit Ursache erhöhen
  (`add_outrage(v, silent, "strike"|…)` bzw. `add_footage(…, cause)`).
* Haeuserkampf: `Unit.cmd_storm`/`storming`, `Structure.stormers`/`_sim_storm`/`secure()`. Sonderbefehle (`cmd_patrol`, `cmd_take_cover`,
  `cmd_entrench`, Zustand `entrenched`) in `entities/unit.gd`; Steuerung in `control/player.gd` (Modi `patrol`/`storm`).
* Grafikstufen: `Gfx.quality`/`apply_quality` (MSAA, Schatten); Modelle blicken nach **+Z** – `look_at` zeigt -Z, also `look_at(pos - dir)` verwenden.
* `ui/` – HUD (alles per Code gebaut), `Minimap`, `WorldOverlay` (2D-Marker über der Welt), `Screens` (Menüs).
* `gfx/` – `MeshBuilder` (Primitive → 1 Mesh mit Vertex-Farben), `Models`, `Props`, `Fx` (GPU-Partikel), Shader.

## Konventionen / Stolpersteine

* GDScript: bei untypisierten Arrays (`for u in world.units`) **kein `:=`** auf Member-Zugriffe (Inferenzfehler) – `var x: float = …`.
* Neue `class_name`-Skripte → einmal `--import` ausführen, sonst „Could not find type“.
* Sichtbarkeit: `Entity.seen_by(team)` (physisch gesehen) vs. `identified_by(team)` (als Feind erkannt). Getarnte Rebellen sind
  gesehen, aber nicht identifiziert. Zivilisten/Gebäude: `can_auto_target` regelt, was automatisch beschossen wird.
* Empörung nie direkt erhöhen, sondern über `Game.report_civilian_deaths` / `report_event_outrage` (berücksichtigt Kameras).
* `Engine.time_scale` + `get_tree().paused` für Geschwindigkeit/Pause; Fx/Timer laufen darüber mit.
* Headless gibt der Dummy-Renderer harmlose „Parameter "m" is null“-Fehler aus (Meshes) – ignorieren.

## Hadar-Front-Tricks & Besatzungen (Runde 5)

* Fähigkeiten `shield`/`staged`/`jam`/`smoke` (Data.ABILITIES, `Support._shield/_staged/_smoke`, `Game.jam_t`, `World.smokes`). Schilde: `Unit.shield_t`,
  `force_shield`, `_sim_shield`; Feuerdisziplin in `World.can_auto_target` über `shield_near`. Ursachen `shield`/`staged` in `Game.CAUSE_LABELS`.
* Besatzungen: `Structure.garrison_of(team)`, `window_pos`, `exposed_by_fire`; `Unit._sim_garrison` (Reichweitenbonus `_garrison_range_bonus`); die Sicht
  Garnisonierter wird in `World._vis_tick` um denselben Bonus erweitert. Infoleiste zeigt Besatzungs-Symbole (`InfoPanel`), Rechtsklick bei gewähltem Haus führt heraus.
* Tests einzeln: `-- only=<Name>` (z. B. `only=reb_tricks`, `only=garrison_fire`), `REPEAT=n` als Umgebungsvariable wiederholt den Test.
* Gebäude-Verdacht: `Structure.suspicion`/`add_suspicion`/`note_traffic`/`observed_by_adf`; Durchsuchen = `cmd_storm` mit `SEARCH_TIME` (5 s); `AiAdf._investigate`. Test: `only=suspicion_search`.
* Hilfe: `Screens.show_help` (Tabs aus `Data.ABILITIES`/`Data.UNITS`, Reihenfolge in `Data.ABILITY_ORDER`), Taste F12 in `main.gd`. Neue Fähigkeiten/Einheiten tauchen automatisch auf – `desc` pflegen.
* Gebäudevielfalt: `City._massing_and_details` (Staffelgeschoss, Balkone, Mashrabiya, Klimageräte, Schattendach, Kuppeln) nutzt einen eigenen RNG je Gebäude (`b.id`), damit das Stadtlayout/Seed unverändert bleibt.

## Lokal unter Windows arbeiten

Das Projekt wird auch lokal auf dem Windows-PC des Nutzers weiterentwickelt (die Linux-Befehle oben gelten nur für die Cloud-Umgebung).

* Repo-Ordner: `C:\Users\timom\OneDrive\Dokumente\Asymmetric` (Empfehlung: außerhalb von OneDrive, z. B. `C:\Dev\Asymmetric`, sonst Sync-Konflikte in `.git` und `.godot`).
* Godot: `C:\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe` (das Projekt wurde mit Godot 4.3 gebaut – bei Parse- oder Importproblemen mit der neueren Version zuerst `--import` laufen lassen und Warnungen prüfen).
* PowerShell-Variante der Befehle (Godot-Pfad in eine Variable legen):

```powershell
$GODOT = "C:\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe"
& $GODOT --headless --path . --import                                              # Import / Klassen-Cache
& $GODOT --headless --fixed-fps 30 --path . tools/test_mechanics.tscn              # Mechanik-Tests
& $GODOT --headless --fixed-fps 30 --path . tools/test_mechanics.tscn -- only=reb_tricks   # einzelner Test
& $GODOT --headless --fixed-fps 30 --path . tools/sim.tscn -- seconds=300 speed=8 demo=0   # KI vs KI
& $GODOT --path . -- autostart=0 scenario=closeup shot=C:\Temp\s                   # Screenshots (mit Fenster, kein xvfb nötig)
python tools/gen_audio.py                                                          # Audio neu erzeugen
```

* Umgebungsvariablen für Tests (z. B. `REPEAT=n`) in PowerShell: `$env:REPEAT = 6`.
* `xvfb-run`, `/opt/...`-Pfade und `/tmp` gibt es unter Windows nicht – Screenshot-Pfade selbst wählen (Ordner muss existieren).
* Zeilenenden: Skripte sind LF; `git config core.autocrlf input` verhindert unnötige Diffs.
* Branch-Stand: Entwicklung lief auf `claude/vibrant-rubin-uinaad`; vor lokalem Arbeiten `git fetch` + `git checkout claude/vibrant-rubin-uinaad` + `git pull`.
