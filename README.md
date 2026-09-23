# 港行库存

在 iPhone 上查看香港 Apple Store 六家门店的 **iPhone 18 Pro Max** 到店取货库存。查到有货就响一声。

这是给没有电脑、手机停在 **iOS 17.0 巨魔（TrollStore）** 的人用的。源码推到 GitHub 后，由 **macOS 26** 托管 runner 编译出未签名 IPA，再用巨魔装回手机。

和 Apple 没有关系。只查公开的到店取货页面，不下单、不代拍。查询间隔最短 1 分钟，一次最多 6 个型号。

## 装到手机

1. 打开这个仓库的 [Releases](https://github.com/zwthys-cyber/hk-iphone-stock/releases/latest)。
2. 下载 `HKStock.ipa`。如果下下来是压缩包，在「文件」App 里解压。
3. 点 IPA → 分享 → **TrollStore** → 安装。
4. 打开「港行库存」，允许通知。
5. 首页直接看六家门店。右上角「型号」改容量、颜色和间隔，左上角「记录」看到货变化。默认是 **256GB 勃艮第红**。
6. 点「开始盯货」，插上电，关掉低电量模式。盯货时屏幕保持常亮。锁屏或离开 App 后，查询会停。

有货时点「打开香港购买页」，自己在官网下单。

## 型号

零件号来自 Apple 香港购买页，以 `ZA/A` 结尾。页面上的目录是 iPhone 18 Pro Max 四个容量、四种颜色。其他港版零件号可以在 App 里粘贴加入。
