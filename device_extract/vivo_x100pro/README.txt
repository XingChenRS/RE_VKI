Vivo X100 Pro (MT6989 / V2324HA) 实机提取文件

本目录存放从 Vivo X100 Pro 实机提取的内核相关数据，供 build_with_device_extract.sh 使用。

必需文件（构建脚本会优先在此目录查找）：
  02_kernel_config/running_kernel.config  实机内核配置
  04_device_tree/fdt.dtb                  实机设备树二进制

其他子目录（01_system_info、03_modules、05_security 等）为提取时的附加信息，便于对照与排查。

构建说明见仓库根目录 README.md 及 docs/ 下的文档。本仓库仅对官方 kernel 做补全，编译产物刷入后几乎无法正常启动，内容仅供参考。
