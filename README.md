A character animation builder for Mini Fantasy characters.
Place raw folders into a directory, launch the plugin, select the directory, generate SpriteFrames with one-click, and then choose a character to produce AnimatedSprite2Ds, an AnimationPlayer, and an AnimationTree to get you up and running.

The AnimationTree should be pointed at any Advance Expression Base Node that updates `is_moving`, `is_attacking`, and `is_dead`.

You also must update the blend_positions to wire up proper facing like
```
animation_tree.set("parameters/Idles/blend_position", direction)
animation_tree.set("parameters/Walks/blend_position", direction)
animation_tree.set("parameters/Attacks/blend_position", direction)
```
