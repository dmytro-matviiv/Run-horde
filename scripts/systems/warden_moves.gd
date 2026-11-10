extends RefCounted
class_name WardenMoves

## РУХИ КЛИНКОВОЇ ВАРТОВОЇ — п'ять ударів комбо й ривок, зібрані кодом
## (ProceduralAnims) від стійки з мечем (Idle_Sword). Як читати кути —
## див. ProceduralAnims. Меч у правій руці; у кинджалів друга рука теж б'є.
##
##   Combo_1 — косий удар згори з-за правого плеча навскіс донизу;
##   Combo_2 — зворотний удар знизу зліва вгору направо;
##   Combo_3 — широкий горизонтальний мах на рівні грудей;
##   Combo_4 — рука з клинком убік, присід (сам оберт робить гра — "spin");
##   Combo_5 — фініш: присід, стрибок і удар обома руками об землю;
##   Dash_Strike — ривок: клинок низько позаду, нахил уперед, у кінці — удар угору.

const SPECS := {
	"Combo_1": {"length": 0.6, "keys": {
		0.0: {},
		0.12: {"UpperArm.R": {"x": -120, "z": -45}, "LowerArm.R": {"x": -55}, "Chest": {"y": -32, "x": -6},
			"Abdomen": {"y": -10}, "UpperArm.L": {"x": -25, "z": 25}, "LowerArm.L": {"x": -35}},
		0.17: {"UpperArm.R": {"x": -115, "z": -40}, "LowerArm.R": {"x": -50}, "Chest": {"y": -30, "x": -5},
			"Abdomen": {"y": -10}, "UpperArm.L": {"x": -25, "z": 25}, "LowerArm.L": {"x": -35}},
		0.25: {"UpperArm.R": {"x": -55, "z": 30}, "LowerArm.R": {"x": -10}, "Chest": {"y": 32, "x": 14},
			"Abdomen": {"y": 12, "x": 5}, "UpperArm.L": {"x": 15, "z": 30}, "Hips": {"loc": Vector3(0, -0.04, 0.08)}},
		0.36: {"UpperArm.R": {"x": -45, "z": 35}, "LowerArm.R": {"x": -10}, "Chest": {"y": 30, "x": 12},
			"Abdomen": {"y": 10, "x": 5}, "UpperArm.L": {"x": 15, "z": 30}, "Hips": {"loc": Vector3(0, -0.04, 0.08)}},
		0.6: {"Hips": {"loc": Vector3.ZERO}},
	}},
	"Combo_2": {"length": 0.55, "keys": {
		0.0: {},
		0.1: {"UpperArm.R": {"x": -40, "z": 45}, "LowerArm.R": {"x": -40}, "Chest": {"y": 40, "x": 12},
			"Abdomen": {"y": 12}, "UpperArm.L": {"x": 20, "z": 20}, "Hips": {"loc": Vector3(0, -0.05, 0.0)}},
		0.15: {"UpperArm.R": {"x": -40, "z": 45}, "LowerArm.R": {"x": -40}, "Chest": {"y": 40, "x": 12},
			"Abdomen": {"y": 12}, "UpperArm.L": {"x": 20, "z": 20}, "Hips": {"loc": Vector3(0, -0.05, 0.0)}},
		0.23: {"UpperArm.R": {"x": -110, "z": -65}, "LowerArm.R": {"x": -10}, "Chest": {"y": -32, "x": -10},
			"Abdomen": {"y": -10}, "UpperArm.L": {"x": -20, "z": 30}, "Hips": {"loc": Vector3(0, 0.02, 0.08)}},
		0.33: {"UpperArm.R": {"x": -115, "z": -70}, "LowerArm.R": {"x": -10}, "Chest": {"y": -30, "x": -10},
			"Abdomen": {"y": -10}, "UpperArm.L": {"x": -20, "z": 30}, "Hips": {"loc": Vector3(0, 0.02, 0.08)}},
		0.55: {"Hips": {"loc": Vector3.ZERO}},
	}},
	"Combo_3": {"length": 0.6, "keys": {
		0.0: {},
		0.13: {"UpperArm.R": {"z": -80, "y": -45}, "LowerArm.R": {"x": -20}, "Chest": {"y": -45, "x": 5},
			"Abdomen": {"y": -15}, "UpperArm.L": {"x": -40, "z": 10}, "LowerArm.L": {"x": -40},
			"UpperLeg.R": {"x": 15}, "UpperLeg.L": {"x": -25}, "LowerLeg.L": {"x": 25}, "Hips": {"loc": Vector3(0, -0.06, -0.04)}},
		0.18: {"UpperArm.R": {"z": -80, "y": -50}, "LowerArm.R": {"x": -20}, "Chest": {"y": -48, "x": 5},
			"Abdomen": {"y": -15}, "UpperArm.L": {"x": -40, "z": 10}, "LowerArm.L": {"x": -40},
			"UpperLeg.R": {"x": 15}, "UpperLeg.L": {"x": -25}, "LowerLeg.L": {"x": 25}, "Hips": {"loc": Vector3(0, -0.06, -0.04)}},
		0.26: {"UpperArm.R": {"z": -80, "y": 85}, "LowerArm.R": {"x": -5}, "Chest": {"y": 45, "x": 10},
			"Abdomen": {"y": 15}, "UpperArm.L": {"z": 40}, "UpperLeg.R": {"x": -20}, "LowerLeg.R": {"x": 20},
			"UpperLeg.L": {"x": 15}, "Hips": {"loc": Vector3(0, -0.06, 0.12)}},
		0.38: {"UpperArm.R": {"z": -75, "y": 90}, "LowerArm.R": {"x": -5}, "Chest": {"y": 42, "x": 10},
			"Abdomen": {"y": 15}, "UpperArm.L": {"z": 40}, "UpperLeg.R": {"x": -20}, "LowerLeg.R": {"x": 20},
			"UpperLeg.L": {"x": 15}, "Hips": {"loc": Vector3(0, -0.05, 0.12)}},
		0.6: {"Hips": {"loc": Vector3.ZERO}},
	}},
	"Combo_4": {"length": 0.6, "keys": {
		0.0: {},
		0.1: {"UpperArm.R": {"z": -85}, "LowerArm.R": {"x": -5}, "Wrist.R": {"z": -75}, "UpperArm.L": {"z": 70}, "Chest": {"x": 12},
			"UpperLeg.L": {"x": -30}, "UpperLeg.R": {"x": -30}, "LowerLeg.L": {"x": 45}, "LowerLeg.R": {"x": 45},
			"Hips": {"loc": Vector3(0, -0.14, 0)}},
		0.42: {"UpperArm.R": {"z": -80}, "LowerArm.R": {"x": -5}, "Wrist.R": {"z": -75}, "UpperArm.L": {"z": 65}, "Chest": {"x": 10},
			"UpperLeg.L": {"x": -30}, "UpperLeg.R": {"x": -30}, "LowerLeg.L": {"x": 45}, "LowerLeg.R": {"x": 45},
			"Hips": {"loc": Vector3(0, -0.12, 0)}},
		0.6: {"Hips": {"loc": Vector3.ZERO}},
	}},
	"Combo_5": {"length": 0.95, "keys": {
		0.0: {},
		0.16: {"UpperArm.R": {"x": -150}, "LowerArm.R": {"x": -25}, "UpperArm.L": {"x": -145}, "LowerArm.L": {"x": -25},
			"Chest": {"x": -12}, "UpperLeg.L": {"x": -45}, "UpperLeg.R": {"x": -45}, "LowerLeg.L": {"x": 70},
			"LowerLeg.R": {"x": 70}, "Hips": {"loc": Vector3(0, -0.16, 0)}},
		0.32: {"UpperArm.R": {"x": -170}, "LowerArm.R": {"x": -15}, "UpperArm.L": {"x": -165}, "LowerArm.L": {"x": -15},
			"Chest": {"x": -20}, "UpperLeg.L": {"x": -60}, "UpperLeg.R": {"x": -20}, "LowerLeg.L": {"x": 90},
			"LowerLeg.R": {"x": 60}, "Hips": {"loc": Vector3(0, 0.45, 0.25)}},
		0.45: {"UpperArm.R": {"x": -40}, "LowerArm.R": {"x": -10}, "UpperArm.L": {"x": -45}, "LowerArm.L": {"x": -10},
			"Chest": {"x": 18}, "Abdomen": {"x": 6}, "UpperLeg.L": {"x": -55}, "LowerLeg.L": {"x": 65},
			"UpperLeg.R": {"x": 15}, "LowerLeg.R": {"x": 60}, "Hips": {"loc": Vector3(0, -0.14, 0.45)}},
		0.65: {"UpperArm.R": {"x": -38}, "LowerArm.R": {"x": -10}, "UpperArm.L": {"x": -42}, "LowerArm.L": {"x": -10},
			"Chest": {"x": 16}, "Abdomen": {"x": 6}, "UpperLeg.L": {"x": -55}, "LowerLeg.L": {"x": 65},
			"UpperLeg.R": {"x": 15}, "LowerLeg.R": {"x": 60}, "Hips": {"loc": Vector3(0, -0.14, 0.45)}},
		0.95: {"Hips": {"loc": Vector3.ZERO}},
	}},
	"Dash_Strike": {"length": 0.7, "keys": {
		0.0: {},
		0.08: {"UpperArm.R": {"x": 35, "z": -30}, "LowerArm.R": {"x": -20}, "UpperArm.L": {"x": -50}, "Chest": {"x": 14},
			"Abdomen": {"x": 5}, "Hips": {"loc": Vector3(0, -0.08, 0)}},
		0.4: {"UpperArm.R": {"x": 40, "z": -30}, "LowerArm.R": {"x": -20}, "UpperArm.L": {"x": -55}, "Chest": {"x": 15},
			"Abdomen": {"x": 5}, "Hips": {"loc": Vector3(0, -0.08, 0)}},
		0.48: {"UpperArm.R": {"x": -135, "z": -35}, "LowerArm.R": {"x": -10}, "UpperArm.L": {"x": 20, "z": 25},
			"Chest": {"x": -14, "y": -20}, "Hips": {"loc": Vector3(0, 0.05, 0.1)}},
		0.7: {"Hips": {"loc": Vector3.ZERO}},
	}},
}
