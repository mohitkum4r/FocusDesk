import SwiftUI

public struct PreferencesView: View {
    @ObservedObject private var shortcutManager = KeyboardShortcutManager.shared
    
    @State private var hideOtherWindowsOfActiveApp = UserDefaults.standard.object(forKey: "hideOtherWindowsOfActiveApp") as? Bool ?? true
    @State private var isHoveringRecord = false
    @State private var isHoveringReset = false
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 20) {
            // App Header
            HStack(spacing: 12) {
                Image(systemName: "viewfinder")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(.blue)
                VStack(alignment: .leading, spacing: 2) {
                    Text("FocusDesk")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                    Text("Version 1.0 (Local-Only)")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 8)
            
            Divider()
            
            // Section 1: Keyboard Shortcut
            VStack(alignment: .leading, spacing: 10) {
                Text("Keyboard Shortcut")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.secondary)
                
                HStack {
                    Text("Toggle Focus Mode")
                        .font(.system(size: 13, weight: .medium))
                    
                    Spacer()
                    
                    if shortcutManager.isRecording {
                        // Pulsing Recording UI
                        Text("Press keys...")
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .foregroundColor(.white)
                            .padding(.vertical, 5)
                            .padding(.horizontal, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.red)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.red.opacity(0.5), lineWidth: 2)
                                    .scaleEffect(1.1)
                            )
                    } else {
                        Button(action: {
                            shortcutManager.startRecording()
                        }) {
                            Text(shortcutManager.currentShortcutString)
                                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                                .foregroundColor(.primary)
                                .padding(.vertical, 4)
                                .padding(.horizontal, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(isHoveringRecord ? Color.blue.opacity(0.15) : Color(NSColor.controlBackgroundColor))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(isHoveringRecord ? Color.blue.opacity(0.3) : Color.gray.opacity(0.2), lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                        .onHover { hovering in
                            isHoveringRecord = hovering
                        }
                    }
                    
                    if !shortcutManager.isRecording {
                        Button(action: {
                            shortcutManager.resetToDefault()
                        }) {
                            Image(systemName: "arrow.counterclockwise")
                                .foregroundColor(.secondary)
                                .font(.system(size: 12))
                                .padding(6)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(isHoveringReset ? Color.red.opacity(0.1) : Color.clear)
                                )
                        }
                        .buttonStyle(.plain)
                        .help("Reset shortcut to default (⌥F)")
                        .onHover { hovering in
                            isHoveringReset = hovering
                        }
                    }
                }
                .padding(12)
                .background(Color(NSColor.windowBackgroundColor).opacity(0.4))
                .cornerRadius(10)
            }
            
            // Section 2: Behavior
            VStack(alignment: .leading, spacing: 10) {
                Text("Focus Behavior")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.secondary)
                
                VStack(alignment: .leading, spacing: 12) {
                    Toggle(isOn: $hideOtherWindowsOfActiveApp) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Isolate Frontmost Window Only")
                                .font(.system(size: 13, weight: .medium))
                            Text("Minimize other windows of the active app in addition to other applications.")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                    }
                    .toggleStyle(.checkbox)
                    .onChange(of: hideOtherWindowsOfActiveApp) { oldValue, newValue in
                        UserDefaults.standard.set(newValue, forKey: "hideOtherWindowsOfActiveApp")
                    }
                }
                .padding(12)
                .background(Color(NSColor.windowBackgroundColor).opacity(0.4))
                .cornerRadius(10)
            }
            
            Spacer()
            
            // Footer Info
            Text("FocusDesk operates entirely locally on your machine.")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(20)
        .frame(width: 420, height: 320)
        .background(VisualEffectView(material: .hudWindow, blendingMode: .behindWindow))
    }
}
