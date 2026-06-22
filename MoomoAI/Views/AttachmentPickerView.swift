//
//  AttachmentPickerView.swift
//  MoomoAI
//
//  Enhanced attachment system with photo, document, and camera support
//

import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

struct AttachmentPickerView: View {
    @Environment(\.dismiss) var dismiss
    @State private var showImagePicker = false
    @State private var showDocumentPicker = false
    @State private var showCamera = false
    
    let onAttachmentSelected: (AttachmentItem) -> Void
    
    var body: some View {
        NavigationView {
            List {
                Section("Media") {
                    attachmentRow(
                        icon: "photo.on.rectangle",
                        title: "Photo Library",
                        color: .purple
                    ) {
                        showImagePicker = true
                    }
                    
                    attachmentRow(
                        icon: "camera.fill",
                        title: "Camera",
                        color: .green
                    ) {
                        showCamera = true
                    }
                }
                
                Section("Files") {
                    attachmentRow(
                        icon: "doc.fill",
                        title: "Browse Files",
                        color: .cyan
                    ) {
                        showDocumentPicker = true
                    }
                }
            }
            .navigationTitle("Add Attachment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showImagePicker) {
                if #available(iOS 16.0, *) {
                    PhotoPickerView { items in
                        for item in items {
                            onAttachmentSelected(item)
                        }
                        dismiss()
                    }
                } else {
                    // Fallback for iOS 15
                    Text("Photo picker requires iOS 16+")
                        .padding()
                }
            }
            .sheet(isPresented: $showDocumentPicker) {
                DocumentPickerView { item in
                    onAttachmentSelected(item)
                    dismiss()
                }
            }
            .sheet(isPresented: $showCamera) {
                CameraView { item in
                    onAttachmentSelected(item)
                    dismiss()
                }
            }
        }
    }
    
    private func attachmentRow(icon: String, title: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(color)
                    .frame(width: 32)
                
                Text(title)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Photo Picker
@available(iOS 16.0, *)
// MARK: - Photo Picker (UIKit-based for reliability)
struct PhotoPickerView: UIViewControllerRepresentable {
    let onPhotosSelected: ([AttachmentItem]) -> Void
    @Environment(\.dismiss) var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .photoLibrary
        picker.allowsEditing = false
        picker.mediaTypes = ["public.image"]
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: PhotoPickerView
        
        init(_ parent: PhotoPickerView) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            var attachments: [AttachmentItem] = []
            
            if let image = info[.originalImage] as? UIImage,
               let imageData = image.jpegData(compressionQuality: 0.8) {
                let attachment = AttachmentItem(
                    id: UUID().uuidString,
                    type: .image,
                    name: "image_\(UUID().uuidString).jpg",
                    data: imageData,
                    thumbnail: image
                )
                attachments.append(attachment)
            }
            
            if !attachments.isEmpty {
                parent.onPhotosSelected(attachments)
            }
            
            picker.dismiss(animated: true)
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}

// MARK: - Document Picker
struct DocumentPickerView: UIViewControllerRepresentable {
    let onDocumentSelected: (AttachmentItem) -> Void
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [
            .pdf,
            .plainText,
            .text,
            .json,
            .spreadsheet,
            .presentation,
            .image,
            .movie,
            .audio,
            .zip,
            .data
        ])
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentPickerView
        
        init(_ parent: DocumentPickerView) {
            self.parent = parent
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            
            // Start accessing security-scoped resource
            guard url.startAccessingSecurityScopedResource() else { return }
            defer { url.stopAccessingSecurityScopedResource() }
            
            if let data = try? Data(contentsOf: url) {
                let filename = url.lastPathComponent
                let type: AttachmentType
                
                if url.pathExtension.lowercased() == "pdf" {
                    type = .pdf
                } else if ["doc", "docx", "txt", "rtf"].contains(url.pathExtension.lowercased()) {
                    type = .document
                } else if ["jpg", "jpeg", "png", "heic"].contains(url.pathExtension.lowercased()) {
                    type = .image
                } else if ["mp4", "mov", "m4v"].contains(url.pathExtension.lowercased()) {
                    type = .video
                } else {
                    type = .other
                }
                
                let attachment = AttachmentItem(
                    id: UUID().uuidString,
                    type: type,
                    name: filename,
                    data: data,
                    thumbnail: nil
                )
                
                parent.onDocumentSelected(attachment)
            }
        }
    }
}

// MARK: - Camera View
struct CameraView: UIViewControllerRepresentable {
    @Environment(\.dismiss) var dismiss
    let onImageCaptured: (AttachmentItem) -> Void
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraView
        
        init(_ parent: CameraView) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage,
               let data = image.jpegData(compressionQuality: 0.8) {
                
                let attachment = AttachmentItem(
                    id: UUID().uuidString,
                    type: .image,
                    name: "photo_\(Date().timeIntervalSince1970).jpg",
                    data: data,
                    thumbnail: image
                )
                
                parent.onImageCaptured(attachment)
            }
            
            picker.dismiss(animated: true)
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}

// MARK: - Attachment Models
struct AttachmentItem: Identifiable {
    let id: String
    let type: AttachmentType
    let name: String
    let data: Data
    let thumbnail: UIImage?
    
    var sizeFormatted: String {
        let bytes = Double(data.count)
        if bytes < 1024 {
            return "\(Int(bytes)) B"
        } else if bytes < 1024 * 1024 {
            return String(format: "%.1f KB", bytes / 1024)
        } else {
            return String(format: "%.1f MB", bytes / (1024 * 1024))
        }
    }
    
    /// Create a resized JPEG thumbnail for persisting in chat history
    func thumbnailJPEGData(maxDimension: CGFloat) -> Data? {
        guard type == .image, let image = thumbnail ?? UIImage(data: data) else { return nil }
        let scale = min(maxDimension / image.size.width, maxDimension / image.size.height, 1.0)
        let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        let resized = renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: newSize)) }
        return resized.jpegData(compressionQuality: 0.6)
    }
}

enum AttachmentType {
    case image
    case video
    case document
    case pdf
    case other
    
    var icon: String {
        switch self {
        case .image: return "photo"
        case .video: return "video"
        case .document: return "doc.text"
        case .pdf: return "doc.fill"
        case .other: return "doc"
        }
    }
    
    var color: Color {
        switch self {
        case .image: return .purple
        case .video: return .pink
        case .document: return .blue
        case .pdf: return .red
        case .other: return .gray
        }
    }
}

// MARK: - Attachment Preview
struct AttachmentPreviewView: View {
    let attachment: AttachmentItem
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail or icon
            if let thumbnail = attachment.thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                Image(systemName: attachment.type.icon)
                    .font(.system(size: 20))
                    .foregroundColor(attachment.type.color)
                    .frame(width: 44, height: 44)
                    .background(attachment.type.color.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(attachment.name)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                Text(attachment.sizeFormatted)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.secondary)
            }
        }
        .padding(8)
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(12)
    }
}

struct AttachmentPickerView_Previews: PreviewProvider {
    static var previews: some View {
        AttachmentPickerView { _ in }
    }
}
