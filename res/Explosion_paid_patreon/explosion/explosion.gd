extends Node3D

func set_one_shot():
	hide()
	$upward_smoke.set_one_shot(true)
	$upward_smoke_glow.set_one_shot(true)
	$radial_smoke.set_one_shot(true)
	$radial_smoke_glow.set_one_shot(true)
	$ground_ring.set_one_shot(true)
	$upper_ring.set_one_shot(true)
	$ground_decal.set_one_shot(true)
	$spikes.set_one_shot(true);
	$embers.set_one_shot(true);

func play():
	show()
	$upward_smoke.restart()
	$upward_smoke_glow.restart()
	$radial_smoke.restart()
	$radial_smoke_glow.restart()
	$ground_ring.restart()
	$upper_ring.restart()
	$ground_decal.restart()
	$spikes.restart()
	$embers.restart()
