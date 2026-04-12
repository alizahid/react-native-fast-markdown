#import <Foundation/Foundation.h>
#import "FormattingRange.h"

NS_ASSUME_NONNULL_BEGIN

@interface FormattingStore : NSObject

// --- Query ---

@property (nonatomic, readonly) NSArray<FormattingRange *> *allRanges;

- (BOOL)hasType:(FormattingType)type atIndex:(NSUInteger)index;
- (NSArray<FormattingRange *> *)rangesAtIndex:(NSUInteger)index;
- (NSArray<FormattingRange *> *)rangesOfType:(FormattingType)type
                                intersecting:(NSRange)range;

// --- Mutate ---

- (void)addRange:(FormattingRange *)range;
- (void)removeRangesOfType:(FormattingType)type intersecting:(NSRange)range;
- (void)replaceAllRanges:(NSArray<FormattingRange *> *)ranges;
- (void)removeAll;

// --- Edit adjustment ---

/// Adjusts all ranges after a text edit. Must be called BEFORE the
/// edit is applied to the text storage (i.e. from
/// shouldChangeTextInRange:).
- (void)adjustForEditAt:(NSUInteger)location
          deletedLength:(NSUInteger)deleted
         insertedLength:(NSUInteger)inserted;

// --- Pending styles (cursor boundary disambiguation) ---

/// Styles the user has toggled ON at the cursor (no selection).
/// Applied to the next insertion, then cleared.
@property (nonatomic, strong, readonly) NSMutableSet<NSNumber *> *pendingStyles;

/// Styles the user has toggled OFF at the cursor (no selection).
/// Prevents the next insertion from inheriting the style.
@property (nonatomic, strong, readonly) NSMutableSet<NSNumber *> *pendingRemovals;

/// Clears both pending sets. Called on cursor move.
- (void)clearPending;

/// Three-layer state check: store → pendingRemovals → pendingStyles.
- (BOOL)isEffectivelyActive:(FormattingType)type atIndex:(NSUInteger)index;

/// Returns the effective link URL at the given index, respecting
/// pending state.
- (nullable NSString *)effectiveLinkAtIndex:(NSUInteger)index;

@end

NS_ASSUME_NONNULL_END
