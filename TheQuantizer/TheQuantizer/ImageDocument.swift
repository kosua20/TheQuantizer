//
//  Document.swift
//  TheQuantizer
//
//  Created by Simon Rodriguez on 16/01/2019.
//  Copyright © 2019 Simon Rodriguez. All rights reserved.
//

import Cocoa

class ImageDocument: NSDocument {

	// Store original image info and data.
	public private(set) var originalImage : NSImage? = nil
	public private(set) var originalSize = 0
	public private(set) var originalData = UnsafeMutablePointer<UInt8>.allocate(capacity: 1)
	// Quantization result data and image.
	public var newImage : NSImage? = nil
	public var newData : Data? = nil
	
	
	/// Document boilerplate.
	override init() {
	    super.init()
		// Add your subclass-specific initialization here.
	}
	
	override class var autosavesInPlace: Bool {
		return false
	}
	
	override func makeWindowControllers() {
		// Returns the Storyboard that contains your Document window.
		let storyboard = NSStoryboard(name: NSStoryboard.Name("Main"), bundle: nil)
		let windowController = storyboard.instantiateController(withIdentifier: NSStoryboard.SceneIdentifier("Document Window Controller")) as! NSWindowController
		self.addWindowController(windowController)
	}

	/// Reading and saving image files.
	override func read(from data: Data, ofType typeName: String) throws {
		// TODO: modify to support more image file types as input.
		if typeName != "PngType" {
			let err = InvalidFileError()
			throw err
		}
		
		if let img = NSImage(data: data) {
			originalImage = img
			originalSize = data.count
			originalData = img.rgbaRepresentation()
		} else {
			throw InvalidFileError()
		}
		
	}

	override func data(ofType typeName: String) throws -> Data {
		if let _ = newData {
			return newData!
		}
		throw UnprocessedFileError()
	}
	
}

