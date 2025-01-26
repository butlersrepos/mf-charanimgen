@tool 
extends EditorScript
class_name DataUtils

## Test case for utilities
func _run() -> void:
	var test1 = func (levels: int = -1):
		return flatten_array([{'a':1}, [{'b':2},{'c':3}], [[[[{'d':4}]]]]], levels)
	
	print(test1.call())
	assert(test1.call() == [{ "a": 1 }, { "b": 2 }, { "c": 3 }, {'d': 4}], "Flatten should flatten a all levels.")
	print(test1.call(1))
	assert(test1.call(1) == [{ "a": 1 }, { "b": 2 }, { "c": 3 }, [[[{'d': 4}]]]], "Flatten should flatten a all levels.")

static func flatten_array(arr: Array[Variant], levels: int = -1) -> Array[Dictionary]:
	if levels == 0:
		return arr
	var flattened: Array[Dictionary] = []
	for item in arr:
		if item is Array:
			# If we're flattening infinite, don't decrement the recursion, just keep going until there's no Arrays
			var decrement = (1 if levels > -1 else 0)
			flattened.append_array(flatten_array(item, levels - decrement))
		else:
			flattened.append(item)
	return flattened
