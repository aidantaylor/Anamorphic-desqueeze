extends Control

#================
# UI references
#================

@onready var squeeze_input: LineEdit = $Layout/SettingPanel/SettingsRow/SqueezeSetting/SqueezeInput
@onready var axis_input: OptionButton = $Layout/SettingPanel/SettingsRow/AxisSetting/AxisInput

@onready var item_count: Label = $Layout/QueuedPanel/QueueHeader/ItemCount
@onready var add_files: Button = $Layout/QueuedPanel/QueueHeader/AddFiles
@onready var add_folder: Button = $Layout/QueuedPanel/QueueHeader/AddFolder
@onready var clear_button: Button = $Layout/QueuedPanel/QueueHeader/ClearQueue

@onready var item_list: ItemList = $Layout/QueuedPanel/QueueScroll/QueueList/ItemList
@onready var queue_count: Label = $Layout/QueuedPanel/QueueScroll/QueueList/QueueCount

@onready var start: Button = $Layout/BottomBar/Start
@onready var cancel: Button = $Layout/BottomBar/Cancel

@onready var about_info: LinkButton = $Layout/Footer/AboutInfo
@onready var about_dialog: AcceptDialog = $Layout/AboutInfo
@onready var github_link: LinkButton = $Layout/AboutInfo/AboutContent/GithubLink

@onready var open_files: FileDialog = $Layout/OpenFiles
@onready var open_folder: FileDialog = $Layout/OpenFolder

@onready var progress_bar: ProgressBar = $Layout/ProgressBar
@onready var status_indicator: Label = $Layout/StatusIndicator
@onready var status_label: Label = $Layout/BottomBar/Status

#================
#variables
#================

var queue: Array[Dictionary] = []
var is_processing: bool = false
var cancel_request: bool = false
var exiftools_path: String
var converter_path: String

#================
#start
#================

func _ready() -> void:
	
	# Configure file dialog
	open_folder.visible = false
	open_files.visible = false
	open_files.file_mode = FileDialog.FILE_MODE_OPEN_FILES
	open_files.access = FileDialog.ACCESS_FILESYSTEM
	open_files.filters = PackedStringArray([
		"*.dng ; DNG Images",
		"*.cr3 ; Canon RAW Images"
	])

# Configure axis selector
	axis_input.clear()
	axis_input.add_item("Horizontal", 0)
	axis_input.add_item("Vertical", 1)

#exiftools path
	exiftools_path = ProjectSettings.globalize_path(
		"res://tools/exiftool-windows/exiftool.exe"
	)
	
	# Adobe DNG Converter path
	converter_path = "C:/Program Files/Adobe/Adobe DNG Converter/Adobe DNG Converter.exe"

#button connections
	add_files.pressed.connect(on_add_files_pressed)
	#add_folder.pressed.connect(on_add_folder_pressed)
	clear_button.pressed.connect(on_clear_pressed)
	start.pressed.connect(on_start_pressed)
	cancel.pressed.connect(on_cancel_pressed)
	about_info.pressed.connect(on_about_pressed)
	open_files.files_selected.connect(on_files_selected)
	#open_folder.files_selected.connect(on_folder_selected)
	github_link.pressed.connect(_on_github_link_pressed)

#Init
	progress_bar.value = 0
	cancel.disabled = true
	about_dialog.hide()
	open_files.hide()
	open_folder.hide()
	
	_update_queue_ui()

#==========
#adding files
#==========

func on_add_files_pressed() -> void:
	if is_processing:
		return
	open_files.visible = true
	open_files.popup_centered_ratio(0.75)

func on_files_selected(paths: PackedStringArray) -> void:
	for path in paths:
		if _is_file_in_queue(path):
			continue
		queue.append({
			"path": path,
			"status": "Queued"
		})
	_refresh_file_list()
	_update_queue_ui()

	status_label.text = "%d files in queue." % queue.size()
	
func _is_file_in_queue(path: String) -> bool:

	for item in queue:
		if item["path"].to_lower() == path.to_lower():
			return true

	return false

#==========
#adding folder
#==========

#func on_add_folder_pressed() -> void:
	#return
#func on_folder_selected(paths: PackedStringArray) -> void:
	#return

#============
#Clear queue
#============

func on_clear_pressed() -> void:

	if is_processing:
		return

	queue.clear()

	_refresh_file_list()
	_update_queue_ui()

	progress_bar.value = 0
	status_label.text = "Queue cleared."

#============
#Process
#============

func _run_processor(
	path: String,
	factor: float,
	vertical: bool,
	tool_path: String
) -> Dictionary:

	return DngProcessor.create_desqueezed_copy(
		path,
		tool_path,
		factor,
		vertical
	)

#============
#Start Processing
#============

func on_start_pressed() -> void:

	if is_processing:
		return
	
	if queue.is_empty():
		status_label.text = "Add some DNG files first."
		return
		
	if not FileAccess.file_exists(exiftools_path):
		status_label.text = "ExifTool executable not found."
		return
		
	if not squeeze_input.text.is_valid_float():
		status_label.text = "Enter a valid squeeze factor."
		return
		
	var factor := squeeze_input.text.to_float()
	if factor <= 0.0 or is_nan(factor) or is_inf(factor):
		status_label.text = "Squeeze factor must be greater than zero."
		return
	
	var vertical := axis_input.get_selected_id() == 1
	await _process_queue(factor, vertical)

#============
#Conversion
#============

func _process_single_file(
	source_path: String,
	factor: float,
	vertical: bool
) -> Dictionary:

	var extension = source_path.get_extension().to_lower()

	# DNG files can be processed directly
	if extension == "dng":
		return DngProcessor.create_desqueezed_copy(
			source_path,
			exiftools_path,
			factor,
			vertical
		)

	# CR3 files need conversion first
	if extension == "cr3":

		# Final output should be next to the original CR3
		var final_output_path = (
			source_path.get_basename() + "_desqueezed.dng"
		)

		if FileAccess.file_exists(final_output_path):
			return {
				"success": false,
				"error": "Output file already exists: " + final_output_path
			}

		# Convert CR3 to DNG
		var conversion = RawConverter.convert_to_dng(
			source_path,
			converter_path
		)

		if not conversion.get("success", false):
			return conversion

		var converted_path: String = conversion["output_path"]

		# Apply desqueeze metadata to converted DNG
		var processing = DngProcessor.create_desqueezed_copy(
			converted_path,
			exiftools_path,
			factor,
			vertical
		)

		# Remove intermediate DNG
		if FileAccess.file_exists(converted_path):
			DirAccess.remove_absolute(converted_path)

		return processing

	return {
		"success": false,
		"error": "Unsupported file format: " + extension
	}

#============
#Process queue
#============	

func _process_queue(factor: float, vertical: bool) -> void:

	is_processing = true
	cancel_request = false
	cancel.disabled = false

	var total := queue.size()
	var completed := 0
	var failed := 0

	progress_bar.max_value = total
	progress_bar.value = 0
	status_label.text = "Starting batch processing..."

	_update_queue_ui()

	for index in range(total):

		# Check whether cancellation was requested
		if cancel_request:
			break

		var path: String = queue[index]["path"]

		queue[index]["status"] = "Processing"
		_refresh_file_list()

		status_label.text = "Processing %d of %d: %s" % [
			index + 1,
			total,
			path.get_file()
		]

		# Create a worker thread for this file
		var worker := Thread.new()

		var task := _process_single_file.bind(
	path,
	factor,
	vertical
)

		var error := worker.start(task)

		# Handle thread startup failure
		if error != OK:
			queue[index]["status"] = "Failed"
			failed += 1

			push_error("Could not start processing thread: " + path)

			progress_bar.value = index + 1
			_refresh_file_list()
			continue

		# Wait without blocking Godot's main thread
		while worker.is_alive():
			await get_tree().process_frame

		# Retrieve the result after the worker finishes
		var result: Dictionary = worker.wait_to_finish()

		if result.get("success", false):
			queue[index]["status"] = "Completed"
			completed += 1

			print("Created: ", result["output_path"])

		else:
			queue[index]["status"] = "Failed"
			failed += 1

			push_error(
				"%s: %s" % [
					path.get_file(),
					result.get("error", "Unknown error")
				]
			)

		progress_bar.value = index + 1

		_refresh_file_list()
		await get_tree().process_frame

	# Mark remaining files if cancelled
	if cancel_request:
		for index in range(total):
			if queue[index]["status"] == "Queued":
				queue[index]["status"] = "Cancelled"

	# Finish processing
	is_processing = false
	cancel.disabled = true

	_refresh_file_list()
	_update_queue_ui()

	if cancel_request:
		status_label.text = "Processing cancelled. %d completed, %d failed." % [
			completed,
			failed
		]
	else:
		status_label.text = "Finished! %d completed, %d failed." % [
			completed,
			failed
		]

#============
#Cancel Processing
#============

func on_cancel_pressed() -> void:
	if not is_processing:
		return
		
	cancel_request = true
	cancel.disabled = true

	status_label.text = "Cancelling after current file..."

#============
#Refresh file list
#============

func _refresh_file_list() -> void:
	item_list.clear()
	for item in queue:
		var filename: String = item["path"].get_file()
		var status: String = item["status"]
		var display_text := "%s    [%s]" % [
			filename,
			status
		]
		item_list.add_item(display_text)

		# Keep the original path attached to each item
		item_list.set_item_metadata(
			item_list.item_count - 1,
			item["path"]
		)

#============
#Update Queue UI
#============

func _update_queue_ui() -> void:

	queue_count.text = "%d files" % queue.size()

	var has_files := not queue.is_empty()

	start.disabled = not has_files
	clear_button.disabled = not has_files

	if is_processing:
		start.disabled = true
		clear_button.disabled = true

#============
#About
#============

func on_about_pressed() -> void:
	about_dialog.popup_centered()

func _on_github_link_pressed() -> void:
	OS.shell_open(github_link.uri)
