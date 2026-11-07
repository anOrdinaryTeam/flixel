package flixel.graphics.tile;

import flixel.FlxCamera;
import flixel.graphics.frames.FlxFrame;
import flixel.graphics.tile.FlxDrawBaseItem.FlxDrawItemType;
import flixel.math.FlxMatrix;
import flixel.system.FlxAssets.FlxShader;
import openfl.Vector;
import openfl.display.ShaderParameter;
import openfl.geom.ColorTransform;

class FlxDrawQuadsItem extends FlxDrawBaseItem<FlxDrawQuadsItem>
{
	static inline var VERTICES_PER_QUAD = 4;

	var rects:Vector<Float>;
	var transforms:Vector<Float>;
	var alphas:Array<Float>;
	var colorMultipliers:Array<Float>;
	var colorOffsets:Array<Float>;

	public function new()
	{
		super();
		type = FlxDrawItemType.TILES;
		rects = new Vector<Float>();
		transforms = new Vector<Float>();
		alphas = [];
	}

	override public function reset():Void
	{
		super.reset();
		rects.length = 0;
		transforms.length = 0;
		alphas.resize(0);
		if (colorMultipliers != null)
			colorMultipliers.resize(0);
		if (colorOffsets != null)
			colorOffsets.resize(0);
	}

	override public function dispose():Void
	{
		super.dispose();
		rects = null;
		transforms = null;
		alphas = null;
		colorMultipliers = null;
		colorOffsets = null;
	}

	override public function addQuad(frame:FlxFrame, matrix:FlxMatrix, ?transform:ColorTransform):Void
	{
		var rect = frame.frame;
		rects.push(rect.x);
		rects.push(rect.y);
		rects.push(rect.width);
		rects.push(rect.height);

		transforms.push(matrix.a);
		transforms.push(matrix.b);
		transforms.push(matrix.c);
		transforms.push(matrix.d);
		transforms.push(matrix.tx);
		transforms.push(matrix.ty);

		var alphaMultiplier = transform != null ? transform.alphaMultiplier : 1.0;
		for (i in 0...VERTICES_PER_QUAD)
			alphas.push(alphaMultiplier);

		if (colored || hasColorOffsets)
		{
			if (colorMultipliers == null)
				colorMultipliers = [];

			if (colorOffsets == null)
				colorOffsets = [];

			for (i in 0...VERTICES_PER_QUAD)
			{
				if (transform != null)
				{
					colorMultipliers.push(transform.redMultiplier);
					colorMultipliers.push(transform.greenMultiplier);
					colorMultipliers.push(transform.blueMultiplier);

					colorOffsets.push(transform.redOffset);
					colorOffsets.push(transform.greenOffset);
					colorOffsets.push(transform.blueOffset);
					colorOffsets.push(transform.alphaOffset);
				}
				else
				{
					colorMultipliers.push(1);
					colorMultipliers.push(1);
					colorMultipliers.push(1);

					colorOffsets.push(0);
					colorOffsets.push(0);
					colorOffsets.push(0);
					colorOffsets.push(0);
				}

				colorMultipliers.push(1);
			}
		}
	}

	/**
	 * Adds a quad with one color transform per vertex (top-left, top-right,
	 * bottom-right, bottom-left), for gradients (Codename Engine API).
	 */
	public function addColoredQuad(frame:FlxFrame, matrix:FlxMatrix, ?transforms:Array<ColorTransform>):Void
	{
		var rect = frame.frame;
		rects.push(rect.x);
		rects.push(rect.y);
		rects.push(rect.width);
		rects.push(rect.height);

		transforms_push(matrix);

		final writeColors = colored || hasColorOffsets;
		if (writeColors)
		{
			if (colorMultipliers == null)
				colorMultipliers = [];
			if (colorOffsets == null)
				colorOffsets = [];
		}

		for (i in 0...VERTICES_PER_QUAD)
		{
			final transform = transforms != null && i < transforms.length ? transforms[i] : null;
			alphas.push(transform != null ? transform.alphaMultiplier : 1.0);

			if (writeColors)
			{
				colorMultipliers.push(transform != null ? transform.redMultiplier : 1);
				colorMultipliers.push(transform != null ? transform.greenMultiplier : 1);
				colorMultipliers.push(transform != null ? transform.blueMultiplier : 1);
				colorMultipliers.push(1);

				colorOffsets.push(transform != null ? transform.redOffset : 0);
				colorOffsets.push(transform != null ? transform.greenOffset : 0);
				colorOffsets.push(transform != null ? transform.blueOffset : 0);
				colorOffsets.push(transform != null ? transform.alphaOffset : 0);
			}
		}
	}

	inline function transforms_push(matrix:FlxMatrix):Void
	{
		transforms.push(matrix.a);
		transforms.push(matrix.b);
		transforms.push(matrix.c);
		transforms.push(matrix.d);
		transforms.push(matrix.tx);
		transforms.push(matrix.ty);
	}

	#if !flash
	override public function render(camera:FlxCamera):Void
	{
		if (rects.length == 0)
			return;

		// TODO: catch this error when the dev actually messes up, not in the draw phase
		if (shader == null && graphics.isDestroyed)
			throw 'Attempted to render an invalid FlxDrawItem, did you destroy a cached sprite?';

		final shader = shader != null ? shader : graphics.shader;
		shader.bitmap.input = graphics.bitmap;
		shader.bitmap.filter = (camera.antialiasing || antialiasing) ? LINEAR : NEAREST;
		shader.bitmap.blendTarget = blendTarget;
		shader.bitmap.wrap = wrapMode != null ? wrapMode : CLAMP;
		shader.alpha.value = alphas;

		if (colored || hasColorOffsets)
		{
			shader.colorMultiplier.value = colorMultipliers;
			shader.colorOffset.value = colorOffsets;
		}

		setParameterValue(shader.hasTransform, true);
		setParameterValue(shader.hasColorTransform, colored || hasColorOffsets);

		camera.canvas.graphics.overrideBlendMode(blend);
		final depthOverride = applyDepthOverride(camera);
		camera.canvas.graphics.beginShaderFill(shader);
		camera.canvas.graphics.drawQuads(rects, null, transforms);
		camera.canvas.graphics.endFill();
		if (depthOverride)
			clearDepthOverride(camera);
		super.render(camera);
	}

	inline function setParameterValue(parameter:ShaderParameter<Bool>, value:Bool):Void
	{
		if (parameter.value == null)
			parameter.value = [];
		parameter.value[0] = value;
	}
	#end
}
