import Cocoa
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var preferencesWindow: NSWindow?
    var onboardingWindow: NSWindow?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Build the status bar menu item
        setupStatusItem()
        
        // Link the global hotkey trigger callback
        KeyboardShortcutManager.shared.onTrigger = { [weak self] in
            self?.toggleFocus()
        }
        
        // Check Accessibility permission and show onboarding if needed
        if !FocusEngine.shared.checkAccessibilityPermission() {
            showOnboardingWindow()
        }
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        // Make sure we restore windows if the app is quit while focused
        if FocusEngine.shared.isFocused {
            FocusEngine.shared.restore()
        }
    }
    
    // MARK: - Menu Bar Setup
    
    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            // Use native SF Symbol for the menu bar icon
            if let image = NSImage(systemSymbolName: "viewfinder", accessibilityDescription: "FocusDesk") {
                image.isTemplate = true
                button.image = image
            }
        }
        
        let menu = NSMenu()
        
        let statusTitleItem = NSMenuItem(title: "Status: Active", action: nil, keyEquivalent: "")
        statusTitleItem.tag = 100
        statusTitleItem.isEnabled = false
        menu.addItem(statusTitleItem)
        
        let toggleItem = NSMenuItem(title: "Focus Workspace", action: #selector(toggleFocus), keyEquivalent: "")
        toggleItem.tag = 101
        toggleItem.target = self
        menu.addItem(toggleItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let prefsItem = NSMenuItem(title: "Preferences...", action: #selector(showPreferencesWindow), keyEquivalent: ",")
        prefsItem.target = self
        menu.addItem(prefsItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let quitItem = NSMenuItem(title: "Quit FocusDesk", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)
        
        statusItem?.menu = menu
        updateMenu()
    }
    
    private func updateMenu() {
        guard let menu = statusItem?.menu else { return }
        
        let isFocused = FocusEngine.shared.isFocused
        
        if let statusItem = menu.item(withTag: 100) {
            statusItem.title = isFocused ? "Status: Focused" : "Status: Active"
        }
        
        if let toggleItem = menu.item(withTag: 101) {
            toggleItem.title = isFocused ? "Restore Windows" : "Focus Workspace"
        }
    }
    
    // MARK: - Actions
    
    @objc func toggleFocus() {
        if !FocusEngine.shared.checkAccessibilityPermission() {
            showOnboardingWindow()
            return
        }
        FocusEngine.shared.toggleFocus()
        updateMenu()
    }
    
    // MARK: - Windows Management
    
    @objc func showPreferencesWindow() {
        if let window = preferencesWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 320),
            styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "FocusDesk Preferences"
        window.center()
        window.isReleasedWhenClosed = false
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        
        // Host the SwiftUI view natively
        window.contentView = NSHostingView(rootView: PreferencesView())
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(preferencesWindowWillClose),
            name: NSWindow.willCloseNotification,
            object: window
        )
        
        self.preferencesWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc func preferencesWindowWillClose(notification: Notification) {
        if let window = notification.object as? NSWindow, window == preferencesWindow {
            preferencesWindow = nil
            NotificationCenter.default.removeObserver(
                self,
                name: NSWindow.willCloseNotification,
                object: window
            )
        }
    }
    
    @objc func showOnboardingWindow() {
        if let window = onboardingWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 430),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "FocusDesk Onboarding"
        window.center()
        window.isReleasedWhenClosed = false
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        
        // Host the SwiftUI onboarding view
        window.contentView = NSHostingView(rootView: OnboardingView(onDismiss: { [weak self] in
            self?.onboardingWindow?.close()
        }))
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(onboardingWindowWillClose),
            name: NSWindow.willCloseNotification,
            object: window
        )
        
        self.onboardingWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc func onboardingWindowWillClose(notification: Notification) {
        if let window = notification.object as? NSWindow, window == onboardingWindow {
            onboardingWindow = nil
            NotificationCenter.default.removeObserver(
                self,
                name: NSWindow.willCloseNotification,
                object: window
            )
        }
    }
}

// Start NSApplication
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
