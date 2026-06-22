//
//  LanguageSelectionView.swift
//  MoomoAI
//
//  Language selection modal - matches web app language selector
//

import SwiftUI

struct LanguageSelectionView: View {
    @EnvironmentObject var chatViewModel: ChatViewModel
    @Environment(\.dismiss) var dismiss
    @State private var searchText = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search bar
                searchBar
                
                // Language list
                languageList
            }
            .background(K.Colors.backgroundPrimary)
            .navigationTitle("Select Language")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    // MARK: - Search Bar
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(K.Colors.textSecondary)
            
            TextField("Search languages...", text: $searchText)
                .foregroundColor(K.Colors.textPrimary)
        }
        .padding(12)
        .background(K.Colors.backgroundSecondary)
        .cornerRadius(K.Layout.smallCornerRadius)
        .padding(K.Layout.padding)
    }
    
    // MARK: - Language List
    private var languageList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(filteredLanguages) { language in
                    languageRow(language)
                }
            }
        }
    }
    
    private func languageRow(_ language: Language) -> some View {
        Button(action: {
            chatViewModel.selectLanguage(language)
            dismiss()
        }) {
            HStack {
                Text(language.flag)
                    .font(.system(size: 24))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(language.name)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(K.Colors.textPrimary)
                    
                    Text(language.nativeName)
                        .font(.system(size: 14))
                        .foregroundColor(K.Colors.textSecondary)
                }
                
                Spacer()
                
                if chatViewModel.selectedLanguage.id == language.id {
                    Image(systemName: "checkmark")
                        .foregroundColor(K.Colors.accentColor)
                        .font(.system(size: 16, weight: .semibold))
                }
            }
            .padding(.horizontal, K.Layout.padding)
            .padding(.vertical, 12)
            .background(K.Colors.backgroundPrimary)
        }
        .buttonStyle(.plain)
    }
    
    private var filteredLanguages: [Language] {
        if searchText.isEmpty {
            return Language.allLanguages
        } else {
            return Language.allLanguages.filter {
                $0.name.containsIgnoringCase(searchText) ||
                $0.nativeName.containsIgnoringCase(searchText)
            }
        }
    }
}

struct LanguageSelectionView_Previews: PreviewProvider {
    static var previews: some View {
        LanguageSelectionView()
            .environmentObject(ChatViewModel())
            .preferredColorScheme(.dark)
    }
}
