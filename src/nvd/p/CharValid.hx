package nvd.p;


class CharValid {
	public static inline function is_alpha(c: Int) {
		return (c >= "a".code && c <= "z".code) || (c >= "A".code && c <= "Z".code);
	}
	// TODO: Dealing with "." for Float
	public static inline function is_number(c: Int) {
		return c >= "0".code && c <= "9".code;
	}

	public static inline function is_space(c: Int) {
		return c == " ".code || (c > 8 && c < 14) || c == 0x3000 || c == 0xA0;
	}

	// for Xml.nodeName
	public static inline function is_validchar(c) {
		return (c >= 'a'.code && c <= 'z'.code) || (c >= 'A'.code && c <= 'Z'.code) || (c >= '0'.code && c <= '9'.code) || c == ':'.code || c == '.'.code || c == '_'.code || c == '-'.code;
	}
}