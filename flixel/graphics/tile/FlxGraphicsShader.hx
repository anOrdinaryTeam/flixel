package flixel.graphics.tile;

import openfl.display.GraphicsShader;

class FlxGraphicsShader extends GraphicsShader
{
	@:glVertexHeader("
		attribute float alpha;
		attribute vec4 colorMultiplier;
		attribute vec4 colorOffset;
		uniform bool hasColorTransform;
	")
	@:glVertexBody("
		openfl_Alphav = openfl_Alpha * alpha;

		if (hasColorTransform)
		{
			if (openfl_HasColorTransform)
			{
				openfl_ColorOffsetv = (openfl_ColorOffsetv * colorMultiplier) + (colorOffset / 255.0);
				openfl_ColorMultiplierv *= colorMultiplier;
			}
			else
			{
				openfl_ColorOffsetv = colorOffset / 255.0;
				openfl_ColorMultiplierv = colorMultiplier;
			}
		}
	")
	@:glFragmentHeader("
		uniform bool hasTransform;  // TODO: Is this still needed? Apparently, yes!
		uniform bool hasColorTransform;
		uniform vec4 _camSize;

		vec4 flixel_applyColorTransform(vec4 color)
		{
			if (!(hasTransform || openfl_HasColorTransform))
				return color;

			if (color.a == 0.0)
				return vec4(0.0, 0.0, 0.0, 0.0);

			if (openfl_HasColorTransform || hasColorTransform)
			{
				color = vec4 (color.rgb / color.a, color.a);
				vec4 mult = vec4 (openfl_ColorMultiplierv.rgb, 1.0);
				color = clamp (openfl_ColorOffsetv + (color * mult), 0.0, 1.0);

				if (color.a == 0.0)
					return vec4 (0.0, 0.0, 0.0, 0.0);

				return vec4 (color.rgb * color.a * openfl_Alphav, color.a * openfl_Alphav);
			}

			return color * openfl_Alphav;
		}

		vec4 flixel_sampleBitmap(sampler2D bitmap, vec2 coord)
		{
			return flixel_applyColorTransform(texture2D(bitmap, coord));
		}

		vec4 flixel_texture2D(sampler2D bitmap, vec2 coord)
		{
			return openfl_applyBlend(flixel_sampleBitmap(bitmap, coord));
		}

		// Codename Engine shader helpers
		vec4 applyFlixelEffects(vec4 color)
		{
			return openfl_applyBlend(flixel_applyColorTransform(color));
		}

		vec2 getCamPos(vec2 pos)
		{
			vec4 size = _camSize / openfl_TextureSize.xyxy;
			return (pos - size.xy) / size.zw;
		}

		vec2 camToOg(vec2 pos)
		{
			vec4 size = _camSize / openfl_TextureSize.xyxy;
			return size.xy + pos * size.zw;
		}

		#define map(value, min1, max1, min2, max2) min2 + (value - min1) * (max2 - min2) / (max1 - min1)
		#define textureCam(bitmap, pos) flixel_texture2D(bitmap, camToOg(pos))
	")
	@:glFragmentSource("
		#pragma header

		void main(void)
		{
			gl_FragColor = flixel_texture2D(bitmap, openfl_TextureCoordv);
		}
	")
	public function new()
	{
		super();
	}

	/**
	 * Sets the `_camSize` uniform used by `getCamPos`, `camToOg` and `textureCam`.
	 * @since CodenameCrew's Flixel
	 */
	public function setCamSize(x:Float, y:Float, width:Float, height:Float)
	{
		data._camSize.value = [x, y, width, height];
	}
}
