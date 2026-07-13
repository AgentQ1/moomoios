//
//  WelcomeView.swift
//  MoomoAI
//
//  Empty chat "home" body — the glowing sparkle orb, a sparkle divider, and the
//  "Intelligence, made effortless." tagline. The Moomo brand cluster lives in the
//  chat header (MoomoBrandHeader); this view fills the space beneath it.
//

import SwiftUI

struct WelcomeView: View {
    var body: some View {
        // Spacers use small minimums so this view can compress when the keyboard
        // takes over half the screen; with the keyboard hidden they still expand
        // to fill, so the resting layout is unchanged.
        VStack(spacing: 0) {
            Spacer(minLength: 8)

            // Glowing sparkle orb.
            GlowingSparkleOrb()

            // Sparkle divider.
            MoomoDivider()
                .padding(.top, 18)

            // Tagline.
            Text("Intelligence, made effortless.")
                .font(.system(size: 17, weight: .regular))
                .foregroundColor(K.Colors.textSecondary)
                .padding(.top, 18)

            Spacer(minLength: 8)
            // Bias the cluster slightly above vertical center, matching the screenshot.
            Spacer(minLength: 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct WelcomeView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            LuxuryBackground()
            WelcomeView()
        }
        .preferredColorScheme(.light)
    }
}
