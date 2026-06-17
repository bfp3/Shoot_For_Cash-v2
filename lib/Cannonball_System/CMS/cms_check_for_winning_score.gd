extends Node

#this script will check if the player has reached 801 points, and if so, then 
#it will destroy all balls, and notify the pineapple launchers

@onready var cms: CMS = $".."

var points_threshold : int = 0
var t := 0.0

func _ready() -> void:
	points_threshold = ScoreGl.winning_score - (ScoreGl.winning_score / 10)
	set_process(false)

func start_checking_for_score() -> void:
	
	if GameManager.current_score_displayed >= points_threshold:
		if GameManager.current_score_displayed >= ScoreGl.winning_score:
			winning_score_has_been_reached()
		set_process(true)
		return
	else:
		return

func _process(delta: float) -> void:
	t += delta
	if t >= 0.35:
		t = 0.0
		check_if_score_has_been_beaten()

func check_if_score_has_been_beaten() -> void:
	#if GameManager.current_score_displayed >= ScoreGl.winning_score && cms.active_cannonballs == 0:
	if GameManager.current_score_not_displayed >= ScoreGl.winning_score:
		winning_score_has_been_reached()
		set_process(false)
		

func winning_score_has_been_reached() -> void:
	if GameManager.player_has_winning_score:
		return
	EventBus.instance.player_has_hit_winning_score.emit() # This connects to the GameManager
	GameManager.player_has_winning_score = true
	#cms._on_player_won()
