//
//  AnimationConstants.swift
//  MoomoAI
//
//  Centralized animation constants for consistent app-wide animations
//

import SwiftUI

enum AnimationConstants {
    // MARK: - Duration
    static let fast: Double = 0.2
    static let standard: Double = 0.3
    static let medium: Double = 0.4
    static let slow: Double = 0.5
    
    // MARK: - Spring Animations
    static let springFast = Animation.spring(response: 0.3, dampingFraction: 0.7)
    static let springStandard = Animation.spring(response: 0.4, dampingFraction: 0.75)
    static let springBouncy = Animation.spring(response: 0.5, dampingFraction: 0.6)
    
    // MARK: - Easing Animations
    static let easeOut = Animation.easeOut(duration: standard)
    static let easeIn = Animation.easeIn(duration: standard)
    static let easeInOut = Animation.easeInOut(duration: standard)
    
    // MARK: - Message Animations
    static let messageSlideIn = AnyTransition.asymmetric(
        insertion: .move(edge: .bottom).combined(with: .opacity),
        removal: .opacity
    )
    
    static let messageFade = AnyTransition.opacity
    
    static let messageScale = AnyTransition.scale(scale: 0.95).combined(with: .opacity)
    
    // MARK: - Reaction Animations
    static let reactionPop = Animation.spring(response: 0.3, dampingFraction: 0.5)
    
    // MARK: - Sheet Animations
    static let sheetPresent = Animation.spring(response: 0.35, dampingFraction: 0.8)
    
    // MARK: - Typing Indicator Animation
    static let typingDot = Animation.easeInOut(duration: 0.6).repeatForever()
}

// MARK: - Haptic Feedback Helper
enum HapticFeedback {
    static func light() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
    
    static func medium() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
    
    static func heavy() {
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred()
    }
    
    static func success() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
    
    static func warning() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.warning)
    }
    
    static func error() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.error)
    }
    
    static func selection() {
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
    }
}
