/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Foundation
import Shared
import WebKit

// A base protocol for something that can be cleared.
protocol Clearable {
    func clear() -> Success
    var label: String { get }
}

class ClearableError: MaybeErrorType {
    private let msg: String
    init(msg: String) {
        self.msg = msg
    }

    var description: String { return msg }
}

// Clears our browsing history, including favicons and thumbnails.
class HistoryClearable: Clearable {
    let profile: Profile
    init(profile: Profile) {
        self.profile = profile
    }

    var label: String {
        return NSLocalizedString("Browsing History", tableName: "ClearPrivateData", comment: "Settings item for clearing browsing history")
    }

    func clear() -> Success {
        return profile.history.clearHistory().bind { success in
            SDImageCache.sharedImageCache().clearDisk()
            SDImageCache.sharedImageCache().clearMemory()
            NSNotificationCenter.defaultCenter().postNotificationName(NotificationPrivateDataClearedHistory, object: nil)
            return Deferred(value: success)
        }
    }
}

// Clear all stored passwords. This will clear both Firefox's SQLite storage and the system shared
// Credential storage.
class PasswordsClearable: Clearable {
    let profile: Profile
    init(profile: Profile) {
        self.profile = profile
    }

    var label: String {
        return NSLocalizedString("Saved Logins", tableName: "ClearPrivateData", comment: "Settings item for clearing passwords and login data")
    }

    func clear() -> Success {
        // Clear our storage
        return profile.logins.removeAll() >>== { res in
            let storage = NSURLCredentialStorage.sharedCredentialStorage()
            let credentials = storage.allCredentials
            for (space, credentials) in credentials {
                for (_, credential) in credentials {
                    storage.removeCredential(credential, forProtectionSpace: space)
                }
            }
            return succeed()
        }
    }
}

struct ClearableErrorType: MaybeErrorType {
    let err: ErrorType

    init(err: ErrorType) {
        self.err = err
    }

    var description: String {
        return "Couldn't clear: \(err)."
    }
}

// Clear the web cache. Note, this has to close all open tabs in order to ensure the data
// cached in them isn't flushed to disk.
class CacheClearable: Clearable {
    let tabManager: TabManager
    init(tabManager: TabManager) {
        self.tabManager = tabManager
    }

    var label: String {
        return NSLocalizedString("Cache", tableName: "ClearPrivateData", comment: "Settings item for clearing the cache")
    }

    func clear() -> Success {
        if #available(iOS 9.0, *) {
            let dataTypes = Set([WKWebsiteDataTypeDiskCache, WKWebsiteDataTypeMemoryCache])
            WKWebsiteDataStore.defaultDataStore().removeDataOfTypes(dataTypes, modifiedSince: NSDate.distantPast(), completionHandler: {})
        } else {
            // First ensure we close all open tabs first.
            tabManager.removeAll()

            // Reset the process pool to ensure no cached data is written back
            tabManager.resetProcessPool()

            // Remove the basic cache.
            NSURLCache.sharedURLCache().removeAllCachedResponses()

            // Now let's finish up by destroying our Cache directory.
            do {
                try deleteLibraryFolderContents("Caches")
            } catch {
                return deferMaybe(ClearableErrorType(err: error))
            }
        }

        return succeed()
    }
}

private func deleteLibraryFolderContents(folder: String) throws {
    let manager = NSFileManager.defaultManager()
    let library = manager.URLsForDirectory(NSSearchPathDirectory.LibraryDirectory, inDomains: .UserDomainMask)[0]
    let dir = library.URLByAppendingPathComponent(folder)
    let contents = try manager.contentsOfDirectoryAtPath(dir.path!)
    for content in contents {
        try manager.removeItemAtURL(dir.URLByAppendingPathComponent(content))
    }
}

private func deleteLibraryFolder(folder: String) throws {
    let manager = NSFileManager.defaultManager()
    let library = manager.URLsForDirectory(NSSearchPathDirectory.LibraryDirectory, inDomains: .UserDomainMask)[0]
    let dir = library.URLByAppendingPathComponent(folder)
    try manager.removeItemAtURL(dir)
}

// Removes all app cache storage.
class SiteDataClearable: Clearable {
    let tabManager: TabManager
    init(tabManager: TabManager) {
        self.tabManager = tabManager
    }

    var label: String {
        return NSLocalizedString("Offline Website Data", tableName: "ClearPrivateData", comment: "Settings item for clearing website data")
    }

    func clear() -> Success {
        if #available(iOS 9.0, *) {
            let dataTypes = Set([WKWebsiteDataTypeOfflineWebApplicationCache])
            WKWebsiteDataStore.defaultDataStore().removeDataOfTypes(dataTypes, modifiedSince: NSDate.distantPast(), completionHandler: {})
        } else {
            // First, close all tabs to make sure they don't hold anything in memory.
            tabManager.removeAll()

            // Then we just wipe the WebKit directory from our Library.
            do {
                try deleteLibraryFolder("WebKit")
            } catch {
                return deferMaybe(ClearableErrorType(err: error))
            }
        }

        return succeed()
    }
}

// Remove all cookies stored by the site. This includes localStorage, sessionStorage, and WebSQL/IndexedDB.
class CookiesClearable: Clearable {
    let tabManager: TabManager
    init(tabManager: TabManager) {
        self.tabManager = tabManager
    }

    var label: String {
        return NSLocalizedString("Cookies", tableName: "ClearPrivateData", comment: "Settings item for clearing cookies")
    }

    func clear() -> Success {
        if #available(iOS 9.0, *) {
            let dataTypes = Set([WKWebsiteDataTypeCookies, WKWebsiteDataTypeLocalStorage, WKWebsiteDataTypeSessionStorage, WKWebsiteDataTypeWebSQLDatabases, WKWebsiteDataTypeIndexedDBDatabases])
            WKWebsiteDataStore.defaultDataStore().removeDataOfTypes(dataTypes, modifiedSince: NSDate.distantPast(), completionHandler: {})
        } else {
            // First close all tabs to make sure they aren't holding anything in memory.
            tabManager.removeAll()

            // Now we wipe the system cookie store (for our app).
            let storage = NSHTTPCookieStorage.sharedHTTPCookieStorage()
            if let cookies = storage.cookies {
                for cookie in cookies {
                    storage.deleteCookie(cookie)
                }
            }

            // And just to be safe, we also wipe the Cookies directory.
            do {
                try deleteLibraryFolderContents("Cookies")
            } catch {
                return deferMaybe(ClearableErrorType(err: error))
            }
        }

        return succeed()
    }
}