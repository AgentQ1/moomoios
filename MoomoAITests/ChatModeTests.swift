//
//  ChatModeTests.swift
//  MoomoAITests
//
//  Covers the three header-button states (ChatMode) and the enter/exit
//  Temporary Chat transitions.
//
//  NOTE: The project has no unit-test target yet. To run these tests, add one
//  in Xcode (File > New > Target… > Unit Testing Bundle, named "MoomoAITests",
//  host application: MoomoAI) and include this file in that target.
//

import XCTest
@testable import MoomoAI

// MARK: - ChatMode derivation (pure)

final class ChatModeDerivationTests: XCTestCase {

    func testNilSessionIsNormalEmpty() {
        XCTAssertEqual(ChatMode.forSession(nil), .normalEmpty)
    }

    func testEmptyNormalSessionIsNormalEmpty() {
        let session = ChatSession(title: "New chat")
        XCTAssertEqual(ChatMode.forSession(session), .normalEmpty)
    }

    func testNormalSessionWithUserMessageIsNormalActive() {
        var session = ChatSession(title: "New chat")
        session.addMessage(ChatMessage(role: .user, content: "Hello"))
        XCTAssertEqual(ChatMode.forSession(session), .normalActive)
    }

    func testAssistantOnlyMessagesStayNormalEmpty() {
        // e.g. an error bubble before any user turn — New Chat would be wrong.
        var session = ChatSession(title: "New chat")
        session.addMessage(ChatMessage(role: .assistant, content: "Something went wrong."))
        XCTAssertEqual(ChatMode.forSession(session), .normalEmpty)
    }

    /// The original bug: a fresh temporary chat is ALSO empty, so deriving the
    /// header action from `messages.isEmpty` showed the Temporary Chat icon
    /// with no way out. isTemporary must win over message count.
    func testEmptyTemporarySessionIsTemporary() {
        let session = ChatSession(title: "Temporary chat", isTemporary: true)
        XCTAssertEqual(ChatMode.forSession(session), .temporary)
    }

    func testTemporarySessionWithMessagesStaysTemporary() {
        var session = ChatSession(title: "Temporary chat", isTemporary: true)
        session.addMessage(ChatMessage(role: .user, content: "Hi"))
        session.addMessage(ChatMessage(role: .assistant, content: "Hello!"))
        XCTAssertEqual(ChatMode.forSession(session), .temporary)
    }
}

// MARK: - Mode transitions on the view model

@MainActor
final class ChatModeTransitionTests: XCTestCase {

    private var viewModel: ChatViewModel!

    override func setUp() async throws {
        // ChatViewModel persists through UserDefaults; start every test clean.
        UserDefaults.standard.removeObject(forKey: "chat_sessions")
        UserDefaults.standard.removeObject(forKey: "current_session_id")
        viewModel = ChatViewModel()
    }

    // Normal empty → tap Temporary Chat → Exit state, before any message.
    func testEnterTemporaryFromNormalEmpty() {
        XCTAssertEqual(viewModel.chatMode, .normalEmpty)

        viewModel.createTemporarySession()

        XCTAssertEqual(viewModel.chatMode, .temporary)
        XCTAssertEqual(viewModel.currentSession?.isTemporary, true)
        XCTAssertEqual(viewModel.currentSession?.messages.isEmpty, true)
    }

    // Temporary chats never appear in Recent Chats.
    func testTemporarySessionIsNotInSessionsList() {
        viewModel.createTemporarySession()
        let tempId = viewModel.currentSession!.id
        XCTAssertFalse(viewModel.sessions.contains { $0.id == tempId })
    }

    // Repeated taps on Temporary Chat must not stack fresh temp sessions.
    func testRepeatedEnterTemporaryKeepsSameSession() {
        viewModel.createTemporarySession()
        let firstId = viewModel.currentSession!.id
        viewModel.createTemporarySession()
        XCTAssertEqual(viewModel.currentSession?.id, firstId)
    }

    // Temporary → send messages → tap Exit → normal empty chat, all discarded.
    func testExitTemporaryDiscardsMessagesAndReturnsToNormalEmpty() {
        viewModel.createTemporarySession()
        var temp = viewModel.currentSession!
        temp.addMessage(ChatMessage(role: .user, content: "secret question"))
        temp.addMessage(ChatMessage(role: .assistant, content: "secret answer"))
        viewModel.currentSession = temp
        XCTAssertEqual(viewModel.chatMode, .temporary, "Exit must stay available after messages are sent")

        viewModel.exitTemporarySession()

        XCTAssertEqual(viewModel.chatMode, .normalEmpty)
        XCTAssertEqual(viewModel.currentSession?.isTemporary, false)
        XCTAssertEqual(viewModel.currentSession?.messages.isEmpty, true)
        // Nothing of the temporary chat survives in the model.
        XCTAssertFalse(viewModel.sessions.contains { $0.isTemporary })
        XCTAssertFalse(viewModel.sessions.contains { $0.id == temp.id })
    }

    // Enter/exit cycles must not stack empty "New chat" rows in the sidebar.
    func testEnterExitCyclesDoNotStackEmptySessions() {
        let baselineCount = viewModel.sessions.count
        for _ in 0..<3 {
            viewModel.createTemporarySession()
            viewModel.exitTemporarySession()
        }
        XCTAssertEqual(viewModel.chatMode, .normalEmpty)
        XCTAssertEqual(viewModel.sessions.count, baselineCount)
    }

    // Exit is a no-op on a normal chat (defensive: the UI never offers it there).
    func testExitIsNoOpOutsideTemporaryMode() {
        let id = viewModel.currentSession?.id
        viewModel.exitTemporarySession()
        XCTAssertEqual(viewModel.currentSession?.id, id)
    }

    // Normal empty → first user message → New Chat state.
    func testFirstUserMessageSwitchesToNormalActive() {
        var session = viewModel.currentSession!
        session.addMessage(ChatMessage(role: .user, content: "Hello"))
        viewModel.currentSession = session
        XCTAssertEqual(viewModel.chatMode, .normalActive)
    }
}
