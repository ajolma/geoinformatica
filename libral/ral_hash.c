#include "config.h"
#include "msg.h"
#include "ral/ral.h"

/*
** BASED ON
** public domain code by Jerry Coffin, with improvements by HenkJan Wolthuis.
*/

unsigned ral_hashfct(int key)
{
    unsigned ret_val = 0;
    ret_val ^= key;
    ret_val <<= 1;
    return ret_val;
}


ral_hash *ral_hash_create(size_t size)
{
    ral_hash *hash;
    RAL_CHECKM(hash = RAL_MALLOC(ral_hash), RAL_ERRSTR_OOM);
    RAL_CHECKM(hash->table = RAL_CALLOC(size, ral_hash_item *), RAL_ERRSTR_OOM);
    hash->size  = size;
    return hash;
 fail:
    ral_hash_destroy(&hash);
    return NULL;
}


void ral_hash_destroy(ral_hash **hash)
{
    unsigned i;
    if (!(*hash)) return;
    if ((*hash)->table) {
	for (i = 0; i < (*hash)->size; i++) {
	    ral_hash_item *a = (*hash)->table[i];
	    while (a) {
		ral_hash_item *b = a->next;
		free(a);
		a = b;
	    }
	}
	free((*hash)->table);
    }
    free(*hash);
    *hash = NULL;
}


int ral_hash_count(ral_hash *hash)
{
    unsigned count = 0, i;
    for (i = 0; i < hash->size; i++) {
	ral_hash_item *a = hash->table[i];
	while (a) {
	    count++;
	    a = a->next;
	}
    }
    return count;
}


RAL_INTEGER *ral_hash_keys(ral_hash *hash, int *count)
{
    RAL_INTEGER *keys, i;
    *count = 0;
    RAL_CHECKM(keys = RAL_CALLOC(ral_hash_count(hash), RAL_INTEGER), RAL_ERRSTR_OOM);
    for (i = 0; i < hash->size; i++) {
	ral_hash_item *a = hash->table[i];
	while (a) {
	    keys[*count] = a->key;
	    (*count)++;
	    a = a->next;
	}
    }
    return keys;
 fail:
    return 0;
}


int ral_hash_delete(ral_hash *hash, int key)
{
    unsigned val = ral_hashfct(key) % hash->size;
    ral_hash_item *ptr, *last;
    
    RAL_CHECK((hash->table)[val]);
    
    for (last = NULL, ptr = (hash->table)[val]; ptr; last = ptr, ptr = ptr->next) {

	if (key == ptr->key) {
	    if (last) {
		last->next = ptr->next;
		free(ptr);
		return 1;
	    } else {
		(hash->table)[val] = ptr->next;
		free(ptr);
		return 1;
	    }
	}
    }
 fail:
    return 0;
}


ral_hash **ral_hash_array_create(size_t size, int n)
{
    ral_hash **hash_array;
    int i;
    RAL_CHECKM(hash_array = RAL_CALLOC(n, ral_hash *), RAL_ERRSTR_OOM);
    for (i = 0; i < n; i++) {
	RAL_CHECK(hash_array[i] = ral_hash_create(size));
    }
    return hash_array;
fail:
    ral_hash_array_destroy(&hash_array, n);
    return NULL;
}


void ral_hash_array_destroy(ral_hash ***hash_array, int n)
{
    if (*hash_array) {
	int i;
	for (i = 0; i < n; i++) {
	    if ((*hash_array)[i]) {
		ral_hash_destroy(&((*hash_array)[i]));
	    }
	}
	free(*hash_array);
	*hash_array = NULL;
    }
}
