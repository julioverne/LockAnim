#import <dlfcn.h>
#import <objc/runtime.h>
#import <substrate.h>
#import <notify.h>

#import "LockAnim.h"

#define NSLog(...)

#define PLIST_PATH_Settings "/var/mobile/Library/Preferences/com.julioverne.lockanim.plist"

static BOOL Enabled;
static int animType;
static float speedFactor;

%hook SBBacklightController
-(void)_animateBacklightToFactor:(float)arg1 duration:(double)arg2 source:(long long)arg3 silently:(BOOL)arg4 completion:(id)arg5 
{
	if(Enabled && (arg1==0 && [self screenIsOn]) ) {
		arg2 = speedFactor;
		
		NSLog(@"** -(void)_animateBacklightToFactor source:%@ duration:%@ Factor:%@ silently:%@", @(arg3), @(arg2), @(arg1), @(arg4));
		
		if([LockAnim sharedInstanceExist]) {
			LockAnim* lockAnim = [LockAnim sharedInstance];
			[lockAnim animWithDuration:arg2 source:0];
		}
	}
	%orig(arg1, arg2, arg3, arg4, arg5);
}
%end

%hook SpringBoard
- (void)applicationDidFinishLaunching:(id)application
{
	%orig;
	[[LockAnim sharedInstance] firstload];	
}
%end


#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>
#import <Foundation/Foundation.h>

typedef void(^ExplodeCompletion)(void);

@interface LockAnimImageView : UIImageView

@property (nonatomic, copy) ExplodeCompletion completionCallback;

- (void)lp_explode;
- (void)lp_explodeWithCallback:(ExplodeCompletion)callback;

@end


@interface LockAnimParticleLayer : CALayer

@property (nonatomic, strong) UIBezierPath *particlePath;

@end


@implementation LockAnimImageView

@dynamic completionCallback;

- (void)setCompletionCallback:(ExplodeCompletion)completionCallback
{
    [self willChangeValueForKey:@"completionCallback"];
    objc_setAssociatedObject(self, @selector(completionCallback), completionCallback, OBJC_ASSOCIATION_COPY_NONATOMIC);
    [self didChangeValueForKey:@"completionCallback"];
}

- (ExplodeCompletion)completionCallback
{
    // obj assoc
    id object = objc_getAssociatedObject(self,@selector(completionCallback));
    return object;
}


float randomFloat()
{
    return (float)rand()/(float)RAND_MAX;
}

- (UIImage *)imageFromLayer:(CALayer *)layer
{
    UIGraphicsBeginImageContext([layer frame].size);
    
    [layer renderInContext:UIGraphicsGetCurrentContext()];
    UIImage *outputImage = UIGraphicsGetImageFromCurrentImageContext();
    
    UIGraphicsEndImageContext();
    
    return outputImage;
}

- (void)lp_explodeWithCallback:(ExplodeCompletion)callback
{
  
    self.userInteractionEnabled = NO;
    
    if (callback)
    {
        self.completionCallback = callback;
    }
    
    float size = self.frame.size.width/5;
    CGSize imageSize = CGSizeMake(size, size);
    
    CGFloat cols = self.frame.size.width / imageSize.width ;
    CGFloat rows = self.frame.size.height /imageSize.height;
    
    int fullColumns = floorf(cols);
    int fullRows = floorf(rows);
    
    CGFloat remainderWidth = self.frame.size.width  -
    (fullColumns * imageSize.width);
    CGFloat remainderHeight = self.frame.size.height -
    (fullRows * imageSize.height );
    
    
    if (cols > fullColumns) fullColumns++;
    if (rows > fullRows) fullRows++;
    
    CGRect originalFrame = self.layer.frame;
    CGRect originalBounds = self.layer.bounds;
    
    
    CGImageRef fullImage = [self imageFromLayer:self.layer].CGImage;
    
    //if its an image, set it to nil
    if ([self isKindOfClass:[UIImageView class]])
    {
        [(UIImageView*)self setImage:nil];
    }
    
    [[self subviews] makeObjectsPerformSelector:@selector(removeFromSuperview)];
    [[self.layer sublayers] makeObjectsPerformSelector:@selector(removeFromSuperlayer)];
    
    for (int y = 0; y < fullRows; ++y)
    {
        for (int x = 0; x < fullColumns; ++x)
        {
            CGSize tileSize = imageSize;
            
            if (x + 1 == fullColumns && remainderWidth > 0)
            {
                // Last column
                tileSize.width = remainderWidth;
            }
            if (y + 1 == fullRows && remainderHeight > 0)
            {
                // Last row
                tileSize.height = remainderHeight;
            }
            
            CGRect layerRect = (CGRect){{x*imageSize.width, y*imageSize.height},
                tileSize};
            
            CGImageRef tileImage = CGImageCreateWithImageInRect(fullImage,layerRect);
            
            LockAnimParticleLayer *layer = [LockAnimParticleLayer layer];
            layer.frame = layerRect;
            layer.contents = (__bridge id)(tileImage);
            layer.borderWidth = 0.0f;
            layer.borderColor = [UIColor blackColor].CGColor;
            layer.particlePath = [self pathForLayer:layer parentRect:originalFrame];
            [self.layer addSublayer:layer];
            
            CGImageRelease(tileImage);
        }
    }
    
    [self.layer setFrame:originalFrame];
    [self.layer setBounds:originalBounds];
    
    
    self.layer.backgroundColor = [UIColor clearColor].CGColor;
    
    NSArray *sublayersArray = [self.layer sublayers];
    [sublayersArray enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        
        LockAnimParticleLayer *layer = (LockAnimParticleLayer *)obj;
        
        //Path
        CAKeyframeAnimation *moveAnim = [CAKeyframeAnimation animationWithKeyPath:@"position"];
        moveAnim.path = layer.particlePath.CGPath;
        moveAnim.removedOnCompletion = YES;
        moveAnim.fillMode=kCAFillModeForwards;
        NSArray *timingFunctions = [NSArray arrayWithObjects:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut],nil];
        [moveAnim setTimingFunctions:timingFunctions];
        
        //float r = randomFloat();
        
        NSTimeInterval speed = speedFactor;//2.35*r;
        
        CAKeyframeAnimation *transformAnim = [CAKeyframeAnimation animationWithKeyPath:@"transform"];
        
        CATransform3D startingScale = layer.transform;
        CATransform3D endingScale = CATransform3DConcat(CATransform3DMakeScale(randomFloat(), randomFloat(), randomFloat()), CATransform3DMakeRotation(M_PI*(1+randomFloat()), randomFloat(), randomFloat(), randomFloat()));
        
        NSArray *boundsValues = [NSArray arrayWithObjects:[NSValue valueWithCATransform3D:startingScale],
                                 
                                 [NSValue valueWithCATransform3D:endingScale], nil];
        [transformAnim setValues:boundsValues];
        
        NSArray *times = [NSArray arrayWithObjects:[NSNumber numberWithFloat:0.0],
                          [NSNumber numberWithFloat:speed*.25], nil];
        [transformAnim setKeyTimes:times];
        
        
        timingFunctions = [NSArray arrayWithObjects:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut],
                           [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseIn],
                           [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut], [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut],
                           nil];
        [transformAnim setTimingFunctions:timingFunctions];
        transformAnim.fillMode = kCAFillModeForwards;
        transformAnim.removedOnCompletion = NO;
        
        //alpha
        CABasicAnimation *opacityAnim = [CABasicAnimation animationWithKeyPath:@"opacity"];
        opacityAnim.fromValue = [NSNumber numberWithFloat:1.0f];
        opacityAnim.toValue = [NSNumber numberWithFloat:0.f];
        opacityAnim.removedOnCompletion = NO;
        opacityAnim.fillMode =kCAFillModeForwards;
        
        
        CAAnimationGroup *animGroup = [CAAnimationGroup animation];
        animGroup.animations = [NSArray arrayWithObjects:moveAnim,transformAnim,opacityAnim, nil];
        animGroup.duration = speed;
        animGroup.fillMode =kCAFillModeForwards;
        animGroup.delegate = self;
        [animGroup setValue:layer forKey:@"animationLayer"];
        [layer addAnimation:animGroup forKey:nil];
        
        //take it off screen
        [layer setPosition:CGPointMake(0, -600)];
        
    }];
}

- (void)lp_explode
{
    [self lp_explodeWithCallback:nil];
}


- (void)animationDidStop:(CAAnimation *)theAnimation finished:(BOOL)flag
{
    LockAnimParticleLayer *layer = [theAnimation valueForKey:@"animationLayer"];
    
    if (layer)
    {
        //make sure we dont have any more
        if ([[self.layer sublayers] count]==1)
        {
            if (self.completionCallback)
            {
                self.completionCallback();
            }
            //[self removeFromSuperview];
            
        }
        else
        {
            [layer removeFromSuperlayer];
        }
    }
}

-(UIBezierPath *)pathForLayer:(CALayer *)layer parentRect:(CGRect)rect
{
    UIBezierPath *particlePath = [UIBezierPath bezierPath];
    [particlePath moveToPoint:layer.position];
    
    float r = ((float)rand()/(float)RAND_MAX) + 0.3f;
    float r2 = ((float)rand()/(float)RAND_MAX)+ 0.4f;
    float r3 = r*r2;
    
    int upOrDown = (r <= 0.5) ? 1 : -1;
    
    CGPoint curvePoint = CGPointZero;
    CGPoint endPoint = CGPointZero;
    
    float maxLeftRightShift = 1.f * randomFloat();
    
    CGFloat layerYPosAndHeight = (self.superview.frame.size.height-((layer.position.y+layer.frame.size.height)))*randomFloat();
    CGFloat layerXPosAndHeight = (self.superview.frame.size.width-((layer.position.x+layer.frame.size.width)))*r3;
    
    float endY = self.superview.frame.size.height-self.frame.origin.y;
    
    if (layer.position.x <= rect.size.width*0.5)
    {
        //going left
        endPoint = CGPointMake(-layerXPosAndHeight, endY);
        curvePoint= CGPointMake((((layer.position.x*0.5)*r3)*upOrDown)*maxLeftRightShift,-layerYPosAndHeight);
    }
    else
    {
        endPoint = CGPointMake(layerXPosAndHeight, endY);
        curvePoint= CGPointMake((((layer.position.x*0.5)*r3)*upOrDown+rect.size.width)*maxLeftRightShift, -layerYPosAndHeight);
    }
    
    [particlePath addQuadCurveToPoint:endPoint
                     controlPoint:curvePoint];
    
    return particlePath;
    
}

@end

@implementation LockAnimParticleLayer
@end


@implementation LockAnimWindow
- (BOOL)_ignoresHitTest
{
	return YES;
}
+ (BOOL)_isSecure
{
	return YES;
}
@end

@implementation LockAnim
@synthesize springboardWindow, label, backView, imageView;
__strong static id _sharedObject;
+ (id)sharedInstance
{
	if (!_sharedObject) {
		_sharedObject = [[self alloc] init];
	}
	return _sharedObject;
}
+ (BOOL)sharedInstanceExist
{
	if (_sharedObject) {
		return YES;
	}
	return NO;
}
- (void)firstload
{
	return;
}
-(id)init
{
	self = [super init];
	if(self != nil) {
		@try {
			
			springboardWindow = [[LockAnimWindow alloc] initWithFrame:CGRectMake(0, 0, [[UIScreen mainScreen] bounds].size.width, [[UIScreen mainScreen] bounds].size.height)];
			springboardWindow.windowLevel = 99999999999;
			[springboardWindow setHidden:YES];
			springboardWindow.alpha = 1;
			[springboardWindow _setSecure:YES];
			[springboardWindow setUserInteractionEnabled:NO];
			springboardWindow.layer.cornerRadius = 1.0f;
			springboardWindow.layer.masksToBounds = YES;
			springboardWindow.layer.shouldRasterize  = NO;
			springboardWindow.backgroundColor = [UIColor blackColor];
			
			backView = [UIView new];
			backView.frame = springboardWindow.bounds;
			backView.backgroundColor = [UIColor blackColor];
			backView.alpha = 1.0f; // 0.5f
			backView.layer.masksToBounds = YES;
			[(UIView *)springboardWindow addSubview:backView];
			
			imageView = [LockAnimImageView new];
			imageView.frame = springboardWindow.bounds;
			imageView.contentMode = UIViewContentModeScaleAspectFill;
			
			[backView addSubview:imageView];
			
		} @catch (NSException * e) {
			
		}
	}
	return self;
}
- (void)restoreFrames
{
	imageView.alpha = 1.0f;
	backView.alpha = 1.0f;
	backView.frame = springboardWindow.bounds;
	imageView.frame = backView.bounds;
	imageView.transform = CGAffineTransformIdentity;
	backView.transform = CGAffineTransformIdentity;
	imageView.image = nil;
	springboardWindow.hidden = YES;
}
- (void)animWithDuration:(float)arg1 source:(int)source
{
	[self restoreFrames];
	
	CGRect newFrameImage = imageView.frame;
	CGRect newFrameBack = backView.frame;
	
	CGAffineTransform newTransformImage = imageView.transform;
	CGAffineTransform newTransformBack = backView.transform;
	
	if(source == 0) {
		if(animType == 0) {
			newFrameImage = CGRectMake(imageView.center.x,imageView.center.y,0,0);
		} else if(animType == 1) {
			newFrameImage = CGRectMake(imageView.frame.origin.x,-imageView.frame.size.height,imageView.frame.size.width,imageView.frame.size.height);
		} else if(animType == 2) {
			newFrameImage = CGRectMake(imageView.frame.origin.x,imageView.frame.size.height,imageView.frame.size.width,imageView.frame.size.height);
		} else if(animType == 3) {
			newFrameImage = CGRectMake(-imageView.frame.size.width,imageView.frame.origin.y,imageView.frame.size.width,imageView.frame.size.height);
		} else if(animType == 4) {
			newFrameImage = CGRectMake(imageView.frame.size.width,imageView.frame.origin.y,imageView.frame.size.width,imageView.frame.size.height);
		} else if(animType == 5) {
			newFrameImage = CGRectMake(imageView.frame.origin.x,-imageView.center.y,imageView.frame.size.width,imageView.frame.size.height);
			newFrameBack = CGRectMake(0,imageView.center.y,imageView.frame.size.width,0);
		} else if(animType == 6) {
			newFrameImage = CGRectMake(imageView.center.x,imageView.center.y,0,0);
			newTransformBack = CGAffineTransformMakeRotation(200 * M_PI/180);
		}
	}
	
	imageView.image = _UICreateScreenUIImage();
	springboardWindow.hidden = NO;
	
	float speed = arg1/2;
	
	if(animType == 7) {
		[imageView lp_explodeWithCallback:^{
			springboardWindow.hidden = YES;
			[self restoreFrames];
		}];
	} else if(animType == 8 || animType == 9) {
		UIVisualEffectView* effectView;
		if(objc_getClass("UIVisualEffectView") != nil) {
			effectView = [[objc_getClass("UIVisualEffectView") alloc]init];
		} else {
			effectView = (UIVisualEffectView *)[UIView new];
		}
		effectView.alpha = 1.0f;
		effectView.frame = imageView.bounds;
		[imageView addSubview:effectView];
		
		[UIView animateWithDuration:speed animations:^{
			//effectView.alpha = 1.0f;
			if(objc_getClass("UIBlurEffect") != nil) {
				effectView.effect = [objc_getClass("UIBlurEffect") effectWithStyle:(UIBlurEffectStyle)((animType==9)?3:0)];
			}
		} completion:^(BOOL finished) {
			dispatch_after(dispatch_time(DISPATCH_TIME_NOW, speed * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
				springboardWindow.hidden = YES;
				[self restoreFrames];
				[effectView removeFromSuperview];
			});
		}];
	} else {
		[UIView animateWithDuration:speed animations:^{
			imageView.frame = newFrameImage;
			backView.frame = newFrameBack;
			imageView.transform = newTransformImage;
			backView.transform = newTransformBack;
		} completion:^(BOOL finished) {
			dispatch_after(dispatch_time(DISPATCH_TIME_NOW, speed * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
				springboardWindow.hidden = YES;
				[self restoreFrames];
			});
		}];
	}
}
@end



static void settingsChanged(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo)
{
	@autoreleasepool {		
		NSDictionary *TweakPrefs = [[[NSDictionary alloc] initWithContentsOfFile:@PLIST_PATH_Settings]?:[NSDictionary dictionary] copy];
		Enabled = (BOOL)[[TweakPrefs objectForKey:@"Enabled"]?:@YES boolValue];
		animType = (int)[[TweakPrefs objectForKey:@"animType"]?:@(0) intValue];
		speedFactor = (float)[@(1.0f) floatValue] - [[TweakPrefs objectForKey:@"speedFactor"]?:@(0.5f) floatValue];
	}
}

%ctor
{
	CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, settingsChanged, CFSTR("com.julioverne.lockanim/Settings"), NULL, CFNotificationSuspensionBehaviorCoalesce);
	settingsChanged(NULL, NULL, NULL, NULL, NULL);
	%init;
}