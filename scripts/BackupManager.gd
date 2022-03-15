extends Node


signal status_message
signal backup_creation_started
signal backup_creation_finished
signal backup_restoration_started
signal backup_restoration_finished
signal backup_deletion_started
signal backup_deletion_finished

onready var _settings := $"/root/SettingsManager"
onready var _fshelper := $"../FSHelper"
onready var _path := $"../PathHelper"

var available = null setget , _get_available


func backup_current(backup_name: String) -> void:
	# Create a backup of the save dir for the current game.

	emit_signal("status_message", tr("msg_backing_up_saves") % backup_name)
	emit_signal("backup_creation_started")

	var dest_dir = _path.save_backups.plus_file(backup_name)
	var d = Directory.new()
	
	if not d.dir_exists(dest_dir):
		d.make_dir(dest_dir)
		for world in _fshelper.list_dir(_path.savegames):
			_fshelper.copy_dir(_path.savegames.plus_file(world), dest_dir)
			yield(_fshelper, "copy_dir_done")
		
		emit_signal("status_message", tr("msg_backup_created"))
	else:
		emit_signal("status_message", tr("msg_backup_name_taken") % backup_name, Enums.MSG_ERROR)

	emit_signal("backup_creation_finished")


func get_save_summary(path: String) -> Dictionary:
	# Get information about a game save directory (any directory containing one or more game worlds)
	
	if not Directory.new().dir_exists(path):
		return {}
	
	var summary = {
		"name": path.get_file(),
		"path": path,
		"worlds": [],
	}
	
	for world in _fshelper.list_dir(path):
		summary["worlds"].append(world)
	
	return summary


func _get_available() -> Array:
	
	if not available:
		refresh_available()
	
	return available


func refresh_available():

	available = []
	
	if not Directory.new().dir_exists(_path.save_backups):
		return
	
	for backup in _fshelper.list_dir(_path.save_backups):
		var path = _path.save_backups.plus_file(backup)
		available.append(get_save_summary(path))


func restore(backup_index: int) -> void:
	# Replace the save dir in the current game with the named backup
	
	var backup_name: String = available[backup_index]["name"]
	emit_signal("status_message", tr("msg_restoring_backup") % backup_name)
	
	var source_dir = available[backup_index]["path"]
	var dest_dir = _path.savegames
	
	emit_signal("backup_restoration_started")

	if Directory.new().dir_exists(source_dir):
		if Directory.new().dir_exists(dest_dir):
			_fshelper.rm_dir(dest_dir)
			yield(_fshelper, "rm_dir_done")
		
		Directory.new().make_dir(dest_dir)
		for world in _fshelper.list_dir(source_dir):
			_fshelper.copy_dir(source_dir.plus_file(world), dest_dir)
			yield(_fshelper, "copy_dir_done")
		
		emit_signal("status_message", tr("msg_backup_restored"))
	else:
		emit_signal("status_message", tr("msg_backup_not_found") % backup_name, Enums.MSG_ERROR)
	
	emit_signal("backup_restoration_finished")


func delete(backup_name: String) -> void:
	# Delete a backup.
	
	var target_dir = _path.save_backups.plus_file(backup_name)
	emit_signal("backup_deletion_started")

	if Directory.new().dir_exists(target_dir):
		emit_signal("status_message", tr("msg_deleting_backup") % backup_name)
	
		_fshelper.rm_dir(target_dir)
		yield(_fshelper, "rm_dir_done")
		emit_signal("status_message", tr("msg_backup_deleted"))

	emit_signal("backup_deletion_finished")
