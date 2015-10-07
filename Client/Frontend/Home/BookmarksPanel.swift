/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import UIKit
import Storage
import Shared
import XCGLogger

private let log = Logger.browserLogger

let BookmarkStatusChangedNotification = "BookmarkStatusChangedNotification"

struct BookmarksPanelUX {
    private static let BookmarkFolderHeaderViewChevronInset: CGFloat = 10
    private static let BookmarkFolderChevronSize: CGFloat = 20
    private static let BookmarkFolderChevronLineWidth: CGFloat = 4.0
}

class BookmarksPanel: SiteTableViewController, HomePanel {
    weak var homePanelDelegate: HomePanelDelegate? = nil
    var source: BookmarksModel?
    var parentFolders = [BookmarksModel]()

    private let BookmarkFolderCellIdentifier = "BookmarkFolderIdentifier"
    private let BookmarkFolderHeaderViewIdentifier = "BookmarkFolderHeaderIdentifier"

    private lazy var defaultIcon: UIImage = {
        return UIImage(named: "defaultFavicon")!
    }()

    override var profile: Profile! {
        didSet {
            // Get all the bookmarks split by folders
             profile.bookmarks.modelForFolder(BookmarkRoots.MobileFolderGUID).upon(onModelFetched)
        }
    }

    init() {
        super.init(nibName: nil, bundle: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "notificationReceived:", name: NotificationFirefoxAccountChanged, object: nil)

        self.tableView.registerClass(BookmarkFolderTableViewCell.self, forCellReuseIdentifier: BookmarkFolderCellIdentifier)
        self.tableView.registerClass(BookmarkFolderTableViewHeader.self, forHeaderFooterViewReuseIdentifier: BookmarkFolderHeaderViewIdentifier)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self, name: NotificationFirefoxAccountChanged, object: nil)
    }

    func notificationReceived(notification: NSNotification) {
        switch notification.name {
        case NotificationFirefoxAccountChanged:
            self.reloadData()
            break
        default:
            // no need to do anything at all
            log.warning("Received unexpected notification \(notification.name)")
            break
        }
    }

    private func onModelFetched(result: Maybe<BookmarksModel>) {
        guard let model = result.successValue else {
            self.onModelFailure(result.failureValue)
            return
        }
        self.onNewModel(model)
    }

    private func onNewModel(model: BookmarksModel) {
        self.source = model
        dispatch_async(dispatch_get_main_queue()) {
            self.tableView.reloadData()
        }
    }

    private func onModelFailure(e: Any) {
        print("Error: failed to get data: \(e)")
    }

    override func reloadData() {
        self.source?.reloadData().upon(onModelFetched)
    }

    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return source?.current.count ?? 0
    }

    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        guard let source = source, bookmark = source.current[indexPath.row] else { return super.tableView(tableView, cellForRowAtIndexPath: indexPath) }
        let cell: UITableViewCell
        if let _ = bookmark as? BookmarkFolder {
            cell = tableView.dequeueReusableCellWithIdentifier(BookmarkFolderCellIdentifier, forIndexPath: indexPath)
        } else {
            cell = super.tableView(tableView, cellForRowAtIndexPath: indexPath)
            if let url = bookmark.favicon?.url.asURL where url.scheme == "asset" {
                cell.imageView?.image = UIImage(named: url.host!)
            } else {
                cell.imageView?.setIcon(bookmark.favicon, withPlaceholder: self.defaultIcon)
            }
        }

        switch (bookmark) {
            case let item as BookmarkItem:
                if item.title.isEmpty {
                    cell.textLabel?.text = item.url
                } else {
                    cell.textLabel?.text = item.title
                }
            default:
                // Bookmark folders don't have a good fallback if there's no title. :(
                cell.textLabel?.text = bookmark.title
        }

        return cell
    }

    override func tableView(tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        // Don't show a header for the root
        if source == nil || parentFolders.isEmpty {
            return nil
        }
        guard let header = tableView.dequeueReusableHeaderFooterViewWithIdentifier(BookmarkFolderHeaderViewIdentifier) as? BookmarkFolderTableViewHeader else { return nil }

        // register as delegate to ensure we get notified when the user interacts with this header
        if header.delegate == nil {
            header.delegate = self
        }

        if let parentFolder = parentFolders.last {
            if parentFolders.count == 1 {
                header.textLabel?.text = NSLocalizedString("Bookmarks", comment: "Panel accessibility label")
            } else {
                header.textLabel?.text = parentFolder.current.title
            }
        }

        return header
    }

    override func tableView(tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        // Don't show a header for the root. If there's no root (i.e. source == nil), we'll also show no header.
        if source == nil || parentFolders.isEmpty {
            return 0
        }

        return SiteTableViewControllerUX.RowHeight
    }

    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        tableView.deselectRowAtIndexPath(indexPath, animated: false)
        if let source = source {
            let bookmark = source.current[indexPath.row]

            switch (bookmark) {
            case let item as BookmarkItem:
                homePanelDelegate?.homePanel(self, didSelectURL: NSURL(string: item.url)!, visitType: VisitType.Bookmark)
                break

            case let folder as BookmarkFolder:
                parentFolders.append(source)
                // Descend into the folder.
                source.selectFolder(folder).upon(onModelFetched)
                break

            default:
                // Weird.
                break        // Just here until there's another executable statement (compiler requires one).
            }
        }
    }

    func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
        // Intentionally blank. Required to use UITableViewRowActions
    }

    func tableView(tableView: UITableView, editingStyleForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCellEditingStyle {
        if source == nil {
            return .None
        }

        if source!.current.itemIsEditableAtIndex(indexPath.row) ?? false {
            return .Delete
        }

        return .None
    }

    func tableView(tableView: UITableView, editActionsForRowAtIndexPath indexPath: NSIndexPath) -> [AnyObject]? {
        if source == nil {
            return [AnyObject]()
        }

        let title = NSLocalizedString("Delete", tableName: "BookmarkPanel", comment: "Action button for deleting bookmarks in the bookmarks panel.")

        let delete = UITableViewRowAction(style: UITableViewRowActionStyle.Default, title: title, handler: { (action, indexPath) in
            if let bookmark = self.source?.current[indexPath.row] {
                // Why the dispatches? Because we call success and failure on the DB
                // queue, and so calling anything else that calls through to the DB will
                // deadlock. This problem will go away when the bookmarks API switches to
                // Deferred instead of using callbacks.
                // TODO: it's now time for this.
                self.profile.bookmarks.remove(bookmark).uponQueue(dispatch_get_main_queue()) { res in
                    if let err = res.failureValue {
                        self.onModelFailure(err)
                        return
                    }

                    dispatch_async(dispatch_get_main_queue()) {
                        self.source?.reloadData().upon {
                            guard let model = $0.successValue else {
                                self.onModelFailure($0.failureValue)
                                return
                            }
                            dispatch_async(dispatch_get_main_queue()) {
                                tableView.beginUpdates()
                                self.tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: UITableViewRowAnimation.Left)
                                self.source = model

                                tableView.endUpdates()

                                NSNotificationCenter.defaultCenter().postNotificationName(BookmarkStatusChangedNotification, object: bookmark, userInfo:["added":false])
                            }
                        }
                    }
                }
            }
        })

        return [delete]
    }
}

private protocol BookmarkFolderTableViewHeaderDelegate {
    func didSelectHeader()
}

extension BookmarksPanel: BookmarkFolderTableViewHeaderDelegate {
    private func didSelectHeader() {
        guard let parentFolder = parentFolders.popLast() else {
            return
        }

        self.onNewModel(parentFolder)
    }
}

class BookmarkFolderTableViewCell: UITableViewCell {
    let topBorder = UIView()
    let bottomBorder = UIView()

    override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        textLabel?.tintColor = SiteTableViewControllerUX.HeaderTextColor
        textLabel?.font = UIConstants.DefaultStandardFontBold
        imageView?.image = UIImage(named: "bookmarkFolder")
        let chevron = ChevronView(direction: .Right)
        chevron.tintColor = SiteTableViewControllerUX.HeaderTextColor
        chevron.frame = CGRectMake(0, 0, BookmarksPanelUX.BookmarkFolderChevronSize, BookmarksPanelUX.BookmarkFolderChevronSize)
        chevron.lineWidth = BookmarksPanelUX.BookmarkFolderChevronLineWidth
        accessoryView = chevron

        separatorInset = UIEdgeInsetsMake(0, 0, 0, 0)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private class BookmarkFolderTableViewHeader : SiteTableViewHeader {
    var delegate: BookmarkFolderTableViewHeaderDelegate?

    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)
        textLabel?.textColor = UIConstants.HighlightBlue
        let chevron = ChevronView(direction: .Left)
        chevron.tintColor = UIConstants.HighlightBlue
        chevron.frame = CGRectMake(BookmarksPanelUX.BookmarkFolderHeaderViewChevronInset, (SiteTableViewControllerUX.RowHeight / 2) - BookmarksPanelUX.BookmarkFolderHeaderViewChevronInset, BookmarksPanelUX.BookmarkFolderChevronSize, BookmarksPanelUX.BookmarkFolderChevronSize)
        chevron.lineWidth = BookmarksPanelUX.BookmarkFolderChevronLineWidth
        addSubview(chevron)

        userInteractionEnabled = true

        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: "viewWasTapped:")
        tapGestureRecognizer.numberOfTapsRequired = 1
        addGestureRecognizer(tapGestureRecognizer)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private override func layoutSubviews() {
        super.layoutSubviews()

        if var textLabelFrame = textLabel?.frame {
            textLabelFrame.origin.x += (BookmarksPanelUX.BookmarkFolderChevronSize + BookmarksPanelUX.BookmarkFolderHeaderViewChevronInset)
            textLabel?.frame = textLabelFrame
        }
    }

    @objc private func viewWasTapped(gestureRecognizer: UITapGestureRecognizer) {
        delegate?.didSelectHeader()
    }
}
