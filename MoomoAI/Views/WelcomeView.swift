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
        VStack(spacing: 0) {
            Spacer(minLength: 40)

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

            Spacer(minLength: 40)
            // Bias the cluster slightly above vertical center, matching the screenshot.
            Spacer(minLength: 40)
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
