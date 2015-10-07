/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import UIKit
import XCTest

import Shared
import Storage
import WebKit

public class TabManagerMockProfile: MockProfile {
    override func storeTabs(tabs: [RemoteTab]) -> Deferred<Maybe<Int>> {
        return self.remoteClientsAndTabs.insertOrUpdateTabs(tabs)
    }
}

class TabManagerTests: XCTestCase {

    override func setUp() {
        super.setUp()
    }

    override func tearDown() {
        super.tearDown()
    }

    func testTabManagerStoresChangesInDB() {
        let profile = TabManagerMockProfile()
        let manager = TabManager(defaultNewTabRequest: NSURLRequest(URL: NSURL(fileURLWithPath: "http://localhost")), profile: profile)
        let configuration = WKWebViewConfiguration()
        configuration.processPool = WKProcessPool()

        // test that non-private tabs are saved to the db
        // add some non-private tabs to the tab manager
        for _ in 0..<3 {
            let tab = Browser(configuration: configuration)
            manager.configureTab(tab, request: NSURLRequest(URL: NSURL(string: "http://yahoo.com")!), flushToDisk: false, zombie: false, restoring: false)
        }

        manager.storeChanges()
        let remoteTabs = profile.remoteClientsAndTabs.getTabsForClientWithGUID(nil).value.successValue
        let count = remoteTabs?.count
        XCTAssertEqual(count, 3)
        // now test that the database contains 3 tabs

        // test that private tabs are not saved to the DB
        // private tabs are only available in iOS9 so don't execute this part of the test if we're testing against < iOS9
        if #available(iOS 9, *) {
            // create some private tabs
            for _ in 0..<3 {
                let tab = Browser(configuration: configuration, isPrivate: true)
                manager.configureTab(tab, request: NSURLRequest(URL: NSURL(string: "http://yahoo.com")!), flushToDisk: false, zombie: false, restoring: false)
            }

            manager.storeChanges()

            // now test that the database still contains only 3 tabs
            let remoteTabs = profile.remoteClientsAndTabs.getTabsForClientWithGUID(nil).value.successValue
            let count = remoteTabs?.count
            XCTAssertEqual(count ?? 0, 3)
        }
    }
    
}
