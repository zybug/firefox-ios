/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Foundation
import XCTest
import Shared
import Storage


// TODO: rewrite this test to not use BrowserTable. It used to use HistoryTable…
class TestSwiftData: XCTestCase {
    var swiftData: SwiftData?
    var urlCounter = 1
    var testDB: String!

    override func setUp() {
        let files = MockFiles()
        do {
            try files.remove("testSwiftData.db")
        } catch _ {
        }
        testDB = (try! (files.getAndEnsureDirectory() as NSString)).stringByAppendingPathComponent("testSwiftData.db")
        swiftData = SwiftData(filename: testDB)
        let table = BrowserTable()

        // Ensure static flags match expected values.
        XCTAssert(SwiftData.ReuseConnections, "Reusing database connections")
        XCTAssert(SwiftData.EnableWAL, "WAL enabled")

        swiftData!.withConnection(SwiftData.Flags.ReadWriteCreate) { db in
            let f = FaviconsTable<Favicon>()
            f.create(db, version: 1)    // Because BrowserTable needs it.
            table.create(db, version: 1)
            return nil
        }

        XCTAssertNil(addSite(table, url: "http://url0", title: "title0"), "Added url0.")
    }

    override func tearDown() {
        // Restore static flags to their default values.
        SwiftData.ReuseConnections = true
        SwiftData.EnableWAL = true
    }

    /*
    // These two tests broke after pull #427.
    func testNoWALOrConnectionReuse() {
    SwiftData.EnableWAL = false
        SwiftData.ReuseConnections = false
        var error = writeDuringRead()
        XCTAssertEqual(error!.code, 5, "Got 'database is locked' error")
    }

    func testNoConnectionReuse() {
        SwiftData.EnableWAL = true
        SwiftData.ReuseConnections = false
        var error = writeDuringRead()
        XCTAssertNotNil(error, "Expected error during write.")
        XCTAssertEqual(error?.code ?? 0, 8, "Got 'attempt to write to read-only database' error")
    }
    */

    func testNoWAL() {
        SwiftData.EnableWAL = false
        SwiftData.ReuseConnections = true
        let error = writeDuringRead()
        XCTAssertNil(error, "Insertion succeeded")
    }

    func testDefaultSettings() {
        SwiftData.EnableWAL = true
        SwiftData.ReuseConnections = true
        let error = writeDuringRead()
        XCTAssertNil(error, "Insertion succeeded")
    }

    func testBusyTimeout() {
        SwiftData.EnableWAL = false
        SwiftData.ReuseConnections = false
        let error = writeDuringRead(closeTimeout: 1)
        XCTAssertNil(error, "Insertion succeeded")
    }

    func testFilledCursor() {
        SwiftData.ReuseConnections = false
        SwiftData.EnableWAL = false
        XCTAssertNil(writeDuringRead(true), "Insertion succeeded")
    }

    private func writeDuringRead(safeQuery: Bool = false, closeTimeout: UInt64? = nil) -> NSError? {

        // Query the database and hold the cursor.
        var c: Cursor<SDRow>!
        let error = swiftData!.withConnection(SwiftData.Flags.ReadOnly) { db in
            if safeQuery {
                c = db.executeQuery("SELECT * FROM history", factory: { $0 })
            } else {
                c = db.executeQueryUnsafe("SELECT * FROM history", factory: { $0 })
            }
            return nil
        }
        XCTAssertNil(error, "Queried database")

        // If we have a live cursor, this will step to the first result.
        // Stepping through a prepared statement without resetting it will lock the connection.
        c[0]

        // Close the cursor after a delay if there's a close timeout set.
        if let closeTimeout = closeTimeout {
            let queue = dispatch_queue_create("cursor timeout queue", DISPATCH_QUEUE_SERIAL)
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(closeTimeout * NSEC_PER_SEC)), queue) {
                c.close()
            }
        }

        return addSite(BrowserTable(), url: "http://url/\(urlCounter++)", title: "title\(urlCounter++)")
    }

    private func addSite(table: BrowserTable, url: String, title: String) -> NSError? {
        return swiftData!.withConnection(SwiftData.Flags.ReadWrite) { connection -> NSError? in
            let args: Args = [Bytes.generateGUID(), url, title]
            return connection.executeChange("INSERT INTO history (guid, url, title, is_deleted, should_upload) VALUES (?, ?, ?, 0, 0)", withArgs: args)
        }
    }

    func testEncrypt() {
        // XXX: Something is holding an open connection to the normal database, making it impossible
        // to change its encryption. This kills it so that we can move on.
        let files = MockFiles()
        do {
            try files.remove("testSwiftData.db")
        } catch _ {
        }
        let path = testDB
        func verifyData(swiftData: SwiftData) -> NSError? {
            return swiftData.withConnection(SwiftData.Flags.ReadOnly) { db in
                return nil
            }
        }

        XCTAssertNotNil(SwiftData(filename: path!), "Connected to unencrypted database")

        // Encrypt the database.
        XCTAssertNil(verifyData(SwiftData(filename: path!, key: "Secret")), "Encrypted database")

        // Now change the encryption key.
        XCTAssertNil(verifyData(SwiftData(filename: path!, key: "Secret2", prevKey: "Secret")), "Re-encrypted database")

        // Changing the encryption without the prevKey should fail.
        XCTAssertNotNil(verifyData(SwiftData(filename: path!)), "Failed decrypting database")

        // Now remove the encryption key.
        XCTAssertNil(verifyData(SwiftData(filename: path!, prevKey: "Secret2")), "Decrypted database")
    }
}