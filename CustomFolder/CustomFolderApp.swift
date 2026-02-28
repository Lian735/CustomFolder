//
//  CustomFolderApp.swift
//  CustomFolder
//
//  Created by Lian on 26.02.26.
//

import SwiftUI

@main
struct CustomFolderApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(model)
                .frame(minWidth: 980, minHeight: 700)
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(after: .newItem) {
                Button("Select Folder...") {
                    model.chooseFolder()
                }
                .keyboardShortcut("o", modifiers: [.command])
            }

            CommandMenu("Customization") {
                Button("Choose Icon Image...") {
                    model.chooseIconImage()
                }
                .keyboardShortcut("i", modifiers: [.command, .shift])

                Divider()

                Button("Apply Folder Customization") {
                    model.applyFolderCustomization()
                }
                .keyboardShortcut("s", modifiers: [.command, .shift])
                .disabled(model.selectedFolderURL == nil)

                Button("Reset Folder Customization") {
                    model.resetFolderCustomization()
                }
                .disabled(model.selectedFolderURL == nil)

                Divider()

                Button("Reveal Folder in Finder") {
                    model.revealSelectedFolderInFinder()
                }
                .disabled(model.selectedFolderURL == nil)
            }
        }
    }
}
