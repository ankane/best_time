class BestTime
  attr_reader :buckets, :best_time

  TIERS = {
    week: {
      range: 0...168,
      bucket: lambda{|time| (time.wday*1440 + time.hour*60 + time.min)/60.0 },
      format: lambda{|key| Time.new(2012, 1, (key / 24) + 1, key % 24).strftime("%a %l %P").sub("  ", " ") }
    },
    day: {
      range: 0...96,
      bucket: lambda{|time| (time.hour*60 + time.min)/15.0 },
      format: lambda{|key| Time.new(2012, 1, 1, (key * 15) / 60, (key * 15) % 60).strftime("%l:%M %P").strip }
    }
  }

  def initialize(conversions, tier = :hour)
    @tier = TIERS[tier.to_sym]

    @buckets = {}
    range = @tier[:range]
    range.each do |hour|
      @buckets[hour] = 0
    end

    size = range.max + 1
    std = size / 84

    # See how many standard deviations until
    # we don't care to add the value.
    p = 1
    std_range = 0
    while p > 1e-5
      std_range += 1
      p = normal_pdf(0, std_range, std)
    end

    conversions.each do |conversion|
      time, weight = conversion.is_a?(Hash) ? [conversion[:time], conversion[:value]] : [conversion, 1]

      mean = @tier[:bucket].call(time)
      rmin = (mean - std_range).floor
      rmax = (mean + std_range).ceil
      (rmin..rmax).each do |x|
        @buckets[x % size] += weight * normal_pdf(x, mean, std)
      end
    end

    # Normalize and find best bucket.
    max = @buckets.values.max
    best_bucket = 0
    @buckets.each do |k,v|
      @buckets[k] = v / max
      best_bucket = k if v == max
    end
    @best_time = @tier[:format].call(best_bucket)
  end

  def graph
    buckets = self.buckets
    buckets[buckets.keys.count] = buckets[0]
    rows = buckets.to_a.map{|v| format = @tier[:format].call(v[0]); [format[0..3], v[1], "%s : %.2f" % [format, v[1]]] }
    str = File.read("chart.html").gsub("{{rows}}", rows.inspect)
    filename = "/tmp/chart.html"
    File.open(filename, "w"){|f| f.write(str) }
    system("open '#{filename}'")
  end

  protected

  SQRT2PI = Math.sqrt(2*Math::PI)

  def normal_pdf(x, mean = 0, std = 1)
    Math.exp(-((x - mean)**2/(2.0*(std**2))))/(SQRT2PI*std)
  end

end

now = Time.now + 7*86400 # - 86400*3 - 3600*9
conversions = []
10_000.times do
  #conversions << now + rand(86400*3) - rand(86400*3)
  conversions << now + rand(3600*4) - rand(3600*4)
end
#conversions = [now, now + 86400, now - 86400]

#conversions = [
  #{:time => now, :value => 2},
  #{:time => now + 86400, :value => 1}
#]

require "benchmark"
bt = nil
puts Benchmark.realtime { bt = BestTime.new(conversions, :day) }
puts bt.best_time
bt.graph
