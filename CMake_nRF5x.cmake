cmake_minimum_required(VERSION 3.6)

# check if all the necessary tools paths have been provided.
if (NOT NRF5_SDK_PATH)
    message(FATAL_ERROR "The path to the nRF5 SDK (NRF5_SDK_PATH) must be set.")
endif ()

if (NOT NRFJPROG)
    message(FATAL_ERROR "The path to the nrfjprog utility (NRFJPROG) must be set.")
endif ()

if (NOT MERGEHEX)
    message(FATAL_ERROR "The path to the mergehex utility (MERGEHEX) must be set.")
endif ()

if (NOT NRFUTIL)
    message(FATAL_ERROR "The path to the nrfutil utility (NRFUTIL) must be set.")
endif ()

# convert toolchain path to bin path
if (DEFINED ARM_NONE_EABI_TOOLCHAIN_PATH)
    set(ARM_NONE_EABI_TOOLCHAIN_BIN_PATH ${ARM_NONE_EABI_TOOLCHAIN_PATH}/bin)
endif ()

# check if the nRF target has been set
if (NRF_TARGET MATCHES "nrf51")

elseif (NRF_TARGET MATCHES "nrf52")

elseif (NOT NRF_TARGET)
    message(FATAL_ERROR "nRF target must be defined")
else ()
    message(FATAL_ERROR "Only nRF51 and rRF52 boards are supported right now")
endif ()

# must be set in file (not macro) scope (in macro would point to parent CMake directory)
set(DIR_OF_nRF5x_CMAKE ${CMAKE_CURRENT_LIST_DIR})

macro(nRF5x_toolchainSetup)
    include(${DIR_OF_nRF5x_CMAKE}/arm-gcc-toolchain.cmake)
endmacro()

macro(nRF5x_selectLinkerScript)
    if (NOT DEFINED NRF5_LINKER_SCRIPT)
        if(${NRF_LINKER_CONFIG_TYPE} MATCHES "app_no_bl")
            set(LINKER_APP_BL "app_")
            set(LINKER_VARIANT "no_bl_")
        elseif(${NRF_LINKER_CONFIG_TYPE} MATCHES "app_release_bl")
            set(LINKER_APP_BL "app_")
            set(LINKER_VARIANT "with_release_bl_")
        elseif(${NRF_LINKER_CONFIG_TYPE} MATCHES "app_debug_bl")
            set(LINKER_APP_BL "app_")
            set(LINKER_VARIANT "with_debug_bl_")
        elseif(${NRF_LINKER_CONFIG_TYPE} MATCHES "bl")
            set(LINKER_APP_BL "secure_bootloader_")
            string(TOLOWER "${CMAKE_BUILD_TYPE}" CMAKE_BUILD_TYPE_TOLOWER)
            if(${CMAKE_BUILD_TYPE_TOLOWER} MATCHES "debug")
                set(LINKER_VARIANT "debug_")
            else()
                set(LINKER_VARIANT "release_")
            endif()
        endif()
        set(NRF5_LINKER_SCRIPT "${DIR_OF_nRF5x_CMAKE}/gcc_${LINKER_APP_BL}${LINKER_VARIANT}${NRF_TARGET}.ld")
    endif ()
    message("Using linker script ${NRF5_LINKER_SCRIPT}")
endmacro()

macro(nRF5x_setup WITH_SD WITH_MBR)
    if (NOT DEFINED ARM_GCC_TOOLCHAIN)
        message(FATAL_ERROR "The toolchain must be set up before calling this macro")
    endif ()

    if(${WITH_SD})
        if (NOT DEFINED SD_FAMILY)
            message(FATAL_ERROR "The SoftDevice family must be setup before calling this macro. Set SD_FAMILY.")
        endif ()
        string(TOUPPER ${SD_FAMILY} NRF_SOFTDEVICE)
        if (NRF_TARGET MATCHES "nrf51")
            set(NRF_SD_BLE_API_VERSION "2")
            set(SHORT_HW_VERSION "51")
        elseif (NRF_TARGET MATCHES "nrf52")
            set(NRF_SD_BLE_API_VERSION "6")
            set(SHORT_HW_VERSION "52")
        endif ()
        add_definitions(-DSOFTDEVICE_PRESENT -D${NRF_SOFTDEVICE} -DNRF_SD_BLE_API_VERSION=${NRF_SD_BLE_API_VERSION} -DSWI_DISABLE0 -DBLE_STACK_SUPPORT_REQD)
        set(SOFTDEVICE_PATH "${NRF5_SDK_PATH}/components/softdevice/${SD_FAMILY}/hex/${SD_FAMILY}_${NRF_TARGET}_${SD_REVISION}_softdevice.hex")
        include_directories(
                "${NRF5_SDK_PATH}/components/softdevice/${SD_FAMILY}/headers"
                "${NRF5_SDK_PATH}/components/softdevice/${SD_FAMILY}/headers/${NRF_TARGET}"
        )
    else()
        include_directories(
                "${NRF5_SDK_PATH}/components/drivers_nrf/nrf_soc_nosd"
        )
        # set a SD path anyway, just for the conveninence of having the FLASH_SOFTDEVICE target
        set(SOFTDEVICE_PATH "${NRF5_SDK_PATH}/components/softdevice/${SD_FAMILY}/hex/${SD_FAMILY}_${NRF_TARGET}_${SD_REVISION}_softdevice.hex")
    endif()

    if(${WITH_MBR})
        include_directories(
                "${NRF5_SDK_PATH}/components/softdevice/mbr/headers"
        )
        add_definitions(-DMBR_PRESENT)
    endif()

    # fix on macOS: prevent cmake from adding implicit parameters to Xcode
    set(CMAKE_OSX_SYSROOT "/")
    set(CMAKE_OSX_DEPLOYMENT_TARGET "")

    # language standard/version settings
    set(CMAKE_C_STANDARD 99)
    set(CMAKE_CXX_STANDARD 98)

    nRF5x_selectLinkerScript()

    list(APPEND SDK_SOURCE_FILES
            "${NRF5_SDK_PATH}/modules/nrfx/mdk/system_${NRF_TARGET}.c"
            "${NRF5_SDK_PATH}/modules/nrfx/mdk/gcc_startup_${NRF_TARGET}.S"
            )

    # CPU specific settings
    if (NRF_TARGET MATCHES "nrf51")
        # nRF51 (nRF51-DK => PCA10028)
        if (NOT NRF_BOARD)
            set(NRF_BOARD "PCA10028")
        else ()
            string(TOUPPER ${NRF_BOARD} NRF_BOARD)
        endif ()

        set(CPU_FLAGS "-mcpu=cortex-m0 -mfloat-abi=soft")
        add_definitions(-DBOARD_${NRF_BOARD} -DNRF51 -DNRF51422)
    elseif (NRF_TARGET MATCHES "nrf52")
        # nRF52 (nRF52-DK => PCA10040)
        if (NOT NRF_BOARD)
            set(NRF_BOARD "PCA10040")
        else ()
            string(TOUPPER ${NRF_BOARD} NRF_BOARD)
        endif ()

        set(CPU_FLAGS "-mcpu=cortex-m4 -mfloat-abi=hard -mfpu=fpv4-sp-d16")
        add_definitions(-DBOARD_${NRF_BOARD} -DNRF52 -DNRF52832 -DNRF52832_XXAA)
        add_definitions(-DNRF52_PAN_74 -DNRF52_PAN_64 -DNRF52_PAN_12 -DNRF52_PAN_58 -DNRF52_PAN_54 -DNRF52_PAN_31 -DNRF52_PAN_51 -DNRF52_PAN_36 -DNRF52_PAN_15 -DNRF52_PAN_20 -DNRF52_PAN_55)
    endif ()

    set(COMMON_FLAGS "-MP -MD -mthumb -mabi=aapcs -Wall -g3 -ffunction-sections -fdata-sections -fno-strict-aliasing -fno-builtin --short-enums ${CPU_FLAGS}")

    # compiler/assambler/linker flags
    set(CMAKE_C_FLAGS "${COMMON_FLAGS}")
    set(CMAKE_C_FLAGS_DEBUG "${CMAKE_C_FLAGS_DEBUG} -O1 -DDEBUG_NRF -DDEBUG_NRF_USER")
    set(CMAKE_C_FLAGS_RELEASE "${CMAKE_C_FLAGS_RELEASE} -O3")
    set(CMAKE_CXX_FLAGS "${COMMON_FLAGS}")
    set(CMAKE_CXX_FLAGS_DEBUG "${CMAKE_CXX_FLAGS_DEBUG} -O1 -DDEBUG_NRF -DDEBUG_NRF_USER")
    set(CMAKE_CXX_FLAGS_RELEASE "${CMAKE_CXX_FLAGS_RELEASE} -O3")
    set(CMAKE_ASM_FLAGS "-MP -MD -std=c99 -x assembler-with-cpp")
    set(CMAKE_EXE_LINKER_FLAGS "-mthumb -mabi=aapcs -std=gnu++98 -std=c99 -L ${NRF5_SDK_PATH}/modules/nrfx/mdk -T${NRF5_LINKER_SCRIPT} ${CPU_FLAGS} -Wl,--gc-sections --specs=nano.specs -lc -lnosys -lm")
    # note: we must override the default cmake linker flags so that CMAKE_C_FLAGS are not added implicitly
    set(CMAKE_C_LINK_EXECUTABLE "${CMAKE_C_COMPILER} <LINK_FLAGS> <OBJECTS> -o <TARGET> <LINK_LIBRARIES>")
    set(CMAKE_CXX_LINK_EXECUTABLE "${CMAKE_C_COMPILER} <LINK_FLAGS> <OBJECTS> -lstdc++ -o <TARGET> <LINK_LIBRARIES>")

    # basic board definitions and drivers
    include_directories(
            "${NRF5_SDK_PATH}/components"
            "${NRF5_SDK_PATH}/components/boards"
            "${NRF5_SDK_PATH}/components/softdevice/common"
            "${NRF5_SDK_PATH}/integration/nrfx"
            "${NRF5_SDK_PATH}/integration/nrfx/legacy"
            "${NRF5_SDK_PATH}/modules/nrfx"
            "${NRF5_SDK_PATH}/modules/nrfx/drivers/include"
            "${NRF5_SDK_PATH}/modules/nrfx/hal"
            "${NRF5_SDK_PATH}/modules/nrfx/mdk"
    )

    list(APPEND SDK_SOURCE_FILES
            "${NRF5_SDK_PATH}/components/boards/boards.c"
            "${NRF5_SDK_PATH}/components/softdevice/common/nrf_sdh.c"
            "${NRF5_SDK_PATH}/components/softdevice/common/nrf_sdh_ble.c"
            "${NRF5_SDK_PATH}/components/softdevice/common/nrf_sdh_soc.c"
            "${NRF5_SDK_PATH}/modules/nrfx/drivers/src/nrfx_clock.c"
            "${NRF5_SDK_PATH}/modules/nrfx/drivers/src/nrfx_gpiote.c"
            "${NRF5_SDK_PATH}/modules/nrfx/drivers/src/nrfx_uart.c"
            "${NRF5_SDK_PATH}/modules/nrfx/drivers/src/nrfx_uarte.c"
            "${NRF5_SDK_PATH}/modules/nrfx/drivers/src/prs/nrfx_prs.c"
            "${NRF5_SDK_PATH}/modules/nrfx/soc/nrfx_atomic.c"
            )


    # toolchain specific
    include_directories(
            "${NRF5_SDK_PATH}/components/toolchain/cmsis/include"
            "${NRF5_SDK_PATH}/components/toolchain/cmsis/dsp/Include"
    )


    # libraries
    include_directories(
            "${NRF5_SDK_PATH}/components/libraries/atomic"
            "${NRF5_SDK_PATH}/components/libraries/atomic_fifo"
            "${NRF5_SDK_PATH}/components/libraries/atomic_flags"
            "${NRF5_SDK_PATH}/components/libraries/balloc"
            "${NRF5_SDK_PATH}/components/libraries/bootloader/ble_dfu"
            "${NRF5_SDK_PATH}/components/libraries/cli"
            "${NRF5_SDK_PATH}/components/libraries/crc16"
            "${NRF5_SDK_PATH}/components/libraries/crc32"
            "${NRF5_SDK_PATH}/components/libraries/crypto"
            "${NRF5_SDK_PATH}/components/libraries/csense"
            "${NRF5_SDK_PATH}/components/libraries/csense_drv"
            "${NRF5_SDK_PATH}/components/libraries/delay"
            "${NRF5_SDK_PATH}/components/libraries/ecc"
            "${NRF5_SDK_PATH}/components/libraries/experimental_section_vars"
            "${NRF5_SDK_PATH}/components/libraries/experimental_task_manager"
            "${NRF5_SDK_PATH}/components/libraries/fds"
            "${NRF5_SDK_PATH}/components/libraries/fstorage"
            "${NRF5_SDK_PATH}/components/libraries/gfx"
            "${NRF5_SDK_PATH}/components/libraries/gpiote"
            "${NRF5_SDK_PATH}/components/libraries/hardfault"
            "${NRF5_SDK_PATH}/components/libraries/hci"
            "${NRF5_SDK_PATH}/components/libraries/led_softblink"
            "${NRF5_SDK_PATH}/components/libraries/log"
            "${NRF5_SDK_PATH}/components/libraries/log/src"
            "${NRF5_SDK_PATH}/components/libraries/low_power_pwm"
            "${NRF5_SDK_PATH}/components/libraries/mem_manager"
            "${NRF5_SDK_PATH}/components/libraries/memobj"
            "${NRF5_SDK_PATH}/components/libraries/mpu"
            "${NRF5_SDK_PATH}/components/libraries/mutex"
            "${NRF5_SDK_PATH}/components/libraries/pwm"
            "${NRF5_SDK_PATH}/components/libraries/pwr_mgmt"
            "${NRF5_SDK_PATH}/components/libraries/queue"
            "${NRF5_SDK_PATH}/components/libraries/ringbuf"
            "${NRF5_SDK_PATH}/components/libraries/scheduler"
            "${NRF5_SDK_PATH}/components/libraries/sdcard"
            "${NRF5_SDK_PATH}/components/libraries/slip"
            "${NRF5_SDK_PATH}/components/libraries/sortlist"
            "${NRF5_SDK_PATH}/components/libraries/spi_mngr"
            "${NRF5_SDK_PATH}/components/libraries/stack_guard"
            "${NRF5_SDK_PATH}/components/libraries/strerror"
            "${NRF5_SDK_PATH}/components/libraries/svc"
            "${NRF5_SDK_PATH}/components/libraries/timer"
            "${NRF5_SDK_PATH}/components/libraries/twi_mngr"
            "${NRF5_SDK_PATH}/components/libraries/twi_sensor"
            "${NRF5_SDK_PATH}/components/libraries/usbd"
            "${NRF5_SDK_PATH}/components/libraries/usbd/class/audio"
            "${NRF5_SDK_PATH}/components/libraries/usbd/class/cdc"
            "${NRF5_SDK_PATH}/components/libraries/usbd/class/cdc/acm"
            "${NRF5_SDK_PATH}/components/libraries/usbd/class/hid"
            "${NRF5_SDK_PATH}/components/libraries/usbd/class/hid/generic"
            "${NRF5_SDK_PATH}/components/libraries/usbd/class/hid/kbd"
            "${NRF5_SDK_PATH}/components/libraries/usbd/class/hid/mouse"
            "${NRF5_SDK_PATH}/components/libraries/usbd/class/msc"
            "${NRF5_SDK_PATH}/components/libraries/util"
    )

    list(APPEND SDK_SOURCE_FILES
            "${NRF5_SDK_PATH}/components/libraries/atomic/nrf_atomic.c"
            "${NRF5_SDK_PATH}/components/libraries/atomic_fifo/nrf_atfifo.c"
            "${NRF5_SDK_PATH}/components/libraries/atomic_flags/nrf_atflags.c"
            "${NRF5_SDK_PATH}/components/libraries/balloc/nrf_balloc.c"
            "${NRF5_SDK_PATH}/components/libraries/experimental_section_vars/nrf_section_iter.c"
            "${NRF5_SDK_PATH}/components/libraries/hardfault/hardfault_implementation.c"
            "${NRF5_SDK_PATH}/components/libraries/util/nrf_assert.c"
            "${NRF5_SDK_PATH}/components/libraries/util/app_util_platform.c"
            "${NRF5_SDK_PATH}/components/libraries/util/sdk_mapped_flags.c"
            "${NRF5_SDK_PATH}/components/libraries/log/src/nrf_log_backend_flash.c"
            "${NRF5_SDK_PATH}/components/libraries/log/src/nrf_log_backend_rtt.c"
            "${NRF5_SDK_PATH}/components/libraries/log/src/nrf_log_backend_serial.c"
            "${NRF5_SDK_PATH}/components/libraries/log/src/nrf_log_backend_uart.c"
            "${NRF5_SDK_PATH}/components/libraries/log/src/nrf_log_default_backends.c"
            "${NRF5_SDK_PATH}/components/libraries/log/src/nrf_log_frontend.c"
            "${NRF5_SDK_PATH}/components/libraries/log/src/nrf_log_str_formatter.c"
            "${NRF5_SDK_PATH}/components/libraries/memobj/nrf_memobj.c"
            "${NRF5_SDK_PATH}/components/libraries/pwr_mgmt/nrf_pwr_mgmt.c"
            "${NRF5_SDK_PATH}/components/libraries/ringbuf/nrf_ringbuf.c"
            "${NRF5_SDK_PATH}/components/libraries/strerror/nrf_strerror.c"
            "${NRF5_SDK_PATH}/components/libraries/uart/retarget.c"
            )

    # Segger RTT
    include_directories(
            "${NRF5_SDK_PATH}/external/segger_rtt/"
    )

    list(APPEND SDK_SOURCE_FILES
            "${NRF5_SDK_PATH}/external/segger_rtt/SEGGER_RTT_Syscalls_GCC.c"
            "${NRF5_SDK_PATH}/external/segger_rtt/SEGGER_RTT.c"
            "${NRF5_SDK_PATH}/external/segger_rtt/SEGGER_RTT_printf.c"
            )


    # Other external
    include_directories(
            "${NRF5_SDK_PATH}/external/fprintf/"
            "${NRF5_SDK_PATH}/external/utf_converter/"
    )

    list(APPEND SDK_SOURCE_FILES
            "${NRF5_SDK_PATH}/external/utf_converter/utf.c"
            "${NRF5_SDK_PATH}/external/fprintf/nrf_fprintf.c"
            "${NRF5_SDK_PATH}/external/fprintf/nrf_fprintf_format.c"
            )

    # adds target for erasing and flashing the board with a softdevice
    add_custom_target(FLASH_SOFTDEVICE ALL
            COMMAND ${NRFJPROG} --program ${SOFTDEVICE_PATH} -f ${NRF_TARGET} --sectorerase
            COMMAND sleep 0.5s
            COMMAND ${NRFJPROG} --reset -f ${NRF_TARGET}
            COMMENT "flashing SoftDevice"
            )

    add_custom_target(FLASH_ERASE ALL
            COMMAND ${NRFJPROG} --eraseall -f ${NRF_TARGET}
            COMMENT "erasing flashing"
            )

    add_custom_target(SDK_CONFIG ALL
            COMMAND java -jar ${NRF5_SDK_PATH}/external_tools/cmsisconfig/CMSIS_Configuration_Wizard.jar ${NRF_PROJECT_PATH}/sdk_config.h
            COMMENT "Launching SDK Configuration Wizard"
            )

    if (${CMAKE_HOST_SYSTEM_NAME} STREQUAL "Darwin")
        set(TERMINAL "open")
        set(TERMINAL_OPTS "")
    elseif (${CMAKE_HOST_SYSTEM_NAME} STREQUAL "Windows")
        set(TERMINAL "sh")
        set(TERMINAL_OPTS "")
    else ()
        set(TERMINAL "gnome-terminal")
        set(TERMINAL_OPTS "--")
    endif ()

    add_custom_target(START_JLINK ALL
            COMMAND ${TERMINAL} ${TERMINAL_OPTS} "${DIR_OF_nRF5x_CMAKE}/runJLinkGDBServer-${NRF_TARGET}"
            COMMAND ${TERMINAL} ${TERMINAL_OPTS} "${DIR_OF_nRF5x_CMAKE}/runJLinkExe-${NRF_TARGET}"
            COMMAND sleep 2s
            COMMAND ${TERMINAL} ${TERMINAL_OPTS} "${DIR_OF_nRF5x_CMAKE}/runJLinkRTTClient"
            COMMENT "started JLink commands"
            )

endmacro(nRF5x_setup WITH_SD WITH_MBR)

macro(nrfx_add_BleCommon)
    # Common Bluetooth Low Energy files
    include_directories(
            "${NRF5_SDK_PATH}/components/ble"
            "${NRF5_SDK_PATH}/components/ble/common"
            "${NRF5_SDK_PATH}/components/ble/ble_advertising"
            "${NRF5_SDK_PATH}/components/ble/ble_dtm"
            "${NRF5_SDK_PATH}/components/ble/ble_link_ctx_manager"
            "${NRF5_SDK_PATH}/components/ble/ble_racp"
            "${NRF5_SDK_PATH}/components/ble/nrf_ble_qwr"
            "${NRF5_SDK_PATH}/components/ble/peer_manager"
    )

    list(APPEND SDK_SOURCE_FILES
            "${NRF5_SDK_PATH}/components/softdevice/common/nrf_sdh_ble.c"
            "${NRF5_SDK_PATH}/components/ble/common/ble_advdata.c"
            "${NRF5_SDK_PATH}/components/ble/common/ble_conn_params.c"
            "${NRF5_SDK_PATH}/components/ble/common/ble_conn_state.c"
            "${NRF5_SDK_PATH}/components/ble/common/ble_srv_common.c"
            "${NRF5_SDK_PATH}/components/ble/ble_advertising/ble_advertising.c"
            "${NRF5_SDK_PATH}/components/ble/ble_link_ctx_manager/ble_link_ctx_manager.c"
            "${NRF5_SDK_PATH}/components/ble/ble_services/ble_nus/ble_nus.c"
            "${NRF5_SDK_PATH}/components/ble/nrf_ble_qwr/nrf_ble_qwr.c"
            )
endmacro(nrfx_add_BleCommon)

# adds a target for compiling and flashing an Application executable
# do not use this for bootloaders
macro(nRF5x_addAppExecutable EXECUTABLE_NAME SOURCE_FILES)
    # get git rev pre-build step to generate the revision header
    add_custom_target ( revision_gen
            COMMAND ${CMAKE_CURRENT_BINARY_DIR}/revision_gen.sh
            WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}/
            COMMENT "pre build steps for ${EXECUTABLE_NAME}")
    # executable
    add_executable(${EXECUTABLE_NAME} ${SDK_SOURCE_FILES} ${SOURCE_FILES})
    set_target_properties(${EXECUTABLE_NAME} PROPERTIES SUFFIX ".out")
    set_target_properties(${EXECUTABLE_NAME} PROPERTIES LINK_FLAGS "-Wl,-Map=${EXECUTABLE_NAME}.map")
    add_dependencies(${EXECUTABLE_NAME} revision_gen)

    # don't remove EXE_NAME, it's used in the template (for some reason referencing EXECUTABLE_NAME
    # directly in there doesn't work
    set(EXE_NAME ${EXECUTABLE_NAME})
    configure_file("${DIR_OF_nRF5x_CMAKE}/blsettings_gen.template.sh" "blsettings_gen.sh" @ONLY)
    configure_file("${DIR_OF_nRF5x_CMAKE}/revision_gen.template.sh" "revision_gen.sh" @ONLY)
    # additional POST BUILD steps to create the .bin and .hex files
    add_custom_command(TARGET ${EXECUTABLE_NAME}
            POST_BUILD
            COMMAND ${CMAKE_SIZE_UTIL} ${EXECUTABLE_NAME}.out
            COMMAND ${CMAKE_OBJCOPY} -O binary ${EXECUTABLE_NAME}.out "${EXECUTABLE_NAME}.bin"
            COMMAND ${CMAKE_OBJCOPY} -O ihex ${EXECUTABLE_NAME}.out "${EXECUTABLE_NAME}.hex"
            COMMAND ${CMAKE_CURRENT_BINARY_DIR}/blsettings_gen.sh
            COMMENT "post build steps for ${EXECUTABLE_NAME}")


    # custom target for flashing an application executable to the board
    add_custom_target("FLASH_${EXECUTABLE_NAME}" ALL
            DEPENDS ${EXECUTABLE_NAME}
            COMMAND ${NRFJPROG} --program ${EXECUTABLE_NAME}.hex -f ${NRF_TARGET} --sectorerase
            COMMAND sleep 0.5s
            COMMAND ${NRFJPROG} --reset -f ${NRF_TARGET}
            COMMENT "flashing ${EXECUTABLE_NAME}.hex"
            )
    # custom target for flashing the executable+bootloader_settings_page to the board
    add_custom_target("FLASH_${EXECUTABLE_NAME}+bl_settings" ALL
            DEPENDS ${EXECUTABLE_NAME}
            COMMAND ${NRFJPROG} --program ${EXECUTABLE_NAME}_with_bl_settings.hex -f ${NRF_TARGET} --sectorerase
            COMMAND sleep 0.5s
            COMMAND ${NRFJPROG} --reset -f ${NRF_TARGET}
            COMMENT "flashing ${EXECUTABLE_NAME}_with_bl_settings.hex"
            )
endmacro()

macro(nRF5x_addBootloaderExecutable EXECUTABLE_NAME SOURCE_FILES)
    # get git rev pre-build step to generate the revision header
    add_custom_target ( revision_gen
            COMMAND ${CMAKE_CURRENT_BINARY_DIR}/revision_gen.sh
            WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}/
            COMMENT "pre build steps for ${EXECUTABLE_NAME}")
    # executable
    add_executable(${EXECUTABLE_NAME} ${SDK_SOURCE_FILES} ${SOURCE_FILES})
    set_target_properties(${EXECUTABLE_NAME} PROPERTIES SUFFIX ".out")
    set_target_properties(${EXECUTABLE_NAME} PROPERTIES LINK_FLAGS "-Wl,-Map=${EXECUTABLE_NAME}.map")
    add_dependencies(${EXECUTABLE_NAME} revision_gen)

    # don't remove EXE_NAME, it's used in the template (for some reason referencing EXECUTABLE_NAME
    # directly in there doesn't work
    set(EXE_NAME ${EXECUTABLE_NAME})
    configure_file("${DIR_OF_nRF5x_CMAKE}/revision_gen.template.sh" "revision_gen.sh" @ONLY)
    # additional POST BUILD steps to create the .bin and .hex files
    add_custom_command(TARGET ${EXECUTABLE_NAME}
            POST_BUILD
            COMMAND ${CMAKE_SIZE_UTIL} ${EXECUTABLE_NAME}.out
            COMMAND ${CMAKE_OBJCOPY} -O binary ${EXECUTABLE_NAME}.out "${EXECUTABLE_NAME}.bin"
            COMMAND ${CMAKE_OBJCOPY} -O ihex ${EXECUTABLE_NAME}.out "${EXECUTABLE_NAME}.hex"
            COMMENT "post build steps for ${EXECUTABLE_NAME}")

    # custom target for flashing a bootloader executable to the board
    add_custom_target("FLASH_${EXECUTABLE_NAME}" ALL
            DEPENDS ${EXECUTABLE_NAME}
            COMMAND ${NRFJPROG} --program ${EXECUTABLE_NAME}.hex -f ${NRF_TARGET} --sectoranduicrerase
            COMMAND sleep 0.5s
            COMMAND ${NRFJPROG} --reset -f ${NRF_TARGET}
            COMMENT "flashing ${EXECUTABLE_NAME}.hex"
            )
endmacro()

# adds a target for compiling and flashing an executable
macro(nRF5x_addDFU_Package EXECUTABLE_NAME)
    # soft device FWID (used to create the DFU package: make sure it's correct, otherwise the package will
    # be generated correctly, but DFU will fail)
    # a list is available in nrfutil pkg generate --help, under "--sd-req TEXT"
    if (NOT SD_FWID)
        nRF5x_setSD_FWID(SD_FWID)
    endif()
    message("SD FWID: ${SD_FWID}")

    # don't remove EXE_NAME, it's used in the template (for some reason referencing EXECUTABLE_NAME
    # directly in there doesn't work
    set(EXE_NAME ${EXECUTABLE_NAME})
    configure_file("${DIR_OF_nRF5x_CMAKE}/dfu_gen.template.sh" "dfu_gen.sh" @ONLY)
    # custom target to create a DFU package
    add_custom_target("CREATE_DFU_PKG_${EXECUTABLE_NAME}" ALL
            DEPENDS ${EXECUTABLE_NAME}
            COMMAND ${CMAKE_CURRENT_BINARY_DIR}/dfu_gen.sh

            COMMENT "creating DFU package for ${EXECUTABLE_NAME}.hex "
            )
endmacro()

# adds app-level scheduler library
macro(nRF5x_addAppScheduler)
    include_directories(
            "${NRF5_SDK_PATH}/components/libraries/scheduler"
    )

    list(APPEND SDK_SOURCE_FILES
            "${NRF5_SDK_PATH}/components/libraries/scheduler/app_scheduler.c"
            )

endmacro(nRF5x_addAppScheduler)

# adds app-level FIFO libraries
macro(nRF5x_addAppFIFO)
    include_directories(
            "${NRF5_SDK_PATH}/components/libraries/fifo"
    )

    list(APPEND SDK_SOURCE_FILES
            "${NRF5_SDK_PATH}/components/libraries/fifo/app_fifo.c"
            )

endmacro(nRF5x_addAppFIFO)

# adds app-level Timer libraries
macro(nRF5x_addAppTimer)
    list(APPEND SDK_SOURCE_FILES
            "${NRF5_SDK_PATH}/components/libraries/timer/app_timer.c"
            )
endmacro(nRF5x_addAppTimer)

# adds app-level UART libraries
macro(nRF5x_addAppUART)
    include_directories(
            "${NRF5_SDK_PATH}/components/libraries/uart"
    )

    list(APPEND SDK_SOURCE_FILES
            "${NRF5_SDK_PATH}/integration/nrfx/legacy/nrf_drv_uart.c"
            "${NRF5_SDK_PATH}/components/libraries/uart/app_uart_fifo.c"
            )

endmacro(nRF5x_addAppUART)

# adds app-level Button library
macro(nRF5x_addAppButton)
    include_directories(
            "${NRF5_SDK_PATH}/components/libraries/button"
    )

    list(APPEND SDK_SOURCE_FILES
            "${NRF5_SDK_PATH}/components/libraries/button/app_button.c"
            )

endmacro(nRF5x_addAppButton)

# adds BSP (board support package) library
macro(nRF5x_addBSP WITH_BLE_BTN WITH_ANT_BTN WITH_NFC)
    include_directories(
            "${NRF5_SDK_PATH}/components/libraries/bsp"
    )

    list(APPEND SDK_SOURCE_FILES
            "${NRF5_SDK_PATH}/components/libraries/bsp/bsp.c"
            )

    if (${WITH_BLE_BTN})
        list(APPEND SDK_SOURCE_FILES
                "${NRF5_SDK_PATH}/components/libraries/bsp/bsp_btn_ble.c"
                )
    endif ()

    if (${WITH_ANT_BTN})
        list(APPEND SDK_SOURCE_FILES
                "${NRF5_SDK_PATH}/components/libraries/bsp/bsp_btn_ant.c"
                )
    endif ()

    if (${WITH_NFC})
        list(APPEND SDK_SOURCE_FILES
                "${NRF5_SDK_PATH}/components/libraries/bsp/bsp_nfc.c"
                )
    endif ()

endmacro(nRF5x_addBSP)

# adds Bluetooth Low Energy GATT support library
macro(nRF5x_addBLEGATT)
    include_directories(
            "${NRF5_SDK_PATH}/components/ble/nrf_ble_gatt"
    )

    list(APPEND SDK_SOURCE_FILES
            "${NRF5_SDK_PATH}/components/ble/nrf_ble_gatt/nrf_ble_gatt.c"
            )

endmacro(nRF5x_addBLEGATT)

# adds Bluetooth Low Energy advertising support library
macro(nRF5x_addBLEAdvertising)
    include_directories(
            "${NRF5_SDK_PATH}/components/ble/ble_advertising"
    )

    list(APPEND SDK_SOURCE_FILES
            "${NRF5_SDK_PATH}/components/ble/ble_advertising/ble_advertising.c"
            )

endmacro(nRF5x_addBLEAdvertising)

# adds Bluetooth Low Energy advertising support library
macro(nRF5x_addBLEPeerManager)
    include_directories(
            "${NRF5_SDK_PATH}/components/ble/peer_manager"
    )

    list(APPEND SDK_SOURCE_FILES
            "${NRF5_SDK_PATH}/components/ble/peer_manager/auth_status_tracker.c"
            "${NRF5_SDK_PATH}/components/ble/peer_manager/gatt_cache_manager.c"
            "${NRF5_SDK_PATH}/components/ble/peer_manager/gatts_cache_manager.c"
            "${NRF5_SDK_PATH}/components/ble/peer_manager/id_manager.c"
            "${NRF5_SDK_PATH}/components/ble/peer_manager/nrf_ble_lesc.c"
            "${NRF5_SDK_PATH}/components/ble/peer_manager/peer_data_storage.c"
            "${NRF5_SDK_PATH}/components/ble/peer_manager/peer_database.c"
            "${NRF5_SDK_PATH}/components/ble/peer_manager/peer_id.c"
            "${NRF5_SDK_PATH}/components/ble/peer_manager/peer_manager.c"
            "${NRF5_SDK_PATH}/components/ble/peer_manager/peer_manager_handler.c"
            "${NRF5_SDK_PATH}/components/ble/peer_manager/pm_buffer.c"
            "${NRF5_SDK_PATH}/components/ble/peer_manager/security_dispatcher.c"
            "${NRF5_SDK_PATH}/components/ble/peer_manager/security_manager.c"
            )

endmacro(nRF5x_addBLEPeerManager)

# adds app-level FDS (flash data storage) library
macro(nRF5x_addAppFDS)
    include_directories(
            "${NRF5_SDK_PATH}/components/libraries/fds"
            "${NRF5_SDK_PATH}/components/libraries/fstorage"
            "${NRF5_SDK_PATH}/components/libraries/experimental_section_vars"
    )

    list(APPEND SDK_SOURCE_FILES
            "${NRF5_SDK_PATH}/components/libraries/fds/fds.c"
            "${NRF5_SDK_PATH}/components/libraries/fstorage/nrf_fstorage.c"
            "${NRF5_SDK_PATH}/components/libraries/fstorage/nrf_fstorage_sd.c"
            "${NRF5_SDK_PATH}/components/libraries/fstorage/nrf_fstorage_nvmc.c"
            )

endmacro(nRF5x_addAppFDS)

macro(nRF5x_addAppError)

    include_directories(
            "${NRF5_SDK_PATH}/components/libraries/util"
    )

    list(APPEND SDK_SOURCE_FILES
            "${NRF5_SDK_PATH}/components/libraries/util/app_error.c"
            "${NRF5_SDK_PATH}/components/libraries/util/app_error_weak.c"
            "${NRF5_SDK_PATH}/components/libraries/util/app_error_handler_gcc.c"
            )
endmacro(nRF5x_addAppError)

# add just the raw fstorage, without FDS (e.g. as used by the Secure Bootloader)
macro(nRF5x_addRawFStorage WITH_SD)
    include_directories(
            "${NRF5_SDK_PATH}/components/libraries/fstorage"
            "${NRF5_SDK_PATH}/modules/nrfx/hal/"
            "${NRF5_SDK_PATH}/components/libraries/experimental_section_vars"
    )

    list(APPEND SDK_SOURCE_FILES
            "${NRF5_SDK_PATH}/components/libraries/fstorage/nrf_fstorage.c"
            "${NRF5_SDK_PATH}/modules/nrfx/hal/nrf_nvmc.c"
            )

    if(${WITH_SD})
        list(APPEND SDK_SOURCE_FILES
                "${NRF5_SDK_PATH}/components/libraries/fstorage/nrf_fstorage_sd.c"
                )
    else()
        list(APPEND SDK_SOURCE_FILES
                "${NRF5_SDK_PATH}/components/libraries/fstorage/nrf_fstorage_nvmc.c"
                )
endif()

endmacro(nRF5x_addRawFStorage)

# adds NFC library
# macro(nRF5x_addNFC)
#     # NFC includes
#     include_directories(
#             "${NRF5_SDK_PATH}/components/nfc/ndef/conn_hand_parser"
#             "${NRF5_SDK_PATH}/components/nfc/ndef/conn_hand_parser/ac_rec_parser"
#             "${NRF5_SDK_PATH}/components/nfc/ndef/conn_hand_parser/ble_oob_advdata_parser"
#             "${NRF5_SDK_PATH}/components/nfc/ndef/conn_hand_parser/le_oob_rec_parser"
#             "${NRF5_SDK_PATH}/components/nfc/ndef/connection_handover/ac_rec"
#             "${NRF5_SDK_PATH}/components/nfc/ndef/connection_handover/ble_oob_advdata"
#             "${NRF5_SDK_PATH}/components/nfc/ndef/connection_handover/ble_pair_lib"
#             "${NRF5_SDK_PATH}/components/nfc/ndef/connection_handover/ble_pair_msg"
#             "${NRF5_SDK_PATH}/components/nfc/ndef/connection_handover/common"
#             "${NRF5_SDK_PATH}/components/nfc/ndef/connection_handover/ep_oob_rec"
#             "${NRF5_SDK_PATH}/components/nfc/ndef/connection_handover/hs_rec"
#             "${NRF5_SDK_PATH}/components/nfc/ndef/connection_handover/le_oob_rec"
#             "${NRF5_SDK_PATH}/components/nfc/ndef/generic/message"
#             "${NRF5_SDK_PATH}/components/nfc/ndef/generic/record"
#             "${NRF5_SDK_PATH}/components/nfc/ndef/launchapp"
#             "${NRF5_SDK_PATH}/components/nfc/ndef/parser/message"
#             "${NRF5_SDK_PATH}/components/nfc/ndef/parser/record"
#             "${NRF5_SDK_PATH}/components/nfc/ndef/text"
#             "${NRF5_SDK_PATH}/components/nfc/ndef/uri"
#             "${NRF5_SDK_PATH}/components/nfc/t2t_lib"
#             "${NRF5_SDK_PATH}/components/nfc/t2t_parser"
#             "${NRF5_SDK_PATH}/components/nfc/t4t_lib"
#             "${NRF5_SDK_PATH}/components/nfc/t4t_parser/apdu"
#             "${NRF5_SDK_PATH}/components/nfc/t4t_parser/cc_file"
#             "${NRF5_SDK_PATH}/components/nfc/t4t_parser/hl_detection_procedure"
#             "${NRF5_SDK_PATH}/components/nfc/t4t_parser/tlv"
#     )
# 
#     list(APPEND SDK_SOURCE_FILES
#             "${NRF5_SDK_PATH}/components/nfc"
#             )
# 
# endmacro(nRF5x_addNFC)

macro(nRF5x_addBLEService NAME)
    include_directories(
            "${NRF5_SDK_PATH}/components/ble/ble_services/${NAME}"
    )

    list(APPEND SDK_SOURCE_FILES
            "${NRF5_SDK_PATH}/components/ble/ble_services/${NAME}/${NAME}.c"
            )

endmacro(nRF5x_addBLEService)

macro(nRF5x_addCryptoFrontend)
    include_directories(
            "${NRF5_SDK_PATH}/components/libraries/crypto"
            "${NRF5_SDK_PATH}/components/libraries/stack_info"
    )
    list(APPEND SDK_SOURCE_FILES
            "${NRF5_SDK_PATH}/components/libraries/crypto/nrf_crypto_aead.c"
            "${NRF5_SDK_PATH}/components/libraries/crypto/nrf_crypto_aes.c"
            "${NRF5_SDK_PATH}/components/libraries/crypto/nrf_crypto_aes_shared.c"
            "${NRF5_SDK_PATH}/components/libraries/crypto/nrf_crypto_ecc.c"
            "${NRF5_SDK_PATH}/components/libraries/crypto/nrf_crypto_ecdh.c"
            "${NRF5_SDK_PATH}/components/libraries/crypto/nrf_crypto_ecdsa.c"
            "${NRF5_SDK_PATH}/components/libraries/crypto/nrf_crypto_eddsa.c"
            "${NRF5_SDK_PATH}/components/libraries/crypto/nrf_crypto_error.c"
            "${NRF5_SDK_PATH}/components/libraries/crypto/nrf_crypto_hash.c"
            "${NRF5_SDK_PATH}/components/libraries/crypto/nrf_crypto_hkdf.c"
            "${NRF5_SDK_PATH}/components/libraries/crypto/nrf_crypto_hmac.c"
            "${NRF5_SDK_PATH}/components/libraries/crypto/nrf_crypto_init.c"
            "${NRF5_SDK_PATH}/components/libraries/crypto/nrf_crypto_rng.c"
            "${NRF5_SDK_PATH}/components/libraries/crypto/nrf_crypto_shared.c"
            )

endmacro(nRF5x_addCryptoFrontend)

macro(nRF5x_addCryptoBackend BE_PATH)
    include_directories(
            "${NRF5_SDK_PATH}/components/libraries/crypto/backend/cc310"
            "${NRF5_SDK_PATH}/components/libraries/crypto/backend/cc310_bl"
            "${NRF5_SDK_PATH}/components/libraries/crypto/backend/cifra"
            "${NRF5_SDK_PATH}/components/libraries/crypto/backend/mbedtls"
            "${NRF5_SDK_PATH}/components/libraries/crypto/backend/micro_ecc"
            "${NRF5_SDK_PATH}/external/micro-ecc/micro-ecc"
            "${NRF5_SDK_PATH}/components/libraries/crypto/backend/nrf_hw"
            "${NRF5_SDK_PATH}/components/libraries/crypto/backend/nrf_sw"
            "${NRF5_SDK_PATH}/components/libraries/crypto/backend/oberon"
            "${NRF5_SDK_PATH}/components/libraries/crypto/backend/optiga"
            "${NRF5_SDK_PATH}/components/libraries/crypto/backend"
            "${NRF5_SDK_PATH}/components/libraries/sha256"
    )
    file(GLOB BE_SRC_FILES CONFIGURE_DEPENDS "${NRF5_SDK_PATH}/components/libraries/crypto/backend/${BE_PATH}/*.c")
    list(APPEND SDK_SOURCE_FILES
            "${BE_SRC_FILES}"
            "${NRF5_SDK_PATH}/components/libraries/sha256/sha256.c"
            )
    if (${BE_PATH} MATCHES "micro_ecc")
        # this bring in the micro_ecc library, which must have been pre-compiled according to the instructions
        # in the SDK documentation
        if (NRF_TARGET MATCHES "nrf51")
            link_libraries("${NRF5_SDK_PATH}/external/micro-ecc/nrf51_armgcc/armgcc/micro_ecc_lib_nrf51.a")
        elseif (NRF_TARGET MATCHES "nrf52")
            link_libraries("${NRF5_SDK_PATH}/external/micro-ecc/nrf52hf_armgcc/armgcc/micro_ecc_lib_nrf52.a")
        else ()
            message(FATAL_ERROR "unknown platform, check NRF_TARGET")
        endif ()
    endif ()

endmacro(nRF5x_addCryptoBackend)

macro(nRF5x_addSecureBootloaderCommon WITH_SD)
    nRF5x_addRawFStorage(${WITH_SD})
    nRF5x_addCryptoFrontend()
    nRF5x_addCryptoBackend("micro_ecc")
    nRF5x_addCryptoBackend("nrf_sw")
    include_directories(
            "${NRF5_SDK_PATH}/components/libraries/bootloader"
            "${NRF5_SDK_PATH}/components/libraries/bootloader/dfu/"
            "${NRF5_SDK_PATH}/external/nano-pb/"
            "${NRF5_SDK_PATH}/components/libraries/crc32/"
            "${NRF5_SDK_PATH}/external/nano-pb/"
    )
    list(APPEND SDK_SOURCE_FILES
            "${NRF5_SDK_PATH}/components/libraries/bootloader/nrf_bootloader_app_start.c"
            "${NRF5_SDK_PATH}/components/libraries/bootloader/nrf_bootloader_app_start_final.c"
            "${NRF5_SDK_PATH}/components/libraries/bootloader/nrf_bootloader.c"
            "${NRF5_SDK_PATH}/components/libraries/bootloader/nrf_bootloader_dfu_timers.c"
            "${NRF5_SDK_PATH}/components/libraries/bootloader/nrf_bootloader_fw_activation.c"
            "${NRF5_SDK_PATH}/components/libraries/bootloader/nrf_bootloader_info.c"
            "${NRF5_SDK_PATH}/components/libraries/bootloader/nrf_bootloader_wdt.c"
            "${NRF5_SDK_PATH}/components/libraries/bootloader/dfu/nrf_dfu.c"
            "${NRF5_SDK_PATH}/components/libraries/bootloader/dfu/nrf_dfu_flash.c"
            "${NRF5_SDK_PATH}/components/libraries/bootloader/dfu/nrf_dfu_handling_error.c"
            "${NRF5_SDK_PATH}/components/libraries/bootloader/dfu/nrf_dfu_mbr.c"
            "${NRF5_SDK_PATH}/components/libraries/bootloader/dfu/nrf_dfu_req_handler.c"
            "${NRF5_SDK_PATH}/components/libraries/bootloader/dfu/nrf_dfu_settings.c"
            "${NRF5_SDK_PATH}/components/libraries/bootloader/dfu/nrf_dfu_transport.c"
            "${NRF5_SDK_PATH}/components/libraries/bootloader/dfu/nrf_dfu_utils.c"
            "${NRF5_SDK_PATH}/components/libraries/bootloader/dfu/nrf_dfu_validation.c"
            "${NRF5_SDK_PATH}/components/libraries/bootloader/dfu/nrf_dfu_ver_validation.c"
            "${NRF5_SDK_PATH}/components/libraries/bootloader/dfu/dfu-cc.pb.c"
            "${NRF5_SDK_PATH}/components/libraries/crc32/crc32.c"
            "${NRF5_SDK_PATH}/components/libraries/slip/slip.c"
            "${NRF5_SDK_PATH}/external/nano-pb/pb_decode.c"
            "${NRF5_SDK_PATH}/external/nano-pb/pb_common.c"
            )
endmacro(nRF5x_addSecureBootloaderCommon WITH_SD)

macro(nRF5x_addSecureBootloaderSerial SERIAL_TYPE)
    nRF5x_addSecureBootloaderCommon(FALSE)
    include_directories(
            "${NRF5_SDK_PATH}/components/libraries/bootloader/serial_dfu/"
    )
    list(APPEND SDK_SOURCE_FILES
            "${NRF5_SDK_PATH}/components/libraries/bootloader/serial_dfu/nrf_dfu_serial.c"
            "${NRF5_SDK_PATH}/components/libraries/bootloader/serial_dfu/nrf_dfu_serial_${SERIAL_TYPE}.c"
            )
    if (${SERIAL_TYPE} MATCHES "usb")
        list(APPEND SDK_SOURCE_FILES
                "${NRF5_SDK_PATH}/components/libraries/bootloader/dfu/nrf_dfu_trigger_usb.c"
                )
    endif ()

endmacro(nRF5x_addSecureBootloaderSerial)

macro(nRF5x_addSecureBootloaderBLE)
    nRF5x_addSecureBootloaderCommon(TRUE)
    include_directories(
            "${NRF5_SDK_PATH}/components/libraries/bootloader/ble_dfu/"
    )
    list(APPEND SDK_SOURCE_FILES
            "${NRF5_SDK_PATH}/components/libraries/bootloader/ble_dfu/nrf_dfu_ble.c"
            "${NRF5_SDK_PATH}/components/libraries/bootloader/dfu/nrf_dfu_settings_svci.c"
            "${NRF5_SDK_PATH}/components/libraries/bootloader/dfu/nrf_dfu_svci.c"
            "${NRF5_SDK_PATH}/components/libraries/bootloader/dfu/nrf_dfu_svci_handler.c"
            )
endmacro(nRF5x_addSecureBootloaderBLE)


macro(nRF5x_addSecureBootloaderANT)
    nRF5x_addSecureBootloaderCommon(TRUE)
    include_directories(
            "${NRF5_SDK_PATH}/components/libraries/bootloader/ant_dfu/"
    )
    list(APPEND SDK_SOURCE_FILES
            "${NRF5_SDK_PATH}/components/libraries/bootloader/ant_dfu/nrf_dfu_ant.c"
            )
endmacro(nRF5x_addSecureBootloaderANT)


# get one of the well known SD FWIDs based on softdevice
function(nRF5x_setSD_FWID SD_FWID)
    set(SD_FWID_NAMES_ARRAY
            "SD_FWID_s112_nrf52_6.0.0"
            "SD_FWID_s112_nrf52_6.1.0"
            "SD_FWID_s112_nrf52_6.1.1"
            "SD_FWID_s112_nrf52_7.0.0"
            "SD_FWID_s112_nrf52_7.0.1"
            "SD_FWID_s113_nrf52_7.0.0"
            "SD_FWID_s113_nrf52_7.0.1"
            "SD_FWID_s130_nrf51_1.0.0"
            "SD_FWID_s130_nrf51_2.0.0"
            "SD_FWID_s132_nrf52_2.0.0"
            "SD_FWID_s130_nrf51_2.0.1"
            "SD_FWID_s132_nrf52_2.0.1"
            "SD_FWID_s132_nrf52_3.0.0"
            "SD_FWID_s132_nrf52_3.1.0"
            "SD_FWID_s132_nrf52_4.0.0"
            "SD_FWID_s132_nrf52_4.0.2"
            "SD_FWID_s132_nrf52_4.0.3"
            "SD_FWID_s132_nrf52_4.0.4"
            "SD_FWID_s132_nrf52_4.0.5"
            "SD_FWID_s132_nrf52_5.0.0"
            "SD_FWID_s132_nrf52_5.1.0"
            "SD_FWID_s132_nrf52_6.0.0"
            "SD_FWID_s132_nrf52_6.1.0"
            "SD_FWID_s132_nrf52_6.1.1"
            "SD_FWID_s132_nrf52_7.0.0"
            "SD_FWID_s132_nrf52_7.0.1"
            "SD_FWID_s140_nrf52_6.0.0"
            "SD_FWID_s140_nrf52_6.1.0"
            "SD_FWID_s140_nrf52_6.1.1"
            "SD_FWID_s140_nrf52_7.0.0"
            "SD_FWID_s140_nrf52_7.0.1"
            "SD_FWID_s212_nrf52_6.1.1"
            "SD_FWID_s332_nrf52_6.1.1"
            "SD_FWID_s340_nrf52_6.1.1")


    set(SD_FWID_VALUES_ARRAY
    "0xA7"
    "0xB0"
    "0xB8"
    "0xC4"
    "0xCD"
    "0xC3"
    "0xCC"
    "0x67"
    "0x80"
    "0x81"
    "0x87"
    "0x88"
    "0x8C"
    "0x91"
    "0x95"
    "0x98"
    "0x99"
    "0x9E"
    "0x9F"
    "0x9D"
    "0xA5"
    "0xA8"
    "0xAF"
    "0xB7"
    "0xC2"
    "0xCB"
    "0xA9"
    "0xAE"
    "0xB6"
    "0xC1"
    "0xCA"
    "0xBC"
    "0xBA"
    "0xB9")

    # set the value we actually care about
    set(SD_FWID_NAME "SD_FWID_${SD_FAMILY}_${NRF_TARGET}_${SD_REVISION}")
    list(FIND SD_FWID_NAMES_ARRAY "${SD_FWID_NAME}" FWID_IDX)
    if(${FWID_IDX} LESS 0)
        message(FATAL_ERROR "Unknown chip/sd combo for FWID")
    endif()
    list(GET SD_FWID_VALUES_ARRAY ${FWID_IDX} FOUND_SD_FWID)
    set(SD_FWID ${FOUND_SD_FWID} PARENT_SCOPE)
endfunction(nRF5x_setSD_FWID SD_FWID)
