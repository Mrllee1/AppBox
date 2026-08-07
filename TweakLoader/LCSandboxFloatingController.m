@import UIKit;
#import <objc/message.h>

#import "LCSandboxFloatingController.h"
#import "utils.h"

typedef NS_ENUM(NSInteger, LCSandboxFloatingState) {
    LCSandboxFloatingStateResting,
    LCSandboxFloatingStatePressed,
    LCSandboxFloatingStateExpanded,
};

static CGFloat const LCFloatingCollapsedSize = 60.0;
static CGFloat const LCFloatingExpandedSize = 96.0;
static CGFloat const LCFloatingEdgeInset = 4.0;
static CGFloat const LCFloatingMenuInset = 8.0;
static CGFloat const LCFloatingDragThreshold = 6.0;
static NSTimeInterval const LCFloatingIdleDelay = 1.5;
static NSString *const LCFloatingDockEdgeKey = @"AppBoxAssistiveDockEdge";
static NSString *const LCFloatingDockRatioKey = @"AppBoxAssistiveDockRatio";

typedef NS_ENUM(NSInteger, LCSandboxDockEdge) {
    LCSandboxDockEdgeLeft,
    LCSandboxDockEdgeRight,
    LCSandboxDockEdgeTop,
    LCSandboxDockEdgeBottom,
};

@interface LCSandboxPassthroughWindow : UIWindow
@property (nonatomic, weak) UIView *interactiveView;
@property (nonatomic) BOOL consumesOutsideTouches;
@property (nonatomic, copy, nullable) dispatch_block_t outsideInteractionHandler;
@end

@interface LCAssistiveTouchOrbView : UIView
@property (nonatomic) BOOL emphasized;
@property (nonatomic) BOOL idleAppearance;
@end

@interface LCAssistiveReturnIconView : UIView
@end

@interface LCSandboxFloatingView : UIView
@property (nonatomic, strong) LCAssistiveTouchOrbView *buttonView;
@property (nonatomic, strong) UIVisualEffectView *menuEffectView;
@property (nonatomic, strong) UIView *menuTintView;
@property (nonatomic, strong) UIStackView *menuContent;
@property (nonatomic, strong) LCAssistiveReturnIconView *iconView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, copy, nullable) dispatch_block_t activationHandler;
- (void)setMenuExpansionAnchor:(CGPoint)anchor;
- (void)applyState:(LCSandboxFloatingState)state animated:(BOOL)animated;
@end

@interface LCSandboxFloatingController () <UIGestureRecognizerDelegate>
@property (nonatomic, strong, nullable) LCSandboxPassthroughWindow *window;
@property (nonatomic, strong, nullable) LCSandboxFloatingView *floatingView;
@property (nonatomic) LCSandboxFloatingState state;
@property (nonatomic) BOOL dragging;
@property (nonatomic) BOOL returningToSandbox;
@property (nonatomic) CGPoint panStartCenter;
@property (nonatomic) CGRect collapsedFrame;
@property (nonatomic) NSUInteger idleGeneration;
@end

@implementation LCSandboxPassthroughWindow

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *interactiveView = self.interactiveView;
    if (!interactiveView || interactiveView.hidden || interactiveView.alpha <= 0.01) {
        return nil;
    }

    CGPoint localPoint = [interactiveView convertPoint:point fromView:self];
    if (![interactiveView pointInside:localPoint withEvent:event]) {
        if (self.outsideInteractionHandler) {
            dispatch_async(dispatch_get_main_queue(), self.outsideInteractionHandler);
        }
        return self.consumesOutsideTouches ? self.rootViewController.view : nil;
    }
    return [super hitTest:point withEvent:event];
}

@end

@implementation LCAssistiveTouchOrbView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (!self) return nil;

    self.backgroundColor = UIColor.clearColor;
    self.opaque = NO;
    self.contentMode = UIViewContentModeRedraw;
    _idleAppearance = YES;
    return self;
}

- (void)setEmphasized:(BOOL)emphasized {
    if (_emphasized == emphasized) return;
    _emphasized = emphasized;
    [self setNeedsDisplay];
}

- (void)setIdleAppearance:(BOOL)idleAppearance {
    if (_idleAppearance == idleAppearance) return;
    _idleAppearance = idleAppearance;
    [self setNeedsDisplay];
}

- (void)drawRect:(CGRect)rect {
    CGFloat side = MIN(CGRectGetWidth(self.bounds), CGRectGetHeight(self.bounds));
    if (side <= 0) return;

    CGFloat scale = side / 100.0;
    CGPoint center = CGPointMake(CGRectGetMidX(self.bounds), CGRectGetMidY(self.bounds));
    CGPoint ringCenter = CGPointMake(center.x - 0.5 * scale, center.y - 0.5 * scale);

    [self fillCircleWithDiameter:side
                          center:center
                           color:[UIColor colorWithRed:32.0 / 255.0
                                                 green:41.0 / 255.0
                                                  blue:49.0 / 255.0
                                                 alpha:1]];
    [self fillCircleWithDiameter:75.0 * scale
                          center:ringCenter
                           color:[UIColor colorWithRed:92.0 / 255.0
                                                 green:100.0 / 255.0
                                                  blue:104.0 / 255.0
                                                 alpha:1]];
    [self fillCircleWithDiameter:65.0 * scale
                          center:ringCenter
                           color:[UIColor colorWithRed:145.0 / 255.0
                                                 green:150.0 / 255.0
                                                  blue:156.0 / 255.0
                                                 alpha:1]];
    [self fillCircleWithDiameter:50.0 * scale
                          center:center
                           color:[UIColor colorWithWhite:1 alpha:self.emphasized ? 1.0 : 0.94]];
}

- (void)fillCircleWithDiameter:(CGFloat)diameter center:(CGPoint)center color:(UIColor *)color {
    CGRect circleRect = CGRectMake(center.x - diameter / 2.0,
                                   center.y - diameter / 2.0,
                                   diameter,
                                   diameter);
    [color setFill];
    [[UIBezierPath bezierPathWithOvalInRect:circleRect] fill];
}

@end

@implementation LCAssistiveReturnIconView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (!self) return nil;

    self.backgroundColor = UIColor.clearColor;
    self.opaque = NO;
    self.contentMode = UIViewContentModeRedraw;
    return self;
}

- (void)drawRect:(CGRect)rect {
    CGFloat side = MIN(CGRectGetWidth(self.bounds), CGRectGetHeight(self.bounds));
    if (side <= 0) return;

    CGFloat stroke = MAX(1.5, side * 0.08);
    CGPoint origin = CGPointMake((CGRectGetWidth(self.bounds) - side) / 2.0,
                                 (CGRectGetHeight(self.bounds) - side) / 2.0);

    CGPoint (^point)(CGFloat, CGFloat) = ^CGPoint(CGFloat x, CGFloat y) {
        return CGPointMake(origin.x + side * x, origin.y + side * y);
    };

    [UIColor.whiteColor setStroke];

    UIBezierPath *box = [UIBezierPath bezierPath];
    [box moveToPoint:point(0.20, 0.45)];
    [box addLineToPoint:point(0.50, 0.26)];
    [box addLineToPoint:point(0.80, 0.45)];
    [box addLineToPoint:point(0.80, 0.74)];
    [box addLineToPoint:point(0.50, 0.90)];
    [box addLineToPoint:point(0.20, 0.74)];
    [box closePath];
    box.lineWidth = stroke;
    box.lineJoinStyle = kCGLineJoinRound;
    [box stroke];

    UIBezierPath *arrow = [UIBezierPath bezierPath];
    [arrow moveToPoint:point(0.50, 0.52)];
    [arrow addLineToPoint:point(0.50, 0.36)];
    [arrow moveToPoint:point(0.39, 0.49)];
    [arrow addLineToPoint:point(0.50, 0.36)];
    [arrow addLineToPoint:point(0.61, 0.49)];
    arrow.lineWidth = stroke;
    arrow.lineCapStyle = kCGLineCapRound;
    arrow.lineJoinStyle = kCGLineJoinRound;
    [arrow stroke];

    CGRect trayRect = CGRectMake(origin.x + side * 0.33,
                                 origin.y + side * 0.54,
                                 side * 0.34,
                                 side * 0.24);
    UIBezierPath *tray = [UIBezierPath bezierPathWithRoundedRect:trayRect
                                                    cornerRadius:side * 0.06];
    tray.lineWidth = stroke;
    [tray stroke];
}

@end

@implementation LCSandboxFloatingView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (!self) return nil;

    self.backgroundColor = UIColor.clearColor;

    _buttonView = [[LCAssistiveTouchOrbView alloc] initWithFrame:CGRectZero];
    _buttonView.userInteractionEnabled = NO;
    [self addSubview:_buttonView];

    UIBlurEffect *blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemChromeMaterialDark];
    _menuEffectView = [[UIVisualEffectView alloc] initWithEffect:blur];
    _menuEffectView.clipsToBounds = YES;
    _menuEffectView.layer.cornerRadius = 22.0;
    _menuEffectView.userInteractionEnabled = NO;
    [self addSubview:_menuEffectView];

    _menuTintView = [[UIView alloc] initWithFrame:CGRectZero];
    _menuTintView.translatesAutoresizingMaskIntoConstraints = NO;
    _menuTintView.backgroundColor = [UIColor colorWithWhite:(75.0 / 255.0) alpha:1.0];
    [_menuEffectView.contentView addSubview:_menuTintView];

    _iconView = [[LCAssistiveReturnIconView alloc] initWithFrame:CGRectZero];
    _iconView.translatesAutoresizingMaskIntoConstraints = NO;

    _titleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _titleLabel.text = @"返回沙盒";
    _titleLabel.textColor = UIColor.whiteColor;
    _titleLabel.textAlignment = NSTextAlignmentCenter;
    _titleLabel.font = [UIFont systemFontOfSize:12.0 weight:UIFontWeightMedium];
    _titleLabel.numberOfLines = 2;

    _menuContent = [[UIStackView alloc] initWithArrangedSubviews:@[_iconView, _titleLabel]];
    _menuContent.translatesAutoresizingMaskIntoConstraints = NO;
    _menuContent.axis = UILayoutConstraintAxisVertical;
    _menuContent.alignment = UIStackViewAlignmentCenter;
    _menuContent.spacing = 6.0;
    _menuContent.userInteractionEnabled = NO;
    [_menuEffectView.contentView addSubview:_menuContent];

    [NSLayoutConstraint activateConstraints:@[
        [_menuTintView.leadingAnchor constraintEqualToAnchor:_menuEffectView.contentView.leadingAnchor],
        [_menuTintView.trailingAnchor constraintEqualToAnchor:_menuEffectView.contentView.trailingAnchor],
        [_menuTintView.topAnchor constraintEqualToAnchor:_menuEffectView.contentView.topAnchor],
        [_menuTintView.bottomAnchor constraintEqualToAnchor:_menuEffectView.contentView.bottomAnchor],
        [_menuContent.centerXAnchor constraintEqualToAnchor:_menuEffectView.contentView.centerXAnchor],
        [_menuContent.centerYAnchor constraintEqualToAnchor:_menuEffectView.contentView.centerYAnchor],
        [_iconView.widthAnchor constraintEqualToConstant:22.0],
        [_iconView.heightAnchor constraintEqualToConstant:22.0],
        [_titleLabel.widthAnchor constraintLessThanOrEqualToConstant:80.0],
    ]];

    self.isAccessibilityElement = YES;
    self.accessibilityTraits = UIAccessibilityTraitButton;
    [self applyState:LCSandboxFloatingStateResting animated:NO];
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    self.buttonView.bounds = CGRectMake(0, 0, LCFloatingCollapsedSize, LCFloatingCollapsedSize);
    CGPoint anchor = self.menuEffectView.layer.anchorPoint;
    self.buttonView.center = CGPointMake(
        CGRectGetWidth(self.bounds) * anchor.x,
        CGRectGetHeight(self.bounds) * anchor.y
    );
    self.menuEffectView.bounds = self.bounds;
    self.menuEffectView.layer.position = CGPointMake(
        CGRectGetWidth(self.bounds) * anchor.x,
        CGRectGetHeight(self.bounds) * anchor.y
    );
}

- (void)setMenuExpansionAnchor:(CGPoint)anchor {
    CGPoint clamped = CGPointMake(MIN(1.0, MAX(0.0, anchor.x)), MIN(1.0, MAX(0.0, anchor.y)));
    self.menuEffectView.layer.anchorPoint = clamped;
    [self setNeedsLayout];
    [self layoutIfNeeded];
}

- (void)applyState:(LCSandboxFloatingState)state animated:(BOOL)animated {
    void (^changes)(void) = ^{
        BOOL expanded = state == LCSandboxFloatingStateExpanded;
        BOOL pressed = state == LCSandboxFloatingStatePressed;
        BOOL idle = state == LCSandboxFloatingStateResting;
        self.buttonView.idleAppearance = state == LCSandboxFloatingStateResting;
        self.buttonView.emphasized = pressed;
        self.buttonView.alpha = expanded ? 0.0 : (idle ? 0.42 : 1.0);
        self.buttonView.transform = pressed
            ? CGAffineTransformMakeScale(0.96, 0.96)
            : CGAffineTransformIdentity;
        self.menuEffectView.alpha = expanded ? 1.0 : 0.0;
        self.menuEffectView.transform = expanded
            ? CGAffineTransformIdentity
            : CGAffineTransformMakeScale(
                LCFloatingCollapsedSize / LCFloatingExpandedSize,
                LCFloatingCollapsedSize / LCFloatingExpandedSize
            );
        self.menuContent.transform = expanded
            ? CGAffineTransformIdentity
            : CGAffineTransformMakeScale(0.72, 0.72);
        self.layer.shadowColor = UIColor.blackColor.CGColor;
        self.layer.shadowOpacity = expanded ? 0.22 : 0.0;
        self.layer.shadowRadius = expanded ? 9.0 : 0.0;
        self.layer.shadowOffset = expanded ? CGSizeMake(0, 4.0) : CGSizeZero;
        self.accessibilityLabel = expanded ? @"返回沙盒" : @"沙盒控制";
        self.accessibilityHint = expanded ? @"轻点返回天涯盒子" : @"轻点展开，拖动可调整位置";
    };

    if (animated) {
        [UIView animateWithDuration:0.24
                              delay:0
             usingSpringWithDamping:0.9
              initialSpringVelocity:0.1
                            options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                         animations:changes
                         completion:nil];
    } else {
        changes();
    }
}

- (BOOL)accessibilityActivate {
    if (!self.activationHandler) return NO;
    self.activationHandler();
    return YES;
}

@end

@implementation LCSandboxFloatingController

+ (instancetype)sharedController {
    static LCSandboxFloatingController *controller;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        controller = [LCSandboxFloatingController new];
    });
    return controller;
}

- (instancetype)init {
    self = [super init];
    if (!self) return nil;

    _state = LCSandboxFloatingStateResting;
    NSNotificationCenter *center = NSNotificationCenter.defaultCenter;
    [center addObserver:self selector:@selector(sceneDidChange:) name:UISceneDidActivateNotification object:nil];
    [center addObserver:self selector:@selector(sceneDidChange:) name:UIApplicationDidBecomeActiveNotification object:nil];
    [center addObserver:self selector:@selector(sceneDidChange:) name:UIDeviceOrientationDidChangeNotification object:nil];
    return self;
}

- (void)installWhenReady {
    NSAssert(NSThread.isMainThread, @"Floating control must be installed on the main thread");
    if (self.window) {
        [self updateWindowAndPositionAnimated:NO];
        return;
    }

    UIWindowScene *scene = [self activeWindowScene];
    if (!scene) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(250 * NSEC_PER_MSEC)), dispatch_get_main_queue(), ^{
            [self installWhenReady];
        });
        return;
    }

    LCSandboxPassthroughWindow *window = [[LCSandboxPassthroughWindow alloc] initWithWindowScene:scene];
    window.backgroundColor = UIColor.clearColor;
    window.windowLevel = UIWindowLevelAlert + 2.0;
    window.rootViewController = [UIViewController new];
    window.rootViewController.view.backgroundColor = UIColor.clearColor;
    window.hidden = NO;

    LCSandboxFloatingView *floatingView = [[LCSandboxFloatingView alloc]
        initWithFrame:CGRectMake(0, 0, LCFloatingCollapsedSize, LCFloatingCollapsedSize)];
    [window.rootViewController.view addSubview:floatingView];
    window.interactiveView = floatingView;

    __weak typeof(self) weakSelf = self;
    window.outsideInteractionHandler = ^{
        if (weakSelf.state == LCSandboxFloatingStateExpanded) {
            [weakSelf collapseMenu];
        }
    };

    UILongPressGestureRecognizer *pressGesture = [[UILongPressGestureRecognizer alloc]
        initWithTarget:self action:@selector(handlePress:)];
    pressGesture.minimumPressDuration = 0;
    pressGesture.allowableMovement = CGFLOAT_MAX;
    pressGesture.delegate = self;
    [floatingView addGestureRecognizer:pressGesture];

    UIPanGestureRecognizer *panGesture = [[UIPanGestureRecognizer alloc]
        initWithTarget:self action:@selector(handlePan:)];
    panGesture.maximumNumberOfTouches = 1;
    panGesture.delegate = self;
    [floatingView addGestureRecognizer:panGesture];

    self.window = window;
    self.floatingView = floatingView;
    floatingView.activationHandler = ^{
        if (weakSelf.state == LCSandboxFloatingStateExpanded) {
            [weakSelf returnToSandbox];
        } else {
            [weakSelf expandMenu];
        }
    };
    [self updateWindowAndPositionAnimated:NO];
}

- (UIWindowScene *)activeWindowScene {
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if ([scene isKindOfClass:UIWindowScene.class] && scene.activationState == UISceneActivationStateForegroundActive) {
            return (UIWindowScene *)scene;
        }
    }
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if ([scene isKindOfClass:UIWindowScene.class]) return (UIWindowScene *)scene;
    }
    return nil;
}

- (void)sceneDidChange:(NSNotification *)notification {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self installWhenReady];
    });
}

- (void)updateWindowAndPositionAnimated:(BOOL)animated {
    UIWindowScene *scene = [self activeWindowScene];
    if (!scene || !self.window || !self.floatingView) return;

    if (self.window.windowScene != scene) self.window.windowScene = scene;
    self.window.frame = scene.coordinateSpace.bounds;
    self.window.rootViewController.view.frame = self.window.bounds;
    if (self.state == LCSandboxFloatingStateExpanded) {
        [self setState:LCSandboxFloatingStateResting animated:NO];
    }

    CGRect frame = [self frameForSavedDockPosition];
    self.collapsedFrame = frame;
    void (^changes)(void) = ^{
        self.floatingView.frame = frame;
    };
    animated ? [UIView animateWithDuration:0.2 animations:changes] : changes();
}

- (CGRect)frameForSavedDockPosition {
    UIEdgeInsets safe = self.window.safeAreaInsets;
    CGFloat minX = safe.left + LCFloatingEdgeInset;
    CGFloat maxX = CGRectGetWidth(self.window.bounds) - safe.right - LCFloatingEdgeInset - LCFloatingCollapsedSize;
    CGFloat minY = safe.top + LCFloatingEdgeInset;
    CGFloat maxY = CGRectGetHeight(self.window.bounds) - safe.bottom - LCFloatingEdgeInset - LCFloatingCollapsedSize;

    NSUserDefaults *defaults = NSUserDefaults.lcSharedDefaults ?: NSUserDefaults.lcUserDefaults;
    NSString *edge = [defaults stringForKey:LCFloatingDockEdgeKey] ?: @"right";
    NSNumber *savedRatio = [defaults objectForKey:LCFloatingDockRatioKey];
    CGFloat ratio = MIN(1.0, MAX(0.0, savedRatio ? savedRatio.doubleValue : 0.92));
    CGFloat x = maxX;
    CGFloat y = minY + (maxY - minY) * ratio;

    if ([edge isEqualToString:@"left"]) {
        x = minX;
    } else if ([edge isEqualToString:@"top"]) {
        x = minX + (maxX - minX) * ratio;
        y = minY;
    } else if ([edge isEqualToString:@"bottom"]) {
        x = minX + (maxX - minX) * ratio;
        y = maxY;
    }
    return CGRectMake(x, y, LCFloatingCollapsedSize, LCFloatingCollapsedSize);
}

- (void)setState:(LCSandboxFloatingState)state animated:(BOOL)animated {
    if (_state == state || !self.floatingView) return;

    LCSandboxFloatingState previousState = _state;
    if (_state != LCSandboxFloatingStateExpanded) {
        self.collapsedFrame = self.floatingView.frame;
    }
    _state = state;
    self.window.consumesOutsideTouches = state == LCSandboxFloatingStateExpanded;

    CGRect nextFrame = self.collapsedFrame;
    if (state == LCSandboxFloatingStateExpanded) {
        CGFloat half = LCFloatingExpandedSize / 2.0;
        UIEdgeInsets safe = self.window.safeAreaInsets;
        CGPoint anchor = CGPointMake(CGRectGetMidX(self.collapsedFrame), CGRectGetMidY(self.collapsedFrame));
        CGFloat minX = safe.left + LCFloatingMenuInset + half;
        CGFloat maxX = CGRectGetWidth(self.window.bounds) - safe.right - LCFloatingMenuInset - half;
        CGFloat minY = safe.top + LCFloatingMenuInset + half;
        CGFloat maxY = CGRectGetHeight(self.window.bounds) - safe.bottom - LCFloatingMenuInset - half;
        CGPoint center = CGPointMake(
            MIN(maxX, MAX(minX, anchor.x)),
            MIN(maxY, MAX(minY, anchor.y))
        );
        nextFrame = CGRectMake(center.x - half, center.y - half, LCFloatingExpandedSize, LCFloatingExpandedSize);
        [self.floatingView setMenuExpansionAnchor:CGPointMake(
            (anchor.x - CGRectGetMinX(nextFrame)) / LCFloatingExpandedSize,
            (anchor.y - CGRectGetMinY(nextFrame)) / LCFloatingExpandedSize
        )];
    }

    if (state == LCSandboxFloatingStateExpanded) {
        self.floatingView.frame = nextFrame;
        [self.floatingView setNeedsLayout];
        [self.floatingView layoutIfNeeded];
        [self.floatingView applyState:state animated:animated];
        return;
    }

    [self.floatingView applyState:state animated:animated];
    if (previousState != LCSandboxFloatingStateExpanded) return;

    void (^restoreCollapsedFrame)(void) = ^{
        if (self.state != state) return;
        self.floatingView.frame = nextFrame;
        [self.floatingView setMenuExpansionAnchor:CGPointMake(0.5, 0.5)];
    };
    if (animated) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(260 * NSEC_PER_MSEC)),
                       dispatch_get_main_queue(), restoreCollapsedFrame);
    } else {
        restoreCollapsedFrame();
    }
}

- (void)expandMenu {
    self.idleGeneration += 1;
    [self setState:LCSandboxFloatingStateExpanded animated:YES];
    UIImpactFeedbackGenerator *feedback = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    [feedback impactOccurred];
}

- (void)collapseMenu {
    [self setState:LCSandboxFloatingStatePressed animated:YES];
    [self scheduleIdleState];
}

- (void)scheduleIdleState {
    NSUInteger generation = ++self.idleGeneration;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(LCFloatingIdleDelay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (generation == self.idleGeneration && self.state == LCSandboxFloatingStatePressed) {
            [self setState:LCSandboxFloatingStateResting animated:YES];
        }
    });
}

- (void)handlePress:(UILongPressGestureRecognizer *)gesture {
    switch (gesture.state) {
        case UIGestureRecognizerStateBegan:
            self.dragging = NO;
            self.idleGeneration += 1;
            if (self.state != LCSandboxFloatingStateExpanded) {
                [self setState:LCSandboxFloatingStatePressed animated:YES];
            }
            break;
        case UIGestureRecognizerStateEnded:
            if (self.dragging) return;
            if (self.state == LCSandboxFloatingStateExpanded) {
                [self returnToSandbox];
            } else {
                [self expandMenu];
            }
            break;
        case UIGestureRecognizerStateCancelled:
        case UIGestureRecognizerStateFailed:
            if (!self.dragging && self.state == LCSandboxFloatingStatePressed) {
                [self scheduleIdleState];
            }
            break;
        default:
            break;
    }
}

- (void)handlePan:(UIPanGestureRecognizer *)gesture {
    if (self.state == LCSandboxFloatingStateExpanded || !self.floatingView || !self.window) return;

    CGPoint translation = [gesture translationInView:self.window.rootViewController.view];
    if (gesture.state == UIGestureRecognizerStateBegan) {
        self.panStartCenter = self.floatingView.center;
    } else if (gesture.state == UIGestureRecognizerStateChanged) {
        if (hypot(translation.x, translation.y) < LCFloatingDragThreshold) return;
        self.dragging = YES;
        UIEdgeInsets safe = self.window.safeAreaInsets;
        CGFloat half = LCFloatingCollapsedSize / 2.0;
        CGFloat minX = safe.left + LCFloatingEdgeInset + half;
        CGFloat maxX = CGRectGetWidth(self.window.bounds) - safe.right - LCFloatingEdgeInset - half;
        CGFloat minY = safe.top + LCFloatingEdgeInset + half;
        CGFloat maxY = CGRectGetHeight(self.window.bounds) - safe.bottom - LCFloatingEdgeInset - half;
        self.floatingView.center = CGPointMake(
            MIN(maxX, MAX(minX, self.panStartCenter.x + translation.x)),
            MIN(maxY, MAX(minY, self.panStartCenter.y + translation.y))
        );
    } else if (gesture.state == UIGestureRecognizerStateEnded || gesture.state == UIGestureRecognizerStateCancelled) {
        if (!self.dragging) return;
        [self snapToNearestEdgeAndPersist];
        [self scheduleIdleState];
        dispatch_async(dispatch_get_main_queue(), ^{ self.dragging = NO; });
    }
}

- (void)snapToNearestEdgeAndPersist {
    UIEdgeInsets safe = self.window.safeAreaInsets;
    CGFloat minX = safe.left + LCFloatingEdgeInset;
    CGFloat maxX = CGRectGetWidth(self.window.bounds) - safe.right - LCFloatingEdgeInset - LCFloatingCollapsedSize;
    CGFloat minY = safe.top + LCFloatingEdgeInset;
    CGFloat maxY = CGRectGetHeight(self.window.bounds) - safe.bottom - LCFloatingEdgeInset - LCFloatingCollapsedSize;
    CGRect frame = self.floatingView.frame;

    CGFloat leftDistance = fabs(CGRectGetMinX(frame) - minX);
    CGFloat rightDistance = fabs(maxX - CGRectGetMinX(frame));
    CGFloat topDistance = fabs(CGRectGetMinY(frame) - minY);
    CGFloat bottomDistance = fabs(maxY - CGRectGetMinY(frame));
    CGFloat nearest = MIN(MIN(leftDistance, rightDistance), MIN(topDistance, bottomDistance));
    LCSandboxDockEdge edge = LCSandboxDockEdgeRight;
    NSString *edgeValue = @"right";
    CGFloat ratio = 0.5;

    if (nearest == leftDistance) {
        edge = LCSandboxDockEdgeLeft;
        edgeValue = @"left";
    } else if (nearest == topDistance) {
        edge = LCSandboxDockEdgeTop;
        edgeValue = @"top";
    } else if (nearest == bottomDistance) {
        edge = LCSandboxDockEdgeBottom;
        edgeValue = @"bottom";
    }

    if (edge == LCSandboxDockEdgeLeft || edge == LCSandboxDockEdgeRight) {
        frame.origin.x = edge == LCSandboxDockEdgeLeft ? minX : maxX;
        ratio = maxY > minY ? (CGRectGetMinY(frame) - minY) / (maxY - minY) : 0.5;
    } else {
        frame.origin.y = edge == LCSandboxDockEdgeTop ? minY : maxY;
        ratio = maxX > minX ? (CGRectGetMinX(frame) - minX) / (maxX - minX) : 0.5;
    }
    ratio = MIN(1.0, MAX(0.0, ratio));
    self.collapsedFrame = frame;

    [UIView animateWithDuration:0.3
                          delay:0
         usingSpringWithDamping:0.78
          initialSpringVelocity:0.2
                        options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                     animations:^{ self.floatingView.frame = frame; }
                     completion:nil];

    NSUserDefaults *defaults = NSUserDefaults.lcSharedDefaults ?: NSUserDefaults.lcUserDefaults;
    [defaults setObject:edgeValue forKey:LCFloatingDockEdgeKey];
    [defaults setDouble:ratio forKey:LCFloatingDockRatioKey];
}

- (void)returnToSandbox {
    if (self.returningToSandbox) return;
    self.returningToSandbox = YES;
    self.floatingView.userInteractionEnabled = NO;
    UIImpactFeedbackGenerator *feedback = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
    [feedback impactOccurred];

    NSString *scheme = NSUserDefaults.lcAppUrlScheme ?: @"livecontainer";
    NSURLComponents *components = [NSURLComponents new];
    components.scheme = scheme;
    components.host = @"livecontainer-launch";
    components.queryItems = @[[NSURLQueryItem queryItemWithName:@"bundle-name" value:@"ui"]];
    NSURL *url = components.URL;
    Class sharedUtils = NSClassFromString(@"LCSharedUtils");
    SEL selector = NSSelectorFromString(@"launchToGuestAppWithURL:");
    if (url && [sharedUtils respondsToSelector:selector]) {
        BOOL (*launch)(id, SEL, NSURL *) = (void *)objc_msgSend;
        if (launch(sharedUtils, selector, url)) return;
    }

    self.returningToSandbox = NO;
    self.floatingView.userInteractionEnabled = YES;
    if (url) {
        [UIApplication.sharedApplication openURL:url options:@{} completionHandler:nil];
    }
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer
        shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    return YES;
}

@end

__attribute__((constructor))
static void LCSandboxFloatingControlInit(void) {
    if (!NSUserDefaults.lcGuestAppId || NSUserDefaults.isLiveProcess || NSUserDefaults.isSideStore) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        [[LCSandboxFloatingController sharedController] installWhenReady];
    });
}
