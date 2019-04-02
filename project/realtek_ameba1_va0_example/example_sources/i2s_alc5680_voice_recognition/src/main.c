/* This is software bypass example */
#include "FreeRTOS.h"
#include "task.h"
#include "diag.h"
#include "main.h"
#include "timer_api.h"
#include "i2s_api.h"
#include "alc5680.h"
#include <platform_stdlib.h>


#define LOOP_BACK
/**
  * @brief  Main program.
  * @param  None
  * @retval None
  */

#include "gpio_api.h"           // mbed
#include "gpio_irq_api.h"       // mbed
#define GPIO_IRQ_PIN            PC_5

static i2s_t i2s_obj;

#define I2S_DMA_PAGE_SIZE	768   // 2 ~ 4096
#define I2S_DMA_PAGE_NUM    4   // Vaild number is 2~4

static u8 i2s_tx_buf[I2S_DMA_PAGE_SIZE*I2S_DMA_PAGE_NUM];
static u8 i2s_rx_buf[I2S_DMA_PAGE_SIZE*I2S_DMA_PAGE_NUM];

#define I2S_SCLK_PIN            PC_1
#define I2S_WS_PIN              PC_0
#define I2S_SD_PIN              PC_2

#define GPIO_LED_PIN            PE_5

static unsigned char voice_irq = 0;
static gpio_t gpio_led;

#define led_off 1
#define led_on  0

#define LED_TIME_PERIOD 100000  //100MS

static void voice_triger_timer_handler(uint32_t id)
{
    static unsigned int count = 0;
    if(voice_irq){
        if(count == 2){
          gpio_write(&gpio_led, led_off);
          count = 0;
          voice_irq = 0;
        }else{
          count++;
        }
    }
}

static void voice_demo_irq_handler (uint32_t id, gpio_irq_event event)
{ 
	if(voice_irq == 0){
		gpio_write(&gpio_led, led_on);
		printf("voice irq \r\n");
		voice_irq = 1;
	}
}



static void test_tx_complete(void *data, char *pbuf)
{    
	return;
}

static void test_rx_complete(void *data, char* pbuf)
{
    i2s_t *obj = (i2s_t *)data;
    int *ptx_buf;

    static u32 count=0;
    count++;
    if ((count&1023) == 1023)
    {
         DBG_8195A_I2S_LVL(VERI_I2S_LVL, ".\n");
    }

    ptx_buf = i2s_get_tx_page(obj);
#ifdef LOOP_BACK
    _memcpy((void*)ptx_buf, (void*)pbuf, I2S_DMA_PAGE_SIZE);
    i2s_send_page(obj, (uint32_t*)ptx_buf);    // loopback
#endif
    i2s_recv_page(obj);    // submit a new page for receive   
}

void main(void)
{
    gtimer_t voice_triger_timer;
    gpio_irq_t voice_irq;
    gpio_t voice_pinr;
        
    printf("GPIO_INIT\r\n");
    // Init LED control pin
    gpio_init(&gpio_led, GPIO_LED_PIN);
    gpio_dir(&gpio_led, PIN_OUTPUT);    // Direction: Output
    gpio_mode(&gpio_led, PullNone);     // No pull
    gpio_write(&gpio_led, led_off);
        
    // Initial Push Button pin as interrupt source
    gpio_irq_init(&voice_irq, GPIO_IRQ_PIN, voice_demo_irq_handler, (uint32_t)(&voice_pinr));
    gpio_irq_set(&voice_irq, IRQ_RISE, 1);   // Rising Edge Trigger
    //gpio_mode(&voice_irq, PullUp);       // Pull-High
    gpio_irq_enable(&voice_irq);
	
    gtimer_init(&voice_triger_timer, TIMER0);
    gtimer_start_periodical(&voice_triger_timer, LED_TIME_PERIOD, (void*)voice_triger_timer_handler, NULL);

	// I2S init
   
    i2s_obj.sampling_rate = SR_48KHZ;
    i2s_obj.channel_num = I2S_CH_STEREO;
    i2s_obj.word_length = I2S_WL_16;

    i2s_obj.direction = I2S_DIR_TXRX;    
    i2s_init(&i2s_obj, I2S_SCLK_PIN, I2S_WS_PIN, I2S_SD_PIN);
    i2s_set_dma_buffer(&i2s_obj, (char*)i2s_tx_buf, (char*)i2s_rx_buf, \
    I2S_DMA_PAGE_NUM, I2S_DMA_PAGE_SIZE);
    i2s_tx_irq_handler(&i2s_obj, (i2s_irq_handler)test_tx_complete, (uint32_t)&i2s_obj);
    i2s_rx_irq_handler(&i2s_obj, (i2s_irq_handler)test_rx_complete, (uint32_t)&i2s_obj);
    
    /* rx need clock, let tx out first */
    i2s_send_page(&i2s_obj, (uint32_t*)i2s_get_tx_page(&i2s_obj));
    i2s_recv_page(&i2s_obj);
	//show the voice trigger version
	alc5680_i2c_init();
    alc5680_get_version();
    
    while(1){
            asm volatile ("nop\n\t");//If run in non-os environment,it needs to add nop operation
            asm volatile ("nop\n\t");
            asm volatile ("nop\n\t");
            asm volatile ("nop\n\t");
    }

}