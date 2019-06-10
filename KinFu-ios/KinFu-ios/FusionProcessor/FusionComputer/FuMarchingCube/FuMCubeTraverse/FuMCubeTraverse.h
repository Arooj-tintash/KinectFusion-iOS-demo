//
//  FuMCubeTraverse.h
//  Scanner
//
//  Created by  沈江洋 on 10/01/2018.
//  Copyright © 2018  沈江洋. All rights reserved.
//

#import <AVFoundation/AVFoundation.h>
#import <QuartzCore/QuartzCore.h>
#import <Metal/Metal.h>
#import <simd/simd.h>

#import "MetalContext.h"
#import "FusionDefinition.h"

@interface FuMCubeTraverse : NSObject

- (instancetype)initWithContext: (MetalContext *)context;
- (int)compute:(id<MTLBuffer>)inTsdfVertexBuffer intoActiveVoxelInfo:(id<MTLBuffer>) outActiveVoxelInfoBuffer withMCubeParameter:(MCubeParameter)mCubeParameter;

@end
