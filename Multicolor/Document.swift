//
//  Document.swift
//  Multicolor
//
//  Created by lucian on 12/3/17.
//  Copyright © 2017 Lucian Marin. All rights reserved.
//

import Cocoa

// MARK: - Perceptual OKLCH Color Space & Scheme Generator Engine

struct OKLCHColor: Equatable {
    var L: Double // Perceptual Lightness: 0.0 ... 1.0
    var C: Double // Perceptual Chroma: 0.0 ... ~0.37
    var H: Double // Hue Angle in degrees: 0.0 ..< 360.0

    static let goldenAngle: Double = 137.50776405003785

    static func normalizeHue(_ degrees: Double) -> Double {
        var h = degrees.truncatingRemainder(dividingBy: 360.0)
        if h < 0 { h += 360.0 }
        return h
    }

    static func bounce(_ value: Double, min minVal: Double, max maxVal: Double) -> Double {
        let span = maxVal - minVal
        guard span > 0 else { return minVal }
        let period = 2.0 * span
        var norm = (value - minVal).truncatingRemainder(dividingBy: period)
        if norm < 0 { norm += period }
        return norm <= span ? (minVal + norm) : (maxVal - (norm - span))
    }

    static func wrap(_ value: Double, min minVal: Double, max maxVal: Double) -> Double {
        let span = maxVal - minVal
        guard span > 0 else { return minVal }
        var norm = (value - minVal).truncatingRemainder(dividingBy: span)
        if norm < 0 { norm += span }
        return minVal + norm
    }

    private static func srgbToLinear(_ x: Double) -> Double {
        return x <= 0.04045 ? (x / 12.92) : pow((x + 0.055) / 1.055, 2.4)
    }

    private static func linearToSrgb(_ x: Double) -> Double {
        let clamped = min(max(x, 0.0), 1.0)
        return clamped <= 0.0031308 ? (12.92 * clamped) : (1.055 * pow(clamped, 1.0 / 2.4) - 0.055)
    }

    private static func oklabToLinearRGB(L: Double, a: Double, b: Double) -> (r: Double, g: Double, b: Double) {
        let l_ = L + 0.3963377774 * a + 0.2158037573 * b
        let m_ = L - 0.1055613458 * a - 0.0638541728 * b
        let s_ = L - 0.0894841775 * a - 1.2914855480 * b

        let l = l_ * l_ * l_
        let m = m_ * m_ * m_
        let s = s_ * s_ * s_

        let lr = +4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s
        let lg = -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s
        let lb = -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s
        return (lr, lg, lb)
    }

    private static func isInGamut(_ rgb: (r: Double, g: Double, b: Double), epsilon: Double = 1e-4) -> Bool {
        return rgb.r >= -epsilon && rgb.r <= 1.0 + epsilon &&
               rgb.g >= -epsilon && rgb.g <= 1.0 + epsilon &&
               rgb.b >= -epsilon && rgb.b <= 1.0 + epsilon
    }

    static func fromNSColor(_ color: NSColor) -> OKLCHColor {
        let rgbColor = color.usingColorSpace(.sRGB) ?? color.usingColorSpace(.deviceRGB) ?? color
        let r = Double(rgbColor.redComponent)
        let g = Double(rgbColor.greenComponent)
        let b = Double(rgbColor.blueComponent)

        let lr = srgbToLinear(r)
        let lg = srgbToLinear(g)
        let lb = srgbToLinear(b)

        let l = 0.4122214708 * lr + 0.5363325363 * lg + 0.0514459929 * lb
        let m = 0.2119034982 * lr + 0.6806995451 * lg + 0.1073969566 * lb
        let s = 0.0883024619 * lr + 0.2817188376 * lg + 0.6299787005 * lb

        let l_ = cbrt(max(0.0, l))
        let m_ = cbrt(max(0.0, m))
        let s_ = cbrt(max(0.0, s))

        let L = 0.2104542553 * l_ + 0.7936177850 * m_ - 0.0040720468 * s_
        let okA = 1.9779984951 * l_ - 2.4285922050 * m_ + 0.4505937099 * s_
        let okB = 0.0259040371 * l_ + 0.7827717662 * m_ - 0.8086757660 * s_

        let C = hypot(okA, okB)
        let H = C < 1e-5 ? 0.0 : normalizeHue(atan2(okB, okA) * 180.0 / .pi)
        return OKLCHColor(L: min(max(L, 0.0), 1.0), C: C, H: H)
    }

    /// Converts OKLCH to sRGB NSColor using CSS Color 4 perceptual gamut mapping
    /// (preserving Lightness L and Hue H by binary-searching Chroma C into the sRGB gamut).
    func toNSColor() -> NSColor {
        let targetL = min(max(L, 0.0), 1.0)
        if targetL <= 0.001 {
            return NSColor(srgbRed: 0, green: 0, blue: 0, alpha: 1)
        }
        if targetL >= 0.999 {
            return NSColor(srgbRed: 1, green: 1, blue: 1, alpha: 1)
        }

        let rad = OKLCHColor.normalizeHue(H) * .pi / 180.0
        let cosH = cos(rad)
        let sinH = sin(rad)
        let targetC = max(0.0, C)

        let directRGB = OKLCHColor.oklabToLinearRGB(L: targetL, a: targetC * cosH, b: targetC * sinH)
        if OKLCHColor.isInGamut(directRGB) {
            return NSColor(
                srgbRed: CGFloat(OKLCHColor.linearToSrgb(directRGB.r)),
                green: CGFloat(OKLCHColor.linearToSrgb(directRGB.g)),
                blue: CGFloat(OKLCHColor.linearToSrgb(directRGB.b)),
                alpha: 1.0
            )
        }

        var low = 0.0
        var high = targetC
        var bestRGB = OKLCHColor.oklabToLinearRGB(L: targetL, a: 0, b: 0)
        for _ in 0..<18 {
            let mid = 0.5 * (low + high)
            let candidate = OKLCHColor.oklabToLinearRGB(L: targetL, a: mid * cosH, b: mid * sinH)
            if OKLCHColor.isInGamut(candidate) {
                low = mid
                bestRGB = candidate
            } else {
                high = mid
            }
        }

        return NSColor(
            srgbRed: CGFloat(OKLCHColor.linearToSrgb(bestRGB.r)),
            green: CGFloat(OKLCHColor.linearToSrgb(bestRGB.g)),
            blue: CGFloat(OKLCHColor.linearToSrgb(bestRGB.b)),
            alpha: 1.0
        )
    }
}

enum HarmonyMode: Int, CaseIterable {
    case goldenRatio = 0
    case analogous
    case complementary
    case splitComplementary
    case triadic
    case tetradic
    case pentadic
    case cubehelix
    case monochromatic
    case shadesAndTints
    case freeform

    var title: String {
        switch self {
        case .goldenRatio: return "Golden Ratio (OKLCH)"
        case .analogous: return "Analogous"
        case .complementary: return "Complementary"
        case .splitComplementary: return "Split-Complementary"
        case .triadic: return "Triadic"
        case .tetradic: return "Tetradic"
        case .pentadic: return "Pentadic (72°)"
        case .cubehelix: return "Cubehelix"
        case .monochromatic: return "Monochromatic"
        case .shadesAndTints: return "Shades & Tints"
        case .freeform: return "Freeform (Unlinked)"
        }
    }

    var keyEquivalent: String {
        switch self {
        case .goldenRatio: return "1"
        case .analogous: return "2"
        case .complementary: return "3"
        case .splitComplementary: return "4"
        case .triadic: return "5"
        case .tetradic: return "6"
        case .pentadic: return "7"
        case .cubehelix: return "8"
        case .monochromatic: return "9"
        case .shadesAndTints: return "0"
        case .freeform: return ""
        }
    }

    /// Generates 5 harmonious colors anchored at `anchorIndex` with `anchorColor`.
    func generateScheme(anchorColor: NSColor, anchorIndex: Int, existingColors: [NSColor], lockedPanels: [Bool]) -> [NSColor] {
        let srgbAnchor = anchorColor.usingColorSpace(.sRGB) ?? anchorColor
        let anchorOKLCH = OKLCHColor.fromNSColor(srgbAnchor)
        return generateScheme(
            anchorOKLCH: anchorOKLCH,
            anchorColor: srgbAnchor,
            anchorIndex: anchorIndex,
            existingColors: existingColors,
            lockedPanels: lockedPanels
        )
    }

    /// Generates 5 harmonious colors directly from an `OKLCHColor` anchor at `anchorIndex`.
    func generateScheme(anchorOKLCH: OKLCHColor, anchorColor: NSColor? = nil, anchorIndex: Int, existingColors: [NSColor], lockedPanels: [Bool]) -> [NSColor] {
        let clampedAnchor = min(max(anchorIndex, 0), 4)
        let resolvedAnchorColor = anchorColor ?? anchorOKLCH.toNSColor()

        if self == .freeform {
            var copy = existingColors
            if clampedAnchor < copy.count {
                copy[clampedAnchor] = resolvedAnchorColor
            }
            return copy
        }

        // Ensure chromatic modes still generate rich hues even if the anchor is near-neutral or gamut-clipped at extreme L
        let baseChroma: Double = {
            switch self {
            case .monochromatic, .shadesAndTints:
                return anchorOKLCH.C < 0.015 ? anchorOKLCH.C : max(anchorOKLCH.C, 0.14)
            default:
                return max(anchorOKLCH.C, 0.14)
            }
        }()

        var result: [NSColor] = []
        for idx in 0..<5 {
            if idx < lockedPanels.count && lockedPanels[idx] && idx < existingColors.count {
                result.append(existingColors[idx])
                continue
            }
            if idx == clampedAnchor {
                result.append(resolvedAnchorColor)
                continue
            }

            let step = idx - clampedAnchor
            let d = Double(step)
            let generated = computeColor(anchor: anchorOKLCH, baseChroma: baseChroma, step: step, d: d)
            result.append(generated.toNSColor())
        }
        return result
    }

    private func computeColor(anchor: OKLCHColor, baseChroma: Double, step: Int, d: Double) -> OKLCHColor {
        let L0 = anchor.L
        let H0 = anchor.H

        switch self {
        case .goldenRatio:
            // Golden Angle (137.508°) rotation in perceptual OKLCH space with harmonic lightness & chroma envelope
            let h = OKLCHColor.normalizeHue(H0 + d * OKLCHColor.goldenAngle)
            let lOffset = d * 0.135 + 0.025 * sin(d * OKLCHColor.goldenAngle * .pi / 180.0)
            let l = OKLCHColor.wrap(L0 + lOffset, min: 0.20, max: 0.88)
            // Parabolic midtone chroma curve so very light and very dark swatches stay clean and natural
            let midtoneFactor = 1.0 - 0.28 * pow((l - 0.58) / 0.42, 2.0)
            let c = max(0.035, baseChroma * midtoneFactor * (1.0 + 0.08 * cos(d * 1.1)))
            return OKLCHColor(L: l, C: c, H: h)

        case .analogous:
            // Smooth 18° steps along the perceptual hue wheel with gentle lightness progression
            let h = OKLCHColor.normalizeHue(H0 + d * 18.0)
            let l = OKLCHColor.wrap(L0 + d * 0.11, min: 0.22, max: 0.87)
            let c = max(0.03, baseChroma * (1.0 - 0.04 * abs(d)))
            return OKLCHColor(L: l, C: c, H: h)

        case .complementary:
            // Pairs anchor hue (0°) with its perceptual complement (180°) and tonal companions
            let hueOffsets: [Int: Double] = [
                -4: 180.0, -3: 180.0, -2: 180.0, -1: 0.0,
                 0: 0.0,
                 1: 0.0,    2: 180.0,  3: 180.0,  4: 180.0
            ]
            let lOffsets: [Int: Double] = [
                -4: 0.42, -3: 0.26, -2: 0.12, -1: -0.15,
                 0: 0.0,
                 1: 0.15,  2: 0.30,  3: 0.45,  4: 0.60
            ]
            let cFactors: [Int: Double] = [
                -4: 0.85, -3: 0.78, -2: 1.0, -1: 0.75,
                 0: 1.0,
                 1: 0.82,  2: 1.0,  3: 0.78,  4: 0.85
            ]
            let h = OKLCHColor.normalizeHue(H0 + (hueOffsets[step] ?? 180.0))
            let l = OKLCHColor.wrap(L0 + (lOffsets[step] ?? (d * 0.14)), min: 0.20, max: 0.88)
            let c = max(0.03, baseChroma * (cFactors[step] ?? 0.9))
            return OKLCHColor(L: l, C: c, H: h)

        case .splitComplementary:
            // Anchor (0°) + Flanking Complements (+150°, +210°) + Tonal Accents
            let hueOffsets: [Int: Double] = [
                -4: 210.0, -3: 150.0, -2: 210.0, -1: 0.0,
                 0: 0.0,
                 1: 150.0,  2: 210.0,  3: 0.0,    4: 150.0
            ]
            let lOffsets: [Int: Double] = [
                -4: 0.52, -3: 0.38, -2: 0.24, -1: -0.14,
                 0: 0.0,
                 1: 0.13,  2: 0.27,  3: 0.41,  4: 0.55
            ]
            let h = OKLCHColor.normalizeHue(H0 + (hueOffsets[step] ?? 150.0))
            let l = OKLCHColor.wrap(L0 + (lOffsets[step] ?? (d * 0.13)), min: 0.20, max: 0.88)
            let c = max(0.035, baseChroma * (abs(step) == 3 ? 0.76 : 0.96))
            return OKLCHColor(L: l, C: c, H: h)

        case .triadic:
            // 120° Perceptual Triad in OKLCH
            let hueOffsets: [Int: Double] = [
                -4: 240.0, -3: 120.0, -2: 240.0, -1: 120.0,
                 0: 0.0,
                 1: 120.0,  2: 240.0,  3: 120.0,  4: 240.0
            ]
            let lOffsets: [Int: Double] = [
                -4: 0.52, -3: 0.38, -2: 0.24, -1: -0.14,
                 0: 0.0,
                 1: 0.13,  2: 0.27,  3: 0.41,   4: 0.55
            ]
            let h = OKLCHColor.normalizeHue(H0 + (hueOffsets[step] ?? 120.0))
            let l = OKLCHColor.wrap(L0 + (lOffsets[step] ?? (d * 0.13)), min: 0.20, max: 0.88)
            let c = max(0.035, baseChroma * (abs(step) >= 3 ? 0.80 : 0.95))
            return OKLCHColor(L: l, C: c, H: h)

        case .tetradic:
            // Double Complementary (0°, 60°, 180°, 240°)
            let hueOffsets: [Int: Double] = [
                -4: 240.0, -3: 180.0, -2: 60.0, -1: 240.0,
                 0: 0.0,
                 1: 60.0,   2: 180.0,  3: 240.0, 4: 0.0
            ]
            let lOffsets: [Int: Double] = [
                -4: 0.52, -3: 0.38, -2: 0.24, -1: -0.14,
                 0: 0.0,
                 1: 0.13,   2: 0.27,  3: 0.41,   4: 0.55
            ]
            let h = OKLCHColor.normalizeHue(H0 + (hueOffsets[step] ?? 90.0))
            let l = OKLCHColor.wrap(L0 + (lOffsets[step] ?? (d * 0.13)), min: 0.20, max: 0.88)
            let c = max(0.035, baseChroma * (abs(step) == 4 ? 0.76 : 0.94))
            return OKLCHColor(L: l, C: c, H: h)

        case .pentadic:
            // Equidistant 72° 5-point perceptual wheel
            let h = OKLCHColor.normalizeHue(H0 + d * 72.0)
            let l = OKLCHColor.wrap(L0 + d * 0.12, min: 0.22, max: 0.86)
            let c = max(0.04, baseChroma * 0.95)
            return OKLCHColor(L: l, C: c, H: h)

        case .cubehelix:
            // Helical trajectory through OKLCH (simultaneous hue rotation + monotonic lightness ramp)
            let h = OKLCHColor.normalizeHue(H0 + d * 52.0)
            let l = OKLCHColor.wrap(L0 + d * 0.145, min: 0.18, max: 0.90)
            let helixEnvelope = max(0.35, sin(.pi * min(max(l, 0.08), 0.92)))
            let c = max(0.03, baseChroma * helixEnvelope)
            return OKLCHColor(L: l, C: c, H: h)

        case .monochromatic:
            // Constant perceptual hue, natural bell-shaped chroma across 5 distinct lightness steps
            let l = OKLCHColor.wrap(L0 + d * 0.15, min: 0.16, max: 0.91)
            let bell = 1.0 - 0.42 * pow((l - 0.55) / 0.45, 2.0)
            let c = max(0.0, baseChroma * max(0.25, bell))
            return OKLCHColor(L: l, C: c, H: H0)

        case .shadesAndTints:
            // Constant hue & chroma-preserving lightness progression across 5 distinct steps
            let l = OKLCHColor.wrap(L0 + d * 0.15, min: 0.16, max: 0.91)
            let c = max(0.0, baseChroma * (1.0 - 0.06 * abs(d)))
            return OKLCHColor(L: l, C: c, H: H0)

        case .freeform:
            return anchor
        }
    }
}


class Document: NSWindowController, NSToolbarDelegate, NSWindowDelegate {
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
    @IBOutlet weak var sortToolbarItem: NSToolbarItem!

    private var harmonyMode: HarmonyMode = {
        if UserDefaults.standard.object(forKey: Document.harmonyModeDefaultsKey) != nil,
           let saved = HarmonyMode(rawValue: UserDefaults.standard.integer(forKey: Document.harmonyModeDefaultsKey)) {
            return saved
        }
        return .goldenRatio
    }() {
        didSet {
            UserDefaults.standard.set(harmonyMode.rawValue, forKey: Document.harmonyModeDefaultsKey)
        }
    }
    private var anchorIndex: Int = 0
    private var lockedPanels: [Bool] = [false, false, false, false, false]
    private var lockButtons: [NSButton] = []
    private var isUpdatingColors: Bool = false
    private var harmonyPopUpButton: NSPopUpButton?

    private static let harmonyToolbarItemID = NSToolbarItem.Identifier("MulticolorHarmonyToolbarItem")
    private static let toolsToolbarItemID = NSToolbarItem.Identifier("MulticolorToolsToolbarItem")
    private static let windowFrameDefaultsKey = "MulticolorSavedWindowFrame_640x480"
    private static let harmonyModeDefaultsKey = "MulticolorLastHarmonyMode"

    private var panelViews: [NSView] {
        return [firstView, secondView, thirdView, fourthView, fifthView]
    }

    private var colorWells: [NSColorWell] {
        return [firstCW, secondCW, thirdCW, fourthCW, fifthCW]
    }

    private var inlineButtons: [NSButton] {
        return [firstInline, secondInline, thirdInline, fourthInline, fifthInline]
    }

    private var recessedButtons: [NSButton] {
        return [firstRecessed, secondRecessed, thirdRecessed, fourthRecessed, fifthRecessed]
    }

    func srgbColor(_ color: NSColor) -> NSColor {
        return color.usingColorSpace(.sRGB) ?? color.usingColorSpace(.deviceRGB) ?? color
    }

    func relativeLuminanceValue(color: NSColor) -> CGFloat {
        let rgb = srgbColor(color)
        let red = rgb.redComponent
        let green = rgb.greenComponent
        let blue = rgb.blueComponent
        let R = (red <= 0.03928) ? (red / 12.92) : pow((red + 0.055) / 1.055, 2.4)
        let G = (green <= 0.03928) ? (green / 12.92) : pow((green + 0.055) / 1.055, 2.4)
        let B = (blue <= 0.03928) ? (blue / 12.92) : pow((blue + 0.055) / 1.055, 2.4)
        return 0.2126 * R + 0.7152 * G + 0.0722 * B
    }

    func getLuminance(color: NSColor) -> Int {
        return Int(round(relativeLuminanceValue(color: color) * 100))
    }

    func contrastRatio(_ c1: NSColor, _ c2: NSColor) -> Double {
        let l1 = Double(relativeLuminanceValue(color: c1))
        let l2 = Double(relativeLuminanceValue(color: c2))
        let lighter = max(l1, l2)
        let darker = min(l1, l2)
        return (lighter + 0.05) / (darker + 0.05)
    }

    func averageLuminance() -> Int {
        let firstLum = getLuminance(color: firstCW.color)
        let secondLum = getLuminance(color: secondCW.color)
        let thirdLum = getLuminance(color: thirdCW.color)
        let fourthLum = getLuminance(color: fourthCW.color)
        let fifthLum = getLuminance(color: fifthCW.color)
        return (firstLum + secondLum + thirdLum + fourthLum + fifthLum) / 5
    }

    func hexString(for color: NSColor, includeHash: Bool = false) -> String {
        let rgb = srgbColor(color)
        let red = min(max(Int(round(rgb.redComponent * 255)), 0), 255)
        let green = min(max(Int(round(rgb.greenComponent * 255)), 0), 255)
        let blue = min(max(Int(round(rgb.blueComponent * 255)), 0), 255)
        let prefix = includeHash ? "#" : ""
        return String(format: "%@%02X%02X%02X", prefix, red, green, blue)
    }

    func setColor(view: NSView, cw: NSColorWell, inline: NSCell, recessed: NSCell) {
        let rgb = srgbColor(cw.color)
        view.wantsLayer = true
        view.layer?.backgroundColor = rgb.cgColor
        let lum = getLuminance(color: rgb)
        inline.title = "\(lum)%"
        let hex = hexString(for: rgb, includeHash: false)
        recessed.title = hex

        let oklch = OKLCHColor.fromNSColor(rgb)
        let whiteContrast = contrastRatio(rgb, .white)
        let blackContrast = contrastRatio(rgb, .black)
        let rInt = Int(round(rgb.redComponent * 255))
        let gInt = Int(round(rgb.greenComponent * 255))
        let bInt = Int(round(rgb.blueComponent * 255))
        let detailsTooltip = String(
            format: "#%@  •  RGB(%d, %d, %d)\nOKLCH(%.0f%%, %.3f, %.0f°)\nLuminance: %d%%  •  Contrast W: %.1f:1 / B: %.1f:1",
            hex, rInt, gInt, bInt,
            oklch.L * 100.0, oklch.C, oklch.H,
            lum, whiteContrast, blackContrast
        )
        cw.toolTip = detailsTooltip

        let avgTitle = "\(averageLuminance())% — \(harmonyMode.title)"
        view.window?.title = avgTitle
    }

    func refreshAllPanels() {
        let views = panelViews
        let wells = colorWells
        let inlines = inlineButtons
        let recessed = recessedButtons
        for idx in 0..<5 {
            if let inlineCell = inlines[idx].cell, let recessedCell = recessed[idx].cell {
                setColor(view: views[idx], cw: wells[idx], inline: inlineCell, recessed: recessedCell)
            }
            if idx < lockButtons.count {
                let locked = lockedPanels[idx]
                let imageName = locked ? NSImage.Name.lockLockedTemplate : NSImage.Name.lockUnlockedTemplate
                lockButtons[idx].image = NSImage(named: imageName)
                lockButtons[idx].state = locked ? .on : .off
                lockButtons[idx].toolTip = locked ? "Unlock Panel \(idx + 1)" : "Lock Panel \(idx + 1)"
            }
        }
        harmonyPopUpButton?.selectItem(withTag: harmonyMode.rawValue)
        updateSortToolbarIcon()
    }

    private func updateSortToolbarIcon() {
        let existing = currentColors()
        let ascending = existing.sorted { relativeLuminanceValue(color: $0) < relativeLuminanceValue(color: $1) }
        let isAscending = zip(existing, ascending).allSatisfy {
            hexString(for: $0) == hexString(for: $1)
        }
        let imageName = isAscending ? "NSTouchBarRotateLeftTemplate" : "NSTouchBarRotateRightTemplate"
        let img = NSImage(named: NSImage.Name(rawValue: imageName))
        sortToolbarItem?.image = img
        (sortToolbarItem?.view as? NSButton)?.image = img
    }

    func currentColors() -> [NSColor] {
        return colorWells.map { srgbColor($0.color) }
    }

    func applyColors(_ newColors: [NSColor], newHarmony: HarmonyMode? = nil, newAnchor: Int? = nil, registerUndo: Bool = true) {
        guard newColors.count == 5 else { return }
        let oldColors = currentColors()
        let oldHarmony = harmonyMode
        let oldAnchor = anchorIndex

        if registerUndo, let undo = window?.undoManager {
            undo.registerUndo(withTarget: self) { target in
                target.applyColors(oldColors, newHarmony: oldHarmony, newAnchor: oldAnchor, registerUndo: true)
            }
        }

        if let h = newHarmony {
            harmonyMode = h
        }
        if let a = newAnchor {
            anchorIndex = min(max(a, 0), 4)
        }

        isUpdatingColors = true
        let wells = colorWells
        for idx in 0..<5 {
            wells[idx].color = srgbColor(newColors[idx])
        }
        refreshAllPanels()
        isUpdatingColors = false
    }

    private func syncHarmonyModeFromToolbar() {
        if let popUp = harmonyPopUpButton,
           let selectedMode = HarmonyMode(rawValue: popUp.selectedTag()),
           selectedMode != harmonyMode {
            harmonyMode = selectedMode
        }
    }

    func applyHarmony(fromAnchorIndex index: Int, registerUndo: Bool = true) {
        guard !isUpdatingColors else { return }
        syncHarmonyModeFromToolbar()
        let clampedIndex = min(max(index, 0), 4)
        anchorIndex = clampedIndex
        let wells = colorWells
        let anchorColor = srgbColor(wells[clampedIndex].color)
        let generated = harmonyMode.generateScheme(
            anchorColor: anchorColor,
            anchorIndex: clampedIndex,
            existingColors: currentColors(),
            lockedPanels: lockedPanels
        )
        applyColors(generated, newHarmony: harmonyMode, newAnchor: clampedIndex, registerUndo: registerUndo)
    }

    func randomOKLCHSeed(for mode: HarmonyMode? = nil) -> OKLCHColor {
        let activeMode = mode ?? harmonyMode
        let L: Double
        switch activeMode {
        case .monochromatic, .shadesAndTints, .cubehelix:
            L = 0.20 + drand48() * 0.12
        case .analogous:
            L = 0.28 + drand48() * 0.14
        default:
            L = 0.38 + drand48() * 0.34
        }
        let C = 0.13 + drand48() * 0.13
        let H = drand48() * 360.0
        return OKLCHColor(L: L, C: C, H: H)
    }

    func randomOKLCHSeedColor(for mode: HarmonyMode? = nil) -> NSColor {
        return randomOKLCHSeed(for: mode).toNSColor()
    }

    private func randomizePanel(at index: Int) {
        syncHarmonyModeFromToolbar()
        var existing = currentColors()
        let seedOKLCH = randomOKLCHSeed(for: harmonyMode)
        if harmonyMode == .freeform {
            existing[index] = seedOKLCH.toNSColor()
            applyColors(existing, newHarmony: harmonyMode, newAnchor: index)
        } else {
            let generated = harmonyMode.generateScheme(
                anchorOKLCH: seedOKLCH,
                anchorIndex: index,
                existingColors: existing,
                lockedPanels: lockedPanels
            )
            applyColors(generated, newHarmony: harmonyMode, newAnchor: index)
        }
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
        for btn in lockButtons {
            btn.isHidden = state
        }
    }

    @IBAction func setFirstColor(sender: NSColorWell) {
        applyHarmony(fromAnchorIndex: 0)
    }

    @IBAction func setSecondColor(sender: NSColorWell) {
        applyHarmony(fromAnchorIndex: 1)
    }

    @IBAction func setThridColor(sender: NSColorWell) {
        applyHarmony(fromAnchorIndex: 2)
    }

    @IBAction func setFourthColor(sender: NSColorWell) {
        applyHarmony(fromAnchorIndex: 3)
    }

    @IBAction func setFifthColor(sender: NSColorWell) {
        applyHarmony(fromAnchorIndex: 4)
    }
    
    @IBAction func randomFirst(sender: AnyObject) {
        randomizePanel(at: 0)
    }
    
    @IBAction func randomSecond(sender: AnyObject) {
        randomizePanel(at: 1)
    }
    
    @IBAction func randomThird(sender: AnyObject) {
        randomizePanel(at: 2)
    }
    
    @IBAction func randomFourth(sender: AnyObject) {
        randomizePanel(at: 3)
    }
    
    @IBAction func randomFifth(sender: AnyObject) {
        randomizePanel(at: 4)
    }

    @IBAction func randomColors(sender: AnyObject) {
        syncHarmonyModeFromToolbar()
        let existing = currentColors()

        if harmonyMode == .freeform {
            let generated = (0..<5).map { idx in
                lockedPanels[idx] ? existing[idx] : randomOKLCHSeedColor(for: .freeform)
            }
            applyColors(generated, newHarmony: .freeform, newAnchor: anchorIndex)
            return
        }

        if let lockedIndex = lockedPanels.firstIndex(of: true) {
            let lockedOKLCH = OKLCHColor.fromNSColor(existing[lockedIndex])
            let jitterL = OKLCHColor.wrap(lockedOKLCH.L + 0.12 + drand48() * 0.45, min: 0.20, max: 0.84)
            let jitterC = max(0.13, min(0.26, lockedOKLCH.C + (drand48() - 0.5) * 0.10))
            let virtualSeed = OKLCHColor(L: jitterL, C: jitterC, H: lockedOKLCH.H)
            let virtualAnchor = Int(drand48() * 5.0) % 5
            let generated = harmonyMode.generateScheme(
                anchorOKLCH: virtualSeed,
                anchorIndex: virtualAnchor,
                existingColors: existing,
                lockedPanels: lockedPanels
            )
            applyColors(generated, newHarmony: harmonyMode, newAnchor: lockedIndex)
            return
        }

        let seedIndex = 0
        let seedOKLCH = randomOKLCHSeed(for: harmonyMode)
        let generated = harmonyMode.generateScheme(
            anchorOKLCH: seedOKLCH,
            anchorIndex: seedIndex,
            existingColors: existing,
            lockedPanels: lockedPanels
        )
        applyColors(generated, newHarmony: harmonyMode, newAnchor: seedIndex)
    }

    // MARK: - Harmony & Scheme Manipulation Actions

    @objc func selectHarmonyMode(_ sender: AnyObject) {
        let rawTag: Int?
        if let popUp = sender as? NSPopUpButton {
            rawTag = popUp.selectedTag()
        } else if let toolbarItem = sender as? NSToolbarItem, let popUp = toolbarItem.view as? NSPopUpButton {
            rawTag = popUp.selectedTag()
        } else if let menuItem = sender as? NSMenuItem {
            rawTag = menuItem.tag
        } else if let popUp = harmonyPopUpButton {
            rawTag = popUp.selectedTag()
        } else {
            rawTag = nil
        }
        guard let tag = rawTag, let mode = HarmonyMode(rawValue: tag) else { return }
        harmonyMode = mode
        harmonyPopUpButton?.selectItem(withTag: mode.rawValue)
        let existing = currentColors()
        let anchorColor = srgbColor(colorWells[anchorIndex].color)
        let generated = mode.generateScheme(
            anchorColor: anchorColor,
            anchorIndex: anchorIndex,
            existingColors: existing,
            lockedPanels: lockedPanels
        )
        applyColors(generated, newHarmony: mode, newAnchor: anchorIndex)
    }

    @objc func toggleLockPanel(_ sender: NSButton) {
        let idx = sender.tag
        guard idx >= 0 && idx < 5 else { return }
        lockedPanels[idx].toggle()
        refreshAllPanels()
    }

    @objc func unlockAllPanels(_ sender: AnyObject) {
        lockedPanels = [false, false, false, false, false]
        refreshAllPanels()
    }

    @objc func rotateHueForward(_ sender: AnyObject) {
        shiftPaletteOKLCH(dL: 0.0, cFactor: 1.0, dH: 15.0)
    }

    @objc func rotateHueBackward(_ sender: AnyObject) {
        shiftPaletteOKLCH(dL: 0.0, cFactor: 1.0, dH: -15.0)
    }

    @objc func brightenScheme(_ sender: AnyObject) {
        shiftPaletteOKLCH(dL: 0.05, cFactor: 1.0, dH: 0.0)
    }

    @objc func darkenScheme(_ sender: AnyObject) {
        shiftPaletteOKLCH(dL: -0.05, cFactor: 1.0, dH: 0.0)
    }

    @objc func boostChroma(_ sender: AnyObject) {
        shiftPaletteOKLCH(dL: 0.0, cFactor: 1.18, dH: 0.0)
    }

    @objc func muteChroma(_ sender: AnyObject) {
        shiftPaletteOKLCH(dL: 0.0, cFactor: 0.84, dH: 0.0)
    }

    private func shiftPaletteOKLCH(dL: Double, cFactor: Double, dH: Double) {
        let existing = currentColors()
        var updated: [NSColor] = []
        for idx in 0..<5 {
            if lockedPanels[idx] {
                updated.append(existing[idx])
                continue
            }
            var oklch = OKLCHColor.fromNSColor(existing[idx])
            oklch.L = min(max(oklch.L + dL, 0.06), 0.96)
            oklch.C = min(max(oklch.C * cFactor, 0.0), 0.35)
            oklch.H = OKLCHColor.normalizeHue(oklch.H + dH)
            updated.append(oklch.toNSColor())
        }
        applyColors(updated)
    }

    @IBAction @objc func sortSchemeByLuminance(_ sender: AnyObject) {
        let existing = currentColors()
        let ascending = existing.sorted { relativeLuminanceValue(color: $0) < relativeLuminanceValue(color: $1) }
        let isAlreadyAscending = zip(existing, ascending).allSatisfy {
            hexString(for: $0) == hexString(for: $1)
        }
        let sorted = isAlreadyAscending ? Array(ascending.reversed()) : ascending
        applyColors(sorted)
    }

    @IBAction @objc func reverseSchemeOrder(_ sender: AnyObject) {
        lockedPanels.reverse()
        applyColors(Array(currentColors().reversed()), newAnchor: 4 - anchorIndex)
    }

    @IBAction @objc func invertScheme(_ sender: AnyObject) {
        let existing = currentColors()
        let inverted = existing.enumerated().map { idx, color -> NSColor in
            if lockedPanels[idx] { return color }
            var oklch = OKLCHColor.fromNSColor(color)
            oklch.L = min(max(1.0 - oklch.L, 0.10), 0.94)
            oklch.H = OKLCHColor.normalizeHue(oklch.H + 180.0)
            return oklch.toNSColor()
        }
        applyColors(inverted)
    }

    // MARK: - Copy / Export Palette Formats

    @objc func copySchemeHexList(_ sender: AnyObject) {
        let text = currentColors().map { hexString(for: $0, includeHash: true) }.joined(separator: ", ")
        writeStringToPasteboard(text)
    }

    @objc func copySchemeCSS(_ sender: AnyObject) {
        let lines = currentColors().enumerated().map { idx, color in
            let hex = hexString(for: color, includeHash: true)
            let oklch = OKLCHColor.fromNSColor(color)
            return String(
                format: "  --color-%d: %@; /* oklch(%.1f%% %.3f %.1f) */",
                idx + 1, hex, oklch.L * 100.0, oklch.C, oklch.H
            )
        }
        let css = ":root {\n" + lines.joined(separator: "\n") + "\n}"
        writeStringToPasteboard(css)
    }

    @objc func copySchemeJSON(_ sender: AnyObject) {
        let items: [[String: Any]] = currentColors().enumerated().map { idx, color in
            let rgb = srgbColor(color)
            let oklch = OKLCHColor.fromNSColor(rgb)
            return [
                "index": idx + 1,
                "hex": hexString(for: rgb, includeHash: true),
                "luminance": getLuminance(color: rgb),
                "rgb": [
                    "r": Int(round(rgb.redComponent * 255)),
                    "g": Int(round(rgb.greenComponent * 255)),
                    "b": Int(round(rgb.blueComponent * 255))
                ],
                "oklch": [
                    "l": Double(round(oklch.L * 1000) / 1000),
                    "c": Double(round(oklch.C * 1000) / 1000),
                    "h": Double(round(oklch.H * 10) / 10)
                ]
            ]
        }
        if let data = try? JSONSerialization.data(withJSONObject: items, options: [.prettyPrinted]),
           let json = String(data: data, encoding: .utf8) {
            writeStringToPasteboard(json)
        }
    }

    @objc func copySchemeSwift(_ sender: AnyObject) {
        let lines = currentColors().map { color -> String in
            let rgb = srgbColor(color)
            let hex = hexString(for: rgb, includeHash: true)
            return String(
                format: "    NSColor(srgbRed: %.3f, green: %.3f, blue: %.3f, alpha: 1.0) // %@",
                rgb.redComponent, rgb.greenComponent, rgb.blueComponent, hex
            )
        }
        let code = "let palette: [NSColor] = [\n" + lines.joined(separator: ",\n") + "\n]"
        writeStringToPasteboard(code)
    }

    @objc func copySchemeSVG(_ sender: AnyObject) {
        let rects = currentColors().enumerated().map { idx, color -> String in
            let hex = hexString(for: color, includeHash: true)
            return "  <rect x=\"\(idx * 100)\" y=\"0\" width=\"100\" height=\"200\" fill=\"\(hex)\"/>"
        }
        let svg = "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 500 200\" width=\"500\" height=\"200\">\n"
            + rects.joined(separator: "\n")
            + "\n</svg>"
        writeStringToPasteboard(svg)
    }

    private func writeStringToPasteboard(_ string: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(string, forType: .string)
    }

    @IBAction func toggleFromMenu(sender: NSMenuItem) {
        setButtonsState(state: !firstRecessed.isHidden)
    }

    @IBAction func toggleFromToolbar(sender: NSToolbarItem) {
        setButtonsState(state: !firstRecessed.isHidden)
    }
    
    @IBAction func resetSplitView(sender: AnyObject) {
        let pane = (mainWindow.frame.width - 4) / 5
        splitView.setPosition(pane, ofDividerAt: 0)
        splitView.setPosition(pane * 2 + 1, ofDividerAt: 1)
        splitView.setPosition(pane * 3 + 2, ofDividerAt: 2)
        splitView.setPosition(pane * 4 + 3, ofDividerAt: 3)
    }
    
    @IBAction func copyToPasteboard(sender: NSButton) {
        let hexTitle = sender.cell?.title ?? ""
        guard hexTitle != "COPIED" else { return }
        writeStringToPasteboard(hexTitle)
        sender.state = .on
        sender.cell?.title = "COPIED"
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) { [weak self] in
            self?.refreshAllPanels()
        }
    }

    private func setupLockButtons() {
        guard lockButtons.isEmpty else { return }
        let views = panelViews
        let inlines = inlineButtons
        for idx in 0..<5 {
            let panel = views[idx]
            let inlineBtn = inlines[idx]
            let lockBtn = NSButton(frame: .zero)
            lockBtn.translatesAutoresizingMaskIntoConstraints = false
            lockBtn.bezelStyle = .inline
            lockBtn.isBordered = false
            lockBtn.setButtonType(.toggle)
            lockBtn.image = NSImage(named: NSImage.Name.lockUnlockedTemplate)
            lockBtn.imagePosition = .imageOnly
            lockBtn.tag = idx
            lockBtn.target = self
            lockBtn.action = #selector(toggleLockPanel(_:))
            lockBtn.toolTip = "Lock Panel \(idx + 1)"
            panel.addSubview(lockBtn)

            NSLayoutConstraint.activate([
                lockBtn.centerXAnchor.constraint(equalTo: inlineBtn.centerXAnchor),
                lockBtn.bottomAnchor.constraint(equalTo: inlineBtn.topAnchor, constant: -8),
                lockBtn.widthAnchor.constraint(equalToConstant: 24),
                lockBtn.heightAnchor.constraint(equalToConstant: 18)
            ])
            lockButtons.append(lockBtn)
        }
    }

    private func setupToolbarControls() {
        guard let toolbar = mainWindow.toolbar else { return }
        toolbar.delegate = self
        let existingIDs = toolbar.items.map { $0.itemIdentifier }
        if !existingIDs.contains(Document.harmonyToolbarItemID) {
            toolbar.insertItem(withItemIdentifier: Document.harmonyToolbarItemID, at: 0)
        }
        if !existingIDs.contains(Document.toolsToolbarItemID) {
            toolbar.insertItem(withItemIdentifier: Document.toolsToolbarItemID, at: 1)
        }
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return [
            Document.harmonyToolbarItemID,
            Document.toolsToolbarItemID,
            .flexibleSpace,
            .space
        ]
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return [
            Document.harmonyToolbarItemID,
            Document.toolsToolbarItemID,
            .flexibleSpace
        ]
    }

    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        if itemIdentifier == Document.harmonyToolbarItemID {
            let item = NSToolbarItem(itemIdentifier: itemIdentifier)
            item.label = "Harmony"
            item.paletteLabel = "Harmony Mode"
            item.toolTip = "Select Color Harmony Algorithm"

            let popUp = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 170, height: 24), pullsDown: false)
            popUp.controlSize = .small
            popUp.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
            for mode in HarmonyMode.allCases {
                popUp.addItem(withTitle: mode.title)
                popUp.lastItem?.tag = mode.rawValue
            }
            popUp.selectItem(withTag: harmonyMode.rawValue)
            popUp.target = self
            popUp.action = #selector(selectHarmonyMode(_:))
            popUp.translatesAutoresizingMaskIntoConstraints = false
            popUp.widthAnchor.constraint(greaterThanOrEqualToConstant: 155).isActive = true
            item.view = popUp
            harmonyPopUpButton = popUp
            return item
        }

        if itemIdentifier == Document.toolsToolbarItemID {
            let item = NSToolbarItem(itemIdentifier: itemIdentifier)
            item.label = "Adjust & Export"
            item.paletteLabel = "Adjust & Export"
            item.toolTip = "Adjust Scheme or Copy Palette"

            let pullDown = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 96, height: 24), pullsDown: true)
            pullDown.controlSize = .small
            pullDown.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
            pullDown.addItem(withTitle: "Scheme")

            let menu = pullDown.menu!
            let addAction: (String, Selector) -> Void = { [weak self] title, selector in
                let mi = NSMenuItem(title: title, action: selector, keyEquivalent: "")
                mi.target = self
                menu.addItem(mi)
            }

            addAction("Rotate Hue +15°", #selector(rotateHueForward(_:)))
            addAction("Rotate Hue -15°", #selector(rotateHueBackward(_:)))
            addAction("Brighten Scheme", #selector(brightenScheme(_:)))
            addAction("Darken Scheme", #selector(darkenScheme(_:)))
            addAction("Boost Vibrance", #selector(boostChroma(_:)))
            addAction("Mute Vibrance", #selector(muteChroma(_:)))
            menu.addItem(.separator())
            addAction("Sort by Luminance", #selector(sortSchemeByLuminance(_:)))
            addAction("Reverse Order", #selector(reverseSchemeOrder(_:)))
            addAction("Invert Scheme", #selector(invertScheme(_:)))
            addAction("Random Scheme", #selector(randomColors(sender:)))
            addAction("Unlock All Panels", #selector(unlockAllPanels(_:)))
            menu.addItem(.separator())
            addAction("Copy Hex List", #selector(copySchemeHexList(_:)))
            addAction("Copy CSS Variables", #selector(copySchemeCSS(_:)))
            addAction("Copy Swift Array", #selector(copySchemeSwift(_:)))
            addAction("Copy JSON", #selector(copySchemeJSON(_:)))
            addAction("Copy SVG Swatch", #selector(copySchemeSVG(_:)))

            pullDown.translatesAutoresizingMaskIntoConstraints = false
            pullDown.widthAnchor.constraint(greaterThanOrEqualToConstant: 86).isActive = true
            item.view = pullDown
            return item
        }

        return nil
    }

    override func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.action == #selector(selectHarmonyMode(_:)) {
            menuItem.state = (menuItem.tag == harmonyMode.rawValue) ? .on : .off
            return true
        }
        return true
    }

    private func saveWindowFrame() {
        guard let window = mainWindow else { return }
        UserDefaults.standard.set(window.stringWithSavedFrame, forKey: Document.windowFrameDefaultsKey)
    }

    func windowDidResize(_ notification: Notification) {
        saveWindowFrame()
    }

    func windowDidMove(_ notification: Notification) {
        saveWindowFrame()
    }

    func windowWillClose(_ notification: Notification) {
        saveWindowFrame()
    }

    override func windowDidLoad() {
        super.windowDidLoad()
        shouldCascadeWindows = false
        NSColorPanel.shared.isContinuous = true
        NSColorPanel.shared.showsAlpha = false
        mainWindow.titleVisibility = .hidden
        mainWindow.styleMask.insert(.fullSizeContentView)

        if let savedFrame = UserDefaults.standard.string(forKey: Document.windowFrameDefaultsKey) {
            mainWindow.setFrameFrom(savedFrame)
        } else {
            var initialFrame = mainWindow.frame
            initialFrame.size = NSSize(width: 640, height: 480)
            mainWindow.setFrame(initialFrame, display: false)
            mainWindow.center()
            resetSplitView(sender: self)
            saveWindowFrame()
        }

        setupLockButtons()
        setupToolbarControls()

        randomColors(sender: self)
        window?.undoManager?.removeAllActions()
    }
}

