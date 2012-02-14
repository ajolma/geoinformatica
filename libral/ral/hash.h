#ifndef RAL_HASH_H
#define RAL_HASH_H

#include <stddef.h>

/**\file ral/hash.h
   \brief A simple hash data type and algorithms.

   Currently key is always a RAL_INTEGER.
   After code written by Jerry Coffin and improved by HenkJan Wolthuis.
*/

/**\brief an integer range */
typedef struct {
    RAL_INTEGER min;
    RAL_INTEGER max;
} ral_integer_range;

/**\brief a real value range */
typedef struct {
    RAL_REAL min;
    RAL_REAL max;
} ral_real_range;

/**\brief an item in a hash (abstract base class) */
typedef struct ral_hash_item {
    RAL_INTEGER key;
    struct ral_hash_item *next;
} ral_hash_item;

/**\brief an integer in a hash */
typedef struct ral_hash_int_item {
    RAL_INTEGER key;
    struct ral_hash_int_item *next;
    int value;
} ral_hash_int_item;

/**\brief a RAL_INTEGER in a hash */
typedef struct ral_hash_integer_item {
    RAL_INTEGER key;
    struct ral_hash_integer_item *next;
    RAL_INTEGER value;
} ral_hash_integer_item;

/**\brief a double value in a hash */
typedef struct ral_hash_double_item {
    RAL_INTEGER key;
    struct ral_hash_double_item *next;
    double value;
} ral_hash_double_item;

/**\brief an integer range in a hash */
typedef struct ral_hash_integer_range_item {
    RAL_INTEGER key;
    struct ral_hash_integer_range_item *next;
    ral_integer_range value;
} ral_hash_integer_range_item;

/**\brief a real value range in a hash */
typedef struct ral_hash_real_range_item {
    RAL_INTEGER key;
    struct ral_hash_real_range_item *next;
    ral_real_range value;
} ral_hash_real_range_item;

/**\brief a hash (index for hash items) */
typedef struct {
    size_t size;
    ral_hash_item **table;
} ral_hash;

typedef ral_hash *ral_hash_handle;

unsigned ral_hashfct(int key);

ral_hash_handle RAL_CALL ral_hash_create(size_t size);
void RAL_CALL ral_hash_destroy(ral_hash **hash);

int RAL_CALL ral_hash_count(ral_hash *hash);
RAL_INTEGER_HANDLE RAL_CALL ral_hash_keys(ral_hash *hash, int *count);

int RAL_CALL ral_hash_delete(ral_hash *hash, int key);

#define RAL_HASH_INSERT(hash, _key, _value, item_type)			\
    {									\
	unsigned val = ral_hashfct(_key) % (hash)->size;		\
	item_type *ptr;							\
	if (!((hash)->table)[val]) {					\
	    RAL_CHECKM(ptr = malloc(sizeof(item_type)), RAL_ERRSTR_OOM); \
	    ptr->key = (_key);						\
	    ptr->value = (_value);					\
	    ptr->next = NULL;						\
	    ((hash)->table)[val] = (ral_hash_item *)ptr;		\
	} else {							\
	    int insert = 1;						\
	    for (ptr = (item_type *)((hash)->table)[val]; ptr; ptr = ptr->next) \
		if (ptr->key == (_key)) {				\
		    ptr->value = (_value);				\
		    insert = 0;						\
		}							\
	    if (insert) {						\
		RAL_CHECKM(ptr = (item_type *)malloc(sizeof(item_type)), RAL_ERRSTR_OOM); \
		ptr->key = (_key);					\
		ptr->value = (_value);					\
		ptr->next = (item_type *)((hash)->table)[val];		\
		((hash)->table)[val] = (ral_hash_item *)ptr;		\
	    }								\
	}								\
    }

#define RAL_HASH_LOOKUP(hash, _key, _value, item_type)			\
    {									\
	unsigned val = ral_hashfct(_key) % (hash)->size;		\
	item_type *ptr;							\
	*(_value) = NULL;						\
	if (((hash)->table)[val])					\
	    for (ptr = (item_type *)((hash)->table)[val]; ptr; ptr = ptr->next) \
		if (ptr->key == (_key))					\
		    *(_value) = &(ptr->value);				\
    }

#define RAL_HASH_ENUMERATE(hash, func, x, item_type)		\
    {								\
	unsigned i;						\
	item_type *temp;					\
	for (i = 0; i < (hash)->size; i++) {			\
	    if (((hash)->table)[i]) {				\
		for (temp = (item_type *)((hash)->table)[i];	\
		     tmp != NULL;				\
		     temp = temp->next)				\
		{						\
		    func(temp->key, temp->value, x);		\
		}						\
	    }							\
	}							\
    }

typedef ral_hash **ral_hash_handle_table;

ral_hash_handle_table RAL_CALL ral_hash_array_create(size_t size, int n);
void RAL_CALL ral_hash_array_destroy(ral_hash ***hash_array, int n);

#endif /* RAL_HASH_H */
