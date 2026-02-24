package io.newgrounds {
	import flash.utils.getDefinitionByName;
	
	/**
	 * NGJSON
	 * 
	 * Wrapper around JSON parsing/stringifying that prefers native JSON when available
	 * and falls back to a minimal built-in encoder/decoder when it's not.
	 */
	public class NGJSON {
		private static var _nativeJSON:Class = resolveNativeJSON();
		
		public function NGJSON() {
			// static class
		}
		
		public static function stringify(value:*):String {
			if (_nativeJSON != null) {
				try {
					return _nativeJSON["stringify"](value);
				} catch (e:*) {
					// Fall through to fallback implementation
				}
			}
			return NGJSONFallback.stringify(value);
		}
		
		public static function parse(text:String):* {
			if (_nativeJSON != null) {
				try {
					return _nativeJSON["parse"](text);
				} catch (e:*) {
					// Fall through to fallback implementation
				}
			}
			return NGJSONFallback.parse(text);
		}
		
		private static function resolveNativeJSON():Class {
			try {
				return getDefinitionByName("JSON") as Class;
			} catch (e:*) {
				return null;
			}
			return null;
		}
	}
}

class NGJSONFallback {
	public function NGJSONFallback() {
		// static class
	}
	
	public static function stringify(value:*):String {
		return encodeValue(value);
	}
	
	public static function parse(text:String):* {
		var parser:NGJSONParser = new NGJSONParser(text);
		return parser.parse();
	}
	
	private static function encodeValue(value:*):String {
		if (value === null || value === undefined) {
			return "null";
		}
		if (value is String) {
			return encodeString(String(value));
		}
		if (value is Boolean) {
			return value ? "true" : "false";
		}
		if (value is Number || value is int || value is uint) {
			var num:Number = Number(value);
			return (isFinite(num)) ? String(num) : "null";
		}
		if (value is Array) {
			return encodeArray(value as Array);
		}
		return encodeObject(value);
	}
	
	private static function encodeArray(arr:Array):String {
		var parts:Array = [];
		var len:int = arr.length;
		for (var i:int = 0; i < len; i++) {
			parts.push(encodeValue(arr[i]));
		}
		return "[" + parts.join(",") + "]";
	}
	
	private static function encodeObject(obj:*):String {
		var parts:Array = [];
		for (var key:String in obj) {
			if (obj.hasOwnProperty != null && !obj.hasOwnProperty(key)) {
				continue;
			}
			parts.push(encodeString(key) + ":" + encodeValue(obj[key]));
		}
		return "{" + parts.join(",") + "}";
	}
	
	private static function encodeString(str:String):String {
		var result:String = "\"";
		var i:int = 0;
		var length:int = str.length;
		while (i < length) {
			var ch:String = str.charAt(i);
			switch (ch) {
				case "\\": result += "\\\\"; break;
				case "\"": result += "\\\""; break;
				case "\b": result += "\\b"; break;
				case "\f": result += "\\f"; break;
				case "\n": result += "\\n"; break;
				case "\r": result += "\\r"; break;
				case "\t": result += "\\t"; break;
				default:
					var code:int = ch.charCodeAt(0);
					if (code < 32) {
						var hex:String = code.toString(16);
						while (hex.length < 4) {
							hex = "0" + hex;
						}
						result += "\\u" + hex;
					} else {
						result += ch;
					}
			}
			i++;
		}
		return result + "\"";
	}
}

class NGJSONParser {
	private var text:String;
	private var index:int = 0;
	private var length:int = 0;
	
	public function NGJSONParser(text:String) {
		this.text = text;
		this.length = text.length;
	}
	
	public function parse():* {
		skipWhitespace();
		var value:* = parseValue();
		skipWhitespace();
		return value;
	}
	
	private function parseValue():* {
		if (index >= length) {
			throw new Error("JSON parse error: unexpected end of input");
		}
		var ch:String = text.charAt(index);
		switch (ch) {
			case "{":
				return parseObject();
			case "[":
				return parseArray();
			case "\"":
				return parseString();
			case "t":
				return parseLiteral("true", true);
			case "f":
				return parseLiteral("false", false);
			case "n":
				return parseLiteral("null", null);
			default:
				return parseNumber();
		}
	}
	
	private function parseObject():Object {
		var obj:Object = {};
		index++; // skip '{'
		skipWhitespace();
		if (peekChar() == "}") {
			index++;
			return obj;
		}
		while (index < length) {
			skipWhitespace();
			var key:String = parseString();
			skipWhitespace();
			expectChar(":");
			skipWhitespace();
			obj[key] = parseValue();
			skipWhitespace();
			var ch:String = peekChar();
			if (ch == "}") {
				index++;
				break;
			}
			expectChar(",");
		}
		return obj;
	}
	
	private function parseArray():Array {
		var arr:Array = [];
		index++; // skip '['
		skipWhitespace();
		if (peekChar() == "]") {
			index++;
			return arr;
		}
		while (index < length) {
			skipWhitespace();
			arr.push(parseValue());
			skipWhitespace();
			var ch:String = peekChar();
			if (ch == "]") {
				index++;
				break;
			}
			expectChar(",");
		}
		return arr;
	}
	
	private function parseString():String {
		expectChar("\"");
		var result:String = "";
		while (index < length) {
			var ch:String = text.charAt(index++);
			if (ch == "\"") {
				return result;
			}
			if (ch == "\\") {
				var esc:String = text.charAt(index++);
				switch (esc) {
					case "\"": result += "\""; break;
					case "\\": result += "\\"; break;
					case "/": result += "/"; break;
					case "b": result += "\b"; break;
					case "f": result += "\f"; break;
					case "n": result += "\n"; break;
					case "r": result += "\r"; break;
					case "t": result += "\t"; break;
					case "u":
						var hex:String = text.substr(index, 4);
						if (hex.length < 4 || !isHex(hex)) {
							throw new Error("JSON parse error: invalid unicode escape");
						}
						result += String.fromCharCode(parseInt(hex, 16));
						index += 4;
						break;
					default:
						throw new Error("JSON parse error: invalid escape sequence");
				}
			} else {
				result += ch;
			}
		}
		throw new Error("JSON parse error: unterminated string");
	}
	
	private function parseNumber():Number {
		var start:int = index;
		var ch:String = text.charAt(index);
		if (ch == "-") {
			index++;
		}
		while (index < length) {
			ch = text.charAt(index);
			if (ch < "0" || ch > "9") {
				break;
			}
			index++;
		}
		if (index < length && text.charAt(index) == ".") {
			index++;
			while (index < length) {
				ch = text.charAt(index);
				if (ch < "0" || ch > "9") {
					break;
				}
				index++;
			}
		}
		if (index < length) {
			ch = text.charAt(index);
			if (ch == "e" || ch == "E") {
				index++;
				ch = text.charAt(index);
				if (ch == "+" || ch == "-") {
					index++;
				}
				while (index < length) {
					ch = text.charAt(index);
					if (ch < "0" || ch > "9") {
						break;
					}
					index++;
				}
			}
		}
		var numStr:String = text.substring(start, index);
		var num:Number = Number(numStr);
		if (isNaN(num)) {
			throw new Error("JSON parse error: invalid number");
		}
		return num;
	}
	
	private function parseLiteral(literal:String, value:*):* {
		if (text.substr(index, literal.length) != literal) {
			throw new Error("JSON parse error: expected " + literal);
		}
		index += literal.length;
		return value;
	}
	
	private function skipWhitespace():void {
		while (index < length) {
			var ch:String = text.charAt(index);
			if (ch == " " || ch == "\t" || ch == "\n" || ch == "\r") {
				index++;
			} else {
				break;
			}
		}
	}
	
	private function expectChar(expected:String):void {
		if (index >= length || text.charAt(index) != expected) {
			throw new Error("JSON parse error: expected '" + expected + "'");
		}
		index++;
	}
	
	private function peekChar():String {
		return text.charAt(index);
	}
	
	private function isHex(s:String):Boolean {
		for (var i:int = 0; i < s.length; i++) {
			var c:String = s.charAt(i);
			if (!((c >= "0" && c <= "9") || (c >= "a" && c <= "f") || (c >= "A" && c <= "F"))) {
				return false;
			}
		}
		return true;
	}
}
