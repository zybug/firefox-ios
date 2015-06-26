/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Foundation

protocol Panels {
    typealias OptionsCallback = (String) -> Void

    func register(id: String, callback: String)
    func unregister(id: String)
    func install(id: String)
    func uninstall(id: String)
    func update(id: String)
    func setAuthenticated(id: String, isAuthenticated: Bool)
}

protocol PanelViewOptions {
    var type: PanelViewType { get }
    var dataset: String { get }
    var backImageUrl: String { get }
    var itemType: PanelItemType? { get }
    var itemHandler: PanelItemHandlerType? { get }
    var empty: AnyObject? { get }
    var onrefresh: String? { get }
}

protocol PanelOptions {
    var title: String { get }
    var layout: PanelLayout? { get }
    var views: [PanelViewOptions] { get }
    var oninstall: String { get }
    var onuninstall: String { get }
}

enum PanelLayout {
    case Frame
}

enum PanelViewType {
    case List
//    case Grid
}

enum PanelItemType: String {
    case Article = "Article"
    case Image = "Image"
}

enum PanelItemHandlerType {
    case Browser
}
