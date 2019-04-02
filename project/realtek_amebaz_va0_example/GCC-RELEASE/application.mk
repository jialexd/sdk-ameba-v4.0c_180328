
# Initialize tool chain
# -------------------------------------------------------------------
ARM_GCC_TOOLCHAIN = ../../../tools/arm-none-eabi-gcc/4_8-2014q3/bin/
AMEBA_TOOLDIR	= ../../../component/soc/realtek/8711b/misc/iar_utility/common/tools/
FLASH_TOOLDIR = ../../../component/soc/realtek/8195a/misc/gcc_utility/
FLASHDOWNLOAD_TOOLDIR = ../../../component/soc/realtek/8711b/misc/gnu_utility/flash_download/image
DEBUG_TOOLDIR = ../../../component/soc/realtek/8711b/misc/gcc_utility/

#CROSS_COMPILE = $(ARM_GCC_TOOLCHAIN)/arm-none-eabi-
CROSS_COMPILE = arm-none-eabi-

ota_idx = 1

# Compilation tools
AR = $(CROSS_COMPILE)ar
CC = $(CROSS_COMPILE)gcc
AS = $(CROSS_COMPILE)as
NM = $(CROSS_COMPILE)nm
LD = $(CROSS_COMPILE)gcc
GDB = $(CROSS_COMPILE)gdb
OBJCOPY = $(CROSS_COMPILE)objcopy
OBJDUMP = $(CROSS_COMPILE)objdump

OS := $(shell uname)

ifeq ($(findstring CYGWIN, $(OS)), CYGWIN) 
PICK = $(AMEBA_TOOLDIR)pick.exe
PAD  = $(AMEBA_TOOLDIR)padding.exe
CHKSUM = $(AMEBA_TOOLDIR)checksum.exe
OTA = $(AMEBA_TOOLDIR)ota.exe
else
PICK = $(AMEBA_TOOLDIR)pick
PAD  = $(AMEBA_TOOLDIR)padding
CHKSUM = $(AMEBA_TOOLDIR)checksum
OTA = $(AMEBA_TOOLDIR)ota
endif

# Initialize target name and target object files
# -------------------------------------------------------------------

all: application manipulate_images

mp: application manipulate_images

TARGET=application

OBJ_DIR=$(TARGET)/Debug/obj
BIN_DIR=$(TARGET)/Debug/bin

# Include folder list
# -------------------------------------------------------------------

INCLUDES =
INCLUDES += -I../inc
INCLUDES += -I../../../component/os/freertos
INCLUDES += -I../../../component/os/freertos/freertos_v8.1.2/Source/include
INCLUDES += -I../../../component/os/freertos/freertos_v8.1.2/Source/portable/GCC/ARM_CM4F
INCLUDES += -I../../../component/os/os_dep/include
INCLUDES += -I../../../component/common/api/network/include
INCLUDES += -I../../../component/common/api
INCLUDES += -I../../../component/common/api/at_cmd
INCLUDES += -I../../../component/common/api/platform
INCLUDES += -I../../../component/common/api/wifi
INCLUDES += -I../../../component/common/api/wifi/rtw_wpa_supplicant/src
INCLUDES += -I../../../component/common/api/wifi/rtw_wowlan
INCLUDES += -I../../../component/common/api/wifi/rtw_wpa_supplicant/wpa_supplicant
INCLUDES += -I../../../component/common/application
INCLUDES += -I../../../component/common/application/mqtt/MQTTClient
INCLUDES += -I../../../component/common/application/mqtt/MQTTPacket
INCLUDES += -I../../../component/common/example
INCLUDES += -I../../../component/common/example/wlan_fast_connect
INCLUDES += -I../../../component/common/drivers/modules
INCLUDES += -I../../../component/common/drivers/sdio/realtek/sdio_host/inc
INCLUDES += -I../../../component/common/drivers/inic/rtl8711b
INCLUDES += -I../../../component/common/drivers/usb_class/device
INCLUDES += -I../../../component/common/drivers/usb_class/device/class
INCLUDES += -I../../../component/common/drivers/wlan/realtek/include
INCLUDES += -I../../../component/common/drivers/wlan/realtek/src/osdep
INCLUDES += -I../../../component/common/drivers/wlan/realtek/src/hci
INCLUDES += -I../../../component/common/drivers/wlan/realtek/src/hal
INCLUDES += -I../../../component/common/drivers/wlan/realtek/src/hal/rtl8711b
INCLUDES += -I../../../component/common/drivers/wlan/realtek/src/hal/OUTSRC
INCLUDES += -I../../../component/common/drivers/wlan/realtek/wlan_ram_map/rom
INCLUDES += -I../../../component/common/file_system
INCLUDES += -I../../../component/common/network
INCLUDES += -I../../../component/common/network/lwip/lwip_v1.4.1/port/realtek/freertos
INCLUDES += -I../../../component/common/network/lwip/lwip_v1.4.1/src/include
INCLUDES += -I../../../component/common/network/lwip/lwip_v1.4.1/src/include/lwip
INCLUDES += -I../../../component/common/network/lwip/lwip_v1.4.1/src/include/ipv4
INCLUDES += -I../../../component/common/network/lwip/lwip_v1.4.1/port/realtek
INCLUDES += -I../../../component/common/network/ssl/polarssl-1.3.8/include
INCLUDES += -I../../../component/common/network/ssl/ssl_ram_map/rom
INCLUDES += -I../../../component/common/test
INCLUDES += -I../../../component/common/utilities
INCLUDES += -I../../../component/soc/realtek/8711b/app/monitor/include
INCLUDES += -I../../../component/soc/realtek/8711b/cmsis
INCLUDES += -I../../../component/soc/realtek/8711b/cmsis/device
INCLUDES += -I../../../component/soc/realtek/8711b/fwlib
INCLUDES += -I../../../component/soc/realtek/8711b/fwlib/include
INCLUDES += -I../../../component/soc/realtek/8711b/fwlib/ram_lib/crypto
INCLUDES += -I../../../component/soc/realtek/8711b/fwlib/rom_lib
INCLUDES += -I../../../component/soc/realtek/8711b/swlib/os_dep/include
INCLUDES += -I../../../component/soc/realtek/8711b/swlib/std_lib/include
INCLUDES += -I../../../component/soc/realtek/8711b/swlib/std_lib/libc/include
INCLUDES += -I../../../component/soc/realtek/8711b/swlib/std_lib/libc/rom/string
INCLUDES += -I../../../component/soc/realtek/8711b/swlib/std_lib/libgcc/rtl8195a/include
INCLUDES += -I../../../component/soc/realtek/8711b/swlib/rtl_lib
INCLUDES += -I../../../component/soc/realtek/8711b/misc
INCLUDES += -I../../../component/soc/realtek/8711b/misc/os
INCLUDES += -I../../../component/common/mbed/api
INCLUDES += -I../../../component/common/mbed/hal
INCLUDES += -I../../../component/common/mbed/hal_ext
INCLUDES += -I../../../component/common/mbed/targets/cmsis/rtl8711b
INCLUDES += -I../../../component/common/mbed/targets/hal/rtl8711b
INCLUDES += -I../../../project/realtek_8195a_gen_project/rtl8195a/sw/lib/sw_lib/mbed/api
INCLUDES += -I../../../component/common/application/mqtt/MQTTClient
INCLUDES += -I../../../component/common/network/websocket

# Source file list
# -------------------------------------------------------------------

SRC_C =
DRAM_C =

#app uart_adapter
SRC_C += ../../../component/common/application/uart_adapter/uart_adapter.c
      
#cmsis
SRC_C += ../../../component/soc/realtek/8711b/cmsis/device/app_start.c
SRC_C += ../../../component/soc/realtek/8711b/fwlib/ram_lib/startup.c
#SRC_C += ../../../component/soc/realtek/8711b/cmsis/device/system_8195a.c
    

#console
SRC_C += ../../../component/common/api/at_cmd/atcmd_lwip.c
SRC_C += ../../../component/common/api/at_cmd/atcmd_sys.c
SRC_C += ../../../component/common/api/at_cmd/atcmd_wifi.c
SRC_C += ../../../component/common/api/at_cmd/log_service.c
SRC_C += ../../../component/soc/realtek/8711b/app/monitor/ram/low_level_io.c
SRC_C += ../../../component/soc/realtek/8711b/app/monitor/ram/monitor.c
SRC_C += ../../../component/soc/realtek/8711b/app/monitor/ram/rtl_consol.c
SRC_C += ../../../component/soc/realtek/8711b/app/monitor/ram/rtl_trace.c
    
  
#lib
#SRC_C += ../../../component/soc/realtek/8711b/misc/bsp/lib/common/IAR/lib_platform.a
#SRC_C += ../../../component/soc/realtek/8711b/misc/bsp/lib/common/IAR/lib_rtlstd.a
#SRC_C += ../../../component/soc/realtek/8711b/misc/bsp/lib/common/IAR/lib_wlan.a
#SRC_C += ../../../component/soc/realtek/8711b/misc/bsp/lib/common/IAR/lib_wlan_mp.a
#SRC_C += ../../../component/soc/realtek/8711b/misc/bsp/lib/common/IAR/lib_wps.a
    
  
#network api wifi rtw_wpa_supplicant
SRC_C += ../../../component/common/api/wifi/rtw_wpa_supplicant/wpa_supplicant/wifi_eap_config.c
SRC_C += ../../../component/common/api/wifi/rtw_wpa_supplicant/wpa_supplicant/wifi_wps_config.c
          
        
#network api wifi        
SRC_C += ../../../component/common/api/wifi/wifi_conf.c
SRC_C += ../../../component/common/api/wifi/wifi_ind.c
SRC_C += ../../../component/common/api/wifi/wifi_promisc.c
SRC_C += ../../../component/common/api/wifi/wifi_simple_config.c
SRC_C += ../../../component/common/api/wifi/wifi_util.c
        
      
#network api      
SRC_C += ../../../component/common/api/lwip_netconf.c
      
    
#network app
SRC_C += ../../../component/common/application/mqtt/MQTTClient/MQTTClient.c
SRC_C += ../../../component/common/application/mqtt/MQTTPacket/MQTTConnectClient.c
SRC_C += ../../../component/common/application/mqtt/MQTTPacket/MQTTConnectServer.c
SRC_C += ../../../component/common/application/mqtt/MQTTPacket/MQTTDeserializePublish.c
SRC_C += ../../../component/common/application/mqtt/MQTTPacket/MQTTFormat.c
SRC_C += ../../../component/common/application/mqtt/MQTTClient/MQTTFreertos.c
SRC_C += ../../../component/common/application/mqtt/MQTTPacket/MQTTPacket.c
SRC_C += ../../../component/common/application/mqtt/MQTTPacket/MQTTSerializePublish.c
SRC_C += ../../../component/common/application/mqtt/MQTTPacket/MQTTSubscribeClient.c
SRC_C += ../../../component/common/application/mqtt/MQTTPacket/MQTTSubscribeServer.c
SRC_C += ../../../component/common/application/mqtt/MQTTPacket/MQTTUnsubscribeClient.c
SRC_C += ../../../component/common/application/mqtt/MQTTPacket/MQTTUnsubscribeServer.c
SRC_C += ../../../component/common/api/network/src/ping_test.c
SRC_C += ../../../component/common/utilities/ssl_client.c
SRC_C += ../../../component/common/utilities/tcptest.c
SRC_C += ../../../component/common/api/network/src/wlan_network.c
      
    
#network lwip api
SRC_C += ../../../component/common/network/lwip/lwip_v1.4.1/src/api/api_lib.c
SRC_C += ../../../component/common/network/lwip/lwip_v1.4.1/src/api/api_msg.c
SRC_C += ../../../component/common/network/lwip/lwip_v1.4.1/src/api/err.c
SRC_C += ../../../component/common/network/lwip/lwip_v1.4.1/src/api/netbuf.c
SRC_C += ../../../component/common/network/lwip/lwip_v1.4.1/src/api/netdb.c
SRC_C += ../../../component/common/network/lwip/lwip_v1.4.1/src/api/netifapi.c
SRC_C += ../../../component/common/network/lwip/lwip_v1.4.1/src/api/sockets.c
SRC_C += ../../../component/common/network/lwip/lwip_v1.4.1/src/api/tcpip.c
        
      
#network lwip core ipv4
SRC_C += ../../../component/common/network/lwip/lwip_v1.4.1/src/core/ipv4/autoip.c
SRC_C += ../../../component/common/network/lwip/lwip_v1.4.1/src/core/ipv4/icmp.c
SRC_C += ../../../component/common/network/lwip/lwip_v1.4.1/src/core/ipv4/igmp.c
SRC_C += ../../../component/common/network/lwip/lwip_v1.4.1/src/core/ipv4/inet.c
SRC_C += ../../../component/common/network/lwip/lwip_v1.4.1/src/core/ipv4/inet_chksum.c
SRC_C += ../../../component/common/network/lwip/lwip_v1.4.1/src/core/ipv4/ip.c
SRC_C += ../../../component/common/network/lwip/lwip_v1.4.1/src/core/ipv4/ip_addr.c
SRC_C += ../../../component/common/network/lwip/lwip_v1.4.1/src/core/ipv4/ip_frag.c
          
        
#network lwip core       
SRC_C += ../../../component/common/network/lwip/lwip_v1.4.1/src/core/def.c
SRC_C += ../../../component/common/network/lwip/lwip_v1.4.1/src/core/dhcp.c
SRC_C += ../../../component/common/network/lwip/lwip_v1.4.1/src/core/dns.c
SRC_C += ../../../component/common/network/lwip/lwip_v1.4.1/src/core/init.c
SRC_C += ../../../component/common/network/lwip/lwip_v1.4.1/src/core/lwip_timers.c
SRC_C += ../../../component/common/network/lwip/lwip_v1.4.1/src/core/mem.c
SRC_C += ../../../component/common/network/lwip/lwip_v1.4.1/src/core/memp.c
SRC_C += ../../../component/common/network/lwip/lwip_v1.4.1/src/core/netif.c
SRC_C += ../../../component/common/network/lwip/lwip_v1.4.1/src/core/pbuf.c
SRC_C += ../../../component/common/network/lwip/lwip_v1.4.1/src/core/raw.c
SRC_C += ../../../component/common/network/lwip/lwip_v1.4.1/src/core/stats.c
SRC_C += ../../../component/common/network/lwip/lwip_v1.4.1/src/core/sys.c
SRC_C += ../../../component/common/network/lwip/lwip_v1.4.1/src/core/tcp.c
SRC_C += ../../../component/common/network/lwip/lwip_v1.4.1/src/core/tcp_in.c
SRC_C += ../../../component/common/network/lwip/lwip_v1.4.1/src/core/tcp_out.c
SRC_C += ../../../component/common/network/lwip/lwip_v1.4.1/src/core/udp.c
        
      
#network lwip netif
SRC_C += ../../../component/common/network/lwip/lwip_v1.4.1/src/netif/etharp.c
        
      
#network lwip port
SRC_C += ../../../component/common/network/lwip/lwip_v1.4.1/port/realtek/freertos/ethernetif.c
SRC_C += ../../../component/common/drivers/wlan/realtek/src/osdep/lwip_intf.c
SRC_C += ../../../component/common/network/lwip/lwip_v1.4.1/port/realtek/freertos/sys_arch.c
      
#network - wsclient
SRC_C += ../../../component/common/network/websocket/wsclient_tls.c  

#network lwip     
SRC_C += ../../../component/common/network/dhcp/dhcps.c
SRC_C += ../../../component/common/network/sntp/sntp.c
      
    
#network polarssl polarssl
SRC_C += ../../../component/common/network/ssl/polarssl-1.3.8/library/aesni.c
SRC_C += ../../../component/common/network/ssl/polarssl-1.3.8/library/blowfish.c
SRC_C += ../../../component/common/network/ssl/polarssl-1.3.8/library/camellia.c
SRC_C += ../../../component/common/network/ssl/polarssl-1.3.8/library/ccm.c
SRC_C += ../../../component/common/network/ssl/polarssl-1.3.8/library/certs.c
SRC_C += ../../../component/common/network/ssl/polarssl-1.3.8/library/cipher.c
SRC_C += ../../../component/common/network/ssl/polarssl-1.3.8/library/cipher_wrap.c
SRC_C += ../../../component/common/network/ssl/polarssl-1.3.8/library/debug.c
SRC_C += ../../../component/common/network/ssl/polarssl-1.3.8/library/ecp_ram.c
SRC_C += ../../../component/common/network/ssl/polarssl-1.3.8/library/entropy.c
SRC_C += ../../../component/common/network/ssl/polarssl-1.3.8/library/entropy_poll.c
SRC_C += ../../../component/common/network/ssl/polarssl-1.3.8/library/error.c
SRC_C += ../../../component/common/network/ssl/polarssl-1.3.8/library/gcm.c
SRC_C += ../../../component/common/network/ssl/polarssl-1.3.8/library/havege.c
SRC_C += ../../../component/common/network/ssl/polarssl-1.3.8/library/md2.c
SRC_C += ../../../component/common/network/ssl/polarssl-1.3.8/library/md4.c
SRC_C += ../../../component/common/network/ssl/polarssl-1.3.8/library/memory_buffer_alloc.c
SRC_C += ../../../component/common/network/ssl/polarssl-1.3.8/library/net.c
SRC_C += ../../../component/common/network/ssl/polarssl-1.3.8/library/padlock.c
SRC_C += ../../../component/common/network/ssl/polarssl-1.3.8/library/pbkdf2.c
SRC_C += ../../../component/common/network/ssl/polarssl-1.3.8/library/pkcs11.c
SRC_C += ../../../component/common/network/ssl/polarssl-1.3.8/library/pkcs12.c
SRC_C += ../../../component/common/network/ssl/polarssl-1.3.8/library/pkcs5.c
SRC_C += ../../../component/common/network/ssl/polarssl-1.3.8/library/pkparse.c
SRC_C += ../../../component/common/network/ssl/polarssl-1.3.8/library/platform.c
SRC_C += ../../../component/common/network/ssl/polarssl-1.3.8/library/ripemd160.c
SRC_C += ../../../component/common/network/ssl/polarssl-1.3.8/library/ssl_cache.c
SRC_C += ../../../component/common/network/ssl/polarssl-1.3.8/library/ssl_ciphersuites.c
SRC_C += ../../../component/common/network/ssl/polarssl-1.3.8/library/ssl_cli.c
SRC_C += ../../../component/common/network/ssl/polarssl-1.3.8/library/ssl_srv.c
SRC_C += ../../../component/common/network/ssl/polarssl-1.3.8/library/ssl_tls.c
SRC_C += ../../../component/common/network/ssl/polarssl-1.3.8/library/threading.c
SRC_C += ../../../component/common/network/ssl/polarssl-1.3.8/library/timing.c
SRC_C += ../../../component/common/network/ssl/polarssl-1.3.8/library/version.c
SRC_C += ../../../component/common/network/ssl/polarssl-1.3.8/library/version_features.c
SRC_C += ../../../component/common/network/ssl/polarssl-1.3.8/library/x509.c
SRC_C += ../../../component/common/network/ssl/polarssl-1.3.8/library/x509_create.c
SRC_C += ../../../component/common/network/ssl/polarssl-1.3.8/library/x509_crl.c
SRC_C += ../../../component/common/network/ssl/polarssl-1.3.8/library/x509_crt.c
SRC_C += ../../../component/common/network/ssl/polarssl-1.3.8/library/x509_csr.c
SRC_C += ../../../component/common/network/ssl/polarssl-1.3.8/library/x509write_crt.c
SRC_C += ../../../component/common/network/ssl/polarssl-1.3.8/library/x509write_csr.c
SRC_C += ../../../component/common/network/ssl/polarssl-1.3.8/library/xtea.c
        
      
#network polarssl ssl_ram_map
SRC_C += ../../../component/common/network/ssl/ssl_ram_map/ssl_ram_map.c
        
      
    
  
#os freertos portable
SRC_C += ../../../component/os/freertos/freertos_v8.1.2/Source/portable/MemMang/heap_5.c
SRC_C += ../../../component/os/freertos/freertos_v8.1.2/Source/portable/GCC/ARM_CM4F/port.c
#SRC_C += ../../../component/os/freertos/freertos_v8.1.2/Source/portable/IAR/ARM_CM4F/portasm.s
        
      
#os freertos       
SRC_C += ../../../component/os/freertos/cmsis_os.c
SRC_C += ../../../component/os/freertos/freertos_v8.1.2/Source/croutine.c
SRC_C += ../../../component/os/freertos/freertos_v8.1.2/Source/event_groups.c
SRC_C += ../../../component/os/freertos/freertos_service.c
SRC_C += ../../../component/os/freertos/freertos_v8.1.2/Source/list.c
SRC_C += ../../../component/os/freertos/freertos_v8.1.2/Source/queue.c
SRC_C += ../../../component/os/freertos/freertos_v8.1.2/Source/tasks.c
SRC_C += ../../../component/os/freertos/freertos_v8.1.2/Source/timers.c
      
    
#os osdep
SRC_C += ../../../component/os/os_dep/device_lock.c
SRC_C += ../../../component/os/os_dep/osdep_service.c
      
    
  
#peripheral api
SRC_C += ../../../component/common/mbed/targets/hal/rtl8711b/analogin_api.c
SRC_C += ../../../component/common/mbed/targets/hal/rtl8711b/dma_api.c
SRC_C += ../../../component/common/mbed/targets/hal/rtl8711b/efuse_api.c
SRC_C += ../../../component/common/mbed/targets/hal/rtl8711b/flash_api.c
SRC_C += ../../../component/common/mbed/targets/hal/rtl8711b/gpio_api.c
SRC_C += ../../../component/common/mbed/targets/hal/rtl8711b/gpio_irq_api.c
SRC_C += ../../../component/common/mbed/targets/hal/rtl8711b/i2c_api.c
SRC_C += ../../../component/common/mbed/targets/hal/rtl8711b/i2s_api.c
SRC_C += ../../../component/common/mbed/targets/hal/rtl8711b/nfc_api.c
SRC_C += ../../../component/common/mbed/targets/hal/rtl8711b/pinmap.c
SRC_C += ../../../component/common/mbed/targets/hal/rtl8711b/pinmap_common.c
SRC_C += ../../../component/common/mbed/targets/hal/rtl8711b/port_api.c
SRC_C += ../../../component/common/mbed/targets/hal/rtl8711b/pwmout_api.c
SRC_C += ../../../component/common/mbed/targets/hal/rtl8711b/rtc_api.c
SRC_C += ../../../component/common/mbed/targets/hal/rtl8711b/serial_api.c
SRC_C += ../../../component/common/mbed/targets/hal/rtl8711b/sleep.c
SRC_C += ../../../component/common/mbed/targets/hal/rtl8711b/spi_api.c
SRC_C += ../../../component/common/mbed/targets/hal/rtl8711b/sys_api.c
SRC_C += ../../../component/common/mbed/targets/hal/rtl8711b/timer_api.c
SRC_C += ../../../component/common/mbed/targets/hal/rtl8711b/us_ticker.c
SRC_C += ../../../component/common/mbed/targets/hal/rtl8711b/us_ticker_api.c
SRC_C += ../../../component/common/mbed/targets/hal/rtl8711b/wait_api.c
SRC_C += ../../../component/common/mbed/targets/hal/rtl8711b/wdt_api.c
      
    
#peripheral rtl8710b
SRC_C += ../../../component/soc/realtek/8711b/fwlib/ram_lib/rtl8710b_dsleepcfg.c
SRC_C += ../../../component/soc/realtek/8711b/fwlib/ram_lib/rtl8710b_dstandbycfg.c
SRC_C += ../../../component/soc/realtek/8711b/fwlib/ram_lib/rtl8710b_intfcfg.c
SRC_C += ../../../component/soc/realtek/8711b/misc/rtl8710b_ota.c
SRC_C += ../../../component/soc/realtek/8711b/fwlib/ram_lib/rtl8710b_pinmapcfg.c
SRC_C += ../../../component/soc/realtek/8711b/fwlib/ram_lib/rtl8710b_sleepcfg.c
      

     
#utilities example
SRC_C += ../../../component/common/example/bcast/example_bcast.c
SRC_C += ../../../component/common/example/dct/example_dct.c
SRC_C += ../../../component/common/example/eap/example_eap.c
SRC_C += ../../../component/common/example/example_entry.c
SRC_C += ../../../component/common/example/get_beacon_frame/example_get_beacon_frame.c
SRC_C += ../../../component/common/example/high_load_memory_use/example_high_load_memory_use.c
SRC_C += ../../../component/common/example/http_client/example_http_client.c
SRC_C += ../../../component/common/example/httpc/example_httpc.c
SRC_C += ../../../component/common/example/httpd/example_httpd.c
SRC_C += ../../../component/common/example/http_download/example_http_download.c
SRC_C += ../../../component/common/example/mcast/example_mcast.c
SRC_C += ../../../component/common/example/mdns/example_mdns.c
SRC_C += ../../../component/common/example/mqtt/example_mqtt.c
SRC_C += ../../../component/common/example/nonblock_connect/example_nonblock_connect.c
SRC_C += ../../../component/common/example/rarp/example_rarp.c
SRC_C += ../../../component/common/example/sntp_showtime/example_sntp_showtime.c
SRC_C += ../../../component/common/example/socket_select/example_socket_select.c
SRC_C += ../../../component/common/example/ssl_download/example_ssl_download.c
SRC_C += ../../../component/common/example/ssl_server/example_ssl_server.c
SRC_C += ../../../component/common/example/tcp_keepalive/example_tcp_keepalive.c
SRC_C += ../../../component/common/example/uart_atcmd/example_uart_atcmd.c
SRC_C += ../../../component/common/example/wifi_mac_monitor/example_wifi_mac_monitor.c
SRC_C += ../../../component/common/example/wlan_fast_connect/example_wlan_fast_connect.c
SRC_C += ../../../component/common/example/wlan_scenario/example_wlan_scenario.c
SRC_C += ../../../component/common/example/websocket/example_wsclient.c
SRC_C += ../../../component/common/example/xml/example_xml.c
SRC_C += ../../../component/common/example/uart_firmware_update/example_uart_update.c


#network - httpc
SRC_C += ../../../component/common/network/httpc/httpc_tls.c

#network - httpd
SRC_C += ../../../component/common/network/httpd/httpd_tls.c   
    
#utilities 
SRC_C += ../../../component/common/utilities/cJSON.c
SRC_C += ../../../component/common/utilities/http_client.c
SRC_C += ../../../component/common/utilities/uart_socket.c
SRC_C += ../../../component/common/utilities/webserver.c
SRC_C += ../../../component/common/utilities/xml.c
    
  
#user
SRC_C += ../src/main.c


# Generate obj list
# -------------------------------------------------------------------

SRC_O = $(patsubst %.c,%.o,$(SRC_C))
DRAM_O = $(patsubst %.c,%.o,$(DRAM_C))

SRC_C_LIST = $(notdir $(SRC_C)) $(notdir $(DRAM_C))
OBJ_LIST = $(addprefix $(OBJ_DIR)/,$(patsubst %.c,%.o,$(SRC_C_LIST)))
DEPENDENCY_LIST = $(addprefix $(OBJ_DIR)/,$(patsubst %.c,%.d,$(SRC_C_LIST)))

# Compile options
# -------------------------------------------------------------------

CFLAGS =
CFLAGS += -DM3 -DCONFIG_PLATFORM_8711B -D__IEEE_LITTLE_ENDIAN
CFLAGS += -mcpu=cortex-m4 -mthumb -mfloat-abi=hard -mfpu=fpv4-sp-d16 -g2 -w -O2 -Wno-pointer-sign -fno-common -fmessage-length=0  -ffunction-sections -fdata-sections -fomit-frame-pointer -fno-short-enums -DF_CPU=166000000L -std=gnu99 -fsigned-char

LFLAGS = 
LFLAGS += -mcpu=cortex-m4 -mthumb -mfloat-abi=hard -mfpu=fpv4-sp-d16 -g --specs=nano.specs -nostartfiles -Wl,-Map=$(BIN_DIR)/application.map -Os -Wl,--gc-sections -Wl,--cref -Wl,--entry=Reset_Handler -Wl,--no-enum-size-warning -Wl,--no-wchar-size-warning
LFLAGS += -Wl,-wrap,malloc -Wl,-wrap,free -Wl,-wrap,realloc


LIBFLAGS =
all: LIBFLAGS += -L../../../component/soc/realtek/8711b/misc/bsp/lib/common/GCC/ -l_platform -l_wlan -l_wps -l_rtlstd -lm -lc -lnosys -lgcc -l_websocket -l_http -l_mdns
mp: LIBFLAGS += -L../../../component/soc/realtek/8711b/misc/bsp/lib/common/GCC/ -l_platform -l_wlan_mp -l_wps -l_rtlstd -lm -lc -lnosys -lgcc -l_websocket -l_http -l_mdns

RAMALL_BIN =
OTA_BIN = 
all: RAMALL_BIN = ram_all.bin
all: OTA_BIN = ota.bin
mp: RAMALL_BIN = ram_all_mp.bin
mp: OTA_BIN = ota_mp.bin

IMAGE2_OTA1=
IMAGE2_OTA2=
OTA_ALL=
all:IMAGE2_OTA1 = image2_all_ota1.bin
all:IMAGE2_OTA2 = image2_all_ota2.bin
all:OTA_ALL = ota_all.bin
mp:IMAGE2_OTA1 = image2_all_ota1_mp.bin
mp:IMAGE2_OTA2 = image2_all_ota2_mp.bin
mp:OTA_ALL = ota_all_mp.bin
# Compile
# -------------------------------------------------------------------

.PHONY: application
application: prerequirement build_info $(SRC_O) $(DRAM_O)

ifeq ("${ota_idx}", "1")
	$(LD) $(LFLAGS) -o $(BIN_DIR)/$(TARGET).axf  $(OBJ_LIST) $(OBJ_DIR)/boot_all.o $(LIBFLAGS) -T./rlx8711B-symbol-v02-img2_xip1.ld
else ifeq ("${ota_idx}", "2")
	$(LD) $(LFLAGS) -o $(BIN_DIR)/$(TARGET).axf  $(OBJ_LIST) $(OBJ_DIR)/boot_all.o $(LIBFLAGS) -T./rlx8711B-symbol-v02-img2_xip2.ld
else
	@echo ===========================================================
	@echo ota_idx must be "1" or "2"
	@echo ===========================================================
endif




	$(OBJDUMP) -d $(BIN_DIR)/$(TARGET).axf > $(BIN_DIR)/$(TARGET).asm


# Manipulate Image
# -------------------------------------------------------------------
	
.PHONY: manipulate_images
manipulate_images:	
	@echo ===========================================================
	@echo Image manipulating
	@echo ===========================================================
	$(NM) $(BIN_DIR)/$(TARGET).axf | sort > $(BIN_DIR)/$(TARGET).nmap

	$(OBJCOPY) -j .ram_image2.entry -j .ram_image2.data -j .ram_image2.bss -j .ram_image2.skb.bss -j .ram_heap.data -Obinary $(BIN_DIR)/$(TARGET).axf $(BIN_DIR)/ram_2.r.bin
	$(OBJCOPY) -j .xip_image2.text -Obinary $(BIN_DIR)/$(TARGET).axf $(BIN_DIR)/xip_image2.bin
	$(OBJCOPY) -j .ram_rdp.text -Obinary $(BIN_DIR)/$(TARGET).axf $(BIN_DIR)/rdp.bin


	cp ../../../component/soc/realtek/8711b/misc/bsp/image/boot_all.bin $(BIN_DIR)/boot_all.bin
	chmod 777 $(BIN_DIR)/boot_all.bin
	chmod +rx $(PICK) $(CHKSUM) $(PAD) $(OTA)

	$(PICK) 0x`grep __ram_image2_text_start__ $(BIN_DIR)/$(TARGET).nmap | gawk '{print $$1}'` 0x`grep __ram_image2_text_end__ $(BIN_DIR)/$(TARGET).nmap | gawk '{print $$1}'` $(BIN_DIR)/ram_2.r.bin $(BIN_DIR)/ram_2.bin raw
	$(PICK) 0x`grep __ram_image2_text_start__ $(BIN_DIR)/$(TARGET).nmap | gawk '{print $$1}'` 0x`grep __ram_image2_text_end__ $(BIN_DIR)/$(TARGET).nmap | gawk '{print $$1}'` $(BIN_DIR)/ram_2.bin $(BIN_DIR)/ram_2.p.bin
	$(PICK) 0x`grep __xip_image2_start__ $(BIN_DIR)/$(TARGET).nmap | gawk '{print $$1}'` 0x`grep __xip_image2_start__ $(BIN_DIR)/$(TARGET).nmap | gawk '{print $$1}'` $(BIN_DIR)/xip_image2.bin $(BIN_DIR)/xip_image2.p.bin
	




ifeq ("${ota_idx}", "1")
	cat $(BIN_DIR)/xip_image2.p.bin > $(BIN_DIR)/$(IMAGE2_OTA1)
	chmod 777 $(BIN_DIR)/$(IMAGE2_OTA1)
	cat $(BIN_DIR)/ram_2.p.bin >> $(BIN_DIR)/$(IMAGE2_OTA1)
	$(CHKSUM) $(BIN_DIR)/$(IMAGE2_OTA1) || true
	#rm $(BIN_DIR)/xip_image2.p.bin $(BIN_DIR)/ram_2.p.bin
else ifeq ("${ota_idx}", "2")
	cat $(BIN_DIR)/xip_image2.p.bin > $(BIN_DIR)/$(IMAGE2_OTA2)
	chmod 777 $(BIN_DIR)/$(IMAGE2_OTA2)
	cat $(BIN_DIR)/ram_2.p.bin >> $(BIN_DIR)/$(IMAGE2_OTA2)
	$(CHKSUM) $(BIN_DIR)/$(IMAGE2_OTA2) || true
	$(OTA) $(BIN_DIR)/$(IMAGE2_OTA1) 0x800B000 $(BIN_DIR)/$(IMAGE2_OTA2) 0x08080000 0x20170111 $(BIN_DIR)/$(OTA_ALL)
else
	@echo ===========================================================
	@echo ota_idx must be "1" or "2"
	@echo ===========================================================
endif

# ramall_bin
#	$(PAD) 44k 0xFF $(BIN_DIR)/boot_all.bin
#	cat $(BIN_DIR)/boot_all.bin > $(BIN_DIR)/$(RAMALL_BIN)
#	chmod 777 $(BIN_DIR)/$(RAMALL_BIN)
#	cat $(BIN_DIR)/image2_all_ota1.bin  >> $(BIN_DIR)/$(RAMALL_BIN)
#	cat $(BIN_DIR)/image2_all_ota2.bin  >> $(BIN_DIR)/$(RAMALL_BIN)


# Generate build info
# -------------------------------------------------------------------	

.PHONY: build_info
build_info:
	@echo \#define UTS_VERSION \"`date +%Y/%m/%d-%T`\" > .ver
	@echo \#define RTL8195AFW_COMPILE_TIME \"`date +%Y/%m/%d-%T`\" >> .ver
	@echo \#define RTL8195AFW_COMPILE_DATE \"`date +%Y%m%d`\" >> .ver
	@echo \#define RTL8195AFW_COMPILE_BY \"`id -u -n`\" >> .ver
	@echo \#define RTL8195AFW_COMPILE_HOST \"`$(HOSTNAME_APP)`\" >> .ver
	@if [ -x /bin/dnsdomainname ]; then \
		echo \#define RTL8195AFW_COMPILE_DOMAIN \"`dnsdomainname`\"; \
	elif [ -x /bin/domainname ]; then \
		echo \#define RTL8195AFW_COMPILE_DOMAIN \"`domainname`\"; \
	else \
		echo \#define RTL8195AFW_COMPILE_DOMAIN ; \
	fi >> .ver

	@echo \#define RTL195AFW_COMPILER \"gcc `$(CC) $(CFLAGS) -dumpversion | tr --delete '\r'`\" >> .ver
	@mv -f .ver ../inc/$@.h


.PHONY: prerequirement
prerequirement:
	@echo ===========================================================
	@echo Build $(TARGET)
	@echo ===========================================================
	mkdir -p $(OBJ_DIR)
	mkdir -p $(BIN_DIR)
	#cp ../../../component/soc/realtek/8195a/misc/bsp/image/ram_1.r.bin $(OBJ_DIR)/ram_1.r.bin
	cp ../../../component/soc/realtek/8711b/misc/bsp/image/boot_all.bin $(OBJ_DIR)/boot_all.bin

	#chmod 777 $(OBJ_DIR)/ram_1.r.bin
	chmod 777 $(OBJ_DIR)/boot_all.bin
#	$(OBJCOPY) --rename-section .data=.loader.data,contents,alloc,load,readonly,data -I binary -O elf32-littlearm -B arm $(OBJ_DIR)/boot_all.bin $(OBJ_DIR)/boot_all.o 
	$(OBJCOPY) -I binary -O elf32-littlearm -B arm $(OBJ_DIR)/boot_all.bin $(OBJ_DIR)/boot_all.o 

$(SRC_O): %.o : %.c
	$(CC) $(CFLAGS) $(INCLUDES) -c $< -o $@
	$(CC) $(CFLAGS) $(INCLUDES) -c $< -MM -MT $@ -MF $(OBJ_DIR)/$(notdir $(patsubst %.o,%.d,$@))
	cp $@ $(OBJ_DIR)/$(notdir $@)
	chmod 777 $(OBJ_DIR)/$(notdir $@)

$(DRAM_O): %.o : %.c
	$(CC) $(CFLAGS) $(INCLUDES) -c $< -o $@
	$(OBJCOPY) --prefix-alloc-sections .sdram $@
	$(CC) $(CFLAGS) $(INCLUDES) -c $< -MM -MT $@ -MF $(OBJ_DIR)/$(notdir $(patsubst %.o,%.d,$@))
	cp $@ $(OBJ_DIR)/$(notdir $@)
	chmod 777 $(OBJ_DIR)/$(notdir $@)

-include $(DEPENDENCY_LIST)

# Generate build info
# -------------------------------------------------------------------	
#ifeq (setup,$(firstword $(MAKECMDGOALS)))
#  # use the rest as arguments for "run"
#  RUN_ARGS := $(wordlist 2,$(words $(MAKECMDGOALS)),$(MAKECMDGOALS))
#  # ...and turn them into do-nothing targets
#  $(eval $(RUN_ARGS):;@:)
#endif
.PHONY: setup
setup:
	@echo "----------------"
	@echo Setup $(GDB_SERVER)
	@echo "----------------"
ifeq ($(GDB_SERVER), openocd)
	cp -p $(FLASH_TOOLDIR)/rtl_gdb_debug_openocd.txt $(FLASH_TOOLDIR)/rtl_gdb_debug.txt
	cp -p $(DEBUG_TOOLDIR)/rtl_gdb_debug_openocd.txt $(DEBUG_TOOLDIR)/rtl_gdb_debug.txt
	cp -p $(FLASH_TOOLDIR)/rtl_gdb_ramdebug_openocd.txt $(FLASH_TOOLDIR)/rtl_gdb_ramdebug.txt
	cp -p $(FLASH_TOOLDIR)/rtl_gdb_flash_write_openocd.txt $(FLASH_TOOLDIR)/rtl_gdb_flash_write.txt
	cp -p $(FLASHDOWNLOAD_TOOLDIR)/rtl_gdb_jtag_boot_com_openocd.txt $(FLASHDOWNLOAD_TOOLDIR)/rtl_gdb_jtag_boot_com.txt
else
	cp -p $(FLASH_TOOLDIR)/rtl_gdb_debug_jlink.txt $(FLASH_TOOLDIR)/rtl_gdb_debug.txt
	cp -p $(DEBUG_TOOLDIR)/rtl_gdb_debug_jlink.txt $(DEBUG_TOOLDIR)/rtl_gdb_debug.txt
	cp -p $(FLASH_TOOLDIR)/rtl_gdb_ramdebug_jlink.txt $(FLASH_TOOLDIR)/rtl_gdb_ramdebug.txt
	cp -p $(FLASH_TOOLDIR)/rtl_gdb_flash_write_jlink.txt $(FLASH_TOOLDIR)/rtl_gdb_flash_write.txt
	cp -p $(FLASHDOWNLOAD_TOOLDIR)/rtl_gdb_jtag_boot_com_jlink.txt $(FLASHDOWNLOAD_TOOLDIR)/rtl_gdb_jtag_boot_com.txt
endif

.PHONY: flashburn
flashburn:
	@if [ ! -f $(FLASHDOWNLOAD_TOOLDIR)/rtl_gdb_flash_write.txt ] ; then echo Please do \"make setup GDB_SERVER=[jlink or openocd]\" first; echo && false ; fi
ifeq ($(findstring CYGWIN, $(OS)), CYGWIN) 
	$(FLASHDOWNLOAD_TOOLDIR)/Check_Jtag.sh
endif
	cp	$(FLASHDOWNLOAD_TOOLDIR)/target_FPGA.axf $(FLASH_TOOLDIR)/target_NORMAL.axf
#	cp	$(FLASH_TOOLDIR)/target_NORMALB.axf $(FLASH_TOOLDIR)/target_NORMAL.axf
	chmod 777 $(FLASHDOWNLOAD_TOOLDIR)/target_NORMAL.axf
	chmod +rx $(FLASHDOWNLOAD_TOOLDIR)/SetupGDB_NORMAL.sh
	$(FLASHDOWNLOAD_TOOLDIR)/SetupGDB_NORMAL.sh
	$(GDB) -x $(FLASHDOWNLOAD_TOOLDIR)/rtl_gdb_flash_write.txt
	
.PHONY: debug
debug:
	@if [ ! -f $(DEBUG_TOOLDIR)/rtl_gdb_debug.txt ] ; then echo Please do \"make setup GDB_SERVER=[jlink or openocd]\" first; echo && false ; fi
ifeq ($(findstring CYGWIN, $(OS)), CYGWIN) 
	$(DEBUG_TOOLDIR)/Check_Jtag.sh
	cmd /c start $(GDB) -x $(DEBUG_TOOLDIR)/rtl_gdb_debug.txt
else
	$(GDB) -x $(DEBUG_TOOLDIR)/rtl_gdb_debug.txt
endif

.PHONY: ramdebug
ramdebug:
	@if [ ! -f $(FLASH_TOOLDIR)/rtl_gdb_ramdebug.txt ] ; then echo Please do \"make setup GDB_SERVER=[jlink or openocd]\" first; echo && false ; fi
ifeq ($(findstring CYGWIN, $(OS)), CYGWIN) 
	$(FLASH_TOOLDIR)/Check_Jtag.sh
	cmd /c start $(GDB) -x $(FLASH_TOOLDIR)/rtl_gdb_ramdebug.txt	
else
	$(GDB) -x $(FLASH_TOOLDIR)/rtl_gdb_ramdebug.txt	
endif

.PHONY: clean
clean:
	rm -rf $(TARGET)
	rm -f $(SRC_O) $(DRAM_O)
	rm -f $(patsubst %.o,%.d,$(SRC_O)) $(patsubst %.o,%.d,$(DRAM_O))

