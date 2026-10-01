## Explicit result returned when immutable game records are constructed.
class_name RecordValidationResult
extends RefCounted

var is_valid: bool
var errors: PackedStringArray
var value: Variant


static func success(next_value: Variant) -> RecordValidationResult:
	var result := RecordValidationResult.new()
	result.is_valid = true
	result.errors = PackedStringArray()
	result.value = next_value
	return result


static func failure(next_errors: PackedStringArray) -> RecordValidationResult:
	var result := RecordValidationResult.new()
	result.is_valid = false
	result.errors = next_errors.duplicate()
	result.value = null
	return result
