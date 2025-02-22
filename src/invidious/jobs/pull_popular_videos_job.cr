class Invidious::Jobs::PullPopularVideosJob < Invidious::Jobs::BaseJob
  POPULAR_VIDEOS = Atomic.new([] of ChannelVideo)

  def begin
    loop do
      videos = Invidious::Database::ChannelVideos.select_popular_videos
        .sort_by!(&.published)
        .reverse!

      POPULAR_VIDEOS.set(videos)

      sleep 1.minute
      Fiber.yield
    end
  end
end
