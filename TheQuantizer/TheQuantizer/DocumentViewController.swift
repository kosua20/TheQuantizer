//
//  ViewController.swift
//  TheQuantizer
//
//  Created by Simon Rodriguez on 16/01/2019.
//  Copyright © 2019 Simon Rodriguez. All rights reserved.
//

import Cocoa




class DocumentViewController: NSViewController {

	
	
	// Ui elements.
	@IBOutlet weak var backgroundLabel: NSTextField!
	
	@IBOutlet weak var showOriginalButton: NSButton!
	@IBAction func showOriginal(_ sender: NSButton) {
		
		if imageView.image == document.originalImage {
			imageView.image = document.newImage
		} else {
			imageView.image = document.originalImage
		}
		
	}
	
	// Colors
	
	@IBOutlet weak var colorsSlider: NSSlider!
	@IBOutlet weak var colorsStepper: NSStepper!
	@IBOutlet weak var colorsLabel: NSTextField!
	@IBOutlet weak var ditheredCheck: NSButton!
	private var colorsCount = 256
	@IBAction func colorsSliderChanged(_ sender: NSSlider) {
		colorsCount = Int(round(pow(2, sender.doubleValue)))
		colorsLabel.cell?.stringValue = "\(colorsCount)"
		colorsStepper.integerValue = colorsCount
		updateCompressedVersion()
	}
	
	@IBAction func colorsStepperChanged(_ sender: NSStepper) {
		colorsCount = sender.integerValue
		colorsLabel.cell?.stringValue = "\(colorsCount)"
		colorsSlider.doubleValue = log2(Double(colorsCount))
		updateCompressedVersion()
	}
	
	@IBAction func ditheredCheckChanged(_ sender: NSButton) {
		updateCompressedVersion()
	}
	
	// Algorithms.
	
	@IBOutlet weak var algo1Button: NSButton!
	@IBOutlet weak var algo2Button: NSButton!
	@IBOutlet weak var algo3Button: NSButton!
	
	@IBAction func algo1ButtonChanged(_ sender: NSButton) {
		algo2Button.state = .off
		algo3Button.state = .off
		updateCompressedVersion()
	}
	@IBAction func algo2ButtonChanged(_ sender: NSButton) {
		algo1Button.state = .off
		algo3Button.state = .off
		updateCompressedVersion()
	}
	@IBAction func algo3ButtonChanged(_ sender: NSButton) {
		algo2Button.state = .off
		algo1Button.state = .off
		updateCompressedVersion()
	}
	
	// Display options.
	
	@IBOutlet weak var smoothingCheck: NSButton!
	@IBAction func smoothingCheckChanged(_ sender: NSButton) {
		
	}
	
	@IBOutlet weak var scaleSlider: NSSlider!
	@IBOutlet weak var scaleStepper: NSStepper!
	@IBOutlet weak var scaleLabel: NSTextField!
	
	@IBAction func scaleSliderChanged(_ sender: NSSlider) {
		scaleLabel.cell?.stringValue = sender.doubleValue.string(fractionDigits: 1) + "x"
		scaleStepper.doubleValue = sender.doubleValue
	}
	
	@IBAction func scaleStepperChanged(_ sender: NSStepper) {
		var currentValue = sender.doubleValue
		// Are we increasing or decreasing.
		if currentValue > scaleSlider.doubleValue {
			currentValue = floor(scaleSlider.doubleValue + 1)
		} else {
			currentValue = ceil(scaleSlider.doubleValue - 1)
		}
		// Safety clamping.
		currentValue = max(scaleSlider.minValue, min(scaleSlider.maxValue, currentValue))
		
		scaleLabel.cell?.stringValue = currentValue.string(fractionDigits: 1) + "x"
		scaleSlider.doubleValue = currentValue
		sender.doubleValue = currentValue
	}
	
	
	// Image view.
	
	
	@IBOutlet weak var imageView: InteractiveImageView!
	@IBOutlet weak var progressIndicator: NSProgressIndicator!
	@IBOutlet weak var infoLabel: NSTextField!
	
	
	override func viewDidLoad() {
		super.viewDidLoad()
		infoLabel.cell!.stringValue = "No image loaded."
		let filter = NSEvent.EventTypeMask.leftMouseDown.union(.leftMouseUp)
		showOriginalButton.cell!.sendAction(on: filter)
		algo1Button.state = .on
	}
	
	
	private var document = ImageDocument()
	
	override func viewWillAppear() {
		if let aDocument = self.view.window?.windowController?.document as? ImageDocument {
			document = aDocument
			
			imageView.image = document.originalImage
			if let _ = document.originalImage {
				backgroundLabel.isHidden = true
			}
			infoLabel.cell!.stringValue = document.displayName + ": \(document.originalSize) bytes"
			updateCompressedVersion()
		}
	}
	
	func updateCompressedVersion(){
		guard let originalImg = document.originalImage else {
			return
		}
		let optionId = algo3Button.state == .on ? 3 : (algo2Button.state == .on ? 2 : 1)
		let ditheringEnabled =  ditheredCheck!.state == .on
		
		print("Running option \(optionId), with \(colorsCount) colors and \(ditheringEnabled ? "" : "no ")dithering")
		
		progressIndicator.startAnimation(self)
		
		DispatchQueue.global(qos: .background).async {
			var compressedImg : CompressedImage? = nil
			
			switch optionId {
			case 1:
				compressedImg = PngQuantCompressor.compress(buffer: self.document.originalData, w: Int(originalImg.size.width), h: Int(originalImg.size.height), colorCount: self.colorsCount, shouldDither: ditheringEnabled)
				break
			case 2:
				compressedImg = PosterizerCompressor.compress(buffer: self.document.originalData, w: Int(originalImg.size.width), h: Int(originalImg.size.height), colorCount: self.colorsCount, shouldDither: ditheringEnabled)
				break
			case 3:
				//compressedImg = BlurizerCompresser.compress(buffer: self.document.originalData, w: Int(originalImg.size.width), h: Int(originalImg.size.height), colorCount: self.colorsCount, shouldDither: ditheringEnabled)
				break
			default:
				break
			}
			
			if let newImg = compressedImg {
				
				let pc = Int(round((Double(self.document.originalSize) - Double(newImg.size))/Double(self.document.originalSize) * 100))
				
				let data = Data(bytes: newImg.data, count: newImg.size)
				
				let pathComponent = self.document.displayName + UUID().uuidString + ".png"
				var tempPath = URL(fileURLWithPath: NSTemporaryDirectory())
				tempPath.appendPathComponent(pathComponent)
				try? data.write(to: tempPath)
				self.document.newImage = NSImage(contentsOf: tempPath)
				self.document.newData = data
				try? FileManager.default.removeItem(at: tempPath)
				
				
				
				DispatchQueue.main.async {
					self.infoLabel.cell!.stringValue = self.document.displayName + ": \(newImg.size) bytes (saved \(pc)% of \(self.document.originalSize) bytes)"
					self.imageView.image = self.document.newImage
					
					
				}
			}
			
			DispatchQueue.main.async {
				self.progressIndicator.stopAnimation(self)
			}
		}
		
		
		
		
	}
	
	
	

	override var representedObject: Any? {
		didSet {
		// Update the view, if already loaded.
		}
	}


}

