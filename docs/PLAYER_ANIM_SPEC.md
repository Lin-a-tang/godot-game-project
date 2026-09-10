# 玩家动画接入规范（Hero 换用 Mixamo 绑骨）

## 当前进度（主角2.blend → 可上传状态）
- 三件套（主体/佩饰/环件）已按材质合并：8245v / 15681f / 3 材质槽，外观无损。
- 归一：脚底 z=0、xy 居中、身高 1.72m（游戏胶囊 1.8m 配平 OK）。
- 备份 blend：`assets/source/playermotion/hero_rig_ready.blend`
- 上传用 FBX：`assets/source/playermotion/hero_upload.fbx`（540KB）

## Mixamo 上传步骤（需浏览器登录，你操作）
1. 打开 https://www.mixamo.com ，用 Adobe 账号免费登录。
2. "Characters" → "Upload character" → 选 `hero_upload.fbx`。
3. 自动绑骨器预览角色；确认自动标记（头/肩/腕/胯/膝/脚踝）落在正确位置，Body 参数页 Face 不用调，直接点 "Confirm"。
4. Characters 面板选中你的角色（人物头像出现即可）。

## 动作下载清单（每动作一个 zip，导出选项：Without Skin）
| 我方 clip 名 | Mixamo 搜索意图 | 单段/循环 |
|---|---|---|
| qc_idle | "idle"（MSP Idle 或 Idle 均可） | loop |
| qc_move_fwd | "walking"（Walking/Turn 类，选向前走） | loop |
| qc_atk1_windup / _recover | "sword slash combo"（拆段，若只有整段则下载整段回来我分帧） | 非loop |
| qc_atk_heavy | "heavy attack" 类（单手重劈） | 非loop |
| qc_block | "block"/"guard"（持械防御） | loop |
| qc_roll | "dodge roll" | 非loop |
| qc_hurt | "getting hit"（单发） | 非loop |
| qc_die | "death"（倒地收尾） | 非loop |

下载后统一放：`assets/source/playermotion/mixamo_clips/`
若 Mixamo 只能搜到整段（尤其剑三连击），可先整段下载，`qc_atk1_windup/_active/_recover` 我导入后用曲线分帧。

## Mixamo 动作与 Player 状态机映射（Godot 侧接线表）
Player.gd 状态 → clip：
- IDLE → qc_idle
- MOVING → qc_move_fwd
- ATTACKING(light) → qc_atk{1..3}_{windup/active/recover}（按 combo_index）
- ATTACKING(heavy) / CHARGING → qc_atk_heavy
- BLOCKING → qc_block
- DODGING → qc_roll
- HURT → qc_hurt
- 死亡（无专用态，玩家满血规则下沿用 hurt + 倒地 qc_die）

## 后续管线
Mixamo 绑定后的 FBX（含骨架）与各动作 FBX → Blender 重定向命名 → 动画装进 Godot AnimationLibrary → Player 骨架替换 qingchuan.glb 视觉。
