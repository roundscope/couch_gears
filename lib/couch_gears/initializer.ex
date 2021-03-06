defmodule CouchGears.Initializer do
  @moduledoc """
  This module is responsible for starting a CouchGears framework
  inside a particular Couch DB note as a independent daemon.

  A `CouchGears.Initializer` starts its own base supervisor. Each application (actually also a supervisor)
  becomes a part of base supervisor.

  A framework configuration designed as easy as possible. It follows
  a Couch DB extension approach.

  ## Configurtion

  1. Specify a CouchGears `ebin` path in `couchdb`.

    COUCH_GEARS_PA_OPTIONS="-pa /var/www/couch_gears/current/ebin"
    ERL_START_OPTIONS="$ERL_OS_MON_OPTIONS -sasl errlog_type error +K true +A 4 $COUCH_GEARS_PA_OPTIONS"

  2. Specify the `daemons` in `local.ini`

    [daemons]
    couch_gears={'Elixir-CouchGears-Initializer', start_link, [[{env, <<"prod">>}]]}

  Finally, notice that after initialization a CouchGears sets both `httpd_db_handlers` and `httpd_global_handlers`
  option which handles incoming `/db/_gears` or `/_gears` requests.

  Is an equivalent to:

    [httpd_global_handlers]
    _gears = {'Elixir-CouchGears-Mochiweb-Handler', handle_global_gears_req}

    [httpd_db_handlers]
    _gears = {'Elixir-CouchGears-Mochiweb-Handler', handle_db_gears_req}

  """

  use Supervisor.Behaviour


  @root_path Path.expand      "../../..", __FILE__
  @httpd_db_handlers          "Elixir-CouchGears-Mochiweb-Handler"
  @gears_request_prefix       "_gears"

  @doc """
  Starts the supervisor
  """
  def start_link(opts) do
    :supervisor.start_link({ :local, __MODULE__ }, __MODULE__, opts)
  end

  @doc """
  Restarts the base supervisor through a `couch_secondary_services` functions such as `terminate_child` and `restart_child`
  """
  def restart do
    :supervisor.terminate_child(:couch_secondary_services, :couch_gears)
    :supervisor.restart_child(:couch_secondary_services, :couch_gears)
  end

  @doc false
  def init(opts) do
    configure_gears(opts)

    # Adds a Elixir deps to the code path
    :erlang.bitstring_to_list(@root_path <> "/deps/elixir/lib/elixir/ebin") |> :code.add_pathz

    Code.append_path(@root_path <> "/deps/elixir/lib/mix/ebin")
    Code.append_path(@root_path <> "/deps/elixir/lib/iex/ebin")

    { Mix.start, Code.load_file(Path.join([@root_path, "mix.exs"])), Mix.loadpaths }

    # Setups gears environment
    setup_httpd_handlers

    # Starts applications
    apps = Enum.map initialize_gears, fn(opts) ->
      supervisor(__MODULE__, [opts], [id: opts[:app_name], function: :start_app, restart: :permanent])
    end

    spec = supervise(apps, [strategy: :one_for_one])

    CouchGears.Logger.info("CouchGears has started")

    spec
  end

  @doc """
  Starts a particular application
  """
  def start_app(opts // []) do
    File.cd(opts[:app_path])

    Code.load_file Path.join([opts[:app_path], "config", "application.ex"])
    app = Module.concat([Mix.Utils.camelize(opts[:app_name]) <> "Application"])

    CouchGears.gears(CouchGears.gears ++ [app])

    app.start_link
  end

  @doc """
  Restarts a particular application through a `supervisor` functions such as `terminate_child` and `restart_child`
  """
  def restart_app(name) do
    :supervisor.terminate_child(__MODULE__, name)
    :supervisor.restart_child(__MODULE__, name)
  end


  defp setup_httpd_handlers do
    :couch_config.set(
      "httpd_global_handlers",
      "#{@gears_request_prefix}",
      binary_to_list("{'#{@httpd_db_handlers}', handle_global_gears_req}"),
      false
    )
    :couch_config.set(
      "httpd_db_handlers",
      "#{@gears_request_prefix}",
      binary_to_list("{'#{@httpd_db_handlers}', handle_db_gears_req}"),
      false
    )
  end

  defp initialize_gears do
    Enum.map Path.wildcard(CouchGears.root_path <> "/apps/*"), fn(app_path) ->
      Code.load_file(Path.join([app_path, "mix.exs"]))

      Mix.Tasks.Deps.Loadpaths.run([])
      Mix.Tasks.Loadpaths.run([])

      [app_name: List.last(Path.split(app_path)), app_path: app_path]
    end
  end

  defp configure_gears(opts) do
    CouchGears.gears([])
    CouchGears.env(:couch_util.get_value(:env, opts, "dev"))
    CouchGears.root_path(@root_path)
  end
end