#include <windows.h>
#include "win_msg.h"
#include "platform_conf.h"
#include "platform.h"

void trigger_atc(void)
{
    MSG msg;
    msg.message = SIMU_UART_ATC_RX_DATA;
    SendToLuaShellMessage(&msg);
}

u32 platform_uart_setup( unsigned id, u32 baud, int databits, int parity, int stopbits, u32 mode )
{      
    if(id == PLATFORM_UART_ID_ATC)
    {
        trigger_atc();
    }
    return baud;
}

u32 platform_uart_close( unsigned id )
{
    return PLATFORM_OK;
}

u32 platform_s_uart_send( unsigned id, u8 data )
{
    return 1;
}

static int iscmgs = 0;
static char atcbuff[1024];
static size_t atcbuffindex = 0; 
u32 platform_s_uart_send_buff( unsigned id, const u8 *buff, u16 len )
{
    if(id == PLATFORM_UART_ID_ATC)
    {
        memset(atcbuff, 0, sizeof(atcbuff));
        atcbuffindex = 0;
        
        if(strcmp(buff,"AT+CGATT?\r") == 0)
        {
            static int count = 0;
            if(++count == 1)
                strcpy(atcbuff,"+CGATT: 1\r\n");
            else
                strcpy(atcbuff,"+CGATT: 0\r\n");
        }
        else if(strcmp(buff, "AT+WISN?\r") == 0)
        {
            strcpy(atcbuff, "00000000\r\n");
        }
        else if(strcmp(buff, "AT+CGSN\r") == 0)
        {
            strcpy(atcbuff, "863616020000161\r\n");
        }
        else if(strncmp(buff,"AT+CMGR",7) == 0)
        {
            //strcpy(atcbuff,"+CMGR: \"REC UNREAD\",\"0031003200350032003000310033003400380032003200390035003500330038\",,\"13/10/08,13:01:04+32\"\r\n674E709C956A003A002000680069\r\n");
            //strcpy(atcbuff,"+CMGR: \"REC UNREAD\",\"002B0038003600310035003800310034003400370038003800330034\",,\"13/10/15,15:56:15+32\"\r\n54C854C854C8\r\n");
            strcpy(atcbuff,"+CMGR: \"REC UNREAD\",\"002B0038003600310038003900310037003300390037003800360039\",,\"13/10/31,17:37:05+32\"\r\n8C03514900310061\r\n\r\n");
        }
        else if(strncmp(buff,"AT+CMGS",7) == 0 || strncmp(buff,"AT+CIPSEND",10) == 0)
        {
            if(strncmp(buff,"AT+CMGS",7) == 0)
            {
                iscmgs = 1;
            }
            else
            {
                iscmgs = 0;
            }
            strcpy(atcbuff,"> \r\n");
        }

        if(strstr(buff,"AT+CIPCLOSE") != NULL)
        {
            strcat(atcbuff,"0,CLOSE OK\r\n");
        }
        else if(0 == strncmp(buff,"AT",2))
            strcat(atcbuff,"OK\r\n");
        else
        {
            if(iscmgs == 1)
            {
                strcat(atcbuff,"+CMGS:108\r\nOK\r\n");
            }
            else
            {
                static int sendcount = 2;
                
                if(sendcount++ > 1)
                    strcat(atcbuff,"0,SEND OK\r\n");
                else
                    strcat(atcbuff,"0,TCP ERROR:12\r\n");
            }
        }

        if(strcmp(buff,"AT+CIPSTATUS\r") == 0)
        {
            strcat(atcbuff,"STATE: IP STATUS\r\n");
        }
        else if(strcmp(buff, "AT+CHFA=0\r") == 0)
        {
            //strcat(atcbuff,"\r\n+CLIP: \"18917397869\",161,\"\",,\"\",0\r\nRING\r\n");
        }
        else if(strncmp(buff,"AT+CIPSTART",10) == 0)
        {
            //strcat(atcbuff,"0, CONNECT FAIL\r\n");
            strcat(atcbuff,"0,CONNECT OK\r\n");
            strcat(atcbuff,"+RECEIVE,0,7:\r\nabcdefg\r\n");
            //strcat(atcbuff,"\r\n+CLIP: \"18917397869\",161,\"\",,\"\",0\r\nRING\r\n");
        }
        else if(strncmp(buff,"ATD",3) == 0)
        {
            //strcat(atcbuff,"NO CARRIER\r\n");
            //strcat(atcbuff,"NO ANSWER\r\n");
            //strcat(atcbuff,"CONNECT\r\n");
            //strcat(atcbuff,"+DTMFDET: 69\r\n+DTMFDET:70\r\n");
        }
        else if(strcmp(buff,"ATH\r") == 0)
        {
            strcat(atcbuff,"NO CARRIER\r\n");
        }
        else if(strncmp(buff,"AT+SENDSOUND",10) == 0)
        {
            extern int win_start_timer(int timer_id, int milliSecond);
            win_start_timer(-2,2340);
        }
        else if(strncmp(buff,"AT+AUDREC",9) == 0)
        {
            strcat(atcbuff,"+AUDREC:2,29480\r\n");
        }

        trigger_atc();
    }
    else
    {
        printf("uart.bufsend:%s\n",buff);
    }

    return len;
}


//0,CONNECT OK\r\n+RECEIVE,0,13:\r\n1234567890123\r\n

static const char atcsimu[] = "RDY\r\n+CFUN: 1\r\n+CPIN: READY\r\n+CREG: 2\r\n" \
"+CREG: 1,\"1813\",\"23c3\"\r\nCALL READY\r\n" \
"SMS READY\r\n";//"+CMTI: \"ME\",44\r\n" \
"+CMTI: \"ME\",45\r\n+CMTI: \"ME\",46\r\n" \
;
static size_t atcreadindex = 0;

int platform_s_uart_recv( unsigned id, s32 timeout )
{
    if(id == PLATFORM_UART_ID_ATC)
    {
        if(atcreadindex < sizeof(atcsimu))
        {
            return atcsimu[atcreadindex++];
        }
        else if(strlen(atcbuff) > atcbuffindex)
        {
            return atcbuff[atcbuffindex++];
        }
    }
    else if(id == 0)
    {
        static unsigned char uart2buf[] = 
        {
            
#if 0
            //,req,time
            0x01,0x80,0x02,0x10,0x02,0x11,0x2B,0xAA,0x03,
                //,send,sms
                0x01,0x82,0x02,0x10,0x14,0x65,0x02,0x10,0x31,0x33,0x39,0x36,0x32,0x38,0x32,0x31,0x35,0x36,0x33,0x8C,0x02,0x13,0x51,0x49,0x02,0x10,0x31,0x02,0x10,0x61,0x03,
                //,set,server
                //0x01,0x83,0x02,0x10,0x02,0x18,0x02,0x13,0x3D,0x9B,0x57,0x26,0x1D,0x52,0x02,0x11,0x11,0x03,
                // reg pack
                //0x01,0x84,0x02,0x10,0x02,0x15,0x5C,0xDC,0x92,0x92,0x92,0x93,0x03,
                // hb pack
                //0x01,0x85,0x02,0x10,0x02,0x15,0x5D,0xDC,0x92,0x92,0x92,0x93,0x03,
                // up data
                0x01,0x81,0x02,0x10,0x02,0x18,0xd2,0x15,0x02,0x18,0x02,0x10,0x02,0x10,0x02,0x11,0x58,0x02,0x015,0x1A,0x03,
#elif 1
                0x55,0x05,0x00,0x56,0x78,0xd3, // cmd 0 查询模块是否有上报内容
                0x55,0x05,0x01,0x56,0x78,0xd4, // cmd 1 查询网络状态
                0x55,0x0C,0x02,0x56,0x78,0xDA,0x5B,0xAF,0xD0,0x1A,0x90,0x01,0x3B, // cmd 2 sck set
                0x55,0x05,0x00,0x56,0x78,0xd3, // cmd 0 查询模块是否有上报内容
                //0x55,0x05,0x00,0x56,0x78,0xd3, // cmd 0 查询模块是否有上报内容
                //0x55,0x05,0x00,0x56,0x78,0xd3, // cmd 0 查询模块是否有上报内容
                0x55,0x05,0x00,0x56,0x78,0xd3, // cmd 0 查询模块是否有上报内容
                0x55,0x09,0x0A,0x56,0x78,0x31,0x32,0x33,0x34,0xAB, // cmd 0a sck send
                0x55,0x05,0x00,0x56,0x78,0xd3, // cmd 0 查询模块是否有上报内容
                0x55,0x0C,0x02,0x56,0x78,0xDA,0x5B,0xAF,0xD0,0x1A,0x90,0x01,0x3B, // cmd 2 sck set
                //0x55,0x05,0x00,0x56,0x78,0xd3, // cmd 0 查询模块是否有上报内容
                //0x55,0x0C,0x02,0x56,0x78,0xDA,0x5B,0xF5,0x39,0x1A,0x90,0x01,0xEA,
                //0x55,0x05,0x00,0x56,0x78,0xd3, // cmd 0 查询模块是否有上报内容
                // 发短信
                0x55,0x1F,0x12,0x56,0x78,0xff,0x31,0x38,0x39,0x31,0x37,0x33,0x39,0x37,0x38,0x36,0x39,0x67,0x4E,0x70,0x9C,0x95,0x6A,0x00,0x3A,0x00,0x20,0x00,0x68,0x00,0x69,0x3D, 
                0x55,0x05,0x00,0x56,0x78,0xd3, // cmd 0 查询模块是否有上报内容
                0x55,0x05,0x00,0x56,0x78,0xd3, // cmd 0 查询模块是否有上报内容
                /* 上报cid */
                0x55,0x19,0x13,0x56,0x78, 0xff,0x31,0x38,0x39,0x31,0x37,0x33,0x39,0x37,0x38,0x36,0x39, 0x31,0x32,0x33,0x34, 0x02,0x8a, 0x03,0x17, 0xbd,
                0x55,0x05,0x00,0x56,0x78,0xd3, // cmd 0 查询模块是否有上报内容
                /*上报语音*/
                0x55,0x32,0x14,0x56,0x78,0x00,0x31,0x38,0x39,0x31,0x37,0x33,0x39,0x37,0x38,0x36,0x39,0x01,0x02,0x03,0x04,0x05,0x06,0x07,0x08,0x09,0x0a,0x0b,0x0c,0x0d,0x0e,0x0f,0x10,0x11,0x12,0x13,0x14,0x15,0x16,0x17,0x18,0x19,0x1a,0x1b,0x1c,0x1d,0x1e,0x1f,0x20,0x21,0x99,
                0x55,0x05,0x00,0x56,0x78,0xd3, // cmd 0 查询模块是否有上报内容
                0x55,0x05,0x00,0x56,0x78,0xd3, // cmd 0 查询模块是否有上报内容
                //0x55,0x05,0x00,0x56,0x78,0xd3, // cmd 0 查询模块是否有上报内容
#else
                0x00,
#endif // 0
        };
        static int readindex = 0;
        int size = sizeof(uart2buf);
        if(sizeof(uart2buf) > readindex)
            return uart2buf[readindex++];
        else
            return -1;
    }
    else if(id == 1)
    {
        static int uart1readindex = 0;
        static char uart1buf[] = {"AT+FT9321\r\n"};
        if(sizeof(uart1buf) > uart1readindex)
            return uart1buf[uart1readindex++];
        else
            return -1;
    }
    return -1;
}

int platform_s_uart_set_flow_control( unsigned id, int type )
{
    return PLATFORM_ERR;
}
