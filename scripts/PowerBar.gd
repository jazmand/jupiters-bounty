extends TextureProgressBar


# Called when the node enters the scene tree for the first time.
func _ready():
	self.value = 0;
	var tween = get_tree().create_tween();
	tween.tween_property(self, "value", 100, 2).set_trans(Tween.TRANS_LINEAR);


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
