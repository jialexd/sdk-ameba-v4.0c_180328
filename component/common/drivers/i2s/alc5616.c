#include <stdio.h>
#include "PinNames.h"
#include "basic_types.h"
#include "diag.h" 

#include "i2c_api.h"
#include "pinmap.h"

//#define I2C_MTR_SDA			PC_4//PB_3
//#define I2C_MTR_SCL			PC_5//PB_2
#if defined(CONFIG_PLATFORM_8195A)
	#define I2C_MTR_SDA			PB_3
	#define I2C_MTR_SCL			PB_2
#elif defined(CONFIG_PLATFORM_8711B)
	#define I2C_MTR_SDA			PA_30
	#define I2C_MTR_SCL			PA_29
#endif 
#define I2C_BUS_CLK			100000  //hz

#define I2C_ALC5616_ADDR	(0x36/2)

#define RT5616_PRIV_INDEX	0x6a
#define RT5616_PRIV_DATA	0x6c
	 
#if defined (__ICCARM__)
i2c_t   alc5616_i2c;
#else
volatile i2c_t   alc5616_i2c;
#define printf  DBG_8195A
#endif

static void alc5616_delay(void)
{
    int i;

	i=10000;
    while (i) {
        i--;
        asm volatile ("nop\n\t");
    }
}

void alc5616_reg_write(unsigned int reg, unsigned int value)
{
	char buf[4];
	buf[0] = (char)reg;
	buf[1] = (char)(value>>8);
	buf[2] = (char)(value&0xff);
	
	i2c_write(&alc5616_i2c, I2C_ALC5616_ADDR, &buf[0], 3, 1);
	alc5616_delay();
}

void alc5616_reg_read(unsigned int reg, unsigned int *value)
{
	int tmp;
	char *buf = (char*)&tmp;	
	
	buf[0] = (char)reg;
	i2c_write(&alc5616_i2c, I2C_ALC5616_ADDR, &buf[0], 1, 1);
	alc5616_delay();
	
	buf[0] = 0xaa;
	buf[1] = 0xaa;
	
	i2c_read(&alc5616_i2c, I2C_ALC5616_ADDR, &buf[0], 2, 1);
	alc5616_delay();
	
	*value= ((buf[0]&0xFF)<<8)|(buf[1]&0xFF); 
}

void alc5616_index_write(unsigned int reg, unsigned int value)
{
	alc5616_reg_write(RT5616_PRIV_INDEX, reg);
	alc5616_reg_write(RT5616_PRIV_DATA, value);
}

void alc5616_index_read(unsigned int reg, unsigned int *value)
{
	alc5616_reg_write(RT5616_PRIV_INDEX, reg);
	alc5616_reg_read(RT5616_PRIV_DATA, value);
}

void alc5616_reg_dump(void)
{
	int i;
	unsigned int value;
  
	printf("alc5616 codec reg dump\n\r");
	printf("------------------------\n\r");
	for(i=0;i<=0xff;i++){
		alc5616_reg_read(i, &value);
		printf("%02x : %04x\n\r", i, (unsigned short)value);
	}
	printf("------------------------\n\r");
}

void alc5616_index_dump(void)
{
	int i;
	unsigned int value;
  
	printf("alc5616 codec index dump\n\r");
	printf("------------------------\n\r");
	for(i=0;i<=0xff;i++){
		alc5616_index_read(i, &value);
		printf("%02x : %04x\n\r", i, (unsigned short)value);
	}
	printf("------------------------\n\r");
}

void alc5616_init(void)
{
    i2c_init(&alc5616_i2c, I2C_MTR_SDA, I2C_MTR_SCL);
    i2c_frequency(&alc5616_i2c, I2C_BUS_CLK);
}

void alc5616_set_word_len(int len_idx)	// interface2
{
	// 0: 16 1: 20 2: 24 3: 8
	unsigned int val;
	alc5616_reg_read(0x71,&val);
	val &= (~(0x3<<2));
	val |= (len_idx<<2);
	alc5616_reg_write(0x71,val);
	alc5616_reg_read(0x70,&val);
	val &= (~(0x3<<2));
	val |= (len_idx<<2);
	alc5616_reg_write(0x70,val);	
	
}

void alc5616_init_interface1(void)
{
    alc5616_reg_write(0x00,0x0021);
    alc5616_reg_write(0x63,0xE8FE);
    alc5616_reg_write(0x61,0x5800);
    alc5616_reg_write(0x62,0x0C00);
    alc5616_reg_write(0x73,0x0000);
    alc5616_reg_write(0x2A,0x4242);
    alc5616_reg_write(0x45,0x2000);
    alc5616_reg_write(0x02,0x4848);
    alc5616_reg_write(0x8E,0x0019);
    alc5616_reg_write(0x8F,0x3100);
    alc5616_reg_write(0x91,0x0E00);
    alc5616_index_write(0x3D,0x3E00);
    alc5616_reg_write(0xFA,0x0011);
    alc5616_reg_write(0x83,0x0800);
    alc5616_reg_write(0x84,0xA000);
    alc5616_reg_write(0xFA,0x0C11);
    alc5616_reg_write(0x64,0x4010);
    alc5616_reg_write(0x65,0x0C00);
    alc5616_reg_write(0x61,0x5806);
    alc5616_reg_write(0x62,0xCC00);
    alc5616_reg_write(0x3C,0x004F);
    alc5616_reg_write(0x3E,0x004F);
    alc5616_reg_write(0x27,0x3820);
    alc5616_reg_write(0x77,0x0000);	
}

void alc5616_init_interface2(void)
{
	alc5616_reg_write(0x00,0x0000);
	alc5616_reg_write(0x02,0x0808);
	alc5616_reg_write(0x19,0xAFAF);
	alc5616_reg_write(0x29,0x8080);
	alc5616_reg_write(0x45,0x2000);
	alc5616_reg_write(0x2A,0x1212);
	alc5616_reg_write(0x53,0x3000);
	alc5616_reg_write(0x03,0x4848);
	alc5616_reg_write(0x61,0x9800);
	alc5616_reg_write(0x62,0x0800);
	alc5616_reg_write(0x63,0xF8FF);
	alc5616_reg_write(0x64,0x0000);
	alc5616_reg_write(0x65,0x0000);
	alc5616_reg_write(0x66,0x0000);
	alc5616_reg_write(0x70,0x8000);
	alc5616_reg_write(0x73,0x0104);
	alc5616_reg_write(0x8E,0x0019);
	alc5616_reg_write(0x8F,0x2000);
	alc5616_reg_write(0xFA,0x0001);
	alc5616_index_write(0x3D,0x0600);
}
