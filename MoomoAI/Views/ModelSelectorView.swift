//
//  ModelSelectorView.swift
//  MoomoAI
//
//  Static model badge. The app ships a single model (Q1), so there is no picker.
//

import SwiftUI

struct ModelSelectorView: View {
    @Binding var selectedModel: AIModel

    var body: some View {
        HStack(spacing: 4) {
            Text(selectedModel.displayName)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(K.Colors.textSecondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(K.Colors.backgroundPrimary)
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
        )
        .frame(height: 32)
    }
}
