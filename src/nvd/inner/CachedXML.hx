package nvd.inner;

import csss.xml.Xml;
import csss.xml.Parser;
import sys.io.File;
import sys.FileSystem;
import haxe.macro.PositionTools.make in pmake;
import haxe.macro.PositionTools.getInfos in pInfos;
 using nvd.inner.Utils;

class CachedXML {

	var mtime: Float;

	public var xml(default, null) : Xml;

	function new() mtime = 0.;

	function update( path : String ) {
		var stat = FileSystem.stat(path);
		var cur = stat.mtime.getTime();
		if (cur > mtime) {
			this.xml = Xml.parse( File.getContent(path) );
			this.mtime = cur;
		}
	}

	public static function get( path, pos ): CachedXML {
		var ret = POOL.get(path);
		if (ret == null) {
			ret = new CachedXML();
			POOL.set(path, ret);
		}
		try
			ret.update(path)
		catch( e : XmlParserException )
			Nvd.fatalError(e.toString(), pmake({file: path, min: e.position, max: e.position + 1}))
		catch( e : Dynamic )
			Nvd.fatalError(Std.string(e), pos);
		return ret;
	}

	@:persistent static var POOL = new Map<String, CachedXML>();
}