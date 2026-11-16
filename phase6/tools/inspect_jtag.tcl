load_package insystem_source_probe
foreach cmd {get_insystem_source_probe_instance_info start_insystem_source_probe write_source_data read_probe_data} {puts [help -cmd $cmd]}
