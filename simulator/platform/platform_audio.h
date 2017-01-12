/**************************************************************************
 *              Copyright (C), AirM2M Tech. Co., Ltd.
 *
 * Name:    platform_audio.h
 * Author:  panjun
 * Version: V0.1
 * Date:    2016/09/13
 *
 * Description:
 *          Implement 'audio' class.
 * History:
 *     panjun 16/09/13 Initially create file.
 **************************************************************************/

#ifndef __PLATFORM_AUDIO_H__
#define __PLATFORM_AUDIO_H__

typedef enum PlatformAudioFormatTag
{
    PLATFORM_AUD_AMR122,
    PLATFORM_AUD_MP3,
    PLATFORM_AUD_PCM,
    PLATFORM_AUD_WAV,
    PLATFORM_AUD_MIDI,
    NumOfPlatformAudFormats
}PlatformAudioFormat;

typedef enum PlatformAudioChannelTag
{
    PLATFORM_AUD_CHANNEL_HANDSET,
    PLATFORM_AUD_CHANNEL_EARPIECE,
    PLATFORM_AUD_CHANNEL_LOUDSPEAKER,
    PLATFORM_AUD_CHANNEL_BLUETOOTH,
    PLATFORM_AUD_CHANNEL_FM,
    PLATFORM_AUD_CHANNEL_FM_LP,
    PLATFORM_AUD_CHANNEL_TV,
    PLATFORM_AUD_CHANNEL_AUX_HANDSET,
    PLATFORM_AUD_CHANNEL_AUX_LOUDSPEAKER,
    PLATFORM_AUD_CHANNEL_AUX_EARPIECE,
    PLATFORM_AUD_CHANNEL_DUMMY_HANDSET,    
    PLATFORM_AUD_CHANNEL_DUMMY_AUX_HANDSET,
    PLATFORM_AUD_CHANNEL_DUMMY_LOUDSPEAKER,
    PLATFORM_AUD_CHANNEL_DUMMY_AUX_LOUDSPEAKER,
    NumOfPlatformAudChannels
}PlatformAudioChannel;

typedef enum PlatformAudioVolTag
{
    PLATFORM_AUD_VOL0,
    PLATFORM_AUD_VOL1,
    PLATFORM_AUD_VOL2,
    PLATFORM_AUD_VOL3,
    PLATFORM_AUD_VOL4,
    PLATFORM_AUD_VOL5,
    PLATFORM_AUD_VOL6,
    PLATFORM_AUD_VOL7,
    NumOfPlatformAudVols
}PlatformAudioVol;

typedef enum PlatformMicVolTag
{
    PLATFORM_MIC_VOL0,
    PLATFORM_MIC_VOL1,
    PLATFORM_MIC_VOL2,
    PLATFORM_MIC_VOL3,
    PLATFORM_MIC_VOL4,
    PLATFORM_MIC_VOL5,
    PLATFORM_MIC_VOL6,
    PLATFORM_MIC_VOL7,
    PLATFORM_MIC_VOL8,
    PLATFORM_MIC_VOL9,
    PLATFORM_MIC_VOL10,
    PLATFORM_MIC_VOL11,
    PLATFORM_MIC_VOL12,
    PLATFORM_MIC_VOL13,
    PLATFORM_MIC_VOL14,
    PLATFORM_MIC_VOL15,
    NumOfPlatformMicVols
}PlatformMicVol;

typedef enum PlatformAudioLoopbackTag
{
    PLATFORM_AUD_LOOPBACK_HANDSET,
    PLATFORM_AUD_LOOPBACK_EARPIECE,
    PLATFORM_AUD_LOOPBACK_LOUDSPEAKER,
    PLATFORM_AUD_LOOPBACK_AUX_HANDSET,
    PLATFORM_AUD_LOOPBACK_AUX_LOUDSPEAKER,
    NumOfPlatformAudLoopbacks
}PlatformAudioLoopback;
/*-\NEW\zhuth\2014.7.25\����������Ƶͨ����������ͬ���ӿ�*/

typedef struct AudioPlayParamTag
{
    BOOL isBuffer;
    union u_tag
    {
        struct
        {
            PCSTR data;
            UINT32 len;
            PlatformAudioFormat format;
            BOOL loop;
        }buffer;
        const char *filename;
    }u;
}AudioPlayParam;

int platform_audio_play(AudioPlayParam *param);

int platform_audio_stop(void);

/*+\NEW\zhuth\2014.7.25\����������Ƶͨ����������ͬ���ӿ�*/
int platform_audio_set_channel(PlatformAudioChannel channel);

int platform_audio_set_vol(PlatformAudioVol vol);

int platform_audio_set_sph_vol(PlatformAudioVol vol);

int platform_audio_set_mic_vol(PlatformMicVol vol);

int platform_audio_set_loopback(BOOL flag, PlatformAudioLoopback typ, BOOL setvol, UINT32 vol);
/*-\NEW\zhuth\2014.7.25\����������Ƶͨ����������ͬ���ӿ�*/

int platform_audio_record(char* file_name, int time_sec, int quality);

int platform_audio_stop_record(void);

#endif //__PLATFORM_AUDIO_H__

