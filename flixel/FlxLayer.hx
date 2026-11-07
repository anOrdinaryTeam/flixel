package flixel;

import flixel.graphics.FlxGraphic;
import flixel.graphics.frames.FlxFrame;
import flixel.graphics.tile.FlxDrawBaseItem;
import flixel.graphics.tile.FlxDrawQuadsItem;
import flixel.graphics.tile.FlxDrawTrianglesItem;
import flixel.math.FlxMatrix;
import flixel.system.FlxAssets.FlxShader;
import openfl.display.BitmapData;
import openfl.display.BlendMode;
import openfl.display3D.Context3DBlendTarget;
import openfl.display3D.Context3DWrapMode;
import openfl.geom.ColorTransform;

using flixel.util.FlxColorTransformUtil;

/**
 * A draw layer, ported from Codename Engine's flixel onto Shadow's draw items.
 *
 * Sprites whose `layer` is set to this object queue their quads here instead of
 * on the camera, wherever they sit in the scene. When the layer itself is drawn,
 * everything it collected this frame is spliced into its camera's draw stack at
 * that point, in order. This lets sprites from different groups share batches
 * and draw at the layer's depth.
 *
 * Only `camera` (the layer's first camera) is supported; sprites drawn to any
 * other camera fall back to drawing directly on it.
 */
@:access(flixel.FlxCamera)
class FlxLayer extends FlxBasic
{
	var _currentDrawItem:FlxDrawBaseItem<Dynamic>;
	var _headOfDrawStack:FlxDrawBaseItem<Dynamic>;
	var _headTiles:FlxDrawQuadsItem;
	var _headTriangles:FlxDrawTrianglesItem;

	static var _storageTilesHead:FlxDrawQuadsItem;
	static var _storageTrianglesHead:FlxDrawTrianglesItem;

	public function new()
	{
		super();
		FlxG.signals.preDraw.add(clearDrawStack);
	}

	override function destroy():Void
	{
		FlxG.signals.preDraw.remove(clearDrawStack);
		clearDrawStack();
		super.destroy();
	}

	@:noCompletion
	public function startQuadBatch(graphic:FlxGraphic, colored:Bool, hasColorOffsets:Bool = false, ?blend:BlendMode, smooth:Bool = false, ?shader:FlxShader,
			?blendTarget:Context3DBlendTarget, ?wrapMode:Context3DWrapMode):FlxDrawQuadsItem
	{
		if (_currentDrawItem != null
			&& _currentDrawItem == _headTiles
			&& _headTiles.graphics == graphic
			&& _headTiles.colored == colored
			&& _headTiles.hasColorOffsets == hasColorOffsets
			&& _headTiles.blend == blend
			&& _headTiles.blendTarget == blendTarget
			&& _headTiles.wrapMode == wrapMode
			&& _headTiles.antialiasing == smooth
			&& _headTiles.shader == shader
			&& FlxCamera.isBatchableBlend(blend, blendTarget))
		{
			return _headTiles;
		}

		var item = _storageTilesHead;
		if (item != null)
		{
			_storageTilesHead = item.nextTyped;
			item.reset();
		}
		else
		{
			item = new FlxDrawQuadsItem();
		}

		if (graphic.isDestroyed)
			throw 'Cannot queue ${graphic.key}. This sprite was destroyed.';

		item.graphics = graphic;
		item.antialiasing = smooth;
		item.colored = colored;
		item.hasColorOffsets = hasColorOffsets;
		item.blend = blend;
		item.blendTarget = blendTarget;
		item.wrapMode = wrapMode;
		item.shader = shader;

		item.nextTyped = _headTiles;
		_headTiles = item;

		pushItem(item);
		return item;
	}

	@:noCompletion
	public function startTrianglesBatch(graphic:FlxGraphic, smoothing:Bool = false, isColored:Bool = false, ?blend:BlendMode, ?hasColorOffsets:Bool,
			?shader:FlxShader, ?blendTarget:Context3DBlendTarget, ?wrapMode:Context3DWrapMode):FlxDrawTrianglesItem
	{
		if (blendTarget == null)
			blendTarget = Context3DBlendTarget.BlendRenderTarget;

		if (_currentDrawItem != null
			&& _currentDrawItem == _headTriangles
			&& _headTriangles.graphics == graphic
			&& _headTriangles.antialiasing == smoothing
			&& _headTriangles.colored == isColored
			&& _headTriangles.blend == blend
			&& _headTriangles.blendTarget == blendTarget
			&& _headTriangles.wrapMode == wrapMode
			&& _headTriangles.hasColorOffsets == hasColorOffsets
			&& _headTriangles.shader == shader
			&& FlxCamera.isBatchableBlend(blend, blendTarget))
		{
			return _headTriangles;
		}

		return getNewDrawTrianglesItem(graphic, smoothing, isColored, blend, hasColorOffsets, shader, blendTarget, wrapMode);
	}

	/**
	 * Always starts a new triangles batch (Codename Engine API).
	 */
	@:noCompletion
	public function getNewDrawTrianglesItem(graphic:FlxGraphic, smoothing:Bool = false, isColored:Bool = false, ?blend:BlendMode, ?hasColorOffsets:Bool,
			?shader:FlxShader, ?blendTarget:Context3DBlendTarget, ?wrapMode:Context3DWrapMode):FlxDrawTrianglesItem
	{
		if (blendTarget == null)
			blendTarget = Context3DBlendTarget.BlendRenderTarget;

		var item = _storageTrianglesHead;
		if (item != null)
		{
			_storageTrianglesHead = item.nextTyped;
			item.reset();
		}
		else
		{
			item = new FlxDrawTrianglesItem();
		}

		item.graphics = graphic;
		item.antialiasing = smoothing;
		item.colored = isColored;
		item.blend = blend;
		item.blendTarget = blendTarget;
		item.wrapMode = wrapMode;
		item.hasColorOffsets = hasColorOffsets;
		item.shader = shader;

		item.nextTyped = _headTriangles;
		_headTriangles = item;

		pushItem(item);
		return item;
	}

	/**
	 * Splices a single draw item onto a camera's draw stack (Codename Engine API).
	 */
	public function injectDrawCall(camera:FlxCamera, drawItem:FlxDrawBaseItem<Dynamic>):Void
	{
		injectDrawCalls(camera, drawItem, drawItem);
	}

	inline function pushItem(item:FlxDrawBaseItem<Dynamic>):Void
	{
		if (_headOfDrawStack == null)
			_headOfDrawStack = item;

		if (_currentDrawItem != null)
			_currentDrawItem.next = item;

		_currentDrawItem = item;
	}

	@:noCompletion
	function clearDrawStack():Void
	{
		var currTiles = _headTiles;
		var newTilesHead;

		while (currTiles != null)
		{
			newTilesHead = currTiles.nextTyped;
			currTiles.reset();
			currTiles.nextTyped = _storageTilesHead;
			_storageTilesHead = currTiles;
			currTiles = newTilesHead;
		}

		var currTriangles = _headTriangles;
		var newTrianglesHead;

		while (currTriangles != null)
		{
			newTrianglesHead = currTriangles.nextTyped;
			currTriangles.reset();
			currTriangles.nextTyped = _storageTrianglesHead;
			_storageTrianglesHead = currTriangles;
			currTriangles = newTrianglesHead;
		}

		_currentDrawItem = null;
		_headOfDrawStack = null;
		_headTiles = null;
		_headTriangles = null;
	}

	/**
	 * Queues a sprite's quad on this layer. Mirrors `FlxCamera.drawPixels`.
	 */
	public function drawPixels(sprite:FlxSprite, camera:FlxCamera, ?frame:FlxFrame, ?pixels:BitmapData, matrix:FlxMatrix, ?transform:ColorTransform,
			?blend:BlendMode, ?smoothing:Bool = false, ?shader:FlxShader, ?blendTarget:Context3DBlendTarget, ?wrapMode:Context3DWrapMode):Void
	{
		// blitting has no draw stack to batch into, and other cameras are not tracked
		if (FlxG.renderBlit || camera != this.camera)
		{
			camera.drawPixels(frame, pixels, matrix, transform, blend, smoothing, shader, blendTarget, wrapMode);
			return;
		}

		var isColored = (transform != null && transform.hasRGBMultipliers());
		var hasColorOffsets = (transform != null && transform.hasRGBAOffsets());

		#if FLX_RENDER_TRIANGLE
		final drawItem = startTrianglesBatch(frame.parent, smoothing, isColored, blend, hasColorOffsets, shader, blendTarget, wrapMode);
		#else
		final drawItem = startQuadBatch(frame.parent, isColored, hasColorOffsets, blend, smoothing, shader, blendTarget, wrapMode);
		#end
		drawItem.addQuad(frame, matrix, transform);
	}

	/**
	 * Splices a draw item chain (`head` ... `tail`) onto the end of a camera's draw stack.
	 */
	public static function injectDrawCalls(camera:FlxCamera, head:FlxDrawBaseItem<Dynamic>, tail:FlxDrawBaseItem<Dynamic>):Void
	{
		if (head == null)
			return;

		tail.next = null;

		if (camera._headOfDrawStack == null)
			camera._headOfDrawStack = head;
		else
			camera._currentDrawItem.next = head;

		camera._currentDrawItem = tail;
	}

	override public function draw():Void
	{
		super.draw();

		if (FlxG.renderTile && camera != null)
			injectDrawCalls(camera, _headOfDrawStack, _currentDrawItem);
	}
}
