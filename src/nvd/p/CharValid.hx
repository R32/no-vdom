package nvd.p;


class CharValid {
	public static function is_alpha(c: Int) {
		return (c >= "a".code && c <= "z".code) || (c >= "A".code && c <= "Z".code);
	}
	// TODO: Dealing with "." for Float
	public static function is_number(c: Int) {
		return c >= "0".code && c <= "9".code;
	}

	public static function is_space(c: Int) {
		return c == " ".code || (c > 8 && c < 14) || c == 0x3000 || c == 0xA0;
	}
}