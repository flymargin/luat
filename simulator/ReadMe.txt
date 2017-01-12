========================================================================
    DYNAMIC LINK LIBRARY : AMWatchDll Project Overview
========================================================================

AppWizard has created this AMWatchDll DLL for you.

This file contains a summary of what you will find in each of the files that
make up your AMWatchDll application.


AMWatchDll.vcproj
    This is the main project file for VC++ projects generated using an Application Wizard.
    It contains information about the version of Visual C++ that generated the file, and
    information about the platforms, configurations, and project features selected with the
    Application Wizard.

AMWatchDll.cpp
    This is the main DLL source file.

	When created, this DLL does not export any symbols. As a result, it
	will not produce a .lib file when it is built. If you wish this project
	to be a project dependency of some other project, you will either need to
	add code to export some symbols from the DLL so that an export library
	will be produced, or you can set the Ignore Input Library property to Yes
	on the General propert page of the Linker folder in the project's Property
	Pages dialog box.

/////////////////////////////////////////////////////////////////////////////
Other standard files:

StdAfx.h, StdAfx.cpp
    These files are used to build a precompiled header (PCH) file
    named AMWatchDll.pch and a precompiled types file named StdAfx.obj.

/////////////////////////////////////////////////////////////////////////////
Other notes:

AppWizard uses "TODO:" comments to indicate parts of the source code you
should add to or customize.

/////////////////////////////////////////////////////////////////////////////

Files in this distribution:
     platform       =>  platform's API for Lua shell
			font                      => Dll's font
			 font_40.dat              => 20x40 ASCII
			 font_pinyin_40.dat       => 20x40 chinese font
			 fonthz_40.dat            => 40x40 chinese font
			 fonthzext_40.dat         => 40x40 chinese font
			 fonthzext_offset_40.dat  => offset of 40x40 chinese font
			iconv                     => character encoding conversion
			 gb2312_to_ucs2.cpp       =>
			 gb2312_to_ucs2_table.h   =>
			 iconv.cpp                =>
			 iconv.h                  =>
			 prv_iconv.h              =>
			 ucs2_to_gb2312.cpp       =>
			 ucs2_to_gb2312_offset.h  =>
			 ucs2_to_gb2312_table.h   =>
			 utf8_to_ucs2.cpp         =>
			json                      => JSON support for Lua
			 fpconv.cpp               =>
			 fpconv.h                 =>
			 lua_cjson.cpp            =>
			 strbuf.cpp               =>
			 strbuf.h                 =>
			qr_encode                 => QR Code encoding tool
			 bitstream.cpp            =>
			 bitstream.h              =>
			 config.h                 =>
			 mask.cpp                 =>
			 mask.h                   =>
			 mmask.cpp                =>
			 mmask.h                  =>
			 mqrspec.cpp              =>
			 mqrspec.h                =>
			 qrenc.cpp                =>
			 qrencode.cpp             =>
			 qrencode.h               =>
			 qrencode_inner.h         =>
			 qrinput.cpp              =>
			 qrinput.h                =>
			 qrspec.cpp               =>
			 qrspec.h                 =>
			 rscode.cpp               =>
			 rscode.h                 =>
			 split.cpp                =>
			 split.h                  =>
      auxmods.h                 => definition for Lua lib API
      buf.cpp                   => eLua "char device" buffering system
      buf.h                     =>
      common.cpp                => common API
      common_tmr.cpp            => common timer
      common_uart.cpp           => common UART
      cycle_queue.cpp           =>
      cycle_queue.h             =>
      daemon.cpp                =>
      daemon.h                  =>
      event.cpp                 =>
      event.h                   =>
      list.cpp                  =>
      list.h                    =>
      mthl.cpp                  =>
      mthl.h                    =>
      platform.cpp              =>
      platform.h                =>
      platform_atc.cpp          =>
      platform_atc.h            =>
      platform_audio.cpp        =>
      platform_audio.h          =>
      platform_conf.h           =>
      platform_disp.cpp         =>
      platform_disp.h           =>
      platform_gps.cpp          =>
      platform_gps.h            =>
      platform_i2c.cpp          =>
      platform_i2c.h            =>
      platform_pmd.cpp          =>
      platform_pmd.h            =>
      platform_rtos.cpp         =>
      platform_rtos.h           =>
      platform_SLI3108.cpp      =>
      platform_SLI3108.h        =>
      platform_socket.cpp       =>
      platform_socket.h         =>
      platform_ttsply.cpp       =>
      platform_ttsply.h         =>
      platform_uart.cpp         =>
      platform_uart.h           =>
      platform_watchdog.cpp     =>
      platform_watchdog.h       =>
      platform_wtimer.cpp       =>
      platform_wtimer.h         =>
      sermux.h                  =>
      w32_abm.cpp               => abm for LUA
      w32_abm.h                 => abm's definition
      w32_socket.cpp            => socket for LUA
      w32_socket.h              => socket's definition
     Win32_lib                  => 32-bit library for Dll
      giflib                    => gif library
      lpng                      => png library
      Lua5.1                    => Lua 5.1
      zlib                      => zlib
      AMWatchDll.dll            => dll for AMWatch
      AMWatchDll.lib            => lib for AMWatch
      lua5.1.dll                => dll for lua5.1
      lua5.1.exe                => exe for lua5.1
      lua5.1.lib                => lib for lua5.1
     x64_lib                    => 64-bit library for Dll
      giflib                    => gif library
      lpng                      => png library
      Lua5.1                    => Lua 5.1
      zlib                      => zlib
      AMWatchDll.dll            => dll for AMWatch
      AMWatchDll.lib            => lib for AMWatch
      lua5.1.dll                => dll for lua5.1
      lua5.1.exe                => exe for lua5.1
      lua5.1.lib                => lib for lua5.1
     adc.cpp                    => Analog-Digit Conversion
     AMWatchAbout.ico           => about icon resource
     AMWatchDll.h               => definition for AMWatch Dll
     AMWatchDll.ico             => icon resource for AMWatch Dll
     AMWatchDll.rc              => icon resource script for AMWatch Dll
     AMWatchDll.vcproj          => project file for AMWatch Dll
     AMWatchSmall.ico           => small icon resource for AMWatch Dll
     AMWatchWinDll.cpp          => 
     AMWatchWinDll.h            =>
     audio.cpp                  =>
     bit.cpp                    =>
     bitarray.cpp               =>
     cpu.cpp                    =>
     Disp.cpp                   =>
     Disp.h                     =>
     dllmain.cpp                =>
     dllmain.h                  =>
     gps.cpp                    =>
     i2c.cpp                    =>
     l_uart.cpp                 =>
     LogWriter.cpp              =>
     LogWriter.h                =>
     lpack.cpp                  =>
     luaiconv.cpp               =>
     pio.cpp                    =>
     pio.h                      =>
     pmd.cpp                    =>
     qr_encode.cpp              =>
     ReadMe.txt                 => this file
     resource.h                 =>
     rtos.cpp                   =>
     sim_gpio.cpp               =>
     sim_key.cpp                =>
     sim_key.h                  =>
     sim_tp.cpp                 =>
     sim_tp.h                   =>
     stdafx.cpp                 =>
     stdafx.h                   =>
     targetver.h                =>
     tcpipsock.cpp              =>
     ttsply.cpp                 =>
     Version.h                  =>
     W32_util.cpp               =>
     W32_util.h                 =>
     watchdog.cpp               =>
     Win32LuaShell.cpp          =>
     Win32LuaShell.h            =>
     
