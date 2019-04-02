/*
 *  Routines to access hardware
 *
 *  Copyright (c) 2015 Realtek Semiconductor Corp.
 *
 *  This module is a confidential and proprietary property of RealTek and
 *  possession or use of this module requires written permission of RealTek.
 */
#include "rtl8195a.h"
#include "build_info.h"
#ifdef PLATFORM_FREERTOS
#include "FreeRTOS.h"
#include "task.h"
#include "semphr.h"
#endif

#include "device.h"
#include "rtl8195a_gspi.h"
#include "spi_api.h"
#include "spi_ex_api.h"
#include "gpio_api.h"
#include "gpio_irq_api.h"
#include "osdep_service.h"
#include "flash_api.h"


/* debug message */
#define FW_DL_DEBUG	0

#if	FW_DL_DEBUG
#define FW_INFO(fmt, args...)		          DBG_8195A("\n\r%s: " fmt, __FUNCTION__, ## args)
#define FW_ERR(fmt, args...)		          DBG_8195A("\n\r%s: " fmt, __FUNCTION__, ## args)
#else
#define FW_INFO(fmt, args...)
#define FW_ERR(fmt, args...)		          DBG_8195A("\n\r%s: " fmt, __FUNCTION__, ## args)
#endif


#define CONFIG_LOOPBACK_TEST 	1

/* define which fw to be download */
#define CONFIG_DL_RAM_ALL_BIN	1 // download ram_all.bin
#define CONFIG_DL_OTA_BIN	1 // download ota.bin

#if CONFIG_DL_RAM_ALL_BIN
	#define RAM_ALL_ADDR		0x00091000	// ram_all.bin address on flash
	#define IMG2_INFO_ADDR		0x1006FFFC	// FIX: should not be changed
#endif
#if CONFIG_DL_OTA_BIN
	#define OTA_ADDR			0x000B1000 // ota.bin address on flash
	#define OTA_INFO_ADDR		0x1006FFC0	// FIX: should not be changed
	#define OTA_CIPHER_TYPE		0	// ota.bin cipher type,  0 for none ciphered
#endif

#define MAX_FW_BLOCK_SZ (30*1024) //define max firmware size loaded per-time

#define STATISTIC_DL_TIME	1 	// config to statistic fw donwload time

u8 aes_128_host_key[16] =
{
	0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 
	0x08, 0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x0E, 0x0F
} ;

u8 aes_128_host_iv[16] =
{
	0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 
	0x08, 0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x0E, 0x0F
};


//
// This structure must be cared byte-ordering
//
typedef struct _RT_8195A_IMG1_HDR
{
    u8      CalData[16];    // Flash calibration data
	u32		Img1Size;
	u32		StartAddr;
    u16     Img2Offset;     // Offset = Img2Offset*1024
    u16     dummy1;
    u32     dummy2;
    u32     StartFunc;
    u32     WakeupFunc;
}RT_8195A_IMG1_HDR, *PRT_8195A_IMG1_HDR;

// This structure must be cared byte-ordering
//
typedef struct _RT_8195A_IMG2_HDR
{
	u32		Img2Size;
	u32		StartAddr;
	u8		Dummy[8];
}RT_8195A_IMG2_HDR, *PRT_8195A_IMG2_HDR;

// This structure must be cared byte-ordering
//
typedef struct _OTA_INFO
{
	u32		crypto_type;	// encyption type
	u8		info[32];	// encyption infomation (eg. aes_key)
	u32		size;
	u32		startaddr;
}OTA_INFO, *POTA_INFO;


//
// This structure must be cared byte-ordering
//
typedef struct _RT_8195A_FIRMWARE_HDR
{
	u32		FwSize;
	u32		StartAddr;
    u8      Dummy[8];
    u32     StartFunc;
    u8      Signature[8];
    u16     Version;        // FW Version
    u16     Subversion; // FW Subversion, default 0x00
    u16     ChipId;
    u8      ChipVer;
    u8      BusType;    
    u8      Rsvd1;
    u8      Rsvd2;
    u8      Rsvd3;
    u8      Rsvd4;
}RT_8195A_FIRMWARE_HDR, *PRT_8195A_FIRMWARE_HDR;


#define CONFIG_USE_INTERRUPT	1
#define PACK_SIZE	2048
#define MAX_DLFW_PAGE_SIZE		2048

/*host endian configuration
	little-endian (1)
	big-endan (0)				   
*/
#define CONFIG_HOST_ENDIAN	1

// SPI0
#define SPI0_MOSI  	PC_2
#define SPI0_MISO  	PC_3
#define SPI0_SCLK  	PC_1
#define SPI0_CS    	PC_0 // This pin is redundant
#if CONFIG_USE_INTERRUPT			
#define GPIO_INT	PB_4 // gspi external interrupt
#endif
#define GPIO_CS		PB_2

#define SPI0_FREQUENCY  20000000

static spi_t spi0_master;
static gpio_irq_t gpio_int;
static gpio_t gpio_cs;
static flash_t 	flash;

typedef enum {
	READ_REG = 0,
	WRITE_REG
}_reg_ops;


// GSPI configuration (big endian recommended)
#define GSPI_CONFIG SPI_BIG_ENDIAN_32

// SPI master configuration
#define SPI_BITS		8 // Ameba SPI support 8bits and 16bits mode

struct spi_more_data {
	unsigned long more_data;
	unsigned long len;
};


#define SLAVE_SELECT()		gpio_write(&gpio_cs, 0)
#define SLAVE_DESELECT()	gpio_write(&gpio_cs, 1)

#define SPI_DUMMY 0xFF

// spi interrupt semaphore
_sema pspiIrqSemaphore;
// spi bus busy
_mutex SPIbusbusy;

volatile bool txDone = FALSE;
volatile bool rxDone = FALSE;
volatile bool txbusIdle = FALSE;

#if CONFIG_LOOPBACK_TEST
#define AGG_SIZE	5000
#define MAX_DUMMY_LEN 3
#define BUFFER_LEN	4+24+PACK_SIZE+8+MAX_DUMMY_LEN // GSPI_CMD + TX_DEC + DATA + GSPI_STATUS

unsigned char TX_DATA[PACK_SIZE];
unsigned char RX_DATA[AGG_SIZE+100]; // extra 100 byte for SDIO header

unsigned char TX_BUFFER[BUFFER_LEN];
unsigned char RX_BUFFER[BUFFER_LEN];
#endif

#define TASK_STACK_SIZE 		2048
#define TASK_PRIORITY			(tskIDLE_PRIORITY + 1)

int spi_transfer(uint8_t* buf, uint32_t buf_len)
{
    int i = 0;
    int ret = 0;

	rtw_mutex_get(&SPIbusbusy);
	SLAVE_SELECT();

	txbusIdle = FALSE; // ensure TX done 
	rxDone = FALSE; // ensure RX done

	if(spi_master_write_read_stream(&spi0_master, buf, buf, buf_len)!=0x00){
		ret = -1;
    }else{
		ret = 0;
		while((!txbusIdle) || (!rxDone)){
		      wait_us(20);
		      if (++i > 2000) {
		              DBG_8195A("SPI write and read Timeout...\r\n");
		              ret = -1;
		              break;
		      }
		}
    }

	/* Chip Select Pull High */
	SLAVE_DESELECT();
	rtw_mutex_put(&SPIbusbusy);
    return ret;
}


static int addr_convert(u32 addr)
{
	u32 domain_id = 0 ;
	u32 temp_addr = addr&0xffff0000;

	switch (temp_addr) {
		case SPI_LOCAL_OFFSET:
			domain_id = SPI_LOCAL_DOMAIN;
			break;
		case SPI_TX_FIFO_OFFSET:
			domain_id = SPI_TXFIFO_DOMAIN;
			break;
		case SPI_RX_FIFO_OFFSET:
			domain_id = SPI_RXFIFO_DOMAIN;
			break;
		default:
			break;
	}

	return domain_id;
}

static inline u32 DWORD_endian_reverse(u32 src, _gspi_conf_t gspi_conf)
{
	u32 temp = 0;
	switch(gspi_conf){
#if CONFIG_HOST_ENDIAN	/*host little-endian*/
		case SPI_LITTLE_ENDIAN_16:
			temp = (((src&0x000000ff)<<8)|((src&0x0000ff00)>>8)|
		((src&0x00ff0000)<<8)|((src&0xff000000)>>8));
			break;
		case SPI_LITTLE_ENDIAN_32:
			temp = (((src&0x000000ff)<<24)|((src&0x0000ff00)<<8)|
		((src&0x00ff0000)>>8)|((src&0xff000000)>>24));
			break;
		case SPI_BIG_ENDIAN_16:
		case SPI_BIG_ENDIAN_32:
			temp = src;
			break;
#else				/*host big-endian*/
		case SPI_LITTLE_ENDIAN_16:
			temp = (((src&0x0000ffff)<<16)|((src&0xffff0000)>>16);
			break;
		case SPI_LITTLE_ENDIAN_32:
			temp = src;
			break;
		case SPI_BIG_ENDIAN_16:
		case SPI_BIG_ENDIAN_32:
			temp = (((src&0x000000ff)<<24)|((src&0x0000ff00)<<8)|
		((src&0x00ff0000)>>8)|((src&0xff000000)>>24));
			break;
#endif
	}
	return temp;
}

/*
*  src buffer bit reorder
*/
static void buf_endian_reverse(u8* src, u32 len, u8* dummy_bytes, _gspi_conf_t gspi_conf)
{
	u32 *buf = (u32*)src;
	
	u16 count = len/4;
	u16 remain = len%4;
	int i = 0;

	if(remain)
		count ++;
	
	for(i = 0;i < count; i++){
		buf[i] = DWORD_endian_reverse(buf[i], gspi_conf);
	}

	if(remain)
			*dummy_bytes = 4 - remain;
}


int gspi_read_write_reg(_reg_ops  ops_type, u32 addr, char * buf, int len,_gspi_conf_t gspi_conf)
{
	int  fun = 1, domain_id = 0x0; //LOCAL
	unsigned int cmd = 0 ;
	int byte_en = 0 ;//,i = 0 ;
	int ret = 0;
	unsigned char status[GSPI_STATUS_LEN] = {0};
	unsigned int data_tmp = 0;

	u32 spi_buf[4] = {0};

	if (len!=1 && len!=2 && len != 4) {
		return -1;
	}

	domain_id = addr_convert(addr);

	addr &= 0x7fff;
	len &= 0xff;
	if (ops_type == WRITE_REG) //write register
	{
		int remainder = addr % 4;
		u32 val32 = *(u32 *)buf;
		switch(len) {
			case 1:
				byte_en = (0x1 << remainder);
				data_tmp = (val32& 0xff)<< (remainder*8);
				break;
			case 2:
				byte_en = (0x3 << remainder);
				data_tmp = (val32 & 0xffff)<< (remainder*8);
				break;
			case 4:
				byte_en = 0xf;
				data_tmp = val32 & 0xffffffff;
				break;
			default:
				byte_en = 0xf;
				data_tmp = val32 & 0xffffffff;
				break;
		}
	}
	else //read register
	{
		switch(len) {
			case 1:
				byte_en = 0x1;
				break;
			case 2:
				byte_en = 0x3;
				break;
			case 4:
				byte_en = 0xf;
				break;
			default:
				byte_en = 0xf;
				break;
		}

		if(domain_id == SPI_LOCAL_DOMAIN)
			byte_en = 0;
	}


	cmd = FILL_SPI_CMD(byte_en, addr, domain_id, fun, ops_type);
	//4 command segment bytes reorder
	cmd = DWORD_endian_reverse(cmd, gspi_conf);

	if ((ops_type == READ_REG)&& (domain_id!= SPI_RXFIFO_DOMAIN)) {
		u32 read_data = 0;

		_memset(spi_buf, 0x00, sizeof(spi_buf));

		//SPI_OUT:32bit cmd
		//SPI_IN:64bits status+ XXbits data
		spi_buf[0] = cmd;
		spi_buf[1] = 0;
		spi_buf[2] = 0;
		spi_buf[3] = 0;

		spi_transfer((u8*)spi_buf, sizeof(spi_buf));

		memcpy(status, (u8 *) &spi_buf[1], GSPI_STATUS_LEN);
		read_data = spi_buf[3];
		
		*(u32*)buf = DWORD_endian_reverse(read_data, gspi_conf);
	}
	else if (ops_type == WRITE_REG ) {
		//4 data segment bytes reorder
		data_tmp = DWORD_endian_reverse(data_tmp, gspi_conf);
		//SPI_OUT:32bits cmd+ XXbits data
		//SPI_IN:64bits status
		spi_buf[0] = cmd;
		spi_buf[1] = data_tmp;
		spi_buf[2] = 0;
		spi_buf[3] = 0;
		
		spi_transfer((u8*)spi_buf, sizeof(spi_buf));

		memcpy(status, (u8 *) &spi_buf[2], GSPI_STATUS_LEN);
	}

	// translate status
	return ret;
}
u8 gspi_read8(u32 addr, s32 *err)
{
	u32 ret = 0;
	int val32 = 0 , remainder = 0 ;
	s32 _err = 0;

	_err = gspi_read_write_reg(READ_REG, addr&0xFFFFFFFC, (char *)&ret, 4, GSPI_CONFIG);
	remainder = addr % 4;
	val32 = ret;
	val32 = (val32& (0xff<< (remainder<<3)))>>(remainder<<3);

	if (err)
		*err = _err;

	return (u8)val32;

}


u16 gspi_read16(u32 addr, s32 *err)
{
   	u32 ret = 0;
	int val32 = 0 , remainder = 0 ;
	s32 _err = 0;

	_err = gspi_read_write_reg(READ_REG, addr&0xFFFFFFFC,(char *)&ret, 4, GSPI_CONFIG);
	remainder = addr % 4;
	val32 = ret;
	val32 = (val32& (0xffff<< (remainder<<3)))>>(remainder<<3);

	if (err)
		*err = _err;

	return (u16)val32;
}


u32 gspi_read32(u32 addr, s32 *err)
{
	unsigned int ret = 0;
	s32 _err = 0;

	_err = gspi_read_write_reg(READ_REG, addr&0xFFFFFFFC,(char *)&ret,4 ,GSPI_CONFIG);
	if (err)
		*err = _err;

	return  ret;
}


s32 gspi_write8(u32 addr, u8 buf, s32 *err)
{
	int ret = 0;

	ret = gspi_read_write_reg(WRITE_REG, addr, (char *)&buf,1, GSPI_CONFIG);
	if (err)
		*err = ret;
	return ret;
}

s32 gspi_write16(u32 addr, u16 buf, s32 *err)
{
	int ret = 0;

	ret = gspi_read_write_reg(WRITE_REG,addr,(char *)&buf,2, GSPI_CONFIG);
	if (err)
		*err = ret;
	return ret;
}

s32 gspi_write32(u32 addr, u32 buf, s32 *err)
{
	int	ret = 0;

	ret = gspi_read_write_reg(WRITE_REG, addr,(char *)&buf,4, GSPI_CONFIG);
	if (err)
		*err = ret;
	return ret;
}



int gspi_read_rx_fifo(u8 *buf, u32 len, struct spi_more_data * pmore_data,_gspi_conf_t gspi_conf)
{
	int fun = 1;
	u32 cmd = 0;
	u8* spi_buf = (u8 *) (buf);
	u8* spi_data = spi_buf + GSPI_CMD_LEN;
	u8* spi_status = spi_data + len;
	int spi_buf_len = GSPI_CMD_LEN + N_BYTE_ALIGMENT(len, 4) + GSPI_STATUS_LEN;
	u8 dummy_bytes = 0;
	
	cmd = FILL_SPI_CMD(len, ((len&0xff00) >>8), SPI_RXFIFO_DOMAIN, fun, (unsigned int)0);

	//4 command segment bytes reorder
	cmd = DWORD_endian_reverse(cmd, gspi_conf);
	memcpy(spi_buf, (u8 *)&cmd, GSPI_CMD_LEN);
	//4 clean data segment 
	memset(spi_data,0x00, len);
	//4  clean status segment 
	memset(spi_status, 0x00, GSPI_STATUS_LEN);
	
	spi_transfer((u8 *) spi_buf, spi_buf_len);
	
	// data segement reorder
	buf_endian_reverse(spi_data, len, &dummy_bytes, gspi_conf);	
	// status segment reorder
	spi_status += dummy_bytes;
	buf_endian_reverse(spi_status, GSPI_STATUS_LEN, &dummy_bytes, gspi_conf);

	pmore_data->more_data = GET_STATUS_HISR(spi_status) & SPI_HIMR_RX_REQUEST_MSK;
	pmore_data->len = GET_STATUS_RXQ_REQ_LEN(spi_status);
	return 0;
}

static int gspi_write_tx_fifo(u8 *buf, u32 len, _gspi_conf_t gspi_conf)
{
	int fun = 1; //TX_HIQ_FIFO
	unsigned int cmd = 0;
	u8 *spi_buf = (u8 *) (buf);
	u8* spi_data = spi_buf + GSPI_CMD_LEN;
	u8* spi_status;// = buf + len
	u32 spi_buf_len = 0;
	
	u32 NumOfFreeSpace;
	u8 wait_num = 0;
	u8 dummy_bytes = 0;
	
	NumOfFreeSpace = gspi_read32(LOCAL_REG_FREE_TX_SPACE, NULL);

	while (NumOfFreeSpace * (PACK_SIZE+SIZE_TX_DESC) < len) {
		if((++wait_num) >= 4){
			DBG_8195A("%s(): wait_num is >= 4\n", __FUNCTION__);
			return -1;
		}
		RtlUdelayOS(100); //delay 100us
		NumOfFreeSpace = gspi_read32(LOCAL_REG_FREE_TX_SPACE, NULL);
	}
	cmd = FILL_SPI_CMD(len, ((len&0xff00) >>8), SPI_TXFIFO_DOMAIN, fun, (unsigned int)1);
	//4 command segment bytes reorder
	cmd = DWORD_endian_reverse(cmd, gspi_conf);
	memcpy(spi_buf, (u8 *)&cmd, GSPI_CMD_LEN);
	
	//4 data segment bytes reorder
	buf_endian_reverse(spi_data, len, &dummy_bytes, gspi_conf);

	//4 status segment 
	spi_status = spi_data + len + dummy_bytes;
	memset(spi_status, 0x00, GSPI_STATUS_LEN);

	spi_buf_len = GSPI_CMD_LEN + len + dummy_bytes + GSPI_STATUS_LEN;
	
	spi_transfer((u8 *) spi_buf, spi_buf_len);
	
	// parse status infomation
	//	GET_STATUS_HISR(status)
	//	GET_STATUS_FREE_TX(status)
	//	GET_STATUS_RXQ_REQ_LEN(status)
	//	GET_STATUS_TX_SEQ(status)

	return 0;
}

static int gspi_write_page(u8 *buf, u32 len, u8 agg_cnt){
	int res;
	u32 tot_len = SIZE_TX_DESC + len;
	PGSPI_TX_DESC ptxdesc;
	
	// clean GSPI command and tx descriptor area
	memset(TX_BUFFER, 0, GSPI_CMD_LEN+SIZE_TX_DESC);

	ptxdesc = (PGSPI_TX_DESC)(TX_BUFFER + GSPI_CMD_LEN); // reserve 4 byte for GSPI cmd
	ptxdesc->txpktsize = len;
	ptxdesc->offset = SIZE_TX_DESC;
	ptxdesc->bus_agg_num = agg_cnt;
	ptxdesc->type = GSPI_CMD_TX;
	
	memcpy(TX_BUFFER+GSPI_CMD_LEN+SIZE_TX_DESC, buf, len);

	res = gspi_write_tx_fifo(TX_BUFFER, tot_len, GSPI_CONFIG);

	return res; 
}

int gspi_configuration(_gspi_conf_t gspi_conf){

	u8 conf = gspi_conf;
	u8 retry_t = 0;
	
retry:
	/*GSPI default mode: SPI_LITTLE_ENDIAN_32*/
	gspi_read_write_reg(WRITE_REG, SPI_LOCAL_OFFSET|SPI_REG_SPI_CFG,(char *)&conf,1 ,SPI_LITTLE_ENDIAN_32);

	// read gspi config
	conf = 0xff;
	conf = gspi_read8(SPI_LOCAL_OFFSET|SPI_REG_SPI_CFG, NULL);

	if(conf != gspi_conf){
		if(++ retry_t <= 3)
			goto retry;
		DBG_8195A("%s: config fail@ 0x%x\n", __FUNCTION__, conf);
		return 1;
	}

	char *s;
	switch (conf) {
		case SPI_LITTLE_ENDIAN_16:
			s = "LITTLE_ENDIAN|WORD_LEN_16"; break;
		case SPI_LITTLE_ENDIAN_32:
			s = "LITTLE_ENDIAN|WORD_LEN_32"; break;
		case SPI_BIG_ENDIAN_16:
			s = "BIG_ENDIAN|WORD_LEN_16"; break;
		case SPI_BIG_ENDIAN_32:
			s = "BIG_ENDIAN|WORD_LEN_32"; break;
		default:
			s = "UNKNOW CONFIGURATION"; break;
	};
	DBG_8195A("%s: Current configuration:%s\n", __FUNCTION__, s);
	return 0;
}

#if CONFIG_USE_INTERRUPT
void spi_interrupt_thread(){
	u32 spi_hisr;
	u32 spi_himr;
	u32 rx_cnt = 0;
	while(1){
		if (rtw_down_sema(&pspiIrqSemaphore) == _FAIL){
			DBG_8195A("%s, Take Semaphore Fail\n", __FUNCTION__);
			goto exit;
		}

		spi_himr = gspi_read32(SPI_LOCAL_OFFSET | SPI_REG_HIMR, NULL);
		spi_hisr = gspi_read32(SPI_LOCAL_OFFSET | SPI_REG_HISR, NULL);

		if (spi_hisr & spi_himr){
			if(spi_hisr & SPI_HISR_RX_REQUEST) {
				u8* rx_buf = NULL;
				u8* payload = NULL;
				u32 rx_len = 0;
				u8 rx_len_rdy = 0;
				PGSPI_RX_DESC prxdesc;
				struct spi_more_data more_data = {0};

				// clean RX buffer
				memset(RX_DATA, 0, AGG_SIZE + 100);
				rx_buf = RX_DATA;
				
				do {
					//validate RX_LEN_RDY before reading RX0_REQ_LEN
					if(rx_len==0){
						rx_len_rdy = gspi_read8(SPI_LOCAL_OFFSET|(SPI_REG_RX0_REQ_LEN + 3), NULL);
						if(rx_len_rdy & BIT7){
							rx_len = (gspi_read32(SPI_LOCAL_OFFSET | SPI_REG_RX0_REQ_LEN, NULL)) &0xffffff;
						}
					}
					
					if (rx_len >(PACK_SIZE+SIZE_RX_DESC))
						rx_len = PACK_SIZE+SIZE_RX_DESC;
					
					if(rx_len){
						
						memset(RX_BUFFER, 0, BUFFER_LEN);
						
						gspi_read_rx_fifo(RX_BUFFER, rx_len, &more_data,GSPI_CONFIG);
						
						memcpy(rx_buf, RX_BUFFER+GSPI_CMD_LEN, rx_len);

						prxdesc = (PGSPI_RX_DESC)rx_buf;
						
						DBG_8195A("Receive Data lenth = %d (cnt = %d)\n",prxdesc->pkt_len, ++rx_cnt);

						payload = rx_buf + prxdesc->offset;
						rx_buf += rx_len;
						rx_len = 0;
					}else{
						break;
					}
				}while(1);
			}				
		}
			// query other interrupt here
	}
exit:
	vTaskDelete(NULL);
}
#endif


// external GSPI interrupt handler
void gspi_irq_handler (uint32_t id, gpio_irq_event event)
{
//DBG_8195A("gspi_irq_handler....\n");
	if(!pspiIrqSemaphore)
		return;
	rtw_up_sema_from_isr(&pspiIrqSemaphore);
}

//  SPI master interrupt callback if use interrupt mode
void spi_tx_rx_intr_callback(void *pdata, SpiIrq event){

	switch(event){
		case SpiRxIrq:
			rxDone = TRUE;
			break;
		case SpiTxIrq:
			txDone = TRUE;
			break;
		default:
			DBG_8195A("unknown interrput evnent!\n");
	} 
}

void spi_tx_bus_idle_callback(void *pdata, SpiIrq event){
	txbusIdle = TRUE;
}

void spi_init_intr(){
#if CONFIG_USE_INTERRUPT
	// init gspi external interrupt
	gpio_irq_init(&gpio_int, GPIO_INT, gspi_irq_handler, NULL);
	gpio_irq_set(&gpio_int, INT_FALLING, 1);	// Falling Edge Trigger
	gpio_irq_enable(&gpio_int);
#endif
	// init spi master tx/rx done interrupt
	spi_irq_hook(&spi0_master, (spi_irq_handler)spi_tx_rx_intr_callback, NULL);

	// init spi master tx bus idle interrupt
	spi_bus_tx_done_irq_hook(&spi0_master, (spi_irq_handler)spi_tx_bus_idle_callback, NULL);
}
void spi_init_master(){
	// init spi master 
	spi_init(&spi0_master, SPI0_MOSI, SPI0_MISO, SPI0_SCLK, SPI0_CS);
	spi_format(&spi0_master, SPI_BITS, 0, 0);
	spi_frequency(&spi0_master, SPI0_FREQUENCY);
	printf("spi master frequency %d Hz\n", SPI0_FREQUENCY);
	
	gpio_init(&gpio_cs, GPIO_CS);
	gpio_mode(&gpio_cs, PullDown);
	gpio_dir(&gpio_cs, PIN_OUTPUT);

	SLAVE_DESELECT(); // deselect slave
}

static s32 _FWMemSet(u32 Addr, u16 Size, u8 Data)
{
	s32 ret = _FAIL;
	GSPI_DESC_MS *tx_des;
	u32 buf_sz;
	u8* tx_buff;
	u16 old_hcpwm2;
	u16 new_hcpwm2;
    u32 i;

	buf_sz = GSPI_CMD_LEN+sizeof(GSPI_DESC_MS)+GSPI_STATUS_LEN; 

	tx_buff = rtw_zmalloc(buf_sz);
	if(tx_buff == NULL)
		goto exit;

	tx_des = (PGSPI_DESC_MS)(tx_buff + GSPI_CMD_LEN); // Resever 4 byte for GSPI Command

	tx_des->txpktsize = 0;
	tx_des->offset = sizeof(GSPI_DESC_MS);
	tx_des->bus_agg_num = 1;
	tx_des->type = GSPI_TX_MEM_SET;
	tx_des->start_addr = rtk_cpu_to_le32(Addr);
	tx_des->write_len = rtk_cpu_to_le16(Size);
	tx_des->data = Data;
	
	old_hcpwm2 = gspi_read16( SPI_LOCAL_OFFSET|SPI_REG_HCPWM2, NULL); 

	FW_INFO("%s: Addr=0x%x Size=%d Data=0x%x\n", __FUNCTION__,Addr, Size, Data);
	
	ret = gspi_write_tx_fifo(tx_buff, sizeof(GSPI_DESC_MS), GSPI_CONFIG);

	if(ret){
		FW_ERR("gspi write tx fifo fail!!\n");
		ret = _FAIL;
		goto exit;
	}
	rtw_msleep_os(50); // wait memory write done
	for (i=0;i<100;i++) {
		new_hcpwm2 = gspi_read16(SPI_LOCAL_OFFSET|SPI_REG_HCPWM2, NULL); 
		if ((new_hcpwm2 & BIT15) != (old_hcpwm2 & BIT15)) {
			// toggle bit(15)  is changed, it means the 8195a update its register value
			old_hcpwm2 = new_hcpwm2;
			if (new_hcpwm2 & GSPI_MEM_ST_DONE) {
				// 8195a memory write done
				ret = _SUCCESS;
				break;
			}
			rtw_msleep_os(10);
		}
		else {
			rtw_msleep_os(10);
		}        
	}
exit:
	if(tx_buff)
		rtw_mfree(tx_buff, buf_sz);
	return ret;
}

static s32 _FWFreeToGo(u32	FirmwareEntryFun, u32 min_cnt)
{
	s32 ret = _FAIL;
	u32 i;
	u8 fw_ready = 0;

	u8* tx_buff = NULL;
	u32 buf_sz = 0;
	PGSPI_DESC_JS	tx_des;

	buf_sz = GSPI_CMD_LEN+sizeof(GSPI_DESC_JS)+GSPI_STATUS_LEN; 

	tx_buff = rtw_zmalloc(buf_sz);
	if(tx_buff == NULL)
		goto exit;

	tx_des = (PGSPI_DESC_JS)(tx_buff + GSPI_CMD_LEN); // Resever 4 byte for GSPI Command
	tx_des->txpktsize = 0;
	tx_des->offset = sizeof(GSPI_DESC_JS);
	tx_des->bus_agg_num = 1;
	tx_des->type = GSPI_TX_FM_FREETOGO;
	tx_des->start_fun = rtk_cpu_to_le32(FirmwareEntryFun);

	FW_INFO("%s: Jump to Entry Func @ 0x%x\n", __FUNCTION__,FirmwareEntryFun);

	ret = gspi_write_tx_fifo(tx_buff, sizeof(GSPI_DESC_JS), GSPI_CONFIG);

	if(ret){
		DBG_8195A("gspi write tx fifo fail!!\n");
		ret = _FAIL;
		goto exit;
	}
	
	// Pooling firmware ready here
	for (i=0;i< min_cnt;i++) {
		fw_ready = gspi_read8(SPI_LOCAL_OFFSET|SPI_REG_CPU_IND, NULL); 
		FW_INFO("%s: cpu_ind @ 0x%02x\n", __FUNCTION__, fw_ready);
		if (fw_ready != 0xff){ // when GSPI/SDIO shut down, spi read back 0xff
			if (fw_ready&GPSI_SYSTEM_TRX_RDY_IND) {
				FW_INFO("Firmware is already running!\n");
				break;
			}
		}
		rtw_msleep_os(2);
	}
	if (i==min_cnt) {
		FW_ERR("Wait Firmware Start Timeout!!\n");
		ret = _FAIL;
	}
	else {
		ret = _SUCCESS;
	}
exit:
	if(tx_buff)
		rtw_mfree(tx_buff, buf_sz);
	return ret;
}


static int
_FwMemWrite(
	IN		u32			offset,
	IN		PVOID		pdata,
	IN		u32			size
	)
{
	u8 ret = _FAIL;
	u8 * tx_buff = NULL;
	GSPI_DESC_MW	*ptx_des;
	u32 buf_sz;
	
	u32 i;
	u16 old_hcpwm2;
	u16 new_hcpwm2;
	
	old_hcpwm2 = gspi_read16( SPI_LOCAL_OFFSET|SPI_REG_HCPWM2, NULL); 

	buf_sz = (((GSPI_CMD_LEN + GSPI_STATUS_LEN + size + sizeof(GSPI_DESC_MW) - 1) >> 9)+1) << 9;
	tx_buff = rtw_zmalloc(buf_sz);
	if(tx_buff == NULL)
		goto exit;

	ptx_des = (GSPI_DESC_MW *)(tx_buff + GSPI_CMD_LEN); // Resever 4 byte for GSPI Command
	ptx_des->txpktsize = rtk_cpu_to_le16(size);
	ptx_des->offset = sizeof(GSPI_DESC_MW);
	ptx_des->bus_agg_num = 1;
	ptx_des->type = GSPI_TX_MEM_WRITE;
	ptx_des->reply = 0;
	ptx_des->start_addr = rtk_cpu_to_le32(offset);
	ptx_des->write_len = rtk_cpu_to_le16(size);

	rtw_memcpy(tx_buff + GSPI_CMD_LEN + sizeof(GSPI_DESC_MW), pdata, size);

	ret = gspi_write_tx_fifo(tx_buff, (size + sizeof(GSPI_DESC_MW)),GSPI_CONFIG);
	if(ret){
		FW_ERR("gspi write tx fifo fail!!\n");
		ret = _FAIL;
		goto exit;
	}
	//rtw_msleep_os(50); // wait memory write done
	for (i=0;i<1000;i++) {
		new_hcpwm2 = gspi_read16(SPI_LOCAL_OFFSET|SPI_REG_HCPWM2, NULL); 
		if ((new_hcpwm2 & BIT15) != (old_hcpwm2 & BIT15)) {
			// toggle bit(15)  is changed, it means the 8195a update its register value
			old_hcpwm2 = new_hcpwm2;
			if (new_hcpwm2 & GSPI_MEM_WR_DONE) {
				// 8195a memory write done
				ret = _SUCCESS;
				break;
			}
			rtw_msleep_os(1);
		}
		else {
			rtw_msleep_os(1);
		}        
	}

exit:	
	if(tx_buff)
		rtw_mfree(tx_buff, buf_sz);
	return ret;
}


static int
_WriteFW(u32 FirmwareStartAddr, PVOID buffer, u32 size)
{
	int 	ret = _SUCCESS;
	u32 	pageNums,remainSize ;
	u32 	page, offset;
	u8*		bufferPtr = (u8*)buffer;

	pageNums = size / MAX_DLFW_PAGE_SIZE ;
	remainSize = size % MAX_DLFW_PAGE_SIZE;

	for (page = 0; page < pageNums; page++) {
		offset = page * MAX_DLFW_PAGE_SIZE;
		
		FW_INFO("Write Mem: StartAddr=0x%x Len=%d\n"
		    ,(FirmwareStartAddr+offset), MAX_DLFW_PAGE_SIZE);

		ret = _FwMemWrite((FirmwareStartAddr+offset), bufferPtr+offset, MAX_DLFW_PAGE_SIZE);
		if(ret == _FAIL) {
			FW_ERR("Error!\n");
			goto exit;
		}
	}
	
	if (remainSize) {
		offset = pageNums * MAX_DLFW_PAGE_SIZE;

	   	FW_INFO("Write Mem (Remain): StartAddr=0x%x Len=%d\n",(FirmwareStartAddr+offset), remainSize);
			
		ret = _FwMemWrite((FirmwareStartAddr+offset), bufferPtr+offset, remainSize);
		
		if(ret == _FAIL)
			goto exit;

	}
	
exit:
	return ret;
}

static int gpsi_firmware_download(
	u32 fw_sramAddr, 
	u8* fw_buffer, 
	u32 fw_size)
{
	int status = 0;
	int retry_cnt =0;
	
	if(!fw_buffer){
		FW_ERR("firmware buffer is NULL.\n");
	}
	
retry:
	status = _WriteFW(fw_sramAddr, fw_buffer, fw_size);
	if (status != _SUCCESS){
		if(++retry_cnt < 3)
			goto retry;
		else{
			FW_ERR("Download firmware fail.\n");
			return _FAIL;
		}
	}
	
	FW_INFO("_WriteFW Done- for Normal chip.\n");
	
	return status;
}

void wait_module_bootup_done(){
	u16 hcpwm2 = 0;

	hcpwm2 = gspi_read16(SPI_LOCAL_OFFSET|SPI_REG_HCPWM2, NULL);
	while(!(hcpwm2&GSPI_INIT_DONE))
	{
		vTaskDelay(1000);
		hcpwm2 = gspi_read16(SPI_LOCAL_OFFSET|SPI_REG_HCPWM2, NULL);
	}
}

void gspi_demo(void)
{
	u32 spi_himr = 0;
	u32 spi_ictlr = 0;
	u32 rx_agg_ctrl = 0;
	s8 res = 0;

	u8	fw_download_ok = 0;
	u32 start_t = 0;
	u32 stop_t = 0;
	
	u32 FirmwareEntryFun = 0;
	int status = 0;
	u8* FwBuffer8195a = NULL;
	u32 FwBufferSize = 0;
	u32 fw_index = 0;
#if CONFIG_DL_RAM_ALL_BIN	
	u32 ram_all_address = RAM_ALL_ADDR; // ram_all.bin address at flash

	RT_8195A_IMG1_HDR	*pImg1Hdr = NULL;
	RT_8195A_IMG2_HDR	*pImg2Hdr = NULL;
	
	u8 	Img1Hdr_buf[sizeof(RT_8195A_IMG1_HDR)]; 
	u8 	Img2Hdr_buf[sizeof(RT_8195A_IMG2_HDR)];

	u32 img2_block_cnt = 0;
	u32 img2_remain = 0;
	u32 img2_ld_addr = 0;

	u32 image2_offset;
#endif
#if CONFIG_DL_OTA_BIN	
	u32 ota_address = OTA_ADDR; // ota.bin address at flash
	RT_8195A_IMG2_HDR	*pOtaHdr = NULL;
	OTA_INFO	ota_info;	// ota information 
	
	u8 	OtaHdr_buf[sizeof(RT_8195A_IMG2_HDR)];
	u32 ota_block_cnt = 0;
	u32 ota_remain = 0;
	u32 ota_offset = 0;
	u32 ota_ld_addr = 0;	// ota block load address on sram
#endif
#if CONFIG_LOOPBACK_TEST
	u32 test_loop = 1000;   
#endif


	DBG_8195A("Init SPI master....\n"); 
	
	//1 SPI host init
	spi_init_master();
	spi_init_intr();

	rtw_init_sema(&pspiIrqSemaphore, 0);
	// used for sync SPI bus, SPI bus shold not be interrupt 
	rtw_mutex_init(&SPIbusbusy);
	
	if( xTaskCreate( (TaskFunction_t)spi_interrupt_thread, "SPI INTERRUPT", (TASK_STACK_SIZE/4), NULL, TASK_PRIORITY+2, NULL) != pdPASS) {
		DBG_8195A("Cannot create SPI INTERRUPT task\n\r");
		goto err;
	}

	//1 GSPI slave configuration
	res = gspi_configuration(GSPI_CONFIG);
	if(res){
		DBG_8195A("gspi configure error....\n");
		while(1);
	}

	/*
		Wait Ameba module bootup done
		This is only valid for Ameba module boot from SDIO 
	*/
	wait_module_bootup_done();

	// INT_CTRL-clean INT control register 
	spi_ictlr = 0;
	gspi_write32(SPI_LOCAL_OFFSET |SPI_REG_INT_CTRL, spi_ictlr, NULL);

	// HISR - clean interrupt status register
	gspi_write32(SPI_LOCAL_OFFSET |SPI_REG_HISR, 0xFFFFFFFF, NULL);
		
	// HIMR - turn all off
	gspi_write32(SPI_LOCAL_OFFSET |SPI_REG_HIMR, SPI_HIMR_DISABLED, NULL);

	// Set intterrupt mask 
	spi_himr = (u32)(SPI_HISR_RX_REQUEST|SPI_HISR_CPWM1_INT);

	// Write and enable interrupt
	gspi_write32(SPI_LOCAL_OFFSET | SPI_REG_HIMR, spi_himr, NULL);

#if 1
	// set RX AGG control register
	rx_agg_ctrl = 0;
	gspi_write32(SPI_LOCAL_OFFSET | SPI_REG_RX_AGG_CTL, rx_agg_ctrl, NULL);
#endif


	//1 Firmware download 

	DBG_8195A("accquire FW from flash ...\n");

	// Turn off FW debug message by write firmware variable ConfigDebugInfo=0
	status = _FWMemSet(0x10000310, 4, 0);
	if(status == _FAIL){
		DBG_8195A("Set Debug info Fail.\n");
		goto err;
	}else{
		DBG_8195A("Set Debug info Done.\n");
	}	

#if STATISTIC_DL_TIME
	start_t = xTaskGetTickCount();
#endif

#if CONFIG_DL_RAM_ALL_BIN	
	//4 load and download image1
	FW_INFO("\n\rDownloading Image1...\n");
	status = flash_stream_read(&flash, ram_all_address, sizeof(RT_8195A_IMG1_HDR), Img1Hdr_buf);
	if(status){
		//DumpForOneBytes(Img1Hdr_buf, sizeof(RT_8195A_IMG1_HDR));
		pImg1Hdr = (RT_8195A_IMG1_HDR*)&Img1Hdr_buf[0];

		pImg1Hdr->Img1Size = rtk_le32_to_cpu(pImg1Hdr->Img1Size);
		pImg1Hdr->StartAddr = rtk_le32_to_cpu(pImg1Hdr->StartAddr);
		pImg1Hdr->Img2Offset = rtk_le16_to_cpu(pImg1Hdr->Img2Offset);
		pImg1Hdr->StartFunc = rtk_le32_to_cpu(pImg1Hdr->StartFunc);

		// jump to image1 when fw download ok
		memcpy(&FirmwareEntryFun, &pImg1Hdr->StartFunc, sizeof(u32));
		//FirmwareEntryFun = pImg1Hdr->StartFunc;

		FW_INFO("image1_len=0x%08x image1_LoadAddr=0x%x image1_StartFunc=%x\n",
			pImg1Hdr->Img1Size, pImg1Hdr->StartAddr,pImg1Hdr->StartFunc);
		
		FW_INFO("image2_offset=%x\n",pImg1Hdr->Img2Offset*1024);
		
		// allocate a buffer for firmware source
		FwBuffer8195a = rtw_zmalloc(pImg1Hdr->Img1Size);
		if(!FwBuffer8195a)
		{
			FW_ERR("Not enough space for image1\n");
			goto err;
		}
		status = flash_stream_read(&flash, ram_all_address + 32, pImg1Hdr->Img1Size, FwBuffer8195a);
		if(status){
			status = gpsi_firmware_download(pImg1Hdr->StartAddr, FwBuffer8195a, pImg1Hdr->Img1Size);
			if(status == _SUCCESS){
				FW_INFO("Image1 download Successfully.\n");
				fw_download_ok = 1;
			}else{
				FW_ERR("Image1 download Fail.\n");
				fw_download_ok = 0; // indicate fw download fail
			}
		}
		if (FwBuffer8195a)
			rtw_mfree((u8*)FwBuffer8195a, pImg1Hdr->Img1Size);
		
		if(!fw_download_ok)
			goto err;
	}

	//4 load and download image2
	FW_INFO("\n\rDownloading Image2...\n");
	image2_offset = pImg1Hdr->Img2Offset*1024;
	status = flash_stream_read(&flash, ram_all_address+image2_offset, sizeof(RT_8195A_IMG2_HDR), Img2Hdr_buf);
	if(status){
		//DumpForOneBytes(Img2Hdr_buf, sizeof(RT_8195A_IMG2_HDR));
		pImg2Hdr = (RT_8195A_IMG2_HDR*)Img2Hdr_buf;

		pImg2Hdr->Img2Size = rtk_le32_to_cpu(pImg2Hdr->Img2Size);
		pImg2Hdr->StartAddr = rtk_le32_to_cpu(pImg2Hdr->StartAddr);
		
		//pImg2Hdr->StartFunc= rtk_le32_to_cpu(pImg2Hdr->StartFunc);
		//pImg2Hdr->Version =  rtk_le16_to_cpu(pImg2Hdr->Version);
		//pImg2Hdr->Subversion = rtk_le16_to_cpu(pImg2Hdr->Subversion);
		//pImg2Hdr->Signature = rtk_le16_to_cpu(pImg2Hdr->Signature);

		// jump to image2 when fw download ok
		//FirmwareEntryFun = pImg2Hdr->StartFunc;

		FW_INFO("image2_len=%x image2_LoadAddr=0x%x\n",pImg2Hdr->Img2Size, pImg2Hdr->StartAddr);
		//DBG_8195A("image2_version=%x image2_subversion=%x image2_signature=%s\n",
			//pImg2Hdr->Version, pImg2Hdr->Subversion, pImg2Hdr->Signature);

		status = _FwMemWrite((u32)IMG2_INFO_ADDR,(u8*)&(pImg2Hdr->StartAddr), 4);
		if(status == _SUCCESS){
			FW_INFO("Image2 information load Done.\n");
			fw_download_ok = 1;
		}else{
			FW_ERR("Image2 information load Fail.\n");
			fw_download_ok = 0; // indicate fw download fail
			goto err;
		}	

		img2_block_cnt = pImg2Hdr->Img2Size/MAX_FW_BLOCK_SZ;
		img2_remain = pImg2Hdr->Img2Size%MAX_FW_BLOCK_SZ;

		// allocate a buffer for firmware source
		FwBufferSize = MAX_FW_BLOCK_SZ;

		FwBuffer8195a = rtw_zmalloc(FwBufferSize);
		if(!FwBuffer8195a)
		{
			FW_ERR("Not enough space for img2 block\n");
			goto err;
		}

		int img2_offset = 0;
		for(fw_index=0;fw_index<img2_block_cnt;fw_index++){
			img2_offset = fw_index*MAX_FW_BLOCK_SZ;

			img2_ld_addr = pImg2Hdr->StartAddr + img2_offset;
			
			status = flash_stream_read(&flash, ram_all_address+image2_offset+16+img2_offset, MAX_FW_BLOCK_SZ, FwBuffer8195a);
			if(status){
				status = gpsi_firmware_download(img2_ld_addr, FwBuffer8195a, MAX_FW_BLOCK_SZ);
				if(status == _SUCCESS){
					FW_INFO("img2 block(index = %d)download Successfully.\n", fw_index);
					fw_download_ok = 1;
				}else{
					FW_ERR("img2 block(index = %d)download Fail.\n", fw_index);
					fw_download_ok = 0; // indicate fw download fail
				}
			}
		}

		if(img2_remain){
			img2_offset = img2_block_cnt*MAX_FW_BLOCK_SZ;
			img2_ld_addr = pImg2Hdr->StartAddr + img2_offset;

			// align ciphertext length
			if(img2_remain%16)
				img2_remain += (16-img2_remain%16);
			
			status = flash_stream_read(&flash, ram_all_address+image2_offset+16+img2_offset, img2_remain, FwBuffer8195a);
		if(status){
				status = gpsi_firmware_download(img2_ld_addr, FwBuffer8195a, img2_remain);
			if(status == _SUCCESS){
					FW_INFO("img2 remain(size = %d)download Successfully.\n", img2_remain);
				fw_download_ok = 1;
			}else{
					FW_ERR("img2 remain(size = %d)download Fail.\n", img2_remain);
				fw_download_ok = 0; // indicate fw download fail
			}

			}
		}
		if (FwBuffer8195a)
			rtw_mfree((u8*)FwBuffer8195a, FwBufferSize);

		if(!fw_download_ok)
			goto err;
	}
#endif

	//4 load and download ota.bin
#if CONFIG_DL_OTA_BIN
	FW_INFO("\n\rDownloading OTA.bin ...\n");
	status = flash_stream_read(&flash, ota_address, sizeof(RT_8195A_IMG2_HDR), OtaHdr_buf);
	if(status){
		//DumpForOneBytes(OtaHdr_buf, sizeof(RT_8195A_IMG2_HDR));
		pOtaHdr = (RT_8195A_IMG2_HDR*)OtaHdr_buf;

		pOtaHdr->Img2Size = rtk_le32_to_cpu(pOtaHdr->Img2Size);
		pOtaHdr->StartAddr = rtk_le32_to_cpu(pOtaHdr->StartAddr);
		
		FW_INFO("ota_len=%x ota_LoadAddr=0x%x\n",pOtaHdr->Img2Size, pOtaHdr->StartAddr);

		ota_block_cnt = pOtaHdr->Img2Size/MAX_FW_BLOCK_SZ;
		ota_remain = pOtaHdr->Img2Size%MAX_FW_BLOCK_SZ;

		/* write ota infomation to device */

		FW_INFO("\n\rPre-load OTA information... \n");

		memset(&ota_info, 0, sizeof(OTA_INFO));
		
		ota_info.crypto_type = (u8)OTA_CIPHER_TYPE; 
		switch(ota_info.crypto_type){
			case 0:
				FW_INFO("OTA encrytion: NONE\n");
				break;
			case 1:
				FW_INFO("OTA encrytion: AES_128_CBC\n");
				memcpy(&(ota_info.info[0]), aes_128_host_key, sizeof(aes_128_host_key));
				memcpy(&(ota_info.info[16]), aes_128_host_iv, sizeof(aes_128_host_iv));
				break;
			/* other encrytion method */
			default:
				FW_ERR("OTA encrytion: UNKOWN\n");
				break;
		}

		ota_info.size = pOtaHdr->Img2Size;
		ota_info.startaddr = pOtaHdr->StartAddr;
#if 0
		DBG_8195A("OTA_INFO size = %d\n",sizeof(OTA_INFO));
		DBG_8195A("OTA_INFO.crypto type = %d\n",ota_info.crypto_type);
		DBG_8195A("OTA_INFO.ota_size = 0x%x\n",ota_info.size);
		DBG_8195A("OTA_INFO.ota_startaddr = 0x%x\n",ota_info.startaddr);
		//DumpForOneBytes(&ota_info ,sizeof(OTA_INFO));
#endif
		status = _FwMemWrite((u32)OTA_INFO_ADDR,(u8*)&ota_info ,sizeof(OTA_INFO));
		if(status == _SUCCESS){
			FW_INFO("OAT information load Done.\n");
			fw_download_ok = 1;
		}else{
			FW_ERR("OAT information load Fail.\n");
			fw_download_ok = 0; // indicate fw download fail
			goto err;
		}	
		
		// allocate a buffer for firmware source
		FwBufferSize = MAX_FW_BLOCK_SZ;

		FwBuffer8195a = rtw_zmalloc(FwBufferSize);
		if(!FwBuffer8195a)
		{
			FW_ERR("Not enough space for OTA block\n");
			goto err;
		}

		for(fw_index=0;fw_index<ota_block_cnt;fw_index++){
			ota_offset = fw_index*MAX_FW_BLOCK_SZ;

			ota_ld_addr = pOtaHdr->StartAddr + ota_offset;
			
			status = flash_stream_read(&flash, ota_address+16+ota_offset, MAX_FW_BLOCK_SZ, FwBuffer8195a);
			if(status){
				status = gpsi_firmware_download(ota_ld_addr, FwBuffer8195a, MAX_FW_BLOCK_SZ);
				if(status == _SUCCESS){
					FW_INFO("ota block(index = %d)download Successfully.\n", fw_index);
					fw_download_ok = 1;
				}else{
					FW_ERR("ota block(index = %d)download Fail.\n", fw_index);
					fw_download_ok = 0; // indicate fw download fail
				}
			}
		}

		if(ota_remain){
			ota_offset = ota_block_cnt*MAX_FW_BLOCK_SZ;
			ota_ld_addr = pOtaHdr->StartAddr + ota_offset;

			// align ciphertext length
			if(ota_remain%16)
				ota_remain += (16-ota_remain%16);
			
			status = flash_stream_read(&flash, ota_address+16+ota_offset, ota_remain, FwBuffer8195a);
			if(status){
				status = gpsi_firmware_download(ota_ld_addr, FwBuffer8195a, ota_remain);
				if(status == _SUCCESS){
					FW_INFO("ota remain(size = %d)download Successfully.\n", ota_remain);
					fw_download_ok = 1;
				}else{
					FW_ERR("ota remain(size = %d)download Fail.\n", ota_remain);
					fw_download_ok = 0; // indicate fw download fail
				}

			}
		}
		
		if (FwBuffer8195a){
			rtw_mfree((u8*)FwBuffer8195a, FwBufferSize);
		}
		if(!fw_download_ok)
			goto err;
	}

#endif
	// jump from rom to sram if fw download ok
	if(fw_download_ok){
		FW_INFO("\n\rFirmware Free to go.\n");
		status = _FWFreeToGo(FirmwareEntryFun, 1000);	
#if STATISTIC_DL_TIME
		stop_t = xTaskGetTickCount();
		DBG_8195A("\n\rTotal down load time %d ms\n", (stop_t-start_t));
#endif
		if(status == _FAIL){
			FW_ERR("Firmware is not runing correctly.\n");
			goto err;
		}else
			DBG_8195A("Firmware download Successfully.\n");
	}else{
		FW_ERR("Firmware download Fail.\n");

		goto err;
	}

#if CONFIG_LOOPBACK_TEST
	//4 Loopback test
	DBG_8195A("Loopback test begin....\n");
	
	// prepare test data (0x00-0xFF, 0x00-0xFF......)
	for(int i=0;i<PACK_SIZE;i++)
		memset(TX_DATA+i, i%256, 1);
	
	do{
		res = gspi_write_page(TX_DATA, PACK_SIZE, 1);
		if(res) {
			DBG_8195A("spi_write_page: Error!");
			// handle error msg here
		}
		rtw_mdelay_os(10);
	}while(--test_loop);
#endif
err:
	/* Kill init thread after all init tasks done */
	vTaskDelete(NULL);
}

void main(void)
{
	if( xTaskCreate( (TaskFunction_t)gspi_demo, "GSPI DEMO", (TASK_STACK_SIZE/4), NULL, TASK_PRIORITY, NULL) != pdPASS) {
		DBG_8195A("Cannot create demo task\n\r");
	}
	
#if defined(CONFIG_KERNEL) && !TASK_SCHEDULER_DISABLED
	#ifdef PLATFORM_FREERTOS
	vTaskStartScheduler();
	#endif
#else
	#error !!!Need FREERTOS!!!
#endif
}

