//
//  SystemPickerView.swift
//  MoomoAI
//
//  Apple-style system picker for Files, Gallery, and Camera
//

import SwiftUI
import PhotosUI

struct SystemPickerView: View {
    @Environment(\.dismiss) var dismiss
    @State private var showImagePicker = false
    @State private var showDocumentPicker = false
    @State private var showCamera = false
    
    let onAttachmentSelected: (AttachmentItem) -> Void
    
    var body: some View {
        NavigationView {
            List {
                // Files
                Button(action: {
                    showDocumentPicker = true
                }) {
                    HStack(spacing: 16) {
                        Image(systemName: "folder.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.blue)
                            .frame(width: 40, height: 40)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(8)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Files")
                                .font(.system(size: 17, weight: .medium))
                                .foregroundColor(.primary)
                            
                            Text("Browse documents and files")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.secondary.opacity(0.5))
                    }
                }
                .listRowBackground(Color.clear)
                
                // Gallery
                Button(action: {
                    showImagePicker = true
                }) {
                    HStack(spacing: 16) {
                        Image(systemName: "photo.fill.on.rectangle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.purple)
                            .frame(width: 40, height: 40)
                            .background(Color.purple.opacity(0.1))
                            .cornerRadius(8)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Gallery")
                                .font(.system(size: 17, weight: .medium))
                                .foregroundColor(.primary)
                            
                            Text("Select photos and videos")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.secondary.opacity(0.5))
                    }
                }
                .listRowBackground(Color.clear)
                
                // Camera
                Button(action: {
                    showCamera = true
                }) {
                    HStack(spacing: 16) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.green)
                            .frame(width: 40, height: 40)
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(8)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Camera")
                                .font(.system(size: 17, weight: .medium))
                                .foregroundColor(.primary)
                            
                            Text("Take a photo or video")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.secondary.opacity(0.5))
                    }
                }
                .listRowBackground(Color.clear)
            }
            .listStyle(InsetGroupedListStyle())
            .navigationTitle("Add Attachment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(K.Colors.accentColor)
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
}

struct SystemPickerView_Previews: PreviewProvider {
    static var previews: some View {
        SystemPickerView { _ in }
            .preferredColorScheme(.dark)
    }
}
