import SwiftUI

/// Example showing how to use the SiriButtonView in your app
/// Add this to any view where you want the floating Siri button

struct SiriButtonExample: View {
    var body: some View {
        ZStack {
            // Your main content here
            Color.black.ignoresSafeArea()
            
            Text("Your Main Content")
                .foregroundColor(.white)
            
            // Add the Siri button on top of everything
            SiriButtonView {
                // Action to perform when button is tapped
                handleSiriButtonTap()
            }
        }
    }
    
    private func handleSiriButtonTap() {
        print("Siri button tapped!")
        // Add your action here, for example:
        // - Open voice recognition
        // - Start recording
        // - Open a specific view
        // - Trigger an AI assistant
    }
}

/// Example: Adding to ContentView
/// Simply overlay the SiriButtonView on your existing content:
///
/// var body: some View {
///     ZStack {
///         // Your existing content
///         ChatView(showSidebar: $showSidebar)
///
///         // Add Siri button overlay
///         SiriButtonView {
///             // Handle tap action
///             startVoiceRecording()
///         }
///     }
/// }

struct SiriButtonExample_Previews: PreviewProvider {
    static var previews: some View {
        SiriButtonExample()
    }
}
