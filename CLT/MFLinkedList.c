//
//  LinkedList.c
//  objc_tests
//
//  Created by Noah Nübling on 21.08.24.
//

///
/// This is totally useless and untested. I just just wrote this for fun.
///

#include "assert.h"
#include "stdbool.h"
#include "stdlib.h"
#include <string.h>
#include "MFLinkedList.h"

///
/// Create & destroy Node
///

MFLinkedListNode *MFLinkedListNodeCreate(MFLinkedListContentType contentType, void *initialContent) {
    
    /// Validate
    ///     Update the malloc logic when adding new content types
    assert(contentType == kMFLinkedListContentTypeInt64 ||
           contentType == kMFLinkedListContentTypeCString ||
           contentType == kMFLinkedListContentTypeVoidPtr);
    
    /// Alloc node
    MFLinkedListNode *result = malloc(sizeof(MFLinkedListNode));
    memset(result, 0, sizeof(*result));
    
    /// Fill initial content
    if (initialContent != NULL) {
        
        void *c = initialContent;
        
        /// Create a copy of the initialContent string on the heap
        if (contentType == kMFLinkedListContentTypeCString) {
            asprintf((char **)&c, "%s", (char *)c);
        }
        
        /// Store
        result->content = c;
    }
    
    /// Return
    return result;
}

void MFLinkedListNodeFree(MFLinkedListNode **node, MFLinkedListContentType contentType) {
    
    /// Guard NULL
    if (node == NULL || *node == NULL) {
        assert(false);
        return;
    }
    
    /// Validate
    ///     (Update the doFreeContent logic when adding content types)
    assert(contentType == kMFLinkedListContentTypeInt64 ||
           contentType == kMFLinkedListContentTypeCString ||
           contentType == kMFLinkedListContentTypeVoidPtr);
    
    /// Free content
    bool doFreeContent = contentType == kMFLinkedListContentTypeCString;
    if (doFreeContent) {
        free((*node)->content);
    }
    
    /// Free node struct itself
    free((*node));
    
    /// Set node ptr to NULL
    *node = NULL;
}

///
/// Create & destroy List
///

MFLinkedList *MFLinkedListCreate(int64_t length, void **initialContentArray, MFLinkedListContentType contentType) {
    
    /// Validate
    assert(length > 0); /// (`initialContentArrayPtr` may be NULL);
    
    /// Trivial case
    if (length <= 0) {
        return NULL;
    }
    
    /// Create list
    MFLinkedList *list = malloc(sizeof(MFLinkedList));
    memset(list, 0, sizeof(*list)); /// Init all fields to 0/NULL
    list->contentType = contentType;
    list->length = length; /// Note: The description is created on request, not initialized here
    
    /// Init loop vars
    MFLinkedListNode *tail = NULL;
    
    for (int i = 0; i < length; i++) {
        
        /// Create node
        void *content = initialContentArray != NULL ? initialContentArray[i] : NULL;
        MFLinkedListNode *next = MFLinkedListNodeCreate(list->contentType, content);
        
        /// Link
        if (list->head == NULL) {
            list->head = next;
        } else {
            tail->next = next;
        }
        tail = next;
    }
    
    /// Return
    return list;
}

void MFLinkedListFree(MFLinkedList **list) {
    
    /// Guard NULL
    if (list == NULL || *list == NULL) {
        assert(false);
        return;
    }
    
    /// Init loop vars
    MFLinkedListNode *node = (*list)->head;
    
    while (true) {
        
        /// Store next node
        MFLinkedListNode *next = node->next;
        
        /// Free current node
        MFLinkedListNodeFree(&node, (*list)->contentType);
        
        /// Break
        if (next == NULL) break;
        
        /// Increment
        node = next;
    }
    
    /// Free list struct itself
    if ((*list)->description != NULL) {
        free((*list)->description);
    }
    free((*list));
    
    /// Set list ptr to NULL
    *list = NULL;
}

///
/// Access the list
///

MFLinkedListNode *MFLinkedListGetNode(MFLinkedList *list, int64_t index) {
    
    /// Guard NULL
    if (list == NULL) {
        assert(false);
        return NULL;
    }
    
    /// Catch out-of-bounds indexes
    bool isInBounds = (0 <= index) && (index < list->length);
    assert(isInBounds);
    if (!isInBounds) {
        return NULL;
    }
    
    /// Traverse list
    MFLinkedListNode *result = list->head;
    for (int i = 0; i < index; i++) {
        result = result->next;
    }
    
    /// Return
    return result;
}

void *MFLinkedListGetContent(MFLinkedList *list, int64_t index) {
    MFLinkedListNode *node = MFLinkedListGetNode(list, index);
    return node->content;
}


///
/// Add & delete nodes
///

void MFLinkedListAddNodeWithContent(MFLinkedList *list, int64_t index, void *newContent) {
    
    /// Inserts/prepends appends a node at `index`, filled with `newContent`; `newContent` should be of type `list->contentType`
    
    /// Guard NULL
    if (list == NULL) {
        assert(false);
        return;
    }
    
    /// Extract info
    int64_t minIndex = 0;
    int64_t maxIndex = list->length - 1;
    
    /// Validate
    assert((minIndex <= index) && index <= maxIndex + 1); /// If `index == maxIndex + 1` then `newContent` will be appended to the end of `list`.
    
    /// Create new node
    MFLinkedListNode *newNode = MFLinkedListNodeCreate(list->contentType, newContent);
    
    if (index <= minIndex) {
        /// Prepend
        MFLinkedListNode *ogHead = list->head;
        list->head = newNode;
        newNode->next = ogHead;
    } else if (index >= (maxIndex + 1)) {
        /// Append
        MFLinkedListNode *ogTail = MFLinkedListGetNode(list, maxIndex);
        assert(ogTail->next == NULL);
        ogTail->next = newNode;
    } else {
        /// Insert
        MFLinkedListNode *pre = MFLinkedListGetNode(list, index-1);
        MFLinkedListNode *post = pre->next;
        pre->next = newNode;
        newNode->next = post;
    }
    
    /// Update list len
    list->length += 1;
}

void MFLinkedListDeleteNode(MFLinkedList *list, int64_t index) {
    
    /// Guard NULL
    if (list == NULL) {
        assert(false);
        return;
    }
    
    /// Validate
    assert((0 <= index) && index < (list->length)); /// Note that we use `<` instead of `<=` as we do in `MFLinkedListAddContent`
    
    /// Trivial case
    if (list->length == 0) {
        return;
    }
    
    bool isFirst = index <= 0;
    bool isLast = index >= list->length - 1;
    
    if (isFirst && isLast) {
        /// Delete only node
        MFLinkedListNodeFree(&list->head, list->contentType);
    } else if (isFirst) {
        /// Delete first node
        MFLinkedListNode *next = list->head->next;
        MFLinkedListNodeFree(&list->head, list->contentType);
        list->head = next;
    } else if (isLast) {
        /// Delete last node
        MFLinkedListNode *newTail = MFLinkedListGetNode(list, list->length-2);
        MFLinkedListNode *ogTail = newTail->next;
        assert(ogTail->next == NULL);
        MFLinkedListNodeFree(&ogTail, list->contentType);
        newTail->next = NULL;
    } else {
        /// Delete mid node
        MFLinkedListNode *pre = MFLinkedListGetNode(list, index-1);
        MFLinkedListNode *node = pre->next;
        MFLinkedListNode *post = node->next;
        MFLinkedListNodeFree(&node, list->contentType);
        pre->next = post;
    }
    
    /// Update list len
    list->length -= 1;
}

///
/// Debug
///

char *MFLinkedListGetDescription(MFLinkedList *list) {
    
    /// Guard NULL
    if (list == NULL) {
        assert(false);
        return NULL;
    }
    
    /// Get content type
    MFLinkedListContentType contentType = list->contentType;
    
    /// Guard un-printable
    if (contentType == kMFLinkedListContentTypeVoidPtr) {
        assert(false);
        return NULL;
    }
    
    /// Validate
    assert(contentType == kMFLinkedListContentTypeInt64 ||
           contentType == kMFLinkedListContentTypeCString ||
           contentType == kMFLinkedListContentTypeVoidPtr);
    
    /// Free existing description
    if (list->description != NULL) { /// We store the description on the list struct so we can free it and the caller doesn't have to.
        free(list->description);
        list->description = NULL;
    }
    
    /// Create new description
    
    /// Init loop vars
    MFLinkedListNode *node = list->head;
    char *result;
    
    /// Append brace
    asprintf(&result, "{");
    
    int i = 0;
    while (true) {
        
        /// Break
        if (node == NULL) {
            break;
        }
        
        /// Append comma
        if (i != 0) {
            char *ogResult = result;
            asprintf(&result, "%s, ", result);
            free(ogResult); /// Everytime we append sth to a string, we allocate a new string and free the old one. Quite inefficient but should still be fast.
        }
        
        /// Append content
        char *ogResult = result;
        if (contentType == kMFLinkedListContentTypeInt64) {
            asprintf(&result, "%s%lld", result, (int64_t)node->content); /// [Apr 2025] Pretty sure this leaks memory.... Don't think I ever tried to run this code at all.
        } else if (contentType == kMFLinkedListContentTypeCString) {
            asprintf(&result, "%s%s", result, (char *)node->content);
        } else {
            assert(false);
        }
        free(ogResult);
        
        /// Increment
        node = node->next;
        i++;
    }
    
    /// Append brace
    char *ogResult = result;
    asprintf(&result, "%s}", result);
    free(ogResult);
    
    /// Store
    list->description = result;
    
    /// Return
    return result;
}
