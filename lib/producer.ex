defmodule Producer do
  @moduledoc """
  Documentation for `Producer`.
  """

  use GenServer
  @routing_key "test_routing_key"
  @exchange "test_exchange"
  @queue "test_queue"

  @content_type "application/json"
  @app_id "test_elixir"
  @one_hour 60*60*1000

  @spec start_link() :: {:ok, pid()}
  def start_link() do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  @spec publish_msg(%{}) :: no_return()
  def publish_msg(msg) do
    publish_msg(@routing_key, msg)
  end

  @spec publish_msg(binary(), %{}) :: no_return()
  def publish_msg(routing_key, msg) do
    {:ok, encoded_msg} = JSON.encode(msg)
    GenServer.cast(__MODULE__, {:publish, routing_key, encoded_msg})
  end

  @impl GenServer
  def init(nil) do
    Process.flag(:trap_exit, true)
    send(self(), :init)
    {:ok, %{}}
  end

  @impl GenServer
  def handle_cast({:publish, routing_key, msg}, %{ conn: conn, chan: chan }) do

    options = get_publish_options()
    AMQP.Basic.publish(chan, @exchange, routing_key, msg, options)
    {:noreply, %{ conn: conn, chan: chan }}
  end

  @impl GenServer
  def handle_info(:init, _state) do
    {:ok, conn} = AMQP.Connection.open()
    {:ok, chan} = AMQP.Channel.open(conn)

    # This appoints the current server as
    # The handler for all unrouted messages.
    :ok = AMQP.Basic.return(chan, self())

    # Allows this server to handle all
    # `Confirm.SelectOk` messages
    :ok = AMQP.Confirm.select(chan)
    :ok = AMQP.Confirm.register_handler(chan, self())

    AMQP.Queue.declare(chan, @queue)
    AMQP.Exchange.declare(chan, @exchange)
    AMQP.Queue.bind(chan, @queue, @exchange, routing_key: @routing_key)

    {:noreply, %{ conn: conn, chan: chan }}
  end

  def handle_info({:basic_return, payload, _property}, state) do
    {:ok, payload} = JSON.decode(payload)
    IO.puts("Payload: #{inspect(payload)}")
    {:noreply, state}
  end

  def handle_info(info, state) do
    IO.puts("Info: #{inspect(info)}")
    {:noreply, state}
  end

  defp get_publish_options() do
    [
      headers: [{"company", :binary, "Eagle_Tech"}],
      timestamp: get_timestamp(),
      content_type: @content_type,
      expiration: @one_hour,
      persistant: false,
      mandatory: true,
      app_id: @app_id
    ]
  end

  defp get_timestamp() do
    DateTime.utc_now() |> DateTime.to_unix()
  end

end
