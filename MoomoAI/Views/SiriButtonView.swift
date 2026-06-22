import SwiftUI

struct SiriButtonView: View {
    @State private var position: CGPoint = .zero
    @State private var isPressed = false
    @State private var glowAnimation = false
    @State private var hasInitialized = false
    
    var onTap: () -> Void
    
    var body: some View {
        GeometryReader { geometry in
            buttonContent
                .position(position)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            position = value.location
                        }
                        .onEnded { value in
                            snapToEdge(in: geometry.size)
                        }
                )
                .onAppear {
                    if !hasInitialized {
                        position = CGPoint(
                            x: geometry.size.width - 80,
                            y: geometry.size.height - 150
                        )
                        hasInitialized = true
                        glowAnimation = true
                    }
                }
        }
    }
    
    private var buttonContent: some View {
        ZStack {
            // Outer glow layers
            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [
                            Color.blue.opacity(glowAnimation ? 0.6 : 0.3),
                            Color.purple.opacity(glowAnimation ? 0.4 : 0.2),
                            Color.clear
                        ]),
                        center: .center,
                        startRadius: 20,
                        endRadius: glowAnimation ? 50 : 35
                    )
                )
                .frame(width: 80, height: 80)
                .blur(radius: glowAnimation ? 15 : 10)
                .scaleEffect(isPressed ? 1.2 : 1.0)
                .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: glowAnimation)
            
            // Middle glow
            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [
                            Color.cyan.opacity(0.6),
                            Color.blue.opacity(0.4),
                            Color.purple.opacity(0.2)
                        ]),
                        center: .center,
                        startRadius: 10,
                        endRadius: 30
                    )
                )
                .frame(width: 60, height: 60)
                .blur(radius: 8)
                .scaleEffect(isPressed ? 0.9 : 1.0)
            
            // Main button
            Circle()
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color(red: 0.3, green: 0.6, blue: 1.0),
                            Color(red: 0.5, green: 0.3, blue: 1.0)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 50, height: 50)
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.3), lineWidth: 2)
                )
                .shadow(color: .blue.opacity(0.5), radius: 10, x: 0, y: 5)
                .scaleEffect(isPressed ? 0.85 : 1.0)
            
            // Siri wave icon
            Image(systemName: "waveform")
                .font(.system(size: 24, weight: .medium))
                .foregroundColor(.white)
                .scaleEffect(isPressed ? 0.85 : 1.0)
        }
        .onTapGesture {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                isPressed = true
            }
            
            // Call the action
            onTap()
            
            // Reset pressed state
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                withAnimation {
                    isPressed = false
                }
            }
        }
    }
    
    private func snapToEdge(in size: CGSize) {
        let screenWidth = size.width
        let screenHeight = size.height
        let margin: CGFloat = 50
        
        // Keep button within screen bounds
        position.x = max(margin, min(position.x, screenWidth - margin))
        position.y = max(margin, min(position.y, screenHeight - margin))
        
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            // Optionally snap to nearest edge
            if position.x < screenWidth / 2 {
                position.x = margin
            } else {
                position.x = screenWidth - margin
            }
        }
    }
}

// Preview
struct SiriButtonView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            SiriButtonView {
                print("Siri button tapped!")
            }
        }
    }
}
