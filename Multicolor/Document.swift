//
//  Document.swift
//  Multicolor
//
//  Created by lucian on 12/3/17.
//  Copyright © 2017 Lucian Marin. All rights reserved.
//

import Cocoa

class Document: NSDocument {
    @IBOutlet var mainWindow: NSWindow!
    @IBOutlet weak var splitView: NSSplitView!
    
    @IBOutlet weak var firstView: NSView!
    @IBOutlet weak var secondView: NSView!
    @IBOutlet weak var thirdView: NSView!
    @IBOutlet weak var fourthView: NSView!
    @IBOutlet weak var fifthView: NSView!

    @IBOutlet weak var firstCW: NSColorWell!
    @IBOutlet weak var secondCW: NSColorWell!
    @IBOutlet weak var thirdCW: NSColorWell!
    @IBOutlet weak var fourthCW: NSColorWell!
    @IBOutlet weak var fifthCW: NSColorWell!

    @IBOutlet weak var firstInline: NSButton!
    @IBOutlet weak var secondInline: NSButton!
    @IBOutlet weak var thirdInline: NSButton!
    @IBOutlet weak var fourthInline: NSButton!
    @IBOutlet weak var fifthInline: NSButton!

    @IBOutlet weak var firstRecessed: NSButton!
    @IBOutlet weak var secondRecessed: NSButton!
    @IBOutlet weak var thirdRecessed: NSButton!
    @IBOutlet weak var fourthRecessed: NSButton!
    @IBOutlet weak var fifthRecessed: NSButton!

    @IBOutlet weak var toggle: NSToolbarItem!

    func getLuminance(color: NSColor) -> CGFloat {
        let red = color.redComponent
        let green = color.greenComponent
        let blue = color.blueComponent
        var R = CGFloat(0)
        var G = CGFloat(0)
        var B = CGFloat(0)
        if (red <= 0.03928) {
            R = red/12.92
        } else {
            R = pow((red + 0.055)/1.055, 2.4)
        }
        if (green <= 0.03928) {
            G = green/12.92
        } else {
            G = pow((green + 0.055)/1.055, 2.4)
        }
        if (blue <= 0.03928) {
            B = blue/12.92
        } else {
            B = pow((blue + 0.055)/1.055, 2.4)
        }
        return 0.2126 * R + 0.7152 * G + 0.0722 * B
    }

    func totalLuminance() -> CGFloat {
        let firstLum = getLuminance(color: firstCW.color)
        let secondLum = getLuminance(color: secondCW.color)
        let thirdLum = getLuminance(color: thirdCW.color)
        let fourthLum = getLuminance(color: fourthCW.color)
        let fifthLum = getLuminance(color: fifthCW.color)
        return round((firstLum + secondLum + thirdLum + fourthLum + fifthLum)*10)/10
    }

    func setColor(view: NSView, cw: NSColorWell, inline: NSCell, recessed: NSCell) {
        view.layer?.backgroundColor = cw.color.cgColor
        let lum = round(getLuminance(color: cw.color)*10)/10
        inline.title = lum.description
        let red = Int(round(cw.color.redComponent * 255))
        let green = Int(round(cw.color.greenComponent * 255))
        let blue = Int(round(cw.color.blueComponent * 255))
        recessed.title = NSString(format:"%02X%02X%02X", red, green, blue) as String!
        view.window?.title = totalLuminance().description
    }
    
    func setButtonsState(state: Bool) {
        firstInline.isHidden = state
        firstRecessed.isHidden = state
        secondInline.isHidden = state
        secondRecessed.isHidden = state
        thirdInline.isHidden = state
        thirdRecessed.isHidden = state
        fourthInline.isHidden = state
        fourthRecessed.isHidden = state
        fifthInline.isHidden = state
        fifthRecessed.isHidden = state
    }

    @IBAction func setFirstColor(sender: NSColorWell) {
        setColor(view: firstView, cw: firstCW, inline: firstInline.cell!, recessed: firstRecessed.cell!)
    }

    @IBAction func setSecondColor(sender: NSColorWell) {
        setColor(view: secondView, cw: secondCW, inline: secondInline.cell!, recessed: secondRecessed.cell!)
    }

    @IBAction func setThridColor(sender: NSColorWell) {
        setColor(view: thirdView, cw: thirdCW, inline: thirdInline.cell!, recessed: thirdRecessed.cell!)
    }

    @IBAction func setFourthColor(sender: NSColorWell) {
        setColor(view: fourthView, cw: fourthCW, inline: fourthInline.cell!, recessed: fourthRecessed.cell!)
    }

    @IBAction func setFifthColor(sender: NSColorWell) {
        setColor(view: fifthView, cw: fifthCW, inline: fifthInline.cell!, recessed: fifthRecessed.cell!)
    }
    
    @IBAction func randomFirst(sender: AnyObject) {
        firstCW.color = NSColor.init(calibratedRed: CGFloat(drand48()), green: CGFloat(drand48()), blue: CGFloat(drand48()), alpha: 1.0)
        setFirstColor(sender: firstCW)
    }
    
    @IBAction func randomSecond(sender: AnyObject) {
        secondCW.color = NSColor.init(calibratedRed: CGFloat(drand48()), green: CGFloat(drand48()), blue: CGFloat(drand48()), alpha: 1.0)
        setSecondColor(sender: secondCW)
    }
    
    @IBAction func randomThird(sender: AnyObject) {
        thirdCW.color = NSColor.init(calibratedRed: CGFloat(drand48()), green: CGFloat(drand48()), blue: CGFloat(drand48()), alpha: 1.0)
        setThridColor(sender: thirdCW)
    }
    
    @IBAction func randomFourth(sender: AnyObject) {
        fourthCW.color = NSColor.init(calibratedRed: CGFloat(drand48()), green: CGFloat(drand48()), blue: CGFloat(drand48()), alpha: 1.0)
        setFourthColor(sender: fourthCW)
    }
    
    @IBAction func randomFifth(sender: AnyObject) {
        fifthCW.color = NSColor.init(calibratedRed: CGFloat(drand48()), green: CGFloat(drand48()), blue: CGFloat(drand48()), alpha: 1.0)
        setFifthColor(sender: fifthCW)
    }

    @IBAction func randomColors(sender: AnyObject) {
        randomFirst(sender: sender)
        randomSecond(sender: sender)
        randomThird(sender: sender)
        randomFourth(sender: sender)
        randomFifth(sender: sender)
    }

    @IBAction func toggleFromMenu(sender: NSMenuItem) {
        if firstRecessed.isHidden {
            setButtonsState(state: false)
            toggle.image = NSImage(named: NSImage.Name(rawValue: "NSIconViewTemplate"))
        } else {
            setButtonsState(state: true)
            toggle.image = NSImage(named: NSImage.Name(rawValue: "NSListViewTemplate"))
        }
    }

    @IBAction func toggleFromToolbar(sender: NSToolbarItem) {
        if firstRecessed.isHidden {
            setButtonsState(state: false)
            sender.image = NSImage(named: NSImage.Name(rawValue: "NSIconViewTemplate"))
        } else {
            setButtonsState(state: true)
            sender.image = NSImage(named: NSImage.Name(rawValue: "NSListViewTemplate"))
        }
    }
    
    @IBAction func resetSplitView(sender: AnyObject) {
        let pane = (mainWindow.frame.width - 4) / 5
        splitView.setPosition(pane, ofDividerAt: 0)
        splitView.setPosition(pane * 2 + 1, ofDividerAt: 1)
        splitView.setPosition(pane * 3 + 2, ofDividerAt: 2)
        splitView.setPosition(pane * 4 + 3, ofDividerAt: 3)
    }
    
    @IBAction func copyToPasteboard(sender: NSButton) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(sender.cell?.title ?? "", forType: .string)
        sender.state = .on
        Swift.print(sender.cell?.title ?? "")
    }

    override func windowControllerDidLoadNib(_ windowController: NSWindowController) {
        super.windowControllerDidLoadNib(windowController)
        mainWindow.titleVisibility = .hidden
        mainWindow.styleMask.insert(.fullSizeContentView)
        randomColors(sender: windowController)
        randomColors(sender: windowController)
        self.displayName = totalLuminance().description
    }

    override init() {
        super.init()
        // Add your subclass-specific initialization here.
    }

    override var isDocumentEdited: Bool {
        return false
    }

    override class var autosavesInPlace: Bool {
        return true
    }

    override var windowNibName: NSNib.Name? {
        // Returns the nib file name of the document
        // If you need to use a subclass of NSWindowController or if your document supports multiple NSWindowControllers, you should remove this property and override -makeWindowControllers instead.
        return NSNib.Name("Document")
    }

    override func data(ofType typeName: String) throws -> Data {
        // Insert code here to write your document to data of the specified type. If outError != nil, ensure that you create and set an appropriate error when returning nil.
        // You can also choose to override fileWrapperOfType:error:, writeToURL:ofType:error:, or writeToURL:ofType:forSaveOperation:originalContentsURL:error: instead.
        throw NSError(domain: NSOSStatusErrorDomain, code: unimpErr, userInfo: nil)
    }

    override func read(from data: Data, ofType typeName: String) throws {
        // Insert code here to read your document from the given data of the specified type. If outError != nil, ensure that you create and set an appropriate error when returning false.
        // You can also choose to override readFromFileWrapper:ofType:error: or readFromURL:ofType:error: instead.
        // If you override either of these, you should also override -isEntireFileLoaded to return false if the contents are lazily loaded.
        throw NSError(domain: NSOSStatusErrorDomain, code: unimpErr, userInfo: nil)
    }


}

