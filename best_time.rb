class BestTime
  attr_reader :buckets

  TIERS = {
    week: {
      range: 0...168,
      bucket: lambda{|time| (time.wday*1440 + time.hour*60 + time.min)/60.0 },
    },
    day: {
      range: 0...96,
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

    size = range.max - range.min + 1
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
      mean = @tier[:bucket].call(conversion)
      weight = 1 # could be weighted

      # Fast way.
      rmin = (mean - std_range).floor
      rmax = (mean + std_range).ceil
      (rmin..rmax).each do |key|
        key = key % size
        value = normal_pdf(key, mean, std)
        value += normal_pdf(key, mean + size, std) if rmin <= 0
        value += normal_pdf(key, mean - size, std) if rmax >= size
        @buckets[key] += weight * value
      end

      # Slow way.
      #range.each do |key|
        #@buckets[key] += weight * (normal_pdf(key, mean, std) + normal_pdf(key + size, mean, std) + normal_pdf(key - size, mean, std))
      #end
    end

    # Normalize.
    max = @buckets.values.max
    @buckets.each{|k,v| @buckets[k] = v / max }
  end

  def graph
    rows = buckets.to_a.map{|v| [v[0], ("%.2f" % v[1]).to_f] }
    str = File.read("chart.html").gsub("{{rows}}", rows.inspect)
    filename = "/tmp/chart.html"
    File.open(filename, "w"){|f| f.write(str) }
    system("open '#{filename}'")
  end

  protected

  def normal_pdf(x, mean = 0, std = 1)
    Math.exp(-((x - mean)**2/(2.0*(std**2))))/(Math.sqrt(2*Math::PI)*std)
  end

end

now = Time.now - 86400*3 - 3600*2
conversions = []
10_000.times do
  conversions << now + rand(86400*4) - rand(86400*4)
end
#conversions = [now]

require "benchmark"
bt = nil
puts Benchmark.realtime { bt = BestTime.new(conversions, :week) }
bt.graph
