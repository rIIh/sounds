/*
 * This file is part of Sounds .
 *
 *   Sounds  is free software: you can redistribute it and/or modify
 *   it under the terms of the Lesser GNU General Public License
 *   version 3 (LGPL3) as published by the Free Software Foundation.
 *
 *   Sounds  is distributed in the hope that it will be useful,
 *   but WITHOUT ANY WARRANTY; without even the implied warranty of
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *   GNU General Public License for more details.
 *
 *   You should have received a copy of the Lesser GNU General Public License
 *   along with Sounds .  If not, see <https://www.gnu.org/licenses/>.
 */

#import <Flutter/Flutter.h>

@interface Track : NSObject
{
    NSString *path;
    NSString *title;
    NSString *artist;
    NSString *albumArtUrl;
    NSString *albumArtAsset;
    FlutterStandardTypedData *dataBuffer;
}

@property(nonatomic, retain) NSString *path;
@property(nonatomic, retain) NSString *title;
@property(nonatomic, retain) NSString *artist;
@property(nonatomic, retain) NSString *albumArtUrl;
@property(nonatomic, retain) NSString *albumArtAsset;
@property(nonatomic, retain) NSString *albumArtFile;
@property(nonatomic, retain) FlutterStandardTypedData *dataBuffer;

- (id)initFromJson:(NSString *)jsonString;
- (id)initFromDictionary:(NSDictionary *)jsonData;
- (bool)isUsingPath;

@end
