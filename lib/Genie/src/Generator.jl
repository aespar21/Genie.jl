module Generator

using Genie, Logger, FileTemplates, Inflector, Configuration, Migration

function new_model(cmd_args::Dict{String,Any}, config::Settings) :: Void
  resource_name = ucfirst(cmd_args["model:new"])
  if Inflector.is_singular(resource_name)
    resource_name = Inflector.to_plural(resource_name) |> Base.get
  end

  resource_path = setup_resource_path(resource_name)
  write_resource_file(resource_path, Genie.GENIE_MODEL_FILE_NAME, resource_name) &&
    Logger.log("New model created at $(joinpath(resource_path, Genie.GENIE_MODEL_FILE_NAME))")

  nothing
end

function new_resource(cmd_args::Dict{AbstractString,Any}, config::Settings) :: Void
  sf = Inflector.to_singular(cmd_args["resource:new"])
  cmd_args["model:new"] = (isnull(sf) ? cmd_args["resource:new"] : Base.get(sf)) |> ucfirst
  new_model(cmd_args, config)

  resource_name = ucfirst(cmd_args["resource:new"])
  if Inflector.is_singular(resource_name)
    resource_name = Inflector.to_plural(resource_name) |> Base.get
  end

  cmd_args["migration:new"] = "create_table_" * lowercase(resource_name)
  Migration.new(cmd_args, config)

  resource_path = setup_resource_path(resource_name)
  for resource_file in [Genie.GENIE_CONTROLLER_FILE_NAME, Genie.GENIE_AUTHORIZATOR_FILE_NAME, Genie.GENIE_VALIDATOR_FILE_NAME]
    write_resource_file(resource_path, resource_file, resource_name) &&
      Logger.log("New $resource_file created at $(joinpath(resource_path, resource_file))")
  end

  views_path = joinpath(resource_path, "views")
  ! isdir(views_path) && mkpath(views_path)

  ! isdir(Genie.TEST_PATH_UNIT) && mkpath(Genie.TEST_PATH_UNIT)
  test_file = resource_name * Genie.TEST_FILE_IDENTIFIER |> lowercase
  write_resource_file(Genie.TEST_PATH_UNIT, test_file, resource_name) &&
    Logger.log("New $test_file created at $(joinpath(Genie.TEST_PATH_UNIT, test_file))")

  nothing
end

function setup_resource_path(resource_name::String) :: String
  resources_dir = Genie.RESOURCE_PATH
  resource_path = joinpath(resources_dir, lowercase(resource_name))

  if ! isdir(resource_path)
    mkpath(resource_path)
  end

  resource_path
end

function write_resource_file(resource_path::String, file_name::String, resource_name::String) :: Void
  if isfile(joinpath(resource_path, file_name))
    Logger.log("File already exists, $(joinpath(resource_path, file_name)) - skipping", :err)
    return nothing
  end

  f = open(joinpath(resource_path, file_name), "w")

  if file_name == Genie.GENIE_MODEL_FILE_NAME
    write(f, FileTemplates.new_model( Base.get(Inflector.to_singular( Inflector.from_underscores(resource_name) )), resource_name ))
  elseif file_name == Genie.GENIE_CONTROLLER_FILE_NAME
    write(f, FileTemplates.new_controller( Base.get(Inflector.to_plural( Inflector.from_underscores(resource_name) )) ))
  elseif file_name == Genie.GENIE_VALIDATOR_FILE_NAME
    write(f, FileTemplates.new_validator( Base.get(Inflector.to_singular(resource_name) |> Inflector.from_underscores) ))
  elseif file_name == Genie.GENIE_AUTHORIZATOR_FILE_NAME
    write(f, FileTemplates.new_authorizer())
  elseif endswith(file_name, Genie.TEST_FILE_IDENTIFIER)
    write(f, FileTemplates.new_test(Base.get(Inflector.to_plural( Inflector.from_underscores(resource_name) )), Base.get(Inflector.to_singular( Inflector.from_underscores(resource_name) )) ))
  else
    error("Not supported, $file_name")
  end

  close(f)

  nothing
end

end
