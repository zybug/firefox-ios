/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Foundation
import Shared

public struct UIConstants {
    static let DefaultHomePage = NSURL(string: "\(WebServer.sharedInstance.base)/about/home/#panel=0")!

    static let AppBackgroundColor = UIColor.blackColor()
    static let PrivateModePurple = UIColor(red: 207 / 255, green: 104 / 255, blue: 255 / 255, alpha: 1)
    static let PrivateModeLocationBackgroundColor = UIColor(red: 31 / 255, green: 31 / 255, blue: 31 / 255, alpha: 1)
    static let PrivateModeLocationBorderColor = UIColor(red: 255, green: 255, blue: 255, alpha: 0.15)
    static let PrivateModeActionButtonTintColor = UIColor(red: 255, green: 255, blue: 255, alpha: 0.8)
    static let PrivateModeTextHighlightColor = UIColor(red: 120 / 255, green: 120 / 255, blue: 165 / 255, alpha: 1)

    static let ToolbarHeight: CGFloat = 44
    static let DefaultRowHeight: CGFloat = 58
    static let DefaultPadding: CGFloat = 10
    static let SnackbarButtonHeight: CGFloat = 48

    static let DeviceFontSize: CGFloat = DeviceInfo.deviceModel().rangeOfString("iPad") != nil ? 18 : 15
    static let DefaultMediumFontSize: CGFloat = 14

    static let DefaultMediumFont: UIFont = UIFont.systemFontOfSize(DefaultMediumFontSize, weight: UIFontWeightRegular)
    static let DefaultMediumBoldFont = UIFont.boldSystemFontOfSize(DefaultMediumFontSize)
    static let DefaultSmallFontSize: CGFloat = 11

    static let DefaultSmallFont = UIFont.systemFontOfSize(DefaultSmallFontSize, weight: UIFontWeightRegular)
    static let DefaultSmallFontBold = UIFont.systemFontOfSize(DefaultSmallFontSize, weight: UIFontWeightBold)

    static let DefaultStandardFontSize: CGFloat = 17
    static let DefaultStandardFontBold = UIFont.boldSystemFontOfSize(DefaultStandardFontSize)

    static let DefaultStandardFont: UIFont = UIFont.systemFontOfSize(DefaultStandardFontSize, weight: UIFontWeightRegular)

    // These highlight colors are currently only used on Snackbar buttons when they're pressed
    static let HighlightColor = UIColor(red: 205/255, green: 223/255, blue: 243/255, alpha: 0.9)
    static let HighlightText = UIColor(red: 42/255, green: 121/255, blue: 213/255, alpha: 1.0)

    static let PanelBackgroundColor = UIColor.whiteColor()
    static let SeparatorColor = UIColor(rgb: 0xcccccc)
    static let HighlightBlue = UIColor(red:0.3, green:0.62, blue:1, alpha:1)
    static let DestructiveRed = UIColor(red: 255/255, green: 64/255, blue: 0/255, alpha: 1.0)
    static let BorderColor = UIColor.blackColor().colorWithAlphaComponent(0.25)
    static let BackgroundColor = UIColor(red: 0.21, green: 0.23, blue: 0.25, alpha: 1)

    // settings
    static let TableViewHeaderBackgroundColor = UIColor(red: 242/255, green: 245/255, blue: 245/255, alpha: 1.0)
    static let TableViewHeaderTextColor = UIColor(red: 130/255, green: 135/255, blue: 153/255, alpha: 1.0)
    static let TableViewRowTextColor = UIColor(red: 53.55/255, green: 53.55/255, blue: 53.55/255, alpha: 1.0)
    static let TableViewSeparatorColor = UIColor(rgb: 0xD1D1D4)

    // Firefox Orange
    static let ControlTintColor = UIColor(red: 240.0 / 255, green: 105.0 / 255, blue: 31.0 / 255, alpha: 1)

    /// JPEG compression quality for persisted screenshots. Must be between 0-1.
    static let ScreenshotQuality: Float = 0.3
}

/// Strings that will be used for features that haven't yet landed.
private struct TempStrings {
    // Bug 1189902 - Offer crash reporting on first run after a crash
    let crashReportTitle = NSLocalizedString("Oops! Firefox crashed", comment: "Pending feature; currently unused string! Title for prompt displayed to user after the app crashes")
    let crashReportDescription = NSLocalizedString("Send a crash report so Mozilla can fix the problem?", comment: "Pending feature; currently unused string! Message displayed in the crash dialog above the buttons used to select when sending reports")
    let sendReport = NSLocalizedString("Send Report", comment: "Pending feature; currently unused string! Used as a button label for crash dialog prompt")
    let alwaysSend = NSLocalizedString("Always Send", comment: "Pending feature; currently unused string! Used as a button label for crash dialog prompt")
    let dontSend = NSLocalizedString("Don't Send", comment: "Pending feature; currently unused string! Used as a button label for crash dialog prompt")
    let neverSend = NSLocalizedString("Never Send", comment: "Pending feature; currently unused string! Used as a button label for crash dialog prompt")

    // Bug 1109675 - Request Desktop Site
    let requestDesktopSite = NSLocalizedString("Request Desktop Site", comment: "Pending feature; currently unused string! Tooltip label triggered by long pressing the refresh button.")
    let requestMobileSite = NSLocalizedString("Request Mobile Site", comment: "Pending feature; currently unused string! Tooltip label triggered by long pressing the refresh button a second time.")

    // Bug 1182303 - Checkbox to block alert spam.
    let disableAlerts = NSLocalizedString("Disable additional page dialogs", comment: "Pending feature; currently unused string! Checkbox label shown after multiple alerts are shown")

    // Bug 1186013 - Prompt for going to clipboard URL
    let goToCopiedURL = NSLocalizedString("Go to copied URL?", comment: "Pending feature; currently unused string! Prompt message shown when browser is opened with URL on the clipboard")
    let goToCopiedURLButton = NSLocalizedString("Go", comment: "Pending feature; currently unused string! Button to browse to URL on the clipboard when browser is opened")

    // Bug 1196227 - (pbmode) [Meta] Private Browsing
    let openInNewPrivateTab = NSLocalizedString("Open In New Private Tab", tableName: "PrivateBrowsing", comment: "Context menu option for opening a link in a new private tab")
}

/// Old strings that will be removed when we kill 1.0. We need to keep them around for now for l10n export.
private struct ObsoleteStrings {
    let introMultiplePages = NSLocalizedString("Browse multiple Web pages at the same time with tabs.", tableName: "Intro", comment: "See http://mzl.la/1T8gxwo")
    let introPersonalize = NSLocalizedString("Personalize your Firefox just the way you like in Settings.", tableName: "Intro", comment: "See http://mzl.la/1T8gxwo")
    let introConnect = NSLocalizedString("Connect Firefox everywhere you use it.", tableName: "Intro", comment: "See http://mzl.la/1T8gxwo")
    let settingsSearchSuggestions = NSLocalizedString("Show search suggestions", comment: "Label for show search suggestions setting.")
    let settingsSignIn = NSLocalizedString("Sign in", comment: "Text message / button in the settings table view")
}
