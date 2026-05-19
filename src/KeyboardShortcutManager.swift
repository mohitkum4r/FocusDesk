import Cocoa
import Carbon
import SwiftUI

public class KeyboardShortcutManager: ObservableObject {
    public static let shared = KeyboardShortcutManager()
    
    @Published public var isRecording = false
    @Published public var currentShortcutString: String = ""
    
    public var onTrigger: (() -> Void)?
    
    private var registeredHotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    private var localMonitor: Any?
    
    private init() {
        self.currentShortcutString = getShortcutString()
        registerSavedShortcut()
    }
    
    deinit {
        unregisterShortcut()
        if let handler = eventHandlerRef {
            RemoveEventHandler(handler)
        }
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }
    
    // MARK: - Public API
    
    public func startRecording() {
        isRecording = true
        // Listen to key down events in our window
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }
            
            let keyCode = event.keyCode
            if self.isModifierOnly(keyCode) {
                return event // Pass through modifier-only events
            }
            
            // Clean up and save
            let modifiers = event.modifierFlags
            self.saveShortcut(keyCode: keyCode, modifiers: modifiers)
            self.stopRecording()
            
            return nil // Consume event
        }
    }
    
    public func stopRecording() {
        isRecording = false
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
    }
    
    public func resetToDefault() {
        UserDefaults.standard.removeObject(forKey: "shortcutKeyCode")
        UserDefaults.standard.removeObject(forKey: "shortcutModifiers")
        self.currentShortcutString = getShortcutString()
        registerSavedShortcut()
    }
    
    // MARK: - Core Implementation
    
    private func isModifierOnly(_ keyCode: UInt16) -> Bool {
        // macOS modifier key codes
        return [55, 56, 57, 58, 59, 60, 61, 62, 63].contains(keyCode)
    }
    
    private func saveShortcut(keyCode: UInt16, modifiers: NSEvent.ModifierFlags) {
        // Only allow option, command, control, shift
        let filteredModifiers = modifiers.intersection([.option, .command, .control, .shift])
        
        UserDefaults.standard.set(Int(keyCode), forKey: "shortcutKeyCode")
        UserDefaults.standard.set(filteredModifiers.rawValue, forKey: "shortcutModifiers")
        
        self.currentShortcutString = getShortcutString()
        registerSavedShortcut()
    }
    
    private var savedKeyCode: UInt16 {
        if UserDefaults.standard.object(forKey: "shortcutKeyCode") == nil {
            return 3 // Default: 'F' key
        }
        return UInt16(UserDefaults.standard.integer(forKey: "shortcutKeyCode"))
    }
    
    private var savedModifiers: NSEvent.ModifierFlags {
        if UserDefaults.standard.object(forKey: "shortcutModifiers") == nil {
            return .option // Default: Option
        }
        return NSEvent.ModifierFlags(rawValue: UInt(UserDefaults.standard.integer(forKey: "shortcutModifiers")))
    }
    
    private func registerSavedShortcut() {
        unregisterShortcut()
        
        let keyCode = savedKeyCode
        let modifiers = savedModifiers
        
        // Convert Cocoa modifiers to Carbon modifiers
        var carbonMods: UInt32 = 0
        if modifiers.contains(.command) { carbonMods |= UInt32(cmdKey) }
        if modifiers.contains(.option)  { carbonMods |= UInt32(optionKey) }
        if modifiers.contains(.control) { carbonMods |= UInt32(controlKey) }
        if modifiers.contains(.shift)   { carbonMods |= UInt32(shiftKey) }
        
        var hotKeyID = EventHotKeyID()
        hotKeyID.signature = OSType(0x464F4355) // "FOCU"
        hotKeyID.id = 1
        
        // Install Carbon handler if not already installed
        if eventHandlerRef == nil {
            var eventType = EventTypeSpec()
            eventType.eventClass = OSType(kEventClassKeyboard)
            eventType.eventKind = OSType(kEventHotKeyPressed)
            
            let handlerUPP: EventHandlerUPP = { (nextHandler, theEvent, userData) -> OSStatus in
                guard let userData = userData else { return noErr }
                let manager = Unmanaged<KeyboardShortcutManager>.fromOpaque(userData).takeUnretainedValue()
                manager.handleCarbonHotKey(theEvent)
                return noErr
            }
            
            let userData = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
            let status = InstallEventHandler(GetApplicationEventTarget(), handlerUPP, 1, &eventType, userData, &eventHandlerRef)
            if status != noErr {
                print("FocusDesk: Failed to install event handler (\(status))")
            }
        }
        
        // Register the hotkey
        let status = RegisterEventHotKey(
            UInt32(keyCode),
            carbonMods,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &registeredHotKeyRef
        )
        
        if status != noErr {
            print("FocusDesk: Failed to register hotkey (\(status))")
        }
    }
    
    private func unregisterShortcut() {
        if let ref = registeredHotKeyRef {
            UnregisterEventHotKey(ref)
            registeredHotKeyRef = nil
        }
    }
    
    private func handleCarbonHotKey(_ theEvent: EventRef?) {
        var hotKeyID = EventHotKeyID()
        let size = MemoryLayout<EventHotKeyID>.size
        let status = GetEventParameter(
            theEvent,
            EventParamName(kEventParamDirectObject),
            EventParamType(typeEventHotKeyID),
            nil,
            size,
            nil,
            &hotKeyID
        )
        
        if status == noErr && hotKeyID.id == 1 {
            DispatchQueue.main.async {
                self.onTrigger?()
            }
        }
    }
    
    // MARK: - Utility formatting
    
    public func getShortcutString() -> String {
        let mods = savedModifiers
        let code = savedKeyCode
        
        var str = ""
        if mods.contains(.control) { str += "⌃" }
        if mods.contains(.option)  { str += "⌥" }
        if mods.contains(.shift)   { str += "⇧" }
        if mods.contains(.command) { str += "⌘" }
        
        str += stringFromKeyCode(code)
        return str
    }
    
    private func stringFromKeyCode(_ keyCode: UInt16) -> String {
        // Handle special keycodes manually for consistency
        switch keyCode {
        case 49: return "Space"
        case 53: return "⎋" // Escape
        case 36: return "↩" // Return
        case 48: return "⇥" // Tab
        case 117: return "⌦" // Delete
        case 51: return "⌫" // Backspace
        case 123: return "←"
        case 124: return "→"
        case 125: return "↓"
        case 126: return "↑"
        default: break
        }
        
        // Translate key code based on keyboard layout
        guard let source = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue() else { return "" }
        let layoutDataRef = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData)
        
        // Safely check and cast LayoutData
        guard let layoutDataPtr = layoutDataRef else { return "" }
        let layoutData = unsafeBitCast(layoutDataPtr, to: CFData.self)
        let keyLayout = unsafeBitCast(CFDataGetBytePtr(layoutData), to: UnsafePointer<UCKeyboardLayout>.self)
        
        var deadKeys: UInt32 = 0
        let maxStringLength = 4
        var unicodeString = [UniChar](repeating: 0, count: maxStringLength)
        var actualStringLength = 0
        
        let status = UCKeyTranslate(
            keyLayout,
            keyCode,
            UInt16(kUCKeyActionDown),
            0,
            UInt32(LMGetKbdType()),
            UInt32(kUCKeyTranslateNoDeadKeysBit),
            &deadKeys,
            maxStringLength,
            &actualStringLength,
            &unicodeString
        )
        
        if status == noErr && actualStringLength > 0 {
            return String(utf16CodeUnits: unicodeString, count: actualStringLength).uppercased()
        }
        
        return ""
    }
}
