/*
 *  Routines to access hardware
 *
 *  Copyright (c) 2013 Realtek Semiconductor Corp.
 *
 *  This module is a confidential and proprietary property of RealTek and
 *  possession or use of this module requires written permission of RealTek.
 */

#include "PinNames.h"
#include "basic_types.h"
#include "diag.h"
#include <osdep_api.h>

#include "i2c_api.h"
#include "pinmap.h"
#include "ex_api.h"

#define MBED_I2C_MTR_SDA    PB_3
#define MBED_I2C_MTR_SCL    PB_2

#define MBED_I2C_SLV_SDA    PC_4
#define MBED_I2C_SLV_SCL    PC_5

#define MBED_I2C_SLAVE_ADDR0    0xAA
#define MBED_I2C_BUS_CLK        100000  //hz

#define I2C_DATA_LENGTH         127
char	i2cdatasrc[I2C_DATA_LENGTH];
char	i2cdatadst[I2C_DATA_LENGTH];
char	i2cdatardsrc[I2C_DATA_LENGTH];
char	i2cdatarddst[I2C_DATA_LENGTH];

#define I2C_MASTER_DEVICE
#ifndef I2C_MASTER_DEVICE
	#define I2C_SLAVE_DEVICE
#endif

// RESTART verification
#undef I2C_RESTART_DEMO	

// Slave
	// RX
#define CLEAR_SLV_RXC_FLAG	(slaveRXC = 0)
#define SET_SLV_RXC_FLAG	(slaveRXC = 1)
#define WAIT_SLV_RXC		while(slaveRXC == 0){;}
	// Tx
#define CLEAR_SLV_TXC_FLAG	(slaveTXC = 0)
#define SET_SLV_TXC_FLAG	(slaveTXC = 1)
#define WAIT_SLV_TXC		while(slaveTXC == 0){;}
    // Read Request
#define CLEAR_SLV_RD_REQ_FLAG	(slaveRdReq = 0)
#define SET_SLV_RD_REQ_FLAG	    (slaveRdReq = 1)
#define WAIT_SLV_RD_REQ		    while(slaveRdReq == 0){;}

// Master
	// Rx
#define CLEAR_MST_RXC_FLAG	(masterRXC = 0)
#define SET_MST_RXC_FLAG	(masterRXC = 1)
#define WAIT_MST_RXC		while(masterRXC == 0){;}
	// Tx
#define CLEAR_MST_TXC_FLAG	(masterTXC = 0)
#define SET_MST_TXC_FLAG	(masterTXC = 1)
#define WAIT_MST_TXC		while(masterTXC == 0){;}

#if defined (__ICCARM__)
i2c_t   i2cmaster;
i2c_t   i2cslave;
#else
volatile i2c_t   i2cmaster;
volatile i2c_t   i2cslave;
#endif
volatile int     masterTXC;
volatile int     masterRXC;
volatile int     slaveTXC;
volatile int     slaveRXC;
volatile int     slaveRdReq;

void i2c_slave_rxc_callback(void *userdata)
{

    int     i2clocalcnt;
    int     result = 0;
    
    i2c_enable_control(&i2cslave, 0);
    for (i2clocalcnt = 0; i2clocalcnt < I2C_DATA_LENGTH; i2clocalcnt+=2) {
    //  DBG_8195A("i2c data: %02x \t %02x\n",i2cdatadst[i2clocalcnt],i2cdatadst[i2clocalcnt+1]);
    }
    //HalDelayUs(5000);
    
    // verify result
    result = 1;
#if !defined(I2C_RESTART_DEMO)
    for (i2clocalcnt = 0; i2clocalcnt < I2C_DATA_LENGTH; i2clocalcnt++) {
        if (i2cdatasrc[i2clocalcnt] != i2cdatadst[i2clocalcnt]) {
            result = 0;
            break;
        }
    }
#else
    if (i2cdatasrc[0] == i2cdatadst[0]) {
        if (i2cdatasrc[0] != i2cdatadst[0]) {
            result = 0;
        }
    } else if (i2cdatasrc[1] == i2cdatadst[0]) {
        for (i2clocalcnt = 1; i2clocalcnt < I2C_DATA_LENGTH; i2clocalcnt++) {
            if (i2cdatasrc[i2clocalcnt] != i2cdatadst[i2clocalcnt -1]) {
                DBG_8195A("idx:%d, src:%x, dst:%x\n", i2clocalcnt, i2cdatasrc[i2clocalcnt], i2cdatadst[i2clocalcnt]);
                for (i2clocalcnt = 0; i2clocalcnt < I2C_DATA_LENGTH; i2clocalcnt+=2) {
                    DBG_8195A("i2c data: %02x \t %02x\n",i2cdatadst[i2clocalcnt],i2cdatadst[i2clocalcnt+1]);
                }
                result = 0;
                break;
            }
        }
    } else {
        for (i2clocalcnt = 0; i2clocalcnt < I2C_DATA_LENGTH; i2clocalcnt++) {
            if (i2cdatasrc[i2clocalcnt] != i2cdatadst[i2clocalcnt]) {
                DBG_8195A("idx:%d, src:%x, dst:%x\n", i2clocalcnt, i2cdatasrc[i2clocalcnt], i2cdatadst[i2clocalcnt]);
                result = 0;
                break;
            }
        }
    }
#endif

    DBG_8195A("\r\nSlave receive: Result is %s\r\n", (result) ? "success" : "fail");
    _memset(&i2cdatadst[0], 0x00, I2C_DATA_LENGTH);
    SET_SLV_RXC_FLAG;
    i2c_enable_control(&i2cslave, 1);
}


void i2c_master_rxc_callback(void *userdata)
{

	int     i2clocalcnt;
	int     result = 0;

	//DBG_8195A("show master received data>>>\n");
	for (i2clocalcnt = 0; i2clocalcnt < I2C_DATA_LENGTH; i2clocalcnt+=2) {
		//DBG_8195A("i2c data: %02x \t %02x\n",i2cdatarddst[i2clocalcnt],i2cdatarddst[i2clocalcnt+1]);
	}

	// verify result
	result = 1;
	for (i2clocalcnt = 0; i2clocalcnt < I2C_DATA_LENGTH; i2clocalcnt++) {
		if (i2cdatarddst[i2clocalcnt] != i2cdatardsrc[i2clocalcnt]) {
			result = 0;
			break;
		}
	}
	DBG_8195A("\r\nMaster receive: Result is %s\r\n", (result) ? "success" : "fail");

}

void i2c_slave_txc_callback(void *userdata)
{
    SET_SLV_TXC_FLAG;
}

void i2c_master_txc_callback(void *userdata)
{
    SET_MST_TXC_FLAG;
}

void i2c_master_err_callback(void *userdata)
{
    DBG_8195A("ERR:%x\n", i2cmaster.SalI2CHndPriv.SalI2CHndPriv.ErrType);
}

void i2c_slave_rd_req_callback(void *userdata) {
    DBG_8195A("rd req\n");
    SET_SLV_RD_REQ_FLAG;
}

void demo_i2c_master_enable(void)
{
	_memset(&i2cmaster, 0x00, sizeof(i2c_t));
	i2c_init(&i2cmaster, MBED_I2C_MTR_SDA ,MBED_I2C_MTR_SCL);  
    i2c_frequency(&i2cmaster,MBED_I2C_BUS_CLK);
    i2c_set_user_callback(&i2cmaster, I2C_RX_COMPLETE, i2c_master_rxc_callback);
    i2c_set_user_callback(&i2cmaster, I2C_TX_COMPLETE, i2c_master_txc_callback);
    i2c_set_user_callback(&i2cmaster, I2C_ERR_OCCURRED, i2c_master_err_callback);
#ifdef I2C_RESTART_DEMO
	i2c_restart_enable(&i2cmaster);
#endif
}

void demo_i2c_slave_enable(void)
{
	_memset(&i2cslave, 0x00, sizeof(i2c_t));
	i2c_init(&i2cslave, MBED_I2C_SLV_SDA ,MBED_I2C_SLV_SCL);
    i2c_frequency(&i2cslave,MBED_I2C_BUS_CLK);
    i2c_slave_address(&i2cslave, 0, MBED_I2C_SLAVE_ADDR0, 0xFF);
    i2c_slave_mode(&i2cslave, 1);
    i2c_set_user_callback(&i2cslave, I2C_RX_COMPLETE, i2c_slave_rxc_callback);
	i2c_set_user_callback(&i2cslave, I2C_TX_COMPLETE, i2c_slave_txc_callback);
    i2c_set_user_callback(&i2cslave, I2C_RD_REQ_COMMAND, i2c_slave_rd_req_callback);
}

void demo_i2c_master_write_1byte(void)
{
	DBG_8195A("Mst-W\n");
    CLEAR_MST_TXC_FLAG;
    i2c_write(&i2cmaster, MBED_I2C_SLAVE_ADDR0, &i2cdatasrc[0], 1, 0);
    WAIT_MST_TXC;
    DBG_8195A("Mst-W is complete and STOP bit is NOT sent.\n");
}

void demo_i2c_master_write_n_1byte(void)
{
	DBG_8195A("Mst-W\n");
	CLEAR_MST_TXC_FLAG;
    i2c_write(&i2cmaster, MBED_I2C_SLAVE_ADDR0, &i2cdatasrc[1], (I2C_DATA_LENGTH-1), 1);
    //wait for master TXC
	WAIT_MST_TXC;
}

void demo_i2c_master_write(void)
{
	DBG_8195A("Mst-W\n");
    CLEAR_MST_TXC_FLAG;
    i2c_write(&i2cmaster, MBED_I2C_SLAVE_ADDR0, &i2cdatasrc[0], I2C_DATA_LENGTH, 1);
    //wait for master TXC
	WAIT_MST_TXC;
}

void demo_i2c_master_read(void)
{
    DBG_8195A("Mst-R\n");
	DBG_8195A("Mst-R need to wait Slv-W complete.\n");
	CLEAR_MST_RXC_FLAG;
    i2c_read(&i2cmaster, MBED_I2C_SLAVE_ADDR0, &i2cdatarddst[0], I2C_DATA_LENGTH, 1);
	WAIT_MST_RXC;
}

void demo_i2c_slave_read(void)
{
    DBG_8195A("Slv-R\n");
    CLEAR_SLV_RXC_FLAG;
    i2c_slave_read(&i2cslave, &i2cdatadst[0], I2C_DATA_LENGTH);
    WAIT_SLV_RXC;
}

void demo_i2c_slave_read_1byte(void)
{
	DBG_8195A("Slv-R\n");
    CLEAR_SLV_RXC_FLAG;
    i2c_slave_read(&i2cslave, &i2cdatadst[0], 1);
    WAIT_SLV_RXC;
}

void demo_i2c_slave_write(void)
{
    DBG_8195A("Slv-W\n");
    CLEAR_SLV_RD_REQ_FLAG;
    i2c_slave_set_for_rd_req(&i2cslave, 1);
    WAIT_SLV_RD_REQ;
	CLEAR_SLV_TXC_FLAG;
    i2c_slave_write(&i2cslave, &i2cdatardsrc[0], I2C_DATA_LENGTH);
	WAIT_SLV_TXC;
}

void main(void)
{
    int     i2clocalcnt;

	DBG_8195A("Slave address: 0x%x\n", MBED_I2C_SLAVE_ADDR0);
#ifdef I2C_RESTART_DEMO
	DBG_8195A("Enable restart\n");
#endif
	
    // prepare for transmission
    _memset(&i2cdatasrc[0], 0x00, I2C_DATA_LENGTH);
    _memset(&i2cdatadst[0], 0x00, I2C_DATA_LENGTH);
    _memset(&i2cdatardsrc[0], 0x00, I2C_DATA_LENGTH);
    _memset(&i2cdatarddst[0], 0x00, I2C_DATA_LENGTH);

    for (i2clocalcnt=0; i2clocalcnt < I2C_DATA_LENGTH; i2clocalcnt++){
        i2cdatasrc[i2clocalcnt] = i2clocalcnt+0x2;
    }

    for (i2clocalcnt=0; i2clocalcnt < I2C_DATA_LENGTH; i2clocalcnt++){
        i2cdatardsrc[i2clocalcnt] = i2clocalcnt+1;
    }

//================================================================
	
// ------- Dual board -------
#ifdef I2C_MASTER_DEVICE
    demo_i2c_master_enable();

	// Master write - Slave read
#ifdef I2C_RESTART_DEMO
	demo_i2c_master_write_1byte();
	demo_i2c_master_write_n_1byte();	// n-1 bytes
#else
	demo_i2c_master_write();
#endif
	
	// Master read - Slave write
#ifdef I2C_RESTART_DEMO
    demo_i2c_master_write_1byte();
#endif
	demo_i2c_master_read();
#endif // #ifdef I2C_MASTER_DEVICE
	

#ifdef I2C_SLAVE_DEVICE
    demo_i2c_slave_enable();
    i2c_slave_set_for_data_nak(&i2cslave, 1);
    HalDelayUs(5000);
    i2c_slave_set_for_data_nak(&i2cslave, 0);
	// Master write - Slave read
	demo_i2c_slave_read();

	// Master read - Slave write
#ifdef I2C_RESTART_DEMO
	demo_i2c_slave_read_1byte();
#endif
	demo_i2c_slave_write();
#endif // #ifdef I2C_SLAVE_DEVICE

    while(1){;}
}

