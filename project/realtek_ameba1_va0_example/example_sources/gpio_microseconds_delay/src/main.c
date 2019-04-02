#include "FreeRTOS.h"
#include "task.h"
#include "diag.h"
#include "main.h"
#include <stdint.h>
#include <example_entry.h>
#include "rtl8195a.h"
#include "gpio_api.h"

extern void console_init(void);

#define GPIO_OUTPUT_PIN PC_0

#ifndef portNVIC_SYSTICK_CURRENT_VALUE_REG
#define portNVIC_SYSTICK_CURRENT_VALUE_REG	( * ( ( volatile uint32_t * ) 0xe000e018 ) )
#endif

#define portOutputRegister(P) ( (volatile uint32_t *)( 0x40001000 + (P) * 0x0C ) )

void delay( uint32_t ms );
void delayMicroseconds(uint32_t us);
uint32_t millis( void );
uint32_t micros( void );

void delay( uint32_t ms ) {
    vTaskDelay(ms);
}

/*
 * This API implemented from a busy loop with CPU assembly "nop" (no operation).
 * The accuracy is mostly less than 0.5us. The parameter inside is corrected from
 * logical analysier. You can try to make it more precisely by changing parameters
 * inside.
 **/
void delayMicroseconds( uint32_t us ) {
    int i, j;
    uint32_t t0, tn;
    if ( us > 100) {
        t0 = micros();
        do {
            tn = micros();
        } while ( tn >= t0 && tn < (t0 + us - 1) );
    } else {
        for (i=0; i<us; i++) {
            for (j=0; j<27; j++) {
                asm("nop");
            }
        }
    }
}

uint32_t millis( void ) {
    return (__get_IPSR() == 0) ? xTaskGetTickCount() : xTaskGetTickCountFromISR();
}

/*
 * This API return current system time in unit of microseconds.
 * It comebines 2 parts: milliseconds and microseconds.
 *     Millisecond is retrieved from system tick.
 *     Microsecond is retrieved from Cortex-M3 CPU clock register.
 * The microsecond part assumes that CPU clock frequency is 166MHz.
 * Please note that calling this API would cost around 1~2 microseconds.
 **/
uint32_t micros( void ) {
    uint32_t tick1, tick2;
    uint32_t us;

    if (__get_IPSR() == 0) {
        tick1 = xTaskGetTickCount();
        us = portNVIC_SYSTICK_CURRENT_VALUE_REG;
        tick2 = xTaskGetTickCount();
    } else {
        tick1 = xTaskGetTickCountFromISR();
        us = portNVIC_SYSTICK_CURRENT_VALUE_REG;
        tick2 = xTaskGetTickCountFromISR();
    }

    if (tick1 == tick2) {
        return tick1 * 1000 - us / 167;
    } else if( (us / 167) < 500 ) {
        return tick1 * 1000 - us / 167;
    } else {
        return tick1 * 1000;
    }
}

/*
 * This thread demonstrate how to use microseconds delay.
 * In this thread we configure a gpio as output pin and generate pulses with interval from 1us to 200us.
 * Then delay 2s and repeat again. You can check this signal on logical analyser or oscilloscope with
 * microsecond precision.
 *
 * INPORTANT NOTICE:
 *     The delayMicroseconds API uses CPU clock resource. It means it cannot be interrupted otherwise it
 *     would be out of precision. We disable interrupt before using this API, and then enable interrupt
 *     after that. Thus it sutibles to situation (Ex. IR) that only occupy a short period of time. And 
 *     it's not recommended to apply on microseconds lelvel PWM.
 */
static void delay_demo_thread(void *param) {

    gpio_t gpio_out;
    uint32_t port, mask;
    uint32_t delay_interval;

    gpio_init(&gpio_out, GPIO_OUTPUT_PIN);
    gpio_dir(&gpio_out, PIN_OUTPUT);
    gpio_mode(&gpio_out, PullNone);
    gpio_write(&gpio_out, 0);

    port = gpio_out.hal_port_num;
    mask = 1 << (gpio_out.hal_pin_num);

    while (1) {
        taskDISABLE_INTERRUPTS();
        for (delay_interval = 1; delay_interval <=200; delay_interval++) {
            *portOutputRegister( port ) |=  mask;
            delayMicroseconds( delay_interval );
            *portOutputRegister( port ) &= ~mask;
            delayMicroseconds( delay_interval );
        }
        taskENABLE_INTERRUPTS();
        delay(2000);
    }
}

/**
  * @brief  Main program.
  * @param  None
  * @retval None
  */
void main(void)
{
	/* Initialize log uart and at command service */
	console_init();	

	/* pre-processor of application example */
	pre_example_entry();

	/* wlan intialization */
#if defined(CONFIG_WIFI_NORMAL) && defined(CONFIG_NETWORK)
	wlan_network();
#endif

	/* Execute application example */
	example_entry();

    if(xTaskCreate(delay_demo_thread, ((const char*)"delay_demo_thread"), 1024, NULL, tskIDLE_PRIORITY+1 , NULL) != pdPASS)
        printf("\n\r%s xTaskCreate(delay_demo_thread) failed", __FUNCTION__);

    	/*Enable Schedule, Start Kernel*/
#if defined(CONFIG_KERNEL) && !TASK_SCHEDULER_DISABLED
	#ifdef PLATFORM_FREERTOS
	vTaskStartScheduler();
	#endif
#else
	RtlConsolTaskRom(NULL);
#endif
}