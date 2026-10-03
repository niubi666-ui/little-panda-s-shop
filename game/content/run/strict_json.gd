extends RefCounted
## Validate syntax and duplicate keys before JSON collapses object members.
const MAX_NESTING := 64
var errors: PackedStringArray = []
var _source := ""
var _index := 0
var _depth := 0
var _label := ""
var _number := RegEx.new()

func parse(text: String, label: String = "JSON") -> Variant:
	errors.clear()
	_source = text
	_index = 0
	_depth = 0
	_label = label
	_number.compile("^-?(0|[1-9][0-9]*)(\\.[0-9]+)?([eE][+-]?[0-9]+)?$")
	_space()
	if _index >= _source.length():
		_fail("empty input")
		return null
	_value()
	_space()
	if _index != _source.length(): _fail("trailing content")
	if not errors.is_empty(): return null
	var parser := JSON.new()
	if parser.parse(_source) != OK:
		_fail(parser.get_error_message())
		return null
	if not _finite(parser.data):
		_fail("non-finite number")
		return null
	return parser.data

func _finite(value: Variant) -> bool:
	if value is float: return is_finite(value)
	if value is Dictionary or value is Array:
		for child in value.values() if value is Dictionary else value:
			if not _finite(child): return false
	return true

func _value() -> void:
	if not errors.is_empty(): return
	_space()
	if _index >= _source.length(): _fail("missing value"); return
	_depth += 1
	if _depth > MAX_NESTING: _fail("nesting limit exceeded"); return
	var char := _source.substr(_index, 1)
	match char:
		"{": _object()
		"[": _array()
		"\"": _string()
		_:
			var start := _index
			while _index < _source.length() and not _source.substr(_index, 1) in [",", "]", "}", " ", "\t", "\r", "\n"]: _index += 1
			var token := _source.substr(start, _index - start)
			if not token in ["true", "false", "null"] and _number.search(token) == null: _fail("invalid scalar")
	_depth -= 1

func _object() -> void:
	_index += 1
	_space()
	if _take("}"): return
	var keys: Dictionary = {}
	while errors.is_empty():
		_space()
		if _peek() != "\"": _fail("object key must be a string"); return
		var key: String = _string()
		if keys.has(key): _fail("duplicate object key: " + key); return
		keys[key] = true
		_space()
		if not _take(":"): _fail("missing object colon"); return
		_value()
		_space()
		if _take("}"): return
		if not _take(","): _fail("missing object separator"); return

func _array() -> void:
	_index += 1
	_space()
	if _take("]"): return
	while errors.is_empty():
		_value()
		_space()
		if _take("]"): return
		if not _take(","): _fail("missing array separator"); return

func _string() -> String:
	var start := _index
	_index += 1
	while _index < _source.length():
		var char := _source.substr(_index, 1)
		if char.unicode_at(0) < 32: _fail("unescaped control character"); return ""
		_index += 1
		if char == "\\":
			var escape := _peek()
			if not escape in ["\"", "\\", "/", "b", "f", "n", "r", "t", "u"]: _fail("invalid string escape"); return ""
			_index += 1
			if escape == "u":
				for ignored in 4:
					if _index >= _source.length() or not _peek().to_lower() in ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "a", "b", "c", "d", "e", "f"]: _fail("invalid unicode escape"); return ""
					_index += 1
		elif char == "\"":
			var parser := JSON.new()
			if parser.parse(_source.substr(start, _index - start)) != OK or not parser.data is String:
				_fail("invalid string escape")
				return ""
			return parser.data
	_fail("unterminated string")
	return ""

func _space() -> void:
	while _index < _source.length() and _source.substr(_index, 1) in [" ", "\t", "\r", "\n"]: _index += 1

func _peek() -> String:
	return _source.substr(_index, 1)

func _take(char: String) -> bool:
	if _peek() != char: return false
	_index += 1
	return true

func _fail(message: String) -> void:
	if errors.is_empty(): errors.append("%s:%s: %s" % [_label, _index, message])
