//
//  PresentationModels.swift
//  MoomoAI
//
//  Data models for presentation matching web app structure exactly
//

import Foundation
import SwiftUI

// MARK: - Slide Template (matches web app template-card structure)
enum SlideTemplate: String, CaseIterable {
    case professional = "professional"
    case modern = "modern"
    case minimal = "minimal"
    case creative = "creative"
    case corporate = "corporate"
    case educational = "educational"
    
    var backgroundColor: String {
        switch self {
        case .professional: return "#FFFFFF"
        case .modern: return "#F8F9FA"
        case .minimal: return "#FAFAFA"
        case .creative: return "#FFF8F0"
        case .corporate: return "#F5F7FA"
        case .educational: return "#F0F4F8"
        }
    }
    
    var primaryColor: String {
        switch self {
        case .professional: return "#8B5CF6"
        case .modern: return "#6C63FF"
        case .minimal: return "#333333"
        case .creative: return "#FF6B6B"
        case .corporate: return "#1E3A8A"
        case .educational: return "#10B981"
        }
    }
    
    var secondaryColor: String {
        switch self {
        case .professional: return "#14B8A6"
        case .modern: return "#4ECDC4"
        case .minimal: return "#888888"
        case .creative: return "#FFB84D"
        case .corporate: return "#3B82F6"
        case .educational: return "#3B82F6"
        }
    }
    
    var textColor: String {
        switch self {
        case .professional: return "#333333"
        case .modern: return "#2D3748"
        case .minimal: return "#000000"
        case .creative: return "#2C3E50"
        case .corporate: return "#1F2937"
        case .educational: return "#1F2937"
        }
    }
}

// MARK: - Presentation Slide (matches web app slide structure)
struct PresentationSlide: Identifiable {
    let id: String
    var title: String
    var content: [String]  // Bullet points or paragraphs
    var images: [SlideImage]
    var template: SlideTemplate
    var backgroundColor: String
    var titleFontSize: CGFloat
    var contentFontSize: CGFloat
    
    init(
        id: String = UUID().uuidString,
        title: String,
        content: [String],
        images: [SlideImage] = [],
        template: SlideTemplate,
        backgroundColor: String? = nil,
        titleFontSize: CGFloat = 44,
        contentFontSize: CGFloat = 24
    ) {
        self.id = id
        self.title = title
        self.content = content
        self.images = images
        self.template = template
        self.backgroundColor = backgroundColor ?? template.backgroundColor
        self.titleFontSize = titleFontSize
        self.contentFontSize = contentFontSize
    }
    
    func copy() -> PresentationSlide {
        return PresentationSlide(
            id: UUID().uuidString,
            title: title,
            content: content,
            images: images,
            template: template,
            backgroundColor: backgroundColor,
            titleFontSize: titleFontSize,
            contentFontSize: contentFontSize
        )
    }
}

// MARK: - Slide Image
struct SlideImage: Identifiable {
    let id: String
    var url: String?
    var data: Data?  // For embedded images
    var x: CGFloat
    var y: CGFloat
    var width: CGFloat
    var height: CGFloat
    
    init(
        id: String = UUID().uuidString,
        url: String? = nil,
        data: Data? = nil,
        x: CGFloat = 0,
        y: CGFloat = 0,
        width: CGFloat = 200,
        height: CGFloat = 150
    ) {
        self.id = id
        self.url = url
        self.data = data
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}

// MARK: - Export Format
enum ExportFormat {
    case pdf
    case pptx
    case html
    
    var fileExtension: String {
        switch self {
        case .pdf: return "pdf"
        case .pptx: return "pptx"
        case .html: return "html"
        }
    }
}

// Note: Color hex extension is already defined in Extensions.swift
