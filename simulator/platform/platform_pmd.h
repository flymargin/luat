/**************************************************************************
 *              Copyright (C), AirM2M Tech. Co., Ltd.
 *
 * Name:    platform_pmd.h
 * Author:  panjun
 * Version: V0.1
 * Date:    2016/10/19
 *
 * Description:
 *          Power Management Definition(PMD).
 * History:
 *     panjun 16/10/19 Initially create file.
 **************************************************************************/

#ifndef __PLATFORM_PMD_H__
#define __PLATFORM_PMD_H__

typedef enum PlatformLdoIdTag
{
    PLATFORM_LDO_KEYPAD,
    PLATFORM_LDO_LCD,

    PLATFORM_LDO_KP_LEDR,
    PLATFORM_LDO_KP_LEDG,
    PLATFORM_LDO_KP_LEDB,

    PLATFORM_LDO_VIB,

    PLATFORM_LDO_VLCD,

    PLATFORM_LDO_VASW,
    PLATFORM_LDO_VMMC,

    PLATFORM_LDO_VCAM,

    PLATFORM_LDO_SINK,

    PLATFORM_LDO_VSIM1,
    PLATFORM_LDO_VSIM2,
	PLATFORM_LDO_VMC,

    PLATFORM_LDO_QTY
}PlatformLdoId;

#define PMD_CFG_INVALID_VALUE           (0xffff)

typedef struct PlatformPmdCfgTag
{
    UINT16             ccLevel;/*�����׶�:4.1*/
    UINT16             cvLevel;/*��ѹ�׶�:4.2*/
    UINT16             ovLevel;/*������ƣ�4.3*/
    UINT16             pvLevel;/*�س�4.1*/
    UINT16             poweroffLevel;/*�ػ���ѹ��3.4�������ڼ�������ٷֱȣ�ʵ�����ϲ���ƹػ�*/
    UINT16             ccCurrent;/*�����׶ε���*/
    UINT16             fullCurrent;/*��ѹ����������30*/
    UINT16             batdetectEnable;
}PlatformPmdCfg;

INT platform_pmd_init(PlatformPmdCfg *pmdCfg);
INT platform_ldo_set(PlatformLdoId id, INT level);

//sleep_wake: 1 sleep 0 wakeup
INT platform_pmd_powersave(INT sleep_wake);

INT platform_pmd_get_charger(void);

UINT32 platform_pmd_getChargingCurrent(void);

#endif //__PLATFORM_PMD_H__
