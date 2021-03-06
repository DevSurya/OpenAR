//
//  OARViewController.m
//  OpenAR
//
//  Created by Cameron Palmer on 20.03.15.
//  Copyright (c) 2015 OAR. All rights reserved.
//

#import "OARViewController.h"

#import <ImageIO/ImageIO.h>

#import "OARMarkerDetector.h"
#import "OARFramemarkerJSON.h"
#import "OARLogger.h"

static NSString *const kFramemarkerCatalog = @"markers.json";



@interface OARViewController () <OARMarkerDetectorDelegate>
@property (strong, nonatomic) OARMarkerDetector *markerDetector;
@property (assign, nonatomic) CGFloat scalingFactor;
@property (assign, nonatomic) OARCameraPosition cameraPosition;
@property (assign, nonatomic) OARCameraResolution cameraResolution;
@property (assign, nonatomic, getter=isBackgroundFullScreen) BOOL backgroundFillScreen;
@property (assign, nonatomic, getter=isObservingAutofocus) BOOL observingAutofocus;

@end



@implementation OARViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    OARMarkerDetector *markerDetector = [[OARMarkerDetector alloc] init];
    markerDetector.delegate = self;
//    [markerDetector start];
    self.markerDetector = markerDetector;

//    self.videoSource = [[OARVideoSource alloc] init];
//    self.cameraResolution = OARCameraResolutionVGA;
//    self.cameraPosition = OARCameraPositionBack;
//    self.backgroundFillScreen = NO;
//    [self.videoSource addObserver:self];
//    [self.videoSource startVideoSource];
}

- (void)didUpdateCameraSize:(CGSize)cameraSize
{
    float screenWidth = self.view.bounds.size.width;
    float screenHeight = self.view.bounds.size.height;
    float screenAspectRatio = screenWidth / screenHeight;
    float imageWidth = cameraSize.width;
    float imageHeight = cameraSize.height;
    float imageAspectRatio = imageWidth / imageHeight;

    float scalingFactor;
    if (/* DISABLES CODE */ (NO)) {
        if (screenAspectRatio > imageAspectRatio) {
            scalingFactor = screenWidth / imageWidth;
        } else {
            scalingFactor = screenHeight / imageHeight;
        }
    } else {
        if (screenAspectRatio > imageAspectRatio) {
            scalingFactor =  screenHeight / imageHeight;
        } else {
            scalingFactor = screenWidth / imageWidth;
        }
    }

    self.scalingFactor = scalingFactor;
}


#pragma mark - 

- (void)didStartMarkerDetector:(OARMarkerDetector *)markerDetector
{
    [markerDetector startCameraWithPosition:self.cameraPosition resolution:self.cameraResolution];
}

- (void)didPauseMarkerDetector:(OARMarkerDetector *)markerDetector
{
    DDLogDebug(@"%s", __PRETTY_FUNCTION__);
}

- (void)didResumeMarkerDetector:(OARMarkerDetector *)markerDetector
{
    DDLogDebug(@"%s", __PRETTY_FUNCTION__);
}

- (void)didStartCameraWithPosition:(OARCameraPosition)cameraPosition resolution:(OARCameraResolution)resolution
{
    [self.markerDetector startTrackingFramemarkers:[self framemarkersCatalog]];
}

- (void)didStopCamera
{
    DDLogDebug(@"%s", __PRETTY_FUNCTION__);
}

- (void)didStartTrackingForFramemarkers:(NSArray *)framemarkers
{
    DDLogDebug(@"%s", __PRETTY_FUNCTION__);
}

- (void)didUpdateCameraImages:(NSArray *)cameraImages
{
    DDLogVerbose(@"Received %d images.", [cameraImages count]);
}

- (void)didUpdateMarkerDetectorResults:(NSArray *)framemarkers
{
    DDLogVerbose(@"Received %d results.", [framemarkers count]);
}

#pragma mark - OARVideoSourceDelegate methods

- (void)didUpdateVideoImage:(CIImage *)videoImage
{
    CIImage *scaledImage = [videoImage imageByApplyingTransform:CGAffineTransformMakeScale(self.scalingFactor, self.scalingFactor)];

    UIImage *orientedImage = nil;
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        orientedImage = [UIImage imageWithCIImage:scaledImage scale:1.f orientation:UIImageOrientationUp];
    } else {
        orientedImage = [UIImage imageWithCIImage:scaledImage scale:1.f orientation:UIImageOrientationDown];
    }

    self.imageView.image = orientedImage;
}



#pragma mark - IBActions

- (IBAction)didPressCameraSwitchButton:(id)sender
{
    UIViewAnimationOptions animation;
    OARCameraPosition position = OARCameraPositionUnknown;
    switch (self.cameraPosition) {
        case OARCameraPositionFront:
            animation = UIViewAnimationOptionTransitionFlipFromRight;
            position = OARCameraPositionBack;
            break;
        case OARCameraPositionBack:
            animation = UIViewAnimationOptionTransitionFlipFromLeft;
            position = OARCameraPositionFront;
            break;
        case OARCameraPositionUnknown:
            animation = UIViewAnimationOptionTransitionNone;
            position = OARCameraPositionBack;
            break;
    }

    self.cameraPosition = position;

    [self updateCameraSceneWithCheckerboard];
    [UIView transitionWithView:self.imageView duration:1.f options:animation animations:nil completion:NULL];
}

- (IBAction)didPressBackgroundFillScreenButton:(id)sender
{
    self.backgroundFillScreen = !self.isBackgroundFullScreen;
}

- (IBAction)didPressCameraResolutionButton:(id)sender
{
    self.cameraResolution = [self nextValidCameraResolution];
}



#pragma mark - Camera getters and setters

- (void)setBackgroundFillScreen:(BOOL)backgroundFillScreen
{
    NSString *backgroundFillScreenTitle;
    if (backgroundFillScreen) {
            backgroundFillScreenTitle = NSLocalizedString(@"Fill", @"Fill Screen");
    } else {
            backgroundFillScreenTitle = NSLocalizedString(@"Fit", @"Fit Screen");
    }

    [self.backgroundFillScreenButtonItem setTitle:backgroundFillScreenTitle];

    _backgroundFillScreen = backgroundFillScreen;
}

- (void)setCameraResolution:(OARCameraResolution)cameraResolution
{
    _cameraResolution = cameraResolution;

    NSString *cameraResolutionText;
    switch (cameraResolution) {
        case OARCameraResolutionVGA:
            cameraResolutionText = NSLocalizedString(@"VGA", @"Camera Resolution VGA");
            break;
        case OARCameraResolution720p:
            cameraResolutionText = NSLocalizedString(@"720p", @"Camera Resolution 720p");
            break;
        case OARCameraResolution1080p:
            cameraResolutionText = NSLocalizedString(@"1080p", @"Camera Resolution 1080p");
            break;
        case OARCameraResolutionUnknown:
            cameraResolutionText = NSLocalizedString(@"N/A", @"Camera Resolution Unknown");
            break;
    }

    [self.cameraResolutionButtonItem setTitle:cameraResolutionText];
}



- (void)updateCameraSceneWithCheckerboard
{
    //UIImage *checkerboardImage = [UIImage ntnu_checkerboardWithRect:[UIScreen mainScreen].bounds];
    //[self.smartScanBridge updateCameraSceneWithImage:checkerboardImage];
}

- (OARCameraResolution)nextValidCameraResolution
{
//    OARCameraResolution cameraResolutions = [self.videoSource availableCameraResolutions];
//    OARCameraResolution nextResolution = self.cameraResolution;
//    if (self.cameraResolution > log2f(cameraResolutions)) {
//        nextResolution = 0;
//    }
//
//    for (int i = 0; i < cameraResolutions; i++) {
//        int value = 1 << i;
//        if (value <= nextResolution) {
//            continue;
//        }
//
//        if (cameraResolutions && value) {
//            nextResolution = value;
//            break;
//        }
//    }
//
//    return nextResolution;
    return OARCameraResolutionUnknown;
}

- (NSArray *)framemarkersCatalog
{
    NSString *filename = [kFramemarkerCatalog stringByDeletingPathExtension];
    NSString *extension = [kFramemarkerCatalog pathExtension];

    NSURL *framemarkerCatalogURL = [[NSBundle mainBundle] URLForResource:filename withExtension:extension];
    NSData *framemarkerCatalogData = [NSData dataWithContentsOfURL:framemarkerCatalogURL];

    NSError *error;
    NSArray *framemarkerCatalog = [NSJSONSerialization JSONObjectWithData:framemarkerCatalogData options:NSJSONReadingAllowFragments error:&error];
    if (error != nil) {
        DDLogError(@"%@", error);
    }

    NSMutableArray *framemarkers = [[NSMutableArray alloc] initWithCapacity:[framemarkerCatalog count]];
    for (NSDictionary *framemarkerData in framemarkerCatalog) {
        OARFramemarker *framemarker = [[OARFramemarkerJSON alloc] initWithDictionary:framemarkerData];
        [framemarkers addObject:framemarker];
    }

    return [framemarkers copy];
}

@end
