/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import UIKit
import Shared

struct ThumbnailCellUX {
    /// Ratio of width:height of the thumbnail image.
    static let ImageAspectRatio: Float = 1.0
    static let TextSize = UIConstants.DefaultSmallFontSize
    static let BorderColor = UIColor.blackColor().colorWithAlphaComponent(0.1)
    static let BorderWidth: CGFloat = 1
    static let LabelFont = UIConstants.DefaultSmallFont
    static let LabelColor = UIAccessibilityDarkerSystemColorsEnabled() ? UIColor.blackColor() : UIColor(rgb: 0x353535)
    static let LabelBackgroundColor = UIColor(white: 1.0, alpha: 0.5)
    static let LabelAlignment: NSTextAlignment = .Center
    static let InsetSize: CGFloat = 20
    static let InsetSizeCompact: CGFloat = 6
    static var Insets: UIEdgeInsets {
        let inset: CGFloat = (UIScreen.mainScreen().traitCollection.horizontalSizeClass == .Compact) ? ThumbnailCellUX.InsetSizeCompact : ThumbnailCellUX.InsetSize
        return UIEdgeInsets(top: inset, left: inset, bottom: inset, right: inset)
    }
    static let ImagePadding: CGFloat = 20
    static let ImagePaddingCompact: CGFloat = 10
    static let LabelInsets = UIEdgeInsetsMake(10, 3, 10, 3)
    static let PlaceholderImage = UIImage(named: "defaultTopSiteIcon")
    static let CornerRadius: CGFloat = 3

    // Make the remove button look 20x20 in size but have the clickable area be 44x44
    static let RemoveButtonSize: CGFloat = 44
    static let RemoveButtonInsets = UIEdgeInsets(top: 11, left: 11, bottom: 11, right: 11)
    static let RemoveButtonAnimationDuration: NSTimeInterval = 0.4
    static let RemoveButtonAnimationDamping: CGFloat = 0.6

    static let NearestNeighbordScalingThreshold: CGFloat = 24
}

@objc protocol ThumbnailCellDelegate {
    func didRemoveThumbnail(thumbnailCell: ThumbnailCell)
    func didLongPressThumbnail(thumbnailCell: ThumbnailCell)
}

class ThumbnailCell: UICollectionViewCell {
    weak var delegate: ThumbnailCellDelegate?

    var imagePadding: CGFloat = 0 {
        didSet {
            imageView.snp_remakeConstraints { make in
                let insets = UIEdgeInsets(top: imagePadding, left: imagePadding, bottom: imagePadding, right: imagePadding)
                make.top.equalTo(self.imageWrapper).inset(insets.top)
                make.left.equalTo(self.imageWrapper).inset(insets.left)
                make.right.equalTo(self.imageWrapper).inset(insets.right)
                make.bottom.equalTo(textWrapper.snp_top).offset(-imagePadding)
            }
            imageView.setNeedsUpdateConstraints()
        }
    }

    var image: UIImage? = nil {
        didSet {
            if let image = image {
                imageView.image = image
                imageView.contentMode = UIViewContentMode.ScaleAspectFit

                // Force nearest neighbor scaling for small favicons
                if image.size.width < ThumbnailCellUX.NearestNeighbordScalingThreshold {
                    imageView.layer.shouldRasterize = true
                    imageView.layer.rasterizationScale = 2
                    imageView.layer.minificationFilter = kCAFilterNearest
                    imageView.layer.magnificationFilter = kCAFilterNearest
                }

            } else {
                imageView.image = ThumbnailCellUX.PlaceholderImage
                imageView.contentMode = UIViewContentMode.Center
            }
        }
    }

    lazy var longPressGesture: UILongPressGestureRecognizer = {
        return UILongPressGestureRecognizer(target: self, action: "SELdidLongPress")
    }()

    lazy var textWrapper: UIView = {
        let wrapper = UIView()
        wrapper.backgroundColor = ThumbnailCellUX.LabelBackgroundColor
        return wrapper
    }()

    lazy var textLabel: UILabel = {
        let textLabel = UILabel()
        textLabel.setContentHuggingPriority(1000, forAxis: UILayoutConstraintAxis.Vertical)
        textLabel.font = ThumbnailCellUX.LabelFont
        textLabel.textColor = ThumbnailCellUX.LabelColor
        textLabel.textAlignment = ThumbnailCellUX.LabelAlignment
        return textLabel
    }()

    lazy var imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = UIViewContentMode.ScaleAspectFit

        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = ThumbnailCellUX.CornerRadius
        return imageView
    }()

    lazy var backgroundImage: UIImageView = {
        let backgroundImage = UIImageView()
        backgroundImage.contentMode = UIViewContentMode.ScaleAspectFill
        return backgroundImage
    }()

    lazy var backgroundEffect: UIVisualEffectView? = {
        let blur = UIBlurEffect(style: UIBlurEffectStyle.Light)
        let vib = UIVibrancyEffect(forBlurEffect: blur)
        return DeviceInfo.isBlurSupported() ? UIVisualEffectView(effect: blur) : nil
    }()

    lazy var imageWrapper: UIView = {
        let imageWrapper = UIView()
        imageWrapper.layer.borderColor = ThumbnailCellUX.BorderColor.CGColor
        imageWrapper.layer.borderWidth = ThumbnailCellUX.BorderWidth
        imageWrapper.layer.cornerRadius = ThumbnailCellUX.CornerRadius
        imageWrapper.clipsToBounds = true
        return imageWrapper
    }()

    lazy var removeButton: UIButton = {
        let removeButton = UIButton()
        removeButton.setImage(UIImage(named: "TileCloseButton"), forState: UIControlState.Normal)
        removeButton.addTarget(self, action: "SELdidRemove", forControlEvents: UIControlEvents.TouchUpInside)
        removeButton.accessibilityLabel = NSLocalizedString("Remove page", comment: "Button shown in editing mode to remove this site from the top sites panel.")
        removeButton.hidden = true
        removeButton.imageEdgeInsets = ThumbnailCellUX.RemoveButtonInsets
        return removeButton
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)

        isAccessibilityElement = true
        addGestureRecognizer(longPressGesture)

        contentView.addSubview(imageWrapper)
        if let backgroundEffect = backgroundEffect {
            imageWrapper.addSubview(backgroundImage)
            imageWrapper.addSubview(backgroundEffect)
            backgroundImage.snp_remakeConstraints { make in
                make.top.bottom.left.right.equalTo(self.imageWrapper)
            }

        }
        imageWrapper.addSubview(imageView)
        imageWrapper.addSubview(textWrapper)
        textWrapper.addSubview(textLabel)
        contentView.addSubview(removeButton)

        imageWrapper.snp_remakeConstraints { make in
            make.top.equalTo(self.contentView).inset(ThumbnailCellUX.Insets.top)
            make.left.equalTo(self.contentView).inset(ThumbnailCellUX.Insets.left)
            make.bottom.equalTo(self.contentView).inset(ThumbnailCellUX.Insets.bottom)
            make.right.equalTo(self.contentView).inset(ThumbnailCellUX.Insets.right)
        }

        backgroundEffect?.snp_remakeConstraints { make in
            make.top.bottom.left.right.equalTo(self.imageWrapper)
        }

        imageView.snp_remakeConstraints { make in
            let imagePadding: CGFloat = (UIScreen.mainScreen().traitCollection.horizontalSizeClass == .Compact) ? ThumbnailCellUX.ImagePaddingCompact : ThumbnailCellUX.ImagePadding
            let insets = UIEdgeInsetsMake(imagePadding, imagePadding, imagePadding, imagePadding)
            make.top.equalTo(self.imageWrapper).inset(insets.top)
            make.left.right.equalTo(self.imageWrapper).inset(insets.left)
            make.right.equalTo(self.imageWrapper).inset(insets.right)
            make.bottom.equalTo(textWrapper.snp_top).offset(-imagePadding) // .insets(insets)
        }

        textWrapper.snp_makeConstraints { make in
            make.bottom.equalTo(self.imageWrapper.snp_bottom) // .offset(ThumbnailCellUX.BorderWidth)
            make.left.right.equalTo(self.imageWrapper) // .offset(ThumbnailCellUX.BorderWidth)
        }

        textLabel.snp_remakeConstraints { make in
            make.edges.equalTo(self.textWrapper).inset(ThumbnailCellUX.LabelInsets) // TODO swift-2.0 I changes insets to inset - how can that be right?
        }
        
        // Prevents the textLabel from getting squished in relation to other view priorities.
        textLabel.setContentCompressionResistancePriority(1000, forAxis: UILayoutConstraintAxis.Vertical)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        // TODO: We can avoid creating this button at all if we're not in editing mode.
        var frame = removeButton.frame
        let insets = ThumbnailCellUX.Insets
        frame.size = CGSize(width: ThumbnailCellUX.RemoveButtonSize, height: ThumbnailCellUX.RemoveButtonSize)
        frame.center = CGPoint(x: insets.left, y: insets.top)
        removeButton.frame = frame
    }

    func SELdidRemove() {
        delegate?.didRemoveThumbnail(self)
    }

    func SELdidLongPress() {
        delegate?.didLongPressThumbnail(self)
    }

    func toggleRemoveButton(show: Bool) {
        // Only toggle if we change state
        if removeButton.hidden != show {
            return
        }

        if show {
            removeButton.hidden = false
        }

        let scaleTransform = CGAffineTransformMakeScale(0.01, 0.01)
        removeButton.transform = show ? scaleTransform : CGAffineTransformIdentity
        UIView.animateWithDuration(ThumbnailCellUX.RemoveButtonAnimationDuration,
            delay: 0,
            usingSpringWithDamping: ThumbnailCellUX.RemoveButtonAnimationDamping,
            initialSpringVelocity: 0,
            options: [UIViewAnimationOptions.AllowUserInteraction, UIViewAnimationOptions.CurveEaseInOut],
            animations: {
                self.removeButton.transform = show ? CGAffineTransformIdentity : scaleTransform
            }, completion: { _ in
                if !show {
                    self.removeButton.hidden = true
                }
            })
    }
}
