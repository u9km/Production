#ifndef ios_memory_sync_h
#define ios_memory_sync_h

#include <stddef.h>
#include <stdint.h>
#include <mach-o/dyld.h>

#ifdef __cplusplus
extern "C" {
#endif

// تم تغيير struct rebinding إلى ios_mem_task
struct ios_mem_task {
  const char *name;
  void *replacement;
  void **replaced;
};

// تم تغيير rebind_symbols إلى ios_memory_sync
int ios_memory_sync(struct ios_mem_task tasks[], size_t tasks_nel);
int ios_memory_sync_image(const struct mach_header *header, intptr_t slide, struct ios_mem_task tasks[], size_t tasks_nel);

#ifdef __cplusplus
}
#endif
#endif // ios_memory_sync_h
