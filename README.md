#帮助蛤仙人

---
##增加关卡

编辑 VineData.plist，可以看到该文件包含了一个字典数组，每个字典包括 **relAnchorPoint** 和 **length**。

对于每个葡萄藤字典，都要取出 `length ` 和 `relAnchorPoint `，用于初始化新的 `VineNode` 对象。`length` 指定了葡萄藤的段数。

---

![](screenshot.png)


