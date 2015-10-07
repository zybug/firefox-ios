/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Shared
import Storage
import AVFoundation
import XCGLogger
import Breakpad

private let log = Logger.browserLogger

class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    var browserViewController: BrowserViewController!
    var rootViewController: UINavigationController!
    weak var profile: BrowserProfile?
    var tabManager: TabManager!

    let appVersion = NSBundle.mainBundle().objectForInfoDictionaryKey("CFBundleShortVersionString") as! String

    func application(application: UIApplication, willFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
        // Set the Firefox UA for browsing.
        setUserAgent()

        // Start the keyboard helper to monitor and cache keyboard state.
        KeyboardHelper.defaultHelper.startObserving()

        // Create a new sync log file on cold app launch
        Logger.syncLogger.newLogWithDate(NSDate())

        let profile = getProfile(application)

        // Set up a web server that serves us static content. Do this early so that it is ready when the UI is presented.
        setUpWebServer(profile)

        do {
            // for aural progress bar: play even with silent switch on, and do not stop audio from other apps (like music)
            try AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryPlayback, withOptions: AVAudioSessionCategoryOptions.MixWithOthers)
        } catch _ {
            log.error("Failed to assign AVAudioSession category to allow playing with silent switch on for aural progress bar")
        }

        self.window = UIWindow(frame: UIScreen.mainScreen().bounds)
        self.window!.backgroundColor = UIColor.whiteColor()

        let defaultRequest = NSURLRequest(URL: UIConstants.DefaultHomePage)
        self.tabManager = TabManager(defaultNewTabRequest: defaultRequest, profile: profile)
        browserViewController = BrowserViewController(profile: profile, tabManager: self.tabManager)

        // Add restoration class, the factory that will return the ViewController we 
        // will restore with.
        browserViewController.restorationIdentifier = NSStringFromClass(BrowserViewController.self)
        browserViewController.restorationClass = AppDelegate.self
        browserViewController.automaticallyAdjustsScrollViewInsets = false

        rootViewController = UINavigationController(rootViewController: browserViewController)
        rootViewController.automaticallyAdjustsScrollViewInsets = false
        rootViewController.delegate = self
        rootViewController.navigationBarHidden = true

        self.window!.rootViewController = rootViewController
        self.window!.backgroundColor = UIConstants.AppBackgroundColor

        activeCrashReporter = BreakpadCrashReporter(breakpadInstance: BreakpadController.sharedInstance())
        configureActiveCrashReporter(profile.prefs.boolForKey("crashreports.send.always"))

        NSNotificationCenter.defaultCenter().addObserverForName(FSReadingListAddReadingListItemNotification, object: nil, queue: nil) { (notification) -> Void in
            if let userInfo = notification.userInfo, url = userInfo["URL"] as? NSURL {
                let title = (userInfo["Title"] as? String) ?? ""
                profile.readingList?.createRecordWithURL(url.absoluteString, title: title, addedBy: UIDevice.currentDevice().name)
            }
        }

        // check to see if we started 'cos someone tapped on a notification.
        if let localNotification = launchOptions?[UIApplicationLaunchOptionsLocalNotificationKey] as? UILocalNotification {
            viewURLInNewTab(localNotification)
        }
        return true
    }

    /**
     * We maintain a weak reference to the profile so that we can pause timed
     * syncs when we're backgrounded.
     *
     * The long-lasting ref to the profile lives in BrowserViewController,
     * which we set in application:willFinishLaunchingWithOptions:.
     *
     * If that ever disappears, we won't be able to grab the profile to stop
     * syncing... but in that case the profile's deinit will take care of things.
     */
    func getProfile(application: UIApplication) -> Profile {
        if let profile = self.profile {
            return profile
        }
        let p = BrowserProfile(localName: "profile", app: application)
        self.profile = p
        return p
    }

    func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject : AnyObject]?) -> Bool {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0)) {
            AdjustIntegration.sharedInstance.triggerApplicationDidFinishLaunchingWithOptions(launchOptions)
        }
        self.window!.makeKeyAndVisible()
        return true
    }

    func application(application: UIApplication, openURL url: NSURL, sourceApplication: String?, annotation: AnyObject) -> Bool {
        if let components = NSURLComponents(URL: url, resolvingAgainstBaseURL: false) {
            if components.scheme != "firefox" && components.scheme != "firefox-x-callback" {
                return false
            }
            var url: String?
            for item in (components.queryItems ?? []) as [NSURLQueryItem] {
                switch item.name {
                case "url":
                    url = item.value
                default: ()
                }
            }
            if let url = url,
                   newURL = NSURL(string: url.unescape()) {
                self.browserViewController.openURLInNewTab(newURL)
                return true
            }
        }
        return false
    }

    // We sync in the foreground only, to avoid the possibility of runaway resource usage.
    // Eventually we'll sync in response to notifications.
    func applicationDidBecomeActive(application: UIApplication) {
        self.profile?.syncManager.applicationDidBecomeActive()

        // We could load these here, but then we have to futz with the tab counter
        // and making NSURLRequests.
        self.browserViewController.loadQueuedTabs()
    }

    func applicationDidEnterBackground(application: UIApplication) {
        self.profile?.syncManager.applicationDidEnterBackground()

        var taskId: UIBackgroundTaskIdentifier = 0
        taskId = application.beginBackgroundTaskWithExpirationHandler { _ in
            log.warning("Running out of background time, but we have a profile shutdown pending.")
            application.endBackgroundTask(taskId)
        }

        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0)) {
            self.profile?.shutdown()
            application.endBackgroundTask(taskId)
        }
    }

    private func setUpWebServer(profile: Profile) {
        let server = WebServer.sharedInstance
        ReaderModeHandlers.register(server, profile: profile)
        ErrorPageHelper.register(server)
        AboutHomeHandler.register(server)
        AboutLicenseHandler.register(server)
        SessionRestoreHandler.register(server)
        server.start()
    }

    private func setUserAgent() {
        // Note that we use defaults here that are readable from extensions, so they
        // can just used the cached identifier.
        let defaults = NSUserDefaults(suiteName: AppInfo.sharedContainerIdentifier())!
        let firefoxUA = UserAgent.defaultUserAgent(defaults)

        // Set the UA for WKWebView (via defaults), the favicon fetcher, and the image loader.
        // This only needs to be done once per runtime.

        defaults.registerDefaults(["UserAgent": firefoxUA])
        FaviconFetcher.userAgent = firefoxUA
        SDWebImageDownloader.sharedDownloader().setValue(firefoxUA, forHTTPHeaderField: "User-Agent")

        // Record the user agent for use by search suggestion clients.
        SearchViewController.userAgent = firefoxUA
    }

    func application(application: UIApplication, handleActionWithIdentifier identifier: String?, forLocalNotification notification: UILocalNotification, completionHandler: () -> Void) {
        if let actionId = identifier {
            if let action = SentTabAction(rawValue: actionId) {
                viewURLInNewTab(notification)
                switch(action) {
                case .Bookmark:
                    addBookmark(notification)
                    break
                case .ReadingList:
                    addToReadingList(notification)
                    break
                default:
                    break
                }
            } else {
                print("ERROR: Unknown notification action received")
            }
        } else {
            print("ERROR: Unknown notification received")
        }
    }

    func application(application: UIApplication, didReceiveLocalNotification notification: UILocalNotification) {
        viewURLInNewTab(notification)
    }

    private func viewURLInNewTab(notification: UILocalNotification) {
        if let alertURL = notification.userInfo?[TabSendURLKey] as? String {
            if let urlToOpen = NSURL(string: alertURL) {
                browserViewController.openURLInNewTab(urlToOpen)
            }
        }
    }

    private func addBookmark(notification: UILocalNotification) {
        if let alertURL = notification.userInfo?[TabSendURLKey] as? String,
            let title = notification.userInfo?[TabSendTitleKey] as? String {
                browserViewController.addBookmark(alertURL, title: title)
        }
    }

    private func addToReadingList(notification: UILocalNotification) {
        if let alertURL = notification.userInfo?[TabSendURLKey] as? String,
           let title = notification.userInfo?[TabSendTitleKey] as? String {
            if let urlToOpen = NSURL(string: alertURL) {
                NSNotificationCenter.defaultCenter().postNotificationName(FSReadingListAddReadingListItemNotification, object: self, userInfo: ["URL": urlToOpen, "Title": title])
            }
        }
    }
}

// MARK: - Root View Controller Animations
extension AppDelegate: UINavigationControllerDelegate {
    func navigationController(navigationController: UINavigationController,
        animationControllerForOperation operation: UINavigationControllerOperation,
        fromViewController fromVC: UIViewController,
        toViewController toVC: UIViewController) -> UIViewControllerAnimatedTransitioning? {
            if operation == UINavigationControllerOperation.Push {
                return BrowserToTrayAnimator()
            } else if operation == UINavigationControllerOperation.Pop {
                return TrayToBrowserAnimator()
            } else {
                return nil
            }
    }
}

var activeCrashReporter: CrashReporter?
func configureActiveCrashReporter(optedIn: Bool?) {
    if let reporter = activeCrashReporter {
        configureCrashReporter(reporter, optedIn: optedIn)
    }
}

public func configureCrashReporter(reporter: CrashReporter, optedIn: Bool?) {
    let configureReporter: () -> () = {
        let addUploadParameterForKey: String -> Void = { key in
            if let value = NSBundle.mainBundle().objectForInfoDictionaryKey(key) as? String {
                reporter.addUploadParameter(value, forKey: key)
            }
        }

        addUploadParameterForKey("AppID")
        addUploadParameterForKey("BuildID")
        addUploadParameterForKey("ReleaseChannel")
        addUploadParameterForKey("Vendor")
    }

    if let optedIn = optedIn {
        // User has explicitly opted-in for sending crash reports. If this is not true, then the user has
        // explicitly opted-out of crash reporting so don't bother starting breakpad or stop if it was running
        if optedIn {
            reporter.start(true)
            configureReporter()
            reporter.setUploadingEnabled(true)
        } else {
            reporter.stop()
        }
    }
    // We haven't asked the user for their crash reporting preference yet. Log crashes anyways but don't send them.
    else {
        reporter.start(true)
        configureReporter()
    }
}
