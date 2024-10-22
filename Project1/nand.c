/* 
    Solution for the first project of Computer Architecture and Operating Systems class.
    Simple library that allows performing chosen operations on NAND gates.
    Author: Gracjan Barski
*/

#include <stdint.h>
#include <stdlib.h>
#include <errno.h>
#include "nand.h"
#include "linked_list.h"

#define _max(a,b)            \
({                           \
    __typeof__ (a) _a = (a); \
    __typeof__ (b) _b = (b); \
    _a > _b ? _a : _b;       \
})
#define ACTIVE 1
#define INACTIVE 0
#define INDEFINITE -1

union _input {
    const bool* bool_input;
    nand_t* nand_input;
};

typedef enum _input_state {DISCONNECTED, NAND, BOOLEAN} input_state;

typedef struct _input_wrapper { //Wrapper can hold two type of input pointers
    input_state state; //Indicates what type of input is connected
    union _input input;
} input_wrapper;

typedef enum _evaluating_stage {UNTOUCHED, TOUCHED, DONE} evaluating_stage;

struct nand {
    int8_t last_output;
    ssize_t last_critical_path;

    evaluating_stage stage;

    uint32_t inputs_size;
    input_wrapper* inputs; //Array of connected inputs
    linked_list connected_outputs;
};

//=============================================================================
//HELPER FUNCTIONS

//Removes g from array arr, setting the value to NULL
void _remove_from_inputs(input_wrapper* arr, uint32_t size, nand_t* g) {
    for (unsigned i = 0; i < size; i++) {
        if (arr[i].state == NAND && arr[i].input.nand_input == g) {
            arr[i].state = DISCONNECTED;
            arr[i].input.bool_input = NULL;
            break;
        }
    }
}

//Recursively sets fields of all gates connected to g to default
void _reset_fields(nand_t* g) {
    if (!g)
        return;
    
    //We check whether the current subtree is already cleared
    if (g->stage == UNTOUCHED)
        return;
    
    g->last_output = INDEFINITE;
    g->last_critical_path = 0;
    g->stage = UNTOUCHED;
    for (size_t i = 0; i < g->inputs_size; i++)
        if (g->inputs[i].state == NAND)
            _reset_fields(g->inputs[i].input.nand_input);
}

//Resets all the gates that are in array g
void _reset_all(nand_t** g, size_t m) {
    for (size_t i = 0; i < m; i++)
        _reset_fields(g[i]);
}

//Performs DFS post-order traversal and computes the gate outputs
void _traverse(nand_t* g) {
    if(!g)
        return;

    int8_t result_output = 1;
    ssize_t path_length = 0;
    input_wrapper current;
    g->stage = TOUCHED;

    for (size_t i = 0; i < g->inputs_size; i++) {
        current = g->inputs[i];
        
        //There is nothing connected to the gate input, 
        //the output remains INDEFINITE and we return
        if (current.state == DISCONNECTED) {
            g->stage = DONE;
            return;
        }
        else if (current.state == NAND) {
            nand_t* current_input = current.input.nand_input;
            
            //Recursive call only if this branch was not yet visited
            if (current_input->stage == UNTOUCHED)
                _traverse(current_input);
            
            //Cycle or disconnected input detected
            if (current_input->stage != DONE) {
                g->stage = DONE;
                return;
            }

            if (current_input->last_output == INDEFINITE) {
                g->stage = DONE;
                return;
            }
            
            result_output &= current_input->last_output;
            path_length = _max(path_length, current_input->last_critical_path);
        } 
        else { //Bool input
            result_output &= *(current.input.bool_input);
        }
    }

    g->last_output = 1 - result_output; //Negate AND
    //If there are no inputs, the critical path length is 0
    g->last_critical_path = g->inputs_size ? path_length + 1 : 0;
    g->stage = DONE;
}

//=============================================================================
//LIBRARY FUNCTIONS

/// @brief Creates a new NAND gate with n inputs
nand_t* nand_new(unsigned n) {
    nand_t* res = (nand_t*) malloc(sizeof(nand_t));
    if(!res) { //Allocation failure
        errno = ENOMEM;
        return NULL;
    }

    res->last_output = INDEFINITE;
    res->last_critical_path = 0;
    res->stage = UNTOUCHED;
    res->inputs_size = n;

    res->inputs = (input_wrapper*) calloc(n, sizeof(input_wrapper));
    if (!(res->inputs)) { //Allocation failure
        free(res);
        errno = ENOMEM;
        return NULL;
    }

    for (unsigned i = 0; i < n; i++) {
        res->inputs[i].state = DISCONNECTED;
        res->inputs[i].input.nand_input = NULL;
    }

    res->connected_outputs = make_linked_list();
    if (!(res->connected_outputs)) { //Allocation failure
        free(res->inputs);
        free(res);
        errno = ENOMEM;
        return NULL;
    }
    
    return res;
}

/// @brief Disconnects the input and output signals of the specified gate, 
/// then removes the specified gate and frees all memory used by it. 
/// It does nothing if called with a NULL pointer. 
/// After this function is executed, the pointer passed to it becomes invalid.
void nand_delete(nand_t *g) {
    if (!g)
        return;

    for (unsigned i = 0; i < g->inputs_size; i++)
        if (g->inputs[i].state == NAND)
            remove_from_list(g->inputs[i].input.nand_input->connected_outputs,
                 g);
    
    node current = g->connected_outputs->head; 
    //Traversing until we reach the dummy node
    while (current != g->connected_outputs->tail) {
        _remove_from_inputs(
            current->value->inputs, 
            current->value->inputs_size, 
            g
        );
        current = current->next;
    }
    
    delete_list(g->connected_outputs);
    free(g->inputs);
    free(g);
}


/// @brief Connects the output of gate g_out to the input k of gate g_in, 
/// optionally disconnecting any signal previously connected to that input.
int nand_connect_nand(nand_t *g_out, nand_t *g_in, unsigned k) {
    if(!g_out || !g_in || k >= g_in->inputs_size) { //Invalid arguments
        errno = EINVAL;
        return -1;
    }
    
    bool success = push_back(g_out->connected_outputs, g_in);    
    if(!success) { //Allocation failure
        errno = ENOMEM;
        return -1;
    }

    //disconnect the gate that is currently connected to k-th input of g_in
    if (g_in->inputs[k].state == NAND) 
        remove_from_list(g_in->inputs[k].input.nand_input->connected_outputs,
             g_in);
    
    g_in->inputs[k].state = NAND;
    g_in->inputs[k].input.nand_input = g_out;

    return 0;
}

/// @brief Connects the boolean signal s to input k of gate g, 
/// optionally disconnecting any signal previously connected to that input. 
int nand_connect_signal(bool const *s, nand_t *g, unsigned k) {
    if(!s || !g || k >= g->inputs_size) { //Invalid arguments
        errno = EINVAL;
        return -1;
    }

    if (g->inputs[k].state == NAND) 
        remove_from_list(g->inputs[k].input.nand_input->connected_outputs, g);
    
    g->inputs[k].state = BOOLEAN;
    g->inputs[k].input.bool_input = s;
    return 0;
}

/// @brief Determines the values of signals at the outputs of the specified 
/// gates and calculates the length of the critical path 
ssize_t nand_evaluate(nand_t **g, bool *s, size_t m) {
    //Check for null values
    if (!g || !s || m == 0) {
        errno = EINVAL;
        return -1;
    } 

    for (size_t i = 0; i < m; i++) {
        if (!(g[i])) {
            errno = EINVAL; 
            return -1;
        }
    }
    
    //Traverse through the whole tree using DFS algorithm, 
    // and compute the ouput of every gate exactly once
    for (size_t i = 0; i < m; i++)
        _traverse(g[i]);

    ssize_t longest_critical_path = 0;
    for (size_t i = 0; i < m; i++) {
         //There was a cycle or disconnected input, exit the function
        if (g[i]->last_output == INDEFINITE || g[i]->stage != DONE) {
            _reset_all(g, m);
            errno = ECANCELED;
            return -1;
        }

        s[i] = g[i]->last_output;
        longest_critical_path = _max(longest_critical_path, 
            g[i]->last_critical_path);
    }

    _reset_all(g, m);
    return longest_critical_path;
}

/// @brief Determines the number of inputs of gates 
/// connected to the output of a given gate.
ssize_t nand_fan_out(nand_t const *g) {
    if (!g) {
        errno = EINVAL;
        return -1;
    }
    
    return g->connected_outputs->size;
}

/// @brief Returns a pointer to a boolean signal or gate connected 
/// to input k of the gate indicated by g, 
/// or NULL if nothing is connected to that input.
void* nand_input(nand_t const *g, unsigned k) {
    if (!g || k >= g->inputs_size) {
        errno = EINVAL;
        return NULL;
    }
    
    switch (g->inputs[k].state) {
        case DISCONNECTED:
            errno = 0;
            return NULL;

        case NAND:
            return (nand_t*) g->inputs[k].input.nand_input;
        
        case BOOLEAN:
            return (bool*) g->inputs[k].input.bool_input;
        
        default:
            errno = EINVAL;
            return NULL;
    }
}

/// @brief allows iterating over gates connected to the output 
/// of the specified gate.
/// The result of this function is undefined if its parameters are incorrect.
/// If the output of gate g is connected to multiple inputs of the same gate, 
/// that gate appears multiple times in the iteration result. 
nand_t* nand_output(nand_t const *g, ssize_t k) {
    if (k < 0 || k >= nand_fan_out(g))
        return NULL;
    
    node current = g->connected_outputs->head;
    for (int i = 1; i <= k; i++) {
        current = current->next;
    }

    return current->value;
}
