defmodule Producer do
  @moduledoc """
  Documentation for `Producer`.
  """

  use GenServer
  alias :jsx, as: JSX
  @routing_key "test_routing_key"
  @exchange "test_exchange"
  @queue "test_queue"

  # APIs
  @spec start_link() :: {:ok, pid()}
  def start_link() do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  @spec stop() :: no_return()
  def stop() do
    GenServer.stop(__MODULE__, :normal)
  end

  @spec publish_msg(%{}) :: no_return()
  def publish_msg(msg) do
    GenServer.cast(__MODULE__, {:publish, JSX.encode(msg)})
  end

  # Callback Functions
  @impl GenServer
  def init(nil) do
    Process.flag(:trap_exit, true)
    send(self(), {:init, @queue, @exchange, @routing_key})
    {:ok, %{}}
  end

  @impl GenServer
  def handle_cast({:publish, msg}, state) do
    opts = get_publish_options()

    AMQP.Basic.publish(
      state.chan,
      state.exchange,
      @routing_key,
      msg,
      opts
    )

    {:noreply, state}
  end

  @impl GenServer
  def handle_info({:init, queue, exchange, routing_key}, _state) do
    {:ok, conn} = AMQP.Connection.open()
    {:ok, chan} = AMQP.Channel.open(conn)

    AMQP.Queue.declare(chan, queue)
    AMQP.Exchange.declare(chan, exchange)
    AMQP.Queue.bind(chan, queue, exchange, routing_key: routing_key)

    # This appoints the current server as
    # The handler for all unrouted messages.
    :ok = AMQP.Basic.return(chan, self())

    # Grants this process the power to handle confirms
    # Messages.
    AMQP.Confirm.register_handler(chan, self())
    # Activates publishing confirmations
    AMQP.Confirm.select(chan)

    {:noreply,
     %{
       conn: conn,
       chan: chan,
       queue: queue,
       exchange: exchange,
       routing_key: routing_key
     }}
  end

  @impl GenServer
  def handle_info({:basic_return, payload, properties}, state) do
    IO.puts("Properties: #{inspect(properties)}")
    IO.puts("Payload: #{inspect(payload)}")
    {:noreply, state}
  end

  def handle_info(info, state) do
    IO.puts("Info: #{inspect(info)}")
    {:noreply, state}
  end

  @impl GenServer
  def terminate(_reason, state) do
    AMQP.Queue.unbind(state.chan, state.queue, state.exchange)
    AMQP.Queue.delete(state.chan, state.queue)

    AMQP.Exchange.delete(state.chan, state.exchange)

    AMQP.Channel.close(state.chan)
    AMQP.Connection.close(state.conn)
  end

  # Internal Functions
  defp get_publish_options() do
    [
      # mandatory triggers a `basic.return` msg
      # In case the message cannot be routed.
      mandatory: true,
      app_id: "elixir push",
      expiry: 60 * 60 * 1000,
      timestamp: timestamp(),
      message_id: UUID.uuid1(),
      content_type: "application/json",
      headers: [{"company", :binary, "HelloTech"}]
    ]
  end

  defp timestamp() do
    DateTime.utc_now() |> DateTime.to_unix()
  end
end
