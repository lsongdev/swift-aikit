//
//  AssistantReasoningStrippingTests.swift
//  ChatClientKitTests
//
//  Regression coverage: reasoning content must not be echoed back on
//  assistant messages in chat-completions requests. Some providers
//  (e.g. DeepSeek) reject the request entirely when reasoning is
//  included on a follow-up turn.
//

@testable import ChatClientKit
import Foundation
import Testing

struct AssistantReasoningStrippingTests {
    @Test
    func `Assistant message omits reasoning from encoded body`() throws {
        let body = ChatRequestBody(
            model: "test-model",
            messages: [
                .user(content: .text("hi")),
                .assistant(
                    content: .text("answer"),
                    toolCalls: nil,
                    reasoning: "step 1\nstep 2"
                ),
                .user(content: .text("follow up")),
            ]
        )

        let data = try JSONEncoder.stableRequestEncoder.encode(body)
        let json = try #require(String(data: data, encoding: .utf8))

        #expect(!json.contains("\"reasoning\""))
        #expect(!json.contains("step 1"))
        #expect(!json.contains("step 2"))
        // Sanity: the assistant message itself is still present.
        #expect(json.contains("\"answer\""))
    }

    @Test
    func `Assistant tool call message omits reasoning from encoded body`() throws {
        let body = ChatRequestBody(
            model: "test-model",
            messages: [
                .assistant(
                    content: nil,
                    toolCalls: [
                        .init(
                            id: "call_1",
                            function: .init(name: "lookup", arguments: "{}")
                        ),
                    ],
                    reasoning: "I should call lookup."
                ),
            ]
        )

        let data = try JSONEncoder.stableRequestEncoder.encode(body)
        let json = try #require(String(data: data, encoding: .utf8))

        #expect(!json.contains("\"reasoning\""))
        #expect(!json.contains("I should call lookup."))
        #expect(json.contains("\"tool_calls\""))
        #expect(json.contains("\"call_1\""))
    }
}
