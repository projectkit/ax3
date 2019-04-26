@:callable // TODO it's a bit unsafe because @:callable takes and returns Dynamic, not ASAny
           // I'm not sure how much can we do about it, maybe wrap the TTAny arguments and the return value in ASAny on the converter level?
abstract ASAny(Dynamic)
	from Dynamic
	from haxe.Constraints.Function
{

	public inline function new() this = {};

	@:to public inline function iterator():NativePropertyIterator {
		return new NativePropertyIterator(this);
	}

	public function hasOwnProperty(name:String):Bool {
		if (Reflect.hasField(this, name)) {
			return true;
		}
        var clazz = Type.getClass(this);
        if (clazz != null) {
            var fields = Type.getInstanceFields(clazz);
            return fields.indexOf(name) > -1 || fields.indexOf("get_"+name) > -1 || fields.indexOf("set_"+name) > -1;
		}
		return false;
	}

	@:to function ___toString():String {
		return this; // TODO
	}

	@:to function ___toBool():Bool {
		return this; // TODO
	}

	@:to function ___toInt():Int {
		return this; // TODO
	}

	@:to function ___toFloat():Float {
		return this; // TODO
	}

	@:to function ___toOther():Dynamic {
		return this;
	}

	@:op(a.b) function ___get(name:String):ASAny {
		var value:Dynamic = Reflect.getProperty(this, name);
		if (Reflect.isFunction(value))
			return Reflect.makeVarArgs(args -> Reflect.callMethod(this, value, args));
		else
			return value;
	}

	@:op(a.b) inline function ___set(name:String, value:ASAny):ASAny {
		Reflect.setProperty(this, name, value);
		return value;
	}

	@:op(!a) inline function __not():Bool {
		return !___toBool();
	}

	// TODO we probably don't want to apply `ASAny` conversions for something that is already Bool
	@:op(a || b) static inline function __or(a:ASAny, b:ASAny):ASAny {
		return if (a) a else b;
	}

	// TODO: same comment as above
	@:op(a && b) static inline function __and(a:ASAny, b:ASAny):ASAny {
		return if (a) b else a;
	}

	@:op(a - b) static function ___minusInt(a:ASAny, b:Int):Int return a.___toInt() - b;
	@:op(a - b) static function ___minusInt2(a:Int, b:ASAny):Int return a - b.___toInt();
	@:commutative @:op(a + b) static function ___plusInt(a:ASAny, b:Int):Int return a.___toInt() + b;

	@:op(a - b) static function ___minusFloat(a:ASAny, b:Float):Float return a.___toFloat() - b;
	@:op(a - b) static function ___minusFloat2(a:Float, b:ASAny):Float return a - b.___toFloat();
	@:commutative @:op(a + b) static function ___plusFloat(a:ASAny, b:Float):Float return a.___toFloat() + b;

	@:op(a > b) static function ___gt(a:ASAny, b:Float):Bool return a.___toFloat() > b;
	@:op(a < b) static function ___lt(a:ASAny, b:Float):Bool return a.___toFloat() < b;
	@:op(a >= b) static function ___gte(a:ASAny, b:Float):Bool return a.___toFloat() >= b;
	@:op(a <= b) static function ___lte(a:ASAny, b:Float):Bool return a.___toFloat() <= b;

	@:op(a > b) static function ___gt2(a:Float, b:ASAny):Bool return a > b.___toFloat();
	@:op(a < b) static function ___lt2(a:Float, b:ASAny):Bool return a < b.___toFloat();
	@:op(a >= b) static function ___gte2(a:Float, b:ASAny):Bool return a >= b.___toFloat();
	@:op(a <= b) static function ___lte2(a:Float, b:ASAny):Bool return a <= b.___toFloat();

	@:op([]) inline function ___arrayGet(name:ASAny):ASAny return ___get(name);
	@:op([]) inline function ___arraySet(name:ASAny, value:ASAny):ASAny return ___set(name, value);

	@:from extern static inline function ___fromDictionary<K,V>(d:ASDictionary<K,V>):ASAny return cast d;
}


private class NativePropertyIterator {
	var collection:Dynamic;
	var index = 0;

	public inline function new(collection:Dynamic) {
		this.collection = collection;
	}

	public inline function hasNext():Bool {
		var c = collection;
		var i = index;
		var result = untyped __has_next__(c, i);
		collection = c;
		index = i;
		return result;
	}

	public inline function next():ASAny {
		var i = index;
		var result = untyped __forin__(collection, i);
		index = i;
		return result;
	}
}
