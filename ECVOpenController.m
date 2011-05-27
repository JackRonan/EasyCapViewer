/* Copyright (c) 2011, Ben Trask
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:
    * Redistributions of source code must retain the above copyright
      notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright
      notice, this list of conditions and the following disclaimer in the
      documentation and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY BEN TRASK ''AS IS'' AND ANY
EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL BEN TRASK BE LIABLE FOR ANY
DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE. */
#import "ECVOpenController.h"

// Models
#import "ECVCaptureDocument.h"
#import "ECVAVEncoder.h"
#import "ECVStreamingServer.h"
#import "ECVVideoFormat.h"

// Other Sources
#import "ECVDebug.h"

@implementation ECVOpenController

#pragma mark -ECVOpenController

- (IBAction)open:(id)sender
{
	[NSApp stopModalWithCode:YES];
}
- (IBAction)quit:(id)sender
{
	[NSApp stopModalWithCode:NO];
}

#pragma mark -

- (void)runModal
{
	if(![NSApp runModalForWindow:[self window]]) return [NSApp terminate:nil];
	NSArray *const sources = [ECVVideoSource sources];
	ECVLog(ECVNotice, @"Recognized sources: %@", sources);
	if(![sources count]) {
		NSAlert *const alert = [[[NSAlert alloc] init] autorelease];
		[alert setMessageText:NSLocalizedString(@"No supported capture hardware was found.", nil)];
		[alert setInformativeText:NSLocalizedString(@"Please connect an EasyCap DC60/002 to your computer. Please note that the DC60+ is not supported.", nil)];
		[alert addButtonWithTitle:NSLocalizedString(@"OK", nil)];
		[alert runModal];
		return;
	}
	ECVCaptureDocument *const doc = [[[ECVCaptureDocument alloc] init] autorelease];
	ECVVideoStorage *const vs = [doc videoStorage];
	[vs setPixelFormat:kCVPixelFormatType_422YpCbCr8];
	[vs setPixelSize:(ECVIntegerSize){704 * 2, 480}];

	// FIXME: Yes, we REALLY shouldn't be hardcoding all of this.
	switch([inputPopUp selectedTag]) {
		case 1: { // 2 EasyCaps, Composite
			if([sources count] < 2) return;
			ECVVideoSource *const s1 = [sources objectAtIndex:0];
			ECVVideoSource *const s2 = [sources objectAtIndex:1];
			ECVVideoPipe *const p1 = [s1 videoPipeWithInput:[[s1 inputs] objectAtIndex:1]];
			ECVVideoPipe *const p2 = [s2 videoPipeWithInput:[[s2 inputs] objectAtIndex:1]];
			[p1 setPosition:(ECVIntegerPoint){0, 0}];
			[p2 setPosition:(ECVIntegerPoint){704, 0}];
			[vs addVideoPipe:p1];
			[vs addVideoPipe:p2];
			break;
		}
		case 2: { // 2 EasyCaps, S-Video
			if([sources count] < 2) return;
			ECVVideoSource *const s1 = [sources objectAtIndex:0];
			ECVVideoSource *const s2 = [sources objectAtIndex:1];
			ECVVideoPipe *const p1 = [s1 videoPipeWithInput:[[s1 inputs] objectAtIndex:0]];
			ECVVideoPipe *const p2 = [s2 videoPipeWithInput:[[s2 inputs] objectAtIndex:0]];
			[p1 setPosition:(ECVIntegerPoint){0, 0}];
			[p2 setPosition:(ECVIntegerPoint){704, 0}];
			[vs addVideoPipe:p1];
			[vs addVideoPipe:p2];
			break;
		}
		case 6: { // 2 EasyCaps, Composite, Anaglyph
			if([sources count] < 2) return;
			[vs setPixelFormat:kCVPixelFormatType_24RGB];
			[vs setPixelSize:(ECVIntegerSize){704, 480}];
			ECVVideoSource *const s1 = [sources objectAtIndex:0];
			ECVVideoSource *const s2 = [sources objectAtIndex:1];
			ECVVideoPipe *const p1 = [s1 videoPipeWithInput:[[s1 inputs] objectAtIndex:1]];
			ECVVideoPipe *const p2 = [s2 videoPipeWithInput:[[s2 inputs] objectAtIndex:1]];
			[p1 setExtraDrawingOptions:ECVDrawChannel1];
			[p2 setExtraDrawingOptions:ECVDrawChannel2 | ECVDrawChannel3];
			[vs addVideoPipe:p1];
			[vs addVideoPipe:p2];
			break;
		}
		case 7: { // 2 EasyCaps, Composite, Anaglyph, Mirrored
			if([sources count] < 2) return;
			[vs setPixelFormat:kCVPixelFormatType_24RGB];
			[vs setPixelSize:(ECVIntegerSize){704, 480}];
			ECVVideoSource *const s1 = [sources objectAtIndex:0];
			ECVVideoSource *const s2 = [sources objectAtIndex:1];
			ECVVideoPipe *const p1 = [s1 videoPipeWithInput:[[s1 inputs] objectAtIndex:1]];
			ECVVideoPipe *const p2 = [s2 videoPipeWithInput:[[s2 inputs] objectAtIndex:1]];
			[p1 setExtraDrawingOptions:ECVDrawChannel1 | ECVDrawMirroredVert];
			[p2 setExtraDrawingOptions:ECVDrawChannel2 | ECVDrawChannel3];
			[vs addVideoPipe:p1];
			[vs addVideoPipe:p2];
			break;
		}
		// FIXME: We can't support multiple simultaneous inputs from the 002. It just isn't happening.
		case 4: { // 1 EasyCap, S-Video
			if([sources count] < 1) return;
			ECVVideoSource *const s = [sources objectAtIndex:0];
			[vs addVideoPipe:[s videoPipeWithInput:[[s inputs] objectAtIndex:0]]];
			[vs setPixelSize:(ECVIntegerSize){704, 480}];
			break;
		}
		case 5: { // 1 EasyCap, Composite 1
			if([sources count] < 1) return;
			ECVVideoSource *const s = [sources objectAtIndex:0];
			[vs addVideoPipe:[s videoPipeWithInput:[[s inputs] objectAtIndex:1]]];
			[vs setPixelSize:(ECVIntegerSize){704, 480}];
			break;
		}
		case 8: { // 1 EasyCap, Composite 1, Mirrored X
			if([sources count] < 1) return;
			ECVVideoSource *const s = [sources objectAtIndex:0];
			ECVVideoPipe *const pipe = [s videoPipeWithInput:[[s inputs] objectAtIndex:1]];
			[pipe setExtraDrawingOptions:ECVDrawMirroredHorz];
			[vs addVideoPipe:pipe];
			[vs setPixelSize:(ECVIntegerSize){704, 480}];
			break;
		}
		case 9: { // 1 EasyCap, Composite 1, Mirrored Y
			if([sources count] < 1) return;
			ECVVideoSource *const s = [sources objectAtIndex:0];
			ECVVideoPipe *const pipe = [s videoPipeWithInput:[[s inputs] objectAtIndex:1]];
			[pipe setExtraDrawingOptions:ECVDrawMirroredVert];
			[vs addVideoPipe:pipe];
			[vs setPixelSize:(ECVIntegerSize){704, 480}];
			break;
		}
		default:
			ECVAssertNotReached(@"Invalid option.");
			return;
	}

	ECVVideoFormat *const format = [[formatPopUp selectedItem] representedObject];
	for(ECVVideoPipe *const pipe in [vs pipes]) [pipe setFormat:format];
	[vs setFrameRate:QTMakeTime([format frameRate].numer, [format frameRate].denom / 2)];
	[vs setSampleAspectRatio:[format sampleAspectRatioWithDisplayAspectRatio:(ECVRational){4, 3}]];

	ECVAVEncoder *const encoder = [[[ECVAVEncoder alloc] initWithStorages:[NSArray arrayWithObjects:vs, nil]] autorelease];
	ECVHTTPServer *const HTTPServer = [[[ECVHTTPServer alloc] initWithPort:3453] autorelease];
	ECVStreamingServer *const server = [[[ECVStreamingServer alloc] init] autorelease];
	[server setEncoder:encoder];
	[server setServer:HTTPServer];
	[doc addReceiver:server];

	[[NSDocumentController sharedDocumentController] addDocument:doc];
	[doc makeWindowControllers];
	[doc showWindows];
}

#pragma mark -NSWindowController

- (void)windowDidLoad
{
	[super windowDidLoad];

	NSTextStorage *const storage = [textView textStorage];
	[storage replaceCharactersInRange:NSMakeRange(0, [storage length]) withAttributedString:[[[NSAttributedString alloc] initWithPath:[[NSBundle bundleForClass:[self class]] pathForResource:@"Release Notes" ofType:@"rtf"] documentAttributes:NULL] autorelease]];

	// TODO: Select the default item in the input popup.

	NSMenu *const formatMenu = [formatPopUp menu];
	[formatMenu removeAllItems];
	NSMutableArray *const formats = [[[ECVVideoFormat formats] mutableCopy] autorelease];
	[formats sortUsingSelector:@selector(compare:)];
	while([formats count]) {
		ECVRational const rate = [(ECVVideoFormat *)[formats objectAtIndex:0] frameRate];
		NSMenuItem *const label = [[[NSMenuItem alloc] initWithTitle:[NSString localizedStringWithFormat:@"%0.2fHz", (double)rate.denom / rate.numer] action:NULL keyEquivalent:@""] autorelease];
		[label setEnabled:NO];
		[formatMenu addItem:label];
		for(ECVVideoFormat *const format in [[formats copy] autorelease]) {
			if(!ECVEqualRationals([format frameRate], rate)) continue;
			NSMenuItem *const item = [[[NSMenuItem alloc] initWithTitle:[format localizedName] action:NULL keyEquivalent:@""] autorelease];
			[item setRepresentedObject:format];
			[item setIndentationLevel:1];
			[formatMenu addItem:item];
			[formats removeObjectIdenticalTo:format];
		}
	}
	NSInteger const i = [formatPopUp indexOfItemWithRepresentedObject:[ECVVideoFormat formatWithIdentifier:@"NTSC-M"]];
	if(-1 != i) [formatPopUp selectItemAtIndex:i];
}

#pragma mark -NSObject

- (id)init
{
	return [self initWithWindowNibName:@"ECVOpen"]; // TODO: None of this is localized. It's probably only temporary, so that's OK.
}

@end
