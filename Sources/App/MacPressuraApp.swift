// Sources/App/MacPressuraApp.swift
import SwiftUI
import AppKit

@main
struct MacPressuraApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = MainViewModel()

    var body: some Scene {
        Window("MacPressura", id: "main") {
            ContentView()
                .environmentObject(model)
                .environmentObject(model.jobQueue)
                .frame(minWidth: 780, minHeight: 500)
        }
        .windowResizability(.contentMinSize)
        .defaultSize(width: 960, height: 620)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button(String(localized: "Open Archive…")) {
                    model.presentOpenPanel()
                }
                .keyboardShortcut("o", modifiers: .command)

                Button(String(localized: "New Archive…")) {
                    model.presentNewArchivePanel()
                }
                .keyboardShortcut("n", modifiers: .command)
            }

            CommandMenu(String(localized: "Archive")) {
                Button(String(localized: "Extract (Default)")) {
                    model.extractCurrent()
                }
                .keyboardShortcut("e", modifiers: .command)
                .disabled(model.archive == nil)

                Button(String(localized: "Extract Here")) {
                    model.extractCurrent(target: .here)
                }
                .disabled(model.archive == nil)

                Button(String(localized: "Extract to Folder Named After Archive")) {
                    model.extractCurrent(target: .subfolder)
                }
                .disabled(model.archive == nil)

                Button(String(localized: "Extract to…")) {
                    model.extractCurrent(target: .ask)
                }
                .keyboardShortcut("e", modifiers: [.command, .shift])
                .disabled(model.archive == nil)

                Divider()

                Button(String(localized: "Show in Finder")) {
                    model.revealArchiveInFinder()
                }
                .disabled(model.archive == nil)

                Button(String(localized: "Close Archive")) {
                    model.closeArchive()
                }
                .keyboardShortcut("w", modifiers: [.command, .shift])
                .disabled(model.archive == nil)
            }

            CommandGroup(after: .toolbar) {
                Button(model.showJobs ? String(localized: "Hide Tasks") : String(localized: "Show Tasks")) {
                    model.showJobs.toggle()
                }
                .keyboardShortcut("j", modifiers: .command)
            }
        }

        Settings {
            SettingsView()
                .environmentObject(model)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.activate(ignoringOtherApps: false)
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        Task { @MainActor in
            OpenURLRelay.shared.deliver(urls)
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        true
    }
}
