//
//  Language.swift
//  MoomoAI
//
//  Model for language selection
//

import Foundation

struct Language: Identifiable, Codable, Equatable {
    let id: String
    let code: String
    let name: String
    let nativeName: String
    let flag: String
    
    static let allLanguages: [Language] = [
        Language(id: "en", code: "en", name: "English", nativeName: "English", flag: "🇺🇸"),
        Language(id: "es", code: "es", name: "Spanish", nativeName: "Español", flag: "🇪🇸"),
        Language(id: "fr", code: "fr", name: "French", nativeName: "Français", flag: "🇫🇷"),
        Language(id: "de", code: "de", name: "German", nativeName: "Deutsch", flag: "🇩🇪"),
        Language(id: "it", code: "it", name: "Italian", nativeName: "Italiano", flag: "🇮🇹"),
        Language(id: "pt", code: "pt", name: "Portuguese", nativeName: "Português", flag: "🇵🇹"),
        Language(id: "ru", code: "ru", name: "Russian", nativeName: "Русский", flag: "🇷🇺"),
        Language(id: "ja", code: "ja", name: "Japanese", nativeName: "日本語", flag: "🇯🇵"),
        Language(id: "ko", code: "ko", name: "Korean", nativeName: "한국어", flag: "🇰🇷"),
        Language(id: "zh", code: "zh", name: "Chinese", nativeName: "中文", flag: "🇨🇳"),
        Language(id: "ar", code: "ar", name: "Arabic", nativeName: "العربية", flag: "🇸🇦"),
        Language(id: "hi", code: "hi", name: "Hindi", nativeName: "हिन्दी", flag: "🇮🇳"),
        Language(id: "th", code: "th", name: "Thai", nativeName: "ไทย", flag: "🇹🇭"),
        Language(id: "vi", code: "vi", name: "Vietnamese", nativeName: "Tiếng Việt", flag: "🇻🇳"),
        Language(id: "tr", code: "tr", name: "Turkish", nativeName: "Türkçe", flag: "🇹🇷"),
        Language(id: "pl", code: "pl", name: "Polish", nativeName: "Polski", flag: "🇵🇱"),
        Language(id: "nl", code: "nl", name: "Dutch", nativeName: "Nederlands", flag: "🇳🇱"),
        Language(id: "sv", code: "sv", name: "Swedish", nativeName: "Svenska", flag: "🇸🇪"),
        Language(id: "da", code: "da", name: "Danish", nativeName: "Dansk", flag: "🇩🇰"),
        Language(id: "id", code: "id", name: "Indonesian", nativeName: "Bahasa Indonesia", flag: "🇮🇩")
    ]
    
    static let defaultLanguage = allLanguages[0] // English
    
    static func == (lhs: Language, rhs: Language) -> Bool {
        lhs.id == rhs.id
    }
}
