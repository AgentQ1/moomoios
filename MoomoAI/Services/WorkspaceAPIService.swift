//
//  WorkspaceAPIService.swift
//  MoomoAI
//
//  Complete Workspace API Service - provider-agnostic
//  Provides Drive and Calendar integration
//

import Foundation

class WorkspaceAPIService {
    static let shared = WorkspaceAPIService()
    private let oauth = WorkspaceOAuthManager.shared
    
    private init() {}
    
    // PERFORMANCE: Add cache for API results
    private var searchCache: [String: (result: Any, timestamp: Date)] = [:]
    private let cacheExpiration: TimeInterval = 300 // 5 minutes
    
    // MARK: - File Storage API
    
    func searchFiles(query: String, maxResults: Int = 20) async throws -> FileSearchResult {
        let token = try await oauth.getValidAccessToken()
        
        // Build query
        var searchQuery: String
        if query.isEmpty || query == "*" {
            searchQuery = "trashed=false"
        } else {
            searchQuery = "(name contains '\(query)' or fullText contains '\(query)') and trashed=false"
        }
        
        let url = "https://www.googleapis.com/drive/v3/files?q=\(searchQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")&pageSize=\(maxResults)&orderBy=modifiedTime desc&fields=files(id,name,mimeType,modifiedTime,size,webViewLink,iconLink)"
        
        let data = try await apiRequest(url: url, token: token)
        let response = try JSONDecoder().decode(FileSearchResponse.self, from: data)
        
        let results = response.files.map { file in
            StoredFile(
                id: file.id,
                name: file.name,
                type: file.mimeType,
                modified: file.modifiedTime,
                size: formatFileSize(bytes: Int64(file.size ?? "0") ?? 0),
                link: file.webViewLink,
                icon: file.iconLink
            )
        }
        
        return FileSearchResult(results: results, total: response.files.count)
    }
    
    func getRecentFiles(maxResults: Int = 10) async throws -> FileSearchResult {
        return try await searchFiles(query: "", maxResults: maxResults)
    }
    
    // MARK: - Calendar API
    
    func searchCalendar(query: String, maxResults: Int = 10) async throws -> CalendarSearchResult {
        let token = try await oauth.getValidAccessToken()
        
        let timeMin = ISO8601DateFormatter().string(from: Date())
        let url = "https://www.googleapis.com/calendar/v3/calendars/primary/events?q=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")&timeMin=\(timeMin)&maxResults=\(maxResults)&singleEvents=true&orderBy=startTime"
        
        let data = try await apiRequest(url: url, token: token)
        let response = try JSONDecoder().decode(CalendarSearchResponse.self, from: data)
        
        let results = response.items.map { event in
            CalendarEvent(
                id: event.id,
                title: event.summary ?? "No Title",
                start: event.start.dateTime ?? event.start.date ?? "",
                end: event.end.dateTime ?? event.end.date ?? "",
                location: event.location ?? "",
                description: event.description ?? "",
                link: event.htmlLink
            )
        }
        
        return CalendarSearchResult(results: results, total: response.items.count)
    }
    
    func getUpcomingEvents(maxResults: Int = 10) async throws -> CalendarSearchResult {
        return try await searchCalendar(query: "", maxResults: maxResults)
    }
    
    // MARK: - Helper Methods
    
    private func apiRequest(url: String, token: String) async throws -> Data {
        guard let requestURL = URL(string: url) else {
            throw WorkspaceAPIError.invalidURL
        }
        
        var request = URLRequest(url: requestURL)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw WorkspaceAPIError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw WorkspaceAPIError.apiError(statusCode: httpResponse.statusCode)
        }
        
        return data
    }
    
    private func formatFileSize(bytes: Int64) -> String {
        if bytes == 0 { return "0 Bytes" }
        
        let k: Int64 = 1024
        let sizes = ["Bytes", "KB", "MB", "GB", "TB"]
        let i = Int(floor(log(Double(bytes)) / log(Double(k))))
        
        let value = Double(bytes) / pow(Double(k), Double(i))
        return String(format: "%.2f %@", value, sizes[i])
    }
}

// MARK: - Models

struct FileSearchResult {
    let results: [StoredFile]
    let total: Int
}

struct StoredFile: Identifiable {
    let id: String
    let name: String
    let type: String
    let modified: String
    let size: String
    let link: String?
    let icon: String?
}

struct CalendarSearchResult {
    let results: [CalendarEvent]
    let total: Int
}

struct CalendarEvent: Identifiable {
    let id: String
    let title: String
    let start: String
    let end: String
    let location: String
    let description: String
    let link: String
}

// MARK: - API Response Models

private struct FileSearchResponse: Codable {
    let files: [FileItem]
    
    struct FileItem: Codable {
        let id: String
        let name: String
        let mimeType: String
        let modifiedTime: String
        let size: String?
        let webViewLink: String?
        let iconLink: String?
    }
}

private struct CalendarSearchResponse: Codable {
    let items: [EventItem]
    
    struct EventItem: Codable {
        let id: String
        let summary: String?
        let start: EventDateTime
        let end: EventDateTime
        let location: String?
        let description: String?
        let htmlLink: String
    }
    
    struct EventDateTime: Codable {
        let dateTime: String?
        let date: String?
    }
}

// MARK: - Errors

enum WorkspaceAPIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case apiError(statusCode: Int)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid API URL"
        case .invalidResponse:
            return "Invalid API response"
        case .apiError(let code):
            return "API error: \(code)"
        }
    }
}
