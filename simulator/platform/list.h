/**************************************************************************
 *              Copyright (C), AirM2M Tech. Co., Ltd.
 *
 * Name:    list.h
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


typedef struct list_head_tag
{
  struct list_head_tag *prev;
  struct list_head_tag *next;
}list_head;

#define list_for_each(pos, head) \
    for ( pos = (head)->next; \
          pos != (head); \
          pos = pos->next)

#define list_for_each_safe(pos,pos_next,head) \
    for ( pos = (head)->next, pos_next = pos->next; \
          pos != (head); \
          pos = pos_next, pos_next = pos->next)

#define list_empty(head) (head->next == head)

#if 1
/* Ϊ���ͨ�������ʹ��Ч��,�뽫list��������Ϊ�ṹ��ĵ�һ������ */
#define list_entry(ptr, type, member) ((type*)ptr)
#else
/* ʹ�øú궨��,������ʹ��ͨ������ʱ,��㶨��list�ı���λ�� */
#define list_entry(ptr, type, member) ((type*)((char*)ptr - offsetof(type,member)))
#endif


#define init_list_head(ptr) \
    do{\
        (ptr)->prev = ptr;  \
        (ptr)->next = ptr;  \
    }while(0)

extern void list_add_before(list_head *node, list_head *pos);

extern void list_add_after(list_head *node, list_head *pos);

extern void list_del(list_head *node);
