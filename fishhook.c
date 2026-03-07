#include "fishhook.h"
#include <dlfcn.h>
#include <stdlib.h>
#include <string.h>
#include <sys/types.h>
#include <mach-o/nlist.h>

struct ios_mem_task_entry {
  struct ios_mem_task task;
  struct ios_mem_task_entry *next;
};

static struct ios_mem_task_entry *tasks_head = NULL;

static int perform_memory_sync(struct ios_mem_task_entry *task_head,
                               const struct mach_header *header,
                               intptr_t slide) {
  Dl_info info;
  if (dladdr(header, &info) == 0) return -1;
  struct segment_command_64 *cur_seg_cmd;
  struct segment_command_64 *linkedit_seg = NULL;
  struct symtab_command* symtab_cmd = NULL;
  struct dysymtab_command* dysymtab_cmd = NULL;

  uintptr_t cur = (uintptr_t)header + sizeof(struct mach_header_64);
  for (uint i = 0; i < header->ncmds; i++, cur += cur_seg_cmd->cmdsize) {
    cur_seg_cmd = (struct segment_command_64 *)cur;
    if (cur_seg_cmd->cmd == LC_SEGMENT_64) {
      if (strcmp(cur_seg_cmd->segname, "__LINKEDIT") == 0) {
        linkedit_seg = cur_seg_cmd;
      }
    } else if (cur_seg_cmd->cmd == LC_SYMTAB) {
      symtab_cmd = (struct symtab_command*)cur_seg_cmd;
    } else if (cur_seg_cmd->cmd == LC_DYSYMTAB) {
      dysymtab_cmd = (struct dysymtab_command*)cur_seg_cmd;
    }
  }

  if (!symtab_cmd || !dysymtab_cmd || !linkedit_seg || !dysymtab_cmd->nindirectsyms) return -1;

  uintptr_t linkedit_base = (uintptr_t)slide + linkedit_seg->vmaddr - linkedit_seg->fileoff;
  struct nlist_64 *symtab = (struct nlist_64 *)(linkedit_base + symtab_cmd->symoff);
  char *strtab = (char *)(linkedit_base + symtab_cmd->stroff);
  uint32_t *indirect_symtab = (uint32_t *)(linkedit_base + dysymtab_cmd->indirectsymoff);

  cur = (uintptr_t)header + sizeof(struct mach_header_64);
  for (uint i = 0; i < header->ncmds; i++, cur += cur_seg_cmd->cmdsize) {
    cur_seg_cmd = (struct segment_command_64 *)cur;
    if (cur_seg_cmd->cmd == LC_SEGMENT_64) {
      if (strcmp(cur_seg_cmd->segname, "__DATA") != 0 && strcmp(cur_seg_cmd->segname, "__DATA_CONST") != 0) continue;
      for (uint j = 0; j < cur_seg_cmd->nsects; j++) {
        struct section_64 *sect = (struct section_64 *)(cur + sizeof(struct segment_command_64)) + j;
        if ((sect->flags & SECTION_TYPE) == S_LAZY_SYMBOL_POINTERS) {
          uint32_t *indirect_symbol_indices = indirect_symtab + sect->reserved1;
          void **indirect_symbol_bindings = (void **)((uintptr_t)slide + sect->addr);
          for (uint i = 0; i < sect->size / sizeof(void *); i++) {
            uint32_t symtab_index = indirect_symbol_indices[i];
            if (symtab_index == INDIRECT_SYMBOL_ABS || symtab_index == INDIRECT_SYMBOL_LOCAL || symtab_index == (INDIRECT_SYMBOL_LOCAL   | INDIRECT_SYMBOL_ABS)) continue;
            uint32_t strtab_offset = symtab[symtab_index].n_un.n_strx;
            char *symbol_name = strtab + strtab_offset;
            struct ios_mem_task_entry *cur_task = task_head;
            while (cur_task) {
              if (strcmp(&symbol_name[1], cur_task->task.name) == 0) {
                if (cur_task->task.replaced != NULL && indirect_symbol_bindings[i] != cur_task->task.replacement) {
                  *(cur_task->task.replaced) = indirect_symbol_bindings[i];
                }
                indirect_symbol_bindings[i] = cur_task->task.replacement;
              }
              cur_task = cur_task->next;
            }
          }
        }
      }
    }
  }
  return 0;
}

static void sys_image_cb(const struct mach_header *header, intptr_t slide) {
  perform_memory_sync(tasks_head, header, slide);
}

int ios_memory_sync_image(const struct mach_header *header, intptr_t slide, struct ios_mem_task tasks[], size_t tasks_nel) {
  struct ios_mem_task_entry *task_head = NULL;
  for (size_t i = 0; i < tasks_nel; i++) {
    struct ios_mem_task_entry *entry = (struct ios_mem_task_entry *)malloc(sizeof(struct ios_mem_task_entry));
    entry->task = tasks[i];
    entry->next = task_head;
    task_head = entry;
  }
  int rv = perform_memory_sync(task_head, header, slide);
  struct ios_mem_task_entry *cur = task_head;
  while (cur) {
    struct ios_mem_task_entry *next = cur->next;
    free(cur);
    cur = next;
  }
  return rv;
}

int ios_memory_sync(struct ios_mem_task tasks[], size_t tasks_nel) {
  int rv = 0;
  for (size_t i = 0; i < tasks_nel; i++) {
    struct ios_mem_task_entry *entry = (struct ios_mem_task_entry *)malloc(sizeof(struct ios_mem_task_entry));
    entry->task = tasks[i];
    entry->next = tasks_head;
    tasks_head = entry;
  }
  if (!_dyld_image_count()) {
    _dyld_register_func_for_add_image(sys_image_cb);
  } else {
    uint32_t c = _dyld_image_count();
    for (uint32_t i = 0; i < c; i++) {
      sys_image_cb(_dyld_get_image_header(i), _dyld_get_image_vmaddr_slide(i));
    }
  }
  return rv;
}
