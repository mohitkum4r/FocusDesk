import SwiftUI

public struct OnboardingView: View {
    @State private var timer = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()
    @State private var checkStatus = false
    
    public var onDismiss: () -> Void
    
    public init(onDismiss: @escaping () -> Void) {
        self.onDismiss = onDismiss
    }
    
    public var body: some View {
        VStack(spacing: 24) {
            // Header Icon with premium gradient glow
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [Color.blue.opacity(0.15), Color.purple.opacity(0.15)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 80, height: 80)
                
                Image(systemName: "hand.raised.fill")
                    .font(.system(size: 38, weight: .semibold))
                    .foregroundStyle(LinearGradient(
                        colors: [Color.blue, Color.purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
            }
            .padding(.top, 16)
            
            // Text Content
            VStack(spacing: 8) {
                Text("Accessibility Permission Required")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.primary)
                
                Text("FocusDesk needs permission to manage other windows. This allows the Focus Engine to minimize background applications and restore them later.")
                    .font(.system(size: 13, weight: .regular))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .lineSpacing(4)
                    .padding(.horizontal, 16)
            }
            
            // Steps instructions in a card
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "1.circle.fill")
                        .foregroundColor(.blue)
                    Text("Click 'Open System Settings' below.")
                        .font(.system(size: 12, weight: .medium))
                }
                
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "2.circle.fill")
                        .foregroundColor(.blue)
                    Text("Find **FocusDesk** in the Accessibility list.")
                        .font(.system(size: 12, weight: .medium))
                }
                
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "3.circle.fill")
                        .foregroundColor(.blue)
                    Text("Toggle the switch to **On**.")
                        .font(.system(size: 12, weight: .medium))
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity)
            .background(Color(NSColor.windowBackgroundColor).opacity(0.5))
            .cornerRadius(12)
            .padding(.horizontal, 16)
            
            // Action Buttons
            VStack(spacing: 8) {
                Button(action: openSystemSettings) {
                    Text("Open System Settings")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 24)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(LinearGradient(
                                    colors: [Color.blue, Color(red: 0.1, green: 0.4, blue: 0.9)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ))
                        )
                }
                .buttonStyle(.plain)
                
                HStack(spacing: 4) {
                    ProgressView()
                        .controlSize(.small)
                        .scaleEffect(0.8)
                    Text("Waiting for permission...")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .frame(width: 380, height: 430)
        .padding(16)
        .background(VisualEffectView(material: .hudWindow, blendingMode: .behindWindow))
        .onReceive(timer) { _ in
            if AXIsProcessTrusted() {
                self.timer.upstream.connect().cancel()
                self.onDismiss()
            }
        }
    }
    
    private func openSystemSettings() {
        // Trigger OS system prompt
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        
        // Directly open settings page as backup
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }
}

// Helper to provide native vibrancy
struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
