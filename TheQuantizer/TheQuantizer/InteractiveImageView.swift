//
//  InteractiveImageView.swift
//  TheQuantizer
//
//  Created by Simon Rodriguez on 20/01/2019.
//  Copyright © 2019 Simon Rodriguez. All rights reserved.
//

import Cocoa

protocol ImageLoaderDelegate : class {
	func loadItem(at: URL)
	func update(zoom : Double)
}

class InteractiveImageView: NSView {
	
	public weak var delegate : ImageLoaderDelegate?
	
	public var image: NSImage? {
		didSet {
			if let img = image {
				imageLayer.isHidden = false
				CATransaction.begin()
				CATransaction.setDisableActions(true)
				imageLayer.contents = img
				CATransaction.commit()
				
			} else {
				imageLayer.isHidden = true
			}
			needsDisplay = true
		}


	}
	
	public var smoothed : Bool = true {
		didSet {
			imageLayer.magnificationFilter = smoothed ? .linear : .nearest
			imageLayer.minificationFilter = smoothed ? .linear : .nearest
			needsDisplay = true
		}
	}

	private var imageLayer = CALayer()
	private var imageOffset = CGPoint(x: 0, y: 0)
	public var imageZoom = 1.0 {
		didSet {
			updateImageFrame()
		}
	}
	
	private var windowZoom : CGFloat = 1.0

	override init(frame frameRect: NSRect) {
		super.init(frame: frameRect)
		setupLayers()
	}


	required init?(coder decoder: NSCoder) {
		super.init(coder: decoder)
		setupLayers()
	}
	
	
	override func setFrameSize(_ newSize: NSSize) {
		super.setFrameSize(newSize)
		updateImageFrame()
	}
	
	
	func setupLayers(){
		registerForDraggedTypes([.URL])
		
		updateImageFrame()
		self.wantsLayer = true
		self.layer = CALayer()
		self.layer!.addSublayer(imageLayer)
	}
	
	
	private let filteringOptions = [NSPasteboard.ReadingOptionKey.urlReadingContentsConformToTypes: NSImage.imageTypes]
	
	func allowDragOperation(info: NSDraggingInfo) -> Bool {
		let pasteBoard = info.draggingPasteboard
		
		if pasteBoard.canReadObject(forClasses: [NSURL.self], options: filteringOptions) {
			return true
		}
		return false
	}
	
	override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
		return allowDragOperation(info: sender) ? .copy : NSDragOperation()
	}
	
	override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
		return allowDragOperation(info: sender)
	}
	
	override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
		let pasteBoard = sender.draggingPasteboard
		if let urls = pasteBoard.readObjects(forClasses: [NSURL.self], options:filteringOptions) as? [URL], urls.count > 0 {
			delegate?.loadItem(at: urls.first!)
			return true
		}
		return false
	}
	
	override func scrollWheel(with event: NSEvent) {
		delegate?.update(zoom: imageZoom + 0.02*Double(event.scrollingDeltaY))
	}
	
	override func mouseDragged(with event: NSEvent) {
		print(event.deltaX)
	}
	
	func updateImageFrame(){
		guard let _ = image else {
			return
		}
		
		windowZoom = min(frame.size.width/image!.size.width, frame.size.height/image!.size.height)
		if windowZoom > 1.0 {
			windowZoom = min(4.0, floor(windowZoom))
		}
		windowZoom = min(16.0,max(1.0/128.0,windowZoom))
		
		let finalZoom = windowZoom * CGFloat(imageZoom)
		let w = (frame.size.width + image!.size.width * finalZoom) / 2
		let h = (frame.size.height + image!.size.height * finalZoom) / 2
		
		imageOffset.x = max(-w+15, min(w-15, imageOffset.x))
		imageOffset.y = max(-h+15, min(h-15, imageOffset.y))
		
		// Apply zoom
		let layerPosition = CGPoint(x: imageOffset.x + bounds.size.width*0.5, y: imageOffset.y + bounds.size.height * 0.5)
		let layerCenter = CGPoint(x: layerPosition.x - image!.size.width*0.5, y: layerPosition.y - image!.size.height * 0.5)
		
		
		CATransaction.begin()
		CATransaction.setDisableActions(true)
		imageLayer.frame = NSMakeRect(layerCenter.x, layerCenter.y, finalZoom*image!.size.width, finalZoom*image!.size.height)
		CATransaction.commit()
		
		
		// Apply position
		CATransaction.begin()
		CATransaction.setDisableActions(true)
		imageLayer.position = layerPosition
		CATransaction.commit()
		
		needsDisplay = true
	}
	
	
	
}
