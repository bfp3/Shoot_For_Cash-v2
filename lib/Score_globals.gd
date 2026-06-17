extends Node

var winning_score := 801


# Bomb types
var red_dots := 0 #2
var grey_dots_astray := 0#1
var grey_dots := 0 #5
var smokescreen_rounds := 0 #1 #10
var disguised_red_dots := 0 #5
var special_bonus_bomb := 0 #9 #winning_score / 10

# Score Multiplier
var score_multiplier := 0
var total_ammo := 12

var PINEAPPLES_AMOUNT_TO_COMPLETE : int = 10
var MAX_PINEAPPLES_PER_ROUND : int = 3
