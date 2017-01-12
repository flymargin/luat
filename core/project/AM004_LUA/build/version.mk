# ------------------------------------------------------------------------ #
#                             AirM2M Ltd.                                  # 
#                                                                          #
# Name: version.mk                                                         #
#                                                                          #
# Author: liweiqiang                                                            #
# Verison: V0.1                                                            #
# Date: 2013.3.4                                                         #
#                                                                          #
# File Description:                                                        #
#                                                                          #
#  版本定义文件                                                            #
# ------------------------------------------------------------------------ #

# 规范：SW_21_10 软件版本命名规范

### 需要设置的内容 ###
# 模块/手机项目号
MODULE_TYPE=A6390

# 客户同一项目不同硬件版本或同一项目不同应用
CUST_HW_TYPE=H

SVN_REVISION=0001
# 软件版本号
ifeq "${SVN_REVISION}" ""
${error MUST define SVN_REVISION}
else
SW_SN=${SVN_REVISION}
endif

# 模块/手机主板号
MODULE_HW_TYPE=13

# 平台软件版本号
PLATFORM_VER=CT8851BL

# 客户产品项目号名
CUST_PROJ_NAME=AM004_LUA

# ------------------------------------------------------------------------ #
# 版本号定义
# ------------------------------------------------------------------------ #
# 内部版本号
IN_VER=SW_$(MODULE_TYPE)_$(CUST_HW_TYPE)_V$(SW_SN)_M$(MODULE_HW_TYPE)_$(PLATFORM_VER)_$(CUST_PROJ_NAME)

# 外部版本号（默认定义）
EX_VER=SW_V$(SW_SN)_$(CUST_PROJ_NAME)

# ------------------------------------------------------------------------ #
# 版本宏
# ------------------------------------------------------------------------ #
LOCAL_EXPORT_FLAG += \
   IN_VER=\"$(IN_VER)\" \
   EX_VER=\"$(EX_VER)\" \
   
ifeq "${AM_VER_ECHO_SUPPORT}" "TRUE"
ECHO_EX_VER:
	@echo $(EX_VER)
endif
