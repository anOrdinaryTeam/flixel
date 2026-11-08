package flixel.system.frontEnds;

#if FLX_SOUND_SYSTEM
import flixel.FlxG;
import flixel.group.FlxGroup;
import flixel.input.keyboard.FlxKey;
import flixel.math.FlxMath;
import flixel.sound.FlxSound;
import flixel.sound.FlxSoundGroup;
import flixel.system.FlxAssets;
import flixel.system.ui.FlxSoundTray;
import flixel.text.FlxInputText;
import flixel.sound.FlxSoundData;
import flixel.util.FlxSignal;
import lime.media.AudioBuffer;
import lime.media.AudioManager;
import openfl.media.Sound;

/**
 * Accessed via `FlxG.sound`.
 */
@:allow(flixel.FlxG)
class SoundFrontEnd
{
	/**
	 * A handy container for a background music object.
	 */
	#if FLX_SAVE
	/**
	 * Where sound preferences (volume, mute) are saved; `FlxG.save` unless set
	 * to another bound save (Codename Engine API).
	 */
	public static var save(get, null):flixel.util.FlxSave;

	static function get_save():flixel.util.FlxSave
	{
		if (save == null || !save.isBound)
			save = FlxG.save;
		return save;
	}
	#end

	/**
	 * How many destroyed sounds are kept in `list` for reuse after a state change.
	 * @since CodenameCrew's Flixel
	 */
	public static var poolMaxSounds:Int = 16;

	public var music:FlxSound;

	/**
	 * Whether `pause()` paused every sound (Codename Engine API).
	 */
	public var paused(default, null):Bool = false;

	/**
	 * Whether sounds pause automatically when the game loses focus (with `FlxG.autoPause`).
	 * @since CodenameCrew's Flixel
	 */
	public var canAutoPause:Bool = true;

	// whether onFocusLost stopped the audio engine, to start it again on focus
	var _suspendedAudio:Bool = false;

	/**
	 * Whether playback follows the system default output device.
	 * Turning it on moves playback back to the default device.
	 */
	public var automaticDefaultDevice(get, set):Bool;

	/**
	 * Name of the output device. Setting it moves playback to that device, or back to
	 * the default one if it cannot be opened. See `lime.media.AudioManager.getPlaybackDeviceNames()`.
	 */
	public var deviceName(get, set):String;

	/**
	 * Dispatched with the device name when the default output device changes.
	 */
	public var onDefaultDeviceChanged(default, null):FlxTypedSignal<String->Void> = new FlxTypedSignal<String->Void>();

	public var onDeviceAdded(default, null):FlxTypedSignal<String->Void> = new FlxTypedSignal<String->Void>();

	public var onDeviceRemoved(default, null):FlxTypedSignal<String->Void> = new FlxTypedSignal<String->Void>();

	var _lastTimeScale:Float = 1.0;
	var _lostFocusPause:Bool = false;

	/**
	 * Whether or not the game sounds are muted.
	 */
	public var muted:Bool = false;

	/**
	 * Set this hook to get a callback whenever the volume changes.
	 * Function should take the form myVolumeHandler(volume:Float).
	 */
	@:deprecated("volumeHandler is deprecated, use onVolumeChange, instead")
	public var volumeHandler:Float->Void;

	/**
	 * A signal that gets dispatched whenever the volume changes.
	 */
	public var onVolumeChange(default, null):FlxTypedSignal<Float->Void> = new FlxTypedSignal<Float->Void>();

	#if FLX_KEYBOARD
	/**
	 * The key codes used to increase volume (see FlxG.keys for the keys available).
	 * Default keys: + (and numpad +). Set to null to deactivate.
	 */
	public var volumeUpKeys:Array<FlxKey> = [PLUS, NUMPADPLUS];

	/**
	 * The keys to decrease volume (see FlxG.keys for the keys available).
	 * Default keys: - (and numpad -). Set to null to deactivate.
	 */
	public var volumeDownKeys:Array<FlxKey> = [MINUS, NUMPADMINUS];

	/**
	 * The keys used to mute / unmute the game (see FlxG.keys for the keys available).
	 * Default keys: 0 (and numpad 0). Set to null to deactivate.
	 */
	public var muteKeys:Array<FlxKey> = [ZERO, NUMPADZERO];
	#end

	/**
	 * Whether or not the soundTray should be shown when any of the
	 * volumeUp-, volumeDown- or muteKeys is pressed.
	 */
	public var soundTrayEnabled:Bool = true;
	
	#if FLX_SOUND_TRAY
	/**
	 * The sound tray display container.
	 * A getter for `FlxG.game.soundTray`.
	 */
	public var soundTray(get, never):FlxSoundTray;
	
	inline function get_soundTray()
	{
		return FlxG.game.soundTray;
	}
	#end

	/**
	 * The group sounds played via playMusic() are added to unless specified otherwise.
	 */
	public var defaultMusicGroup:FlxSoundGroup = new FlxSoundGroup();

	/**
	 * The group sounds in load() / play() / stream() are added to unless specified otherwise.
	 */
	public var defaultSoundGroup:FlxSoundGroup = new FlxSoundGroup();

	/**
	 * A list of all the sounds being played in the game.
	 */
	public var list(default, null):FlxTypedGroup<FlxSound> = new FlxTypedGroup<FlxSound>();

	/**
	 * Set this to a number between 0 and 1 to change the global volume.
	 */
	public var volume(default, set):Float = 1;

	/**
	 * Set up and play a looping background soundtrack.
	 *
	 * **Note:** If the `FLX_DEFAULT_SOUND_EXT` flag is enabled, you may omit the file extension
	 *
	 * @param   embeddedMusic  The sound file you want to loop in the background.
	 * @param   volume         How loud the sound should be, from 0 to 1.
	 * @param   looped         Whether to loop this music.
	 * @param   group          The group to add this sound to.
	 */
	public function playMusic(embeddedMusic:FlxSoundAsset, volume = 1.0, looped = true, ?group:FlxSoundGroup):Void
	{
		if (group == null)
			group = defaultMusicGroup;
		
		if (music == null)
		{
			music = new FlxSound();
		}
		else if (music.active)
		{
			music.stop();
		}
		
		music.loadEmbedded(embeddedMusic, looped);
		music.volume = volume;
		music.persist = true;
		group.add(music);
		music.play();
	}

	/**
	 * Creates a new FlxSound object.
	 *
	 * **Note:** If the `FLX_DEFAULT_SOUND_EXT` flag is enabled, you may omit the file extension
	 *
	 * @param   embeddedSound   The embedded sound resource you want to play.  To stream, use the optional URL parameter instead.
	 * @param   volume          How loud to play it (0 to 1).
	 * @param   looped          Whether to loop this sound.
	 * @param   group           The group to add this sound to.
	 * @param   autoDestroy     Whether to destroy this sound when it finishes playing.
	 *                          Leave this value set to "false" if you want to re-use this FlxSound instance.
	 * @param   autoPlay        Whether to play the sound.
	 * @param   url             Load a sound from an external web resource or a local path instead.
	 *                          Local files are streamed instead of decoded all at once.
	 * @param   onComplete      Called when the sound finished playing.
	 * @param   onLoad          Called when the sound finished loading.  Called immediately for succesfully loaded embedded sounds.
	 * @return  A FlxSound object.
	 */
	public function load(?embeddedSound:FlxSoundAsset, volume = 1.0, looped = false, ?group:FlxSoundGroup, autoDestroy = false, autoPlay = false, ?url:String,
			?onComplete:Void->Void, ?onLoad:Void->Void):FlxSound
	{
		if ((embeddedSound == null) && (url == null))
		{
			FlxG.log.warn("FlxG.sound.load() requires either\nan embedded sound or a URL to work.");
			return null;
		}

		var sound:FlxSound = list.recycle(FlxSound);

		if (embeddedSound != null)
		{
			sound.loadEmbedded(embeddedSound, looped, autoDestroy, onComplete);
			loadHelper(sound, volume, group, autoPlay);
			// Call OnlLoad() because the sound already loaded
			if (onLoad != null && sound._sound != null)
				onLoad();
		}
		else
		{
			var loadCallback = onLoad;
			if (autoPlay)
			{
				// Auto play the sound when it's done loading
				loadCallback = function()
				{
					sound.play();

					if (onLoad != null)
						onLoad();
				}
			}

			sound.loadStream(url, looped, autoDestroy, onComplete, loadCallback);
			loadHelper(sound, volume, group);
		}

		return sound;
	}

	function loadHelper(sound:FlxSound, volume:Float, group:FlxSoundGroup, autoPlay = false):FlxSound
	{
		if (group == null)
			group = defaultSoundGroup;
		
		sound.volume = volume;
		group.add(sound);
		
		if (autoPlay)
			sound.play();
		
		return sound;
	}

	/**
	 * Method for sound caching (especially useful on mobile targets). The game may freeze
	 * for some time the first time you try to play a sound if you don't use this method.
	 *
	 * @param   embeddedSound  Name of sound assets specified in your .xml project file
	 * @return  Cached Sound object
	 */
	public inline function cache(embeddedSound:String):Sound
	{
		// load the sound into the OpenFL assets cache
		if (FlxG.assets.exists(embeddedSound, SOUND))
			return FlxG.assets.getSoundUnsafe(embeddedSound, true);
		FlxG.log.error('Could not find a Sound asset with an ID of \'$embeddedSound\'.');
		return null;
	}

	/**
	 * Calls FlxG.sound.cache() on all sounds that are embedded.
	 * WARNING: can lead to high memory usage.
	 */
	public function cacheAll():Void
	{
		for (id in FlxG.assets.list(SOUND))
		{
			cache(id);
		}
	}

	/**
	 * Plays a sound from an embedded sound. Tries to recycle a cached sound first.
	 *
	 * **Note:** If the `FLX_DEFAULT_SOUND_EXT` flag is enabled, you may omit the file extension
	 *
	 * @param   embeddedSound  The embedded sound resource you want to play.
	 * @param   volume         How loud to play it (0 to 1).
	 * @param   looped         Whether to loop this sound.
	 * @param   group          The group to add this sound to.
	 * @param   autoDestroy    Whether to destroy this sound when it finishes playing.
	 *                         Leave this value set to "false" if you want to re-use this FlxSound instance.
	 * @param   onComplete     Called when the sound finished playing
	 * @return  A FlxSound object.
	 */
	public function play(embeddedSound:FlxSoundAsset, volume = 1.0, looped = false, ?group:FlxSoundGroup, autoDestroy = true, ?onComplete:Void->Void):FlxSound
	{
		if ((embeddedSound is String))
		{
			embeddedSound = cache(embeddedSound);
		}
		var sound = list.recycle(FlxSound).loadEmbedded(embeddedSound, looped, autoDestroy, onComplete);
		return loadHelper(sound, volume, group, true);
	}

	/**
	 * Plays a sound from a URL or a local path, streaming local files. Tries to recycle a cached sound first.
	 * NOTE: Just calls FlxG.sound.load() with AutoPlay == true.
	 *
	 * @param   url          Load a sound from an external web resource or a local path instead.
	 * @param   volume       How loud to play it (0 to 1).
	 * @param   looped       Whether to loop this sound.
	 * @param   group        The group to add this sound to.
	 * @param   autoDestroy  Whether to destroy this sound when it finishes playing.
	 *                       Leave this value set to "false" if you want to re-use this FlxSound instance.
	 * @param   onComplete   Called when the sound finished playing
	 * @param   onLoad       Called when the sound finished loading.
	 * @return  A FlxSound object.
	 */
	public function stream(url:String, volume = 1.0, looped = false, ?group:FlxSoundGroup, autoDestroy = true, ?onComplete:Void->Void,
			?onLoad:Void->Void):FlxSound
	{
		return load(null, volume, looped, group, autoDestroy, true, url, onComplete, onLoad);
	}

	/**
	 * Pause all sounds currently playing.
	 */
	public function pause():Void
	{
		if (music != null && music.exists && music.active)
		{
			music.pause();
		}

		for (sound in list.members)
		{
			if (sound != null && sound.exists && sound.active)
			{
				sound.pause();
			}
		}

		paused = true;
	}

	/**
	 * Resume playing existing sounds.
	 */
	public function resume():Void
	{
		if (music != null && music.exists)
		{
			music.resume();
		}

		for (sound in list.members)
		{
			if (sound != null && sound.exists)
			{
				sound.resume();
			}
		}

		paused = false;
	}

	/**
	 * Called by FlxGame on state changes to stop and destroy sounds.
	 *
	 * @param   forceDestroy  Kill sounds even if persist is true.
	 */
	public function destroy(forceDestroy = false):Void
	{
		if (music != null && (forceDestroy || !music.persist))
		{
			music.destroy();
			music = null;
		}

		// destroy sounds, keeping at most `poolMaxSounds` destroyed ones for reuse
		var kept = 0;
		var i = list.members.length;
		while (i-- > 0)
		{
			final sound = list.members[i];
			if (sound == null)
			{
				list.members.splice(i, 1);
			}
			else if (forceDestroy || !sound.persist)
			{
				sound.destroy();
				if (kept < poolMaxSounds)
					kept++;
				else
					list.members.splice(i, 1);
			}
		}

		// members were spliced directly, keep the group's counter in sync
		@:privateAccess list.length = list.members.length;
	}

	/**
	 * Toggles muted, also activating the sound tray.
	 */
	@:haxe.warning("-WDeprecated")
	public function toggleMuted():Void
	{
		muted = !muted;

		if (volumeHandler != null)
		{
			volumeHandler(muted ? 0 : volume);
		}

		onVolumeChange.dispatch(muted ? 0 : volume);

		showSoundTray(true);
	}

	/**
	 * Changes the volume by a certain amount, also activating the sound tray.
	 */
	/**
	 * Whether volume control by keys is allowed.
	 * @since CodenameCrew's Flixel
	 */
	public var keysAllowed:Bool = true;

	/**
	 * Takes the volume scale used by Flixel fields and gives the transformed volume.
	 * Kept for Codename Engine compatibility: this fork already applies a logarithmic
	 * curve in `changeVolume`, so the result is not fed into the final gain.
	 * @since CodenameCrew's Flixel
	 */
	public dynamic function applySoundCurve(volume:Float):Float
	{
		return volume;
	}

	/**
	 * Reverses `applySoundCurve`.
	 * @since CodenameCrew's Flixel
	 */
	public dynamic function reverseSoundCurve(curvedVolume:Float):Float
	{
		return curvedVolume;
	}

	/**
	 * Removes a sound from the default groups and destroys it.
	 * @since CodenameCrew's Flixel
	 */
	@:deprecated("destroySound is deprecated, use FlxSound.destroy() instead.")
	public function destroySound(sound:FlxSound):Void
	{
		if (sound == null) return;
		defaultMusicGroup.remove(sound);
		defaultSoundGroup.remove(sound);
		sound.destroy();
	}

	/**
	 * Whether sound data with this key is cached.
	 * @since CodenameCrew's Flixel
	 */
	public inline function checkCache(key:String):Bool
	{
		return getCache(key) != null;
	}

	/**
	 * Removes cached sound data (and its OpenFL cached sound), destroying it unless `destroy` is false.
	 * @since CodenameCrew's Flixel
	 */
	public function removeCache(key:String, destroy = true):Void
	{
		if (key == null)
			return;
		FlxSoundData.removeFromCache(key, destroy);
		openfl.utils.Assets.cache.removeSound(key);
	}

	/**
	 * Caches the given sound data under its key.
	 * @since CodenameCrew's Flixel
	 */
	public inline function addCache(soundData:FlxSoundData):FlxSoundData
	{
		return FlxSoundData.addToCache(soundData);
	}

	/**
	 * Cached sound data with this key, or null.
	 * @since CodenameCrew's Flixel
	 */
	public inline function getCache(key:String):FlxSoundData
	{
		return FlxSoundData.getCached(key);
	}

	/**
	 * One clearing cycle: unused, non-persistent sound data is destroyed on the second cycle.
	 * @since CodenameCrew's Flixel
	 */
	public function clearCache():Void
	{
		FlxSoundData.clearCache();
	}

	/**
	 * Destroys unused sound data that has `destroyOnNoUse` set.
	 * @since CodenameCrew's Flixel
	 */
	public function clearUnused():Void
	{
		FlxSoundData.clearUnused();
	}

	/**
	 * Key of the cached sound data using `buffer`, or null.
	 * @since CodenameCrew's Flixel
	 */
	public function findKeyForBuffer(buffer:AudioBuffer):Null<String>
	{
		return FlxSoundData.findKeyForBuffer(buffer);
	}

	/**
	 * Destroys ALL cached sound data and removes every sound from the OpenFL asset cache.
	 * @since CodenameCrew's Flixel
	 */
	public function resetCache():Void
	{
		FlxSoundData.resetCache();

		var cache = Std.downcast(openfl.utils.Assets.cache, openfl.utils.AssetCache);
		if (cache == null || cache.sound == null) return;
		for (key in [for (k in cache.sound.keys()) k])
			cache.removeSound(key);
	}

	public function changeVolume(Amount:Float):Void
	{
		muted = false;
		var logVolume:Float = linearToLog(logToLinear(volume) + Amount);
		// Makes sure that the volume is fully muted when it hits the lower limit and is fully set back to max when increased
		if (logVolume < 0.0011)
			logVolume = 0;
		else if (logVolume > 0.99)
			logVolume = 1;

		volume = logVolume;

		showSoundTray(Amount > 0);
	}

	public function linearToLog(x:Float, minValue:Float = 0.001):Float
	{
		// Ensure x is between 0 and 1
		x = Math.max(0, Math.min(1, x));
		
		// Convert linear scale to logarithmic
		return Math.exp(Math.log(minValue) * (1 - x));
	}
	
	public function logToLinear(x:Float, minValue:Float = 0.001):Float
	{
		// Ensure x is between minValue and 1
		x = Math.max(minValue, Math.min(1, x));
		
		// Convert logarithmic scale to linear
		return 1 - (Math.log(x) / Math.log(minValue));
	}
	
	/**
	 * Shows the sound tray if it is enabled.
	 * @param up Whether or not the volume is increasing.
	 */
	public function showSoundTray(up:Bool = false):Void
	{
		#if FLX_SOUND_TRAY
		if (FlxG.game.soundTray != null && soundTrayEnabled)
		{
			if (up)
				FlxG.game.soundTray.showIncrement();
			else
				FlxG.game.soundTray.showDecrement();
		}
		#end
	}
	
	function new()
	{
		AudioManager.onDefaultPlaybackDeviceChanged.add(onDefaultDeviceChanged.dispatch);
		AudioManager.onPlaybackDeviceAdded.add(onDeviceAdded.dispatch);
		AudioManager.onPlaybackDeviceRemoved.add(onDeviceRemoved.dispatch);

		#if FLX_SAVE
		loadSavedPrefs();
		#end
	}

	/**
	 * Called by the game loop to make sure the sounds get updated each frame.
	 */
	@:allow(flixel.FlxGame)
	function update(elapsed:Float):Void
	{
		if (!paused)
		{
			// pitch follows FlxG.timeScale for sounds with timeScaledPitch
			if (_lastTimeScale != FlxG.timeScale)
			{
				_lastTimeScale = FlxG.timeScale;
				if (music != null && music.exists)
					@:privateAccess music.updatePitch();
				for (sound in list.members)
					if (sound != null && sound.exists)
						@:privateAccess sound.updatePitch();
			}

			if (music != null && music.active)
				music.update(elapsed);

			if (list != null && list.active)
				list.update(elapsed);
		}

		#if FLX_KEYBOARD
		if (keysAllowed && !FlxInputText.globalManager.isTyping)
		{
			if (FlxG.keys.anyJustReleased(muteKeys))
				toggleMuted();
			else if (FlxG.keys.anyJustReleased(volumeUpKeys))
				changeVolume(0.1);
			else if (FlxG.keys.anyJustReleased(volumeDownKeys))
				changeVolume(-0.1);
		}
		#end
	}

	@:allow(flixel.FlxGame)
	function onFocusLost():Void
	{
		_lostFocusPause = canAutoPause;
		if (!_lostFocusPause)
			return;

		if (music != null)
		{
			music.onFocusLost();
		}

		for (sound in list.members)
		{
			if (sound != null)
			{
				sound.onFocusLost();
			}
		}

		// stop the output too, so nothing keeps playing while unfocused, even a sound outside this list
		// a repeated focus loss must not forget that the engine was running
		if (@:privateAccess AudioManager.active)
		{
			_suspendedAudio = true;
			AudioManager.suspend();
		}
	}

	@:allow(flixel.FlxGame)
	function onFocus():Void
	{
		if (!_lostFocusPause)
			return;
		_lostFocusPause = false;

		if (_suspendedAudio)
		{
			_suspendedAudio = false;
			AudioManager.resume();
		}

		if (music != null)
		{
			music.onFocus();
		}

		for (sound in list.members)
		{
			if (sound != null)
			{
				sound.onFocus();
			}
		}
	}

	#if FLX_SAVE
	/**
	 * Loads saved sound preferences if they exist.
	 */
	function loadSavedPrefs():Void
	{
		if (!FlxG.save.isBound)
			return;

		if (FlxG.save.data.volume != null)
		{
			volume = FlxG.save.data.volume;
		}

		if (FlxG.save.data.mute != null)
		{
			muted = FlxG.save.data.mute;
		}
	}
	#end

	inline function get_automaticDefaultDevice():Bool
		return AudioManager.automaticDefaultPlaybackDevice;

	function set_automaticDefaultDevice(value:Bool):Bool
	{
		if (AudioManager.automaticDefaultPlaybackDevice != value)
		{
			AudioManager.automaticDefaultPlaybackDevice = value;
			if (value && AudioManager.getCurrentPlaybackDeviceName() != AudioManager.getPlaybackDefaultDeviceName())
				AudioManager.refresh();
		}
		return value;
	}

	inline function get_deviceName():String
		return AudioManager.getCurrentPlaybackDeviceName();

	function set_deviceName(value:String):String
	{
		if (AudioManager.getCurrentPlaybackDeviceName() == value)
			return value;

		if (AudioManager.refresh(value))
			return value;

		AudioManager.refresh();
		return AudioManager.getCurrentPlaybackDeviceName();
	}

	/**
	 * Re-applies the volume of every sound (Codename Engine API).
	 */
	public function updateVolume():Void
	{
		if (music != null)
			@:privateAccess music.updateVolume();
		for (sound in list.members)
			if (sound != null)
				@:privateAccess sound.updateVolume();
	}

	@:haxe.warning("-WDeprecated")
	function set_volume(Volume:Float):Float
	{
		volume = FlxMath.bound(Volume, 0, 1);

		if (volumeHandler != null)
		{
			volumeHandler(muted ? 0 : volume);
		}

		onVolumeChange.dispatch(muted ? 0 : volume);

		return volume;
	}
}
#end
