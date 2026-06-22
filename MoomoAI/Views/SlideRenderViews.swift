//
//  SlideRenderViews.swift
//  MoomoAI
//
//  Slide rendering views matching web app's visual display exactly
//

import SwiftUI

// MARK: - Slide Canvas View (matches web app slide-container)
struct SlideCanvasView: View {
    let slide: PresentationSlide
    let scale: CGFloat
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            // Background
            Color(hex: slide.backgroundColor)
            
            VStack(alignment: .leading, spacing: 20) {
                // Title (matches web app h1)
                Text(slide.title)
                    .font(.system(size: slide.titleFontSize * scale, weight: .bold))
                    .foregroundColor(Color(hex: slide.template.textColor))
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                
                // Content (matches web app ul/li or p)
                VStack(alignment: .leading, spacing: 12 * scale) {
                    ForEach(Array(slide.content.enumerated()), id: \.offset) { index, item in
                        HStack(alignment: .top, spacing: 12 * scale) {
                            // Bullet point
                            Circle()
                                .fill(Color(hex: slide.template.primaryColor))
                                .frame(width: 8 * scale, height: 8 * scale)
                                .offset(y: 8 * scale)
                            
                            Text(item)
                                .font(.system(size: slide.contentFontSize * scale))
                                .foregroundColor(Color(hex: slide.template.textColor))
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                
                Spacer()
                
                // Accent bar at bottom (matches web app template styling)
                Rectangle()
                    .fill(Color(hex: slide.template.primaryColor))
                    .frame(height: 6 * scale)
            }
            .padding(40 * scale)
            
            // Images overlay (matches web app image-container)
            ForEach(slide.images) { image in
                slideImageView(image: image)
            }
        }
        .frame(width: 800 * scale, height: 600 * scale)
    }
    
    @ViewBuilder
    private func slideImageView(image: SlideImage) -> some View {
        Group {
            if let data = image.data, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: image.width * scale, height: image.height * scale)
                    .cornerRadius(8 * scale)
                    .position(x: image.x * scale, y: image.y * scale)
            } else if let urlString = image.url, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                            .frame(width: image.width * scale, height: image.height * scale)
                    case .success(let img):
                        img
                            .resizable()
                            .scaledToFit()
                            .frame(width: image.width * scale, height: image.height * scale)
                            .cornerRadius(8 * scale)
                    case .failure:
                        Image(systemName: "photo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: image.width * scale, height: image.height * scale)
                    @unknown default:
                        EmptyView()
                    }
                }
                .position(x: image.x * scale, y: image.y * scale)
            }
        }
    }
}

// MARK: - Slide Thumbnail View (matches web app slide thumbnails)
struct SlideThumbnailView: View {
    let slide: PresentationSlide
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            SlideCanvasView(slide: slide, scale: 0.2)
                .frame(width: 160, height: 120)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isSelected ? Color(hex: slide.template.primaryColor) : K.Colors.borderColor, lineWidth: isSelected ? 3 : 1)
                )
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Loading View (matches web app spinner)
struct PresentationLoadingView: View {
    let progress: Double
    
    var body: some View {
        VStack(spacing: 20) {
            // Spinner (matches web app)
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: K.Colors.accentColor))
                .scaleEffect(1.5)
            
            Text("Generating your presentation...")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(K.Colors.textPrimary)
            
            // Progress bar (matches web app)
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(K.Colors.borderColor)
                        .frame(height: 6)
                        .cornerRadius(3)
                    
                    Rectangle()
                        .fill(LinearGradient(
                            colors: [Color(hex: "#f5b800"), Color(hex: "#e6a600")],
                            startPoint: .leading,
                            endPoint: .trailing
                        ))
                        .frame(width: geometry.size.width * CGFloat(progress), height: 6)
                        .cornerRadius(3)
                        .animation(.linear(duration: 0.3), value: progress)
                }
            }
            .frame(height: 6)
            .padding(.horizontal, 40)
            
            Text("\(Int(progress * 100))%")
                .font(.system(size: 14))
                .foregroundColor(K.Colors.textSecondary)
        }
        .padding(40)
        .background(K.Colors.backgroundSecondary)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(K.Colors.borderColor, lineWidth: 1)
        )
    }
}

// MARK: - Export Modal (matches web app export-modal)
struct ExportModalView: View {
    @Binding var isPresented: Bool
    let onExportPDF: () -> Void
    let onExportPPTX: () -> Void
    let onExportHTML: () -> Void
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture {
                    isPresented = false
                }
            
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 8) {
                    Text("Export Presentation")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(K.Colors.textPrimary)
                    
                    Text("Choose your preferred format to download")
                        .font(.system(size: 14))
                        .foregroundColor(K.Colors.textSecondary)
                }
                .padding(.top, 30)
                .padding(.bottom, 25)
                
                // Export options (matches web app export-option)
                VStack(spacing: 10) {
                    exportButton(
                        icon: "doc.richtext",
                        title: "Export as PDF",
                        color: Color(hex: "#dc3545"),
                        action: {
                            isPresented = false
                            onExportPDF()
                        }
                    )
                    
                    exportButton(
                        icon: "doc.text",
                        title: "Export as PowerPoint",
                        color: Color(hex: "#d83b01"),
                        action: {
                            isPresented = false
                            onExportPPTX()
                        }
                    )
                    
                    exportButton(
                        icon: "doc.badge.gearshape",
                        title: "Export as HTML",
                        color: Color(hex: "#28a745"),
                        action: {
                            isPresented = false
                            onExportHTML()
                        }
                    )
                }
                .padding(.horizontal, 30)
                
                // Cancel button
                Button(action: {
                    isPresented = false
                }) {
                    Text("Cancel")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(K.Colors.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(K.Colors.backgroundTertiary)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(K.Colors.borderColor, lineWidth: 1)
                        )
                }
                .padding(.horizontal, 30)
                .padding(.top, 20)
                .padding(.bottom, 30)
            }
            .background(K.Colors.backgroundSecondary)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(K.Colors.borderColor, lineWidth: 1)
            )
            .frame(maxWidth: 400)
            .padding(20)
        }
    }
    
    private func exportButton(icon: String, title: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundColor(color)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(color.opacity(0.1))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(color, lineWidth: 2)
            )
        }
    }
}
