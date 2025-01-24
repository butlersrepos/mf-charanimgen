@tool
class_name MiniFantasyAnimationLibraryBuilder

var path_to_sprite_frames: String = "res://mini-fantasy-sprite-frames.res"
var mini_fantasy_animated_sprite_name: String = "MiniFantasyAnimatedSprite2D"

static func create_anim_library(character: String, sprite_frames: SpriteFrames, base_sprite: AnimatedSprite2D, shadow_sprite: AnimatedSprite2D) -> AnimationLibrary:
	var library = AnimationLibrary.new()
	
	var char_frames = Array(sprite_frames.get_animation_names()).filter(func(a: String):
		return a.to_lower().begins_with(character)
	)
	for anim_name in char_frames:
		print('Lib - ', anim_name)
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
		
		# We'll add the shadow if we found one
		var shadow_anim = anim_name + "-shadow"
		print('Lib - ', shadow_anim)
		if sprite_frames.has_animation(shadow_anim):
			var shadow_frames = sprite_frames.get_frame_count(shadow_anim)
			# Setup the third track to set the current animation of the shadow sprite immediately, like "troll-idle-downleft-shadow"
			var shadow_anim_track = animation.add_track(Animation.TYPE_VALUE)
			animation.value_track_set_update_mode(shadow_anim_track, Animation.UPDATE_DISCRETE)
			animation.track_set_path(shadow_anim_track, "%s:animation" % [shadow_sprite.name])
			animation.track_insert_key(shadow_anim_track, 0, shadow_anim)
			# Setup the fourth track to iterate through the shadow frames until they're done
			var shadow_frames_track = animation.add_track(Animation.TYPE_VALUE)
			animation.value_track_set_update_mode(shadow_frames_track, Animation.UPDATE_DISCRETE)
			animation.track_set_path(shadow_frames_track, "%s:frame" % [shadow_sprite.name])
			for i in shadow_frames:
				animation.track_insert_key(shadow_frames_track, i * frame_interval, i)
		# Set animation properties
		animation.length = frame_count * frame_interval
		animation.loop_mode = Animation.LOOP_LINEAR if sprite_frames.get_animation_loop(anim_name) else Animation.LOOP_NONE
		
		# Add to library
		library.add_animation(anim_name, animation)
	return library
