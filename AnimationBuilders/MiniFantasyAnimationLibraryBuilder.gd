@tool
extends EditorScript
class_name MiniFantasyAnimationLibraryBuilder

var path_to_sprite_frames: String = "res://mini-fantasy-sprite-frames.res"
var mini_fantasy_animated_sprite_name: String = "MiniFantasyAnimatedSprite2D"

func _run() -> void:
	var library = create_anim_library("paladin", load(path_to_sprite_frames), AnimatedSprite2D.new(), AnimatedSprite2D.new(), AnimationPlayer.new())
	FileOps.save_res(library, "res://test-library.res")

static func create_anim_library(character: String, sprite_frames: SpriteFrames, base_sprite: AnimatedSprite2D, effects_sprite: AnimatedSprite2D, hitbox_player: AnimationPlayer) -> AnimationLibrary:
	var library = AnimationLibrary.new()
	
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
		var frame_interval = 0.2 # 200ms?
		for i in frame_count:
			animation.track_insert_key(frames_track, i * frame_interval, i)
		
		# We'll add the shadow/glow if we found one
		var shadow_anim = anim_name + "-shadow"
		var glow_anim = anim_name + '-glow';
		if sprite_frames.has_animation(shadow_anim) or sprite_frames.has_animation(glow_anim):
			var effect_anim = shadow_anim if sprite_frames.has_animation(shadow_anim) else glow_anim
			var effect_frames = sprite_frames.get_frame_count(effect_anim)
			# Setup the third track to set the current animation of the shadow sprite immediately, like "troll-idle-downleft-shadow"
			var effect_anim_track = animation.add_track(Animation.TYPE_VALUE)
			animation.value_track_set_update_mode(effect_anim_track, Animation.UPDATE_DISCRETE)
			animation.track_set_path(effect_anim_track, "%s:animation" % [effects_sprite.name])
			animation.track_insert_key(effect_anim_track, 0, effect_anim)
			# Setup the fourth track to iterate through the shadow frames until they're done
			var effect_frames_track = animation.add_track(Animation.TYPE_VALUE)
			animation.value_track_set_update_mode(effect_frames_track, Animation.UPDATE_DISCRETE)
			animation.track_set_path(effect_frames_track, "%s:frame" % [effects_sprite.name])
			for i in effect_frames:
				animation.track_insert_key(effect_frames_track, i * frame_interval, i)
		else:
			# If there's no shadow then hide the shadow sprite to avoid default sprites showing conspicuously
			var effect_anim_track = animation.add_track(Animation.TYPE_VALUE)
			animation.value_track_set_update_mode(effect_anim_track, Animation.UPDATE_DISCRETE)
			animation.track_set_path(effect_anim_track, "%s:visible" % [effects_sprite.name])
			animation.track_insert_key(effect_anim_track, 0, false)
			animation.track_insert_key(effect_anim_track, frame_count * frame_interval,true)
		# Set animation properties
		animation.length = frame_count * frame_interval
		animation.loop_mode = Animation.LOOP_LINEAR if sprite_frames.get_animation_loop(anim_name) else Animation.LOOP_NONE
		
		# Setup the fifth track to execute the hitbox player's track by the same name
		var hitbox_track = animation.add_track(Animation.TYPE_ANIMATION)
		animation.track_set_path(hitbox_track, "%s" % [hitbox_player.name])
		animation.animation_track_insert_key(hitbox_track, 0, anim_name)
		animation.animation_track_set_key_animation(hitbox_track, 0, anim_name)
		
		# Add to library
		library.add_animation(anim_name, animation)
		if !library.has_animation('RESET') and anim_name.containsn('idle') and anim_name.containsn('down'):
			library.add_animation('RESET', animation)
	return library
