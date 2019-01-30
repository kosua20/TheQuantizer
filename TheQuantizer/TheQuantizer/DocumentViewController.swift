//
//  ViewController.swift
//  TheQuantizer
//
//  Created by Simon Rodriguez on 16/01/2019.
//  Copyright © 2019 Simon Rodriguez. All rights reserved.
//

import Cocoa

class DocumentViewController: NSViewController  {
	
	/// Methods.
	private var optionId = 0
	@IBAction func methodMenuChanged(_ sender: NSPopUpButton) {
		optionId = sender.selectedTag()
		updateCompressedVersion()
	}
	
	
	/// Method settings.
	private var colorsCount = 256
	@IBOutlet weak var colorsLabel: NSTextField!
	
	@IBOutlet weak var colorsSlider: NSSlider!
	@IBAction func colorsSliderChanged(_ sender: NSSlider) {
		colorsCount = Int(round(pow(2, sender.doubleValue)))
		colorsLabel.cell?.stringValue = "\(colorsCount)"
		colorsStepper.integerValue = colorsCount
		updateCompressedVersion()
	}
	
	@IBOutlet weak var colorsStepper: NSStepper!
	@IBAction func colorsStepperChanged(_ sender: NSStepper) {
		colorsCount = sender.integerValue
		colorsLabel.cell?.stringValue = "\(colorsCount)"
		colorsSlider.doubleValue = log2(Double(colorsCount))
		updateCompressedVersion()
	}
	
	@IBOutlet weak var ditheredCheck: NSButton!
	@IBAction func ditheredCheckChanged(_ sender: NSButton) {
		updateCompressedVersion()
	}
	
	@IBOutlet weak var noAlphaCheck: NSButton!
	@IBAction func noAlphaChecked(_ sender: NSButton) {
		updateCompressedVersion()
	}
	
	
	/// Display settings.
	@IBOutlet weak var scaleLabel: NSTextField!
	
	@IBOutlet weak var scaleSlider: NSSlider!
	@IBAction func scaleSliderChanged(_ sender: NSSlider) {
		update(zoom: sender.doubleValue)
	}
	
	@IBOutlet weak var scaleStepper: NSStepper!
	@IBAction func scaleStepperChanged(_ sender: NSStepper) {
		var currentValue = sender.doubleValue
		// Are we increasing or decreasing.
		if currentValue > scaleSlider.doubleValue {
			currentValue = floor(scaleSlider.doubleValue + 1)
		} else {
			currentValue = ceil(scaleSlider.doubleValue - 1)
		}
		update(zoom: currentValue)
	}
	
	@IBOutlet weak var showOriginalButton: NSButton!
	@IBAction func showOriginal(_ sender: NSButton) {
		
		if imageView.image == document.originalImage {
			imageView.image = document.newImage
		} else {
			imageView.image = document.originalImage
		}
		
	}
	
	@IBOutlet weak var smoothingCheck: NSButton!
	@IBAction func smoothingCheckChanged(_ sender: NSButton) {
		imageView.smoothed = sender.state == .on
	}
	
	
	/// Image view and infos.
	@IBOutlet weak var imageView: InteractiveImageView!
	@IBOutlet weak var progressIndicator: NSProgressIndicator!
	@IBOutlet weak var infoLabel: NSTextField!
	@IBOutlet weak var backgroundLabel: NSTextField!
	
	
	private var document = ImageDocument()
	private let semaphore = DispatchSemaphore(value: 1) //< Semaphore for processing threading.
	
	
	/// View setup.
	override func viewDidLoad() {
		super.viewDidLoad()
		infoLabel.cell!.stringValue = "No image loaded."
		imageView.delegate = self
		// We need to register the showOriginal button as a "hold to show" button.
		let filter = NSEvent.EventTypeMask.leftMouseDown.union(.leftMouseUp)
		showOriginalButton.cell!.sendAction(on: filter)
	}
	
	override func viewWillAppear() {
		// if a document is available, display it.
		if let aDocument = self.view.window?.windowController?.document as? ImageDocument, let originImage = aDocument.originalImage {
			document = aDocument
			imageView.image = originImage
			backgroundLabel.isHidden = true
			infoLabel.cell!.stringValue = document.displayName + ": \(document.originalSize) bytes"
			updateCompressedVersion()
		}
	}
	
	
	/// Compression process.
	func updateCompressedVersion(){
		
		// Check if image available.
		guard let originalImg = document.originalImage else {
			return
		}
		
		// Gather settings.
		let ditheringEnabled = ditheredCheck!.state == .on
		let noAlphaEnabled = noAlphaCheck!.state == .on
		
		DispatchQueue.global(qos: .userInteractive ).async {
			// Wait for the compressors to be available.
			// The C libraries are using some global static state preventing us from running multiple instances in parallel (technically I solved this but let's be cautious).
			// At the same time, we want to run the compression on a background thread as we need to update the progress indicator.
			// So we use a semaphore to lock/unlock access to the compressors.
			self.semaphore.wait()
			
			// Start animation.
			DispatchQueue.main.async {
				self.progressIndicator.startAnimation(self)
			}
			
			// Duplicate buffer: some C algorithms will work in place.
			let w = originalImg.representations.first?.pixelsWide ?? Int(originalImg.size.width)
			let h = originalImg.representations.first?.pixelsHigh ?? Int(originalImg.size.height)
			let bufferCopy = UnsafeMutablePointer<UInt8>.allocate(capacity: w*h*4)
			for i in 0..<w*h {
				let baseInd = 4*i
				bufferCopy[baseInd+0] = self.document.originalData[baseInd+0]
				bufferCopy[baseInd+1] = self.document.originalData[baseInd+1]
				bufferCopy[baseInd+2] = self.document.originalData[baseInd+2]
				// Remove alpha if needed.
				bufferCopy[baseInd+3] = noAlphaEnabled ? 255 : self.document.originalData[baseInd+3]
			}
			
			// Do the stuuuuff.
			// It returns a compressed image containing the raw output PNG data and the file size.
			var compressedImg : CompressedImage? = nil
			switch self.optionId {
			case 0:
				compressedImg = PngQuantCompressor.compress(buffer: bufferCopy, w: w, h: h, colorCount: self.colorsCount, shouldDither: ditheringEnabled)
				break
			case 1:
				compressedImg = PosterizerCompressor.compress(buffer: bufferCopy, w: w, h: h, colorCount: self.colorsCount, shouldDither: ditheringEnabled)
				break
			case 2:
				compressedImg = PngNQCompressor.compress(buffer: bufferCopy, w: w, h: h, colorCount: self.colorsCount, shouldDither: ditheringEnabled)
				break
			default:
				break
			}
			// We can free the copy now.
			bufferCopy.deallocate()
			
			// If the compression succeeded
			if let newImg = compressedImg {
				
				// Compute size gain.
				let pc = Int(round((Double(self.document.originalSize) - Double(newImg.size))/Double(self.document.originalSize) * 100))
				
				// Create data from the image.
				let data = Data(bytes: newImg.data, count: newImg.size)
				self.document.newImage =  NSImage(data: data)
				self.document.newData = data
				// We don't need the initial data anymore.
				newImg.data.deallocate()
				
				// Update GUI.
				DispatchQueue.main.async {
					self.infoLabel.cell!.stringValue = self.document.displayName + ": \(newImg.size) bytes (saved \(pc)% of \(self.document.originalSize) bytes)"
					self.imageView.image = self.document.newImage
					self.progressIndicator.stopAnimation(self)
					// Release the compressors.
					self.semaphore.signal()
				}
			} else {
				// Else just stop.
				DispatchQueue.main.async {
					self.progressIndicator.stopAnimation(self)
					self.semaphore.signal()
				}
			}
		}
	}

	override var representedObject: Any? {
		didSet {
		// Update the view, if already loaded.
		}
	}

}

/// Delegate to receive orders from the view.
extension DocumentViewController : ImageLoaderDelegate {
	
	func loadItems(at paths: [URL]) {
		for path in paths {
		// Open a new tab/window with the new document.
			NSDocumentController.shared.openDocument(withContentsOf: path, display: true, completionHandler: {_,_,_ in })
		}
	}
	
	func update(zoom : Double){
		// Update the zoom value.
		let newZoom = min(max(zoom, 0.1), scaleSlider.maxValue)
		scaleLabel.cell?.stringValue = newZoom.string(fractionDigits: 1) + "x"
		scaleStepper.doubleValue = newZoom
		scaleSlider.doubleValue = newZoom
		imageView.imageZoom = newZoom
	}
	
}
