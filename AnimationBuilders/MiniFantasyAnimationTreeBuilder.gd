@tool
extends EditorScript
class_name MiniFantasyAnimationTreeBuilder

func _run() -> void:
	var library = load("res://test-library.res")
	#create_animation_tree("druid", library)
	var tree = create_animation_tree("paladin", library)
	FileOps.save_node(tree)

const BLEND_POSITIONS = {
	"none": Vector2.ZERO,
	"up": Vector2(0, -1),
	"right": Vector2(1, 0),
	"down": Vector2(0, 0.9), # Slight offset to favor facing down(camera) while moving horizontally
	"left": Vector2(-1, 0),
	"upright": Vector2(1, -1),
	"downleft": Vector2(-1, 0.9), # Slight offset to maintain downward facing while moving horizontally
	"downright": Vector2(1, 0.9), # Slight offset to maintain downward facing while moving horizontally
	"upleft": Vector2(-1, -1),
}

# These actions are pretty uniform and expected, if we find them we'll link them up
const STANDARD_ACTIONS = {
	'attack': {'condition': 'is_attacking', 'is_blocking': true},
	'idle': {'condition': '!is_moving', 'is_blocking': false},
	'walk': {'condition': 'is_moving', 'is_blocking': false},
	'jump': {'condition': 'is_jumping', 'is_blocking': true},
	'dmg': {'condition': 'is_hurt', 'is_blocking': true},
	'die': {'condition': 'is_dead', 'is_blocking': false},
}

static func create_animation_tree(character: String, library: AnimationLibrary) -> AnimationTree:
	var tree = AnimationTree.new()
	print(library.get_animation_list())
	# Get all animations for the given character
	var character_anims = library.get_animation_list().filter(func(anim: String):
		# Ignore shadow, already worked into regular animations frames of AnimationPlayer
		var ignore = anim.containsn('shadow') or anim.containsn('glow') or anim.containsn('effect')
		return !ignore and anim.to_lower().begins_with(character)
	)

	# Keeping track of longest for spacing the nodes in the editor
	var longest_name = 0
	var anim_infos = {}
	# Construct info by extracting action names and directions to group them and build blendspace2ds
	for anim in character_anims:
		var info = MiniFantasySpritesheetClassifier.decipher_name(anim)
		var action = info['action']
		var anim_action_info: Array = anim_infos.get_or_add(action, [])
		anim_action_info.append(info)
		longest_name = max(action.length(), longest_name)
	
	# Track and place the nodes in two clusters, one for all the standardly connected ones, and an area with the rest left up to the user
	var standard_nodes_index = 0
	var other_nodes_index = 0
	# Loose approximation to space the nodes in the editor so they don't overlap names
	var node_width = longest_name * 18
	
	var state_machine = AnimationNodeStateMachine.new()
	state_machine.set_node_position('Start', Vector2(-100, -100))
	state_machine.set_node_position('End', Vector2(100, -100))
	# Programmatically build all states and assign their animations based on what directions they seem to support
	for action: String in anim_infos:
		# Check for multi-animation sets like foo-start, foo, foo-end. Which can also have directionality
		var like_actions = anim_infos[action]
		var main_anims = like_actions.filter(func(i): return !i['is_start'] and !i['is_end'])
		var leave_anims = like_actions.filter(func(i): return i['is_end'])
		var enter_anims = like_actions.filter(func(i): return i['is_start'])

		## Special case for idle, which can have activate/deactivate anims so we build a state machine instead of a single blendspace
		## This simplifies connecting transitions to it later
		if (action == 'idle') and anim_infos.keys().has('activate') and anim_infos.keys().has('deactivate'):
			var start_actions = anim_infos['activate']
			var idle_actions = anim_infos['idle'].filter(func(i): return !i['is_start'] and !i['is_end'])
			var end_actions = anim_infos['deactivate']
			var inner_machine = create_state_machine_box(start_actions, idle_actions, end_actions, 'is_moving or is_attacking or is_jumping')
			state_machine.add_node('idle', inner_machine)
		elif main_anims and leave_anims and enter_anims:
			var inner_machine = create_state_machine_box(enter_anims, main_anims, leave_anims, 'is_moving')
			state_machine.add_node(action, inner_machine)
		else:
			var new_node = create_blend_space()		
			place_points_in_blend(anim_infos[action], new_node)
			state_machine.add_node(action, new_node)
		
		# Place the nodes to not overlap in the AnimationTree editor
		if STANDARD_ACTIONS.has(action):
			var point = get_point_on_circle(standard_nodes_index, STANDARD_ACTIONS.keys().size())
			point += Vector2(0, 200)
			state_machine.set_node_position(action, point)
			standard_nodes_index += 1
		else:
			var x = 500 + (other_nodes_index % 3) * node_width
			var y = (floor(other_nodes_index / 3) * 75) - 100
			state_machine.set_node_position(action, Vector2(x, y))
			other_nodes_index += 1
	
	add_standard_transitions(state_machine, anim_infos)
	tree.tree_root = state_machine
	tree.name = "MiniFantasyAnimationTree"
	return tree
	

static func add_standard_transitions(state_machine: AnimationNodeStateMachine, anim_infos: Dictionary) -> void:
	var is_wrapped_idle = anim_infos.has('activate') and anim_infos.has('deactivate')
	## The AnimationTree is a graph, the actions are nodes, the transitions are edges
	## I'm building edges between all standard nodes except edges FROM "die"
	for action in STANDARD_ACTIONS:
		var condition = STANDARD_ACTIONS[action]['condition']
		if anim_infos.has(action):
			var attack_anim_info = anim_infos[action][0]
			var actions = anim_infos[action]
			var entity = attack_anim_info['entity']
			# If this character has this action, link Start->Action
			state_machine.add_transition("Start", action, create_immediate_transition(condition))
			# Death is terminal, no more transition building
			if action == 'die':
				continue
			# Check for other actions to build typical transitions from This->Those
			for target_action in STANDARD_ACTIONS:
				if target_action == action:
					# Don't link to itself
					continue
				if anim_infos.has(target_action):
					var target_condition = STANDARD_ACTIONS[target_action]['condition']
					var transition = create_at_end_transition(target_condition) if STANDARD_ACTIONS[action]['is_blocking'] else create_immediate_transition(target_condition)
					state_machine.add_transition(action, target_action, transition)

static func create_immediate_transition(condition: String, advance_mode: AnimationNodeStateMachineTransition.AdvanceMode = AnimationNodeStateMachineTransition.AdvanceMode.ADVANCE_MODE_AUTO) -> AnimationNodeStateMachineTransition:
	var transition = AnimationNodeStateMachineTransition.new()
	transition.advance_mode = advance_mode
	transition.advance_expression = condition
	return transition

static func create_at_end_transition(condition: String, switch_mode = AnimationNodeStateMachineTransition.SWITCH_MODE_AT_END, advance_mode: AnimationNodeStateMachineTransition.AdvanceMode = AnimationNodeStateMachineTransition.AdvanceMode.ADVANCE_MODE_AUTO) -> AnimationNodeStateMachineTransition:
	var transition = AnimationNodeStateMachineTransition.new()
	transition.advance_mode = advance_mode
	transition.switch_mode = switch_mode
	transition.advance_expression = condition
	transition.break_loop_at_end = true
	return transition

static func create_blend_space() -> AnimationNodeBlendSpace2D:
	var blend_space: AnimationNodeBlendSpace2D = AnimationNodeBlendSpace2D.new()
	# Set up standard blend space configuration
	blend_space.blend_mode = AnimationNodeBlendSpace2D.BLEND_MODE_DISCRETE
	blend_space.auto_triangles = true
	
	return blend_space

static func place_points_in_blend(actions: Array, space: AnimationNodeBlendSpace2D) -> void:
	for action in actions:
		var direction = action['direction']
		var point = AnimationNodeAnimation.new()
		point.animation = action['anim_name']
		space.add_blend_point(point, BLEND_POSITIONS[direction])

static func create_state_machine_box(enter_anims: Array, main_anims: Array, exit_anims: Array, exit_condition: String) -> AnimationNodeStateMachine:
	var inner_machine = AnimationNodeStateMachine.new()
	
	var transition_in_blend = create_blend_space()
	inner_machine.add_node("transition_in", transition_in_blend)
	inner_machine.set_node_position("transition_in", Vector2(300, 200))
	var main_blend = create_blend_space()
	inner_machine.add_node("main_animation", main_blend)
	inner_machine.set_node_position("main_animation", Vector2(500, 200))
	var transition_out_blend = create_blend_space()
	inner_machine.add_node("transition_out", transition_out_blend)
	inner_machine.set_node_position("transition_out", Vector2(700, 200))

	place_points_in_blend(enter_anims, transition_in_blend)
	place_points_in_blend(main_anims, main_blend)
	place_points_in_blend(exit_anims, transition_out_blend)

	inner_machine.add_transition('Start', 'transition_in', create_immediate_transition(''))
	inner_machine.add_transition('transition_in', 'main_animation', create_at_end_transition(''))
	inner_machine.add_transition('main_animation', 'transition_out', create_immediate_transition(exit_condition))
	inner_machine.add_transition('transition_out', 'End', create_at_end_transition(''))
	return inner_machine

static func get_point_on_circle(index: int, total_points: int, diameter: float = 500) -> Vector2:
	var angle = (TAU / total_points) * index
	var radius = diameter / 2
	return Vector2(cos(angle) * radius, sin(angle) * radius)
