#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// A rectangular tappable overlay with built-in highlight-on-touch
/// feedback. Switches its backgroundColor between `normalColor` and
/// `pressedColor` as the user's finger goes down / up / cancels,
/// driven by UIControl's highlighted state.
///
/// Used for both mention spans and spoiler regions — the two
/// systems that need to capture taps on inline ranges in a
/// non-editable UITextView without going through
/// NSLinkAttributeName (which would also enable long-press
/// preview menus, drag-to-drop, etc.).
@interface MarkdownPressableOverlayView : UIControl

/// Background color shown when the control is not being pressed.
/// Default: clear.
@property (nonatomic, strong, nullable) UIColor *normalColor;

/// Background color shown while the user's finger is down on the
/// control. Default: a subtle semi-transparent dark tint.
@property (nonatomic, strong, nullable) UIColor *pressedColor;

/// Opaque identifier for grouping overlays that belong to the same
/// logical target (e.g. all line fragments of one mention or
/// spoiler). When one overlay in a group is highlighted the whole
/// group is highlighted in lockstep.
@property (nonatomic, copy, nullable) NSString *groupId;

@end

NS_ASSUME_NONNULL_END
