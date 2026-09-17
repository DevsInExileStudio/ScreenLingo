extends SceneTree
## CSV importer shortens regional columns to the base language in output filenames.
## Build explicit resources for the two Chinese variants and Brazilian Portuguese.

const CATALOG := "res://assets/i18n/ui.csv"


func _init() -> void:
	var file := FileAccess.open(CATALOG, FileAccess.READ)
	var header := file.get_csv_line()
	var key_column := header.find("keys")
	for spec in [["pt_br", "pt_BR"], ["zh_tw", "zh_TW"], ["zh_cn", "zh_CN"]]:
		file.seek(0)
		file.get_csv_line()
		var column := header.find(spec[0])
		var translation := Translation.new()
		translation.locale = spec[1]
		var count := 0
		while not file.eof_reached():
			var row := file.get_csv_line()
			if row.size() <= maxi(key_column, column):
				continue
			translation.add_message(row[key_column], row[column])
			count += 1
		ResourceSaver.save(translation, "res://assets/i18n/ui_%s.translation" % spec[0])
		print("%s: %d messages" % [spec[1], count])
	quit()
