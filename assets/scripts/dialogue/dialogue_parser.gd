class_name DialogueParser
extends RefCounted
## Parses .dlg dialogue files into an array of typed entries:
##   {type: "line", speaker, text}
##   {type: "choice", options: [{text, target}, ...]}
##   {type: "label", name}
##   {type: "jump", target}
##
## Format, one entry per line:
##   speaker_id: TEXT_OR_TRANSLATION_KEY
##   : narration line (no speaker)
##   == label_name          — jump target
##   -> label_name          — jump ("end" ends the dialogue)
##   * TEXT -> label_name   — choice option; consecutive * lines form one
##                            choice; omitting "-> label" falls through
##   # comment
## Blank lines are skipped. A line whose prefix before ":" is not a valid
## identifier is treated as narration in full.


static func parse_file(path: String) -> Array[Dictionary]:
	if not FileAccess.file_exists(path):
		push_warning("Dialogue file not found: %s" % path)
		return []
	return parse(FileAccess.get_file_as_string(path))


static func parse(source: String) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for raw_line: String in source.split("\n"):
		var line := raw_line.strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue
		if line.begins_with("=="):
			var label := line.trim_prefix("==").strip_edges()
			if label.is_valid_identifier():
				entries.append({"type": "label", "name": label})
			else:
				push_warning("Invalid dialogue label: %s" % line)
			continue
		if line.begins_with("->"):
			entries.append({"type": "jump", "target": line.trim_prefix("->").strip_edges()})
			continue
		if line.begins_with("*"):
			var body := line.trim_prefix("*").strip_edges()
			var target := ""
			var arrow := body.rfind("->")
			if arrow != -1:
				target = body.substr(arrow + 2).strip_edges()
				body = body.substr(0, arrow).strip_edges()
			if body.is_empty():
				continue
			var option: Dictionary = {"text": body, "target": target}
			if not entries.is_empty() and entries.back()["type"] == "choice":
				var options: Array = entries.back()["options"]
				options.append(option)
			else:
				entries.append({"type": "choice", "options": [option]})
			continue
		var sep := line.find(":")
		var speaker := ""
		var text := line
		if sep != -1:
			var prefix := line.substr(0, sep).strip_edges()
			if prefix.is_empty() or prefix.is_valid_identifier():
				speaker = prefix
				text = line.substr(sep + 1).strip_edges()
		if not text.is_empty():
			entries.append({"type": "line", "speaker": speaker, "text": text})
	return entries
