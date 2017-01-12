/**************************************************************************
 *              Copyright (C), AirM2M Tech. Co., Ltd.
 *
 * Name:    platform_conf.h
 * Author:  liweiqiang
 * Version: V0.1
 * Date:    2012/10/8
 *
 * Description:
 * 
 **************************************************************************/

#ifndef __PLATFORM_CONF_H__
#define __PLATFORM_CONF_H__

#include "auxmods.h"

// *****************************************************************************
// ¶¨ÒåÆ½Ì¨Òª¿ªÆôµÄ¹¦ÄÜ
#define BUILD_LUA_INT_HANDLERS
#define BUILD_C_INT_HANDLERS

/*+\NEW\liweiqiang\2013.12.6\¶ÔÓÚ³¬¹y500KµÄdlÄÚ´æ³Ø,ÄÇÃ´Î±libcµÄmalloc´Ódlmalloc·ÖÅä */
#if DLMALLOC_DEFAULT_GRANULARITY > 500*1024
#define USE_DLMALLOC_ALLOCATOR
#else
#define USE_PLATFORM_ALLOCATOR
#endif
/*-\NEW\liweiqiang\2013.12.6\¶ÔÓÚ³¬¹y500KµÄdlÄÚ´æ³Ø,ÄÇÃ´Î±libcµÄmalloc´Ódlmalloc·ÖÅä */

// *****************************************************************************
// Configuration data

// Virtual timers (0 if not used)
#define VTMR_NUM_TIMERS       0

// Number of resources (0 if not available/not implemented)
#define NUM_PIO               3 // port 0:gpio; port 1:gpo; port 2: gpio ex;
#define NUM_SPI               0
#define NUM_UART              4 //Êµ¼ÊÖ»Ó?2¸öÎïÀí´®¿Ú id0-¼æÈY¾É°æ±¾Îªuart2 id1-uart1 id2-uart2 id3-hostuart
#define NUM_TIMER             2
#define NUM_PWM               0
#define NUM_ADC               8
#define NUM_CAN               0
#define NUM_I2C               3

#define PIO_PIN_EX            9 /*gpio ex 0~6,7,8*/
#define PIO_PIN_ARRAY         {32 /* gpio_num 32 */, 10/* gpo_num 10 */, PIO_PIN_EX}

//?éÄâatÃüÁîÍ¨µÀ
#define PLATFORM_UART_ID_ATC              0x7f

//host uart debugÍ¨µÀ
#define PLATFORM_PORT_ID_DEBUG            0x80

//ÃüÁî??Í¨µÀ
#define CON_UART_ID           (platform_get_console_port())
#define CON_UART_SPEED        115200
#define CON_TIMER_ID          0

// PIO prefix ('0' for P0, P1, ... or 'A' for PA, PB, ...)
#define PIO_PREFIX            '0'

/*+\NEW\liweiqiang\2013.7.16\Ôö¼Óiconv×Ö·û±àÂë×ª»»¿â */
#ifdef LUA_ICONV_LIB
#define ICONV_LINE   _ROM( AUXLIB_ICONV, luaopen_iconv, iconv_map )
#else
#define ICONV_LINE   
#endif
/*-\NEW\liweiqiang\2013.7.16\Ôö¼Óiconv×Ö·û±àÂë×ª»»¿â */

/*+\NEW\liweiqiang\2014.2.9\Ôö¼Ózlib¿â */
#ifdef LUA_ZLIB_LIB
#define ZLIB_LINE   _ROM( AUXLIB_ZLIB, luaopen_zlib, zlib_map )
#else
#define ZLIB_LINE
#endif
/*-\NEW\liweiqiang\2014.2.9\Ôö¼Ózlib¿â */

/*+\NEW\liweiqiang\2014.1.17\AM002_LUA²»Ö§³ÖÏÔÊ¾½Ó¿Ú */
#ifdef LUA_DISP_LIB
#define DISP_LIB_LINE   _ROM( AUXLIB_DISP, luaopen_disp, disp_map )
#else
#define DISP_LIB_LINE
#endif
/*-\NEW\liweiqiang\2014.1.17\AM002_LUA²»Ö§³ÖÏÔÊ¾½Ó¿Ú */

/*+\NEW\liulean\2015.6.15\Ôö¼Ó»ñÈ¡Ä¬ÈÏAPNµÄ¿â */
#ifdef LUA_APN_LIB
#define APN_LINE   _ROM( AUXLIB_APN, luaopen_apn, apn_map )
#else
#define APN_LINE
#endif
/*-\NEW\liulean\2015.6.15\Ôö¼Ó»ñÈ¡Ä¬ÈÏAPNµÄ¿â */


#define LUA_PLATFORM_LIBS_ROM \
    _ROM( AUXLIB_BIT, luaopen_bit, bit_map ) \
    _ROM( AUXLIB_BITARRAY, luaopen_bitarray, bitarray_map ) \
    _ROM( AUXLIB_PACK, luaopen_pack, pack_map ) \
    _ROM( AUXLIB_PIO, luaopen_pio, pio_map ) \
    _ROM( AUXLIB_UART, luaopen_uart, uart_map ) \
    _ROM( AUXLIB_I2C, luaopen_i2c, i2c_map ) \
    _ROM( AUXLIB_RTOS, luaopen_rtos, rtos_map ) \
    DISP_LIB_LINE \
    _ROM( AUXLIB_PMD, luaopen_pmd, pmd_map ) \
    _ROM( AUXLIB_ADC, luaopen_adc, adc_map ) \
    ICONV_LINE \
    _ROM( AUXLIB_AUDIOCORE, luaopen_audiocore, audiocore_map ) \
    ZLIB_LINE \
    _ROM( AUXLIB_WATCHDOG, luaopen_watchdog, watchdog_map ) \
    _ROM( AUXLIB_CPU, luaopen_cpu, cpu_map) \
    APN_LINE \
    _ROM( AUXLIB_GPSCORE, luaopen_gpscore, gpscore_map) 




    // Interrupt queue size
#define PLATFORM_INT_QUEUE_LOG_SIZE 5

#define CPU_FREQUENCY         ( 26 * 1000 * 1000 )

// Interrupt list
#define INT_GPIO_POSEDGE      ELUA_INT_FIRST_ID
#define INT_GPIO_NEGEDGE      ( ELUA_INT_FIRST_ID + 1 )
#define INT_ELUA_LAST         INT_GPIO_NEGEDGE
    
#define PLATFORM_CPU_CONSTANTS \
     _C( INT_GPIO_POSEDGE ),\
     _C( INT_GPIO_NEGEDGE )

#endif //__PLATFORM_CONF_H__
