
bits 64

kernel_subsystems_initialize:
    call memory_physical_initialize
    call memory_heap_initialize

    call process_initialize
    call thread_initialize
    call scheduler_initialize

    call service_registry_initialize
    call events_initialize
    call ipc_initialize

    ret