//
//  LinkedList.h
//  objc_tests
//
//  Created by Noah Nübling on 21.08.24.
//

#ifndef LinkedList_h
#define LinkedList_h

#include <stdio.h>

///
/// Typedef
///

typedef enum {
    kMFLinkedListContentTypeCString,
    kMFLinkedListContentTypeInt64,
    kMFLinkedListContentTypeVoidPtr, /// For untyped/mixed type list
} MFLinkedListContentType;

typedef struct _MFLinkedListNode {
    
    void *content;
    struct _MFLinkedListNode *next;
    
} MFLinkedListNode;

typedef struct _MFLinkedList {
    
    MFLinkedListContentType contentType;
    char *description;
    int64_t length;
    struct _MFLinkedListNode *head;
    
} MFLinkedList;

///
/// Interface
///

MFLinkedList *MFLinkedListCreate(int64_t length, void **initialContentArrayPtr, MFLinkedListContentType contentType);
void MFLinkedListNodeFree(MFLinkedListNode **node, MFLinkedListContentType contentType);
void MFLinkedListFree(MFLinkedList **list);
MFLinkedListNode *MFLinkedListGetNode(MFLinkedList *list, int64_t index);
void MFLinkedListAddNodeWithContent(MFLinkedList *list, int64_t index, void *newContent);
void MFLinkedListDeleteNode(MFLinkedList *list, int64_t index);
void *MFLinkedListGetContent(MFLinkedList *list, int64_t index);
char *MFLinkedListGetDescription(MFLinkedList *list);

#endif /* LinkedList_h */
