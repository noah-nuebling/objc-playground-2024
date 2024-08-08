//
// --------------------------------------------------------------------------
// MarkdownParser.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2024
// Licensed under Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import "MarkdownParser.h"
#import "AppDelegate.h"
#import <AppKit/AppKit.h>
#import "cmark/branch-cjk/headers/src/cmark.h"
#import "NSString+Additions.h"
#import "NSAttributedString+Additions.h"

@implementation MarkdownParser

+ (NSAttributedString *)attributedStringWithMarkdown:(NSString *)src {
    return attributedStringWithMarkdown(src.attributed, false);
}
+ (NSAttributedString *)attributedStringWithAttributedMarkdown:(NSAttributedString *)src {
    return attributedStringWithMarkdown(src, true);
}

static NSAttributedString *attributedStringWithMarkdown(NSAttributedString *src, Boolean keepExistingAttributes) {
    
    /// Irrelevant sidenote:
    /// - I started writing this using c-style variable names with lots of 'mnemonic' abbreviations and underscores - since that's what the cmark libary uses and I thought it was interesting to try.
    ///     But then we ended up also using lots of Cocoa APIs and all the naming got mixed up.
    
    /// Get markdown node iterator
    const char *md = [src.string cStringUsingEncoding:NSUTF8StringEncoding];
    int md_options = CMARK_OPT_HARDBREAKS;   /// Don't swallow single linebreaks. Not totally sure what this does.
    cmark_node *root = cmark_parse_document(md, strlen(md), md_options);
    cmark_iter *iter = cmark_iter_new(root);
    
    ///  Create stack
    ///     Array of dicts that stores state of the nodes we're currently inside of.
    NSMutableArray<NSDictionary *> *stack = [NSMutableArray array];
    
    /// Create/init search range for src string
    __block NSRange src_search_range = NSMakeRange(0, src.length);
    
    /// Create counter for md lists
    __block int md_list_index = -1;
    
    /// Declare result
    ///     Note: We're modifying this as we walk the markdown tree so should be mutable but all our custom`NSAttributedString` apis don't work on mutable strings, so we're making it immutable and copying it on every modification.
    __block NSAttributedString *dst = [[NSMutableAttributedString alloc] init];
    
    /// Walk the md tree
    while (true) {
        
        /// Increment iter
        cmark_iter_next(iter);
        
        /// Get info from iter
        cmark_event_type ev_type = cmark_iter_get_event_type(iter);
        cmark_node *node = cmark_iter_get_node(iter);
        
        /// Process none event (assert false)
        if (ev_type == CMARK_EVENT_NONE) assert(false);
        
        /// Process done event (break loop)
        if (ev_type == CMARK_EVENT_DONE) break;
        
        /// Process enter / exit events
        Boolean did_enter = ev_type == CMARK_EVENT_ENTER; /// Entered node
        Boolean did_exit = ev_type == CMARK_EVENT_EXIT;
        assert(did_enter || did_exit);
        
        /// Get info from node
        cmark_node_type node_type = cmark_node_get_type(node);
        const char *node_type_name = cmark_node_get_type_string(node);
        const char *node_literal = cmark_node_get_literal(node);
        Boolean is_leaf = cmark_node_first_child(node) == NULL;
        
        /// Define `leaf_node_types`
        ///     Note: Leaf node types as documented in the cmark headers..
        int leaf_types[] = {
            CMARK_NODE_HTML_BLOCK,
            CMARK_NODE_THEMATIC_BREAK,
            CMARK_NODE_CODE_BLOCK,
            CMARK_NODE_TEXT,
            CMARK_NODE_SOFTBREAK,
            CMARK_NODE_LINEBREAK,
            CMARK_NODE_CODE,
            CMARK_NODE_HTML_INLINE
        };
        
        /// Valdiate info from node
        
#if DEBUG
        if (node_literal != NULL) {
            assert(is_leaf); /// I think only leaf nodes can contain text. That would simplify our control flow
        }
        if (is_leaf) {
            Boolean node_has_leaf_type = false;
            for (int i = 0; i < sizeof(leaf_types)/sizeof(leaf_types[0]); i++) {
                if (leaf_types[i] == node_type) {
                    node_has_leaf_type = true;
                    break;
                }
            }
            assert(node_has_leaf_type);
        }
#endif
        
        /// Use stack to track node enter and exit
        
        __block NSRange rangeOfExitedNodeInDst = NSMakeRange(NSNotFound, 0);
        
        if (!is_leaf && did_enter) {
            /// Stack push
            [stack addObject:@{ @"startIndexOfNodeInDst": @(dst.length) }];
        } else if (did_exit) {
            /// Stack pop
            NSInteger node_start_idx = [[stack lastObject][@"startIndexOfNodeInDst"] integerValue];
            [stack removeLastObject];
            /// Locate the exited node in the dst string.
            NSInteger node_end_idx = dst.length - 1;
            rangeOfExitedNodeInDst = NSMakeRange(node_start_idx, node_end_idx - node_start_idx + 1);
        }
        
        /// Define macros
        ///     To help with repetitve code for adding double linebreaks between block-elements.
        
        #define nodeIsBlockElement(__cmark_node) \
        ({ \
            cmark_node_type type = cmark_node_get_type(__cmark_node); \
            Boolean is_block = CMARK_NODE_FIRST_BLOCK <= type && type <= CMARK_NODE_LAST_BLOCK; \
            is_block; \
        })
        #define nodeIsInlineElement(__cmark_node) \
        ({ \
            cmark_node_type type = cmark_node_get_type(__cmark_node); \
            Boolean is_inline = CMARK_NODE_FIRST_INLINE <= type && type <= CMARK_NODE_LAST_INLINE; \
            is_inline; \
        })
        #define addDoubleLinebreaksForBlockElementToDst() \
            if (did_enter) { \
                Boolean is_block = nodeIsBlockElement(node); \
                Boolean previous_sibling_is_also_block = nodeIsBlockElement(cmark_node_previous(node)); \
                if (is_block && previous_sibling_is_also_block) { \
                dst = [dst attributedStringByAppending:@"\n\n".attributed]; \
            } \
        }
        
        /// Handle all types of nodes
        ///     Notes:
        ///     - Leaf nodes are marked with 🍁. They only have enter events, no exit events.
        ///     - The `command_map` dict is just a long if-else statement, but the dict makes it far more readable.
        NSDictionary *command_map = @{
            
            @(CMARK_NODE_NONE): ^{
                
                assert(false); /// Something went wrong
                
            },
            @(CMARK_NODE_DOCUMENT): ^{          /// == `CMARK_NODE_FIRST_BLOCK`
                
                /// Root node
                
            },
            @(CMARK_NODE_BLOCK_QUOTE): ^{
                
                assert(false); /// Don't know how to handle
                
            },
            @(CMARK_NODE_LIST): ^{
                
                addDoubleLinebreaksForBlockElementToDst();
                
                if (did_enter) {
                    
                    /// Initialize list item counter
                    md_list_index = cmark_node_get_list_start(node);
                }
                
            },
            @(CMARK_NODE_ITEM): ^{
                
                /// Note: Even though list items are blockElements, they don't have double linebreaks between them, so we don't use addDoubleLinebreaksForBlockElementToDst()
                
                if (did_enter) {
                    
                    /// Get parent node of item (the list node)
                    cmark_node *list_node = cmark_node_parent(node);
                    
                    /// Validate
                    assert(cmark_node_get_type(list_node) == CMARK_NODE_LIST);
                    
                    /// Get list tightness
                    ///     A markdown list can become non-tight when there are empty lines between the item lines.
                    Boolean is_tight = cmark_node_get_list_tight(list_node);
                    
                    /// Check if this is the first `list_item`
                    Boolean is_first_item = md_list_index == cmark_node_get_list_start(list_node);
                    
                    /// Get list prefix string
                    NSString *prefix;
                    cmark_list_type list_type = cmark_node_get_list_type(list_node);
                    if (list_type == CMARK_BULLET_LIST) {
                        prefix = @"• ";
                    } else if (list_type == CMARK_ORDERED_LIST)  {
                        if (cmark_node_get_list_delim(list_node) == CMARK_PAREN_DELIM) {
                            prefix = stringf(@"%d) ", md_list_index);
                        } else if (cmark_node_get_list_delim(list_node) == CMARK_PERIOD_DELIM) {
                            prefix = stringf(@"%d. ", md_list_index);
                        } else {
                            assert(false);
                        }
                    } else {
                        assert(false);
                    }
                    
                    /// Append newline
                    if (!is_first_item) {
                        if (is_tight || !is_tight) { /// Turning off non-tight lists (which have a whole free line between items) bc I don't like them and accidentally produce them sometimes.
                            dst = [dst attributedStringByAppending:@"\n".attributed];
                        }
                    }
                    
                    /// Append list-item-prefix to dst
                    ///     Note: The next nodes we'll iterate over will be the child nodes of this item node.
                    dst = [dst attributedStringByAppending:prefix.attributed];
                    
                    /// Advance list counter
                    md_list_index += 1;
                }
                
            },
            @(CMARK_NODE_CODE_BLOCK): ^{        /// 🍁
                
                assert(did_enter); /// Leaf node
                assert(false); /// Don't know how to handle
                
            },
            @(CMARK_NODE_HTML_BLOCK): ^{        /// 🍁
                
                assert(did_enter); /// Leaf node
                assert(false); /// Don't know how to handle
                
            },
            @(CMARK_NODE_CUSTOM_BLOCK): ^{
                
                assert(false); /// Don't know how to handle
                
            },
            @(CMARK_NODE_PARAGRAPH): ^{
                
                addDoubleLinebreaksForBlockElementToDst();
                
                /// Note: Why the isTopLevel restriction?
                ///     Update: every list item seems to contain its own paragraph, they are all last paragraphs through, so the `is_top_level` check doesn't seem necessary.
            },
            @(CMARK_NODE_HEADING): ^{
                
                assert(false); /// Don't know how to handle
                
            },
            @(CMARK_NODE_THEMATIC_BREAK): ^{    /// == `CMARK_NODE_LAST_BLOCK` || 🍁 || "thematic break" is the horizontal line aka hrule
                
                assert(did_enter); /// Leaf node
                assert(false); /// Don't know how to handle
                
            },
            @(CMARK_NODE_TEXT): ^{              /// == `CMARK_NODE_FIRST_INLINE` || 🍁
                
                assert(did_enter); /// Leaf node
                
                NSString *node_text = stringf(@"%s", cmark_node_get_literal(node));
                
                if (!keepExistingAttributes) {
                    dst = [dst attributedStringByAppending:node_text.attributed];
                } else {
                    /// Get attributed substring of src which contains the same text as `node_text`
                    ///     By appending the attributed substring of src to dst instead of appending `node_text` directly, we effectively carry over the string attributes from src into dst
                    NSRange src_range = [src.string rangeOfString:node_text options:0 range:src_search_range];
                    NSAttributedString *src_substr = [src attributedSubstringFromRange:src_range];
                    dst = [dst attributedStringByAppending:src_substr];
                    /// Remove the processed range from the search range
                    ///     End of the search range should always be the end of the src string
                    NSInteger new_search_range_start = src_range.location + src_range.length;
                    src_search_range = NSMakeRange(new_search_range_start, src.length - new_search_range_start);
                }
                
            },
            @(CMARK_NODE_SOFTBREAK): ^{         /// 🍁
                
                assert(did_enter); /// Leaf node
                dst = [dst attributedStringByAppending:@"\n".attributed];
                
            },
            @(CMARK_NODE_LINEBREAK): ^{         /// 🍁
                
                /// Notes:
                /// - I've never seen this be called. `\n\n` will start a new paragraph, not insert a 'linebreak'.
                /// - That's because even a siingle newline char starts a new paragraph (at least for NSParagraphStyle). We should be using the "Unicode Line Separator" for simple linebreaks in UI text.
                ///   - See: https://stackoverflow.com/questions/4404286/how-is-a-paragraph-defined-in-an-nsattributedstring
                
                assert(did_enter); /// Leaf node
                dst = [dst attributedStringByAppending:@"\n".attributed];
                
            },
            @(CMARK_NODE_CODE): ^{              /// 🍁
                
                assert(did_enter); /// Leaf node
                assert(false); /// Don't know how to handle
                
            },
            @(CMARK_NODE_HTML_INLINE): ^{       /// 🍁
                
                assert(did_enter); /// Leaf node
                assert(false); /// Don't know how to handle
                
            },
            @(CMARK_NODE_CUSTOM_INLINE): ^{
                
                assert(false); /// Don't know how to handle
                
            },
            @(CMARK_NODE_EMPH): ^{
                /// Notes:
                /// - We're misusing emphasis (which is usually italic) as a semibold. We're using the semibold, because for the small hint texts in the UI, bold looks way to strong. This is a very unsemantic and hacky solution. It works for now, but just keep this in mind.
                /// - I tried using Italics in different places in the UI, and it always looked really bad. Also Chinese, Korean, and Japanese don't have italics. Edit: Actually on GitHub they do seem to have italics: https://github.com/dokuwiki/dokuwiki/issues/4080
                if (did_exit) {
                    dst = [dst attributedStringByAddingWeight:NSFontWeightSemibold forRange:&rangeOfExitedNodeInDst];
                }
            },
            @(CMARK_NODE_STRONG): ^{
                if (did_exit) {
                    dst = [dst attributedStringByAddingWeight:NSFontWeightBold forRange:&rangeOfExitedNodeInDst];
                }
            },
            @(CMARK_NODE_LINK): ^{
                if (did_exit) {
                    dst = [dst attributedStringByAddingHyperlink:[NSURL URLWithString:stringf(@"%s", cmark_node_get_url(node))] forRange:&rangeOfExitedNodeInDst];
                }
            },
            @(CMARK_NODE_IMAGE): ^{             /// == `CMARK_NODE_LAST_INLINE`
                
                assert(false); /// Don't know how to handle
                
            }
        };
        
        /// Execute command from map for this node
        void (^command)(void) = command_map[@(node_type)];
        if (command != nil) {
            command();
        } else {
            NSLog(@"Error: Unknown node_type: %s", node_type_name);
            assert(false);
        }
        
    } /// End iterating nodes
    
    /// Free iterator & and tree
    cmark_iter_free(iter);
    cmark_node_free(root);
    
    /// Return generate string
    return dst;
}


@end
