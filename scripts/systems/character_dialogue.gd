class_name CharacterDialogue
extends Resource
## 角色台词表（resources/dialogue/*.tres）
## 说明：导出包会把 .tres 转成二进制，PackedStringArray 字段在转换后会丢内容，
## 因此台词统一存成多行文本，运行时按行切分（数据仍在 .tres 里，代码只读取）

@export var char_id: String = ""
@export_multiline var intro_text: String = ""
@export_multiline var boss_enter_text: String = ""
@export_multiline var low_health_text: String = ""
@export_multiline var death_text: String = ""
@export_multiline var victory_text: String = ""
