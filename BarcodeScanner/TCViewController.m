//
//  TCViewController.m
//  BarcodeScanner
//
//  Created by James Frye on 1/23/14.
//  Copyright (c) 2014 James Frye. All rights reserved.
//

#import <AVFoundation/AVFoundation.h>
#import "TCViewController.h"

@interface TCViewController () <AVCaptureMetadataOutputObjectsDelegate>

@property (strong, nonatomic) AVCaptureSession* session;
@property (strong, nonatomic) AVCaptureVideoPreviewLayer *previewLayer;
@property (strong,nonatomic) AVCaptureMetadataOutput *metadataOutput;

@end

@implementation TCViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	
    self.session = [AVCaptureSession new];
    [self.session setSessionPreset:AVCaptureSessionPreset640x480];
    
    [self updateCameraSelection];
    
    CALayer *rootLayer = self.view.layer;

    self.previewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:self.session];
    [self.previewLayer setBackgroundColor:[[UIColor blackColor] CGColor]];
    [self.previewLayer setVideoGravity:AVLayerVideoGravityResizeAspectFill];
    
    [self.previewLayer setFrame:[rootLayer frame]];
    
    [rootLayer addSublayer:self.previewLayer];
    
    [self setupBarcodeDetection];
    
    [self.session startRunning];
}

- (void)setupBarcodeDetection {
    self.metadataOutput = [AVCaptureMetadataOutput new];
    if ( ! [self.session canAddOutput:self.metadataOutput] ) {
        [self teardownBarcodeDetection];
        return;
    }
    
    [self.metadataOutput setMetadataObjectsDelegate:self queue:dispatch_get_main_queue()];
    [self.session addOutput:self.metadataOutput];
    
    if ( ! [self.metadataOutput.availableMetadataObjectTypes containsObject:AVMetadataObjectTypeEAN13Code] ) {
        [self teardownBarcodeDetection];
        return;
    }
    
    self.metadataOutput.metadataObjectTypes = @[AVMetadataObjectTypeEAN13Code];
}

- (void) updateCameraSelection {
    // Changing the camera device will reset connection state, so we call the
    // update*Detection functions to resync them.  When making multiple
    // session changes, wrap in a beginConfiguration / commitConfiguration.
    // This will avoid consecutive session restarts for each configuration
    // change (noticeable delay and camera flickering)
    
    [self.session beginConfiguration];
    
    // have to remove old inputs before we test if we can add a new input
    NSArray* oldInputs = [self.session inputs];
    
    for (AVCaptureInput *oldInput in oldInputs)
        [self.session removeInput:oldInput];
    
    AVCaptureDeviceInput* input = [self pickCamera];
    if ( ! input ) {
        // failed, restore old inputs
        for (AVCaptureInput *oldInput in oldInputs)
            [self.session addInput:oldInput];
    } else {
        // succeeded, set input and update connection states
        [self.session addInput:input];
    }
    
    [self.session commitConfiguration];
}

- (AVCaptureDeviceInput*) pickCamera {
    AVCaptureDevicePosition desiredPosition = AVCaptureDevicePositionBack;
    BOOL hadError = NO;
    
    for (AVCaptureDevice *d in [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo]) {
        if ([d position] == desiredPosition) {
            NSError *error = nil;
            [d lockForConfiguration:&error];
            if ([d isAutoFocusRangeRestrictionSupported]){
                [d setAutoFocusRangeRestriction:AVCaptureAutoFocusRangeRestrictionNear];
            }
            
            [d unlockForConfiguration];
            AVCaptureDeviceInput *input = [AVCaptureDeviceInput deviceInputWithDevice:d error:&error];
            if (error) {
                hadError = YES;
            } else if ( [self.session canAddInput:input] ) {
                return input;
            }
        }
    }
    
    if ( ! hadError ) {
        // no errors, simply couldn't find a matching camera
    }
    
    return nil;
}

- (void)teardownBarcodeDetection {
    if ( self.metadataOutput ) {
        [self.session removeOutput:self.metadataOutput];
    }
}

- (void) captureOutput:(AVCaptureOutput *)captureOutput didOutputMetadataObjects:(NSArray *)faces fromConnection:(AVCaptureConnection *)connection {
    
    [self teardownBarcodeDetection];
    
    AVMetadataMachineReadableCodeObject *barcode = faces[0];
    
    NSLog(@"The value is %@", barcode.stringValue);
}


@end
