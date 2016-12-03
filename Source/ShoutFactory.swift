import UIKit

var shoutViews = [ShoutView]()

open class ShoutView: UIView {

  public struct Dimensions {
    public static let indicatorHeight: CGFloat = 6
    public static let indicatorWidth: CGFloat = 30
    public static let imageSize: CGFloat = 27
    public static let imageOffset: CGFloat = 12
    public static var height: CGFloat = UIApplication.sharedApplication().statusBarHidden ? 55 : 65
    public static var textOffset: CGFloat = 47
  }

  open fileprivate(set) lazy var backgroundView: UIView = {
    let view = UIView()
    view.backgroundColor = ColorList.Shout.background
    view.alpha = 0.98
    view.clipsToBounds = true

    return view
    }()

  open fileprivate(set) lazy var indicatorView: UIView = {
    let view = UIView()
    view.backgroundColor = ColorList.Shout.dragIndicator
    view.layer.cornerRadius = Dimensions.indicatorHeight / 2
    view.isUserInteractionEnabled = true

    return view
    }()

  open fileprivate(set) lazy var imageView: UIImageView = {
    let imageView = UIImageView()
    imageView.layer.cornerRadius = Dimensions.imageSize / 2
    imageView.clipsToBounds = true
    imageView.contentMode = .scaleAspectFill

    return imageView
    }()

  open fileprivate(set) lazy var titleLabel: UILabel = {
    let label = UILabel()
    label.font = FontList.Shout.title
    label.textColor = ColorList.Shout.title
    label.numberOfLines = 2

    return label
    }()

  open fileprivate(set) lazy var subtitleLabel: UILabel = {
    let label = UILabel()
    label.font = FontList.Shout.subtitle
    label.textColor = ColorList.Shout.subtitle
    label.numberOfLines = 2

    return label
    }()

  open fileprivate(set) lazy var tapGestureRecognizer: UITapGestureRecognizer = { [unowned self] in
    let gesture = UITapGestureRecognizer()
    gesture.addTarget(self, action: #selector(ShoutView.handleTapGestureRecognizer))

    return gesture
    }()

  open fileprivate(set) lazy var panGestureRecognizer: UIPanGestureRecognizer = { [unowned self] in
    let gesture = UIPanGestureRecognizer()
    gesture.addTarget(self, action: #selector(ShoutView.handlePanGestureRecognizer))

    return gesture
    }()

  open fileprivate(set) var announcement: Announcement?
  open fileprivate(set) var displayTimer = Timer()
  open fileprivate(set) var panGestureActive = false
  open fileprivate(set) var shouldSilent = false
  open fileprivate(set) var completion: (() -> ())?

  private var subtitleLabelOriginalHeight: CGFloat = 0
  private var internalHeight: CGFloat = 0

  // MARK: - Initializers

  public override init(frame: CGRect) {
    super.init(frame: frame)

    addSubview(backgroundView)
    [imageView, titleLabel, subtitleLabel, indicatorView].forEach {
      $0.autoresizingMask = []
      backgroundView.addSubview($0)
    }

    clipsToBounds = false
    isUserInteractionEnabled = true
    layer.shadowColor = UIColor.black.cgColor
    layer.shadowOffset = CGSize(width: 0, height: 0.5)
    layer.shadowOpacity = 0.1
    layer.shadowRadius = 0.5

    backgroundView.addGestureRecognizer(tapGestureRecognizer)
    addGestureRecognizer(panGestureRecognizer)

    NotificationCenter.default.addObserver(self, selector: #selector(ShoutView.orientationDidChange), name: NSNotification.Name.UIDeviceOrientationDidChange, object: nil)
  }

  public required init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  deinit {
    NotificationCenter.default.removeObserver(self, name: NSNotification.Name.UIDeviceOrientationDidChange, object: nil)
  }

  // MARK: - Configuration

  open func craft(_ announcement: Announcement, to: UIViewController, completion: (() -> ())?) {
    panGestureActive = false
    shouldSilent = false
    configureView(announcement)
    shout(to: to)

    self.completion = completion
  }

  open func configureView(_ announcement: Announcement) {
    self.announcement = announcement
    imageView.image = announcement.image
    titleLabel.text = announcement.title
    titleLabel.font = announcement.titleFont
    subtitleLabel.text = announcement.subtitle

    displayTimer.invalidate()
    displayTimer = Timer.scheduledTimer(timeInterval: announcement.duration,
      target: self, selector: #selector(ShoutView.displayTimerDidFire), userInfo: nil, repeats: false)

    setupFrames()
  }

  open func shout(to controller: UIViewController) {
    controller.view.addSubview(self)
    
    frame = CGRect(x: 0, y: shoutViews.last?.frame.maxY ?? 0, width: width, height: 0)
    backgroundView.frame = CGRect(x: 0, y: 0, width: width, height: 0)
    
    UIView.animateWithDuration(0.35, animations: {
        self.frame.size.height = Dimensions.height
        self.backgroundView.frame.size.height = self.frame.height
    })
  }

  // MARK: - Setup

  public func setupFrames() {
    let totalWidth = UIScreen.mainScreen().bounds.width
    let offset: CGFloat = UIApplication.sharedApplication().statusBarHidden || shoutViews.count > 0 ? 2.5 : 5
    let textOffsetX: CGFloat = imageView.image != nil ? Dimensions.textOffset : 18
    let imageSize: CGFloat = imageView.image != nil ? Dimensions.imageSize : 0
    
    [titleLabel, subtitleLabel].forEach {
        $0.frame.size.width = totalWidth - imageSize - (Dimensions.imageOffset * 2)
        $0.sizeToFit()
    }
    
    Dimensions.height += subtitleLabel.frame.height
    
    backgroundView.frame.size = CGSize(width: totalWidth, height: Dimensions.height)
    gestureContainer.frame = backgroundView.frame
    indicatorView.frame = CGRect(x: (totalWidth - Dimensions.indicatorWidth) / 2,
                                 y: Dimensions.height - Dimensions.indicatorHeight - 5, width: Dimensions.indicatorWidth, height: Dimensions.indicatorHeight)
    
    imageView.frame = CGRect(x: Dimensions.imageOffset, y: (Dimensions.height - imageSize) / 2 + offset,
                             width: imageSize, height: imageSize)
    
    let textOffsetY = imageView.image != nil ? imageView.frame.origin.x + 3 : textOffsetX + 5
    
    titleLabel.frame.origin = CGPoint(x: textOffsetX, y: textOffsetY)
    subtitleLabel.frame.origin = CGPoint(x: textOffsetX, y: titleLabel.frame.maxY + 2.5)
    
    if subtitleLabel.text?.isEmpty ?? true {
        titleLabel.center.y = imageView.center.y
    }

    frame = CGRect(x: 0, y: 0, width: totalWidth, height: internalHeight + Dimensions.touchOffset)
  }

  // MARK: - Frame

  open override var frame: CGRect {
    didSet {
      backgroundView.frame = CGRect(x: 0, y: 0,
                                    width: frame.size.width,
                                    height: frame.size.height - Dimensions.touchOffset)

      indicatorView.frame = CGRect(x: (backgroundView.frame.size.width - Dimensions.indicatorWidth) / 2,
                                   y: backgroundView.frame.height - Dimensions.indicatorHeight - 5,
                                   width: Dimensions.indicatorWidth,
                                   height: Dimensions.indicatorHeight)
    }
  }

  // MARK: - Actions

  public func silent() {
    func getSelfIndex() -> Int {
        var selfIndex = 0
        for (index, v) in shoutViews.enumerate() {
            if v == self {
                selfIndex = index
            }
        }
        
        return selfIndex
    }
    
    UIView.animateWithDuration(0.35, animations: {
        for (index, v) in shoutViews.enumerate() {
            if index > getSelfIndex() {
                v.frame.origin.y -= self.frame.size.height
            }
        }
        self.frame.size.height = 0
        self.backgroundView.frame.size.height = self.frame.height
    }, completion: { finished in
        self.completion?()
        self.displayTimer.invalidate()
        self.removeFromSuperview()
        shoutViews.removeAtIndex(getSelfIndex())
    })
  }

  // MARK: - Timer methods

  open func displayTimerDidFire() {
    shouldSilent = true

    if panGestureActive { return }
    silent()
  }

  // MARK: - Gesture methods

  @objc fileprivate func handleTapGestureRecognizer() {
    guard let announcement = announcement else { return }
    announcement.action?()
    silent()
  }
  
  @objc private func handlePanGestureRecognizer() {
    let translation = panGestureRecognizer.translation(in: self)

    if panGestureRecognizer.state == .began {
      subtitleLabelOriginalHeight = subtitleLabel.bounds.size.height
      subtitleLabel.numberOfLines = 0
      subtitleLabel.sizeToFit()
    } else if panGestureRecognizer.state == .changed {
      panGestureActive = true
      
      let maxTranslation = subtitleLabel.bounds.size.height - subtitleLabelOriginalHeight
      
      if translation.y >= maxTranslation {
        frame.size.height = internalHeight + maxTranslation
          + (translation.y - maxTranslation) / 25 + Dimensions.touchOffset
      } else {
        frame.size.height = internalHeight + translation.y + Dimensions.touchOffset
      }
    } else {
      panGestureActive = false
      let height = translation.y < -5 || shouldSilent ? 0 : internalHeight

      subtitleLabel.numberOfLines = 2
      subtitleLabel.sizeToFit()
      
      UIView.animate(withDuration: 0.2, animations: {
        self.frame.size.height = height + Dimensions.touchOffset
      }, completion: { _ in
          if translation.y < -5 {
            self.completion?()
            self.removeFromSuperview()
        }
      })
    }
  }


  // MARK: - Handling screen orientation

  func orientationDidChange() {
    setupFrames()
  }
}
