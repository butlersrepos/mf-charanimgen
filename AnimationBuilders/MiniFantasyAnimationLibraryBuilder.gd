@tool
extends EditorScript
class_name MiniFantasyAnimationLibraryBuilder

var path_to_sprite_frames: String = "res://mini-fantasy-sprite-frames.res"
var mini_fantasy_animated_sprite_name: String = "MiniFantasyAnimatedSprite2D"

const frame_interval = 0.1 # 100ms?

func _run() -> void:
	var library = create_anim_library("paladin", load(path_to_sprite_frames), AnimatedSprite2D.new(), AnimatedSprite2D.new(), AnimatedSprite2D.new(), AnimationPlayer.new())
	FileOps.save_res(library, "res://test-library.res")

static func create_anim_library(character: String, sprite_frames: SpriteFrames, base_sprite: AnimatedSprite2D, shadow_sprite: AnimatedSprite2D, effects_sprite: AnimatedSprite2D, hitbox_player: AnimationPlayer) -> AnimationLibrary:
	var library = AnimationLibrary.new()
	var hitbox_library = AnimationLibrary.new()
	
	var char_frames = Array(sprite_frames.get_animation_names()).filter(func(a: String):
		return a.to_lower().begins_with(character)
	)
	var set_defaults = false
	for anim_name in char_frames:
		if String(anim_name).containsn('die') and not set_defaults:
			base_sprite.animation = anim_name
			effects_sprite.animation = anim_name
			hitbox_player.current_animation = anim_name
			set_defaults = true
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
			animation.track_insert_key(frames_track, i * frame_interval, i)
		
		# We'll add the shadow if we found one
		build_shadow_sprite(anim_name, animation, shadow_sprite, sprite_frames)
		build_effects_sprite(anim_name, animation, effects_sprite, sprite_frames)
		
		# Set animation properties
		animation.length = frame_count * frame_interval
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
		
		# Add to library
		library.add_animation(anim_name, animation)
		if !library.has_animation('RESET') and anim_name.containsn('idle') and anim_name.containsn('down'):
			library.add_animation('RESET', animation)
	
	hitbox_player.add_animation_library("", hitbox_library)
	return library

static func build_support_sprite(anim_name: String, animation: Animation, sprite: AnimatedSprite2D, sprite_frames: SpriteFrames, parent_frame_count: int):
	if sprite_frames.has_animation(anim_name):
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
		animation.track_insert_key(sprite_visibility_track, parent_frame_count * frame_interval, true)

static func build_effects_sprite(anim_name: String, animation: Animation, sprite: AnimatedSprite2D, sprite_frames: SpriteFrames):
	var parent_anim_frame_count = sprite_frames.get_frame_count(anim_name)
	var glow_anim_name = anim_name + '-glow';
	var effect_anim_name = anim_name + '-effect'
	var effect_anim = glow_anim_name if sprite_frames.has_animation(glow_anim_name) else effect_anim_name if sprite_frames.has_animation(effect_anim_name) else null
	# Build regardless of existence since the builder also handles non-existence by hiding the sprite
	build_support_sprite(effect_anim, animation, sprite, sprite_frames, parent_anim_frame_count)

static func build_shadow_sprite(anim_name: String, animation: Animation, sprite: AnimatedSprite2D, sprite_frames: SpriteFrames):
	var parent_anim_frame_count = sprite_frames.get_frame_count(anim_name)
	var shadow_anim_name = anim_name + "-shadow"
	# Build regardless of existence since the builder also handles non-existence by hiding the sprite
	build_support_sprite(shadow_anim_name, animation, sprite, sprite_frames, parent_anim_frame_count)
