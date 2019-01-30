//
//  InteractiveImageView.swift
//  TheQuantizer
//
//  Created by Simon Rodriguez on 20/01/2019.
//  Copyright © 2019 Simon Rodriguez. All rights reserved.
//

import Cocoa

/// Delegate to send orders to.
protocol ImageLoaderDelegate : class {
	func loadItems(at: [URL])
	func update(zoom : Double)
}

/// Custom NSImageView supporting scaling/filtering using a Core Animation layer.
class InteractiveImageView: NSView {
	
	public weak var delegate : ImageLoaderDelegate?
	
	// Image to display.
	public var image: NSImage? {
		didSet {
			if let img = image {
				// Show the image.
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
	private var imageLayer = CALayer()
	
	
	/// Zoom and position.
	// We split the zoom into a user-deined image zoom and a "fit-to-window" zoom.
	private var imageOffset = CGPoint(x: 0, y: 0)
	private var windowZoom : CGFloat = 1.0
	public var imageZoom = 1.0 {
		didSet {
			updateImageFrame()
		}
	}
	
	
	// Apply smoothing when zooming in/out.
	public var smoothed : Bool = true {
		didSet {
			imageLayer.magnificationFilter = smoothed ? .linear : .nearest
			imageLayer.minificationFilter = smoothed ? .linear : .nearest
			needsDisplay = true
		}
	}
	
	
	/// Init and layers setup.
	override init(frame frameRect: NSRect) {
		super.init(frame: frameRect)
		setupLayers()
	}

	required init?(coder decoder: NSCoder) {
		super.init(coder: decoder)
		setupLayers()
	}
	
	func setupLayers(){
		registerForDraggedTypes([.URL])
		updateImageFrame()
		self.wantsLayer = true
		self.layer = CALayer()
		self.layer!.addSublayer(imageLayer)
	}
	
	/// Layer frame update.
	func updateImageFrame(){
		guard let _ = image else {
			return
		}
		
		// Update window fit-to-frame zoom (see ImageAlpha for reference)
		windowZoom = min(frame.size.width/image!.size.width, frame.size.height/image!.size.height)
		if windowZoom > 1.0 {
			windowZoom = min(4.0, floor(windowZoom))
		}
		windowZoom = min(16.0,max(1.0/128.0,windowZoom))
		
		// Combine both zooms, update size.
		let finalZoom = windowZoom * CGFloat(imageZoom)
		let w = (frame.size.width + image!.size.width * finalZoom) / 2
		let h = (frame.size.height + image!.size.height * finalZoom) / 2
		
		// Udpate offset.
		imageOffset.x = max(-w+15, min(w-15, imageOffset.x))
		imageOffset.y = max(-h+15, min(h-15, imageOffset.y))
		
		// Compute final layer parameters.
		let layerPosition = CGPoint(x: imageOffset.x + bounds.size.width*0.5, y: imageOffset.y + bounds.size.height * 0.5)
		let layerCenter = CGPoint(x: layerPosition.x - image!.size.width*0.5, y: layerPosition.y - image!.size.height * 0.5)
		
		// Apply position and zoom.
		// Disable actions to avoid smooth inteproaltion over time.
		CATransaction.begin()
		CATransaction.setDisableActions(true)
		imageLayer.frame = NSMakeRect(layerCenter.x, layerCenter.y, finalZoom*image!.size.width, finalZoom*image!.size.height)
		imageLayer.position = layerPosition
		CATransaction.commit()
		needsDisplay = true
	}
	
	
	/// Interactions.
	override func scrollWheel(with event: NSEvent) {
		delegate?.update(zoom: imageZoom + 0.02*Double(event.scrollingDeltaY))
	}
	
	override func mouseDragged(with event: NSEvent) {
		imageOffset.x = imageOffset.x+event.deltaX
		imageOffset.y = imageOffset.y-event.deltaY
		updateImageFrame()
	}
	
	override func setFrameSize(_ newSize: NSSize) {
		super.setFrameSize(newSize)
		updateImageFrame()
	}
	
	
	/// Drag and drop support.
	private let filteringOptions = [NSPasteboard.ReadingOptionKey.urlReadingContentsConformToTypes: NSImage.imageTypes]
	
	func allowDragOperation(info: NSDraggingInfo) -> Bool {
		let pasteBoard = info.draggingPasteboard
		return pasteBoard.canReadObject(forClasses: [NSURL.self], options: filteringOptions)
	}
	
	override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
		return allowDragOperation(info: sender) ? .copy : NSDragOperation()
	}
	
	override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
		return allowDragOperation(info: sender)
	}
	
	override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
		// Get the first file URL and send it to the delegate.
		let pasteBoard = sender.draggingPasteboard
		if let urls = pasteBoard.readObjects(forClasses: [NSURL.self], options:filteringOptions) as? [URL], urls.count > 0 {
			delegate?.loadItems(at: urls)
			return true
		}
		return false
	}
	
}
