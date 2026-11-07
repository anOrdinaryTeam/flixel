package flixel.sound;

import flixel.system.FlxAssets.FlxSoundAsset;
import haxe.Int64;
import haxe.io.Bytes;
import lime.app.Future;
import lime.media.AudioBuffer;
import openfl.media.Sound;
import openfl.utils.Assets;

/**
 * Sound data shared between `FlxSound`s, built on the miniaudio backend.
 *
 * Wraps a lime `AudioBuffer`, either streamed (decoded while playing) or fully decoded,
 * and the OpenFL `Sound` made from it. Keeps the API of CodenameCrew's Flixel
 * `FlxSoundData` so Codename Engine code can use it.
 *
 * @since CodenameCrew's Flixel
 */
class FlxSoundData
{
	/**
	 * Whether sounds may be streamed at all. When `false`, every sound is fully decoded.
	 */
	public static var allowStreaming:Bool = true;

	/**
	 * When `stream` is not specified, sounds at least this long (in milliseconds) are streamed.
	 */
	public static var streamMinimumLength:Float = 8000;

	/**
	 * Sounds shorter than this (in milliseconds) persist in the cache by default.
	 */
	public static var persistMaxDuration:Float = 3000;

	static var _cache:Map<String, FlxSoundData> = [];
	static var _lastUniqueKeyIndex:Int = 0;

	/**
	 * Creates (or gets from the cache) sound data from any supported sound asset.
	 */
	public static function fromAsset(asset:FlxSoundAsset, ?stream:Bool, ?key:String, cache = true):FlxSoundData
	{
		if ((asset is FlxSoundData))
			return cast asset;
		if ((asset is String))
			return fromAssetKey(cast asset, stream, key, cache);
		if ((asset is Sound))
			return fromSound(cast asset, key, cache);
		if ((asset is Class))
			return fromClass(cast asset, key, cache);
		return null;
	}

	/**
	 * Creates (or gets from the cache) sound data from an asset key or a file path.
	 *
	 * @param   source  OpenFL asset key, for example `"assets/sound.ogg"`, or a file path.
	 * @param   stream  Whether to stream the sound. `null` streams sounds longer than `streamMinimumLength`.
	 * @param   key     Cache key to use, defaults to `source`.
	 * @param   cache   Whether to use the cache.
	 */
	public static function fromAssetKey(source:String, ?stream:Bool, ?key:String, cache = true):FlxSoundData
	{
		if (source == null)
			return null;
		if (key == null)
			key = source;

		if (cache)
		{
			final cached = getCached(key);
			if (cached != null)
				return cached;
		}

		final assetExists = Assets.exists(source);
		final path = assetExists ? Assets.getPath(source) : source;
		final wantStream = allowStreaming && (stream == null || stream);

		var buffer:AudioBuffer = null;
		#if sys
		if (path != null && sys.FileSystem.exists(path))
		{
			buffer = AudioBuffer.fromFile(path, wantStream);
			// unspecified: keep short sounds fully decoded
			if (buffer != null && wantStream && stream == null && lengthOf(buffer) < streamMinimumLength)
			{
				buffer.dispose();
				buffer = AudioBuffer.fromFile(path, false);
			}
		}
		#end

		if (buffer == null && assetExists)
		{
			final bytes = Assets.getBytes(source);
			if (bytes != null)
				buffer = AudioBuffer.fromBytes(bytes, false);
		}

		if (buffer == null)
			return null;

		final data = new FlxSoundData(key, buffer, path);
		if (cache)
			_cache.set(key, data);
		return data;
	}

	/**
	 * Creates sound data from compressed audio bytes.
	 */
	public static function fromByteArray(source:Bytes, ?stream:Bool, ?key:String, cache = true):FlxSoundData
	{
		if (source == null)
			return null;
		if (key == null)
			key = generateKey();
		if (cache)
		{
			final cached = getCached(key);
			if (cached != null)
				return cached;
		}

		final buffer = AudioBuffer.fromBytes(source, allowStreaming && stream == true);
		if (buffer == null)
			return null;

		final data = new FlxSoundData(key, buffer);
		if (cache)
			_cache.set(key, data);
		return data;
	}

	/**
	 * Creates sound data from an embedded `Sound` class.
	 */
	public static function fromClass(source:Class<Sound>, ?key:String, cache = true):FlxSoundData
	{
		if (source == null)
			return null;
		if (key == null)
			key = Type.getClassName(source);
		return fromSound(Type.createInstance(source, []), key, cache);
	}

	/**
	 * Creates sound data from an OpenFL `Sound`.
	 */
	public static function fromSound(source:Sound, ?key:String, cache = true):FlxSoundData
	{
		if (source == null)
			return null;
		@:privateAccess
		final data = fromAudioBuffer(source.__buffer, key, cache);
		if (data != null)
			data._sound = source;
		return data;
	}

	/**
	 * Creates sound data from a lime `AudioBuffer`.
	 */
	public static function fromAudioBuffer(source:AudioBuffer, ?key:String, cache = true):FlxSoundData
	{
		if (source == null)
			return null;
		if (key == null)
			key = generateKey();
		if (cache)
		{
			final cached = getCached(key);
			if (cached != null && cached.buffer == source)
				return cached;
		}

		final data = new FlxSoundData(key, source);
		if (cache)
			_cache.set(key, data);
		return data;
	}

	/**
	 * Gets cached sound data, if it exists and was not destroyed.
	 */
	public static function getCached(key:String):Null<FlxSoundData>
	{
		final data = _cache.get(key);
		if (data == null)
			return null;
		if (data.isDestroyed)
		{
			_cache.remove(key);
			return null;
		}
		return data;
	}

	/**
	 * Clearing cycle, as in Codename Engine: sound data that is not persistent and
	 * not in use is marked `unused`, and destroyed on the next cycle if still unused.
	 */
	public static function clearCache():Void
	{
		for (key in [for (k in _cache.keys()) k])
		{
			final data = _cache.get(key);
			if (data == null || data.isDestroyed)
			{
				_cache.remove(key);
				continue;
			}
			if (data.unused)
			{
				_cache.remove(key);
				data.destroy();
			}
			else if (!data.persist && data.useCount <= 0)
			{
				data.unused = true;
			}
		}
	}

	/**
	 * Destroys every cached sound data, persistent or not.
	 */
	public static function resetCache():Void
	{
		for (key in [for (k in _cache.keys()) k])
		{
			final data = _cache.get(key);
			_cache.remove(key);
			if (data != null)
				data.destroy();
		}
	}

	/**
	 * Destroys cached sound data that is not in use, not persistent and `destroyOnNoUse`.
	 */
	public static function clearUnused():Void
	{
		for (key in [for (k in _cache.keys()) k])
		{
			final data = _cache.get(key);
			if (data != null && data.useCount <= 0 && !data.persist && data.destroyOnNoUse)
			{
				_cache.remove(key);
				data.destroy();
			}
		}
	}

	/**
	 * Adds sound data to the cache under its `key`.
	 */
	public static function addToCache(data:FlxSoundData):FlxSoundData
	{
		if (data != null && data.key != null)
			_cache.set(data.key, data);
		return data;
	}

	/**
	 * Removes sound data from the cache, destroying it unless `destroy` is false.
	 */
	public static function removeFromCache(key:String, destroy = true):Void
	{
		if (key == null)
			return;
		final data = _cache.get(key);
		_cache.remove(key);
		if (destroy && data != null)
			data.destroy();
	}

	/**
	 * Key of the cached sound data using `buffer`, or null.
	 */
	public static function findKeyForBuffer(buffer:AudioBuffer):Null<String>
	{
		for (key => data in _cache)
			if (data != null && data.buffer == buffer)
				return key;
		return null;
	}

	static function generateKey():String
	{
		var key:String;
		do
			key = "FlxSoundData" + (_lastUniqueKeyIndex++)
		while (_cache.exists(key));
		return key;
	}

	static inline function lengthOf(buffer:AudioBuffer):Float
	{
		return buffer.sampleRate > 0 ? Int64.toInt(buffer.frames) / buffer.sampleRate * 1000 : 0;
	}

	/**
	 * Key of this sound data in the cache.
	 */
	public var key(default, null):String;

	/**
	 * When `true`, `clearCache()` keeps this sound data. Defaults to `true` for sounds
	 * shorter than `persistMaxDuration`.
	 */
	public var persist:Bool = false;

	/**
	 * Destroy this sound data as soon as `useCount` drops to zero (unless `persist`).
	 */
	public var destroyOnNoUse(default, set):Bool = false;

	/**
	 * How many `FlxSound`s use this sound data.
	 */
	public var useCount(default, null):Int = 0;

	/**
	 * Marked by a clearing cycle; destroyed on the next one if still unused.
	 */
	@:allow(flixel.system.frontEnds.SoundFrontEnd)
	public var unused(default, null):Bool = false;

	/**
	 * The lime audio buffer.
	 */
	public var buffer(default, null):AudioBuffer;

	/**
	 * The OpenFL sound made from `buffer`, created on first use.
	 */
	public var sound(get, never):Sound;

	public var bitsPerSample(get, never):Int;
	public var channels(get, never):Int;
	public var sampleRate(get, never):Int;

	/**
	 * Number of sample frames.
	 */
	public var samples(get, never):Int64;

	/**
	 * Length in milliseconds.
	 */
	public var length(get, never):Float;

	public var isDestroyed(get, never):Bool;

	/**
	 * Whether `buffer` is streamed (decoded while playing) instead of fully decoded.
	 */
	public var isStreamable(get, never):Bool;

	var _sound:Sound;
	var _path:Null<String>;

	public function new(key:String, buffer:AudioBuffer, ?path:String, ?persist:Bool)
	{
		this.key = key;
		this.buffer = buffer;
		this._path = path;
		if (persist == null)
			persist = buffer != null && get_length() < persistMaxDuration;
		this.persist = persist;
	}

	public function incrementUseCount():Void
	{
		useCount++;
		unused = false;
	}

	public function decrementUseCount():Void
	{
		useCount--;
		checkUseCount();
	}

	function checkUseCount():Void
	{
		if (useCount <= 0 && destroyOnNoUse && !persist)
			destroy();
	}

	function set_destroyOnNoUse(value:Bool):Bool
	{
		destroyOnNoUse = value;
		checkUseCount();
		return value;
	}

	/**
	 * Fully decodes a streamed buffer, so it no longer streams.
	 */
	public function load():Void
	{
		if (!isStreamable || _path == null)
			return;
		final decoded = AudioBuffer.fromFile(_path, false);
		if (decoded != null)
			replaceBuffer(decoded);
	}

	/**
	 * Same as `load()`, without blocking. `onComplete` gets this sound data.
	 */
	public function loadAsync(?onComplete:FlxSoundData->Void):Void
	{
		if (!isStreamable || _path == null)
		{
			if (onComplete != null)
				onComplete(this);
			return;
		}

		AudioBuffer.loadFromFile(_path).onComplete(function(decoded:AudioBuffer)
		{
			if (decoded != null && !isDestroyed)
				replaceBuffer(decoded);
			if (onComplete != null)
				onComplete(this);
		}).onError(function(_)
		{
			if (onComplete != null)
				onComplete(this);
		});
	}

	public function destroy():Void
	{
		if (buffer != null)
			buffer.dispose();
		buffer = null;
		_sound = null;
		if (_cache.get(key) == this)
			_cache.remove(key);
	}

	public function toString():String
	{
		return 'FlxSoundData(key: $key, streamed: $isStreamable, length: $length)';
	}

	function replaceBuffer(decoded:AudioBuffer):Void
	{
		final old = buffer;
		buffer = decoded;
		_sound = null;
		if (old != null && old != decoded)
			old.dispose();
	}

	function get_sound():Sound
	{
		if (_sound == null && buffer != null)
			_sound = Sound.fromAudioBuffer(buffer);
		return _sound;
	}

	inline function get_bitsPerSample():Int
		return buffer != null ? buffer.bitsPerSample : 0;

	inline function get_channels():Int
		return buffer != null ? buffer.channels : 0;

	inline function get_sampleRate():Int
		return buffer != null ? buffer.sampleRate : 0;

	inline function get_samples():Int64
		return buffer != null ? buffer.frames : Int64.ofInt(0);

	inline function get_length():Float
		return buffer != null ? lengthOf(buffer) : 0;

	inline function get_isDestroyed():Bool
		return buffer == null;

	@:privateAccess
	inline function get_isStreamable():Bool
		return buffer != null && buffer.data == null;
}
