extends Node

signal changed

var _items: Dictionary = {}

func _ready() -> void:
	add(RepairKit.new(), 3)
	add(PowerCell.new(), 2)

func add(item: Item, amount := 1) -> void:
	_items[item] = int(_items.get(item, 0)) + amount
	changed.emit()

func remove(item: Item, amount := 1) -> bool:
	if int(_items.get(item, 0)) < amount:
		return false
	_items[item] = int(_items[item]) - amount
	if int(_items[item]) <= 0:
		_items.erase(item)
	changed.emit()
	return true

func count(item: Item) -> int:
	return int(_items.get(item, 0))

func entries() -> Array[Item]:
	var out: Array[Item] = []
	for item: Item in _items:
		out.append(item)
	return out
