//
//  Compressor.swift
//  TheQuantizer
//
//  Created by Simon Rodriguez on 18/01/2019.
//  Copyright © 2019 Simon Rodriguez. All rights reserved.
//

import Foundation

class CompressedImage {
	
	public private(set) var size : Int = 0
	public private(set) var data : UnsafeMutablePointer<UInt8>!
	
	init(buffer: UnsafeMutablePointer<UInt8>, bufferSize: Int ){
		data = buffer
		size = bufferSize
	}
	
}

class PngQuantCompressor {
	
	static func compress(buffer: UnsafeMutablePointer<UInt8>, w: Int, h: Int, colorCount: Int, shouldDither: Bool) -> CompressedImage? {
		let colorCountBounded = min(256, max(2, colorCount))
		let handle = liq_attr_create()!
		
		liq_set_max_colors(handle, Int32(colorCountBounded))
		
		let input_image = liq_image_create_rgba(handle, buffer, Int32(w), Int32(h), 0)!
		let quantization_result = UnsafeMutablePointer<OpaquePointer?>.allocate(capacity: 1)
		let ret1 = liq_image_quantize(input_image, handle, quantization_result)
		
		if(ret1 != LIQ_OK){
			return nil
		}
		
		let pixels_size = Int(w * h)
		let raw_8bit_pixels = UnsafeMutablePointer<UInt8>.allocate(capacity: pixels_size)
		
		liq_set_dithering_level(quantization_result.pointee!, shouldDither ? 1.0 : 0.0)
		liq_write_remapped_image(quantization_result.pointee!, input_image, raw_8bit_pixels, pixels_size)
		
		let palette = liq_get_palette(quantization_result.pointee!)!
		
		let state = UnsafeMutablePointer<LodePNGState>.allocate(capacity: 1)
		lodepng_state_init(state)
		state.pointee.info_raw.colortype = LCT_PALETTE
		state.pointee.info_raw.bitdepth = 8
		state.pointee.info_png.color.colortype = LCT_PALETTE
		state.pointee.info_png.color.bitdepth = 8
		// Build array from tuple.
		let palcol = populatePalette(palette: palette.pointee)
		
		for i in 0..<Int(palette.pointee.count) {
			lodepng_palette_add(&(state.pointee.info_png.color), palcol[i].r, palcol[i].g, palcol[i].b, palcol[i].a)
			lodepng_palette_add(&(state.pointee.info_raw), palcol[i].r, palcol[i].g, palcol[i].b, palcol[i].a)
		}
		
		let output_file_data = UnsafeMutablePointer<UnsafeMutablePointer<UInt8>?>.allocate(capacity: 1)
		var output_file_size : Int = 0
		let out_status = lodepng_encode(output_file_data, &output_file_size, raw_8bit_pixels, UInt32(w), UInt32(h), state)
		
		if (out_status != 0) {
			return nil
		}
		// TODO: free
		liq_result_destroy(quantization_result.pointee!) // Must be freed only after you're done using the palette
		liq_image_destroy(input_image)
		liq_attr_destroy(handle)
		lodepng_state_cleanup(state)
		
		return CompressedImage(buffer: output_file_data.pointee!, bufferSize: output_file_size)
	}
	
}

class PosterizerCompressor {
	
	// Note: blurizer is not provided as it is a preprocess that takes advantage of the rwpng save function, that we don't use.
	static func compress(buffer: UnsafeMutablePointer<UInt8>, w: Int, h: Int, colorCount: Int, shouldDither: Bool) -> CompressedImage? {
		let bufferCopy = UnsafeMutablePointer<UInt8>.allocate(capacity: w*h*4)
		for i in 0..<(w*h*4) {
			bufferCopy[i] = buffer[i]
		}
		
		let maxLevels = min(255, max(2, UInt32(colorCount)))
		posterizer(bufferCopy, UInt32(w), UInt32(h), maxLevels, 1.0, shouldDither)
		
		let output_file_data = UnsafeMutablePointer<UnsafeMutablePointer<UInt8>?>.allocate(capacity: 1)
		var output_file_size : Int = 0
		lodepng_encode32(output_file_data, &output_file_size, bufferCopy, UInt32(w), UInt32(h))
		return CompressedImage(buffer: output_file_data.pointee!, bufferSize: output_file_size)
	}
	
}

// Note: blurizer is not provided as it is a preprocess that takes advantage of the rwpng save function, that we don't use.
/*
class BlurizerCompresser {

	static func compress(buffer: UnsafeMutablePointer<UInt8>, w: Int, h: Int, colorCount: Int, shouldDither: Bool) -> CompressedImage? {
		
		let bufferCopy = UnsafeMutablePointer<UInt8>.allocate(capacity: w*h*4)
		for i in 0..<(w*h*4) {
			bufferCopy[i] = buffer[i]
		}
		
		let maxLevels = min(255, max(2, UInt32(colorCount)))
		blurizer(bufferCopy, UInt32(w), UInt32(h), maxLevels, 1.0)
		
		let output_file_data = UnsafeMutablePointer<UnsafeMutablePointer<UInt8>?>.allocate(capacity: 1)
		var output_file_size : Int = 0
		lodepng_encode32(output_file_data, &output_file_size, bufferCopy, UInt32(w), UInt32(h))
		return CompressedImage(buffer: output_file_data.pointee!, bufferSize: output_file_size)
	}
}
*/
