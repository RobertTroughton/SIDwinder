# CPU6510 implementation files
set(CPU6510_SOURCES
    ${CMAKE_CURRENT_SOURCE_DIR}/src/cpu6510.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/src/6510/CPU6510Impl.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/src/6510/CPUState.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/src/6510/MemorySubsystem.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/src/6510/AddressingModes.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/src/6510/InstructionExecutor.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/src/6510/OpcodeTable.cpp
)

set(CPU6510_HEADERS
    ${CMAKE_CURRENT_SOURCE_DIR}/src/cpu6510.h
    ${CMAKE_CURRENT_SOURCE_DIR}/src/6510/CPU6510Impl.h
    ${CMAKE_CURRENT_SOURCE_DIR}/src/6510/CPUState.h
    ${CMAKE_CURRENT_SOURCE_DIR}/src/6510/MemorySubsystem.h
    ${CMAKE_CURRENT_SOURCE_DIR}/src/6510/AddressingModes.h
    ${CMAKE_CURRENT_SOURCE_DIR}/src/6510/InstructionExecutor.h
)