defmodule Notification.SyncConsumer do
    use GenServer
    use AMQP


    def start_link do
        GenServer.start_link(__MODULE__, [], [])
    end

    @exchange    "sync_consumer_exchange"
    @queue       "sync_consumer_queue"
    @queue_error "#{@queue}_error"

    def init(_opts) do
      rabbitmq_connect
    end

    defp rabbitmq_connect do
			case Connection.open(Application.fetch_env!(:rabbitmq_config, :host)) do
				{:ok, conn} ->
					# Get notifications when the connection goes down
					Process.monitor(conn.pid)
					# Everything else remains the same
					{:ok, chan} = Channel.open(conn)
					Basic.qos(chan, prefetch_count: 10)
					Queue.declare(chan, @queue_error, durable: true)
					Queue.declare(chan, @queue, durable: true,
												arguments: [{"x-dead-letter-exchange", :longstr, ""},
																									{"x-dead-letter-routing-key", :longstr, @queue_error}])
					Exchange.fanout(chan, @exchange, durable: true)
					Queue.bind(chan, @queue, @exchange)
					{:ok, _consumer_tag} = Basic.consume(chan, @queue)
					{:ok, chan}
				{:error, _} ->
					# Reconnection loop
					:timer.sleep(10000)
					rabbitmq_connect
			end
	end

  # Confirmation sent by the broker after registering this process as a consumer
  def handle_info({:basic_consume_ok, %{consumer_tag: consumer_tag}}, chan) do
    {:noreply, chan}
  end

  # Sent by the broker when the consumer is unexpectedly cancelled (such as after a queue deletion)
  def handle_info({:basic_cancel, %{consumer_tag: consumer_tag}}, chan) do
    {:stop, :normal, chan}
  end

  # Confirmation sent by the broker to the consumer process after a Basic.cancel
  def handle_info({:basic_cancel_ok, %{consumer_tag: consumer_tag}}, chan) do
    {:noreply, chan}
  end

	def handle_info({:basic_deliver, payload, %{delivery_tag: tag, redelivered: redelivered}}, chan) do
    spawn fn -> consume(chan, tag, redelivered, payload) end
    {:noreply, chan}
	end
	
	def handle_info({:DOWN, _, :process, _pid, _reason}, _) do
		{:ok, chan} = rabbitmq_connect
		{:noreply, chan}
	end

  defp consume(channel, tag, redelivered, payload) do
    {:ok, data} = Poison.decode(payload)
    {"user_id" => user_id} = data
    room_id = Kernel.inspect(user_id)    
    NotificationWeb.Endpoint.broadcast("notification_room:"<>room_id, "notification:sync", data)
    Basic.ack channel, tag
    IO.inspect payload
    

  rescue
    # Requeue unless it's a redelivered message.
    # This means we will retry consuming a message once in case of exception
    # before we give up and have it moved to the error queue
    #
    # You might also want to catch :exit signal in production code.
    # Make sure you call ack, nack or reject otherwise comsumer will stop
    # receiving messages.
    exception ->
      Basic.reject channel, tag, requeue: not redelivered
      IO.puts "Error converting #{payload} to integer"
  end
    
end