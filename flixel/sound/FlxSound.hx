package flixel.sound;

import flixel.FlxBasic;
import flixel.FlxG;
import flixel.math.FlxMath;
import flixel.math.FlxPoint;
import flixel.system.FlxAssets.FlxSoundAsset;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxSignal;
import flixel.util.FlxStringUtil;
import lime.media.AudioBuffer;
import lime.media.AudioEffect;
import lime.media.AudioManager;
import lime.media.AudioSource;
import openfl.events.Event;
import openfl.events.IEventDispatcher;
import openfl.media.Sound;
import openfl.net.URLRequest;
import openfl.utils.ByteArray;

/**
 * This is the universal flixel sound object, used for streaming, music, and sound effects.
 */
class FlxSound extends FlxBasic
{
	/**
	 * The x position of this sound in world coordinates.
	 * Only really matters if you are doing proximity/panning stuff.
	 */
	public var x:Float;
	
	/**
	 * The y position of this sound in world coordinates.
	 * Only really matters if you are doing proximity/panning stuff.
	 */
	public var y:Float;
	
	/**
	 * The song title from the sound file's tags (ID3, Vorbis comments, WAV INFO), if it has one.
	 */
	public var name(get, null):String;
	
	/**
	 * The artist from the sound file's tags (ID3, Vorbis comments, WAV INFO), if it has one.
	 */
	public var artist(get, null):String;
	
	/**
	 * Stores the average wave amplitude of both stereo channels
	 */
	public var amplitude(default, null):Float;
	
	/**
	 * Just the amplitude of the left stereo channel
	 */
	public var amplitudeLeft(default, null):Float;
	
	/**
	 * Just the amplitude of the right stereo channel
	 */
	public var amplitudeRight(default, null):Float;
	
	/**
	 * At which point to stop playing the sound, in milliseconds.
	 * If not set / `null`, the sound completes normally.
	 * @since 4.2.0
	 */
	public var endTime:Null<Float>;
	
	/**
	 * Whether or not this sound should be automatically destroyed when you switch states.
	 */
	public var persist:Bool;
	
	/**
	 * Whether to call `destroy()` when the sound has finished playing.
	 */
	public var autoDestroy:Bool;
	
	/**
	 * Tracker for sound complete callback. If assigned, will be called
	 * each time when sound reaches its end.
	 */
	public var onComplete:Void->Void;
	
	/**
	 * Pan amount. -1 = full left, 1 = full right. Proximity based panning overrides this.
	 * 
	 * Note: On desktop targets this only works with mono sounds, due to limitations of OpenAL.
	 * More info: [OpenFL Forums - SoundTransform.pan does not work](https://community.openfl.org/t/windows-legacy-soundtransform-pan-does-not-work/6616/2?u=geokureli)
	 */
	public var pan(get, set):Float;
	
	/**
	 * Whether or not the sound is currently playing.
	 */
	public var playing(get, never):Bool;
	
	/**
	 * Set volume to a value between 0 and 1 to change how this sound is.
	 */
	public var volume(get, set):Float;
	
	/**
	 * Set pitch, which also alters the playback speed. Default is 1.
	 */
	public var pitch(get, set):Float;

	/**
	 * Whether this sound is muted, independent of `volume` (Codename Engine API).
	 */
	public var muted(get, set):Bool;

	/**
	 * Offset in milliseconds between the source's timeline and `time`: `time` 0 plays the
	 * source from `offset`. `length`, `loopTime` and `endTime` are relative to it as well
	 * (Codename Engine API).
	 */
	public var offset:Float = 0;

	var _muted:Bool = false;
	
	/**
	 * The position in runtime of the music playback in milliseconds.
	 */
	public var time(get, set):Float;
	
	/**
	 * The length of the sound in milliseconds.
	 * @since 4.2.0
	 */
	public var length(get, never):Float;
	
	/**
	 * The sound group this sound belongs to, can only be in one group.
	 * NOTE: This setter is deprecated, use `group.add(sound)` or `group.remove(sound)`.
	 */
	public var group(default, set):FlxSoundGroup;
	
	/**
	 * Whether or not this sound should loop.
	 */
	public var looped:Bool;
	
	/**
	 * In case of looping, the point (in milliseconds) from where to restart the sound when it loops back
	 * @since 4.1.0
	 */
	public var loopTime:Float = 0;
	
	/**
	 * The tween used to fade this sound's volume in and out (set via `fadeIn()` and `fadeOut()`)
	 * @since 4.1.0
	 */
	public var fadeTween:FlxTween;

	/**
	 * Dispatched when the sound finishes playing (every loop, like `onComplete`).
	 * @since CodenameCrew's Flixel
	 */
	public final onFinish:FlxSignal = new FlxSignal();

	/**
	 * Dispatched when the sound is destroyed.
	 * @since CodenameCrew's Flixel
	 */
	public final onDestroy:FlxSignal = new FlxSignal();

	/**
	 * Whether proximity (distance based volume and pan) is active. Set by `proximity()`.
	 * @since CodenameCrew's Flixel
	 */
	public var proximityEnabled(get, set):Bool;

	/**
	 * Whether proximity also pans the sound.
	 * @since CodenameCrew's Flixel
	 */
	public var proximityPan(get, set):Bool;

	/**
	 * The object this sound's proximity is measured from.
	 */
	public var target(get, set):FlxObject;

	/**
	 * Maximum distance this sound can be heard from with proximity. Default is 1024.
	 */
	public var radius(get, set):Float;

	/**
	 * How camera scrolling affects this sound's position for proximity. Created by `proximity()`.
	 * @since CodenameCrew's Flixel
	 */
	public var scrollFactor(default, null):FlxPoint;

	/**
	 * Whether the sound is paused (not the same as stopped).
	 */
	public var paused(get, never):Bool;

	/**
	 * Whether the sound played to its end (without looping).
	 * @since CodenameCrew's Flixel
	 */
	public var completed(get, never):Bool;

	/**
	 * How many times the sound looped since it was last started.
	 * @since CodenameCrew's Flixel
	 */
	public var loopCount(default, null):Int = 0;

	/**
	 * How many times a looped sound repeats, `-1` (default) loops forever.
	 * @since CodenameCrew's Flixel
	 */
	public var loopUntil(default, set):Int = -1;

	/**
	 * Whether the pitch follows `FlxG.timeScale`. Defaults to `defaultTimeScaledPitch`.
	 * @since CodenameCrew's Flixel
	 */
	public var timeScaledPitch(get, set):Bool;

	/**
	 * Output latency of the audio device in milliseconds.
	 * @since CodenameCrew's Flixel
	 */
	public var latency(get, never):Float;

	/**
	 * Peak of each channel (left, right).
	 * @since CodenameCrew's Flixel
	 */
	public var amplitudes(get, never):Array<Float>;

	/**
	 * The lime audio buffer being played.
	 * @since CodenameCrew's Flixel
	 */
	public var buffer(get, never):AudioBuffer;

	var _proximityEnabled:Bool = false;
	var _completed:Bool = false;
	var _timeScaledPitch:Bool = true;
	var _amplitudes:Array<Float> = [0, 0];
	
	/**
	 * Internal tracker for the loaded sound asset.
	 */
	@:allow(flixel.system.frontEnds.SoundFrontEnd.load)
	var _sound:Sound;
	
	/**
	 * Internal tracker for a lime audio source object.
	 */
	var _source:AudioSource;

	/**
	 * Effects of this sound, kept across sources so a newly loaded sound gets them too.
	 */
	var _effects:Array<AudioEffect> = [];
	
	/**
	 * Internal tracker for whether the sound is paused or not (not the same as stopped).
	 */
	var _paused:Bool;
	
	/**
	 * Internal tracker for volume.
	 */
	var _volume:Float;
	
	/**
	 * Internal tracker for pitch.
	 */
	var _pitch:Float = 1.0;
	
	/**
	 * Internal tracker for total volume adjustment.
	 */
	var _volumeAdjust:Float = 1.0;
	
	/**
	 * Internal tracker for pan, since `AudioSource` has no native pan property - see the `pan` doc above.
	 */
	var _pan:Float = 0;
	
	/**
	 * Internal tracker for the sound's "target" (for proximity and panning).
	 */
	var _target:FlxObject;
	
	/**
	 * Internal tracker for the maximum effective radius of this sound (for proximity and panning).
	 */
	var _radius:Float;
	
	/**
	 * Internal tracker for whether to pan the sound left and right.  Default is false.
	 */
	var _proximityPan:Bool;
	
	/**
	 * Helper var to prevent the sound from playing after focus was regained when it was already paused.
	 */
	var _resumeOnFocus:Bool = false;
	
	/**
	 * Whether `name` and `artist` were already read from `_sound`'s tags.
	 */
	var _tagsRead:Bool = false;
	
	/**
	 * The FlxSound constructor gets all the variables initialized, but NOT ready to play a sound yet.
	 */
	public function new()
	{
		super();
		resetSound();
	}
	
	/**
	 * An internal function for clearing all the variables used by sounds.
	 * Unloads the sound; see `reset` for a reset that keeps it loaded.
	 */
	function resetSound():Void
	{
		__destroy();
		
		x = 0;
		y = 0;
		
		_paused = false;
		_volume = 1.0;
		_volumeAdjust = 1.0;
		_pan = 0;
		looped = false;
		loopTime = 0.0;
		_target = null;
		_radius = 1024;
		_proximityPan = false;
		_proximityEnabled = false;
		_completed = false;
		loopCount = 0;
		loopUntil = -1;
		_timeScaledPitch = defaultTimeScaledPitch;
		visible = false;
		autoDestroy = false;
		amplitude = 0;
		amplitudeLeft = 0;
		amplitudeRight = 0;
		endTime = null;
		name = null;
		artist = null;
		_tagsRead = false;
		_releaseData();
		offset = 0;
		_muted = false;
	}

	/**
	 * Stops the sound and resets its playback properties (volume, pan, pitch,
	 * offset, mute) while keeping the loaded sound (Codename Engine API).
	 * @param	force	Also reset looping, end time and proximity settings.
	 */
	public function reset(force = false):Void
	{
		autoDestroy = false;
		stop();

		x = y = 0;

		if (force)
		{
			_target = null;
			_radius = 1024;
			_proximityPan = true;
			_proximityEnabled = false;
			scrollFactor?.set(0, 0);
			looped = false;
			loopTime = 0;
			loopUntil = -1;
			endTime = null;
			_timeScaledPitch = defaultTimeScaledPitch;
			clearEffects();
		}

		loopCount = 0;
		_completed = false;

		offset = 0;
		_paused = false;
		_volume = 1.0;
		_volumeAdjust = 1.0;
		_muted = false;
		_pan = 0;
		pitch = 1;

		updateVolume();
		updatePan();
	}
	
	override public function destroy():Void
	{
		onDestroy.dispatch();
		onDestroy.removeAll();
		onFinish.removeAll();
		scrollFactor = flixel.util.FlxDestroyUtil.put(scrollFactor);
		clearEffects();
		__destroy();
		// after __destroy disposed the source using its buffer
		_releaseData();
	}

	/**
	 * Releases the source and resets the basic state, without dispatching `onDestroy`
	 * (used internally when a new sound is loaded).
	 */
	function __destroy():Void
	{
		// Prevents double destroy
		if (group != null)
			group.remove(this);
			
		exists = false;
		active = false;
		_target = null;
		
		if (fadeTween != null)
		{
			fadeTween.cancel();
			fadeTween = null;
		}
		
		if (_source != null)
		{
			_source.onComplete.remove(stopped);
			_detachEffects();
			_source.dispose();
			_source = null;
		}
		
		_sound = null;
		
		onComplete = null;
		
		super.destroy();
	}
	
	/**
	 * Handles fade out, fade in, panning and proximity, operations each frame.
	 */
	override public function update(elapsed:Float):Void
	{
		if (!playing)
		{
			amplitude = amplitudeLeft = amplitudeRight = 0;
			return;
		}
			
		_volumeAdjust = 1.0;
		
		// Distance-based volume control
		if (_target != null && _proximityEnabled)
		{
			final targetPos = _target.getPosition();
			var soundX = x;
			var soundY = y;

			// with a scroll factor (CNE proximity), compare screen positions
			if (scrollFactor != null)
			{
				final camera = FlxG.camera;
				if (camera != null)
				{
					targetPos.subtract(camera.scroll.x * _target.scrollFactor.x, camera.scroll.y * _target.scrollFactor.y);
					soundX -= camera.scroll.x * scrollFactor.x;
					soundY -= camera.scroll.y * scrollFactor.y;
				}
			}

			final radius = _radius > 0 ? _radius : 1;
			_volumeAdjust = 1 - FlxMath.bound(targetPos.distanceTo(FlxPoint.weak(soundX, soundY)) / radius, 0, 1);
			
			if (_proximityPan)
				pan = FlxMath.bound((soundX - targetPos.x) / radius, -1, 1);

			targetPos.put();
		}
		
		updateVolume();
		
		// the meter reads the source's output, so take its gain back out like the old SoundChannel peaks
		final gain:Float = _source.gain;
		
		if (gain > 0)
		{
			amplitudeLeft = Math.min(1, _source.getPeak(0) / gain);
			amplitudeRight = Math.min(1, _source.getPeak(1) / gain);
			amplitude = (amplitudeLeft + amplitudeRight) * 0.5;
			_amplitudes[0] = amplitudeLeft;
			_amplitudes[1] = amplitudeRight;
		}
		else
		{
			amplitude = amplitudeLeft = amplitudeRight = 0;
		}
		
		if (endTime != null && time >= endTime)
			stopped();
	}
	
	override public function kill():Void
	{
		super.kill();
		cleanup(false);
	}
	
	/**
	 * One of the main setup functions for sounds, this function loads a sound from an embedded MP3.
	 *
	 * **Note:** If the `FLX_DEFAULT_SOUND_EXT` flag is enabled, you may omit the file extension
	 *
	 * @param	EmbeddedSound	An embedded Class object representing an MP3 file.
	 * @param	Looped			Whether or not this sound should loop endlessly.
	 * @param	AutoDestroy		Whether or not this FlxSound instance should be destroyed when the sound finishes playing.
	 * 							Default value is false, but `FlxG.sound.play()` and `FlxG.sound.stream()` will set it to true by default.
	 * @param	OnComplete		Called when the sound finished playing
	 * @return	This FlxSound instance (nice for chaining stuff together, if you're into that).
	 */
	public function loadEmbedded(EmbeddedSound:FlxSoundAsset, ?Looped:Bool, ?LoopTime:Float, ?EndTime:Float, AutoDestroy:Bool = false,
			?OnComplete:Void->Void):FlxSound
	{
		if (EmbeddedSound == null)
			return this;
			
		cleanup(true);
		
		if ((EmbeddedSound is FlxSoundData))
		{
			_useData(EmbeddedSound);
		}
		else if ((EmbeddedSound is Sound))
		{
			_sound = EmbeddedSound;
		}
		else if ((EmbeddedSound is Class))
		{
			_sound = Type.createInstance(EmbeddedSound, []);
		}
		else if ((EmbeddedSound is String))
		{
			// like Codename Engine: through FlxSoundData, so long sounds (songs) are streamed
			// instead of decoded whole into memory
			var data = FlxSoundData.fromAsset(EmbeddedSound);
			var ownStream = false;
			if (data != null && data.isStreamable && data.useCount > 0)
			{
				// a stream is one decoder: another sound already plays this one, so open our own
				data = FlxSoundData.fromAssetKey(EmbeddedSound, true, null, false);
				ownStream = true;
			}
			if (data != null && !data.isDestroyed)
			{
				_useData(data);
				// not cached: freed once this sound lets go of it (after the use is counted)
				if (ownStream)
					data.destroyOnNoUse = true;
			}
			else if (FlxG.assets.exists(EmbeddedSound, SOUND))
				_sound = FlxG.assets.getSoundUnsafe(EmbeddedSound);
			else
				FlxG.log.error('Could not find a Sound asset with an ID of \'$EmbeddedSound\'.');
		}
		
		init(Looped == true, AutoDestroy, OnComplete);
		if (LoopTime != null)
			loopTime = LoopTime;
		if (EndTime != null)
			endTime = EndTime;
		return this;
	}

	/**
	 * Streams a sound from an asset path or ID, decoding it while it plays
	 * (Codename Engine API, same arguments as `loadEmbedded`).
	 */
	public function loadStreamed(path:String, ?looped:Bool, ?loopTime:Float, ?endTime:Float, autoDestroy:Bool = false, ?onComplete:Void->Void):FlxSound
	{
		return loadEmbedded(FlxSoundData.fromAssetKey(path, true), looped, loopTime, endTime, autoDestroy, onComplete);
	}

	/**
	 * Loads a sound from a URL or file path (Codename Engine API, see `loadStream`).
	 */
	public function loadFromURL(url:String, ?looped:Bool, ?loopTime:Float, ?endTime:Float, autoDestroy:Bool = false, ?onComplete:Void->Void,
			?onLoad:Void->Void):FlxSound
	{
		loadStream(url, looped == true, autoDestroy, onComplete, onLoad);
		if (loopTime != null)
			this.loopTime = loopTime;
		if (endTime != null)
			this.endTime = endTime;
		return this;
	}

	/**
	 * Stops the sound and releases the loaded audio, keeping this `FlxSound` reusable.
	 * @since CodenameCrew's Flixel
	 */
	public function unload():FlxSound
	{
		cleanup(false);

		if (_source != null)
		{
			_source.onComplete.remove(stopped);
			_detachEffects();
			_source.dispose();
			_source = null;
		}

		_sound = null;
		_releaseData();
		alive = false;
		exists = false;
		loopTime = 0;
		endTime = null;
		return this;
	}
	
	/**
	 * One of the main setup functions for sounds, this function loads a sound from a URL.
	 * Local files are streamed with miniaudio's decoder instead of being decoded all at once.
	 *
	 * @param	SoundURL		A string representing the URL or path of the sound file you want to play.
	 * @param	Looped			Whether or not this sound should loop endlessly.
	 * @param	AutoDestroy		Whether or not this FlxSound instance should be destroyed when the sound finishes playing.
	 * 							Default value is false, but `FlxG.sound.play()` and `FlxG.sound.stream()` will set it to true by default.
	 * @param	OnComplete		Called when the sound finished playing
	 * @param	OnLoad			Called when the sound finished loading.
	 * @return	This FlxSound instance (nice for chaining stuff together, if you're into that).
	 */
	public function loadStream(SoundURL:String, Looped:Bool = false, AutoDestroy:Bool = false, ?OnComplete:Void->Void, ?OnLoad:Void->Void):FlxSound
	{
		cleanup(true);
		
		#if sys
		if (sys.FileSystem.exists(SoundURL))
		{
			try
			{
				_sound = Sound.fromFile(SoundURL, true);
			}
			catch (e:Dynamic)
			{
				FlxG.log.error('Could not stream the sound at \'$SoundURL\'.');
				_sound = null;
			}
			
			init(Looped, AutoDestroy, OnComplete);
			
			if (OnLoad != null && _sound != null)
				OnLoad();
				
			return this;
		}
		#end
		
		final sound:Sound = new Sound();
		var loadCallback:Event->Void = null;
		loadCallback = function(e:Event)
		{
			(e.target : IEventDispatcher).removeEventListener(e.type, loadCallback);
			
			// Check if the sound was destroyed or reloaded before it finished loading
			if (_sound == sound)
			{
				init(Looped, AutoDestroy, OnComplete);
				
				if (OnLoad != null)
					OnLoad();
			}
		}
		
		_sound = sound;
		_sound.addEventListener(Event.COMPLETE, loadCallback);
		_sound.load(new URLRequest(SoundURL));
		
		looped = Looped;
		autoDestroy = AutoDestroy;
		onComplete = OnComplete;
		exists = true;
		return this;
	}
	
	/**
	 * One of the main setup functions for sounds, this function loads a sound from a ByteArray.
	 *
	 * @param	Bytes 			A ByteArray object.
	 * @param	Looped			Whether or not this sound should loop endlessly.
	 * @param	AutoDestroy		Whether or not this FlxSound instance should be destroyed when the sound finishes playing.
	 * 							Default value is false, but `FlxG.sound.play()` and `FlxG.sound.stream()` will set it to true by default.
	 * @return	This FlxSound instance (nice for chaining stuff together, if you're into that).
	 */
	public function loadByteArray(Bytes:ByteArray, Looped:Bool = false, AutoDestroy:Bool = false, ?OnComplete:Void->Void):FlxSound
	{
		cleanup(true);
		
		_sound = Sound.fromBytes(Bytes);
		
		return init(Looped, AutoDestroy, OnComplete);
	}
	
	function init(Looped:Bool = false, AutoDestroy:Bool = false, ?OnComplete:Void->Void):FlxSound
	{
		looped = Looped;
		autoDestroy = AutoDestroy;
		exists = true;
		onComplete = OnComplete;
		
		if (_sound != null)
		{
			@:privateAccess
			_source = new AudioSource(_sound.__buffer);
			_source.onComplete.add(stopped);
			for (effect in _effects)
				_source.addEffect(effect);
		}
		
		pitch = 1;
		_completed = false;
		loopCount = 0;
		updateVolume();
		updatePan();
		return this;
	}
	
	/**
	 * Call this function if you want this sound's volume to change
	 * based on distance from a particular FlxObject.
	 *
	 * @param	X			The X position of the sound.
	 * @param	Y			The Y position of the sound.
	 * @param	TargetObject		The object you want to track.
	 * @param	Radius			The maximum distance this sound can travel.
	 * @param	Pan			Whether panning should be used in addition to the volume changes.
	 * @return	This FlxSound instance (nice for chaining stuff together, if you're into that).
	 */
	public function proximity(X:Float = 0, Y:Float = 0, ?TargetObject:FlxObject, ?Radius:Float, Pan:Bool = true, ?ScrollFactor:FlxPoint):FlxSound
	{
		x = X;
		y = Y;
		_proximityEnabled = true;
		_proximityPan = Pan;
		if (TargetObject != null)
			_target = TargetObject;
		if (Radius != null)
			_radius = Radius;
		if (ScrollFactor != null)
		{
			if (scrollFactor == null)
				scrollFactor = FlxPoint.get();
			scrollFactor.copyFrom(ScrollFactor);
		}
		return this;
	}

	/**
	 * World position of this sound.
	 * @since CodenameCrew's Flixel
	 */
	/**
	 * Adds an audio effect at the end of this sound's effect chain.
	 * It stays on this sound when another sound is loaded into it.
	 * @param	effect	A `lime.media.AudioEffect` instance.
	 * @since CodenameCrew's Flixel
	 */
	public function addEffect(effect:AudioEffect):Void
	{
		if (effect == null || _effects.contains(effect))
			return;

		_effects.push(effect);
		if (_source != null)
			_source.addEffect(effect);
	}

	/**
	 * Removes an audio effect from this sound.
	 * @param	effect	A `lime.media.AudioEffect` instance.
	 * @since CodenameCrew's Flixel
	 */
	public function removeEffect(effect:AudioEffect):Void
	{
		if (effect == null || !_effects.remove(effect))
			return;

		if (_source != null)
			_source.removeEffect(effect);
	}

	/**
	 * Removes every audio effect from this sound.
	 * @since CodenameCrew's Flixel
	 */
	public function clearEffects():Void
	{
		for (effect in _effects.copy())
			removeEffect(effect);
	}

	/**
	 * @param	index	An index in this sound's effect chain.
	 * @return	The `lime.media.AudioEffect` at `index`, or null.
	 * @since CodenameCrew's Flixel
	 */
	public function getEffectAt(index:Int):AudioEffect
	{
		return index >= 0 && index < _effects.length ? _effects[index] : null;
	}

	/**
	 * @param	effect	A `lime.media.AudioEffect` instance.
	 * @return	The index of `effect` in this sound's effect chain, or -1.
	 * @since CodenameCrew's Flixel
	 */
	public function getEffectIndex(effect:AudioEffect):Int
	{
		return _effects.indexOf(effect);
	}

	/**
	 * Unlinks the current source from this sound's effects before it is disposed,
	 * without disposing the effects themselves.
	 */
	function _detachEffects():Void
	{
		for (effect in _effects)
		{
			final autoDispose = effect.autoDispose;
			effect.autoDispose = false;
			_source.removeEffect(effect);
			effect.autoDispose = autoDispose;
		}
	}

	public function getPosition(?result:FlxPoint):FlxPoint
	{
		if (result == null)
			result = FlxPoint.get();
		return result.set(x, y);
	}
	
	/**
	 * Call this function to play the sound - also works on paused sounds.
	 *
	 * @param   ForceRestart   Whether to start the sound over or not.
	 *                         Default value is false, meaning if the sound is already playing or was
	 *                         paused when you call play(), it will continue playing from its current
	 *                         position, NOT start again from the beginning.
	 * @param   StartTime      At which point to start playing the sound, in milliseconds.
	 *                         Only used when the sound starts from the beginning (or `ForceRestart` is true).
	 */
	public function play(ForceRestart:Bool = false, StartTime:Float = 0.0, ?EndTime:Float, ?Volume:Float, ?Pitch:Float, ?Pan:Float):FlxSound
	{
		// optional overrides, as in Codename Engine's FlxSound.play
		if (EndTime != null)
			endTime = EndTime;
		if (Volume != null)
			volume = Volume;
		if (Pitch != null)
			pitch = Pitch;
		if (Pan != null)
			pan = Pan;

		if (!exists || _source == null)
			return this;
			
		if (ForceRestart)
		{
			loopCount = 0;
			startSound(StartTime);
		}
		else if (!playing)
		{
			if (_paused)
				resume();
			else
			{
				loopCount = 0;
				startSound(StartTime);
			}
		}
		
		return this;
	}
	
	/**
	 * Unpause a sound. Only works on sounds that have been paused.
	 */
	public function resume():FlxSound
	{
		if (!_paused || _source == null)
			return this;
			
		_paused = false;
		_source.play();
		active = true;
		
		return this;
	}
	
	/**
	 * Call this function to pause this sound.
	 */
	public function pause():FlxSound
	{
		if (!playing)
			return this;
			
		_paused = true;
		_source.pause();
		active = false;
		
		return this;
	}
	
	/**
	 * Call this function to stop this sound.
	 */
	public inline function stop():FlxSound
	{
		cleanup(autoDestroy, true);
		return this;
	}
	
	/**
	 * Helper function that tweens this sound's volume.
	 *
	 * @param	Duration	The amount of time the fade-out operation should take.
	 * @param	To			The volume to tween to, 0 by default.
	 */
	public function fadeOut(Duration:Float = 1, ?To:Float = 0, ?onComplete:FlxTween->Void, ?ease:EaseFunction):FlxSound
	{
		fadeTween?.cancel();
		fadeTween = FlxTween.num(volume, To, Duration, {ease: ease ?? FlxEase.quadIn, onComplete: onComplete}, volumeTween);
		return this;
	}
	
	/**
	 * Helper function that tweens this sound's volume.
	 *
	 * @param	Duration	The amount of time the fade-in operation should take.
	 * @param	From		The volume to tween from, 0 by default.
	 * @param	To			The volume to tween to, 1 by default.
	 */
	public function fadeIn(Duration:Float = 1, From:Float = 0, To:Float = 1, ?onComplete:FlxTween->Void, ?ease:EaseFunction):FlxSound
	{
		if (!playing)
			play();
			
		fadeTween?.cancel();
		fadeTween = FlxTween.num(From, To, Duration, {ease: ease ?? FlxEase.quadOut, onComplete: onComplete}, volumeTween);
		return this;
	}

	function volumeTween(f:Float):Void
	{
		volume = f;
	}
	
	/**
	 * Returns the currently selected "real" volume of the sound (takes fades and proximity into account).
	 *
	 * @return	The adjusted volume of the sound.
	 */
	/**
	 * Default value for `timeScaledPitch`-like behaviour, kept for Codename Engine compatibility.
	 * @since CodenameCrew's Flixel
	 */
	public static var defaultTimeScaledPitch:Bool = true;

	/**
	 * Sound data this `FlxSound` plays.
	 * @since CodenameCrew's Flixel
	 */
	public var data(get, never):FlxSoundData;

	var _data:FlxSoundData;

	/**
	 * Whether this sound counts as a use of `_data` (see `FlxSoundData.useCount`).
	 */
	var _dataCounted:Bool = false;

	function get_data():FlxSoundData
	{
		if (_sound == null)
			return null;
		if (_data == null || _data.isDestroyed || _data.sound != _sound)
		{
			_releaseData();
			// uncached wrapper of a plain Sound: not counted
			_data = FlxSoundData.fromSound(_sound, null, false);
		}
		return _data;
	}

	/**
	 * Plays `data` and counts this sound as one of its uses, so the sound data
	 * cache keeps it while it is loaded here.
	 */
	function _useData(data:FlxSoundData):Void
	{
		_releaseData();
		_data = data;
		_sound = data.sound;
		data.incrementUseCount();
		_dataCounted = true;
	}

	/**
	 * Drops `_data`, giving back its use. Call it after the source using its buffer is gone:
	 * data that is no longer used may be destroyed right away.
	 */
	function _releaseData():Void
	{
		final data = _data;
		final counted = _dataCounted;
		_data = null;
		_dataCounted = false;
		if (counted && data != null && !data.isDestroyed)
			data.decrementUseCount();
	}

	/**
	 * The lime audio source playing this sound.
	 * @since CodenameCrew's Flixel
	 */
	public var source(get, never):AudioSource;

	inline function get_source():AudioSource
		return _source;

	/**
	 * Whether a sound is loaded into this `FlxSound`.
	 * @since CodenameCrew's Flixel
	 */
	public var loaded(get, never):Bool;

	inline function get_loaded():Bool
		return _source != null;

	/**
	 * Seeks to `startTime` and leaves the sound paused, ready for `resume()` or `FlxSound.playSounds()`.
	 * @since CodenameCrew's Flixel
	 */
	public function prepare(startTime = 0.0, ?endTime:Float, ?volume:Float, ?pitch:Float, ?pan:Float):FlxSound
	{
		if (volume != null)
			this.volume = volume;
		if (pitch != null)
			this.pitch = pitch;
		if (pan != null)
			this.pan = pan;
		if (endTime != null)
			this.endTime = endTime;

		if (_source == null)
			return this;

		if (_source.playing)
			_source.pause();
		_source.currentTime = startTime + offset;
		_paused = true;
		active = false;

		return this;
	}

	/**
	 * Starts every given sound back to back, so they stay in sync. Use `prepare()` first.
	 * @since CodenameCrew's Flixel
	 */
	public static function playSounds(sounds:Array<FlxSound>):Void
	{
		final toPlay:Array<FlxSound> = [];
		for (sound in sounds)
		{
			if (sound == null || !sound.exists || sound._source == null)
				continue;
			sound._paused = false;
			sound.active = true;
			toPlay.push(sound);
		}
		for (sound in toPlay)
			sound._source.play();
	}

	/**
	 * Pauses every given sound.
	 * @since CodenameCrew's Flixel
	 */
	public static function pauseSounds(sounds:Array<FlxSound>):Void
	{
		for (sound in sounds)
			if (sound != null && sound.exists && sound.playing)
				sound.pause();
	}

	/**
	 * Current playback time, read from the audio source.
	 * @since CodenameCrew's Flixel
	 */
	public inline function getActualTime():Float
		return time;

	public function getActualVolume():Float
	{
		return _muted ? 0 : (group != null ? group.getVolume() : 1.0) * _volume * _volumeAdjust;
	}

	/**
	 * Pitch the source plays at: `pitch`, times `FlxG.timeScale` with `timeScaledPitch`.
	 * @since CodenameCrew's Flixel
	 */
	public function getActualPitch():Float
	{
		return _timeScaledPitch ? _pitch * FlxG.timeScale : _pitch;
	}

	/**
	 * Pan the source plays at (includes proximity panning).
	 * @since CodenameCrew's Flixel
	 */
	public function getActualPan():Float
	{
		return _pan;
	}

	/**
	 * Stops every given sound (Codename Engine API).
	 */
	public static function stopSounds(sounds:Array<FlxSound>):Void
	{
		for (sound in sounds)
			if (sound != null && sound.exists && sound.playing)
				sound.stop();
	}
	
	/**
	 * Helper function to set the coordinates of this object.
	 * Sound positioning is used in conjunction with proximity/panning.
	 *
	 * @param        X        The new x position
	 * @param        Y        The new y position
	 */
	public inline function setPosition(X:Float = 0, Y:Float = 0):Void
	{
		x = X;
		y = Y;
	}
	
	/**
	 * Call after adjusting the volume to update the sound's settings.
	 */
	@:allow(flixel.sound.FlxSoundGroup)
	function updateVolume():Void
	{
		if (_source != null)
			_source.gain = calcTransformVolume();
	}
	
	/**
	 * Call after adjusting the pan to update the sound's settings.
	 */
	@:allow(flixel.sound.FlxSoundGroup)
	function updatePan():Void
	{
		if (_source != null)
			_source.pan = _pan;
	}
	
	function calcTransformVolume():Float
	{
		if (_muted)
			return 0.0;

		final volume = (group != null ? group.getVolume() : 1.0) * _volume * _volumeAdjust;
		
		#if FLX_SOUND_SYSTEM
		if (FlxG.sound.muted)
			return 0.0;
			
		return FlxG.sound.volume * volume;
		#else
		return volume;
		#end
	}
	
	/**
	 * An internal helper function used to (re)start playback on the persistent `_source`
	 * from a given position. Doesn't create or destroy anything - just seeks and plays.
	 */
	function startSound(StartTime:Float):Void
	{
		if (_source == null)
			return;
			
		_paused = false;
		_completed = false;
		
		_source.currentTime = StartTime + offset;
		
		_source.play();
		
		active = true;
	}
	
	/**
	 * An internal helper called when the source finishes playing.
	 * Restarts looped sounds, otherwise cleans up (and destroys the sound if `autoDestroy` is enabled).
	 */
	function stopped():Void
	{
		if (onComplete != null)
			onComplete();
		onFinish.dispatch();
			
		if (looped && (loopUntil < 0 || loopCount < loopUntil))
		{
			loopCount++;
			startSound(loopTime);
		}
		else
		{
			_completed = true;
			cleanup(autoDestroy);
		}
	}
	
	/**
	 * An internal helper function used to clean up (and potentially re-use) finished sounds.
	 * Will stop the current sound, plus any other commands ordered by the passed in parameters.
	 *
	 * @param  destroySound    Whether or not to destroy the sound. If this is true,
	 *                         everything is reset and `resetPosition` is ignored.
	 * @param  resetPosition   Whether or not to clear the paused state, so the next `play()`
	 *                         starts from the beginning instead of resuming.
	 */
	function cleanup(destroySound:Bool, resetPosition:Bool = true):Void
	{
		if (destroySound)
		{
			resetSound();
			return;
		}
		
		if (_source != null)
			_source.stop();
			
		active = false;
		
		if (resetPosition)
			_paused = false;
	}
	
	function get_name():String
	{
		readTags();
		return name;
	}
	
	function get_artist():String
	{
		readTags();
		return artist;
	}
	
	function readTags():Void
	{
		if (_tagsRead || _sound == null)
			return;
			
		_tagsRead = true;
		
		final id3 = _sound.id3;
		
		if (id3 != null)
		{
			name = id3.songName;
			artist = id3.artist;
		}
	}
	
	#if FLX_SOUND_SYSTEM
	@:allow(flixel.system.frontEnds.SoundFrontEnd)
	function onFocus():Void
	{
		if (_resumeOnFocus)
		{
			_resumeOnFocus = false;
			resume();
		}
	}
	
	@:allow(flixel.system.frontEnds.SoundFrontEnd)
	function onFocusLost():Void
	{
		_resumeOnFocus = playing;
		pause();
	}
	#end
	
	@:deprecated("sound.group = myGroup is deprecated, use myGroup.add(sound)") // 5.7.0
	function set_group(value:FlxSoundGroup):FlxSoundGroup
	{
		if (value != null)
		{
			// add to new group, also removes from prev and calls updateTransform
			value.add(this);
		}
		else
		{
			// remove from prev group, also calls updateTransform
			group.remove(this);
		}
		return value;
	}
	
	inline function get_playing():Bool
	{
		return _source != null && _source.playing;
	}
	
	inline function get_volume():Float
	{
		return _volume;
	}
	
	function set_volume(Volume:Float):Float
	{
		_volume = FlxMath.bound(Volume, 0, 1);
		updateVolume();
		return _volume;
	}
	
	inline function get_pitch():Float
	{
		return _pitch;
	}
	
	function set_pitch(v:Float):Float
	{
		_pitch = v;
		updatePitch();
		return v;
	}

	/** Codename Engine names for the internal update helpers. */
	@:noCompletion inline function _updateVolume():Void
		updateVolume();

	@:noCompletion inline function _updatePan():Void
		updatePan();

	@:noCompletion inline function _updatePitch():Void
		updatePitch();

	@:noCompletion function updateTransform():Void
	{
		updateVolume();
		updatePan();
		updatePitch();
	}

	@:allow(flixel.system.frontEnds.SoundFrontEnd)
	function updatePitch():Void
	{
		if (_source != null)
			_source.pitch = getActualPitch();
	}
	
	inline function get_pan():Float
	{
		return _pan;
	}
	
	function set_pan(pan:Float):Float
	{
		_pan = FlxMath.bound(pan, -1, 1);
		updatePan();
		return _pan;
	}
	
	inline function get_time():Float
	{
		return _source != null ? _source.currentTime - offset : 0;
	}
	
	function set_time(time:Float):Float
	{
		if (_source != null)
			_source.currentTime = time + offset;
			
		return time;
	}
	
	inline function get_length():Float
	{
		return _source != null ? _source.length - offset : 0;
	}

	inline function get_muted():Bool
	{
		return _muted;
	}

	function set_muted(value:Bool):Bool
	{
		if (_muted != value)
		{
			_muted = value;
			updateVolume();
		}
		return value;
	}
	
	inline function get_proximityEnabled():Bool
		return _proximityEnabled;

	function set_proximityEnabled(value:Bool):Bool
	{
		if (!value)
			_volumeAdjust = 1.0;
		return _proximityEnabled = value;
	}

	inline function get_proximityPan():Bool
		return _proximityPan;

	inline function set_proximityPan(value:Bool):Bool
		return _proximityPan = value;

	inline function get_target():FlxObject
		return _target;

	inline function set_target(value:FlxObject):FlxObject
		return _target = value;

	inline function get_radius():Float
		return _radius;

	inline function set_radius(value:Float):Float
		return _radius = value;

	inline function get_paused():Bool
		return _paused;

	inline function get_completed():Bool
		return _completed;

	function set_loopUntil(value:Int):Int
		return loopUntil = value < 0 ? -1 : value;

	inline function get_timeScaledPitch():Bool
		return _timeScaledPitch;

	function set_timeScaledPitch(value:Bool):Bool
	{
		_timeScaledPitch = value;
		updatePitch();
		return value;
	}

	function get_latency():Float
	{
		#if lime_miniaudio
		return AudioManager.engine != null ? AudioManager.engine.get_latency() : 0;
		#else
		return 0;
		#end
	}

	inline function get_amplitudes():Array<Float>
		return _amplitudes;

	function get_buffer():AudioBuffer
	{
		if (_data != null && _data.buffer != null)
			return _data.buffer;
		@:privateAccess
		return _sound != null ? _sound.__buffer : null;
	}

	override public function revive():Void
	{
		super.revive();
		reset(true);
	}

	override public function toString():String
	{
		return FlxStringUtil.getDebugString([
			LabelValuePair.weak("playing", playing),
			LabelValuePair.weak("time", time),
			LabelValuePair.weak("length", length),
			LabelValuePair.weak("volume", volume)
		]);
	}
}
