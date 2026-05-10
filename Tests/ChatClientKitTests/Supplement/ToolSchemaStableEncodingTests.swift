//
//  ToolSchemaStableEncodingTests.swift
//  ChatClientKitTests
//
//  Regression coverage for https://github.com/Lakr233/FlowDown/issues/273
//  Tool parameter schemas must serialize with deterministic key ordering so
//  remote inference servers can reuse prefix caches across turns.
//

@testable import ChatClientKit
import Foundation
import Testing

struct ToolSchemaStableEncodingTests {
    // MARK: - AnyCodingValue

    @Test
    func `AnyCodingValue object encodes keys in lexicographic order`() throws {
        let value: AnyCodingValue = .object([
            "type": .string("object"),
            "additionalProperties": .bool(false),
            "properties": .object([
                "start_date": .object(["type": .string("string")]),
                "end_date": .object(["type": .string("string")]),
                "include_all_day_events": .object(["type": .string("boolean")]),
            ]),
        ])

        let encoder = JSONEncoder.stableRequestEncoder
        let data = try encoder.encode(value)
        let json = try #require(String(data: data, encoding: .utf8))

        // Top-level keys are sorted: additionalProperties, properties, type.
        let topAdditionalIndex = try #require(json.range(of: "\"additionalProperties\""))
        let topPropertiesIndex = try #require(json.range(of: "\"properties\""))
        let topTypeIndex = try #require(json.range(of: "\"type\""))
        #expect(topAdditionalIndex.lowerBound < topPropertiesIndex.lowerBound)
        #expect(topPropertiesIndex.lowerBound < topTypeIndex.lowerBound)

        // Nested keys are sorted: end_date, include_all_day_events, start_date.
        let endIndex = try #require(json.range(of: "\"end_date\""))
        let includeIndex = try #require(json.range(of: "\"include_all_day_events\""))
        let startIndex = try #require(json.range(of: "\"start_date\""))
        #expect(endIndex.lowerBound < includeIndex.lowerBound)
        #expect(includeIndex.lowerBound < startIndex.lowerBound)
    }

    @Test
    func `AnyCodingValue produces identical bytes across repeated encodings`() throws {
        // Build the same logical schema from differently-ordered literals to
        // exercise hash-randomized dictionary iteration.
        let schemaA: AnyCodingValue = .object([
            "type": "object",
            "additionalProperties": false,
            "properties": .object([
                "alpha": .object(["type": "string"]),
                "beta": .object(["type": "string"]),
                "gamma": .object(["type": "boolean"]),
                "delta": .object(["type": "integer"]),
            ]),
        ])
        let schemaB: AnyCodingValue = .object([
            "additionalProperties": false,
            "properties": .object([
                "delta": .object(["type": "integer"]),
                "gamma": .object(["type": "boolean"]),
                "beta": .object(["type": "string"]),
                "alpha": .object(["type": "string"]),
            ]),
            "type": "object",
        ])

        let encoder = JSONEncoder.stableRequestEncoder
        let dataA = try encoder.encode(schemaA)
        let dataB = try encoder.encode(schemaB)
        #expect(dataA == dataB)
    }

    // MARK: - ChatRequestBody

    @Test
    func `Chat request body emits stable tool schema across encodes`() throws {
        let parameters: [String: AnyCodingValue] = [
            "type": "object",
            "additionalProperties": false,
            "properties": .object([
                "title": .object(["type": "string"]),
                "start_date": .object(["type": "string"]),
                "end_date": .object(["type": "string"]),
                "all_day": .object(["type": "boolean"]),
            ]),
            "required": .array(["title", "start_date"]),
        ]

        let body = ChatRequestBody(
            model: "test-model",
            messages: [.user(content: .text("hi"))],
            tools: [
                .function(
                    name: "add_calendar_event",
                    description: "Adds a calendar event.",
                    parameters: parameters,
                    strict: nil
                ),
            ]
        )

        let encoder = JSONEncoder.stableRequestEncoder
        let first = try encoder.encode(body)
        let second = try encoder.encode(body)
        #expect(first == second)

        let json = try #require(String(data: first, encoding: .utf8))
        // Tool function key ordering inside `parameters` must be stable.
        let additionalIdx = try #require(json.range(of: "\"additionalProperties\""))
        let propertiesIdx = try #require(json.range(of: "\"properties\""))
        let requiredIdx = try #require(json.range(of: "\"required\""))
        let typeIdx = try #require(json.range(of: "\"type\":\"object\""))
        #expect(additionalIdx.lowerBound < propertiesIdx.lowerBound)
        #expect(propertiesIdx.lowerBound < requiredIdx.lowerBound)
        #expect(requiredIdx.lowerBound < typeIdx.lowerBound)
    }

    // MARK: - Builders

    @Test
    func `Completions request builder emits identical bytes for identical input`() throws {
        let body = makeBody()
        let builder = RemoteCompletionsChatRequestBuilder(
            baseURL: "https://example.invalid",
            path: "/v1/chat/completions",
            apiKey: nil,
            additionalHeaders: [:]
        )

        let r1 = try builder.makeRequest(body: body, additionalField: ["provider": "openrouter"])
        let r2 = try builder.makeRequest(body: body, additionalField: ["provider": "openrouter"])

        let b1 = try #require(r1.httpBody)
        let b2 = try #require(r2.httpBody)
        #expect(b1 == b2)
    }

    @Test
    func `Responses request builder emits identical bytes for identical input`() throws {
        let chatBody = makeBody()
        let transformer = ResponsesRequestTransformer()
        let body = transformer.makeRequestBody(
            from: chatBody,
            model: chatBody.model ?? "test-model",
            stream: false
        )

        let builder = RemoteResponsesRequestBuilder(
            baseURL: "https://example.invalid",
            path: "/v1/responses",
            apiKey: nil,
            additionalHeaders: [:]
        )

        let r1 = try builder.makeRequest(body: body, additionalField: ["provider": "openrouter"])
        let r2 = try builder.makeRequest(body: body, additionalField: ["provider": "openrouter"])

        let b1 = try #require(r1.httpBody)
        let b2 = try #require(r2.httpBody)
        #expect(b1 == b2)
    }

    // MARK: - Helpers

    private func makeBody() -> ChatRequestBody {
        ChatRequestBody(
            model: "test-model",
            messages: [.user(content: .text("hi"))],
            tools: [
                .function(
                    name: "add_calendar_event",
                    description: "Adds a calendar event.",
                    parameters: [
                        "type": "object",
                        "additionalProperties": false,
                        "properties": .object([
                            "title": .object(["type": "string"]),
                            "start_date": .object(["type": "string"]),
                            "end_date": .object(["type": "string"]),
                        ]),
                    ],
                    strict: nil
                ),
                .function(
                    name: "query_calendar_events",
                    description: "Queries calendar events.",
                    parameters: [
                        "type": "object",
                        "additionalProperties": false,
                        "properties": .object([
                            "start_date": .object(["type": "string"]),
                            "end_date": .object(["type": "string"]),
                            "include_all_day_events": .object(["type": "boolean"]),
                        ]),
                    ],
                    strict: nil
                ),
            ]
        )
    }
}
