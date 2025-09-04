class_name CrewData extends Resource

var first_names: Array[String] = [
	"Marie",
	"Jeanne",
	"Marguerite",
	"Madeleine",
	"Yvonne",
	"Suzanne",
	"Renée",
	"Germaine",
	"Lucienne",
	"Hélène",
	"Gertrud",
	"Hildegard",
	"Irmgard",
	"Frieda",
	"Lieselotte",
	"Margarete",
	"Elisabeth",
	"Anneliese",
	"Käthe",
	"Herta",
]

var last_names: Array[String] = [
	"Dubois",
	"Lefèvre",
	"Laurent",
	"Moreau",
	"Fontaine",
	"Boucher",
	"Chevalier",
	"Durand",
	"Giraud",
	"Martin",
	"Müller",
	"Schmidt",
	"Schneider",
	"Fischer",
	"Weber",
	"Wagner",
	"Becker",
	"Hoffmann",
	"Schäfer",
	"Braun",
]


var id: int
var name: String
var age: int
var hometown: String

# Variable stats (0–10, coarse scale)
var vigour: int
var appetite: int
var contentment: int

# Fixed personality traits (1920s-flavored, booleans)
var is_industrious: bool
var is_amiable: bool
var is_meticulous: bool
var is_plucky: bool

func _init() -> void:
	id = Global.station.crew.size() + 1
	name = generate_name()
	age = randi_range(18, 65)
	hometown = "New Ilion, Ganymede"
	# Defaults on 0–10 scale
	vigour = 10
	appetite = 0
	contentment = 6
	# Randomize personalities 50/50
	is_industrious = (randi() % 2) == 0
	is_amiable = (randi() % 2) == 0
	is_meticulous = (randi() % 2) == 0
	is_plucky = (randi() % 2) == 0
	

func generate_name() -> String:
	var first = first_names[randi_range(0, len(first_names) - 1)]
	var last = last_names[randi_range(0, len(last_names) - 1)]
	return "%s %s" % [first, last]
