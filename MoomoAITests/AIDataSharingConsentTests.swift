//
//  AIDataSharingConsentTests.swift
//  MoomoAITests
//
//  Regression tests for the third-party AI data-sharing permission
//  (App Review Guidelines 5.1.1(i) and 5.1.2(i)).
//
//  Standalone runnable, in the same spirit as functions/test-quota.js — the app
//  has no XCTest target, and the rules encoded here are the ones a regression
//  would get the app rejected for, so they need to be executable now rather than
//  after a test target is set up.
//
//  Run:
//    swiftc -o /tmp/consent-tests \
//      MoomoAI/Utilities/AIDataSharingConsent.swift \
//      MoomoAITests/AIDataSharingConsentTests.swift && /tmp/consent-tests
//

import Foundation

var passed = 0
var failed = 0

func ok(_ name: String, _ condition: Bool) {
    if condition {
        passed += 1
        print("  ✓ \(name)")
    } else {
        failed += 1
        print("  ✗ \(name)")
    }
}

/// A fresh, isolated UserDefaults per test so one case can't leak into the next.
func makeDefaults(_ suite: String) -> UserDefaults {
    let defaults = UserDefaults(suiteName: suite)!
    defaults.removePersistentDomain(forName: suite)
    return defaults
}

@main
struct AIDataSharingConsentTests {
    static func main() {
    // MARK: - Default state

    print("\nDefault state")
    do {
        let defaults = makeDefaults("consent.default")
        let consent = AIDataSharingConsent(defaults: defaults)

        ok("starts undecided", consent.status == .undecided)
        ok("does NOT grant by default", consent.isGranted == false)
        ok("is not treated as a decline either", consent.isDeclined == false)
        ok("has no decision timestamp", consent.decidedAt == nil)
    }

    // MARK: - Accept / decline

    print("\nRecording a decision")
    do {
        let defaults = makeDefaults("consent.grant")
        let consent = AIDataSharingConsent(defaults: defaults)

        consent.grant()
        ok("grant() grants", consent.isGranted)
        ok("grant() stamps a time", consent.decidedAt != nil)
        ok("grant() records the provider", consent.recordedProvider == AIProvider.company)
        ok("grant() records the disclosure version",
           defaults.string(forKey: AIDataSharingConsent.versionKey) == AIDataSharingConsent.currentVersion)

        consent.decline()
        ok("decline() revokes the grant", consent.isGranted == false)
        ok("decline() is distinguishable from undecided", consent.isDeclined)

        consent.grant()
        ok("a declined user can grant again", consent.isGranted)

        consent.revoke()
        ok("revoke() blocks AI again", consent.isGranted == false)
        ok("revoke() reads as declined", consent.isDeclined)
    }

    // MARK: - Persistence across launches

    print("\nPersistence")
    do {
        let defaults = makeDefaults("consent.persist")
        AIDataSharingConsent(defaults: defaults).grant()

        // A second instance models the next app launch reading the same store.
        let relaunched = AIDataSharingConsent(defaults: defaults)
        ok("a grant survives relaunch", relaunched.isGranted)

        relaunched.decline()
        ok("a decline survives relaunch", AIDataSharingConsent(defaults: defaults).isDeclined)
        ok("a declined relaunch does not grant", AIDataSharingConsent(defaults: defaults).isGranted == false)
    }

    // MARK: - Versioning

    print("\nVersioning")
    do {
        let defaults = makeDefaults("consent.version")
        AIDataSharingConsent(defaults: defaults).grant()

        // Simulate the disclosure being rewritten after the user accepted the old one.
        defaults.set("1999-01-01", forKey: AIDataSharingConsent.versionKey)
        let afterBump = AIDataSharingConsent(defaults: defaults)

        ok("a superseded acceptance no longer grants", afterBump.isGranted == false)
        ok("a superseded acceptance re-prompts (undecided, not declined)",
           afterBump.status == .undecided)

        // Same rule for a stale decline: the user is asked about the NEW disclosure.
        let declineDefaults = makeDefaults("consent.version.decline")
        AIDataSharingConsent(defaults: declineDefaults).decline()
        declineDefaults.set("1999-01-01", forKey: AIDataSharingConsent.versionKey)
        ok("a superseded decline re-prompts too",
           AIDataSharingConsent(defaults: declineDefaults).status == .undecided)
    }

    // MARK: - Corrupt / partial storage fails closed

    print("\nFails closed")
    do {
        let defaults = makeDefaults("consent.corrupt")

        defaults.set("granted", forKey: AIDataSharingConsent.statusKey)
        // ...but no version written at all (partial/legacy write).
        ok("status without a version does not grant",
           AIDataSharingConsent(defaults: defaults).isGranted == false)

        defaults.set(AIDataSharingConsent.currentVersion, forKey: AIDataSharingConsent.versionKey)
        defaults.set("yes-please", forKey: AIDataSharingConsent.statusKey)
        ok("an unrecognized status value does not grant",
           AIDataSharingConsent(defaults: defaults).isGranted == false)

        let empty = makeDefaults("consent.empty")
        ok("an empty store does not grant",
           AIDataSharingConsent(defaults: empty).isGranted == false)
    }

    // MARK: - reset()

    print("\nReset")
    do {
        let defaults = makeDefaults("consent.reset")
        let consent = AIDataSharingConsent(defaults: defaults)
        consent.grant()
        consent.reset()

        ok("reset() returns to undecided", consent.status == .undecided)
        ok("reset() clears the grant", consent.isGranted == false)
        ok("reset() clears the timestamp", consent.decidedAt == nil)
        ok("reset() clears the provider", consent.recordedProvider == nil)
    }

    // MARK: - Disclosure copy must satisfy Apple's four requirements

    print("\nDisclosure copy")
    do {
        let summary = AIDataSharingDisclosure.summary
        let recipient = AIDataSharingDisclosure.recipient
        let consentSentence = AIDataSharingDisclosure.consentSentence
        let plain = AIDataSharingDisclosure.plainText

        ok("names the receiving company", recipient.contains(AIProvider.company))
        ok("names the AI service", summary.contains("Gemini"))
        ok("says what is sent", summary.lowercased().contains("text you enter"))
        ok("the consent sentence names the recipient", consentSentence.contains(AIProvider.company))
        ok("warns about sensitive information",
           AIDataSharingDisclosure.caution.lowercased().contains("sensitive"))
        ok("states Google does not train on the content",
           recipient.lowercased().contains("does not use it to train"))

        ok("itemizes what is sent", AIDataSharingDisclosure.itemsSent.count >= 4)
        ok("itemizes what is not sent", AIDataSharingDisclosure.itemsNotSent.count >= 3)
        ok("mentions images among what is sent",
           AIDataSharingDisclosure.itemsSent.contains { $0.lowercased().contains("image") })
        ok("mentions conversation context among what is sent",
           AIDataSharingDisclosure.itemsSent.contains { $0.lowercased().contains("conversation") })
        ok("promises email is not sent",
           AIDataSharingDisclosure.itemsNotSent.contains { $0.lowercased().contains("email") })

        ok("the blocked message explains why AI is off",
           AIDataSharingDisclosure.blockedMessage.contains(AIProvider.company))
        ok("the decline explanation points at Settings",
           AIDataSharingDisclosure.declinedExplanation.contains("Settings"))

        // The plain-text rendering is what Settings shows and what the policy
        // mirrors — it must carry the whole disclosure, not a fragment.
        ok("plain text includes the summary", plain.contains(summary))
        ok("plain text includes the recipient", plain.contains(recipient))
        ok("plain text includes every 'sent' item",
           AIDataSharingDisclosure.itemsSent.allSatisfy { plain.contains($0) })
        ok("plain text includes every 'not sent' item",
           AIDataSharingDisclosure.itemsNotSent.allSatisfy { plain.contains($0) })
    }

    // MARK: - Summary

    print("\n\(passed) passed, \(failed) failed\n")
    exit(failed == 0 ? 0 : 1)
    }
}
