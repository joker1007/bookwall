# frozen_string_literal: true

# ActiveStorage normally schedules blob analysis and purges through
# ActiveJob (AnalyzeJob / PurgeJob), which means those write operations
# land on the primary SQLite database from a different worker thread
# (development) or a different worker process (production), competing
# with the foreground writer for the single SQLite writer lock.
#
# Bookwall is a small single-user service where every blob is cheap to
# analyze and purge, so we run both inline. Any analyze / purge work now
# completes within the same thread (and, when called from the scanner,
# the same enclosing transaction) as the attach / destroy that triggered
# it — eliminating that source of writer-lock contention entirely.
Rails.application.config.to_prepare do
  ActiveStorage::Blob.prepend(Module.new do
    def analyze_later
      analyze
    end

    def purge_later
      purge
    end
  end)
end
