extends RefCounted
class_name RawConverter


static func convert_to_dng(
	source_path: String,
	converter_path: String
) -> Dictionary:

	# Validate source file
	if not FileAccess.file_exists(source_path):
		return {
			"success": false,
			"error": "Source CR3 file not found."
		}

	# Validate converter executable
	if not FileAccess.file_exists(converter_path):
		return {
			"success": false,
			"error": "Adobe DNG Converter not found."
		}

	# Validate input format
	if source_path.get_extension().to_lower() != "cr3":
		return {
			"success": false,
			"error": "Input must be a CR3 file."
		}

	# Adobe creates the DNG beside the original CR3
	var output_path = source_path.get_base_dir().path_join(
		source_path.get_file().get_basename() + ".dng"
	)

	# Prevent overwriting an existing DNG
	if FileAccess.file_exists(output_path):
		return {
			"success": false,
			"error": "Intermediate DNG already exists: " + output_path
		}

	# Run Adobe DNG Converter
	# This is the command we confirmed works manually.
	var arguments = [
		"-c",
		source_path
	]

	var output: Array = []

	var exit_code = OS.execute(
		converter_path,
		arguments,
		output,
		true
	)

	# Check conversion result
	if exit_code != 0 or not FileAccess.file_exists(output_path):
		return {
			"success": false,
			"error": "Adobe DNG Converter did not create the expected DNG. Exit code: %d\n%s" % [
				exit_code,
				"\n".join(output)
			]
		}

	return {
		"success": true,
		"output_path": output_path
	}
