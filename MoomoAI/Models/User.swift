//
//  User.swift
//  MoomoAI
//
//  Model for user data
//

import Foundation

struct User: Identifiable, Equatable {
    let id: String
    let email: String
    let name: String
    let picture: String?
    let provider: String

    init(
        id: String,
        email: String,
        name: String,
        picture: String? = nil,
        provider: String = "google"
    ) {
        self.id = id
        self.email = email
        self.name = name
        self.picture = picture
        self.provider = provider
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
