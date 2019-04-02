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
#include "hal_crypto.h"

/* debug message */
#define FW_DL_DEBUG	0

#if	FW_DL_DEBUG
#define FW_INFO(fmt, args...)		          DBG_8195A("\n\r%s: " fmt, __FUNCTION__, ## args)
#define FW_ERR(fmt, args...)		          DBG_8195A("\n\r%s: " fmt, __FUNCTION__, ## args)
#else
#define FW_INFO(fmt, args...)
#define FW_ERR(fmt, args...)		          DBG_8195A("\n\r%s: " fmt, __FUNCTION__, ## args)
#endif

/* compulsive: define fw_loader start address on SRAM
*              One can adjust the address to avoid image overlap
*/
#define __ICFEDIT_region_BD_RAM_start__  0x10060000


// GPSI slave configuration
#define OTA_INFO_region         0x1006FFC0
#define DECIPHER_BLOCK_SIZE	(16*1000)	//define deciphering block size, must be multiple of 16
									// should not over 16000 = 16*1000

/* decryption buffer */
u8 cache_buf[DECIPHER_BLOCK_SIZE+4];
u8 key_buf[16+4]; // for Crypto engine alignment
u8 iv_buf[16+4];
u8 iv_tmp[16];


static const u8 aes_cbc_slave_key[16] =
{
	0x2b, 0x7e, 0x15, 0x16, 0x28, 0xae, 0xd2, 0xa6,
	0xab, 0xf7, 0x15, 0x88, 0x09, 0xcf, 0x4f, 0x3c
} ;

u8 aes_cbc_slave_iv[16] =
{
	0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 
	0x08, 0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x0E, 0x0F
};

// This structure must be cared byte-ordering
//
typedef struct _OTA_INFO
{
	u32		crypto_type;	// encyption type
	u8		info[32];	// encyption infomation (eg. aes_key)
	u32		size;
	u32		startaddr;
}OTA_INFO, *POTA_INFO;

int aes_cbc_decryption(u8* aes_key,
                    u8	aes_key_len,
                    u8* aes_iv,
                    u8 	aes_iv_len,
                    const u8 *input,
                    u8 *output,
                    u32 act_len)
{
    u8 *key_buf_aligned;
    u8 *iv_buf_aligned;
    u8 *output_buf, *output_buf_aligned;
	int result = 0;
	u32 cipher_len = 0;

	if(act_len%16)
		cipher_len = act_len + (16-act_len%16);
	else
		cipher_len = act_len;

	if(cipher_len%16)
		return -1;
	
	if(cipher_len > 0){
        key_buf_aligned = (u8 *) (((u32) key_buf + 4) / 4 * 4);
        iv_buf_aligned = (u8 *) (((u32) iv_buf + 4) / 4 * 4);
		output_buf = cache_buf;

        if(output_buf == NULL){
			FW_ERR("Not enough space for cipher text.\n");
			return -2;
		}
            
        output_buf_aligned = (u8 *) (((u32) output_buf + 4) / 4 * 4);
        memcpy(iv_buf_aligned, aes_iv, aes_iv_len);
        memset(output_buf_aligned, 0, cipher_len);

        memcpy(key_buf_aligned, aes_key, aes_key_len);
		
       	result = rtl_crypto_aes_cbc_init(key_buf_aligned, aes_key_len);
		if(result == 0){
			memcpy(iv_tmp, (input + cipher_len - aes_iv_len), aes_iv_len);
			result = rtl_crypto_aes_cbc_decrypt(input, cipher_len, iv_buf_aligned, aes_iv_len, output_buf_aligned);
			if(result == 0){
				memcpy(aes_iv, iv_tmp, aes_iv_len);
				memcpy(output, output_buf_aligned, act_len);
			}else{
				FW_ERR("[%s]rtl_crypto_aes_cbc_decrypt fail.(status = %d)\n",__FUNCTION__,result);
			}
		}
		else{
			FW_ERR("[s%]rtl_crypto_aes_cbc_init fail.(status = %d)\n",__FUNCTION__,result);
		}
    }

	if(result == 0)
		return 0;
    return -1;
}

// GPSI fw loader
void fw_loader(void){
	u8* pbuf = (u8*)OTA_INFO_region;
	u8	local_key[16];
	u8	remote_key[16]; // key from host
	u8	local_iv[16];
	u8	remote_iv[16]; // iv from host
	
	u8	aes_key[16];
	u8	aes_iv[16];

	POTA_INFO	ota_info = NULL; 
	u32 OTA_LoadAddr = 0;
	u32 OTA_Len = 0;
	u32 OTA_crypt = 0; 

	
	u8* otg_img = NULL;
	u8* __ota_entry_func__ = NULL;
	u8* __ota_validate_code__ = NULL;

	u32 ciphered_block_num = 0;
	u32 ciphered_remain = 0;
	
	FW_INFO("===== Enter FW Loader Image	====\n");
		
	ota_info = (POTA_INFO)pbuf;
	
	/* local_key should be read from efuse */
	memcpy(local_key, aes_cbc_slave_key, sizeof(aes_cbc_slave_key));
	memcpy(local_iv, aes_cbc_slave_iv, sizeof(aes_cbc_slave_iv));
	
	/* Load OTA info from cache */
	OTA_crypt = ota_info->crypto_type;
	OTA_Len = ota_info->size;
	OTA_LoadAddr= ota_info->startaddr;

	__ota_entry_func__ = (u8*)OTA_LoadAddr;
	__ota_validate_code__ = __ota_entry_func__ + 4;
	otg_img = __ota_entry_func__; // ota ciphertext start address

	if(!__ota_entry_func__){
		while (1) {
			FW_ERR(" Wrong ota entry pointer ...\n");
			RtlConsolRom(10000);
		}
	}

	switch(OTA_crypt){
		case 0:
			FW_INFO("OTA encrytion: NONE\n");
			break;
		case 1:
			FW_INFO("OTA encrytion: AES_128_CBC\n");
			memcpy(remote_key, &(ota_info->info[0]), 16);
			memcpy(remote_iv, &(ota_info->info[16]), 16);

			/* generate deciphering key and iv */	
			for(int i=0;i<sizeof(aes_key);i++){
				aes_key[i] = local_key[i]^remote_key[i];
			}
			
			memcpy(aes_iv, local_iv, sizeof(local_iv));
			
			if(OTA_LoadAddr != 0){
				int index;
				int offset;
				int result;
				/* OTA decryption */
				ciphered_block_num = OTA_Len/DECIPHER_BLOCK_SIZE;
				ciphered_remain = OTA_Len%DECIPHER_BLOCK_SIZE;

				FW_INFO("Deciphering Start ...\n");
				if ( rtl_cryptoEngine_init() != 0 ) {
					while (1) {
							FW_ERR("cryptoEngine init Fail ...\n");
							RtlConsolRom(10000);
						}
				}

				for(index =0;index<ciphered_block_num;index++){
					offset = index*DECIPHER_BLOCK_SIZE;
					result = aes_cbc_decryption(aes_key, 16,aes_iv, 16, otg_img+offset, otg_img+offset, DECIPHER_BLOCK_SIZE);
					if(result != 0){
						FW_ERR("Deciphering OTA block (index=%d,length=%d) Fail\n",index, DECIPHER_BLOCK_SIZE);
						while (1) {
							FW_ERR("Deciphering fail...\n");
							RtlConsolRom(10000);
						}
					}
				}

				if(ciphered_remain){
					offset = index*DECIPHER_BLOCK_SIZE;

					result = aes_cbc_decryption(aes_key, 16, aes_iv, 16, otg_img+offset, otg_img+offset, ciphered_remain);	
					if(result != 0){
						FW_ERR("Deciphering OTA remain(length=%d) Fail\n", ciphered_remain);
						while (1) {
							FW_ERR("Deciphering fail...\n");
							RtlConsolRom(10000);
						}
					}
				}
				
			}
			FW_INFO("OTA deciphering DONE.\n");
			break;
		/* other encrytion method */
		default:
			FW_ERR("OTA encrytion: UNKOWN\n");
			break;
	}
	
	FW_INFO("===== Enter OTA Image	====\n");
	
	PRAM_START_FUNCTION OTAEntryFun=(PRAM_START_FUNCTION)__ota_entry_func__;

	// Unregister irq handler that has been registered in InfraStart() of fwloader.
	// These irq handler will be properly registered in InfraStart() of user's image2
	IRQ_HANDLE           SysHandle;
	SysHandle.IrqNum     = SYSTEM_ON_IRQ;
	InterruptUnRegister(&SysHandle);

//3 	Jump to OTA Image
	FW_INFO("InfraStart: %p, Img2 Sign %s \n", OTAEntryFun, (char*)__ota_validate_code__);
	if (_strcmp((char *)__ota_validate_code__, "RTKWin")) {
		while (1) {
			FW_ERR("Invalid Image2 Signature\n");
			RtlConsolRom(10000);
		}
	}

	OTAEntryFun->RamStartFun(); 
}

void main(void)
{
	//2 Firmware Loader
	fw_loader();
  while(1);
}

