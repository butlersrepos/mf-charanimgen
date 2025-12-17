@tool
extends EditorScript
class_name MiniFantasyAnimationLibraryBuilder

"""
Builds the AnimationPlayers' Animation Library resources and attaches them to the appropriate AnimatedSprites.
"""

var path_to_sprite_frames: String = "res://mini-fantasy-sprite-frames.res"
var mini_fantasy_animated_sprite_name: String = "MiniFantasyAnimatedSprite2D"

const default_frame_interval_ms = 100 # 100ms

func _run() -> void:
	var library = create_anim_library("paladin", load(path_to_sprite_frames), AnimatedSprite2D.new(), AnimatedSprite2D.new(), AnimatedSprite2D.new(), AnimationPlayer.new(), {})
	FileOps.save_res(library, "res://test-library.res")

static func create_anim_library(character: String, sprite_frames: SpriteFrames,
		base_sprite: AnimatedSprite2D,
		shadow_sprite: AnimatedSprite2D,
		effects_sprite: AnimatedSprite2D,
		hitbox_player: AnimationPlayer,
		anim_metadata: Dictionary) -> AnimationLibrary:
	var library = AnimationLibrary.new()
	var hitbox_library = AnimationLibrary.new()

	var char_frames = Array(sprite_frames.get_animation_names()).filter(func(a: String):
		return a.to_lower().begins_with(character)
	)
	var has_set_default_anim = false
	for anim_name in char_frames:
		if String(anim_name).containsn('die') and not has_set_default_anim:
			base_sprite.animation = anim_name
			effects_sprite.animation = anim_name
			hitbox_player.current_animation = anim_name
			has_set_default_anim = true

		# Collect high-level info about this animation
		var details = MiniFantasySpritesheetClassifier.decipher_name(anim_name)
		# Action is like "attack", "idle", "walk", "die"
		var this_action = details.get('action', '') as String
		# Intervals are stores as milliseconds, here we convert to seconds
		var frame_interval_in_s = safely_access(anim_metadata, 'frame_intervals.%s' % [this_action], default_frame_interval_ms) / 1000.0
		var frame_count = sprite_frames.get_frame_count(anim_name)
		var animation = Animation.new()

		# Setup the first track to set the current animation of the sprite immediately, like "troll-idle-downleft"
		var anim_name_track = animation.add_track(Animation.TYPE_VALUE)
		animation.value_track_set_update_mode(anim_name_track, Animation.UPDATE_DISCRETE)
		animation.track_set_path(anim_name_track, "%s:animation" % [base_sprite.name])
		animation.track_insert_key(anim_name_track, 0, anim_name)
		# Setup the second track to iterate through the frames until they're done
		var frames_track = animation.add_track(Animation.TYPE_VALUE)
		animation.value_track_set_update_mode(frames_track, Animation.UPDATE_DISCRETE)
		animation.track_set_path(frames_track, "%s:frame" % [base_sprite.name])
		for i in frame_count:
			animation.track_insert_key(frames_track, i * frame_interval_in_s, i)

		# We'll add the shadow & effect if we found one
		build_shadow_sprite(anim_name, animation, shadow_sprite, sprite_frames, frame_interval_in_s)
		build_effects_sprite(anim_name, animation, effects_sprite, sprite_frames, frame_interval_in_s)

		# Set animation properties
		animation.length = frame_count * frame_interval_in_s
		animation.loop_mode = Animation.LOOP_LINEAR if sprite_frames.get_animation_loop(anim_name) else Animation.LOOP_NONE

		# Setup the last track to execute the hitbox player's track by the same name
		var hitbox_track = animation.add_track(Animation.TYPE_ANIMATION)
		animation.track_set_path(hitbox_track, "%s" % [hitbox_player.name])
		animation.animation_track_insert_key(hitbox_track, 0, anim_name)
		animation.animation_track_set_key_animation(hitbox_track, 0, anim_name)


		# Copy the track length and name into the HitBoxPlayer so it's easy to sync up and add hits
		var hitbox_anim = Animation.new()
		hitbox_anim.length = animation.length
		hitbox_anim.loop_mode = animation.loop_mode
		hitbox_library.add_animation(anim_name, hitbox_anim)

		# Create track for hitbox even if we don't have any auto-populated
		var hitbox_position_track = hitbox_anim.add_track(Animation.TYPE_VALUE)
		hitbox_anim.value_track_set_update_mode(hitbox_position_track, Animation.UPDATE_DISCRETE)
		hitbox_anim.track_set_path(hitbox_position_track, 'HitBox:position')
		hitbox_anim.track_insert_key(hitbox_position_track, 0, Vector2(0,0))
		var hitbox_rotation_track = hitbox_anim.add_track(Animation.TYPE_VALUE)
		hitbox_anim.value_track_set_update_mode(hitbox_rotation_track, Animation.UPDATE_DISCRETE)
		hitbox_anim.track_set_path(hitbox_rotation_track, 'HitBox:rotation')
		hitbox_anim.track_insert_key(hitbox_rotation_track, 0, 0.0)
		var hurtbox_position_track = hitbox_anim.add_track(Animation.TYPE_VALUE)
		hitbox_anim.value_track_set_update_mode(hurtbox_position_track, Animation.UPDATE_DISCRETE)
		hitbox_anim.track_set_path(hurtbox_position_track, 'HurtBox:position')
		hitbox_anim.track_insert_key(hurtbox_position_track, 0, Vector2(0,0))
		var hurtbox_rotation_track = hitbox_anim.add_track(Animation.TYPE_VALUE)
		hitbox_anim.value_track_set_update_mode(hurtbox_rotation_track, Animation.UPDATE_DISCRETE)
		hitbox_anim.track_set_path(hurtbox_rotation_track, 'HurtBox:rotation')
		hitbox_anim.track_insert_key(hurtbox_rotation_track, 0, 0.0)

		if this_action.containsn('attack'):
			# All attacks should start with no active hitbox detection
			var hitbox_monitoring_track = hitbox_anim.add_track(Animation.TYPE_VALUE)
			hitbox_anim.track_set_path(hitbox_monitoring_track, 'HitBox:monitoring')
			hitbox_anim.track_insert_key(hitbox_monitoring_track, 0.0, false)
			# All attacks should end by deactivating the detection
			hitbox_anim.track_insert_key(hitbox_monitoring_track, frame_count * frame_interval_in_s, false)
			# Set up hitbox activation based on metadata
			var all_hit_frames: Array = safely_access(anim_metadata, 'hit_frames.attack', [])
			var this_attack_hits_on: Array = safely_access(anim_metadata, 'hit_frames.%s' % [this_action], [])
			var combined_hit_frames = all_hit_frames + this_attack_hits_on
			myprint('Found hit frames: ' + ','.join(combined_hit_frames) + ' for action: ' + this_action)
			var has_added_strike_call = false
			for frame_num in combined_hit_frames:
				# Check for hits starting at each configured HIT FRAME
				var start_frame_time = frame_num * frame_interval_in_s
				hitbox_anim.track_insert_key(hitbox_monitoring_track, start_frame_time, true)
				if not has_added_strike_call:
					# Adds our custom event communication for "do hit logic here" to the hit frame
					var animation_event_track = hitbox_anim.add_track(Animation.TYPE_METHOD)
					hitbox_anim.track_set_path(animation_event_track, 'Components/AnimationComponent')
					hitbox_anim.track_insert_key(animation_event_track, start_frame_time, {"method":'_on_animation_event', "args": [["strike"]]})
					hitbox_anim.track_insert_key(animation_event_track, frame_count * frame_interval_in_s, {"method":'_on_animation_event', "args": [["done"]]})
					has_added_strike_call = true
				# Turn detection off on the next frame
				# If there are two back-to-back hits then the second hit will overwrite this, creating the desired 2-consecutive frames of detection
				var end_frame_time = (frame_num + 1) * frame_interval_in_s
				hitbox_anim.track_insert_key(hitbox_monitoring_track, end_frame_time, false)

		# Add to library
		library.add_animation(anim_name, animation)
		if !library.has_animation('RESET') and anim_name.containsn('idle') and anim_name.containsn('down'):
			# If there's a foo-idle-downleft animation, make that the RESET
			library.add_animation('RESET', animation)

	hitbox_player.add_animation_library("", hitbox_library)
	return library

## Builds a track to sync shadow or effects sprite, but only if we find a similarly named SpriteFrames to support it.
static func build_support_sprite(anim_name: Variant, animation: Animation, sprite: AnimatedSprite2D, sprite_frames: SpriteFrames, parent_frame_count: int, frame_interval: float):
	const ANTI_FLICKER_ADJUSTMENT = 0.01
	if anim_name is String and sprite_frames.has_animation(anim_name):
		var support_anim_frame_count = sprite_frames.get_frame_count(anim_name)
		# Setup third track to ensure the sprite is visible
		var sprite_visibility_track = animation.add_track(Animation.TYPE_VALUE)
		animation.value_track_set_update_mode(sprite_visibility_track, Animation.UPDATE_DISCRETE)
		animation.track_set_path(sprite_visibility_track, "%s:visible" % [sprite.name])
		animation.track_insert_key(sprite_visibility_track, 0, true)
		animation.track_insert_key(sprite_visibility_track, parent_frame_count * frame_interval, false)
		# Setup the fourth track to set the current animation of the sprite immediately, like "troll-idle-downleft-shadow"
		var animation_name_track = animation.add_track(Animation.TYPE_VALUE)
		animation.value_track_set_update_mode(animation_name_track, Animation.UPDATE_DISCRETE)
		animation.track_set_path(animation_name_track, "%s:animation" % [sprite.name])
		animation.track_insert_key(animation_name_track, 0, anim_name)
		# Setup the fifth track to iterate through the frames until they're done
		var animation_frame_count_track = animation.add_track(Animation.TYPE_VALUE)
		animation.value_track_set_update_mode(animation_frame_count_track, Animation.UPDATE_DISCRETE)
		animation.track_set_path(animation_frame_count_track, "%s:frame" % [sprite.name])
		for i in support_anim_frame_count:
			animation.track_insert_key(animation_frame_count_track, i * frame_interval, i)
	else:
		# If there's no animation then hide the sprite to avoid default sprites showing conspicuously
		var sprite_visibility_track = animation.add_track(Animation.TYPE_VALUE)
		animation.value_track_set_update_mode(sprite_visibility_track, Animation.UPDATE_DISCRETE)
		animation.track_set_path(sprite_visibility_track, "%s:visible" % [sprite.name])
		animation.track_insert_key(sprite_visibility_track, 0, false)
		animation.track_insert_key(sprite_visibility_track, (parent_frame_count * frame_interval) + ANTI_FLICKER_ADJUSTMENT, true)

static func build_effects_sprite(anim_name: String, animation: Animation, sprite: AnimatedSprite2D, sprite_frames: SpriteFrames, frame_interval: float):
	var parent_anim_frame_count = sprite_frames.get_frame_count(anim_name)
	var glow_anim_name = anim_name + '-glow';
	var effect_anim_name = anim_name + '-effect'
	var effect_anim = glow_anim_name if sprite_frames.has_animation(glow_anim_name) else effect_anim_name if sprite_frames.has_animation(effect_anim_name) else null
	
	# If no standard effect found, check for front/back attack effect variants.
	# Some spritesheets use separate "attackf" (front) and "attackb" (back) effects
	# for more depth - we use front for down-facing, back for up-facing animations.
	# e.g. "zombie_bear-attack-downleft" -> "zombie_bear-attackf-downleft-effect"
	if effect_anim == null and anim_name.containsn('attack'):
		var is_up_direction = anim_name.containsn('up')
		# Replace "-attack-" with "-attackb-" or "-attackf-" based on direction
		var variant_suffix = 'b' if is_up_direction else 'f'
		var variant_base = anim_name.replace('-attack-', '-attack%s-' % variant_suffix)
		var variant_glow_name = variant_base + '-glow'
		var variant_effect_name = variant_base + '-effect'
		effect_anim = variant_glow_name if sprite_frames.has_animation(variant_glow_name) else variant_effect_name if sprite_frames.has_animation(variant_effect_name) else null
	
	# Build regardless of existence since the builder also handles non-existence by hiding the sprite
	build_support_sprite(effect_anim, animation, sprite, sprite_frames, parent_anim_frame_count, frame_interval)

static func build_shadow_sprite(anim_name: String, animation: Animation, sprite: AnimatedSprite2D, sprite_frames: SpriteFrames, frame_interval: float):
	var parent_anim_frame_count = sprite_frames.get_frame_count(anim_name)
	var shadow_anim_name = anim_name + "-shadow"
	# Build regardless of existence since the builder also handles non-existence by hiding the sprite
	build_support_sprite(shadow_anim_name, animation, sprite, sprite_frames, parent_anim_frame_count, frame_interval)

## Used to drill into a Dictionary to retrieve nested fields without manually checking each field along the way.
static func safely_access(dict: Dictionary, path: String, default_return: Variant = null) -> Variant:
	var keys: PackedStringArray = path.split('.')
	var current = dict
	for idx in range(keys.size()):
		var key: String = keys[idx]
		# If this is the last segment we wanted, i.e. Z in x.y.z, then default to the supplied default, if we aren't at the end then supply an empty Dictionary
		var default = default_return if idx + 1 == keys.size() else {}
		current = current.get(key, default)
	return current

# Helper to colorcode all logs in this file
static func myprint(msg: Variant) -> void:
	var call_info: Dictionary = get_stack()[1]
	var marker = '[color=green]%s:%s[/color] ' % ['MiniFantasyAnimationLibraryBuilder', call_info.get('line')]
	print_rich(marker, msg)
