# Asymmetric – Designdokument (Prototyp 0.1)

## 1. Kernidee

Ein RTS im Stil von *C&C Generals*, bei dem die **Ressource nicht Gold oder Öl** ist, sondern die
**öffentliche Wahrnehmung**. Zwei Seiten, die dasselbe Schlachtfeld in völlig verschiedenen Währungen spielen:

| | Aurelische Streitkräfte (Supermacht) | Hadar-Front (Guerilla) |
|---|---|---|
| Stärke | Feuerkraft, Aufklärung, Budget | Tarnung, Zahl, Hinterhalt, Bilder |
| Schwäche | jeder Fehler wird zum Video | schwach im offenen Gefecht |
| Siegpunkt | Tunnelnetz zerschlagen | Empörung auf 100 % |
| Verlustpunkt | Empörung 100 % / Kommandozentrale | alle Tunnelknoten verloren |

Das Spiel will das Gefühl erzeugen: *„Ich könnte das sofort in Schutt und Asche legen – aber was kostet es mich?“*
(Aurelia) bzw. *„Ich brauche nur das richtige Bild zur richtigen Zeit.“* (Hadar-Front).

## 2. Die Empörungsmechanik

```
Ziviler Tod / Treffer auf Klinik, Schule, Presse
        │  Schwere: Direktbeschuss 1.5 · Einsturz/Splash 1.0 · "unklarer Vorfall" 0.45
        ▼
Dokumentation = 0.4 (Handys) + 0.6 (Medien-Team ≤ 42 m) + Zeugen (≤ 0.25)
        ▼
Videomaterial (nicht veröffentlicht)  ──Upload ×1.35──►  Empörung (0…100)
        │ ohne Medien-Team: langsames Durchsickern
        ▼
Stufe 1 (35 %)  Sanktionen         Budget −40 %
Stufe 2 (65 %)  Flugverbotszone    Luftschlag/Hubschrauber/Drohnen weg
Stufe 3 (100 %) Intervention       Aurelia verliert
```

Gegengewichte:

* Natürlicher Abbau (−0,03 %/s, wenn 30 s nichts passiert).
* **Beweise veröffentlichen** (Aurelia): Raketenabschüsse, die das Gegenbatterie-Radar ortet, und zivile Opfer
  durch Rebellen-Raketen füllen einen Beweis-Zähler; jeder Punkt senkt die Empörung um ≈ 3,2 %.
* Einwirkung der Hadar-Front: Journalisten sind **tabu** (Tod ⇒ +9 %), Klinik/Schule +14 %.

## 3. Nebel der Ungewissheit

* Rebellen mit `conceal` erscheinen für die Gegenseite als Zivilisten (bzw. ziviler Lkw).
* **Verdacht** wächst, wenn Beobachter mit `detect_range` in der Nähe sind (Infanterie 9 m, Aufklärer 15 m, Drohne 22 m,
  Wolf 12 m). Bei 100 → Enttarnung für 14 s. Bewegung erhöht die Auffälligkeit leicht.
* Aktive **Kontrolle** (`C`): Ein Soldat geht hin und überprüft die Person 2,2 s – sicher, aber nicht ohne Preis
  (Zivilisten: +0,2 % Empörung).
* **Tunnelknoten** = normale Gebäude (`hub = true`). Entdeckung durch: herauskommende Einheiten im Sichtfeld, Aufklärungsflug (50 %
  je Knoten im Radius), Gefecht.
* Wer aus einem Haus schießt, macht es **„heiß“** (7 s): Bei Einsatzregel *frei* beschießt Aurelia es automatisch.
* Zielvorschau der Schläge zeigt **geschätzte Zivilisten**, Kameras und sensible Orte. Die Zahlen sind
  Schätzungen – was die Armee nicht sieht, kann sie nicht zählen.

## 4. Einheiten (Prototyp)

Siehe `scripts/core/data.gd` (`UNITS`, `STRUCTS`, `ABILITIES`). Schadensmatrix `DMG_MULT` (Handfeuerwaffe / Panzerbrechend /
Splitter / Lenkwaffe / IED gegen Infanterie, Zivil, leicht, schwer, Gebäude, Luft).

Wichtige Dynamiken:

* **Hubschrauber** sind stark, aber Technicals und RPGs (RPG trifft Luft) halten sie in Schach.
* **Artillerie / Raketenrampen** feuern nur auf Befehl (Bodenziel) und streuen – Kollateralrisiko.
* **Raketenrampe**: ca. 2,5 s Aufbau, Salve von 4 Raketen, reichweite 140 m, danach wieder getarnt. Jeder Abschuss löst
  Radar-Ortung aus (Position für 14 s sichtbar, +1 Beweis).
* **Sprengfallen** (max. 8) sind unsichtbar, bis Aufklärer in die Nähe kommen; sie zünden bei Fahrzeugen im Radius 2,8 m.

## 5. Die KI

* **Aurelia-KI**: produziert nach Bedarfsquote, rückt in Sektoren vor (Drohne vorweg), hält Artillerie hinten, ruft
  Aufklärungsflüge, veröffentlicht Beweise. Auf Raketenabschüsse reagiert sie nach 4–8 s mit **Vergeltung** – wählt aber
  je nach Empörung und geschätzten Zivilisten zwischen Salve, Präzisionsschlag, Luftschlag, Haubitze oder bricht ab.
  Bei Tunnelknoten mit Bewohnern gibt sie erst eine **Warnung**, dann schlägt sie zu.
* **Hadar-KI**: besetzt Häuser entlang der Anmarschwege (Hinterhalt), lässt getarnte Streuner patrouillieren, schickt
  Raketenrampen in **dicht besiedelte Gebiete** (maximale Zivilistenzahl im Umkreis), stellt Medien-Teams in die
  Nähe des Geschehens, legt Sprengfallen auf dem Anmarschweg und führt Gegenangriffe nur bei lokaler Überlegenheit.

Schwierigkeit (0/1/2) skaliert Startbudget, Einkommen und Takt der KI.

## 6. Technik

* **Godot 4.3, GL Compatibility**, reiner GDScript, keine externen Assets.
* Prozedurale Stadt (`city.gd`): Straßenraster, Blöcke → Grundstücke → Gebäude. Fassaden, Boden und Palmen sind
  Shader (`facade.gdshader`: Fenster, Balkone, Markisen, Putzschäden, Ruß, Einschusslöcher, beleuchtete Fenster am Abend).
* `MeshBuilder` baut Fahrzeuge/Infanterie/Gebäude aus Primitiven mit Vertex-Farben (1 Mesh = 1 Draw-Call).
* Navigation: eigenes 2-m-Raster mit zwei `AStarGrid2D` (Fußgänger / Fahrzeuge mit Sicherheitsabstand) und Pfadglättung.
* Sichtbarkeit: Beobachter-getriebene Abfrage über Spatial-Hash, 5×/s; getrennte Bits für *gesehen* und *identifiziert*.
* Tageszeit: Die Sonne wandert im Spielverlauf Richtung Dämmerung, Fenster beginnen zu leuchten.
* Audio: `tools/gen_audio.py` synthetisiert SFX (Filter-Rauschen, Sweeps) und zwei Musikstücke im Hijaz-Modus
  (Karplus-Strong-Zupfinstrument + Trommel); die Musik blendet dynamisch zwischen ruhig und Kampf.

## 7. Testen

* `tools/sim.tscn`: KI gegen KI, schnell, ohne Grafik (Balancing).
* `tools/scenarios/*.gd` + Startparameter `scenario=`: Szenarien mit Screenshots (Nahaufnahmen, Effekte, Eingabe-Simulation,
  Spielfluss).

## 8. Offene Punkte / Ideen

* Kampagnen- und Missionsstruktur; mehrere Karten (Hafen, Grenzstadt, Flüchtlingslager).
* „Allianztreue“ als eigene Leiste mit Verbündeten (Waffenlieferungen, Basen).
* Presse-Briefings, Gegenpropaganda, Cyber-/Funkstörung; Zensur-/Pressefreiheits-Entscheidungen.
* Fahrzeug-Transport, Pioniere/Entminung, Scharfschützen, Checkpoints, Ausgangssperre.
* Sichtfeld-/Nebel-Overlay, Replay und Mehrspieler.
