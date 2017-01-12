/**************************************************************************
 *              Copyright (C), AirM2M Tech. Co., Ltd.
 *
 * Name:    sim_gpio.cpp
 * Author:  panjun
 * Version: V0.1
 * Date:    2016/10/19
 *
 * Description:
 *
 *
 * History:
 *     panjun 16/10/19 Initially create file.
 **************************************************************************/
 
#include "stdafx.h"
#include "event.h"
#include "platform.h"
#include "platform_conf.h"
#include "platform_rtos.h"
#include "W32_util.h"

#define GPIO_EVENT_DIR      1
#define GPIO_EVENT_SET      2
#define GPIO_EVENT_CHANGE   3

#define GPIO_DIR_NOT_OPEN 0
#define GPIO_DIR_OUTPUT 1
#define GPIO_DIR_INPUT  2
#define GPIO_DIR_INT    3

typedef struct{
    UINT8 dir;
    UINT8 val;
}gpio_value_t;

static event_handle_t gpio_event = INVALID_EVENT_HANDLE;
static gpio_value_t gpio_value[NUM_PIO][32];

void send_int_message(UINT8 int_id, UINT16 resnum){
	PlatformMessage *message = (PlatformMessage*)WinUtil::L_MALLOC(sizeof(PlatformMessage));

    message->id = RTOS_MSG_INT;
    message->data.interruptData.id = int_id;
    message->data.interruptData.resnum = resnum;

	platform_rtos_send(message);
}

void gpio_event_cb(UINT8* packet, UINT32 length){
    UINT8 port, pin, val;

    if(length < 1) return;

    switch(packet[0]){    
    case GPIO_EVENT_CHANGE:
        if(length != 4){
            printf("gpio_event_cb: error int packet length %d!\n", length);
            break;
        }
        
        port = packet[1];
        pin = packet[2];
        val = packet[3];

        if(!(gpio_value[port][pin].dir == GPIO_DIR_INPUT || gpio_value[port][pin].dir == GPIO_DIR_INT)) break;

        if(gpio_value[port][pin].val == val) break;

        gpio_value[port][pin].val = val;
        //printf("gpio_event_change:%d %d %d\n",port,pin,val);

        if(gpio_value[port][pin].dir == GPIO_DIR_INT){
            send_int_message(val == 1 ? INT_GPIO_POSEDGE : INT_GPIO_NEGEDGE, PLATFORM_IO_ENCODE(port, pin, 0));
        }
        break;

    case GPIO_EVENT_SET:
        break;
    }
}

static _inline int set_dir(UINT8 port, UINT8 pin, UINT8 dir){
    UINT8 packet[4];
    if(dir != GPIO_DIR_NOT_OPEN && gpio_value[port][pin].dir != GPIO_DIR_NOT_OPEN){
		LogWriter::LOGX("[set_dir]: error pin has opened %d %d %d", port, pin, gpio_value[port][pin].dir);
        return -1;
    }

    gpio_value[port][pin].dir = dir;
    packet[0] = GPIO_EVENT_DIR;
    packet[1] = port;
    packet[2] = pin;
    packet[3] = dir;
    send_event(gpio_event, (PCSTR)packet, sizeof(packet));

    return 0;
}

static _inline int gpio_set(UINT8 port, UINT8 pin, UINT8 val){
    if(port == 1 && gpio_value[port][pin].dir == GPIO_DIR_NOT_OPEN) {
        set_dir(port, pin, GPIO_DIR_OUTPUT);
    }

    if(gpio_value[port][pin].dir != GPIO_DIR_OUTPUT){
        printf("[gpio_set]: pin is not output %d %d %d\n",port, pin, gpio_value[port][pin].dir);
        return -1;
    }

    if(gpio_value[port][pin].val != val){
        UINT8 packet[4];
        gpio_value[port][pin].val = val; 
        packet[0] = GPIO_EVENT_SET;
        packet[1] = port;
        packet[2] = pin;
        packet[3] = val;
        send_event(gpio_event, (PCSTR)packet, sizeof(packet));
    }
    
    return 0;
}

static _inline int gpio_get(UINT8 port, UINT8 pin){
    if(gpio_value[port][pin].dir != GPIO_DIR_INPUT && gpio_value[port][pin].dir != GPIO_DIR_INT){
	LogWriter::LOGX("[gpio_get]: pin is not input %d %d %d", port, pin, gpio_value[port][pin].dir);
	return -1;
    }

    return gpio_value[port][pin].val;
}

// ****************************************************************************
// ****************************************************************************
// PIO functions

pio_type platform_pio_op( unsigned port_val, pio_type pinmask, int op )
{
    UINT8 port = (UINT8)port_val;
    UINT8 pin;

    if(INVALID_EVENT_HANDLE == gpio_event){
        gpio_event = add_event("GPIO", EVENT_GPIO, gpio_event_cb);
    }

    for(pin = 0; pin < 32; pin++){
        if((pinmask&(1<<pin)) == 0) continue;

        switch(op){
        case PLATFORM_IO_PIN_DIR_INT:
            if(set_dir(port, pin, GPIO_DIR_INT) == -1) return 0;
            break;
            
        case PLATFORM_IO_PIN_DIR_INPUT:
            if(set_dir(port, pin, GPIO_DIR_INPUT) == -1) return 0;
            break;
            
        case PLATFORM_IO_PIN_DIR_OUTPUT:
        case PLATFORM_IO_PIN_DIR_OUTPUT1:
            if(set_dir(port, pin, GPIO_DIR_OUTPUT) == -1) return 0;
            break;
            
        case PLATFORM_IO_PIN_SET:
            if(gpio_set(port, pin, 1) == -1) return 0;
            break;
            
        case PLATFORM_IO_PIN_CLEAR:
            if(gpio_set(port, pin, 0) == -1) return 0;
            break;
            
        case PLATFORM_IO_PIN_GET:
            return gpio_get(port, pin);
            break;
            
        case PLATFORM_IO_PIN_CLOSE:
            if(set_dir(port, pin, GPIO_DIR_NOT_OPEN) == -1) return 0;
            break;
            
        default:
            break;
        }
    }
    
    return 1;
}
