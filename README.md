#GTA数据收集平台V0.0
---
[image1]: ./OpenIVConfig1.jpg
[image2]: ./OpenIVConfig2.jpg
[image3]: ./RD1.jpg
[image4]: ./RD2.jpg
[image5]: ./RD3.jpg
[image6]: ./RD4.jpg
[image7]: ./RD5.jpg

##1. 软件安装

GTA, 从Steam获取。安装后还需要安装social club
在安装大量补丁之后不要进入多人模式，否则可能被封号！

[RenderDoc](https://renderdoc.org/), 
用于帧采集, 直接安装即可
公版可能无法满足开发需求，在play for data中，使用了一个修改版本的rendendoc来配合他们的脚本

[Script Hook V](http://www.dev-c.com/gtav/scripthookv/), 
GTA脚本编辑库，实现摄像头参数调节、位置安放和多个固定视角的切换等功能. 要实现脚本编辑需要下载[Script Hook V SDK](http://www.dev-c.com/files/ScriptHookV_SDK_1.0.617.1a.zip)，将bin文件夹下的三个文件扔到游戏目录中即可

安装Script Hook V后进入游戏按F4，左上会出现一个绿色的作弊器，这个作弊器代码可以在SDK中找到。

[OpenIV](http://openiv.com/)
GTA文件存储在很多很多.rpf中，OpenIV可以访问并修改存在.rpf中的文件，包括模型、贴图以及游戏数据都可以在这里访问、导出和修改安装后，选择GTAV Windows

![image1]

然后定位到GTA的安装位置，Steam默认是C:\Program Files(x86)\Steam\steamapps\common\Grand Theft Auto V\
![image2]

然后就可以看到封装到.rpf中的文件了，如果要修改，需要进入Edit mode

##2. 帧采集

首先打开RenderDoc,进入capture executable页面，路径写steam.exe的路径，Working Directory会自动生成。然后勾选下边的Hook Into，这样软件就可以监测由steam launch的一切进程了
![image3]
然后点击右下角的launch，进入steam，打开GTA5，当屏幕左上方出现一行小字，说明可以开始捕获帧了。
进入游戏后，选择故事模式，可以操作Franklin后，按F12捕获帧，捕获后可以切出游戏在renderdoc中查看。
在Steam选项卡中，双击GTAVlauncher，GTAVlauncher是Steam的一个子进程，GTA5.exe又是GTAVlauncher的子进程，一层层进入就可以找到GTA5.exe
![image4]
![image5]
双击点开GTA5进程后可以看到刚刚保存的帧文件
![image6]
点击右键可以将其保存，双击载入后，可以在texture viewer选项卡中看到帧的细节
![image7]

##3. 参考代码库

1:[playing for data](https://download.visinf.tu-darmstadt.de/data/from_games/index.html) 这是之前那篇paper的主页，标记过程，[源代码在这里](https://bitbucket.org/visinf/projects-2016-playing-for-data)

2:[RD作者写的在fram中提取图片的script，使用Renderdoc python shell](https://gist.github.com/baldurk/53aeecbc94150438477a09e9f49d9a41)

##4. 工程详细结构

要获得一帧可用的数据，首先需要用script hook v编写一个可自由调节第一人称camera视角的脚本，然后根据车辆实装的摄像头位置和焦距，调节GTA中的视角大小，GTA中的视角大小需要根据游戏中的物体估算。
下一步是进入游戏截取帧，Renderdoc将帧储存，然后调用帧处理模块将截取的帧做预处理，生成截图、深度图、少量划分过的stencil图和记录渲染过程的txt文件，随后调用play for data中的matlab脚本实现人工标记并输出

##5. 开发流程规划

1:编译playing for data修改版本的Renderdoc，测试playing for data代码
1:熟悉script hook V sdk并编写camera调节脚本，做到按键切换左、中、右三个视角
1:确定主摄像头安装位置、焦距，在GTA中寻找参照物确定GTA视角大小和未来实装摄像头视角相同
2:进行数据抓取工作，储存帧文件
2:设计要标记的内容，比如可行域、障碍物，然后展开标记工作
2:设计标记后的处理流程，比如根据深度图计算标记出的障碍物到镜头距离

