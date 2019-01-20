//
//  InteractiveImageView.swift
//  TheQuantizer
//
//  Created by Simon Rodriguez on 20/01/2019.
//  Copyright © 2019 Simon Rodriguez. All rights reserved.
//

import Cocoa

class InteractiveImageView: NSView {

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


	private var imageLayer = CALayer()
	private var imageOffset = CGPoint(x: 0, y: 0)
	private var imageZoom = 1.0


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
		print("bup")
		updateImageFrame()
	}
	
	
	func setupLayers(){
		updateImageFrame()
		self.wantsLayer = true
		self.layer = CALayer()
		self.layer!.addSublayer(imageLayer)
	}
	
	
	func updateImageFrame(){
		guard let _ = image else {
			return
		}
		
		var zoom = min(frame.size.width/image!.size.width, frame.size.height/image!.size.height)
		if zoom > 1.0 {
			zoom = min(4.0, floor(zoom))
		}
		
		imageZoom = Double(min(16.0,max(1.0/128.0,zoom)))
		
		
		
		
		
		
		let w = (frame.size.width + image!.size.width * zoom) / 2
		let h = (frame.size.height + image!.size.height * zoom) / 2
		
		imageOffset.x = max(-w+15, min(w-15, imageOffset.x))
		imageOffset.y = max(-h+15, min(h-15, imageOffset.y))
		
		// Apply zoom
		let layerPosition = CGPoint(x: imageOffset.x + bounds.size.width*0.5, y: imageOffset.y + bounds.size.height * 0.5)
		let layerCenter = CGPoint(x: layerPosition.x - image!.size.width*0.5, y: layerPosition.y - image!.size.height * 0.5)
		
		
		CATransaction.begin()
		CATransaction.setDisableActions(true)
		imageLayer.frame = NSMakeRect(layerCenter.x, layerCenter.y, zoom*image!.size.width, zoom*image!.size.height)
		CATransaction.commit()
		
		
		// Apply position
		CATransaction.begin()
		CATransaction.setDisableActions(true)
		imageLayer.position = layerPosition
		CATransaction.commit()
		
		needsDisplay = true
	}
	
	
	
}
