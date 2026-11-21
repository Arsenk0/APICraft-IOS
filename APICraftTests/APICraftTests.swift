//
//  APICraftTests.swift
//  APICraftTests
//
//  Created by Arsen Khomiak on 05.11.2026.
//

import Testing
import Foundation
import SwiftData
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
    
    @Test("Parse POST request with urlencoded form body")
    func testParsePostWithURLEncodedBody() {
        let curl = """
        curl -X POST "https://api.example.com/login" \
             -H "Content-Type: application/x-www-form-urlencoded" \
             -d "username=arsen&password=secret"
        """
        let parsed = CURLParser.parse(curl)
        #expect(parsed != nil)
        #expect(parsed?.url == "https://api.example.com/login")
        #expect(parsed?.method == HTTPMethodType.post)
        #expect(parsed?.bodyType == BodyType.urlEncoded)
        #expect(parsed?.body == "username=arsen&password=secret")
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
    
    struct MockAssertion: AssertionProtocol {
        var target: AssertionTarget
        var keyPath: String?
        var comparison: AssertionComparison
        var expectedValue: String
        var isEnabled: Bool = true
    }
    
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
        
        let passAssertion = MockAssertion(
            target: .statusCode,
            comparison: .equals,
            expectedValue: "200"
        )
        let passResult = AssertionEngine.evaluate(assertion: passAssertion, response: response)
        #expect(passResult.isPassed)
        
        let failAssertion = MockAssertion(
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
        let latencyAssertion = MockAssertion(
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
    
    @Test("Header equality, containment, and case-insensitivity per RFC 7230")
    func testHeaderAssertionCaseInsensitive() {
        let response = NetworkResponse(
            statusCode: 200,
            headers: ["Content-Type": "application/json; charset=utf-8"],
            cookies: [],
            body: nil,
            durationMs: 80.0,
            sizeBytes: 20
        )
        
        // Exact match
        let exactAssertion = MockAssertion(
            target: .header,
            keyPath: "Content-Type",
            comparison: .contains,
            expectedValue: "application/json"
        )
        #expect(AssertionEngine.evaluate(assertion: exactAssertion, response: response).isPassed)
        
        // Lowercase query
        let lowerAssertion = MockAssertion(
            target: .header,
            keyPath: "content-type",
            comparison: .contains,
            expectedValue: "application/json"
        )
        #expect(AssertionEngine.evaluate(assertion: lowerAssertion, response: response).isPassed)
        
        // Uppercase query
        let upperAssertion = MockAssertion(
            target: .header,
            keyPath: "CONTENT-TYPE",
            comparison: .contains,
            expectedValue: "application/json"
        )
        #expect(AssertionEngine.evaluate(assertion: upperAssertion, response: response).isPassed)
        
        // Regex match on header
        let regexAssertion = MockAssertion(
            target: .header,
            keyPath: "content-type",
            comparison: .regexMatch,
            expectedValue: "application/[a-z]+"
        )
        #expect(AssertionEngine.evaluate(assertion: regexAssertion, response: response).isPassed)
        
        // Not equals on header
        let notEqAssertion = MockAssertion(
            target: .header,
            keyPath: "content-type",
            comparison: .notEquals,
            expectedValue: "text/html"
        )
        #expect(AssertionEngine.evaluate(assertion: notEqAssertion, response: response).isPassed)
    }
    
    @Test("Body substring containment, equality, not equals and regex")
    func testBodyContainsAssertion() {
        let response = NetworkResponse(
            statusCode: 200,
            headers: [:],
            cookies: [],
            body: "{\"message\": \"User registered successfully\", \"status\": \"ok\"}",
            durationMs: 90.0,
            sizeBytes: 60
        )
        
        let bodyContains = MockAssertion(
            target: .bodyContains,
            comparison: .contains,
            expectedValue: "registered successfully"
        )
        #expect(AssertionEngine.evaluate(assertion: bodyContains, response: response).isPassed)
        
        let bodyNotEquals = MockAssertion(
            target: .bodyContains,
            comparison: .notEquals,
            expectedValue: "Error"
        )
        #expect(AssertionEngine.evaluate(assertion: bodyNotEquals, response: response).isPassed)
        
        let bodyRegex = MockAssertion(
            target: .bodyContains,
            comparison: .regexMatch,
            expectedValue: "User [a-z]+ successfully"
        )
        #expect(AssertionEngine.evaluate(assertion: bodyRegex, response: response).isPassed)
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
        
        let keyAssertion = MockAssertion(
            target: .jsonKeyExists,
            keyPath: "data.profile.email",
            comparison: .equals,
            expectedValue: ""
        )
        let result = AssertionEngine.evaluate(assertion: keyAssertion, response: response)
        #expect(result.isPassed)
        
        let arrayKeyAssertion = MockAssertion(
            target: .jsonKeyExists,
            keyPath: "data.roles[0]",
            comparison: .equals,
            expectedValue: ""
        )
        let arrayResult = AssertionEngine.evaluate(assertion: arrayKeyAssertion, response: response)
        #expect(arrayResult.isPassed)
        
        let missingKeyAssertion = MockAssertion(
            target: .jsonKeyExists,
            keyPath: "data.profile.phoneNumber",
            comparison: .equals,
            expectedValue: ""
        )
        let missingResult = AssertionEngine.evaluate(assertion: missingKeyAssertion, response: response)
        #expect(!missingResult.isPassed)
    }
    
    @Test("JSON Value comparison: string, equality, numbers, and regex")
    func testJSONValueComparison() {
        let jsonString = """
        {
            "user": {
                "id": 105,
                "name": "Arsen",
                "email": "arsen@example.com",
                "score": 98.5
            }
        }
        """
        let response = NetworkResponse(statusCode: 200, headers: [:], cookies: [], body: jsonString, durationMs: 50.0, sizeBytes: 100)
        
        let nameAssertion = MockAssertion(
            target: .jsonValue,
            keyPath: "user.name",
            comparison: .equals,
            expectedValue: "Arsen"
        )
        let nameResult = AssertionEngine.evaluate(assertion: nameAssertion, response: response)
        #expect(nameResult.isPassed)
        
        let scoreAssertion = MockAssertion(
            target: .jsonValue,
            keyPath: "user.score",
            comparison: .greaterThan,
            expectedValue: "90"
        )
        let scoreResult = AssertionEngine.evaluate(assertion: scoreAssertion, response: response)
        #expect(scoreResult.isPassed)
        
        let regexAssertion = MockAssertion(
            target: .jsonValue,
            keyPath: "user.email",
            comparison: .regexMatch,
            expectedValue: "^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$"
        )
        let regexResult = AssertionEngine.evaluate(assertion: regexAssertion, response: response)
        #expect(regexResult.isPassed)
    }
    
    @Test("AssertionEngine evaluateOverallSuccess handles empty and non-empty assertion lists")
    func testEvaluateOverallSuccess() {
        // Empty assertions: 2xx/3xx passes
        #expect(AssertionEngine.evaluateOverallSuccess(evaluationResults: [], statusCode: 200))
        #expect(AssertionEngine.evaluateOverallSuccess(evaluationResults: [], statusCode: 301))
        #expect(!AssertionEngine.evaluateOverallSuccess(evaluationResults: [], statusCode: 404))
        #expect(!AssertionEngine.evaluateOverallSuccess(evaluationResults: [], statusCode: 500))
        
        // Non-empty assertions: all must pass
        let passLog = AssertionEvaluationResult(description: "OK", isPassed: true)
        let failLog = AssertionEvaluationResult(description: "Failed", isPassed: false, failureReason: "Mismatch")
        
        #expect(AssertionEngine.evaluateOverallSuccess(evaluationResults: [passLog], statusCode: 200))
        #expect(AssertionEngine.evaluateOverallSuccess(evaluationResults: [passLog], statusCode: 500))
        #expect(!AssertionEngine.evaluateOverallSuccess(evaluationResults: [passLog, failLog], statusCode: 200))
    }
}

@Suite("HTTP Methods & Enums Tests")
struct HTTPMethodAndModelTests {
    
    @Test("All HTTPMethodType cases have valid colors and badge rawValues")
    func testAllHTTPMethods() {
        let allMethods: [HTTPMethodType] = [.get, .post, .put, .patch, .delete, .head, .options]
        #expect(allMethods.count == 7)
        
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
        #expect(BodyType.formData.rawValue == "Form Data")
        #expect(BodyType.allCases.count == 4)
    }
    
    @Test("AssertionComparison cases include regexMatch")
    func testAssertionComparisonCases() {
        #expect(AssertionComparison.allCases.contains(.regexMatch))
        #expect(AssertionComparison.regexMatch.rawValue == "matches regex")
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

@Suite("Collection Persistence Tests")
@MainActor
struct CollectionPersistenceTests {
    
    @Test("Save request to collection")
    func testSaveToCollection() throws {
        let schema = Schema([
            SDCollection.self,
            SDRequest.self,
            SDRequestParameter.self,
            SDTestAssertion.self,
            SDExecutionResult.self,
            SDAssertionLog.self,
            SDEnvironment.self,
            SDEnvironmentVariable.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = container.mainContext
        
        let col = SDCollection(name: "Test Col")
        context.insert(col)
        try context.save()
        
        let vm = RequestBuilderViewModel()
        vm.url = "https://httpbin.org/get"
        vm.queryParams = [RequestKeyValue(key: "foo", value: "bar", isEnabled: true)]
        vm.headers = [RequestKeyValue(key: "X-Test", value: "1", isEnabled: true)]
        vm.assertions = [RequestAssertionItem(target: .statusCode, comparison: .equals, expectedValue: "200")]
        
        vm.saveToCollection(collection: col, customTitle: "My Request", context: context)
        
        #expect(col.requests.count == 1)
        #expect(col.requests.first?.title == "My Request")
    }
}


@Suite("Real-World JSONPlaceholder & End-to-End Tests")
struct RealWorldDataTests {
    
    @Test("Resolve URL with both raw and percent-encoded template variables")
    func testResolveEncodedAndRawVariables() {
        let envVars = [
            "baseUrl": "https://jsonplaceholder.typicode.com",
            "postId": "1"
        ]
        
        // Raw template
        let rawURL = "{{baseUrl}}/posts/{{postId}}"
        let resolvedRaw = VariableResolver.resolve(text: rawURL, using: envVars)
        #expect(resolvedRaw == "https://jsonplaceholder.typicode.com/posts/1")
        
        // Percent-encoded template (%7B%7B and %7D%7D) produced by URL components
        let encodedURL = "%7B%7BbaseUrl%7D%7D/posts/%7B%7BpostId%7D%7D"
        let resolvedEncoded = VariableResolver.resolve(text: encodedURL, using: envVars)
        #expect(resolvedEncoded == "https://jsonplaceholder.typicode.com/posts/1")
    }
    
    @Test("Validate JSONPlaceholder Post response with all assertion targets")
    func testJSONPlaceholderPostAssertions() {
        let realResponseBody = """
        {
            "userId": 1,
            "id": 1,
            "title": "sunt aut facere repellat provident occaecati excepturi optio reprehenderit",
            "body": "quia et suscipit recusandae consequuntur expedita et cum reprehenderit"
        }
        """
        
        let response = NetworkResponse(
            statusCode: 200,
            headers: [
                "Content-Type": "application/json; charset=utf-8",
                "Server": "cloudflare"
            ],
            cookies: [],
            body: realResponseBody,
            durationMs: 142.0,
            sizeBytes: realResponseBody.utf8.count
        )
        
        // 1. Status Code 200
        let statusAssertion = SDTestAssertion(target: .statusCode, comparison: .equals, expectedValue: "200")
        let statusRes = AssertionEngine.evaluate(assertion: statusAssertion, response: response)
        #expect(statusRes.isPassed)
        
        // 2. Response Time < 1000ms
        let timeAssertion = SDTestAssertion(target: .responseTime, comparison: .lessThan, expectedValue: "1000")
        let timeRes = AssertionEngine.evaluate(assertion: timeAssertion, response: response)
        #expect(timeRes.isPassed)
        
        // 3. JSON Key Exists "title"
        let titleKeyAssertion = SDTestAssertion(target: .jsonKeyExists, keyPath: "title", comparison: .equals, expectedValue: "title")
        let titleKeyRes = AssertionEngine.evaluate(assertion: titleKeyAssertion, response: response)
        #expect(titleKeyRes.isPassed)
        
        // 4. JSON Key Exists "userId"
        let userIdKeyAssertion = SDTestAssertion(target: .jsonKeyExists, keyPath: "userId", comparison: .equals, expectedValue: "userId")
        let userIdKeyRes = AssertionEngine.evaluate(assertion: userIdKeyAssertion, response: response)
        #expect(userIdKeyRes.isPassed)
        
        // 5. JSON Value "id" == 1
        let idValAssertion = SDTestAssertion(target: .jsonValue, keyPath: "id", comparison: .equals, expectedValue: "1")
        let idValRes = AssertionEngine.evaluate(assertion: idValAssertion, response: response)
        #expect(idValRes.isPassed)
        
        // 6. Header "Content-Type" contains "application/json"
        let headerAssertion = SDTestAssertion(target: .header, keyPath: "Content-Type", comparison: .contains, expectedValue: "application/json")
        let headerRes = AssertionEngine.evaluate(assertion: headerAssertion, response: response)
        #expect(headerRes.isPassed)
        
        // 7. Body substring "sunt aut facere"
        let bodyAssertion = SDTestAssertion(target: .bodyContains, comparison: .contains, expectedValue: "sunt aut facere")
        let bodyRes = AssertionEngine.evaluate(assertion: bodyAssertion, response: response)
        #expect(bodyRes.isPassed)
    }
    
    @Test("Telegram-style clipboard parser identifies URLs, JSON, and cURL")
    func testTelegramClipboardParser() {
        // TikTok URL
        let tiktokInfo = ClipboardPreviewInfo.make(from: "https://vt.tiktok.com/ZS1234567/")
        #expect(tiktokInfo != nil)
        #expect(tiktokInfo?.title == "vt.tiktok.com")
        #expect(tiktokInfo?.subtitle == "Paste from TikTok")
        #expect(tiktokInfo?.iconName == "safari.fill")
        
        // JSONPlaceholder URL
        let typicodeInfo = ClipboardPreviewInfo.make(from: "https://jsonplaceholder.typicode.com/posts/1")
        #expect(typicodeInfo != nil)
        #expect(typicodeInfo?.title == "jsonplaceholder.typicode.com")
        #expect(typicodeInfo?.subtitle == "Paste from Typicode")
        
        // JSON Body
        let jsonInfo = ClipboardPreviewInfo.make(from: "{\"title\": \"New Post\", \"userId\": 1}")
        #expect(jsonInfo != nil)
        #expect(jsonInfo?.subtitle == "Paste JSON")
        #expect(jsonInfo?.iconName == "curlybraces")
        
        // cURL Command
        let curlInfo = ClipboardPreviewInfo.make(from: "curl -X GET \"https://jsonplaceholder.typicode.com/posts\"")
        #expect(curlInfo != nil)
        #expect(curlInfo?.title == "cURL Command")
        #expect(curlInfo?.subtitle == "Paste cURL")
        #expect(curlInfo?.iconName == "terminal.fill")
    }
    
    @MainActor
    @Test("SwiftData In-Memory Model Container: Collection, Request, Environment and Assertions")
    func testSwiftDataCollectionAndEnvironmentIntegration() throws {
        let schema = Schema([
            SDCollection.self,
            SDRequest.self,
            SDRequestParameter.self,
            SDTestAssertion.self,
            SDExecutionResult.self,
            SDAssertionLog.self,
            SDEnvironment.self,
            SDEnvironmentVariable.self
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = container.mainContext
        
        // Create Environment
        let env = SDEnvironment(name: "JSONPlaceholder Test")
        let var1 = SDEnvironmentVariable(key: "baseUrl", value: "https://jsonplaceholder.typicode.com")
        let var2 = SDEnvironmentVariable(key: "postId", value: "1")
        var1.environment = env
        var2.environment = env
        env.variables = [var1, var2]
        context.insert(env)
        
        // Create Collection & Request
        let collection = SDCollection(name: "Posts API", details: "Integration tests for posts endpoints")
        let request = SDRequest(
            title: "Get Post by ID",
            urlTemplate: "{{baseUrl}}/posts/{{postId}}",
            method: .get,
            bodyType: .none,
            rawBodyContent: nil,
            isHistoryItem: false
        )
        request.collection = collection
        collection.requests.append(request)
        
        let assertion = SDTestAssertion(
            target: .statusCode,
            comparison: .equals,
            expectedValue: "200"
        )
        request.assertions.append(assertion)
        
        context.insert(collection)
        try context.save()
        
        // Verify query
        let fetchDesc = FetchDescriptor<SDCollection>()
        let fetchedCollections = try context.fetch(fetchDesc)
        #expect(fetchedCollections.count == 1)
        #expect(fetchedCollections.first?.requests.first?.assertions.count == 1)
        
        // Verify resolution
        let varsMap = Dictionary(uniqueKeysWithValues: env.variables.map { ($0.key, $0.value) })
        let finalURL = VariableResolver.resolve(text: request.urlTemplate, using: varsMap)
        #expect(finalURL == "https://jsonplaceholder.typicode.com/posts/1")
    }
}

@Suite("URL Sync & Decoding Tests")
struct URLSyncAndDecodingTests {
    
    @Test("syncParamsToURL preserves Cyrillic and unicode characters without %D0% encoding")
    @MainActor
    func testSyncParamsToURLPreservesCyrillic() {
        let vm = RequestBuilderViewModel()
        vm.url = "https://example.com/пошук"
        vm.queryParams = [
            RequestKeyValue(key: "query", value: "Київ", isEnabled: true),
            RequestKeyValue(key: "filter", value: "книги", isEnabled: true)
        ]
        
        vm.syncParamsToURL()
        
        #expect(!vm.url.contains("%D0%"))
        #expect(vm.url.contains("Київ"))
        #expect(vm.url.contains("книги"))
        #expect(vm.url.contains("пошук"))
    }
    
    @Test("syncURLToParams decodes percent-encoded query items into human-readable text")
    @MainActor
    func testSyncURLToParamsDecodesPercentEncoding() {
        let vm = RequestBuilderViewModel()
        vm.url = "https://example.com/search?user=%D0%9C%D0%B0%D0%BA%D1%81%D0%B8%D0%BC&city=%D0%9A%D0%B8%D1%97%D0%B2"
        
        vm.syncURLToParams()
        
        #expect(vm.queryParams.count == 2)
        #expect(vm.queryParams.first { $0.key == "user" }?.value == "Максим")
        #expect(vm.queryParams.first { $0.key == "city" }?.value == "Київ")
    }
    
    @Test("Arbitrary pasted text with Cyrillic characters is not corrupted by syncParamsToURL")
    @MainActor
    func testArbitraryPastedTextNotCorrupted() {
        let vm = RequestBuilderViewModel()
        let sample = "Максимка прийшов, сидим я ніхуя не роблю п він работає "
        let clean = sample.removingPercentEncoding ?? sample
        vm.url = clean
        
        // Calling syncParamsToURL directly should never corrupt raw text into %D0%
        vm.syncParamsToURL()
        
        #expect(!vm.url.contains("%D0%9C%D0%B0"))
        #expect(vm.url == sample)
    }
}

// MARK: - Additional Coverage Tests (Auth, JSON Formatting, Title Resolution, JSONPath Edge Cases)

@Suite("Auth & cURL Export Tests")
struct AuthCURLExportTests {
    
    @Test("cURL export includes Bearer Authorization header")
    @MainActor
    func testCURLExportWithBearerToken() {
        let vm = RequestBuilderViewModel()
        vm.url = "https://api.example.com/users"
        vm.method = .get
        vm.authType = .bearer
        vm.bearerToken = "mySecret123"
        vm.headers = []
        
        let curl = vm.exportAsCURL()
        #expect(curl.contains("Authorization: Bearer mySecret123"))
        #expect(curl.contains("curl -X GET"))
    }
    
    @Test("cURL export includes Basic Authorization header with Base64 encoding")
    @MainActor
    func testCURLExportWithBasicAuth() {
        let vm = RequestBuilderViewModel()
        vm.url = "https://api.example.com/login"
        vm.method = .post
        vm.authType = .basic
        vm.basicUsername = "admin"
        vm.basicPassword = "password123"
        vm.headers = []
        
        let curl = vm.exportAsCURL()
        // "admin:password123" in base64 = "YWRtaW46cGFzc3dvcmQxMjM="
        #expect(curl.contains("Authorization: Basic YWRtaW46cGFzc3dvcmQxMjM="))
    }
    
    @Test("cURL import detects Bearer token from Authorization header")
    @MainActor
    func testCURLImportBearerAuth() {
        let vm = RequestBuilderViewModel()
        let curlString = """
        curl -X GET "https://api.example.com/me" \
             -H "Authorization: Bearer tok_abc123"
        """
        let success = vm.importFromCURL(curlString)
        #expect(success)
        #expect(vm.authType == .bearer)
        #expect(vm.bearerToken == "tok_abc123")
        #expect(vm.url == "https://api.example.com/me")
    }
}

@Suite("JSON Formatting & Title Resolution Tests")
struct FormattingAndTitleTests {
    
    @Test("formatJSONBody pretty-prints valid JSON")
    @MainActor
    func testFormatJSONBody() {
        let vm = RequestBuilderViewModel()
        vm.bodyText = "{\"name\":\"Arsen\",\"age\":22}"
        vm.formatJSONBody()
        
        #expect(vm.bodyText.contains("\"age\" : 22"))
        #expect(vm.bodyText.contains("\"name\" : \"Arsen\""))
    }
    
    @Test("resolveTitle extracts host and path from URL")
    @MainActor
    func testResolveTitleFromURL() {
        let vm = RequestBuilderViewModel()
        vm.title = ""
        vm.url = "https://jsonplaceholder.typicode.com/posts/1"
        
        let resolved = vm.resolveTitle()
        #expect(resolved == "jsonplaceholder.typicode.com/posts/1")
    }
}

@Suite("JSON Path Lookup Edge Cases")
struct JSONPathEdgeCaseTests {
    
    @Test("lookupJSONPath returns nil for empty path")
    func testEmptyPathReturnsNil() {
        let json: [String: Any] = ["key": "value"]
        let result = AssertionEngine.lookupJSONPath(in: json, path: "")
        #expect(result == nil)
    }
    
    @Test("lookupJSONPath handles whitespace-only path")
    func testWhitespaceOnlyPathReturnsNil() {
        let json: [String: Any] = ["key": "value"]
        let result = AssertionEngine.lookupJSONPath(in: json, path: "   ")
        #expect(result == nil)
    }
    
    @Test("lookupJSONPath works with root-level array")
    func testRootArrayLookup() {
        let json: [Any] = ["first", "second", "third"]
        let result = AssertionEngine.lookupJSONPath(in: json, path: "1")
        #expect(result as? String == "second")
    }
}
