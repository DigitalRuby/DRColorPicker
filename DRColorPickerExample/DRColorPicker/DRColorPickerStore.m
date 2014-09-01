//
//  DRColorPickerStore.m
//
//  Created by Jeff on 8/10/14.
//  Copyright (c) 2014 Digital Ruby, LLC. All rights reserved.
//
/*
 The MIT License (MIT)

 Copyright (c) <year> <copyright holders>

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

#import <CommonCrypto/CommonDigest.h>
#import "DRColorPickerStore.h"
#import "DRColorPicker.h"
#import <MobileCoreServices/MobileCoreServices.h>

@import ImageIO;

#define DR_COLOR_PICKER_FIND_AND_REPLACE_OPTION_COPY_ONLY 0
#define DR_COLOR_PICKER_FIND_AND_REPLACE_OPTION_MOVE_TO_FRONT 1
#define DR_COLOR_PICKER_FIND_AND_REPLACE_OPTION_KEEP_IN_PLACE 2
#define DR_COLOR_PICKER_FIND_AND_REPLACE_OPTION_DELETE 3

static DRColorPickerStore* s_instance;
static CGFloat s_thumbnailSizePixels;
static CGFloat s_thumbnailSizePoints;

@interface DRColorPickerStore ()

// for fast thumbnail retrieval
@property (nonatomic, strong, readonly) NSCache* cache;

// turn off saving if bulk creating colors, must manually call save when done
@property (nonatomic, assign) BOOL disableSave;

@end

@implementation DRColorPickerStore

+ (void) initialize
{
    if (self == DRColorPickerStore.class)
    {
        s_instance = [[DRColorPickerStore alloc] initAsSingleton];

        s_thumbnailSizePixels = (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad ? (UIScreen.mainScreen.scale * DRColorPickerThumbnailSizeInPointsPad) : (UIScreen.mainScreen.scale * DRColorPickerThumbnailSizeInPointsPhone));
        s_thumbnailSizePoints = s_thumbnailSizePixels / UIScreen.mainScreen.scale;
    }
}

+ (instancetype) sharedInstance
{
    return s_instance;
}

+ (CGFloat) thumbnailSizePixels
{
    return s_thumbnailSizePixels;
}

+ (CGFloat) thumbnailSizePoints
{
    return s_thumbnailSizePoints;
}

+ (NSString*) md5Data:(NSData*)input
{
    unsigned char digest[16];
    CC_MD5(input.bytes, (CC_LONG)input.length, digest);
    NSMutableString* output = [NSMutableString stringWithCapacity:CC_MD5_DIGEST_LENGTH * 2];
    for (NSInteger i = 0; i < CC_MD5_DIGEST_LENGTH; i++)
    {
        [output appendFormat:@"%02x", digest[i]];
    }
    return  output;
}

+ (NSString*) md5Image:(UIImage*)image
{
    CFDataRef rawData = CGDataProviderCopyData(CGImageGetDataProvider(image.CGImage));
    NSData* bytes = (__bridge_transfer NSData*)rawData;

    return [self md5Data:bytes];
}

+ (NSData*) convertToJPEG2000:(UIImage*)image withQuality:(CGFloat)quality
{
    NSMutableData* d = [NSMutableData data];
    CGImageDestinationRef destinationRef = CGImageDestinationCreateWithData((__bridge CFMutableDataRef)d, kUTTypeJPEG2000, 1, NULL);
    CGImageDestinationAddImage(destinationRef, image.CGImage, (__bridge CFDictionaryRef)@
    {
        (__bridge NSString*)kCGImageDestinationLossyCompressionQuality: @(quality)
    });

    if (!CGImageDestinationFinalize(destinationRef))
    {
        d = nil;
    }
    CFRelease(destinationRef);

    return d;
}

+ (UIImage*) resizeImage:(UIImage*)image toSize:(CGFloat)size clipPath:(UIBezierPath*)clipPath
{
    if (image.size.width < size && image.size.height < size)
    {
        return image;
    }

    UIGraphicsBeginImageContextWithOptions(CGSizeMake(size, size), YES, 1.0f);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGContextSetInterpolationQuality(ctx, kCGInterpolationHigh);
    if (clipPath != nil)
    {
        [clipPath addClip];
    }
    [image drawAtPoint:CGPointZero blendMode:kCGBlendModeCopy alpha:1.0f];
    UIImage* scaledImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return scaledImage;
}

- (NSString *) rootDirectory
{
    NSArray* paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString* basePath = ([paths count] > 0 ? [paths objectAtIndex:0] : nil);
    return [basePath stringByAppendingPathComponent:@"DRColorPicker"];
}

- (id) init
{
    NSAssert(NO, @"Use sharedInstance");

    return nil;
}

- (id) initAsSingleton
{
    if ((self = [super init]) == nil) { return nil; }

    _cache = [[NSCache alloc] init];
    _recentColors = [NSMutableArray array];
    _favoriteColors = [NSMutableArray array];

    NSFileManager* f = [[NSFileManager alloc] init];
    [f createDirectoryAtPath:[self rootDirectory] withIntermediateDirectories:YES attributes:nil error:nil];
    [self migrateColors];

    return self;
}

- (void) migrateColors
{
    NSString* fileName = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)[0] stringByAppendingPathComponent:@"neoFavoriteColors.data"];
    NSFileManager* fileManager = [[NSFileManager alloc] init];
    if ([fileManager isReadableFileAtPath:fileName])
    {
        NSMutableOrderedSet* set = [[NSMutableOrderedSet alloc] initWithOrderedSet:[NSKeyedUnarchiver unarchiveObjectWithFile:fileName]];
        [fileManager removeItemAtPath:fileName error:nil];

        self.disableSave = YES;
        for (UIColor* color in set)
        {
            [self createColorWithColor:color list:DRColorPickerStoreListFavorites moveToFront:NO];
        }
        self.disableSave = NO;

        [self saveColorSettings];
    }
}

- (NSString*) fullPathForColor:(DRColorPickerColor*)color
{
    return [self fullPathForHash:color.fullImageHash];
}

- (NSString*) fullPathForHash:(NSString*)hash
{
    if (hash.length != 0)
    {
        NSString* path = [[[self rootDirectory] stringByAppendingPathComponent:hash] stringByAppendingString:@"_full.img"];
        return path;
    }
    return nil;
}

- (NSString*) thumbnailPathForHash:(NSString*)hash
{
    if (hash.length != 0)
    {
        NSString* path = [[[self rootDirectory] stringByAppendingPathComponent:hash] stringByAppendingString:@"_thumb.img"];
        return path;
    }
    return nil;
}

- (NSString*) thumbnailPathForColor:(DRColorPickerColor*)color
{
    return [self thumbnailPathForHash:color.fullImageHash];
}

- (void) loadColorSettings
{
    NSString* settingsFilePath = [[self rootDirectory] stringByAppendingPathComponent:DR_COLOR_PICKER_SETTINGS_FILE_NAME];
    NSData* settings = [NSData dataWithContentsOfFile:settingsFilePath];

    if (settings.length == 0)
    {
        return;
    }

    NSError* error;
    NSDictionary* json = [NSJSONSerialization JSONObjectWithData:settings options:0 error:&error];
    if (error != nil)
    {
        NSLog(@"Error reading DRColorPickerStore settings: %@", error);
        return;
    }

    NSArray* recentColors = (NSArray*)json[@"Recent"];
    for (NSDictionary* d in recentColors)
    {
        [(NSMutableArray*)self.recentColors addObject:[[DRColorPickerColor alloc] initWithDictionary:d]];
    }

    NSArray* favoriteColors = (NSArray*)json[@"Favorites"];
    for (NSDictionary* d in favoriteColors)
    {
        [(NSMutableArray*)self.favoriteColors addObject:[[DRColorPickerColor alloc] initWithDictionary:d]];
    }
}

- (void) saveColorSettings
{
    if (self.disableSave)
    {
        return;
    }

    NSMutableDictionary* json = [NSMutableDictionary dictionary];
    NSString* settingsFilePath = [[self rootDirectory] stringByAppendingPathComponent:DR_COLOR_PICKER_SETTINGS_FILE_NAME];

    NSMutableArray* recents = [NSMutableArray array];
    json[@"Recent"] = recents;
    for (DRColorPickerColor* c in self.recentColors)
    {
        [recents addObject:[c dictionary]];
    }

    NSMutableArray* favorites = [NSMutableArray array];
    json[@"Favorites"] = favorites;
    for (DRColorPickerColor* c in self.favoriteColors)
    {
        [favorites addObject:[c dictionary]];
    }

#if DEBUG

    NSData* jsonData = [NSJSONSerialization dataWithJSONObject:json options:NSJSONWritingPrettyPrinted error:nil];

#else

    NSData* jsonData = [NSJSONSerialization dataWithJSONObject:json options:0 error:nil];

#endif

    [jsonData writeToFile:settingsFilePath atomically:YES];
}

- (NSInteger) findColor:(DRColorPickerColor*)color inArray:(NSArray*)array alphaMatch:(BOOL*)alphaMatch
{
    NSAssert(alphaMatch != NULL, @"Bool pointer must be allocated");

    NSInteger nonAlphaIndex = NSNotFound;

    for (NSInteger i = 0; i < array.count; i++)
    {
        DRColorPickerColor* c = (DRColorPickerColor*)array[i];
        if ((color.rgbColor != nil && c.rgbColor != nil && color.rgbColor.rgbHex == c.rgbColor.rgbHex) ||
            (color.fullImageHash.length != 0 && c.fullImageHash.length != 0 && [color.fullImageHash isEqualToString:c.fullImageHash]))
        {
            if (c.alpha == color.alpha)
            {
                *alphaMatch = YES;
                return i;
            }
            else if (nonAlphaIndex == NSNotFound)
            {
                nonAlphaIndex = i;
            }
        }
    }

    *alphaMatch = NO;
    return nonAlphaIndex;
}

- (DRColorPickerColor*) findAndReplaceColor:(DRColorPickerColor*)color array:(NSMutableArray*)array option:(NSInteger)option
{
    BOOL alphaMatch;
    NSInteger i = [self findColor:color inArray:array alphaMatch:&alphaMatch];
    if (i != NSNotFound)
    {
        DRColorPickerColor* found = (DRColorPickerColor*)array[i];
        [found clearImages];
        [color clearImages];

        // create a copy so that changes to the color do not modify the color already in the list
        DRColorPickerColor* clone = [[DRColorPickerColor alloc] initWithClone:color];

        if (alphaMatch)
        {
            // we matched on alpha, this is an exact match. we will either leave the color where it is or move it to the front
            if (option == DR_COLOR_PICKER_FIND_AND_REPLACE_OPTION_MOVE_TO_FRONT)
            {
                // move color to the front of the array
                [array removeObjectAtIndex:i];
                [array insertObject:clone atIndex:0];
            }
            else if (option == DR_COLOR_PICKER_FIND_AND_REPLACE_OPTION_DELETE)
            {
                [array removeObjectAtIndex:i];
            }
        }
        else
        {
            // we matched, but not on alpha so we have to add a new color either at the front or at the end
            if (option == DR_COLOR_PICKER_FIND_AND_REPLACE_OPTION_MOVE_TO_FRONT)
            {
                [array insertObject:clone atIndex:0];
            }
            else if (option == DR_COLOR_PICKER_FIND_AND_REPLACE_OPTION_KEEP_IN_PLACE)
            {
                [array addObject:clone];
            }
        }

        return color;
    }

    return nil;
}

- (DRColorPickerColor*) findAndReplaceColor:(DRColorPickerColor*)color array:(NSMutableArray*)array moveToFront:(BOOL)moveToFront
{
    // see if this color is in the desired array
    NSInteger option = (moveToFront ? DR_COLOR_PICKER_FIND_AND_REPLACE_OPTION_MOVE_TO_FRONT : DR_COLOR_PICKER_FIND_AND_REPLACE_OPTION_KEEP_IN_PLACE);
    DRColorPickerColor* foundColor = [self findAndReplaceColor:color array:array option:option];

    // if the colors is in the array, we are done
    if (foundColor != nil)
    {
        return foundColor;
    }

    // check other arrays to see if we can re-use the color in the desired list
    for (NSMutableArray* otherArray in @[ self.favoriteColors, self.recentColors ])
    {
        if (otherArray != array)
        {
            // try and re-use color from this array
            foundColor = [self findAndReplaceColor:color array:otherArray option:DR_COLOR_PICKER_FIND_AND_REPLACE_OPTION_COPY_ONLY];
            if (foundColor != nil)
            {
                break;
            }
        }
    }

    // if we didn't find the color in any array, assign the passed in color
    if (foundColor == nil)
    {
        foundColor = [[DRColorPickerColor alloc] initWithClone:color];
    }

    // add the color to the requested array
    if (moveToFront)
    {
        [array insertObject:foundColor atIndex:0];
    }
    else
    {
        [array addObject:foundColor];
    }

    return color;
}

- (NSArray*) colorsForList:(DRColorPickerStoreList)list
{
    if (list == DRColorPickerStoreListRecent)
    {
        return self.recentColors;
    }
    else if (list == DRColorPickerStoreListFavorites)
    {
        return self.favoriteColors;
    }
    return nil;
}

- (void) removeFiles:(DRColorPickerColor*)c
{
    if (c.fullImageHash.length != 0)
    {
        NSFileManager* f = [[NSFileManager alloc] init];
        NSString* path = [self thumbnailPathForColor:c];
        [f removeItemAtPath:path error:nil];
        path = [self fullPathForColor:c];
        [f removeItemAtPath:path error:nil];
    }
}

- (DRColorPickerColor*) createColorWithColor:(UIColor*)color list:(DRColorPickerStoreList)list moveToFront:(BOOL)moveToFront
{
    NSAssert(color != nil, @"Color is required");

    // get the first array to check
    NSMutableArray* array = (NSMutableArray*)[self colorsForList:list];
    DRColorPickerColor* drColor = [[DRColorPickerColor alloc] initWithColor:color];

    // find or create the color
    DRColorPickerColor* existing = [self findAndReplaceColor:drColor array:array moveToFront:moveToFront];

    while (array.count > DRColorPickerStoreMaxColors)
    {
        DRColorPickerColor* c = (DRColorPickerColor*)[array lastObject];
        [self deleteColor:c fromList:list];
    }

    return existing;
}

- (DRColorPickerColor*) createColorWithImage:(DRColorPickerColor*)color list:(DRColorPickerStoreList)list moveToFront:(BOOL)moveToFront
{
    NSAssert(color.image != nil && color.thumbnailImage != nil, @"Image is required");

    // get the first array to check
    NSMutableArray* array = (NSMutableArray*)[self colorsForList:list];

    // if we don't have a full image yet, make one so we can check if we already exist
    if (color.fullImageHash.length == 0)
    {
        color.fullImageHash = [DRColorPickerStore md5Image:color.image];
        NSString* fullPath = [self fullPathForHash:color.fullImageHash];
        if (![[[NSFileManager alloc] init] fileExistsAtPath:fullPath])
        {
            if (DRColorPickerUsePNG)
            {
                NSData* compressedData = UIImagePNGRepresentation(color.image);
                [compressedData writeToFile:fullPath atomically:YES];
            }
            else
            {
                // since we have lossless compression, we have to re-compute the hash
                NSData* compressedData = [DRColorPickerStore convertToJPEG2000:color.image withQuality:DRColorPickerJPEG2000Quality];
                UIImage* recomputeHashImage = [UIImage imageWithData:compressedData];
                DRColorPickerColor* normalizedColor = [[DRColorPickerColor alloc] initWithImage:recomputeHashImage];
                color.fullImageHash = [DRColorPickerStore md5Image:normalizedColor.image];
                fullPath = [self fullPathForHash:color.fullImageHash];
                if (![[[NSFileManager alloc] init] fileExistsAtPath:fullPath])
                {
                    [compressedData writeToFile:fullPath atomically:YES];
                }
            }

            // generate the thumbnail as well
            NSString* thumbPath = [self thumbnailPathForHash:color.fullImageHash];
            if (![[[NSFileManager alloc] init] fileExistsAtPath:thumbPath])
            {
                NSData* pngData = UIImagePNGRepresentation(color.thumbnailImage);
                [pngData writeToFile:thumbPath atomically:YES];
            }
        }
    }

    color = [self findAndReplaceColor:color array:array moveToFront:moveToFront];
    while (array.count > DRColorPickerStoreMaxColors)
    {
        DRColorPickerColor* c = (DRColorPickerColor*)[array lastObject];
        [self deleteColor:c fromList:list];
    }

    return color;
}

- (void) upsertColor:(DRColorPickerColor*)color list:(DRColorPickerStoreList)list moveToFront:(BOOL)moveToFront
{
    if (color.rgbColor == nil)
    {
        [self createColorWithImage:color list:list moveToFront:YES];
    }
    else
    {
        [self createColorWithColor:color.rgbColor list:list moveToFront:YES];
    }
}

- (void) deleteColor:(DRColorPickerColor*)color fromList:(DRColorPickerStoreList)list
{
    NSArray* array = [self colorsForList:list];
    [self findAndReplaceColor:color array:(NSMutableArray*)array option:DR_COLOR_PICKER_FIND_AND_REPLACE_OPTION_DELETE];

    // if this was an image, we need to check if anyone else is referencing the image - if not we nuke it
    if (color.rgbColor == nil)
    {
        BOOL foundMatchingImage = NO;
        for (DRColorPickerColor* c in [self.favoriteColors arrayByAddingObjectsFromArray:self.recentColors])
        {
            if ([c.fullImageHash isEqualToString:color.fullImageHash])
            {
                foundMatchingImage = YES;
                break;
            }
        }

        if (!foundMatchingImage)
        {
            [self removeFiles:color];
        }
    }
}

- (UIImage*) thumbnailImageForHash:(NSString*)hash
{
    NSString* thumbnailPath = [self thumbnailPathForHash:hash];
    UIImage* fileThumbnail = [UIImage imageWithContentsOfFile:thumbnailPath];

    NSAssert(fileThumbnail != nil, @"Must call createColor first");

    [self.cache setObject:fileThumbnail forKey:hash];

    return fileThumbnail;
}

- (UIImage*) thumbnailImageForColor:(DRColorPickerColor*)color completion:(DRColorPickerStoreThumbnailCompletionBlock)completion
{
    if (color.rgbColor != nil)
    {
        return nil;
    }
    else if (color.thumbnailImage != nil)
    {
        if (completion == nil)
        {
            return color.thumbnailImage;
        }
        completion(color.thumbnailImage);
        return nil;
    }

    NSString* hash = color.fullImageHash;
    UIImage* cachedThumbnail = (UIImage*)[self.cache objectForKey:hash];
    if (cachedThumbnail != nil)
    {
        if (completion == nil)
        {
            return cachedThumbnail;
        }
        else
        {
            dispatch_async(dispatch_get_main_queue(), ^
            {
                completion(cachedThumbnail);
            });
        }
        return nil;
    }

    dispatch_async(dispatch_get_global_queue(0, 0), ^
    {
        UIImage* fileThumbnail = [self thumbnailImageForHash:hash];
        dispatch_async(dispatch_get_main_queue(), ^
        {
            completion(fileThumbnail);
        });
    });

    return nil;
}

@end
