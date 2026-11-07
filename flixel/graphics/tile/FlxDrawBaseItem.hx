package flixel.graphics.tile;

import flixel.FlxCamera;
import flixel.graphics.frames.FlxFrame;
import flixel.math.FlxMatrix;
import openfl.display.BlendMode;
import openfl.display3D.Context3DBlendTarget;
import openfl.display3D.Context3DCompareMode;
import openfl.display3D.Context3DWrapMode;
import openfl.geom.ColorTransform;
import flixel.system.FlxAssets.FlxShader;

/**
 * @author Zaphod
 */
class FlxDrawBaseItem<T>
{
	/**
	 * Tracks the total number of draw calls made each frame.
	 */
	public static var drawCalls:Int = 0;

	@:noCompletion
	@:deprecated("blendToInt() is deprecated, remove all references to it")
	public static function blendToInt(blend:BlendMode):Int
	{
		return 0; // no blend mode support in drawQuads()
	}

	public var nextTyped:T;

	public var next:FlxDrawBaseItem<T>;

	public var graphics:FlxGraphic;
	public var antialiasing:Bool = false;
	public var colored:Bool = false;
	public var hasColorOffsets:Bool = false;
	public var blend:BlendMode;
	public var blendTarget:Context3DBlendTarget = Context3DBlendTarget.BlendRenderTarget;

	/**
	 * Texture wrapping for this batch. `null` keeps the item's default
	 * (`CLAMP` for quads, `REPEAT` for triangles).
	 */
	public var wrapMode:Null<Context3DWrapMode> = null;

	/**
	 * Depth test for this batch; anything but `ALWAYS` enables depth testing while it draws
	 * (Codename Engine API).
	 */
	public var depthCompareMode:Context3DCompareMode = ALWAYS;

	@:noCompletion
	@:deprecated("blending is deprecated, remove all references to it")
	public var blending:Int = 0;

	public var type:FlxDrawItemType;

	public var shader:FlxShader;

	public var numVertices(get, never):Int;

	public var numTriangles(get, never):Int;

	public function new() {}

	public function reset():Void
	{
		graphics = null;
		antialiasing = false;
		wrapMode = null;
		depthCompareMode = ALWAYS;
		nextTyped = null;
		next = null;
	}

	public function dispose():Void
	{
		graphics = null;
		next = null;
		type = null;
		nextTyped = null;
	}

	public function render(camera:FlxCamera):Void
	{
		drawCalls++;
	}

	public function addQuad(frame:FlxFrame, matrix:FlxMatrix, ?transform:ColorTransform):Void {}

	function get_numVertices():Int
	{
		return 0;
	}

	function get_numTriangles():Int
	{
		return 0;
	}

	/**
	 * Enables the batch's depth test on the camera canvas, if it has one.
	 * Returns whether `clearDepthOverride` has to be called after drawing.
	 */
	inline function applyDepthOverride(camera:FlxCamera):Bool
	{
		if (depthCompareMode == null || depthCompareMode == ALWAYS)
			return false;

		camera.canvas.graphics.overrideDepthTest(true, depthCompareMode);
		return true;
	}

	inline function clearDepthOverride(camera:FlxCamera):Void
	{
		camera.canvas.graphics.overrideDepthTest(false, ALWAYS);
	}
}

enum FlxDrawItemType
{
	TILES;
	TRIANGLES;
}

