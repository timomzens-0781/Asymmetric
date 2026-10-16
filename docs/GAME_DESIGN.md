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

## 3b. Tunnelnetz

* Die 7 Tunnelknoten bilden einen Graphen: minimaler Spannbaum + 2 Zusatzkanten (Schleifen). Länge = 1,15 × Luftlinie.
* **Reise**: Besatzungen (Infanterie) reisen mit `N` zwischen Knoten, auch über mehrere Stationen (Dijkstra über aktive Kanten).
  Dauer = 2,5 s + Länge / 24 m/s. Die Einheit zählt sofort zur Besatzung des Zielknotens (belegt Platz), ist aber „unterwegs“.
* **Tunnel-Sammelpunkt**: Rechtsklick mit gewähltem Knoten auf einen anderen Knoten – neu ausgebildete Infanterie verschwindet im Haus und reist hin.
* **Entdeckung** (Aurelia): ein Aufklärungsflug mit Kreisradius 26 m findet jede Verbindung, deren Strecke ≤ 18 m vom Mittelpunkt
  verläuft, mit 45 % – beide Knoten gelten dann als entdeckt; die Verbindung erscheint rot gestrichelt auf Bild und Minikarte.
* **Zerstörung** eines Knotens: Verbindungen fallen weg; Reisende zum Knoten sterben.
* **KI**: Bedrohte Knoten (≥ 1,5 Bedrohung durch Armeeeinheiten ≤ 42 m, oder < 70 % Trefferpunkte) evakuieren ihre Besatzung durch den
  Tunnel in den sichersten Knoten.

## 3c. Radikalisierung & Hilfsmaßnahmen

```
Zivile Tote (Aurelia)  ─►  Wut im Viertel (0…100, Raster 40 m)  ─►  Freiwillige (Zivilist → getarnter Kämpfer, ≈ (Wut−10)/90·0,045 /s)
Zerstörtes Wohnhaus +4          │                                  ─►  Spenden +0,012 × Gesamtwut /s
Klinik/Schule +12·1,2           └─ Wut ≥ 22: „WUT n %“ im Bild      ─►  Verdacht der Armee ×(1 − Wut/160)
Zivile Tote durch Rebellen −2/Tote
Natürlicher Abbau −0,05/s
```

Aurelias Gegenmittel:

| Fähigkeit | Kosten | Abklingzeit | Wirkung |
|---|---|---|---|
| Hilfskonvoi (F7) | 400 | 60 s | 3 Hilfslaster fahren hin, jeder senkt die Wut um 15, Empörung −1. Beschuss durch Rebellen: +2 Beweise, Empörung −2,5 |
| Feldlazarett (F8) | 600 | 90 s | Gebäude (max. 2): Wut −0,9/s in der Umgebung, Empörung −0,08 %/10 s. Zerstörung durch Rebellen: +3 Beweise, Empörung −3 |
| Evakuierungskorridor (F9) | 150 | 50 s | Radius 40 m, 45 s: Zivilisten laufen hinaus, kein Nachschub aus Häusern, Verdachtszuwachs ×2,2 für Verbliebene |
| Presse-Briefing (F10) | 250 | 90 s | Empörung −2,5 %; 60 s lang wirken neue Zuwächse nur zu 70 % |

## 3c. Hadar-Front: Tricks

| Fähigkeit | Kosten | Abklingzeit | Wirkung |
|---|---|---|---|
| Upload (F1) | 0 | 4 s | Videomaterial ×1,35 → Empörung |
| Spendenaufruf (F2) | 0 | 70 s | 150 + 9·Empörung Budget |
| Menschliche Schutzschilde (F3) | 150 | 50 s | ≤ 8 Zivilisten im Radius 16 m, 40 s; sie stellen sich um den nächsten Kämpfer/besetztes Haus (`Unit.force_shield`). ADF-Auto-Ziel: kein Feuer auf Ziele mit ≥ 2 Schilden im Umkreis (`World.shield_near`). Tote Schilde: Ursache `shield` (Schwere ×1,6). Nebenwirkung: +0,5 Beweise je Zivilist, Wut −2 je Zivilist |
| Inszenierung (F4) | 200 | 60 s | Klinik/Schule: 60 s `staged_t`, `hot_t` dauerhaft; +4…9 Videomaterial; Zerstörung ×2,5 (Ursache `staged`), bis zu 4 Treffermeldungen je +1,5 Empörung; +2 Beweise für Aurelia, Wut +8 |
| Störsender (F5) | 180 | 70 s | `Game.jam_t` = 25 s: Luftfahrzeuge blind & ohne Zielerfassung, Präzisionsschlag/Aufklärungsflug gesperrt, kein Gegenbatterie-Radar |
| Rauchschleier (F6) | 120 | 35 s | `World.smokes` (Radius 15 m, 25 s): jenseits von 6 m kein Sichtkontakt zu/aus dem Rauch |

* **Scharfschütze** (200, 55 HP, Reichweite 50 m, 68 Schaden alle 3,4 s, Sicht 48 m, tarnbar) – tödlich aus Fenstern.
* **Besatzungsfeuer**: Eine Garnison schießt mit Reichweitenbonus `Radius·0,8 + 3` m, sieht entsprechend weiter und feuert von der zugewandten Fassade.
  Wer aus einem Tunnelknoten auf die Armee schießt, wird sofort entdeckt (`Structure.exposed_by_fire`).
* Wirtschaft: Start 2800, Einkommen 3,6/s je Knoten ×(1+Empörung/80) + 1,5.

## 3d. Häuserkampf & Sonderbefehle

* **Gebäude**: Trefferpunkte ×1,5; Schadensmultiplikator gegen Gebäude: Handfeuerwaffe 0,03 (vorher 0,10), Panzerabwehr 0,55 (vorher 0,8),
  Splitter/Lenkwaffe unverändert – Bomben, Artillerie und Raketen bleiben die schnelle (und teure) Lösung.
* **Stürmen** (`Unit.cmd_storm`, `Structure._sim_storm`): Angreifer (max. 8) verschwinden im Haus. Alle 2 s eine Kampfrunde:
  Verteidiger −15·√Angreifer, zufälliger Angreifer −13·√Verteidiger (je ±30 %). Pro Runde 14 % Chance, dass ein Bewohner stirbt
  (zählt als direkter Beschuss, Empörung). Ohne Verteidiger: Haus durchsucht (kleine Schikane) bzw. **Tunnelknoten gesichert**
  (`Structure.secure`: Knoten verlässt das Netz, kein Einsturz). Wird das Haus währenddessen zerstört, sterben die Angreifer mit.
* **KI**: Aurelia stürmt Tunnelknoten (bis zu 3 Versuche), wenn Bewohner > 3 oder Empörung > 25 % und ≥ 3 Infanteristen nahe sind;
  sonst bombardiert sie wie bisher.
* **Deckung / Verschanzen**: `entrenched` halbiert Kleinwaffenschaden (0,5 eingegraben, 0,58 an der Mauer), Splitter/Panzerabwehr nur 0,7/0,78.
  Eingraben dauert 2,4 s, jeder Bewegungsbefehl hebt es auf. Deckung sucht per `Nav.find_cover` eine freie Zelle neben einem Hindernis,
  das zwischen Einheit und nächstem sichtbaren Gegner liegt.
* **Patrouille**: Wegpunkte pendeln (Ping-Pong, Index 0 = Startpunkt); bis auf Bewegung verhält sich die Einheit wie bei Angriffsbewegung.
* **Drohnen**: Flughöhe 30 m (Kampfhubschrauber 21 m), Rüstung `airh`: Kleinwaffen 0, nur Waffen mit `aa` (RPG) zielen auf sie.
  Kosten 700, 170 TP.

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
  Nähe des Geschehens, legt Sprengfallen auf dem Anmarschweg und führt Gegenangriffe nur bei lokaler Überlegenheit. Sie nutzt auch die
  Tricks: Rauch und Schutzschilde an bedrohten Knoten, Inszenierung von Klinik/Schule bei Annäherung der Armee, Störsender gegen Luftunterstützung.

Schwierigkeit (0/1/2) skaliert Startbudget, Einkommen und Takt der KI.

## 6. Technik

* **Godot 4.3, GL Compatibility**, reiner GDScript, keine externen Assets.
* Prozedurale Stadt (`city.gd`, 320 × 320 m): Straßenraster, Blöcke → Grundstücke → Gebäude; Sonderzonen: Marktplatz, Park, Sportfeld, Rathausplatz, Zeltlager, Busdepot, Palmenhain, Klinik, Schule. Fassaden, Boden und Palmen sind
  Shader (`facade.gdshader`: Fenster, Balkone, Markisen, Putzschäden, Ruß, Einschusslöcher, beleuchtete Fenster am Abend).
* `MeshBuilder` baut Fahrzeuge/Infanterie/Gebäude aus Primitiven mit Vertex-Farben (1 Mesh = 1 Draw-Call).
* Navigation: eigenes 2-m-Raster mit zwei `AStarGrid2D` (Fußgänger / Fahrzeuge mit Sicherheitsabstand) und Pfadglättung.
* Sichtbarkeit: Beobachter-getriebene Abfrage über Spatial-Hash, 5×/s; getrennte Bits für *gesehen* und *identifiziert*.
* Tageszeit: Die Sonne wandert im Spielverlauf Richtung Dämmerung, Fenster beginnen zu leuchten.
* Audio: `tools/gen_audio.py` synthetisiert SFX (Filter-Rauschen, Sweeps) und zwei Musikstücke im Hijaz-Modus
  (Karplus-Strong-Zupfinstrument + Trommel); die Musik blendet dynamisch zwischen ruhig und Kampf.

## 6b. Auswertung

`Game` protokolliert Ereignisse (`log_event`), die Empörung im 2-s-Takt und die **Ursachen** jedes Empörungszuwachses
(`attrib`; Videomaterial wird anteilig nach Ursache geführt und beim Upload verteilt). `EndReport` zeichnet daraus Verlaufskurve,
Ursachenbalken und Wendepunkte.

## 7. Testen

* `tools/sim.tscn`: KI gegen KI, schnell, ohne Grafik (Balancing).
* `tools/scenarios/*.gd` + Startparameter `scenario=`: Szenarien mit Screenshots (Nahaufnahmen, Effekte, Eingabe-Simulation,
  Spielfluss).

## 8. Offene Punkte / Ideen

* Kampagnen- und Missionsstruktur; weitere Karten (Hafen, Grenzstadt).
* „Allianztreue“ als eigene Leiste mit Verbündeten (Waffenlieferungen, Basen).
* Presse-Briefings, Gegenpropaganda, Cyber-/Funkstörung; Zensur-/Pressefreiheits-Entscheidungen.
* Fahrzeug-Transport, Pioniere/Entminung, Scharfschützen, Checkpoints, Ausgangssperre; Dilemma-Ereignisse (UN-Beobachter, Waffenstillstand).
* Sichtfeld-/Nebel-Overlay, Replay und Mehrspieler.
