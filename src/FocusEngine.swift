import Cocoa
import ApplicationServices

public class FocusEngine: ObservableObject {
    public static let shared = FocusEngine()
    
    @Published public var isFocused = false
    
    // Stores references to windows we minimized during the focus session
    private var minimizedWindows: [AXUIElement] = []
    // Stores the process ID of the app that was active before focusing
    private var previouslyActivePID: pid_t?
    
    private init() {}
    
    // MARK: - Public API
    
    public func checkAccessibilityPermission() -> Bool {
        return AXIsProcessTrusted()
    }
    
    public func toggleFocus() {
        if isFocused {
            restore()
        } else {
            focus()
        }
    }
    
    public func focus() {
        guard checkAccessibilityPermission() else {
            print("FocusDesk: Cannot focus, Accessibility permissions are missing.")
            return
        }
        
        guard let targetApp = getFrontmostApp() else {
            print("FocusDesk: No suitable frontmost application found.")
            return
        }
        
        let targetPid = targetApp.processIdentifier
        previouslyActivePID = targetPid
        
        // Find the active window of the target application
        let targetAppElement = AXUIElementCreateApplication(targetPid)
        var activeWindow: AXUIElement?
        
        var focusedWindowValue: AnyObject?
        let activeWindowResult = AXUIElementCopyAttributeValue(targetAppElement, kAXFocusedWindowAttribute as CFString, &focusedWindowValue)
        if activeWindowResult == .success, let element = focusedWindowValue {
            activeWindow = (element as! AXUIElement)
        }
        
        // If we can't find an active window, we fallback to keeping all windows of the frontmost app visible,
        // but if we do find it, we will keep ONLY that specific window visible.
        
        minimizedWindows.removeAll()
        
        // Traverse all running applications
        let runningApps = NSWorkspace.shared.runningApplications
        let regularApps = runningApps.filter { $0.activationPolicy == .regular }
        
        for app in regularApps {
            let pid = app.processIdentifier
            let appElement = AXUIElementCreateApplication(pid)
            
            // Get all windows for this application
            var windowsValue: AnyObject?
            let result = AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsValue)
            
            guard result == .success, let windows = windowsValue as? [AXUIElement] else {
                continue
            }
            
            let hideOtherWindowsOfActive = UserDefaults.standard.object(forKey: "hideOtherWindowsOfActiveApp") as? Bool ?? true
            
            for window in windows {
                // If this is the active window we want to isolate, don't minimize it
                if let active = activeWindow, CFEqual(window, active) {
                    continue
                }
                
                // If we shouldn't hide other windows of the active app, skip them
                if !hideOtherWindowsOfActive && pid == targetPid {
                    continue
                }
                
                // Also do not minimize other windows of the active app if we failed to identify a specific active window
                // (e.g. if we just want to isolate the frontmost app as a fallback)
                if activeWindow == nil && pid == targetPid {
                    continue
                }
                
                // Query if the window is already minimized
                if isWindowAlreadyMinimized(window) {
                    continue
                }
                
                // Attempt to minimize the window
                if minimizeWindow(window) {
                    minimizedWindows.append(window)
                }
            }
        }
        
        isFocused = true
        print("FocusDesk: Focused! Isolated PID \(targetPid). Minimized \(minimizedWindows.count) windows.")
    }
    
    public func restore() {
        guard checkAccessibilityPermission() else {
            print("FocusDesk: Cannot restore, Accessibility permissions are missing.")
            return
        }
        
        var restoredCount = 0
        for window in minimizedWindows {
            if restoreWindow(window) {
                restoredCount += 1
            }
        }
        
        // Reactivate the app that was frontmost before focusing
        if let pid = previouslyActivePID,
           let app = NSWorkspace.shared.runningApplications.first(where: { $0.processIdentifier == pid }) {
            app.activate()
        }
        
        minimizedWindows.removeAll()
        previouslyActivePID = nil
        isFocused = false
        print("FocusDesk: Restored! Restored \(restoredCount) windows.")
    }
    
    // MARK: - Helper Methods
    
    private func getFrontmostApp() -> NSRunningApplication? {
        if let frontmost = NSWorkspace.shared.frontmostApplication,
           frontmost.bundleIdentifier != Bundle.main.bundleIdentifier {
            return frontmost
        }
        return NSWorkspace.shared.runningApplications.first { app in
            app.isActive && app.bundleIdentifier != Bundle.main.bundleIdentifier
        }
    }
    
    private func isWindowAlreadyMinimized(_ window: AXUIElement) -> Bool {
        var value: AnyObject?
        let result = AXUIElementCopyAttributeValue(window, kAXMinimizedAttribute as CFString, &value)
        if result == .success, let isMin = value as? Bool {
            return isMin
        }
        return false
    }
    
    private func minimizeWindow(_ window: AXUIElement) -> Bool {
        // First try to set the minimized attribute directly
        let value: CFBoolean = kCFBooleanTrue
        let error = AXUIElementSetAttributeValue(window, kAXMinimizedAttribute as CFString, value)
        if error == .success {
            return true
        }
        
        // Fallback: Perform AXMinimizeAction if setting the attribute failed
        var actionNames: CFArray?
        let actionResult = AXUIElementCopyActionNames(window, &actionNames)
        let minimizeAction = "AXMinimize" as CFString
        if actionResult == .success, let actions = actionNames as? [String], actions.contains(minimizeAction as String) {
            let performResult = AXUIElementPerformAction(window, minimizeAction)
            return performResult == .success
        }
        
        return false
    }
    
    private func restoreWindow(_ window: AXUIElement) -> Bool {
        // Unminimize by setting minimized attribute to false
        let value: CFBoolean = kCFBooleanFalse
        let error = AXUIElementSetAttributeValue(window, kAXMinimizedAttribute as CFString, value)
        return error == .success
    }
}
