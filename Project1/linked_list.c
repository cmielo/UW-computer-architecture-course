#include <stdlib.h>
#include "linked_list.h"

//Implementation of simple linked list using pointers

//Creates a new node
node create_node(nand_t* elem) {
    node res = (node) malloc(sizeof(struct _node));
    if (!res)
        return NULL;

    res->value = elem;
    res->next = NULL;
    return res;
}


//Creates new empty linked list
linked_list make_linked_list() {
    linked_list res = (linked_list) malloc(sizeof(struct _linked_list));
    if (!res)
        return NULL;
    res->head = res->tail = create_node(NULL); //dummy node kept at tail*
    if (res->head == NULL) {
        free(res);
        return NULL;
    }
    res->size = 0LL;
    return res;
}

//Checks whether provided list is empty or not
bool is_empty(linked_list list) {
    return list->head == list->tail;
}

//Pushes the element on the back of the list
bool push_back(linked_list list, nand_t* elem) {
    node new_tail = create_node(NULL);
    if (!new_tail)
        return false;

    list->tail->value = elem;
    list->tail->next = new_tail;
    list->tail = new_tail;
    list->size++;
    return true;
}

//Removes the first element of the list
bool pop_front(linked_list list) {
    if (is_empty(list))
        return false;
    node to_remove = list->head;
    list->head = list->head->next;
    free(to_remove);
    list->size--;
    return true;
}

//Removes the provided element from the list
bool remove_from_list(linked_list list, nand_t* elem) {
    if (is_empty(list))
        return false;

    node prev = list->head;
    if (prev->value == elem) {
        return pop_front(list);
    }

    while(prev != list->tail && prev->next->value != elem)
        prev = prev->next;
    
    if (prev == list->tail)
        return false;
    
    node to_remove = prev->next;
    prev->next = prev->next->next;
    free(to_remove);
    list->size--;
    return true;
}

//Deletes provided list
void delete_list(linked_list list) {
    if (is_empty(list)) {
        free(list->head);
        free(list);
        return;
    }

    node prev = list->head;
    node current = prev->next;
    while (prev != list->tail) {
        free(prev);
        prev = current;
        current = current->next;
    }
    free(list->tail);
    free(list);
}