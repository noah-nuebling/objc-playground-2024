//
//  AppDelegate.m
//  ObjcTests
//
//  Created by Noah Nübling on 07.08.24.
//

#import "AppDelegate.h"
#import "MarkdownParser.h"
#import "NSString+Additions.h"
#import "NSAttributedString+Additions.h"

@interface AppDelegate ()

@property (strong) IBOutlet NSWindow *window;
@property (unsafe_unretained) IBOutlet NSTextView *markdownTextView;

@end

@implementation AppDelegate

/// Singleton
static AppDelegate *_shared;
+ (AppDelegate *)shared {
    return _shared;
}

/// Init
- (instancetype)init
{
    self = [super init];
    if (self) {
        _shared = self;
    }
    return self;
}

/// Lifecycle
- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    
    /// Run markdown tests:
    
    NSString *md =
    @"This is some **cool**\n"
    "\n"                              /// Paragraphbreak
    "emphasised textandalistoo:\n"
    "butfirstasoftbreakandthen:\n"
    "- first item\n"
    "- second [**bold**](https://google.com) item\n"
    "\n"
    "1. numbered also *kinda*\n"
    "2. pretty cool also\n"
    "\n"
    "1. numbered also *kinda*\n"
    "\n"
    "2. pretty cool also\n"
    "\n"
    "2. **very** w i d e"
    ;
    NSAttributedString *mdAttr = md.attributed;
    mdAttr = [mdAttr attributedStringByAddingItalicForRange:nil];
    
    NSAttributedString *result = [MarkdownParser attributedStringWithAttributedMarkdown:mdAttr];
    
    [_markdownTextView.layoutManager.textStorage setAttributedString:result];
}


- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
}

/// Config
- (BOOL)applicationSupportsSecureRestorableState:(NSApplication *)app {
    return YES;
}


@end
