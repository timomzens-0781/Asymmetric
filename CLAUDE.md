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
`scenario=<tools/scenarios/NAME.gd>`, `shot=<prefix>`, `shots=t1,t2,..`, `quit_after=<s>`.
Mit llvmpipe (Xvfb) rendert alles langsam – `--fixed-fps 30` macht Spielzeit deterministisch.

## Architektur in Kürze

* `scripts/main.gd` – Zustandsmaschine (title → briefing → playing ↔ paused → ended), baut `World`, KI, HUD.
* `autoload/game.gd` – Regeln: Budget, **Empörung/Videomaterial/Beweise**, Stufen, Fähigkeiten, Sieg/Niederlage.
* `world/world.gd` – Entitäten, Spatial-Hashes (`dyn` Einheiten, `stat` Gebäude), **Sichtbarkeit** (`seen_mask` / `ident_mask`),
  Verdacht gegen getarnte Rebellen, Zielwahl (`can_auto_target`), `explode`, Gebäude-Einsturz, Zivilisten-Management.
* `world/city.gd` – prozedurale Stadt (Straßen, Maske für den Bodenshader, Blöcke, Gebäude, Props, Dünen, Skyline).
* `entities/` – `Entity` (Basis) → `Unit` (Bewegung/Kampf/Tarnung/Garnison/Kontrolle), `Civilian`, `Structure`
  (Zivilhaus/Tunnelknoten/Basisgebäude, Produktion), `Projectile`, `Mine`.
* `core/data.gd` – alle Einheiten-/Gebäude-/Fähigkeitswerte, Schadensmatrix, Schlagzeilen.
* `ai/` – `AiAdf`, `AiRebel` (denken 1×/s, Mikro 0.4–0.6 s). KI nutzt dieselben `cmd_*`-Funktionen wie der Spieler.
* `control/player.gd` – Eingabe, Auswahl (Ray-Picking), Befehle, Zielmodi; `control/rts_camera.gd`.
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
