//
//  AppModel.swift
//  CustomFolder
//
//  Created by Codex on 26.02.26.
//

import AppKit
import Combine
import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class AppModel: ObservableObject {
    enum FolderTextureSource: String, CaseIterable, Identifiable {
        case full = "Full"
        case empty = "Empty"
        case current = "Current"

        var id: String { rawValue }
    }

    enum IconCompositionMode: String, CaseIterable, Identifiable {
        case overlay = "Overlay"
        case replace = "Replace"

        var id: String { rawValue }
    }

    struct SymbolItem: Identifiable {
        let id: String
        let name: String

        var image: NSImage {
            let config = NSImage.SymbolConfiguration(pointSize: 20, weight: .regular)
            return NSImage(systemSymbolName: name, accessibilityDescription: nil)?.withSymbolConfiguration(config) ?? NSImage()
        }
    }

    enum IconBlendMode: String, CaseIterable, Identifiable {
        case normal = "Normal"
        case multiply = "Multiply"
        case screen = "Screen"
        case overlay = "Overlay"
        case softLight = "Soft Light"

        var id: String { rawValue }

        var compositingOperation: NSCompositingOperation {
            switch self {
            case .normal:
                return .sourceOver
            case .multiply:
                return .multiply
            case .screen:
                return .screen
            case .overlay:
                return .overlay
            case .softLight:
                return .softLight
            }
        }
    }

    @Published var selectedFolderURL: URL?
    @Published var droppedImage: NSImage?
    @Published var folderTintColor: Color = Color(red: 0.31, green: 0.58, blue: 0.96)
    @Published var folderTintIntensity: Double = 0.45
    @Published var statusMessage = "Drop an image or SF Symbol"
    @Published var dropTargetIsActive = false
    @Published var compositionMode: IconCompositionMode = .overlay
    @Published var resetRotateTrigger: Int = 0
    @Published var resetWiggleTrigger: Int = 0
    @Published var revealBounceTrigger: Int = 0
    @Published var applySuccessTrigger: Int = 0
    @Published var iconShadow: Double = 5
    @Published var iconScale: Double = 1.0
    @Published var iconOpacity: Double = 1.0
    @Published var iconBlendMode: IconBlendMode = .overlay
    @Published var iconTintColor: Color = Color(red: 64.0/255.0, green: 64.0/255.0, blue: 64.0/255.0)
    @Published var iconTintIntensity: Double = 1.0
    @Published var folderTextureSource: FolderTextureSource = .current

    @Published var symbols: [SymbolItem] = [
        "star.fill", "heart.fill", "flame.fill", "bolt.fill", "leaf.fill", "pawprint.fill",
        "moon.stars.fill", "sun.max.fill", "cloud.fill", "book.fill", "music.note", "headphones",
        "gamecontroller.fill", "camera.fill", "film.fill", "paintpalette.fill", "hammer.fill", "wrench.fill",
        "shippingbox.fill", "gift.fill", "tag.fill", "cart.fill", "briefcase.fill", "person.fill",
        "sparkles", "brain.head.profile", "car.fill", "airplane", "house.fill", "folder.fill"
    ].map { SymbolItem(id: $0, name: $0) }

    private var didPromptForFolder = false
    private var securityScopedFolderURL: URL?
    private var folderSourceCacheKey: String?
    private var folderSourceCacheImage: NSImage?
    private var folderTintMaskCacheImage: NSImage?
    private var folderResultCacheKey: String?
    private var folderResultCacheImage: NSImage?

    var folderPathText: String {
        selectedFolderURL?.path ?? "No folder selected"
    }

    var previewIcon: NSImage {
        let folderBase = tintedFolderIcon()
        guard let droppedImage else { return folderBase }

        switch compositionMode {
        case .overlay:
            return overlayIcon(base: folderBase, overlay: droppedImage)
        case .replace:
            return droppedImage
        }
    }

    func promptForFolderAtLaunchIfNeeded() {
        guard !didPromptForFolder else { return }
        guard ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] != "1" else { return }
        didPromptForFolder = true

        DispatchQueue.main.async { [weak self] in
            self?.chooseFolder()
        }
    }

    deinit {
        securityScopedFolderURL?.stopAccessingSecurityScopedResource()
    }

    func chooseFolder() {
        let panel = NSOpenPanel()
        panel.title = "Select a folder"
        panel.message = "Choose a folder to customize."
        panel.prompt = "Select Folder"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = selectedFolderURL ?? FileManager.default.homeDirectoryForCurrentUser

        guard panel.runModal() == .OK, let url = panel.url else {
            if selectedFolderURL == nil {
                statusMessage = "Select a folder to begin"
            }
            return
        }

        securityScopedFolderURL?.stopAccessingSecurityScopedResource()
        _ = url.startAccessingSecurityScopedResource()
        securityScopedFolderURL = url

        withAnimation(.spring(response: 0.4, dampingFraction: 0.84)) {
            selectedFolderURL = url
        }
        invalidateFolderTintCache()
        statusMessage = "Drop an image or SF Symbol"
    }

    func chooseIconImage() {
        let panel = NSOpenPanel()
        panel.title = "Choose custom icon image"
        panel.message = "Pick an image to use as the folder icon."
        panel.prompt = "Choose Image"
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.image]

        guard panel.runModal() == .OK, let url = panel.url, let image = NSImage(contentsOf: url) else {
            return
        }

        setDroppedImage(image, importedFromSymbol: false)
    }

    func setDroppedSymbol(named symbolName: String) {
        let size = NSSize(width: 512, height: 512)
        let config = NSImage.SymbolConfiguration(pointSize: 340, weight: .regular)

        guard let symbol = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)?.withSymbolConfiguration(config) else {
            statusMessage = "Could not use symbol \(symbolName)"
            return
        }

        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.clear.setFill()
        NSBezierPath(rect: NSRect(origin: .zero, size: size)).fill()

        let targetRect = NSRect(
            x: (size.width - 320) / 2,
            y: (size.height - 320) / 2,
            width: 320,
            height: 320
        )
        let symbolSize = symbol.size
        let fitScale = min(
            targetRect.width / max(symbolSize.width, 1),
            targetRect.height / max(symbolSize.height, 1)
        )
        let fittedSize = NSSize(width: symbolSize.width * fitScale, height: symbolSize.height * fitScale)
        let fittedRect = NSRect(
            x: targetRect.midX - (fittedSize.width / 2),
            y: targetRect.midY - (fittedSize.height / 2),
            width: fittedSize.width,
            height: fittedSize.height
        )
        symbol.draw(in: fittedRect, from: .zero, operation: .sourceOver, fraction: 1)
        image.unlockFocus()

        setDroppedImage(image, importedFromSymbol: true)
    }

    func clearDroppedImage() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            droppedImage = nil
        }
        statusMessage = "Drop an image or SF Symbol"
    }

    func applyFolderCustomization() {
        guard let folderURL = selectedFolderURL else {
            chooseFolder()
            return
        }

        let icon = normalizedIcon(from: previewIcon)
        let didSet = withSelectedFolderAccess(folderURL) {
            FolderIconManager.setIcon(icon, for: folderURL)
        } ?? false
        if didSet {
            invalidateFolderTintCache()
        }
        statusMessage = didSet ? "Folder customization applied" : "Failed to apply folder customization"
        if didSet { applySuccessTrigger += 1 }
    }

    func resetFolderCustomization() {
        guard let folderURL = selectedFolderURL else {
            statusMessage = "Select a folder first"
            chooseFolder()
            return
        }

        guard FileManager.default.fileExists(atPath: folderURL.path) else {
            statusMessage = "Selected folder no longer exists"
            selectedFolderURL = nil
            return
        }

        let hadCustomIcon = withSelectedFolderAccess(folderURL) {
            FolderIconManager.hasCustomIcon(folderURL)
        } ?? false

        guard hadCustomIcon else {
            statusMessage = "Nothing to reset"
            resetWiggleTrigger += 1
            return
        }

        let didReset = withSelectedFolderAccess(folderURL) {
            FolderIconManager.removeIcon(from: folderURL)
        } ?? false
        if didReset {
            invalidateFolderTintCache()
        }
        statusMessage = didReset ? "Folder customization reset" : "Failed to reset folder customization"
        if didReset {
            clearDroppedImage()
            resetRotateTrigger += 1
        }
    }

    func revealSelectedFolderInFinder() {
        guard let folderURL = selectedFolderURL else {
            statusMessage = "Select a folder first"
            chooseFolder()
            return
        }

        guard FileManager.default.fileExists(atPath: folderURL.path) else {
            statusMessage = "Selected folder no longer exists"
            selectedFolderURL = nil
            return
        }

        NSWorkspace.shared.activateFileViewerSelecting([folderURL])
        revealBounceTrigger += 1
        statusMessage = "Revealed in Finder"
    }

    func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        if let symbolProvider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) }) {
            symbolProvider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { [weak self] item, _ in
                let symbolName: String?
                if let data = item as? Data {
                    symbolName = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
                } else if let string = item as? String {
                    symbolName = string.trimmingCharacters(in: .whitespacesAndNewlines)
                } else {
                    symbolName = nil
                }

                guard let symbolName, !symbolName.isEmpty else { return }
                Task { @MainActor [weak self] in
                    self?.setDroppedSymbol(named: symbolName)
                }
            }
            return true
        }

        if let fileProvider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) }) {
            fileProvider.loadDataRepresentation(forTypeIdentifier: UTType.fileURL.identifier) { [weak self] data, _ in
                guard let data, let url = URL(dataRepresentation: data, relativeTo: nil), let image = NSImage(contentsOf: url) else {
                    return
                }
                Task { @MainActor [weak self] in
                    self?.setDroppedImage(image)
                }
            }
            return true
        }

        if let imageProvider = providers.first(where: { $0.canLoadObject(ofClass: NSImage.self) }) {
            _ = imageProvider.loadObject(ofClass: NSImage.self) { [weak self] object, _ in
                guard let image = object as? NSImage else { return }
                Task { @MainActor [weak self] in
                    self?.setDroppedImage(image)
                }
            }
            return true
        }

        return false
    }

    func addSymbol(named name: String) {
        guard !symbols.contains(where: { $0.name == name }) else { return }
        withAnimation {
            symbols.insert(SymbolItem(id: name, name: name), at: 0)
        }
    }

    func removeSymbol(named name: String) {
        if let index = symbols.firstIndex(where: { $0.name == name }) {
            withAnimation {
                symbols.remove(at: index)
            }
        }
    }

    private func setDroppedImage(_ image: NSImage, importedFromSymbol: Bool = false) {
        if !importedFromSymbol {
            iconBlendMode = .normal
            iconTintIntensity = 0
        }
        withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
            droppedImage = image
        }
        statusMessage = "Icon ready to apply"
    }

    private func tintedFolderIcon() -> NSImage {
        let canvas = NSSize(width: 512, height: 512)
        let sourceCacheKey = [
            folderTextureSource.rawValue,
            selectedFolderURL?.path ?? "none"
        ].joined(separator: "|")

        let sourceIcon: NSImage
        let tintMask: NSImage
        if
            folderSourceCacheKey == sourceCacheKey,
            let cachedSource = folderSourceCacheImage,
            let cachedMask = folderTintMaskCacheImage
        {
            sourceIcon = cachedSource
            tintMask = cachedMask
        } else {
            let rawSourceIcon: NSImage
            switch folderTextureSource {
            case .full:
                rawSourceIcon = NSImage(named: "Folder_Full")
                    ?? NSWorkspace.shared.icon(for: .folder)
            case .empty:
                rawSourceIcon = NSImage(named: "Folder_Empty")
                    ?? NSWorkspace.shared.icon(for: .folder)
            case .current:
                if let selectedFolderURL {
                    rawSourceIcon = NSWorkspace.shared.icon(forFile: selectedFolderURL.path)
                } else {
                    rawSourceIcon = NSWorkspace.shared.icon(for: .folder)
                }
            }

            sourceIcon = renderedImage(from: rawSourceIcon, size: canvas)
            tintMask = tintMaskImage(from: sourceIcon) ?? fullTintMaskImage(size: canvas)
            folderSourceCacheKey = sourceCacheKey
            folderSourceCacheImage = sourceIcon
            folderTintMaskCacheImage = tintMask
        }

        let tintRGB = NSColor(folderTintColor).usingColorSpace(.deviceRGB) ?? .systemBlue
        let resultCacheKey = [
            sourceCacheKey,
            String(format: "%.4f", folderTintIntensity),
            String(format: "%.4f", tintRGB.redComponent),
            String(format: "%.4f", tintRGB.greenComponent),
            String(format: "%.4f", tintRGB.blueComponent)
        ].joined(separator: "|")
        if let cached = folderResultCacheImage, folderResultCacheKey == resultCacheKey {
            return cached
        }

        let tintedFolder = tintedImage(from: sourceIcon, tintMask: tintMask)
        folderResultCacheKey = resultCacheKey
        folderResultCacheImage = tintedFolder
        return tintedFolder
    }

    private func tintedImage(from sourceIcon: NSImage, tintMask: NSImage) -> NSImage {
        let intensity = CGFloat(max(0, min(folderTintIntensity, 1)))
        guard intensity > 0.001 else { return sourceIcon }
        let canvas = sourceIcon.size

        let tintLayer = NSImage(size: canvas)
        tintLayer.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        sourceIcon.draw(in: NSRect(origin: .zero, size: canvas), from: .zero, operation: .sourceOver, fraction: 1.0)
        let tintColor = NSColor(folderTintColor).usingColorSpace(.deviceRGB) ?? .systemBlue
        tintColor.setFill()
        let tintOp = NSGraphicsContext.current?.compositingOperation ?? .sourceOver
        NSGraphicsContext.current?.compositingOperation = .color
        NSBezierPath(rect: NSRect(origin: .zero, size: canvas)).fill()
        NSGraphicsContext.current?.compositingOperation = tintOp
        tintLayer.unlockFocus()

        let maskedTintLayer = NSImage(size: canvas)
        maskedTintLayer.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        tintLayer.draw(in: NSRect(origin: .zero, size: canvas), from: .zero, operation: .sourceOver, fraction: 1.0)
        tintMask.draw(in: NSRect(origin: .zero, size: canvas), from: .zero, operation: .destinationIn, fraction: 1.0)
        maskedTintLayer.unlockFocus()

        let result = NSImage(size: canvas)
        result.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        sourceIcon.draw(in: NSRect(origin: .zero, size: canvas), from: .zero, operation: .sourceOver, fraction: 1.0)
        maskedTintLayer.draw(in: NSRect(origin: .zero, size: canvas), from: .zero, operation: .sourceOver, fraction: intensity)
        result.unlockFocus()
        return result
    }

    private func renderedImage(from image: NSImage, size: NSSize) -> NSImage {
        let output = NSImage(size: size)
        output.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        NSColor.clear.setFill()
        NSBezierPath(rect: NSRect(origin: .zero, size: size)).fill()
        image.draw(in: NSRect(origin: .zero, size: size), from: .zero, operation: .sourceOver, fraction: 1.0)
        output.unlockFocus()
        return output
    }

    private func tintMaskImage(from sourceIcon: NSImage) -> NSImage? {
        let size = sourceIcon.size
        guard
            let sourceRep = bitmapRepresentation(from: sourceIcon, size: size),
            let maskRep = NSBitmapImageRep(
                bitmapDataPlanes: nil,
                pixelsWide: sourceRep.pixelsWide,
                pixelsHigh: sourceRep.pixelsHigh,
                bitsPerSample: 8,
                samplesPerPixel: 4,
                hasAlpha: true,
                isPlanar: false,
                colorSpaceName: .deviceRGB,
                bytesPerRow: 0,
                bitsPerPixel: 0
            )
        else {
            return nil
        }

        let smoothstep: (CGFloat, CGFloat, CGFloat) -> CGFloat = { edge0, edge1, value in
            if edge0 == edge1 { return value < edge0 ? 0 : 1 }
            let t = max(0, min((value - edge0) / (edge1 - edge0), 1))
            return t * t * (3 - (2 * t))
        }

        let whiteFeatherStart: CGFloat = 0.96
        let whiteCutoff: CGFloat = 0.98
        let sourceSamples = sourceRep.samplesPerPixel
        let maskSamples = maskRep.samplesPerPixel
        guard sourceSamples >= 3, maskSamples >= 3 else { return nil }

        let sourceAlphaFirst = sourceRep.bitmapFormat.contains(.alphaFirst)
        let sourceAlphaIndex = sourceRep.hasAlpha ? (sourceAlphaFirst ? 0 : sourceSamples - 1) : -1
        let sourceRedIndex = sourceAlphaFirst ? 1 : 0
        let sourceGreenIndex = sourceAlphaFirst ? 2 : 1
        let sourceBlueIndex = sourceAlphaFirst ? 3 : 2

        let maskAlphaFirst = maskRep.bitmapFormat.contains(.alphaFirst)
        let maskAlphaIndex = maskRep.hasAlpha ? (maskAlphaFirst ? 0 : maskSamples - 1) : -1
        let maskRedIndex = maskAlphaFirst ? 1 : 0
        let maskGreenIndex = maskAlphaFirst ? 2 : 1
        let maskBlueIndex = maskAlphaFirst ? 3 : 2

        var sourcePixel = [Int](repeating: 0, count: sourceSamples)
        var maskPixel = [Int](repeating: 0, count: maskSamples)

        for y in 0..<sourceRep.pixelsHigh {
            for x in 0..<sourceRep.pixelsWide {
                sourceRep.getPixel(&sourcePixel, atX: x, y: y)

                let red = CGFloat(max(0, min(255, sourcePixel[sourceRedIndex]))) / 255.0
                let green = CGFloat(max(0, min(255, sourcePixel[sourceGreenIndex]))) / 255.0
                let blue = CGFloat(max(0, min(255, sourcePixel[sourceBlueIndex]))) / 255.0
                let alpha = sourceAlphaIndex >= 0
                    ? (CGFloat(max(0, min(255, sourcePixel[sourceAlphaIndex]))) / 255.0)
                    : 1.0
                if alpha <= 0.001 {
                    for i in 0..<maskSamples { maskPixel[i] = 0 }
                    maskRep.setPixel(&maskPixel, atX: x, y: y)
                    continue
                }

                let luminance = (0.2126 * red)
                    + (0.7152 * green)
                    + (0.0722 * blue)
                let whiteSuppression = smoothstep(whiteFeatherStart, whiteCutoff, luminance)
                let tintAmount = 1 - whiteSuppression
                let outAlpha = max(0, min(255, Int(round((alpha * tintAmount) * 255.0))))

                for i in 0..<maskSamples { maskPixel[i] = 0 }
                maskPixel[maskRedIndex] = 255
                maskPixel[maskGreenIndex] = 255
                maskPixel[maskBlueIndex] = 255
                if maskAlphaIndex >= 0 {
                    maskPixel[maskAlphaIndex] = outAlpha
                }
                maskRep.setPixel(&maskPixel, atX: x, y: y)
            }
        }

        let maskImage = NSImage(size: size)
        maskImage.addRepresentation(maskRep)
        return maskImage
    }

    private func fullTintMaskImage(size: NSSize) -> NSImage {
        let image = NSImage(size: size)
        image.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        NSColor.white.setFill()
        NSBezierPath(rect: NSRect(origin: .zero, size: size)).fill()
        image.unlockFocus()
        return image
    }

    private func bitmapRepresentation(from image: NSImage, size: NSSize) -> NSBitmapImageRep? {
        guard
            let rep = NSBitmapImageRep(
                bitmapDataPlanes: nil,
                pixelsWide: Int(size.width),
                pixelsHigh: Int(size.height),
                bitsPerSample: 8,
                samplesPerPixel: 4,
                hasAlpha: true,
                isPlanar: false,
                colorSpaceName: .deviceRGB,
                bytesPerRow: 0,
                bitsPerPixel: 0
            )
        else {
            return nil
        }

        guard let context = NSGraphicsContext(bitmapImageRep: rep) else {
            return nil
        }

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        NSGraphicsContext.current?.imageInterpolation = .high
        NSColor.clear.setFill()
        NSBezierPath(rect: NSRect(origin: .zero, size: size)).fill()
        image.draw(in: NSRect(origin: .zero, size: size), from: .zero, operation: .sourceOver, fraction: 1.0)
        NSGraphicsContext.restoreGraphicsState()
        return rep
    }

    private func invalidateFolderTintCache() {
        folderSourceCacheKey = nil
        folderSourceCacheImage = nil
        folderTintMaskCacheImage = nil
        folderResultCacheKey = nil
        folderResultCacheImage = nil
    }

    private func overlayIcon(base: NSImage, overlay: NSImage) -> NSImage {
        let size = NSSize(width: 512, height: 512)
        let output = NSImage(size: size)

        let normalizedOverlay = normalizedIcon(from: overlay)
        let overlayImage = tintedOverlayImage(from: normalizedOverlay)
        let baseOverlaySize: CGFloat = 230
        let scaledSize = baseOverlaySize * CGFloat(iconScale)
        let overlayRect = NSRect(
            x: 255 - (scaledSize / 2),
            y: 225 - (scaledSize / 2),
            width: scaledSize,
            height: scaledSize
        )

        output.lockFocus()
        base.draw(in: NSRect(origin: .zero, size: size), from: .zero, operation: .sourceOver, fraction: 1)

        if iconShadow > 0 {
            let shadow = NSShadow()
            shadow.shadowColor = NSColor.black.withAlphaComponent(0.28)
            shadow.shadowBlurRadius = CGFloat(iconShadow)
            shadow.shadowOffset = NSSize(width: 0, height: -CGFloat(iconShadow) * 0.45)
            shadow.set()
        }

        overlayImage.draw(
            in: overlayRect,
            from: .zero,
            operation: iconBlendMode.compositingOperation,
            fraction: CGFloat(max(0, min(iconOpacity, 1)))
        )

        NSShadow().set()
        output.unlockFocus()

        return output
    }

    private func tintedOverlayImage(from image: NSImage) -> NSImage {
        guard iconTintIntensity > 0.001 else { return image }

        let output = NSImage(size: image.size)
        output.lockFocus()

        image.draw(in: NSRect(origin: .zero, size: image.size), from: .zero, operation: .sourceOver, fraction: 1)

        let tintColor = NSColor(iconTintColor).withAlphaComponent(CGFloat(max(0, min(iconTintIntensity, 1))))
        tintColor.setFill()

        let previousOperation = NSGraphicsContext.current?.compositingOperation ?? .sourceOver
        NSGraphicsContext.current?.compositingOperation = .sourceAtop
        NSBezierPath(rect: NSRect(origin: .zero, size: image.size)).fill()
        NSGraphicsContext.current?.compositingOperation = previousOperation

        output.unlockFocus()
        return output
    }

    private func normalizedIcon(from image: NSImage) -> NSImage {
        let canvasSize = NSSize(width: 512, height: 512)
        let output = NSImage(size: canvasSize)

        let widthRatio = canvasSize.width / max(image.size.width, 1)
        let heightRatio = canvasSize.height / max(image.size.height, 1)
        let scale = min(widthRatio, heightRatio)
        let drawSize = NSSize(width: image.size.width * scale, height: image.size.height * scale)
        let drawOrigin = NSPoint(
            x: (canvasSize.width - drawSize.width) / 2,
            y: (canvasSize.height - drawSize.height) / 2
        )

        output.lockFocus()
        NSColor.clear.setFill()
        NSBezierPath(rect: NSRect(origin: .zero, size: canvasSize)).fill()
        image.draw(in: NSRect(origin: drawOrigin, size: drawSize), from: .zero, operation: .sourceOver, fraction: 1)
        output.unlockFocus()

        return output
    }

    private func withSelectedFolderAccess<T>(_ folderURL: URL, _ operation: () -> T) -> T? {
        let accessed = folderURL.startAccessingSecurityScopedResource()
        defer {
            if accessed {
                folderURL.stopAccessingSecurityScopedResource()
            }
        }
        return operation()
    }
}
