//
//  AppDelegate.swift
//  Multicolor
//
//  Created by lucian on 12/3/17.
//  Copyright © 2017 Lucian Marin. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    private var windowController: Document?

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        srand48(Int(Date().timeIntervalSince1970))
        installMenus()

        let controller = Document(windowNibName: NSNib.Name("Document"))
        windowController = controller
        controller.showWindow(self)
        controller.window?.makeKeyAndOrderFront(self)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            windowController?.showWindow(self)
            windowController?.window?.makeKeyAndOrderFront(self)
        }
        return true
    }

    private func installMenus() {
        guard let mainMenu = NSApp.mainMenu else { return }

        let modeMenuItem = NSMenuItem(title: "Mode", action: nil, keyEquivalent: "")
        let modeMenu = NSMenu(title: "Mode")
        modeMenuItem.submenu = modeMenu

        for mode in HarmonyMode.allCases {
            let item = NSMenuItem(
                title: mode.title,
                action: #selector(Document.selectHarmonyMode(_:)),
                keyEquivalent: mode.keyEquivalent
            )
            item.tag = mode.rawValue
            if !mode.keyEquivalent.isEmpty {
                item.keyEquivalentModifierMask = [.command]
            }
            modeMenu.addItem(item)
        }

        let schemeMenuItem = NSMenuItem(title: "Scheme", action: nil, keyEquivalent: "")
        let schemeMenu = NSMenu(title: "Scheme")
        schemeMenuItem.submenu = schemeMenu

        let addItem: (String, Selector, String, NSEvent.ModifierFlags) -> Void = { title, action, key, mods in
            let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
            item.keyEquivalentModifierMask = mods
            schemeMenu.addItem(item)
        }

        addItem("Rotate Hue +15°", #selector(Document.rotateHueForward(_:)), "]", [.command])
        addItem("Rotate Hue -15°", #selector(Document.rotateHueBackward(_:)), "[", [.command])
        addItem("Brighten Scheme", #selector(Document.brightenScheme(_:)), "=", [.command])
        addItem("Darken Scheme", #selector(Document.darkenScheme(_:)), "-", [.command])
        addItem("Boost Vibrance", #selector(Document.boostChroma(_:)), "+", [.command, .shift])
        addItem("Mute Vibrance", #selector(Document.muteChroma(_:)), "_", [.command, .shift])

        schemeMenu.addItem(.separator())

        addItem("Sort by Luminance", #selector(Document.sortSchemeByLuminance(_:)), "l", [.command])
        addItem("Reverse Order", #selector(Document.reverseSchemeOrder(_:)), "r", [.command, .shift])
        addItem("Invert Scheme", #selector(Document.invertScheme(_:)), "i", [.command, .shift])
        addItem("Random Scheme", #selector(Document.randomColors(sender:)), "", [])
        addItem("Unlock All Panels", #selector(Document.unlockAllPanels(_:)), "u", [.command, .option])

        schemeMenu.addItem(.separator())

        addItem("Copy Hex List", #selector(Document.copySchemeHexList(_:)), "c", [.command, .shift])
        addItem("Copy CSS Variables", #selector(Document.copySchemeCSS(_:)), "", [])
        addItem("Copy Swift Array", #selector(Document.copySchemeSwift(_:)), "", [])
        addItem("Copy JSON", #selector(Document.copySchemeJSON(_:)), "", [])
        addItem("Copy SVG Swatch", #selector(Document.copySchemeSVG(_:)), "", [])

        let insertIndex = min(3, mainMenu.items.count)
        mainMenu.insertItem(modeMenuItem, at: insertIndex)
        mainMenu.insertItem(schemeMenuItem, at: insertIndex + 1)
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }


}

