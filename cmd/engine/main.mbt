///|
/// One compiled entry point is shared by CLI and browser.
#export_name("run_json")
pub fn run_json(request : String) -> String {
  @config.run_json(request)
}

///|
#export_name("result_json")
pub fn result_json(response : String) -> String {
  @config.result_json(response)
}

///|
#export_name("result_field_json")
pub fn result_field_json(response : String, field : String) -> String {
  @config.result_field_json(response, field)
}

///|
#export_name("result_path_json")
pub fn result_path_json(response : String, path : String) -> String {
  @config.result_path_json(response, path)
}
