class BestTime
  attr_reader :buckets

  TIERS = {
    week: {
      range: 0...168,
      bucket: lambda{|time| (time.wday*1440 + time.hour*60 + time.min)/60.0 }
    },
    day: {
      range: 0..96,
      bucket: lambda{|time| (time.hour*60 + time.min)/15.0 }
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

    # Normalize.
    max = @buckets.values.max
    @buckets.each{|k,v| @buckets[k] = v / max }
  end

  def graph
    buckets = self.buckets
    buckets[buckets.keys.count] = buckets[0]
    rows = buckets.to_a #.map{|v| [v[0], ("%.2f" % v[1]).to_f] }
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
  conversions << now + rand(86400*3) - rand(86400*3)
end
#conversions = [now, now + 86400, now - 86400]

conversions = [
  {:time => now, :value => 2},
  {:time => now + 86400, :value => 1}
]

require "benchmark"
bt = nil
puts Benchmark.realtime { bt = BestTime.new(conversions, :week) }
bt.graph
