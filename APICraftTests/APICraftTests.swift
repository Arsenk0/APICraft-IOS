//
//  APICraftTests.swift
//  APICraftTests
//
//  Created by Arsen Khomiak on 05.11.2026.
//

import Testing
import Foundation
@testable import APICraft

@Suite("Variable Resolver Tests")
struct VariableResolverTests {
    
    @Test("Basic single variable interpolation")
    func testSingleVariableInterpolation() {
        let template = "{{baseUrl}}/users"
        let vars = ["baseUrl": "https://api.example.com"]
        let result = VariableResolver.resolve(text: template, using: vars)
        #expect(result == "https://api.example.com/users")
    }
    
    @Test("Multiple distinct variables interpolation")
    func testMultipleVariablesInterpolation() {
        let template = "{{protocol}}://{{host}}:{{port}}/api/v1/{{resource}}?id={{id}}"
        let vars: [String: String] = [
            "protocol": "https",
            "host": "staging.example.com",
            "port": "8080",
            "resource": "items",
            "id": "42"
        ]
        let result = VariableResolver.resolve(text: template, using: vars)
        #expect(result == "https://staging.example.com:8080/api/v1/items?id=42")
    }
    
    @Test("Unmatched placeholder remains intact")
    func testUnmatchedPlaceholder() {
        let template = "https://example.com/api/{{unknownKey}}/test"
        let vars = ["knownKey": "value"]
        let result = VariableResolver.resolve(text: template, using: vars)
        #expect(result == "https://example.com/api/{{unknownKey}}/test")
    }
    
    @Test("Empty variables map returns identical text")
    func testEmptyVariables() {
        let template = "https://api.example.com/items/{{id}}"
        let result = VariableResolver.resolve(text: template, using: [:])
        #expect(result == template)
    }
}

@Suite("cURL Parser & Generator Tests")
struct CURLParserTests {
    
    @Test("Parse simple GET request")
    func testParseSimpleGet() {
        let curl = "curl https://api.example.com/todos"
        let parsed = CURLParser.parse(curl)
        #expect(parsed != nil)
        #expect(parsed?.url == "https://api.example.com/todos")
        #expect(parsed?.method == HTTPMethodType.get)
    }
    
    @Test("Parse POST request with headers and JSON body")
    func testParsePostWithHeadersAndBody() {
        let curl = """
        curl -X POST "https://api.example.com/users" \
             -H "Content-Type: application/json" \
             -H "Authorization: Bearer mySecretToken" \
             -d '{"name": "Arsen", "role": "admin"}'
        """
        let parsed = CURLParser.parse(curl)
        #expect(parsed != nil)
        #expect(parsed?.url == "https://api.example.com/users")
        #expect(parsed?.method == HTTPMethodType.post)
        #expect(parsed?.bodyType == BodyType.json)
        #expect(parsed?.body?.contains("\"name\": \"Arsen\"") == true)
        
        let headerKeys = parsed?.headers.map { $0.key } ?? []
        #expect(headerKeys.contains("Content-Type"))
        #expect(headerKeys.contains("Authorization"))
    }
    
    @Test("Generate cURL string for all methods")
    func testGenerateCURL() {
        let generated = CURLGenerator.generate(
            url: "https://api.example.com/users",
            method: .post,
            headers: [("X-Requested-With", "APICraft", true)],
            body: "{\"username\": \"test\"}",
            bodyType: .json
        )
        #expect(generated.contains("curl -X POST \"https://api.example.com/users\""))
        #expect(generated.contains("-H \"X-Requested-With: APICraft\""))
        #expect(generated.contains("-d '{\"username\": \"test\"}'"))
        
        let deleteCurl = CURLGenerator.generate(
            url: "https://api.example.com/items/5",
            method: .delete,
            headers: [],
            body: nil,
            bodyType: .none
        )
        #expect(deleteCurl.contains("curl -X DELETE \"https://api.example.com/items/5\""))
    }
}

@Suite("Assertion Engine Tests")
struct AssertionEngineTests {
    
    @Test("Status code equality and inequality")
    func testStatusCodeAssertions() {
        let response = NetworkResponse(
            statusCode: 200,
            headers: ["Content-Type": "application/json"],
            cookies: [],
            body: "{\"ok\": true}",
            durationMs: 120.0,
            sizeBytes: 15
        )
        
        let passAssertion = SDTestAssertion(
            target: .statusCode,
            comparison: .equals,
            expectedValue: "200"
        )
        let passResult = AssertionEngine.evaluate(assertion: passAssertion, response: response)
        #expect(passResult.isPassed)
        
        let failAssertion = SDTestAssertion(
            target: .statusCode,
            comparison: .equals,
            expectedValue: "404"
        )
        let failResult = AssertionEngine.evaluate(assertion: failAssertion, response: response)
        #expect(!failResult.isPassed)
        #expect(failResult.failureReason?.contains("200") == true)
    }
    
    @Test("Response time latency assertion")
    func testResponseTimeAssertion() {
        let fastResponse = NetworkResponse(statusCode: 200, headers: [:], cookies: [], body: nil, durationMs: 150.0, sizeBytes: 100)
        let latencyAssertion = SDTestAssertion(
            target: .responseTime,
            comparison: .lessThan,
            expectedValue: "300"
        )
        let result = AssertionEngine.evaluate(assertion: latencyAssertion, response: fastResponse)
        #expect(result.isPassed)
        
        let slowResponse = NetworkResponse(statusCode: 200, headers: [:], cookies: [], body: nil, durationMs: 450.0, sizeBytes: 100)
        let slowResult = AssertionEngine.evaluate(assertion: latencyAssertion, response: slowResponse)
        #expect(!slowResult.isPassed)
    }
    
    @Test("Header equality and containment")
    func testHeaderAssertion() {
        let response = NetworkResponse(
            statusCode: 200,
            headers: ["Content-Type": "application/json; charset=utf-8"],
            cookies: [],
            body: nil,
            durationMs: 80.0,
            sizeBytes: 20
        )
        
        let headerAssertion = SDTestAssertion(
            target: .header,
            keyPath: "Content-Type",
            comparison: .contains,
            expectedValue: "application/json"
        )
        let result = AssertionEngine.evaluate(assertion: headerAssertion, response: response)
        #expect(result.isPassed)
    }
    
    @Test("Body substring containment")
    func testBodyContainsAssertion() {
        let response = NetworkResponse(
            statusCode: 200,
            headers: [:],
            cookies: [],
            body: "{\"message\": \"User registered successfully\", \"status\": \"ok\"}",
            durationMs: 90.0,
            sizeBytes: 60
        )
        
        let bodyAssertion = SDTestAssertion(
            target: .bodyContains,
            comparison: .contains,
            expectedValue: "registered successfully"
        )
        let result = AssertionEngine.evaluate(assertion: bodyAssertion, response: response)
        #expect(result.isPassed)
    }
    
    @Test("JSON Key existence and nested path lookup")
    func testJSONKeyExists() {
        let jsonString = """
        {
            "status": "success",
            "data": {
                "profile": {
                    "email": "user@example.com"
                },
                "roles": ["admin", "editor"]
            }
        }
        """
        let response = NetworkResponse(statusCode: 200, headers: [:], cookies: [], body: jsonString, durationMs: 50.0, sizeBytes: 100)
        
        let keyAssertion = SDTestAssertion(
            target: .jsonKeyExists,
            keyPath: "data.profile.email",
            comparison: .equals,
            expectedValue: ""
        )
        let result = AssertionEngine.evaluate(assertion: keyAssertion, response: response)
        #expect(result.isPassed)
        
        let arrayKeyAssertion = SDTestAssertion(
            target: .jsonKeyExists,
            keyPath: "data.roles[0]",
            comparison: .equals,
            expectedValue: ""
        )
        let arrayResult = AssertionEngine.evaluate(assertion: arrayKeyAssertion, response: response)
        #expect(arrayResult.isPassed)
        
        let missingKeyAssertion = SDTestAssertion(
            target: .jsonKeyExists,
            keyPath: "data.profile.phoneNumber",
            comparison: .equals,
            expectedValue: ""
        )
        let missingResult = AssertionEngine.evaluate(assertion: missingKeyAssertion, response: response)
        #expect(!missingResult.isPassed)
    }
    
    @Test("JSON Value comparison: string, equality and numbers")
    func testJSONValueComparison() {
        let jsonString = """
        {
            "user": {
                "id": 105,
                "name": "Arsen",
                "score": 98.5
            }
        }
        """
        let response = NetworkResponse(statusCode: 200, headers: [:], cookies: [], body: jsonString, durationMs: 50.0, sizeBytes: 100)
        
        let nameAssertion = SDTestAssertion(
            target: .jsonValue,
            keyPath: "user.name",
            comparison: .equals,
            expectedValue: "Arsen"
        )
        let nameResult = AssertionEngine.evaluate(assertion: nameAssertion, response: response)
        #expect(nameResult.isPassed)
        
        let scoreAssertion = SDTestAssertion(
            target: .jsonValue,
            keyPath: "user.score",
            comparison: .greaterThan,
            expectedValue: "90"
        )
        let scoreResult = AssertionEngine.evaluate(assertion: scoreAssertion, response: response)
        #expect(scoreResult.isPassed)
    }
}

@Suite("HTTP Methods & Enums Tests")
struct HTTPMethodAndModelTests {
    
    @Test("All HTTPMethodType cases have valid colors and badge rawValues")
    func testAllHTTPMethods() {
        let allMethods: [HTTPMethodType] = [.get, .post, .put, .patch, .delete, .head]
        #expect(allMethods.count == 6)
        
        for method in allMethods {
            _ = MethodBadgeView.color(for: method)
            #expect(!method.rawValue.isEmpty)
            #expect(method.id == method.rawValue)
        }
    }
    
    @Test("BodyType display names and encodings")
    func testBodyTypes() {
        #expect(BodyType.none.rawValue == "None")
        #expect(BodyType.json.rawValue == "JSON")
        #expect(BodyType.urlEncoded.rawValue == "x-www-form-urlencoded")
        #expect(BodyType.allCases.count == 4)
    }
}

@Suite("Response Cookie Model Tests")
struct ResponseCookieTests {
    
    @Test("ResponseCookie properties mapping")
    func testCookieModel() {
        let cookie = ResponseCookie(
            name: "session_id",
            value: "xyz123abc",
            domain: "example.com",
            path: "/",
            isSecure: true,
            isHTTPOnly: true
        )
        
        #expect(cookie.name == "session_id")
        #expect(cookie.value == "xyz123abc")
        #expect(cookie.domain == "example.com")
        #expect(cookie.path == "/")
        #expect(cookie.isSecure)
        #expect(cookie.isHTTPOnly)
    }
}
