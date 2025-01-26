@tool
class_name MiniFantasyAnimationTreeBuilder

const ORTHOGONAL_BLEND_POSITIONS = {
	"up": Vector2(0, -1),
	"right": Vector2(1, 0),
	"down": Vector2(0, 0.9), # Slight offset to favor facing down(camera) while moving horizontally
	"left": Vector2(-1, 0),
}

const DIAGONAL_BLEND_POSITIONS = {
	"upright": Vector2(1, -1),
	"downleft": Vector2(-1, 0.9), # Slight offset to maintain downward facing while moving horizontally
	"downright": Vector2(1, 0.9),
	"upleft": Vector2(-1, -1),
}

static func create_animation_tree(character: String) -> AnimationTree:
	var tree = AnimationTree.new()
	
	var state_machine = AnimationNodeStateMachine.new()
	var idle_blend = create_blend_space(character, "idle")
	var walk_blend = create_blend_space(character, "walk")
	var attack_blend = create_blend_space(character, "attack")
	var die_state = AnimationNodeAnimation.new()
	die_state.animation = "%s-die" % [character]
	
	state_machine.add_node("Idles", idle_blend)
	state_machine.add_node("Walks", walk_blend)
	state_machine.add_node("Attacks", attack_blend)
	state_machine.add_node("Dies", die_state)
	
	add_standard_transitions(state_machine)
	tree.tree_root = state_machine
	tree.name = "MiniFantasyAnimationTree"
	return tree

static func create_blend_space(character: String, action: String) -> AnimationNodeBlendSpace2D:
	var blend_space: AnimationNodeBlendSpace2D = AnimationNodeBlendSpace2D.new()
	
	# Set up standard blend space configuration
	blend_space.blend_mode = AnimationNodeBlendSpace2D.BLEND_MODE_DISCRETE
	blend_space.auto_triangles = true
	
	# Add standard points
	for direction in DIAGONAL_BLEND_POSITIONS:
		var pos = DIAGONAL_BLEND_POSITIONS[direction]
		var animation_name = "%s-%s-%s" % [character, action, direction]
		var point = AnimationNodeAnimation.new()
		point.animation = animation_name
		blend_space.add_blend_point(point, pos)
	
	return blend_space

static func add_standard_transitions(state_machine: AnimationNodeStateMachine) -> void:
	# Idle -> Walk
	var idle_to_walk = AnimationNodeStateMachineTransition.new()
	idle_to_walk.advance_mode = AnimationNodeStateMachineTransition.ADVANCE_MODE_AUTO
	idle_to_walk.advance_expression = "is_moving"
	state_machine.add_transition("Idles", "Walks", idle_to_walk)
	
	# Walk -> Idle
	var walk_to_idle = AnimationNodeStateMachineTransition.new()
	walk_to_idle.advance_mode = AnimationNodeStateMachineTransition.ADVANCE_MODE_AUTO
	walk_to_idle.advance_expression = "!is_moving"
	state_machine.add_transition("Walks", "Idles", walk_to_idle)
	
	# Idle -> Attack
	var idle_to_attack = AnimationNodeStateMachineTransition.new()
	idle_to_attack.advance_mode = AnimationNodeStateMachineTransition.ADVANCE_MODE_AUTO
	idle_to_attack.advance_expression = "is_attacking"
	state_machine.add_transition("Idles", "Attacks", idle_to_attack)
	
	# Attack -> Idle
	var attack_to_idle = AnimationNodeStateMachineTransition.new()
	attack_to_idle.advance_mode = AnimationNodeStateMachineTransition.ADVANCE_MODE_AUTO
	attack_to_idle.switch_mode = AnimationNodeStateMachineTransition.SWITCH_MODE_AT_END
	attack_to_idle.advance_expression = "!is_attacking"
	attack_to_idle.break_loop_at_end = true
	state_machine.add_transition("Attacks", "Idles", attack_to_idle)
	
	# Walk -> Attack
	var walk_to_attack = AnimationNodeStateMachineTransition.new()
	walk_to_attack.advance_mode = AnimationNodeStateMachineTransition.ADVANCE_MODE_AUTO
	walk_to_attack.advance_expression = "is_attacking"
	state_machine.add_transition("Walks", "Attacks", walk_to_attack)
	
	# Attack -> Walks
	var attack_to_walk = AnimationNodeStateMachineTransition.new()
	attack_to_walk.advance_mode = AnimationNodeStateMachineTransition.ADVANCE_MODE_AUTO
	attack_to_walk.switch_mode = AnimationNodeStateMachineTransition.SWITCH_MODE_AT_END
	attack_to_walk.advance_expression = "!is_attacking and is_moving"
	attack_to_walk.break_loop_at_end = true
	state_machine.add_transition("Attacks", "Walks", attack_to_walk)
	
	# Idle -> Dead
	var idle_to_dead = AnimationNodeStateMachineTransition.new()
	idle_to_dead.advance_mode = AnimationNodeStateMachineTransition.ADVANCE_MODE_AUTO
	idle_to_dead.advance_expression = "is_dead"
	state_machine.add_transition("Idles", "Dies", idle_to_dead)
	
	# Walk -> Dead
	var walk_to_dead = AnimationNodeStateMachineTransition.new()
	walk_to_dead.advance_mode = AnimationNodeStateMachineTransition.ADVANCE_MODE_AUTO
	walk_to_dead.advance_expression = "is_dead"
	state_machine.add_transition("Walks", "Dies", walk_to_dead)

	var attack_to_dead = AnimationNodeStateMachineTransition.new()
	attack_to_dead.advance_mode = AnimationNodeStateMachineTransition.ADVANCE_MODE_AUTO
	attack_to_dead.advance_expression = "is_dead"
	state_machine.add_transition("Attacks", "Dies", attack_to_dead)
	
	var start_to_idle = AnimationNodeStateMachineTransition.new()
	start_to_idle.advance_mode = AnimationNodeStateMachineTransition.ADVANCE_MODE_AUTO
	start_to_idle.advance_expression = "!is_moving"
	state_machine.add_transition("Start", "Idles", start_to_idle)
	
	var start_to_walk = AnimationNodeStateMachineTransition.new()
	start_to_walk.advance_mode = AnimationNodeStateMachineTransition.ADVANCE_MODE_AUTO
	start_to_walk.advance_expression = "is_moving"
	state_machine.add_transition("Start", "Walks", start_to_walk)
	
	var start_to_attack = AnimationNodeStateMachineTransition.new()
	start_to_attack.advance_mode = AnimationNodeStateMachineTransition.ADVANCE_MODE_AUTO
	start_to_attack.advance_expression = "is_attacking"
	state_machine.add_transition("Start", "Attacks", start_to_attack)
	
	var start_to_die = AnimationNodeStateMachineTransition.new()
	start_to_die.advance_mode = AnimationNodeStateMachineTransition.ADVANCE_MODE_AUTO
	start_to_die.advance_expression = "is_dead"
	state_machine.add_transition("Start", "Dies", start_to_die)
