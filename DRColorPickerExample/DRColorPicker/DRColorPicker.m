//
//  DRColorPicker.m
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

#import "DRColorPicker.h"

CGFloat DRColorPickerThumbnailSizeInPointsPhone = 42.0f;
CGFloat DRColorPickerThumbnailSizeInPointsPad = 54.0f;
UIFont* DRColorPickerFont;
UIColor* DRColorPickerLabelColor;
UIColor* DRColorPickerBackgroundColor;
UIColor* DRColorPickerBorderColor;
NSInteger DRColorPickerStoreMaxColors = 200;
BOOL DRColorPickerUsePNG = NO;
CGFloat DRColorPickerJPEG2000Quality = 0.9f;

UIImage* DRColorPickerImage(NSString* subPath)
{
    if (subPath.length == 0)
    {
        return nil;
    }

    static NSCache* imageWithContentsOfFileCache;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken,
    ^{
        imageWithContentsOfFileCache = [[NSCache alloc] init];
    });
    NSString* fullPath = [@"DRColorPicker.bundle/" stringByAppendingString:subPath];
    UIImage* img = [UIImage imageNamed:fullPath];
    if (img == nil)
    {
        NSBundle* b = [NSBundle bundleWithPath:[[NSBundle bundleForClass:DRColorPickerViewController.class] pathForResource:@"DRColorPicker" ofType:@"bundle"]];
        fullPath = [[b.bundlePath stringByAppendingString:@"/"] stringByAppendingString:subPath];
        img = [UIImage imageNamed:fullPath];
        if (img == nil)
        {
            img = (UIImage*)[imageWithContentsOfFileCache objectForKey:subPath];
            if (img == nil)
            {
                img = [UIImage imageWithContentsOfFile:fullPath];
                if (img != nil)
                {
                    [imageWithContentsOfFileCache setObject:img forKey:subPath];
                }
            }
        }
    }
    
    return img;
}
