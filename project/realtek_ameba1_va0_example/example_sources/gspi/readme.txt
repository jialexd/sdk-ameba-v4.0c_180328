Example Description

	This example describes how to communicate with Ameba gspi interface. 

How to build:
	1. copy src\main.c to project\realtek_ameba1_va0_example\src
	2. include lib\lib_sdiod.a for build, then re-build the project 

	This example source code(mian.c) contain both GSPI slave code and SPI master code, you can use "CONFIG_GPSI_SLAVE" to chose which dirver to run.

	"#define CONFIG_GPSI_SLAVE 1"  for GSPI Slave(NOTE: lib_sdiod.a is need for released SDK) 
	"#define CONFIG_GPSI_SLAVE 0"  for SPI master

Requirement Components:
    2 Ameba DEV_3V0

    Ameba (A): Assign as SPI master
	
	 SCK: PC_1(D13)
	  CS: PB_2(D15)
	MOSI: PC_2(D11)
	MISO: PC_3(D12)
        
	 INT: PB_4(D8)

    Ameba (B): Assign as GSPI slave

	SPI_IN:	PA_4(D5)
	SPI_OUT:PA_2(D7)
	SPI_CLK:PA_3(D6)
	SPI_CS: PA_1(D16)
	SPI_INT:PA_5(D2)

Setup:connect A and B as given
	
	A:	B:

	SCK --- SPI_CLK
	CS  --- SPI_CS
	MOSI---	SPI_OUT
	MISO---	SPI_IN
	INT ---	SPI_INT

	V3.3--- V3.3
	GND --- GND

Behavior:
	A send 2048 bytes to B and B will send whatever recived abck to A
