#ifndef LINKED_LIST_H
#define LINKED_LIST_H

#include <stdlib.h>

#include "nand.h"

typedef struct _node *node;
typedef struct _linked_list *linked_list;

struct _node {
    nand_t* value;
    node next;
};

struct _linked_list {
    node head;
    node tail;
    int size;
};

linked_list make_linked_list();

bool push_back(linked_list list, nand_t* elem);

bool remove_from_list(linked_list list, nand_t* elem);

void delete_list(linked_list list);

#endif