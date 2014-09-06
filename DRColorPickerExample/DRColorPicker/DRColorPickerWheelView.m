//
//  DRColorPickerWheelView.h
//
//  Created by Jeff on 8/10/14.
//  Copyright (c) 2014 Digital Ruby, LLC. All rights reserved.
//
/*
 The MIT License (MIT)

 Copyright (c) 2014 Digital Ruby, LLC

 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:

 The above copyright notice and this permission notice shall be included in
 all copies or substantial portions of the Software.

 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 THE SOFTWARE.
 */

#import "DRColorPickerWheelView.h"
#import "DRColorPicker+UIColor.h"
#import "DRColorPicker.h"

@interface DRColorPickerWheelViewBrightnessView : UIView

@property (nonatomic, assign) CGGradientRef gradient;
@property (nonatomic, strong) UIColor* color;

@end

@implementation DRColorPickerWheelViewBrightnessView

- (void) setColor:(UIColor*)color
{
    if (_color != color)
    {
        _color = [color copy];
        [self setupGradient];
        [self setNeedsDisplay];
    }
}

- (void) setupGradient
{
	const CGFloat *c = CGColorGetComponents(_color.CGColor);
	CGFloat colors[] = { c[0], c[1], c[2], 1.0f, 0.0f, 0.0f, 0.0f, 1.0f };
	CGColorSpaceRef rgb = CGColorSpaceCreateDeviceRGB();

    if (self.gradient != NULL)
    {
        CGGradientRelease(self.gradient);
    }

	self.gradient = CGGradientCreateWithColorComponents(rgb, colors, NULL, sizeof(colors) / (sizeof(colors[0]) * 4));
	CGColorSpaceRelease(rgb);
}

- (void) drawRect:(CGRect)rect
{
	CGContextRef context = UIGraphicsGetCurrentContext();
	CGRect clippingRect = CGRectMake(0.0f, 0.0f, self.frame.size.width, self.frame.size.height);
	CGPoint endPoints[] = { CGPointMake(0.0f, 0.0f), CGPointMake(self.frame.size.width, 0.0f) };

	CGContextSaveGState(context);
	CGContextClipToRect(context, clippingRect);
	CGContextDrawLinearGradient(context, self.gradient, endPoints[0], endPoints[1], 0.0f);
	CGContextRestoreGState(context);
}

- (void) dealloc
{
    if (self.gradient != NULL)
    {
        CGGradientRelease(self.gradient);
    }
}

@end

CGFloat const DRColorPickerWheelViewGradientViewHeight = 40.0f;
CGFloat const DRColorPickerWheelViewGradientTopMargin = 20.0f;
CGFloat const DRColorPickerWheelViewDefaultMargin = 10.0f;
CGFloat const DRColorPickerWheelLabelWidth = 60.0f;
CGFloat const DRColorPickerWheelLabelHeight = 30.0f;
CGFloat const DRColorPickerWheelTextFieldWidth = 84.0f;
CGFloat const DRColorPickerWheelViewBrightnessIndicatorWidth = 16.0f;
CGFloat const DRColorPickerWheelViewBrightnessIndicatorHeight = 48.0f;
CGFloat const DRColorPickerWheelViewCrossHairshWidthAndHeight = 38.0f;

@interface DRColorPickerWheelView () <UITextFieldDelegate>

@property (nonatomic, strong) DRColorPickerWheelViewBrightnessView* brightnessView;
@property (nonatomic, strong) UIImageView* brightnessIndicator;
@property (nonatomic, strong) UIImageView* hueSaturationImage;
@property (nonatomic, strong) UIView* colorBubble;
@property (nonatomic, assign) CGFloat brightness;
@property (nonatomic, assign) CGFloat hue;
@property (nonatomic, assign) CGFloat saturation;
@property (nonatomic, strong) UILabel* rgbLabel;
@property (nonatomic, strong) UITextField* rgbTextField;
@property (nonatomic, strong) UIView* colorPreviewView;

@end

@implementation DRColorPickerWheelView

- (id) initWithFrame:(CGRect)f
{
    if ((self = [super initWithFrame:f]) == nil) { return nil; }

    self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self createViews];
    self.color = [UIColor redColor];

    return self;
}

- (void) createViews
{
    UIColor* borderColor = [UIColor colorWithWhite:0.0f alpha:0.1f];

    _rgbLabel = [[UILabel alloc] init];
    _rgbLabel.text = @"RGB: #";
    _rgbLabel.textAlignment = NSTextAlignmentCenter;
    _rgbLabel.textColor = UIColor.blackColor;
    _rgbLabel.shadowColor = UIColor.whiteColor;
    _rgbLabel.shadowOffset = CGSizeMake(0.0f, 1.0f);
    _rgbLabel.font = [DRColorPickerFont fontWithSize:16.0f];
    _rgbLabel.backgroundColor = UIColor.whiteColor;
    [self addSubview:_rgbLabel];

    _rgbTextField = [[UITextField alloc] init];
    _rgbTextField.textColor = UIColor.blackColor;
    _rgbTextField.backgroundColor = UIColor.whiteColor;
    _rgbTextField.layer.borderColor = borderColor.CGColor;
    _rgbTextField.layer.borderWidth = 1.0f;
    _rgbTextField.leftView = [[UIView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 9.0f, 1.0f)];
    _rgbTextField.leftViewMode = UITextFieldViewModeAlways;
    _rgbTextField.font = [UIFont fontWithName:@"Courier" size:18.0f];
    _rgbTextField.returnKeyType = UIReturnKeyDone;
    _rgbTextField.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter;
    _rgbTextField.delegate = self;
    [_rgbTextField addTarget:self action:@selector(textFieldChanged:) forControlEvents:UIControlEventEditingChanged];
    [self addSubview:_rgbTextField];

    _colorPreviewView = [[UIView alloc] init];
    _colorPreviewView.layer.borderWidth = 1.0f;
    _colorPreviewView.layer.borderColor = DRColorPickerBorderColor.CGColor;
    [self addSubview:_colorPreviewView];

    _hueSaturationImage = [[UIImageView alloc] initWithImage:DRColorPickerImage(@"images/common/drcolorpicker-colormap.png")];
    _hueSaturationImage.layer.borderWidth = 1.0f;
    _hueSaturationImage.layer.borderColor = borderColor.CGColor;
    [self addSubview:_hueSaturationImage];

    _brightnessView = [[DRColorPickerWheelViewBrightnessView alloc] init];
    _brightnessView.layer.borderWidth = 1.0f;
    _brightnessView.layer.borderColor = borderColor.CGColor;
    [self addSubview:_brightnessView];

    _colorBubble = [[UIView alloc] initWithFrame:CGRectMake(CGRectGetMidX(_brightnessView.frame), CGRectGetMidX(_brightnessView.frame),
                                                           DRColorPickerWheelViewCrossHairshWidthAndHeight, DRColorPickerWheelViewCrossHairshWidthAndHeight)];
    UIColor* bubbleBorderColor = [UIColor colorWithWhite:0.9 alpha:0.8];
    _colorBubble.layer.cornerRadius = DRColorPickerWheelViewCrossHairshWidthAndHeight * 0.5f;
    _colorBubble.layer.borderColor = bubbleBorderColor.CGColor;
    _colorBubble.layer.borderWidth = 2;
    _colorBubble.layer.shadowColor = [UIColor blackColor].CGColor;
    _colorBubble.layer.shadowOffset = CGSizeZero;
    _colorBubble.layer.shadowRadius = 1;
    _colorBubble.layer.shadowOpacity = 0.5f;
    _colorBubble.layer.shouldRasterize = YES;
    _colorBubble.layer.rasterizationScale = UIScreen.mainScreen.scale;
    [self addSubview:_colorBubble];

    _brightnessIndicator = [[UIImageView alloc] initWithFrame:CGRectMake(DRColorPickerWheelViewDefaultMargin, self.brightnessView.center.y,
                                                                         DRColorPickerWheelViewBrightnessIndicatorWidth, DRColorPickerWheelViewBrightnessIndicatorHeight)];
    _brightnessIndicator.image = DRColorPickerImage(@"images/common/drcolorpicker-brightnessguide.png");
    _brightnessIndicator.layer.shadowColor = [UIColor blackColor].CGColor;
    _brightnessIndicator.layer.shadowOffset = CGSizeZero;
    _brightnessIndicator.layer.shadowRadius = 1;
    _brightnessIndicator.layer.shadowOpacity = 0.8f;
    _brightnessIndicator.layer.shouldRasterize = YES;
    _brightnessIndicator.layer.rasterizationScale = UIScreen.mainScreen.scale;
    [self addSubview:_brightnessIndicator];
}

- (void) layoutSubviews
{
    [super layoutSubviews];

    self.rgbLabel.frame = CGRectMake(DRColorPickerWheelViewDefaultMargin, DRColorPickerWheelViewDefaultMargin, DRColorPickerWheelLabelWidth, DRColorPickerWheelLabelHeight);

    self.rgbTextField.frame = CGRectMake(DRColorPickerWheelViewDefaultMargin + DRColorPickerWheelLabelWidth,
                                         DRColorPickerWheelViewDefaultMargin,
                                         DRColorPickerWheelTextFieldWidth,
                                         DRColorPickerWheelLabelHeight);

    CGFloat previewX = DRColorPickerWheelViewDefaultMargin + DRColorPickerWheelLabelWidth + DRColorPickerWheelViewDefaultMargin + DRColorPickerWheelTextFieldWidth;
    self.colorPreviewView.frame = CGRectMake(previewX, DRColorPickerWheelViewDefaultMargin, self.frame.size.width - DRColorPickerWheelViewDefaultMargin - previewX, DRColorPickerWheelLabelHeight);


    self.hueSaturationImage.frame = CGRectMake(DRColorPickerWheelViewDefaultMargin,
                                               DRColorPickerWheelViewDefaultMargin + DRColorPickerWheelViewDefaultMargin + DRColorPickerWheelLabelHeight,
                                               CGRectGetWidth(self.frame) - (DRColorPickerWheelViewDefaultMargin * 2),
                                               CGRectGetHeight(self.frame) - DRColorPickerWheelViewGradientViewHeight - DRColorPickerWheelViewDefaultMargin - DRColorPickerWheelViewGradientTopMargin - DRColorPickerWheelViewDefaultMargin - DRColorPickerWheelLabelHeight);
    
    self.brightnessView.frame = CGRectMake(DRColorPickerWheelViewDefaultMargin,
                                         CGRectGetHeight(self.frame) - DRColorPickerWheelViewGradientViewHeight - DRColorPickerWheelViewDefaultMargin,
                                         CGRectGetWidth(self.frame) - (DRColorPickerWheelViewDefaultMargin * 2),
                                         DRColorPickerWheelViewGradientViewHeight);

    [self updateBrightnessPosition];
    [self updateColorBubblePosition];
}

- (void) textFieldChanged:(id)sender
{
    NSString* text = [self.rgbTextField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (text.length == 6)
    {
        UIColor* color = [UIColor colorWithHexString:text];
        if (color != nil)
        {
            [self setColor:color];
        }
    }
}

- (BOOL) textField:(UITextField*)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString*)string
{
    return ([textField.text stringByReplacingCharactersInRange:range withString:string].length <= 6);
}

- (BOOL) textFieldShouldReturn:(UITextField *)textField
{
    [textField resignFirstResponder];
    
    return NO;
}

- (void) setColor:(UIColor*)newColor
{
    if (![_color isEqual:newColor])
    {
        [newColor getHue:&_hue saturation:&_saturation brightness:&_brightness alpha:NULL];
        CGColorSpaceModel colorSpaceModel = newColor.colorSpaceModel;
        if (colorSpaceModel == kCGColorSpaceModelMonochrome && newColor != nil)
        {
            const CGFloat* c = CGColorGetComponents(newColor.CGColor);
            _color = [UIColor colorWithHue:0 saturation:0 brightness:c[0] alpha:1.0];
        }
        else
        {
            _color = [newColor copy];
        }
        
        if (self.colorChangedBlock != nil)
        {
            self.colorChangedBlock(self.color);
        }

        self.colorPreviewView.backgroundColor = newColor;
        NSString* hex = newColor.hexStringFromColorNoAlpha;
        if ([hex caseInsensitiveCompare:self.rgbTextField.text] != NSOrderedSame)
        {
            self.rgbTextField.text = hex;
        }

        [self updateBrightnessColor];
        [self updateBrightnessPosition];
        [self updateColorBubblePosition];
    }
}

- (void) updateBrightnessPosition
{
    [self.color getHue:nil saturation:nil brightness:&_brightness alpha:nil];
    
    CGPoint brightnessPosition;
    brightnessPosition.x = (1.0f - self.brightness) * self.brightnessView.frame.size.width + self.brightnessView.frame.origin.x;
    brightnessPosition.y = self.brightnessView.center.y;
    
    self.brightnessIndicator.center = brightnessPosition;
}

- (void) setColorBubblePosition:(CGPoint)p
{
    self.colorBubble.center = p;
}

- (void) updateColorBubblePosition
{
    CGPoint hueSatPosition;
    
    hueSatPosition.x = (self.hue * self.hueSaturationImage.frame.size.width) + self.hueSaturationImage.frame.origin.x;
    hueSatPosition.y = (1.0f - self.saturation) * self.hueSaturationImage.frame.size.height + self.hueSaturationImage.frame.origin.y;
    [self setColorBubblePosition:hueSatPosition];
    [self updateBrightnessColor];
}

- (void) updateBrightnessColor
{
    UIColor* brightnessColor = [UIColor colorWithHue:self.hue saturation:self.saturation brightness:1.0f alpha:1.0f];
    self.colorBubble.backgroundColor = brightnessColor;
	[self.brightnessView setColor:brightnessColor];
}

- (void) updateHueSatWithMovement:(CGPoint)position
{
	self.hue = (position.x - self.hueSaturationImage.frame.origin.x) / self.hueSaturationImage.frame.size.width;
	self.saturation = 1.0f -  (position.y - self.hueSaturationImage.frame.origin.y) / self.hueSaturationImage.frame.size.height;
    
	UIColor* topColor = [UIColor colorWithHue:self.hue saturation:self.saturation brightness:self.brightness alpha:1.0f];
    UIColor* gradientColor = [UIColor colorWithHue:self.hue saturation:self.saturation brightness:1.0f alpha:1.0f];
    self.colorBubble.backgroundColor = gradientColor;
    [self updateBrightnessColor];
    [self setColor:topColor];
}

- (void) updateBrightnessWithMovement:(CGPoint)position
{
	self.brightness = 1.0f - ((position.x - self.brightnessView.frame.origin.x) / self.brightnessView.frame.size.width);
	
	UIColor* topColor = [UIColor colorWithHue:self.hue saturation:self.saturation brightness:self.brightness alpha:1.0f];
    [self setColor:topColor];
}

- (void) touchesBegan:(NSSet*)touches withEvent:(UIEvent*)event
{
    [super touchesBegan:touches withEvent:event];

	for (UITouch* touch in touches)
    {
		[self handleTouchEvent:[touch locationInView:self]];
    }
}

- (void) touchesMoved:(NSSet*)touches withEvent:(UIEvent*)event
{
    [super touchesMoved:touches withEvent:event];

	for (UITouch* touch in touches)
    {
		[self handleTouchEvent:[touch locationInView:self]];
	}
}

- (void) handleTouchEvent:(CGPoint)position
{
	if (CGRectContainsPoint(self.hueSaturationImage.frame,position))
    {
        [self setColorBubblePosition:position];
		[self updateHueSatWithMovement:position];
	}
    else if (CGRectContainsPoint(self.brightnessView.frame, position))
    {
        self.brightnessIndicator.center = CGPointMake(position.x, self.brightnessView.center.y);
		[self updateBrightnessWithMovement:position];
	}
}

@end

