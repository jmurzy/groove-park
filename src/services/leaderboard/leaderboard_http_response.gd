## Raw terminal response from one cancellable HTTP request.
class_name LeaderboardHttpResponse
extends RefCounted

var request_result := HTTPRequest.RESULT_CANT_CONNECT
var response_code := 0
var body := PackedByteArray()
var request_error: Error = OK
