/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Foundation
import JavaScriptCore

class AddonEngine: NSObject {
    let jsContext = JSContext()

    

    init() {
        super.init()
        jsContext["HomeProvider"] =
    }
}

private class HomeProviderImpl: NSObject, JSExport, HomeProvider {

    func getStorage(datasetId: String) -> String {
        return ""
    }

    func requestSync(datasetId: String, callback: String) {

    }

    func addPeriodicSync(datasetId: String, callback: String) {

    }

    func removePeriodicSync(datasetId: String) {

    }
}

private class PanelsImpl: NSObject, JSExport, Panels {
    let rootObject = "panels"

    func register(id: String, callback: String) {

    }

    func unregister(id: String) {

    }

    func install(id: String) {

    }

    func uninstall(id: String) {

    }

    func update(id: String) {

    }

    func setAuthenticated(id: String, isAuthenticated: Bool) {

    }
}