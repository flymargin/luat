/**************************************************************************
 *              Copyright (C), AirM2M Tech. Co., Ltd.
 *
 * Name:    event.cpp
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
#include "list.h"
#include "W32_util.h"

typedef struct{
    list_head           list;
    const char          *name;
    unsigned char       id;
    event_cb_t          cb;
}event_t;

static list_head event_list = {NULL, NULL};

event_handle_t add_event(PCSTR name, unsigned char id, event_cb_t cb){
	event_t *evt = (event_t *)WinUtil::L_MALLOC(sizeof(event_t));

    evt->name = name;
    evt->id = id;
    evt->cb = cb;

    list_add_after(&evt->list, &event_list);

    return (event_handle_t)evt;
}

void remove_event(event_handle_t *handle){
    event_t **evt_pp = (event_t**)handle;

    if(*evt_pp == NULL) return;

    list_del(&(*evt_pp)->list);

	WinUtil::L_FREE(*evt_pp);
    *evt_pp = NULL;
}

void dispatch_event(UINT8* data, int length){
    list_head *list_pos;
    int evt_id;
    event_t *evt;

    if(length < 1) {
        return;
    }
    
    evt_id = data[0];

    list_for_each(list_pos, &event_list){
        evt = list_entry(list_pos, event_t, list);

        if(evt->id == evt_id && evt->cb){
            evt->cb(&data[1], length-1);
            break;
        }
    }
}

void send_event(event_handle_t handle, PCSTR data, int length){
    event_t *evt = (event_t *)handle;

    daemon_emit_event(evt->id, data, length);
}
