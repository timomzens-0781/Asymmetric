class_name Data
extends RefCounted
## Statische Spieldaten: Einheiten, Gebaeude, Faehigkeiten, Schadensmatrix, Schlagzeilen.

const FACTION_NAMES := {
	0: "Aurelische Streitkräfte",
	1: "Hadar-Front",
	2: "Zivilbevölkerung",
}

## Schadensmultiplikatoren [Schadenstyp][Panzerungsklasse]
const DMG_MULT := {
	"bullet":  {"inf": 1.0, "civ": 1.0, "light": 0.35, "heavy": 0.08, "struct": 0.03, "air": 0.45, "airh": 0.0},
	"ap":      {"inf": 0.7, "civ": 0.7, "light": 1.0, "heavy": 1.0, "struct": 0.55, "air": 0.8, "airh": 0.8},
	"he":      {"inf": 1.0, "civ": 1.0, "light": 0.9, "heavy": 0.6, "struct": 1.25, "air": 0.0, "airh": 0.0},
	"missile": {"inf": 0.8, "civ": 0.8, "light": 1.0, "heavy": 0.9, "struct": 1.0, "air": 1.0, "airh": 1.0},
	"ied":     {"inf": 1.0, "civ": 1.0, "light": 1.2, "heavy": 0.9, "struct": 0.5, "air": 0.0, "airh": 0.0},
}

const UNITS := {
	# ------------------------------------------------------------ AURELIA (Supermacht)
	"adf_rifle": {
		"short": "Infanterie", "name": "Infanterist", "team": 0, "cost": 100, "time": 4.0, "hp": 100.0, "speed": 5.2,
		"turn": 12.0, "vision": 26.0, "radius": 0.8, "layer": "foot", "armor": "inf", "pop": 1,
		"weapons": [{"range": 23.0, "damage": 8.0, "cd": 0.55, "type": "bullet", "proj": "hit", "air": true}],
		"detect_range": 9.0, "detect_rate": 24.0, "icon": "inf", "model": "adf_rifle",
		"desc": "Standardinfanterie. Billig, schnell ausgebildet, erkennt Verdächtige im Nahbereich.",
	},
	"adf_recon": {
		"short": "Aufklärer", "name": "Aufklärer", "team": 0, "cost": 160, "time": 5.0, "hp": 90.0, "speed": 5.6,
		"turn": 12.0, "vision": 34.0, "radius": 0.8, "layer": "foot", "armor": "inf", "pop": 1,
		"weapons": [{"range": 26.0, "damage": 9.0, "cd": 0.7, "type": "bullet", "proj": "hit", "air": false}],
		"detect_range": 15.0, "detect_rate": 40.0, "icon": "eye", "model": "adf_recon",
		"desc": "Spezialist mit Wärmebildgerät. Entlarvt getarnte Kämpfer deutlich schneller.",
	},
	"adf_apc": {
		"short": "Wolf IFV", "name": "Wolf IFV", "team": 0, "cost": 450, "time": 9.0, "hp": 520.0, "speed": 9.5,
		"turn": 2.6, "vision": 34.0, "radius": 2.0, "layer": "wheel", "armor": "light", "pop": 3,
		"weapons": [{"range": 29.0, "damage": 9.0, "cd": 0.22, "type": "bullet", "proj": "hit", "air": true}],
		"detect_range": 12.0, "detect_rate": 26.0, "icon": "apc", "model": "adf_apc",
		"desc": "Schneller Schützenpanzer mit Maschinenkanone. Gut gegen Infanterie und Technicals.",
	},
	"adf_mbt": {
		"short": "Titan", "name": "Titan MBT", "team": 0, "cost": 950, "time": 14.0, "hp": 1100.0, "speed": 6.2,
		"turn": 1.9, "vision": 36.0, "radius": 2.4, "layer": "track", "armor": "heavy", "pop": 4,
		"weapons": [{"range": 42.0, "damage": 125.0, "cd": 2.8, "type": "ap", "proj": "shell", "splash": 2.6, "speed": 90.0, "air": false}],
		"detect_range": 10.0, "detect_rate": 14.0, "icon": "tank", "model": "adf_mbt",
		"desc": "Kampfpanzer. Fast unverwundbar gegen Handfeuerwaffen – RPGs sind die Gefahr.",
	},
	"adf_arty": {
		"short": "Haubitze", "name": "Hammer Haubitze", "team": 0, "cost": 750, "time": 12.0, "hp": 380.0, "speed": 5.5,
		"turn": 1.8, "vision": 24.0, "radius": 2.3, "layer": "track", "armor": "light", "pop": 3,
		"weapons": [{"range": 100.0, "min_range": 26.0, "damage": 150.0, "cd": 6.5, "type": "he", "proj": "arty", "splash": 8.0, "spread": 6.5, "speed": 48.0, "air": false}],
		"detect_range": 0.0, "detect_rate": 0.0, "icon": "arty", "model": "adf_arty", "manual_only": true,
		"desc": "Billige Flächenwirkung auf große Distanz. Ungenau – hohes Kollateralrisiko!",
	},
	"adf_drone": {
		"short": "Drohne", "name": "Argus Drohne", "team": 0, "cost": 700, "time": 10.0, "hp": 170.0, "speed": 16.0,
		"turn": 3.0, "vision": 54.0, "radius": 1.0, "layer": "air", "armor": "airh", "pop": 2, "high": true, "air_h": 30.0,
		"weapons": [],
		"detect_range": 22.0, "detect_rate": 14.0, "icon": "drone", "model": "adf_drone",
		"desc": "Aufklärungsdrohne mit riesiger Sichtweite, fliegt hoch über den Dächern. Nur RPGs können sie erreichen. Mit P auf Patrouille schicken.",
	},
	"adf_viper": {
		"short": "Viper", "name": "Viper Kampfhubschrauber", "team": 0, "cost": 1200, "time": 16.0, "hp": 420.0, "speed": 15.0,
		"turn": 2.4, "vision": 42.0, "radius": 2.0, "layer": "air", "armor": "air", "pop": 4, "air_h": 21.0,
		"weapons": [
			{"range": 40.0, "damage": 80.0, "cd": 3.2, "type": "missile", "proj": "missile", "splash": 3.0, "speed": 60.0, "air": true},
			{"range": 32.0, "damage": 7.0, "cd": 0.14, "type": "bullet", "proj": "hit", "air": true},
		],
		"detect_range": 14.0, "detect_rate": 16.0, "icon": "heli", "model": "adf_viper",
		"desc": "Verheerende Feuerkraft aus der Luft. Wird bei Flugverbotszone abgezogen!",
	},
	"adf_aid": {
		"short": "Hilfslaster", "name": "Hilfskonvoi-Lkw", "team": 0, "cost": 0, "time": 1.0, "hp": 260.0, "speed": 9.0,
		"turn": 2.8, "vision": 24.0, "radius": 1.9, "layer": "wheel", "armor": "light", "pop": 0,
		"weapons": [],
		"detect_range": 0.0, "detect_rate": 0.0, "icon": "aid", "model": "adf_aid",
		"desc": "Unbewaffneter Hilfslaster mit Wasser, Lebensmitteln und Medikamenten. Ein Angriff darauf wäre ein Propagandageschenk.",
	},
	# ------------------------------------------------------------ HADAR-FRONT (Guerilla)
	"reb_fighter": {
		"short": "Kämpfer", "name": "Kämpfer", "team": 1, "cost": 60, "time": 3.0, "hp": 70.0, "speed": 5.4,
		"turn": 12.0, "vision": 24.0, "radius": 0.8, "layer": "foot", "armor": "inf", "pop": 1,
		"weapons": [{"range": 20.0, "damage": 7.0, "cd": 0.6, "type": "bullet", "proj": "hit", "air": true}],
		"conceal": true, "icon": "inf", "model": "reb_fighter",
		"desc": "Spottbillig. Kann sich als Zivilist tarnen und aus dem Hinterhalt zuschlagen.",
	},
	"reb_rpg": {
		"short": "RPG", "name": "RPG-Schütze", "team": 1, "cost": 120, "time": 5.0, "hp": 75.0, "speed": 5.0,
		"turn": 12.0, "vision": 24.0, "radius": 0.8, "layer": "foot", "armor": "inf", "pop": 1,
		"weapons": [{"range": 28.0, "damage": 150.0, "cd": 4.6, "type": "ap", "proj": "rocket", "splash": 1.8, "speed": 42.0, "air": true, "aa": true}],
		"conceal": true, "icon": "rpg", "model": "reb_rpg",
		"desc": "Der Panzerschreck der Armen. Zwei, drei Treffer – und der Gigant brennt.",
	},
	"reb_tech": {
		"short": "Technical", "name": "Technical", "team": 1, "cost": 260, "time": 7.0, "hp": 230.0, "speed": 12.5,
		"turn": 3.2, "vision": 28.0, "radius": 1.9, "layer": "wheel", "armor": "light", "pop": 2,
		"weapons": [{"range": 30.0, "damage": 10.0, "cd": 0.18, "type": "bullet", "proj": "hit", "air": true}],
		"icon": "tech", "model": "reb_tech",
		"desc": "Pick-up mit schwerem MG. Schnell, billig – und ein Albtraum für Hubschrauber.",
	},
	"reb_launcher": {
		"short": "Raketen", "name": "Raketenrampe", "team": 1, "cost": 380, "time": 11.0, "hp": 160.0, "speed": 8.0,
		"turn": 2.6, "vision": 22.0, "radius": 2.0, "layer": "wheel", "armor": "light", "pop": 3,
		"weapons": [{"range": 140.0, "min_range": 35.0, "damage": 42.0, "cd": 15.0, "type": "he", "proj": "arty", "splash": 4.5, "spread": 5.0, "speed": 40.0, "air": false, "burst": 4, "burst_gap": 0.35}],
		"conceal": true, "setup": 2.5, "icon": "launcher", "model": "reb_launcher", "manual_only": true, "is_launcher": true,
		"desc": "Getarnter Lkw mit Raketen. Jeder Abschuss provoziert – und verrät die Position.",
	},
	"reb_media": {
		"short": "Medien", "name": "Medien-Team", "team": 1, "cost": 150, "time": 6.0, "hp": 40.0, "speed": 5.6,
		"turn": 12.0, "vision": 20.0, "radius": 0.8, "layer": "foot", "armor": "civ", "pop": 1,
		"weapons": [], "press": true, "film_range": 42.0, "icon": "camera", "model": "reb_media",
		"desc": "Filmt das Geschehen. Aufnahmen mit Kamera-Präsenz wiegen ein Vielfaches.",
	},
	"reb_saboteur": {
		"short": "Saboteur", "name": "Sprengfallen-Leger", "team": 1, "cost": 140, "time": 6.0, "hp": 55.0, "speed": 5.6,
		"turn": 12.0, "vision": 22.0, "radius": 0.8, "layer": "foot", "armor": "inf", "pop": 1,
		"weapons": [], "conceal": true, "ied": true, "icon": "ied", "model": "reb_saboteur",
		"desc": "Legt versteckte Sprengfallen (IED) an Straßen. Fahrzeuge zahlen den Preis.",
	},
}

const STRUCTS := {
	"adf_hq": {
		"name": "Kommandozentrale", "team": 0, "hp": 3600.0, "armor": "struct", "vision": 44.0, "size": Vector3(15, 7, 13),
		"produces": ["adf_drone"], "desc": "Herz der Operation. Fällt sie, ist die Mission verloren.",
	},
	"adf_barracks": {
		"name": "Kaserne", "team": 0, "hp": 1700.0, "armor": "struct", "vision": 30.0, "size": Vector3(13, 4.5, 9),
		"produces": ["adf_rifle", "adf_recon"], "desc": "Bildet Infanterie aus.",
	},
	"adf_factory": {
		"name": "Fahrzeugfabrik", "team": 0, "hp": 2200.0, "armor": "struct", "vision": 30.0, "size": Vector3(16, 7, 12),
		"produces": ["adf_apc", "adf_mbt", "adf_arty"], "desc": "Produziert Schützenpanzer, Kampfpanzer und Artillerie.",
	},
	"adf_airfield": {
		"name": "Hubschrauberlandeplatz", "team": 0, "hp": 1500.0, "armor": "struct", "vision": 34.0, "size": Vector3(14, 3, 14),
		"produces": ["adf_viper", "adf_drone"], "desc": "Kampfhubschrauber und Drohnen. Nicht nutzbar bei Flugverbotszone.",
	},
	"adf_press": {
		"name": "Pressezentrum", "team": 0, "hp": 1100.0, "armor": "struct", "vision": 26.0, "size": Vector3(10, 4.5, 8),
		"produces": [], "desc": "Veröffentlicht Beweismaterial und dämpft die Empörung.",
	},
	"adf_radar": {
		"name": "Gegenbatterie-Radar", "team": 0, "hp": 1000.0, "armor": "struct", "vision": 60.0, "size": Vector3(7, 9, 7),
		"produces": [], "desc": "Ortet Raketenabschüsse und liefert Abschussposition.",
	},
	"adf_fieldhosp": {
		"name": "Feldlazarett", "team": 0, "hp": 650.0, "armor": "struct", "vision": 16.0, "size": Vector3(9, 3.2, 9),
		"produces": [], "desc": "Versorgt Verletzte, beruhigt das Viertel und senkt die Empörung. Ein Angriff darauf wäre ein Propagandageschenk.",
	},
	"adf_tower": {
		"name": "Wachturm", "team": 0, "hp": 800.0, "armor": "struct", "vision": 34.0, "size": Vector3(4, 9, 4),
		"produces": [], "desc": "Automatischer MG-Turm.",
		"weapons": [{"range": 30.0, "damage": 9.0, "cd": 0.2, "type": "bullet", "proj": "hit", "air": true}],
	},
}

## Globale Faehigkeiten (pro Seite)
const ABILITIES := {
	"airstrike": {
		"team": 0, "name": "Luftschlag", "cost": 500, "cd": 45.0, "radius": 14.0, "target": true, "icon": "bomb",
		"desc": "Bomberstaffel räumt eine Schneise. Gewaltig – und gewaltiger Kollateralschaden.",
		"needs_air": true,
	},
	"precision": {
		"team": 0, "name": "Präzisionsschlag", "cost": 1200, "cd": 22.0, "radius": 5.0, "target": true, "icon": "missile",
		"desc": "Lenkwaffe mit kleinem Wirkradius. Teuer, aber chirurgisch.",
		"needs_air": false,
	},
	"salvo": {
		"team": 0, "name": "Artillerie-Salve", "cost": 250, "cd": 26.0, "radius": 15.0, "target": true, "icon": "arty",
		"desc": "Billige Flächenfeuer-Salve. Ungenau und riskant.",
		"needs_air": false,
	},
	"warning": {
		"team": 0, "name": "Evakuierungswarnung", "cost": 40, "cd": 5.0, "radius": 10.0, "target": true, "icon": "horn",
		"desc": "Warnschuss auf das Dach: Zivilisten verlassen das Gebäude. Auch Kämpfer ahnen den Schlag.",
		"needs_air": false,
	},
	"scan": {
		"team": 0, "name": "Aufklärungsflug", "cost": 150, "cd": 30.0, "radius": 26.0, "target": true, "icon": "eye",
		"desc": "Entlarvt getarnte Kämpfer im Zielgebiet und spürt Tunnelsignaturen auf.",
		"needs_air": false,
	},
	"evidence": {
		"team": 0, "name": "Beweise veröffentlichen", "cost": 0, "cd": 25.0, "radius": 0.0, "target": false, "icon": "doc",
		"desc": "Setzt gesammeltes Beweismaterial (Kämpfer in zivilen Gebäuden, Raketenabschüsse) gegen die Empörung ein.",
		"needs_air": false,
	},
	"convoy": {
		"team": 0, "name": "Hilfskonvoi", "cost": 400, "cd": 60.0, "radius": 18.0, "target": true, "icon": "aid",
		"desc": "Drei Hilfslaster fahren ins Zielgebiet und verteilen Wasser und Medikamente. Senkt Wut im Viertel und die Empörung. Die Hadar-Front könnte den Konvoi beschießen.",
		"needs_air": false,
	},
	"fieldhosp": {
		"team": 0, "name": "Feldlazarett", "cost": 600, "cd": 90.0, "radius": 8.0, "target": true, "icon": "medic",
		"desc": "Baut ein Lazarett im Viertel auf. Solange es steht, sinkt die Wut der Bevölkerung und die Empörung langsam. Maximal zwei.",
		"needs_air": false,
	},
	"corridor": {
		"team": 0, "name": "Evakuierungskorridor", "cost": 150, "cd": 50.0, "radius": 40.0, "target": true, "icon": "corridor",
		"desc": "Zivilisten verlassen das Gebiet für 45 Sekunden. Wer bleibt, fällt auf – Verdacht steigt doppelt so schnell. Die Hadar-Front wird gewarnt.",
		"needs_air": false,
	},
	"briefing": {
		"team": 0, "name": "Presse-Briefing", "cost": 250, "cd": 90.0, "radius": 0.0, "target": false, "icon": "mic",
		"desc": "Aurelia setzt ihre Erzählung: sofort −2,5 % Empörung und 60 Sekunden lang wirken neue Bilder nur zu 70 %.",
		"needs_air": false,
	},
	"upload": {
		"team": 1, "name": "Upload", "cost": 0, "cd": 4.0, "radius": 0.0, "target": false, "icon": "upload",
		"desc": "Veröffentlicht das gesammelte Videomaterial weltweit. Benötigt ein lebendes Medien-Team.",
		"needs_air": false,
	},
	"donate": {
		"team": 1, "name": "Spendenaufruf", "cost": 0, "cd": 70.0, "radius": 0.0, "target": false, "icon": "coin",
		"desc": "Verwandelt Sympathie in Geld. Je größer die Empörung, desto mehr Spenden fließen.",
		"needs_air": false,
	},
}

## Empörungsstufen
const OUTRAGE_L1 := 35.0   # Sanktionen
const OUTRAGE_L2 := 65.0   # Flugverbotszone
const OUTRAGE_L3 := 100.0  # Intervention

## Schlagzeilen
const OUTLETS := ["WNN", "Tagesbote", "Al-Hadar Live", "Global Eye", "Meridian Post", "Open Wire"]

const HEADLINES_CIV_STRIKE := [
	"%d Tote nach Luftangriff in Qadira – Krankenhäuser überfüllt",
	"Videos zeigen zerstörtes Wohnhaus: Rettungskräfte suchen nach Überlebenden",
	"Entsetzen nach Angriff: %d Zivilisten unter den Opfern",
	"UN-Beobachter fordern Untersuchung nach Beschuss ziviler Gebäude",
	"Bilder aus Qadira gehen um die Welt: Staub, Trümmer, Trauer",
]
const HEADLINES_CIV_DIRECT := [
	"Soldaten feuern auf Zivilisten – Handyvideo löst Empörung aus",
	"Augenzeugen: Unbewaffnete bei Straßenkontrolle erschossen",
]
const HEADLINES_PRESS_KILLED := [
	"Reporter im Kreuzfeuer getötet – Pressefreiheitsverbände schlagen Alarm",
]
const HEADLINES_SENSITIVE := [
	"Klinik getroffen! Ärzte ohne Strom und Medikamente",
	"Schule in Trümmern: Das Entsetzen kennt keine Grenzen",
]
const HEADLINES_REBEL_ATTACK := [
	"Raketenbeschuss auf Stützpunkt – Aurelia kündigt Vergeltung an",
	"Hadar-Front feuert aus dicht besiedeltem Wohngebiet",
]
const HEADLINES_EVIDENCE := [
	"Armee veröffentlicht Luftaufnahmen: Raketenwerfer neben Wohnhäusern",
	"Beweise vorgelegt: Kämpfer operierten aus zivilen Gebäuden",
]
const HEADLINES_L1 := [
	"Verbündete verhängen Sanktionen – Haushalt der Streitkräfte wird gekürzt",
]
const HEADLINES_L2 := [
	"Sicherheitsrat beschließt Flugverbotszone – Luftunterstützung wird abgezogen",
]
const HEADLINES_L3 := [
	"Internationale Koalition greift ein – Aurelia militärisch isoliert",
]
const HEADLINES_VOLUNTEERS := [
	"Nach dem Angriff: Junge Männer schließen sich der Hadar-Front an",
	"Trauer wird zu Wut: Viertel in Qadira radikalisiert sich",
	"Familien verlieren Angehörige – die Front gewinnt Freiwillige",
]
const HEADLINES_AID := [
	"Hilfskonvoi erreicht Qadira: Wasser und Medikamente für das Viertel",
	"Aurelia liefert Hilfsgüter – Bewohner reagieren zurückhaltend dankbar",
]
const HEADLINES_AID_ATTACKED := [
	"Hadar-Front greift Hilfskonvoi an – Entsetzen in den Hauptstädten",
	"Beschuss auf Feldlazarett: Weltgemeinschaft verurteilt Hadar-Front",
]
const HEADLINES_HUB := [
	"Tunnelnetz der Hadar-Front schwer getroffen",
]
const HEADLINES_QUIET := [
	"Lage in Qadira bleibt angespannt",
	"Verbündete beobachten Einsatz mit wachsender Sorge",
	"Hadar-Front meldet sich über Telegram-Kanäle zu Wort",
	"Händler in Qadira schließen Läden – Menschen suchen Schutz",
	"Diplomaten: Hinter den Kulissen laufen Gespräche",
	"Aurelia: Einsatz richtet sich ausschließlich gegen Terrorstrukturen",
	"Hadar-Front: 'Der Widerstand lebt in jedem Haus'",
]
