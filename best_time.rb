class BestTime
  attr_reader :buckets

  TIERS = {
    week: {
      range: 0...168,
      bucket: lambda{|time| time.wday*24 + time.hour },
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

    conversions.each do |conversion|
      mean = @tier[:bucket].call(conversion)
      size = range.max - range.min + 1
      std = size / 24
      #std = 1e-10
      value = 1 # could be weighted
      range.each do |key|
        @buckets[key] += value * (normal_pdf(key, mean, std) + normal_pdf(key + size, mean, std) + normal_pdf(key - size, mean, std))
      end
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

now = Time.now
conversions = [
  now,
  now + 3600,
  now + 7200
]

bt = BestTime.new(conversions, :week)
bt.graph
