

extern "C" UIImage* _UICreateScreenUIImage();

@class LockAnimImageView;

@interface LockAnim : NSObject
{
	UIWindow* springboardWindow;
	UILabel *label;
	UIView *backView;
	LockAnimImageView *imageView;
}
@property (nonatomic, strong) UIWindow* springboardWindow;
@property (nonatomic, strong) UILabel *label;
@property (nonatomic, strong) UIView *backView;
@property (nonatomic, strong) LockAnimImageView *imageView;
+ (id)sharedInstance;
+ (BOOL)sharedInstanceExist;
- (void)firstload;
- (void)animWithDuration:(float)arg1 source:(int)source;
- (void)restoreFrames;
@end

@interface UIWindow ()
- (void)_setSecure:(BOOL)arg1;
@end

@interface LockAnimWindow : UIWindow
@end

@interface SBBacklightController : NSObject
@property (nonatomic,readonly) BOOL screenIsOn; 
@property (nonatomic,readonly) BOOL screenIsDim;
@end