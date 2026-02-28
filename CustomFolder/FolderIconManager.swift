//
//  FolderIconManager.swift
//  CustomFolder
//
//  Created by Lian on 26.02.26.
//


import Cocoa
import UniformTypeIdentifiers

final class FolderIconManager {

    // MARK: - Set Custom Icon
    @discardableResult
    static func setIcon(_ image: NSImage, for folderURL: URL) -> Bool {
        NSWorkspace.shared.setIcon(
            image,
            forFile: folderURL.path,
            options: []
        )
    }

    // MARK: - Get Current Icon
    static func getIcon(for folderURL: URL) -> NSImage {
        NSWorkspace.shared.icon(forFile: folderURL.path)
    }

    // MARK: - Check if Custom Icon Exists
    static func hasCustomIcon(_ folderURL: URL) -> Bool {
        let currentIcon = NSWorkspace.shared.icon(forFile: folderURL.path)
        let defaultIcon = NSWorkspace.shared.icon(for: .folder)
        return !currentIcon.isEqual(defaultIcon)
    }

    // MARK: - Remove Custom Icon
    @discardableResult
    static func removeIcon(from folderURL: URL) -> Bool {
        NSWorkspace.shared.setIcon(
            nil,
            forFile: folderURL.path,
            options: []
        )
    }
}
