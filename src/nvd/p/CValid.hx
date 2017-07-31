package nvd.p;

class CValid {
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

	public static inline function is_alpha_u(c: Int) {
		return is_alpha(c) || c == "_".code;
	}

	/**
	alpha + number + "_"
	*/
	public static inline function is_anu(c: Int) {
		return is_alpha_u(c) || is_number(c);
	}

	/**
	alpha + number + "_" + "-"
	*/
	public static inline function is_anum(c: Int) {
		return is_anu(c) || c == "-".code;
	}

	/**
	alpha + number + "_" + "-" + ":" + "." that used for Xml's nodeName
	*/
	public static inline function is_anumx(c: Int) {
		return is_anum(c) || c == ":".code || c == ".".code;
	}
}