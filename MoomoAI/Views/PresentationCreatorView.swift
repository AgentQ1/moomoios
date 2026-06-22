//
//  PresentationCreatorView.swift
//  MoomoAI
//
//  AI-Powered Presentation Creator matching web app ppt-editor.html exactly
//

import SwiftUI

struct PresentationCreatorView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel = PresentationViewModel()
    @State private var showExportModal = false
    @State private var exportURL: URL?
    
    let initialTopic: String
    
    init(initialTopic: String = "") {
        self.initialTopic = initialTopic
    }
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Header (matches web app .header)
                headerView
                
                // Main Container (matches web app .main-container)
                if viewModel.isGenerating {
                    // Loading view (matches web app .loading)
                    loadingView
                } else if viewModel.slides.isEmpty {
                    // Left sidebar only when no slides (matches web app layout)
                    leftSidebarView
                } else {
                    // Full layout: sidebar + editor (matches web app 3-column)
                    HStack(spacing: 0) {
                        leftSidebarView
                            .frame(width: 300)
                        
                        Divider()
                        
                        slideEditorView
                    }
                }
            }
            .background(K.Colors.backgroundPrimary)
            
            // Export Modal (matches web app .export-modal)
            if showExportModal {
                ExportModalView(
                    isPresented: $showExportModal,
                    onExportPDF: { Task { await exportToPDF() } },
                    onExportPPTX: { Task { await exportToPPTX() } },
                    onExportHTML: { Task { await exportToHTML() } }
                )
            }
        }
        .onAppear {
            if !initialTopic.isEmpty {
                viewModel.promptText = initialTopic
            }
        }
    }
    
    // MARK: - Header (matches web app .header)
    private var headerView: some View {
        HStack {
            // Logo (matches web app .logo)
            HStack(spacing: 8) {
                VStack(spacing: 2) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color(hex: "#8B5CF6"))
                        .frame(width: 24, height: 4)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color(hex: "#F43F5E"))
                        .frame(width: 24, height: 4)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color(hex: "#F59E0B"))
                        .frame(width: 24, height: 4)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color(hex: "#14B8A6"))
                        .frame(width: 24, height: 4)
                }
                
                Text("MoomoPro")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(K.Colors.textPrimary)
            }
            
            Text("AI-Powered Presentation Creator")
                .font(.system(size: 16))
                .foregroundColor(K.Colors.textSecondary)
                .padding(.leading, 20)
            
            Spacer()
            
            // Header buttons (matches web app .header-btn)
            HStack(spacing: 10) {
                headerButton(icon: "doc.badge.plus", title: "New", action: newPresentation)
                
                headerButton(icon: "square.and.arrow.down", title: "Save", action: savePresentation)
                    .disabled(viewModel.slides.isEmpty)
                
                headerButton(icon: "square.and.arrow.up", title: "Export", isPrimary: false, action: {
                    showExportModal = true
                })
                .disabled(viewModel.slides.isEmpty)
                
                headerButton(icon: "arrow.left.circle.fill", title: "Back", isPrimary: true, action: {
                    dismiss()
                })
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 15)
        .background(K.Colors.backgroundSecondary)
        .overlay(
            Rectangle()
                .fill(K.Colors.borderColor)
                .frame(height: 1),
            alignment: .bottom
        )
    }
    
    private func headerButton(icon: String, title: String, isPrimary: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                Text(title)
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundColor(isPrimary ? .white : K.Colors.textPrimary)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(isPrimary ? Color(hex: "#f5b800") : K.Colors.backgroundTertiary)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isPrimary ? Color(hex: "#f5b800") : K.Colors.borderColor, lineWidth: 1)
            )
        }
    }
    
    // MARK: - Left Sidebar (matches web app .left-sidebar exactly)
    private var leftSidebarView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Prompt Section (matches web app .prompt-section)
                VStack(alignment: .leading, spacing: 15) {
                    Text("AI Prompt")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(K.Colors.textPrimary)
                    
                    TextEditor(text: $viewModel.promptText)
                        .frame(minHeight: 100)
                        .padding(12)
                        .background(K.Colors.backgroundTertiary)
                        .foregroundColor(K.Colors.textPrimary)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(K.Colors.borderColor, lineWidth: 2)
                        )
                        .overlay(
                            Group {
                                if viewModel.promptText.isEmpty {
                                    Text("Describe your presentation topic...\nE.g., 'Create a presentation about artificial intelligence and its impact on healthcare'")
                                        .font(.system(size: 14))
                                        .foregroundColor(K.Colors.textSecondary)
                                        .padding(16)
                                        .allowsHitTesting(false)
                                }
                            },
                            alignment: .topLeading
                        )
                }
                .padding(20)
                .background(K.Colors.backgroundSecondary)
                .overlay(
                    Rectangle()
                        .fill(K.Colors.borderColor)
                        .frame(height: 1),
                    alignment: .bottom
                )
                
                // Slide Count Section (matches web app .slide-count-section)
                VStack(alignment: .leading, spacing: 12) {
                    Text("Number of Slides")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(K.Colors.textPrimary)
                    
                    HStack(spacing: 10) {
                        // Minus button
                        Button(action: {
                            if viewModel.slideCount > 1 {
                                viewModel.slideCount -= 1
                            }
                        }) {
                            Text("-")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 28, height: 28)
                                .background(Color(hex: "#f5b800"))
                                .cornerRadius(4)
                        }
                        
                        // Count display
                        Text("\(viewModel.slideCount)")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(K.Colors.textPrimary)
                            .frame(width: 70)
                            .padding(.vertical, 8)
                            .background(K.Colors.backgroundTertiary)
                            .cornerRadius(6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(K.Colors.borderColor, lineWidth: 2)
                            )
                        
                        // Plus button
                        Button(action: {
                            if viewModel.slideCount < 20 {
                                viewModel.slideCount += 1
                            }
                        }) {
                            Text("+")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 28, height: 28)
                                .background(Color(hex: "#f5b800"))
                                .cornerRadius(4)
                        }
                    }
                    
                    // Preset buttons (matches web app .preset-btn)
                    HStack(spacing: 8) {
                        presetButton(count: 5)
                        presetButton(count: 10)
                        presetButton(count: 15)
                    }
                }
                .padding(15)
                .padding(.horizontal, 5)
                .background(K.Colors.backgroundSecondary)
                .overlay(
                    Rectangle()
                        .fill(K.Colors.borderColor)
                        .frame(height: 1),
                    alignment: .bottom
                )
                
                // Templates Section (matches web app .templates-section)
                VStack(alignment: .leading, spacing: 15) {
                    Text("Select Template")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(K.Colors.textPrimary)
                    
                    // Template grid (matches web app .template-grid)
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        ForEach(SlideTemplate.allCases, id: \.self) { template in
                            templateCard(template)
                        }
                    }
                }
                .padding(20)
                .background(K.Colors.backgroundSecondary)
                .overlay(
                    Rectangle()
                        .fill(K.Colors.borderColor)
                        .frame(height: 1),
                    alignment: .bottom
                )
                
                // Generate Button (matches web app .generate-btn)
                Button(action: {
                    Task {
                        await viewModel.generatePresentation()
                    }
                }) {
                    HStack(spacing: 8) {
                        if viewModel.isGenerating {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "wand.and.stars")
                                .font(.system(size: 18))
                        }
                        
                        Text(viewModel.isGenerating ? "Generating..." : "Generate with AI")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color(hex: "#f5b800"))
                    .cornerRadius(8)
                }
                .disabled(viewModel.isGenerating || viewModel.promptText.isEmpty)
                .opacity((viewModel.isGenerating || viewModel.promptText.isEmpty) ? 0.5 : 1.0)
                .padding(20)
            }
        }
        .frame(maxWidth: .infinity)
        .background(K.Colors.backgroundSecondary)
    }
    
    private func presetButton(count: Int) -> some View {
        Button(action: {
            viewModel.slideCount = count
        }) {
            Text("\(count)")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(viewModel.slideCount == count ? .white : K.Colors.textPrimary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(viewModel.slideCount == count ? Color(hex: "#f5b800") : K.Colors.backgroundTertiary)
                .cornerRadius(4)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(viewModel.slideCount == count ? Color(hex: "#f5b800") : K.Colors.borderColor, lineWidth: 1)
                )
        }
    }
    
    private func templateCard(_ template: SlideTemplate) -> some View {
        VStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(hex: template.backgroundColor))
                .frame(height: 50)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(hex: template.primaryColor))
                        .frame(height: 6),
                    alignment: .top
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(viewModel.selectedTemplate == template ? Color(hex: "#f5b800") : K.Colors.borderColor, lineWidth: viewModel.selectedTemplate == template ? 2 : 1)
                )
            
            Text(template.rawValue.capitalized)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(K.Colors.textPrimary)
        }
        .onTapGesture {
            viewModel.selectedTemplate = template
        }
    }
    
    // MARK: - Loading View (matches web app .loading with spinner and progress)
    private var loadingView: some View {
        VStack {
            Spacer()
            PresentationLoadingView(progress: viewModel.generationProgress)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(K.Colors.backgroundPrimary)
    }
    
    // MARK: - Slide Editor (matches web app .middle-content)
    private var slideEditorView: some View {
        VStack(spacing: 0) {
            // Slide preview area (matches web app .slide-editor)
            ScrollView {
                VStack(spacing: 16) {
                    if let currentSlide = viewModel.currentSlide {
                        SlideCanvasView(slide: currentSlide, scale: 1.0)
                            .frame(width: 800, height: 600)
                            .background(Color.white)
                            .cornerRadius(8)
                            .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 4)
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity)
            }
            .background(K.Colors.backgroundPrimary)
            
            Divider()
            
            // Bottom toolbar (matches web app toolbar)
            bottomToolbarView
        }
    }
    
    // MARK: - Bottom Toolbar (matches web app bottom toolbar)
    private var bottomToolbarView: some View {
        HStack {
            Text("\(viewModel.currentSlideIndex + 1) / \(viewModel.slides.count)")
                .font(.system(size: 14))
                .foregroundColor(K.Colors.textSecondary)
            
            Spacer()
            
            // Navigation buttons
            HStack(spacing: 16) {
                Button(action: {
                    if viewModel.currentSlideIndex > 0 {
                        viewModel.currentSlideIndex -= 1
                    }
                }) {
                    Image(systemName: "chevron.left.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(viewModel.currentSlideIndex > 0 ? Color(hex: "#f5b800") : K.Colors.textSecondary.opacity(0.3))
                }
                .disabled(viewModel.currentSlideIndex == 0)
                
                Button(action: {
                    if viewModel.currentSlideIndex < viewModel.slides.count - 1 {
                        viewModel.currentSlideIndex += 1
                    }
                }) {
                    Image(systemName: "chevron.right.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(viewModel.currentSlideIndex < viewModel.slides.count - 1 ? Color(hex: "#f5b800") : K.Colors.textSecondary.opacity(0.3))
                }
                .disabled(viewModel.currentSlideIndex == viewModel.slides.count - 1)
            }
            
            Spacer()
            
            // Action buttons
            HStack(spacing: 12) {
                Button(action: {
                    viewModel.addSlide()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle")
                            .font(.system(size: 14))
                        Text("Add")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color(hex: "#f5b800"))
                    .cornerRadius(8)
                }
                
                Button(action: {
                    viewModel.duplicateSlide(at: viewModel.currentSlideIndex)
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 14))
                        Text("Duplicate")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color(hex: "#8B5CF6"))
                    .cornerRadius(8)
                }
                
                Button(action: {
                    viewModel.deleteSlide(at: viewModel.currentSlideIndex)
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "trash")
                            .font(.system(size: 14))
                        Text("Delete")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.red)
                    .cornerRadius(8)
                }
                .disabled(viewModel.slides.count <= 1)
                .opacity(viewModel.slides.count <= 1 ? 0.5 : 1.0)
                
                Button(action: {
                    Task {
                        await viewModel.generatePresentation()
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 14))
                        Text("Regenerate")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color(hex: "#f5b800"))
                    .cornerRadius(8)
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(K.Colors.backgroundSecondary)
        .overlay(
            Rectangle()
                .fill(K.Colors.borderColor)
                .frame(height: 1),
            alignment: .top
        )
    }
    
    // MARK: - Actions
    private func newPresentation() {
        viewModel.promptText = ""
        viewModel.slides = []
        viewModel.slideCount = 5
        viewModel.selectedTemplate = .professional
    }
    
    private func savePresentation() {
        Task {
            await exportToPDF()
        }
    }
    
    private func exportToPDF() async {
        if #available(iOS 16.0, *) {
            do {
                let url = try await PresentationExportService.shared.exportToPDF(
                    slides: viewModel.slides,
                    title: viewModel.promptText.isEmpty ? "Presentation" : viewModel.promptText
                )
                exportURL = url
                // Show share sheet
                shareFile(url: url)
            } catch {
                print("PDF export failed: \(error)")
            }
        } else {
            print("PDF export requires iOS 16.0 or later")
        }
    }
    
    private func exportToPPTX() async {
        do {
            let url = try await PresentationExportService.shared.exportToPPTX(
                slides: viewModel.slides,
                title: viewModel.promptText.isEmpty ? "Presentation" : viewModel.promptText
            )
            exportURL = url
            shareFile(url: url)
        } catch {
            print("PPTX export failed: \(error)")
        }
    }
    
    private func exportToHTML() async {
        do {
            let url = try await PresentationExportService.shared.exportToHTML(
                slides: viewModel.slides,
                title: viewModel.promptText.isEmpty ? "Presentation" : viewModel.promptText
            )
            exportURL = url
            shareFile(url: url)
        } catch {
            print("HTML export failed: \(error)")
        }
    }
    
    private func shareFile(url: URL) {
        let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
    }
}

// MARK: - Preview
struct PresentationCreatorView_Previews: PreviewProvider {
    static var previews: some View {
        PresentationCreatorView()
    }
}
