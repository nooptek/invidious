class Invidious::Jobs::NotificationJob < Invidious::Jobs::BaseJob
  private getter connection_channel : ::Channel(NotifierParam)
  @connections = [] of ::Channel(NotificationPayload)

  def initialize(@connection_channel)
  end

  def begin
    case PG_DB.driver
    when PG::Driver
      LOGGER.info("jobs: using DB driven notifications")
      PG.connect_listen(CONFIG.database_url, "notifications") do |event|
        payload = NotificationPayload.from_json(event.payload)
        @connections.each(&.send(payload))
      end
      notify = ->(payload : NotificationPayload) do
        PG_DB.exec("NOTIFY notifications, E'#{payload.to_json}'")
      end
    else
      LOGGER.info("jobs: using internal notifications")
      notify = ->(payload : NotificationPayload) do
        @connections.each(&.send(payload))
      end
    end

    loop do
      action, obj = @connection_channel.receive

      case action
      in NotifierAction::Subscribe
        @connections << obj.as(::Channel(NotificationPayload))
      in NotifierAction::Unsubscribe
        @connections.delete(obj)
      in NotifierAction::Notify
        notify.call(obj.as(NotificationPayload))
      end
    end
  end
end
