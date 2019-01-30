//
//  Compressor.swift
//  TheQuantizer
//
//  Created by Simon Rodriguez on 18/01/2019.
//  Copyright © 2019 Simon Rodriguez. All rights reserved.
//

import Foundation

/// Just pack raw palettized-PNG data and it's size.
class CompressedImage {
	
	public private(set) var size : Int = 0
	public private(set) var data : UnsafeMutablePointer<UInt8>!
	
	init(buffer: UnsafeMutablePointer<UInt8>, bufferSize: Int ){
		data = buffer
		size = bufferSize
	}
	
}


protocol Compressor {
	static func compress(buffer: UnsafeMutablePointer<UInt8>, w: Int, h: Int, colorCount: Int, shouldDither: Bool) -> CompressedImage?
}


/// Quantizer using libimagequant.
class PngQuantCompressor : Compressor {
	
	static func compress(buffer: UnsafeMutablePointer<UInt8>, w: Int, h: Int, colorCount: Int, shouldDither: Bool) -> CompressedImage? {
		// Settings.
		let handle = liq_attr_create()!
		let colorCountBounded = min(256, max(2, colorCount))
		liq_set_max_colors(handle, Int32(colorCountBounded))
		
		// Initial quantization.
		let input_image = liq_image_create_rgba(handle, buffer, Int32(w), Int32(h), 0)!
		let quantization_result = UnsafeMutablePointer<OpaquePointer?>.allocate(capacity: 1)
		let ret1 = liq_image_quantize(input_image, handle, quantization_result)
		if(ret1 != LIQ_OK){
			quantization_result.deallocate()
			liq_image_destroy(input_image)
			liq_attr_destroy(handle)
			return nil
		}
		
		// Apply quantization to image (with dithering).
		let pixels_size = Int(w * h)
		let raw_8bit_pixels = UnsafeMutablePointer<UInt8>.allocate(capacity: pixels_size)
		liq_set_dithering_level(quantization_result.pointee!, shouldDither ? 1.0 : 0.0)
		liq_write_remapped_image(quantization_result.pointee!, input_image, raw_8bit_pixels, pixels_size)
		// Get the palette.
		let palette = liq_get_palette(quantization_result.pointee!)!
		
		// Write PNG header.
		let state = UnsafeMutablePointer<LodePNGState>.allocate(capacity: 1)
		lodepng_state_init(state)
		state.pointee.info_raw.colortype = LCT_PALETTE
		state.pointee.info_raw.bitdepth = 8
		state.pointee.info_png.color.colortype = LCT_PALETTE
		state.pointee.info_png.color.bitdepth = 8
		// Build array from tuple.
		let palcol = populatePalette(palette: palette.pointee)
		// Write PNG palette.
		for i in 0..<Int(palette.pointee.count) {
			lodepng_palette_add(&(state.pointee.info_png.color), palcol[i].r, palcol[i].g, palcol[i].b, palcol[i].a)
			lodepng_palette_add(&(state.pointee.info_raw), palcol[i].r, palcol[i].g, palcol[i].b, palcol[i].a)
		}
		// Finish writing PNG data.
		let output_file_data = UnsafeMutablePointer<UnsafeMutablePointer<UInt8>?>.allocate(capacity: 1)
		var output_file_size : Int = 0
		let out_status = lodepng_encode(output_file_data, &output_file_size, raw_8bit_pixels, UInt32(w), UInt32(h), state)
		
		// Bit of cleaning.
		liq_result_destroy(quantization_result.pointee!)
		liq_image_destroy(input_image)
		liq_attr_destroy(handle)
		lodepng_state_cleanup(state)
		quantization_result.deallocate()
		raw_8bit_pixels.deallocate()
		
		if (out_status != 0) {
			return nil
		}
		
		return CompressedImage(buffer: output_file_data.pointee!, bufferSize: output_file_size)
	}
	
}


// Quantizer using PngNeuQuant.
class PngNQCompressor : Compressor {
	
	static func compress(buffer: UnsafeMutablePointer<UInt8>, w: Int, h: Int, colorCount: Int, shouldDither: Bool) -> CompressedImage? {
		// Settings.
		let colorCountBounded = min(256, max(2, colorCount))
		let gamma = 1.0
		let cols = UInt32(w)
		let rows = UInt32(h)
		let sampleFactor = min(Int(1 + Double(w*h)/(512.0*512)), 10)
		
		// Init network, learn color palette.
		let network = initnet(buffer, cols*rows*4, UInt32(colorCountBounded), gamma)
		let map = UnsafeMutablePointer<UInt8>.allocate(capacity: Int(MAXNETSIZE)*4)
		let remap = UnsafeMutablePointer<UInt32>.allocate(capacity: Int(MAXNETSIZE))
		learn(network, UInt32(sampleFactor), 0)
		inxbuild(network)
		getcolormap(network, map)
		
		// Remap indexes so all tRNS chunks are together (see pngNQ code).
		var botIdx : UInt32 = 0
		var topIdx : Int32 = Int32(colorCount)-1
		for x in 0..<colorCountBounded {
			if map[4*x+3] == 255 {
				remap[x] = UInt32(topIdx)
				topIdx -= 1
			} else {
				remap[x] = botIdx
				botIdx += 1
			}
			remap[x] = UInt32(x)
		}
		if(botIdx != topIdx + 1){
			return nil
		}
		
		// Apply palette to image data (and dither).
		let indexedData = UnsafeMutablePointer<UInt8>.allocate(capacity: w*h)
		if shouldDither {
			remap_floyd(network, buffer, cols, rows, map, remap, indexedData, 1)
		} else {
			remap_simple(network, buffer, cols, rows, remap, indexedData)
		}
		
		// Write PNG header.
		let state = UnsafeMutablePointer<LodePNGState>.allocate(capacity: 1)
		lodepng_state_init(state)
		state.pointee.info_raw.colortype = LCT_PALETTE
		state.pointee.info_raw.bitdepth = 8
		state.pointee.info_png.color.colortype = LCT_PALETTE
		state.pointee.info_png.color.bitdepth = 8
		// Write PNG palette.
		var invRemap = [Int](repeating: 0, count: Int(MAXNETSIZE))
		for rid in 0..<colorCountBounded {
			invRemap[Int(remap[rid])] = rid
		}
		for i in 0..<colorCountBounded {
			let lid = invRemap[i]
			lodepng_palette_add(&(state.pointee.info_png.color), map[4*lid+0], map[4*lid+1], map[4*lid+2], map[4*lid+3])
			lodepng_palette_add(&(state.pointee.info_raw), map[4*lid+0], map[4*lid+1], map[4*lid+2], map[4*lid+3])
		}
		// Write PNG data.
		let output_file_data = UnsafeMutablePointer<UnsafeMutablePointer<UInt8>?>.allocate(capacity: 1)
		var output_file_size : Int = 0
		lodepng_encode(output_file_data, &output_file_size, indexedData, UInt32(w), UInt32(h), state)

		// Cleanup.
		lodepng_state_cleanup(state)
		remap.deallocate()
		map.deallocate()
		indexedData.deallocate()
		
		return CompressedImage(buffer: output_file_data.pointee!, bufferSize: output_file_size)
	}
	
}


// Quantizer using mediantcut-posterizer.
class PosterizerCompressor : Compressor {
	
	static var first = true
	
	static func compress(buffer: UnsafeMutablePointer<UInt8>, w: Int, h: Int, colorCount: Int, shouldDither: Bool) -> CompressedImage? {
		// We only set gamma the first time (shared global array).
		if first {
			set_gamma(1.0)
			first = false
		}
		// Posterization.
		let maxLevels = min(255, max(2, UInt32(colorCount)))
		posterizer(buffer, UInt32(w), UInt32(h), maxLevels, shouldDither)
		// Write PNG data.
		let output_file_data = UnsafeMutablePointer<UnsafeMutablePointer<UInt8>?>.allocate(capacity: 1)
		var output_file_size : Int = 0
		lodepng_encode32(output_file_data, &output_file_size, buffer, UInt32(w), UInt32(h))
		
		return CompressedImage(buffer: output_file_data.pointee!, bufferSize: output_file_size)
	}
	
}

// Note: blurizer is not provided as it is a preprocess that takes advantage of the rwpng save function, that we don't use.
/*
class BlurizerCompresser : Compressor {

	static func compress(buffer: UnsafeMutablePointer<UInt8>, w: Int, h: Int, colorCount: Int, shouldDither: Bool) -> CompressedImage? {

		let maxLevels = min(255, max(2, UInt32(colorCount)))
		blurizer(buffer, UInt32(w), UInt32(h), maxLevels)
		
		let output_file_data = UnsafeMutablePointer<UnsafeMutablePointer<UInt8>?>.allocate(capacity: 1)
		var output_file_size : Int = 0
		lodepng_encode32(output_file_data, &output_file_size, bufferCopy, UInt32(w), UInt32(h))
		return CompressedImage(buffer: output_file_data.pointee!, bufferSize: output_file_size)
	}
}
*/
