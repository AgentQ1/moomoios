//
//  User.swift
//  MoomoAI
//
//  Model for user data
//

import Foundation

struct User: Identifiable, Codable, Equatable {
    let id: String
    let email: String
    let name: String
    let picture: String?
    let provider: String
    let createdAt: Date
    var lastSignIn: Date
    var totalSessions: Int
    var totalMessages: Int
    var totalSearches: Int
    var connectedServices: [String]
    
    init(
        id: String,
        email: String,
        name: String,
        picture: String? = nil,
        provider: String = "google",
        createdAt: Date = Date(),
        lastSignIn: Date = Date(),
        totalSessions: Int = 0,
        totalMessages: Int = 0,
        totalSearches: Int = 0,
        connectedServices: [String] = []
    ) {
        self.id = id
        self.email = email
        self.name = name
        self.picture = picture
        self.provider = provider
        self.createdAt = createdAt
        self.lastSignIn = lastSignIn
        self.totalSessions = totalSessions
        self.totalMessages = totalMessages
        self.totalSearches = totalSearches
        self.connectedServices = connectedServices
    }
    
    var initials: String {
        let components = name.components(separatedBy: " ")
        let firstInitial = components.first?.first?.uppercased() ?? ""
        let lastInitial = components.count > 1 ? components.last?.first?.uppercased() ?? "" : ""
        return firstInitial + lastInitial
    }
    
    static func == (lhs: User, rhs: User) -> Bool {
        lhs.id == rhs.id
    }
}
