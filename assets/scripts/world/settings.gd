extends Node

const PATH := "user://settings.cfg"
const REBINDABLE: Array[String] = ["interact", "cancel", "menu", "attack", "show_turn_order", "run"]
const LOCALES: Array[String] = ["en", "fr_CA"]

var volume := 1.0
var locale := "en"

func _ready() -> void:
	_load()

func set_volume(v: float) -> void:
	volume = clampf(v, 0.0, 1.0)
	var bus := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(volume, 0.001)))
	AudioServer.set_bus_mute(bus, volume <= 0.0)
	save_settings()

func set_locale(l: String) -> void:
	locale = l if LOCALES.has(l) else "en"
	TranslationServer.set_locale(locale)
	save_settings()

func rebind(action: String, source: InputEventKey) -> void:
	var old_code := 0 as Key
	for ev: InputEvent in InputMap.action_get_events(action):
		if ev is InputEventKey:
			old_code = (ev as InputEventKey).physical_keycode
			break
	for other: String in REBINDABLE:
		if other == action:
			continue
		for ev: InputEvent in InputMap.action_get_events(other):
			if ev is InputEventKey and (ev as InputEventKey).physical_keycode == source.physical_keycode:
				_bind_key(other, old_code)
				break
	_bind_key(action, source.physical_keycode)
	save_settings()

func _bind_key(action: String, code: Key) -> void:
	InputMap.action_erase_events(action)
	if code == 0:
		return
	var ev := InputEventKey.new()
	ev.physical_keycode = code
	InputMap.action_add_event(action, ev)

func key_name(action: String) -> String:
	for ev: InputEvent in InputMap.action_get_events(action):
		if ev is InputEventKey:
			return OS.get_keycode_string((ev as InputEventKey).physical_keycode)
	return "---"

func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "master", volume)
	cfg.set_value("general", "locale", locale)
	for action: String in REBINDABLE:
		for ev: InputEvent in InputMap.action_get_events(action):
			if ev is InputEventKey:
				cfg.set_value("keys", action, (ev as InputEventKey).physical_keycode)
				break
	cfg.save(PATH)

func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		set_volume(volume)
		set_locale(locale)
		return
	for action: String in REBINDABLE:
		var code := int(cfg.get_value("keys", action, 0))
		if code != 0:
			var ev := InputEventKey.new()
			ev.physical_keycode = code as Key
			InputMap.action_erase_events(action)
			InputMap.action_add_event(action, ev)
	set_volume(float(cfg.get_value("audio", "master", 1.0)))
	set_locale(str(cfg.get_value("general", "locale", "en")))
