/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Foundation
import Shared
import XCGLogger

// To keep SwiftData happy.

let TableBookmarks = "bookmarks"
let TableBookmarksMirror = "bookmarksMirror"                           // Added in v9.
let TableBookmarksMirrorStructure = "bookmarksMirrorStructure"         // Added in v10.

let TableFavicons = "favicons"
let TableHistory = "history"
let TableDomains = "domains"
let TableVisits = "visits"
let TableFaviconSites = "favicon_sites"
let TableQueuedTabs = "queue"

let ViewWidestFaviconsForSites = "view_favicons_widest"
let ViewHistoryIDsWithWidestFavicons = "view_history_id_favicon"
let ViewIconForURL = "view_icon_for_url"

let IndexHistoryShouldUpload = "idx_history_should_upload"
let IndexVisitsSiteIDDate = "idx_visits_siteID_date"                   // Removed in v6.
let IndexVisitsSiteIDIsLocalDate = "idx_visits_siteID_is_local_date"   // Added in v6.
let IndexBookmarksMirrorStructureParentIdx = "idx_bookmarksMirrorStructure_parent_idx"   // Added in v10.

private let AllTables: Args = [
    TableDomains,
    TableFavicons,
    TableFaviconSites,

    TableHistory,
    TableVisits,

    TableBookmarks,
    TableBookmarksMirror,
    TableBookmarksMirrorStructure,

    TableQueuedTabs,
]

private let AllViews: Args = [
    ViewHistoryIDsWithWidestFavicons,
    ViewWidestFaviconsForSites,
    ViewIconForURL,
]

private let AllIndices: Args = [
    IndexHistoryShouldUpload,
    IndexVisitsSiteIDIsLocalDate,
    IndexBookmarksMirrorStructureParentIdx,
]

private let AllTablesIndicesAndViews: Args = AllViews + AllIndices + AllTables

private let log = Logger.syncLogger

/**
 * The monolithic class that manages the inter-related history etc. tables.
 * We rely on SQLiteHistory having initialized the favicon table first.
 */
public class BrowserTable: Table {
    static let DefaultVersion = 10
    let version: Int
    var name: String { return "BROWSER" }
    let sqliteVersion: Int32
    let supportsPartialIndices: Bool

    public init(version: Int = DefaultVersion) {
        self.version = version
        let v = sqlite3_libversion_number()
        self.sqliteVersion = v
        self.supportsPartialIndices = v >= 3008000          // 3.8.0.
        let ver = String.fromCString(sqlite3_libversion())!
        log.info("SQLite version: \(ver) (\(v)).")
    }

    func run(db: SQLiteDBConnection, sql: String, args: Args? = nil) -> Bool {
        let err = db.executeChange(sql, withArgs: args)
        if err != nil {
            log.error("Error running SQL in BrowserTable. \(err?.localizedDescription)")
            log.error("SQL was \(sql)")
        }
        return err == nil
    }

    // TODO: transaction.
    func run(db: SQLiteDBConnection, queries: [(String, Args?)]) -> Bool {
        for (sql, args) in queries {
            if !run(db, sql: sql, args: args) {
                return false
            }
        }
        return true
    }

    func runValidQueries(db: SQLiteDBConnection, queries: [(String?, Args?)]) -> Bool {
        for (sql, args) in queries {
            if let sql = sql {
                if !run(db, sql: sql, args: args) {
                    return false
                }
            }
        }
        return true
    }

    func prepopulateRootFolders(db: SQLiteDBConnection) -> Bool {
        let type = BookmarkNodeType.Folder.rawValue
        let root = BookmarkRoots.RootID

        let titleMobile = NSLocalizedString("Mobile Bookmarks", tableName: "Storage", comment: "The title of the folder that contains mobile bookmarks. This should match bookmarks.folder.mobile.label on Android.")
        let titleMenu = NSLocalizedString("Bookmarks Menu", tableName: "Storage", comment: "The name of the folder that contains desktop bookmarks in the menu. This should match bookmarks.folder.menu.label on Android.")
        let titleToolbar = NSLocalizedString("Bookmarks Toolbar", tableName: "Storage", comment: "The name of the folder that contains desktop bookmarks in the toolbar. This should match bookmarks.folder.toolbar.label on Android.")
        let titleUnsorted = NSLocalizedString("Unsorted Bookmarks", tableName: "Storage", comment: "The name of the folder that contains unsorted desktop bookmarks. This should match bookmarks.folder.unfiled.label on Android.")

        let args: Args = [
            root, BookmarkRoots.RootGUID, type, "Root", root,
            BookmarkRoots.MobileID, BookmarkRoots.MobileFolderGUID, type, titleMobile, root,
            BookmarkRoots.MenuID, BookmarkRoots.MenuFolderGUID, type, titleMenu, root,
            BookmarkRoots.ToolbarID, BookmarkRoots.ToolbarFolderGUID, type, titleToolbar, root,
            BookmarkRoots.UnfiledID, BookmarkRoots.UnfiledFolderGUID, type, titleUnsorted, root,
        ]

        let sql =
        "INSERT INTO bookmarks (id, guid, type, url, title, parent) VALUES " +
            "(?, ?, ?, NULL, ?, ?), " +    // Root
            "(?, ?, ?, NULL, ?, ?), " +    // Mobile
            "(?, ?, ?, NULL, ?, ?), " +    // Menu
            "(?, ?, ?, NULL, ?, ?), " +    // Toolbar
            "(?, ?, ?, NULL, ?, ?)  "      // Unsorted

        return self.run(db, sql: sql, args: args)
    }

    func getHistoryTableCreationString(forVersion version: Int = BrowserTable.DefaultVersion) -> String? {
        return "CREATE TABLE IF NOT EXISTS \(TableHistory) (" +
            "id INTEGER PRIMARY KEY AUTOINCREMENT, " +
            "guid TEXT NOT NULL UNIQUE, " +       // Not null, but the value might be replaced by the server's.
            "url TEXT UNIQUE, " +                 // May only be null for deleted records.
            "title TEXT NOT NULL, " +
            "server_modified INTEGER, " +         // Can be null. Integer milliseconds.
            "local_modified INTEGER, " +          // Can be null. Client clock. In extremis only.
            "is_deleted TINYINT NOT NULL, " +     // Boolean. Locally deleted.
            "should_upload TINYINT NOT NULL, " +  // Boolean. Set when changed or visits added.
            (version > 5 ? "domain_id INTEGER REFERENCES \(TableDomains)(id) ON DELETE CASCADE, " : "") +
            "CONSTRAINT urlOrDeleted CHECK (url IS NOT NULL OR is_deleted = 1)" +
            ")"
    }

    func getDomainsTableCreationString(forVersion version: Int = BrowserTable.DefaultVersion) -> String? {
        if version <= 5 {
            return nil
        }

        return "CREATE TABLE IF NOT EXISTS \(TableDomains) (" +
                   "id INTEGER PRIMARY KEY AUTOINCREMENT, " +
                   "domain TEXT NOT NULL UNIQUE, " +
                   "showOnTopSites TINYINT NOT NULL DEFAULT 1" +
               ")"
    }

    func getQueueTableCreationString(forVersion version: Int = BrowserTable.DefaultVersion) -> String? {
        if version <= 4 {
            return nil
        }

        return "CREATE TABLE IF NOT EXISTS \(TableQueuedTabs) (" +
                   "url TEXT NOT NULL UNIQUE, " +
                   "title TEXT" +
               ") "
    }

    func getBookmarksMirrorTableCreationString(forVersion version: Int = BrowserTable.DefaultVersion) -> String? {
        if version < 9 {
            return nil
        }

        // The stupid absence of naming conventions here is thanks to pre-Sync Weave. Sorry.
        // For now we have the simplest possible schema: everything in one.
        let sql =
        "CREATE TABLE IF NOT EXISTS \(TableBookmarksMirror) " +

        // Shared fields.
        "( id INTEGER PRIMARY KEY AUTOINCREMENT" +
        ", guid TEXT NOT NULL UNIQUE" +
        ", type TINYINT NOT NULL" +                    // Type enum. TODO: BookmarkNodeType needs to be extended.

        // Record/envelope metadata that'll allow us to do merges.
        ", server_modified INTEGER NOT NULL" +         // Milliseconds.
        ", is_deleted TINYINT NOT NULL DEFAULT 0" +    // Boolean

        ", hasDupe TINYINT NOT NULL DEFAULT 0" +       // Boolean, 0 (false) if deleted.
        ", parentid TEXT" +                            // GUID
        ", parentName TEXT" +

        // Type-specific fields. These should be NOT NULL in many cases, but we're going
        // for a sparse schema, so this'll do for now. Enforce these in the application code.
        ", feedUri TEXT, siteUri TEXT" +               // LIVEMARKS
        ", pos INT" +                                  // SEPARATORS
        ", title TEXT, description TEXT" +             // FOLDERS, BOOKMARKS, QUERIES
        ", bmkUri TEXT, tags TEXT, keyword TEXT" +     // BOOKMARKS, QUERIES
        ", folderName TEXT, queryId TEXT" +            // QUERIES
        ", CONSTRAINT parentidOrDeleted CHECK (parentid IS NOT NULL OR is_deleted = 1)" +
        ", CONSTRAINT parentNameOrDeleted CHECK (parentName IS NOT NULL OR is_deleted = 1)" +
        ")"

        return sql
    }

    /**
     * We need to explicitly store what's provided by the server, because we can't rely on
     * referenced child nodes to exist yet!
     */
    func getBookmarksMirrorStructureTableCreationString(forVersion version: Int = BrowserTable.DefaultVersion) -> String? {
        if version < 10 {
            return nil
        }

        // TODO: index me.
        let sql =
        "CREATE TABLE IF NOT EXISTS \(TableBookmarksMirrorStructure) " +
        "( parent TEXT NOT NULL REFERENCES \(TableBookmarksMirror)(guid) ON DELETE CASCADE" +
        ", child TEXT NOT NULL" +      // Should be the GUID of a child.
        ", idx INTEGER NOT NULL" +     // Should advance from 0.
        ")"

        return sql
    }

    func create(db: SQLiteDBConnection, version: Int) -> Bool {
        let favicons =
        "CREATE TABLE IF NOT EXISTS \(TableFavicons) (" +
        "id INTEGER PRIMARY KEY AUTOINCREMENT, " +
        "url TEXT NOT NULL UNIQUE, " +
        "width INTEGER, " +
        "height INTEGER, " +
        "type INTEGER NOT NULL, " +
        "date REAL NOT NULL" +
        ") "

        // Right now we don't need to track per-visit deletions: Sync can't
        // represent them! See Bug 1157553 Comment 6.
        // We flip the should_upload flag on the history item when we add a visit.
        // If we ever want to support logic like not bothering to sync if we added
        // and then rapidly removed a visit, then we need an 'is_new' flag on each visit.
        let visits =
        "CREATE TABLE IF NOT EXISTS \(TableVisits) (" +
        "id INTEGER PRIMARY KEY AUTOINCREMENT, " +
        "siteID INTEGER NOT NULL REFERENCES \(TableHistory)(id) ON DELETE CASCADE, " +
        "date REAL NOT NULL, " +           // Microseconds since epoch.
        "type INTEGER NOT NULL, " +
        "is_local TINYINT NOT NULL, " +    // Some visits are local. Some are remote ('mirrored'). This boolean flag is the split.
        "UNIQUE (siteID, date, type) " +
        ") "

        let indexShouldUpload: String
        if self.supportsPartialIndices {
            // There's no point tracking rows that are not flagged for upload.
            indexShouldUpload =
            "CREATE INDEX IF NOT EXISTS \(IndexHistoryShouldUpload) " +
            "ON \(TableHistory) (should_upload) WHERE should_upload = 1"
        } else {
            indexShouldUpload =
            "CREATE INDEX IF NOT EXISTS \(IndexHistoryShouldUpload) " +
            "ON \(TableHistory) (should_upload)"
        }

        let indexSiteIDDate =
        "CREATE INDEX IF NOT EXISTS \(IndexVisitsSiteIDIsLocalDate) " +
        "ON \(TableVisits) (siteID, is_local, date)"

        let faviconSites =
        "CREATE TABLE IF NOT EXISTS \(TableFaviconSites) (" +
        "id INTEGER PRIMARY KEY AUTOINCREMENT, " +
        "siteID INTEGER NOT NULL REFERENCES \(TableHistory)(id) ON DELETE CASCADE, " +
        "faviconID INTEGER NOT NULL REFERENCES \(TableFavicons)(id) ON DELETE CASCADE, " +
        "UNIQUE (siteID, faviconID) " +
        ") "

        let widestFavicons =
        "CREATE VIEW IF NOT EXISTS \(ViewWidestFaviconsForSites) AS " +
        "SELECT " +
        "\(TableFaviconSites).siteID AS siteID, " +
        "\(TableFavicons).id AS iconID, " +
        "\(TableFavicons).url AS iconURL, " +
        "\(TableFavicons).date AS iconDate, " +
        "\(TableFavicons).type AS iconType, " +
        "MAX(\(TableFavicons).width) AS iconWidth " +
        "FROM \(TableFaviconSites), \(TableFavicons) WHERE " +
        "\(TableFaviconSites).faviconID = \(TableFavicons).id " +
        "GROUP BY siteID "

        let historyIDsWithIcon =
        "CREATE VIEW IF NOT EXISTS \(ViewHistoryIDsWithWidestFavicons) AS " +
        "SELECT \(TableHistory).id AS id, " +
        "iconID, iconURL, iconDate, iconType, iconWidth " +
        "FROM \(TableHistory) " +
        "LEFT OUTER JOIN " +
        "\(ViewWidestFaviconsForSites) ON history.id = \(ViewWidestFaviconsForSites).siteID "

        let iconForURL =
        "CREATE VIEW IF NOT EXISTS \(ViewIconForURL) AS " +
        "SELECT history.url AS url, icons.iconID AS iconID FROM " +
        "\(TableHistory), \(ViewWidestFaviconsForSites) AS icons WHERE " +
        "\(TableHistory).id = icons.siteID "

        let bookmarks =
        "CREATE TABLE IF NOT EXISTS \(TableBookmarks) (" +
        "id INTEGER PRIMARY KEY AUTOINCREMENT, " +
        "guid TEXT NOT NULL UNIQUE, " +
        "type TINYINT NOT NULL, " +
        "url TEXT, " +
        "parent INTEGER REFERENCES \(TableBookmarks)(id) NOT NULL, " +
        "faviconID INTEGER REFERENCES \(TableFavicons)(id) ON DELETE SET NULL, " +
        "title TEXT" +
        ") "

        let bookmarksMirror = getBookmarksMirrorTableCreationString()
        let bookmarksMirrorStructure = getBookmarksMirrorStructureTableCreationString()

        let indexStructureParentIdx = "CREATE INDEX IF NOT EXISTS \(IndexBookmarksMirrorStructureParentIdx) " +
            "ON \(TableBookmarksMirrorStructure) (parent, idx)"

        let queries: [(String?, Args?)] = [
            (getDomainsTableCreationString(forVersion: version), nil),
            (getHistoryTableCreationString(forVersion: version), nil),
            (favicons, nil),
            (visits, nil),
            (bookmarks, nil),
            (bookmarksMirror, nil),
            (bookmarksMirrorStructure, nil),
            (indexStructureParentIdx, nil),
            (faviconSites, nil),
            (indexShouldUpload, nil),
            (indexSiteIDDate, nil),
            (widestFavicons, nil),
            (historyIDsWithIcon, nil),
            (iconForURL, nil),
            (getQueueTableCreationString(forVersion: version), nil)
        ]

        assert(queries.count == AllTablesIndicesAndViews.count, "Did you forget to add your table, index, or view to the list?")

        log.debug("Creating \(queries.count) tables, views, and indices.")

        return self.runValidQueries(db, queries: queries) &&
               self.prepopulateRootFolders(db)
    }

    func updateTable(db: SQLiteDBConnection, from: Int, to: Int) -> Bool {
        if from == to {
            log.debug("Skipping update from \(from) to \(to).")
            return true
        }

        if from == 0 {
            // This is likely an upgrade from before Bug 1160399.
            log.debug("Updating browser tables from zero. Assuming drop and recreate.")
            return drop(db) && create(db, version: to)
        }

        if from > to {
            // This is likely an upgrade from before Bug 1160399.
            log.debug("Downgrading browser tables. Assuming drop and recreate.")
            return drop(db) && create(db, version: to)
        }

        if from < 4 && to >= 4 {
            return drop(db) && create(db, version: to)
        }

        if from < 5 && to >= 5  {
            let queries: [(String?, Args?)] = [(getQueueTableCreationString(forVersion: to), nil)]
            if !self.runValidQueries(db, queries: queries) {
                return false
            }
        }

        if from < 6 && to >= 6 {
            if !self.run(db, queries: [
                ("DROP INDEX IF EXISTS \(IndexVisitsSiteIDDate)", nil),
                ("CREATE INDEX IF NOT EXISTS \(IndexVisitsSiteIDIsLocalDate) ON \(TableVisits) (siteID, is_local, date)", nil)
            ]) {
                return false
            }
        }

        if from < 7 && to >= 7 {
            let queries: [(String?, Args?)] = [
                (getDomainsTableCreationString(forVersion: to), nil),
                ("ALTER TABLE \(TableHistory) ADD COLUMN domain_id INTEGER REFERENCES \(TableDomains)(id) ON DELETE CASCADE", nil)
            ]

            if !self.runValidQueries(db, queries: queries) {
                return false
            }

            let urls = db.executeQuery("SELECT DISTINCT url FROM \(TableHistory) WHERE url IS NOT NULL",
                                       factory: { $0["url"] as! String })
            if !fillDomainNamesFromCursor(urls, db: db) {
                return false
            }
        }

        if from < 8 && to == 8 {
            // Nothing to do: we're just shifting the favicon table to be owned by this class.
            return true
        }

        if from < 9 && to >= 9 {
            if !self.run(db, sql: getBookmarksMirrorTableCreationString(forVersion: to)!) {
                return false
            }
        }

        if from < 10 && to >= 10 {
            if !self.run(db, sql: getBookmarksMirrorStructureTableCreationString(forVersion: to)!) {
                return false
            }

            let indexStructureParentIdx = "CREATE INDEX IF NOT EXISTS \(IndexBookmarksMirrorStructureParentIdx) " +
                                          "ON \(TableBookmarksMirrorStructure) (parent, idx)"
            if !self.run(db, sql: indexStructureParentIdx) {
                return false
            }
        }

        return true
    }

    private func fillDomainNamesFromCursor(cursor: Cursor<String>, db: SQLiteDBConnection) -> Bool {
        if cursor.count == 0 {
            return true
        }

        // URL -> hostname, flattened to make args.
        var pairs = Args()
        pairs.reserveCapacity(cursor.count * 2)
        for url in cursor {
            if let url = url, host = url.asURL?.normalizedHost() {
                pairs.append(url)
                pairs.append(host)
            }
        }
        cursor.close()

        let tmpTable = "tmp_hostnames"
        let table = "CREATE TEMP TABLE \(tmpTable) (url TEXT NOT NULL UNIQUE, domain TEXT NOT NULL, domain_id INT)"
        if !self.run(db, sql: table, args: nil) {
            log.error("Can't create temporary table. Unable to migrate domain names. Top Sites is likely to be broken.")
            return false
        }

        // Now insert these into the temporary table. Chunk by an even number, for obvious reasons.
        let chunks = chunk(pairs, by: BrowserDB.MaxVariableNumber - (BrowserDB.MaxVariableNumber % 2))
        for chunk in chunks {
            let ins = "INSERT INTO \(tmpTable) (url, domain) VALUES " +
                      Array<String>(count: chunk.count / 2, repeatedValue: "(?, ?)").joinWithSeparator(", ")
            if !self.run(db, sql: ins, args: Array(chunk)) {
                log.error("Couldn't insert domains into temporary table. Aborting migration.")
                return false
            }
        }

        // Now make those into domains.
        let domains = "INSERT OR IGNORE INTO \(TableDomains) (domain) SELECT DISTINCT domain FROM \(tmpTable)"

        // … and fill that temporary column.
        let domainIDs = "UPDATE \(tmpTable) SET domain_id = (SELECT id FROM \(TableDomains) WHERE \(TableDomains).domain = \(tmpTable).domain)"

        // Update the history table from the temporary table.
        let updateHistory = "UPDATE \(TableHistory) SET domain_id = (SELECT domain_id FROM \(tmpTable) WHERE \(tmpTable).url = \(TableHistory).url)"

        // Clean up.
        let dropTemp = "DROP TABLE \(tmpTable)"

        // Now run these.
        if !self.run(db, queries: [(domains, nil),
                                   (domainIDs, nil),
                                   (updateHistory, nil),
                                   (dropTemp, nil)]) {
            log.error("Unable to migrate domains.")
            return false
        }

        return true
    }

    /**
     * The Table mechanism expects to be able to check if a 'table' exists. In our (ab)use
     * of Table, that means making sure that any of our tables and views exist.
     * We do that by fetching all tables from sqlite_master with matching names, and verifying
     * that we get back more than one.
     * Note that we don't check for views -- trust to luck.
     */
    func exists(db: SQLiteDBConnection) -> Bool {
        return db.tablesExist(AllTables)
    }

    func drop(db: SQLiteDBConnection) -> Bool {
        log.debug("Dropping all browser tables.")
        let additional: [(String, Args?)] = [
            ("DROP TABLE IF EXISTS faviconSites", nil) // We renamed it to match naming convention.
        ]

        let queries: [(String, Args?)] = AllViews.map { ("DROP VIEW IF EXISTS \($0!)", nil) } as [(String, Args?)] +
                      AllIndices.map { ("DROP INDEX IF EXISTS \($0!)", nil) } as [(String, Args?)] +
                      AllTables.map { ("DROP TABLE IF EXISTS \($0!)", nil) } as [(String, Args?)] +
                      additional

        return self.run(db, queries: queries)
    }
}