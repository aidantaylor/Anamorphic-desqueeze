extends RefCounted
class_name DngProcessor


static func create_desqueezed_copy(
	source_path: String,
	exiftool_path: String,
	squeeze_factor: float,
	vertical: bool
) -> Dictionary:

	# Validate input
	if not FileAccess.file_exists(source_path):
		return {"success": false, "error": "Source file not found."}

	if not FileAccess.file_exists(exiftool_path):
		return {"success": false, "error": "ExifTool not found."}

	if source_path.get_extension().to_lower() != "dng":
		return {"success": false, "error": "Input must be a DNG."}

	if squeeze_factor <= 0.0 or is_nan(squeeze_factor) or is_inf(squeeze_factor):
		return {"success": false, "error": "Invalid squeeze factor."}

	# Generate output path
	var output_path = source_path.get_basename() + "_desqueezed.dng"
	
	if FileAccess.file_exists(output_path):
		return {
			"success": false,
			"error": "Output file already exists: " + output_path
	}

	# Copy original DNG
	var copy_error = DirAccess.copy_absolute(source_path, output_path)

	if copy_error != OK:
		return {"success": false, "error": "Could not copy DNG."}

	# Calculate DefaultScale
	var factor = str(squeeze_factor)

	var scale_x = "1" if vertical else factor
	var scale_y = factor if vertical else "1"

	var default_scale = scale_x + " " + scale_y

	# Execute ExifTool
	var arguments = [
		"-overwrite_original",
		"-P",
		"-DefaultScale=" + default_scale,
		output_path
	]

	var output = []
	var exit_code = OS.execute(
		exiftool_path,
		arguments,
		output,
		true
	)

	if exit_code != 0:
		DirAccess.remove_absolute(output_path)

		return {
			"success": false,
			"error": "ExifTool failed: " + "\n".join(output)
		}

	# Verify metadata
	var verify_output = []

	var verify_exit = OS.execute(
		exiftool_path,
		["-s3", "-DefaultScale", output_path],
		verify_output,
		true
	)

	var actual_scale = "\n".join(verify_output).strip_edges()

	if verify_exit != 0 or not _scale_matches(
		actual_scale, scale_x, scale_y
	):
		DirAccess.remove_absolute(output_path)

		return {
			"success": false,
			"error": "DefaultScale verification failed: " + actual_scale
		}

	return {
		"success": true,
		"output_path": output_path,
		"default_scale": default_scale
	}

static func _scale_matches(
	actual: String,
	expected_x: String,
	expected_y: String
) -> bool:

	# Remove leading/trailing whitespace
	var normalized = actual.strip_edges()

	# Replace tabs and newlines with spaces
	normalized = normalized.replace("\t", " ")
	normalized = normalized.replace("\n", " ")
	normalized = normalized.replace("\r", " ")

	# Split into values, ignoring empty entries
	var values = normalized.split(" ", false)

	# We expect exactly two values
	if values.size() != 2:
		return false

	# Validate both values are numeric
	if not values[0].is_valid_float():
		return false

	if not values[1].is_valid_float():
		return false

	# Compare actual and expected values
	return (
		is_equal_approx(float(values[0]), float(expected_x))
		and is_equal_approx(float(values[1]), float(expected_y))
	)
