defmodule Grpc.Testing.WorkerService.Server do
  use GRPC.Server, service: Grpc.Testing.WorkerService.Service
  alias GRPC.Server

  alias Benchmark.Manager
  alias Benchmark.ServerManager
  alias Benchmark.ClientManager

  require Logger

  def run_server(args_enum, stream) do
    Enum.reduce(args_enum, nil, fn args, server ->
      Logger.debug("Server got args:")
      Logger.debug(inspect(args))

      {server, status} =
        case args.argtype do
          {:setup, config} ->
            cores = Manager.set_cores(config.core_limit)
            server = ServerManager.start_server(config)
            Logger.debug("Started server: #{inspect(server)}")

            {server, stats} = Benchmark.Server.get_stats(server)

            status =
              Grpc.Testing.ServerStatus.new(
                stats: stats,
                port: server.port,
                cores: cores
              )

            {server, status}

          {:mark, mark} ->
            {server, stats} = Benchmark.Server.get_stats(server, mark)
            status = Grpc.Testing.ServerStatus.new(stats: stats)
            {server, status}
        end

      Logger.debug("Server send reply #{inspect(status)}")
      Server.send_reply(stream, status)
      server
    end)
  end

  def run_client(args_enum, stream) do
    Enum.each(args_enum, fn args ->
      Logger.debug("Client got args:")
      Logger.debug(inspect(args))

      status =
        case args.argtype do
          {:setup, client_config} ->
            ClientManager.start_client(client_config)
            Grpc.Testing.ClientStatus.new()

          {:mark, mark} ->
            stats = get_stats(mark.reset)
            Grpc.Testing.ClientStatus.new(stats: stats)
        end

      Logger.debug("Client send reply #{inspect(status)}")
      Server.send_reply(stream, status)
    end)
  end

  def core_count(_, _) do
    Grpc.Testing.CoreResponse.new(cores: Manager.get_cores())
  end

  def quit_worker(_, stream) do
    Logger.debug("Received quit_work")
    Logger.debug(inspect(stream.local[:main_pid]))
    send(stream.local[:main_pid], {:quit, self()})
    Grpc.Testing.Void.new()
  end

  def get_stats(_) do
  end
end
