/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Foundation

import UIKit
import XCTest

class SearchTests: XCTestCase {
    private let uriFixup = URIFixup()

    func testParsing() {
        let parser = OpenSearchParser(pluginMode: true)
        let file = NSBundle.mainBundle().pathForResource("google", ofType: "xml", inDirectory: "SearchPlugins/en")
        let engine: OpenSearchEngine! = parser.parse(file!)
        XCTAssertEqual(engine.shortName, "Google")
        XCTAssertNil(engine.description)

        // Test regular search queries.
        XCTAssertEqual(engine.searchURLForQuery("foobar")!.absoluteString, "https://www.google.com/search?q=foobar&ie=utf-8&oe=utf-8")

        // Test search suggestion queries.
        XCTAssertEqual(engine.suggestURLForQuery("foobar")!.absoluteString, "https://www.google.com/complete/search?client=firefox&q=foobar")
    }

    func testURIFixup() {
        // Check valid URLs. We can load these after some fixup.
        checkValidURL("http://www.mozilla.org", afterFixup: "http://www.mozilla.org")
        checkValidURL("about:", afterFixup: "about:")
        checkValidURL("about:config", afterFixup: "about:config")
        checkValidURL("file:///f/o/o", afterFixup: "file:///f/o/o")
        checkValidURL("ftp://ftp.mozilla.org", afterFixup: "ftp://ftp.mozilla.org")
        checkValidURL("foo.bar", afterFixup: "http://foo.bar")
        checkValidURL(" foo.bar ", afterFixup: "http://foo.bar")
        checkValidURL("1.2.3", afterFixup: "http://1.2.3")

        // Check invalid URLs. These are passed along to the default search engine.
        checkInvalidURL("foobar")
        checkInvalidURL("foo bar")
        checkInvalidURL("mozilla. org")
        checkInvalidURL("about: config")
        checkInvalidURL("123")
        checkInvalidURL("a/b")
    }

    private func checkValidURL(beforeFixup: String, afterFixup: String) {
        XCTAssertEqual(uriFixup.getURL(beforeFixup)!.absoluteString, afterFixup)
    }

    private func checkInvalidURL(beforeFixup: String) {
        XCTAssertNil(uriFixup.getURL(beforeFixup))
    }

    func testSuggestClient() {
        let webServerBase = startMockSuggestServer()

        let engine = OpenSearchEngine(shortName: "Mock engine", description: nil, image: nil, searchTemplate: "", suggestTemplate: "\(webServerBase)?q={searchTerms}")
        let client = SearchSuggestClient(searchEngine: engine, userAgent: "Fx-testSuggestClient")


        let query1 = self.expectationWithDescription("foo query")
        client.query("foo", callback: { response, error in
            withExtendedLifetime(client) {
                if error != nil {
                    XCTFail("Error: \(error?.description)")
                }

                XCTAssertEqual(response![0], "foo")
                XCTAssertEqual(response![1], "foo2")
                XCTAssertEqual(response![2], "foo you")

                query1.fulfill()
            }
        })
        waitForExpectationsWithTimeout(10, handler: nil)

        let query2 = self.expectationWithDescription("foo bar query")
        client.query("foo bar", callback: { response, error in
            withExtendedLifetime(client) {
                if error != nil {
                    XCTFail("Error: \(error?.description)")
                }

                XCTAssertEqual(response![0], "foo bar soap")
                XCTAssertEqual(response![1], "foo barstool")
                XCTAssertEqual(response![2], "foo bartender")

                query2.fulfill()
            }
        })
        waitForExpectationsWithTimeout(10, handler: nil)
    }

    private func startMockSuggestServer() -> String {
        let webServer: GCDWebServer = GCDWebServer()

        webServer.addHandlerForMethod("GET", path: "/", requestClass: GCDWebServerRequest.self) { (request) -> GCDWebServerResponse! in
            var suggestions: [String]!
            let query = request.query["q"] as! String
            switch query {
            case "foo":
                suggestions = ["foo", "foo2", "foo you"]
            case "foo bar":
                suggestions = ["foo bar soap", "foo barstool", "foo bartender"]
            default:
                XCTFail("Unexpected query: \(query)")
            }
            return GCDWebServerDataResponse(JSONObject: [query, suggestions])
        }

        if !webServer.startWithPort(0, bonjourName: nil) {
            XCTFail("Can't start the GCDWebServer")
        }

        return "http://localhost:\(webServer.port)"
    }
}
